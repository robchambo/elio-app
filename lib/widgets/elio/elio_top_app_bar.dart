// lib/widgets/elio/elio_top_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';

/// 64px top app bar: elio wordmark left, profile icon right.
class ElioTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;

  const ElioTopAppBar({super.key, this.onProfileTap});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: ElioColors.offWhite,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'elio',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ElioColors.amber,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: ElioColors.navy, size: 28),
            onPressed: onProfileTap,
          ),
        ],
      ),
    );
  }
}
