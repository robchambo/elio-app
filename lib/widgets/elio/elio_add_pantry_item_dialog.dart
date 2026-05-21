import 'package:flutter/material.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/pantry_staples.dart';
import '../../utils/pantry_utils.dart';

/// Result of showing the add-pantry-item dialog.
///
/// The caller decides what to do based on which variant is returned:
///  * [AddItemCancelled] — user cancelled; do nothing.
///  * [AddItemPromoteExisting] — an existing item with the same name
///    (case-insensitive, normalised) is already in the pantry. Promote
///    that item to the appropriate tier instead of adding a duplicate.
///  * [AddItemAddNew] — add this name as a new custom item.
sealed class AddItemResult {
  const AddItemResult();
}

class AddItemCancelled extends AddItemResult {
  const AddItemCancelled();
}

class AddItemPromoteExisting extends AddItemResult {
  final String existingName;
  const AddItemPromoteExisting(this.existingName);
}

class AddItemAddNew extends AddItemResult {
  final String name;
  const AddItemAddNew(this.name);
}

/// Shows a small "Add something" dialog prompting the user to type an
/// item name. Handles the dedup logic before returning:
///
///  * Universal staple (salt, pepper, water, sugar, generic oils — see
///    [PantryStaples.isStaple]) → inline error shown, only Cancel visible,
///    returns [AddItemCancelled].
///  * Exact normalised match against any entry in [existing] →
///    [AddItemPromoteExisting] (no extra warning shown — the correct
///    behaviour is to promote the existing tile silently).
///  * Fuzzy match via [PantryUtils.findDuplicates] →
///    [PantryUtils.showDuplicateWarning] is shown; if the user picks
///    "Add anyway" we return [AddItemAddNew], otherwise [AddItemCancelled].
///  * No match → [AddItemAddNew].
///
/// **Caller responsibility:** when handling [AddItemAddNew], the caller
/// must call `PantryMemoryService.instance.upsertCustom(name, tier)` once
/// the target tier is known. The dialog does not call it because the tier
/// is determined after the dialog returns.
///
/// [categoryName] appears in the dialog heading so the user knows which
/// section their new item will land in.
Future<AddItemResult> showAddPantryItemDialog(
  BuildContext context, {
  required String categoryName,
  required List<String> existing,
}) async {
  final controller = TextEditingController();
  String? errorText;
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          void onSubmit(String raw) {
            final value = raw.trim();
            if (value.isEmpty) {
              Navigator.of(ctx).pop(null);
              return;
            }
            if (PantryStaples.isStaple(value)) {
              setLocalState(() {
                errorText = PantryStaples.assumedNote(value);
              });
              return; // do NOT pop — let user cancel or change input
            }
            Navigator.of(ctx).pop(value);
          }

          return AlertDialog(
            backgroundColor: ElioColors.creamDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ElioRadii.card),
            ),
            title: Text(
              'Add to $categoryName',
              style: ElioTextStyles.sectionHeadingStyle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Miso paste',
                    hintStyle: ElioTextStyles.bodyStyle.copyWith(
                      color: ElioColors.mocha,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ElioRadii.input),
                      borderSide: const BorderSide(color: ElioColors.rule),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ElioRadii.input),
                      borderSide: const BorderSide(
                        color: ElioColors.terracotta,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setLocalState(() => errorText = null);
                    }
                  },
                  onSubmitted: onSubmit,
                ),
                if (errorText != null) ...[
                  const SizedBox(height: ElioSpacing.sm),
                  Text(
                    errorText!,
                    style: ElioTextStyles.bodySmallStyle.copyWith(
                      color: ElioColors.terracotta,
                    ),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(
              ElioSpacing.md, 0, ElioSpacing.md, ElioSpacing.sm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(
                  'Cancel',
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                    color: ElioColors.mocha,
                  ),
                ),
              ),
              if (errorText == null)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ElioColors.terracotta, width: 1.5),
                    foregroundColor: ElioColors.terracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ElioRadii.input),
                    ),
                  ),
                  onPressed: () => onSubmit(controller.text),
                  child: Text(
                    'Add',
                    style: ElioTextStyles.uiLabelStyle.copyWith(
                      color: ElioColors.terracotta,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );

  if (submitted == null || submitted.isEmpty) {
    return const AddItemCancelled();
  }

  // Exact (normalised) match → promote the existing item.
  final normalisedNew = PantryUtils.normalise(submitted);
  for (final name in existing) {
    if (PantryUtils.normalise(name) == normalisedNew) {
      return AddItemPromoteExisting(name);
    }
  }

  // Fuzzy match → confirm with the user.
  final fuzzy = PantryUtils.findDuplicates(submitted, existing);
  if (fuzzy.isNotEmpty) {
    if (!context.mounted) return const AddItemCancelled();
    final addAnyway =
        await PantryUtils.showDuplicateWarning(context, submitted, fuzzy);
    if (!addAnyway) return const AddItemCancelled();
  }

  return AddItemAddNew(submitted);
}
