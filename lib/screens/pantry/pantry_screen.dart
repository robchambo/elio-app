// lib/screens/pantry/pantry_screen.dart
//
// Sprint 16 Phase 3 — standalone Pantry screen.
//
// Body-only (hosted inside ElioAppScaffold via AppShell). Subscribes to the
// `users/{uid}/inventory` subcollection and renders:
//   • ElioHeroHeading — "what did you / pick up?"
//   • Two ElioBentoCards (Scan receipt / Scan barcode) opening ScannerScreen
//   • A full-width "Pantry Builder" row that opens PantryBuilderSheet via
//     showDialog (CLAUDE.md rule: never nest a modal bottom sheet inside
//     another bottom sheet).
//   • Three ElioTierRows — Perishables / Always Have / Almost Always Have.
//     Tapping a row expands it inline and collapses the others.
//
// The legacy pantry tab inside ProfileScreen still exists and is untouched;
// it will be removed when the Account restructure lands in Phase 6.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_bento_card.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_tier_row.dart';
import '../../widgets/pantry_builder_sheet.dart';
import '../scanner/scanner_screen.dart';

/// Tier keys as used in Firestore `users/{uid}/inventory/{id}.tier`.
const String _tierPerishable = 'perishable';
const String _tierAlwaysHave = 'alwaysHave';
const String _tierAlmostAlwaysHave = 'almostAlwaysHave';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

/// Test seam: when set, [_PantryScreenState._subscribeInventory] is skipped
/// and these items are used as the initial inventory. Lets widget tests
/// exercise the tap/long-press behaviour without booting FirebaseAuth.
@visibleForTesting
List<Map<String, dynamic>>? debugPantryInitialItems;

/// Test seam: when set, tier mutations call this instead of FirestoreService.
/// Receives (itemId, action) where action's `type` is one of
/// `updateTier` (with `tier`), `updateExpiry` (with `expiryDate`),
/// or `delete`.
@visibleForTesting
void Function(String itemId, Map<String, dynamic> action)?
    debugPantryMutationOverride;

class _PantryScreenState extends State<PantryScreen> {
  final FirestoreService _firestore = FirestoreService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invSub;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  /// Which tier is currently expanded (single-open-at-a-time). `null` = all collapsed.
  String? _expandedTier;

  @override
  void initState() {
    super.initState();
    final seed = debugPantryInitialItems;
    if (seed != null) {
      _items = List<Map<String, dynamic>>.from(seed);
      _loading = false;
      return;
    }
    _subscribeInventory();
  }

  @override
  void dispose() {
    _invSub?.cancel();
    super.dispose();
  }

