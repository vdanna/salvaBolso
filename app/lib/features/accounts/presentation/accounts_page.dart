import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../data/account_models.dart';
import '../data/accounts_api.dart';
import 'account_form_page.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({
    super.key,
    required this.accountsApi,
  });

  final AccountsApi accountsApi;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<FinancialAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await widget.accountsApi.getAccounts();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
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

    return 'Erro ao carregar contas.';
  }

  Future<void> _openCreatePage() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountFormPage(
          accountsApi: widget.accountsApi,
        ),
      ),
    );

    if (changed == true) {
      await _loadAccounts();
    }
  }

  Future<void> _openEditPage(FinancialAccount account) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountFormPage(
          accountsApi: widget.accountsApi,
          account: account,
        ),
      ),
    );

    if (changed == true) {
      await _loadAccounts();
    }
  }

  Future<void> _confirmDelete(FinancialAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: Text(
            'Tem certeza que deseja excluir "${account.name}"?\n\n'
            'Se houver transações ligadas a ela, o backend também poderá remover dados relacionados.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteAccount(account);
  }

  Future<void> _deleteAccount(FinancialAccount account) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.accountsApi.deleteAccount(
        accountId: account.id,
      );

      await _loadAccounts();
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Contas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Gerencie suas contas correntes, cartões e carteiras.',
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Nova conta',
              icon: Icons.add,
              onPressed: _openCreatePage,
            ),
            const SizedBox(height: 20),
            if (_isLoading && _accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_errorMessage != null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Tentar novamente',
                      icon: Icons.refresh,
                      onPressed: _loadAccounts,
                    ),
                  ],
                ),
              ),
            if (!_isLoading && _accounts.isEmpty && _errorMessage == null)
              SalvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma conta cadastrada',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crie uma conta corrente e um cartão de crédito para começar a importar seus CSVs.',
                    ),
                  ],
                ),
              ),
            for (final account in _accounts) ...[
              _AccountCard(
                account: account,
                onEdit: () => _openEditPage(account),
                onDelete: () => _confirmDelete(account),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = account.isCreditCard
        ? Icons.credit_card
        : account.isChecking
            ? Icons.account_balance_wallet
            : Icons.savings_outlined;

    return SalvaCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.mint,
            child: Icon(
              icon,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${account.institutionName} • ${account.accountTypeLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              }

              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir'),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}