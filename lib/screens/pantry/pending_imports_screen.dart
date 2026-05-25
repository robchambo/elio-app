// lib/screens/pantry/pending_imports_screen.dart
//
// Sprint 17 — Online Order → Pantry Import (Task 9).
//
// Inbox host for parsed order emails awaiting review. Streams the
// user's pending_imports collection (filtered to status:pending_review,
// newest first) and renders one row per import. Tapping a row opens
// the OrderImportReviewSheet in a modal bottom sheet, prefetching the
// current pantry's matchKey set so each row can render Will add /
// Will increment without a per-row Firestore round-trip.
//
// onApply: writes the selected items through OrderImportService.
//   applyImport (which uses InventoryWriter under the hood), pops the
//   sheet, and shows a snackbar with the applied count.
// onDiscard: flips status to 'discarded' via discardImport, pops.
//
// Pushed from the pantry-tab badge tap (see ElioBottomNav). When the
// underlying stream empties, this screen self-pops so the user lands
// back on whatever pantry surface they came from — keeps the flow
// crisp on a single-import inbox.

import 'package:flutter/material.dart';

import '../../models/pending_import.dart';
import '../../services/order_import_service.dart';
import '../../widgets/order_import_review_sheet.dart';

class PendingImportsScreen extends StatelessWidget {
  final OrderImportService service;

  const PendingImportsScreen({super.key, required this.service});

  Future<void> _open(BuildContext ctx, PendingImport pi) async {
    final matchKeys = await service.currentPantryMatchKeys();
    if (!ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return OrderImportReviewSheet(
          pendingImport: pi,
          existingMatchKeys: matchKeys,
          onApply: (items) async {
            await service.applyImport(pi.id, items);
            if (!sheetCtx.mounted) return;
            Navigator.of(sheetCtx).pop();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  'Added ${items.length} item${items.length == 1 ? '' : 's'}',
                ),
              ),
            );
          },
          onDiscard: () async {
            await service.discardImport(pi.id);
            if (!sheetCtx.mounted) return;
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending imports')),
      body: StreamBuilder<List<PendingImport>>(
        stream: service.pendingImportsStream(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <PendingImport>[];
          if (list.isEmpty) {
            return const Center(child: Text('No pending imports'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final pi = list[i];
              final retailer = pi.retailer.isEmpty
                  ? 'Order'
                  : pi.retailer[0].toUpperCase() + pi.retailer.substring(1);
              return ListTile(
                title: Text('${pi.items.length} items from $retailer'),
                subtitle: pi.emailSubject.isEmpty
                    ? null
                    : Text(
                        pi.emailSubject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, pi),
              );
            },
          );
        },
      ),
    );
  }
}
