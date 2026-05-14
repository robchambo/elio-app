import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../../services/gemini_service.dart';
import '../../services/error_service.dart';
import '../../utils/friendly_error.dart';
import '../recipe/recipe_screen.dart';

// ─────────────────────────────────────────────
// RecipeImportScreen
// Two-tab screen: Photo scan or Manual entry.
// Pro feature — paywall checked before navigating here.
// ─────────────────────────────────────────────

class RecipeImportScreen extends StatefulWidget {
  /// Which tab to open on first build: 0 = Photo, 1 = Manual.
  /// Sprint 16.4: the Recipes-tab bento cards now route here directly,
  /// so the Photo bento opens on Photo and the Manual bento opens on
  /// Manual instead of always landing on Photo.
  final int initialTab;
  const RecipeImportScreen({super.key, this.initialTab = 0});

  @override
  State<RecipeImportScreen> createState() => _RecipeImportScreenState();
}

class _RecipeImportScreenState extends State<RecipeImportScreen> {
  late int _activeTab = widget.initialTab; // 0 = Photo, 1 = Manual
  bool _isProcessing = false;
  bool _isImportingUrl = false;

  // ── URL import ────────────────────────────────────────────────────
  final _urlController = TextEditingController();
  String? _clipboardUrl;

  // ── Manual entry controllers ──────────────────────────────────────
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final List<_IngredientRow> _ingredientRows = [_IngredientRow()];

