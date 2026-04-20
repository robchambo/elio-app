# Onboarding Rebuild — 15-Screen Flow with Deferred Sign-In

> **⏸ RESUME MARKER (20 Apr 2026):** Phases 0–4 complete and pushed on branch `sprint/16-onboarding-rebuild` (32 commits, 194 tests passing, `flutter analyze` clean). **Next up: Phase 5 — Task 5.0 Gemini ephemeral spike, then Task 5.1 screen 13 first-recipe demo.** Before resuming, Rob to decide on (1) screen-12 `expiryDate` mapping vs spec §Data model, (2) screen-11 default count (20 vs "~16"), (3) palette token hex ratification, (4) screen-10 hero art. Use `superpowers:executing-plans` + subagent-per-phase pattern already established in Phases 1–4.


**Goal:** Replace Elio's existing 8-screen, sign-in-first onboarding with a 15-screen, value-first flow that defers authentication to the final screen. The user sells-to-self on screen 01, personalises via screens 02–09, builds a real pantry on screens 11–12, sees a live Gemini-generated recipe on screen 13, meets the paywall on 14, and only then hits a soft account gate on 15. All pre-sign-in state lives in-memory (`OnboardingController`) and is migrated to Firestore post-auth by a new `MigrationService`.

**Architecture:** In-memory `OnboardingController extends ChangeNotifier` wraps an extended `OnboardingState`. `GuestPantryService` is extended to persist screens 11/12 to `SharedPreferences` for crash-resume. `AuthGate` is inverted to key off `SharedPreferences.getBool('onboardingComplete')` rather than `FirebaseAuth.currentUser`. Screen 13 calls `GeminiService` with ephemeral pantry/preferences (no Firestore read). Screen 15's sign-in success triggers `MigrationService.migrateGuestToFirestore(uid)` followed by `Purchases.logIn(uid)` to alias the RevenueCat anonymous ID.

**Tech Stack:** Flutter 3.27.x, Dart `>=3.4.0 <4.0.0`, Sprint 16 design system (`lib/widgets/elio/*`, `lib/theme/elio_*`), Firebase Auth + Firestore, Gemini 2.5-flash streaming (`GeminiService`), RevenueCat (`PurchaseService`), `shared_preferences`, `shimmer`. Tests: `flutter_test` + `WidgetTester` with injected fakes/mocks.

---

## PRE-EXECUTION DECISIONS

Rob — please tick each before kickoff. Defaults are my recommendations; flip any you disagree with.

- [ ] **Q1. Palette tokens for screen 12 perishable tiers.** Default: add `ElioColors.freshGreen = #3D9970` (reuse existing `success`), `ElioColors.perishThisWeek = #F08C14` (reuse `amber`), `ElioColors.perishToday = #E06C5E` (new coral). **Placeholder hex — confirm with Kate before Phase 4.**
- [ ] **Q2. "I already have an account" link on screen 01.** Default: YES — small `TextButton` below primary CTA, routes to `lib/screens/auth/email_login_screen.dart`.
- [ ] **Q3. Remove `customAllergens` field.** Default: YES — fold into new `allergies: List<String>`. **Grep confirms no downstream reader (verify in Task 0.1 Step 0).**
- [ ] **Q4. Crash-resume scope v1.** Default: persist only on screens 11/12 completion to `SharedPreferences`. No resume on 01–10; fast re-entry only.
- [ ] **Q5. Analytics.** Default: KEEP `onboarding_step_completed` funnel event + ADD `onboarding_paywall_viewed`, `onboarding_recipe_demo_started` (w/ `hero_ingredient`), `onboarding_recipe_regenerated` (w/ `count`), `onboarding_account_signin_success`, `onboarding_skipped_signin`.
- [ ] **Q6. Progress bar.** Default: reuse `lib/widgets/elio_progress_bar.dart` if it accepts `value: double` and styles match; otherwise create `ElioOnboardingProgressBar` (15-tick). Decision made in Task 0.7 Step 0.
- [ ] **Q7. Gemini ephemeral pantry.** Default: verify `GeminiService.streamGenerateContent` accepts pantry/preferences as params (Task 5.0 spike). If it reads Firestore directly, add `streamGenerateContentEphemeral(...)` entry point.
- [ ] **Q8. RevenueCat alias.** Default: use `Purchases.logIn(uid)` post-auth on screen 15. Task 6.0 spike confirms `PurchaseService` exposes or can expose this.

**Type conventions (locked):** `userGoal: String?`, `householdType: String?`, `householdCount: int`, `householdHasDifferingDiet: bool`, `householdCombinedDietary: List<String>`, `maxCookTime: int?`, `cookingConfidence: String?`, `region: String` lowercase `uk|us|other`, `measurementUnits: String` `metric|imperial`, `dietary: List<String>`, `allergies: List<String>`, `dislikes: List<String>`, `appliances: List<String>`, `firstRecipeId: String?`, `entitlement: String?`, `regenerateCount: int`.

**Union-of-needs capture (Option B, April 2026):** When `householdCount > 1` and the user toggles "does anyone eat differently?" ON, screen 04 reveals a second multi-select capturing `householdCombinedDietary` — the union of all dietary needs in the household. Screen 13's Gemini call uses `state.effectiveDietary` (a getter on `OnboardingState`: returns `householdCombinedDietary` when `householdHasDifferingDiet && householdCombinedDietary.isNotEmpty`, else `dietary`). Names + per-member assignment stay deferred to post-onboarding Account → Household.

---

## File Structure

### CREATE — models, services, controllers

- `lib/controllers/onboarding_controller.dart`
- `lib/services/migration_service.dart`

### CREATE — widgets (each has widget test under `test/widgets/`)

- `lib/widgets/elio/elio_onboarding_option_card.dart`
- `lib/widgets/elio/elio_onboarding_progress_bar.dart` *(if Q6 says create)*
- `lib/widgets/elio/elio_appliance_tile.dart`
- `lib/widgets/elio/elio_pantry_item_tile.dart`
- `lib/widgets/elio/elio_sticky_category_header.dart`
- `lib/widgets/elio/elio_chip_text_input.dart`
- `lib/widgets/elio/elio_segmented_toggle.dart`
- `lib/widgets/elio/elio_household_stepper.dart`
- `lib/widgets/elio/elio_pantry_tag_pill.dart`
- `lib/widgets/elio/elio_provider_signin_button.dart`
- `lib/widgets/elio/phone_mockup_recipe_card.dart`