  void _subscribeInventory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventory');
    _invSub = query.snapshots().listen((snap) {
      if (!mounted) return;
      final items = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        DateTime? expiry;
        final rawExpiry = data['expiryDate'];
        if (rawExpiry is Timestamp) {
          expiry = rawExpiry.toDate();
        } else if (rawExpiry is String) {
          expiry = DateTime.tryParse(rawExpiry);
        }
        items.add({
          'id': doc.id,
          'name': data['name'] as String? ?? '',
          'tier': data['tier'] as String? ?? _tierAlwaysHave,
          'runningLow': data['runningLow'] as bool? ?? false,
          'category': data['category'] as String?,
          if (expiry != null) 'expiryDate': expiry.toIso8601String(),
        });
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  // ─── Tier filtering ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _itemsForTier(String tier) {
    final filtered = _items.where((i) => i['tier'] == tier).toList();
    if (tier == _tierPerishable) {
      filtered.sort((a, b) {
        final aExpiry = a['expiryDate'] as String?;
        final bExpiry = b['expiryDate'] as String?;
        if (aExpiry == null && bExpiry == null) return 0;
        if (aExpiry == null) return 1;
        if (bExpiry == null) return -1;
        final aDate = DateTime.tryParse(aExpiry);
        final bDate = DateTime.tryParse(bExpiry);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    } else {
      filtered.sort((a, b) =>
          (a['name'] as String? ?? '').toLowerCase().compareTo(
              (b['name'] as String? ?? '').toLowerCase()));
    }
    return filtered;
  }

  int _countForTier(String tier) =>
      _items.where((i) => i['tier'] == tier).length;

  void _toggleTier(String tier) {
    setState(() {
      _expandedTier = (_expandedTier == tier) ? null : tier;
    });
  }

  // ─── Tier mutation (tap-cycle + long-press picker) ─────────────────

  /// Bucket a perishable item by days-from-today on its expiryDate.
  /// Mirrors the suffix logic in [_TierItemChip] and the inverse of
  /// `screen12_pantry_perishables._onContinue`.
  String _perishableBucket(Map<String, dynamic> item) {
    final expiryStr = item['expiryDate'] as String?;
    if (expiryStr == null) return 'fresh';
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return 'fresh';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiry.year, expiry.month, expiry.day);
    final days = exp.difference(today).inDays;
    if (days <= 0) return 'today';
    if (days <= 6) return 'thisWeek';
    return 'fresh';
  }

  Future<void> _applyMutation(
      String itemId, Map<String, dynamic> action) async {
    final override = debugPantryMutationOverride;
    if (override != null) {
      override(itemId, action);
      // Reflect change in local state so the test can observe it
      // without a Firestore stream.
      setState(() {
        switch (action['type']) {
          case 'updateTier':
            final i = _items.indexWhere((it) => it['id'] == itemId);
            if (i != -1) {
              _items[i] = {..._items[i], 'tier': action['tier']};
            }
            break;
          case 'updateExpiry':
            final i = _items.indexWhere((it) => it['id'] == itemId);
            if (i != -1) {
              final d = action['expiryDate'] as DateTime;
              _items[i] = {
                ..._items[i],
                'expiryDate': d.toIso8601String(),
              };
            }
            break;
          case 'delete':
            _items = _items.where((it) => it['id'] != itemId).toList();
            break;
        }
      });
      return;
    }
    switch (action['type']) {
      case 'updateTier':
        await _firestore.updateInventoryItem(itemId,
            tier: action['tier'] as String);
        break;
      case 'updateExpiry':
        await _firestore.updateInventoryItem(itemId,
            expiryDate: action['expiryDate'] as DateTime);
        break;
      case 'delete':
        await _firestore.deleteInventoryItem(itemId);
        break;
    }
  }

  /// Map a perishable bucket to the same expiryDate anchors used by
  /// `screen12_pantry_perishables._onContinue` so a tier set here matches
  /// what onboarding would have written.
  DateTime _expiryForBucket(String bucket) {
    final now = DateTime.now();
    switch (bucket) {
      case 'today':
        return now;
      case 'thisWeek':
        return now.add(const Duration(days: 3));
      case 'fresh':
      default:
        return now.add(const Duration(days: 7));
    }
  }

  Future<void> _onItemTap(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    final tier = item['tier'] as String?;
    if (tier == _tierAlwaysHave) {
      await _applyMutation(
          id, {'type': 'updateTier', 'tier': _tierAlmostAlwaysHave});
    } else if (tier == _tierAlmostAlwaysHave) {
      await _applyMutation(id, const {'type': 'delete'});
    } else if (tier == _tierPerishable) {
      // fresh → thisWeek → today → removed
      final bucket = _perishableBucket(item);
      switch (bucket) {
        case 'fresh':
          await _applyMutation(id, {
            'type': 'updateExpiry',
            'expiryDate': _expiryForBucket('thisWeek'),
          });
          break;
        case 'thisWeek':
          await _applyMutation(id, {
            'type': 'updateExpiry',
            'expiryDate': _expiryForBucket('today'),
          });
          break;
        case 'today':
        default:
          await _applyMutation(id, const {'type': 'delete'});
          break;
      }
    }
  }

  Future<void> _onItemLongPress(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    final tier = item['tier'] as String?;
    final name = item['name'] as String? ?? '';
    if (tier == _tierPerishable) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(name),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'fresh'),
              child: const Text('Mark fresh'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'thisWeek'),
              child: const Text('Mark this week'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'today'),
              child: const Text('Mark today'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, '__remove__'),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == '__remove__') {
        await _applyMutation(id, const {'type': 'delete'});
      } else {
        await _applyMutation(id, {
          'type': 'updateExpiry',
          'expiryDate': _expiryForBucket(choice),
        });
      }
    } else {
      // Staple picker
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(name),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _tierAlwaysHave),
              child: const Text('Always have'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _tierAlmostAlwaysHave),
              child: const Text('Almost always have'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, '__remove__'),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == '__remove__') {
        await _applyMutation(id, const {'type': 'delete'});
      } else {
        await _applyMutation(id, {'type': 'updateTier', 'tier': choice});
      }
    }
  }

  // ─── Actions ────────────────────────────────────────────────────────
  void _openReceiptScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 1)),
    );
    // Stream keeps state fresh automatically on return.
  }

  void _openBarcodeScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 0)),
    );
  }

  /// Opens the Pantry Builder sheet via `showDialog` rather than
  /// `showModalBottomSheet`. Nested bottom sheets fail silently on Android —
  /// this screen may itself be reached from contexts that use sheets, and
  /// the builder also opens its own tier-picker dialog. See CLAUDE.md.
  void _openPantryBuilder() {
    final existingNames = _items
        .map((item) => item['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: ElioRadii.card,
          child: Material(
            color: ElioColors.white,
            child: PantryBuilderSheet(
              existingItemNames: existingNames,
              onAddItem: (name, tier, category) async {
                await _firestore.addInventoryItem(
                  name,
                  tier,
                  category: category,
                );
              },
              onRemoveItem: (name) async {
                final idx = _items.indexWhere(
                  (i) => (i['name'] as String? ?? '').toLowerCase() ==
                      name.toLowerCase(),
                );
                if (idx == -1) return;
                final itemId = _items[idx]['id'] as String?;
                if (itemId == null) return;
                await _firestore.deleteInventoryItem(itemId);
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final perishables = _itemsForTier(_tierPerishable);
    final alwaysHave = _itemsForTier(_tierAlwaysHave);
    final almostAlways = _itemsForTier(_tierAlmostAlwaysHave);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge,
        ElioSpacing.lg,
        ElioSpacing.screenEdge,
        ElioSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElioHeroHeading(
            lines: ['what did you', 'pick up?'],
            amberLastLine: true,
            showUnderline: true,
          ),
          const SizedBox(height: ElioSpacing.xl),
          Row(
            children: [
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.receipt_long_outlined,
                  kicker: 'From a photo',
                  title: 'Scan receipt',
                  backgroundColor: const Color(0xFFE87A5C), // salmon from Figma
                  onTap: _openReceiptScanner,
                ),
              ),
              const SizedBox(width: ElioSpacing.lg),
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.qr_code_scanner_outlined,
                  kicker: 'Item lookup',
                  title: 'Scan barcode',
                  backgroundColor: ElioColors.amber,
                  onTap: _openBarcodeScanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.xl),
          _PantryBuilderRow(onTap: _openPantryBuilder),
          const SizedBox(height: ElioSpacing.md),
          ElioTierRow(
            label: 'Perishables',
            count: _countForTier(_tierPerishable),
            onTap: () => _toggleTier(_tierPerishable),
            expandedBody: _expandedTier == _tierPerishable
                ? _TierItemsList(
                    items: perishables,
                    onItemTap: _onItemTap,
                    onItemLongPress: _onItemLongPress,
                  )
                : null,
          ),
          const SizedBox(height: ElioSpacing.sm),
          ElioTierRow(
            label: 'Always Have',
            count: _countForTier(_tierAlwaysHave),
            onTap: () => _toggleTier(_tierAlwaysHave),
            expandedBody: _expandedTier == _tierAlwaysHave
                ? _TierItemsList(
                    items: alwaysHave,
                    onItemTap: _onItemTap,
                    onItemLongPress: _onItemLongPress,
                  )
                : null,
          ),
          const SizedBox(height: ElioSpacing.sm),
          ElioTierRow(
            label: 'Almost Always Have',
            count: _countForTier(_tierAlmostAlwaysHave),
            onTap: () => _toggleTier(_tierAlmostAlwaysHave),
            expandedBody: _expandedTier == _tierAlmostAlwaysHave
                ? _TierItemsList(
                    items: almostAlways,
                    onItemTap: _onItemTap,
                    onItemLongPress: _onItemLongPress,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Pantry Builder row (full-width cream card) ───────────────────────
class _PantryBuilderRow extends StatelessWidget {
  final VoidCallback onTap;
  const _PantryBuilderRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.card,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: ElioRadii.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Pantry Builder', style: ElioTextStyles.heading5),
            ),
            const Icon(Icons.chevron_right,
                color: ElioColors.navy, size: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Inline tier items list (expanded body) ───────────────────────────
class _TierItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onItemTap;
  final ValueChanged<Map<String, dynamic>> onItemLongPress;
  const _TierItemsList({
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No items yet.',
        style: ElioTextStyles.bodySmall,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _TierItemChip(
            item: item,
            onTap: () => onItemTap(item),
            onLongPress: () => onItemLongPress(item),
          ),
      ],
    );
  }
}

class _TierItemChip extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _TierItemChip({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final expiryStr = item['expiryDate'] as String?;
    String? suffix;
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null) {
        final today =
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final exp = DateTime(expiry.year, expiry.month, expiry.day);
        final days = exp.difference(today).inDays;
        if (days < 0) {
          suffix = 'Expired';
        } else if (days == 0) {
          suffix = 'Today';
        } else if (days <= 6) {
          suffix = '${days}d';
        } else if (days <= 13) {
          suffix = '1w';
        } else {
          suffix = '${(days / 7).round()}w';
        }
      }
    }
    // RawGestureDetector with explicit recognizers — bare GestureDetector
    // long-press loses to Wrap/scrollable scroll arbitration. See CLAUDE.md.
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer r) {
            r.onTap = onTap;
          },
        ),
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 300),
          ),
          (LongPressGestureRecognizer r) {
            r.onLongPress = onLongPress;
          },
        ),
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ElioColors.white,
          borderRadius: ElioRadii.chip,
          border: Border.all(color: ElioColors.border),
        ),
        child: Text(
          suffix == null ? name : '$name · $suffix',
          style: ElioTextStyles.bodySmall.copyWith(color: ElioColors.navy),
        ),
      ),
    );
  }
}
