// @riverpod authStateChanges, currentUserProvider.
// Dipakai oleh router untuk redirect logic (splash -> login/dashboard).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_provider.g.dart';

/// Stream status login Firebase Auth. Emit setiap kali user login/logout.
/// Dipakai oleh router untuk redirect logic (splash -> login/dashboard).
@riverpod
Stream<User?> authStateChanges(Ref ref) {
  return FirebaseAuth.instance.authStateChanges();
}

/// User yang sedang login saat ini (nilai sinkron, bukan stream).
/// Berguna untuk dipanggil di tempat yang tidak butuh reactive update,
/// misal saat submit form (ambil uid sekali saja).
@riverpod
User? currentUser(Ref ref) {
  return FirebaseAuth.instance.currentUser;
}

/// Repository kecil untuk aksi auth: login, register, logout.
/// Dipisah dari provider di atas supaya UI (login_screen.dart dst)
/// tidak langsung bicara ke FirebaseAuth.instance secara langsung.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

// ============================================================
// DEVICE MODE — properti LOKAL device (HP), bukan properti akun.
// Disimpan di SharedPreferences, bukan Firestore, karena satu akun
// Admin yang sama bisa login normal di HP-nya sendiri, sekaligus
// men-setup HP orang tuanya sebagai "Mode Pasien".
// ============================================================

const _kDeviceModeKey = 'device_mode'; // value: "patient" atau tidak ada (normal)
const _kDevicePatientIdKey = 'device_patient_id'; // patientId yang terhubung ke device ini

/// Mengecek apakah HP ini sudah di-setup sebagai "HP Pasien".
/// Splash screen membaca ini SEBELUM memutuskan mau redirect ke mana.
@riverpod
Future<bool> isPatientModeDevice(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kDeviceModeKey) == 'patient';
}

/// patientId yang terhubung ke device ini (hanya relevan jika
/// isPatientModeDevice == true).
@riverpod
Future<String?> devicePatientId(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kDevicePatientIdKey);
}

/// Helper untuk menandai device ini sebagai "Mode Pasien" setelah
/// Admin selesai mengisi form Create Patient Profile di halaman
/// konfirmasi setup. Dipanggil dari alur "Setup HP Pasien".
class DeviceModeService {
  Future<void> setPatientMode(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceModeKey, 'patient');
    await prefs.setString(_kDevicePatientIdKey, patientId);
  }

  /// Untuk keperluan testing/reset, atau kalau device dialihfungsikan
  /// kembali jadi device biasa.
  Future<void> clearPatientMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeviceModeKey);
    await prefs.remove(_kDevicePatientIdKey);
  }
}

@riverpod
DeviceModeService deviceModeService(Ref ref) {
  return DeviceModeService();
}