import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

// 1. 最外层的 App 壳子，配置主题和初始路由
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hardcore Mixer',
      theme: ThemeData(primarySwatch: Colors.blue),
      // 🚀 核心改造：首次启动，先进入一个入口过渡页，给 iOS GPU 喘息的时间！
      home: const EntryPage(),
    );
  }
}

// ==========================================
// 🚪 2. 新增的入口过渡页 (拯救冷启动黑屏的终极武器)
// ==========================================
class EntryPage extends StatelessWidget {
  const EntryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('系统初始化就绪', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            backgroundColor: Colors.blueAccent,
          ),
          onPressed: () {
            // 点击按钮时，App 绝对已经 100% 处于 Active 活跃状态，显卡随叫随到！
            // 此时推入视频页面，就等同于热重载的环境！
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VideoMixerPage(),
              ),
            );
          },
          child: const Text(
            '🔥 进入 9 路视频监控',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📺 3. 核心业务页面（加入了调试探针和模拟按钮）
// ==========================================
class VideoMixerPage extends StatefulWidget {
  const VideoMixerPage({Key? key}) : super(key: key);

  @override
  State<VideoMixerPage> createState() => _VideoMixerPageState();
}

class _VideoMixerPageState extends State<VideoMixerPage> {
  final HardcoreMixer _mixer = HardcoreMixer();
  bool _isReady = false;
  int _currentCount = 9;

  final List<String> _allUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_1.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_2.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_3.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_4.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_5.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_6.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_6.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_6.mp4",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/test_stream/anchor_6.mp4",
  ];

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  // 🚀 将你 UI 上的 Flex 布局配置，翻译成底层的数学坐标 [x, y, width, height] (0.0~1.0)
  List<List<double>> _generateLayouts(int count) {
    if (count == 3) {
      // 🚀 特殊处理你的 3 人不对称布局：左 1，右上下 2
      return [
        [0.0, 0.0, 0.5, 1.0], // 左侧大屏
        [0.5, 0.0, 0.5, 0.5], // 右上小屏
        [0.5, 0.5, 0.5, 0.5], // 右下小屏
      ];
    }

    // 其他对称布局，完美匹配你的 _buildFlexGrid 逻辑！
    List<int> rowConfigs = [];
    switch (count) {
      case 2: rowConfigs = [2]; break;
      case 4: rowConfigs = [2, 2]; break;
      case 5: rowConfigs = [2, 3]; break;
      case 6: rowConfigs = [3, 3]; break;
      case 7: rowConfigs = [3, 4]; break;
      case 8: rowConfigs = [4, 4]; break;
      case 9: rowConfigs = [3, 3, 3]; break;
      default: rowConfigs = [1];
    }

    List<List<double>> layouts = [];
    int numRows = rowConfigs.length;
    double h = 1.0 / numRows;

    for (int i = 0; i < numRows; i++) {
      int cols = rowConfigs[i];
      double w = 1.0 / cols;
      double y = i * h;
      for (int j = 0; j < cols; j++) {
        double x = j * w;
        layouts.add([x, y, w, h]);
      }
    }
    return layouts;
  }

  void _initEngine() async {
    await _mixer.initialize();
    if (!mounted) return;
    setState(() {
      _isReady = true;
    });
    _switchLayout(9);
  }

  void _switchLayout(int count) {
    setState(() {
      _currentCount = count;
    });
    // 计算出对应的坐标系！
    List<List<double>> layouts = _generateLayouts(count);
    _mixer.playStreams(_allUrls.sublist(0, count), layouts);
  }

  void _simulateHotReload() async {
    print("🔄 [Flutter] 模拟深度热重载（彻底销毁重建底层渲染引擎）...");
    setState(() {
      _isReady = false;
    });

    // 🚀 核心关键：彻底干掉旧的底层的原生解码器和渲染器，释放死锁资源！
    _mixer.dispose();

    // 等待 0.5 秒，让苹果底层的垃圾回收系统把显卡垃圾清理干净
    await Future.delayed(const Duration(milliseconds: 500));

    print("🔄 [Flutter] 重新走一遍热重载时的全流程...");
    _initEngine(); // 重新向原生发起连麦请求
  }

  @override
  void dispose() {
    _mixer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('大厂同款 测试', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.grey[900],
        actions: [
          // 🚀 在右上角加一个红色的紧急按钮
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 30),
            onPressed: _simulateHotReload,
            tooltip: '模拟热重载',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(8, (index) {
                int count = index + 2;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _currentCount == count ? Colors.blue : Colors.grey[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(60, 40)
                  ),
                  onPressed: () => _switchLayout(count),
                  child: Text('$count人'),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: _isReady && _mixer.textureId != null
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Texture(textureId: _mixer.textureId!),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.0)),
                    child: _buildMockDynamicGrid(_currentCount),
                  )
                ],
              )
                  : const Center(
                child: Text('Texture 已卸载 / 等待中...', style: TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (保留你原来的 _buildMockDynamicGrid 和 _mockCell 方法...)
  Widget _buildMockDynamicGrid(int count) {
    switch (count) {
      case 2: return _buildFlexGrid([2]);
      case 3:
        return Row(
          children: [
            Expanded(flex: 1, child: _mockCell(0)),
            Container(width: 1, color: Colors.white),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(flex: 1, child: _mockCell(1)),
                  Container(height: 1, color: Colors.white),
                  Expanded(flex: 1, child: _mockCell(2)),
                ],
              ),
            ),
          ],
        );
      case 4: return _buildFlexGrid([2, 2]);
      case 5: return _buildFlexGrid([2, 3]);
      case 6: return _buildFlexGrid([3, 3]);
      case 7: return _buildFlexGrid([3, 4]);
      case 8: return _buildFlexGrid([4, 4]);
      case 9: return _buildFlexGrid([3, 3, 3]);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildFlexGrid(List<int> rowConfigs) {
    List<Widget> rows = [];
    int pIndex = 0;
    for (int i = 0; i < rowConfigs.length; i++) {
      int cols = rowConfigs[i];
      List<Widget> rowChildren = [];
      for (int j = 0; j < cols; j++) {
        rowChildren.add(Expanded(child: _mockCell(pIndex)));
        if (j < cols - 1) rowChildren.add(Container(width: 1, color: Colors.white));
        pIndex++;
      }
      rows.add(Expanded(child: Row(children: rowChildren)));
      if (i < rowConfigs.length - 1) rows.add(Container(height: 1, color: Colors.white));
    }
    return Column(children: rows);
  }

  Widget _mockCell(int index) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 4, bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
              child: Text('主播通道 $index', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 🔌 4. Flutter 与底层 C++/GPU 的终极通信桥梁
// ==========================================
class HardcoreMixer {
  static const MethodChannel _channel = MethodChannel('hardcore_mixer');

  int? textureId;

  // 1. 初始化引擎，向 iOS 申请一块 GPU 共享显存
  Future<void> initialize() async {
    textureId = await _channel.invokeMethod('initialize');
    print("✅ [底层引擎] 初始化成功，分配 TextureID: $textureId");
  }

  // 2. 传入有效视频流，瞬间点火播放
  Future<void> playStreams(List<String> urls, List<List<double>> layouts) async {
    print("🚀 [底层引擎] 正在推入 ${urls.length} 路流及对应坐标...");
    await _channel.invokeMethod('playStreams', {
      'urls': urls,
      'layouts': layouts, // 🚀 发送坐标
    });
  }

  // 3. 页面退出或热重载时，核平销毁底层资源
  Future<void> dispose() async {
    print("💥 [底层引擎] 正在销毁 C++ 线程和 GPU 显存...");
    await _channel.invokeMethod('dispose');
    textureId = null;
  }
}