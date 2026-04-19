import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import 'generate_test_user_sig.dart';

class TRTCManager {
  static final TRTCManager _instance = TRTCManager._internal();
  factory TRTCManager() => _instance;
  TRTCManager._internal();

  late TRTCCloud trtcCloud;
  bool _isInitialized = false;

  TRTCCloudListener? _listener;

  // 🔴 页面 UI 回调事件
  Function(String userId, bool available)? onRemoteVideoAvailable;
  Function(String userId)? onRemoteUserEnterRoom;
  Function(String userId)? onRemoteUserLeaveRoom;

  // 🚀🚀🚀 核心防碰撞锁：记录底层 C++ 引擎是否正在清理上一个房间
  bool _isExiting = false;

  Future<void> init() async {
    if (_isInitialized) return;
    trtcCloud = (await TRTCCloud.sharedInstance())!;

    _listener = TRTCCloudListener(
      onEnterRoom: (result) {
        debugPrint(result > 0 ? "✅ [TRTC] 进房成功，耗时: $result ms" : "❌ [TRTC] 进房失败: $result");
      },
      onExitRoom: (reason) {
        debugPrint("🚪 [TRTC] 底层已彻底退出上一个房间, reason: $reason");
        // 🚀 引擎清理完毕，释放防撞锁！
        _isExiting = false;
      },
      onRemoteUserEnterRoom: (userId) {
        debugPrint("🙋‍♂️ [TRTC] 远端用户进房: $userId");
        if (onRemoteUserEnterRoom != null) onRemoteUserEnterRoom!(userId);
      },
      onRemoteUserLeaveRoom: (userId, reason) {
        debugPrint("👋 [TRTC] 远端用户离房: $userId, reason: $reason");
        if (onRemoteUserLeaveRoom != null) onRemoteUserLeaveRoom!(userId);
      },
      onUserVideoAvailable: (userId, available) {
        debugPrint("📹 [TRTC] 用户 $userId 视频流状态变为: $available");
        if (onRemoteVideoAvailable != null) onRemoteVideoAvailable!(userId, available);
      },
      onError: (errCode, errMsg) {
        debugPrint("🚨 [TRTC] 内部错误: $errCode, $errMsg");
      },
    );

    trtcCloud.registerListener(_listener!);
    _isInitialized = true;
  }

