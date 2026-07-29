// Tampilkan kode undangan, tombol share WhatsApp/salin link.

// Layar "Invite" — satu kode circle yang sama dipakai untuk mengundang
// siapa saja (calon Patient MAUPUN calon Caregiver). Layar ini SENGAJA
// tidak bertanya "undang sebagai apa?" — penentuan role/patient
// dilakukan Admin nanti di layar approve join request, bukan di sini.
// (Keputusan desain, lihat CHECKLIST_PROGRESS.md.)
//
// Lokasi: lib/features/care_circle/presentation/screens/invite_screen.dart
//
// Cara membuka (contoh dari CareCircleScreen / Daftar Family):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => InviteScreen(circleId: circle.circleId),
//   ));

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/invite_provider.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _isRegenerating = false;

  Future<void> _handleRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buat Ulang Kode?'),
        content: const Text(
          'Kode lama tidak akan bisa dipakai lagi untuk bergabung. '
          'Pastikan bagikan kode baru ke anggota keluarga yang belum join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Buat Ulang'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRegenerating = true);
    try {
      await ref.read(inviteActionsProvider.notifier).regenerateCode(widget.circleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode baru berhasil dibuat')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat kode baru: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _handleCopy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode disalin ke clipboard')),
    );
  }

  Future<void> _handleShare(String code, String circleName) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Gabung ke Care Circle "$circleName" di aplikasi Care '
            'Reminder. Masukkan kode undangan ini: $code',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(watchCareCircleProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Undang Keluarga')),
      body: circleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat data circle: $error'),
          ),
        ),
        data: (circle) {
          if (circle == null) {
            return const Center(child: Text('Care Circle tidak ditemukan.'));
          }

          final code = circle.inviteCode;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bagikan kode ini ke anggota keluarga',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mereka bisa jadi Pasien baru atau Anggota pendamping — '
                  'kamu yang menentukan setelah mereka meminta bergabung.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: QrImageView(
                      data: code,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Kode 6 digit, besar & mudah dibaca/didikte
                Center(
                  child: Text(
                    _formatCodeForDisplay(code),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // Copy & Share
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleCopy(code),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Salin'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handleShare(code, circle.name),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Bagikan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Regenerate
                TextButton.icon(
                  onPressed: _isRegenerating ? null : _handleRegenerate,
                  icon: _isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _isRegenerating ? 'Membuat kode baru...' : 'Buat Ulang Kode',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Menampilkan "782945" sebagai "782 945" supaya lebih mudah dibaca/diucapkan.
  String _formatCodeForDisplay(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }
}