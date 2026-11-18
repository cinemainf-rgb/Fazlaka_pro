import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class MikroTikApi {
  Socket? socket;
  List<int> buf = [];

  Future<List>> run(
    String host,
    String user,
    String pass,
    String cmd, [
    List<String> args = const [],
  ]) async {
    try {
      return await runLogin(host, user, pass, cmd, args, true);
    } catch (_) {
      return await runLogin(host, user, pass, cmd, args, false);
    }
  }

  Future<List>> runLogin(
    String host,
    String user,
    String pass,
    String cmd,
    List<String> args,
    bool useChallenge,
  ) async {
    buf = [];
    try {
      socket = await Socket.connect(host, 8728, timeout: const Duration(seconds: 8));
      socket!.listen((d) {
        buf.addAll(d);
      });
      if (useChallenge) {
        final chal = await loginStep(user);
        List<int> hexToBytes(String hex) {
          final out = <int>[];
          for (int i = 0; i < hex.length; i += 2) {
            out.add(int.parse(hex.substring(i, i + 2), radix: 16));
          }
          return out;
        }
        final resp = md5.convert([0, ...utf8.encode(pass), ...hexToBytes(chal)]).toString();
        await send(['/login', '=name=$user', '=response=00$resp']);
      } else {
        await send(['/login', '=name=$user', '=password=$pass']);
      }
      final loginRes = await readSentence();
      if (loginRes.any((m) => m['__type__'] == '!trap')) {
        throw Exception('login failed');
      }
      await send([cmd, ...args]);
      final result = await readAll();
      return result;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
      socket = null;
      buf = [];
    }
  }

  Future<String> loginStep(String user) async {
    await send(['/login', '=name=$user']);
    final res = await readSentence();
    for (final m in res) {
      if (m.containsKey('ret')) return m['ret']!;
    }
    throw Exception('no challenge');
  }

  Future<void> send(List<String> words) async {
    final out = <int>[];
    for (final w in words) {
      final b = utf8.encode(w);
      if (b.length < 0x80) {
        out.add(b.length);
      } else if (b.length < 0x4000) {
        out.add(0x80 | (b.length >> 8));
        out.add(b.length & 0xFF);
      } else {
        out.add(0xC0 | (b.length >> 16));
        out.add((b.length >> 8) & 0xFF);
        out.add(b.length & 0xFF);
      }
      out.addAll(b);
    }
    out.add(0);
    socket!.add(out);
    await socket!.flush();
  }

  Future<List>> readSentence() async {
    while (true) {
      final parsed = tryParse();
      if (parsed != null) return parsed;
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<List>> readAll() async {
    final all = >[];
    while (true) {
      final s = await readSentence();
      all.addAll(s);
      if (s.any((m) => m['__type__'] == '!done')) break;
    }
    return all;
  }

  List>? tryParse() {
    int pos = 0;
    final result = >[];
    var cur = <String, String>{};
    while (pos < buf.length) {
      int len = buf[pos];
      pos++;
      if (len == 0) {
        if (cur.isNotEmpty) {
          result.add(cur);
          cur = <String, String>{};
        }
        buf = buf.sublist(pos);
        return result;
      }
      if ((len & 0x80) != 0) {
        if ((len & 0xC0) == 0x80) {
          if (pos >= buf.length) return null;
          len = ((len & 0x3F) << 8) | buf[pos];
          pos++;
        } else if ((len & 0xE0) == 0xC0) {
          if (pos + 1 >= buf.length) return null;
          len = ((len & 0x1F) << 16) | (buf[pos] << 8) | buf[pos + 1];
          pos += 2;
        } else {
          return null;
        }
      }
      if (pos + len > buf.length) return null;
      final word = utf8.decode(buf.sublist(pos, pos + len), allowMalformed: true);
      pos += len;
      if (word.startsWith('!')) {
        if (cur.isNotEmpty) {
          result.add(cur);
          cur = <String, String>{};
        }
        cur['__type__'] = word;
      } else if (word.startsWith('=')) {
        final eq = word.indexOf('=', 1);
        if (eq > 0) {
          cur[word.substring(1, eq)] = word.substring(eq + 1);
        }
      }
    }
    return null;
  }
}

String quotaFor(String p) {
  if (p == '20') return '2';
  if (p == '50') return '8';
  if (p == '100') return '20';
  if (p == '200') return '45';
  return '2';
}

int daysForProfile(String p) {
  if (p == '20') return 3;
  if (p == '50') return 15;
  if (p == '100') return 30;
  if (p == '200') return 30;
  return 30;
}

String bytesFor(String p) {
  if (p == '20') return '2147483648';
  if (p == '50') return '8589934592';
  if (p == '100') return '21474836480';
  if (p == '200') return '48318382080';
  return '2147483648';
}
