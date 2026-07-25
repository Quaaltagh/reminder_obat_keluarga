import 'package:flutter/material.dart';

/// Logo resmi Obat Keluarga: Card putih berisi gambar logo resmi dari assets/images/app_logo.png
class ObatKeluargaLogo extends StatelessWidget {
  final double size;

  const ObatKeluargaLogo({
    super.key,
    this.size = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            final primaryColor = Theme.of(context).colorScheme.primary;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, size: size * 0.45, color: primaryColor),
                SizedBox(height: size * 0.04),
                Text(
                  'Obat Keluarga',
                  style: TextStyle(
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
