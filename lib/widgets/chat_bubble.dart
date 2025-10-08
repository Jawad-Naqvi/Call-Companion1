import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isFromUser;
  final DateTime timestamp;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isFromUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isFromUser) ...[
            const CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 16,
              child: Icon(Icons.smart_toy, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFromUser
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isFromUser ? 16 : 4),
                      bottomRight: Radius.circular(isFromUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isFromUser
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    DateFormat.jm().format(timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (isFromUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.green,
              radius: 16,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}