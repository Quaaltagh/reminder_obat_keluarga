// Halaman Register: nama, email, password, checkbox persetujuan privasi (UU PDP).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/user_repository.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Password dan konfirmasi tidak sama.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Disimpan di luar try supaya bisa dipakai untuk rollback kalau
    // langkah Firestore gagal setelah akun Auth berhasil dibuat.
    User? createdAuthUser;

    debugPrint('🔵 [REGISTER] Mulai proses registrasi...');

    // PENTING — race condition fix:
    // Begitu authRepo.registerWithEmail() berhasil (di bawah), Firebase
    // Auth langsung emit event lewat authStateChanges. app_router.dart
    // mendeteksi ini dan bisa langsung redirect ke /dashboard SEBELUM
    // baris kode setelah `await` sempat lanjut jalan. Kalau widget ini
    // sudah di-unmount duluan, `ref.read(...)` yang dipanggil SETELAH
    // await tersebut menjadi tidak valid ("ref used after unmounted").
    //
    // Fix: ambil semua provider yang dibutuhkan SEBELUM memanggil
    // registerWithEmail(), supaya tidak ada ref.read() lagi setelah
    // titik yang bisa memicu redirect.
    final authRepo = ref.read(authRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);

    // Juga simpan input form ke variabel lokal sebelum await, supaya
    // tidak bergantung pada widget (controller) yang mungkin sudah
    // di-dispose setelah redirect terjadi.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _nameController.text.trim();
    final phoneNumber =
        _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

    try {
      debugPrint('🔵 [REGISTER] Step 1: Memanggil Firebase Auth...');
      final credential = await authRepo.registerWithEmail(email, password);
      createdAuthUser = credential.user;
      debugPrint('✅ [REGISTER] Step 1 sukses. UID: ${createdAuthUser?.uid}');

      final uid = createdAuthUser?.uid;
      if (uid == null) {
        throw Exception('Registrasi berhasil tapi UID tidak ditemukan.');
      }

      // Simpan dokumen users/{uid} di Firestore. userRepo sudah diambil
      // SEBELUM await di atas, jadi tidak bergantung lagi pada `ref`
      // widget ini masih hidup atau tidak.
      debugPrint('🔵 [REGISTER] Step 2: Menulis dokumen ke Firestore...');
      await userRepo.createUserDocument(
        uid: uid,
        displayName: displayName,
        email: email,
        phoneNumber: phoneNumber,
      );

      debugPrint('✅ [REGISTER] Step 2 sukses. Dokumen users/$uid tersimpan.');

      // Setelah register, redirect logic di app_router.dart otomatis
      // akan mendeteksi user sudah login dan mengarahkan ke langkah
      // berikutnya (nanti: onboarding, karena belum ada circle).
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [REGISTER] FirebaseAuthException di Step 1: '
          '${e.code} — ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = _mapAuthError(e);
        });
      }
    } catch (e, stackTrace) {
      // Akun Auth sudah terlanjur dibuat tapi dokumen Firestore gagal
      // disimpan (misal: koneksi putus, rules menolak, dsb). User jadi
      // bisa login tapi tanpa profil Firestore. Penanganan permanen
      // (retry otomatis / auto-create saat login) akan dikerjakan
      // bersamaan poin 6 (redirect logic circle check).
      debugPrint('🔴 [REGISTER] Gagal di Step 2 (Firestore). '
          'uid=${createdAuthUser?.uid}');
      debugPrint('🔴 [REGISTER] Error: $e');
      debugPrint('🔴 [REGISTER] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Akun dibuat, tapi gagal menyimpan profil. Coba login ulang.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('🔵 [REGISTER] Selesai (finally).');
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login.';
      case 'weak-password':
        return 'Password terlalu lemah (minimal 6 karakter).';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return 'Gagal membuat akun. Periksa kembali data Anda.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(Icons.favorite,
                      size: 36, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Obat Keluarga',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Join our caring community',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Full Name', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Email Address', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Phone Number', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+62 812-3456-7890',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Password', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Create a strong password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Confirm Password',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Repeat your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
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
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('Create Account'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    TextButton(
                      onPressed: () => context.goNamed('login'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'By creating an account, you agree to our Terms of Service '
                'and Privacy Policy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}