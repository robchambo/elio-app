import 'package:flutter/material.dart';

/// Border-radius scale, matches Figma rounded-corner system.
class ElioRadii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius card = BorderRadius.all(Radius.circular(24));
  static const BorderRadius button = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
}
