import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;
  final String? hintText;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.hintText = 'Type a message...',
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        border: Border(top: BorderSide(color: AppConstants.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField()),
              const SizedBox(width: 8),
              _buildSendButton(),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: _isExpanded ? 5 : 1,
      textInputAction: _isExpanded
          ? TextInputAction.newline
          : TextInputAction.send,
      onSubmitted: _handleSubmit,
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: AppConstants.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _controller.text.trim().isNotEmpty && !widget.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: canSend ? AppConstants.primaryColor : AppConstants.borderColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: widget.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send, color: Colors.white, size: 20),
        onPressed: canSend ? () => _handleSubmit(_controller.text) : null,
      ),
    );
  }

  void _handleSubmit(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      widget.onSend(trimmed);
      _controller.clear();
      setState(() {
        _isExpanded = false;
      });
      _focusNode.requestFocus();
    }
  }
}

// Quick action buttons widget
class ChatQuickActions extends StatelessWidget {
  final List<String> actions;
  final Function(String) onTap;

  const ChatQuickActions({
    super.key,
    required this.actions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: actions.map((action) {
          return GestureDetector(
            onTap: () => onTap(action),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppConstants.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppConstants.textSecondary,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Typing indicator widget
class TypingIndicator extends StatelessWidget {
  final String agentName;

  const TypingIndicator({super.key, required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppConstants.textSecondary,
                  shape: BoxShape.circle,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  key: ValueKey(index),
                  builder: (context, value, child) {
                    return Container(
                      height: 6 * value,
                      decoration: const BoxDecoration(
                        color: AppConstants.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            '$agentName is typing...',
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
