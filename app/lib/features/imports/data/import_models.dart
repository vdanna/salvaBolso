import '../../../shared/formatters/money_formatter.dart';

enum CsvImportKind {
  account,
  creditCard,
}

extension CsvImportKindLabel on CsvImportKind {
  String get label {
    switch (this) {
      case CsvImportKind.account:
        return 'Conta corrente';
      case CsvImportKind.creditCard:
        return 'Cartão de crédito';
    }
  }

  String get accountType {
    switch (this) {
      case CsvImportKind.account:
        return 'checking';
      case CsvImportKind.creditCard:
        return 'credit_card';
    }
  }
}

class AccountCsvPreview {
  AccountCsvPreview({
    required this.fileName,
    required this.format,
    required this.periodStart,
    required this.periodEnd,
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.grossInflow,
    required this.grossOutflow,
    required this.netCashflow,
    required this.income,
    required this.expenses,
    required this.debtPayments,
    required this.liabilityIncrease,
    required this.warnings,
  });

  final String fileName;
  final String format;
  final String? periodStart;
  final String? periodEnd;
  final int totalRows;
  final int validRows;
  final int errorRows;
  final double grossInflow;
  final double grossOutflow;
  final double netCashflow;
  final double income;
  final double expenses;
  final double debtPayments;
  final double liabilityIncrease;
  final List<String> warnings;

  factory AccountCsvPreview.fromJson(Map<String, dynamic> json) {
    return AccountCsvPreview(
      fileName: json['file_name']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      totalRows: int.tryParse(json['total_rows'].toString()) ?? 0,
      validRows: int.tryParse(json['valid_rows'].toString()) ?? 0,
      errorRows: int.tryParse(json['error_rows'].toString()) ?? 0,
      grossInflow: MoneyFormatter.parse(json['gross_inflow']),
      grossOutflow: MoneyFormatter.parse(json['gross_outflow']),
      netCashflow: MoneyFormatter.parse(json['net_cashflow']),
      income: MoneyFormatter.parse(json['income']),
      expenses: MoneyFormatter.parse(json['expenses']),
      debtPayments: MoneyFormatter.parse(json['debt_payments']),
      liabilityIncrease: MoneyFormatter.parse(json['liability_increase']),
      warnings: List<String>.from(json['warnings'] ?? const []),
    );
  }
}

class CreditCardCsvPreview {
  CreditCardCsvPreview({
    required this.fileName,
    required this.format,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.statementReference,
    required this.statementName,
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.chargesTotal,
    required this.paymentsTotal,
    required this.statementBalance,
    required this.purchaseRows,
    required this.paymentRows,
    required this.installmentRows,
    required this.installmentTotal,
    required this.singlePurchaseRows,
    required this.singlePurchaseTotal,
    required this.warnings,
  });

  final String fileName;
  final String format;
  final String? periodStart;
  final String? periodEnd;
  final String? dueDate;
  final String? statementReference;
  final String? statementName;
  final int totalRows;
  final int validRows;
  final int errorRows;
  final double chargesTotal;
  final double paymentsTotal;
  final double statementBalance;
  final int purchaseRows;
  final int paymentRows;
  final int installmentRows;
  final double installmentTotal;
  final int singlePurchaseRows;
  final double singlePurchaseTotal;
  final List<String> warnings;

  factory CreditCardCsvPreview.fromJson(Map<String, dynamic> json) {
    return CreditCardCsvPreview(
      fileName: json['file_name']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      dueDate: json['due_date']?.toString(),
      statementReference: json['statement_reference']?.toString(),
      statementName: json['statement_name']?.toString(),
      totalRows: int.tryParse(json['total_rows'].toString()) ?? 0,
      validRows: int.tryParse(json['valid_rows'].toString()) ?? 0,
      errorRows: int.tryParse(json['error_rows'].toString()) ?? 0,
      chargesTotal: MoneyFormatter.parse(json['charges_total']),
      paymentsTotal: MoneyFormatter.parse(json['payments_total']),
      statementBalance: MoneyFormatter.parse(json['statement_balance']),
      purchaseRows: int.tryParse(json['purchase_rows'].toString()) ?? 0,
      paymentRows: int.tryParse(json['payment_rows'].toString()) ?? 0,
      installmentRows: int.tryParse(json['installment_rows'].toString()) ?? 0,
      installmentTotal: MoneyFormatter.parse(json['installment_total']),
      singlePurchaseRows:
          int.tryParse(json['single_purchase_rows'].toString()) ?? 0,
      singlePurchaseTotal: MoneyFormatter.parse(json['single_purchase_total']),
      warnings: List<String>.from(json['warnings'] ?? const []),
    );
  }
}

class CsvImportResult {
  CsvImportResult({
    required this.success,
    required this.importBatchId,
    required this.fileName,
    required this.format,
    required this.periodStart,
    required this.periodEnd,
    required this.totalRows,
    required this.imported,
    required this.duplicates,
    required this.errors,
    required this.warnings,
    this.statementId,
    this.dueDate,
    this.statementReference,
    this.purchaseRows,
    this.paymentRows,
    this.installmentRows,
    this.matchedPayments,
    this.pendingPayments,
  });

  final bool success;
  final int importBatchId;
  final String fileName;
  final String format;
  final String? periodStart;
  final String? periodEnd;
  final int totalRows;
  final int imported;
  final int duplicates;
  final List<String> errors;
  final List<String> warnings;

  final int? statementId;
  final String? dueDate;
  final String? statementReference;
  final int? purchaseRows;
  final int? paymentRows;
  final int? installmentRows;
  final int? matchedPayments;
  final int? pendingPayments;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) {
    return CsvImportResult(
      success: json['success'] == true,
      importBatchId: int.tryParse(json['import_batch_id'].toString()) ?? 0,
      fileName: json['file_name']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      totalRows: int.tryParse(json['total_rows'].toString()) ?? 0,
      imported: int.tryParse(json['imported'].toString()) ?? 0,
      duplicates: int.tryParse(json['duplicates'].toString()) ?? 0,
      errors: List<String>.from(json['errors'] ?? const []),
      warnings: List<String>.from(json['warnings'] ?? const []),
      statementId: json['statement_id'] == null
          ? null
          : int.tryParse(json['statement_id'].toString()),
      dueDate: json['due_date']?.toString(),
      statementReference: json['statement_reference']?.toString(),
      purchaseRows: json['purchase_rows'] == null
          ? null
          : int.tryParse(json['purchase_rows'].toString()),
      paymentRows: json['payment_rows'] == null
          ? null
          : int.tryParse(json['payment_rows'].toString()),
      installmentRows: json['installment_rows'] == null
          ? null
          : int.tryParse(json['installment_rows'].toString()),
      matchedPayments: json['matched_payments'] == null
          ? null
          : int.tryParse(json['matched_payments'].toString()),
      pendingPayments: json['pending_payments'] == null
          ? null
          : int.tryParse(json['pending_payments'].toString()),
    );
  }
}