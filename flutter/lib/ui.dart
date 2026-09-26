import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import 'api.dart';
import 'cover_cache.dart';
import 'store.dart';
import 'tools_local.dart';

const ink = Color(0xFF1F2328);
const ink2 = Color(0xFF5B6470);
const line = Color(0xFFEEF0F3);
const paper = Colors.white;
const bg = Color(0xFFF5F6F8);
const primary = Color(0xFF2B2B2B);
const accent = Color(0xFF3FAE5A);
const accentSoft = Color(0xFFE7F6EB);
const warn = Color(0xFFF2994A);
const warnSoft = Color(0xFFFFF4E8);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final page = switch (store.route) {
      'login' => LoginPage(store: store),
      'preview' => PreviewPage(store: store),
      'player' => PlayerPage(store: store),
      'downloads' => DownloadsPage(store: store),
      'me' => MePage(store: store),
      'vip' => VipPage(store: store),
      'member' => MemberPage(store: store),
      'affiliate' => AffiliatePage(store: store),
      'affiliate_promotions' => PromotionListPage(store: store),
      'feedback' => FeedbackPage(store: store),
      'doc' => DocPage(store: store),
      'tools' => ToolsPage(store: store),
      'tool' => ToolWorkPage(store: store),
      _ => HomePage(store: store),
    };
    return PopScope(
      canPop: !store.canNavigateBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        store.handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _EdgeSwipeBack(
                      enabled: store.canNavigateBack,
                      onBack: store.handleSystemBack,
                      child: page,
                    ),
                  ),
                  if (store.route != 'login') TabBarX(store: store),
                ],
              ),
              if (store.toast != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 96),
                    child: Material(
                      color: const Color(0xEB1F2328),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        child: Text(store.toast!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              if (store.loginPrompt) _LoginPrompt(store: store),
              if (store.payQr != null) _PayQrDialog(store: store),
            ],
          ),
        ),
        bottomSheet: store.showWithdraw ? WithdrawSheet(store: store) : null,
      ),
    );
  }
}

/// 左缘右滑返回，与顶部返回 / 系统返回一致（仅左缘热区，不干扰页面滑动）。
class _EdgeSwipeBack extends StatefulWidget {
  const _EdgeSwipeBack(
      {required this.child, required this.enabled, required this.onBack});
  final Widget child;
  final bool enabled;
  final bool Function() onBack;

  @override
  State<_EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<_EdgeSwipeBack> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.enabled)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                _dx += details.delta.dx;
              },
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (_dx > 48 || v > 350) widget.onBack();
                _dx = 0;
              },
              onHorizontalDragCancel: () => _dx = 0,
            ),
          ),
      ],
    );
  }
}