### CREATE — screens

- `lib/screens/onboarding/screen01_welcome.dart`
- `lib/screens/onboarding/screen02_goal.dart`
- `lib/screens/onboarding/screen03_household.dart`
- `lib/screens/onboarding/screen04_dietary.dart`
- `lib/screens/onboarding/screen05_allergies.dart`
- `lib/screens/onboarding/screen06_time.dart`
- `lib/screens/onboarding/screen07_confidence.dart`
- `lib/screens/onboarding/screen08_appliances.dart`
- `lib/screens/onboarding/screen09_region.dart`
- `lib/screens/onboarding/screen10_pantry_intro.dart`
- `lib/screens/onboarding/screen11_pantry_staples.dart`
- `lib/screens/onboarding/screen12_pantry_perishables.dart`
- `lib/screens/onboarding/screen13_first_recipe.dart`
- `lib/screens/onboarding/screen14_paywall.dart`
- `lib/screens/onboarding/screen15_account.dart`

### MODIFY

- `lib/models/onboarding_state.dart` — data model delta (see Phase 0)
- `lib/services/guest_pantry_service.dart` — add `saveStaples`, `savePerishables`, `loadAll`, `clear`
- `lib/services/firestore_service.dart` — `completeOnboarding` becomes callable post-sign-in
- `lib/screens/paywall/paywall_screen.dart` — add `PaywallTrigger.first_recipe` + per-goal headline
- `lib/screens/onboarding/onboarding_flow.dart` — full rewrite as coordinator
- `lib/main.dart` / `AuthGate` — invert routing on `onboardingComplete` pref
- `lib/screens/auth/email_login_screen.dart` — on success push `AppShell`, not `OnboardingFlow`
- `lib/screens/auth/email_register_screen.dart` — on success push `AppShell`, not `OnboardingFlow`
- `lib/theme/elio_theme.dart` — add `freshGreen`, `perishToday`, `perishThisWeek` tokens

### DELETE

- `lib/screens/onboarding/screen0_welcome.dart`
- `lib/screens/onboarding/screen1_dietary.dart`
- `lib/screens/onboarding/screen2_preset.dart`
- `lib/screens/onboarding/screen3_pantry.dart`
- `lib/screens/onboarding/screen4_household.dart`
- `lib/screens/onboarding/screen5_style.dart`
- `lib/screens/onboarding/screen6_appliances.dart`
- `lib/screens/onboarding/screen7_units_region.dart`
- `lib/screens/onboarding/screen8_complete.dart`

---

## Phase 0 — Scaffold

### Task 0.1 — OnboardingState data model delta

**Files:**
- Modify: `lib/models/onboarding_state.dart`
- Test: `test/models/onboarding_state_test.dart`

**Step 0 (investigation, 2 min).** Run `rg "customAllergens|kitchenPreset|stylePreferences|additionalMembers"` across `lib/`. Confirm no readers outside onboarding screens. If any exist, surface to Rob before continuing.

**Step 1 — failing test.** Create `test/models/onboarding_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/onboarding_state.dart';

void main() {
  group('OnboardingState', () {
    test('defaults match spec', () {
      final s = OnboardingState();
      expect(s.userGoal, isNull);
      expect(s.householdType, isNull);
      expect(s.householdCount, 1);
      expect(s.householdHasDifferingDiet, false);
      expect(s.householdCombinedDietary, <String>[]);
      expect(s.dietary, <String>[]);
      expect(s.allergies, <String>[]);
      expect(s.dislikes, <String>[]);
      expect(s.maxCookTime, isNull);
      expect(s.cookingConfidence, isNull);
      expect(s.appliances, <String>[]);
      expect(s.region, 'uk');
      expect(s.measurementUnits, 'metric');
      expect(s.inventory, isEmpty);
      expect(s.firstRecipeId, isNull);
      expect(s.entitlement, isNull);
      expect(s.regenerateCount, 0);
    });

    test('copyWith updates userGoal only', () {
      final s = OnboardingState().copyWith(userGoal: 'pantryFirst');
      expect(s.userGoal, 'pantryFirst');
      expect(s.householdCount, 1);
    });

    test('effectiveDietary falls back to user dietary when toggle off', () {
      final s = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: false,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );
      expect(s.effectiveDietary, ['vegan']);
    });

    test('effectiveDietary uses combined when toggle on and non-empty', () {
      final s = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: true,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );
      expect(s.effectiveDietary, ['vegan', 'pescatarian']);
    });

    test('effectiveDietary falls back to user dietary when toggle on but combined empty', () {
      final s = OnboardingState(
        dietary: ['halal'],
        householdHasDifferingDiet: true,
        householdCombinedDietary: [],
      );
      expect(s.effectiveDietary, ['halal']);
    });
  });
}
```

**Step 2.** Run `flutter test test/models/onboarding_state_test.dart -r expanded`. Expect FAIL: `The getter 'userGoal' isn't defined for the type 'OnboardingState'`.

**Step 3 — minimal implementation.** Replace `lib/models/onboarding_state.dart`:

