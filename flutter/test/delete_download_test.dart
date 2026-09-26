import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jisuxiongmao/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deleteDownload 只删本地列表，不请求云端', () async {
    final store = Store();
    store.user = {'id': 1};
    store.downloads = [
      {'id': 9, 'title': '测试', 'videoUrl': 'https://example.com/a.mp4', 'status': 'completed'},
    ];
    store.localVideos['9'] = '/fake/cache/a.mp4';

    final ok = await store.deleteDownload(store.downloads.first);

    expect(ok, isTrue);
    expect(store.downloads, isEmpty);
    expect(store.hiddenDownloadIds.contains('9'), isTrue);
    expect(store.localVideos.containsKey('9'), isFalse);

    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('hidden_downloads_1'), ['9']);
  });

  test('deleteDownload 源码不调删除接口、不碰相册', () async {
    final source = await File('lib/store.dart').readAsString();
    final start = source.indexOf('Future<bool> deleteDownload');
    final end = source.indexOf('Future<void> _loadHiddenDownloads', start);
    final block = source.substring(start, end);
    expect(block.contains('ImageGallerySaver'), isFalse);
    expect(block.contains('/api/download/'), isFalse);
    expect(block.contains('_api()'), isFalse);
    expect(block.contains('相册与云端不受影响'), isTrue);
  });
}