  /// 进入 TRTC 房间
  Future<void> enterRoom({
    required String userId,
    required String roomId,
    required bool isHost,
  }) async {
    await init();

    // 🚀🚀🚀 终极防撞处理：如果底层还在退出上个房间，强制排队等待！
    // 最大等待 1 秒 (10 * 100ms)，绝不让进房请求被系统吃掉！
    int waitCount = 0;
    while (_isExiting && waitCount < 10) {
      debugPrint("⏳ [TRTC] 引擎正在打扫上个房间的战场，排队等待 100ms...");
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    _isExiting = false; // 兜底解锁

    String userSig = GenerateTestUserSig.genTestSig(userId);

    TRTCParams params = TRTCParams();
    params.sdkAppId = GenerateTestUserSig.sdkAppId;
    params.userId = userId;
    params.userSig = userSig;

    // 安全处理房间号
    int? parsedRoomId = int.tryParse(roomId);
    if (parsedRoomId != null && parsedRoomId > 0) {
      params.roomId = parsedRoomId;
      params.strRoomId = "";
    } else {
      params.roomId = 0;
      params.strRoomId = roomId;
    }

    params.role = isHost ? TRTCRoleType.anchor : TRTCRoleType.audience;

    debugPrint("🚀 [TRTC 发起进房] userId: $userId, 房号: $roomId, 角色: ${isHost ? '主播' : '观众'}");
    trtcCloud.enterRoom(params, TRTCAppScene.live);

    if (isHost) {
      trtcCloud.startLocalAudio(TRTCAudioQuality.music);
    }
  }

  /// 退出房间并清理
  Future<void> exitRoom() async {
    if (!_isInitialized) return;

    // 🚀 上锁：标记正在退出
    _isExiting = true;
    debugPrint("🚪 [TRTC] 发起退出房间请求，开始拦截后续进房...");

    // 1. 彻底清空回调，防止底层状态变化时去刷新已经销毁的旧页面（导致红屏报错）
    onRemoteVideoAvailable = null;
    onRemoteUserEnterRoom = null;
    onRemoteUserLeaveRoom = null;

    // 2. 停止所有音视频采集，释放麦克风和摄像头
    trtcCloud.stopLocalAudio();
    trtcCloud.stopLocalPreview();

    // 3. 退出房间（这句调完后，底层会异步处理，直到触发 onExitRoom 回调才算真正结束）
    trtcCloud.exitRoom();
  }

  // ==========================================
  // ⚔️ 跨房连麦 (PK) 专属方法
  // ==========================================

  /// 发起跨房连麦 (PK)
  Future<void> startPK({required String targetUserId, required String targetRoomId}) async {
    if (!_isInitialized) return;

    Map<String, dynamic> param = {
      "userId": targetUserId,
    };

    // 🚀 安全处理房间号：防止超长房号转 int 失败
    int? parsedRoomId = int.tryParse(targetRoomId);
    if (parsedRoomId != null && parsedRoomId > 0) {
      param["roomId"] = parsedRoomId;
    } else {
      param["strRoomId"] = targetRoomId;
    }

    String jsonParam = jsonEncode(param);
    debugPrint("⚔️ [TRTC 发起PK] 呼叫参数: $jsonParam");

    // 调用底层 API
    trtcCloud.connectOtherRoom(jsonParam);
  }

  /// 结束跨房连麦 (PK)
  Future<void> stopPK() async {
    if (!_isInitialized) return;
    debugPrint("🛑 [TRTC 结束PK] 断开跨房连麦");
    trtcCloud.disconnectOtherRoom();
  }

  // ==========================================
  // Widget 渲染区
  // ==========================================
  Widget getLocalVideoWidget() {
    return TRTCCloudVideoView(
      key: const ValueKey("TRTCLocalView"),
      onViewCreated: (viewId) {
        trtcCloud.startLocalPreview(true, viewId);
      },
    );
  }

  Widget getRemoteVideoWidget(String targetUserId) {
    return TRTCCloudVideoView(
      key: ValueKey("TRTCRemoteView_$targetUserId"),
      onViewCreated: (viewId) {
        trtcCloud.startRemoteView(targetUserId, TRTCVideoStreamType.big, viewId);
      },
    );
  }

  void startLocalPreview(int viewId) {
    trtcCloud.startLocalPreview(true, viewId);
  }

  void startRemoteView(String userId, int viewId) {
    trtcCloud.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
  }

  /// 观众上麦：把身份切换为主播，并开启音频推流
  void startCoHosting() {
    if (!_isInitialized) return;
    debugPrint("🎤 [TRTC] 观众发起上麦，切换身份为 Anchor...");

    // 1. 切换身份为“主播”
    trtcCloud.switchRole(TRTCRoleType.anchor);

    // 2. 打开麦克风
    trtcCloud.startLocalAudio(TRTCAudioQuality.speech);

    // 注意：这里的摄像头会在 UI 渲染 getLocalVideoWidget() 时自动打开，不需要重复调用
  }

  /// 观众下麦：关闭音视频，把身份切回观众
  void stopCoHosting() {
    if (!_isInitialized) return;
    debugPrint("🛑 [TRTC] 观众下麦，切回 Audience...");

    // 1. 关闭摄像头和麦克风
    trtcCloud.stopLocalPreview();
    trtcCloud.stopLocalAudio();

    // 2. 切回观众身份，停止向房间内推流
    trtcCloud.switchRole(TRTCRoleType.audience);
  }
}