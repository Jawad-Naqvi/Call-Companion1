import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:call_companion/services/transcription_service.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockStorage extends Mock implements FirebaseStorage {}
class MockReference extends Mock implements Reference {}
class MockUploadTask extends Mock implements UploadTask {}
class MockTaskSnapshot extends Mock implements TaskSnapshot {}

void main() {
  late TranscriptionService transcriptionService;
  late MockFirestore mockFirestore;
  late MockStorage mockStorage;
  late MockReference mockReference;

  setUp(() {
    mockFirestore = MockFirestore();
    mockStorage = MockStorage();
    mockReference = MockReference();
    transcriptionService = TranscriptionService();
  });

  group('TranscriptionService Tests', () {
    test('transcribeCall should handle successful transcription', () async {
      // Arrange
      const callId = 'test_call_id';
      const audioUrl = 'test_audio_url';
      final mockTranscript = {
        'text': 'This is a test transcript',
        'segments': [],
        'language': 'en'
      };

      // Mock storage behavior
      when(mockStorage.ref()).thenReturn(mockReference);
      when(mockReference.child(any)).thenReturn(mockReference);
      
      // Act
      final result = await transcriptionService.transcribeCall(
        callId: callId,
        audioUrl: audioUrl,
        provider: 'whisper'
      );

      // Assert
      expect(result, isNotNull);
      expect(result['text'], isNotEmpty);
      verify(mockFirestore.collection('calls').doc(callId).update(any)).called(1);
    });

    test('transcribeCall should handle errors gracefully', () async {
      // Arrange
      const callId = 'test_call_id';
      const audioUrl = 'invalid_audio_url';

      // Mock storage behavior to throw error
      when(mockStorage.ref()).thenThrow(Exception('Storage error'));

      // Act & Assert
      expect(
        () => transcriptionService.transcribeCall(
          callId: callId,
          audioUrl: audioUrl,
          provider: 'whisper'
        ),
        throwsException
      );
    });
  });
}