import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.padding =
        const EdgeInsets.only(right: 16, left: 8, top: 22, bottom: 12),
  });

  final String title;
  final VoidCallback? onSeeAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text('عرض الكل',
                  style: TextStyle(fontSize: 13, color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}
