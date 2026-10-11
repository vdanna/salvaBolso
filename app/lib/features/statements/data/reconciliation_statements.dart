import '../../../shared/formatters/money_formatter.dart';

class ReconciliationTransaction {
  const ReconciliationTransaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amount,
    required this.amountAbs,
    required this.accountType,
    required this.cashflowType,
    required this.operationType,
    required this.displayDescription,
    required this.reconciliationStatus,
    required this.isReconciled,
  });

  final int id;
  final int accountId;
  final String date;
  final double amount;
  final double amountAbs;
  final String accountType;
  final String cashflowType;
  final String operationType;
  final String? displayDescription;
  final String reconciliationStatus;
  final bool isReconciled;

  factory ReconciliationTransaction.fromJson(Map<String, dynamic> json) {
    return ReconciliationTransaction(
      id: int.tryParse(json['id'].toString()) ?? 0,
      accountId: int.tryParse(json['account_id'].toString()) ?? 0,
      date: json['date']?.toString() ?? '',
      amount: MoneyFormatter.parse(json['amount']),
      amountAbs: MoneyFormatter.parse(json['amount_abs']),
      accountType: json['account_type']?.toString() ?? '',
      cashflowType: json['cashflow_type']?.toString() ?? '',
      operationType: json['operation_type']?.toString() ?? '',
      displayDescription: json['display_description']?.toString(),
      reconciliationStatus: json['reconciliation_status']?.toString() ?? '',
      isReconciled: json['is_reconciled'] == true,
    );
  }

  String get title {
    final description = displayDescription;

    if (description != null && description.isNotEmpty) {
      return description;
    }

    return 'Transação #$id';
  }
}

class ManualCandidateGroup {
  const ManualCandidateGroup({
    required this.cardPayment,
    required this.bankCandidates,
  });

  final ReconciliationTransaction cardPayment;
  final List<ReconciliationTransaction> bankCandidates;

  factory ManualCandidateGroup.fromJson(Map<String, dynamic> json) {
    final candidates = json['bank_candidates'];

    return ManualCandidateGroup(
      cardPayment: ReconciliationTransaction.fromJson(
        Map<String, dynamic>.from(json['card_payment'] as Map),
      ),
      bankCandidates: candidates is List
          ? candidates
              .map(
                (item) => ReconciliationTransaction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : [],
    );
  }
}

class ManualCandidatesResponse {
  const ManualCandidatesResponse({
    required this.statementId,
    required this.dayWindow,
    required this.items,
  });

  final int statementId;
  final int dayWindow;
  final List<ManualCandidateGroup> items;

  factory ManualCandidatesResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'];

    return ManualCandidatesResponse(
      statementId: int.tryParse(json['statement_id'].toString()) ?? 0,
      dayWindow: int.tryParse(json['day_window'].toString()) ?? 0,
      items: items is List
          ? items
              .map(
                (item) => ManualCandidateGroup.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : [],
    );
  }
}