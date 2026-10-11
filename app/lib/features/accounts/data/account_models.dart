class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.institutionName,
    required this.accountType,
  });

  final int id;
  final String name;
  final String institutionName;
  final String accountType;

  factory FinancialAccount.fromJson(Map<String, dynamic> json) {
    return FinancialAccount(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      institutionName: json['institution_name']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? '',
    );
  }

  String get accountTypeLabel {
    switch (accountType) {
      case 'checking':
        return 'Conta corrente';
      case 'credit_card':
        return 'Cartão de crédito';
      case 'investment':
        return 'Investimento';
      case 'cash':
        return 'Dinheiro';
      case 'wallet':
        return 'Carteira digital';
      default:
        return accountType;
    }
  }

  bool get isChecking => accountType == 'checking';

  bool get isCreditCard => accountType == 'credit_card';
}

class AccountTypeOption {
  const AccountTypeOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

const List<AccountTypeOption> accountTypeOptions = [
  AccountTypeOption(
    value: 'checking',
    label: 'Conta corrente',
  ),
  AccountTypeOption(
    value: 'credit_card',
    label: 'Cartão de crédito',
  ),
  AccountTypeOption(
    value: 'investment',
    label: 'Investimento',
  ),
  AccountTypeOption(
    value: 'cash',
    label: 'Dinheiro',
  ),
  AccountTypeOption(
    value: 'wallet',
    label: 'Carteira digital',
  ),
];