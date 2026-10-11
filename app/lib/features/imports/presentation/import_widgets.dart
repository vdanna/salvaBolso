import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/import_models.dart';

class ImportSummaryRow extends StatelessWidget {
  const ImportSummaryRow({
    super.key,
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
          Text(
            value,
            style: const TextStyle(
              color: AppColors.indigo,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountPreviewCard extends StatelessWidget {
  const AccountPreviewCard({
    super.key,
    required this.preview,
  });

  final AccountCsvPreview preview;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prévia da conta corrente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ImportSummaryRow(label: 'Arquivo', value: preview.fileName),
          ImportSummaryRow(
            label: 'Período',
            value: '${preview.periodStart ?? '--'} até ${preview.periodEnd ?? '--'}',
          ),
          ImportSummaryRow(label: 'Linhas', value: '${preview.totalRows}'),
          ImportSummaryRow(label: 'Válidas', value: '${preview.validRows}'),
          ImportSummaryRow(label: 'Com erro', value: '${preview.errorRows}'),
          const Divider(height: 24),
          ImportSummaryRow(
            label: 'Entradas brutas',
            value: MoneyFormatter.format(preview.grossInflow),
          ),
          ImportSummaryRow(
            label: 'Saídas brutas',
            value: MoneyFormatter.format(preview.grossOutflow),
          ),
          ImportSummaryRow(
            label: 'Saldo líquido',
            value: MoneyFormatter.format(preview.netCashflow),
          ),
          ImportSummaryRow(
            label: 'Renda',
            value: MoneyFormatter.format(preview.income),
          ),
          ImportSummaryRow(
            label: 'Despesas',
            value: MoneyFormatter.format(preview.expenses),
          ),
          ImportSummaryRow(
            label: 'Pagamento de fatura',
            value: MoneyFormatter.format(preview.debtPayments),
          ),
          ImportSummaryRow(
            label: 'Crédito usado como caixa',
            value: MoneyFormatter.format(preview.liabilityIncrease),
          ),
          ImportWarnings(warnings: preview.warnings),
        ],
      ),
    );
  }
}

class CreditCardPreviewCard extends StatelessWidget {
  const CreditCardPreviewCard({
    super.key,
    required this.preview,
  });

  final CreditCardCsvPreview preview;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prévia da fatura',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ImportSummaryRow(label: 'Arquivo', value: preview.fileName),
          ImportSummaryRow(
            label: 'Fatura',
            value: preview.statementName ?? preview.statementReference ?? '--',
          ),
          ImportSummaryRow(
            label: 'Período',
            value: '${preview.periodStart ?? '--'} até ${preview.periodEnd ?? '--'}',
          ),
          ImportSummaryRow(label: 'Vencimento', value: preview.dueDate ?? '--'),
          ImportSummaryRow(label: 'Linhas', value: '${preview.totalRows}'),
          ImportSummaryRow(label: 'Válidas', value: '${preview.validRows}'),
          ImportSummaryRow(label: 'Com erro', value: '${preview.errorRows}'),
          const Divider(height: 24),
          ImportSummaryRow(
            label: 'Compras',
            value: MoneyFormatter.format(preview.chargesTotal),
          ),
          ImportSummaryRow(
            label: 'Pagamentos recebidos',
            value: MoneyFormatter.format(preview.paymentsTotal),
          ),
          ImportSummaryRow(
            label: 'Saldo da fatura',
            value: MoneyFormatter.format(preview.statementBalance),
          ),
          ImportSummaryRow(
            label: 'Compras à vista',
            value:
                '${preview.singlePurchaseRows} • ${MoneyFormatter.format(preview.singlePurchaseTotal)}',
          ),
          ImportSummaryRow(
            label: 'Parceladas',
            value:
                '${preview.installmentRows} • ${MoneyFormatter.format(preview.installmentTotal)}',
          ),
          ImportSummaryRow(
            label: 'Pagamentos',
            value: '${preview.paymentRows}',
          ),
          ImportWarnings(warnings: preview.warnings),
        ],
      ),
    );
  }
}

class ImportResultCard extends StatelessWidget {
  const ImportResultCard({
    super.key,
    required this.result,
  });

  final CsvImportResult result;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.seaGreen,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'Importação concluída',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ImportSummaryRow(label: 'Arquivo', value: result.fileName),
          ImportSummaryRow(label: 'Lote', value: '#${result.importBatchId}'),
          ImportSummaryRow(label: 'Linhas', value: '${result.totalRows}'),
          ImportSummaryRow(label: 'Importadas', value: '${result.imported}'),
          ImportSummaryRow(label: 'Duplicadas', value: '${result.duplicates}'),
          if (result.statementId != null)
            ImportSummaryRow(label: 'Fatura ID', value: '#${result.statementId}'),
          if (result.pendingPayments != null)
            ImportSummaryRow(
              label: 'Pagamentos pendentes',
              value: '${result.pendingPayments}',
            ),
          ImportWarnings(warnings: result.warnings),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ImportWarnings(
              title: 'Erros',
              warnings: result.errors,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    );
  }
}

class ImportWarnings extends StatelessWidget {
  const ImportWarnings({
    super.key,
    required this.warnings,
    this.title = 'Avisos',
    this.icon = Icons.info_outline,
  });

  final List<String> warnings;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.indigo,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings) ...[
            Text('• $warning'),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}