class _PayQrDialog extends StatelessWidget {
  const _PayQrDialog({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final url = store.payQr ?? '';
    return Material(
      color: const Color(0x99000000),
      child: Center(
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('微信扫码支付',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('请打开微信扫一扫，支付成功后会自动开通',
                  style: TextStyle(color: ink2, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              QrImageView(data: url, size: 220, backgroundColor: Colors.white),
              const SizedBox(height: 8),
              const Text('等待支付结果…',
                  style: TextStyle(color: ink2, fontSize: 12)),
              const SizedBox(height: 10),
              TextButton(onPressed: store.closePayQr, child: const Text('关闭')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black45,
        child: Center(
          child: Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            decoration: BoxDecoration(
                color: paper, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('需要登录',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text('解析视频前请先登录或注册账号',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ink2, fontSize: 13, height: 1.5)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: store.dismissLoginPrompt,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink2,
                          side: const BorderSide(color: line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: store.openLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('去登录'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabBarX extends StatelessWidget {
  const TabBarX({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('home', '首页', Icons.home_outlined),
      ('downloads', '下载', Icons.download_outlined),
      ('tools', '工具', Icons.build_outlined),
      ('me', '我的', Icons.person_outline),
    ];
    return Container(
      decoration: const BoxDecoration(
          color: paper, border: Border(top: BorderSide(color: line))),
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                onTap: () => store.tab(tab.$1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.$3, color: _on(tab.$1) ? primary : ink2),
                    Text(tab.$2,
                        style: TextStyle(
                            fontSize: 11,
                            color: _on(tab.$1) ? primary : ink2,
                            fontWeight: _on(tab.$1)
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _on(String id) {
    if (store.route == id) return true;
    if (id == 'me' &&
        [
          'vip',
          'member',
          'affiliate',
          'affiliate_promotions',
          'feedback',
          'doc',
          'login'
        ].contains(store.route)) return true;
    if (id == 'tools' && store.route == 'tool') return true;
    return false;
  }
}

class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [child],
    );
  }
}

class CenterBar extends StatelessWidget {
  const CenterBar(
      {super.key,
      required this.title,
      this.onBack,
      this.action,
      this.onAction,
      this.actionWidget});
  final String title;
  final VoidCallback? onBack;
  final IconData? action;
  final VoidCallback? onAction;
  final Widget? actionWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
          if (onBack != null)
            Align(
                alignment: Alignment.centerLeft,
                child: IconBtn(icon: Icons.chevron_left, onTap: onBack!)),
          if (actionWidget != null)
            Align(alignment: Alignment.centerRight, child: actionWidget!)
          else if (action != null)
            Align(
                alignment: Alignment.centerRight,
                child: IconBtn(icon: action!, onTap: onAction ?? () {})),
        ],
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line)),
        child: Icon(icon, size: 20, color: ink),
      ),
    );
  }
}

class PandaMark extends StatelessWidget {
  const PandaMark({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _PandaPainter());
  }
}

class _PandaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width;
    final black = Paint()..color = primary;
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r * 0.3)),
        black);
    canvas.drawCircle(Offset(r * 0.22, r * 0.16), r * 0.16, black);
    canvas.drawCircle(Offset(r * 0.78, r * 0.16), r * 0.16, black);
    canvas.drawOval(
        Rect.fromLTWH(r * 0.18, r * 0.36, r * 0.64, r * 0.46), white);
    canvas.drawCircle(Offset(r * 0.38, r * 0.55), r * 0.055, black);
    canvas.drawCircle(Offset(r * 0.62, r * 0.55), r * 0.055, black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Cta extends StatelessWidget {
  const Cta(
      {super.key,
      required this.text,
      required this.onTap,
      this.color = primary,
      this.icon});
  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

void copyText(Store store, String text) {
  Clipboard.setData(ClipboardData(text: text));
  store.show('已复制');
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final tab = store.authTab;
    final title = switch (tab) {
      'register' => '注册账号',
      'reset' => '找回密码',
      _ => '密码登录',
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconBtn(icon: Icons.chevron_left, onTap: store.back),
        ),
        const SizedBox(height: 12),
        const Center(child: PandaMark(size: 64)),
        const SizedBox(height: 12),
        const Center(
            child: Text('极速熊猫',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
        Center(
            child:
                Text(title, style: const TextStyle(color: ink2, fontSize: 13))),
        const SizedBox(height: 18),
        if (tab != 'reset')
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (final item in [('login', '登录'), ('register', '注册')])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => store.setAuthTab(item.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == item.$1 ? paper : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tab == item.$1
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: tab == item.$1 ? primary : ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (tab != 'reset') const SizedBox(height: 18),
        Field(
            label: '手机号',
            value: store.phone,
            hint: '请输入手机号',
            onChanged: (v) => store.phone = v),
        if (tab != 'login')
          Field(
            label: '验证码',
            value: store.code,
            hint: '请输入验证码',
            onChanged: (v) => store.code = v,
            suffix: _CodeButton(store: store),
          ),
        Field(
          label: tab == 'reset' ? '新密码' : '密码',
          value: store.password,
          hint: '至少 6 位',
          obscureText: true,
          onChanged: (v) => store.password = v,
        ),
        if (tab != 'login')
          Field(
            label: '确认密码',
            value: store.password2,
            hint: '再次输入密码',
            obscureText: true,
            onChanged: (v) => store.password2 = v,
          ),
        if (tab == 'register')
          Field(
              label: '邀请码（选填）',
              value: store.inviteInput,
              hint: '填写有效邀请码可领 1 日会员',
              onChanged: (v) => store.inviteInput = v),
        const SizedBox(height: 8),
        Cta(
          text: store.busy
              ? '请稍候…'
              : switch (tab) {
                  'register' => '注册并登录',
                  'reset' => '重置密码并登录',
                  _ => '登录',
                },
          color: accent,
          onTap: store.busy
              ? () {}
              : switch (tab) {
                  'register' => store.register,
                  'reset' => store.resetPassword,
                  _ => store.login,
                },
        ),
        if (tab == 'login')
          Center(
            child: TextButton(
              onPressed: () => store.setAuthTab('reset'),
              child: const Text('找回密码', style: TextStyle(color: ink2)),
            ),
          ),
        if (tab == 'reset')
          Center(
            child: TextButton(
              onPressed: () => store.setAuthTab('login'),
              child: const Text('返回登录', style: TextStyle(color: ink2)),
            ),
          ),
      ],
    );
  }
}

class DocPage extends StatelessWidget {
  const DocPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final body = store.t(store.docKey, '暂无内容，请先在管理后台「设置 → 用户协议」中填写。');
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(title: store.docTitle, onBack: store.back),
          Text(body,
              style: const TextStyle(fontSize: 14, height: 1.7, color: ink)),
        ],
      ),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const _CodeButton({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final cooling = store.codeLeft > 0;
    final sending = store.codeSending;
    final enabled = !cooling && !sending;
    final label = cooling ? '${store.codeLeft}s' : (sending ? '发送中…' : '获取验证码');
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: enabled ? store.sendCode : null,
        style: TextButton.styleFrom(
          foregroundColor: accent,
          disabledForegroundColor: ink2,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class Field extends StatefulWidget {
  const Field({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
  });
  final String label;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool obscureText;
  final Widget? suffix;

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final TextEditingController controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(Field oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != controller.text) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(color: ink2, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            decoration: _inputDeco(widget.hint, suffix: widget.suffix),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDeco(String hint, {Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.5)),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final platforms = store
        .t('download.platforms', '抖音/快手/B站/小红书/视频号/更多')
        .split(RegExp(r'[/、,]'));
    final recent = store.downloads.take(2).toList();
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 48,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                PandaMark(size: 30),
                SizedBox(width: 7),
                Text('极速',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                Text('熊猫',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: accent)),
              ]),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('支持复制链接 · 自动识别',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.18))),
                  child: Row(
                    children: [
                      Expanded(child: _LinkField(store: store)),
                      TextButton(
                        style: TextButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: store.parseLink,
                        child: const Text('解析'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      for (final name in platforms)
                        if (name.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => store.show('已选择：${name.trim()}'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(name.trim(),
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 11)),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 12),
              child: Text('选择下载模式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          InfoCard(
              icon: Icons.download_outlined,
              title: '普通下载',
              sub: store.t('download.normal_rule', '标准速度 · 首次 3 次 · 每日送 1 次'),
              badge: '免费',
              badgeColor: accent,
              onTap: store.parseLink),
          InfoCard(
              icon: Icons.bolt,
              iconBg: accentSoft,
              iconColor: accent,
              title: '加速下载',
              sub: store.t('download.fast_desc', '多线程提速 · 极速完成'),
              badge: 'VIP',
              badgeColor: warn,
              onTap: store.parseLink),
          Row(
            children: [
              const Expanded(
                  child: Text('最近下载',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              TextButton(
                  onPressed: () => store.tab('downloads'),
                  child: const Text('查看全部 ›', style: TextStyle(color: ink2))),
            ],
          ),
          if (recent.isEmpty)
            const Text('还没有下载记录', style: TextStyle(color: ink2, fontSize: 13)),
          for (final item in recent)
            InfoCard(
              icon: Icons.play_arrow,
              thumb: CoverThumb(
                  cacheKey: 'dl_${item['id']}',
                  url: (item['coverUrl'] ?? '').toString()),
              title: (item['title'] ?? '未命名视频').toString(),
              sub:
                  '${(item['platform'] ?? '视频')} · ${item['status'] == 'completed' ? '已完成' : '${item['progress'] ?? 0}%'}',
              badge: item['status'] == 'completed'
                  ? '完成'
                  : '${item['progress'] ?? 0}%',
              badgeColor: item['status'] == 'completed' ? accent : warn,
              onTap: () {
                if (item['status'] == 'completed') {
                  store.openDownloadItem(item);
                } else {
                  store.tab('downloads');
                }
              },
            ),
        ],
      ),
    );
  }
}

class _LinkField extends StatefulWidget {
  const _LinkField({required this.store});
  final Store store;

  @override
  State<_LinkField> createState() => _LinkFieldState();
}

class _LinkFieldState extends State<_LinkField> with WidgetsBindingObserver {
  late final TextEditingController controller =
      TextEditingController(text: widget.store.link);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fillFromClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fillFromClipboard();
  }

  Future<void> _fillFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (!mounted || text.isEmpty || controller.text.trim().isNotEmpty) return;
    controller.text = text;
    widget.store.link = text;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
                hintText: '粘贴视频链接到这里…',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                isDense: true),
            onChanged: (v) {
              widget.store.link = v;
              setState(() {});
            },
          ),
        ),
        if (hasText)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              controller.clear();
              widget.store.link = '';
              setState(() {});
            },
            child: const Text('清空'),
          ),
      ],
    );
  }
}

class CoverThumb extends StatefulWidget {
  const CoverThumb({super.key, required this.cacheKey, required this.url});
  final String cacheKey;
  final String url;

  @override
  State<CoverThumb> createState() => _CoverThumbState();
}

