import 'package:flutter/material.dart';

import '../../../shared/widgets/brand_logo.dart';
import '../../accounts/presentation/accounts_page.dart';
import '../../auth/data/auth_models.dart';
import '../../chat/presentation/chat_home_page.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../imports/presentation/import_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../statements/presentation/statements_page.dart';
import '../../accounts/data/accounts_api.dart';
import '../../imports/data/import_api.dart';
import '../../statements/data/statements_api.dart';
import '../../chat/data/chat_api.dart';
import '../../transactions/data/transactions_api.dart';
import '../../transactions/presentation/transactions_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.user,
    required this.accountsApi,
    required this.importApi,
    required this.statementsApi,
    required this.chatApi,
    required this.transactionsApi,
    required this.dashboardApi,
    required this.onLogout,
  });

  final AppUser user;
  final AccountsApi accountsApi;
  final ImportApi importApi;
  final StatementsApi statementsApi;
  final ChatApi chatApi;
  final TransactionsApi transactionsApi;
  final DashboardApi dashboardApi;
  final Future<void> Function() onLogout;
  

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        user: widget.user,
        dashboardApi: widget.dashboardApi,
      ),
      TransactionsPage(
        transactionsApi: widget.transactionsApi,
      ),
      AccountsPage(
        accountsApi: widget.accountsApi,
      ),
      ImportPage(
        accountsApi: widget.accountsApi,
        importApi: widget.importApi,
      ),
      StatementsPage(
        statementsApi: widget.statementsApi,
      ),
      ChatHomePage(
        chatApi: widget.chatApi,
      ),
      ProfilePage(
        user: widget.user,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(compact: true),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transações',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Contas',
          ),
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file),
            label: 'Importar',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Faturas',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}