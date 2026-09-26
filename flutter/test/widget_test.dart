import 'package:flutter_test/flutter_test.dart';
import 'package:jisuxiongmao/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('phone mask', () {
    expect(maskPhone('13800000002'), '138****0002');
  });

  test('default api host uses production https', () {
    expect(defaultBaseUrl(), 'https://api.dcyzq.cn');
  });

  test('prefs mock is available', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await prefs();
    await p.setString('base', 'http://127.0.0.1:3000');
    expect(p.getString('base'), 'http://127.0.0.1:3000');
  });
}
