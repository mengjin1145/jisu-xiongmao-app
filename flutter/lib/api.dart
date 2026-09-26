import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Api {
  Api(this.baseUrl, this.token);

  final String baseUrl;
  final String token;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<String> upload(String filePath) async {
    final req = http.MultipartRequest('POST', _uri('/api/upload/image'));
    if (token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send().timeout(const Duration(seconds: 40));
    final text = await streamed.stream.bytesToString();
    final data = _unwrap(text);
    final url = (data['url'] ?? '').toString();
    if (url.isEmpty) throw ApiException('上传失败');
    return url;
  }

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    http.Response res;
    try {
      final uri = _uri(path);
      if (method == 'POST') {
        res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 40));
      } else if (method == 'DELETE') {
        res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 40));
      } else {
        res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 40));
      }
    } catch (_) {
      throw ApiException('连不上服务器，请稍后重试');
    }
    return _unwrap(res.body);
  }

  Map<String, dynamic> _unwrap(String text) {
    if (text.isEmpty) throw ApiException('服务器无响应');
    final json = jsonDecode(text);
    if (json is! Map) throw ApiException('服务器返回异常');
    final code = json['code'];
    if (code != 0) {
      final raw = json['message'];
      final msg = raw is List ? raw.join('；') : (raw ?? '请求失败').toString();
      throw ApiException(code == 401 ? '登录已过期' : msg);
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'_list': data};
  }

  Uri _uri(String path) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) throw ApiException('服务器地址未配置');
    return Uri.parse('$base$path');
  }
}

String defaultBaseUrl() => 'https://api.dcyzq.cn';

/// 从纯邀请码、邀请链接或推广文案中解析邀请码。格式：XSP + 6 位。
String? parseInviteCode(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final pattern = RegExp(r'XSP[A-HJ-NP-Z2-9]{6}', caseSensitive: false);

  final compact = text.replaceAll('-', '').toUpperCase();
  if (RegExp(r'^XSP[A-HJ-NP-Z2-9]{6}$').hasMatch(compact)) return compact;

  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
    final last = uri.pathSegments.last.replaceAll('-', '').toUpperCase();
    if (RegExp(r'^XSP[A-HJ-NP-Z2-9]{6}$').hasMatch(last)) return last;
  }

  final match = pattern.firstMatch(text.replaceAll('-', ''));
  if (match == null) return null;
  return match.group(0)!.toUpperCase();
}

Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

String maskPhone(String phone) {
  if (phone.length < 7) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
}

String money(num value) => '¥${value.toStringAsFixed(2)}';

String planName(String type) {
  switch (type) {
    case 'month':
      return '月卡';
    case 'half':
      return '半年卡';
    case 'year':
      return '年卡';
    default:
      return type;
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> asList(dynamic value) {
  final raw = value is Map && value.containsKey('_list') ? value['_list'] : value;
  if (raw is! List) return [];
  return raw.map(asMap).toList();
}
