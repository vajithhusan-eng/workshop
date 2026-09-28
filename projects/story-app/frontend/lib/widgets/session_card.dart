import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/session_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const SessionCard({
    super.key,
    required this.session,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: onEdit,
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: onDelete,
            backgroundColor: AppConstants.errorColor,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primaryColor.withOpacity(0.1)
                : AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppConstants.primaryColor
                  : AppConstants.borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.description.isNotEmpty
                          ? session.description
                          : 'No description',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppConstants.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip(),
                        const SizedBox(width: 8),
                        Text(
                          '${session.agentIds.length} agents',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppConstants.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Helpers.formatRelativeTime(session.updatedAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isSelected
            ? AppConstants.primaryColor
            : AppConstants.secondaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.auto_stories,
        color: isSelected ? Colors.white : AppConstants.primaryColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusChip() {
    Color statusColor;
    switch (session.status) {
      case AppConstants.statusActive:
        statusColor = AppConstants.successColor;
        break;
      case AppConstants.statusCompleted:
        statusColor = AppConstants.infoColor;
        break;
      case AppConstants.statusArchived:
        statusColor = AppConstants.textSecondary;
        break;
      default:
        statusColor = AppConstants.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        session.status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }
}
