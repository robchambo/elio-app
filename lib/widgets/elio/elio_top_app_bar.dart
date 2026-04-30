// lib/widgets/elio/elio_top_app_bar.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// 64px top app bar: elio wordmark left, profile icon right.
class ElioTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;

  const ElioTopAppBar({super.key, this.onProfileTap});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    // Scaffold gives the appBar slot extra height equal to the status-bar
    // inset, so we wrap with SafeArea(bottom:false) to push the wordmark /
    // profile row below the system status bar (battery, signal, clock).
    // Without this, the 64px bar sits flush at y=0 and overlaps the status
    // bar on devices with a non-zero top inset (most Samsungs).
    return Material(
      color: ElioColors.offWhite,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'elio',
                style: ElioTextStyles.sectionHeadingStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ElioColors.terracotta,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined,
                    color: ElioColors.espresso, size: 28),
                onPressed: onProfileTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
