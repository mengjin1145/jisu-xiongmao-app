# 极速熊猫 Flutter 客户端

极速熊猫移动客户端，支持视频解析、普通视频下载、多图图文保存、小红书实况图片与短视频播放/保存，以及 B 站视频防盗链请求。

## 构建

```powershell
cd D:\phpstudy_pro\WWW\jisoxmao\flutter
flutter pub get
flutter build apk --debug
flutter build apk --release
```

Debug 和 Release 使用不同的 Android 包名，可以同时安装：

- Release：`com.jisuxiongmao.jisuxiongmao`
- Debug：`com.jisuxiongmao.jisuxiongmao.debug`

APK 输出目录：`build\\app\\outputs\\flutter-apk\\`

## 媒体类型

- 普通视频：优先使用后端返回的 `video_cdn_url`，为空时回退 `video_url`。
- 图文：读取 `image_list[].url`，支持批量保存图片。
- 实况：读取 `image_list[].live_photo_url`，支持点击播放并保存图片和短视频。
- B 站：播放和下载请求会携带 `Referer`、`Origin` 等请求头。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
