import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_text_field.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authApi,
    required this.onLoginSuccess,
    required this.onGoToRegister,
  });

  final AuthApi authApi;
  final ValueChanged<AppUser> onLoginSuccess;
  final VoidCallback onGoToRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Informe e-mail e senha.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.authApi.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      widget.onLoginSuccess(user);
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
      return 'E-mail ou senha inválidos.';
    }

    return 'Erro ao fazer login.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Center(
                      child: BrandLogo(centered: true),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Bem-vindo ao\nSALVA BOLSO',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 28),
                    SalvaTextField(
                      controller: _emailController,
                      label: 'Endereço de e-mail',
                      hint: 'Endereço de e-mail',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    SalvaTextField(
                      controller: _passwordController,
                      label: 'Senha',
                      hint: 'Senha',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: null,
                        child: Text(
                          'Esqueceu a senha?',
                          style: TextStyle(
                            color: AppColors.seaGreen.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Entrar',
                      icon: Icons.chat_bubble_outline,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _login,
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Não tem uma conta? '),
                        GestureDetector(
                          onTap: _isLoading ? null : widget.onGoToRegister,
                          child: const Text(
                            'Cadastre-se',
                            style: TextStyle(
                              color: AppColors.seaGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}