import 'dart:convert';

import 'package:http/http.dart' as http;

/// SePay settings, passed at build time so nothing secret lands in git:
///
///   flutter run --dart-define-from-file=sepay.json
///
/// sepay.json holds SEPAY_BANK, SEPAY_ACCOUNT and SEPAY_TOKEN.
class SePayConfig {
  const SePayConfig({
    required this.bank,
    required this.accountNumber,
    required this.apiToken,
  });

  factory SePayConfig.fromEnvironment() => const SePayConfig(
    bank: String.fromEnvironment('SEPAY_BANK'),
    accountNumber: String.fromEnvironment('SEPAY_ACCOUNT'),
    apiToken: String.fromEnvironment('SEPAY_TOKEN'),
  );

  final String bank;
  final String accountNumber;
  final String apiToken;

  bool get isConfigured =>
      bank.isNotEmpty && accountNumber.isNotEmpty && apiToken.isNotEmpty;
}

/// An incoming bank transfer reported by SePay.
class SePayTransaction {
  const SePayTransaction({
    required this.id,
    required this.amountIn,
    required this.content,
  });

  factory SePayTransaction.fromJson(Map<String, dynamic> json) =>
      SePayTransaction(
        id: '${json['id']}',
        amountIn: double.tryParse('${json['amount_in']}') ?? 0,
        content: '${json['transaction_content'] ?? ''}',
      );

  final String id;
  final double amountIn;
  final String content;
}

/// Builds VietQR codes and checks SePay for the matching transfer.
class SePayService {
  SePayService(this.config, {http.Client? client})
    : _client = client ?? http.Client();

  static const _apiUrl = 'https://my.sepay.vn/userapi/transactions/list';

  final SePayConfig config;
  final http.Client _client;

  /// A transfer note that is unique per payment attempt. Letters and digits
  /// only, because banks rewrite other characters.
  static String newPaymentCode(DateTime now) =>
      'PRM${now.millisecondsSinceEpoch}';

  /// VietQR image with the amount and note already filled in.
  Uri qrImageUrl({required int amount, required String code}) =>
      Uri.https('qr.sepay.vn', '/img', {
        'acc': config.accountNumber,
        'bank': config.bank,
        'amount': '$amount',
        'des': code,
      });

  /// Returns the transfer that pays [amount] with [code] in its note, or null
  /// while it has not arrived yet.
  Future<SePayTransaction?> findPayment({
    required String code,
    required int amount,
  }) async {
    final uri = Uri.parse(_apiUrl).replace(
      queryParameters: {'account_number': config.accountNumber, 'limit': '50'},
    );
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${config.apiToken}',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw SePayException('SePay returned HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['transactions'] as List?) ?? const [];
    return matchPayment(
      list.cast<Map<String, dynamic>>().map(SePayTransaction.fromJson),
      code: code,
      amount: amount,
    );
  }

  /// Picks the transfer whose note contains [code] and that covers [amount].
  /// Banks may insert spaces or change case in the note, so both are ignored.
  static SePayTransaction? matchPayment(
    Iterable<SePayTransaction> transactions, {
    required String code,
    required int amount,
  }) {
    String normalize(String s) => s.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final wanted = normalize(code);
    for (final t in transactions) {
      if (t.amountIn >= amount && normalize(t.content).contains(wanted)) {
        return t;
      }
    }
    return null;
  }
}

class SePayException implements Exception {
  SePayException(this.message);
  final String message;
  @override
  String toString() => message;
}
