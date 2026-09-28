import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

// Agent State
class AgentState {
  final List<AgentModel> agents;
  final AgentModel? selectedAgent;
  final bool isLoading;
  final String? error;

  const AgentState({
    this.agents = const [],
    this.selectedAgent,
    this.isLoading = false,
    this.error,
  });

  AgentState copyWith({
    List<AgentModel>? agents,
    AgentModel? selectedAgent,
    bool? isLoading,
    String? error,
  }) {
    return AgentState(
      agents: agents ?? this.agents,
      selectedAgent: selectedAgent ?? this.selectedAgent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final agentProvider = StateNotifierProvider<AgentNotifier, AgentState>(
  (ref) => AgentNotifier(ref.read(storageServiceProvider)),
);

class AgentNotifier extends StateNotifier<AgentState> {
  final StorageService _storageService;

  AgentNotifier(this._storageService) : super(const AgentState()) {
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    state = state.copyWith(isLoading: true);
    try {
      final agents = await _storageService.getAgents();
      state = state.copyWith(agents: agents, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load agents', isLoading: false);
    }
  }

  Future<void> addAgent(AgentModel agent) async {
    final agents = [...state.agents, agent];
    agents.sort((a, b) => a.order.compareTo(b.order));
    await _storageService.saveAgents(agents);
    state = state.copyWith(agents: agents);
  }

  Future<void> updateAgent(AgentModel agent) async {
    final agents = state.agents.map((a) {
      if (a.id == agent.id) return agent;
      return a;
    }).toList();
    await _storageService.saveAgents(agents);
    state = state.copyWith(agents: agents);
  }

  void removeAgent(String agentId) async {
    final agents = state.agents.where((a) => a.id != agentId).toList();
    await _storageService.saveAgents(agents);
    state = state.copyWith(
      agents: agents,
      selectedAgent: state.selectedAgent?.id == agentId
          ? null
          : state.selectedAgent,
    );
  }

  void selectAgent(String? agentId) {
    final agent = agentId != null
        ? state.agents.firstWhere(
            (a) => a.id == agentId,
            orElse: () => state.agents.first,
          )
        : null;
    state = state.copyWith(selectedAgent: agent);
  }

  void toggleAgentActive(String agentId) {
    final agents = state.agents.map((a) {
      if (a.id == agentId) {
        return a.copyWith(isActive: !a.isActive);
      }
      return a;
    }).toList();
    _storageService.saveAgents(agents);
    state = state.copyWith(agents: agents);
  }

  void reorderAgents(List<String> agentIds) {
    final agents = agentIds.asMap().entries.map((entry) {
      return state.agents
          .firstWhere((a) => a.id == entry.value)
          .copyWith(order: entry.key);
    }).toList();
    agents.sort((a, b) => a.order.compareTo(b.order));
    _storageService.saveAgents(agents);
    state = state.copyWith(agents: agents);
  }

  List<AgentModel> get activeAgents =>
      state.agents.where((a) => a.isActive).toList();

  List<AgentModel> get agentsByType {
    final grouped = <String, List<AgentModel>>{};
    for (final agent in state.agents) {
      grouped.putIfAbsent(agent.type, () => []);
      grouped[agent.type]!.add(agent);
    }
    return state.agents;
  }
}

// Selected agent provider
final selectedAgentProvider = Provider<AgentModel?>((ref) {
  return ref.watch(agentProvider).selectedAgent;
});

final agentsListProvider = Provider<List<AgentModel>>((ref) {
  return ref.watch(agentProvider).agents;
});