class _CoverThumbState extends State<CoverThumb> {
  String? path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey || oldWidget.url != widget.url)
      _load();
  }

  Future<void> _load() async {
    final saved = await ensureCover(widget.cacheKey, widget.url);
    if (!mounted || saved == null) return;
    setState(() => path = saved);
  }

  @override
  Widget build(BuildContext context) {
    final file = path;
    final image = file != null && File(file).existsSync()
        ? Image.file(File(file), width: 72, height: 54, fit: BoxFit.cover)
        : const Icon(Icons.play_arrow, color: ink);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 54,
        color: const Color(0xFFF2F3F5),
        alignment: Alignment.center,
        child: image,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.sub,
      required this.badge,
      required this.badgeColor,
      this.onTap,
      this.iconBg = const Color(0xFFF2F3F5),
      this.iconColor = ink,
      this.thumb});
  final IconData icon;
  final String title;
  final String sub;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;
  final Color iconBg;
  final Color iconColor;
  final Widget? thumb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: paper,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Row(
              children: [
                thumb ??
                    Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: iconColor)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink2, fontSize: 12)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(badge,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.store});
  final Store store;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? controller;
  String? error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = widget.store.playingUrl ?? '';
    if (url.isEmpty) {
      setState(() => error = '没有播放地址');
      return;
    }
    final VideoPlayerController next;
    if (url.startsWith('http')) {
      next = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: widget.store.playHeaders());
    } else {
      next = VideoPlayerController.file(File(url));
    }
    controller = next;
    try {
      await next.initialize();
      await next.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => error = '无法播放，请确认视频地址可访问');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(
              title: widget.store.playingTitle ?? '播放',
              onBack: widget.store.back),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: (c != null &&
                      c.value.isInitialized &&
                      c.value.aspectRatio > 0)
                  ? c.value.aspectRatio
                  : 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: error != null
                    ? Center(
                        child: Text(error!,
                            style: const TextStyle(color: Colors.white)))
                    : (c != null && c.value.isInitialized)
                        ? VideoPlayer(c)
                        : const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (c != null && c.value.isInitialized)
            Cta(
              text: c.value.isPlaying ? '暂停' : '播放',
              icon: c.value.isPlaying ? Icons.pause : Icons.play_arrow,
              onTap: () {
                c.value.isPlaying ? c.pause() : c.play();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.store});
  final Store store;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  VideoPlayerController? _player;
  bool _loading = false;
  String? _playError;
  String _openedUrl = '';
  final PageController _albumController = PageController();
  int _albumIndex = 0;

  Store get store => widget.store;

  @override
  void dispose() {
    _player?.removeListener(_onPlayer);
    _player?.dispose();
    _albumController.dispose();
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleInlinePlay() async {
    final c = _player;
    if (c != null && c.value.isInitialized) {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
      setState(() {});
      return;
    }
    await _openInline();
  }

  Future<void> _openInline({String? overrideUrl}) async {
    final url = store.resolvePlayUrl(overrideUrl: overrideUrl);
    if (url.isEmpty) {
      store.show('没有可播放的地址');
      return;
    }
    store.playingUrl = url;
    store.playingTitle = (store.parsed?['title'] ?? '播放').toString();
    if (_openedUrl == url && _player != null && _player!.value.isInitialized) {
      await _player!.play();
      setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _playError = null;
    });
    await _player?.dispose();
    _player = null;
    final VideoPlayerController next;
    if (url.startsWith('http')) {
      next = VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: store.playHeaders());
    } else {
      next = VideoPlayerController.file(File(url));
    }
    next.addListener(_onPlayer);
    _player = next;
    _openedUrl = url;
    try {
      await next.initialize();
      await next.play();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _playError = '无法播放，请确认视频可访问';
        });
      }
    }
  }

  Future<void> _openLivePhoto(Map<String, dynamic> item) async {
    final url = (item['livePhotoUrl'] ??
            item['live_photo_url'] ??
            item['liveVideoUrl'] ??
            item['live_video_url'] ??
            '')
        .toString()
        .trim();
    if (url.isEmpty || !url.startsWith('http')) {
      store.show('这张图片没有实况视频');
      return;
    }
    store.playingUrl = url;
    store.playingTitle = (store.parsed?['title'] ?? '实况').toString();
    await _openInline(overrideUrl: url);
  }

  Widget _meta(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Text(k, style: const TextStyle(color: ink2, fontSize: 13)),
        const Spacer(),
        Text(v,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = store.parsed ?? {};
    final fromDownload = v['fromDownload'] == true;
    final imageList = asList(v['imageList']);
    final contentType = (v['contentType'] ?? '').toString();
    final isImagePost = imageList.isNotEmpty;
    final isLivePhoto = contentType == 'live_photo' || imageList.any((item) => (item['livePhotoUrl'] ?? item['live_photo_url'] ?? '').toString().isNotEmpty);
    final title = (v['title'] ?? '未命名视频').toString();
    final author = (asMap(v['author'])['nickname'] ?? '未知作者').toString();
    final source = (v['platform'] ?? '未知平台').toString();
    final cover = (v['coverUrl'] ?? '').toString();
    final link = (v['sourceUrl'] ?? v['videoUrl'] ?? '').toString();
    final taskId = (v['taskId'] ?? '').toString();
    final c = _player;
    final playing = c != null && c.value.isInitialized && c.value.isPlaying;
    final ready = c != null && c.value.isInitialized;

    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(
              title: fromDownload ? '下载详情' : '解析预览',
              onBack: store.back,
              action: Icons.more_horiz,
              onAction: () => store.show('更多操作')),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 210,
              width: double.infinity,
              color: primary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!isImagePost && fromDownload && ready)
                    ColoredBox(
                      color: Colors.black,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width:
                              c.value.size.width > 0 ? c.value.size.width : 9,
                          height: c.value.size.height > 0
                              ? c.value.size.height
                              : 16,
                          child: VideoPlayer(c),
                        ),
                      ),
                    )
                  else if (isImagePost)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _albumController,
                          itemCount: imageList.length,
                          onPageChanged: (i) =>
                              setState(() => _albumIndex = i),
                          itemBuilder: (_, index) {
                            final item = imageList[index];
                            final imageUrl = (item['url'] ??
                                    item['imageUrl'] ??
                                    item['downloadUrl'] ??
                                    item['src'] ??
                                    '')
                                .toString();
                            final hasLive = (item['livePhotoUrl'] ??
                                    item['live_photo_url'] ??
                                    '')
                                .toString()
                                .isNotEmpty;
                            return GestureDetector(
                              onTap: isLivePhoto
                                  ? () => _openLivePhoto(item)
                                  : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                        size: 42),
                                  ),
                                  if (hasLive)
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Row(children: [
                                          Icon(Icons.play_circle_fill,
                                              size: 13,
                                              color: Colors.white),
                                          SizedBox(width: 3),
                                          Text('实况',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11)),
                                        ]),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (imageList.length > 1)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  '${_albumIndex + 1} / ${imageList.length}  ·  左右滑动查看',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    _PreviewCover(
                        cacheKey: taskId.isEmpty ? '' : 'dl_$taskId',
                        url: cover),
                  if (_loading)
                    const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                  else if (_playError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_playError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  else if (!isImagePost)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          fromDownload ? _toggleInlinePlay : store.playCurrent,
                      child: Center(
                        child: (fromDownload && playing)
                            ? const SizedBox.expand()
                            : const CircleAvatar(
                                radius: 29,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.play_arrow,
                                    color: primary, size: 32),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  TextButton.icon(
                      onPressed: () => copyText(store, title),
                      icon: const Icon(Icons.copy, size: 14),
                      label:
                          const Text('复制标题', style: TextStyle(fontSize: 11))),
                ]),
                _meta('作者', author),
                _meta('来源', source),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () =>
                        copyText(store, '$title · 作者：$author · 来源：$source'),
                    icon: const Icon(Icons.copy, color: accent),
                    label: const Text('复制文案'))),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () =>
                        copyText(store, link.isEmpty ? title : link),
                    icon: const Icon(Icons.copy, color: accent),
                    label: const Text('复制链接'))),
          ]),
          const SizedBox(height: 12),
          if (isImagePost)
            Cta(
                text: isLivePhoto ? '保存图文和实况' : '保存图文图片',
                icon: Icons.download_outlined,
                color: accent,
                onTap: () => store.startDownload('normal'))
          else if (fromDownload)
            Cta(
              text: playing ? '暂停' : (ready ? '继续播放' : '播放视频'),
              icon: playing ? Icons.pause : Icons.play_arrow,
              color: accent,
              onTap: _toggleInlinePlay,
            )
          else
            Row(children: [
              Expanded(
                  child: Cta(
                      text: '普通下载',
                      icon: Icons.download_outlined,
                      onTap: () => store.startDownload('normal'))),
              const SizedBox(width: 12),
              Expanded(
                  child: Cta(
                      text: '加速下载',
                      color: accent,
                      icon: Icons.bolt,
                      onTap: () => store.startDownload('fast'))),
            ]),
          const SizedBox(height: 14),
          Center(
            child: Text(
              isImagePost
                  ? (isLivePhoto ? '点击实况图片可播放短视频，也可以保存全部媒体' : '这是图文作品，可保存全部图片')
                  : (fromDownload
                      ? '点击封面或下方按钮，在本页直接播放'
                      : store.t('download.done_tip', '下载完成后可在手机相册中查看')),
              style: const TextStyle(color: ink2, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCover extends StatefulWidget {
  const _PreviewCover({required this.cacheKey, required this.url});
  final String cacheKey;
  final String url;

  @override
  State<_PreviewCover> createState() => _PreviewCoverState();
}

class _PreviewCoverState extends State<_PreviewCover> {
  String? path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PreviewCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey || oldWidget.url != widget.url) {
      path = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.cacheKey.isEmpty) return;
    final saved = await ensureCover(widget.cacheKey, widget.url);
    if (!mounted || saved == null) return;
    setState(() => path = saved);
  }

  @override
  Widget build(BuildContext context) {
    final file = path;
    if (file != null && File(file).existsSync()) {
      return Image.file(File(file), fit: BoxFit.cover);
    }
    if (widget.url.startsWith('http')) {
      return Image.network(widget.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return const SizedBox.shrink();
  }
}

class _SwipeDeleteTile extends StatefulWidget {
  const _SwipeDeleteTile(
      {super.key, required this.child, required this.onDelete});
  final Widget child;
  final Future<bool> Function() onDelete;

  @override
  State<_SwipeDeleteTile> createState() => _SwipeDeleteTileState();
}

class _SwipeDeleteTileState extends State<_SwipeDeleteTile> {
  static const _actionWidth = 88.0;
  double offset = 0;
  bool busy = false;

  bool get _open => offset <= -_actionWidth / 2;

  void _snap() {
    setState(() => offset = _open ? -_actionWidth : 0);
  }

  Future<void> _delete() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await widget.onDelete();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!ok) offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFE85D5D),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _actionWidth,
                    child: Center(
                      child: Text(busy ? '…' : '删除',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  offset = (offset + details.delta.dx).clamp(-_actionWidth, 0);
                });
              },
              onHorizontalDragEnd: (_) => _snap(),
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: paper,
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(18)),
                  child: widget.child,
                ),
              ),
            ),
            if (_open)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _actionWidth,
                child: Material(
                  color: const Color(0xFFE85D5D),
                  child: InkWell(
                    onTap: busy ? null : _delete,
                    child: Center(
                      child: Text(busy ? '…' : '删除',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final list = store.downloads.where((item) {
      if (store.filter == 'downloading') return item['status'] != 'completed';
      if (store.filter == 'completed') return item['status'] == 'completed';
      return true;
    }).toList();
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CenterBar(title: '下载记录'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (final item in [
                  ('all', '全部'),
                  ('downloading', '下载中'),
                  ('completed', '已完成')
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        store.filter = item.$1;
                        store.refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                            color: store.filter == item.$1
                                ? paper
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: Text(item.$2,
                            style: TextStyle(
                                fontWeight: store.filter == item.$1
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color:
                                    store.filter == item.$1 ? primary : ink2)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (store.downloading)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: line)),
              child: Row(
                children: [
                  CoverThumb(
                      cacheKey: store.downloadCoverKey,
                      url: store.downloadCoverUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            store.downloadHint.isEmpty
                                ? '正在下载'
                                : store.downloadHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                            '下载中 ${(store.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                            style:
                                const TextStyle(color: accent, fontSize: 12)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                            value: store.downloadProgress.clamp(0, 1),
                            color: accent,
                            backgroundColor: bg,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (list.isEmpty && !store.downloading)
            const Center(child: Text('暂无记录', style: TextStyle(color: ink2))),
          for (final item in list)
            _SwipeDeleteTile(
              key: ValueKey('dl_${item['id']}'),
              onDelete: () => store.deleteDownload(item),
              child: item['status'] != 'completed'
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(children: [
                            CoverThumb(
                                cacheKey: 'dl_${item['id']}',
                                url: (item['coverUrl'] ?? '').toString()),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text((item['title'] ?? '未命名').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            Text('${item['progress'] ?? 0}%',
                                style: const TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                              value: ((item['progress'] as num?) ?? 0) / 100,
                              color: accent,
                              backgroundColor: bg,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(6)),
                        ],
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => store.openDownloadItem(item),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CoverThumb(
                                  cacheKey: 'dl_${item['id']}',
                                  url: (item['coverUrl'] ?? '').toString()),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((item['title'] ?? '未命名').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                    Text('${item['platform'] ?? '视频'} · 已保存到相册',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: ink2, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16)),
                                child: const Text('播放',
                                    style: TextStyle(
                                        color: accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _MeGear extends StatefulWidget {
  const _MeGear({required this.store});
  final Store store;

  @override
  State<_MeGear> createState() => _MeGearState();
}

class _MeGearState extends State<_MeGear> {
  int bytes = 0;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final size = await cacheBytes();
    if (mounted) setState(() => bytes = size);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final version = store.t('common.version', 'v1.0.0');
    return PopupMenuButton<String>(
      tooltip: '设置',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'about') {
          store.show('极速熊猫 $version');
        } else if (value == 'cache') {
          await store.clearCache();
          await _loadSize();
        } else if (value == 'logout') {
          store.logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'about', child: Text('关于极速熊猫  $version')),
        PopupMenuItem(
          value: 'cache',
          child: Row(
            children: [
              const Text('清理缓存'),
              const Spacer(),
              Text(formatCacheSize(bytes),
                  style: const TextStyle(color: ink2, fontSize: 12)),
            ],
          ),
        ),
        if (store.loggedIn)
          const PopupMenuItem(value: 'logout', child: Text('退出登录')),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line)),
        child: const Icon(Icons.settings_outlined, size: 20, color: ink),
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) {
      return Container(
        width: 140,
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line, width: 2)),
        child: const Text('微信二维码', style: TextStyle(color: ink2, fontSize: 12)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 140,
        height: 140,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          color: bg,
          child: const Text('二维码加载失败',
              style: TextStyle(color: ink2, fontSize: 12)),
        ),
      ),
    );
  }
}

bool _isHttpUrl(String value) => value.trim().startsWith('http');

String _contactQrUrl(Store store) {
  final qr = store.t('contact.qrcode', '').trim();
  if (_isHttpUrl(qr)) return qr;
  final tip = store.t('contact.qrcode_tip', '').trim();
  if (_isHttpUrl(tip)) return tip;
  return '';
}

String _contactQrTip(Store store) {
  final tip = store.t('contact.qrcode_tip', '').trim();
  if (tip.isEmpty || _isHttpUrl(tip)) return '扫码添加客服微信';
  return tip;
}

class MePage extends StatelessWidget {
  const MePage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final u = store.user ?? {};
    final vip = u['vipActive'] == true;
    final phone = maskPhone((u['phone'] ?? '').toString());
    return PageScroll(
      child: Column(
        children: [
          CenterBar(title: '我的', actionWidget: _MeGear(store: store)),
          Material(
            color: paper,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: store.loggedIn ? null : store.openLogin,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line)),
                child: Row(
                  children: [
                    const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFF0F0F0),
                        child: PandaMark(size: 40)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            store.loggedIn
                                ? (u['nickname'] ?? '熊猫用户').toString()
                                : '点击登录 / 注册',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          Text(
                              store.loggedIn
                                  ? (phone.isEmpty ? '已登录' : phone)
                                  : '登录后可解析下载与分销',
                              style:
                                  const TextStyle(color: ink2, fontSize: 12)),
                          if (vip)
                            Text(
                                '到期 ${(u['vipExpireAt'] ?? '').toString().split('T').first}',
                                style:
                                    const TextStyle(color: warn, fontSize: 12)),
                        ])),
                    InkWell(
                      onTap: () {
                        if (!store.loggedIn) {
                          store.openLogin();
                        } else if (vip) {
                          store.go('member');
                        } else {
                          store.go('vip');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: warnSoft,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(vip ? '会员' : '开通 VIP',
                            style: const TextStyle(
                                color: warn,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _group([
            _row(Icons.bolt, '加速下载', 'VIP 专享',
                () => store.loggedIn ? store.go('vip') : store.openLogin()),
            _row(
                Icons.share_outlined,
                '推广赚钱',
                '分销赚佣金',
                () =>
                    store.loggedIn ? store.go('affiliate') : store.openLogin()),
          ]),
          _group([
            _row(
                Icons.info_outline,
                '关于极速熊猫',
                store.t('common.version', 'v1.0.0'),
                () =>
                    store.show('极速熊猫 ${store.t('common.version', 'v1.0.0')}')),
            _row(Icons.description_outlined, '用户协议', '',
                () => store.openDoc('legal.agreement', '用户协议')),
            _row(Icons.shield_outlined, '隐私政策', '',
                () => store.openDoc('legal.privacy', '隐私政策')),
            _row(
                Icons.chat_bubble_outline,
                '意见反馈',
                '',
                () =>
                    store.loggedIn ? store.go('feedback') : store.openLogin()),
          ]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('联系我们',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15))),
                _contact(store, '客服微信',
                    store.t('contact.wechat', 'jisuxiongmao_kefu')),
                _contact(store, 'QQ 邮箱',
                    store.t('contact.email', '123456789@qq.com')),
                const SizedBox(height: 12),
                _QrImage(url: _contactQrUrl(store)),
                const SizedBox(height: 8),
                Text(_contactQrTip(store),
                    style: const TextStyle(color: ink2, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line)),
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: ink),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value.isNotEmpty)
          Text(value, style: const TextStyle(color: ink2, fontSize: 13)),
        const Icon(Icons.chevron_right, color: Color(0xFFC0C6CF)),
      ]),
      onTap: onTap,
    );
  }

  Widget _contact(Store store, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Text(label, style: const TextStyle(color: ink2, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        TextButton(
            onPressed: () => copyText(store, value), child: const Text('复制')),
      ]),
    );
  }
}

String _virtualPaidCount() {
  const start = 12860;
  final days = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
  final count = start + (days < 0 ? 0 : days) * 17;
  final text = count.toString();
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buf.write(',');
    buf.write(text[i]);
  }
  return buf.toString();
}

String _memberExpire(dynamic raw) {
  final text = (raw ?? '').toString();
  if (text.isEmpty) return '长期有效';
  final time = DateTime.tryParse(text)?.toLocal();
  if (time == null) return text.split('T').first;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}

class MemberPage extends StatelessWidget {
  const MemberPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final u = store.user ?? {};
    final vip = u['vipActive'] == true;
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(title: '会员信息', onBack: store.back),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)]),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0x33F2994A),
                    child: Icon(Icons.workspace_premium, color: warn)),
                const SizedBox(height: 12),
                Text(vip ? '当前是会员' : '当前未开通',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(vip ? '会员权益已生效' : '开通后可查看到期时间',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              children: [
                _line('会员状态', vip ? '会员' : '未开通'),
                _line('到期时间', vip ? _memberExpire(u['vipExpireAt']) : '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: ink2, fontSize: 14)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}

class VipPage extends StatelessWidget {
  const VipPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final plans = store.plans.isEmpty
        ? [
            {'type': 'month', 'name': '月卡', 'desc': '适合短期体验', 'amount': 19.9},
            {'type': 'half', 'name': '半年卡', 'desc': '折合每月约 ¥9.8', 'amount': 59},
            {
              'type': 'year',
              'name': '年卡',
              'desc': '折合每月约 ¥8.25 · 最划算',
              'amount': 99
            },
          ]
        : store.plans;
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(
              title: '开通会员',
              onBack: store.back,
              action: Icons.more_horiz,
              onAction: () => store.show('更多操作')),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                    colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)])),
            child: Column(
              children: [
                const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0x33F2994A),
                    child: Icon(Icons.workspace_premium, color: warn)),
                const SizedBox(height: 12),
                Text(store.t('plan.title', '极速熊猫 VIP'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(store.t('plan.subtitle', '解锁加速下载 · 原画质 · 无限次解析'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 10),
                Text('已有 ${_virtualPaidCount()} 人支付',
                    style: const TextStyle(
                        color: warn,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(child: _Perk(title: '极速下载', sub: '多线程不限速')),
            SizedBox(width: 10),
            Expanded(child: _Perk(title: '原画质', sub: '无损下载')),
            SizedBox(width: 10),
            Expanded(child: _Perk(title: '无限解析', sub: '不限次数')),
          ]),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 12),
              child: Text('选择套餐',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          for (final plan in plans) _plan(store, plan),
          Cta(
              text: store.busy ? '请稍候…' : '立即开通',
              color: warn,
              onTap: store.busy ? () {} : store.pay),
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                  child: Text('开通即同意会员服务协议 · 虚拟商品不支持退款',
                      style: TextStyle(color: ink2, fontSize: 11)))),
          const SizedBox(height: 12),
          InfoCard(
              icon: Icons.share_outlined,
              iconBg: accentSoft,
              iconColor: accent,
              title: '推广赚钱',
              sub: store.t('affiliate.entry', '邀请好友开通会员，最高得 50% 佣金'),
              badge: '分销 ›',
              badgeColor: warn,
              onTap: () => store.go('affiliate')),
        ],
      ),
    );
  }

  Widget _plan(Store store, Map<String, dynamic> plan) {
    final type = (plan['type'] ?? '').toString();
    final on = store.selectedPlan == type;
    final amount = plan['amount'];
    final price = amount is num
        ? (amount % 1 == 0 ? '¥${amount.toInt()}' : '¥$amount')
        : '¥$amount';
    return GestureDetector(
      onTap: () {
        store.selectedPlan = type;
        store.refresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFFFDF9) : paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? warn : line, width: 2),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                color: on ? warn : const Color(0xFFC0C6CF)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${plan['name'] ?? planName(type)}${type == 'year' ? '  最划算' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text((plan['desc'] ?? '').toString(),
                      style: const TextStyle(color: ink2, fontSize: 12)),
                ])),
            Text(price,
                style: const TextStyle(
                    color: warn, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: line)),
      child: Column(children: [
        const Icon(Icons.bolt, color: accent, size: 22),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(sub, style: const TextStyle(color: ink2, fontSize: 11)),
      ]),
    );
  }
}

