import 'package:flutter/material.dart';

import '../utils/constants.dart';

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
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                key: ValueKey(index),
                builder: (context, value, child) {
                  return Container(
                    width: 6,
                    height: 6 * value,
                    decoration: BoxDecoration(
                      color: AppConstants.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  );
                },
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
