import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/dashboard_models.dart';

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.mint,
            child: Icon(
              icon,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.indigo,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({
    super.key,
    required this.healthScore,
  });

  final HealthScoreSummary healthScore;

  @override
  Widget build(BuildContext context) {
    final score = healthScore.score.clamp(0, 100);
    final progress = score / 100;

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score financeiro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      backgroundColor: AppColors.lightGray,
                      color: AppColors.seaGreen,
                    ),
                    Center(
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          color: AppColors.indigo,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthScore.status.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.indigo,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Consumo: ${_rateText(healthScore.consumptionRate)}',
                    ),
                    Text(
                      'Dívidas/fatura: ${_rateText(healthScore.debtPaymentRate)}',
                    ),
                    Text(
                      'Margem de caixa: ${_rateText(healthScore.cashMarginRate)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rateText(double? value) {
    if (value == null) {
      return '--';
    }

    return '${value.toStringAsFixed(2).replaceAll('.', ',')}%';
  }
}

class WarningListCard extends StatelessWidget {
  const WarningListCard({
    super.key,
    required this.title,
    required this.items,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.indigo,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class MerchantListCard extends StatelessWidget {
  const MerchantListCard({
    super.key,
    required this.items,
  });

  final List<MerchantSummary> items;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onde você mais gastou no cartão',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Nenhum lojista encontrado para este mês.')
          else
            for (final item in items.take(5)) ...[
              _LineItem(
                title: item.merchantName,
                subtitle: '${item.transactionCount} transações',
                value: MoneyFormatter.format(item.total),
              ),
              const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class InstallmentsCard extends StatelessWidget {
  const InstallmentsCard({
    super.key,
    required this.items,
  });

  final List<InstallmentSummary> items;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compras parceladas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Nenhuma compra parcelada encontrada para este mês.')
          else
            for (final item in items.take(5)) ...[
              _LineItem(
                title: item.merchantName,
                subtitle: _installmentSubtitle(item),
                value: MoneyFormatter.format(item.amountInMonth),
              ),
              const Divider(height: 20),
            ],
        ],
      ),
    );
  }

  String _installmentSubtitle(InstallmentSummary item) {
    final seen = item.installmentsSeen.isEmpty
        ? '--'
        : item.installmentsSeen.join(', ');

    final total = item.installmentTotal?.toString() ?? '--';

    return 'Parcelas vistas: $seen de $total';
  }
}

class TopTransactionsCard extends StatelessWidget {
  const TopTransactionsCard({
    super.key,
    required this.items,
  });

  final List<DashboardTransaction> items;

  @override
  Widget build(BuildContext context) {
    return SalvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maiores gastos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Nenhuma transação encontrada para este mês.')
          else
            for (final item in items.take(6)) ...[
              _LineItem(
                title: item.displayDescription ??
                    item.merchantName ??
                    'Transação',
                subtitle: '${item.date} • ${item.paymentMethod}',
                value: MoneyFormatter.format(item.amountAbs),
              ),
              const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.lightGray,
          child: Icon(
            Icons.payments_outlined,
            color: AppColors.indigo,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.indigo,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}