```dart
import 'elio_models.dart';

class OnboardingState {
  String? userGoal;
  String? householdType;
  int householdCount;
  bool householdHasDifferingDiet;
  List<String> householdCombinedDietary;
  List<String> dietary;
  List<String> allergies;
  List<String> dislikes;
  int? maxCookTime;
  String? cookingConfidence;
  List<String> appliances;
  String region;
  String measurementUnits;
  List<InventoryItem> inventory;
  String? firstRecipeId;
  String? entitlement;
  int regenerateCount;

  OnboardingState({
    this.userGoal,
    this.householdType,
    this.householdCount = 1,
    this.householdHasDifferingDiet = false,
    List<String>? householdCombinedDietary,
    List<String>? dietary,
    List<String>? allergies,
    List<String>? dislikes,
    this.maxCookTime,
    this.cookingConfidence,
    List<String>? appliances,
    this.region = 'uk',
    this.measurementUnits = 'metric',
    List<InventoryItem>? inventory,
    this.firstRecipeId,
    this.entitlement,
    this.regenerateCount = 0,
  })  : dietary = dietary ?? [],
        householdCombinedDietary = householdCombinedDietary ?? [],
        allergies = allergies ?? [],
        dislikes = dislikes ?? [],
        appliances = appliances ?? [],
        inventory = inventory ?? [];

  /// Dietary constraints to pass to Gemini.
  /// Returns the household union when the "differing diet" toggle is on
  /// AND the union has been populated; otherwise the user's own dietary.
  List<String> get effectiveDietary =>
      (householdHasDifferingDiet && householdCombinedDietary.isNotEmpty)
          ? householdCombinedDietary
          : dietary;

  OnboardingState copyWith({
    String? userGoal,
    String? householdType,
    int? householdCount,
    bool? householdHasDifferingDiet,
    List<String>? householdCombinedDietary,
    List<String>? dietary,
    List<String>? allergies,
    List<String>? dislikes,
    int? maxCookTime,
    String? cookingConfidence,
    List<String>? appliances,
    String? region,
    String? measurementUnits,
    List<InventoryItem>? inventory,
    String? firstRecipeId,
    String? entitlement,
    int? regenerateCount,
  }) =>
      OnboardingState(
        userGoal: userGoal ?? this.userGoal,
        householdType: householdType ?? this.householdType,
        householdCount: householdCount ?? this.householdCount,
        householdHasDifferingDiet: householdHasDifferingDiet ?? this.householdHasDifferingDiet,
        householdCombinedDietary: householdCombinedDietary ?? this.householdCombinedDietary,
        dietary: dietary ?? this.dietary,
        allergies: allergies ?? this.allergies,
        dislikes: dislikes ?? this.dislikes,
        maxCookTime: maxCookTime ?? this.maxCookTime,
        cookingConfidence: cookingConfidence ?? this.cookingConfidence,
        appliances: appliances ?? this.appliances,
        region: region ?? this.region,
        measurementUnits: measurementUnits ?? this.measurementUnits,
        inventory: inventory ?? this.inventory,
        firstRecipeId: firstRecipeId ?? this.firstRecipeId,
        entitlement: entitlement ?? this.entitlement,
        regenerateCount: regenerateCount ?? this.regenerateCount,
      );

  Map<String, dynamic> toFirestoreMap() => {
        'userGoal': userGoal,
        'householdType': householdType,
        'householdCount': householdCount,
        'householdHasDifferingDiet': householdHasDifferingDiet,
        'householdCombinedDietary': householdCombinedDietary,
        'dietary': dietary,
        'allergies': allergies,
        'dislikes': dislikes,
        'maxCookTime': maxCookTime,
        'cookingConfidence': cookingConfidence,
        'appliances': appliances,
        'region': region,
        'measurementUnits': measurementUnits,
        'firstRecipeId': firstRecipeId,
        'entitlement': entitlement,
      };
}
```

**Step 4.** Run `flutter test test/models/onboarding_state_test.dart -r expanded`. Expect PASS.

**Step 5 — commit.**

```bash
git add lib/models/onboarding_state.dart test/models/onboarding_state_test.dart
git commit -m "feat(sprint-16-onboarding): rebuild OnboardingState to 15-screen spec"
```

---

### Task 0.2 — OnboardingController (ChangeNotifier)

**Files:**
- Create: `lib/controllers/onboarding_controller.dart`
- Test: `test/controllers/onboarding_controller_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/controllers/onboarding_controller.dart';

void main() {
  test('setUserGoal updates state and notifies', () {
    final c = OnboardingController();
    var notified = 0;
    c.addListener(() => notified++);
    c.setUserGoal('pantryFirst');
    expect(c.state.userGoal, 'pantryFirst');
    expect(notified, 1);
  });

  test('incrementRegenerateCount caps at 3', () {
    final c = OnboardingController();
    for (var i = 0; i < 5; i++) {
      c.incrementRegenerateCount();
    }
    expect(c.state.regenerateCount, 3);
  });
}
```

**Step 2.** Run `flutter test test/controllers/onboarding_controller_test.dart -r expanded`. Expect FAIL: file not found.

**Step 3.** Create `lib/controllers/onboarding_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:elio/models/onboarding_state.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingState _state = OnboardingState();
  OnboardingState get state => _state;

  void setUserGoal(String v) { _state = _state.copyWith(userGoal: v); notifyListeners(); }
  void setHouseholdType(String v) { _state = _state.copyWith(householdType: v); notifyListeners(); }
  void setHouseholdCount(int v) { _state = _state.copyWith(householdCount: v); notifyListeners(); }
  void setHouseholdDiffering(bool v) {
    // When toggling OFF, clear the union so effectiveDietary falls back cleanly.
    _state = _state.copyWith(
      householdHasDifferingDiet: v,
      householdCombinedDietary: v ? _state.householdCombinedDietary : <String>[],
    );
    notifyListeners();
  }
  void setHouseholdCombinedDietary(List<String> v) {
    _state = _state.copyWith(householdCombinedDietary: v);
    notifyListeners();
  }
  void setDietary(List<String> v) { _state = _state.copyWith(dietary: v); notifyListeners(); }
  void setAllergies(List<String> v) { _state = _state.copyWith(allergies: v); notifyListeners(); }
  void setDislikes(List<String> v) { _state = _state.copyWith(dislikes: v); notifyListeners(); }
  void setMaxCookTime(int v) { _state = _state.copyWith(maxCookTime: v); notifyListeners(); }
  void setCookingConfidence(String v) { _state = _state.copyWith(cookingConfidence: v); notifyListeners(); }
  void setAppliances(List<String> v) { _state = _state.copyWith(appliances: v); notifyListeners(); }
  void setRegion(String v) { _state = _state.copyWith(region: v); notifyListeners(); }
  void setMeasurementUnits(String v) { _state = _state.copyWith(measurementUnits: v); notifyListeners(); }
  void setInventory(List v) { _state = _state.copyWith(inventory: List.from(v)); notifyListeners(); }
  void setFirstRecipeId(String v) { _state = _state.copyWith(firstRecipeId: v); notifyListeners(); }
  void setEntitlement(String v) { _state = _state.copyWith(entitlement: v); notifyListeners(); }

  void incrementRegenerateCount() {
    if (_state.regenerateCount >= 3) return;
    _state = _state.copyWith(regenerateCount: _state.regenerateCount + 1);
    notifyListeners();
  }
}
```

