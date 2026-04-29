import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  test('perishable tokens resolve', () {
    expect(ElioColors.freshGreen, const Color(0xFF3D9970));
    expect(ElioColors.perishThisWeek, ElioColors.amber);
    expect(ElioColors.perishToday, const Color(0xFFE06C5E));
  });

  group('elioTheme()', () {
    test('uses cream as scaffoldBackgroundColor', () {
      final t = elioTheme();
      expect(t.scaffoldBackgroundColor, ElioColors.cream);
    });
    test('primary colour is terracotta', () {
      final t = elioTheme();
      expect(t.colorScheme.primary, ElioColors.terracotta);
    });
    test('text theme bodyMedium uses DM Sans', () {
      final t = elioTheme();
      expect(t.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    });
    test('text theme displayLarge uses Bricolage Grotesque', () {
      final t = elioTheme();
      expect(t.textTheme.displayLarge?.fontFamily, 'Bricolage Grotesque');
    });
    test('elevatedButton background is terracotta', () {
      final t = elioTheme();
      final style = t.elevatedButtonTheme.style;
      expect(style, isNotNull);
      final bg = style!.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, ElioColors.terracotta);
    });
  });
}
