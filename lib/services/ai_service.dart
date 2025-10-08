import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:call_companion/config/environment.dart';
import 'package:call_companion/models/ai_summary.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/chat_message.dart';
import 'package:call_companion/models/call.dart';

class AIService {
  FirebaseFirestore? _firestore; // Only initialized on mobile/desktop
  final Uuid _uuid = const Uuid();

  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  
  String get _geminiApiKey => Environment.geminiApiKey;
  
  Future<AISummary?> generateCallSummary(Transcript transcript, {String? apiKey}) async {
    final key = apiKey ?? Environment.geminiApiKey;
    try {
      final prompt = _buildSummaryPrompt(transcript.fullText);
      final response = await _callGeminiAPI(prompt, key);
      
      if (response == null) return null;

      final summary = _parseSummaryResponse(response);
      
      final aiSummary = AISummary(
        id: _uuid.v4(),
        callId: transcript.callId,
        employeeId: transcript.employeeId,
        customerId: transcript.customerId,
        summary: summary['summary'] ?? '',
        keyHighlights: summary['highlights'] ?? [],
        sentiment: summary['sentiment'] ?? SentimentType.neutral,
        sentimentScore: summary['sentimentScore'] ?? 0.0,
        nextSteps: summary['nextSteps'] ?? [],
        concerns: summary['concerns'] ?? [],
        aiProvider: 'gemini',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore (skip on web to avoid Firebase initialization issues)
      if (!kIsWeb) {
        _firestore ??= FirebaseFirestore.instance;
        await _firestore!
            .collection('ai_summaries')
            .doc(aiSummary.id)
            .set(aiSummary.toJson());
      }

      return aiSummary;
    } catch (e) {
      print('Error generating AI summary: $e');
      return null;
    }
  }

  Future<String?> generateAIResponse({
    required String userMessage,
    required String customerId,
    required String employeeId,
    String? apiKey,
  }) async {
    final key = apiKey ?? Environment.geminiApiKey;
    try {
      // Get context from previous summaries and chat
      final context = await _buildContextForCustomer(customerId, employeeId);
      final prompt = _buildChatPrompt(userMessage, context);

      String? response;
      if (kIsWeb) {
        // Call backend proxy to avoid CORS and Firebase on web
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final headers = {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        };
        final body = jsonEncode({
          'message': userMessage,
          'context': context,
          'temperature': 0.7,
          'apiKey': Environment.geminiApiKey,
        });
        final resp = await http.post(
          Uri.parse('http://127.0.0.1:8001/api/ai/chat'),
          headers: headers,
          body: body,
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          response = data['reply'] as String?;
        } else {
          throw Exception('AI proxy error ${resp.statusCode}: ${resp.body}');
        }
      } else {
        // Mobile/desktop: call Gemini directly, persist chat to Firestore
        response = await _callGeminiAPI(prompt, key);
      }
      
      if (response != null) {
        // Save both user message and AI response
        await _saveChatMessage(
          customerId: customerId,
          employeeId: employeeId,
          content: userMessage,
          sender: MessageSender.user,
        );
        await _saveChatMessage(
          customerId: customerId,
          employeeId: employeeId,
          content: response,
          sender: MessageSender.ai,
        );
      }
      
      return response;
    } catch (e) {
      print('Error generating AI response: $e');
      return null;
    }
  }

  Future<String?> _callGeminiAPI(String prompt, String apiKey) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'contents': [{
          'parts': [{'text': prompt}]
        }],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      });

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$apiKey'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
    }
    return null;
  }

  String _buildSummaryPrompt(String transcript) {
    return '''
Analyze this sales call transcript and provide a structured summary in JSON format:

Transcript: "$transcript"

Please provide the response in the following JSON structure:
{
  "summary": "Brief overview of the call in 2-3 sentences",
  "highlights": ["Key point 1", "Key point 2", "Key point 3"],
  "sentiment": "positive|neutral|negative",
  "sentimentScore": -1.0 to 1.0,
  "nextSteps": ["Action item 1", "Action item 2"],
  "concerns": ["Customer concern 1", "Customer concern 2"]
}

Focus on:
- Container sales context
- Customer needs and pain points
- Pricing discussions
- Timeline and delivery requirements
- Competitor mentions
- Decision-making process
- Follow-up requirements

Ensure the sentiment analysis considers the overall tone and customer engagement level.
''';
  }

  String _buildChatPrompt(String userMessage, String context) {
    return '''
You are an AI sales assistant helping a container sales representative. 

Context from previous interactions with this customer:
$context

Current question from the sales rep: "$userMessage"

Please provide a helpful, strategic response that:
1. Takes into account all previous interactions with this customer
2. Suggests next steps based on the customer's history
3. Identifies opportunities or concerns
4. Provides actionable sales advice
5. Maintains a professional, supportive tone

Keep responses concise but comprehensive, focusing on practical sales strategies.
''';
  }

  Map<String, dynamic> _parseSummaryResponse(String response) {
    try {
      // Try to extract JSON from the response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonString = response.substring(jsonStart, jsonEnd + 1);
        final parsed = jsonDecode(jsonString);
        
        return {
          'summary': parsed['summary'] as String?,
          'highlights': List<String>.from(parsed['highlights'] ?? []),
          'sentiment': _parseSentiment(parsed['sentiment']),
          'sentimentScore': (parsed['sentimentScore'] as num?)?.toDouble() ?? 0.0,
          'nextSteps': List<String>.from(parsed['nextSteps'] ?? []),
          'concerns': List<String>.from(parsed['concerns'] ?? []),
        };
      }
    } catch (e) {
      print('Error parsing summary response: $e');
    }
    
    // Fallback parsing
    return {
      'summary': response.length > 200 ? response.substring(0, 200) + '...' : response,
      'highlights': <String>[],
      'sentiment': SentimentType.neutral,
      'sentimentScore': 0.0,
      'nextSteps': <String>[],
      'concerns': <String>[],
    };
  }

  SentimentType _parseSentiment(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'positive':
        return SentimentType.positive;
      case 'negative':
        return SentimentType.negative;
      default:
        return SentimentType.neutral;
    }
  }

  Future<String> _buildContextForCustomer(String customerId, String employeeId) async {
    try {
      final summaries = await getAISummariesByCustomer(customerId);
      final chatMessages = await getChatMessagesByCustomer(customerId, employeeId);
      
      final context = StringBuffer();
      
      if (summaries.isNotEmpty) {
        context.writeln('Previous call summaries:');
        for (final summary in summaries.take(5)) { // Last 5 calls
          context.writeln('- ${summary.summary}');
          if (summary.concerns.isNotEmpty) {
            context.writeln('  Concerns: ${summary.concerns.join(', ')}');
          }
          if (summary.nextSteps.isNotEmpty) {
            context.writeln('  Next steps: ${summary.nextSteps.join(', ')}');
          }
        }
      }
      
      if (chatMessages.isNotEmpty) {
        context.writeln('\nRecent chat history:');
        for (final message in chatMessages.take(10)) { // Last 10 messages
          final sender = message.isFromUser ? 'Rep' : 'AI';
          context.writeln('$sender: ${message.content}');
        }
      }
      
      return context.toString();
    } catch (e) {
      print('Error building context: $e');
      return 'No previous interaction history available.';
    }
  }

  Future<void> _saveChatMessage({
    required String customerId,
    required String employeeId,
    required String content,
    required MessageSender sender,
    String? relatedCallId,
  }) async {
    try {
      final now = DateTime.now();
      final msgId = _uuid.v4();
      if (kIsWeb) {
        // Persist to local storage on web so UI can render history
        final prefs = await SharedPreferences.getInstance();
        final key = 'chat_${customerId}_${employeeId}';
        final raw = prefs.getString(key);
        final List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : <dynamic>[];
        final map = {
          'id': msgId,
          'customerId': customerId,
          'employeeId': employeeId,
          'content': content,
          'sender': sender.name,
          'type': MessageType.text.name,
          'metadata': null,
          'relatedCallId': relatedCallId,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        list.add(map);
        await prefs.setString(key, jsonEncode(list));
        return;
      }

      _firestore ??= FirebaseFirestore.instance;
      final message = ChatMessage(
        id: msgId,
        customerId: customerId,
        employeeId: employeeId,
        content: content,
        sender: sender,
        relatedCallId: relatedCallId,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore!
          .collection('chat_messages')
          .doc(message.id)
          .set(message.toJson());
    } catch (e) {
      print('Error saving chat message: $e');
    }
  }

  Future<AISummary?> getAISummaryByCallId(String callId) async {
    try {
      if (kIsWeb) return null; // Skip Firestore on web
      _firestore ??= FirebaseFirestore.instance;
      final querySnapshot = await _firestore!
          .collection('ai_summaries')
          .where('callId', isEqualTo: callId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return AISummary.fromJson({...doc.data(), 'id': doc.id});
      }
    } catch (e) {
      print('Error getting AI summary: $e');
    }
    return null;
  }

  Future<List<AISummary>> getAISummariesByCustomer(String customerId) async {
    try {
      if (kIsWeb) return []; // Skip Firestore on web
      _firestore ??= FirebaseFirestore.instance;
      final querySnapshot = await _firestore!
          .collection('ai_summaries')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => 
        AISummary.fromJson({...doc.data(), 'id': doc.id})
      ).toList();
    } catch (e) {
      print('Error getting AI summaries by customer: $e');
      return [];
    }
  }

  Future<List<ChatMessage>> getChatMessagesByCustomer(String customerId, String employeeId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'chat_${customerId}_${employeeId}';
        final raw = prefs.getString(key);
        if (raw == null) return [];
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final msgs = list.map((m) {
          final map = m as Map<String, dynamic>;
          return ChatMessage(
            id: map['id'] as String,
            customerId: map['customerId'] as String,
            employeeId: map['employeeId'] as String,
            content: map['content'] as String,
            sender: MessageSender.values.firstWhere((e) => e.name == (map['sender'] as String)),
            type: MessageType.text,
            metadata: map['metadata'] as Map<String, dynamic>?,
            relatedCallId: map['relatedCallId'] as String?,
            createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
            updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
          );
        }).toList();
        // Return in descending createdAt like Firestore query
        msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return msgs;
      }

      _firestore ??= FirebaseFirestore.instance;
      final querySnapshot = await _firestore!
          .collection('chat_messages')
          .where('customerId', isEqualTo: customerId)
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => 
        ChatMessage.fromJson({...doc.data(), 'id': doc.id})
      ).toList();
    } catch (e) {
      print('Error getting chat messages: $e');
      return [];
    }
  }
}