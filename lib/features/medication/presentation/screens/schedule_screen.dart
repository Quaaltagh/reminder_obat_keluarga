import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../../care_circle/presentation/providers/circle_management_provider.dart';
import '../../../care_circle/presentation/screens/join_requests_screen.dart';
import '../../../patient/data/patient_repository.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../../shared/widgets/app_bottom_nav_bar.dart';

import '../../data/medication_repository.dart';
import '../../domain/medication.dart';
import '../../domain/medication_log.dart';

/// Screen Schedule (Jadwal Medication) — Sesuai Mockup Desain
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({
    super.key,
    this.circleId,
    this.currentUserId,
    this.selectedIndex = 1,
    this.onTabSelected,
  });

  final String? circleId;
  final String? currentUserId;
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
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
    final user = ref.watch(currentUserProvider);
    final activeUserId = widget.currentUserId ?? user?.uid;

    if (activeUserId == null) {
      return const Scaffold(
        backgroundColor: bgSlate,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.circleId != null && widget.circleId!.isNotEmpty) {
      return _buildContent(context, widget.circleId!, activeUserId);
    }

    final appUserAsync = ref.watch(watchAppUserProvider(activeUserId));

    return appUserAsync.when(
      loading: () => const Scaffold(
        backgroundColor: bgSlate,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: bgSlate,
        body: Center(child: Text('Gagal memuat profil: $err')),
      ),
      data: (appUser) {
        if (appUser == null || appUser.circleIds.isEmpty) {
          return const Scaffold(
            backgroundColor: bgSlate,
            body: Center(child: Text('Care Circle tidak ditemukan.')),
          );
        }

        final circleId = appUser.circleIds.first;
        return _buildContent(context, circleId, activeUserId);
      },
    );
  }

  Widget _buildContent(BuildContext context, String circleId, String userId) {
    final patientsAsync = ref.watch(watchActivePatientsInCircleProvider(circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(circleId));

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
                      if (targetTab != null && widget.onTabSelected != null) {
                        widget.onTabSelected!(targetTab);
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: primaryBlue, size: 26),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JoinRequestsScreen(
                                circleId: circleId,
                                adminUserId: userId,
                              ),
                            ),
                          );
                        },
                      ),
                      if ((pendingCountAsync.value ?? 0) > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${pendingCountAsync.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                        _buildDailyLogList(patientId, userId),

                        const SizedBox(height: 16),

                        // Legend Dots Footer
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendItem(color: Color(0xFF22C55E), label: 'Full'),
                            SizedBox(width: 20),
                            _LegendItem(color: Color(0xFF2563EB), label: 'Partial'),
                            SizedBox(width: 20),
                            _LegendItem(color: Color(0xFFEF4444), label: 'Missed'),
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
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: widget.selectedIndex,
        circleId: circleId,
        currentUserId: userId,
        onTabSelected: (index) {
          if (widget.onTabSelected != null) {
            widget.onTabSelected!(index);
            return;
          }
          if (index == 0) {
            context.go('/dashboard');
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
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
              _WeekdayLabel('S'),
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
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

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

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

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

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