**Step 4.** Run `flutter test test/controllers/onboarding_controller_test.dart -r expanded`. Expect PASS.

**Step 5 — commit.**

```bash
git add lib/controllers/onboarding_controller.dart test/controllers/onboarding_controller_test.dart
git commit -m "feat(sprint-16-onboarding): add OnboardingController ChangeNotifier"
```

---

### Task 0.3 — Routing inversion on `onboardingComplete` pref

**Files:**
- Modify: `lib/main.dart` (AuthGate)
- Modify: `lib/screens/auth/email_login_screen.dart`
- Modify: `lib/screens/auth/email_register_screen.dart`
- Test: `test/routing/auth_gate_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio/main.dart';

void main() {
  testWidgets('AuthGate routes to OnboardingFlow when onboardingComplete false',
      (t) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': false});
    await t.pumpWidget(const MaterialApp(home: AuthGate()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('onboardingFlowRoot')), findsOneWidget);
  });

  testWidgets('AuthGate routes to AppShell when onboardingComplete true',
      (t) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    await t.pumpWidget(const MaterialApp(home: AuthGate()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('appShellRoot')), findsOneWidget);
  });
}
```

**Step 2.** Run `flutter test test/routing/auth_gate_test.dart -r expanded`. Expect FAIL: wrong route or missing key.

**Step 3.** Edit `AuthGate` in `lib/main.dart` to read `SharedPreferences.getInstance().then((p) => p.getBool('onboardingComplete') ?? false)`. Return `OnboardingFlow(key: Key('onboardingFlowRoot'))` if false, `AppShell(key: Key('appShellRoot'))` if true. Update `email_login_screen.dart` and `email_register_screen.dart` to `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()))` on success.

**Step 4.** Run `flutter test test/routing/auth_gate_test.dart -r expanded`. Expect PASS.

**Step 5 — commit.**

```bash
git add lib/main.dart lib/screens/auth/email_login_screen.dart lib/screens/auth/email_register_screen.dart test/routing/auth_gate_test.dart
git commit -m "feat(sprint-16-onboarding): invert AuthGate to key off onboardingComplete pref"
```

---

### Task 0.4 — Extend GuestPantryService for partial persistence

**Files:**
- Modify: `lib/services/guest_pantry_service.dart`
- Test: `test/services/guest_pantry_service_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio/services/guest_pantry_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saveStaples + loadAll round-trips', () async {
    final svc = GuestPantryService();
    await svc.saveStaples({'olive_oil': 'always', 'pasta': 'usually'});
    final loaded = await svc.loadAll();
    expect(loaded.staples['olive_oil'], 'always');
    expect(loaded.staples['pasta'], 'usually');
  });

  test('clear wipes all keys', () async {
    final svc = GuestPantryService();
    await svc.saveStaples({'onion': 'always'});
    await svc.clear();
    final loaded = await svc.loadAll();
    expect(loaded.staples, isEmpty);
  });
}
```

**Step 2.** Run `flutter test test/services/guest_pantry_service_test.dart -r expanded`. Expect FAIL: method `saveStaples` not defined.

**Step 3.** Add to `lib/services/guest_pantry_service.dart`:

```dart
Future<void> saveStaples(Map<String, String> tiers) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('guest_staples', jsonEncode(tiers));
}

Future<void> savePerishables(Map<String, String> tiers) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('guest_perishables', jsonEncode(tiers));
}

Future<GuestPantrySnapshot> loadAll() async {
  final p = await SharedPreferences.getInstance();
  final staples = _decode(p.getString('guest_staples'));
  final perish = _decode(p.getString('guest_perishables'));
  return GuestPantrySnapshot(staples: staples, perishables: perish);
}

Future<void> clear() async {
  final p = await SharedPreferences.getInstance();
  await p.remove('guest_staples');
  await p.remove('guest_perishables');
}

Map<String, String> _decode(String? s) =>
    s == null ? {} : Map<String, String>.from(jsonDecode(s) as Map);
```

Plus new `GuestPantrySnapshot({required this.staples, required this.perishables})` class at bottom of file.

**Step 4.** Run `flutter test test/services/guest_pantry_service_test.dart -r expanded`. Expect PASS.

**Step 5 — commit.**

```bash
git add lib/services/guest_pantry_service.dart test/services/guest_pantry_service_test.dart
git commit -m "feat(sprint-16-onboarding): extend GuestPantryService for partial persistence"
```

---

### Task 0.5 — MigrationService stub

**Files:**
- Create: `lib/services/migration_service.dart`
- Test: `test/services/migration_service_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/onboarding_state.dart';
import 'package:elio/services/migration_service.dart';

void main() {
  test('buildUserDocPayload includes all spec fields', () {
    final s = OnboardingState()
      ..userGoal = 'pantryFirst'
      ..householdType = 'couple';
    final payload = MigrationService.buildUserDocPayload(s);
    expect(payload['userGoal'], 'pantryFirst');
    expect(payload['householdType'], 'couple');
    expect(payload['dietary'], <String>[]);
  });
}
```

**Step 2.** Run `flutter test test/services/migration_service_test.dart -r expanded`. Expect FAIL: file not found.

**Step 3.** Create `lib/services/migration_service.dart`:

```dart
import 'package:elio/models/onboarding_state.dart';

class MigrationService {
  static Map<String, dynamic> buildUserDocPayload(OnboardingState s) =>
      s.toFirestoreMap();

  // Full implementation (Firestore writes + RC alias) lands in Task 6.5.
  static Future<void> migrateGuestToFirestore(String uid, OnboardingState s) async {
    throw UnimplementedError('Implemented in Task 6.5');
  }
}
```

**Step 4.** Run `flutter test test/services/migration_service_test.dart -r expanded`. Expect PASS.

**Step 5 — commit.**

