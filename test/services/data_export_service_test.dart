// Sprint 17 — DataExportService.
//
// As with AccountService, the destructive/IO bits (Firestore reads,
// share sheet) need an emulator to test end-to-end and that lives in
// the Sprint 17 emulator-rule task. What we lock down here is the
// pure-data normaliser — it has to convert every Firestore-specific
// type to JSON-safe primitives, and a regression there would corrupt
// every export silently.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/data_export_service.dart';

void main() {
  group('DataExportService.normaliseForTest', () {
    test('passes primitives through unchanged', () {
      expect(DataExportService.normaliseForTest('hi'), 'hi');
      expect(DataExportService.normaliseForTest(42), 42);
      expect(DataExportService.normaliseForTest(3.14), 3.14);
      expect(DataExportService.normaliseForTest(true), true);
      expect(DataExportService.normaliseForTest(null), isNull);
    });

    test('converts Timestamp to ISO 8601 UTC string', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 4, 26, 12, 30));
      final out = DataExportService.normaliseForTest(ts);
      expect(out, '2026-04-26T12:30:00.000Z');
    });

    test('converts DateTime to ISO 8601 UTC string', () {
      final dt = DateTime.utc(2026, 4, 26, 12, 30);
      final out = DataExportService.normaliseForTest(dt);
      expect(out, '2026-04-26T12:30:00.000Z');
    });

    test('converts GeoPoint to lat/lng map', () {
      final gp = const GeoPoint(50.7, 0.34);
      final out = DataExportService.normaliseForTest(gp);
      expect(out, {'lat': 50.7, 'lng': 0.34});
    });

    test('converts Blob to base64 string', () {
      final blob = Blob(Uint8List.fromList([1, 2, 3, 4]));
      final out = DataExportService.normaliseForTest(blob);
      expect(out, base64Encode([1, 2, 3, 4]));
    });

    test('recurses into nested lists and maps', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      final input = {
        'name': 'Salt',
        'addedAt': ts,
        'tags': ['staple', 'always'],
        'meta': {
          'expiry': ts,
          'history': [
            {'when': ts, 'qty': 1},
          ],
        },
      };
      final out = DataExportService.normaliseForTest(input)
          as Map<String, dynamic>;
      expect(out['name'], 'Salt');
      expect(out['addedAt'], '2026-01-01T00:00:00.000Z');
      expect(out['tags'], ['staple', 'always']);
      final meta = out['meta'] as Map<String, dynamic>;
      expect(meta['expiry'], '2026-01-01T00:00:00.000Z');
      final history = meta['history'] as List;
      expect(history.first, {
        'when': '2026-01-01T00:00:00.000Z',
        'qty': 1,
      });
    });

    test('output round-trips cleanly through jsonEncode', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      final input = {
        'when': ts,
        'where': const GeoPoint(1.0, 2.0),
        'bytes': Blob(Uint8List.fromList([0xff])),
        'nested': [
          {'ts': ts}
        ],
      };
      final out = DataExportService.normaliseForTest(input);
      // If anything non-JSON-safe slipped through, jsonEncode throws.
      expect(() => jsonEncode(out), returnsNormally);
    });
  });

  group('DataExportResult', () {
    test('Success carries path and byte count', () {
      const r = DataExportSuccess(filePath: '/tmp/x.json', byteCount: 1234);
      expect(r.filePath, '/tmp/x.json');
      expect(r.byteCount, 1234);
    });

    test('Failed carries message', () {
      const r = DataExportFailed('boom');
      expect(r.message, 'boom');
    });
  });

  test('schemaVersion is set', () {
    expect(DataExportService.schemaVersion, greaterThanOrEqualTo(1));
  });
}
