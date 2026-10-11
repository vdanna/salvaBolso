import '../../../core/network/api_client.dart';
import 'transaction_models.dart';

class TransactionsApi {
  TransactionsApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<String>> getAvailableMonths() async {
    final response = await _apiClient.dio.get('/summary/months');

    final data = Map<String, dynamic>.from(response.data as Map);
    final items = data['items'];

    if (items is! List) {
      return [];
    }

    return items.map((item) => item.toString()).toList();
  }

  Future<TransactionsResponse> getTransactions({
    String? month,
    String? accountType,
    String? cashflowType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (month != null && month.isNotEmpty && month != 'all') {
      query['month'] = month;
    }

    if (accountType != null &&
        accountType.isNotEmpty &&
        accountType != 'all') {
      query['account_type'] = accountType;
    }

    if (cashflowType != null &&
        cashflowType.isNotEmpty &&
        cashflowType != 'all') {
      query['cashflow_type'] = cashflowType;
    }

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final response = await _apiClient.dio.get(
      '/transactions',
      queryParameters: query,
    );

    return TransactionsResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FinancialTransaction> getTransaction({
    required int transactionId,
  }) async {
    final response = await _apiClient.dio.get(
      '/transactions/$transactionId',
    );

    return FinancialTransaction.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}