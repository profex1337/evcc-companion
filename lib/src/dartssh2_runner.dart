import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_runner.dart';

/// Real [SshRunner] backed by dartssh2 (pure-Dart SSH, password auth).
///
/// Thin I/O adapter: no parsing or business logic lives here (that is in the
/// unit-tested pure layer). Exercised end-to-end by the manual dry-run against
/// the real Pi (see README).
class Dartssh2Runner implements SshRunner {
  final SshConfig config;
  SSHClient? _client;

  Dartssh2Runner(this.config);

  @override
  Future<void> connect() async {
    // SSHSocket.connect's timeout only bounds the TCP handshake, so bound the
    // auth handshake separately — otherwise a host that accepts TCP but stalls
    // during key-exchange/auth would hang forever.
    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: config.timeout,
    );
    final client = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: () => config.password,
    );
    try {
      // Force authentication now so wrong-password errors surface here.
      await client.authenticated.timeout(config.timeout);
    } catch (_) {
      client.close();
      rethrow;
    }
    _client = client;
  }

  @override
  Future<CommandResult> run(
    String command, {
    String? stdin,
    void Function(String chunk)? onOutput,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('connect() must be called before run()');
    }

    final session = await client.execute(command);

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    // Drain both streams to completion. asFuture() resolves on the stream's
    // onDone, which dartssh2 fires only after all channel data is delivered —
    // so no trailing chunk (e.g. a short version string) can be lost. Awaiting
    // the streams (rather than session.done + cancel) is what guarantees this.
    final outDone = session.stdout.listen((data) {
      final s = utf8.decode(data, allowMalformed: true);
      stdoutBuf.write(s);
      onOutput?.call(s);
    }).asFuture<void>();
    final errDone = session.stderr.listen((data) {
      final s = utf8.decode(data, allowMalformed: true);
      stderrBuf.write(s);
      onOutput?.call(s);
    }).asFuture<void>();

    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode(stdin)));
    }
    await session.stdin.close();

    try {
      await Future.wait([outDone, errDone]).timeout(config.commandTimeout);
    } on TimeoutException {
      session.close();
      rethrow;
    }

    return CommandResult(
      exitCode: session.exitCode,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
    );
  }

  @override
  Future<void> close() async {
    _client?.close();
    _client = null;
  }
}
