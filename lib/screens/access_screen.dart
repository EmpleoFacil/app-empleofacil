import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

enum AccessMode { login, recovery, resetPassword }

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  AccessMode _mode = AccessMode.login;
  
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _rememberSession = false;
  
  String? _recoveryId;
  String? _resetToken;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _switchToLogin() {
    setState(() {
      _mode = AccessMode.login;
      _clearRecoveryState();
    });
  }

  void _switchToRecovery() {
    setState(() {
      _mode = AccessMode.recovery;
    });
  }

  void _clearRecoveryState() {
    _recoveryId = null;
    _resetToken = null;
    for (var controller in _codeControllers) {
      controller.clear();
    }
  }

  Future<void> _login() async {
    if (_identifierController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showError('Ingresa tu teléfono o correo y contraseña');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      identifier: _formatIdentifier(_identifierController.text.trim()),
      password: _passwordController.text,
      rememberSession: _rememberSession,
    );

    if (success && mounted) {
      context.go('/home');
    } else if (authProvider.error != null && mounted) {
      _showError('Teléfono, correo o contraseña incorrectos.');
    }
  }

  Future<void> _sendRecoveryCode() async {
    if (_identifierController.text.trim().isEmpty) {
      _showError('Ingresa tu teléfono o correo');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.recoverAccess(
      _formatIdentifier(_identifierController.text.trim()),
    );

    if (response != null && mounted) {
      setState(() {
        _recoveryId = response['recoveryId'] as String?;
        _resendCountdown = 45;
      });
      _startResendCountdown();
      _showSuccess('Código enviado');
    } else if (authProvider.error != null && mounted) {
      _showError(authProvider.error!);
    }
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 6 || _recoveryId == null) {
      _showError('Ingresa el código de 6 dígitos');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.verifyCode(
      recoveryId: _recoveryId!,
      code: code,
    );

    if (response != null && response['verified'] == true && mounted) {
      setState(() {
        _resetToken = response['resetToken'] as String?;
        _mode = AccessMode.resetPassword;
      });
    } else if (authProvider.error != null && mounted) {
      _showError(authProvider.error!);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.length < 6) {
      _showError('La contraseña debe tener mínimo 6 caracteres');
      return;
    }
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }
    if (_resetToken == null) {
      _showError('Token inválido, intenta de nuevo');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      resetToken: _resetToken!,
      newPassword: _newPasswordController.text,
    );

    if (success && mounted) {
      _showSuccess('Contraseña actualizada. Ya puedes ingresar.');
      _switchToLogin();
    } else if (authProvider.error != null && mounted) {
      _showError(authProvider.error!);
    }
  }

  String _formatIdentifier(String value) {
    if (value.contains('@')) return value;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('505')) return '+$digits';
    return '+505$digits';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/welcome'),
        ),
        title: const Text('Empleo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              const Text(
                'Accede a tu cuenta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Tabs
              _buildTabs(),
              
              const SizedBox(height: 32),
              
              // Contenido según modo
              if (_mode == AccessMode.login) _buildLoginForm(),
              if (_mode == AccessMode.recovery) _buildRecoveryForm(),
              if (_mode == AccessMode.resetPassword) _buildResetPasswordForm(),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _switchToLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == AccessMode.login ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Iniciar sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _mode == AccessMode.login ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _switchToRecovery,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode != AccessMode.login ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Recuperar acceso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _mode != AccessMode.login ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inicia sesión en tu cuenta',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('Teléfono o correo'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: '+505 8888 8888 o ejemplo@correo.com',
            suffixIcon: _buildGBadge(),
          ),
        ),
        
        const SizedBox(height: 20),
        
        _buildLabel('Contraseña'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'contraseña',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                _buildGBadge(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Remember me y Olvidé contraseña
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberSession,
                    onChanged: (v) => setState(() => _rememberSession = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recordarme',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _switchToRecovery,
              child: Text(
                'Olvidé mi contraseña',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Botón Entrar
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecoveryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿No puedes iniciar sesión?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recupera tu acceso en minutos.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 20),
              
              _buildLabel('Teléfono o correo'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identifierController,
                decoration: InputDecoration(
                  hintText: '+505 8888 8888 o ejemplo@correo.com',
                  suffixIcon: _buildGBadge(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botón Enviar código
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _sendRecoveryCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Enviar código'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        if (_recoveryId != null) ...[
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa el código de 6 dígitos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Inputs de código
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextFormField(
                        controller: _codeControllers[index],
                        focusNode: _codeFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _codeFocusNodes[index + 1].requestFocus();
                          }
                          if (_codeControllers.every((c) => c.text.isNotEmpty)) {
                            _verifyCode();
                          }
                        },
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 16),
                
                // Reenviar código
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _resendCountdown > 0 ? null : _sendRecoveryCode,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Reenviar código en 00:${_resendCountdown.toString().padLeft(2, '0')}'
                            : 'Reenviar código',
                        style: TextStyle(
                          color: _resendCountdown > 0 ? AppColors.textSecondary : AppColors.primary,
                        ),
                      ),
                    ),
                    _buildGBadgeSmall(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crear nueva contraseña',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 20),
          
          _buildLabel('Nueva contraseña'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              hintText: 'Mínimo 6 caracteres',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildLabel('Confirmar contraseña'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmNewPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Repite tu contraseña',
            ),
          ),
          
          const SizedBox(height: 24),
          
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Actualizar contraseña'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildGBadge() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('G', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildGBadgeSmall() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
      child: const Center(
        child: Text('G', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