```bash
git add lib/services/migration_service.dart test/services/migration_service_test.dart
git commit -m "feat(sprint-16-onboarding): MigrationService stub with payload builder"
```

---

### Task 0.6 — Palette tokens for perishable tiers

**Files:**
- Modify: `lib/theme/elio_theme.dart`
- Test: `test/theme/elio_theme_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';

void main() {
  test('perishable tokens resolve', () {
    expect(ElioColors.freshGreen, const Color(0xFF3D9970));
    expect(ElioColors.perishThisWeek, ElioColors.amber);
    expect(ElioColors.perishToday, const Color(0xFFE06C5E));
  });
}
```

**Step 2.** Run `flutter test test/theme/elio_theme_test.dart -r expanded`. Expect FAIL.

**Step 3.** Add to `ElioColors` class in `lib/theme/elio_theme.dart`:

```dart
static const Color freshGreen = Color(0xFF3D9970);
static const Color perishThisWeek = amber;
static const Color perishToday = Color(0xFFE06C5E);
```

**Step 4.** PASS.

**Step 5 — commit.**

```bash
git add lib/theme/elio_theme.dart test/theme/elio_theme_test.dart
git commit -m "feat(sprint-16-onboarding): add perishable-tier palette tokens (placeholder hex)"
```

---

### Task 0.7 — Progress bar widget decision

**Files:**
- Inspect: `lib/widgets/elio_progress_bar.dart`
- If reuse: no-op. If create: `lib/widgets/elio/elio_onboarding_progress_bar.dart` + test.

**Step 0 (Q6).** Read existing progress bar. If it accepts `double value` 0.0–1.0 and renders amber over cream with `elio_radii.chip` rounding, reuse. Else create.

**Step 1 — failing test (if creating).**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  testWidgets('renders value 0.0..1.0', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElioOnboardingProgressBar(value: 0.4)),
    ));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, 0.4);
  });

  testWidgets('clamps out-of-range', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElioOnboardingProgressBar(value: 2.0)),
    ));
    expect(tester_findClamped(t), 1.0);
  });
}

double tester_findClamped(WidgetTester t) => (t
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value ??
    0);
```

**Step 2.** FAIL: file not found.

**Step 3.**

```dart
import 'package:flutter/material.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_radii.dart';

class ElioOnboardingProgressBar extends StatelessWidget {
  final double value;
  const ElioOnboardingProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ElioRadii.chip),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 6,
        backgroundColor: ElioColors.cream.withValues(alpha: 0.5),
        valueColor: const AlwaysStoppedAnimation(ElioColors.amber),
      ),
    );
  }
}
```

**Step 4.** PASS.

**Step 5 — commit.**

```bash
git add lib/widgets/elio/elio_onboarding_progress_bar.dart test/widgets/elio_onboarding_progress_bar_test.dart
git commit -m "feat(sprint-16-onboarding): add ElioOnboardingProgressBar"
```

---

### Tasks 0.8–0.15 — Shared widgets (one per widget, TDD)

Each of these follows the same shape: failing test → expect FAIL → minimal widget → PASS → commit. Files listed in File Structure above. Every widget test:

- Pumps the widget inside `MaterialApp(home: Scaffold(body: ...))`.
- Asserts selected state toggles via `tester.tap`.
- Asserts `.withValues(alpha:)` usage only (no `.withOpacity`).
- Asserts callback is invoked with the expected value.

| # | Widget | Key test assertion |
|---|---|---|
| 0.8 | `ElioOnboardingOptionCard` | tap fires `onTap(value)`; `selected: true` renders amber border |
| 0.9 | `ElioHouseholdStepper` | `+`/`-` clamps to 1..10, fires `onChanged(int)`, sets `manuallyEdited` |
| 0.10 | `ElioChipTextInput` | `onSubmitted` adds to `values`, duplicate rejected, X chip removes |
| 0.11 | `ElioSegmentedToggle` | two-segment toggle fires `onChanged(String)` with the new value |
| 0.12 | `ElioApplianceTile` | multi-select toggle with checkmark |
| 0.13 | `ElioPantryItemTile` (2-tier variant + 3-tier variant) | tap cycles, `RawGestureDetector` present; LongPressGestureRecognizer duration 300ms |
| 0.14 | `ElioStickyCategoryHeader` | renders title + count badge |
| 0.15 | `ElioPantryTagPill` | renders tag label, colour dot |
| 0.16 | `ElioProviderSignInButton` | provider icon + label; iOS-only visibility flag respected |
| 0.17 | `PhoneMockupRecipeCard` | renders demo recipe + 3 tag pills |

**Example Task 0.13 — `ElioPantryItemTile` failing test (demonstrating long-press constraint):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/widgets/elio/elio_pantry_item_tile.dart';

void main() {
  testWidgets('uses RawGestureDetector with 300ms long-press', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioPantryItemTile(
          label: 'Olive oil',
          tier: 'unselected',
          tiers: const ['unselected', 'usually', 'always'],
          onCycle: (_) {},
          onJumpToTop: () {},
        ),
      ),
    ));
    final raw = t.widget<RawGestureDetector>(find.byType(RawGestureDetector));
    expect(raw.gestures.keys, contains(LongPressGestureRecognizer));
  });

  testWidgets('tap cycles tiers', (t) async {
    String? next;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioPantryItemTile(
          label: 'Olive oil',
          tier: 'unselected',
          tiers: const ['unselected', 'usually', 'always'],
          onCycle: (v) => next = v,
          onJumpToTop: () {},
        ),
      ),
    ));
    await t.tap(find.byType(ElioPantryItemTile));
    expect(next, 'usually');
  });
}
```

Commit each widget independently with message `feat(sprint-16-onboarding): add <WidgetName>`.

---

## Phase 1 — Welcome (01) + Goal (02)

### Task 1.1 — screen01_welcome.dart

