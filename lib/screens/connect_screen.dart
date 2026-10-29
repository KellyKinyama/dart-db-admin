import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection.dart';
import '../state/app_state.dart';

/// Connection manager: list saved endpoints, add/edit, and connect.
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Connections', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openEditor(context, null),
                icon: const Icon(Icons.add),
                label: const Text('New connection'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                state.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(),
          Expanded(
            child: state.connections.isEmpty
                ? const Center(
                    child: Text('No connections yet. Add one to get started.'),
                  )
                : ListView.builder(
                    itemCount: state.connections.length,
                    itemBuilder: (context, i) {
                      final conn = state.connections[i];
                      final open = state.isOpen(conn);
                      final active = state.active?.name == conn.name;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            open ? Icons.link : Icons.storage,
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : (open ? Colors.green : null),
                          ),
                          title: Text(conn.name),
                          subtitle: Text(conn.baseUrl),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.connecting && !open)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (open && active)
                                TextButton(
                                  onPressed: state.disconnect,
                                  child: const Text('Disconnect'),
                                )
                              else if (open)
                                TextButton(
                                  onPressed: () => state.connect(conn),
                                  child: const Text('Switch to'),
                                )
                              else
                                FilledButton.tonal(
                                  onPressed: () => state.connect(conn),
                                  child: const Text('Connect'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEditor(context, conn),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => state.removeConnection(conn),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
      BuildContext context, ServerConnection? existing) async {
    final result = await showDialog<ServerConnection>(
      context: context,
      builder: (_) => _ConnectionEditor(existing: existing),
    );
    if (result != null && context.mounted) {
      await context.read<AppState>().saveConnection(result);
    }
  }
}

class _ConnectionEditor extends StatefulWidget {
  const _ConnectionEditor({this.existing});

  final ServerConnection? existing;

  @override
  State<_ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<_ConnectionEditor> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _token;
  bool _useTls = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? 'local');
    _host = TextEditingController(text: e?.host ?? '127.0.0.1');
    _port = TextEditingController(text: '${e?.port ?? 8088}');
    _token = TextEditingController(text: e?.token ?? '');
    _useTls = e?.useTls ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New connection' : 'Edit connection'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _host,
              decoration: const InputDecoration(labelText: 'Host'),
            ),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Admin API port'),
            ),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Bearer token (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use TLS (https)'),
              value: _useTls,
              onChanged: (v) => setState(() => _useTls = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final port = int.tryParse(_port.text.trim()) ?? 8088;
    final token = _token.text.trim();
    Navigator.of(context).pop(
      ServerConnection(
        name: _name.text.trim().isEmpty ? 'unnamed' : _name.text.trim(),
        host: _host.text.trim().isEmpty ? '127.0.0.1' : _host.text.trim(),
        port: port,
        token: token.isEmpty ? null : token,
        useTls: _useTls,
      ),
    );
  }
}
