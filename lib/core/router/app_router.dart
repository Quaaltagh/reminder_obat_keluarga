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
import '../../features/medication/presentation/screens/schedule_screen.dart';

import '../../features/patient/presentation/screens/patient_link_device_screen.dart';
import '../../features/patient/presentation/screens/patient_dashboard_screen.dart';

part 'app_router.g.dart';

/// Provider utama GoRouter. Redirect logic di sini mengikuti diagram alur:
///
/// splash -> cek device_mode lokal
///   -> "patient" -> Simplified Patient Home
///   -> normal    -> cek Firebase Auth
///        -> belum login -> Login/Register
///        -> sudah login -> cek circle membership -> Dashboard atau Onboarding
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
          state.matchedLocation == '/patient-setup-confirm' ||
          state.matchedLocation == '/patient-link-device';
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');
      final isPatientLinkDevice =
          state.matchedLocation == '/patient-link-device';
      final isPatientDashboard =
          state.matchedLocation == '/patient-dashboard';

      // 1. Splash Screen selalu tampil pertama kali tanpa di-override oleh router
      if (isSplash) {
        debugPrint('🔵 Berada di Splash Screen, biarkan timer Splash berjalan');
        return null;
      }

      // 2. Cek Mode HP Pasien lokal (perangkat khusus lansia/pasien)
      final isPatientDevice = ref.read(isPatientModeDeviceProvider).value ?? false;
      if (isPatientDevice) {
        if (!isPatientDashboard) {
          debugPrint('🔵 Mode Pasien Aktif -> Redirect ke /patient-dashboard');
          return '/patient-dashboard';
        }
        return null;
      }

      // 3. Jika sedang di alur setup HP pasien (/patient-link-device), biarkan berjalan
      if (isPatientLinkDevice) {
        return null;
      }

      // 4. Cek status Auth Firebase
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

      final isRegisterRoute = state.matchedLocation == '/register';
      if (isRegisterRoute) {
        debugPrint('🔵 Di halaman register, biarkan alur register selesai');
        return null;
      }

      // 5. Sudah login -> cek circle membership di Firestore
      debugPrint('🔵 Mulai cek circle membership...');
      final appUserAsync = refreshListenable.currentAppUser;

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
        final isPatientDeviceNow = ref.read(isPatientModeDeviceProvider).value ?? false;
        if (isPatientDeviceNow) {
          debugPrint('🔵 Redirect ke /patient-dashboard (Mode Pasien)');
          return '/patient-dashboard';
        }
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
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final password = state.uri.queryParameters['password'];
          final isPatientSetup = state.uri.queryParameters['mode'] == 'patient';
          return LoginScreen(
            initialEmail: email,
            initialPassword: password,
            isPatientSetup: isPatientSetup,
          );
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          final isPatientSetup = state.uri.queryParameters['mode'] == 'patient';
          return RegisterScreen(isPatientSetup: isPatientSetup);
        },
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
      GoRoute(
        path: '/patient-link-device',
        name: 'patient-link-device',
        builder: (context, state) => const PatientLinkDeviceScreen(),
      ),
      GoRoute(
        path: '/patient-dashboard',
        name: 'patient-dashboard',
        builder: (context, state) => const PatientDashboardScreen(),
      ),
      GoRoute(
        path: '/schedule',
        name: 'schedule',
        builder: (context, state) => const ScheduleScreen(),
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

  AsyncValue<AppUser?> _currentAppUser = const AsyncLoading();

  AsyncValue<AppUser?> get currentAppUser => _currentAppUser;

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
    _currentAppUser = const AsyncLoading();

    if (uid != null) {
      _appUserSub = _ref.listen<AsyncValue<AppUser?>>(
        watchAppUserProvider(uid),
        (previous, next) {
          debugPrint('🔵 AppRouterRefreshListenable: watchAppUser state changed '
              '(isLoading: ${next.isLoading}, value: ${next.value?.circleIds})');
          _currentAppUser = next;
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