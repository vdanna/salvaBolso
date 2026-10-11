import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../../../shared/widgets/salva_text_field.dart';
import '../data/account_models.dart';
import '../data/accounts_api.dart';

class AccountFormPage extends StatefulWidget {
  const AccountFormPage({
    super.key,
    required this.accountsApi,
    this.account,
  });

  final AccountsApi accountsApi;
  final FinancialAccount? account;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();

  String _accountType = 'checking';
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    if (account != null) {
      _nameController.text = account.name;
      _institutionController.text = account.institutionName;
      _accountType = account.accountType;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final institutionName = _institutionController.text.trim();

    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Informe um nome com pelo menos 2 caracteres.';
      });
      return;
    }

    if (institutionName.length < 2) {
      setState(() {
        _errorMessage = 'Informe a instituição com pelo menos 2 caracteres.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await widget.accountsApi.updateAccount(
          accountId: widget.account!.id,
          name: name,
          institutionName: institutionName,
          accountType: _accountType,
        );
      } else {
        await widget.accountsApi.createAccount(
          name: name,
          institutionName: institutionName,
          accountType: _accountType,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
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

    if (error.response?.statusCode == 409) {
      return 'Já existe uma conta com esses dados.';
    }

    if (error.response?.statusCode == 401) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    return 'Erro ao salvar conta.';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar conta' : 'Nova conta';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SalvaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cadastre suas contas para importar extratos e montar seus resumos financeiros.',
                  ),
                  const SizedBox(height: 24),
                  SalvaTextField(
                    controller: _nameController,
                    label: 'Nome da conta',
                    hint: 'Ex: Nubank Conta Corrente',
                    icon: Icons.account_balance_wallet_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  SalvaTextField(
                    controller: _institutionController,
                    label: 'Instituição',
                    hint: 'Ex: Nubank',
                    icon: Icons.account_balance_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _accountType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de conta',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: accountTypeOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _accountType = value;
                            });
                          },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    label: _isEditing ? 'Salvar alterações' : 'Criar conta',
                    icon: _isEditing ? Icons.save_outlined : Icons.add,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}