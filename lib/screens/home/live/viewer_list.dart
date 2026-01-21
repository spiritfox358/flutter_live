import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ViewerList extends StatelessWidget {
  const ViewerList();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(
                    'https://picsum.photos/seed/${888 + index}/200',
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            "4",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
