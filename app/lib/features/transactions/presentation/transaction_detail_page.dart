import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/transaction_models.dart';
import '../data/transactions_api.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.transaction,
    required this.transactionsApi,
  });

  final FinancialTransaction transaction;
  final TransactionsApi transactionsApi;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  bool _isLoading = false;
  String? _errorMessage;
  FinancialTransaction? _transaction;

  @override
  void initState() {
    super.initState();

    _transaction = widget.transaction;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transaction = await widget.transactionsApi.getTransaction(
        transactionId: widget.transaction.id,
      );

      if (!mounted) return;

      setState(() {
        _transaction = transaction;
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

    return 'Erro ao carregar detalhe da transação.';
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction ?? widget.transaction;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe da transação'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadDetail,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                transaction.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${transaction.date} • ${transaction.accountTypeLabel}',
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_errorMessage != null)
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
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações principais',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      label: 'Valor',
                      value: MoneyFormatter.format(transaction.amountAbs),
                    ),
                    _DetailRow(
                      label: 'Valor original',
                      value: MoneyFormatter.format(transaction.amount),
                    ),
                    _DetailRow(
                      label: 'Data',
                      value: transaction.date,
                    ),
                    _DetailRow(
                      label: 'Conta',
                      value:
                          '${transaction.accountName} • ${transaction.institutionName}',
                    ),
                    _DetailRow(
                      label: 'Tipo de conta',
                      value: transaction.accountTypeLabel,
                    ),
                    _DetailRow(
                      label: 'Fluxo',
                      value: transaction.cashflowTypeLabel,
                    ),
                    _DetailRow(
                      label: 'Operação',
                      value: transaction.operationTypeLabel,
                    ),
                    _DetailRow(
                      label: 'Forma de pagamento',
                      value: transaction.paymentMethod.isEmpty
                          ? '--'
                          : transaction.paymentMethod,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descrição e classificação',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      label: 'Descrição',
                      value: transaction.displayDescription ?? '--',
                    ),
                    _DetailRow(
                      label: 'Lojista',
                      value: transaction.merchantName ?? '--',
                    ),
                    _DetailRow(
                      label: 'Categoria',
                      value: transaction.categoryName ?? '--',
                    ),
                    _DetailRow(
                      label: 'Fatura',
                      value: transaction.statementId?.toString() ?? '--',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conciliação',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      label: 'Status',
                      value: transaction.reconciliationStatus ?? '--',
                    ),
                    _DetailRow(
                      label: 'Conciliada',
                      value: transaction.isReconciled ? 'Sim' : 'Não',
                    ),
                    _DetailRow(
                      label: 'Transação vinculada',
                      value:
                          transaction.matchedTransactionId?.toString() ?? '--',
                    ),
                  ],
                ),
              ),
              if (transaction.installmentNumber != null ||
                  transaction.installmentTotal != null) ...[
                const SizedBox(height: 16),
                SalvaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parcelamento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        label: 'Parcela',
                        value:
                            '${transaction.installmentNumber ?? '--'} de ${transaction.installmentTotal ?? '--'}',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '--' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              cleanValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.indigo,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}