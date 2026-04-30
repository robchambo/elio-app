import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../services/notification_service.dart';

// ─────────────────────────────────────────────
// NotificationPrefsScreen
// Toggle push notification categories on/off.
// ─────────────────────────────────────────────

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  final NotificationService _notifications = NotificationService.instance;
  NotificationPrefs _prefs = NotificationPrefs.defaults();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await _notifications.getNotificationPrefs();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _isLoading = false;
    });
  }

  Future<void> _updatePref(NotificationPrefs updated) async {
    setState(() => _prefs = updated);
    await _notifications.updateNotificationPrefs(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: ElioColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notifications', style: ElioText.headingLarge),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ElioColors.terracotta))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose which notifications you receive.',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                ),
                const SizedBox(height: 24),

                _buildToggle(
                  icon: Icons.calendar_today_outlined,
                  title: 'Weekly meal reminder',
                  subtitle: 'A nudge to plan your meals for the week',
                  value: _prefs.weeklyReminder,
                  onChanged: (v) => _updatePref(_prefs.copyWith(weeklyReminder: v)),
                ),
                const SizedBox(height: 12),

                _buildToggle(
                  icon: Icons.warning_amber_rounded,
                  title: 'Restock reminder',
                  subtitle: 'Reminder to check your pantry for low items',
                  value: _prefs.restockReminder,
                  onChanged: (v) => _updatePref(_prefs.copyWith(restockReminder: v)),
                ),
                const SizedBox(height: 12),

                _buildToggle(
                  icon: Icons.lightbulb_outline,
                  title: 'Tips & updates',
                  subtitle: 'New features, cooking tips, and app updates',
                  value: _prefs.tipsAndUpdates,
                  onChanged: (v) => _updatePref(_prefs.copyWith(tipsAndUpdates: v)),
                ),
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.rule),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: ElioColors.terracotta),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                    fontSize: 15,
                    color: ElioColors.espresso,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: ElioColors.terracotta,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
