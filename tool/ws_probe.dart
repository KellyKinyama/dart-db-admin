import 'dart:async';
import 'dart:io';

/// Connects to the admin API event stream, triggers a request, and prints
/// every event received for a few seconds (expects hello + request + heartbeat).
Future<void> main() async {
  final ws = await WebSocket.connect('ws://127.0.0.1:8088/api/events');
  stdout.writeln('connected to /api/events');
  ws.listen((msg) => stdout.writeln('event: $msg'));

  // Trigger a 'request' broadcast.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('http://127.0.0.1:8088/api/health'));
  final resp = await req.close();
  await resp.drain<void>();
  client.close();

  // Wait long enough to catch at least one 5s heartbeat.
  await Future<void>.delayed(const Duration(seconds: 6));
  await ws.close();
  stdout.writeln('done');
}
