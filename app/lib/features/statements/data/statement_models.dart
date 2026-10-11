import '../../../shared/formatters/money_formatter.dart';

class CreditCardStatement {
  const CreditCardStatement({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.institutionName,
    required this.statementReference,
    required this.statementName,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.chargesTotal,
    required this.paymentsTotal,
    required this.statementBalance,
    required this.reconciliationStatus,
  });

  final int id;
  final int accountId;
  final String accountName;
  final String institutionName;
  final String? statementReference;
  final String? statementName;
  final String? periodStart;
  final String? periodEnd;
  final String? dueDate;
  final double chargesTotal;
  final double paymentsTotal;
  final double statementBalance;
  final String? reconciliationStatus;

  factory CreditCardStatement.fromJson(Map<String, dynamic> json) {
    return CreditCardStatement(
      id: int.tryParse(json['id'].toString()) ?? 0,
      accountId: int.tryParse(json['account_id'].toString()) ?? 0,
      accountName: json['account_name']?.toString() ?? '',
      institutionName: json['institution_name']?.toString() ?? '',
      statementReference: json['statement_reference']?.toString(),
      statementName: json['statement_name']?.toString(),
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      dueDate: json['due_date']?.toString(),
      chargesTotal: MoneyFormatter.parse(json['charges_total']),
      paymentsTotal: MoneyFormatter.parse(json['payments_total']),
      statementBalance: MoneyFormatter.parse(json['statement_balance']),
      reconciliationStatus: json['reconciliation_status']?.toString(),
    );
  }

  String get title {
    if (statementName != null && statementName!.isNotEmpty) {
      return statementName!;
    }

    if (statementReference != null && statementReference!.isNotEmpty) {
      return 'Fatura $statementReference';
    }

    return 'Fatura #$id';
  }

  String get statusLabel {
    switch (reconciliationStatus) {
      case 'reconciled':
        return 'Conciliada';
      case 'partially_reconciled':
        return 'Parcialmente conciliada';
      case 'partial':
        return 'Parcial';
      case 'pending':
        return 'Pendente';
      case 'ignored':
        return 'Ignorada';
      case 'no_payments':
        return 'Sem pagamentos';
      default:
        return reconciliationStatus ?? 'Pendente';
    }
  }

  bool get isReconciled => reconciliationStatus == 'reconciled';
}