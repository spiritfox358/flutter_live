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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    // 初始化状态：在屏幕右侧之外 (1.5倍宽度处)
    _animation = Tween<Offset>(begin: const Offset(1.5, 0), end: const Offset(1.5, 0)).animate(_controller);
  }

  @override
  void dispose() {
    // 🚀 2. 安全兜底：如果组件销毁，强制熄灭信号灯，防止横幅永远卡在下面
    EntranceSignal.active.value = false;
    _controller.dispose();
    super.dispose();
  }

  /// 外部调用此方法添加进场消息
  void addEvent(EntranceEvent event) {
    _entranceQueue.add(event);
    if (!_isBannerShowing) {
      _playNext();
    }
  }

  Future<void> _playNext() async {
    // 🚀🚀🚀 核心逻辑 1：队列空了，说明刚才最后一个人已经滑出屏幕了。熄灭信号灯！
    if (_entranceQueue.isEmpty) {
      EntranceSignal.active.value = false;
      return;
    }

    // 🚀🚀🚀 核心逻辑 2：只要准备播下一个人，强制点亮/保持信号灯！礼物横幅立刻下沉避让！
    EntranceSignal.active.value = true;

    _isBannerShowing = true;
    final event = _entranceQueue.removeFirst();

    if (mounted) {
      setState(() {
        _currentEvent = event;
        // 🟢 进场动画：从右侧 (1.5) 滑动到显示位置 (0)
        _animation = Tween<Offset>(
          begin: const Offset(1.5, 0),
          end: const Offset(0, 0),
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
      });
    }

    _controller.reset();
    await _controller.forward();

    // 停留展示时间
    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      setState(() {
        // 🟢 离场动画：从当前位置 (0) 向左滑动出屏幕 (-1.5)
        _animation = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(-1.5, 0),
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuart));
      });
    }

    _controller.reset();
    await _controller.forward();

    _isBannerShowing = false;

    // 稍微延迟一点处理下一个 (这 200ms 的间隙里，信号灯依然是亮的，这很好！避免了连着进场时横幅上下鬼畜抖动)
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      // 递归调用：如果没人了，下一次进去就会触发上面的 isEmpty 逻辑，熄灭信号灯。
      _playNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有当前事件，渲染空容器
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