**Files:**
- Create: `lib/screens/onboarding/screen01_welcome.dart`
- Test: `test/screens/onboarding/screen01_welcome_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/controllers/onboarding_controller.dart';
import 'package:elio/screens/onboarding/screen01_welcome.dart';

void main() {
  testWidgets('no back button on screen 01', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Screen01Welcome(
        controller: OnboardingController(),
        onContinue: () {},
      ),
    ));
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('Get started CTA fires onContinue', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(
      home: Screen01Welcome(
        controller: OnboardingController(),
        onContinue: () => tapped = true,
      ),
    ));
    await t.tap(find.text('Get started'));
    expect(tapped, true);
  });

  testWidgets('I already have an account link present (Q2)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Screen01Welcome(
        controller: OnboardingController(),
        onContinue: () {},
      ),
    ));
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
```

**Step 2.** FAIL.

**Step 3.**

```dart
import 'package:flutter/material.dart';
import 'package:elio/controllers/onboarding_controller.dart';
import 'package:elio/widgets/elio/elio_big_button.dart';
import 'package:elio/widgets/elio/elio_hero_heading.dart';
import 'package:elio/widgets/elio/phone_mockup_recipe_card.dart';
import 'package:elio/screens/auth/email_login_screen.dart';

class Screen01Welcome extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  const Screen01Welcome({super.key, required this.controller, required this.onContinue});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const PhoneMockupRecipeCard(),
                const SizedBox(height: 24),
                const ElioHeroHeading(
                  lines: ['Cook what', 'you already', 'have'],
                  accentLine: 2,
                ),
                const Spacer(),
                ElioBigButton(label: 'Get started', onTap: onContinue),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const EmailLoginScreen())),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ),
      );
}
```

**Step 4.** PASS.

**Step 5.**

```bash
git add lib/screens/onboarding/screen01_welcome.dart test/screens/onboarding/screen01_welcome_test.dart
git commit -m "feat(sprint-16-onboarding): screen 01 welcome hook"
```

---

### Task 1.2 — screen02_goal.dart

**Files:**
- Create: `lib/screens/onboarding/screen02_goal.dart`
- Test: `test/screens/onboarding/screen02_goal_test.dart`

**Step 1 — failing test.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/controllers/onboarding_controller.dart';
import 'package:elio/screens/onboarding/screen02_goal.dart';

void main() {
  testWidgets('Continue disabled until a goal is picked', (t) async {
    final c = OnboardingController();
    await t.pumpWidget(MaterialApp(
      home: Screen02Goal(controller: c, onContinue: () {}, onBack: () {}),
    ));
    final cta = t.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
    expect(cta.onPressed, isNull);
  });

  testWidgets('selecting pantryFirst sets state.userGoal and enables CTA', (t) async {
    final c = OnboardingController();
    await t.pumpWidget(MaterialApp(
      home: Screen02Goal(controller: c, onContinue: () {}, onBack: () {}),
    ));
    await t.tap(find.text('Use what I already have'));
    await t.pump();
    expect(c.state.userGoal, 'pantryFirst');
  });
}
```

**Step 2.** FAIL.

**Step 3.**

```dart
import 'package:flutter/material.dart';
import 'package:elio/controllers/onboarding_controller.dart';
import 'package:elio/widgets/elio/elio_big_button.dart';
import 'package:elio/widgets/elio/elio_hero_heading.dart';
import 'package:elio/widgets/elio/elio_onboarding_option_card.dart';

class Screen02Goal extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  const Screen02Goal({super.key, required this.controller, required this.onContinue, required this.onBack});
  @override
  State<Screen02Goal> createState() => _S();
}

