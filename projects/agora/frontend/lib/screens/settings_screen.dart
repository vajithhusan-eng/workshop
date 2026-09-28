import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_model.dart';
import '../providers/agent_provider.dart';
import '../widgets/agent_avatar.dart';
import '../widgets/agent_config_card.dart';
import '../widgets/app_drawer.dart';
import '../utils/constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late List<AgentModel> _localAgents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _localAgents = ref.read(agentsListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsListProvider);
    final isLoading = ref.watch(agentProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAgentDialog(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : agents.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return AgentConfigCard(
                  agent: agent,
                  onEdit: () => _showEditAgentDialog(context, agent),
                  onRemove: () => _confirmRemoveAgent(agent),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.robotics,
            size: 80,
            color: AppConstants.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Agents Configured',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppConstants.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add agents to configure your multi-agent orchestrator',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppConstants.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddAgentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Agent'),
          ),
        ],
      ),
    );
  }

  void _showAddAgentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final systemPromptController = TextEditingController();
    AgentModel selectedType = AgentModel.create(
      name: 'New Agent',
      type: AppConstants.agentTypePlanner,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Agent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Agent Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType.type,
                  decoration: const InputDecoration(labelText: 'Agent Type'),
                  items:
                      [
                        AppConstants.agentTypePlanner,
                        AppConstants.agentTypeWriter,
                        AppConstants.agentTypeEditor,
                        AppConstants.agentTypeReviewer,
                        AppConstants.agentTypeIllustrator,
                      ].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = selectedType.copyWith(type: value!);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: systemPromptController,
                  decoration: const InputDecoration(labelText: 'System Prompt'),
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 8),
                Text(
                  'Capabilities: ${selectedType.type.toUpperCase()}, Auto-Planning',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameController.text.trim().isNotEmpty
                  ? () {
                      final agent = AgentModel.create(
                        name: nameController.text.trim(),
                        type: selectedType.type,
                        description: descController.text.trim(),
                        systemPrompt: systemPromptController.text.trim(),
                        capabilities: [
                          selectedType.type.toUpperCase(),
                          'Auto-Planning',
                        ],
                      );
                      ref.read(agentProvider.notifier).addAgent(agent);
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAgentDialog(BuildContext context, AgentModel agent) {
    final nameController = TextEditingController(text: agent.name);
    final descController = TextEditingController(text: agent.description);
    final systemPromptController = TextEditingController(
      text: agent.systemPrompt,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Agent Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: systemPromptController,
                decoration: const InputDecoration(labelText: 'System Prompt'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = agent.copyWith(
                name: nameController.text.trim(),
                description: descController.text.trim(),
                systemPrompt: systemPromptController.text.trim(),
              );
              ref.read(agentProvider.notifier).updateAgent(updated);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveAgent(AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Agent'),
        content: Text('Are you sure you want to remove "${agent.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(agentProvider.notifier).removeAgent(agent.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
