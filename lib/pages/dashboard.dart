// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:meditrack/modals/medicine_details_modal.dart';
import 'package:meditrack/modals/medicine_modal.dart';
import 'package:meditrack/pages/reports.dart';
import 'package:meditrack/pages/stocks.dart';
import 'package:meditrack/modals/settings_modal.dart';
import 'package:meditrack/tutorials/dashboard_tutorial.dart';
import 'package:meditrack/tutorials/tutorial_preferences.dart';
import 'package:meditrack/widgets/intro_popup_dialog.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/stock_storage.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.showFirstLoginSectionsPopup = false,
    this.initialTabIndex = 0,
    this.startAddMedicationTutorial = false,
  });
  final bool showFirstLoginSectionsPopup;
  final int initialTabIndex;
  final bool startAddMedicationTutorial;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;
  bool _startStockTutorialOnNextBuild = false;
  bool _startAddMedicationTutorialOnNextBuild = false;
  static const String _takenRemindersStorageKey = 'taken_reminders_v1';
  static const String _deductedRemindersStorageKey = 'deducted_reminders_v1';

  final GlobalKey _titleShowcaseKey = GlobalKey();
  final GlobalKey _scheduleButtonShowcaseKey = GlobalKey();
  final GlobalKey _dateSelectorShowcaseKey = GlobalKey();
  final GlobalKey _stockTabShowcaseKey = GlobalKey();

  final List<IntroPopupPage> _firstLoginSectionsPages = const <IntroPopupPage>[
    IntroPopupPage(
      title: 'Getting Started',
      description:
          "Since it's your first time, we'll show you the main sections of the app:",
      steps: <String>[
        'Reminders: This is where you can set and view your medicine schedules',
        'Stocks: This is where you can manage your medicine stocks',
      ],
      extra:
          'Tip: If you need help later, tapping the help icon indicated by (?) lets you access the Help Center.',
    ),
  ];

  List<MedicineRecord> _medicines = <MedicineRecord>[];
  Set<String> _takenReminderKeys = <String>{};
  Set<String> _deductedReminderKeys = <String>{};
  Map<String, String> _stockIconByMedicine = <String, String>{};
  Set<String> _expiredMedicineNames = <String>{};
  int _stockCount = 0;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);
  final Color textAccessibleSubtitle = const Color(0xFF616161);
  final Color morningColor = const Color(0xFF56BFA8);
  final Color afternoonColor = const Color(0xFFFFB74D);
  final Color nightColor = const Color(0xFF7986CB);

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _startAddMedicationTutorialOnNextBuild = widget.startAddMedicationTutorial;
    _loadMedicines();
    _loadStocks();
    _loadReminderCompletionState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showFirstLoginSectionsPopupThenTutorial();
    });
  }

  Future<void> _startDashboardTutorialIfNeeded() async {
    await startDashboardTutorialIfNeeded(
      context: context,
      isMounted: () => mounted,
      steps: buildDashboardTutorialSteps(
        titleShowcaseKey: _titleShowcaseKey,
        scheduleButtonShowcaseKey: _scheduleButtonShowcaseKey,
        dateSelectorShowcaseKey: _dateSelectorShowcaseKey,
        stockTabShowcaseKey: _stockTabShowcaseKey,
      ),
    );
  }

  Future<void> _showFirstLoginSectionsPopupThenTutorial() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasSeenSectionsIntro =
        prefs.getBool(TutorialPreferences.firstLoginSectionsSeenKey) ?? false;
    if (!mounted) {
      return;
    }
    if (!hasSeenSectionsIntro) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return IntroPopupDialog(pages: _firstLoginSectionsPages);
        },
      );
      await prefs.setBool(TutorialPreferences.firstLoginSectionsSeenKey, true);
    }
    if (!mounted) {
      return;
    }
    await _startDashboardTutorialIfNeeded();
  }

  void _showStockTab({
    bool startTutorial = false,
    bool startAddMedicationTutorial = false,
  }) {
    setState(() {
      _selectedTabIndex = 1;
      _startStockTutorialOnNextBuild = startTutorial;
      _startAddMedicationTutorialOnNextBuild = startAddMedicationTutorial;
    });
  }

  Future<void> _openHelpSectionsPopup() async {
    final DashboardHelpSection? selectedSection =
        await showDashboardHelpSectionsPopup(
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
              scheduleButtonShowcaseKey: _scheduleButtonShowcaseKey,
              dateSelectorShowcaseKey: _dateSelectorShowcaseKey,
              stockTabShowcaseKey: _stockTabShowcaseKey,
            ),
          );
          break;
        case DashboardHelpSection.addSchedule:
          _openMedicineModal(startScheduleTutorial: true);
          break;
        case DashboardHelpSection.manageStocks:
          _showStockTab(startTutorial: true);
          break;
        case DashboardHelpSection.addMedicationStock:
          Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => DashboardScreen(
                    initialTabIndex: 1,
                    startAddMedicationTutorial: true,
                  ),
                ),
              )
              .then((_) => _loadStocks());
          break;
      }
    }
  }

  Future<void> _loadMedicines() async {
    final List<MedicineRecord> medicines =
        (await MedicineStorage.loadMedicines())
            .where((MedicineRecord record) => record.patientId == null)
            .toList();
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
    final Map<String, String> stockIconByMedicine = <String, String>{};
    final Set<String> expiredMedicineNames = <String>{};
    for (final StockRecord stock in stocks) {
      final String key = stock.medicineName.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      stockIconByMedicine[key] = stock.iconKey;
      if (stock.isExpired) {
        expiredMedicineNames.add(key);
      }
    }
    setState(() {
      _stockCount = stocks.length;
      _stockIconByMedicine = stockIconByMedicine;
      _expiredMedicineNames = expiredMedicineNames;
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

  void _showDashboardSnackBar(
    String message, {
    Color background = const Color(0xFFEF6C00),
    IconData icon = Icons.info_outline,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          backgroundColor: background,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
    final String normalizedName = reminder.medicine.name.trim().toLowerCase();

    // Guard against context access after disposal
    if (!mounted) {
      return;
    }
    if (_expiredMedicineNames.contains(normalizedName)) {
      if (!mounted) {
        return;
      }
      _showDashboardSnackBar(
        'This medicine is expired. Cannot mark dose as taken.',
        background: const Color(0xFFC62828),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final int doseCount = _extractDoseCount(reminder.medicine.doseAmount);
    if (!_deductedReminderKeys.contains(storageKey)) {
      final int availableStock =
          await StockStorage.getAvailableStockForMedicine(
            medicineName: reminder.medicine.name,
          );
      if (availableStock < doseCount) {
        if (!mounted) {
          return;
        }
        _showDashboardSnackBar(
          'Not enough stock for ${reminder.medicine.name}. Need $doseCount, available $availableStock.',
          background: const Color(0xFFEF6C00),
          icon: Icons.inventory_2_outlined,
        );
        return;
      }
    }

    bool deducted = false;
    if (!_deductedReminderKeys.contains(storageKey)) {
      deducted = await StockStorage.deductStockForMedicine(
        medicineName: reminder.medicine.name,
        amount: doseCount,
      );
      if (!deducted) {
        if (!mounted) {
          return;
        }
        _showDashboardSnackBar(
          'Unable to deduct stock. Please try again.',
          background: const Color(0xFFC62828),
          icon: Icons.error_outline,
        );
        return;
      }
      if (mounted) {
        setState(() {
          _deductedReminderKeys.add(storageKey);
        });
      } else {
        _deductedReminderKeys.add(storageKey);
      }
      unawaited(_loadStocks());
    }

    if (!mounted) {
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

    await _persistReminderCompletionState();

    if (!mounted) {
      return;
    }
    final String message = deducted
        ? 'Deducted $doseCount pill${doseCount == 1 ? '' : 's'} from ${reminder.medicine.name} stock.'
        : 'Reminder marked done.';
    _showDashboardSnackBar(
      message,
      background: const Color(0xFF2E7D32),
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _openMedicineModal({bool startScheduleTutorial = false}) async {
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          MedicineModal(startScheduleTutorial: startScheduleTutorial),
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
    final Widget currentTab = _selectedTabIndex == 0
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            height: 40,
                            child: Image.asset(
                              'android/app/src/main/res/assets/icons (1).png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
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
                            onPressed: _openHelpSectionsPopup,
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
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Showcase(
                        key: _titleShowcaseKey,
                        title: 'Reminders dashboard overview',
                        description:
                            "This is the reminders dashboard where you can review today's medication list.",
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
                    ),
                    Showcase(
                      key: _scheduleButtonShowcaseKey,
                      title: 'Schedule medication',
                      description:
                          'Use this button to add a new medication reminder.',
                      child: ElevatedButton.icon(
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
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Showcase(
                  key: _dateSelectorShowcaseKey,
                  title: 'Pick a day',
                  description:
                      'Switch between dates to review reminders for any day of the week.',
                  child: _buildDateSelector(),
                ),
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
        : _selectedTabIndex == 1
        ? StockScreen(
            startTutorial: _startStockTutorialOnNextBuild,
            startAddMedicationTutorial: _startAddMedicationTutorialOnNextBuild,
            onStockTutorialLaunched: () {
              if (!_startStockTutorialOnNextBuild || !mounted) {
                return;
              }
              setState(() {
                _startStockTutorialOnNextBuild = false;
              });
            },
            onAddMedicationTutorialLaunched: () {
              if (!_startAddMedicationTutorialOnNextBuild || !mounted) {
                return;
              }
              setState(() {
                _startAddMedicationTutorialOnNextBuild = false;
              });
            },
            onHelpPressed: _openHelpSectionsPopup,
          )
        : ReportsScreen(onHelpPressed: _openHelpSectionsPopup);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: currentTab),
      bottomNavigationBar: Showcase(
        key: _stockTabShowcaseKey,
        title: 'Open stocks',
        description:
            'Tap here to manage inventory and move to the stock screen.',
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (int index) {
            setState(() {
              _selectedTabIndex = index;
            });
            if (index == 0 || index == 1) {
              _loadStocks();
            }
          },
          backgroundColor: cardColor,
          selectedItemColor: textDark,
          unselectedItemColor: textFaint,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm),
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

  Widget _buildDateSelector() {
    final DateTime today = DateTime.now();
    // Show 3 days before → today → 3 days after
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
    final List<_ReminderInstance> allReminders = _expandRemindersForDate(
      _selectedDate,
    );

    final bool isToday = _isSameDay(_selectedDate, DateTime.now());
    final List<_ReminderInstance> reminders;

    // ✅ FIXED: Show ALL reminders regardless of time passed
    // No longer filters by .isAfter(now) - preserves complete history
    reminders = allReminders;

    if (reminders.isEmpty) {
      return Center(
        child: Text(
          isToday
              ? 'No upcoming reminders for today'
              : 'No reminders for this day',
          style: TextStyle(
            color: textFaint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Grouping logic remains unchanged...
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
    final String iconKey =
        _stockIconByMedicine[medicine.name.trim().toLowerCase()] ??
        medicine.iconKey;
    final bool isToday = _isSameDay(_selectedDate, DateTime.now());
    final String reminderKey = _reminderStorageKey(reminder, _selectedDate);
    final bool isChecked = _takenReminderKeys.contains(reminderKey);
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
            color: Colors.black.withValues(alpha: 0.04),
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
                            MedicineIcons.resolve(iconKey),
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
                        const SizedBox(width: 16),
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
                                  color: textAccessibleSubtitle,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          // FIX: Allow tap on any date, but action only valid if isToday
                          onTap:
                              (!isChecked) // Only allow interaction if not already checked
                              ? () {
                                  if (!isToday)
                                    return; // Prevent marking non-today as taken
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
        ),
      ),
    );
  }

  List<_ReminderInstance> _expandRemindersForDate(DateTime date) {
    final List<_ReminderInstance> result = [];
    // Normalize selected date to midnight (date-only comparison)
    final DateTime selectedDateOnly = DateTime(
      date.year,
      date.month,
      date.day,
      0,
      0,
      0,
    );

    for (final medicine in _medicines) {
      // Skip medicines without time info
      if (medicine.specificTime == null) continue;

      final String normalizedMedicineName = medicine.name.trim().toLowerCase();
      if (normalizedMedicineName.isNotEmpty &&
          _expiredMedicineNames.contains(normalizedMedicineName)) {
        continue;
      }

      // Respect selected weekdays from frequency text (e.g. "on Sun, Tue").
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

      // Handle Range-Based Meds (with start/end dates)
      if (startOnly != null || endOnly != null) {
        // ⚠️ CRITICAL FIX: DO NOT create reminders before start date
        if (startOnly != null && selectedDateOnly.isBefore(startOnly)) {
          continue;
        }
        // Filter OUT: Medicines that have ended
        if (endOnly != null && selectedDateOnly.isAfter(endOnly)) {
          continue;
        }

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
      // Handle One-Time / Single Date Meds (No Range Set)
      else if (medicine.specificTime != null &&
          medicine.reminderStartDate == null) {
        // Exact match required for single-intake medicines
        final DateTime targetDate = DateTime(
          medicine.specificTime!.year,
          medicine.specificTime!.month,
          medicine.specificTime!.day,
        );

        if (_isSameDay(targetDate, selectedDateOnly)) {
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

  // FIXED: Uses normalization to ensure accurate Today/Yesterday labels
  String _dateLabel(DateTime date, DateTime today) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );

    if (normalizedDate == normalizedToday) return 'Today';
    if (normalizedDate == normalizedToday.add(const Duration(days: 1)))
      return 'Tomorrow';
    if (normalizedDate == normalizedToday.subtract(const Duration(days: 1)))
      return 'Yesterday';
    return '${date.month}/${date.day}';
  }
}

class _ReminderInstance {
  final MedicineRecord medicine;
  final TimeOfDay time;
  _ReminderInstance({required this.medicine, required this.time});
}

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
                        color: Colors.black.withValues(alpha: 0.03),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
      autofocus: false,
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
