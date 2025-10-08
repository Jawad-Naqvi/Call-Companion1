import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:call_companion/models/call.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/theme.dart';

class CallTile extends StatelessWidget {
  final Call call;
  final Customer customer;
  final VoidCallback onTap;

  const CallTile({
    super.key,
    required this.call,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Call type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCallTypeColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCallTypeIcon(),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getCallTypeText(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM d, HH:mm').format(call.startTime),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          if (call.duration != null) ...[
                            Text(
                              ' • ${call.formattedDuration}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Status indicators
                Column(
                  children: [
                    if (call.hasTranscript)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Icon(
                          Icons.transcribe,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.light
                              ? LightModeColors.lightSuccess
                              : DarkModeColors.darkSuccess,
                        ),
                      ),
                    if (call.hasAISummary)
                      Icon(
                        Icons.smart_toy,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
                
                const SizedBox(width: 8),
                
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCallTypeIcon() {
    switch (call.type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
    }
  }

  String _getCallTypeText() {
    switch (call.type) {
      case CallType.incoming:
        return 'Incoming Call';
      case CallType.outgoing:
        return 'Outgoing Call';
    }
  }

  Color _getCallTypeColor(BuildContext context) {
    switch (call.type) {
      case CallType.incoming:
        return Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightSuccess
            : DarkModeColors.darkSuccess;
      case CallType.outgoing:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getStatusText() {
    switch (call.status) {
      case CallStatus.recording:
        return 'RECORDING';
      case CallStatus.completed:
        return 'COMPLETED';
      case CallStatus.transcribing:
        return 'TRANSCRIBING';
      case CallStatus.analyzed:
        return 'ANALYZED';
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (call.status) {
      case CallStatus.recording:
        return Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightRecording
            : DarkModeColors.darkRecording;
      case CallStatus.completed:
        return Theme.of(context).colorScheme.secondary;
      case CallStatus.transcribing:
        return Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightWarning
            : DarkModeColors.darkWarning;
      case CallStatus.analyzed:
        return Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightSuccess
            : DarkModeColors.darkSuccess;
    }
  }
}