import 'package:flutter/material.dart';
import 'package:meditrack/modals/medicine_details_modal.dart';
import 'package:meditrack/modals/medicine_modal.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/patient_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key, required this.patient});

  final PatientRecord patient;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  static const String _takenRemindersStorageKey = 'patient_taken_reminders_v1';

  List<MedicineRecord> _reminders = <MedicineRecord>[];
  Set<String> _takenReminderKeys = <String>{};
  bool _isLoadingReminders = true;
  DateTime _selectedDate = DateTime.now();

  String get _patientId => widget.patient.createdAt.toIso8601String();

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _loadReminderCompletionState();
  }

  Future<void> _loadReminders() async {
    final List<MedicineRecord> reminders =
        (await MedicineStorage.loadMedicines())
            .where((MedicineRecord record) => record.patientId == _patientId)
            .toList()
          ..sort((MedicineRecord a, MedicineRecord b) {
            final DateTime aTime = a.specificTime ?? a.createdAt;
            final DateTime bTime = b.specificTime ?? b.createdAt;
            return aTime.compareTo(bTime);
          });

    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _isLoadingReminders = false;
    });
  }

  Future<void> _openAddReminderModal() async {
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MedicineModal(patientId: _patientId);
      },
    );

    if (didSave == true) {
      await _loadReminders();
    }
  }

  String _dateStorageKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _reminderStorageKey(MedicineRecord reminder, DateTime date) {
    final DateTime reminderTime = reminder.specificTime ?? reminder.createdAt;
    return '${reminder.createdAt.toIso8601String()}_${_dateStorageKey(date)}_${reminderTime.hour}_${reminderTime.minute}';
  }

  Future<void> _loadReminderCompletionState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> taken =
        prefs.getStringList(_takenRemindersStorageKey) ?? <String>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _takenReminderKeys = taken.toSet();
    });
  }

  Future<void> _persistReminderCompletionState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _takenRemindersStorageKey,
      _takenReminderKeys.toList(),
    );
  }

  Future<void> _markReminderAsTaken(MedicineRecord reminder) async {
    final DateTime today = DateTime.now();
    if (!_isSameDay(_selectedDate, today)) {
      return;
    }

    final String reminderKey = _reminderStorageKey(reminder, _selectedDate);
    if (_takenReminderKeys.contains(reminderKey)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _takenReminderKeys.add(reminderKey);
    });
    await _persistReminderCompletionState();

    final DateTime reminderTime = reminder.specificTime ?? reminder.createdAt;
    final DateTime scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    NotificationService.cancelEscalatingReminderAttempts(
      medicineCreatedAtMillis: reminder.createdAt.millisecondsSinceEpoch,
      scheduledAt: scheduledAt,
    ).catchError((_) {});
  }

  Future<void> _openReminderDetails(MedicineRecord reminder) async {
    final bool? didChange = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MedicineDetailsModal(medicine: reminder);
      },
    );

    if (didChange == true) {
      await _loadReminders();
    }
  }

  String _formatReminderTime(BuildContext context, MedicineRecord reminder) {
    if (reminder.specificTime == null) {
      return 'No time';
    }
    return TimeOfDay.fromDateTime(reminder.specificTime!).format(context);
  }

  String _compactFrequency(String frequency) {
    final RegExp regex = RegExp(
      r'^Every (\d+(?:\.\d+)?) hours(?: on .+)?$',
      caseSensitive: false,
    );
    final Match? match = regex.firstMatch(frequency.trim());
    if (match == null) {
      return frequency.trim().isEmpty ? 'Not set' : frequency.trim();
    }
    final String raw = match.group(1)!;
    final double? hours = double.tryParse(raw);
    if (hours == null) {
      return 'Every $raw hrs';
    }
    if (hours == hours.toInt()) {
      return 'Every ${hours.toInt()} hrs';
    }
    return 'Every ${hours.toStringAsFixed(1)} hrs';
  }

  List<MedicineRecord> _expandRemindersForDate(DateTime date) {
    final List<MedicineRecord> result = <MedicineRecord>[];
    final DateTime selectedDateOnly = DateTime(date.year, date.month, date.day);

    for (final MedicineRecord reminder in _reminders) {
      if (reminder.specificTime == null) {
        continue;
      }

      if (!_isScheduledOnWeekday(reminder.frequency, selectedDateOnly)) {
        continue;
      }

      final DateTime? startOnly = reminder.reminderStartDate == null
          ? null
          : DateTime(
              reminder.reminderStartDate!.year,
              reminder.reminderStartDate!.month,
              reminder.reminderStartDate!.day,
            );
      final DateTime? endOnly = reminder.reminderEndDate == null
          ? null
          : DateTime(
              reminder.reminderEndDate!.year,
              reminder.reminderEndDate!.month,
              reminder.reminderEndDate!.day,
            );

      if (startOnly != null || endOnly != null) {
        if (startOnly != null && selectedDateOnly.isBefore(startOnly)) {
          continue;
        }
        if (endOnly != null && selectedDateOnly.isAfter(endOnly)) {
          continue;
        }
        result.add(reminder);
      } else {
        final DateTime targetDate = DateTime(
          reminder.specificTime!.year,
          reminder.specificTime!.month,
          reminder.specificTime!.day,
        );

        if (_isSameDay(targetDate, selectedDateOnly)) {
          result.add(reminder);
        }
      }
    }

    result.sort((MedicineRecord a, MedicineRecord b) {
      final DateTime aTime = a.specificTime!;
      final DateTime bTime = b.specificTime!;
      final int hourCompare = aTime.hour.compareTo(bTime.hour);
      if (hourCompare != 0) {
        return hourCompare;
      }
      return aTime.minute.compareTo(bTime.minute);
    });

    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  String _dateLabel(DateTime date, DateTime today) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );

    if (normalizedDate == normalizedToday) {
      return 'Today';
    }
    if (normalizedDate == normalizedToday.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }
    if (normalizedDate == normalizedToday.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return '${date.month}/${date.day}';
  }

  Widget _buildDateSelector() {
    final DateTime today = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => today.add(Duration(days: i - 3)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...days.map((DateTime date) {
            final bool isSelected = _isSameDay(date, _selectedDate);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  _dateLabel(date, today),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    fontSize: 14,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF8BBA91),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F5F0);
    const Color cardColor = Colors.white;
    const Color textDark = Color(0xFF1A1A1A);
    const Color textLight = Color(0xFF757575);
    final List<MedicineRecord> remindersForSelectedDate =
        _expandRemindersForDate(_selectedDate);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EFE4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF5C7A58),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patient.fullName,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.patient.age} years old',
                            style: const TextStyle(
                              color: textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactInfoItem(
                        icon: Icons.people_outline,
                        label: 'Relationship',
                        value: widget.patient.relationship,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: const Color(0xFFE4E7DF),
                    ),
                    Expanded(
                      child: _CompactInfoItem(
                        icon: Icons.phone_outlined,
                        label: 'Emergency',
                        value: widget.patient.emergencyContactNumber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openAddReminderModal,
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('Add Reminder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E765D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Reminders',
                style: TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _buildDateSelector(),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoadingReminders
                    ? const Center(child: CircularProgressIndicator())
                    : remindersForSelectedDate.isEmpty
                    ? Center(
                        child: Text(
                          _reminders.isEmpty
                              ? 'No reminders yet for this patient.'
                              : 'No reminders for this day.',
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: remindersForSelectedDate.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final MedicineRecord reminder =
                              remindersForSelectedDate[index];
                          final bool isToday = _isSameDay(
                            _selectedDate,
                            DateTime.now(),
                          );
                          final String reminderKey = _reminderStorageKey(
                            reminder,
                            _selectedDate,
                          );
                          final bool isChecked = _takenReminderKeys.contains(
                            reminderKey,
                          );

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openReminderDetails(reminder),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE7EFE4),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        MedicineIcons.resolve(reminder.iconKey),
                                        color: const Color(0xFF5C7A58),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reminder.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: textDark,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_formatReminderTime(context, reminder)} • ${_compactFrequency(reminder.frequency)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: textLight,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: !isChecked
                                          ? () {
                                              if (!isToday) {
                                                return;
                                              }
                                              _markReminderAsTaken(reminder);
                                            }
                                          : null,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: isChecked
                                              ? const Color(0xFF8BBA91)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isChecked
                                                ? const Color(0xFF8BBA91)
                                                : const Color(0xFFBDBDBD),
                                            width: 2.2,
                                          ),
                                        ),
                                        child: isChecked
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: textLight,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactInfoItem extends StatelessWidget {
  const _CompactInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF6E765D)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
