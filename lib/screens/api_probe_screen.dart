import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_api_client.dart';
import '../state/app_state.dart';

/// API Probe: discover admin endpoints, fire requests, and view raw responses.
class ApiProbeScreen extends StatefulWidget {
  const ApiProbeScreen({super.key});

  @override
  State<ApiProbeScreen> createState() => _ApiProbeScreenState();
}

class _ApiProbeScreenState extends State<ApiProbeScreen> {
  final _methodCtrl = TextEditingController(text: 'GET');
  final _pathCtrl = TextEditingController(text: '/api/health');
  final _bodyCtrl = TextEditingController();

  List<ApiRoute> _routes = const [];
  bool _loadingRoutes = false;
  bool _sending = false;
  ProbeResult? _result;

  static const _methods = ['GET', 'POST', 'OPTIONS'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoutes());
  }

  @override
  void dispose() {
    _methodCtrl.dispose();
    _pathCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    setState(() => _loadingRoutes = true);
    try {
      final routes = await client.routes();
      if (!mounted) return;
      setState(() => _routes = routes);
    } catch (_) {
      // Discovery is best-effort; manual entry still works.
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  void _selectRoute(ApiRoute route) {
    setState(() {
      _methodCtrl.text = route.method;
      _pathCtrl.text = route.path;
      _bodyCtrl.text = route.sampleBody == null
          ? ''
          : const JsonEncoder.withIndent('  ').convert(route.sampleBody);
    });
  }

  Future<void> _send() async {
    final client = context.read<AppState>().client;
    if (client == null) {
      setState(() => _result = ProbeResult(
            statusCode: 0,
            elapsedMs: 0,
            body: '',
            error: 'Not connected. Open the Connect tab first.',
          ));
      return;
    }
    setState(() => _sending = true);
    final result = await client.probe(
      _methodCtrl.text.trim(),
      _pathCtrl.text.trim(),
      body: _bodyCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<AppState>().isConnected;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: _routeList(context)),
          const VerticalDivider(),
          Expanded(child: _requestPanel(context, connected)),
        ],
      ),
    );
  }

  Widget _routeList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Endpoints', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: _loadingRoutes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Reload /api/routes',
              onPressed: _loadingRoutes ? null : _loadRoutes,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _routes.isEmpty
              ? const Center(child: Text('No routes loaded.'))
              : ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (context, i) {
                    final r = _routes[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        dense: true,
                        leading: _MethodChip(method: r.method),
                        title: Text(r.path,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)),
                        subtitle: r.description == null
                            ? null
                            : Text(r.description!,
                                style: const TextStyle(fontSize: 11)),
                        onTap: () => _selectRoute(r),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _requestPanel(BuildContext context, bool connected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                initialValue: _methods.contains(_methodCtrl.text)
                    ? _methodCtrl.text
                    : 'GET',
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final m in _methods)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _methodCtrl.text = v ?? 'GET'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Path',
                  hintText: '/api/health',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: connected && !_sending ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Request body (JSON, for POST)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        Expanded(child: _responseView(context)),
      ],
    );
  }

  Widget _responseView(BuildContext context) {
    final result = _result;
    if (result == null) {
      return const Center(child: Text('Send a request to see the response.'));
    }
    final theme = Theme.of(context);
    final color = result.ok
        ? Colors.green
        : (result.error != null ? theme.colorScheme.error : Colors.orange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              result.error != null
                  ? 'ERROR'
                  : 'HTTP ${result.statusCode}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 16),
            Text('${result.elapsedMs} ms', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(
              result.error ?? _pretty(result.body),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  String _pretty(String body) {
    if (body.isEmpty) return '(empty response)';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final color = switch (method.toUpperCase()) {
      'GET' => Colors.blue,
      'POST' => Colors.green,
      'DELETE' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
