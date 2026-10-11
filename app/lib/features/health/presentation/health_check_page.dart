import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../data/health_api.dart';

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({
    super.key,
    required this.healthApi,
  });

  final HealthApi healthApi;

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _apiHealth;
  Map<String, dynamic>? _databaseHealth;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiHealth = await widget.healthApi.getHealth();
      final databaseHealth = await widget.healthApi.getDatabaseHealth();

      if (!mounted) return;

      setState(() {
        _apiHealth = apiHealth;
        _databaseHealth = databaseHealth;
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
    if (error.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar à API. Confirme se o backend está rodando em ${AppConfig.apiBaseUrl}.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    return 'Erro na API. Status: $statusCode. Resposta: $data';
  }

  @override
  Widget build(BuildContext context) {
    final apiHealth = _apiHealth;
    final databaseHealth = _databaseHealth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance App'),
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Teste de conexão',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppConfig.apiBaseUrl,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            if (apiHealth != null)
              _StatusCard(
                title: 'API',
                status: apiHealth['status']?.toString() ?? 'desconhecido',
                details: apiHealth.toString(),
              ),
            if (databaseHealth != null)
              _StatusCard(
                title: 'Banco de dados',
                status: databaseHealth['database']?.toString() ?? 'desconhecido',
                details: databaseHealth.toString(),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _checkConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('Testar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.status,
    required this.details,
  });

  final String title;
  final String status;
  final String details;

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'ok' || status == 'connected';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isOk ? Icons.check_circle : Icons.error,
              color: isOk ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Status: $status'),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    style: Theme.of(context).textTheme.bodySmall,
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