import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  test('perishable tokens resolve', () {
    expect(ElioColors.freshGreen, const Color(0xFF3D9970));
    expect(ElioColors.perishThisWeek, ElioColors.amber);
    expect(ElioColors.perishToday, const Color(0xFFE06C5E));
  });
}
