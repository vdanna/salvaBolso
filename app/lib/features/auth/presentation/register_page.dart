import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/salva_text_field.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authApi,
    required this.onRegisterSuccess,
    required this.onGoToLogin,
  });

  final AuthApi authApi;
  final ValueChanged<AppUser> onRegisterSuccess;
  final VoidCallback onGoToLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Informe um nome com pelo menos 2 caracteres.';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Informe um e-mail válido.';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'A senha precisa ter pelo menos 8 caracteres.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.authApi.register(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      widget.onRegisterSuccess(user);
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
      return 'Este e-mail já está cadastrado.';
    }

    return 'Erro ao criar conta.';
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                      'Criar conta',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comece a organizar seu dinheiro com o Salva Bolso.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SalvaTextField(
                      controller: _nameController,
                      label: 'Nome',
                      hint: 'Seu nome',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
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
                      hint: 'Mínimo de 8 caracteres',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'Cadastrar',
                      icon: Icons.person_add_alt,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _register,
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Já tem uma conta? '),
                        GestureDetector(
                          onTap: _isLoading ? null : widget.onGoToLogin,
                          child: const Text(
                            'Entrar',
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