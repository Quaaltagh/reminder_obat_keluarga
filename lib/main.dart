import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Wajib dipanggil sebelum ada kode async apa pun (Firebase, dst)
  // yang jalan sebelum runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase menggunakan config hasil `flutterfire configure`.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // ProviderScope wajib membungkus seluruh app supaya semua provider
    // Riverpod di folder features/ bisa diakses di widget tree manapun.
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ambil instance go_router dari provider (didefinisikan di
    // core/router/app_router.dart). Nanti router ini yang menentukan
    // redirect logic: splash -> login/dashboard, dst.
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Obat & Keluarga Care Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}