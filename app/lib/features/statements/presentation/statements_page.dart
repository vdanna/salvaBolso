import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/statement_models.dart';
import '../data/statements_api.dart';
import 'statement_detail_page.dart';

class StatementsPage extends StatefulWidget {
  const StatementsPage({
    super.key,
    required this.statementsApi,
  });

  final StatementsApi statementsApi;

  @override
  State<StatementsPage> createState() => _StatementsPageState();
}

class _StatementsPageState extends State<StatementsPage> {
  String _selectedMonth = 'all';
  bool _isLoading = false;
  String? _errorMessage;
  List<CreditCardStatement> _statements = [];

  @override
  void initState() {
    super.initState();
    _loadStatements();
  }

  Future<void> _loadStatements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statements = await widget.statementsApi.getStatements(
        month: _selectedMonth == 'all' ? null : _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _statements = statements;
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

    return 'Erro ao carregar faturas.';
  }

  Future<void> _openStatement(CreditCardStatement statement) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StatementDetailPage(
          statement: statement,
          statementsApi: widget.statementsApi,
        ),
      ),
    );

    if (changed == true) {
      await _loadStatements();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _loadStatements,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Faturas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Veja suas faturas importadas e rode a conciliação dos pagamentos.',
            ),
            const SizedBox(height: 20),
            SalvaCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Todas as faturas'),
                    ),
                    DropdownMenuItem(
                      value: '2026-04',
                      child: Text('Mês: 2026-04'),
                    ),
                    DropdownMenuItem(
                      value: '2026-05',
                      child: Text('Mês: 2026-05'),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _selectedMonth = value;
                          });

                          _loadStatements();
                        },
                ),
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Atualizar faturas',
              icon: Icons.refresh,
              onPressed: _isLoading ? null : _loadStatements,
            ),
            const SizedBox(height: 20),
            if (_isLoading && _statements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
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
            if (!_isLoading && _statements.isEmpty && _errorMessage == null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma fatura encontrada',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Importe um CSV de cartão de crédito para que a fatura apareça aqui.',
                    ),
                  ],
                ),
              ),
            for (final statement in _statements) ...[
              _StatementCard(
                statement: statement,
                onTap: () => _openStatement(statement),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.statement,
    required this.onTap,
  });

  final CreditCardStatement statement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        statement.isReconciled ? AppColors.seaGreen : AppColors.warning;

    return SalvaCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.mint,
              child: const Icon(
                Icons.credit_card,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statement.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${statement.accountName} • vence ${statement.dueDate ?? '--'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statement.statusLabel,
                      style: TextStyle(
                        color: statusColor == AppColors.warning
                            ? AppColors.indigo
                            : AppColors.seaGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormatter.format(statement.chargesTotal),
                  style: const TextStyle(
                    color: AppColors.indigo,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.indigo.withOpacity(0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}