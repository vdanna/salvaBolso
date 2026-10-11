import '../../../shared/formatters/money_formatter.dart';

class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.institutionName,
    required this.date,
    required this.amount,
    required this.amountAbs,
    required this.accountType,
    required this.cashDirection,
    required this.cashflowType,
    required this.operationType,
    required this.paymentMethod,
    required this.displayDescription,
    required this.merchantName,
    required this.categoryName,
    required this.statementId,
    required this.installmentNumber,
    required this.installmentTotal,
    required this.reconciliationStatus,
    required this.isReconciled,
    required this.matchedTransactionId,
    required this.createdAt,
  });

  final int id;
  final int accountId;
  final String accountName;
  final String institutionName;
  final String date;
  final double amount;
  final double amountAbs;
  final String accountType;
  final String cashDirection;
  final String cashflowType;
  final String operationType;
  final String paymentMethod;
  final String? displayDescription;
  final String? merchantName;
  final String? categoryName;
  final int? statementId;
  final int? installmentNumber;
  final int? installmentTotal;
  final String? reconciliationStatus;
  final bool isReconciled;
  final int? matchedTransactionId;
  final String? createdAt;

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    return FinancialTransaction(
      id: int.tryParse(json['id'].toString()) ?? 0,
      accountId: int.tryParse(json['account_id'].toString()) ?? 0,
      accountName: json['account_name']?.toString() ?? '',
      institutionName: json['institution_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: MoneyFormatter.parse(json['amount']),
      amountAbs: MoneyFormatter.parse(json['amount_abs']),
      accountType: json['account_type']?.toString() ?? '',
      cashDirection: json['cash_direction']?.toString() ?? '',
      cashflowType: json['cashflow_type']?.toString() ?? '',
      operationType: json['operation_type']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      displayDescription: json['display_description']?.toString(),
      merchantName: json['merchant_name']?.toString(),
      categoryName: json['category_name']?.toString(),
      statementId: parseNullableInt(json['statement_id']),
      installmentNumber: parseNullableInt(json['installment_number']),
      installmentTotal: parseNullableInt(json['installment_total']),
      reconciliationStatus: json['reconciliation_status']?.toString(),
      isReconciled: json['is_reconciled'] == true,
      matchedTransactionId: parseNullableInt(json['matched_transaction_id']),
      createdAt: json['created_at']?.toString(),
    );
  }

  String get title {
    final description = displayDescription;

    if (description != null && description.trim().isNotEmpty) {
      return description;
    }

    final merchant = merchantName;

    if (merchant != null && merchant.trim().isNotEmpty) {
      return merchant;
    }

    return 'Transação #$id';
  }

  String get accountTypeLabel {
    switch (accountType) {
      case 'checking':
        return 'Conta corrente';
      case 'credit_card':
        return 'Cartão de crédito';
      default:
        return accountType.isEmpty ? 'Conta' : accountType;
    }
  }

  String get cashflowTypeLabel {
    switch (cashflowType) {
      case 'income':
        return 'Entrada';
      case 'expense':
        return 'Despesa';
      case 'debt_payment':
        return 'Pagamento de dívida/fatura';
      case 'liability_increase':
        return 'Aumento de dívida';
      default:
        return cashflowType.isEmpty ? 'Não classificado' : cashflowType;
    }
  }

  String get operationTypeLabel {
    switch (operationType) {
      case 'credit_card_purchase':
        return 'Compra no crédito';
      case 'credit_card_installment':
        return 'Compra parcelada';
      case 'credit_card_payment_received':
        return 'Pagamento recebido no cartão';
      case 'credit_card_bill_payment':
        return 'Pagamento de fatura';
      case 'pix_sent':
        return 'Pix enviado';
      case 'pix_received':
        return 'Pix recebido';
      case 'bank_slip_payment':
        return 'Boleto';
      case 'debit_purchase':
        return 'Débito';
      case 'income':
        return 'Renda';
      default:
        return operationType.isEmpty ? 'Operação' : operationType;
    }
  }

  bool get isOutflow {
    return cashDirection == 'outflow' || amount < 0;
  }

  bool get isIncome {
    return cashflowType == 'income';
  }

  String get displayAmount {
    final formatted = MoneyFormatter.format(amountAbs);

    if (isIncome) {
      return '+ $formatted';
    }

    if (isOutflow || cashflowType == 'expense') {
      return '- $formatted';
    }

    return formatted;
  }
}

class TransactionsResponse {
  const TransactionsResponse({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<FinancialTransaction> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'];

    return TransactionsResponse(
      items: items is List
          ? items
              .map(
                (item) => FinancialTransaction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : [],
      total: int.tryParse(json['total'].toString()) ?? 0,
      limit: int.tryParse(json['limit'].toString()) ?? 0,
      offset: int.tryParse(json['offset'].toString()) ?? 0,
      hasMore: json['has_more'] == true,
    );
  }
}