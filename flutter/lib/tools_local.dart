import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// 图片/实况素材保存失败时抛出，携带可读原因。
class MediaSaveException implements Exception {
  MediaSaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _galleryUa =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

class LocalToolResult {
  LocalToolResult(this.path, {this.message = '已保存到相册'});
  final String path;
  final String message;
}

Future<String> _tempPath(String name) async {
  final dir = await getTemporaryDirectory();
  final out = Directory('${dir.path}/jsx_tools');
  if (!out.existsSync()) out.createSync(recursive: true);
  return '${out.path}/$name';
}

Future<img.Image> _decode(String path) async {
  final bytes = await File(path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('无法读取图片');
  return img.bakeOrientation(decoded);
}

Future<void> _saveToGallery(String path) async {
  final isVideo = path.toLowerCase().endsWith('.mp4') ||
      path.toLowerCase().endsWith('.mov');
  final result = isVideo
      ? await ImageGallerySaver.saveFile(path,
          name: 'jsx_${DateTime.now().millisecondsSinceEpoch}',
          isReturnPathOfIOS: true)
      : await ImageGallerySaver.saveFile(path,
          name: 'jsx_${DateTime.now().millisecondsSinceEpoch}');
  final ok = result is Map &&
      (result['isSuccess'] == true ||
          result['isSuccess'] == 1 ||
          result['filePath'] != null);
  if (!ok) {
    throw MediaSaveException('保存到相册失败，请在系统设置中允许「极速熊猫」访问照片');
  }
}

Future<LocalToolResult> _saveBytes(Uint8List bytes, String filename) async {
  final path = await _tempPath(filename);
  await File(path).writeAsBytes(bytes, flush: true);
  await _saveToGallery(path);
  return LocalToolResult(path);
}

/// 下载单张图片并写入相册。失败时抛 [MediaSaveException]，不再静默返回 null。
Future<String?> downloadImageToGallery(String url,
    {required int index, Map<String, String>? headers}) async {
  final response = await http.get(Uri.parse(url), headers: {
    'User-Agent': _galleryUa,
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    ...?headers,
  }).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 400) {
    throw MediaSaveException('图片下载失败 HTTP ${response.statusCode}');
  }
  if (response.bodyBytes.isEmpty) {
    throw MediaSaveException('图片内容为空');
  }
  final type = (response.headers['content-type'] ?? '').toLowerCase();
  final ext =
      type.contains('png') || url.toLowerCase().contains('.png') ? 'png' : 'jpg';
  final result = await _saveBytes(response.bodyBytes,
      'pic_${DateTime.now().millisecondsSinceEpoch}_$index.$ext');
  return result.path;
}

/// 实况短视频/大图：流式落盘再写相册，避免整段读进内存。
/// 失败时抛 [MediaSaveException]，让上层能区分「网络失败 / 相册权限失败」。
Future<String?> downloadMediaToGallery(String url,
    {required String prefix, Map<String, String>? headers}) async {
  final client = http.Client();
  IOSink? sink;
  try {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll({
      'User-Agent': _galleryUa,
      'Accept': '*/*',
      ...?headers,
    });
    final response =
        await client.send(request).timeout(const Duration(seconds: 60));
    if (response.statusCode >= 400) {
      throw MediaSaveException('素材下载失败 HTTP ${response.statusCode}');
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isVideo =
        contentType.contains('video') || url.toLowerCase().contains('.mp4');
    final ext = isVideo ? 'mp4' : (contentType.contains('png') ? 'png' : 'jpg');
    final path =
        await _tempPath('${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    final file = File(path);
    sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    if (!file.existsSync() || await file.length() == 0) {
      throw MediaSaveException('素材内容为空');
    }
    await _saveToGallery(path);
    return path;
  } finally {
    await sink?.close();
    client.close();
  }
}

Future<LocalToolResult> compressImage(String path, {int quality = 70}) async {
  final out =
      await _tempPath('compress_${DateTime.now().millisecondsSinceEpoch}.jpg');
  final result = await FlutterImageCompress.compressAndGetFile(
    path,
    out,
    quality: quality.clamp(10, 95),
    format: CompressFormat.jpeg,
  );
  if (result == null) throw Exception('压缩失败');
  await _saveToGallery(result.path);
  return LocalToolResult(result.path, message: '压缩完成，已保存到相册');
}

Future<LocalToolResult> convertImage(String path, String format) async {
  final image = await _decode(path);
  late Uint8List bytes;
  late String ext;
  switch (format) {
    case 'png':
      bytes = Uint8List.fromList(img.encodePng(image));
      ext = 'png';
    case 'webp':
      bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      ext = 'jpg';
    default:
      bytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
      ext = 'jpg';
  }
  return _saveBytes(
      bytes, 'convert_${DateTime.now().millisecondsSinceEpoch}.$ext');
}

Future<LocalToolResult> resizeImage(String path,
    {int? width, int? height}) async {
  final image = await _decode(path);
  final w = width ?? image.width;
  final h = height ?? ((image.height * w) / image.width).round();
  final resized = img.copyResize(image,
      width: w, height: h, interpolation: img.Interpolation.linear);
  final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 92));
  return _saveBytes(
      bytes, 'resize_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> rotateImage(String path, int degrees) async {
  final image = await _decode(path);
  final rotated = img.copyRotate(image, angle: degrees);
  final bytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
  return _saveBytes(
      bytes, 'rotate_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> cropCenter(String path, {double ratio = 1}) async {
  final image = await _decode(path);
  var cropW = image.width;
  var cropH = (cropW / ratio).round();
  if (cropH > image.height) {
    cropH = image.height;
    cropW = (cropH * ratio).round();
  }
  final x = ((image.width - cropW) / 2).round();
  final y = ((image.height - cropH) / 2).round();
  final cropped = img.copyCrop(image, x: x, y: y, width: cropW, height: cropH);
  final bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  return _saveBytes(bytes, 'crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> watermarkImage(String path, String text) async {
  final image = await _decode(path);
  final mark = text.trim().isEmpty ? '极速熊猫' : text.trim();
  final font = img.arial24;
  final tw = mark.length * 14;
  final x = (image.width - tw - 24).clamp(8, image.width - 8);
  final y = (image.height - 40).clamp(8, image.height - 8);
  img.drawString(image, mark,
      font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 200));
  img.drawString(image, mark,
      font: font, x: x + 1, y: y + 1, color: img.ColorRgba8(0, 0, 0, 120));
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  return _saveBytes(bytes, 'wm_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> stripExif(String path) async {
  final image = await _decode(path);
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  return _saveBytes(bytes, 'exif_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> idPhoto(String path,
    {required int width, required int height, int bg = 0xFFFFFFFF}) async {
  final image = await _decode(path);
  final resized = img.copyResize(image,
      width: width, height: height, interpolation: img.Interpolation.linear);
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas,
      color:
          img.ColorRgba8((bg >> 16) & 0xFF, (bg >> 8) & 0xFF, bg & 0xFF, 255));
  img.compositeImage(canvas, resized);
  final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
  return _saveBytes(bytes, 'id_${DateTime.now().millisecondsSinceEpoch}.jpg');
}

Future<LocalToolResult> stitchImages(List<String> paths,
    {bool vertical = true}) async {
  if (paths.isEmpty) throw Exception('请先选择图片');
  final images = <img.Image>[];
  for (final p in paths) {
    images.add(await _decode(p));
  }
  if (vertical) {
    final width = images.map((e) => e.width).reduce((a, b) => a > b ? a : b);
    final height = images.fold<int>(
        0, (sum, e) => sum + ((e.height * width) / e.width).round());
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
    var y = 0;
    for (final src in images) {
      final h = ((src.height * width) / src.width).round();
      final resized = img.copyResize(src, width: width, height: h);
      img.compositeImage(canvas, resized, dstY: y);
      y += h;
    }
    final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    return _saveBytes(
        bytes, 'stitch_${DateTime.now().millisecondsSinceEpoch}.jpg');
  }
  final height = images.map((e) => e.height).reduce((a, b) => a > b ? a : b);
  final width = images.fold<int>(
      0, (sum, e) => sum + ((e.width * height) / e.height).round());
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  var x = 0;
  for (final src in images) {
    final w = ((src.width * height) / src.height).round();
    final resized = img.copyResize(src, width: w, height: height);
    img.compositeImage(canvas, resized, dstX: x);
    x += w;
  }
  final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  return _saveBytes(
      bytes, 'stitch_${DateTime.now().millisecondsSinceEpoch}.jpg');
}
