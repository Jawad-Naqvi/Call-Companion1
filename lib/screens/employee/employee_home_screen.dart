import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/providers/recording_provider.dart';
import 'package:call_companion/widgets/recording_toggle.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Global recording toggle
          const RecordingToggle(),

          // Customer search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                // TODO: Implement customer search
              },
            ),
          ),

          // Customer threads list
          Expanded(
            child: Consumer<RecordingProvider>(
              builder: (context, recordingProvider, child) {
                // TODO: Replace with actual customer threads
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.phone_callback_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        recordingProvider.isRecordingEnabled
                            ? 'Recording is active\nWaiting for calls...'
                            : 'Enable call recording to get started',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}