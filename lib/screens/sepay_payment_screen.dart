import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sepay_service.dart';
import '../theme/app_theme.dart';
import '../utils/revenue.dart';
import '../widgets/decor.dart';

/// Shows a VietQR code and waits until SePay reports the matching transfer.
/// Pops `true` once paid, `false` (or null) when the user gives up.
class SePayPaymentScreen extends StatefulWidget {
  const SePayPaymentScreen({
    super.key,
    required this.service,
    required this.amount,
  });

  final SePayService service;
  final int amount;

  @override
  State<SePayPaymentScreen> createState() => _SePayPaymentScreenState();
}

class _SePayPaymentScreenState extends State<SePayPaymentScreen> {
  static const _pollEvery = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 10);

  late final String _code = SePayService.newPaymentCode(DateTime.now());
  late final DateTime _deadline = DateTime.now().add(_timeout);
  Timer? _timer;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_checking || !mounted) return;
    if (DateTime.now().isAfter(_deadline)) {
      _timer?.cancel();
      setState(() => _error = 'Payment timed out. Please try again.');
      return;
    }
    _checking = true;
    try {
      final paid = await widget.service.findPayment(
        code: _code,
        amount: widget.amount,
      );
      if (!mounted) return;
      if (paid != null) {
        _timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
      if (_error != null) setState(() => _error = null);
    } catch (e) {
      if (mounted)
        setState(() => _error = 'SePay check failed ($e). Retrying...');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final qr = widget.service.qrImageUrl(amount: widget.amount, code: _code);

    return Scaffold(
      appBar: AppBar(title: const Text('Bank transfer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'Scan with your banking app',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    qr.toString(),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stack) =>
                        const Center(child: Text('Could not load the QR code')),
                  ),
                ),
                const SizedBox(height: 12),
                GradientText(
                  formatPrice(widget.amount),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Bank', value: widget.service.config.bank),
                _InfoRow(
                  label: 'Account',
                  value: widget.service.config.accountNumber,
                ),
                _InfoRow(label: 'Transfer note', value: _code),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error == null) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  _error ?? 'Waiting for your transfer...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error == null ? AppColors.muted : AppColors.coral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep the transfer note exactly as shown. The order is placed '
            'automatically once the money arrives.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
