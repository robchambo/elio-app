import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// NotificationService
// Handles FCM push notifications for Elio.
// Manages token lifecycle, topic subscriptions,
// and notification preferences in Firestore.
//
// Usage: call NotificationService.instance.init()
// once at startup (after Firebase.initializeApp).
// ─────────────────────────────────────────────

/// Top-level background message handler required by FCM.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op placeholder — background messages handled by system tray.
  // Add processing logic here if needed in the future.
  debugPrint('[Elio] Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialised = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Global scaffold messenger key — set from MaterialApp to show snackbars.
  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  // ─── Topic constants ──────────────────────────────────────────────

  static const String topicWeeklyReminder = 'weekly_meal_reminder';
  static const String topicRestockReminder = 'restock_reminder';
  static const String topicTipsAndUpdates = 'tips_and_updates';

  // ─── Initialisation ───────────────────────────────────────────────

  /// Initialise FCM: request permissions, register token, set up listeners.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions (Android 13+ requires runtime permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Elio] Notification permission denied');
      return;
    }

    // Get and save the initial FCM token
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('[Elio] Failed to get FCM token: $e');
    }

    // Listen for token refreshes
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // ─── Token management ─────────────────────────────────────────────

  /// Save the FCM token to Firestore under the current user's document.
  Future<void> _saveToken(String token) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final tokenRef = _db
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token.hashCode.toString());

      await tokenRef.set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Elio] Failed to save FCM token: $e');
    }
  }

  // ─── Foreground messages ──────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'Elio';

    // Show a snackbar via the global scaffold messenger key
    final messenger = scaffoldMessengerKey?.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(title)),
      );
    }
  }

  // ─── Topic subscriptions ──────────────────────────────────────────

  /// Subscribe to an FCM topic.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[Elio] Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from an FCM topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[Elio] Failed to unsubscribe from topic $topic: $e');
    }
  }

  /// Sync topic subscriptions based on current notification preferences.
  Future<void> syncTopicSubscriptions() async {
    final prefs = await getNotificationPrefs();

    if (prefs.weeklyReminder) {
      await subscribeToTopic(topicWeeklyReminder);
    } else {
      await unsubscribeFromTopic(topicWeeklyReminder);
    }

    if (prefs.restockReminder) {
      await subscribeToTopic(topicRestockReminder);
    } else {
      await unsubscribeFromTopic(topicRestockReminder);
    }

    if (prefs.tipsAndUpdates) {
      await subscribeToTopic(topicTipsAndUpdates);
    } else {
      await unsubscribeFromTopic(topicTipsAndUpdates);
    }
  }

  // ─── Notification preferences ─────────────────────────────────────

  /// Get notification preferences from Firestore.
  /// Returns defaults (all true) if no prefs are saved or user not logged in.
  Future<NotificationPrefs> getNotificationPrefs() async {
    final uid = _currentUid;
    if (uid == null) return NotificationPrefs.defaults();

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null || !data.containsKey('notificationPrefs')) {
        return NotificationPrefs.defaults();
      }

      final prefsMap = data['notificationPrefs'] as Map<String, dynamic>;
      return NotificationPrefs.fromMap(prefsMap);
    } catch (e) {
      debugPrint('[Elio] Failed to get notification prefs: $e');
      return NotificationPrefs.defaults();
    }
  }

  /// Update notification preferences in Firestore and sync topic subscriptions.
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'notificationPrefs': prefs.toMap(),
      });
      await syncTopicSubscriptions();
    } catch (e) {
      debugPrint('[Elio] Failed to update notification prefs: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Returns the current user's UID, or null if not logged in.
  String? get _currentUid {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return user.uid;
  }

  /// Clean up listeners.
  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}

// ─── NotificationPrefs model ──────────────────────────────────────────────────

class NotificationPrefs {
  final bool weeklyReminder;
  final bool restockReminder;
  final bool tipsAndUpdates;

  const NotificationPrefs({
    required this.weeklyReminder,
    required this.restockReminder,
    required this.tipsAndUpdates,
  });

  /// Defaults: all notifications enabled.
  factory NotificationPrefs.defaults() => const NotificationPrefs(
        weeklyReminder: true,
        restockReminder: true,
        tipsAndUpdates: true,
      );

  factory NotificationPrefs.fromMap(Map<String, dynamic> map) {
    return NotificationPrefs(
      weeklyReminder: map['weeklyReminder'] as bool? ?? true,
      restockReminder: map['restockReminder'] as bool? ?? true,
      tipsAndUpdates: map['tipsAndUpdates'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'weeklyReminder': weeklyReminder,
        'restockReminder': restockReminder,
        'tipsAndUpdates': tipsAndUpdates,
      };

  NotificationPrefs copyWith({
    bool? weeklyReminder,
    bool? restockReminder,
    bool? tipsAndUpdates,
  }) {
    return NotificationPrefs(
      weeklyReminder: weeklyReminder ?? this.weeklyReminder,
      restockReminder: restockReminder ?? this.restockReminder,
      tipsAndUpdates: tipsAndUpdates ?? this.tipsAndUpdates,
    );
  }
}
