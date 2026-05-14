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
import '../../services/inventory_writer.dart';
import '../../services/pantry_memory_service.dart';
import '../../services/shopping_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/pantry_chip_urgency.dart';
import '../../utils/snackbar_helpers.dart';
import '../../widgets/elio/elio_add_pantry_item_dialog.dart';
import '../../widgets/elio/elio_bento_card.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_section_heading.dart';
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

/// Test seam: when set, `_onAddToTier` calls this instead of
/// FirestoreService.addInventoryItem. The mock generates a synthetic id
/// so the new chip appears in the local `_items` list.
@visibleForTesting
String Function(String name, String tier, DateTime? expiryDate)?
    debugPantryAddOverride;

class _PantryScreenState extends State<PantryScreen> {
  final FirestoreService _firestore = FirestoreService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invSub;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  /// Which tier is currently expanded (single-open-at-a-time). `null` = all collapsed.
  String? _expandedTier;

  /// Sprint 16.6 (Notion XX-2 B1, 13 May 2026): track the most-recent
  /// snackbar from THIS screen so we can dismiss it in dispose() and
  /// avoid orphan toasts leaking across tab navigation. Combined with
  /// shorter durations (2s for the × Undo, 3s for auto-dedup +
  /// running-low) this kills the "toast still persistent" report.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _activeSnackbar;

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
    // Sprint 16.6.x: fire silent auto-dedup once per app session when
    // the Pantry tab opens. Cleans legacy pre-15.9.1 duplicates that
    // the gated-on-addItem migration never ran for users who just
    // open the app to view their existing pantry. The hidden long-
    // press recovery on the page title stays as a manual fallback.
    _runAutoDedup();
  }

  /// Fire-and-forget auto-dedup. Quiet on a clean pantry; shows a
  /// brief snackbar only when duplicates were actually merged so the
  /// user knows the app tidied up.
  Future<void> _runAutoDedup() async {
    try {
      final deleted = await InventoryWriter.instance.autoDedupOnce();
      if (!mounted) return;
      if (deleted == null || deleted == 0) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      _activeSnackbar = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'Tidied up your pantry — merged $deleted duplicate '
            'row${deleted == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (_) {
      // ErrorService already logged inside InventoryWriter — auto-
      // dedup failure is a non-event for the user. The hidden long-
      // press on the page title is the fallback.
    }
  }

  @override
  void dispose() {
    _invSub?.cancel();
    // Notion XX-2 B1 (13 May 2026): kill any active pantry-tab
    // snackbar on screen dispose so it can't leak past the screen's
    // lifetime. Combined with shorter durations this prevents toasts
    // lingering past a tab navigation in production builds.
    //
    // Try/catch: close() throws "Bad state: No element" when the
    // snackbar queue is already drained (e.g. user tapped Undo or it
    // auto-dismissed and the messenger has torn down). Close is
    // best-effort — swallow.
    try {
      _activeSnackbar?.close();
    } catch (_) {}
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

  // ─── Tier mutation (long-press picker only) ────────────────────────

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
          case 'toggleRunningLow':
            final i = _items.indexWhere((it) => it['id'] == itemId);
            if (i != -1) {
              _items[i] = {
                ..._items[i],
                'runningLow': action['runningLow'] as bool,
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
      case 'toggleRunningLow':
        // Sprint 16.6.x: pantry ↔ shopping list bridge. Marking an
        // item running low flips the inventory flag AND adds (or
        // removes) the matching restock entry from the user's
        // shopping list so they see what to pick up next shop.
        final runningLow = action['runningLow'] as bool;
        final name = action['name'] as String? ?? '';
        await _firestore.updateInventoryItem(itemId, runningLow: runningLow);
        if (name.isNotEmpty) {
          if (runningLow) {
            await ShoppingService.instance.addRestockItem(name);
          } else {
            await ShoppingService.instance.removeRestockItem(name);
          }
        }
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

  // Sprint 16.4 (Bug 4): single-tap on a chip used to cycle the tier and
  // ultimately delete the item. Too easy to lose items by mistake. The
  // long-press picker (below) already exposes Remove, so tap is now a
  // no-op — long-press is the only mutation path.

  Future<void> _onItemLongPress(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    final tier = item['tier'] as String?;
    final name = item['name'] as String? ?? '';
    // Sprint 16.6.x: running-low toggle appears on every long-press dialog
    // (staple + perishable). The wording flips so the user can both mark
    // and unmark without leaving the picker.
    final wasLow = item['runningLow'] == true;
    final runningLowLabel =
        wasLow ? 'Unmark running low' : 'Mark running low';
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
              onPressed: () => Navigator.pop(ctx, '__runningLow__'),
              child: Text(runningLowLabel),
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
      } else if (choice == '__runningLow__') {
        await _applyMutation(id, {
          'type': 'toggleRunningLow',
          'runningLow': !wasLow,
          'name': name,
        });
        _showRunningLowSnackbar(name, !wasLow);
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
              onPressed: () => Navigator.pop(ctx, '__runningLow__'),
              child: Text(runningLowLabel),
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
      } else if (choice == '__runningLow__') {
        await _applyMutation(id, {
          'type': 'toggleRunningLow',
          'runningLow': !wasLow,
          'name': name,
        });
        _showRunningLowSnackbar(name, !wasLow);
      } else {
        await _applyMutation(id, {'type': 'updateTier', 'tier': choice});
      }
    }
  }

  /// Sprint 16.6 row 9 — explicit per-chip remove with undo.
  ///
  /// Distinct from the long-press picker's Remove (which exists for
  /// power users already inside the picker for another reason): the
  /// small × on each chip is the dedicated remove affordance. It
  /// deletes the item immediately and shows an Undo snackbar with a
  /// 4-second window so a stray tap doesn't lose data.
  Future<void> _onItemRemove(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    // Snapshot the full row before deletion so Undo can recreate
    // name + tier + expiry + runningLow exactly.
    final snapshot = Map<String, dynamic>.from(item);
    final name = (item['name'] as String?) ?? '';

    await _applyMutation(id, const {'type': 'delete'});
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    // Belt-and-braces snackbar lifecycle (13 May 2026), combining two
    // independent fixes that both landed for the same Rob-reported bug:
    //   • duration 4s → 2s (Notion XX-2 B1, integration commit 841e91c)
    //     — Material's standard undo pattern, shrinks the leak window
    //     to almost nothing
    //   • _activeSnackbar tracked + closed in dispose() (also 841e91c)
    //     — kills the toast on screen lifecycle exit
    //   • showSnackBarWithTimer (Sprint 16.7c, commit d8e5e7c) — bypasses
    //     Flutter's accessibility-related timer suppression so the 2s
    //     dismiss is enforced on devices with TalkBack / Switch Access
    //     / various Samsung accessibility shortcuts (Flutter otherwise
    //     skips its own auto-dismiss timer when accessibleNavigation is
    //     true AND the snackbar has an action).
    _activeSnackbar = messenger.showSnackBarWithTimer(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          name.isEmpty ? 'Removed item.' : 'Removed $name.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restoreItem(snapshot),
        ),
      ),
    );
  }

  /// Re-adds a previously-deleted inventory row via the same add path
  /// used by the per-tier "+ Add" chip. Goes through
  /// `debugPantryAddOverride` in tests, and `FirestoreService.addInventoryItem`
  /// + a follow-up `updateInventoryItem(runningLow)` in production so a
  /// chip that was Low when removed comes back still Low.
  Future<void> _restoreItem(Map<String, dynamic> snapshot) async {
    final name = (snapshot['name'] as String?) ?? '';
    if (name.isEmpty) return;
    final tier = (snapshot['tier'] as String?) ?? _tierAlwaysHave;
    DateTime? expiry;
    final rawExpiry = snapshot['expiryDate'];
    if (rawExpiry is String) {
      expiry = DateTime.tryParse(rawExpiry);
    }
    final runningLow = snapshot['runningLow'] == true;

    final addOverride = debugPantryAddOverride;
    if (addOverride != null) {
      final newId = addOverride(name, tier, expiry);
      setState(() {
        _items = [
          ..._items,
          {
            'id': newId,
            'name': name,
            'tier': tier,
            'runningLow': runningLow,
            if (expiry != null) 'expiryDate': expiry.toIso8601String(),
          },
        ];
      });
      return;
    }

    final newId = await _firestore.addInventoryItem(
      name,
      tier,
      expiryDate: expiry,
    );
    if (runningLow) {
      await _firestore.updateInventoryItem(newId, runningLow: true);
    }
  }

  /// Confirmation snackbar after toggling running-low. The shopping-list
  /// side-effect is silent otherwise — this is the user's cue to check
  /// the Shopping tab.
  void _showRunningLowSnackbar(String name, bool runningLow) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    // Notion XX-2 B1 (13 May 2026): controller saved so dispose() can
    // close it on screen exit. Duration kept at 3s — short enough to
    // not leak across tabs, long enough to read.
    _activeSnackbar = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          runningLow
              ? '$name added to shopping list — restock soon.'
              : '$name removed from restock list.',
        ),
      ),
    );
  }

  // ─── Add-to-tier (Bug 3 — Sprint 16.4) ─────────────────────────────
  // Without this, the only way to add items after onboarding was the
  // Pantry Builder sheet (staples-flavoured) or scanning. Perishables in
  // particular had nowhere to go. Each expanded tier now ends in a small
  // dashed "+ Add" chip that opens the same dialog used by onboarding
  // 11/12, then for perishables follows up with a fresh/thisWeek/today
  // bucket picker so the new item gets a sensible expiryDate.
  Future<void> _onAddToTier(String tier) async {
    final categoryName = switch (tier) {
      _tierPerishable => 'Perishables',
      _tierAlmostAlwaysHave => 'Almost Always Have',
      _ => 'Always Have',
    };
    final existing = _items
        .map((i) => i['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final result = await showAddPantryItemDialog(
      context,
      categoryName: categoryName,
      existing: existing,
    );

    if (!mounted) return;

    String? chosenName;
    String? promotedFromId;
    switch (result) {
      case AddItemCancelled():
        return;
      case AddItemPromoteExisting(existingName: final name):
        chosenName = name;
        // If the existing item is in another tier, move it. If it's
        // already in this tier (perishable case), still continue so the
        // user can pick a fresh expiryDate bucket.
        final idx = _items.indexWhere(
          (i) => (i['name'] as String? ?? '').toLowerCase() ==
              name.toLowerCase(),
        );
        if (idx != -1) promotedFromId = _items[idx]['id'] as String?;
      case AddItemAddNew(name: final name):
        chosenName = name;
        // Persist the typed custom so it surfaces as a first-class chip
        // on subsequent builder opens. Fire-and-forget — inventory write
        // happens via the existing path below regardless.
        PantryMemoryService.instance.upsertCustom(
          displayName: name,
          category: categoryName,
          tier: tier,
        );
    }

    DateTime? expiry;
    if (tier == _tierPerishable) {
      final bucket = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('How fresh is $chosenName?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'fresh'),
              child: const Text('Fresh (about a week)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'thisWeek'),
              child: const Text('Use this week'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'today'),
              child: const Text('Use today'),
            ),
          ],
        ),
      );
      if (bucket == null) return;
      expiry = _expiryForBucket(bucket);
    }

    // Promote existing → updateTier (and expiry for perishables).
    if (promotedFromId != null) {
      await _applyMutation(promotedFromId, {'type': 'updateTier', 'tier': tier});
      if (expiry != null) {
        await _applyMutation(promotedFromId, {
          'type': 'updateExpiry',
          'expiryDate': expiry,
        });
      }
      return;
    }

    // New item.
    final addOverride = debugPantryAddOverride;
    if (addOverride != null) {
      final id = addOverride(chosenName, tier, expiry);
      setState(() {
        _items = [
          ..._items,
          {
            'id': id,
            'name': chosenName,
            'tier': tier,
            'runningLow': false,
            if (expiry != null) 'expiryDate': expiry.toIso8601String(),
          },
        ];
      });
      return;
    }
    await _firestore.addInventoryItem(chosenName, tier, expiryDate: expiry);
  }

  // ─── Actions ────────────────────────────────────────────────────────

  /// Sprint 15.9.3: force-runs InventoryWriter's collapse step, ignoring
  /// the `inventoryDuplicatesCollapsed` flag. Triggered by long-press on
  /// the page title. Recovery affordance for dev devices where the
  /// initial migration silently failed but the flag was set anyway.
  /// Shows a snackbar with the deleted count so the user gets feedback.
  Future<void> _forceCollapseDuplicates() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('Cleaning up duplicates…'),
      ),
    );
    try {
      final deleted = await InventoryWriter.instance.forceCollapseDuplicates();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted == 0
                ? 'No duplicates found.'
                : 'Cleaned up $deleted duplicate row${deleted == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Cleanup failed: $e')),
      );
    }
  }

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
          borderRadius: BorderRadius.circular(ElioRadii.card),
          child: Material(
            color: ElioColors.cream,
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
          // Sprint 15.9.3: long-press the page title to force-collapse
          // duplicate inventory rows. Diagnostic affordance — exposes
          // InventoryWriter.forceCollapseDuplicates() so dev devices
          // that already had `inventoryDuplicatesCollapsed: true` set
          // can still clean up. Hidden from normal users; long-press
          // is unobtrusive enough that no one will discover it
          // accidentally.
          GestureDetector(
            onLongPress: _forceCollapseDuplicates,
            behavior: HitTestBehavior.opaque,
            child: const ElioPageTitle('what did you pick up?'),
          ),
          const SizedBox(height: ElioSpacing.xl),
          Row(
            children: [
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.photo_camera_outlined,
                  kicker: 'Photo Or Camera',
                  title: 'Scan Receipt',
                  iconBackgroundColor: ElioColors.peach,
                  onTap: _openReceiptScanner,
                ),
              ),
              const SizedBox(width: ElioSpacing.lg),
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.qr_code_scanner_outlined,
                  kicker: 'Item Lookup',
                  title: 'Scan Barcode',
                  iconBackgroundColor: const Color(0xFFF5C26B),
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
                    onItemLongPress: _onItemLongPress,
                    onItemRemove: _onItemRemove,
                    onAdd: () => _onAddToTier(_tierPerishable),
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
                    onItemLongPress: _onItemLongPress,
                    onItemRemove: _onItemRemove,
                    onAdd: () => _onAddToTier(_tierAlwaysHave),
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
                    onItemLongPress: _onItemLongPress,
                    onItemRemove: _onItemRemove,
                    onAdd: () => _onAddToTier(_tierAlmostAlwaysHave),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Pantry Builder section header (Kate's Sprint-16 pantry frame) ─────
//
// Section header + sub-line, with a discrete pencil icon button on the
// right that opens the PantryBuilderSheet. Replaces the previous
// full-width chevron-card affordance — only the pencil is now tappable,
// the heading/sub-copy are read-only.
class _PantryBuilderRow extends StatelessWidget {
  final VoidCallback onTap;
  const _PantryBuilderRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElioSectionHeading('Pantry Builder'),
              const SizedBox(height: 2),
              Text(
                'Browse and add by category',
                style: ElioTextStyles.bodySmallStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: ElioSpacing.md),
        Material(
          color: ElioColors.creamDeep,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.edit_note_rounded,
                  color: ElioColors.espresso, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Inline tier items list (expanded body) ───────────────────────────
class _TierItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onItemLongPress;
  final ValueChanged<Map<String, dynamic>> onItemRemove;
  final VoidCallback onAdd;
  const _TierItemsList({
    required this.items,
    required this.onItemLongPress,
    required this.onItemRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Sprint 15.9.3: + Add pill leads each tier so users don't have
        // to scroll past every existing item to find the affordance.
        _AddSomethingChip(onTap: onAdd),
        for (final item in items)
          _TierItemChip(
            item: item,
            onLongPress: () => onItemLongPress(item),
            onRemove: () => onItemRemove(item),
          ),
      ],
    );
  }
}

/// Small dashed-border chip that mirrors `_TierItemChip` shape and lives
/// at the end of each tier's expanded body. Single tap (no long-press
/// here — adding is intentional, not destructive).
class _AddSomethingChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSomethingChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(ElioRadii.chip),
          border: Border.all(
            color: ElioColors.terracotta,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: ElioColors.terracotta, size: 16),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: ElioTextStyles.bodySmall.copyWith(
                color: ElioColors.terracotta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierItemChip extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  const _TierItemChip({
    required this.item,
    required this.onLongPress,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final isRunningLow = item['runningLow'] == true;
    // Sprint 16.6: urgency colours now drive background + border + dot
    // via PantryChipUrgency.forItem. Matches the onboarding pantry-tile
    // palette (ElioPantryItemTile._defaultStyles) — same colour language
    // across both surfaces. See lib/utils/pantry_chip_urgency.dart.
    final urgency = PantryChipUrgency.forItem(item);
    final dotColor = urgency.dotColor;

    // Sprint 16.6 row 9: dedicated × hit-target on each chip for
    // explicit delete with Undo snackbar. Long-press still opens the
    // tier/expiry/running-low picker (which also contains Remove for
    // power users already inside the dialog).
    //
    // Layout: a single outer Container with the chip decoration, an
    // inner Row that has TWO independent gesture surfaces side by
    // side. The chip body uses RawGestureDetector (long-press +
    // no-op tap absorber) so a stray tap doesn't collapse the parent
    // ElioTierRow. The × is a separate GestureDetector so its tap is
    // claimed before bubbling.
    //
    // CLAUDE.md gotcha: bare GestureDetector long-press loses to
    // Wrap/scrollable scroll arbitration — RawGestureDetector required.
    return Container(
      decoration: BoxDecoration(
        color: urgency.background,
        borderRadius: BorderRadius.circular(ElioRadii.chip),
        border: Border.all(color: urgency.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (TapGestureRecognizer r) {
                  r.onTap = () {}; // no-op — absorb tap, prevent parent toggle
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
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    name,
                    style: ElioTextStyles.bodySmallStyle
                        .copyWith(color: ElioColors.espresso),
                  ),
                  if (isRunningLow) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ElioColors.terracotta.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(ElioRadii.chip),
                        border: Border.all(
                          color:
                              ElioColors.terracotta.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        'Low',
                        style: ElioTextStyles.bodySmallStyle.copyWith(
                          color: ElioColors.terracotta,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Dedicated × hit-target. Tooltip + Semantics for a11y.
          // Padding gives the icon a ~30×26 hit area — tight but bigger
          // than a bare 14px icon. Deliberate hit-area choice: the ×
          // sits inside the visible chip footprint so the chip doesn't
          // grow tall, and the Undo snackbar (4s) covers stray-tap risk.
          Tooltip(
            message: 'Remove $name',
            child: Semantics(
              button: true,
              label: 'Remove $name',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(4, 6, 10, 6),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: ElioColors.mocha,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
