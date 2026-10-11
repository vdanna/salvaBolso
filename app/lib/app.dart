import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_models.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/auth/presentation/splash_page.dart';
import 'features/shell/presentation/main_shell_page.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/accounts/data/accounts_api.dart';
import 'features/imports/data/import_api.dart';
import 'features/statements/data/statements_api.dart';
import 'features/chat/data/chat_api.dart';
import 'features/transactions/data/transactions_api.dart';

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  final TokenStorage _tokenStorage = TokenStorage();

  late final ApiClient _apiClient = ApiClient(
    tokenStorage: _tokenStorage,
  );

  late final AuthApi _authApi = AuthApi(
    apiClient: _apiClient,
    tokenStorage: _tokenStorage,
  );

  late final DashboardApi _dashboardApi = DashboardApi(
    apiClient: _apiClient,
  );

  late final AccountsApi _accountsApi = AccountsApi(
    apiClient: _apiClient,
  );

  late final ImportApi _importApi = ImportApi(
    apiClient: _apiClient,
  );

  late final StatementsApi _statementsApi = StatementsApi(
    apiClient: _apiClient,
  );

  late final ChatApi _chatApi = ChatApi(
    apiClient: _apiClient,
  );

  late final TransactionsApi _transactionsApi = TransactionsApi(
    apiClient: _apiClient,
  );

  bool _isCheckingSession = true;
  bool _showRegister = false;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    setState(() {
      _isCheckingSession = true;
    });

    try {
      final hasToken = await _authApi.hasToken();

      if (!hasToken) {
        return;
      }

      final user = await _authApi.me();

      if (!mounted) return;

      setState(() {
        _user = user;
      });
    } catch (_) {
      await _authApi.logout();
    } finally {
      if (!mounted) return;

      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  void _handleLoginSuccess(AppUser user) {
    setState(() {
      _user = user;
      _showRegister = false;
    });
  }

  Future<void> _handleLogout() async {
    await _authApi.logout();

    if (!mounted) return;

    setState(() {
      _user = null;
      _showRegister = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;

    if (_isCheckingSession) {
      home = const SplashPage();
    } else if (_user != null) {
      home = MainShellPage(
        user: _user!,
        accountsApi: _accountsApi,
        importApi: _importApi,
        statementsApi: _statementsApi,
        chatApi: _chatApi,
        transactionsApi: _transactionsApi,
        dashboardApi: _dashboardApi,
        onLogout: _handleLogout,
      );
    } else if (_showRegister) {
      home = RegisterPage(
        authApi: _authApi,
        onRegisterSuccess: _handleLoginSuccess,
        onGoToLogin: () {
          setState(() {
            _showRegister = false;
          });
        },
      );
    } else {
      home = LoginPage(
        authApi: _authApi,
        onLoginSuccess: _handleLoginSuccess,
        onGoToRegister: () {
          setState(() {
            _showRegister = true;
          });
        },
      );
    }

    return MaterialApp(
      title: 'Salva Bolso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}