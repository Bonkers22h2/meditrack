// pages/reports.dart
import 'package:flutter/material.dart';
import 'package:meditrack/modals/settings_modal.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    this.patientId,
    this.patientLabel,
    this.takenRemindersStorageKey = 'taken_reminders_v1',
    this.title = 'Adherence Report',
    this.onHelpPressed,
    this.showTopActions = true,
  });

  final String? patientId;
  final String? patientLabel;
  final String takenRemindersStorageKey;
  final String title;
  final VoidCallback? onHelpPressed;
  final bool showTopActions;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedRangeIndex = 0;
  bool _isLoading = true;
  _ReportSummary _summary = _ReportSummary.empty();

  final List<String> _ranges = const <String>[
    'This Week',
    'Last 7 Days',
    'Last 30 Days',
  ];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.takenRemindersStorageKey != widget.takenRemindersStorageKey) {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<MedicineRecord> medicines =
        await MedicineStorage.loadMedicines();
    final Set<String> takenReminderKeys =
        (prefs.getStringList(widget.takenRemindersStorageKey) ?? <String>[])
            .toSet();

    final List<MedicineRecord> filteredMedicines = medicines
        .where(
          (MedicineRecord record) => widget.patientId == null
              ? record.patientId == null
              : record.patientId == widget.patientId,
        )
        .toList();

    final DateTime now = DateTime.now();
    final DateTimeRange range = _selectedDateRange(now);
    final _ReportSummary summary = _buildSummary(
      medicines: filteredMedicines,
      takenReminderKeys: takenReminderKeys,
      range: range,
      now: now,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  DateTimeRange _selectedDateRange(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime endOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    );
    switch (_selectedRangeIndex) {
      case 0:
        final int weekday = today.weekday;
        final DateTime start = today.subtract(Duration(days: weekday - 1));
        return DateTimeRange(start: start, end: endOfToday);
      case 1:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: endOfToday,
        );
      default:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: endOfToday,
        );
    }
  }

  _ReportSummary _buildSummary({
    required List<MedicineRecord> medicines,
    required Set<String> takenReminderKeys,
    required DateTimeRange range,
    required DateTime now,
  }) {
    final Map<String, _MedicineStatsBuilder> medicineStats =
        <String, _MedicineStatsBuilder>{};

    int onTrack = 0;
    int dueSoon = 0;
    int missed = 0;

    final DateTime startDay = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final DateTime endDay = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );

    DateTime currentDay = startDay;
    while (!currentDay.isAfter(endDay)) {
      final List<_ReminderOccurrence> dayReminders = _expandRemindersForDate(
        medicines,
        currentDay,
      );

      for (final _ReminderOccurrence reminder in dayReminders) {
        final DateTime scheduledAt = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day,
          reminder.time.hour,
          reminder.time.minute,
        );

        if (scheduledAt.isBefore(range.start) ||
            scheduledAt.isAfter(range.end)) {
          continue;
        }

        final String key = _reminderStorageKey(
          medicineCreatedAt: reminder.medicine.createdAt,
          date: currentDay,
          time: reminder.time,
        );

        final _ReminderStatus status;
        if (takenReminderKeys.contains(key)) {
          status = _ReminderStatus.onTrack;
          onTrack += 1;
        } else if (scheduledAt.isAfter(now)) {
          status = _ReminderStatus.dueSoon;
          dueSoon += 1;
        } else {
          status = _ReminderStatus.missed;
          missed += 1;
        }

        final String medicineId = reminder.medicine.createdAt.toIso8601String();
        final _MedicineStatsBuilder builder = medicineStats.putIfAbsent(
          medicineId,
          () => _MedicineStatsBuilder(name: reminder.medicine.name),
        );
        builder.add(status);
      }

      currentDay = currentDay.add(const Duration(days: 1));
    }

    final List<_MedicineBreakdown> breakdown =
        medicineStats.values
            .map((_MedicineStatsBuilder builder) => builder.build())
            .where((_MedicineBreakdown item) => item.total > 0)
            .toList()
          ..sort(
            (_MedicineBreakdown a, _MedicineBreakdown b) =>
                a.adherencePercent == b.adherencePercent
                ? a.name.compareTo(b.name)
                : a.adherencePercent.compareTo(b.adherencePercent),
          );

    final int denominator = onTrack + missed;
    final int adherence = denominator == 0
        ? 0
        : ((onTrack / denominator) * 100).round();

    return _ReportSummary(
      adherencePercent: adherence,
      onTrackCount: onTrack,
      dueSoonCount: dueSoon,
      missedCount: missed,
      breakdown: breakdown,
    );
  }

  List<_ReminderOccurrence> _expandRemindersForDate(
    List<MedicineRecord> medicines,
    DateTime date,
  ) {
    final List<_ReminderOccurrence> result = <_ReminderOccurrence>[];
    final DateTime day = DateTime(date.year, date.month, date.day);
    for (final MedicineRecord medicine in medicines) {
      if (medicine.specificTime == null) {
        continue;
      }

      if (!_isScheduledOnWeekday(medicine.frequency, day)) {
        continue;
      }

      final DateTime? start = medicine.reminderStartDate == null
          ? null
          : DateTime(
              medicine.reminderStartDate!.year,
              medicine.reminderStartDate!.month,
              medicine.reminderStartDate!.day,
            );
      final DateTime? end = medicine.reminderEndDate == null
          ? null
          : DateTime(
              medicine.reminderEndDate!.year,
              medicine.reminderEndDate!.month,
              medicine.reminderEndDate!.day,
            );

      if (start != null || end != null) {
        if ((start == null || !day.isBefore(start)) &&
            (end == null || !day.isAfter(end))) {
          result.add(
            _ReminderOccurrence(
              medicine: medicine,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      } else {
        final DateTime oneOff = DateTime(
          medicine.specificTime!.year,
          medicine.specificTime!.month,
          medicine.specificTime!.day,
        );
        final DateTime day = DateTime(date.year, date.month, date.day);
        if (_isSameDay(oneOff, day)) {
          result.add(
            _ReminderOccurrence(
              medicine: medicine,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      }
    }
    return result;
  }

  bool _isScheduledOnWeekday(String frequency, DateTime day) {
    final RegExp onDaysRegex = RegExp(
      r'^Every \d+(?:\.\d+)? hours on (.+)$',
      caseSensitive: false,
    );
    final Match? match = onDaysRegex.firstMatch(frequency.trim());
    if (match == null) {
      return true;
    }

    final String daysPart = (match.group(1) ?? '').trim();
    if (daysPart.isEmpty) {
      return true;
    }

    const Map<String, int> weekdayMap = <String, int>{
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };

    final Set<int> allowedWeekdays = daysPart
        .split(',')
        .map((String raw) => raw.trim())
        .map((String label) => weekdayMap[label])
        .whereType<int>()
        .toSet();

    if (allowedWeekdays.isEmpty) {
      return true;
    }
    return allowedWeekdays.contains(day.weekday);
  }

  String _dateStorageKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _reminderStorageKey({
    required DateTime medicineCreatedAt,
    required DateTime date,
    required TimeOfDay time,
  }) {
    return '${medicineCreatedAt.toIso8601String()}_${_dateStorageKey(date)}_${time.hour}_${time.minute}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _adherenceMessage(int percent) {
    if (percent >= 90) {
      return 'Excellent consistency. Keep it going.';
    }
    if (percent >= 75) {
      return 'Good job, but room for improvement.';
    }
    if (percent >= 50) {
      return 'You are halfway there. Stay consistent.';
    }
    return 'Needs attention. Try setting tighter reminders.';
  }

  _AdherencePalette _adherencePalette(int percent) {
    if (percent >= 85) {
      return const _AdherencePalette(
        background: Color(0xFFCAD8C8),
        title: Color(0xFF596F57),
        value: Color(0xFF566F55),
        subtitle: Color(0xFF5C6A5A),
      );
    }
    if (percent >= 60) {
      return const _AdherencePalette(
        background: Color(0xFFFFF1BD),
        title: Color(0xFF7A6800),
        value: Color(0xFF6E5E00),
        subtitle: Color(0xFF665B1A),
      );
    }
    return const _AdherencePalette(
      background: Color(0xFFFFD6D6),
      title: Color(0xFF8C2E2E),
      value: Color(0xFF7A2525),
      subtitle: Color(0xFF703030),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFFF4F5F0);
    final Color cardColor = Colors.white;
    final Color textDark = const Color(0xFF1A1A1A);
    final Color textLight = const Color(0xFF8B9084);
    final _AdherencePalette adherencePalette = _adherencePalette(
      _summary.adherencePercent,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if (widget.showTopActions) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Image.asset(
                          'android/app/src/main/res/assets/icons (1).png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: 'Help Center',
                              icon: Icon(
                                Icons.help_outline,
                                color: textDark,
                                size: 24,
                              ),
                              onPressed: widget.onHelpPressed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.settings,
                                color: textDark,
                                size: 24,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (BuildContext context) =>
                                      const SettingsModal(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                ],
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 54 / 2,
                    fontWeight: FontWeight.w500,
                    color: textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.patientLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.patientLabel!,
                    style: TextStyle(
                      fontSize: 15,
                      color: textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List<Widget>.generate(_ranges.length, (
                      int index,
                    ) {
                      final bool selected = _selectedRangeIndex == index;
                      return Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                        child: ChoiceChip(
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedRangeIndex = index;
                            });
                            _loadReportData();
                          },
                          side: const BorderSide(color: Color(0xFFB7BBB3)),
                          backgroundColor: cardColor,
                          selectedColor: const Color(0xFF98BD96),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Color(0xFF415E40),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _ranges[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? const Color(0xFFF4F8F3)
                                      : textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: adherencePalette.background,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Overall Adherence',
                          style: TextStyle(
                            fontSize: 48 / 2,
                            fontWeight: FontWeight.w700,
                            color: adherencePalette.title,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_summary.adherencePercent}%',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w700,
                            color: adherencePalette.value,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _adherenceMessage(_summary.adherencePercent),
                          style: TextStyle(
                            fontSize: 18,
                            color: adherencePalette.subtitle,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LegendItem(
                          color: const Color(0xFF49B04A),
                          label: 'On Track',
                          count: _summary.onTrackCount,
                        ),
                        _LegendItem(
                          color: const Color(0xFFF4BB00),
                          label: 'Due Soon',
                          count: _summary.dueSoonCount,
                        ),
                        _LegendItem(
                          color: const Color(0xFFF44336),
                          label: 'Missed',
                          count: _summary.missedCount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Medication Breakdown',
                    style: TextStyle(
                      fontSize: 48 / 2,
                      fontWeight: FontWeight.w500,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_summary.breakdown.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'No medication reminders found in this range.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5B5E58),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    ..._summary.breakdown.map(
                      (_MedicineBreakdown item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MedicationCard(
                          name: item.name,
                          percentage: item.adherencePercent,
                          segments: [
                            _Segment(
                              widthFactor: item.onTrackRatio,
                              color: const Color(0xFF4CAF50),
                            ),
                            _Segment(
                              widthFactor: item.dueSoonRatio,
                              color: const Color(0xFFF4BB00),
                            ),
                            _Segment(
                              widthFactor: item.missedRatio,
                              color: const Color(0xFFF44336),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6A6E66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.name,
    required this.percentage,
    required this.segments,
  });

  final String name;
  final int percentage;
  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 38 / 2,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2B2E2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: segments
                  .where((_Segment segment) => segment.widthFactor > 0)
                  .map((_Segment segment) {
                    final int flex = (segment.widthFactor * 1000).round();
                    return Expanded(
                      flex: flex == 0 ? 1 : flex,
                      child: Container(height: 18, color: segment.color),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary {
  const _ReportSummary({
    required this.adherencePercent,
    required this.onTrackCount,
    required this.dueSoonCount,
    required this.missedCount,
    required this.breakdown,
  });

  factory _ReportSummary.empty() {
    return const _ReportSummary(
      adherencePercent: 0,
      onTrackCount: 0,
      dueSoonCount: 0,
      missedCount: 0,
      breakdown: <_MedicineBreakdown>[],
    );
  }

  final int adherencePercent;
  final int onTrackCount;
  final int dueSoonCount;
  final int missedCount;
  final List<_MedicineBreakdown> breakdown;
}

class _MedicineBreakdown {
  const _MedicineBreakdown({
    required this.name,
    required this.adherencePercent,
    required this.total,
    required this.onTrackRatio,
    required this.dueSoonRatio,
    required this.missedRatio,
  });

  final String name;
  final int adherencePercent;
  final int total;
  final double onTrackRatio;
  final double dueSoonRatio;
  final double missedRatio;
}

class _MedicineStatsBuilder {
  _MedicineStatsBuilder({required this.name});

  final String name;
  int onTrack = 0;
  int dueSoon = 0;
  int missed = 0;

  void add(_ReminderStatus status) {
    switch (status) {
      case _ReminderStatus.onTrack:
        onTrack += 1;
        break;
      case _ReminderStatus.dueSoon:
        dueSoon += 1;
        break;
      case _ReminderStatus.missed:
        missed += 1;
        break;
    }
  }

  _MedicineBreakdown build() {
    final int total = onTrack + dueSoon + missed;
    if (total == 0) {
      return _MedicineBreakdown(
        name: name,
        adherencePercent: 0,
        total: 0,
        onTrackRatio: 0,
        dueSoonRatio: 0,
        missedRatio: 0,
      );
    }

    final int adherenceDenominator = onTrack + missed;
    final int adherence = adherenceDenominator == 0
        ? 0
        : ((onTrack / adherenceDenominator) * 100).round();

    return _MedicineBreakdown(
      name: name,
      adherencePercent: adherence,
      total: total,
      onTrackRatio: onTrack / total,
      dueSoonRatio: dueSoon / total,
      missedRatio: missed / total,
    );
  }
}

class _ReminderOccurrence {
  const _ReminderOccurrence({required this.medicine, required this.time});

  final MedicineRecord medicine;
  final TimeOfDay time;
}

enum _ReminderStatus { onTrack, dueSoon, missed }

class _Segment {
  const _Segment({required this.widthFactor, required this.color});

  final double widthFactor;
  final Color color;
}

class _AdherencePalette {
  const _AdherencePalette({
    required this.background,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final Color background;
  final Color title;
  final Color value;
  final Color subtitle;
}
