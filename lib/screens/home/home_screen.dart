import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../recipe/recipe_screen.dart';

// ─────────────────────────────────────────────
// HomeScreen — Sprint 2
// Design philosophy: approachable utility.
// Single-purpose screen: tell Elio what's fresh,
// optionally set a mood, then tap Generate.
//
// Layout:
//   • Elio wordmark header + profile avatar
//   • "What's fresh today?" dual-mode input
//     - Quick-tap chips (common perishables)
//     - Free-text field with tag conversion
//   • Mood chips (Time / Style / Mood rows)
//   • Large amber Generate button
//   • Recent recipes list (below fold)
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  // ── Perishables state ──────────────────────────────────────────────
  final Set<String> _selectedPerishables = {};

  // ── Mood chips state ───────────────────────────────────────────────
  String? _selectedTime;
  String? _selectedStyle;
  String? _selectedMood;

  // ── User data ──────────────────────────────────────────────────────
  List<String> _stylePreferences = [];
  List<String> _alwaysHave = [];
  List<String> _almostAlwaysHave = [];
  List<String> _dietaryRequirements = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  // ── Common quick-tap perishables ───────────────────────────────────
  static const List<String> _commonPerishables = [
    'Chicken breast', 'Eggs', 'Spinach', 'Tomatoes', 'Bell peppers',
    'Broccoli', 'Salmon', 'Minced beef', 'Mushrooms', 'Courgette',
    'Sweet potato', 'Avocado', 'Lemon', 'Greek yoghurt', 'Bacon',
    'Prawns', 'Tofu', 'Aubergine', 'Kale', 'Carrots',
  ];

  // ── Time chips ─────────────────────────────────────────────────────
  static const List<String> _timeChips = [
    'Quick (under 20 min)', '30 minutes', 'No rush',
  ];

  // ── Mood chips ─────────────────────────────────────────────────────
  static const List<String> _moodChips = [
    'Something hearty', 'Light bite', 'Impress someone', 'Use everything up',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _firestore.getUserData();
      if (mounted) {
        setState(() {
          _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _dietaryRequirements = List<String>.from(data['dietaryRequirements'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Style chips: user's preferences + Surprise me ─────────────────
  List<String> get _styleChips {
    final chips = List<String>.from(_stylePreferences);
    if (!chips.contains('Surprise me')) chips.add('Surprise me');
    // Cap at 6 for readability
    return chips.take(6).toList();
  }

  // ── Add item from text field ───────────────────────────────────────
  void _addFromText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedPerishables.add(text);
      _textController.clear();
    });
    _textFocus.requestFocus();
  }

  void _removePerishable(String item) {
    setState(() => _selectedPerishables.remove(item));
  }

  // ── Generate recipe ────────────────────────────────────────────────
  Future<void> _generateRecipe() async {
    if (_isGenerating) return;

    // Check free tier cap
    final canGenerate = await _firestore.canGenerateRecipe();
    if (!canGenerate && mounted) {
      _showUpgradeDialog();
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final request = RecipeGenerationRequest(
        perishables: _selectedPerishables.toList(),
        alwaysHave: _alwaysHave,
        almostAlwaysHave: _almostAlwaysHave,
        dietaryRequirements: _dietaryRequirements,
        timePreference: _selectedTime,
        stylePreference: _selectedStyle,
        moodPreference: _selectedMood,
        servings: 2,
      );

      final recipe = await GeminiService.generateRecipe(request);
      await _firestore.incrementDailyGenerations();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeScreen(recipe: recipe),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t generate a recipe right now. Try again?'),
            backgroundColor: ElioColors.navy,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ElioColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: ElioColors.amber, size: 28),
            ),
            const SizedBox(height: 16),
            Text("You've cooked up 3 today!", style: ElioText.headingMedium, textAlign: TextAlign.center),
          ],
        ),
        content: Text(
          'Free accounts get 3 recipe generations per day. Upgrade to Elio Pro for unlimited recipes, weekly meal plans, and more.',
          style: ElioText.bodyLarge,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // TODO: Navigate to subscription screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscription coming soon!')),
                    );
                  },
                  child: const Text('Upgrade to Pro — \$2.99/mo'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Maybe tomorrow',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────
            _buildAppBar(),

            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ElioColors.amber))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildPerishablesSection(),
                          const SizedBox(height: 24),
                          _buildMoodChipsSection(),
                          const SizedBox(height: 28),
                          _buildGenerateButton(),
                          const SizedBox(height: 32),
                          _buildRecentSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    final initials = (user?.displayName ?? 'U')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ELiO wordmark
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(text: 'EL', style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.navy)),
                TextSpan(text: 'i', style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.sky)),
                TextSpan(text: 'O', style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.navy)),
              ],
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () {
              // TODO: Navigate to profile/settings
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ElioColors.navy,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Perishables section ──────────────────────────────────────────────────────
  Widget _buildPerishablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What's fresh today?", style: ElioText.displayMedium),
        const SizedBox(height: 4),
        Text(
          'Tap what you have, or type anything else.',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // ── Quick-tap chips ──────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _commonPerishables.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = _commonPerishables[i];
              final isSelected = _selectedPerishables.contains(item);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedPerishables.remove(item);
                  } else {
                    _selectedPerishables.add(item);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ElioColors.amber : ElioColors.offWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? ElioColors.amber : ElioColors.border,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : ElioColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Free-text input ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _textFocus,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Add anything else...',
                  hintStyle: TextStyle(color: ElioColors.textMuted, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _addFromText(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addFromText,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ElioColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),

        // ── Selected perishable tags ─────────────────────────────
        if (_selectedPerishables.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPerishables.map((item) => _SelectedTag(
              label: item,
              onRemove: () => _removePerishable(item),
            )).toList(),
          ),
        ],
      ],
    );
  }

  // ─── Mood chips section ───────────────────────────────────────────────────────
  Widget _buildMoodChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anything in mind?',
          style: ElioText.headingMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'All optional — Elio will figure it out if you skip these.',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Time row
        _buildChipRow(
          label: 'Time',
          chips: _timeChips,
          selected: _selectedTime,
          onSelect: (v) => setState(() => _selectedTime = _selectedTime == v ? null : v),
        ),
        const SizedBox(height: 12),

        // Style row
        if (_styleChips.isNotEmpty) ...[
          _buildChipRow(
            label: 'Style',
            chips: _styleChips,
            selected: _selectedStyle,
            onSelect: (v) => setState(() => _selectedStyle = _selectedStyle == v ? null : v),
          ),
          const SizedBox(height: 12),
        ],

        // Mood row
        _buildChipRow(
          label: 'Mood',
          chips: _moodChips,
          selected: _selectedMood,
          onSelect: (v) => setState(() => _selectedMood = _selectedMood == v ? null : v),
        ),
      ],
    );
  }

  Widget _buildChipRow({
    required String label,
    required List<String> chips,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ElioText.label.copyWith(
            color: ElioColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = chips[i];
              final isSelected = selected == chip;
              return GestureDetector(
                onTap: () => onSelect(chip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ElioColors.navy.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? ElioColors.navy : ElioColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Generate button ──────────────────────────────────────────────────────────
  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateRecipe,
        style: ElevatedButton.styleFrom(
          backgroundColor: ElioColors.amber,
          disabledBackgroundColor: ElioColors.amber.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isGenerating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Generate Recipe →',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ─── Recent recipes section ───────────────────────────────────────────────────
  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent recipes', style: ElioText.headingMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ElioColors.offWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ElioColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: ElioColors.textMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your generated recipes will appear here.',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Selected tag widget ──────────────────────────────────────────────────────

class _SelectedTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: ElioColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ElioColors.navy.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ElioColors.navy,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 16, color: ElioColors.navy),
          ),
        ],
      ),
    );
  }
}
