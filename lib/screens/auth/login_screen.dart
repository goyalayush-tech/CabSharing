import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/errors/app_error.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      authProvider.addListener(_onAuthStateChanged);
    });
  }

  @override
  void dispose() {
    final authProvider = context.read<AuthProvider>();
    authProvider.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.isAuthenticated && mounted) {
      context.go('/home');
    }
    
    if (authProvider.error != null && mounted) {
      _showErrorSnackBar(authProvider.error!);
      authProvider.clearError();
    }
  }

  void _showErrorSnackBar(AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getErrorMessage(error)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _signInWithGoogle(),
        ),
      ),
    );
  }

  String _getErrorMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Network error: ${error.message}';
      case ErrorType.auth:
        return 'Sign-in failed: ${error.message}';
      default:
        return 'An error occurred: ${error.message}';
    }
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.directions_car,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to RideLink',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Connect with fellow travelers and share your journey',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return ElevatedButton.icon(
                    onPressed: authProvider.isLoading ? null : _signInWithGoogle,
                    icon: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(authProvider.isLoading ? 'Signing in...' : 'Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}