import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final Map<String, Future<String?>> _coverJobs = {};
int _cacheGen = 0;

/// 把视频封面存到本机。同一 [key] 只下载一次，之后直接读本地文件。
Future<String?> ensureCover(String key, String url, {String? referer}) {
  final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  if (safeKey.isEmpty || !url.startsWith('http')) return Future.value(null);
  return _coverJobs[safeKey] ??= _save(safeKey, url, referer).whenComplete(() {
    _coverJobs.remove(safeKey);
  });
}

Future<void> cacheDownloadCovers(List<Map<String, dynamic>> items) async {
  final batch = <Future<void>>[];
  for (final item in items) {
    final id = (item['id'] ?? '').toString();
    final url = (item['coverUrl'] ?? '').toString();
    if (id.isEmpty || !url.startsWith('http')) continue;
    batch.add(ensureCover('dl_$id', url).then((_) {}));
    if (batch.length >= 3) {
      await Future.wait(batch);
      batch.clear();
    }
  }
  if (batch.isNotEmpty) await Future.wait(batch);
}

Future<String?> _save(String key, String url, String? referer) async {
  final gen = _cacheGen;
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/covers');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final existing = dir.listSync().whereType<File>().where((file) => file.uri.pathSegments.last.startsWith('$key.')).toList();
  if (existing.isNotEmpty && existing.first.lengthSync() > 0) return existing.first.path;

  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = 'Mozilla/5.0';
    final from = (referer ?? '').trim();
    if (from.isNotEmpty) req.headers['Referer'] = from;
    final res = await client.send(req).timeout(const Duration(seconds: 20));
    if (res.statusCode >= 400 || gen != _cacheGen) return null;
    final bytes = await res.stream.toBytes();
    if (bytes.length < 32 || gen != _cacheGen) return null;
    final ext = _ext(url, res.headers['content-type'] ?? '');
    final file = File('${dir.path}/$key.$ext');
    await file.writeAsBytes(bytes, flush: true);
    if (gen != _cacheGen) {
      if (file.existsSync()) file.deleteSync();
      return null;
    }
    return file.path;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

Future<int> cacheBytes() async {
  var total = 0;
  total += await _dirBytes(Directory('${(await getApplicationSupportDirectory()).path}/covers'));
  final temp = await getTemporaryDirectory();
  if (temp.existsSync()) {
    for (final entity in temp.listSync()) {
      if (entity is File && _isVideoCache(entity.uri.pathSegments.last)) {
        total += entity.lengthSync();
      }
    }
  }
  total += await _dirBytes(Directory('${temp.path}/jsx_tools'));
  return total;
}

Future<void> clearAppCache() async {
  _cacheGen++;
  _coverJobs.clear();
  final covers = Directory('${(await getApplicationSupportDirectory()).path}/covers');
  if (covers.existsSync()) covers.deleteSync(recursive: true);
  final temp = await getTemporaryDirectory();
  if (temp.existsSync()) {
    for (final entity in temp.listSync()) {
      if (entity is File && _isVideoCache(entity.uri.pathSegments.last)) {
        entity.deleteSync();
      }
    }
  }
  final tools = Directory('${temp.path}/jsx_tools');
  if (tools.existsSync()) tools.deleteSync(recursive: true);
}

String formatCacheSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
}

Future<int> _dirBytes(Directory dir) async {
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) total += entity.lengthSync();
  }
  return total;
}

bool _isVideoCache(String name) => name.startsWith('jsx_') && name.endsWith('.mp4');

Future<void> removeCover(String key) async {
  try {
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (safeKey.isEmpty) return;
    _coverJobs.remove(safeKey);
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/covers');
    if (!dir.existsSync()) return;
    for (final file in dir.listSync().whereType<File>()) {
      if (file.uri.pathSegments.last.startsWith('$safeKey.')) {
        file.deleteSync();
      }
    }
  } catch (_) {}
}

String _ext(String url, String contentType) {
  final type = contentType.toLowerCase();
  if (type.contains('png')) return 'png';
  if (type.contains('webp')) return 'webp';
  if (type.contains('gif')) return 'gif';
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.gif')) return 'gif';
  return 'jpg';
}
