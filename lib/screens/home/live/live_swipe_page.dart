import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/feed/recommend_feed_page.dart'; // 引入之前的抖音同款物理引擎
import 'package:flutter_live/store/user_store.dart'; // 引入你的 UserStore

// 引入你刚刚改造好的真实直播间
import 'real_live_page.dart';

class LiveSwipePage extends StatefulWidget {
  final List<dynamic> initialRoomList; // 房间列表数据
  final int initialIndex; // 点击进来的初始位置

  const LiveSwipePage({super.key, required this.initialRoomList, this.initialIndex = 0});

  @override
  State<LiveSwipePage> createState() => _LiveSwipePageState();
}

class _LiveSwipePageState extends State<LiveSwipePage> {
  late PageController _pageController;
  late int _currentIndex;
  late List<dynamic> _roomList;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _roomList = List.from(widget.initialRoomList); // 复制一份列表用于后续加载更多
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 可选：如果滑到了底部，加载下一页房间列表
  void _loadMoreRooms() {
    // TODO: 请求接口获取下一页直播间并 setState 加入 _roomList
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 直播流底色必须黑
      resizeToAvoidBottomInset: false,
      body: PageView.builder(
        controller: _pageController,
        // physics: const HeavyScrollPhysics(), // 🟢 使用重度阻尼滑动
        physics: const TikTokPagePhysics(),
        scrollDirection: Axis.vertical,
        // 🟢 关键：上下滑动
        dragStartBehavior: DragStartBehavior.down,
        // 🟢 关键：使用之前短视频那套丝滑弹簧引擎
        itemCount: _roomList.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // 预加载逻辑：滑到倒数第二个时去请求新房间
          if (index >= _roomList.length - 2) {
            _loadMoreRooms();
          }
        },
        itemBuilder: (context, index) {
          final roomInfo = _roomList[index];

          final bool isCurrentView = (_currentIndex == index);

          // 🟢 在滑动页里解析出当前房间的类型
          int dbRoomType = int.tryParse(roomInfo['roomType']?.toString() ?? "0") ?? 0;
          const Map<int, LiveRoomType> dbValueToEnum = {0: LiveRoomType.normal, 1: LiveRoomType.voice, 2: LiveRoomType.music, 3: LiveRoomType.video};

          // 渲染直播间
          return RealLivePage(
            isCurrentView: isCurrentView,
            pageController: _pageController,
            // 👈 传给刚才改造好的参数
            roomId: roomInfo['roomId']?.toString() ?? roomInfo['id']?.toString() ?? "",
            initialRoomData: roomInfo,
            // 传入初始数据用于展示封面
            // 🟢 把解析好的房间类型传给真的直播间
            roomType: dbValueToEnum[dbRoomType] ?? LiveRoomType.normal,

            // 下面这些是你本身需要传的当前登录用户信息
            userId: UserStore.to.userId,
            userName: UserStore.to.nickname,
            avatarUrl: UserStore.to.avatar,
            level: UserStore.to.userLevel,
            monthLevel: UserStore.to.monthLevel,
            isHost: false, // 观众上下滑刷直播，当然不是 Host
          );
        },
      ),
    );
  }
}

class HeavyScrollPhysics extends PageScrollPhysics {
  const HeavyScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  HeavyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HeavyScrollPhysics(parent: buildParent(ancestor));
  }

  // 修改位移缩放比例 (默认是1.0，越小滑动越费力)
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset * 0.55);
  }
}