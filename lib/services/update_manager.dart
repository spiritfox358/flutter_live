import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../tools/HttpUtil.dart'; // 你的网络工具

class UpdateManager {
  /// 检查更新的主入口
  static Future<void> checkUpdate(BuildContext context, {bool showToast = false}) async {
    if (!Platform.isAndroid) return;

    try {
      // 1. 获取当前版本
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. 请求接口
      final res = await HttpUtil().get("/api/app/check_update");
      if (res == null) return;

      int serverCode = res['versionCode'] ?? 0;
      String versionName = res['versionName'] ?? "";
      String content = res['content'] ?? "优化了一些体验";
      String url = res['downloadUrl'] ?? "";
      bool isForce = res['isForce'] ?? false;

      // 3. 对比版本
      if (serverCode > currentCode) {
        if (context.mounted) {
          _showUpdateDialog(context, versionName, content, url, isForce);
        }
      } else {
        if (showToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("当前已是最新版本")));
        }
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  /// 显示更新确认弹窗
  static void _showUpdateDialog(
      BuildContext context, String version, String content, String url, bool isForce) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) {
        return PopScope(
          canPop: !isForce,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text("发现新版本 $version", style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Text(content, style: const TextStyle(color: Colors.white70)),
            ),
            actions: [
              if (!isForce)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("暂不更新", style: TextStyle(color: Colors.white38)),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // 关闭确认框
                  _showDownloadProgressDialog(context, url, isForce); // 打开下载进度框
                },
                child: const Text("立即更新", style: TextStyle(color: Colors.pinkAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示下载进度弹窗
  static void _showDownloadProgressDialog(BuildContext context, String url, bool isForce) {
    // 使用 ValueNotifier 更新进度条，避免 setState 的麻烦
    ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

    showDialog(
      context: context,
      barrierDismissible: false, // 下载中禁止点击背景关闭
      builder: (ctx) {
        // 只有非强制更新才允许点击返回键取消下载
        return PopScope(
          canPop: !isForce,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text("正在下载...", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(Colors.pinkAccent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${(value * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    // 开始下载任务
    _startDownload(url, (received, total) {
      if (total != -1) {
        progressNotifier.value = received / total;
      }
    }).then((savePath) {
      // 下载完成
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度框
        if (savePath != null) {
          _installApk(savePath); // 安装
        }
      }
    }).catchError((e) {
      // 下载出错
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度框
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下载失败: $e")));
      }
    });
  }

  /// 执行下载逻辑 (Dio)
  static Future<String?> _startDownload(String url, Function(int, int) onProgress) async {
    try {
      // 获取临时目录
      Directory? dir = await getExternalStorageDirectory(); // Android 专用
      // 如果获取不到外部存储（极少数情况），回退到 cache
      dir ??= await getTemporaryDirectory();

      String savePath = "${dir.path}/app_update.apk";

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.bytes), // 确保是二进制流
      );

      return savePath;
    } catch (e) {
      throw e;
    }
  }

  static void _installApk(String path) {
    debugPrint("开始安装: $path");
    // 打开文件，Android 会自动识别 .apk 并拉起安装器
    OpenFile.open(path);
  }
}