import 'package:flutter/material.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 定义背景色，和你之前的直播间深色风格保持一致
    const backgroundColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("赞赏支持", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              // 2. 感谢信卡片
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    Text(
                      "致亲爱的用户",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "这款 App 是我利用业余时间一点一滴搭建起来的。从每一行代码到每一个交互动画，都倾注了我的热情与心血。\n\n"
                          "能够在这个茫茫网络中与你相遇，并为你带来哪怕一点点的快乐或便利，都是我最大的荣幸。\n\n"
                          "如果你喜欢这个 App，或者想支持服务器的维护费用，欢迎请我喝杯咖啡 ☕️。你的支持是我持续更新的最大动力！",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6, // 增加行高，阅读更舒适
                      ),
                      textAlign: TextAlign.justify, // 两端对齐
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // 3. 收款码区域
              const Text(
                "请使用微信扫一扫",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white, // 二维码最好放在白色底上，防止识别错误
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  // 🟢 请替换为你自己的收款码图片路径
                  // 建议把图片放在 assets/images/qr_code.jpg
                  child: Image.asset(
                    "assets/images/qr_code.jpg",
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    // 如果暂时没有图片，可以用下面这个 errorBuilder 显示占位符
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Text("请放入收款码图片", style: TextStyle(color: Colors.black54)),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // 4. 底部 Slogan
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("Made with ", style: TextStyle(color: Colors.grey)),
                  Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  Text(" by 独立开发者", style: TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}