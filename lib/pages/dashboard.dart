import 'package:flutter/material.dart';
import 'dart:async';
import 'package:meditrack/modals/medicine_details_modal.dart';
import 'package:meditrack/modals/medicine_modal.dart';
import 'package:meditrack/pages/stocks.dart';
import 'package:meditrack/modals/settings_modal.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/tutorial_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  runApp(const MeditrackApp());
}

class MeditrackApp extends StatelessWidget {
  const MeditrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: const DashboardScreen(),
    );
  }
}

// ---------------------------------------------------------
// DASHBOARD SCREEN (Reminders) - UPDATED WITH TIME COLORS
// ---------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;
  static const String _takenRemindersStorageKey = 'taken_reminders_v1';
  static const String _deductedRemindersStorageKey = 'deducted_reminders_v1';

  final GlobalKey _titleShowcaseKey = GlobalKey();
  final GlobalKey _dateSelectorShowcaseKey = GlobalKey();
  final GlobalKey _addReminderShowcaseKey = GlobalKey();
  final GlobalKey _stockShowcaseKey = GlobalKey();

  List<MedicineRecord> _medicines = <MedicineRecord>[];
  Set<String> _takenReminderKeys = <String>{};
  Set<String> _deductedReminderKeys = <String>{};
  int _stockCount = 0;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // Color palette
  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color textDark = const Color(0xFF1A1A1A); // High contrast black
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);

  // New High-Contrast Subtitle color (Fixing the greyed out text issue)
  final Color textAccessibleSubtitle = const Color(0xFF616161);

  // Time of Day Colors
  final Color morningColor = const Color(0xFF56BFA8); // Teal from image
  final Color afternoonColor = const Color(0xFFFFB74D); // Warm Orange
  final Color nightColor = const Color(0xFF7986CB); // Indigo

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _loadStocks();
    _loadReminderCompletionState();
    startDashboardTutorialIfNeeded(
      context: context,
      isMounted: () => mounted,
      steps: buildDashboardTutorialSteps(
        titleShowcaseKey: _titleShowcaseKey,
        dateSelectorShowcaseKey: _dateSelectorShowcaseKey,
        addReminderShowcaseKey: _addReminderShowcaseKey,
        stockShowcaseKey: _stockShowcaseKey,
      ),
    );
  }

  Future<void> _openHelpSectionsPopup() async {
    final DashboardHelpSection? selectedSection = await showDashboardHelpSectionsPopup(
      context: context,
      textDark: textDark,
      textLight: textLight,
      textFaint: textFaint,
    );

    if (selectedSection != null) {
      switch (selectedSection) {
        case DashboardHelpSection.dashboardOverview:
          await startDashboardTutorial(
            context: context,
            isMounted: () => mounted,
            steps: buildDashboardTutorialSteps(
              titleShowcaseKey: _titleShowcaseKey,
              dateSelectorShowcaseKey: _dateSelectorShowcaseKey,
              addReminderShowcaseKey: _addReminderShowcaseKey,
              stockShowcaseKey: _stockShowcaseKey,
            ),
          );
          break;
        case DashboardHelpSection.addSchedule:
          _openMedicineModal(startScheduleTutorial: true);
          break;
        case DashboardHelpSection.manageStocks:
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const StockScreen(
                startTutorial: true,
              ),
            ),
          ).then((_) => _loadStocks());
          break;
      }
    }
  }

  Future<void> _openSettingsMenu() async {
    final bool? resetTutorials = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restart_alt, color: textLight),
                  title: Text(
                    'Reset Tutorials',
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Show all first-time tutorials again. Requires app restart.',
                    style: TextStyle(color: textFaint),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (resetTutorials != true || !mounted) {
      return;
    }

    await TutorialPreferences.resetAllSeen();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tutorials have been reset.')),
      );
  }

  Future<void> _loadMedicines() async {
    final List<MedicineRecord> medicines =
        await MedicineStorage.loadMedicines();
    if (!mounted) {
      return;
    }

    setState(() {
      _medicines = medicines.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> _loadStocks() async {
    final List<StockRecord> stocks = await StockStorage.loadStocks();
    if (!mounted) {
      return;
    }

    setState(() {
      _stockCount = stocks.length;
    });
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

  String _dateStorageKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _reminderStorageKey(_ReminderInstance reminder, DateTime date) {
    return '${reminder.medicine.createdAt.toIso8601String()}_${_dateStorageKey(date)}_${reminder.time.hour}_${reminder.time.minute}';
  }

  int _extractDoseCount(String doseAmount) {
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(doseAmount);
    if (match == null) {
      return 1;
    }
    return int.tryParse(match.group(0)!) ?? 1;
  }

  Future<void> _markReminderAsTaken(_ReminderInstance reminder) async {
    final DateTime today = DateTime.now();
    if (!_isSameDay(_selectedDate, today)) {
      return;
    }

    final String storageKey = _reminderStorageKey(reminder, _selectedDate);
    if (_takenReminderKeys.contains(storageKey)) {
      return;
    }

    setState(() {
      _takenReminderKeys.add(storageKey);
    });

    await _persistReminderCompletionState();

    final DateTime scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    NotificationService.cancelEscalatingReminderAttempts(
      medicineCreatedAtMillis:
          reminder.medicine.createdAt.millisecondsSinceEpoch,
      scheduledAt: scheduledAt,
    ).catchError((_) {});

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
        unawaited(_loadStocks());
      }
    }

    await _persistReminderCompletionState();

    if (!mounted) {
      return;
    }

    final String message = deducted
        ? 'Deducted $doseCount pill${doseCount == 1 ? '' : 's'} from ${reminder.medicine.name} stock.'
        : 'Reminder marked done.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMedicineModal({bool startScheduleTutorial = false}) async {
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => MedicineModal(
        startScheduleTutorial: startScheduleTutorial,
      ),
    );

    if (didSave == true) {
      await _loadMedicines();
    }
  }

  Future<void> _openMedicineDetailsModal(MedicineRecord medicine) async {
    final bool? didChange = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MedicineDetailsModal(medicine: medicine);
      },
    );

    if (didChange == true) {
      await _loadMedicines();
    }
  }

  String _buildSubtitle(MedicineRecord medicine) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _selectedTabIndex == 0
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // 1. Top Bar (Logo + Settings)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny_outlined,
                              color: textFaint,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Meditrack',
                              style: TextStyle(
                                color: textFaint,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
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
                    const SizedBox(height: 22),
                    // 2. Title and Schedule Medication button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Reminders',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openMedicineModal,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Schedule Medication',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: textDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Date selector row
                    _buildDateSelector(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '$_stockCount stock item${_stockCount == 1 ? '' : 's'} tracked',
                          style: TextStyle(
                            color: textFaint,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Text(
                          '${_medicines.length} reminder${_medicines.length == 1 ? '' : 's'} saved',
                          style: TextStyle(
                            color: textFaint,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildRemindersForSelectedDate(),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              )
            : const StockScreen(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (int index) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 1) _loadStocks();
          });
        },
        backgroundColor: cardColor,
        selectedItemColor: textDark,
        unselectedItemColor: textFaint,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Reminders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Stocks',
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final DateTime today = DateTime.now();
    final List<DateTime> days = List.generate(
      7,
      (i) => today.add(Duration(days: i - 3)),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...days.map((date) {
            final bool isSelected = _isSameDay(date, _selectedDate);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  _dateLabel(date, today),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textDark,
                    fontSize: 15,
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

  Widget _buildRemindersForSelectedDate() {
    final List<_ReminderInstance> reminders = _expandRemindersForDate(
      _selectedDate,
    );
    if (reminders.isEmpty) {
      return Center(
        child: Text(
          'No reminders for this day',
          style: TextStyle(
            color: textFaint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final Map<String, List<_ReminderInstance>> grouped = {
      'Morning': [],
      'Afternoon': [],
      'Night': [],
    };
    for (final r in reminders) {
      final int hour = r.time.hour;
      if (hour >= 5 && hour < 12) {
        grouped['Morning']!.add(r);
      } else if (hour >= 12 && hour < 18) {
        grouped['Afternoon']!.add(r);
      } else {
        grouped['Night']!.add(r);
      }
    }
    for (final group in grouped.values) {
      group.sort((a, b) => a.time.compareTo(b.time));
    }

    return ListView(
      children: [
        for (final period in ['Morning', 'Afternoon', 'Night'])
          if (grouped[period]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            ...grouped[period]!.map((reminder) => _buildReminderCard(reminder)),
          ],
      ],
    );
  }

  Widget _buildReminderCard(_ReminderInstance reminder) {
    final medicine = reminder.medicine;
    final bool isToday = _isSameDay(_selectedDate, DateTime.now());
    final String reminderKey = _reminderStorageKey(reminder, _selectedDate);
    final bool isChecked = _takenReminderKeys.contains(reminderKey);

    // Determine period colors based on the time
    Color periodColor;
    final int hour = reminder.time.hour;
    if (hour >= 5 && hour < 12) {
      periodColor = morningColor;
    } else if (hour >= 12 && hour < 18) {
      periodColor = afternoonColor;
    } else {
      periodColor = nightColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openMedicineDetailsModal(medicine),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NEW: Colored Left Border Indicator
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

                // Card Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Medicine Icon
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EFE4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            MedicineIcons.resolve(medicine.iconKey),
                            color: const Color(0xFF5C7A58),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Time
                        Text(
                          reminder.time.format(context),
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Text Information (Name & Accessible Subtitle)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                medicine.name,
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _buildSubtitle(medicine),
                                style: TextStyle(
                                  // NEW: Fixed grey text issue - highly readable dark grey
                                  color: textAccessibleSubtitle,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // NEW: Large accessible custom checkbox tap target
                        GestureDetector(
                          onTap: (!isToday || isChecked)
                              ? null
                              : () => _markReminderAsTaken(reminder),
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
        ),
      ),
    );
  }

  List<_ReminderInstance> _expandRemindersForDate(DateTime date) {
    final List<_ReminderInstance> result = [];
    for (final medicine in _medicines) {
      if (medicine.reminderStartDate != null &&
          medicine.reminderEndDate != null &&
          medicine.specificTime != null) {
        final DateTime d = DateTime(date.year, date.month, date.day);
        final DateTime start = DateTime(
          medicine.reminderStartDate!.year,
          medicine.reminderStartDate!.month,
          medicine.reminderStartDate!.day,
        );
        final DateTime end = DateTime(
          medicine.reminderEndDate!.year,
          medicine.reminderEndDate!.month,
          medicine.reminderEndDate!.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          result.add(
            _ReminderInstance(
              medicine: medicine,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      } else if (medicine.specificTime != null) {
        final DateTime d = DateTime(date.year, date.month, date.day);
        final DateTime t = DateTime(
          medicine.specificTime!.year,
          medicine.specificTime!.month,
          medicine.specificTime!.day,
        );
        if (d == t) {
          result.add(
            _ReminderInstance(
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateLabel(DateTime date, DateTime today) {
    if (_isSameDay(date, today)) return 'Today';
    if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Tomorrow';
    if (_isSameDay(date, today.subtract(const Duration(days: 1))))
      return 'Yesterday';
    return '${date.month}/${date.day}';
  }
}

class _ReminderInstance {
  final MedicineRecord medicine;
  final TimeOfDay time;
  _ReminderInstance({required this.medicine, required this.time});
}

// ---------------------------------------------------------
// LOGIN SCREEN (RESTORED - Exactly as requested)
// ---------------------------------------------------------
class MeditrackLoginScreen extends StatelessWidget {
  const MeditrackLoginScreen({super.key});

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color buttonColor = const Color(0xFF6E765D);
  final Color iconGreenColor = const Color(0xFF87A884);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.star_border_rounded,
                      color: iconGreenColor,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Meditrack',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login / Sign up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(obscureText: false),
                      const SizedBox(height: 20),
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(obscureText: true),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required bool obscureText}) {
    return TextField(
      obscureText: obscureText,
      style: TextStyle(color: textDark, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: textFieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
