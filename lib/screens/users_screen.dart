import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_api_client.dart';
import '../state/app_state.dart';

/// Oracle user management: list users and add new ones via the admin API.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _loading = false;
  String? _error;
  Map<String, Object?> _status = const {};
  List<String> _users = const [];

  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _pbkdf2 = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final client = context.read<AppState>().client;
    if (client == null) {
      setState(() => _error = 'Not connected.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await client.oracleStatus();
      final users = (status['enabled'] == true)
          ? await client.oracleUsers()
          : <String>[];
      if (!mounted) return;
      setState(() {
        _status = status;
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addUser() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final user = _username.text.trim();
    final pwd = _password.text;
    if (user.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Username and password are required.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final users = await client.addOracleUser(user, pwd, pbkdf2: _pbkdf2);
      if (!mounted) return;
      setState(() {
        _users = users;
        _adding = false;
        _username.clear();
        _password.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added user $user')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AdminApiException ? e.message : e.toString();
        _adding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status['enabled'] == true;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Users', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              if (enabled)
                Text('Oracle wire :${_status['port']}  ·  '
                    '${_status['connections']} conn',
                    style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const Divider(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (!_loading && !enabled)
            const Expanded(
              child: Center(
                child: Text(
                  'Oracle wire is not enabled on this server.\n'
                  'Start it with --oracle-port to manage users.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            _addForm(context),
            const SizedBox(height: 12),
            Expanded(child: _userList(context)),
          ],
        ],
      ),
    );
  }

  Widget _addForm(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                        labelText: 'Username', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _adding ? null : _addUser,
                  icon: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add),
                  label: const Text('Add user'),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _pbkdf2,
                  onChanged: (v) => setState(() => _pbkdf2 = v ?? true),
                ),
                const Text('12c PBKDF2 verifier (needed by most drivers)'),
              ],
            ),
            Text(
              'Passwords are sent to the server; use a bearer token + TLS for '
              'remote servers.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _userList(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) {
      return const Center(child: Text('No users registered.'));
    }
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, i) => ListTile(
        dense: true,
        leading: const Icon(Icons.person_outline),
        title: Text(_users[i]),
      ),
    );
  }
}
