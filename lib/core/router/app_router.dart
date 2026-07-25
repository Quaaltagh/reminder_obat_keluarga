// Konfigurasi go_router.
// TODO: Redirect logic: splash -> cek auth -> cek circle membership -> dashboard.
// Lihat diagram alur navigasi yang sudah didiskusikan untuk referensi lengkap.
// Konfigurasi go_router.
// Redirect logic: splash -> cek device_mode -> cek auth -> cek circle
// membership -> dashboard atau onboarding.
// Konfigurasi go_router.
// Redirect logic: splash -> cek device_mode -> cek auth -> cek circle
// membership -> dashboard atau onboarding.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/patient_setup_confirm_screen.dart';
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
  final refreshListenable = AppRouterRefreshListenable(ref);
  ref.onDispose(() => refreshListenable.dispose());

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      debugPrint('🔵 REDIRECT DIPANGGIL untuk: ${state.matchedLocation}');

      final isSplash = state.matchedLocation == '/splash';
      final isLoginOrRegister = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/patient-setup-confirm';
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');

      // 1. Cek HP Pasien (flag lokal SharedPreferences)
      final isPatientDevice =
          await ref.read(isPatientModeDeviceProvider.future);
      debugPrint('🔵 isPatientDevice = $isPatientDevice');

      if (isPatientDevice) {
        if (isSplash) return '/dashboard';
        return null;
      }

      // 2. Cek status Auth Firebase
      final authState = ref.read(authStateChangesProvider);
      final isLoading = authState.isLoading;
      debugPrint('🔵 authState.isLoading = $isLoading');
      if (isLoading) {
        return null;
      }

      User? user;
      try {
        user = authState.value;
      } catch (_) {
        user = null;
      }
      debugPrint('🔵 user = ${user?.uid ?? "null (belum login)"}');
      final isLoggedIn = user != null;

      if (!isLoggedIn) {
        if (isSplash || isLoginOrRegister) {
          debugPrint('🔵 Redirect ke /login');
          return isSplash ? '/login' : null;
        }
        debugPrint('🔵 Redirect ke /login (paksa)');
        return '/login';
      }

      // 3. Sudah login -> cek circle membership di Firestore
      debugPrint('🔵 Mulai cek circle membership...');
      final appUserAsync = ref.read(watchAppUserProvider(user.uid));

      if (appUserAsync.isLoading) {
        debugPrint('🔵 appUser masih loading, tunda redirect');
        return null;
      }

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
        if (isOnboardingRoute) {
          debugPrint('🔵 Di halaman onboarding, tidak di-redirect');
          return null;
        }
        debugPrint('🔵 Redirect ke /onboarding (belum punya circle)');
        return '/onboarding';
      }

      if (isSplash || isLoginOrRegister || isOnboardingRoute) {
        debugPrint('🔵 Redirect ke /dashboard');
        return '/dashboard';
      }

      debugPrint('🔵 Tidak ada redirect, lanjut normal');
      return null;
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
      GoRoute(
        path: '/patient-setup-confirm',
        name: 'patient-setup-confirm',
        builder: (context, state) => const PatientSetupConfirmScreen(),
      ),
    ],
  );
}

/// Listenable khusus yang mendengarkan perubahan pada:
/// 1. Status Auth (login / logout)
/// 2. Mode HP Pasien (isPatientModeDevice)
/// 3. Status data user di Firestore (watchAppUserProvider)
///
/// Ketika salah satu data tersebut selesai loading / berubah,
/// `notifyListeners()` dipanggil untuk memicu GoRouter men-evaluate
/// ulang fungsi `redirect` tanpa merebuild instance GoRouter.
class AppRouterRefreshListenable extends ChangeNotifier {
  final Ref _ref;
  ProviderSubscription<AsyncValue<User?>>? _authSub;
  ProviderSubscription<AsyncValue<bool>>? _patientModeSub;
  ProviderSubscription<AsyncValue<AppUser?>>? _appUserSub;

  AppRouterRefreshListenable(this._ref) {
    // Listen status Auth
    _authSub = _ref.listen<AsyncValue<User?>>(
      authStateChangesProvider,
      (previous, next) {
        debugPrint('🔵 AppRouterRefreshListenable: authState berubah -> ${next.value?.uid}');
        _updateAppUserSubscription(next.value?.uid);
        notifyListeners();
      },
      fireImmediately: true,
    );

    // Listen mode HP Pasien
    _patientModeSub = _ref.listen<AsyncValue<bool>>(
      isPatientModeDeviceProvider,
      (previous, next) {
        debugPrint('🔵 AppRouterRefreshListenable: isPatientModeDevice berubah');
        notifyListeners();
      },
    );
  }

  void _updateAppUserSubscription(String? uid) {
    _appUserSub?.close();
    _appUserSub = null;

    if (uid != null) {
      _appUserSub = _ref.listen<AsyncValue<AppUser?>>(
        watchAppUserProvider(uid),
        (previous, next) {
          debugPrint('🔵 AppRouterRefreshListenable: watchAppUser state changed '
              '(isLoading: ${next.isLoading}, value: ${next.value?.circleIds})');
          notifyListeners();
        },
        fireImmediately: true,
      );
    }
  }

  @override
  void dispose() {
    _authSub?.close();
    _patientModeSub?.close();
    _appUserSub?.close();
    super.dispose();
  }
}