  @override
  void initState() {
    super.initState();
    if (_activeTab == 1) {
      // Land on Manual? Pre-check clipboard for a recipe URL just like
      // tapping the Manual tab does later.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkClipboardForUrl();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Check clipboard for a URL when switching to the Manual tab.
  Future<void> _checkClipboardForUrl() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && (text.startsWith('http://') || text.startsWith('https://'))) {
        if (mounted) setState(() => _clipboardUrl = text);
      } else {
        if (mounted) setState(() => _clipboardUrl = null);
      }
    } catch (_) {
      // Clipboard access may fail — not critical
    }
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL.'),
          backgroundColor: ElioColors.espresso,
        ),
      );
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL starting with http:// or https://'),
          backgroundColor: ElioColors.espresso,
        ),
      );
      return;
    }

    setState(() => _isImportingUrl = true);

    try {
      final recipe = await GeminiService.importRecipeFromUrl(url);

      if (!mounted) return;
      setState(() => _isImportingUrl = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeScreen(recipe: recipe, autoSave: true),
        ),
      );
    } catch (e) {
      ErrorService.log('recipe_import_url', e);
      if (!mounted) return;
      setState(() => _isImportingUrl = false);

      final msg = friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.length > 100 ? '${msg.substring(0, 100)}...' : msg),
          backgroundColor: ElioColors.espresso,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: ElioColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ElioColors.espresso, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Import Recipe', style: ElioText.headingLarge),
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ElioColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ElioColors.rule),
              ),
              child: Row(
                children: [
                  _buildTab(0, Icons.camera_alt_rounded, 'Photo'),
                  _buildTab(1, Icons.edit_rounded, 'Manual'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _activeTab == 0 ? _buildPhotoTab() : _buildManualTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = index);
          if (index == 1) _checkClipboardForUrl();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ElioColors.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? ElioColors.espresso : ElioColors.mocha),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? ElioColors.espresso : ElioColors.mocha,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Photo Tab ──────────────────────────────────────────────────────

  Widget _buildPhotoTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Spacer(),
          // Icon area
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: ElioColors.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.menu_book_rounded, size: 48, color: ElioColors.terracotta),
          ),
          const SizedBox(height: 20),
          Text(
            'Snap a recipe',
            style: ElioText.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of any recipe — from a book, magazine, or screen — and Elio will extract it for you.',
            textAlign: TextAlign.center,
            style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
          ),
          const SizedBox(height: 8),
          Text(
            'Works best with clear, well-lit photos. Handwritten recipes may not extract perfectly.',
            textAlign: TextAlign.center,
            style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.mocha),
          ),
          const SizedBox(height: 32),
          // Buttons
          if (_isProcessing) ...[
            const CircularProgressIndicator(color: ElioColors.terracotta),
            const SizedBox(height: 12),
            Text('Extracting recipe...', style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha)),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _capturePhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      label: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ElioColors.terracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _capturePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 18, color: ElioColors.espresso),
                      label: Text('Gallery', style: TextStyle(color: ElioColors.espresso, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ElioColors.rule),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await _processImage(bytes);
  }

  Future<void> _processImage(Uint8List bytes) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final recipe = await GeminiService.importRecipeFromImage(bytes);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Navigate to recipe screen — autoSave handles saving + bookmarking
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeScreen(recipe: recipe, autoSave: true),
        ),
      );
    } catch (e) {
      ErrorService.log('recipe_import_photo', e);
      if (!mounted) return;
      setState(() => _isProcessing = false);

      final msg = friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.length > 100 ? '${msg.substring(0, 100)}...' : msg),
          backgroundColor: ElioColors.espresso,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ─── Manual Tab ─────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── URL import section ──────────────────────────────────────
          Text('Import from URL', style: ElioText.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _buildTextField(_urlController, 'Paste a recipe URL'),
          if (_clipboardUrl != null && _urlController.text.isEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _urlController.text = _clipboardUrl!;
                  _clipboardUrl = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ElioColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ElioColors.mocha.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_paste_rounded, size: 14, color: ElioColors.mocha),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Paste from clipboard',
                        style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: ElioColors.mocha),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isImportingUrl ? null : _importFromUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.terracotta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isImportingUrl
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Import from URL',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // ── Divider ─────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider(color: ElioColors.rule)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Or enter manually',
                  style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.mocha, fontWeight: FontWeight.w600),
                ),
              ),
              const Expanded(child: Divider(color: ElioColors.rule)),
            ],
          ),
          const SizedBox(height: 20),
          // ── Manual form fields ──────────────────────────────────────
          // Title
          Text('Title', style: ElioText.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _buildTextField(_titleController, 'e.g. Grandma\'s Tomato Soup'),
          const SizedBox(height: 20),
          // Description
          Text('Description', style: ElioText.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _buildTextField(_descriptionController, 'Optional — a short description', maxLines: 2),
          const SizedBox(height: 20),
          // Ingredients
          Row(
            children: [
              Text('Ingredients', style: ElioText.label.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _addIngredientRow,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: ElioColors.terracotta),
                    const SizedBox(width: 4),
                    Text('Add', style: ElioText.label.copyWith(color: ElioColors.terracotta, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_ingredientRows.length, (i) => _buildIngredientRow(i)),
          const SizedBox(height: 20),
          // Instructions
          Text('Instructions', style: ElioText.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _buildTextField(
            _instructionsController,
            'Paste or type the full instructions...',
            maxLines: 8,
          ),
          const SizedBox(height: 28),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveManualRecipe,
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.terracotta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Save Recipe',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: ElioText.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
        filled: true,
        fillColor: ElioColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElioColors.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElioColors.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ElioColors.terracotta, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildIngredientRow(int index) {
    final row = _ingredientRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Quantity + unit
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.quantityController,
              style: ElioText.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Qty',
                hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                filled: true,
                fillColor: ElioColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ElioColors.rule),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ElioColors.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ElioColors.terracotta, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: TextField(
              controller: row.nameController,
              style: ElioText.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ingredient name',
                hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                filled: true,
                fillColor: ElioColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ElioColors.rule),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ElioColors.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ElioColors.terracotta, width: 1.5),
                ),
              ),
            ),
          ),
          // Remove button (if more than 1 row)
          if (_ingredientRows.length > 1)
            GestureDetector(
              onTap: () => _removeIngredientRow(index),
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.close_rounded, size: 18, color: ElioColors.mocha),
              ),
            ),
        ],
      ),
    );
  }

  void _addIngredientRow() {
    setState(() => _ingredientRows.add(_IngredientRow()));
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _ingredientRows[index].dispose();
      _ingredientRows.removeAt(index);
    });
  }

  Future<void> _saveManualRecipe() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a recipe title.'),
          backgroundColor: ElioColors.espresso,
        ),
      );
      return;
    }

    // Parse ingredients
    final ingredients = <RecipeIngredient>[];
    for (final row in _ingredientRows) {
      final name = row.nameController.text.trim();
      if (name.isEmpty) continue;
      final qtyRaw = row.quantityController.text.trim();
      // Try to split quantity and unit (e.g. "200g" → "200", "g")
      String quantity = qtyRaw;
      String unit = '';
      final match = RegExp(r'^([\d./½¼¾⅓⅔]+)\s*([a-zA-Z]*)$').firstMatch(qtyRaw);
      if (match != null) {
        quantity = match.group(1) ?? qtyRaw;
        unit = match.group(2) ?? '';
      }
      ingredients.add(RecipeIngredient(
        name: name,
        quantity: quantity,
        unit: unit,
        fromInventory: false,
      ));
    }

    // Parse instructions into steps
    final rawInstructions = _instructionsController.text.trim();
    List<String> steps;
    if (rawInstructions.isEmpty) {
      steps = [];
    } else {
      // Split by newlines, numbered list items, or periods followed by capital letters
      steps = rawInstructions
          .split(RegExp(r'\n+|(?<=\.)\s+(?=[A-Z\d])'))
          .map((s) => s.replaceFirst(RegExp(r'^\d+[.)\s]+'), '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final recipe = GeneratedRecipe(
      title: title,
      description: _descriptionController.text.trim(),
      prepTimeMinutes: 0,
      cookTimeMinutes: 0,
      servings: 2,
      ingredients: ingredients,
      steps: steps,
      substitutions: [],
      dietaryTags: [],
    );

    if (!mounted) return;

    // Navigate to recipe screen — autoSave handles saving + bookmarking
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeScreen(recipe: recipe, autoSave: true),
      ),
    );
  }
}

// ─── Helper class for ingredient rows ────────────────────────────────────────

class _IngredientRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
