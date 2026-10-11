import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/transaction_models.dart';
import '../data/transactions_api.dart';
import 'transaction_detail_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.transactionsApi,
  });

  final TransactionsApi transactionsApi;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMore = false;

  String? _errorMessage;
  String _selectedMonth = 'all';
  String _selectedAccountType = 'all';
  String _selectedCashflowType = 'all';

  List<String> _availableMonths = [];
  List<FinancialTransaction> _transactions = [];

  int _total = 0;
  int _offset = 0;
  bool _hasMore = false;

  static const int _limit = 50;

  @override
  void initState() {
    super.initState();

    _loadMonths();
    _loadTransactions(reset: true);
  }

  Future<void> _loadMonths() async {
    try {
      final months = await widget.transactionsApi.getAvailableMonths();

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

  Future<void> _loadTransactions({
    required bool reset,
  }) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await widget.transactionsApi.getTransactions(
        month: _selectedMonth,
        accountType: _selectedAccountType,
        cashflowType: _selectedCashflowType,
        search: _searchController.text,
        limit: _limit,
        offset: reset ? 0 : _offset,
      );

      if (!mounted) return;

      setState(() {
        _total = response.total;
        _hasMore = response.hasMore;
        _offset = response.offset + response.items.length;

        if (reset) {
          _transactions = response.items;
        } else {
          _transactions = [
            ..._transactions,
            ...response.items,
          ];
        }
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
        _isLoadingMore = false;
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

    return 'Erro ao carregar transações.';
  }

  Future<void> _openDetail(FinancialTransaction transaction) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(
          transaction: transaction,
          transactionsApi: widget.transactionsApi,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _selectedMonth == 'all'
        ? 'Todas as transações importadas'
        : 'Transações de $_selectedMonth';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      child: RefreshIndicator(
        onRefresh: () => _loadTransactions(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Transações',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 18),
            _FiltersCard(
              selectedMonth: _selectedMonth,
              availableMonths: _availableMonths,
              selectedAccountType: _selectedAccountType,
              selectedCashflowType: _selectedCashflowType,
              searchController: _searchController,
              onMonthChanged: (value) {
                setState(() {
                  _selectedMonth = value;
                });

                _loadTransactions(reset: true);
              },
              onAccountTypeChanged: (value) {
                setState(() {
                  _selectedAccountType = value;
                });

                _loadTransactions(reset: true);
              },
              onCashflowTypeChanged: (value) {
                setState(() {
                  _selectedCashflowType = value;
                });

                _loadTransactions(reset: true);
              },
              onSearch: () => _loadTransactions(reset: true),
            ),
            const SizedBox(height: 16),
            SalvaCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.indigo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Total encontrado: $_total',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              SalvaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_isLoading && _transactions.isEmpty && _errorMessage == null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma transação encontrada',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Altere o mês, os filtros ou importe um CSV de conta corrente/cartão.',
                    ),
                  ],
                ),
              ),
            for (final transaction in _transactions) ...[
              _TransactionCard(
                transaction: transaction,
                onTap: () => _openDetail(transaction),
              ),
              const SizedBox(height: 12),
            ],
            if (_hasMore) ...[
              const SizedBox(height: 8),
              GradientButton(
                label: 'Carregar mais',
                icon: Icons.expand_more,
                isLoading: _isLoadingMore,
                onPressed: _isLoadingMore
                    ? null
                    : () => _loadTransactions(reset: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.selectedMonth,
    required this.availableMonths,
    required this.selectedAccountType,
    required this.selectedCashflowType,
    required this.searchController,
    required this.onMonthChanged,
    required this.onAccountTypeChanged,
    required this.onCashflowTypeChanged,
    required this.onSearch,
  });

  final String selectedMonth;
  final List<String> availableMonths;
  final String selectedAccountType;
  final String selectedCashflowType;
  final TextEditingController searchController;
  final ValueChanged<String> onMonthChanged;
  final ValueChanged<String> onAccountTypeChanged;
  final ValueChanged<String> onCashflowTypeChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final months = [
      'all',
      ...availableMonths,
    ];

    return SalvaCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedMonth,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Período',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: months
                .map(
                  (month) => DropdownMenuItem(
                    value: month,
                    child: Text(
                      month == 'all' ? 'Todos os meses' : 'Mês: $month',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;

              onMonthChanged(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedAccountType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de conta',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Todas as contas'),
              ),
              DropdownMenuItem(
                value: 'checking',
                child: Text('Conta corrente'),
              ),
              DropdownMenuItem(
                value: 'credit_card',
                child: Text('Cartão de crédito'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              onAccountTypeChanged(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCashflowType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de fluxo',
              prefixIcon: Icon(Icons.swap_vert),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Todos os fluxos'),
              ),
              DropdownMenuItem(
                value: 'income',
                child: Text('Entradas'),
              ),
              DropdownMenuItem(
                value: 'expense',
                child: Text('Despesas'),
              ),
              DropdownMenuItem(
                value: 'debt_payment',
                child: Text('Pagamentos de fatura/dívida'),
              ),
              DropdownMenuItem(
                value: 'liability_increase',
                child: Text('Aumento de dívida'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              onCashflowTypeChanged(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              labelText: 'Pesquisar',
              hintText: 'Pix, mercado, Nubank...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onTap,
  });

  final FinancialTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isIncome
        ? AppColors.seaGreen
        : transaction.isOutflow
            ? AppColors.error
            : AppColors.indigo;

    return SalvaCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.mint,
              child: Icon(
                transaction.accountType == 'credit_card'
                    ? Icons.credit_card
                    : Icons.account_balance_wallet_outlined,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${transaction.date} • ${transaction.accountTypeLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.cashflowTypeLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              transaction.displayAmount,
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}