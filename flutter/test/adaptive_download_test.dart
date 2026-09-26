import 'package:flutter_test/flutter_test.dart';
import 'package:jisuxiongmao/video_save.dart';

void main() {
  test('小文件自适应为单线程', () {
    expect(adaptiveThreadCount(2 * 1024 * 1024, 8), 1);
    expect(adaptiveThreadCount(3 * 1024 * 1024, 8), 1);
  });

  test('中大文件提高线程数', () {
    expect(adaptiveThreadCount(5 * 1024 * 1024, 8), greaterThanOrEqualTo(2));
    expect(adaptiveThreadCount(20 * 1024 * 1024, 8), greaterThanOrEqualTo(4));
    expect(adaptiveThreadCount(60 * 1024 * 1024, 8), greaterThanOrEqualTo(6));
    expect(adaptiveThreadCount(60 * 1024 * 1024, 8), lessThanOrEqualTo(8));
  });
}
