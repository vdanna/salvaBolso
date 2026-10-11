import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/statement_models.dart';
import '../data/statements_api.dart';
import 'manual_reconciliation_page.dart';

class StatementDetailPage extends StatefulWidget {
  const StatementDetailPage({
    super.key,
    required this.statement,
    required this.statementsApi,
  });

  final CreditCardStatement statement;
  final StatementsApi statementsApi;

  @override
  State<StatementDetailPage> createState() => _StatementDetailPageState();
}

class _StatementDetailPageState extends State<StatementDetailPage> {
  bool _isLoadingSummary = false;
  bool _isReconciling = false;
  bool _reconciliationChanged = false;

  int _dayWindow = 3;

  String? _errorMessage;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _reconciliationResult;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _errorMessage = null;
    });

    try {
      final summary = await widget.statementsApi.getStatementSummary(
        statementId: widget.statement.id,
      );

      if (!mounted) return;

      setState(() {
        _summary = summary;
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
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _reconcile() async {
    setState(() {
      _isReconciling = true;
      _errorMessage = null;
      _reconciliationResult = null;
    });

    try {
      final result = await widget.statementsApi.reconcileStatement(
        statementId: widget.statement.id,
        dayWindow: _dayWindow,
      );

      if (!mounted) return;

      setState(() {
        _reconciliationResult = result;
        _reconciliationChanged = true;
      });

      await _loadSummary();
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
        _isReconciling = false;
      });
    }
  }

  Future<void> _openManualReconciliation() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualReconciliationPage(
          statement: widget.statement,
          statementsApi: widget.statementsApi,
          dayWindow: _dayWindow < 30 ? 30 : _dayWindow,
        ),
      ),
    );

    if (changed == true) {
      setState(() {
        _reconciliationChanged = true;
        _reconciliationResult = {
          'success': true,
          'statement_status': 'reconciled',
          'matched': 1,
          'pending': 0,
          'ambiguous': 0,
          'message': 'Conciliação manual realizada com sucesso.',
        };
      });

      await _loadSummary();
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

    return 'Erro ao processar fatura.';
  }

  void _close() {
    Navigator.of(context).pop(_reconciliationChanged);
  }

  @override
  Widget build(BuildContext context) {
    final statement = widget.statement;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalhe da fatura'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.pageGradient,
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                statement.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '${statement.accountName} • ${statement.institutionName}',
              ),
              const SizedBox(height: 20),
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo da fatura',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      label: 'Período',
                      value:
                          '${statement.periodStart ?? '--'} até ${statement.periodEnd ?? '--'}',
                    ),
                    _DetailRow(
                      label: 'Vencimento',
                      value: statement.dueDate ?? '--',
                    ),
                    _DetailRow(
                      label: 'Compras',
                      value: MoneyFormatter.format(statement.chargesTotal),
                    ),
                    _DetailRow(
                      label: 'Pagamentos',
                      value: MoneyFormatter.format(statement.paymentsTotal),
                    ),
                    _DetailRow(
                      label: 'Saldo da fatura',
                      value: MoneyFormatter.format(statement.statementBalance),
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: statement.statusLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SalvaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _dayWindow,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: const [
                      DropdownMenuItem(
                        value: 3,
                        child: Text('Buscar pagamento em ±3 dias'),
                      ),
                      DropdownMenuItem(
                        value: 7,
                        child: Text('Buscar pagamento em ±7 dias'),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text('Buscar pagamento em ±15 dias'),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('Buscar pagamento em ±30 dias'),
                      ),
                    ],
                    onChanged: _isReconciling
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _dayWindow = value;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingSummary)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_summary != null) _SummaryCard(summary: _summary!),
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
              const SizedBox(height: 16),
              GradientButton(
                label: 'Conciliar automaticamente',
                icon: Icons.sync_alt,
                isLoading: _isReconciling,
                onPressed: _isReconciling ? null : _reconcile,
              ),
              if (_reconciliationResult != null) ...[
                const SizedBox(height: 16),
                _ReconciliationResultCard(
                  result: _reconciliationResult!,
                  onManualPressed: _openManualReconciliation,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
  });

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final entriesToShow = [
      'reconciliation_status',
      'total_charges',
      'total_payments',
      'statement_balance',
      'purchase_rows',
      'payment_rows',
      'installment_rows',
      'single_purchase_rows',
      'matched_bank_payment_id',
      'matched_card_payment_id',
    ];

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhes calculados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final key in entriesToShow)
            if (summary.containsKey(key))
              _DetailRow(
                label: key,
                value: summary[key]?.toString() ?? '--',
              ),
        ],
      ),
    );
  }
}

class _ReconciliationResultCard extends StatelessWidget {
  const _ReconciliationResultCard({
    required this.result,
    required this.onManualPressed,
  });

  final Map<String, dynamic> result;
  final VoidCallback onManualPressed;

  int _asInt(String key) {
    return int.tryParse(result[key].toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final matched = _asInt('matched');
    final pending = _asInt('pending');
    final ambiguous = _asInt('ambiguous');
    final statementStatus = result['statement_status']?.toString() ?? '--';
    final message = result['message']?.toString() ?? '';

    final isSuccess = matched > 0 && pending == 0 && ambiguous == 0;
    final isPartial = matched > 0 && (pending > 0 || ambiguous > 0);
    final needsManual = pending > 0 || ambiguous > 0;

    final IconData icon;
    final Color color;
    final String title;

    if (isSuccess) {
      icon = Icons.check_circle;
      color = AppColors.seaGreen;
      title = 'Fatura conciliada';
    } else if (isPartial) {
      icon = Icons.warning_amber_rounded;
      color = AppColors.warning;
      title = 'Conciliação parcial';
    } else if (ambiguous > 0) {
      icon = Icons.help_outline;
      color = AppColors.warning;
      title = 'Candidatos ambíguos';
    } else if (pending > 0) {
      icon = Icons.search_off;
      color = AppColors.warning;
      title = 'Pagamento não encontrado';
    } else {
      icon = Icons.info_outline;
      color = AppColors.indigo;
      title = 'Conciliação processada';
    }

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message),
          ],
          const Divider(height: 28),
          _DetailRow(
            label: 'Status da fatura',
            value: statementStatus,
          ),
          _DetailRow(
            label: 'Conciliados',
            value: '$matched',
          ),
          _DetailRow(
            label: 'Pendentes',
            value: '$pending',
          ),
          _DetailRow(
            label: 'Ambíguos',
            value: '$ambiguous',
          ),
          if (needsManual) ...[
            const SizedBox(height: 16),
            const Text(
              'A conciliação automática não conseguiu resolver tudo. Você pode tentar escolher manualmente o pagamento correspondente.',
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Abrir conciliação manual',
              icon: Icons.tune,
              onPressed: onManualPressed,
            ),
          ],
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
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