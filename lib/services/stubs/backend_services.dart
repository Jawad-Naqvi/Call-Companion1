import 'package:call_companion/models/call.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/ai_summary.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final _mockCustomers = [
    Customer(
      id: '1',
      phoneNumber: '+1 (555) 123-4567',
      name: 'John Smith',
      company: 'Tech Solutions Inc.',
      email: 'john.smith@techsolutions.com',
      employeeId: 'dev_user_1',
      alias: 'Enterprise Client',
      lastCallAt: DateTime.now().subtract(const Duration(hours: 2)),
      totalCalls: 5,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    ),
    Customer(
      id: '2',
      phoneNumber: '+1 (555) 987-6543',
      name: 'Sarah Johnson',
      company: 'Marketing Pros LLC',
      email: 'sarah.j@marketingpros.com',
      employeeId: 'dev_user_1',
      alias: 'Marketing Lead',
      lastCallAt: DateTime.now().subtract(const Duration(days: 1)),
      totalCalls: 3,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final _mockCalls = [
    Call(
      id: '1',
      employeeId: 'dev_user_1',
      customerId: '1',
      customerPhoneNumber: '+1 (555) 123-4567',
      type: CallType.outgoing,
      status: CallStatus.analyzed,
      startTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      endTime: DateTime.now().subtract(const Duration(hours: 2)),
      duration: 15 * 60 + 30,
      audioFileUrl: 'mock_recording_1.mp3',
      audioFileName: 'call_1.mp3',
      audioFileSize: 1024 * 1024,
      hasTranscript: true,
      hasAISummary: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Call(
      id: '2',
      employeeId: 'dev_user_1',
      customerId: '2',
      customerPhoneNumber: '+1 (555) 987-6543',
      type: CallType.incoming,
      status: CallStatus.analyzed,
      startTime: DateTime.now().subtract(const Duration(days: 1, minutes: 8)),
      endTime: DateTime.now().subtract(const Duration(days: 1)),
      duration: 8 * 60 + 45,
      audioFileUrl: 'mock_recording_2.mp3',
      audioFileName: 'call_2.mp3',
      audioFileSize: 768 * 1024,
      hasTranscript: true,
      hasAISummary: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<List<Customer>> getCustomers(String employeeId) async {
    return _mockCustomers;
  }

  Future<List<Call>> getCalls(String employeeId) async {
    return _mockCalls;
  }

  Future<Customer?> getCustomer(String customerId) async {
    return _mockCustomers.firstWhere((c) => c.id == customerId);
  }

  Future<Call?> getCall(String callId) async {
    return _mockCalls.firstWhere((c) => c.id == callId);
  }

  Future<Transcript?> getTranscript(String callId) async {
    if (callId == '1') {
      final text = '''
Employee: Hello, this is Alex from Call Companion. How are you today, Mr. Smith?
Customer: Hi Alex, I'm doing well, thanks. I was expecting your call.
Employee: Great! I wanted to follow up on our previous discussion about the enterprise solution.
Customer: Yes, we've reviewed the proposal and have some questions about implementation.
Employee: Of course! I'd be happy to address any concerns you have about the implementation process.
''';
      return Transcript(
        id: 'transcript_1',
        callId: '1',
        employeeId: 'dev_user_1',
        customerId: '1',
        fullText: text,
        segments: [
          TranscriptSegment(
            text: "Hello, this is Alex from Call Companion. How are you today, Mr. Smith?",
            startTime: 0.0,
            endTime: 4.5,
            speaker: 'employee',
          ),
          TranscriptSegment(
            text: "Hi Alex, I'm doing well, thanks. I was expecting your call.",
            startTime: 4.8,
            endTime: 8.2,
            speaker: 'customer',
          ),
          TranscriptSegment(
            text: "Great! I wanted to follow up on our previous discussion about the enterprise solution.",
            startTime: 8.5,
            endTime: 13.0,
            speaker: 'employee',
          ),
          TranscriptSegment(
            text: "Yes, we've reviewed the proposal and have some questions about implementation.",
            startTime: 13.5,
            endTime: 18.0,
            speaker: 'customer',
          ),
          TranscriptSegment(
            text: "Of course! I'd be happy to address any concerns you have about the implementation process.",
            startTime: 18.5,
            endTime: 23.0,
            speaker: 'employee',
          ),
        ],
        confidence: 0.95,
        language: 'en',
        transcriptionProvider: 'whisper',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      );
    } else if (callId == '2') {
      final text = '''
Employee: Thank you for calling Call Companion. This is Alex speaking.
Customer: Hi Alex, this is Sarah from Marketing Pros. I'm calling about the marketing analytics feature.
Employee: Hello Sarah! Yes, I'd be happy to discuss our marketing analytics capabilities.
Customer: Great, we're particularly interested in the social media integration aspects.
Employee: I'll walk you through our social media analytics dashboard and reporting features.
''';
      return Transcript(
        id: 'transcript_2',
        callId: '2',
        employeeId: 'dev_user_1',
        customerId: '2',
        fullText: text,
        segments: [
          TranscriptSegment(
            text: "Thank you for calling Call Companion. This is Alex speaking.",
            startTime: 0.0,
            endTime: 3.5,
            speaker: 'employee',
          ),
          TranscriptSegment(
            text: "Hi Alex, this is Sarah from Marketing Pros. I'm calling about the marketing analytics feature.",
            startTime: 4.0,
            endTime: 9.5,
            speaker: 'customer',
          ),
          TranscriptSegment(
            text: "Hello Sarah! Yes, I'd be happy to discuss our marketing analytics capabilities.",
            startTime: 10.0,
            endTime: 14.5,
            speaker: 'employee',
          ),
          TranscriptSegment(
            text: "Great, we're particularly interested in the social media integration aspects.",
            startTime: 15.0,
            endTime: 19.5,
            speaker: 'customer',
          ),
          TranscriptSegment(
            text: "I'll walk you through our social media analytics dashboard and reporting features.",
            startTime: 20.0,
            endTime: 24.5,
            speaker: 'employee',
          ),
        ],
        confidence: 0.92,
        language: 'en',
        transcriptionProvider: 'whisper',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
    }
    return null;
  }

  Future<AISummary?> getAISummary(String callId) async {
    if (callId == '1') {
      return AISummary(
        id: 'summary_1',
        callId: '1',
        employeeId: 'dev_user_1',
        customerId: '1',
        summary: 'Follow-up call discussing enterprise solution implementation with positive customer engagement.',
        keyHighlights: [
          'Follow-up call regarding enterprise solution proposal',
          'Customer has reviewed the proposal',
          'Customer has implementation questions',
          'Positive engagement and receptive to discussion'
        ],
        sentiment: SentimentType.positive,
        sentimentScore: 0.8,
        nextSteps: [
          'Schedule technical review meeting',
          'Prepare detailed implementation timeline',
          'Send pricing breakdown for enterprise tier'
        ],
        concerns: ['Implementation complexity needs to be addressed'],
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      );
    } else if (callId == '2') {
      return AISummary(
        id: 'summary_2',
        callId: '2',
        employeeId: 'dev_user_1',
        customerId: '2',
        summary: 'Inbound inquiry about marketing analytics features with focus on social media integration.',
        keyHighlights: [
          'Inbound inquiry about marketing analytics feature',
          'Specific interest in social media integration',
          'Discussed analytics dashboard and reporting',
          'Customer showed high engagement'
        ],
        sentiment: SentimentType.positive,
        sentimentScore: 0.9,
        nextSteps: [
          'Send marketing analytics feature documentation',
          'Schedule demo of social media dashboard',
          'Prepare custom report examples'
        ],
        concerns: [],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
    }
    return null;
  }
}