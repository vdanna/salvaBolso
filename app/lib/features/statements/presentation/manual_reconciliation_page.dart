import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/reconciliation_statements.dart';
import '../data/statement_models.dart';
import '../data/statements_api.dart';

class ManualReconciliationPage extends StatefulWidget {
  const ManualReconciliationPage({
    super.key,
    required this.statement,
    required this.statementsApi,
    required this.dayWindow,
  });

  final CreditCardStatement statement;
  final StatementsApi statementsApi;
  final int dayWindow;

  @override
  State<ManualReconciliationPage> createState() =>
      _ManualReconciliationPageState();
}

class _ManualReconciliationPageState extends State<ManualReconciliationPage> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ManualCandidatesResponse? _candidates;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final candidates = await widget.statementsApi.getManualCandidates(
        statementId: widget.statement.id,
        dayWindow: widget.dayWindow,
      );

      if (!mounted) return;

      setState(() {
        _candidates = candidates;
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

  Future<void> _reconcile({
    required ReconciliationTransaction cardPayment,
    required ReconciliationTransaction bankPayment,
  }) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.statementsApi.manualReconcileCardPayment(
        bankPaymentTransactionId: bankPayment.id,
        cardPaymentTransactionId: cardPayment.id,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Conciliação realizada'),
            content: const Text(
              'O pagamento da conta corrente foi vinculado ao pagamento recebido na fatura.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
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
        _isSubmitting = false;
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

    return 'Erro ao conciliar pagamento manualmente.';
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conciliação manual'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadCandidates,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.statement.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Buscando candidatos em uma janela de ${widget.dayWindow} dias.',
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(28),
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
              if (candidates != null && candidates.items.isEmpty)
                SalvaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhum pagamento pendente',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esta fatura não possui pagamentos pendentes para conciliação manual.',
                      ),
                    ],
                  ),
                ),
              if (candidates != null)
                for (final group in candidates.items) ...[
                  _ManualCandidateCard(
                    group: group,
                    isSubmitting: _isSubmitting,
                    onReconcile: _reconcile,
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualCandidateCard extends StatelessWidget {
  const _ManualCandidateCard({
    required this.group,
    required this.isSubmitting,
    required this.onReconcile,
  });

  final ManualCandidateGroup group;
  final bool isSubmitting;
  final Future<void> Function({
    required ReconciliationTransaction cardPayment,
    required ReconciliationTransaction bankPayment,
  }) onReconcile;

  @override
  Widget build(BuildContext context) {
    final cardPayment = group.cardPayment;

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagamento pendente na fatura',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _TransactionInfo(transaction: cardPayment),
          const Divider(height: 28),
          Text(
            'Possíveis pagamentos na conta corrente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (group.bankCandidates.isEmpty)
            const Text(
              'Nenhum pagamento bancário com o mesmo valor foi encontrado nessa janela. Importe o extrato da conta corrente correto ou tente uma janela maior.',
            )
          else
            for (final bankPayment in group.bankCandidates) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TransactionInfo(transaction: bankPayment),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: 'Conciliar com este pagamento',
                      icon: Icons.link,
                      isLoading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () {
                              onReconcile(
                                cardPayment: cardPayment,
                                bankPayment: bankPayment,
                              );
                            },
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _TransactionInfo extends StatelessWidget {
  const _TransactionInfo({
    required this.transaction,
  });

  final ReconciliationTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Icon(
            Icons.payments_outlined,
            color: AppColors.indigo,
          ),
        ),
        const SizedBox(width: 12),
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
                '${transaction.date} • #${transaction.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          MoneyFormatter.format(transaction.amountAbs),
          style: const TextStyle(
            color: AppColors.indigo,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}