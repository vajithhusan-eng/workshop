import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/message_model.dart';
import '../models/agent_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final AgentModel? agent;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    this.agent,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser) _buildSenderName(),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppConstants.primaryColor
                        : AppConstants.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppConstants.primaryColor
                          : AppConstants.borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: message.content,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                                  p: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : AppConstants.textPrimary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  strong: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : AppConstants.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        selectable: true,
                      ),
                      if (message.confidence != null) _buildConfidence(),
                      if (!message.toolCalls.isEmpty) _buildToolCalls(),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Helpers.formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppConstants.textSecondary),
                ),
                if (message.isEdited && !isUser)
                  const Text(
                    '(edited)',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppConstants.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: agent != null
            ? getAgentColor(agent!.id.hashCode)
            : AppConstants.secondaryColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          agent?.name.isNotEmpty == true ? agent!.name[0].toUpperCase() : '🤖',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        agent?.name ?? 'Agent',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: agent != null
              ? getAgentColor(agent!.id.hashCode)
              : AppConstants.textSecondary,
        ),
      ),
    );
  }

  Widget _buildConfidence() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insights,
            size: 14,
            color: AppConstants.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            'Confidence: ${(message.confidence! * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 11,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCalls() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 Tool Calls (${message.toolCalls.length})',
              style: const TextStyle(
                fontSize: 11,
                color: AppConstants.textSecondary,
              ),
            ),
            ...message.toolCalls
                .take(3)
                .map(
                  (call) => Text(
                    '• $call',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ),
            if (message.toolCalls.length > 3)
              Text(
                '• +${message.toolCalls.length - 3} more',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppConstants.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// System message widget
class SystemMessageBubble extends StatelessWidget {
  final MessageModel message;

  const SystemMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
