import 'package:flutter/material.dart';

import '../models/agent_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AgentAvatar extends StatelessWidget {
  final AgentModel? agent;
  final double size;
  final bool showStatus;
  final bool isOnline;
  final VoidCallback? onTap;

  const AgentAvatar({
    super.key,
    this.agent,
    this.size = 40,
    this.showStatus = false,
    this.isOnline = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: agent != null
              ? getAgentColor(agent!.id.hashCode).withOpacity(0.2)
              : AppConstants.secondaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: agent != null
                ? getAgentColor(agent!.id.hashCode).withOpacity(0.5)
                : AppConstants.borderColor,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(_getEmoji(), style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }

  String _getEmoji() {
    if (agent == null) return '🤖';
    return getAgentEmoji(agent!.type);
  }
}

// Agent list item widget
class AgentListItem extends StatelessWidget {
  final AgentModel agent;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const AgentListItem({
    super.key,
    required this.agent,
    this.isSelected = false,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? getAgentColor(agent.id.hashCode).withOpacity(0.1)
              : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? getAgentColor(agent.id.hashCode)
                : AppConstants.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AgentAvatar(agent: agent, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    agent.type.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: getAgentColor(agent.id.hashCode)),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: agent.isActive,
                onChanged: (_) {
                  // Toggle handled by parent
                },
                activeColor: AppConstants.successColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Agent config card widget
class AgentConfigCard extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const AgentConfigCard({
    super.key,
    required this.agent,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AgentAvatar(agent: agent, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        agent.type.toUpperCase(),
                        style: TextStyle(
                          color: getAgentColor(agent.id.hashCode),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              agent.description.isNotEmpty
                  ? agent.description
                  : 'No description',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppConstants.textSecondary),
            ),
            if (agent.systemPrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'System Prompt',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  agent.systemPrompt,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppConstants.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ...agent.capabilities.map(
                  (cap) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cap,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                  ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppConstants.errorColor,
                    ),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
