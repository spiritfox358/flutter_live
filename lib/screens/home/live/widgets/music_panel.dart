import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MusicModel {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String url;

  MusicModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.url,
  });
}

class MusicPanel extends StatefulWidget {
  const MusicPanel({super.key});

  @override
  State<MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<MusicPanel> {
  // 单例播放器（为了简单，这里直接用静态变量，保证退出面板歌还在放）
  // 实际项目中建议放在 Provider/GetX 中管理
  static final AudioPlayer _player = AudioPlayer();

  // 当前播放的歌曲 ID
  static String? _currentId;
  static bool _isPlaying = false;

  // 模拟歌单数据
  final List<MusicModel> _songs = [
    MusicModel(
      id: "1",
      title: "嘉宾",
      artist: "张远",
      coverUrl: "https://p1.music.126.net/1gNCbmf55X5k50m_5p_55g==/109951165416986566.jpg",
      url: "https://music.163.com/song/media/outer/url?id=1488966763.mp3",
    ),
    MusicModel(
      id: "2",
      title: "白月光与朱砂痣",
      artist: "大籽",
      coverUrl: "https://p2.music.126.net/s8rC0Xn4X7X_x_x_x_x_xQ==/109951165596009369.jpg",
      url: "https://music.163.com/song/media/outer/url?id=1808492017.mp3",
    ),
    MusicModel(
      id: "3",
      title: "哪里都是你",
      artist: "队长",
      coverUrl: "https://p1.music.126.net/K_x_x_x_x_x_x_x_x_x_xQ==/109951163401479866.jpg",
      url: "https://music.163.com/song/media/outer/url?id=486814412.mp3",
    ),
    MusicModel(
      id: "4",
      title: "起风了",
      artist: "买辣椒也用券",
      coverUrl: "https://p2.music.126.net/diGAyEmpymX8G7JcnElncQ==/109951163699673355.jpg",
      url: "https://music.163.com/song/media/outer/url?id=1330348068.mp3",
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 监听播放状态变化，刷新 UI
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          // 如果播放结束，重置状态
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      }
    });
  }

  Future<void> _playMusic(MusicModel music) async {
    try {
      if (_currentId == music.id) {
        // 点击同一首：切换 播放/暂停
        if (_isPlaying) {
          await _player.pause();
        } else {
          await _player.play();
        }
      } else {
        // 点击不同首：切歌
        _currentId = music.id;
        await _player.setUrl(music.url);
        await _player.play();
      }
    } catch (e) {
      print("播放失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: const Center(
              child: Text(
                "点歌列表",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 列表
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                final isCurrent = _currentId == song.id;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(song.coverUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: isCurrent && _isPlaying
                        ? Container(
                      color: Colors.black54,
                      child: const Icon(Icons.graphic_eq, color: Colors.pinkAccent),
                    )
                        : null,
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: isCurrent ? Colors.pinkAccent : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  trailing: InkWell(
                    onTap: () => _playMusic(song),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isCurrent && _isPlaying ? Colors.pinkAccent : Colors.white24,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        color: isCurrent && _isPlaying ? Colors.pinkAccent.withOpacity(0.1) : null,
                      ),
                      child: Text(
                        isCurrent && _isPlaying ? "暂停" : "播放",
                        style: TextStyle(
                          color: isCurrent && _isPlaying ? Colors.pinkAccent : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}