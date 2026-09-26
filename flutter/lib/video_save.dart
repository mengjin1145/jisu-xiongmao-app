import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

const _defaultUa =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

/// 小于该体积时多线程收益被探测/建连开销吃掉，直接单线程更快。
const _minMultiBytes = 4 * 1024 * 1024;

/// 每段至少这么大，避免切太碎。
const _minPartBytes = 1536 * 1024;

/// 把视频下到临时文件并写入系统相册，通过 [onProgress] 回报 0~1。
/// [threads] > 1 时按体积自适应分段并行；过小或不支持 Range 则单线程。
Future<String> downloadVideoToGallery(
  String url, {
  required void Function(double progress) onProgress,
  Map<String, String>? headers,
  int threads = 1,
}) async {
  final merged = _mergeHeaders(url, headers);
  if (threads > 1) {
    try {
      final path = await _downloadMulti(
        url,
        headers: merged,
        maxThreads: threads.clamp(2, 8),
        onProgress: onProgress,
      );
      return await _saveToGallery(path);
    } catch (_) {
      // CDN 不支持 Range / 探测失败等，回退单线程
    }
  }
  final path = await _downloadSingle(url, headers: merged, onProgress: onProgress);
  return await _saveToGallery(path);
}

Map<String, String> _mergeHeaders(String url, Map<String, String>? headers) {
  final out = <String, String>{
    'User-Agent': _defaultUa,
    'Accept': '*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };
  if (headers != null) {
    headers.forEach((key, value) {
      if (value.trim().isNotEmpty) out[key] = value;
    });
  }
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if ((host.contains('bilivideo') || host.contains('bilibili')) && (out['Referer'] ?? '').isEmpty) {
    out['Referer'] = 'https://www.bilibili.com/';
    out['Origin'] = 'https://www.bilibili.com';
  }
  return out;
}

/// 按体积决定线程数：小文件 1，中等 2~4，大文件最高 [maxThreads]。
int adaptiveThreadCount(int totalBytes, int maxThreads) {
  if (totalBytes < _minMultiBytes) return 1;
  final cap = maxThreads.clamp(2, 8);
  final byPart = math.max(2, (totalBytes / _minPartBytes).floor());
  if (totalBytes >= 50 * 1024 * 1024) return math.min(cap, math.max(6, byPart));
  if (totalBytes >= 15 * 1024 * 1024) return math.min(cap, math.max(4, byPart));
  return math.min(4, math.min(cap, byPart));
}

Future<String> _downloadSingle(
  String url, {
  required Map<String, String> headers,
  required void Function(double progress) onProgress,
}) async {
  final client = http.Client();
  IOSink? sink;
  try {
    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(headers);
    final res = await client.send(req).timeout(const Duration(seconds: 45));
    if (res.statusCode >= 400) {
      throw Exception('视频下载失败（${res.statusCode}）');
    }
    final total = res.contentLength ?? 0;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/jsx_${DateTime.now().millisecondsSinceEpoch}.mp4');
    sink = file.openWrite();
    var received = 0;
    var lastTick = DateTime.now();
    await for (final chunk in res.stream) {
      sink.add(chunk);
      received += chunk.length;
      final now = DateTime.now();
      if (now.difference(lastTick).inMilliseconds > 200) {
        lastTick = now;
        onProgress(total > 0 ? (received / total).clamp(0, 1) : 0);
      }
    }
    await sink.flush();
    await sink.close();
    sink = null;
    onProgress(1);
    return file.path;
  } finally {
    await sink?.close();
    client.close();
  }
}

Future<String> _downloadMulti(
  String url, {
  required Map<String, String> headers,
  required int maxThreads,
  required void Function(double progress) onProgress,
}) async {
  // 只发一次 Range:0-0，避免 HEAD + 二次探测拖慢小文件
  final total = await _probeSizeFast(url, headers);
  if (total == null || total <= 0) {
    throw Exception('不支持分段下载');
  }

  final partCount = adaptiveThreadCount(total, maxThreads);
  if (partCount < 2) {
    throw Exception('文件过小，单线程更快');
  }

  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final partSize = (total / partCount).ceil();
  final received = List<int>.filled(partCount, 0);
  var lastTick = DateTime.now();

  void tick() {
    final now = DateTime.now();
    if (now.difference(lastTick).inMilliseconds < 150) return;
    lastTick = now;
    final sum = received.fold<int>(0, (a, b) => a + b);
    onProgress((sum / total).clamp(0, 0.99));
  }

  final parts = <File>[];
  try {
    final futures = <Future<void>>[];
    for (var i = 0; i < partCount; i++) {
      final start = i * partSize;
      if (start >= total) break;
      final end = math.min(total - 1, start + partSize - 1);
      final part = File('${dir.path}/jsx_${stamp}_p$i.bin');
      parts.add(part);
      final idx = i;
      futures.add(() async {
        await _downloadRange(url, headers, start, end, part, (n) {
          received[idx] = n;
          tick();
        });
      }());
    }
    await Future.wait(futures);

    final out = File('${dir.path}/jsx_$stamp.mp4');
    final raf = await out.open(mode: FileMode.write);
    try {
      for (final part in parts) {
        await raf.writeFrom(await part.readAsBytes());
      }
    } finally {
      await raf.close();
    }
    onProgress(1);
    return out.path;
  } finally {
    for (final part in parts) {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
    }
  }
}

Future<void> _downloadRange(
  String url,
  Map<String, String> headers,
  int start,
  int end,
  File part,
  void Function(int received) onChunk,
) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(headers);
    req.headers['Range'] = 'bytes=$start-$end';
    final res = await client.send(req).timeout(const Duration(seconds: 90));
    if (res.statusCode != 206 && res.statusCode != 200) {
      throw Exception('分段失败（${res.statusCode}）');
    }
    if (res.statusCode == 200 && (res.contentLength ?? 0) > (end - start + 1) * 2) {
      throw Exception('服务器未按 Range 响应');
    }
    final sink = part.openWrite();
    var got = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        onChunk(got);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    final expect = end - start + 1;
    if (got < expect && res.statusCode == 206) {
      throw Exception('分段不完整');
    }
  } finally {
    client.close();
  }
}