class _S extends State<Screen02Goal> {
  static const _options = [
    ('pantryFirst', 'Use what I already have', 'Recipes built around your pantry'),
    ('wasteReduction', 'Waste less food', 'Catch things before they go off'),
    ('decisionFatigue', 'Skip the 6pm panic', 'Dinner sorted in seconds'),
    ('household', 'Feed the whole household', 'One plan, everyone fed'),
    ('takeawayEscape', 'Stop ordering takeaway', 'Eat in without the effort'),
  ];

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (c, _) => Column(children: [
                const ElioHeroHeading(lines: ['What brings you here?']),
                const SizedBox(height: 16),
                ..._options.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElioOnboardingOptionCard(
                        value: o.$1,
                        title: o.$2,
                        subtitle: o.$3,
                        selected: widget.controller.state.userGoal == o.$1,
                        onTap: (v) => widget.controller.setUserGoal(v),
                      ),
                    )),
                const Spacer(),
                ElioBigButton(
                  label: 'Continue',
                  onTap: widget.controller.state.userGoal == null ? null : widget.onContinue,
                ),
              ]),
            ),
          ),
        ),
      );
}
```

**Step 4.** PASS.

**Step 5.**

```bash
git add lib/screens/onboarding/screen02_goal.dart test/screens/onboarding/screen02_goal_test.dart
git commit -m "feat(sprint-16-onboarding): screen 02 goal single-select"
```

---

## Phase 2 — Household (03) + Dietary (04) + Allergies (05)

Each task follows the Phase 1 shape. Skeleton given; copy exact per-screen spec from `docs/onboarding/0N-*.md`.

### Task 2.1 — screen03_household.dart

Required assertions in test:
- Continue disabled until `householdType != null`.
- Tapping `couple` sets `householdType = 'couple'` and pre-fills `householdCount = 2`.
- `ElioHouseholdStepper` appears only when a type card is selected.
- Changing stepper sets `countManuallyEdited = true`.

Implementation reuses `ElioOnboardingOptionCard` and `ElioHouseholdStepper`. Commit: `feat(sprint-16-onboarding): screen 03 household`.

### Task 2.2 — screen04_dietary.dart

Test assertions:
- `vegan` auto-excludes `vegetarian`/`pescatarian` (mutual-exclusion logic) on the primary multi-select.
- `none` clears all others when selected.
- `householdHasDifferingDiet` `SwitchListTile` only rendered when `controller.state.householdCount > 1`.
- **Toggle OFF → only primary multi-select visible; no union section; `state.householdCombinedDietary == []`.**
- **Toggle ON → union multi-select reveals below the toggle row, seeded with the primary selection (`state.householdCombinedDietary` initialised to a copy of `state.dietary`).**
- **Tapping a union card toggles it in `state.householdCombinedDietary`; same mutual-exclusion rules as the primary selector.**
- **Toggle ON→OFF transition clears `state.householdCombinedDietary` to `[]` and collapses the union section.**
- **Continue disabled while toggle ON and `householdCombinedDietary` is empty; hint text "Pick at least one — or turn the toggle off if everyone's the same." renders non-blockingly.**

Implementation note: wire the union selector to `controller.setHouseholdCombinedDietary(newList)`. The screen does NOT need to know about `effectiveDietary` — that getter is consumed on screen 13 only. Commit: `feat(sprint-16-onboarding): screen 04 dietary multi-select + household union`.

### Task 2.3 — screen05_allergies.dart

Test assertions:
- 9 preset chips (`peanut`, `treenut`, `dairy`, `egg`, `gluten`, `shellfish`, `soy`, `sesame`, `fish`) render.
- "Other" inline input expands to `ElioChipTextInput`; submitted tag appends to `state.allergies`.
- Dislikes use a separate `ElioChipTextInput` writing to `state.dislikes`.

Commit: `feat(sprint-16-onboarding): screen 05 allergies & dislikes`.

---

## Phase 3 — Time (06) + Confidence (07) + Appliances (08) + Region (09)

### Task 3.1 — screen06_time.dart

Asserts: 4 option cards `{15, 30, 45, 75}`, tap sets `maxCookTime: int`, Continue disabled until non-null. Commit: `feat(sprint-16-onboarding): screen 06 max cook time`.

### Task 3.2 — screen07_confidence.dart

Asserts: 3 option cards, subhead reads "Short on time? We've got you." when `maxCookTime == 15`, otherwise default copy. Commit: `feat(sprint-16-onboarding): screen 07 cooking confidence`.

### Task 3.3 — screen08_appliances.dart

Asserts: 11 `ElioApplianceTile`s in a 3-column grid; `oven`, `hob`, `microwave` pre-selected on first render; multi-select toggles work. Commit: `feat(sprint-16-onboarding): screen 08 appliances grid`.

### Task 3.4 — screen09_region.dart

Asserts: `ElioSegmentedToggle` pre-selects based on `Localizations.localeOf(context).countryCode` (`GB` → `uk`, `US` → `us`, else `other`); changing region updates `measurementUnits` default (`uk|other` → metric, `us` → imperial); user can still override units independently. Commit: `feat(sprint-16-onboarding): screen 09 region & units`.

---

## Phase 4 — Pantry intro (10) + Staples (11) + Perishables (12)

### Task 4.1 — screen10_pantry_intro.dart

Asserts: hero illustration renders; subhead reads goal-specific copy (switch on `state.userGoal` — 5 branches). Commit: `feat(sprint-16-onboarding): screen 10 pantry intro hook`.

### Task 4.2 — screen11_pantry_staples.dart

**Files:**
- Create: `lib/screens/onboarding/screen11_pantry_staples.dart`
- Test: `test/screens/onboarding/screen11_pantry_staples_test.dart`

**Key test assertions:**
- 12 sticky `ElioStickyCategoryHeader`s rendered in a `CustomScrollView`.
- Tap on an `ElioPantryItemTile` cycles `unselected → usually → always → unselected`.
- Long-press (via `LongPressGestureRecognizer(Duration(milliseconds: 300))`) jumps to `always` regardless of current tier.
- `~16` defaults pre-selected respect dietary filters (vegan state → no honey).
- Sticky CTA footer shows live count `"N items in your pantry"`.
- Persists via `GuestPantryService.saveStaples` on Continue.

Code block uses `RawGestureDetector` + `LongPressGestureRecognizer(duration: Duration(milliseconds: 300))` as mandated. Commit: `feat(sprint-16-onboarding): screen 11 pantry staples`.

### Task 4.3 — screen12_pantry_perishables.dart

**Key test assertions:**
- Tap cycles `unselected → fresh(green) → thisWeek(amber) → today(red) → unselected`.
- Long-press opens action sheet via `showDialog` (NOT `showModalBottomSheet`).
- Selecting `today` derives `expiryDate = DateTime.now()` and `runningLow = true`.
- Selecting `thisWeek` derives `expiryDate = now + Duration(days: 7)`.
- Sticky CTA renders `"N fresh · M today"`, switches to red when `M > 0`.
- Persists via `GuestPantryService.savePerishables` on Continue.

Reuses `ElioPantryItemTile` 3-tier variant. Commit: `feat(sprint-16-onboarding): screen 12 pantry perishables`.

---

## Phase 5 — First recipe demo (13)

### Task 5.0 — Gemini spike (Q7)

**Files:**
- Read: `lib/services/gemini_service.dart`
- Write scratch notes in PR description — no code change unless a new entry point is needed.

**Deliverable:** Confirm whether `streamGenerateContent` accepts ephemeral pantry/preferences as params. If yes, use it directly in 5.1. If no, add `Future<Stream<RecipeGenerationStatus>> streamGenerateContentEphemeral({required List<InventoryItem> pantry, required OnboardingState prefs, String? heroIngredientName})` that bypasses Firestore reads and builds the prompt via existing `_buildPrompt` but accepts the required hero ingredient as a client-side override. **The prompt's `dietary` field must be populated from `prefs.effectiveDietary` (not `prefs.dietary`)** — this is the hook for Option B's household union capture. Add a one-line assertion in `_buildPrompt` or the ephemeral entry point that reads the getter.

No commit unless code changes. If new method added: commit `feat(sprint-16-onboarding): GeminiService ephemeral entry point`.

### Task 5.1 — screen13_first_recipe.dart

**Files:**
- Create: `lib/screens/onboarding/screen13_first_recipe.dart`
- Create: `test/screens/onboarding/screen13_first_recipe_test.dart` (uses `FakeGeminiService`)

**Key test assertions:**
- Hero ingredient selected by cascade: `today` > `thisWeek` > `fresh` > meat > veg.
- Calls `FakeGeminiService.streamGenerateContentEphemeral(...)` with hero-ingredient as REQUIRED.
- **Fake asserts `prefs.effectiveDietary` matches the captured union when `householdHasDifferingDiet=true`:** test sets up controller with `dietary=['vegan']`, `householdHasDifferingDiet=true`, `householdCombinedDietary=['vegan','pescatarian']`, then verifies the fake received `['vegan','pescatarian']` in the prompt's dietary constraint.
- **Separate test case with toggle OFF verifies fake received only `['vegan']` (the user's own).**
- During streaming, renders shimmer skeleton (reuse existing from `lib/screens/home/`).
- Ingredient rows show `ElioPantryTagPill` for items already in pantry.
- `Show me another` bumps `regenerateCount`, disabled at 3.
- `Cook this tonight` fires `onContinue` with `firstRecipeId` set on controller.
- Error state offers `Retry` + `Skip for now` (latter advances without `firstRecipeId`).

Commit: `feat(sprint-16-onboarding): screen 13 first recipe demo`.

---

## Phase 6 — Paywall (14) + Account (15)

### Task 6.0 — PurchaseService RC alias spike (Q8)

Read `lib/services/purchase_service.dart`; confirm or add `Future<void> aliasToUid(String uid)` calling `Purchases.logIn(uid)`. Commit if added: `feat(sprint-16-onboarding): PurchaseService aliasToUid`.

### Task 6.1 — Paywall trigger addition

**Files:** Modify `lib/screens/paywall/paywall_screen.dart`.

Add `PaywallTrigger.first_recipe` enum value + headline switch:

```dart
case PaywallTrigger.first_recipe:
  switch (onboarding?.userGoal) {
    case 'pantryFirst': return 'Keep cooking what you have.';
    case 'wasteReduction': return 'Waste less, every week.';
    case 'decisionFatigue': return 'No more 6pm panic.';
    case 'household': return 'One plan for the whole house.';
    case 'takeawayEscape': return 'Skip the takeaway.';
    default: return 'Start your 7-day free trial.';
  }
