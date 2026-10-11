import '../../../shared/formatters/money_formatter.dart';

class CashflowSummary {
  CashflowSummary({
    required this.month,
    required this.grossInflow,
    required this.grossOutflow,
    required this.netCashflow,
    required this.income,
    required this.expenses,
    required this.debtPayments,
    required this.liabilityIncrease,
    required this.cardBillPayments,
    required this.reconciledCardBillPayments,
    required this.unreconciledCardBillPayments,
    required this.warnings,
  });

  final String month;
  final double grossInflow;
  final double grossOutflow;
  final double netCashflow;
  final double income;
  final double expenses;
  final double debtPayments;
  final double liabilityIncrease;
  final double cardBillPayments;
  final double reconciledCardBillPayments;
  final double unreconciledCardBillPayments;
  final List<String> warnings;

  factory CashflowSummary.fromJson(Map<String, dynamic> json) {
    return CashflowSummary(
      month: json['month']?.toString() ?? '',
      grossInflow: MoneyFormatter.parse(json['gross_inflow']),
      grossOutflow: MoneyFormatter.parse(json['gross_outflow']),
      netCashflow: MoneyFormatter.parse(json['net_cashflow']),
      income: MoneyFormatter.parse(json['income']),
      expenses: MoneyFormatter.parse(json['expenses']),
      debtPayments: MoneyFormatter.parse(json['debt_payments']),
      liabilityIncrease: MoneyFormatter.parse(json['liability_increase']),
      cardBillPayments: MoneyFormatter.parse(json['card_bill_payments']),
      reconciledCardBillPayments:
          MoneyFormatter.parse(json['reconciled_card_bill_payments']),
      unreconciledCardBillPayments:
          MoneyFormatter.parse(json['unreconciled_card_bill_payments']),
      warnings: List<String>.from(json['warnings'] ?? const []),
    );
  }
}

class ConsumptionSummary {
  ConsumptionSummary({
    required this.month,
    required this.totalConsumption,
    required this.checkingConsumption,
    required this.creditCardConsumption,
    required this.debitCardTotal,
    required this.pixTotal,
    required this.bankSlipTotal,
    required this.creditCardTotal,
    required this.nupayTotal,
    required this.installmentTotal,
    required this.singlePurchaseTotal,
    required this.topTransactions,
    required this.warnings,
  });

  final String month;
  final double totalConsumption;
  final double checkingConsumption;
  final double creditCardConsumption;
  final double debitCardTotal;
  final double pixTotal;
  final double bankSlipTotal;
  final double creditCardTotal;
  final double nupayTotal;
  final double installmentTotal;
  final double singlePurchaseTotal;
  final List<DashboardTransaction> topTransactions;
  final List<String> warnings;

  factory ConsumptionSummary.fromJson(Map<String, dynamic> json) {
    final transactions = json['top_transactions'];

    return ConsumptionSummary(
      month: json['month']?.toString() ?? '',
      totalConsumption: MoneyFormatter.parse(json['total_consumption']),
      checkingConsumption: MoneyFormatter.parse(json['checking_consumption']),
      creditCardConsumption:
          MoneyFormatter.parse(json['credit_card_consumption']),
      debitCardTotal: MoneyFormatter.parse(json['debit_card_total']),
      pixTotal: MoneyFormatter.parse(json['pix_total']),
      bankSlipTotal: MoneyFormatter.parse(json['bank_slip_total']),
      creditCardTotal: MoneyFormatter.parse(json['credit_card_total']),
      nupayTotal: MoneyFormatter.parse(json['nupay_total']),
      installmentTotal: MoneyFormatter.parse(json['installment_total']),
      singlePurchaseTotal: MoneyFormatter.parse(json['single_purchase_total']),
      topTransactions: transactions is List
          ? transactions
              .map(
                (item) => DashboardTransaction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : [],
      warnings: List<String>.from(json['warnings'] ?? const []),
    );
  }
}

class HealthScoreSummary {
  HealthScoreSummary({
    required this.month,
    required this.score,
    required this.status,
    required this.income,
    required this.consumption,
    required this.debtPayments,
    required this.netCashflow,
    required this.consumptionRate,
    required this.debtPaymentRate,
    required this.cashMarginRate,
    required this.warnings,
    required this.recommendations,
  });

  final String month;
  final int score;
  final String status;
  final double income;
  final double consumption;
  final double debtPayments;
  final double netCashflow;
  final double? consumptionRate;
  final double? debtPaymentRate;
  final double? cashMarginRate;
  final List<String> warnings;
  final List<String> recommendations;

