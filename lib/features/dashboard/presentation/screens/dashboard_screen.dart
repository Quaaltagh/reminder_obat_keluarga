import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../../care_circle/presentation/providers/circle_management_provider.dart';
import '../../../care_circle/presentation/screens/invite_screen.dart';
import '../../../care_circle/presentation/screens/join_requests_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

import '../../../patient/data/patient_repository.dart';
import '../../../patient/domain/patient_profile.dart';
import '../../../patient/presentation/screens/add_patient_screen.dart';

import '../../../medication/data/medication_repository.dart';
import '../../../medication/domain/medication.dart';
import '../../../medication/domain/medication_log.dart';
import '../../../medication/presentation/screens/add_medication_screen.dart';

/// Dashboard Utama — Mendukung Tab Home (Admin/Caregiver Input) & Tab Family
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0; // Default: Home tab (index 0)

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final appUserAsync = ref.watch(watchAppUserProvider(user.uid));

    return appUserAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(child: Text('Gagal memuat profil: $error')),
      ),
      data: (appUser) {
        if (appUser == null || appUser.circleIds.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: Text('Circle tidak ditemukan.')),
          );
        }

        final circleId = appUser.circleIds.first;

        // Auto-redirect jika Mode Pasien aktif atau user ini adalah Pasien
        final isPatientDevice = ref.watch(isPatientModeDeviceProvider).value ?? false;
        final activePatientsAsync = ref.watch(watchActivePatientsInCircleProvider(circleId));
        final activePatients = activePatientsAsync.value ?? [];
        final isUserPatient = activePatients.any((p) => p.linkedUserId == user.uid);

        if (isPatientDevice || isUserPatient) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/patient-dashboard');
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0F4C81)),
            ),
          );
        }

        // Verifikasi keanggotaan: Jika user sudah dihapus Admin, bersihkan circleId dan router akan redirect ke /onboarding
        final membersAsync = ref.watch(watchFamilyMembersProvider(circleId));
        if (membersAsync.hasValue) {
          final members = membersAsync.value ?? [];
          final isStillMember = members.any((m) => m.userId == user.uid);
          if (!isStillMember) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(userRepositoryProvider).removeCircleId(user.uid, circleId);
            });
            return const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(child: CircularProgressIndicator()),
            );
          }
        }

        void handleTabSelected(int index) async {
          if (index == 4) {
            final targetTab = await Navigator.push<int?>(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SettingsScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
            if (targetTab != null && mounted) {
              setState(() => _selectedIndex = targetTab);
            }
          } else {
            setState(() => _selectedIndex = index);
          }
        }

        if (_selectedIndex == 1) {
          return _DashboardScheduleContent(
            circleId: circleId,
            currentUserId: user.uid,
            selectedIndex: _selectedIndex,
            onTabSelected: handleTabSelected,
          );
        }

        if (_selectedIndex == 2) {
          return _DashboardFamilyContent(
            circleId: circleId,
            currentUserId: user.uid,
            selectedIndex: _selectedIndex,
            onTabSelected: handleTabSelected,
          );
        }

        return _DashboardHomeContent(
          circleId: circleId,
          currentUserId: user.uid,
          selectedIndex: _selectedIndex,
          onTabSelected: handleTabSelected,
        );
      },
    );
  }
}

