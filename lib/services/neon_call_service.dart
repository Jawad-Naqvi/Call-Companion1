import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service to sync call recordings to Neon database via backend API
/// Works alongside Firebase storage for redundancy
class NeonCallService {
  // Use the same backend URL as auth
  static const String baseUrl = kIsWeb 
      ? 'http://localhost:8001/api'
      : 'http://192.168.1.17:8001/api';
  
  static const String tokenKey = 'auth_token';

  /// Get stored authentication token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  /// Upload call recording to Neon database
  /// Returns the call record ID from Neon if successful
  Future<String?> uploadCallRecording({
    required String userId,
    required String customerNumber,
    String? customerName,
    required String callType, // 'incoming' or 'outgoing'
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationSec,
    String? firebaseCallId,
    String? firebaseAudioUrl,
    File? audioFile,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('[NeonCallService] No auth token found');
        return null;
      }

      final uri = Uri.parse('$baseUrl/calls/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['user_id'] = userId;
      request.fields['customer_number'] = customerNumber;
      if (customerName != null) {
        request.fields['customer_name'] = customerName;
      }
      request.fields['call_type'] = callType;
      request.fields['started_at'] = startedAt.toIso8601String();
      if (endedAt != null) {
        request.fields['ended_at'] = endedAt.toIso8601String();
      }
      if (durationSec != null) {
        request.fields['duration_sec'] = durationSec.toString();
      }
      if (firebaseCallId != null) {
        request.fields['firebase_call_id'] = firebaseCallId;
      }
      if (firebaseAudioUrl != null) {
        request.fields['firebase_audio_url'] = firebaseAudioUrl;
      }

      // Add audio file if provided
      if (audioFile != null && await audioFile.exists()) {
        final fileStream = http.ByteStream(audioFile.openRead());
        final fileLength = await audioFile.length();
        
        final multipartFile = http.MultipartFile(
          'audio_file',
          fileStream,
          fileLength,
          filename: 'recording.m4a',
        );
        
        request.files.add(multipartFile);
        print('[NeonCallService] Added audio file: ${fileLength} bytes');
      }

      print('[NeonCallService] Uploading call recording to Neon...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final callId = data['id'];
        print('[NeonCallService] ✅ Call uploaded to Neon: $callId');
        return callId;
      } else {
        print('[NeonCallService] ❌ Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('[NeonCallService] ❌ Error uploading call: $e');
      return null;
    }
  }

  /// Get call records for a specific customer
  Future<List<Map<String, dynamic>>> getCallsByCustomer(String customerNumber) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('[NeonCallService] No auth token found');
        return [];
      }

      final uri = Uri.parse('$baseUrl/calls?customer_number=$customerNumber&limit=50');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[NeonCallService] ✅ Retrieved ${data.length} calls from Neon');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('[NeonCallService] ❌ Get calls failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[NeonCallService] ❌ Error getting calls: $e');
      return [];
    }
  }

  /// Get call records for a specific user
  Future<List<Map<String, dynamic>>> getCallsByUser(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('[NeonCallService] No auth token found');
        return [];
      }

      final uri = Uri.parse('$baseUrl/calls?user_id=$userId&limit=50');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[NeonCallService] ✅ Retrieved ${data.length} calls from Neon');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('[NeonCallService] ❌ Get calls failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[NeonCallService] ❌ Error getting calls: $e');
      return [];
    }
  }

  /// Get audio URL for streaming from backend
  String getAudioUrl(String callId) {
    return '$baseUrl/calls/$callId/audio';
  }

  /// Get headers for authenticated audio streaming
  Future<Map<String, String>> getAudioHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }
}
