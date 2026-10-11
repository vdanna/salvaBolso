import '../../../core/network/api_client.dart';
import 'statement_models.dart';
import 'reconciliation_statements.dart';

class StatementsApi {
  StatementsApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CreditCardStatement>> getStatements({
    String? month,
  }) async {
    final path = month == null || month.isEmpty
        ? '/credit-card/statements'
        : '/credit-card/statements?month=$month';

    final response = await _apiClient.dio.get(path);

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => CreditCardStatement.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> getStatementSummary({
    required int statementId,
  }) async {
    final response = await _apiClient.dio.get(
      '/summary/statements/$statementId',
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reconcileStatement({
    required int statementId,
    int dayWindow = 3,
  }) async {
    final response = await _apiClient.dio.post(
      '/reconciliation/statements/$statementId?day_window=$dayWindow',
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ManualCandidatesResponse> getManualCandidates({
    required int statementId,
    int dayWindow = 30,
  }) async {
    final response = await _apiClient.dio.get(
      '/reconciliation/statements/$statementId/manual-candidates?day_window=$dayWindow',
    );  

    return ManualCandidatesResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  } 

  Future<Map<String, dynamic>> manualReconcileCardPayment({
    required int bankPaymentTransactionId,
    required int cardPaymentTransactionId,
  }) async {
    final response = await _apiClient.dio.post(
      '/reconciliation/card-payment',
      data: {
        'bank_payment_transaction_id': bankPaymentTransactionId,
        'card_payment_transaction_id': cardPaymentTransactionId,
      },
    );  

    return Map<String, dynamic>.from(response.data as Map);
  }
}