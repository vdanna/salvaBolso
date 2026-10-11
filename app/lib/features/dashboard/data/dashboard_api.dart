import '../../../core/network/api_client.dart';
import 'dashboard_models.dart';

class DashboardApi {
  DashboardApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DashboardData> getDashboardData({
    String? month,
  }) async {
    if (month == null || month == 'all') {
      final response = await _apiClient.dio.get('/summary/overview');
  
      final data = Map<String, dynamic>.from(response.data as Map);
  
      return DashboardData(
        cashflow: CashflowSummary.fromJson(
          Map<String, dynamic>.from(data['cashflow'] as Map),
        ),
        consumption: ConsumptionSummary.fromJson(
          Map<String, dynamic>.from(data['consumption'] as Map),
        ),
        healthScore: HealthScoreSummary.fromJson(
          Map<String, dynamic>.from(data['health_score'] as Map),
        ),
        merchants: ((data['merchants']?['items'] as List?) ?? [])
            .map(
              (item) => MerchantSummary.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        installments: ((data['installments']?['items'] as List?) ?? [])
            .map(
              (item) => InstallmentSummary.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        categories: ((data['categories']?['items'] as List?) ?? [])
            .map(
              (item) => CategorySummary.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
    }
  
    final responses = await Future.wait([
      _apiClient.dio.get(
        '/summary/cashflow',
        queryParameters: {
          'month': month,
        },
      ),
      _apiClient.dio.get(
        '/summary/consumption',
        queryParameters: {
          'month': month,
        },
      ),
      _apiClient.dio.get(
        '/summary/health-score',
        queryParameters: {
          'month': month,
        },
      ),
      _apiClient.dio.get(
        '/summary/credit-card/merchants',
        queryParameters: {
          'month': month,
        },
      ),
      _apiClient.dio.get(
        '/summary/credit-card/installments',
        queryParameters: {
          'month': month,
        },
      ),
      _apiClient.dio.get(
        '/summary/categories',
        queryParameters: {
          'month': month,
          'view': 'consumption',
        },
      ),
    ]);
  
    final cashflowData = Map<String, dynamic>.from(responses[0].data as Map);
    final consumptionData = Map<String, dynamic>.from(responses[1].data as Map);
    final healthScoreData = Map<String, dynamic>.from(responses[2].data as Map);
    final merchantsData = Map<String, dynamic>.from(responses[3].data as Map);
    final installmentsData = Map<String, dynamic>.from(responses[4].data as Map);
    final categoriesData = Map<String, dynamic>.from(responses[5].data as Map);
  
    return DashboardData(
      cashflow: CashflowSummary.fromJson(cashflowData),
      consumption: ConsumptionSummary.fromJson(consumptionData),
      healthScore: HealthScoreSummary.fromJson(healthScoreData),
      merchants: ((merchantsData['items'] as List?) ?? [])
          .map(
            (item) => MerchantSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      installments: ((installmentsData['items'] as List?) ?? [])
          .map(
            (item) => InstallmentSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      categories: ((categoriesData['items'] as List?) ?? [])
          .map(
            (item) => CategorySummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Future<List<String>> getAvailableMonths() async {
    final response = await _apiClient.dio.get('/summary/months'); 

    final data = Map<String, dynamic>.from(response.data as Map);
    final items = data['items'];  

    if (items is! List) {
      return [];
    } 

    return items.map((item) => item.toString()).toList();
  }
}