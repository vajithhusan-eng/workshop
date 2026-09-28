import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_model.dart';
import '../providers/session_provider.dart';
import '../providers/websocket_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/session_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ref.read(sessionProvider.notifier);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsListProvider);
    final isLoading = ref.watch(isSessionLoadingProvider);
    final websocketState = ref.watch(websocketStateProvider);

    final filteredSessions = sessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-AI Agent Orchestrator'),
        centerTitle: false,
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: websocketState.isConnected
                  ? AppConstants.successColor.withOpacity(0.15)
                  : AppConstants.errorColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  websocketState.isConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: websocketState.isConnected
                        ? AppConstants.successColor
                        : AppConstants.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshSessions(),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'Search sessions...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Session list
            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (filteredSessions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 64,
                        color: AppConstants.primaryColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No sessions yet'
                            : 'No results found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppConstants.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to create a new session',
                        style: TextStyle(
                          color: AppConstants.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    return SessionCard(
                      session: session,
                      isSelected:
                          ref.watch(selectedSessionProvider)?.id == session.id,
                      onTap: () {
                        ref
                            .read(sessionProvider.notifier)
                            .selectSession(session.id);
                        Navigator.pushNamed(context, '/chat');
                      },
                      onEdit: () {
                        Navigator.pushNamed(context, '/session/${session.id}');
                      },
                      onDelete: () {
                        _deleteSession(session);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSession(),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Future<void> _refreshSessions() async {
    await ref.read(sessionProvider.notifier)._loadSessions();
    if (mounted) {
      setState(() {});
    }
  }

  void _createSession() {
    showDialog(context: context, builder: (context) => _CreateSessionDialog());
  }

  void _deleteSession(SessionModel session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(sessionProvider.notifier).deleteSession(session.id);
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

class _CreateSessionDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateSessionDialog> createState() =>
      _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<_CreateSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Session Title',
                hintText: 'Enter a title for your session',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
              ),
              maxLines: 2,
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
            if (_formKey.currentState?.validate() ?? false) {
              ref
                  .read(sessionProvider.notifier)
                  .createSession(
                    _titleController.text,
                    description: _descriptionController.text,
                  );
              Navigator.pop(context);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
