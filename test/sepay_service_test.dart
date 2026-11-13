import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prm393_pe/services/sepay_service.dart';

void main() {
  const config = SePayConfig(
    bank: 'VCB',
    accountNumber: '0123456789',
    apiToken: 'test-token',
  );

  SePayTransaction tx(String content, double amount) =>
      SePayTransaction(id: '1', amountIn: amount, content: content);

  group('matchPayment', () {
    test(
      'matches the code even when the bank adds spaces or lowercases it',
      () {
        final hit = SePayService.matchPayment(
          [tx('MBVCB.123 prm 1700 000 chuyen tien', 50000)],
          code: 'PRM1700000',
          amount: 50000,
        );
        expect(hit, isNotNull);
      },
    );

    test('ignores transfers below the order total', () {
      final hit = SePayService.matchPayment(
        [tx('PRM1700000', 49999)],
        code: 'PRM1700000',
        amount: 50000,
      );
      expect(hit, isNull);
    });

    test('ignores transfers with another note', () {
      final hit = SePayService.matchPayment(
        [tx('PRM1699999', 50000)],
        code: 'PRM1700000',
        amount: 50000,
      );
      expect(hit, isNull);
    });
  });

  test(
    'findPayment sends the bearer token and parses SePay transactions',
    () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'status': 200,
            'transactions': [
              {
                'id': '92704',
                'amount_in': '120000.00',
                'transaction_content': 'PRM42 thanh toan',
              },
            ],
          }),
          200,
        );
      });

      final paid = await SePayService(
        config,
        client: client,
      ).findPayment(code: 'PRM42', amount: 120000);

      expect(paid?.id, '92704');
      expect(sent.headers['Authorization'], 'Bearer test-token');
      expect(sent.url.queryParameters['account_number'], '0123456789');
    },
  );

  test('findPayment throws on an HTTP error', () async {
    final client = MockClient((_) async => http.Response('nope', 401));
    expect(
      SePayService(
        config,
        client: client,
      ).findPayment(code: 'PRM42', amount: 1),
      throwsA(isA<SePayException>()),
    );
  });

  test('qrImageUrl carries account, bank, amount and note', () {
    final url = SePayService(config).qrImageUrl(amount: 120000, code: 'PRM42');
    expect(url.queryParameters, {
      'acc': '0123456789',
      'bank': 'VCB',
      'amount': '120000',
      'des': 'PRM42',
    });
  });
}
