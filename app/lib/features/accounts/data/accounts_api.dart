import '../../../core/network/api_client.dart';
import 'account_models.dart';

class AccountsApi {
  AccountsApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<FinancialAccount>> getAccounts() async {
    final response = await _apiClient.dio.get('/accounts');

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => FinancialAccount.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<FinancialAccount> createAccount({
    required String name,
    required String institutionName,
    required String accountType,
  }) async {
    final response = await _apiClient.dio.post(
      '/accounts',
      data: {
        'name': name,
        'institution_name': institutionName,
        'account_type': accountType,
      },
    );

    return FinancialAccount.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FinancialAccount> updateAccount({
    required int accountId,
    required String name,
    required String institutionName,
    required String accountType,
  }) async {
    final response = await _apiClient.dio.put(
      '/accounts/$accountId',
      data: {
        'name': name,
        'institution_name': institutionName,
        'account_type': accountType,
      },
    );

    return FinancialAccount.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteAccount({
    required int accountId,
  }) async {
    await _apiClient.dio.delete('/accounts/$accountId');
  }
}