class AffiliatePage extends StatelessWidget {
  const AffiliatePage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final u = store.user ?? {};
    final a = {
      ...u,
      ...?store.affiliate,
    };
    final inviteCode = (a['inviteCode'] ?? '').toString();
    final inviteLink = (a['inviteLink'] ?? '').toString();
    final shareText = (a['shareText'] ?? '').toString().isNotEmpty
        ? (a['shareText'] ?? '').toString()
        : (inviteLink.isNotEmpty
            ? '「极速熊猫」下载神器，用我的邀请码 $inviteCode 开通会员 👉 $inviteLink'
            : '');
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(
              title: '分销中心',
              onBack: store.back,
              action: Icons.more_horiz,
              onAction: () => store.show('分销规则见下方')),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                    colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)])),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('推广极速熊猫，轻松赚佣金',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('好友通过你的邀请码开通会员，你即可获得收益',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 16),
                Row(children: [
                  _stat(money((a['totalCommission'] as num?) ?? 0), '累计佣金'),
                  _stat(
                      money((a['balance'] as num?) ??
                          (a['commissionBalance'] as num?) ??
                          0),
                      '可提现余额'),
                  _stat('${a['inviteeCount'] ?? store.invitees.length}', '已邀请'),
                  _stat('${a['openedCount'] ?? 0}', '已开通'),
                ]),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 12),
              child: Text('我的邀请',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('我的邀请码',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(
                        child: Text(inviteCode.isEmpty ? '加载中…' : inviteCode,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2))),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      onPressed: inviteCode.isEmpty
                          ? null
                          : () => copyText(store, inviteCode),
                      child: const Text('复制'),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Cta(
                  text: '复制推广链接',
                  color: primary,
                  icon: Icons.share_outlined,
                  onTap: () {
                    final text = shareText.isNotEmpty ? shareText : inviteLink;
                    if (text.isEmpty) {
                      store.show('邀请信息加载中，请稍后再试');
                      return;
                    }
                    copyText(store, text);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('推广明细',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  if (store.promotionTotal > 20 ||
                      store.promotions.length >= 20)
                    TextButton(
                      onPressed: () => store.go('affiliate_promotions'),
                      child: const Text('查看更多 ›',
                          style: TextStyle(color: accent, fontSize: 12)),
                    ),
                ]),
                if (store.promotions.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child:
                              Text('还没有推广记录', style: TextStyle(color: ink2))))
                else ...[
                  const SizedBox(height: 4),
                  const PromotionTableHeader(),
                  for (final item in store.promotions.take(20))
                    PromotionTableRow(store: store, item: item),
                  if (store.promotionTotal > 20) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => store.go('affiliate_promotions'),
                        child: Text('查看全部 ${store.promotionTotal} 条 ›',
                            style: const TextStyle(color: accent)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Cta(
              text: '申请提现',
              color: warn,
              icon: Icons.account_balance_wallet_outlined,
              onTap: () {
                store.showWithdraw = true;
                store.refresh();
              }),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分销规则',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('· ${store.t('affiliate.example', '受邀人开通会员后按比例返佣')}',
                    style: const TextStyle(color: ink2, height: 1.7)),
                Text(
                    '· 普通用户 ${store.t('affiliate.rate.normal', '20')}%，会员 ${store.t('affiliate.rate.member', '30')}%，流量主最高 ${store.t('affiliate.rate.traffic', '50')}%',
                    style: const TextStyle(color: ink2, height: 1.7)),
                Text(
                    '· 满 ${store.t('affiliate.withdraw.min', '10')} 元可提现，${store.t('affiliate.withdraw.eta', '通常 12 小时内到账')}',
                    style: const TextStyle(color: ink2, height: 1.7)),
                Text('· ${store.t('affiliate.anti_cheat', '自推小号可能被认定作弊，不予结算')}',
                    style: const TextStyle(color: ink2, height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Expanded(
        child: Column(children: [
      Text(num,
          style: const TextStyle(
              color: warn, fontWeight: FontWeight.w800, fontSize: 14)),
      Text(label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
    ]));
  }
}

class PromotionListPage extends StatelessWidget {
  const PromotionListPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final list =
        store.promotionsAll.isNotEmpty ? store.promotionsAll : store.promotions;
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(title: '推广明细', onBack: store.back),
          Text('共 ${store.promotionTotal} 条',
              style: const TextStyle(color: ink2, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child:
                              Text('还没有推广记录', style: TextStyle(color: ink2))))
                else ...[
                  const PromotionTableHeader(),
                  for (final item in list)
                    PromotionTableRow(store: store, item: item),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PromotionTableHeader extends StatelessWidget {
  const PromotionTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
            flex: 5,
            child: Text('好友',
                style: TextStyle(
                    color: ink2, fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(
            flex: 2,
            child: Text('开通',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ink2, fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(
            flex: 2,
            child: Text('比例',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ink2, fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(
            flex: 3,
            child: Text('佣金',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: ink2, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class PromotionTableRow extends StatelessWidget {
  const PromotionTableRow({super.key, required this.store, required this.item});
  final Store store;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final vip = item['vipActive'] == true;
    final phone = maskPhone((item['phone'] ?? '').toString());
    final name = (item['nickname'] ?? '用户 $phone').toString();
    final rate = (item['ratePercent'] as num?)?.round() ??
        (((store.affiliate?['ratePercent'] as num?) ?? 20).round());
    final commission = (item['commission'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(phone, style: const TextStyle(color: ink2, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              vip ? '是' : '否',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: vip ? accent : ink2,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('$rate%',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              money(commission),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: vip ? warn : ink2,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class WithdrawSheet extends StatelessWidget {
  const WithdrawSheet({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final acc = store.account;
    final wechatQr =
        store.payChannel == 'wechat' && store.payAccount.startsWith('http');
    return Container(
      color: paper,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0E3E8),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('申请提现',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '关闭',
                      onPressed: () {
                        store.showWithdraw = false;
                        store.refresh();
                      },
                      icon: const Icon(Icons.close, color: ink2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (acc == null) ...[
              Text(store.t('common.withdraw_lock_tip', '设置完成后将无法修改'),
                  style: const TextStyle(color: warn, fontSize: 12)),
              const SizedBox(height: 12),
              _pay('支付宝', store.payChannel == 'alipay', () => _set('alipay')),
              _pay('微信', store.payChannel == 'wechat', () => _set('wechat')),
              if (store.payChannel == 'alipay')
                Field(
                    label: '支付宝账号',
                    value: store.payAccount,
                    hint: '保存后不能修改',
                    onChanged: (v) => store.payAccount = v)
              else ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('微信收款二维码',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: store.pickWithdrawQr,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: wechatQr
                        ? Image.network(store.payAccount, fit: BoxFit.contain)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, color: ink2, size: 36),
                              SizedBox(height: 8),
                              Text('点击上传收款码图片',
                                  style: TextStyle(color: ink2, fontSize: 13)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('请上传微信「收款二维码」截图，不是微信号',
                      style: TextStyle(color: ink2, fontSize: 11)),
                ),
              ],
              const SizedBox(height: 12),
              Cta(text: '确认配置', color: accent, onTap: store.saveAccount),
              TextButton(
                onPressed: () {
                  store.showWithdraw = false;
                  store.refresh();
                },
                child: const Text('关闭'),
              ),
            ] else ...[
              if (acc['channel'] == 'wechat') ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('微信收款码',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                if ((acc['account'] ?? '').toString().startsWith('http'))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(acc['account'].toString(),
                        height: 120, fit: BoxFit.contain),
                  )
                else
                  Text('${acc['account']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              ] else
                Text('支付宝  ${acc['account']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Field(
                  label: '提现金额',
                  value: store.withdrawAmount,
                  hint: '满 10 元可提',
                  onChanged: (v) => store.withdrawAmount = v),
              Text('可提现余额：${money((store.affiliate?['balance'] as num?) ?? 0)}',
                  style: const TextStyle(color: warn, fontSize: 11)),
              const SizedBox(height: 12),
              Cta(text: '确认提现', color: accent, onTap: store.withdraw),
              TextButton(
                onPressed: () {
                  store.showWithdraw = false;
                  store.refresh();
                },
                child: const Text('取消'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _set(String channel) {
    store.payChannel = channel;
    store.payAccount = '';
    store.refresh();
  }

  Widget _pay(String title, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: on ? accent : line, width: 1.5)),
        tileColor: on ? accentSoft : paper,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
            color: on ? accent : const Color(0xFFC0C6CF)),
        onTap: tap,
      ),
    );
  }
}

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final types =
        store.t('feedback.types', '功能新增,问题反馈,优化建议').split(RegExp(r'[,，]'));
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(title: '意见反馈', onBack: store.back),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                    colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)])),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.t('feedback.guide_title', '做用户有用的短视频下载工具'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Text(store.t('feedback.guide_body', '使用中的问题、建议都可以告诉我们'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: warn.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(store.t('feedback.slogan', '听人劝，吃饱饭'),
                      style: const TextStyle(
                          color: warn, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            for (final type in types)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      store.fbType = type.trim();
                      store.refresh();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: store.fbType == type.trim() ? accentSoft : paper,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: store.fbType == type.trim() ? accent : line,
                            width: 1.5),
                      ),
                      child: Text(type.trim(),
                          style: TextStyle(
                              color:
                                  store.fbType == type.trim() ? accent : ink2,
                              fontWeight: store.fbType == type.trim()
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 13)),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Field(
              label: '反馈内容',
              value: store.fbContent,
              hint: '请详细描述您的想法、问题或建议…',
              maxLines: 5,
              onChanged: (v) => store.fbContent = v),
          const Text('上传截图（选填，最多 3 张）',
              style: TextStyle(color: ink2, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: [
            for (final url in store.fbImages)
              Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
            if (store.fbImages.length < 3)
              InkWell(
                onTap: store.pickImage,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: line, width: 2)),
                  child: const Text('添加',
                      style: TextStyle(color: ink2, fontSize: 12)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Field(
              label: '邮箱（选填）',
              value: store.fbEmail,
              hint: '便于我们回复您',
              onChanged: (v) => store.fbEmail = v),
          Cta(
              text: store.busy ? '提交中…' : '提交反馈',
              onTap: store.busy ? () {} : store.submitFeedback),
        ],
      ),
    );
  }
}

const _toolItems = [
  ('compress', '图片压缩', '控制质量或目标体积', Icons.compress, accentSoft, accent),
  (
    'convert',
    '格式转换',
    'JPG / PNG / WebP 互转',
    Icons.swap_horiz,
    accentSoft,
    accent
  ),
  (
    'resize',
    '改尺寸',
    '宽高、等比、最长边',
    Icons.photo_size_select_large,
    Color(0xFFF2F3F5),
    ink
  ),
  ('crop', '裁剪旋转', '裁剪、旋转与翻转', Icons.crop_rotate, Color(0xFFF2F3F5), ink),
  ('watermark', '加水印', '文字水印', Icons.branding_watermark, warnSoft, warn),
  ('idphoto', '证件照', '标准尺寸与换底色', Icons.badge_outlined, warnSoft, warn),
  ('stitch', '长图拼接', '竖拼 / 横拼', Icons.view_agenda_outlined, accentSoft, accent),
  ('exif', '去 EXIF', '清除元数据与定位', Icons.timer_outlined, Color(0xFFF2F3F5), ink),
];

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CenterBar(title: '工具'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  colors: [Color(0xFF2B2B2B), Color(0xFF1C1C1C)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('图片小工具',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('本地处理，不上传服务器',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Text('来自相册 · 结果保存到相册',
                      style: TextStyle(
                          color: Color(0xFF6FD18A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 12),
              child: Text('推荐工具',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (final t in _toolItems)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => store.openTool(t.$1, t.$2),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: t.$5,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(t.$4, color: t.$6, size: 20),
                        ),
                        const Spacer(),
                        Text(t.$2,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(t.$3,
                            style: const TextStyle(
                                fontSize: 12, color: ink2, height: 1.3)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('二期可考虑',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD7DBE2))),
            child: Column(
              children: [
                for (final item in ['GIF 压缩', '视频转 GIF', 'PDF ↔ 图片', '提取文字'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(item, style: const TextStyle(fontSize: 14)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Text('二期',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: ink2,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ToolWorkPage extends StatefulWidget {
  const ToolWorkPage({super.key, required this.store});
  final Store store;

  @override
  State<ToolWorkPage> createState() => _ToolWorkPageState();
}

class _ToolWorkPageState extends State<ToolWorkPage> {
  final picker = ImagePicker();
  final List<XFile> files = [];
  bool busy = false;
  int quality = 70;
  String format = 'jpg';
  int width = 1080;
  int rotate = 90;
  String watermark = '极速熊猫';
  String idSize = '1cun';
  int bgColor = 0xFFFFFFFF;
  bool stitchVertical = true;

  Store get store => widget.store;

  Future<void> pick({bool multi = false}) async {
    if (multi) {
      final list = await picker.pickMultiImage(imageQuality: 95);
      if (list.isEmpty) return;
      setState(() {
        files
          ..clear()
          ..addAll(list.take(9));
      });
      return;
    }
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;
    setState(() {
      files
        ..clear()
        ..add(file);
    });
  }

  Future<void> run() async {
    if (files.isEmpty) {
      store.show('请先选择图片');
      return;
    }
    setState(() => busy = true);
    try {
      final path = files.first.path;
      final LocalToolResult result = switch (store.toolId) {
        'compress' => await compressImage(path, quality: quality),
        'convert' => await convertImage(path, format),
        'resize' => await resizeImage(path, width: width),
        'crop' => rotate == 0
            ? await cropCenter(path)
            : await rotateImage(path, rotate),
        'watermark' => await watermarkImage(path, watermark),
        'exif' => await stripExif(path),
        'idphoto' => await idPhoto(
            path,
            width: idSize == '2cun'
                ? 413
                : idSize == 'passport'
                    ? 390
                    : 295,
            height: idSize == '2cun'
                ? 579
                : idSize == 'passport'
                    ? 567
                    : 413,
            bg: bgColor,
          ),
        'stitch' => await stitchImages(files.map((e) => e.path).toList(),
            vertical: stitchVertical),
        _ => throw Exception('未知工具'),
      };
      store.show(result.message);
    } catch (e) {
      store.show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = store.toolId;
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CenterBar(title: store.toolTitle, onBack: store.back),
          const Text('本地处理，图片不会上传',
              style: TextStyle(color: ink2, fontSize: 12)),
          const SizedBox(height: 14),
          if (files.isEmpty)
            InkWell(
              onTap: () => pick(multi: id == 'stitch'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: line)),
                child: Text(id == 'stitch' ? '选择多张图片' : '从相册选择图片',
                    style: const TextStyle(color: ink2)),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in files)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(f.path),
                        width: 88, height: 88, fit: BoxFit.cover),
                  ),
                InkWell(
                  onTap: () => pick(multi: id == 'stitch'),
                  child: Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line)),
                    child: const Icon(Icons.add, color: ink2),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          ..._options(),
          const SizedBox(height: 16),
          Cta(
              text: busy ? '处理中…' : '开始处理并保存',
              color: accent,
              onTap: busy ? () {} : run),
        ],
      ),
    );
  }

  List<Widget> _options() {
    switch (store.toolId) {
      case 'compress':
        return [
          Text('压缩质量 $quality',
              style: const TextStyle(fontSize: 13, color: ink2)),
          Slider(
              value: quality.toDouble(),
              min: 30,
              max: 90,
              divisions: 12,
              activeColor: accent,
              onChanged: (v) => setState(() => quality = v.round())),
        ];
      case 'convert':
        return [
          const Text('目标格式', style: TextStyle(fontSize: 13, color: ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final f in ['jpg', 'png', 'webp'])
              ChoiceChip(
                  label: Text(f.toUpperCase()),
                  selected: format == f,
                  onSelected: (_) => setState(() => format = f)),
          ]),
          if (format == 'webp')
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('当前 WebP 会先导出为高质量 JPG',
                    style: TextStyle(fontSize: 12, color: ink2))),
        ];
      case 'resize':
        return [
          Text('目标宽度 $width px（高度等比）',
              style: const TextStyle(fontSize: 13, color: ink2)),
          Slider(
              value: width.toDouble(),
              min: 200,
              max: 3000,
              divisions: 28,
              activeColor: accent,
              onChanged: (v) => setState(() => width = v.round())),
        ];
      case 'crop':
        return [
          const Text('操作', style: TextStyle(fontSize: 13, color: ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('居中裁方'),
                selected: rotate == 0,
                onSelected: (_) => setState(() => rotate = 0)),
            ChoiceChip(
                label: const Text('旋转 90°'),
                selected: rotate == 90,
                onSelected: (_) => setState(() => rotate = 90)),
            ChoiceChip(
                label: const Text('旋转 180°'),
                selected: rotate == 180,
                onSelected: (_) => setState(() => rotate = 180)),
          ]),
        ];
      case 'watermark':
        return [
          Field(
              label: '水印文字',
              value: watermark,
              hint: '极速熊猫',
              onChanged: (v) => watermark = v)
        ];
      case 'idphoto':
        return [
          const Text('规格', style: TextStyle(fontSize: 13, color: ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('一寸'),
                selected: idSize == '1cun',
                onSelected: (_) => setState(() => idSize = '1cun')),
            ChoiceChip(
                label: const Text('二寸'),
                selected: idSize == '2cun',
                onSelected: (_) => setState(() => idSize = '2cun')),
            ChoiceChip(
                label: const Text('护照'),
                selected: idSize == 'passport',
                onSelected: (_) => setState(() => idSize = 'passport')),
          ]),
          const SizedBox(height: 12),
          const Text('底色', style: TextStyle(fontSize: 13, color: ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('白底'),
                selected: bgColor == 0xFFFFFFFF,
                onSelected: (_) => setState(() => bgColor = 0xFFFFFFFF)),
            ChoiceChip(
                label: const Text('蓝底'),
                selected: bgColor == 0xFF438EDB,
                onSelected: (_) => setState(() => bgColor = 0xFF438EDB)),
            ChoiceChip(
                label: const Text('红底'),
                selected: bgColor == 0xFFD94B4B,
                onSelected: (_) => setState(() => bgColor = 0xFFD94B4B)),
          ]),
        ];
      case 'stitch':
        return [
          const Text('拼接方向', style: TextStyle(fontSize: 13, color: ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('竖拼'),
                selected: stitchVertical,
                onSelected: (_) => setState(() => stitchVertical = true)),
            ChoiceChip(
                label: const Text('横拼'),
                selected: !stitchVertical,
                onSelected: (_) => setState(() => stitchVertical = false)),
          ]),
        ];
      default:
        return [
          const Text('将重新编码图片以清除 EXIF',
              style: TextStyle(fontSize: 13, color: ink2))
        ];
    }
  }
}
