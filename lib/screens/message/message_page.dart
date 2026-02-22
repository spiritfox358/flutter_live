import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  // --- 模拟顶部状态/直播数据 (15条数据，完美体验左右滑动) ---
  final List<Map<String, dynamic>> _stories = [
    {
      "isMe": true,
      "name": "限时日常",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "badge": null,
    },
    {
      "isMe": false,
      "name": "小太阳",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "badge": "连线中",
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "小魔女",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "badge": "连线中",
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "榜一大哥",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "badge": "直播中",
      "isLive": true,
    },
    {
      "isMe": false,
      "name": "深夜食堂",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "badge": "直播中",
      "isLive": true,
    },
    {
      "isMe": false,
      "name": "前端带师",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "badge": null,
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "花开富贵",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "badge": "连线中",
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "一生平安",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "badge": null,
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "Flutter狂热粉",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "badge": "直播中",
      "isLive": true,
    },
    {
      "isMe": false,
      "name": "熬夜冠军",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "badge": null,
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "一杯美式",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "badge": "连线中",
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "多肉葡萄",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "badge": null,
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "星空探索者",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "badge": "直播中",
      "isLive": true,
    },
    {
      "isMe": false,
      "name": "不吃香菜",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "badge": null,
      "isLive": false,
    },
    {
      "isMe": false,
      "name": "快乐小狗",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "badge": "连线中",
      "isLive": false,
    },
  ];

  // --- 模拟会话列表数据 (30条数据，涵盖各种状态) ---
  final List<Map<String, dynamic>> _chats = [
    {
      "isSystem": true,
      "name": "互动消息",
      "avatar": "",
      "subtitle": "2026拥抱钱行 赞了你的视频",
      "time": "16分钟前",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "2026拥抱钱行",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "我有个小号关注你了，你回关一下，...",
      "time": "刚刚",
      "isMuted": false,
      "hasError": true, // 发送失败的红色感叹号
    },
    {
      "isSystem": false,
      "name": "fox",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "向你问候晚上好",
      "time": "5分钟前",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "安静呀",
      "avatarText": "安", // 文字头像
      "avatarBg": const Color(0xFFF6A623),
      "subtitle": "如愿🐟: 👍👍👍",
      "time": "17:44",
      "isMuted": true, // 消息免打扰（铃铛划线）
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "霸业🐻",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "我们已互相关注，可以开始聊天了",
      "time": "11:34",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "深圳软件｜联盟搞AI🍁",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "我们已互相关注，可以开始聊天了",
      "time": "昨天 22:35",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "清醒哥的直播售后...",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "🐱: [分享视频]",
      "time": "昨天 21:24",
      "isMuted": true,
      "hasError": false,
    },
    // 以下为追加的数据，凑满 30 条
    {
      "isSystem": false,
      "name": "Flutter开发日常",
      "avatarText": "F",
      "avatarBg": const Color(0xFF2196F3),
      "subtitle": "这个组件的源码你看懂了吗？",
      "time": "昨天 18:30",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "AA建材批发老王",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "老板，上次那批货什么时候结一下尾款",
      "time": "昨天 14:20",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "深夜emo导师",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "今晚网抑云时间到了，连麦吗",
      "time": "昨天 01:15",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "不吃香菜",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "明天中午吃什么？",
      "time": "星期二",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "早起失败",
      "avatarText": "早",
      "avatarBg": const Color(0xFFE91E63),
      "subtitle": "定了8个闹钟还是没醒...",
      "time": "星期二",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "摸鱼达人",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "快来看这个搞笑视频哈哈哈哈",
      "time": "星期一",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "法外狂徒张三",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "你的律师函已经寄出",
      "time": "星期一",
      "isMuted": false,
      "hasError": true,
    },
    {
      "isSystem": false,
      "name": "一生平安",
      "avatarText": "平",
      "avatarBg": const Color(0xFF4CAF50),
      "subtitle": "[图片]",
      "time": "星期一",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "花开富贵",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "早上好，认同的请转发！",
      "time": "星期日",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "KFC疯狂星期四",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "V我50，聆听我的复仇计划",
      "time": "上周四",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "只因你太美",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "鸡你太美~",
      "time": "上周三",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "ikun",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "小黑子露出鸡脚了吧",
      "time": "上周三",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "云游四海",
      "avatarText": "云",
      "avatarBg": const Color(0xFF9C27B0),
      "subtitle": "今天在西藏，风景真不错",
      "time": "上周二",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "快乐小狗",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "汪汪汪！",
      "time": "02-15",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "熬夜冠军",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "我还能再战三百回合",
      "time": "02-14",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "一杯美式",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "今天也是打工人的一天",
      "time": "02-12",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "多肉葡萄",
      "avatarText": "多",
      "avatarBg": const Color(0xFF673AB7),
      "subtitle": "喜茶出新品了，去尝尝吗？",
      "time": "02-10",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "星空探索者",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "今晚有流星雨！",
      "time": "02-08",
      "isMuted": true,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "前端工程师",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "CSS居中到底有几种写法？",
      "time": "02-05",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "UI设计师",
      "avatar": "https://images.xxapi.cn/images/head/2867952553.jpg",
      "subtitle": "这个红色不够红，麻烦调一下",
      "time": "02-01",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "产品经理",
      "avatarText": "PM",
      "avatarBg": const Color(0xFFFF5722),
      "subtitle": "稍微改个小需求，马上要上线",
      "time": "01-28",
      "isMuted": false,
      "hasError": true, // 发送失败标识
    },
    {
      "isSystem": false,
      "name": "老张",
      "avatar": "https://images.xxapi.cn/images/head/6623257184.jpg",
      "subtitle": "下班喝一杯去？",
      "time": "01-20",
      "isMuted": false,
      "hasError": false,
    },
    {
      "isSystem": false,
      "name": "测试工程师",
      "avatar": "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
      "subtitle": "提了3个紧急Bug，抓紧看一下",
      "time": "01-15",
      "isMuted": false,
      "hasError": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        // 左侧菜单图标
        leading: IconButton(
          icon: Icon(Icons.menu, color: iconColor, size: 28),
          onPressed: () {},
        ),
        // 标题
        title: Text(
          "消息",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // 右侧操作栏
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: iconColor, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: iconColor, size: 26),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. 顶部状态/连线栏 (横向滑动)
          SliverToBoxAdapter(
            child: _buildStoriesArea(isDark),
          ),

          // 2. 会话列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildChatItem(_chats[index], isDark),
              childCount: _chats.length,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 顶部状态栏区域 (天生支持横向滑动)
  // ==========================================
  Widget _buildStoriesArea(bool isDark) {
    return Container(
      height: 110,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      // 🟢 这里的 scrollDirection: Axis.horizontal 就决定了它可以丝滑地左右滑动！
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return _buildStoryItem(story, isDark);
        },
      ),
    );
  }

  // 构建单个状态/连线 Item
  Widget _buildStoryItem(Map<String, dynamic> story, bool isDark) {
    final bool isMe = story['isMe'];
    final String name = story['name'];
    final String avatar = story['avatar'];
    final String? badge = story['badge'];
    final bool isLive = story['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像区
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 渐变圆环 (如果不是自己)
                if (!isMe)
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF2C55), Color(0xFFFE2B54), Color(0xFFFF7B93)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),

                // 头像本体
                Container(
                  width: isMe ? 60 : 58, // 有圆环时头像小一点
                  height: isMe ? 60 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                    image: DecorationImage(image: CachedNetworkImageProvider(avatar), fit: BoxFit.cover),
                  ),
                ),

                // 我的日常：右下角绿色加号
                if (isMe)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),

                // 连线中 / 直播中 Badge
                if (badge != null)
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLive
                              ? [const Color(0xFFFF2C55), const Color(0xFFFF5270)] // 直播中渐变红
                              : [const Color(0xFFFF2C55), const Color(0xFFE02080)], // 连线中渐变紫
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 名字
          SizedBox(
            width: 70, // 限制名字宽度，防止名字太长挤压排版
            child: Text(
              name,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 会话列表区域
  // ==========================================
  Widget _buildChatItem(Map<String, dynamic> chat, bool isDark) {
    final bool isSystem = chat['isSystem'];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.grey[500];

    return InkWell(
      onTap: () {}, // 点击进入聊天
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. 头像区
            _buildChatAvatar(chat),
            const SizedBox(width: 14),

            // 2. 右侧文本区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶行：名字 + 免打扰 + 时间
                  // 顶行：名字 + 免打扰 + 时间
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐
                    children: [
                      // 1. 左侧区：名字和免打扰图标 (用 Expanded 撑开，把时间挤到最右边)
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat['name'],
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis, // 名字过长自动省略号
                              ),
                            ),
                            if (chat['isMuted'])
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.notifications_off_outlined, color: Colors.grey[400], size: 14),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12), // 名字和时间之间至少留点空隙

                      // 2. 右侧区：时间 (自然靠最右侧)
                      Text(
                        chat['time'],
                        style: TextStyle(color: subTextColor, fontSize: 12),
                        textAlign: TextAlign.right, // 确保文本自身右对齐
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 底行：发送失败标识 + 副标题
                  Row(
                    children: [
                      // 发送失败的红色感叹号
                      if (chat['hasError'])
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.error, color: Color(0xFFFF2C55), size: 16),
                        ),

                      // 消息预览文字
                      Expanded(
                        child: Text(
                          chat['subtitle'],
                          style: TextStyle(color: subTextColor, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建会话头像 (包含系统图标、文字头像、普通图片头像的分发)
  Widget _buildChatAvatar(Map<String, dynamic> chat) {
    if (chat['isSystem']) {
      // 互动消息的粉红渐变图标
      return Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF5270), Color(0xFFFE2B54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.messenger, color: Colors.white, size: 28), // 替代原生图标
        ),
      );
    }

    if (chat['avatarText'] != null) {
      // 纯色背景 + 文字头像 (如：安静呀 -> 安)
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: chat['avatarBg'] as Color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            chat['avatarText'],
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // 常规图片头像
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: chat['avatar'],
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.person)),
      ),
    );
  }
}