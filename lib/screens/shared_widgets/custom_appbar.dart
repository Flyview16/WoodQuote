import 'package:flutter/material.dart';
import 'package:wood_quote/utils/colors.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: neutral,
      surfaceTintColor: neutral,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black12,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.carpenter, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'WoodQuote',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
