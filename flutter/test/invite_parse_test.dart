import 'package:flutter_test/flutter_test.dart';
import 'package:jisuxiongmao/api.dart';

void main() {
  test('纯邀请码', () {
    expect(parseInviteCode('XSPAB2CD3'), 'XSPAB2CD3');
    expect(parseInviteCode('xspab2cd3'), 'XSPAB2CD3');
  });

  test('邀请链接', () {
    expect(parseInviteCode('https://i.dcyzq.cn/XSPAB2CD3'), 'XSPAB2CD3');
    expect(parseInviteCode('https://i.dcyzq.cn/XSPAB2CD3?x=1'), 'XSPAB2CD3');
  });

  test('推广文案', () {
    expect(
      parseInviteCode('「极速熊猫」用我的邀请码 XSPAB2CD3 开通会员 👉 https://i.dcyzq.cn/XSPAB2CD3'),
      'XSPAB2CD3',
    );
  });

  test('无效内容', () {
    expect(parseInviteCode(''), isNull);
    expect(parseInviteCode('hello'), isNull);
    expect(parseInviteCode('XSP123'), isNull);
  });
}