/// Content Halaman Home (Dashboard Admin & Caregiver Input Sesuai Mockup Gambar)
class _DashboardHomeContent extends ConsumerStatefulWidget {
  const _DashboardHomeContent({
    required this.circleId,
    required this.currentUserId,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final String circleId;
  final String currentUserId;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  ConsumerState<_DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends ConsumerState<_DashboardHomeContent> {
  String? _selectedPatientId;

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(watchActivePatientsInCircleProvider(widget.circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(widget.circleId));
    final membersAsync = ref.watch(watchFamilyMembersProvider(widget.circleId));
    final isCurrentAdmin = membersAsync.value?.any((m) => m.userId == widget.currentUserId && m.isAdmin) ?? false;
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final targetTab = await Navigator.push<int?>(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      if (targetTab != null && mounted) {
                        widget.onTabSelected(targetTab);
                      }
                    },
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.person, color: primaryBlue, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Obat Keluarga',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrentAdmin)
                    _NotificationBellButton(
                      pendingCount: pendingCountAsync.value ?? 0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinRequestsScreen(
                              circleId: widget.circleId,
                              adminUserId: widget.currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            Expanded(
              child: patientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Gagal memuat profil pasien: $err')),
                data: (patients) {
                  if (patients.isEmpty) {
                    return _buildNoPatientsState(context);
                  }

                  // Auto select first patient if not set
                  if (_selectedPatientId == null ||
                      !patients.any((p) => p.patientId == _selectedPatientId)) {
                    _selectedPatientId = patients.first.patientId;
                  }

                  final selectedPatient = patients.firstWhere(
                    (p) => p.patientId == _selectedPatientId,
                    orElse: () => patients.first,
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(watchActivePatientsInCircleProvider(widget.circleId));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Daily Progress Section (Mockup)
                          _buildDailyProgressSection(context, selectedPatient),

                          const SizedBox(height: 16),

                          // 2. Missed Dose Alert (If Any)
                          _buildMissedDoseAlert(context, selectedPatient),

                          const SizedBox(height: 16),

                          // 3. Care Circle Patient Avatars Carousel
                          _buildPatientCarousel(context, patients, selectedPatient),

                          const SizedBox(height: 20),

                          // 4. Upcoming Today List OR Dynamic Empty State
                          _buildUpcomingTodaySection(context, selectedPatient),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: patientsAsync.maybeWhen(
        data: (patients) {
          if (patients.isEmpty) return null;
          final selectedPatient = patients.firstWhere(
            (p) => p.patientId == _selectedPatientId,
            orElse: () => patients.first,
          );
          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddMedicationScreen(
                    patientId: selectedPatient.patientId,
                    patientName: selectedPatient.name,
                  ),
                ),
              );
              ref.invalidate(watchPatientMedicationsProvider(selectedPatient.patientId));
            },
            backgroundColor: primaryBlue,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          );
        },
        orElse: () => null,
      ),
      bottomNavigationBar: _CustomBottomNavBar(
        selectedIndex: widget.selectedIndex,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }

  /// Empty state jika belum ada pasien di Care Circle
  Widget _buildNoPatientsState(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Pasien di Care Circle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan profil pasien (lansia / anggota keluarga) terlebih dahulu untuk mulai menjadwalkan obat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddPatientScreen(circleId: widget.circleId)),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Pasien Pertama', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Daily Progress Section Card (Mockup Gambar)
  Widget _buildDailyProgressSection(BuildContext context, PatientProfile patient) {
    final todayStr = _getTodayString();
    final medicationsAsync = ref.watch(watchPatientMedicationsProvider(patient.patientId));
    final logsAsync = ref.watch(watchPatientMedicationLogsProvider((
      patientId: patient.patientId,
      dateString: todayStr,
    )));

    const primaryBlue = Color(0xFF0F4C81);

    final meds = medicationsAsync.value ?? [];
    final logs = logsAsync.value ?? [];

    final totalCount = meds.length;
    final takenCount = logs.where((l) => l.status == MedicationStatus.taken).length;
    final percentage = totalCount > 0 ? ((takenCount / totalCount) * 100).round() : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Text Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                // Pill Encouragement Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    totalCount == 0
                        ? '💡 Belum ada jadwal'
                        : (takenCount == totalCount
                            ? '✨ Semua obat diminum'
                            : (takenCount > 0
                                ? '💊 Dalam proses ($takenCount/$totalCount)'
                                : '📊 Pemantauan rutin')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Right Circular Percentage Ring Chart
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: totalCount > 0 ? (takenCount / totalCount) : 0.0,
                    strokeWidth: 7,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Missed Dose Alert Card (Komponen opsional jika ada obat yang terlewat)
  Widget _buildMissedDoseAlert(BuildContext context, PatientProfile patient) {
    final todayStr = _getTodayString();
    final logsAsync = ref.watch(watchPatientMedicationLogsProvider((
      patientId: patient.patientId,
      dateString: todayStr,
    )));

    final logs = logsAsync.value ?? [];
    final missedLogs = logs.where((l) => l.status == MedicationStatus.missed).toList();

    if (missedLogs.isEmpty) return const SizedBox.shrink();

    final firstMissed = missedLogs.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFDC2626), width: 4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Missed Dose',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${firstMissed.medicationName} - ${firstMissed.scheduledTime}',
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF991B1B)),
        ],
      ),
    );
  }

  /// 3. Care Circle Patient Avatars Carousel
  Widget _buildPatientCarousel(
      BuildContext context, List<PatientProfile> patients, PatientProfile selectedPatient) {
    const primaryBlue = Color(0xFF0F4C81);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: patients.length, // Multi-pasien (Add button) ditunda untuk Tahap 3
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                // Catatan: Tombol "+ Add" disembunyikan sementara untuk fokus 1 pasien (MVP Tahap 1)
                final p = patients[index];
                final isSelected = p.patientId == selectedPatient.patientId;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPatientId = p.patientId);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryBlue : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 23,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                            style: TextStyle(
                              color: isSelected ? primaryBlue : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? primaryBlue : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Upcoming Today List / Dynamic Empty State
  Widget _buildUpcomingTodaySection(BuildContext context, PatientProfile patient) {
    final todayStr = _getTodayString();
    final medicationsAsync = ref.watch(watchPatientMedicationsProvider(patient.patientId));
    final logsAsync = ref.watch(watchPatientMedicationLogsProvider((
      patientId: patient.patientId,
      dateString: todayStr,
    )));

    const primaryBlue = Color(0xFF0F4C81);

    final meds = medicationsAsync.value ?? [];
    final logs = logsAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () => widget.onTabSelected(1), // Switch to Schedule tab
              child: const Text(
                'View Schedule',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Dynamic Content: IF NO MEDICATIONS YET -> SHOW EMPTY STATE
        if (meds.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    size: 32,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum Ada Jadwal Obat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Admin belum menambahkan daftar obat untuk ${patient.name}. Tambahkan obat agar pengingat otomatis aktif.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddMedicationScreen(
                          patientId: patient.patientId,
                          patientName: patient.name,
                        ),
                      ),
                    );
                    ref.invalidate(watchPatientMedicationsProvider(patient.patientId));
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Tambah Obat Pertama', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // MEDICATIONS LIST CARDS (Sesuai Mockup)
          Column(
            children: meds.map((med) {
              final log = logs.firstWhere(
                (l) => l.medicationId == med.id,
                orElse: () => MedicationLog(
                  id: '',
                  medicationId: med.id,
                  patientId: patient.patientId,
                  medicationName: med.name,
                  dosage: med.dosage,
                  instruction: med.instruction,
                  scheduledTime: med.scheduledTime,
                  iconType: med.iconType,
                  status: MedicationStatus.scheduled,
                  dateString: todayStr,
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MedicationScheduleCard(
                  medication: med,
                  log: log,
                  onTap: () {
                    if (log.status == MedicationStatus.scheduled) {
                      _showMarkAsTakenDialog(context, patient, med, todayStr);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showMarkAsTakenDialog(
      BuildContext context, PatientProfile patient, Medication med, String todayStr) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Konfirmasi Minum Obat'),
        content: Text('Apakah ${patient.name} sudah meminum ${med.name} (${med.dosage})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final repo = ref.read(medicationRepositoryProvider);
              await repo.markAsTaken(
                patientId: patient.patientId,
                medication: med,
                dateString: todayStr,
                userId: widget.currentUserId,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${med.name} ditandai SUDAH DIMINUM!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81)),
            child: const Text('Sudah Minum', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Card Item Jadwal Obat Sesuai Mockup Gambar
class _MedicationScheduleCard extends StatelessWidget {
  const _MedicationScheduleCard({
    required this.medication,
    required this.log,
    required this.onTap,
  });

  final Medication medication;
  final MedicationLog log;
  final VoidCallback onTap;

  IconData _getIcon(String iconType) {
    switch (iconType) {
      case 'bottle':
        return Icons.local_pharmacy_outlined;
      case 'injection':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.medication_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTaken = log.status == MedicationStatus.taken;
    final isMissed = log.status == MedicationStatus.missed;

    Color accentColor = const Color(0xFF64748B);
    if (isTaken) accentColor = const Color(0xFF0F4C81);
    if (isMissed) accentColor = const Color(0xFFDC2626);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Icon Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getIcon(medication.iconType), color: const Color(0xFF0F4C81), size: 24),
            ),

            const SizedBox(width: 14),

            // Middle Column: Title & Instruction
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medication.dosage} • ${medication.instruction}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right Column: Scheduled Time & Status Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  medication.scheduledTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusBadge(log.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(MedicationStatus status) {
    switch (status) {
      case MedicationStatus.taken:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF0F4C81), size: 20),
            SizedBox(width: 4),
            Text(
              'TAKEN',
              style: TextStyle(
                color: Color(0xFF0F4C81),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case MedicationStatus.missed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 4),
            Text(
              'MISSED',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case MedicationStatus.scheduled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 20),
            SizedBox(width: 4),
            Text(
              'SCHEDULED',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
    }
  }
}

/// Content Halaman Family Circle (Sesuai Gambar 2)
class _DashboardFamilyContent extends ConsumerWidget {
  const _DashboardFamilyContent({
    required this.circleId,
    required this.currentUserId,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final String circleId;
  final String currentUserId;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(watchFamilyMembersProvider(circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(circleId));

    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF0F4C81);

    final members = membersAsync.value ?? [];
    final isCurrentAdmin = members.any((m) => m.userId == currentUserId && m.isAdmin);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final targetTab = await Navigator.push<int?>(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const SettingsScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                      if (targetTab != null && context.mounted) {
                        onTabSelected(targetTab);
                      }
                    },
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.person, color: primaryBlue, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Obat Keluarga',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrentAdmin)
                    _NotificationBellButton(
                      pendingCount: pendingCountAsync.value ?? 0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinRequestsScreen(
                              circleId: circleId,
                              adminUserId: currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(watchFamilyMembersProvider(circleId));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Title Header
                      Text(
                        'Family Circle',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage members and medication access levels.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Outlined Action Button: + Invite New Member (Khusus Admin)
                      if (isCurrentAdmin) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InviteScreen(circleId: circleId),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 22),
                            label: const Text(
                              'Invite New Member',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryBlue,
                              side: const BorderSide(color: primaryBlue, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Members List Cards
                      membersAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Gagal memuat anggota: $e'),
                        ),
                        data: (membersList) {
                          if (membersList.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Belum ada anggota di circle ini.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: membersList.map((member) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _FamilyMemberCard(
                                  member: member,
                                  isSelf: member.userId == currentUserId,
                                  canRemove: isCurrentAdmin && member.userId != currentUserId,
                                  onEditRole: isCurrentAdmin && !member.isAdmin
                                      ? () => _handleEditRole(context, ref, circleId, member)
                                      : null,
                                  onRemove: () => _handleRemoveMember(
                                    context,
                                    ref,
                                    circleId,
                                    currentUserId,
                                    member,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Role Access Information Box
                      const _RoleAccessInformationBox(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CustomBottomNavBar(
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }

  void _handleEditRole(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    FamilyMemberDisplay member,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ubah Peran ${member.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Anggota Input', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Bisa mencatat & menambah obat'),
              leading: Icon(
                Icons.edit_note_rounded,
                color: member.caregiverRole == CaregiverRole.editor ? const Color(0xFF0F4C81) : Colors.grey,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final actions = ref.read(circleManagementActionsProvider.notifier);
                  await actions.updateCaregiverRole(
                    circleId: circleId,
                    userId: member.userId,
                    role: CaregiverRole.editor,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Peran ${member.displayName} berhasil diubah menjadi Anggota Input.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengubah peran: $e')),
                    );
                  }
                }
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('View Only', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Hanya dapat melihat jadwal'),
              leading: Icon(
                Icons.visibility_outlined,
                color: member.caregiverRole == CaregiverRole.viewer ? const Color(0xFF0F4C81) : Colors.grey,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final actions = ref.read(circleManagementActionsProvider.notifier);
                  await actions.updateCaregiverRole(
                    circleId: circleId,
                    userId: member.userId,
                    role: CaregiverRole.viewer,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Peran ${member.displayName} berhasil diubah menjadi View Only.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengubah peran: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleRemoveMember(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String currentUserId,
    FamilyMemberDisplay member,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: Text('Apakah Anda yakin ingin menghapus "${member.displayName}" dari circle ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final actions = ref.read(circleManagementActionsProvider.notifier);
                await actions.removeMember(
                  circleId: circleId,
                  userId: member.userId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${member.displayName} berhasil dihapus dari circle.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus anggota: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.isSelf,
    required this.canRemove,
    this.onEditRole,
    required this.onRemove,
  });

  final FamilyMemberDisplay member;
  final bool isSelf;
  final bool canRemove;
  final VoidCallback? onEditRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.isAdmin;
    final roleLabel = member.roleLabel;
    final initial = member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: Color(0xFF0F4C81),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF0F4C81),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(Kamu)',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onEditRole,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoleBadgePill(roleLabel: roleLabel, isAdmin: isAdmin),
                      if (onEditRole != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (canRemove)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8)),
              onPressed: onRemove,
              tooltip: 'Hapus Anggota',
            ),
        ],
      ),
    );
  }
}

class _RoleBadgePill extends StatelessWidget {
  const _RoleBadgePill({
    required this.roleLabel,
    required this.isAdmin,
  });

  final String roleLabel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0);
    final Color fgColor = isAdmin ? const Color(0xFF1E40AF) : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        roleLabel,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoleAccessInformationBox extends StatelessWidget {
  const _RoleAccessInformationBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 8),
              Text(
                'Role Access Information',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
              children: const [
                TextSpan(
                  text: 'Admins ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can edit schedules and manage members.\n'),
                TextSpan(
                  text: 'Input Members ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can log medication intake and add new medications.\n'),
                TextSpan(
                  text: 'View Only ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can see the schedule but cannot make changes.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF0F4C81),
            size: 26,
          ),
          onPressed: onTap,
        ),
        if (pendingCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Content Halaman Schedule / Jadwal Medication (Sesuai Gambar 2 Mockup)
class _DashboardScheduleContent extends ConsumerStatefulWidget {
  const _DashboardScheduleContent({
    required this.circleId,
    required this.currentUserId,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final String circleId;
  final String currentUserId;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  ConsumerState<_DashboardScheduleContent> createState() =>
      __DashboardScheduleContentState();
}

class __DashboardScheduleContentState
    extends ConsumerState<_DashboardScheduleContent> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  String? _selectedPatientId;

  static const primaryBlue = Color(0xFF0F4C81);
  static const bgSlate = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _getFormattedDateHeader(DateTime date) {
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    final dayName = days[date.weekday % 7];
    final monthName = monthsShort[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(watchActivePatientsInCircleProvider(widget.circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(widget.circleId));
    final membersAsync = ref.watch(watchFamilyMembersProvider(widget.circleId));
    final isCurrentAdmin = membersAsync.value?.any((m) => m.userId == widget.currentUserId && m.isAdmin) ?? false;

    return Scaffold(
      backgroundColor: bgSlate,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final targetTab = await Navigator.push<int?>(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      if (targetTab != null && mounted) {
                        widget.onTabSelected(targetTab);
                      }
                    },
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.person, color: primaryBlue, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Obat Keluarga',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                  ),
                  const Spacer(),
                  if (isCurrentAdmin)
                    _NotificationBellButton(
                      pendingCount: pendingCountAsync.value ?? 0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinRequestsScreen(
                              circleId: widget.circleId,
                              adminUserId: widget.currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // Main Title & Subtitle Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Stay on track with your family wellness',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Body Content (Calendar + Daily Log)
            Expanded(
              child: patientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (patients) {
                  if (patients.isEmpty) {
                    return const Center(
                      child: Text('Belum ada pasien terdaftar di circle ini.'),
                    );
                  }

                  final activePatient = _selectedPatientId != null
                      ? patients.firstWhere(
                          (p) => p.patientId == _selectedPatientId,
                          orElse: () => patients.first,
                        )
                      : patients.first;

                  final patientId = activePatient.patientId;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pasien Selector (jika pasien > 1)
                        if (patients.length > 1) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: patients.map((p) {
                                final isSelected = p.patientId == patientId;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                                  child: ChoiceChip(
                                    label: Text(p.name),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _selectedPatientId = p.patientId;
                                        });
                                      }
                                    },
                                    selectedColor: primaryBlue,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        // Calendar Card Box
                        _buildCalendarCard(patientId),

                        const SizedBox(height: 20),

                        // Daily Log Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Daily Log',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _getFormattedDateHeader(_selectedDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Daily Medication Log List
                        _buildDailyLogList(patientId, widget.currentUserId),

                        const SizedBox(height: 16),

                        // Legend Dots Footer
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDotItem(color: Color(0xFF22C55E), label: 'Full'),
                            SizedBox(width: 20),
                            _LegendDotItem(color: Color(0xFF2563EB), label: 'Partial'),
                            SizedBox(width: 20),
                            _LegendDotItem(color: Color(0xFFEF4444), label: 'Missed'),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CustomBottomNavBar(
        selectedIndex: widget.selectedIndex,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }

  /// Calendar Card Widget matching mockup
  Widget _buildCalendarCard(String patientId) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0 = Sun

    final selectedDateStr = _formatDateString(_selectedDate);
    final logsAsync = ref.watch(
      watchPatientMedicationLogsProvider((
        patientId: patientId,
        dateString: selectedDateStr,
      )),
    );
    final medsAsync = ref.watch(watchPatientMedicationsProvider(patientId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Header with arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getMonthName(month)} $year',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: primaryBlue),
                    onPressed: _previousMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: primaryBlue),
                    onPressed: _nextMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Days of Week Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayLabelItem('S'),
              _WeekdayLabelItem('M'),
              _WeekdayLabelItem('T'),
              _WeekdayLabelItem('W'),
              _WeekdayLabelItem('T'),
              _WeekdayLabelItem('F'),
              _WeekdayLabelItem('S'),
            ],
          ),

          const SizedBox(height: 8),

          // Days Grid (Interactive)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }

              final dayNum = index - firstWeekday + 1;
              final date = DateTime(year, month, dayNum);
              final isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;

              Color? dotColor;
              final meds = medsAsync.value ?? [];

              if (isSelected && meds.isNotEmpty) {
                final logs = logsAsync.value ?? [];
                final takenCount = logs.where((l) => l.status == MedicationStatus.taken).length;
                final missedCount = logs.where((l) => l.status == MedicationStatus.missed).length;

                if (takenCount > 0 && takenCount >= meds.length) {
                  dotColor = const Color(0xFF22C55E); // Green Full
                } else if (takenCount > 0) {
                  dotColor = const Color(0xFF2563EB); // Blue Partial
                } else if (missedCount > 0) {
                  dotColor = const Color(0xFFEF4444); // Red Missed
                }
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? primaryBlue : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      if (dotColor != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Daily Log Medication List for selected date
  Widget _buildDailyLogList(String patientId, String userId) {
    final selectedDateStr = _formatDateString(_selectedDate);

    final medicationsAsync = ref.watch(watchPatientMedicationsProvider(patientId));
    final logsAsync = ref.watch(
      watchPatientMedicationLogsProvider((
        patientId: patientId,
        dateString: selectedDateStr,
      )),
    );

    return medicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Gagal memuat jadwal obat: $err'),
      data: (medications) {
        if (medications.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Belum ada daftar obat untuk pasien ini.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final logs = logsAsync.value ?? [];
        final logMap = {for (var l in logs) l.medicationId: l};

        return Column(
          children: medications.map((med) {
            final log = logMap[med.id];

            MedicationStatus status = MedicationStatus.scheduled;
            String? takenTimeStr;

            if (log != null) {
              status = log.status;
              if (log.takenAt != null) {
                takenTimeStr =
                    '${log.takenAt!.hour.toString().padLeft(2, '0')}:${log.takenAt!.minute.toString().padLeft(2, '0')}';
              }
            }

            return _buildMedicationLogCard(
              context: context,
              patientId: patientId,
              userId: userId,
              medication: med,
              status: status,
              takenTimeStr: takenTimeStr,
              dateString: selectedDateStr,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMedicationLogCard({
    required BuildContext context,
    required String patientId,
    required String userId,
    required Medication medication,
    required MedicationStatus status,
    required String dateString,
    String? takenTimeStr,
  }) {
    Color accentBorderColor;
    Color iconBgColor;
    IconData iconData;
    Widget rightActionWidget;

    switch (status) {
      case MedicationStatus.taken:
        accentBorderColor = const Color(0xFF0284C7);
        iconBgColor = const Color(0xFFE0F2FE);
        iconData = medication.iconType == 'bottle'
            ? Icons.water_drop
            : Icons.medication;
        rightActionWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Taken ${takenTimeStr ?? '08:00'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 24),
          ],
        );
        break;

      case MedicationStatus.missed:
        accentBorderColor = const Color(0xFFEF4444);
        iconBgColor = const Color(0xFFFEE2E2);
        iconData = Icons.medication;
        rightActionWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text(
              'Missed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
            SizedBox(height: 4),
            Icon(Icons.cancel, color: Color(0xFFEF4444), size: 24),
          ],
        );
        break;

      case MedicationStatus.scheduled:
        accentBorderColor = const Color(0xFF94A3B8);
        iconBgColor = const Color(0xFFF1F5F9);
        iconData = medication.iconType == 'bottle'
            ? Icons.medical_information
            : Icons.medication_liquid;
        rightActionWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Upcoming',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () async {
                final repo = ref.read(medicationRepositoryProvider);
                await repo.markAsTaken(
                  patientId: patientId,
                  medication: medication,
                  dateString: dateString,
                  userId: userId,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${medication.name} berhasil ditandai sudah diminum!'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log Now',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentBorderColor, width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: primaryBlue, size: 24),
            ),
            const SizedBox(width: 14),

            // Med Name & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medication.scheduledTime} • ${medication.dosage}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Right Status / Action
            rightActionWidget,
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabelItem extends StatelessWidget {
  const _WeekdayLabelItem(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _LegendDotItem extends StatelessWidget {
  const _LegendDotItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class _CustomBottomNavBar extends StatelessWidget {
  const _CustomBottomNavBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    const activeBluePill = Color(0xFF0F4C81);
    const inactiveIconColor = Color(0xFF334155);
    const inactiveTextColor = Color(0xFF475569);

    final items = [
      const _NavBarItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _NavBarItemData(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Schedule'),
      const _NavBarItemData(icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, label: 'Family'),
      const _NavBarItemData(icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services, label: 'Medicine'),
      const _NavBarItemData(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == selectedIndex;

            return InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? activeBluePill : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : inactiveIconColor,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : inactiveTextColor,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavBarItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}