import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_card.dart';
import '../../accounts/data/account_models.dart';
import '../../accounts/data/accounts_api.dart';
import '../data/import_api.dart';
import '../data/import_models.dart';
import 'import_widgets.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({
    super.key,
    required this.accountsApi,
    required this.importApi,
  });

  final AccountsApi accountsApi;
  final ImportApi importApi;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  CsvImportKind _kind = CsvImportKind.account;
  List<FinancialAccount> _accounts = [];
  FinancialAccount? _selectedAccount;
  XFile? _selectedFile;

  bool _isLoadingAccounts = false;
  bool _isSending = false;
  String? _errorMessage;

  AccountCsvPreview? _accountPreview;
  CreditCardCsvPreview? _creditCardPreview;
  CsvImportResult? _result;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  List<FinancialAccount> get _filteredAccounts {
    return _accounts
        .where((account) => account.accountType == _kind.accountType)
        .toList();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
      _errorMessage = null;
    });

    try {
      final accounts = await widget.accountsApi.getAccounts();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _selectedAccount = _filteredAccounts.isEmpty
            ? null
            : _filteredAccounts.first;
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
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _pickCsv() async {
    const csvTypeGroup = XTypeGroup(
      label: 'Arquivos CSV',
      extensions: ['csv'],
      mimeTypes: [
        'text/csv',
        'application/csv',
        'text/comma-separated-values',
      ],
    );

    final file = await openFile(
      acceptedTypeGroups: [csvTypeGroup],
    );

    if (file == null) {
      return;
    }

    setState(() {
      _selectedFile = file;
      _accountPreview = null;
      _creditCardPreview = null;
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _preview() async {
    final account = _selectedAccount;
    final file = _selectedFile;

    if (account == null) {
      setState(() {
        _errorMessage = 'Selecione uma conta.';
      });
      return;
    }

    if (file == null) {
      setState(() {
        _errorMessage = 'Selecione um arquivo CSV.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      if (_kind == CsvImportKind.account) {
        final preview = await widget.importApi.previewAccountCsv(
          accountId: account.id,
          file: file,
        );

        if (!mounted) return;

        setState(() {
          _accountPreview = preview;
          _creditCardPreview = null;
        });
      } else {
        final preview = await widget.importApi.previewCreditCardCsv(
          accountId: account.id,
          file: file,
        );

        if (!mounted) return;

        setState(() {
          _creditCardPreview = preview;
          _accountPreview = null;
        });
      }
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
        _isSending = false;
      });
    }
  }

  Future<void> _confirmImport() async {
    final account = _selectedAccount;
    final file = _selectedFile;

    if (account == null || file == null) {
      return;
    }

    final hasPreview = _accountPreview != null || _creditCardPreview != null;

    if (!hasPreview) {
      setState(() {
        _errorMessage = 'Gere a prévia antes de importar.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      CsvImportResult result;

      if (_kind == CsvImportKind.account) {
        result = await widget.importApi.importAccountCsv(
          accountId: account.id,
          file: file,
        );
      } else {
        result = await widget.importApi.importCreditCardCsv(
          accountId: account.id,
          file: file,
        );
      }

      if (!mounted) return;

      setState(() {
        _result = result;
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
        _isSending = false;
      });
    }
  }

  void _changeKind(CsvImportKind kind) {
    setState(() {
      _kind = kind;
      _selectedAccount = null;
      _selectedFile = null;
      _accountPreview = null;
      _creditCardPreview = null;
      _result = null;
      _errorMessage = null;
    });

    final filtered = _filteredAccounts;

    if (filtered.isNotEmpty) {
      setState(() {
        _selectedAccount = filtered.first;
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

    if (error.response?.statusCode == 409) {
      return 'Este arquivo já foi importado para esta conta.';
    }

    return 'Erro ao importar CSV.';
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = _filteredAccounts;
    final selectedFile = _selectedFile;
    final hasPreview = _accountPreview != null || _creditCardPreview != null;

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
              'Importar CSV',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Envie seus extratos para o Salva Bolso organizar seus dados.',
            ),
            const SizedBox(height: 20),
            SalvaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de arquivo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<CsvImportKind>(
                    segments: const [
                      ButtonSegment(
                        value: CsvImportKind.account,
                        label: Text('Conta'),
                        icon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      ButtonSegment(
                        value: CsvImportKind.creditCard,
                        label: Text('Cartão'),
                        icon: Icon(Icons.credit_card),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: _isSending
                        ? null
                        : (selected) {
                            _changeKind(selected.first);
                          },
                  ),
                  const SizedBox(height: 18),
                  if (_isLoadingAccounts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (filteredAccounts.isEmpty)
                    Text(
                      _kind == CsvImportKind.account
                          ? 'Cadastre uma conta corrente antes de importar.'
                          : 'Cadastre um cartão de crédito antes de importar.',
                    )
                  else
                    DropdownButtonFormField<FinancialAccount>(
                      value: _selectedAccount,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Conta de destino',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      selectedItemBuilder: (context) {
                        return filteredAccounts.map((account) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${account.name} • ${account.institutionName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: filteredAccounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account,
                              child: Text(
                                '${account.name} • ${account.institutionName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSending
                          ? null
                          : (account) {
                              setState(() {
                                _selectedAccount = account;
                                _accountPreview = null;
                                _creditCardPreview = null;
                                _result = null;
                              });
                            },
                    ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _isSending ? null : _pickCsv,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      selectedFile == null
                          ? 'Selecionar CSV'
                          : selectedFile.name,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Gerar prévia',
                    icon: Icons.visibility_outlined,
                    isLoading: _isSending,
                    onPressed: _isSending ? null : _preview,
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              SalvaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_accountPreview != null) ...[
              const SizedBox(height: 16),
              AccountPreviewCard(preview: _accountPreview!),
            ],
            if (_creditCardPreview != null) ...[
              const SizedBox(height: 16),
              CreditCardPreviewCard(preview: _creditCardPreview!),
            ],
            if (hasPreview && _result == null) ...[
              const SizedBox(height: 16),
              GradientButton(
                label: 'Confirmar importação',
                icon: Icons.cloud_upload_outlined,
                isLoading: _isSending,
                onPressed: _isSending ? null : _confirmImport,
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              ImportResultCard(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}