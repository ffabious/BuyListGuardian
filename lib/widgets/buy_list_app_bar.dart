import 'package:flutter/material.dart';

class BuyListAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BuyListAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icon/icon.png',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 12),
          const Text('Buy List Guardian'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
