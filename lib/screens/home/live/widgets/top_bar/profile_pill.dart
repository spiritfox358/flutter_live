import 'package:flutter/material.dart';

import '../profile/live_user_profile_popup.dart';

class ProfilePill extends StatelessWidget {
  final String name;
  final String avatar;
  final int anchorId;

  const ProfilePill({super.key, required this.name, required this.avatar, required this.anchorId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Map<String, dynamic>? userMap = {};
              userMap["userId"] = anchorId;
              LiveUserProfilePopup.show(context, userMap);
            },
            child: CircleAvatar(radius: 18, backgroundImage: NetworkImage(avatar)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4), // 👈 上边距
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Text("0本场点赞", style: TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
