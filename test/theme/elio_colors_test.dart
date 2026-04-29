import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  group('ElioColors new palette tokens', () {
    test('cream is #F4ECE0', () {
      expect(ElioColors.cream, const Color(0xFFF4ECE0));
    });
    test('creamDeep is #EFE3D2', () {
      expect(ElioColors.creamDeep, const Color(0xFFEFE3D2));
    });
    test('terracotta is #E37B53', () {
      expect(ElioColors.terracotta, const Color(0xFFE37B53));
    });
    test('peach is #F2C9A8', () {
      expect(ElioColors.peach, const Color(0xFFF2C9A8));
    });
    test('espresso is #2A1F1A', () {
      expect(ElioColors.espresso, const Color(0xFF2A1F1A));
    });
    test('mocha is #6B5A4F', () {
      expect(ElioColors.mocha, const Color(0xFF6B5A4F));
    });
    test('rule is #D7C5B0', () {
      expect(ElioColors.rule, const Color(0xFFD7C5B0));
    });
  });
}
