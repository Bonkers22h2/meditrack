import 'package:flutter/material.dart';
import 'package:meditrack/modals/settings_modal.dart';
import 'package:meditrack/pages/patient_profile.dart';
import 'package:meditrack/pages/reports.dart';
import 'package:meditrack/pages/stocks.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/patient_storage.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/tutorial_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  int _selectedTabIndex = 0;
  final GlobalKey _caregiverTitleShowcaseKey = GlobalKey();
  final GlobalKey _addPatientShowcaseKey = GlobalKey();
  final GlobalKey _patientsListShowcaseKey = GlobalKey();
  final GlobalKey _caregiverRemindersTabShowcaseKey = GlobalKey();
  static const String _takenRemindersStorageKey = 'patient_taken_reminders_v1';
  static const String _deductedRemindersStorageKey =
      'patient_deducted_reminders_v1';
  List<PatientRecord> _patients = <PatientRecord>[];
  List<MedicineRecord> _patientMedicines = <MedicineRecord>[];
  Map<String, int> _reminderCountByPatientId = <String, int>{};
  Set<String> _takenReminderKeys = <String>{};
  Set<String> _deductedReminderKeys = <String>{};
  String? _selectedPatientId;
  DateTime _selectedReminderDate = DateTime.now();
  bool _isLoading = true;

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);
  final Color actionColor = const Color(0xFF6E765D);
  final Color morningColor = const Color(0xFF56BFA8);
  final Color afternoonColor = const Color(0xFFFFB74D);
  final Color nightColor = const Color(0xFF7986CB);

  InputDecoration _patientFieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F8F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: actionColor.withValues(alpha: 0.5)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startCaregiverTutorialIfNeeded();
    });
  }

  Future<void> _startCaregiverTutorialIfNeeded() async {
    final bool hasSeenTutorial = await TutorialPreferences.hasSeen(
      TutorialPreferences.caregiverDashboardTutorialSeenKey,
    );
    if (hasSeenTutorial || !mounted) {
      return;
    }

    await _startCaregiverTutorial(markSeenAfter: true);
  }

  Future<void> _startCaregiverTutorial({bool markSeenAfter = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }

    ShowCaseWidget.of(context).startShowCase(<GlobalKey>[
      _caregiverTitleShowcaseKey,
      _addPatientShowcaseKey,
      _patientsListShowcaseKey,
      _caregiverRemindersTabShowcaseKey,
    ]);

    if (markSeenAfter) {
      await TutorialPreferences.markSeen(
        TutorialPreferences.caregiverDashboardTutorialSeenKey,
      );
    }
  }

  String _patientIdFor(PatientRecord patient) {
    return patient.createdAt.toIso8601String();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait<void>(<Future<void>>[
      _loadPatients(),
      _loadReminderCounts(),
      _loadReminderCompletionState(),
    ]);
  }

  Future<void> _loadReminderCompletionState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> taken =
        prefs.getStringList(_takenRemindersStorageKey) ?? <String>[];
    final List<String> deducted =
        prefs.getStringList(_deductedRemindersStorageKey) ?? <String>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _takenReminderKeys = taken.toSet();
      _deductedReminderKeys = deducted.toSet();
    });
  }

  Future<void> _persistReminderCompletionState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _takenRemindersStorageKey,
      _takenReminderKeys.toList(),
    );
    await prefs.setStringList(
      _deductedRemindersStorageKey,
      _deductedReminderKeys.toList(),
    );
  }

  Future<void> _loadPatients() async {
    final List<PatientRecord> patients = await PatientStorage.loadPatients();
    if (!mounted) {
      return;
    }
    setState(() {
      _patients = patients;
      if (_selectedPatientId == null ||
          !_patients.any(
            (PatientRecord patient) =>
                _patientIdFor(patient) == _selectedPatientId,
          )) {
        _selectedPatientId = patients.isNotEmpty
            ? _patientIdFor(patients.first)
            : null;
      }
      _isLoading = false;
    });
  }

  Future<void> _loadReminderCounts() async {
    final List<MedicineRecord> allRecords =
        await MedicineStorage.loadMedicines();
    final Map<String, int> counts = <String, int>{};
    final List<MedicineRecord> patientMedicines = <MedicineRecord>[];

    for (final MedicineRecord record in allRecords) {
      final String? patientId = record.patientId;
      if (patientId == null || patientId.isEmpty) {
        continue;
      }
      patientMedicines.add(record);
      counts[patientId] = (counts[patientId] ?? 0) + 1;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _reminderCountByPatientId = counts;
      _patientMedicines = patientMedicines;
    });
  }

  Future<void> _showAddPatientDialog() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String fullName = '';
    String ageText = '';
    String relationship = '';
    String emergencyContactNumber = '';

    final PatientRecord? patient = await showDialog<PatientRecord>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          title: const Text('Add Patient'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: _patientFieldDecoration(
                        label: 'Full Name',
                        hint: 'Enter full name',
                        icon: Icons.badge_outlined,
                      ),
                      onChanged: (String value) {
                        fullName = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: _patientFieldDecoration(
                        label: 'Age',
                        hint: 'Enter age',
                        icon: Icons.cake_outlined,
                      ),
                      onChanged: (String value) {
                        ageText = value;
                      },
                      validator: (String? value) {
                        final int? age = int.tryParse((value ?? '').trim());
                        if (age == null || age <= 0) {
                          return 'Enter a valid age';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      textCapitalization: TextCapitalization.words,
                      decoration: _patientFieldDecoration(
                        label: 'Relationship',
                        hint: 'e.g. Parent, Spouse',
                        icon: Icons.people_outline,
                      ),
                      onChanged: (String value) {
                        relationship = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Relationship is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      keyboardType: TextInputType.phone,
                      decoration: _patientFieldDecoration(
                        label: 'Emergency Contact Number',
                        hint: 'Enter contact number',
                        icon: Icons.phone_outlined,
                      ),
                      onChanged: (String value) {
                        emergencyContactNumber = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Emergency contact is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                Navigator.of(context).pop(
                  PatientRecord(
                    fullName: fullName.trim(),
                    age: int.parse(ageText.trim()),
                    relationship: relationship.trim(),
                    emergencyContactNumber: emergencyContactNumber.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (patient == null) {
      return;
    }

    await PatientStorage.addPatient(patient);
    if (!mounted) {
      return;
    }

    setState(() {
      _patients.add(patient);
      if (_selectedPatientId == null) {
        _selectedPatientId = _patientIdFor(patient);
      }
    });
  }

  Future<void> _openPatientProfile(PatientRecord patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PatientProfileScreen(patient: patient),
      ),
    );

    if (!mounted) {
      return;
    }
    await Future.wait<void>(<Future<void>>[
      _loadReminderCounts(),
      _loadReminderCompletionState(),
    ]);
  }

  String? _selectedPatientName() {
    if (_selectedPatientId == null) {
      return null;
    }

    for (final PatientRecord patient in _patients) {
      if (_patientIdFor(patient) == _selectedPatientId) {
        return patient.fullName;
      }
    }

    return null;
  }

  PatientRecord? _patientForId(String patientId) {
    for (final PatientRecord patient in _patients) {
      if (_patientIdFor(patient) == patientId) {
        return patient;
      }
    }
    return null;
  }

  String _dateLabel(DateTime date, DateTime today) {
    if (_isSameDay(date, today)) {
      return 'Today';
    }
    if (_isSameDay(date, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (_isSameDay(date, today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    const List<String> shortWeekdays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final String weekday = shortWeekdays[date.weekday - 1];
    return '$weekday ${date.month}/${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateStorageKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _reminderStorageKey(
    _CaregiverReminderInstance reminder,
    DateTime date,
  ) {
    return '${reminder.medicine.createdAt.toIso8601String()}_${_dateStorageKey(date)}_${reminder.time.hour}_${reminder.time.minute}';
  }

  int _extractDoseCount(String doseAmount) {
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(doseAmount);
    if (match == null) {
      return 1;
    }
    return int.tryParse(match.group(0)!) ?? 1;
  }

  Future<void> _markReminderAsTaken(_CaregiverReminderInstance reminder) async {
    final DateTime today = DateTime.now();
    if (!_isSameDay(_selectedReminderDate, today)) {
      return;
    }

    final String storageKey = _reminderStorageKey(
      reminder,
      _selectedReminderDate,
    );
    if (_takenReminderKeys.contains(storageKey)) {
      await _cancelReminderNotifications(reminder);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _takenReminderKeys.add(storageKey);
    });
    await _persistReminderCompletionState();
    await _cancelReminderNotifications(reminder);

    final int doseCount = _extractDoseCount(reminder.medicine.doseAmount);
    bool deducted = false;
    if (!_deductedReminderKeys.contains(storageKey)) {
      deducted = await StockStorage.deductStockForMedicine(
        medicineName: reminder.medicine.name,
        amount: doseCount,
      );
      if (deducted) {
        if (mounted) {
          setState(() {
            _deductedReminderKeys.add(storageKey);
          });
        } else {
          _deductedReminderKeys.add(storageKey);
        }
      }
    }
    await _persistReminderCompletionState();

    if (!mounted) {
      return;
    }
    final String message = deducted
        ? 'Marked done and deducted $doseCount pill${doseCount == 1 ? '' : 's'} from ${reminder.medicine.name} stock.'
        : 'Reminder marked done.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelReminderNotifications(
    _CaregiverReminderInstance reminder,
  ) async {
    final DateTime scheduledAt = DateTime(
      _selectedReminderDate.year,
      _selectedReminderDate.month,
      _selectedReminderDate.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    await NotificationService.cancelEscalatingReminderAttempts(
      medicineCreatedAtMillis:
          reminder.medicine.createdAt.millisecondsSinceEpoch,
      scheduledAt: scheduledAt,
    ).catchError((_) {});
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

    final String daysText = (match.group(1) ?? '').trim();
    if (daysText.isEmpty) {
      return true;
    }

    const Map<String, int> weekdayByToken = <String, int>{
      'mon': DateTime.monday,
      'monday': DateTime.monday,
      'tue': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'tuesday': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'wednesday': DateTime.wednesday,
      'thu': DateTime.thursday,
      'thur': DateTime.thursday,
      'thurs': DateTime.thursday,
      'thursday': DateTime.thursday,
      'fri': DateTime.friday,
      'friday': DateTime.friday,
      'sat': DateTime.saturday,
      'saturday': DateTime.saturday,
      'sun': DateTime.sunday,
      'sunday': DateTime.sunday,
    };

    final List<String> tokens = daysText
        .split(',')
        .map((String token) => token.trim().toLowerCase())
        .where((String token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return true;
    }

    final Set<int> allowedWeekdays = tokens
        .map((String token) => weekdayByToken[token])
        .whereType<int>()
        .toSet();

    if (allowedWeekdays.isEmpty) {
      return true;
    }

    return allowedWeekdays.contains(day.weekday);
  }

  List<_CaregiverReminderInstance> _expandPatientRemindersForDate(
    DateTime date,
  ) {
    final DateTime selectedDateOnly = DateTime(date.year, date.month, date.day);
    final List<_CaregiverReminderInstance> result =
        <_CaregiverReminderInstance>[];

    for (final MedicineRecord medicine in _patientMedicines) {
      if (medicine.specificTime == null) {
        continue;
      }

      final String? patientId = medicine.patientId;
      if (patientId == null || patientId.isEmpty) {
        continue;
      }

      final PatientRecord? patient = _patientForId(patientId);
      if (patient == null) {
        continue;
      }

      if (!_isScheduledOnWeekday(medicine.frequency, selectedDateOnly)) {
        continue;
      }

      final DateTime? startOnly = medicine.reminderStartDate == null
          ? null
          : DateTime(
              medicine.reminderStartDate!.year,
              medicine.reminderStartDate!.month,
              medicine.reminderStartDate!.day,
            );
      final DateTime? endOnly = medicine.reminderEndDate == null
          ? null
          : DateTime(
              medicine.reminderEndDate!.year,
              medicine.reminderEndDate!.month,
              medicine.reminderEndDate!.day,
            );

      if (startOnly != null || endOnly != null) {
        if (startOnly != null && selectedDateOnly.isBefore(startOnly)) {
          continue;
        }
        if (endOnly != null && selectedDateOnly.isAfter(endOnly)) {
          continue;
        }

        result.add(
          _CaregiverReminderInstance(
            medicine: medicine,
            patient: patient,
            time: TimeOfDay(
              hour: medicine.specificTime!.hour,
              minute: medicine.specificTime!.minute,
            ),
          ),
        );
      } else {
        final DateTime targetDate = DateTime(
          medicine.specificTime!.year,
          medicine.specificTime!.month,
          medicine.specificTime!.day,
        );

        if (_isSameDay(targetDate, selectedDateOnly)) {
          result.add(
            _CaregiverReminderInstance(
              medicine: medicine,
              patient: patient,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      }
    }

    result.sort((a, b) {
      final int timeCompare =
          (a.time.hour * 60 + a.time.minute) -
          (b.time.hour * 60 + b.time.minute);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.patient.fullName.toLowerCase().compareTo(
        b.patient.fullName.toLowerCase(),
      );
    });
    return result;
  }

  Widget _buildReminderDateSelector() {
    final DateTime today = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int index) => today.add(Duration(days: index - 3)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...days.map((DateTime date) {
            final bool isSelected = _isSameDay(date, _selectedReminderDate);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  _dateLabel(date, today),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textDark,
                    fontSize: 14,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF8BBA91),
                backgroundColor: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedReminderDate = date;
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

  Widget _buildCaregiverRemindersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patients.isEmpty) {
      return Center(
        child: Text(
          'Add a patient to view reminders.',
          style: TextStyle(
            color: textFaint,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final List<_CaregiverReminderInstance> reminders =
        _expandPatientRemindersForDate(_selectedReminderDate);
    final Map<String, List<_CaregiverReminderInstance>> grouped =
        <String, List<_CaregiverReminderInstance>>{
          'Morning': <_CaregiverReminderInstance>[],
          'Afternoon': <_CaregiverReminderInstance>[],
          'Night': <_CaregiverReminderInstance>[],
        };

    for (final _CaregiverReminderInstance reminder in reminders) {
      final int hour = reminder.time.hour;
      if (hour >= 5 && hour < 12) {
        grouped['Morning']!.add(reminder);
      } else if (hour >= 12 && hour < 18) {
        grouped['Afternoon']!.add(reminder);
      } else {
        grouped['Night']!.add(reminder);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Image.asset(
              'android/app/src/main/res/assets/icons (1).png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Patient Reminders',
            style: TextStyle(
              color: textDark,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every reminder from every patient appears here by schedule.',
            style: TextStyle(
              color: textFaint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildReminderDateSelector(),
          const SizedBox(height: 12),
          Text(
            '${reminders.length} reminder${reminders.length == 1 ? '' : 's'} found',
            style: TextStyle(
              color: textFaint,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: reminders.isEmpty
                ? Center(
                    child: Text(
                      'No reminders for this day.',
                      style: TextStyle(
                        color: textFaint,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final String period in <String>[
                        'Morning',
                        'Afternoon',
                        'Night',
                      ])
                        if (grouped[period]!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 12,
                              bottom: 8,
                              left: 4,
                            ),
                            child: Text(
                              period,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                          ),
                          ...grouped[period]!.map(
                            (_CaregiverReminderInstance reminder) =>
                                _buildCaregiverReminderCard(reminder),
                          ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _buildReminderSubtitle(MedicineRecord medicine) {
    final String dose = medicine.doseAmount.trim();
    final String frequency = medicine.frequency.trim();
    if (dose.isEmpty && frequency.isEmpty) {
      return 'No dosage details';
    }
    if (dose.isEmpty) {
      return frequency;
    }
    if (frequency.isEmpty) {
      return dose;
    }
    return '$dose • $frequency';
  }

  Widget _buildCaregiverReminderCard(_CaregiverReminderInstance reminder) {
    final int hour = reminder.time.hour;
    final Color periodColor;
    if (hour >= 5 && hour < 12) {
      periodColor = morningColor;
    } else if (hour >= 12 && hour < 18) {
      periodColor = afternoonColor;
    } else {
      periodColor = nightColor;
    }

    final bool isToday = _isSameDay(_selectedReminderDate, DateTime.now());
    final String reminderKey = _reminderStorageKey(
      reminder,
      _selectedReminderDate,
    );
    final bool isChecked = _takenReminderKeys.contains(reminderKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: periodColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
                        MedicineIcons.resolve(reminder.medicine.iconKey),
                        color: const Color(0xFF5C7A58),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      reminder.time.format(context),
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            reminder.medicine.name,
                            style: TextStyle(
                              color: const Color(0xFF355A3A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reminder.patient.fullName,
                              style: TextStyle(
                                color: const Color(0xFF7A4D00),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_buildReminderSubtitle(reminder.medicine)} • ${reminder.patient.relationship}',
                            style: TextStyle(
                              color: textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFF8BBA91)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isChecked
                                ? const Color(0xFF8BBA91)
                                : const Color(0xFFBDBDBD),
                            width: 2.5,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget currentTab = _selectedTabIndex == 0
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: 'Help Center',
                            icon: Icon(
                              Icons.help_outline,
                              color: textLight,
                              size: 24,
                            ),
                            onPressed: _startCaregiverTutorial,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: 'Caregiver options',
                            icon: Icon(
                              Icons.settings_outlined,
                              color: textLight,
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
                const SizedBox(height: 24),
                Showcase(
                  key: _caregiverTitleShowcaseKey,
                  title: 'Caregiver dashboard overview',
                  description:
                      'This is your caregiver home screen for managing patients and reminders.',
                  child: Text(
                    'Caregiver Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor patients and quickly add people you care for.',
                  style: TextStyle(
                    color: textFaint,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Showcase(
                  key: _addPatientShowcaseKey,
                  title: 'Add a new patient',
                  description:
                      'Tap this button to create a patient profile and track their medications.',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddPatientDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add Patient'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
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
                      Icon(Icons.people_outline, color: textDark),
                      const SizedBox(width: 10),
                      Text(
                        '${_patients.length} patient${_patients.length == 1 ? '' : 's'} under care',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Patients',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Showcase(
                  key: _patientsListShowcaseKey,
                  title: 'Patient list',
                  description:
                      'Select a patient card to view details and reminders for that patient.',
                  child: Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _patients.isEmpty
                        ? Center(
                            child: Text(
                              'No patients yet. Tap Add Patient to begin.',
                              style: TextStyle(
                                color: textFaint,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _patients.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final PatientRecord patient = _patients[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openPatientProfile(patient),
                                child: _buildPatientCard(patient),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          )
        : _selectedTabIndex == 1
        ? _buildCaregiverRemindersTab()
        : _selectedTabIndex == 2
        ? const StockScreen()
        : _buildReportsTab();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: currentTab),
      bottomNavigationBar: Showcase(
        key: _caregiverRemindersTabShowcaseKey,
        title: 'Reminders tab',
        description:
            'Open this tab to view and mark reminders from all patients in one place.',
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (int index) {
            setState(() {
              _selectedTabIndex = index;
            });
            if (index == 1) {
              _loadReminderCounts();
              _loadReminderCompletionState();
            }
          },
          backgroundColor: cardColor,
          selectedItemColor: textDark,
          unselectedItemColor: textFaint,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined),
              label: 'Reminders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Stocks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart_outlined),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patients.isEmpty) {
      return Center(
        child: Text(
          'Add a patient to view caregiver reports.',
          style: TextStyle(
            color: textFaint,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final String selectedPatientId =
        _selectedPatientId ?? _patientIdFor(_patients.first);

    final String? selectedPatientName = _selectedPatientName();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Caregiver Reports',
            style: TextStyle(
              color: textDark,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch between patients to review adherence and missed doses.',
            style: TextStyle(
              color: textFaint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: selectedPatientId,
                decoration: const InputDecoration(border: InputBorder.none),
                items: _patients
                    .map(
                      (PatientRecord patient) => DropdownMenuItem<String>(
                        value: _patientIdFor(patient),
                        child: Text(patient.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedPatientId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReportsScreen(
              key: ValueKey<String?>(selectedPatientId),
              patientId: selectedPatientId,
              patientLabel: selectedPatientName,
              takenRemindersStorageKey: 'patient_taken_reminders_v1',
              title: 'Adherence Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(PatientRecord patient) {
    final String patientId = _patientIdFor(patient);
    final int reminderCount = _reminderCountByPatientId[patientId] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EFE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF5C7A58),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                patient.fullName,
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${patient.age} yrs',
                style: TextStyle(
                  color: textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              patient.relationship,
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EFE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$reminderCount reminder${reminderCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: textLight, size: 22),
        ],
      ),
    );
  }
}

class _CaregiverReminderInstance {
  const _CaregiverReminderInstance({
    required this.medicine,
    required this.patient,
    required this.time,
  });

  final MedicineRecord medicine;
  final PatientRecord patient;
  final TimeOfDay time;
}
