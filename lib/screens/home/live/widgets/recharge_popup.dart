import 'package:flutter/material.dart';

import '../../../../tools/HttpUtil.dart';

class RechargePopup extends StatefulWidget {
  const RechargePopup({Key? key}) : super(key: key);

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RechargePopup(),
    );
  }

  @override
  State<RechargePopup> createState() => _RechargePopupState();
}

class _RechargePopupState extends State<RechargePopup> {
  final List<Map<String, int>> _rechargeItems = [
    {'amount': 10, 'diamond': 100},
    {'amount': 50, 'diamond': 500},
    {'amount': 100, 'diamond': 1000},
    {'amount': 300, 'diamond': 3000},
    {'amount': 500, 'diamond': 5000},
    {'amount': 1000, 'diamond': 10000},
  ];

  int _selectedIndex = 0;
  bool _isSubmitting = false;
  bool _isSuccess = false; // 🟢 新增：标记是否成功

  Future<void> _handleRecharge() async {
    if (_isSubmitting || _isSuccess) return;

    setState(() => _isSubmitting = true);

    final selectedItem = _rechargeItems[_selectedIndex];

    try {
      // 1. 调用接口
      await HttpUtil().post(
        '/api/recharge/create',
        data: {
          'amount': selectedItem['amount'],
          'diamondCount': selectedItem['diamond'],
          'payType': 1,
        },
      );

      if (mounted) {
        // ✅ 2. 接口成功：切换到成功状态 (按钮变绿)
        setState(() {
          _isSubmitting = false;
          _isSuccess = true;
        });

        debugPrint("充值成功，等待关闭...");

        // ✅ 3. 延迟 1.5 秒，让用户看到“充值成功”的按钮变化
        await Future.delayed(const Duration(milliseconds: 1000));

        // ✅ 4. 关闭窗口
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("充值失败: $e");
      // 失败时，我们可以弹一个 Dialog 或者用 SnackBar (注意：失败时通常希望用户重试，所以SnackBar虽然被挡住，但如果是系统级错误可以接受，或者用 dialog)
      if (mounted) {
        setState(() => _isSubmitting = false);
        // 如果一定要在弹窗上显示报错，可以用由 Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("充值失败"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("确定"))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF161823),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "充值中心",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildNoticeBar(),
          const SizedBox(height: 20),
          Expanded(child: _buildAmountGrid()),
          _buildSubmitButton(), // 🟢 按钮逻辑已修改
        ],
      ),
    );
  }

  Widget _buildNoticeBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined, color: Color(0xFFFFD700), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "温馨提示：理性消费，量力而行。未成年人请在监护人陪同下操作。",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _rechargeItems.length,
      itemBuilder: (context, index) {
        final item = _rechargeItems[index];
        final isSelected = _selectedIndex == index;

        return GestureDetector(
          // 如果正在提交或已成功，禁止切换金额
          onTap: (_isSubmitting || _isSuccess) ? null : () => setState(() => _selectedIndex = index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFFFFD700).withOpacity(0.15) : Colors.white.withOpacity(0.05),
              border: Border.all(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                  width: 1.5
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        "${item['diamond']}",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 2),
                    const Text("钻", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    "¥${item['amount']}",
                    style: TextStyle(
                        color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
                        fontSize: 12
                    )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🟢 核心修改：按钮根据状态变化颜色和文字
  Widget _buildSubmitButton() {
    // 根据状态决定背景色
    Color bgColor = const Color(0xFFFFD700); // 默认金色
    Color fgColor = const Color(0xFF161823); // 默认黑色字

    if (_isSuccess) {
      bgColor = Colors.green; // 成功变绿
      fgColor = Colors.white; // 成功白字
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isSuccess) ? null : _handleRecharge,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          // 如果成功了，取消按钮点击态，让它看起来像个静态提示条
          disabledBackgroundColor: _isSuccess ? Colors.green : Colors.grey,
          disabledForegroundColor: _isSuccess ? Colors.white : Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: _buildButtonChild(),
      ),
    );
  }

  // 🟢 构建按钮内部内容
  Widget _buildButtonChild() {
    if (_isSubmitting) {
      return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)
      );
    }

    if (_isSuccess) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text("充值成功", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return const Text(
        "立即充值",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
    );
  }
}