import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/providers/recording_provider.dart';
import 'package:call_companion/providers/auth_provider.dart';

class RecordingToggle extends StatelessWidget {
  const RecordingToggle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recordingProvider = Provider.of<RecordingProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Call Recording',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: recordingProvider.isRecordingEnabled,
                onChanged: (value) async {
                  try {
                    await recordingProvider.toggleRecording(
                      authProvider.currentUser!.id,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          if (recordingProvider.isServiceRunning)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recording Active',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (recordingProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                recordingProvider.error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}