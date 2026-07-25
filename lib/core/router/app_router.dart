// Konfigurasi go_router.
// TODO: Redirect logic: splash -> cek auth -> cek circle membership -> dashboard.
// Lihat diagram alur navigasi yang sudah didiskusikan untuk referensi lengkap.
// Konfigurasi go_router.
// Redirect logic: splash -> cek device_mode -> cek auth -> cek circle
// membership -> dashboard atau onboarding.
// Konfigurasi go_router.
// Redirect logic: splash -> cek device_mode -> cek auth -> cek circle
// membership -> dashboard atau onboarding.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_choice_screen.dart';
import '../../features/onboarding/presentation/screens/create_circle_screen.dart';
import '../../features/onboarding/presentation/screens/join_circle_screen.dart';
import '../../features/onboarding/presentation/screens/waiting_approval_screen.dart';

part 'app_router.g.dart';

/// Provider utama GoRouter. Redirect logic di sini mengikuti diagram alur:
///
/// splash -> cek device_mode lokal
///   -> "patient" -> Simplified Patient Home (belum diimplementasi, TODO)
///   -> normal    -> cek Firebase Auth
///        -> belum login -> Login/Register
///        -> sudah login -> cek circle membership -> Dashboard atau Onboarding
///
/// Kenapa redirect logic dipusatkan di sini (bukan tersebar di tiap
/// screen)? Supaya ada SATU sumber kebenaran untuk "siapa boleh lihat
/// halaman apa", gampang di-debug dan di-test.
@riverpod
GoRouter appRouter(Ref ref) {
  // PENTING: watch (bukan cuma read di dalam redirect) supaya Riverpod
  // tahu provider ini masih dipakai selama router aktif, dan tidak
  // di-dispose di tengah proses loading. Ini juga membuat GoRouter
  // otomatis re-evaluate redirect setiap kali authState berubah
  // (login/logout) berkat refreshListenable di bawah.
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) async {
      debugPrint('🔵 REDIRECT DIPANGGIL untuk: ${state.matchedLocation}');

      final isSplash = state.matchedLocation == '/splash';
      final isLoginOrRegister = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      // Semua halaman onboarding dikecualikan dari paksaan redirect
      // "circleIds kosong -> /onboarding", supaya user yang SEDANG di
      // tengah proses (isi form create-circle, submit kode invite,
      // atau menunggu approval) tidak terus dilempar balik ke halaman
      // pilihan awal. Tanpa pengecualian ini, begitu user mendarat di
      // /onboarding/create-circle, redirect akan langsung mendeteksi
      // circleIds masih kosong dan memaksa balik ke /onboarding lagi
      // — infinite loop.
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');

      // 1. Cek dulu apakah device ini di-setup sebagai "HP Pasien".
      //    Ini flag LOKAL (SharedPreferences), independen dari status
      //    login akun.
      debugPrint('🔵 Mulai cek isPatientModeDevice...');
      final isPatientDevice =
          await ref.read(isPatientModeDeviceProvider.future);
      debugPrint('🔵 isPatientDevice = $isPatientDevice');

      if (isPatientDevice) {
        // TODO: arahkan ke Simplified Patient Home saat sudah dibuat.
        // Untuk sekarang, tetap ke dashboard biasa supaya tidak dead-end.
        if (isSplash) return '/dashboard';
        return null;
      }

      // 2. Device biasa (Admin/Member) -> cek status login.
      //    Pakai nilai dari `authState` yang sudah di-watch di atas
      //    (AsyncValue), bukan await ulang ke provider yang bisa
      //    ke-dispose saat masih loading.
      final isLoading = authState.isLoading;
      debugPrint('🔵 authState.isLoading = $isLoading');
      if (isLoading) {
        // Masih menunggu Firebase Auth mengirim status pertama kali.
        // Jangan redirect dulu, biarkan splash screen tetap tampil.
        return null;
      }

      // .value bisa throw kalau state error; kita tangani manual
      // supaya tidak crash saat auth stream sempat error.
      User? user;
      try {
        user = authState.value;
      } catch (_) {
        user = null;
      }
      debugPrint('🔵 user = ${user?.uid ?? "null (belum login)"}');
      final isLoggedIn = user != null;

      if (!isLoggedIn) {
        // Belum login: boleh di splash/login/register, selain itu
        // paksa balik ke /login.
        if (isSplash || isLoginOrRegister) {
          debugPrint('🔵 Redirect ke /login');
          return isSplash ? '/login' : null;
        }
        debugPrint('🔵 Redirect ke /login (paksa)');
        return '/login';
      }

      // 3. Sudah login -> cek circle membership.
      //    Dibaca lewat watchAppUserProvider (stream ke Firestore
      //    users/{uid}), di-watch (bukan read/await sekali) supaya
      //    redirect otomatis re-evaluate begitu circleIds berubah
      //    (misal: user baru selesai submit create-circle, provider
      //    ini akan emit ulang dan redirect jalan lagi tanpa perlu
      //    trigger manual dari screen).
      debugPrint('🔵 Mulai cek circle membership...');
      final appUserAsync = ref.watch(watchAppUserProvider(user.uid));

      // Kalau data users/{uid} belum siap (masih loading / error),
      // jangan paksa redirect dulu — biarkan halaman saat ini tetap
      // tampil supaya tidak flicker atau redirect prematur berdasar
      // data yang belum lengkap.
      if (appUserAsync.isLoading) {
        debugPrint('🔵 appUser masih loading, tunda redirect');
        return null;
      }

      // .value bisa throw kalau state error atau belum ada data;
      // ditangani manual dengan try-catch karena Riverpod 3.1.0 di
      // project ini tidak menyediakan .valueOrNull pada AsyncValue
      // yang di-generate (lihat catatan institusional: "Riverpod
      // 3.1.0 API: No .valueOrNull").
      AppUser? appUser;
      try {
        appUser = appUserAsync.value;
      } catch (_) {
        appUser = null;
      }
      final hasCircle = appUser != null && appUser.circleIds.isNotEmpty;
      debugPrint('🔵 hasCircle = $hasCircle '
          '(circleIds: ${appUser?.circleIds})');

      if (!hasCircle) {
        // Belum ikut circle manapun. Kecualikan halaman onboarding
        // sendiri supaya tidak infinite redirect (lihat komentar
        // isOnboardingRoute di atas).
        if (isOnboardingRoute) {
          debugPrint('🔵 Di halaman onboarding, tidak di-redirect');
          return null;
        }
        debugPrint('🔵 Redirect ke /onboarding (belum punya circle)');
        return '/onboarding';
      }

      // Sudah punya circle. Kalau masih di splash/login/register ATAU
      // nyasar ke halaman onboarding (misal buka link lama), arahkan
      // ke dashboard.
      if (isSplash || isLoginOrRegister || isOnboardingRoute) {
        debugPrint('🔵 Redirect ke /dashboard');
        return '/dashboard';
      }

      debugPrint('🔵 Tidak ada redirect, lanjut normal');
      return null; // tidak perlu redirect, biarkan navigasi normal
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding-choice',
        builder: (context, state) => const OnboardingChoiceScreen(),
      ),
      GoRoute(
        path: '/onboarding/create-circle',
        name: 'create-circle',
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/onboarding/join-circle',
        name: 'join-circle',
        builder: (context, state) => const JoinCircleScreen(),
      ),
      GoRoute(
        path: '/onboarding/waiting-approval',
        name: 'waiting-approval',
        builder: (context, state) {
          final circleId = state.uri.queryParameters['circleId'] ?? '';
          return WaitingApprovalScreen(circleId: circleId);
        },
      ),
    ],
  );
}

/// Helper untuk menghubungkan sebuah Stream (authStateChanges) ke
/// Listenable yang dibutuhkan go_router's `refreshListenable`. Setiap
/// kali stream ini emit nilai baru (login/logout), go_router otomatis
/// menjalankan ulang fungsi `redirect` di atas.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}