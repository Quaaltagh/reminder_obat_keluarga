import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../../medication/data/medication_repository.dart';
import '../../../medication/domain/medication.dart';
import '../../../patient/data/patient_repository.dart';
import '../../../patient/domain/patient_profile.dart';

/// Halaman Pasien / Simple Medication View (Sesuai Gambar 4)
class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  int _currentTab = 0; // 0 = Home, 1 = Riwayat, 2 = Settings

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    const primaryBlue = Color(0xFF0F4C81);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final appUserAsync = ref.watch(watchAppUserProvider(user.uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: appUserAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat data pasien: $e')),
          data: (appUser) {
            final displayName = appUser?.displayName ?? user.email?.split('@').first ?? 'Pasien';
            final circleId = (appUser != null && appUser.circleIds.isNotEmpty)
                ? appUser.circleIds.first
                : null;

            return Column(
              children: [
                // Top App Bar Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: primaryBlue,
                          size: 26,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tidak ada pemberitahuan baru')),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Main Content Body based on selected Tab
                Expanded(
                  child: _currentTab == 0
                      ? _PatientHomeContent(displayName: displayName, circleId: circleId)
                      : (_currentTab == 1
                          ? _PatientHistoryContent(circleId: circleId)
                          : _PatientSettingsContent(
                              displayName: displayName,
                              email: user.email ?? '',
                              circleId: circleId,
                            )),
                ),
              ],
            );
          },
        ),
      ),

      // Patient Mode Simple Bottom Navigation Bar (3 Tabs: Home, Riwayat, Settings)
      bottomNavigationBar: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PatientNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _currentTab == 0,
                onTap: () => setState(() => _currentTab = 0),
              ),
              _PatientNavItem(
                icon: Icons.history_rounded,
                label: 'Riwayat',
                isSelected: _currentTab == 1,
                onTap: () => setState(() => _currentTab = 1),
              ),
              _PatientNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: _currentTab == 2,
                onTap: () => setState(() => _currentTab = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientHomeContent extends ConsumerWidget {
  const _PatientHomeContent({
    required this.displayName,
    required this.circleId,
  });

  final String displayName;
  final String? circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryBlue = Color(0xFF0F4C81);

    if (circleId == null) {
      return _buildEmptyState(context, displayName, 'Belum ada Care Circle terhubung.');
    }

    final activePatientsAsync = ref.watch(watchActivePatientsInCircleProvider(circleId!));

    return activePatientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryBlue)),
      error: (e, _) => _buildEmptyState(context, displayName, 'Gagal memuat data pasien.'),
      data: (patients) {
        if (patients.isEmpty) {
          return _buildEmptyState(context, displayName, 'Admin belum menambahkan profil pasien.');
        }

        final currentUser = ref.watch(currentUserProvider);
        final patient = patients.firstWhere(
          (p) => p.linkedUserId == currentUser?.uid,
          orElse: () => patients.first,
        );

        final medicationsAsync = ref.watch(watchPatientMedicationsProvider(patient.patientId));

        return medicationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: primaryBlue)),
          error: (e, _) => _buildEmptyState(context, patient.name, 'Gagal memuat daftar obat.'),
          data: (medications) {
            if (medications.isEmpty) {
              return _buildEmptyState(context, patient.name, 'Admin belum menambahkan jadwal obat.');
            }

            final totalCount = medications.length;
            final remainingCount = totalCount;
            const double progress = 0.0;
            const int progressPercent = 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Header
                  Text(
                    'Good Morning, ${patient.name}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Soft Blue Card Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'You have ',
                          style: TextStyle(color: Color(0xFF334155), fontSize: 14),
                        ),
                        Text(
                          '$remainingCount doses',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          ' left for today.',
                          style: TextStyle(color: Color(0xFF334155), fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TODAY'S PROGRESS Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'TODAY\'S PROGRESS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '$progressPercent% Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Medication Cards List
                  ...medications.map((med) {
                    final String timeText = med.scheduledTime.isNotEmpty ? med.scheduledTime : '08:00 AM';
                    final String detailText = med.instruction.isNotEmpty
                        ? '${med.dosage} • ${med.instruction}'
                        : med.dosage;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PatientMedicationCard(
                        title: med.name,
                        time: timeText,
                        detail: detailText,
                        icon: Icons.medical_services_rounded,
                        iconBgColor: const Color(0xFFDBEAFE),
                        accentColor: primaryBlue,
                        isTaken: false,
                        isLocked: false,
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Banner Card Image
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C81), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Taking your medicine on time keeps you healthy.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String name, String subtitle) {
    const primaryBlue = Color(0xFF0F4C81);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning, $name',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Text(
              'Belum ada jadwal obat untuk hari ini.',
              style: TextStyle(color: Color(0xFF334155), fontSize: 14),
            ),
          ),

          const SizedBox(height: 32),

          // Clean Empty State Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    size: 38,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Jadwal Obat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin belum menambahkan daftar obat untuk $name.\nSilakan hubungi Admin keluarga Anda untuk menambahkan jadwal obat agar pengingat otomatis aktif.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientMedicationCard extends StatefulWidget {
  const _PatientMedicationCard({
    required this.title,
    required this.time,
    required this.detail,
    required this.icon,
    required this.iconBgColor,
    required this.accentColor,
    required this.isTaken,
    required this.isLocked,
    this.availableTimeText,
  });

  final String title;
  final String time;
  final String detail;
  final IconData icon;
  final Color iconBgColor;
  final Color accentColor;
  final bool isTaken;
  final bool isLocked;
  final String? availableTimeText;

  @override
  State<_PatientMedicationCard> createState() => _PatientMedicationCardState();
}

class _PatientMedicationCardState extends State<_PatientMedicationCard> {
  late bool _taken;

  @override
  void initState() {
    super.initState();
    _taken = widget.isTaken;
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: widget.isLocked
            ? Border.all(color: const Color(0xFFCBD5E1), width: 1.5)
            : Border(left: BorderSide(color: widget.accentColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pill Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Title & Time & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: widget.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          widget.time,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: widget.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: widget.isLocked
                ? ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      disabledBackgroundColor: const Color(0xFFEFF6FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                    label: Text(
                      widget.availableTimeText ?? 'Locked',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                : (_taken
                    ? ElevatedButton.icon(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDCFCE7),
                          disabledBackgroundColor: const Color(0xFFDCFCE7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF15803D)),
                        label: const Text(
                          'Sudah Diminum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _taken = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Obat ${widget.title} berhasil dicatat!'),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: const Text(
                          'Mark as Taken',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}

class _PatientHistoryContent extends ConsumerWidget {
  const _PatientHistoryContent({this.circleId});

  final String? circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryBlue = Color(0xFF0F4C81);

    if (circleId == null) {
      return _buildEmptyHistoryState('Belum ada Care Circle terhubung.');
    }

    final activePatientsAsync = ref.watch(watchActivePatientsInCircleProvider(circleId!));

    return activePatientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryBlue)),
      error: (e, _) => _buildEmptyHistoryState('Gagal memuat data riwayat.'),
      data: (patients) {
        if (patients.isEmpty) {
          return _buildEmptyHistoryState('Belum ada profil pasien.');
        }

        final currentUser = ref.watch(currentUserProvider);
        final patient = patients.firstWhere(
          (p) => p.linkedUserId == currentUser?.uid,
          orElse: () => patients.first,
        );

        final medicationsAsync = ref.watch(watchPatientMedicationsProvider(patient.patientId));

        return medicationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: primaryBlue)),
          error: (e, _) => _buildEmptyHistoryState('Gagal memuat daftar obat.'),
          data: (medications) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header
                  const Text(
                    'Medication History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review the medicines you have already taken.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (medications.isEmpty) ...[
                    _buildEmptyHistoryState('Belum ada riwayat obat yang diminum.'),
                  ] else ...[
                    // Group 1: TODAY Header
                    Row(
                      children: const [
                        Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                        SizedBox(width: 6),
                        Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Today Cards
                    ...medications.take(2).map((med) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildHistoryCard(
                          title: med.name,
                          time: med.scheduledTime.isNotEmpty ? med.scheduledTime : '08:30 AM',
                          isToday: true,
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Group 2: YESTERDAY Header
                    Row(
                      children: const [
                        Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 6),
                        Text(
                          'YESTERDAY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Yesterday Cards
                    ...medications.skip(2).map((med) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildHistoryCard(
                          title: med.name,
                          time: med.scheduledTime.isNotEmpty ? med.scheduledTime : '02:30 PM',
                          isToday: false,
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard({
    required String title,
    required String time,
    required bool isToday,
  }) {
    const primaryBlue = Color(0xFF0F4C81);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday ? Colors.white : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? const Border(
                left: BorderSide(color: primaryBlue, width: 4),
                top: BorderSide(color: Color(0xFFE2E8F0)),
                right: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              )
            : Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Green Checked Badge Icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDCFCE7),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState(String message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medication History',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review the medicines you have already taken.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 38,
                    color: Color(0xFF0F4C81),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Riwayat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSettingsContent extends ConsumerWidget {
  const _PatientSettingsContent({
    required this.displayName,
    required this.email,
    required this.circleId,
  });

  final String displayName;
  final String email;
  final String? circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryBlue = Color(0xFF0F4C81);

    PatientProfile? patient;
    if (circleId != null) {
      final patientsAsync = ref.watch(watchActivePatientsInCircleProvider(circleId!));
      final patients = patientsAsync.value ?? [];
      final currentUser = ref.watch(currentUserProvider);
      if (patients.isNotEmpty) {
        patient = patients.firstWhere(
          (p) => p.linkedUserId == currentUser?.uid,
          orElse: () => patients.first,
        );
      }
    }

    final patientName = patient?.name ?? displayName;
    final ageText = patient?.age != null ? '${patient!.age} Tahun' : '';
    final notes = patient?.healthConditionNotes;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Hero Avatar Card with Verification Badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryBlue, width: 3),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name & Subtitle Info
          Text(
            patientName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          if (ageText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ageText,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Health Conditions Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Kondisi Kesehatan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Health Condition Content (Dynamic based on Admin input)
          if (notes != null && notes.trim().isNotEmpty)
            _buildHealthConditionCard(
              title: notes,
              subtitle: 'Catatan dari Admin Keluarga',
              badgeText: 'Aktif',
              badgeBgColor: const Color(0xFFDBEAFE),
              badgeTextColor: const Color(0xFF1E40AF),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Belum ada catatan kondisi kesehatan dari Admin.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),

          const SizedBox(height: 28),

          // Secondary Button: Sign Out
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                final deviceService = ref.read(deviceModeServiceProvider);
                await deviceService.clearPatientMode();
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHealthConditionCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0F4C81),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientNavItem extends StatelessWidget {
  const _PatientNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeBlue = Color(0xFF0F4C81);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
