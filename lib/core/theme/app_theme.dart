// Tema Material 3.
// TODO: Kontras tinggi, font besar, sesuai gaya visual di prompt desain Google Stitch.
import 'package:flutter/material.dart';

/// Tema aplikasi. Prinsip desain sesuai NFR usability untuk lansia:
/// - Kontras tinggi
/// - Font lebih besar dari default Material
/// - Touch target besar (tombol tidak boleh terlalu kecil)
class AppTheme {
  AppTheme._(); // Tidak boleh di-instantiate, cuma kumpulan static config.

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D6B), // teal hangat, kesan menenangkan
        brightness: Brightness.light,
      ),
      // Ukuran font dasar dinaikkan dari default Material supaya lebih
      // mudah dibaca lansia. Nanti bisa dipindah ke core/constants/app_sizes.dart
      // saat kita rapikan lebih lanjut.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 18),
        bodyMedium: TextStyle(fontSize: 16),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 52), // touch target lebih besar
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}