  factory HealthScoreSummary.fromJson(Map<String, dynamic> json) {
    return HealthScoreSummary(
      month: json['month']?.toString() ?? '',
      score: int.tryParse(json['score'].toString()) ?? 0,
      status: json['status']?.toString() ?? '',
      income: MoneyFormatter.parse(json['income']),
      consumption: MoneyFormatter.parse(json['consumption']),
      debtPayments: MoneyFormatter.parse(json['debt_payments']),
      netCashflow: MoneyFormatter.parse(json['net_cashflow']),
      consumptionRate: json['consumption_rate'] == null
          ? null
          : MoneyFormatter.parse(json['consumption_rate']),
      debtPaymentRate: json['debt_payment_rate'] == null
          ? null
          : MoneyFormatter.parse(json['debt_payment_rate']),
      cashMarginRate: json['cash_margin_rate'] == null
          ? null
          : MoneyFormatter.parse(json['cash_margin_rate']),
      warnings: List<String>.from(json['warnings'] ?? const []),
      recommendations:
          List<String>.from(json['recommendations'] ?? const []),
    );
  }
}

class MerchantSummary {
  MerchantSummary({
    required this.merchantName,
    required this.total,
    required this.transactionCount,
    required this.percentage,
  });

  final String merchantName;
  final double total;
  final int transactionCount;
  final double percentage;

  factory MerchantSummary.fromJson(Map<String, dynamic> json) {
    return MerchantSummary(
      merchantName: json['merchant_name']?.toString() ?? 'Não identificado',
      total: MoneyFormatter.parse(json['total']),
      transactionCount: int.tryParse(json['transaction_count'].toString()) ?? 0,
      percentage: MoneyFormatter.parse(json['percentage']),
    );
  }
}

class InstallmentSummary {
  InstallmentSummary({
    required this.merchantName,
    required this.installmentTotal,
    required this.amountInMonth,
    required this.transactionCountInMonth,
    required this.installmentsSeen,
  });

  final String merchantName;
  final int? installmentTotal;
  final double amountInMonth;
  final int transactionCountInMonth;
  final List<int> installmentsSeen;

  factory InstallmentSummary.fromJson(Map<String, dynamic> json) {
    final seen = json['installments_seen'];

    return InstallmentSummary(
      merchantName: json['merchant_name']?.toString() ?? 'Não identificado',
      installmentTotal: json['installment_total'] == null
          ? null
          : int.tryParse(json['installment_total'].toString()),
      amountInMonth: MoneyFormatter.parse(json['amount_in_month']),
      transactionCountInMonth:
          int.tryParse(json['transaction_count_in_month'].toString()) ?? 0,
      installmentsSeen: seen is List
          ? seen.map((item) => int.tryParse(item.toString()) ?? 0).toList()
          : [],
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.categoryName,
    required this.total,
    required this.transactionCount,
    required this.percentage,
  });

  final String categoryName;
  final double total;
  final int transactionCount;
  final double percentage;

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      categoryName: json['category_name']?.toString() ?? 'Sem categoria',
      total: MoneyFormatter.parse(json['total']),
      transactionCount:
          int.tryParse(json['transaction_count'].toString()) ?? 0,
      percentage: MoneyFormatter.parse(json['percentage']),
    );
  }
}

class DashboardTransaction {
  DashboardTransaction({
    required this.id,
    required this.date,
    required this.amountAbs,
    required this.accountType,
    required this.cashflowType,
    required this.operationType,
    required this.paymentMethod,
    required this.merchantName,
    required this.displayDescription,
  });

  final int id;
  final String date;
  final double amountAbs;
  final String accountType;
  final String cashflowType;
  final String operationType;
  final String paymentMethod;
  final String? merchantName;
  final String? displayDescription;

  factory DashboardTransaction.fromJson(Map<String, dynamic> json) {
    return DashboardTransaction(
      id: int.tryParse(json['id'].toString()) ?? 0,
      date: json['date']?.toString() ?? '',
      amountAbs: MoneyFormatter.parse(json['amount_abs']),
      accountType: json['account_type']?.toString() ?? '',
      cashflowType: json['cashflow_type']?.toString() ?? '',
      operationType: json['operation_type']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      merchantName: json['merchant_name']?.toString(),
      displayDescription: json['display_description']?.toString(),
    );
  }
}

class DashboardData {
  DashboardData({
    required this.cashflow,
    required this.consumption,
    required this.healthScore,
    required this.merchants,
    required this.installments,
    required this.categories,
  });

  final CashflowSummary cashflow;
  final ConsumptionSummary consumption;
  final HealthScoreSummary healthScore;
  final List<MerchantSummary> merchants;
  final List<InstallmentSummary> installments;
  final List<CategorySummary> categories;
}