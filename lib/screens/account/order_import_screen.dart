// lib/screens/account/order_import_screen.dart
//
// Sprint 17 — Online Order → Pantry Import.
//
// Pro-gated sub-screen pushed from Settings > Preferences > Order
// import. Calls `service.ensureImportAddress()` in initState (which
// short-circuits when the user doc already has the address). Renders
// loading / error / success states. Copy uses Clipboard + snackbar;
// Share uses the existing share_plus dep.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../services/order_import_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_page_title.dart';

class OrderImportScreen extends StatefulWidget {
  final OrderImportService service;
  const OrderImportScreen({super.key, required this.service});

  @override
  State<OrderImportScreen> createState() => _OrderImportScreenState();
}

class _OrderImportScreenState extends State<OrderImportScreen> {
  String? _address;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await widget.service.ensureImportAddress();
      if (!mounted) return;
      setState(() => _address = a);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _copy() async {
    final addr = _address;
    if (addr == null) return;
    await Clipboard.setData(ClipboardData(text: addr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  Future<void> _share() async {
    final addr = _address;
    if (addr == null) return;
    await Share.share(addr, subject: 'Elio order import address');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ElioColors.espresso),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          ElioSpacing.xl,
          0,
          ElioSpacing.xl,
          ElioSpacing.xxxl,
        ),
        child: ListView(
          children: [
            const ElioPageTitle('order import.'),
            const SizedBox(height: ElioSpacing.xl),
            if (_address == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: ElioSpacing.xxl),
                  child: CircularProgressIndicator(
                    color: ElioColors.terracotta,
                  ),
                ),
              )
            else if (_error != null)
              Text(
                'Could not load your import address. Pull to retry, '
                'or sign out and back in.\n\n$_error',
                style: ElioTextStyles.bodyStyle,
              )
            else ...[
              Text(
                'Forward your grocery order confirmation emails to this '
                'address and Elio will line them up for review in your '
                'pantry.',
                style: ElioTextStyles.bodyStyle,
              ),
              const SizedBox(height: ElioSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ElioSpacing.md,
                  vertical: ElioSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: ElioColors.creamDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ElioColors.rule, width: 1),
                ),
                child: SelectableText(
                  _address!,
                  style: ElioTextStyles.bodyStyle.copyWith(
                    fontFamily: 'DM Mono',
                  ),
                ),
              ),
              const SizedBox(height: ElioSpacing.lg),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: ElioSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
