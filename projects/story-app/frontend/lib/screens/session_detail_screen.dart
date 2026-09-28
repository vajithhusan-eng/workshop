import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_model.dart';
import '../models/agent_model.dart';
import '../providers/session_provider.dart';
import '../providers/agent_provider.dart';
import '../utils/constants.dart';
import '../widgets/agent_avatar.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  late SessionModel _session;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = ref.read(selectedSessionProvider);
    if (session == null && ref.watch(sessionsListProvider).isNotEmpty) {
      _session = ref.watch(sessionsListProvider).first;
    } else {
      _session = session!;
    }
    _titleController.text = _session.title;
    _descriptionController.text = _session.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsListProvider);
    final sessionAgents = agents
        .where((a) => _session.agentIds.contains(a.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.title),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveSession(),
            tooltip: 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info section
            const Text(
              'Session Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: InputBorder.none,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_session.status)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _session.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(_session.status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_session.agentIds.length} agents',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Agents section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agents (${_session.agentIds.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddAgentDialog(context, agents),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Agent'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (sessionAgents.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No agents added yet. Tap "Add Agent" to get started.',
                    style: TextStyle(
                      color: AppConstants.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessionAgents.length,
                itemBuilder: (context, index) {
                  final agent = sessionAgents[index];
                  return Card(
                    child: ListTile(
                      leading: AgentAvatar(agent: agent, size: 40),
                      title: Text(agent.name),
                      subtitle: Text(agent.type.toUpperCase()),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: AppConstants.errorColor,
                        ),
                        onPressed: () => _removeAgentFromSession(agent.id),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // Session metadata
            const Text(
              'Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('ID', _session.id),
                    const Divider(height: 24),
                    _buildDetailRow('Created', _session.createdAt.toString()),
                    const Divider(height: 24),
                    _buildDetailRow('Updated', _session.updatedAt.toString()),
                    if (_session.createdBy != null) ...[
                      const Divider(height: 24),
                      _buildDetailRow('Created By', _session.createdBy!),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Danger zone
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _deleteSession(context),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppConstants.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusActive:
        return AppConstants.successColor;
      case AppConstants.statusCompleted:
        return AppConstants.infoColor;
      case AppConstants.statusArchived:
        return AppConstants.textSecondary;
      default:
        return AppConstants.warningColor;
    }
  }

  void _saveSession() {
    ref
        .read(sessionProvider.notifier)
        .updateSession(
          _session.id,
          _titleController.text,
          description: _descriptionController.text,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session saved successfully!')),
    );
  }

  void _showAddAgentDialog(BuildContext context, List<AgentModel> allAgents) {
    final existingAgentIds = Set<String>.from(_session.agentIds);
    final availableAgents = allAgents
        .where((a) => !existingAgentIds.contains(a.id))
        .toList();

    if (availableAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All agents have been added')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search agents...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: availableAgents.length,
                itemBuilder: (context, index) {
                  final agent = availableAgents[index];
                  return ListTile(
                    leading: AgentAvatar(agent: agent, size: 40),
                    title: Text(agent.name),
                    subtitle: Text(agent.type.toUpperCase()),
                    trailing: const Icon(
                      Icons.add_circle,
                      color: AppConstants.primaryColor,
                    ),
                    onTap: () {
                      ref
                          .read(sessionProvider.notifier)
                          .addAgentToSession(_session.id, agent.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeAgentFromSession(String agentId) {
    ref
        .read(sessionProvider.notifier)
        .removeAgentFromSession(_session.id, agentId);
  }

  void _deleteSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'Are you sure you want to delete this session? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(sessionProvider.notifier).deleteSession(_session.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
