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
                          subtitle: Text(conn.endpointLabel),
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
                                  onPressed: () => _connect(context, conn),
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

  /// Connects [conn], prompting for the Oracle password when it isn't held.
  Future<void> _connect(BuildContext context, ServerConnection conn) async {
    final state = context.read<AppState>();
    var target = conn;
    if (conn.isOracle && (conn.password == null || conn.password!.isEmpty)) {
      final pwd = await _promptPassword(context, conn);
      if (pwd == null) return;
      target = conn.copyWith(password: pwd);
    }
    await state.connect(target);
  }

  Future<String?> _promptPassword(
      BuildContext context, ServerConnection conn) async {
    final controller = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Password for ${conn.user}@${conn.oracleConnectString}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Oracle password'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pwd;
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
  late final TextEditingController _service;
  late final TextEditingController _user;
  late final TextEditingController _password;
  ConnectionKind _kind = ConnectionKind.adminHttp;
  bool _useTls = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? ConnectionKind.adminHttp;
    _name = TextEditingController(text: e?.name ?? 'local');
    _host = TextEditingController(text: e?.host ?? '127.0.0.1');
    _port = TextEditingController(
        text: '${e?.port ?? (_kind == ConnectionKind.oracleWire ? 1521 : 8088)}');
    _token = TextEditingController(text: e?.token ?? '');
    _service = TextEditingController(text: e?.service ?? 'DARTDB');
    _user = TextEditingController(text: e?.user ?? 'admin');
    _password = TextEditingController(text: e?.password ?? '');
    _useTls = e?.useTls ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _token.dispose();
    _service.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oracle = _kind == ConnectionKind.oracleWire;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New connection' : 'Edit connection'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<ConnectionKind>(
                segments: const [
                  ButtonSegment(
                      value: ConnectionKind.adminHttp,
                      label: Text('Admin API'),
                      icon: Icon(Icons.http)),
                  ButtonSegment(
                      value: ConnectionKind.oracleWire,
                      label: Text('Oracle wire'),
                      icon: Icon(Icons.storage)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) {
                  setState(() {
                    _kind = s.first;
                    final p = int.tryParse(_port.text.trim());
                    if (p == null || p == 1521 || p == 8088) {
                      _port.text = _kind == ConnectionKind.oracleWire
                          ? '1521'
                          : '8088';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
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
                decoration: InputDecoration(
                    labelText: oracle ? 'Oracle port' : 'Admin API port'),
              ),
              if (!oracle) ...[
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
              ] else ...[
                TextField(
                  controller: _service,
                  decoration: const InputDecoration(labelText: 'Service name'),
                ),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: 'User'),
                ),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (not saved to disk)',
                  ),
                ),
              ],
            ],
          ),
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
    final oracle = _kind == ConnectionKind.oracleWire;
    final port =
        int.tryParse(_port.text.trim()) ?? (oracle ? 1521 : 8088);
    final token = _token.text.trim();
    Navigator.of(context).pop(
      ServerConnection(
        name: _name.text.trim().isEmpty ? 'unnamed' : _name.text.trim(),
        host: _host.text.trim().isEmpty ? '127.0.0.1' : _host.text.trim(),
        port: port,
        kind: _kind,
        token: token.isEmpty ? null : token,
        useTls: _useTls,
        service: oracle ? _service.text.trim() : null,
        user: oracle ? _user.text.trim() : null,
        password: oracle && _password.text.isNotEmpty ? _password.text : null,
      ),
    );
  }
}
