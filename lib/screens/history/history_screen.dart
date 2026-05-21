import 'package:flutter/material.dart';
import '../../models/recipe_models.dart';
import '../../services/history_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/snackbar_helpers.dart';
import '../recipe/recipe_screen.dart';

// ─────────────────────────────────────────────
// HistoryScreen
// Shows locally saved recipes, newest first.
// Swipe left to delete. Tap to view full recipe.
// ─────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SavedRecipe> _recipes = [];
  bool _loading = true;
  bool _historyTrimmed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Refresh entitlements then apply the free-tier 20-item cap.
    await EntitlementService.instance.refresh();
    final allRecipes = await HistoryService.getHistory();
    List<SavedRecipe> recipes = allRecipes;
    bool trimmed = false;
    if (EntitlementService.instance.isFree &&
        allRecipes.length > EntitlementService.freeHistoryLimit) {
      recipes = allRecipes.take(EntitlementService.freeHistoryLimit).toList();
      trimmed = true;
    }
    if (mounted) {
      setState(() {
        _recipes = recipes;
        _historyTrimmed = trimmed;
        _loading = false;
      });
    }
  }

  Future<void> _delete(SavedRecipe saved) async {
    await HistoryService.deleteRecipe(saved.savedAt);
    if (mounted) setState(() => _recipes.removeWhere((r) => r.savedAt == saved.savedAt));
    if (mounted) {
      // Sprint 16.7c — withTimer enforces the default 4s dismiss even
      // when the device's accessibleNavigation flag is true.
      ScaffoldMessenger.of(context).showSnackBarWithTimer(
        SnackBar(
          content: Text('${saved.recipe.title} removed', style: ElioTextStyles.bodyStyle),
          backgroundColor: ElioColors.espresso,
          action: SnackBarAction(
            label: 'Undo',
            textColor: ElioColors.terracotta,
            onPressed: () async {
              await HistoryService.saveRecipe(saved);
              _load();
            },
          ),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        title: Text('Clear history?', style: ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 20, color: ElioColors.espresso)),
        content: Text('All saved recipes will be removed from this device.', style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear all', style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.clearAll();
      if (mounted) setState(() => _recipes = []);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: ElioColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ElioColors.espresso, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'EL',
                style: ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              TextSpan(
                text: 'i',
                style: ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w300, color: ElioColors.terracotta, letterSpacing: -0.5),
              ),
              TextSpan(
                text: 'O',
                style: ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              TextSpan(
                text: ' History',
                style: ElioTextStyles.bodyStyle.copyWith(fontSize: 18, color: ElioColors.mocha),
              ),
            ],
          ),
        ),
        actions: [
          if (_recipes.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text('Clear all', style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.red.shade400, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ElioColors.terracotta))
          : _recipes.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: ElioColors.rule),
            const SizedBox(height: 20),
            Text(
              'No recipes yet',
              style: ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 22, color: ElioColors.espresso),
            ),
            const SizedBox(height: 8),
            Text(
              'Recipes you generate will appear here automatically.',
              textAlign: TextAlign.center,
              style: ElioTextStyles.bodyStyle.copyWith(fontSize: 15, color: ElioColors.mocha, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.terracotta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.terracotta, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: ElioColors.terracotta, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade for full history — free accounts show the 20 most recent recipes.',
              style: ElioTextStyles.bodySmallStyle.copyWith(color: ElioColors.espresso, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _recipes.length + (_historyTrimmed ? 1 : 0),
      itemBuilder: (context, index) {
        if (_historyTrimmed && index == _recipes.length) {
          return _buildUpgradeBanner();
        }
        final saved = _recipes[index];
        final recipe = saved.recipe;
        return Dismissible(
          key: Key(saved.savedAt),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _delete(saved),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
          ),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RecipeScreen(recipe: recipe)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ElioColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ElioColors.rule, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: ElioTextStyles.uiLabelStyle.copyWith(
                            color: ElioColors.espresso,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recipe.description,
                          style: ElioTextStyles.bodySmallStyle.copyWith(
                            color: ElioColors.mocha,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _chip(Icons.timer_outlined, '${recipe.totalTimeMinutes} min'),
                            const SizedBox(width: 8),
                            _chip(Icons.people_outline_rounded, '${recipe.servings} servings'),
                            const Spacer(),
                            Text(
                              _formatDate(saved.savedAt),
                              style: ElioTextStyles.tabLabelStyle.copyWith(color: ElioColors.mocha),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: arrow
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded, color: ElioColors.rule, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: ElioColors.mocha),
        const SizedBox(width: 3),
        Text(label, style: ElioTextStyles.tabLabelStyle.copyWith(color: ElioColors.mocha)),
      ],
    );
  }
}
