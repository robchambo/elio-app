import 'package:elio_app/screens/onboarding/screen14_paywall.dart';

// ─────────────────────────────────────────────
// FakeTrialStarter — test double for screen 14's trial start hook.
//
// Records every invocation of [startDefaultTrial] and returns the
// configured [simulatedSuccess] value. Tests flip [simulatedSuccess]
// to true to drive the "entitlement = pro" path, leave it false to
// drive the failure path.
// ─────────────────────────────────────────────

class FakeTrialStarter implements TrialStarter {
  bool simulatedSuccess;
  int calls = 0;

  FakeTrialStarter({this.simulatedSuccess = true});

  @override
  Future<bool> startDefaultTrial() async {
    calls++;
    return simulatedSuccess;
  }
}
