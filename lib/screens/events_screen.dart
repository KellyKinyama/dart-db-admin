import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../state/app_state.dart';

/// Live event stream viewer backed by the admin API's WebSocket `/api/events`.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  WebSocketChannel? _channel;
  final List<_Event> _events = [];
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _connect() {
    final conn = context.read<AppState>().active;
    if (conn == null) {
      setState(() => _error = 'Not connected. Open the Connect tab first.');
      return;
    }
    _disconnect();
    try {
      final channel = WebSocketChannel.connect(Uri.parse(conn.wsUrl));
      _channel = channel;
      setState(() {
        _connected = true;
        _error = null;
      });
      channel.stream.listen(
        (data) {
          setState(() {
            _events.insert(0, _Event.parse('$data'));
            if (_events.length > 500) _events.removeLast();
          });
        },
        onDone: () => mounted ? setState(() => _connected = false) : null,
        onError: (e) =>
            mounted ? setState(() => _error = '$e') : null,
        cancelOnError: true,
      );
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (mounted) setState(() => _connected = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Events', style: theme.textTheme.titleLarge),
              const SizedBox(width: 12),
              Icon(Icons.circle,
                  size: 10,
                  color: _connected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(_connected ? 'streaming' : 'disconnected',
                  style: theme.textTheme.bodySmall),
              const Spacer(),
              if (_events.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(_events.clear),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                ),
              IconButton(
                tooltip: _connected ? 'Disconnect' : 'Reconnect',
                icon: Icon(_connected ? Icons.stop : Icons.play_arrow),
                onPressed: _connected ? _disconnect : _connect,
              ),
            ],
          ),
          const Divider(),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          Expanded(
            child: _events.isEmpty
                ? const Center(child: Text('Waiting for events…'))
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      return ListTile(
                        dense: true,
                        leading: _TypeChip(type: e.type),
                        title: Text(e.summary,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Event {
  _Event(this.type, this.summary);

  final String type;
  final String summary;

  factory _Event.parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        final type = json['type']?.toString() ?? 'event';
        final rest = Map<String, Object?>.from(json)..remove('type');
        return _Event(type, jsonEncode(rest));
      }
    } catch (_) {}
    return _Event('raw', raw);
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'heartbeat' => Colors.blue,
      'request' => Colors.green,
      'hello' => Colors.purple,
      _ => Colors.grey,
    };
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(type,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
