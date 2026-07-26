import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/obat_keluarga_logo.dart';
import '../../data/user_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  final String? initialPassword;

  const LoginScreen({
    super.key,
    this.initialEmail,
    this.initialPassword,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final credentials = ref.read(lastRegisteredCredentialsProvider);
    final initialEmail = credentials?.email ?? widget.initialEmail ?? '';
    final initialPassword = credentials?.password ?? widget.initialPassword ?? '';

    _emailController = TextEditingController(text: initialEmail);
    _passwordController = TextEditingController(text: initialPassword);

    if (credentials != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastRegisteredCredentialsProvider.notifier).clear();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEmail != null && widget.initialEmail != oldWidget.initialEmail) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword != null && widget.initialPassword != oldWidget.initialPassword) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Harap isi email dan password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final credential = await authRepo.signInWithEmail(email, password);
      final uid = credential.user?.uid;

      if (uid != null) {
        final userRepo = ref.read(userRepositoryProvider);
        final appUser = await userRepo.getUser(uid);

        if (mounted) {
          if (appUser != null && appUser.circleIds.isNotEmpty) {
            context.go('/dashboard');
          } else {
            context.go('/onboarding');
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Email atau password salah. Silakan coba lagi.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final credential = await authRepo.signInWithGoogle();
      final uid = credential?.user?.uid;

      if (uid != null) {
        final userRepo = ref.read(userRepositoryProvider);
        var appUser = await userRepo.getUser(uid);

        if (appUser == null) {
          final user = credential!.user!;
          await userRepo.createUserDocument(
            uid: uid,
            displayName: user.displayName ?? 'Pengguna Google',
            email: user.email ?? '',
            phoneNumber: user.phoneNumber ?? '',
          );
          appUser = await userRepo.getUser(uid);
        }

        if (mounted) {
          if (appUser != null && appUser.circleIds.isNotEmpty) {
            context.go('/dashboard');
          } else {
            context.go('/onboarding');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal login Google. Pastikan SHA-1 & OAuth telah dikonfigurasi di Firebase Console.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final credential = await authRepo.signInWithFacebook();
      final uid = credential?.user?.uid;

      if (uid != null) {
        final userRepo = ref.read(userRepositoryProvider);
        var appUser = await userRepo.getUser(uid);

        if (appUser == null) {
          final user = credential!.user!;
          await userRepo.createUserDocument(
            uid: uid,
            displayName: user.displayName ?? 'Pengguna Facebook',
            email: user.email ?? '',
            phoneNumber: user.phoneNumber ?? '',
          );
          appUser = await userRepo.getUser(uid);
        }

        if (mounted) {
          if (appUser != null && appUser.circleIds.isNotEmpty) {
            context.go('/dashboard');
          } else {
            context.go('/onboarding');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal login Facebook. Pastikan Facebook App ID telah dikonfigurasi.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Logo Card Resmi
              const Center(
                child: ObatKeluargaLogo(size: 80),
              ),
              const SizedBox(height: 16),
              Text(
                'Obat Keluarga',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Guided wellness for your family\'s health',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 28),

              // White Card Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Field Email
                    const Text(
                      'Email address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'name@example.com',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.mail_outline, color: Colors.grey.shade500, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Field Password & Forgot Password Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Forgot password action
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Login ➔
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider: Or continue with
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Social buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                            label: const Text(
                              'Google',
                              style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleFacebookLogin,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
                            label: const Text(
                              'Facebook',
                              style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Link Don't have an account? Create account
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed('register'),
                      child: const Text(
                        'Create account',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Link Menyiapkan HP untuk pasien? Setup di sini
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Menyiapkan HP untuk pasien? ',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => context.pushNamed('patient-setup-confirm'),
                      child: const Text(
                        'Setup di sini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}