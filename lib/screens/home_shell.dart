import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'api_probe_screen.dart';
import 'connect_screen.dart';
import 'events_screen.dart';
import 'schema_screen.dart';
import 'sql_console_screen.dart';
import 'status_screen.dart';
import 'vector_screen.dart';

/// Top-level shell with a NavigationRail and a connection badge.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
  ];

  static const _destinations = [
    (icon: Icons.cable, label: 'Connect'),
    (icon: Icons.terminal, label: 'SQL'),
    (icon: Icons.schema, label: 'Schema'),
    (icon: Icons.scatter_plot, label: 'Vector'),
    (icon: Icons.api, label: 'API Probe'),
    (icon: Icons.bolt, label: 'Events'),
    (icon: Icons.monitor_heart, label: 'Status'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final body = switch (_index) {
      0 => const ConnectScreen(),
      1 => const SqlConsoleScreen(),
      2 => const SchemaScreen(),
      3 => const VectorScreen(),
      4 => const ApiProbeScreen(),
      5 => const EventsScreen(),
      6 => const StatusScreen(),
      _ => const SizedBox.shrink(),
    };

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < _destinations.length; i++)
          SingleActivator(_digitKeys[i], control: true):
              () => setState(() => _index = i),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            state.cycleTheme,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Icon(Icons.dns, size: 28),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IconButton(
                        tooltip: 'Theme (Ctrl+D): ${state.themeMode.name}',
                        icon: Icon(switch (state.themeMode) {
                          ThemeMode.light => Icons.light_mode,
                          ThemeMode.dark => Icons.dark_mode,
                          ThemeMode.system => Icons.brightness_auto,
                        }),
                        onPressed: state.cycleTheme,
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _ConnectionTabs(state: state),
                    const Divider(height: 1),
                    // Re-create the screen when the active session changes so it
                    // re-fetches against the newly selected connection.
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey(state.activeSessionId ?? 'none'),
                        child: body,
                      ),
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
}

class _ConnectionTabs extends StatelessWidget {
  const _ConnectionTabs({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Colors.grey),
            const SizedBox(width: 8),
            const Text('Not connected',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('Open the Connect tab to add a server',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in state.sessions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: _SessionChip(
                label: s.connection.name,
                subtitle: '${s.connection.host}:${s.connection.port}',
                selected: s.id == state.activeSessionId,
                onTap: () => state.setActiveSession(s.id),
                onClose: () => state.closeSession(s.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 9, color: Colors.green),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
