import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_companion/providers/call_provider.dart';

class RecordingWidget extends StatefulWidget {
  const RecordingWidget({super.key});

  @override
  State<RecordingWidget> createState() => _RecordingWidgetState();
}

class _RecordingWidgetState extends State<RecordingWidget> with TickerProviderStateMixin {
  bool _isRecordingEnabled = false;
  bool _isProcessing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final isRecording = callProvider.isRecording;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Call Recording',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: _isRecordingEnabled,
                  onChanged: _isProcessing 
                    ? null 
                    : (value) => _toggleRecording(value, context),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            if (_isRecordingEnabled) ...[
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isRecording
                        ? Colors.red.withOpacity(0.1 + _pulseController.value * 0.2)
                        : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRecording ? Icons.mic : Icons.mic_none,
                          color: isRecording ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRecording ? 'Recording...' : 'Ready to record',
                          style: TextStyle(
                            color: isRecording ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording(bool enabled, BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      
      if (enabled) {
        // Request microphone permission
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          await callProvider.enableGlobalRecording();
          setState(() {
            _isRecordingEnabled = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call recording enabled'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission required for call recording'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        await callProvider.disableGlobalRecording();
        setState(() {
          _isRecordingEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call recording disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}