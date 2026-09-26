import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'cover_cache.dart';
import 'video_save.dart';
import 'tools_local.dart';

class Store extends ChangeNotifier {
  String baseUrl = defaultBaseUrl();
  String token = '';
  String route = 'home';
  final List<String> _stack = [];
  String? toast;
  bool busy = false;
  bool loginPrompt = false;

  String phone = '';
  String code = '';
  int codeLeft = 0;
  bool codeSending = false;
  Timer? _codeTimer;
  String password = '';
  String password2 = '';
  String inviteInput = '';
  String authTab = 'login'; // login | register | reset
  String docTitle = '';
  String docKey = '';
  String toolId = '';
  String toolTitle = '';
  String link = '';

  Map<String, dynamic>? user;
  Map<String, dynamic>? parsed;
  List<Map<String, dynamic>> downloads = [];
  String filter = 'all';
  bool downloading = false;
  double downloadProgress = 0;
  String downloadHint = '';
  String downloadCoverKey = '';
  String downloadCoverUrl = '';
  String? playingUrl;
  String? playingTitle;
  final Map<String, String> localVideos = {};

  /// 本地已隐藏的下载记录 id（云端仍保留）
  Set<String> hiddenDownloadIds = {};
  List<Map<String, dynamic>> plans = [];
  String selectedPlan = 'year';
  Map<String, String> texts = {};

  Map<String, dynamic>? affiliate;
  List<Map<String, dynamic>> commissions = [];
  List<Map<String, dynamic>> invitees = [];
  List<Map<String, dynamic>> promotions = [];
  List<Map<String, dynamic>> promotionsAll = [];
  int promotionTotal = 0;
  Map<String, dynamic>? account;
  bool showWithdraw = false;
  String payChannel = 'alipay';
  String payAccount = '';
  String withdrawAmount = '';
  String? payQr;
  int? payWatchOrderId;

  String fbType = '功能新增';
  String fbContent = '';
  String fbEmail = '';
  List<String> fbImages = [];

  String t(String key, String fallback) {
    final value = texts[key];
    if (value == null || value.trim().isEmpty) return fallback;
    return value;
  }

  Future<void> init() async {
    final p = await prefs();
    // 线上固定接口，覆盖本地曾保存的调试地址
    baseUrl = defaultBaseUrl();
    await p.setString('base', baseUrl);
    token = p.getString('token') ?? '';
    route = 'home';
    notifyListeners();
    try {
      await loadPublic();
      if (token.isNotEmpty) {
        await loadUser();
        await loadDownloads();
      }
    } catch (e) {
      show(e.toString());
    }
  }

  bool get loggedIn => token.isNotEmpty;

  void refresh() => notifyListeners();

  void openLogin() {
    loginPrompt = false;
    go('login');
    if (authTab == 'register') fillInviteFromClipboard();
  }

  void dismissLoginPrompt() {
    loginPrompt = false;
    notifyListeners();
  }

  void setAuthTab(String tab) {
    authTab = tab;
    notifyListeners();
    if (tab == 'register') fillInviteFromClipboard();
  }

