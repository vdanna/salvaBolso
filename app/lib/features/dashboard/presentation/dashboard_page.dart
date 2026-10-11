import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../../auth/data/auth_models.dart';
import '../data/dashboard_api.dart';
import '../data/dashboard_models.dart';
import 'dashboard_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.dashboardApi,
  });

  final AppUser user;
  final DashboardApi dashboardApi;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedMonth = 'all';
  List<String> _availableMonths = [];
  bool _isLoading = false;
  String? _errorMessage;
  DashboardData? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadMonths();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.dashboardApi.getDashboardData(
        month: _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _dashboardData = data;
      });
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _extractDioError(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro inesperado: $error';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  String _extractDioError(DioException error) {
    final data = error.response?.data;

    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar à API.';
    }

    if (error.response?.statusCode == 401) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    return 'Erro ao carregar dashboard.';
  }

  @override
  Widget build(BuildContext context) {
    final data = _dashboardData;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Olá, ${widget.user.name}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _selectedMonth == 'all'
                  ? 'Balanço geral de todos os meses'
                  : 'Resumo financeiro de $_selectedMonth',
            ),
            const SizedBox(height: 20),
            _MonthSelector(
              selectedMonth: _selectedMonth,
              availableMonths: _availableMonths,
              onChanged: (month) {
                setState(() {
                  _selectedMonth = month;
                });

                _loadDashboard();
              },
            ),
            const SizedBox(height: 20),
            if (_isLoading && data == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_errorMessage != null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Tentar novamente',
                      icon: Icons.refresh,
                      onPressed: _loadDashboard,
                    ),
                  ],
                ),
              ),
            if (data != null) ...[
              _DashboardContent(data: data),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadMonths() async {
    try {
      final months = await widget.dashboardApi.getAvailableMonths();
  
      if (!mounted) return;
  
      setState(() {
        _availableMonths = months;
      });
    } catch (_) {
      if (!mounted) return;
  
      setState(() {
        _availableMonths = [];
      });
    }
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.availableMonths,
    required this.onChanged,
  });

  final String selectedMonth;
  final List<String> availableMonths;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final months = [
      'all',
      ...availableMonths,
    ];

    return SalvaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: months
              .map(
                (month) => DropdownMenuItem(
                  value: month,
                  child: Text(
                    month == 'all'
                        ? 'Balanço geral'
                        : 'Mês: $month',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;

            onChanged(value);
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
  });

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final cashflow = data.cashflow;
    final consumption = data.consumption;
    final healthScore = data.healthScore;

    final warnings = [
      ...cashflow.warnings,
      ...consumption.warnings,
      ...healthScore.warnings,
    ];

    return Column(
      children: [
        HealthScoreCard(healthScore: healthScore),
        const SizedBox(height: 16),
        DashboardMetricCard(
          title: 'Consumo real do mês',
          value: MoneyFormatter.format(consumption.totalConsumption),
          icon: Icons.shopping_bag_outlined,
          subtitle: 'Não inclui pagamento de fatura em duplicidade.',
        ),
        const SizedBox(height: 12),
        DashboardMetricCard(
          title: 'Saldo líquido de caixa',
          value: MoneyFormatter.format(cashflow.netCashflow),
          icon: Icons.savings_outlined,
          subtitle: 'Entradas menos saídas da conta corrente.',
        ),
        const SizedBox(height: 12),
        DashboardMetricCard(
          title: 'Renda identificada',
          value: MoneyFormatter.format(cashflow.income),
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 12),
        DashboardMetricCard(
          title: 'Pagamento de fatura',
          value: MoneyFormatter.format(cashflow.cardBillPayments),
          icon: Icons.credit_card,
          subtitle:
              '${MoneyFormatter.format(cashflow.reconciledCardBillPayments)} conciliado.',
        ),
        const SizedBox(height: 16),
        _CategoriesCard(categories: data.categories),
        const SizedBox(height: 16),
        _ConsumptionBreakdownCard(consumption: consumption),
        const SizedBox(height: 16),
        MerchantListCard(items: data.merchants),
        const SizedBox(height: 16),
        InstallmentsCard(items: data.installments),
        const SizedBox(height: 16),
        TopTransactionsCard(items: consumption.topTransactions),
        const SizedBox(height: 16),
        WarningListCard(
          title: 'Avisos e recomendações',
          icon: Icons.tips_and_updates_outlined,
          items: warnings,
        ),
        if (healthScore.recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          WarningListCard(
            title: 'Próximos passos',
            icon: Icons.check_circle_outline,
            items: healthScore.recommendations,
          ),
        ],
      ],
    );
  }
}

class _ConsumptionBreakdownCard extends StatelessWidget {
  const _ConsumptionBreakdownCard({
    required this.consumption,
  });

  final ConsumptionSummary consumption;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como você gastou',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _BreakdownRow(
            label: 'Cartão de crédito',
            value: consumption.creditCardTotal,
            total: consumption.totalConsumption,
          ),
          _BreakdownRow(
            label: 'Débito',
            value: consumption.debitCardTotal,
            total: consumption.totalConsumption,
          ),
          _BreakdownRow(
            label: 'Pix',
            value: consumption.pixTotal,
            total: consumption.totalConsumption,
          ),
          _BreakdownRow(
            label: 'Boletos',
            value: consumption.bankSlipTotal,
            total: consumption.totalConsumption,
          ),
          _BreakdownRow(
            label: 'NuPay',
            value: consumption.nupayTotal,
            total: consumption.totalConsumption,
          ),
          const Divider(height: 24),
          _BreakdownRow(
            label: 'Parcelados',
            value: consumption.installmentTotal,
            total: consumption.totalConsumption,
          ),
          _BreakdownRow(
            label: 'Compras à vista',
            value: consumption.singlePurchaseTotal,
            total: consumption.totalConsumption,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final double value;
  final double total;

  @override
  Widget build(BuildContext context) {
    final percentage = total <= 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                MoneyFormatter.format(value),
                style: const TextStyle(
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percentage.clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.lightGray,
              color: AppColors.seaGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.categories,
  });

  final List<CategorySummary> categories;

  @override
  Widget build(BuildContext context) {
    final items = categories.take(8).toList();

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastos por categoria',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'Nenhuma categoria encontrada para este período.',
            )
          else
            for (final category in items) ...[
              _CategoryRow(category: category),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
  });

  final CategorySummary category;

  @override
  Widget build(BuildContext context) {
    final percentage = category.percentage.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.categoryName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              MoneyFormatter.format(category.total),
              style: const TextStyle(
                color: AppColors.indigo,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: 3),
        Text(
          '${category.percentage.toStringAsFixed(1)}% • ${category.transactionCount} transações',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}