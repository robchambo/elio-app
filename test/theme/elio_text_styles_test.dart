import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_text_styles.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  group('ElioTextStyles rebrand ramp', () {
    test('pageTitleStyle uses Bricolage Grotesque w800 size 54', () {
      final s = ElioTextStyles.pageTitleStyle;
      expect(s.fontFamily, 'Bricolage Grotesque');
      expect(s.fontWeight, FontWeight.w800);
      expect(s.fontSize, 54);
      expect(s.color, ElioColors.espresso);
    });
    test('sectionHeadingStyle uses Bricolage Grotesque w700 size 24', () {
      final s = ElioTextStyles.sectionHeadingStyle;
      expect(s.fontFamily, 'Bricolage Grotesque');
      expect(s.fontWeight, FontWeight.w700);
      expect(s.fontSize, 24);
    });
    test('bodyStyle uses DM Sans w400 size 16', () {
      final s = ElioTextStyles.bodyStyle;
      expect(s.fontFamily, 'DM Sans');
      expect(s.fontWeight, FontWeight.w400);
      expect(s.fontSize, 16);
    });
    test('eyebrowStyle uses DM Mono uppercase tracked-out', () {
      final s = ElioTextStyles.eyebrowStyle;
      expect(s.fontFamily, 'DM Mono');
      expect(s.fontWeight, FontWeight.w500);
      expect(s.letterSpacing, isNotNull);
      expect(s.letterSpacing! > 0, true);
    });
  });
}
