import 'package:flutter/material.dart';

class DocScreen extends StatelessWidget {
  const DocScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Start on '文件' tab as per your primary screenshot
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('我的文档', style: TextStyle(color: Colors.black)),
          bottom: const TabBar(
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: '文章'),
              Tab(text: '文件'),
              Tab(text: '图片'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildArticleList(), // Tab 1: 文章
            _buildFileList(),    // Tab 2: 文件
            _buildImageList(),   // Tab 3: 图片
          ],
        ),
      ),
    );
  }

  // --- TAB 1: 文章 (Articles) ---
  Widget _buildArticleList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => _buildDocCard(
        title: "2020年高考延期一个月...",
        subtitle: "2020-03-31 14:13",
        tag: "公开",
        icon: Icons.article,
        iconColor: Colors.blue,
      ),
    );
  }

  // --- TAB 2: 文件 (Files) ---
  Widget _buildFileList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => _buildDocCard(
        title: "null_20200727111344_814.docx",
        subtitle: "2020-08-25 08:26",
        tag: "公开",
        icon: Icons.description,
        iconColor: Colors.deepPurpleAccent,
      ),
    );
  }

  // --- TAB 3: 图片 (Images) ---
  Widget _buildImageList() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(10),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildImageCard("新建相册", null, isCreate: true),
        _buildImageCard("辟邪剑法", "4张"),
        _buildImageCard("独孤九剑", "26张"),
      ],
    );
  }

  // Reusable card for Article and File lists
  Widget _buildDocCard({required String title, required String subtitle, String? tag, required IconData icon, required Color iconColor}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(icon, size: 45, color: iconColor),
            if (tag != null)
              Positioned( // Changed 'Position:' to 'Positioned'
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  color: Colors.orange,
                  child: Text(
                    tag,
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ),
              ),
          ],
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }

  // Reusable card for the Image Grid
  Widget _buildImageCard(String title, String? count, {bool isCreate = false}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              alignment: Alignment.center, // Fix: Use 'alignment' instead of 'center'
              child: Icon(
                isCreate ? Icons.add_photo_alternate_outlined : Icons.image,
                size: 50,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (count != null) Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(count, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}