  /// 从剪贴板识别邀请码或邀请链接，自动填入注册页邀请码框。
  Future<void> fillInviteFromClipboard() async {
    if (inviteInput.trim().isNotEmpty) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final code = parseInviteCode(data?.text ?? '');
      if (code == null || inviteInput.trim().isNotEmpty) return;
      inviteInput = code;
      notifyListeners();
      show('已自动填入邀请码');
    } catch (_) {}
  }

  void show(String msg) {
    toast = msg;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toast == msg) {
        toast = null;
        notifyListeners();
      }
    });
  }

  void go(String id) {
    if (route != 'login' && route != id) _stack.add(route);
    route = id;
    notifyListeners();
    _enter(id);
    if (id == 'login' && authTab == 'register') fillInviteFromClipboard();
  }

  void tab(String id) {
    _stack.clear();
    route = id;
    notifyListeners();
    _enter(id);
  }

  /// 系统返回 / 侧滑：有栈或非首页时由 App 消化，不退出。
  bool get canNavigateBack {
    if (showWithdraw || payQr != null || loginPrompt) return true;
    if (_stack.isNotEmpty) return true;
    return route != 'home';
  }

  /// 处理系统返回键 / 侧滑。返回 true 表示已拦截。
  bool handleSystemBack() {
    if (showWithdraw) {
      showWithdraw = false;
      notifyListeners();
      return true;
    }
    if (payQr != null) {
      payQr = null;
      payWatchOrderId = null;
      notifyListeners();
      return true;
    }
    if (loginPrompt) {
      loginPrompt = false;
      notifyListeners();
      return true;
    }
    if (_stack.isNotEmpty || route != 'home') {
      back();
      return true;
    }
    return false;
  }

  void back() {
    route = _stack.isEmpty ? 'home' : _stack.removeLast();
    notifyListeners();
  }

  Future<void> logout() async {
    token = '';
    user = null;
    final p = await prefs();
    await p.remove('token');
    _stack.clear();
    route = 'home';
    notifyListeners();
  }

  Future<void> saveBase(String url) async {
    baseUrl = url.trim();
    final p = await prefs();
    await p.setString('base', baseUrl);
    notifyListeners();
  }

  void openDoc(String key, String title) {
    docKey = key;
    docTitle = title;
    go('doc');
    _run(loadPublic, quiet: true);
  }

  void openTool(String id, String title) {
    toolId = id;
    toolTitle = title;
    go('tool');
  }

  Future<void> sendCode() async {
    if (codeLeft > 0 || codeSending) return;
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      show('手机号格式不正确');
      return;
    }
    final scene = authTab == 'reset' ? 'reset' : 'register';
    codeSending = true;
    notifyListeners();
    try {
      await _api()
          .post('/api/user/send-code', {'phone': phone, 'scene': scene});
      show('验证码已发送');
      _startCodeCountdown();
    } catch (e) {
      show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      codeSending = false;
      notifyListeners();
    }
  }

  void _startCodeCountdown() {
    _codeTimer?.cancel();
    codeLeft = 60;
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (codeLeft <= 1) {
        codeLeft = 0;
        timer.cancel();
        _codeTimer = null;
      } else {
        codeLeft -= 1;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _afterAuth(Map<String, dynamic> data, String tip) async {
    token = (data['token'] ?? '').toString();
    user = asMap(data['user']);
    final p = await prefs();
    await p.setString('token', token);
    route = _stack.isEmpty ? 'home' : _stack.removeLast();
    await loadDownloads();
    await loadPublic();
    show(tip);
  }

  Future<void> login() async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      show('手机号格式不正确');
      return;
    }
    if (password.length < 6) {
      show('密码至少 6 位');
      return;
    }
    await saveBase(baseUrl);
    await _run(() async {
      final data = await _api()
          .post('/api/user/login', {'phone': phone, 'password': password});
      await _afterAuth(data, '登录成功');
    });
  }

  Future<void> register() async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      show('手机号格式不正确');
      return;
    }
    if (code.length < 4) {
      show('请输入验证码');
      return;
    }
    if (password.length < 6) {
      show('密码至少 6 位');
      return;
    }
    if (password != password2) {
      show('两次输入的密码不一致');
      return;
    }
    await saveBase(baseUrl);
    await _run(() async {
      final body = <String, dynamic>{
        'phone': phone,
        'code': code,
        'password': password,
      };
      if (inviteInput.trim().isNotEmpty) {
        final parsed = parseInviteCode(inviteInput);
        body['inviteCode'] =
            (parsed ?? inviteInput.replaceAll('-', '').trim()).toUpperCase();
      }
      final data = await _api().post('/api/user/register', body);
      final hadInvite = body.containsKey('inviteCode');
      await _afterAuth(data, hadInvite ? '注册成功，已赠送 1 日会员' : '注册成功');
    });
  }

  Future<void> resetPassword() async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      show('手机号格式不正确');
      return;
    }
    if (code.length < 4) {
      show('请输入验证码');
      return;
    }
    if (password.length < 6) {
      show('密码至少 6 位');
      return;
    }
    if (password != password2) {
      show('两次输入的密码不一致');
      return;
    }
    await saveBase(baseUrl);
    await _run(() async {
      final data = await _api().post('/api/user/reset-password', {
        'phone': phone,
        'code': code,
        'password': password,
      });
      await _afterAuth(data, '密码已重置，已自动登录');
    });
  }

  Future<void> parseLink() async {
    if (!loggedIn) {
      loginPrompt = true;
      notifyListeners();
      return;
    }
    final text = link.trim();
    if (text.length < 4) {
      show('请先粘贴视频链接');
      return;
    }
    await _run(() async {
      final data = await _api().post('/api/parse', {'text': text});
      parsed = {...data, 'fromDownload': false, 'taskId': ''};
      go('preview');
    });
  }

  Future<void> pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    if (link.trim().isNotEmpty) return;
    link = text;
    notifyListeners();
  }

  Future<void> startDownload(String mode) async {
    final video = parsed;
    if (video == null) {
      show('请先解析链接');
      return;
    }
    final images = asList(video['imageList']);
    if (images.isNotEmpty) {
      await _downloadAlbum(video, images, mode);
      return;
    }
    final url = (video['downloadUrl'] ?? video['videoUrl'] ?? '').toString();
    if (url.isEmpty) {
      show('没有可下载的地址');
      return;
    }
    if (downloading) {
      show('已有下载进行中');
      return;
    }
    var recorded = false;
    var taskId = '';
    await _run(() async {
      final author = asMap(video['author'])['nickname']?.toString() ?? '';
      final task = await _api().post('/api/download/task', {
        'videoUrl': url,
        'title': video['title'] ?? '',
        'platform': video['platform'] ?? '',
        'coverUrl': video['coverUrl'] ?? '',
        'author': author,
        'mode': mode,
      });
      taskId = (task['id'] ?? '').toString();
      recorded = true;
      await loadUser();
    });
    if (!recorded) return;

    final cover = (video['coverUrl'] ?? '').toString();
    final headers = _videoHeaders(video);
    final referer = headers['Referer'] ?? '';
    downloading = true;
    downloadProgress = 0.02;
    downloadHint = (video['title'] ?? '视频').toString();
    downloadCoverKey = taskId.isEmpty ? '' : 'dl_$taskId';
    downloadCoverUrl = cover;
    if (downloadCoverKey.isNotEmpty) {
      ensureCover(downloadCoverKey, cover, referer: referer);
    }
    notifyListeners();
    tab('downloads');
    try {
      final path = await downloadVideoToGallery(
        url,
        headers: headers,
        threads: mode == 'fast' ? 8 : 1,
        onProgress: (p) {
          downloadProgress = p <= 0 ? 0.02 : p;
          notifyListeners();
        },
      );
      if (taskId.isNotEmpty) localVideos[taskId] = path;
      localVideos[url] = path;
      downloadProgress = 1;
      show('已保存到相册');
      await loadDownloads();
    } catch (e) {
      show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  /// 图文 / 实况：逐条保存，成功后登记后端下载任务，失败条目单独计数。
  Future<void> _downloadAlbum(
      Map<String, dynamic> video, List<dynamic> images, String mode) async {
    final author = asMap(video['author'])['nickname']?.toString() ?? '';
    final firstUrl = images.isEmpty ? '' : _imageUrl(images.first);
    var failed = 0;
    var savedImages = 0;
    var savedLive = 0;
    await _run(() async {
      for (var i = 0; i < images.length; i++) {
        final imageUrl = _imageUrl(images[i]);
        if (imageUrl.isNotEmpty) {
          try {
            if (await downloadImageToGallery(imageUrl,
                    index: i, headers: _mediaHeaders(video)) !=
                null) {
              savedImages++;
            }
          } catch (_) {
            failed++;
          }
        }
        final liveUrl = _livePhotoUrl(images[i]);
        if (liveUrl.isNotEmpty) {
          try {
            if (await downloadMediaToGallery(liveUrl,
                    prefix: 'live_$i', headers: _mediaHeaders(video)) !=
                null) {
              savedLive++;
            }
          } catch (_) {
            failed++;
          }
        }
      }
      if (savedImages == 0 && savedLive == 0) {
        show('保存失败：图片/实况素材未能写入相册，请检查网络或相册权限');
        return;
      }
      final parts = <String>['$savedImages 张图片'];
      if (savedLive > 0) parts.add('$savedLive 个实况视频');
      if (failed > 0) parts.add('$failed 项失败');
      show('已保存 ${parts.join('、')}');
      try {
        await _api().post('/api/download/task', {
          'videoUrl': firstUrl,
          'title': video['title'] ?? '',
          'platform': video['platform'] ?? '',
          'coverUrl': video['coverUrl'] ?? '',
          'author': author,
          'mode': mode,
        });
        await loadDownloads();
      } catch (_) {
        // 登记失败不影响已保存的内容。
      }
    });
  }

  String _imageUrl(dynamic value) {
    if (value is String) return value.trim();
    final map = asMap(value);
    final candidates = <dynamic>[
      map['url'],
      map['imageUrl'],
      map['downloadUrl'],
      map['src'],
      map['originUrl'],
      map['origin_url'],
      ...asList(map['urlList']),
      ...asList(map['url_list']),
    ];
    for (final item in candidates) {
      final text = (item ?? '').toString().trim();
      if (text.startsWith('http')) return text;
    }
    return '';
  }

  Map<String, String> _mediaHeaders(Map<String, dynamic> video) {
    final platform = (video['platform'] ?? '').toString().toLowerCase();
    final headers = _videoHeaders(video);
    if (platform.contains('小红书') || platform.contains('xiaohongshu')) {
      headers['Referer'] = 'https://www.xiaohongshu.com/';
    } else if (platform.contains('抖音') || platform.contains('douyin')) {
      headers['Referer'] = 'https://www.douyin.com/';
    }
    return headers;
  }

  String _livePhotoUrl(dynamic value) {
    final map = asMap(value);
    final candidates = <dynamic>[
      map['livePhotoUrl'],
      map['live_photo_url'],
      map['liveVideoUrl'],
      map['live_video_url'],
      map['videoUrl'],
    ];
    for (final item in candidates) {
      final text = (item ?? '').toString().trim();
      if (text.startsWith('http')) return text;
    }
    return '';
  }

  Map<String, String> _videoHeaders(Map<String, dynamic> video) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'Accept': '*/*',
    };
    var referer = (video['referer'] ?? '').toString().trim();
    final platform = (video['platform'] ?? '').toString();
    final url = (video['downloadUrl'] ?? video['videoUrl'] ?? '').toString();
    final bili = platform.contains('哔哩') ||
        platform.toLowerCase().contains('bili') ||
        url.contains('bilivideo') ||
        url.contains('bilibili');
    if (referer.isEmpty && bili) referer = 'https://www.bilibili.com/';
    if (bili) {
      headers['Accept'] = 'video/mp4,video/*;q=0.9,*/*;q=0.8';
      headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
    }
    if (referer.isNotEmpty) {
      headers['Referer'] = referer;
      final origin = Uri.tryParse(referer);
      if (origin != null && origin.hasScheme && origin.host.isNotEmpty) {
        headers['Origin'] = '${origin.scheme}://${origin.host}';
      }
    }
    return headers;
  }

  void openDownloadItem(Map<String, dynamic> item) {
    final author = (item['author'] ?? '').toString();
    final url = (item['videoUrl'] ?? '').toString();
    parsed = {
      'title': item['title'] ?? '未命名视频',
      'platform': item['platform'] ?? '视频',
      'coverUrl': item['coverUrl'] ?? '',
      'author': {'nickname': author.isEmpty ? '未知作者' : author},
      'videoUrl': url,
      'downloadUrl': url,
      'sourceUrl': url,
      'taskId': item['id'],
      'fromDownload': true,
    };
    go('preview');
  }

  /// 解析当前可播放地址：优先本地缓存，其次远端直链。
  String resolvePlayUrl({String? overrideUrl}) {
    final video = parsed;
    if (video == null) return overrideUrl ?? '';
    final remote = (overrideUrl ?? video['downloadUrl'] ?? video['videoUrl'] ?? '').toString();
    final id = (video['taskId'] ?? '').toString();
    final local = id.isNotEmpty ? (localVideos[id] ?? '') : '';
    return local.isNotEmpty ? local : (localVideos[remote] ?? remote);
  }

  Map<String, String> playHeaders() {
    final video = parsed;
    if (video == null) return {};
    return _videoHeaders(video);
  }

  void playCurrent() {
    final video = parsed;
    if (video == null) {
      show('请先解析视频');
      return;
    }
    final url = resolvePlayUrl();
    if (url.isEmpty) {
      show('没有可播放的地址');
      return;
    }
    playingUrl = url;
    playingTitle = (video['title'] ?? '播放').toString();
    // 下载详情由 PreviewPage 内嵌播放，不跳转
    if (video['fromDownload'] == true) {
      notifyListeners();
      return;
    }
    go('player');
  }

  void playItem(Map<String, dynamic> item) {
    openDownloadItem(item);
  }

  Future<void> pay() async {
    if (!loggedIn) {
      openLogin();
      return;
    }
    await _run(() async {
      final created =
          await _api().post('/api/order/create', {'planType': selectedPlan});
      final order = asMap(created['order']);
      final pay = asMap(created['pay']);
      final channel = (pay['channel'] ?? '').toString();
      if (channel == 'gateway' || channel == 'wechat') {
        final h5Url = (pay['h5Url'] ?? '').toString();
        final codeUrl = (pay['codeUrl'] ?? '').toString();
        final orderId = int.tryParse('${order['id']}') ?? 0;
        if (orderId <= 0) throw ApiException('下单失败');
        if (h5Url.isNotEmpty) {
          show('正在打开支付页面…');
          final ok = await launchUrl(Uri.parse(h5Url),
              mode: LaunchMode.externalApplication);
          if (!ok) throw ApiException('无法打开支付页面');
          payWatchOrderId = orderId;
          notifyListeners();
          _watchPay(orderId);
          show('支付完成后返回 App，会员会自动开通');
        } else if (codeUrl.isNotEmpty) {
          payQr = codeUrl;
          payWatchOrderId = orderId;
          notifyListeners();
          _watchPay(orderId);
        } else {
          throw ApiException(
              (pay['error'] ?? '支付下单失败，请检查后台网关/微信配置').toString());
        }
      } else if (channel == 'mock') {
        final orderId = order['id'];
        if (orderId == null) throw ApiException('下单失败');
        await _api().post('/api/pay/mock-success', {'orderId': orderId});
        await loadUser();
        show('开通成功');
      } else {
        throw ApiException((pay['error'] ?? '支付通道不可用').toString());
      }
    });
  }

  Future<void> onResume() async {
    final id = payWatchOrderId;
    if (id == null || !loggedIn) return;
    try {
      final data = await _api().get('/api/order/$id');
      if (data['payStatus'] == 'paid') {
        payQr = null;
        payWatchOrderId = null;
        await loadUser();
        show('支付成功，会员已开通');
      }
    } catch (_) {}
  }

  void closePayQr() {
    payQr = null;
    payWatchOrderId = null;
    notifyListeners();
  }

  Future<void> _watchPay(int orderId) async {
    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (payWatchOrderId != orderId) return;
      try {
        final data = await _api().get('/api/order/$orderId');
        if (data['payStatus'] == 'paid') {
          payQr = null;
          payWatchOrderId = null;
          await loadUser();
          show('支付成功，会员已开通');
          return;
        }
      } catch (_) {}
    }
    if (payWatchOrderId == orderId) {
      show('还没收到支付结果，可稍后在「我的」查看会员状态');
    }
  }

  Future<void> loadAffiliate() async {
    affiliate = await _api().get('/api/affiliate/info');
    promotions = asList(affiliate?['promotions']);
    if (promotions.isEmpty) {
      promotions = asList(affiliate?['invitees']);
    }
    invitees = promotions;
    promotionTotal = (affiliate?['promotionTotal'] as num?)?.toInt() ??
        (affiliate?['inviteeCount'] as num?)?.toInt() ??
        promotions.length;
    commissions = asList(affiliate?['commissions']);
    try {
      final acc = await _api().get('/api/affiliate/account');
      account = acc.containsKey('id') ? acc : null;
    } catch (_) {
      account = null;
    }
    notifyListeners();
  }

  Future<void> loadPromotionsAll() async {
    await _run(() async {
      final data =
          await _api().get('/api/affiliate/promotions?limit=500&offset=0');
      promotionsAll = asList(data['list'] ?? data);
      promotionTotal = (data['total'] as num?)?.toInt() ?? promotionsAll.length;
    });
  }

  Future<void> pickWithdrawQr() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    await _run(() async {
      payAccount = await _api().upload(file.path);
      show('收款二维码已选择');
    });
  }

  Future<void> saveAccount() async {
    final value = payAccount.trim();
    if (payChannel == 'wechat') {
      if (!value.startsWith('http')) {
        show('请上传微信收款二维码');
        return;
      }
    } else if (value.length < 2) {
      show('请先填写支付宝账号');
      return;
    }
    await _run(() async {
      await _api().post(
          '/api/affiliate/account', {'channel': payChannel, 'account': value});
      final acc = await _api().get('/api/affiliate/account');
      account = acc.containsKey('id') ? acc : null;
      show('收款方式已保存，之后不能修改');
    });
  }

  Future<void> withdraw() async {
    final amount = double.tryParse(withdrawAmount) ?? 0;
    if (amount < 10) {
      show('提现金额需满 10 元');
      return;
    }
    await _run(() async {
      await _api().post('/api/affiliate/withdraw', {'amount': amount});
      showWithdraw = false;
      withdrawAmount = '';
      show('提现申请已提交');
      await loadAffiliate();
      await loadUser();
    });
  }

  Future<void> pickImage() async {
    if (fbImages.length >= 3) {
      show('最多上传 3 张截图');
      return;
    }
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    await _run(() async {
      final url = await _api().upload(file.path);
      fbImages = [...fbImages, url];
    });
  }

  Future<void> submitFeedback() async {
    if (fbContent.trim().length < 5) {
      show('请先填写反馈内容');
      return;
    }
    await _run(() async {
      final body = <String, dynamic>{
        'type': fbType,
        'content': fbContent.trim(),
        'images': fbImages,
      };
      if (fbEmail.trim().isNotEmpty) body['email'] = fbEmail.trim();
      await _api().post('/api/feedback/submit', body);
      fbContent = '';
      fbEmail = '';
      fbImages = [];
      show('反馈已提交，感谢您的建议');
      back();
    });
  }

  void _enter(String id) {
    if (!loggedIn) return;
    switch (id) {
      case 'home':
        _run(() async {
          await loadUser();
          await loadDownloads();
        }, quiet: true);
      case 'downloads':
        _run(loadDownloads, quiet: true);
      case 'me':
        _run(loadUser, quiet: true);
      case 'vip':
        _run(() async {
          await loadUser();
          await loadPublic();
        }, quiet: true);
      case 'member':
        _run(loadUser, quiet: true);
      case 'affiliate':
        _run(() async {
          await loadUser();
          await loadAffiliate();
        }, quiet: true);
      case 'affiliate_promotions':
        _run(loadPromotionsAll, quiet: true);
    }
  }

  Future<void> loadPublic() async {
    final all = await _api().get('/api/config/all');
    final map = asMap(all['map']);
    texts = map.map((k, v) => MapEntry(k, v.toString()));
    final list = asList(await _api().get('/api/plans'));
    if (list.isNotEmpty) plans = list;
    notifyListeners();
  }

  Future<void> loadUser() async {
    user = await _api().get('/api/user/info');
    notifyListeners();
  }

  Future<void> clearCache() async {
    if (downloading) {
      show('下载中，请稍后再清理');
      return;
    }
    final freed = await cacheBytes();
    await clearAppCache();
    localVideos.clear();
    show(freed > 0 ? '已清理 ${formatCacheSize(freed)}' : '没有可清理的缓存');
  }

  Future<void> loadDownloads() async {
    await _loadHiddenDownloads();
    final all = asList(await _api().get('/api/download/list'));
    downloads =
        all.where((e) => !hiddenDownloadIds.contains('${e['id']}')).toList();
    notifyListeners();
    cacheDownloadCovers(downloads);
  }

  /// 仅删除 App 本地展示记录；云端与相册不动。
  Future<bool> deleteDownload(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return false;
    final remote = (item['videoUrl'] ?? '').toString();
    hiddenDownloadIds.add(id);
    await _saveHiddenDownloads();
    downloads = downloads.where((e) => '${e['id']}' != id).toList();
    localVideos.remove(id);
    if (remote.isNotEmpty) localVideos.remove(remote);
    await removeCover('dl_$id');
    show('已删除本地记录，相册与云端不受影响');
    notifyListeners();
    return true;
  }

  Future<void> _loadHiddenDownloads() async {
    final p = await prefs();
    final uid = '${user?['id'] ?? ''}';
    final key = uid.isEmpty ? 'hidden_downloads' : 'hidden_downloads_$uid';
    hiddenDownloadIds = (p.getStringList(key) ?? []).toSet();
  }

  Future<void> _saveHiddenDownloads() async {
    final p = await prefs();
    final uid = '${user?['id'] ?? ''}';
    final key = uid.isEmpty ? 'hidden_downloads' : 'hidden_downloads_$uid';
    await p.setStringList(key, hiddenDownloadIds.toList());
  }

  Api _api() => Api(baseUrl, token);

  Future<void> _run(Future<void> Function() block, {bool quiet = false}) async {
    if (!quiet) {
      busy = true;
      notifyListeners();
    }
    try {
      await block();
      if (quiet) notifyListeners();
    } catch (e) {
      if (e.toString().contains('登录已过期')) await logout();
      show(e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (!quiet) {
        busy = false;
        notifyListeners();
      }
    }
  }
}
