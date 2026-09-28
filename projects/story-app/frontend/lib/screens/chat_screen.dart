import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../models/agent_model.dart';
import '../providers/chat_provider.dart';
import '../providers/session_provider.dart';
import '../providers/websocket_provider.dart';
import '../utils/constants.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Set current session ID in chat provider
    final currentSession = ref.read(selectedSessionProvider);
    if (currentSession != null) {
      ref.read(chatProvider.notifier).setCurrentSessionId(currentSession.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final isTyping = ref.watch(isTypingProvider);
    final typingAgentId = ref.watch(chatProvider).typingAgentId;
    final currentSession = ref.read(selectedSessionProvider);
    final agents = ref.watch(agentsListProvider);
    final websocketState = ref.watch(websocketStateProvider);

    // Find the agent that is typing
    final typingAgent = typingAgentId != null
        ? agents.where((a) => a.id == typingAgentId).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentSession?.title ?? 'Chat',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: websocketState.isConnected
                        ? AppConstants.successColor
                        : AppConstants.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  websocketState.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 11,
                    color: websocketState.isConnected
                        ? AppConstants.successColor
                        : AppConstants.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(websocketProvider.notifier).reconnect();
            },
            tooltip: 'Reconnect',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    reverse: false,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final agent = agents
                          .where((a) => a.id == message.agentId)
                          .firstOrNull;
                      final isLastInGroup = index == messages.length - 1;

                      // Show typing indicator if this is the last message
                      // and we're typing
                      if (isLastInGroup && isTyping && typingAgent != null) {
                        return Column(
                          children: [
                            MessageBubble(
                              message: message,
                              agent: agent,
                              isLastInGroup: false,
                            ),
                            TypingIndicator(agentName: typingAgent.name),
                          ],
                        );
                      }

                      return MessageBubble(
                        message: message,
                        agent: agent,
                        isLastInGroup: isLastInGroup,
                      );
                    },
                  ),
          ),

          // Typing indicator at bottom
          if (isTyping && typingAgent != null)
            TypingIndicator(agentName: typingAgent.name),

          // Chat input
          ChatInput(
            onSend: (text) => _handleSendMessage(text),
            isLoading: isTyping,
            hintText: 'Type a message...',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppConstants.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppConstants.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a session or create a new one',
            style: TextStyle(
              color: AppConstants.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendMessage(String text) {
    final currentSession = ref.read(selectedSessionProvider);
    if (currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a session first')),
      );
      return;
    }

    ref.read(chatProvider.notifier).sendMessage(currentSession.id, text);
  }
}
