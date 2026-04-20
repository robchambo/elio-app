import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio_app/services/guest_pantry_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saveStaples + loadAll round-trips', () async {
    final svc = GuestPantryService();
    await svc.saveStaples({'olive_oil': 'always', 'pasta': 'usually'});
    final loaded = await svc.loadAll();
    expect(loaded.staples['olive_oil'], 'always');
    expect(loaded.staples['pasta'], 'usually');
  });

  test('savePerishables + loadAll round-trips', () async {
    final svc = GuestPantryService();
    await svc.savePerishables({'milk': 'today', 'apples': 'thisWeek'});
    final loaded = await svc.loadAll();
    expect(loaded.perishables['milk'], 'today');
    expect(loaded.perishables['apples'], 'thisWeek');
  });

  test('clear wipes all keys', () async {
    final svc = GuestPantryService();
    await svc.saveStaples({'onion': 'always'});
    await svc.savePerishables({'milk': 'today'});
    await svc.clear();
    final loaded = await svc.loadAll();
    expect(loaded.staples, isEmpty);
    expect(loaded.perishables, isEmpty);
  });
}
