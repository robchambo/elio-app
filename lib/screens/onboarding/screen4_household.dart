import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_custom_field.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

// ─────────────────────────────────────────────
// Screen 4 — Add Household Members (Optional)
// "Anyone else eating with you?"
// List with + Add person. Each person completes dietary in a bottom sheet.
// "Skip for now" is clearly visible — only optional step in onboarding.
// ─────────────────────────────────────────────

class HouseholdScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState updated) onComplete;
  final VoidCallback onBack;

  const HouseholdScreen({
    super.key,
    required this.state,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  late List<HouseholdProfile> _members;

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.state.additionalMembers);
  }

  void _addMember() async {
    final result = await showModalBottomSheet<HouseholdProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddMemberSheet(),
    );
    if (result != null) {
      setState(() => _members.add(result));
    }
  }

  void _removeMember(int index) {
    setState(() => _members.removeAt(index));
  }

  void _complete() {
    widget.onComplete(widget.state.copyWith(additionalMembers: _members));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: ElioProgressBar(currentStep: 4, totalSteps: 8),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ElioColors.navy),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const ElioEyebrow('step 4 of 8'),
                    const SizedBox(height: 12),
                    const ElioHeroHeading(
                      lines: ["who's in", 'your household?'],
                      amberLastLine: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "add household members so elio can respect everyone's dietary needs. this step is optional.",
                      style: ElioTextStyles.body,
                    ),
                    const SizedBox(height: 28),

                    // Member list
                    if (_members.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ElioColors.cream,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline, color: ElioColors.textMuted, size: 22),
                            const SizedBox(width: 12),
                            Text('no household members added yet.', style: ElioTextStyles.body),
                          ],
                        ),
                      )
                    else
                      ..._members.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberCard(
                          profile: entry.value,
                          onRemove: () => _removeMember(entry.key),
                        ),
                      )),

                    const SizedBox(height: 16),

                    // Add person button
                    GestureDetector(
                      onTap: _addMember,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ElioColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ElioColors.amber, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, color: ElioColors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'add a person',
                              style: ElioTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ElioColors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  ElioBigButton(
                    label: _members.isEmpty ? 'Skip for now' : 'Continue',
                    trailingIcon: Icons.chevron_right,
                    onTap: _complete,
                  ),
                  if (_members.isEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'you can add household members later in settings.',
                      style: ElioTextStyles.bodySmall.copyWith(color: ElioColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final HouseholdProfile profile;
  final VoidCallback onRemove;

  const _MemberCard({required this.profile, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ElioColors.navy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: ElioColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  profile.dietaryRequirements.isEmpty
                      ? 'No restrictions'
                      : profile.dietaryRequirements.map((d) => d.label).join(', '),
                  style: ElioText.bodyMedium.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: ElioColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Add Member Bottom Sheet ─────────────────
class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final TextEditingController _nameController = TextEditingController();
  final Set<DietaryRequirement> _selected = {};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(DietaryRequirement req) {
    setState(() {
      if (_selected.contains(req)) {
        _selected.remove(req);
      } else {
        _selected.add(req);
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(HouseholdProfile(
      name: name,
      dietaryRequirements: _selected.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ElioColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ElioColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('add a household member', style: ElioTextStyles.heading3),
            const SizedBox(height: 20),

            const ElioEyebrow('their name'),
            const SizedBox(height: 10),
            ElioCustomField(
              placeholder: 'e.g. partner, child, flatmate',
              controller: _nameController,
              onSubmitted: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            const ElioEyebrow('dietary requirements (optional)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietaryRequirement.values.map((req) {
                final isSelected = _selected.contains(req);
                return ElioChip(
                  label: req.label,
                  selected: isSelected,
                  onTap: () => _toggle(req),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            ElioBigButton(
              label: 'Add member',
              trailingIcon: Icons.chevron_right,
              onTap: _nameController.text.isNotEmpty ? _save : null,
            ),
          ]),
      ),
    );
  }
}