/// 优先 Range bytes=0-0 一次拿总长（B 站等 CDN 友好）；失败再试 HEAD。
Future<int?> _probeSizeFast(String url, Map<String, String> headers) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(headers);
    req.headers['Range'] = 'bytes=0-0';
    final res = await client.send(req).timeout(const Duration(seconds: 12));
    final cr = res.headers['content-range'] ?? '';
    await res.stream.drain();
    if (res.statusCode == 206) {
      final m = RegExp(r'/(\d+)\s*$').firstMatch(cr);
      if (m != null) return int.tryParse(m.group(1)!);
    }
  } catch (_) {
    // fall through
  } finally {
    client.close();
  }

  final client2 = http.Client();
  try {
    final head = http.Request('HEAD', Uri.parse(url));
    head.headers.addAll(headers);
    final headRes = await client2.send(head).timeout(const Duration(seconds: 12));
    await headRes.stream.drain();
    final len = int.tryParse(headRes.headers['content-length'] ?? '');
    if (len != null && len > 0) {
      final accept = (headRes.headers['accept-ranges'] ?? '').toLowerCase();
      if (accept.contains('bytes')) return len;
    }
  } catch (_) {
    return null;
  } finally {
    client2.close();
  }
  return null;
}

Future<String> _saveToGallery(String path) async {
  final saved = await ImageGallerySaver.saveFile(
    path,
    name: 'jsx_${DateTime.now().millisecondsSinceEpoch}',
  );
  final ok = saved is Map && (saved['isSuccess'] == true || saved['isSuccess'] == 1 || saved['filePath'] != null);
  if (!ok) throw Exception('已下载但写入相册失败，请检查存储权限');
  return path;
}
