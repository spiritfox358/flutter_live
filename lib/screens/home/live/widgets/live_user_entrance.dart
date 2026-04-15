import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart'; // 请确保路径正确

// 🚀 1. 引入刚才我们建好的全局单例信号站！
import 'effect_player/user_entrance_effect_layer.dart';

/// 进场数据模型
class EntranceEvent {
  final String userName;
  final int level;
  final int monthLevel;
  final String avatarUrl;
  final String? frameUrl;

  EntranceEvent({required this.userName, required this.level, required this.monthLevel, required this.avatarUrl, this.frameUrl});
}

class LiveUserEntrance extends StatefulWidget {
  const LiveUserEntrance({super.key});

  @override
  State<LiveUserEntrance> createState() => LiveUserEntranceState();
}

class LiveUserEntranceState extends State<LiveUserEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  final Queue<EntranceEvent> _entranceQueue = Queue();
  bool _isBannerShowing = false;
  EntranceEvent? _currentEvent;

  bool _isInterrupted = false; // 🚀 标记是否被打断

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = Tween<Offset>(begin: const Offset(1.5, 0), end: const Offset(1.5, 0)).animate(_controller);

    // 🚀 监听特权进场的全局打断信号
    EntranceSignal.isSpecialPlaying.addListener(_onSpecialPlayingChanged);
  }

  @override
  void dispose() {
    // 销毁时移除监听
    EntranceSignal.isSpecialPlaying.removeListener(_onSpecialPlayingChanged);
    EntranceSignal.active.value = false;
    _controller.dispose();
    super.dispose();
  }

  // 🚨 接收到特权信号变化时的回调
  void _onSpecialPlayingChanged() {
    if (EntranceSignal.isSpecialPlaying.value) {
      // 🚨 特权进场来了！如果屏幕上正挂着普通横幅，立刻打断它
      if (_isBannerShowing && _currentEvent != null) {
        _interruptCurrent();
      }
    } else {
      // 🟢 特权进场结束了，如果队伍里还有人，继续开始播
      if (_entranceQueue.isNotEmpty && !_isBannerShowing) {
        _playNext();
      }
    }
  }

  // 🚀 核心退让逻辑
  void _interruptCurrent() {
    _isInterrupted = true; // 触发中断标志，防止后续流程继续跑
    _controller.stop(); // 停止当前横幅的一切运动

    if (_currentEvent != null) {
      // 🚀 完美兜底：将刚露个脸就被打断的普通用户，重新塞回队列的【最前面】！
      // 保证他不丢出场机会，等大佬播完，他紧跟着继续出场。
      _entranceQueue.addFirst(_currentEvent!);
    }

    if (mounted) {
      setState(() {
        // 立刻从停住的那个位置，以极快的速度向左滑出屏幕 (-1.5)
        _animation = Tween<Offset>(
          begin: _animation.value,
          end: const Offset(-1.5, 0),
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
      });

      // 切换为极速退场模式 (300毫秒)
      _controller.duration = const Duration(milliseconds: 300);
      _controller.reset();
      _controller.forward().then((_) {
        _isBannerShowing = false;
        _currentEvent = null;
        // 退场完毕，恢复原本的进出场速度
        _controller.duration = const Duration(milliseconds: 800);
      });
    }
  }

  /// 外部调用此方法添加进场消息
  void addEvent(EntranceEvent event) {
    _entranceQueue.add(event);
    // 🚀 只有在“当前没在播横幅” 且 “大佬特权横幅没在播” 时，才能启动播放
    if (!_isBannerShowing && !EntranceSignal.isSpecialPlaying.value) {
      _playNext();
    }
  }

  Future<void> _playNext() async {
    // 🚨 队伍空了，或者正在被大佬特权霸屏，直接跳出
    if (_entranceQueue.isEmpty || EntranceSignal.isSpecialPlaying.value) {
      if (_entranceQueue.isEmpty) {
        EntranceSignal.active.value = false;
      }
      return;
    }

    EntranceSignal.active.value = true;
    _isBannerShowing = true;
    _isInterrupted = false; // 发车前，重置中断标志

    final event = _entranceQueue.removeFirst();

    // 🟢 第 1 道防线：初始检查
    if (!mounted) return;

    setState(() {
      _currentEvent = event;
      _animation = Tween<Offset>(begin: const Offset(1.5, 0), end: const Offset(0, 0))
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    });

    _controller.reset();
    try {
      await _controller.forward();
    } catch (e) {
      // 防止动画在中途被 dispose 抛出异常
      return;
    }

    // 🟢 第 2 道防线：动画1播放完后检查
    if (!mounted || _isInterrupted) return;

    int waitTimeMs = 2000;
    int waitedMs = 0;
    while (waitedMs < waitTimeMs) {
      await Future.delayed(const Duration(milliseconds: 100));
      // 🟢 第 3 道防线：在漫长的等待循环中，随时检查是否被销毁！
      if (!mounted || _isInterrupted) return;
      waitedMs += 100;
    }

    // 🚀🚀🚀 最致命的第 4 道防线：等待彻底结束后，操作控制器前必须检查！
    if (!mounted) return;

    setState(() {
      _animation = Tween<Offset>(begin: const Offset(0, 0), end: const Offset(-1.5, 0))
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuart));
    });

    _controller.reset(); // 有了上面的 mounted 保护，这里绝对安全了
    try {
      await _controller.forward();
    } catch (e) {
      return;
    }

    // 🟢 第 5 道防线：动画2播放完后检查
    if (!mounted || _isInterrupted) return;

    _isBannerShowing = false;
    _currentEvent = null;

    await Future.delayed(const Duration(milliseconds: 200));

    // 🟢 第 6 道防线：准备递归调用自己前检查
    if (!mounted || _isInterrupted) return;

    _playNext();
  }

  @override
  Widget build(BuildContext context) {
    // 保持你原有的 build 代码不变
    if (_currentEvent == null) return const SizedBox();

    return SlideTransition(
      position: _animation,
      child: Container(
        margin: const EdgeInsets.only(left: 11),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12.5),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LevelBadge(level: _currentEvent!.level, monthLevel: _currentEvent!.monthLevel),
            const SizedBox(width: 6),
            Text(
              "${_currentEvent!.userName} 加入了直播间",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.1),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}