```

Add optional `recipeThumbnailUrl` param rendered at top. Commit: `feat(sprint-16-onboarding): paywall first_recipe trigger + goal headlines`.

### Task 6.2 — screen14_paywall.dart

Test: `✕` calls `onBack()` (returns to 13 non-destructively); `Continue with Free` sets `state.entitlement = 'free'` and fires `onContinue`; `Start Free Trial` resolves via `FakePurchaseService` and sets `state.entitlement = 'pro'`. Commit: `feat(sprint-16-onboarding): screen 14 paywall wrapper`.

### Task 6.3 — screen15_account.dart

**Files:**
- Create: `lib/screens/onboarding/screen15_account.dart`
- Test: `test/screens/onboarding/screen15_account_test.dart`

**Key test assertions:**
- On iOS (`Platform.isIOS`) Apple button visible; on Android it is not.
- All three provider buttons present as peers (no primary-style distinction).
- `Skip for now` sets `SharedPreferences` `onboardingComplete = true` and navigates to `AppShell`.
- Successful sign-in calls `FakeMigrationService.migrateGuestToFirestore(uid, state)` and `FakePurchaseService.aliasToUid(uid)`.
- Analytics event `onboarding_account_signin_success` or `onboarding_skipped_signin` fired.

Commit: `feat(sprint-16-onboarding): screen 15 soft account gate`.

### Task 6.4 — Full MigrationService implementation

**Files:** Modify `lib/services/migration_service.dart` + test.

Implementation writes `users/{uid}` doc with `toFirestoreMap()`, batches inventory items under `users/{uid}/inventory/{id}`, calls `Purchases.logIn(uid)`, clears `GuestPantryService`. Test uses `FakeFirebaseFirestore`. Commit: `feat(sprint-16-onboarding): MigrationService full implementation`.

---

## Phase 7 — Wire-up & Hardening

### Task 7.1 — Rewrite onboarding_flow.dart coordinator

**Files:** Replace `lib/screens/onboarding/onboarding_flow.dart`.

Coordinator uses a `PageController` and `OnboardingController` injected at root. Renders top `ElioOnboardingProgressBar(value: (index + 1) / 15)` from screen 02 onward. Index transitions are `animateToPage`. Back button on screens 02–15 calls `previousPage`. Screen 15 replaces the root with `AppShell` via `pushReplacement`.

Test: `pumpWidget(OnboardingFlow())`, verify initial index 0, tap Get started, verify at index 1, tap back, verify at index 0. Commit: `feat(sprint-16-onboarding): OnboardingFlow coordinator`.

### Task 7.2 — Delete old screens

```bash
git rm lib/screens/onboarding/screen0_welcome.dart \
       lib/screens/onboarding/screen1_dietary.dart \
       lib/screens/onboarding/screen2_preset.dart \
       lib/screens/onboarding/screen3_pantry.dart \
       lib/screens/onboarding/screen4_household.dart \
       lib/screens/onboarding/screen5_style.dart \
       lib/screens/onboarding/screen6_appliances.dart \
       lib/screens/onboarding/screen7_units_region.dart \
       lib/screens/onboarding/screen8_complete.dart
flutter analyze
```

Fix any import-not-found in callers (email_login/register should already be done in Task 0.3). Commit: `chore(sprint-16-onboarding): remove legacy 8-screen flow`.

### Task 7.3 — Analytics wiring

Add analytics calls per Q5 spec at each screen's `onContinue`. Test with `FakeAnalyticsService`. Commit: `feat(sprint-16-onboarding): onboarding analytics events`.

### Task 7.4 — Final verification

```bash
flutter analyze
flutter test
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint 16.1
```

Expect zero analyze warnings, all tests green, APK builds. On-device smoke test: launch fresh (clear app data), walk screens 01 → 15, verify Firestore write post-sign-in matches `toFirestoreMap`. Tag working build `v16.1-onboarding-rebuild`. Commit: `chore(sprint-16-onboarding): verified on-device; release build`.

---

## Execution Handoff

**Subagent-driven execution (recommended):** Phase 0 widgets (0.8–0.17) are fully independent — dispatch in parallel via `superpowers:dispatching-parallel-agents`. Phases 1–4 screens are serial because each depends on the controller's prior state being correct. Phase 5 must wait on Task 5.0 spike result. Phases 6–7 serial.

**Inline execution:** Single-agent, sequential through phases. ~25 commits total. Estimate 3–4 full working days.

Pick subagent-driven for Phase 0 (save ~40 min), then inline from Phase 1 onwards so downstream screens observe each prior screen's controller state in the running app.
