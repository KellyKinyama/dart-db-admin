import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Status dashboard: live metric tiles + raw status/info, with auto-refresh.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool _loading = false;
  bool _auto = false;
  Timer? _timer;
  String? _error;

  Map<String, Object?> _status = const {};
  Map<String, Object?> _metrics = const {};
  Map<String, Object?> _stats = const {};
  Map<String, Object?> _sessions = const {};
  final List<double> _lsnHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleAuto(bool on) {
    setState(() => _auto = on);
    _timer?.cancel();
    if (on) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
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
      final results = await Future.wait([
        client.status(),
        client.metrics(),
        client.stats(),
        client.sessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0];
        _metrics = results[1];
        _stats = results[2];
        _sessions = results[3];
        final lsn = (_status['log_last_lsn'] as num?)?.toDouble() ?? 0;
        _lsnHistory.add(lsn);
        if (_lsnHistory.length > 60) _lsnHistory.removeAt(0);
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

  @override
  Widget build(BuildContext context) {
    final info = context.watch<AppState>().info;
    const encoder = JsonEncoder.withIndent('  ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Status', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const Text('Auto-refresh'),
              Switch(value: _auto, onChanged: _toggleAuto),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh now',
              ),
            ],
          ),
          const Divider(),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Expanded(
            child: ListView(
              children: [
                _tiles(context),
                const SizedBox(height: 16),
                _LsnChart(samples: _lsnHistory),
                const SizedBox(height: 16),
                _Section(title: 'HA status', body: encoder.convert(_status)),
                const SizedBox(height: 12),
                _Section(title: 'Engine info', body: encoder.convert(info)),
                const SizedBox(height: 12),
                _Section(title: 'Metrics', body: encoder.convert(_metrics)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles(BuildContext context) {
    String fmtUptime(Object? ms) {
      final v = (ms as num?)?.toInt() ?? 0;
      final s = v ~/ 1000;
      final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
      return h > 0 ? '${h}h ${m}m' : (m > 0 ? '${m}m ${sec}s' : '${sec}s');
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Tile(label: 'Role', value: '${_status['role'] ?? '—'}', icon: Icons.account_tree),
        _Tile(label: 'Uptime', value: fmtUptime(_metrics['uptimeMs']), icon: Icons.timer_outlined),
        _Tile(label: 'Requests', value: '${_metrics['requests'] ?? 0}', icon: Icons.swap_vert),
        _Tile(label: 'Tables', value: '${_stats['tableCount'] ?? 0}', icon: Icons.table_chart_outlined),
        _Tile(label: 'Views', value: '${_stats['viewCount'] ?? 0}', icon: Icons.visibility_outlined),
        _Tile(label: 'Native conns', value: '${_sessions['nativeConnections'] ?? 0}', icon: Icons.cable),
        _Tile(label: 'Event subs', value: '${_sessions['eventSubscribers'] ?? 0}', icon: Icons.bolt),
        _Tile(label: 'LSN', value: '${_status['log_last_lsn'] ?? 0}', icon: Icons.numbers),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            body,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// A compact line chart of recent `log_last_lsn` samples.
class _LsnChart extends StatelessWidget {
  const _LsnChart({required this.samples});

  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = samples.isEmpty ? 0.0 : samples.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Log LSN trend', style: theme.textTheme.labelLarge),
            const Spacer(),
            Text('current: ${last.toInt()}', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 80,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: samples.length < 2
              ? Center(
                  child: Text('Collecting samples…  (enable auto-refresh)',
                      style: theme.textTheme.bodySmall),
                )
              : CustomPaint(
                  painter: _SparklinePainter(
                    samples: samples,
                    color: theme.colorScheme.primary,
                  ),
                  size: Size.infinite,
                ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = samples.reduce((a, b) => a < b ? a : b);
    final maxV = samples.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final dx = size.width / (samples.length - 1);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = dx * i;
      final y = size.height - ((samples[i] - minV) / range) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.samples != samples;
}