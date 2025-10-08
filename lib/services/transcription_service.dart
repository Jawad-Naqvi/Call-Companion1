import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/call.dart';

class TranscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // These would be configured via environment variables or app settings
  static const String _whisperApiUrl = 'https://api.openai.com/v1/audio/transcriptions';
  static const String _deepgramApiUrl = 'https://api.deepgram.com/v1/listen';
  
  Future<Transcript?> transcribeCall(Call call, String apiKey, {String provider = 'whisper'}) async {
    try {
      if (call.audioFileUrl == null) {
        throw Exception('No audio file URL found for call');
      }

      String transcriptionText;
      List<TranscriptSegment> segments = [];
      double confidence = 0.0;

      switch (provider.toLowerCase()) {
        case 'whisper':
          final result = await _transcribeWithWhisper(call.audioFileUrl!, apiKey);
          transcriptionText = result['text'] ?? '';
          confidence = result['confidence'] ?? 0.0;
          segments = result['segments'] ?? [];
          break;
        case 'deepgram':
          final result = await _transcribeWithDeepgram(call.audioFileUrl!, apiKey);
          transcriptionText = result['text'] ?? '';
          confidence = result['confidence'] ?? 0.0;
          segments = result['segments'] ?? [];
          break;
        default:
          throw Exception('Unsupported transcription provider: $provider');
      }

      if (transcriptionText.isEmpty) {
        throw Exception('Empty transcription received');
      }

      final transcript = Transcript(
        id: _uuid.v4(),
        callId: call.id,
        employeeId: call.employeeId,
        customerId: call.customerId,
        fullText: transcriptionText,
        segments: segments,
        confidence: confidence,
        transcriptionProvider: provider,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save transcript to Firestore
      await _firestore
          .collection('transcripts')
          .doc(transcript.id)
          .set(transcript.toJson());

      return transcript;
    } catch (e) {
      print('Error transcribing call: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _transcribeWithWhisper(String audioUrl, String apiKey) async {
    try {
      // Download audio file temporarily
      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode != 200) {
        throw Exception('Failed to download audio file');
      }

      final request = http.MultipartRequest('POST', Uri.parse(_whisperApiUrl));
      request.headers['Authorization'] = 'Bearer $apiKey';
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioResponse.bodyBytes,
          filename: 'audio.m4a',
        ),
      );
      
      request.fields['model'] = 'whisper-1';
      request.fields['response_format'] = 'verbose_json';
      // Auto-detect language to support Indian languages like Hindi, Tamil, etc.
      // Whisper is particularly good with Hinglish and other Indian language variations

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        final segments = (data['segments'] as List<dynamic>?)?.map((segment) {
          return TranscriptSegment(
            text: segment['text'] as String,
            startTime: (segment['start'] as num).toDouble(),
            endTime: (segment['end'] as num).toDouble(),
          );
        }).toList() ?? [];

        return {
          'text': data['text'] as String,
          'confidence': _calculateAverageConfidence(data),
          'segments': segments,
        };
      } else {
        throw Exception('Whisper API error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error with Whisper transcription: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _transcribeWithDeepgram(String audioUrl, String apiKey) async {
    try {
      final headers = {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'url': audioUrl,
        'options': {
          'punctuate': true,
          'language': 'en',
          'model': 'general',
          'tier': 'enhanced',
          'timestamps': true,
          'smart_format': true,
        },
      });

      final response = await http.post(
        Uri.parse(_deepgramApiUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'];
        
        if (results != null && results['channels'] != null) {
          final channel = results['channels'][0];
          final alternatives = channel['alternatives'][0];
          
          final transcript = alternatives['transcript'] as String;
          final confidence = (alternatives['confidence'] as num?)?.toDouble() ?? 0.0;
          
          final segments = (alternatives['words'] as List<dynamic>?)?.map((word) {
            return TranscriptSegment(
              text: word['word'] as String,
              startTime: (word['start'] as num).toDouble(),
              endTime: (word['end'] as num).toDouble(),
            );
          }).toList() ?? [];

          return {
            'text': transcript,
            'confidence': confidence,
            'segments': segments,
          };
        }
      }

      throw Exception('Deepgram API error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error with Deepgram transcription: $e');
      rethrow;
    }
  }

  double _calculateAverageConfidence(Map<String, dynamic> whisperData) {
    final segments = whisperData['segments'] as List<dynamic>?;
    if (segments == null || segments.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int count = 0;

    for (final segment in segments) {
      if (segment['no_speech_prob'] != null) {
        totalConfidence += (1.0 - (segment['no_speech_prob'] as num));
        count++;
      }
    }

    return count > 0 ? totalConfidence / count : 0.0;
  }

  Future<Transcript?> getTranscriptByCallId(String callId) async {
    try {
      final querySnapshot = await _firestore
          .collection('transcripts')
          .where('callId', isEqualTo: callId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Transcript.fromJson({...doc.data(), 'id': doc.id});
      }
    } catch (e) {
      print('Error getting transcript: $e');
    }
    return null;
  }

  Future<List<Transcript>> getTranscriptsByCustomer(String customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('transcripts')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => 
        Transcript.fromJson({...doc.data(), 'id': doc.id})
      ).toList();
    } catch (e) {
      print('Error getting transcripts by customer: $e');
      return [];
    }
  }

  Future<bool> deleteTranscript(String transcriptId) async {
    try {
      await _firestore.collection('transcripts').doc(transcriptId).delete();
      return true;
    } catch (e) {
      print('Error deleting transcript: $e');
      return false;
    }
  }
}