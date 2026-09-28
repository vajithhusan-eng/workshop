import 'package:flutter/material.dart';

import '../utils/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppConstants.surfaceColor,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppConstants.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Story App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Multi-AI Agent Orchestrator',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'v1.0.0',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  label: 'Home',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.chat,
                  label: 'Chat',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/chat');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.auto_stories,
                  label: 'Sessions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.robotics,
                  label: 'Agents',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/agents');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),
          ),

          // Connection status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppConstants.borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppConstants.successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.successColor,
                  ),
                ),
                const Spacer(),
                Text(
                  'v${AppConstants.appVersion}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppConstants.primaryColor),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      hoverColor: AppConstants.primaryColor.withOpacity(0.05),
    );
  }
}
