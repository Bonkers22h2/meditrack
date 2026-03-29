import 'package:flutter/material.dart';

import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/schedule_tutorial.dart';
import 'package:showcaseview/showcaseview.dart';

class MedicineModal extends StatefulWidget {
  const MedicineModal({
    super.key,
    this.initialMedicine,
    this.startScheduleTutorial = false,
  });

  final MedicineRecord? initialMedicine;
  final bool startScheduleTutorial;

  @override
  State<MedicineModal> createState() => _MedicineModalState();
}

class _MedicineModalState extends State<MedicineModal> {
  int _currentTabIndex = 0;

  final GlobalKey _scheduleDetailsShowcaseKey = GlobalKey();
  final GlobalKey _scheduleIconShowcaseKey = GlobalKey();
  final GlobalKey _scheduleDoseShowcaseKey = GlobalKey();
  final GlobalKey _scheduleFrequencyShowcaseKey = GlobalKey();
  final GlobalKey _scheduleRangeShowcaseKey = GlobalKey();
  final GlobalKey _scheduleSaveShowcaseKey = GlobalKey();

  final TextEditingController _medicineInputController =
      TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  DateTime? _reminderStartDate;
  DateTime? _reminderEndDate;
  TimeOfDay? _reminderTime;
  String _selectedIconKey = MedicineIcons.defaultIconKey;
  bool _isSaving = false;
  List<String> _selectedMedicines = <String>[];
  List<String> _stockMedicineNames = <String>[];
  Map<String, int> _stockCountByMedicine = <String, int>{};
  bool _isLoadingStockNames = true;

  final Color modalBgColor = const Color(0xFFC0D1BD);
  final Color sectionHeaderColor = const Color(0xFF8BBA91);
  final Color inputBgColor = Colors.white;
  final Color clearBtnColor = const Color(0xFFB53434);
  final Color saveBtnColor = const Color(0xFF3B5E3C);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textHint = const Color(0xFFC5C5C5);

  @override
  void initState() {
    super.initState();
    _populateInitialValues();
    _loadMedicineNamesFromStocks();

    if (widget.startScheduleTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _startScheduleTutorial();
      });
    }
  }

  @override
  void dispose() {
    _medicineInputController.dispose();
    _doseAmountController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.initialMedicine != null;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double maxModalHeight = MediaQuery.of(context).size.height * 0.9;
    final double bottomInset = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom
        : mediaQuery.viewPadding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxModalHeight),
            child: Container(
              decoration: BoxDecoration(
                color: modalBgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        Showcase(
                          key: _scheduleIconShowcaseKey,
                          title: 'Schedule details',
                          description:
                              'Set medicine names, dose, frequency, and schedule in one flow.',
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.medication_liquid_rounded,
                              color: sectionHeaderColor,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Schedule Medicines',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add medicines and schedule time range',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textDark.withOpacity(0.75),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Schedule tutorial',
                          icon: const Icon(Icons.help_outline),
                          onPressed: _startScheduleTutorial,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.75),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: textDark.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textDark.withOpacity(0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _buildCurrentTabContent(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _clearForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: clearBtnColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.delete_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Showcase(
                            key: _scheduleSaveShowcaseKey,
                            title: 'Save schedule',
                            description:
                                'When you are done, tap here to save medication details and schedule reminders.',
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveMedicine,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: saveBtnColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isSaving
                                    ? (isEditMode ? 'Updating...' : 'Saving...')
                                    : (isEditMode ? 'Update' : 'Save'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Showcase(
            key: _scheduleDetailsShowcaseKey,
            title: 'Choose medication type',
            description:
                'Add medicines one by one. Each medicine will be saved separately under this schedule.',
            child: _buildSectionCard(child: _buildMedicationSetGroup()),
          ),
          Showcase(
            key: _scheduleDoseShowcaseKey,
            title: 'Dose amount',
            description:
                'Enter how much of the medicine the user should take each time.',
            child: _buildSectionCard(
              child: _buildInputGroup(
                label: 'Dose Amount',
                hint: '1 pill..',
                controller: _doseAmountController,
              ),
            ),
          ),
          Showcase(
            key: _scheduleFrequencyShowcaseKey,
            title: 'Frequency',
            description:
                'Set how often this medicine should be taken, like daily or every 6 hours.',
            child: _buildSectionCard(
              child: _buildInputGroup(
                label: 'Frequency',
                hint: 'Daily..',
                controller: _frequencyController,
              ),
            ),
          ),
          Showcase(
            key: _scheduleRangeShowcaseKey,
            title: 'Schedule dates and time',
            description:
                'Choose the date range and reminder time for this medication schedule.',
            child: _buildSectionCard(child: _buildReminderRangeGroup()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMedicationSetGroup() {
    final bool hasStocks = _stockMedicineNames.isNotEmpty;
    final String query = _medicineInputController.text.trim().toLowerCase();
    final List<String> suggestions = _stockMedicineNames
        .where((String name) {
          final bool alreadySelected = _selectedMedicines.any(
            (String selected) => selected.toLowerCase() == name.toLowerCase(),
          );
          if (alreadySelected) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return name.toLowerCase().contains(query);
        })
        .take(6)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicines',
            style: TextStyle(
              fontSize: 14,
              color: textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: inputBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6ECE1)),
                  ),
                  child: TextField(
                    controller: _medicineInputController,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: true,
                    enableSuggestions: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) =>
                        _addMedicineName(_medicineInputController.text),
                    decoration: InputDecoration(
                      hintText: hasStocks
                          ? 'Type medicine (or choose suggested below)'
                          : 'Type medicine name',
                      hintStyle: TextStyle(color: textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () =>
                      _addMedicineName(_medicineInputController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sectionHeaderColor,
                    foregroundColor: textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingStockNames)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (suggestions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map((String suggestion) {
                    return ActionChip(
                      label: Text(
                        '$suggestion (${_stockCountByMedicine[suggestion] ?? 0} left)',
                      ),
                      onPressed: () => _addMedicineName(suggestion),
                    );
                  })
                  .toList(growable: false),
            )
          else
            Text(
              hasStocks
                  ? 'No matching suggestions. You can still add a custom medicine name.'
                  : 'No stocks found. You can still add custom medicine names.',
              style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.65)),
            ),
          const SizedBox(height: 10),
          if (_selectedMedicines.isEmpty)
            Text(
              'Added medicines will appear below. Tap X to remove one.',
              style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.65)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedMedicines
                  .map((String medicine) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6EC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD7E3D2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            medicine,
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeMedicineName(medicine),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: textDark.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6ECE1)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: textHint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderRangeGroup() {
    final String timeText = _reminderTime == null
        ? 'Select time'
        : _formatTimeOfDay(_reminderTime!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specific Time Range',
            style: TextStyle(
              fontSize: 14,
              color: textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6ECE1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select:',
                  style: TextStyle(fontSize: 15, color: textDark),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectReminderDate(isStart: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDate(_reminderStartDate) ?? 'Start date',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectReminderDate(isStart: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDate(_reminderEndDate) ?? 'End date',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6ECE1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time:', style: TextStyle(fontSize: 15, color: textDark)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectReminderTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(timeText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (_selectedMedicines.isEmpty) {
      final String pendingName = _medicineInputController.text.trim();
      if (pendingName.isNotEmpty) {
        _addMedicineName(pendingName);
      }
    }

    if (_selectedMedicines.isEmpty) {
      _showSnackBar('Add at least one medication first.');
      return;
    }

    final bool hasReminderInput =
        _reminderStartDate != null ||
        _reminderEndDate != null ||
        _reminderTime != null;
    if (hasReminderInput &&
        (_reminderStartDate == null ||
            _reminderEndDate == null ||
            _reminderTime == null)) {
      _showSnackBar('Please select start date, end date, and time.');
      return;
    }

    if (_reminderStartDate != null &&
        _reminderEndDate != null &&
        _reminderEndDate!.isBefore(_reminderStartDate!)) {
      _showSnackBar('End date must be on or after start date.');
      return;
    }

    final bool hasReminderRange =
        _reminderStartDate != null &&
        _reminderEndDate != null &&
        _reminderTime != null;

    DateTime? reminderDateTime;
    if (_reminderStartDate != null && _reminderTime != null) {
      reminderDateTime = DateTime(
        _reminderStartDate!.year,
        _reminderStartDate!.month,
        _reminderStartDate!.day,
        _reminderTime!.hour,
        _reminderTime!.minute,
      );
    }

    String? postSaveMessage;
    if (!hasReminderRange &&
        reminderDateTime != null &&
        !reminderDateTime.isAfter(DateTime.now())) {
      reminderDateTime = null;
      postSaveMessage =
          'Medicine saved, but reminder was not scheduled because the selected time is in the past.';
    }

    final DateTime baseTime = DateTime.now();
    final List<MedicineRecord> recordsToSave = <MedicineRecord>[];
    for (int i = 0; i < _selectedMedicines.length; i += 1) {
      final DateTime createdAt = widget.initialMedicine != null && i == 0
          ? widget.initialMedicine!.createdAt
          : baseTime.add(Duration(microseconds: i + 1));
      recordsToSave.add(
        MedicineRecord(
          iconKey: _selectedIconKey,
          name: _selectedMedicines[i],
          doseAmount: _doseAmountController.text.trim(),
          frequency: _frequencyController.text.trim(),
          specificTime: reminderDateTime,
          reminderStartDate: _reminderStartDate,
          reminderEndDate: _reminderEndDate,
          createdAt: createdAt,
        ),
      );
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.initialMedicine == null) {
        for (final MedicineRecord record in recordsToSave) {
          await MedicineStorage.addMedicine(record);
        }
      } else {
        await MedicineStorage.updateMedicine(recordsToSave.first);
        if (recordsToSave.length > 1) {
          for (final MedicineRecord record in recordsToSave.skip(1)) {
            await MedicineStorage.addMedicine(record);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showSnackBar('Unable to save medicine. Please try again.');
      }
      return;
    }

    if (hasReminderRange) {
      try {
        final bool hasAccess =
            await NotificationService.ensureNotificationAccess();
        if (!hasAccess) {
          postSaveMessage =
              'Medicine saved, but notifications are disabled in system settings.';
        } else {
          int totalScheduledCount = 0;
          for (final MedicineRecord record in recordsToSave) {
            final int scheduledCount =
                await NotificationService.scheduleMedicineReminderRange(
                  medicineCreatedAtMillis:
                      record.createdAt.millisecondsSinceEpoch,
                  medicineName: record.name,
                  startDate: _reminderStartDate!,
                  endDate: _reminderEndDate!,
                  hour: _reminderTime!.hour,
                  minute: _reminderTime!.minute,
                  doseAmount: record.doseAmount,
                );
            totalScheduledCount += scheduledCount;
          }

          if (totalScheduledCount == 0) {
            postSaveMessage =
                'Medicine saved, but no reminders were scheduled because all selected dates are in the past.';
          }
        }
      } catch (_) {
        postSaveMessage =
            'Medicine saved, but reminder could not be scheduled. Check notification permission.';
      }
    } else if (reminderDateTime != null) {
      try {
        final bool hasAccess =
            await NotificationService.ensureNotificationAccess();
        if (!hasAccess) {
          postSaveMessage =
              'Medicine saved, but notifications are disabled in system settings.';
        } else {
          for (final MedicineRecord record in recordsToSave) {
            await NotificationService.scheduleMedicineReminder(
              medicineCreatedAtMillis: record.createdAt.millisecondsSinceEpoch,
              medicineName: record.name,
              scheduledAt: reminderDateTime,
              doseAmount: record.doseAmount,
            );
          }
        }
      } catch (_) {
        postSaveMessage =
            'Medicine saved, but reminder could not be scheduled. Check notification permission.';
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
    if (postSaveMessage != null) {
      _showSnackBar(postSaveMessage);
    }
    Navigator.pop(context, true);
  }

  void _clearForm() {
    setState(() {
      _medicineInputController.clear();
      _selectedMedicines = <String>[];
      _doseAmountController.clear();
      _frequencyController.clear();
      _reminderStartDate = null;
      _reminderEndDate = null;
      _reminderTime = null;
      _selectedIconKey = MedicineIcons.defaultIconKey;
    });
  }

  void _addMedicineName(String value) {
    final String name = value.trim();
    if (name.isEmpty) {
      return;
    }

    final bool exists = _selectedMedicines.any(
      (String item) => item.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      _medicineInputController.clear();
      setState(() {});
      return;
    }

    setState(() {
      _selectedMedicines = <String>[..._selectedMedicines, name];
      _medicineInputController.clear();
    });
  }

  void _removeMedicineName(String name) {
    setState(() {
      _selectedMedicines = _selectedMedicines
          .where((String item) => item != name)
          .toList(growable: false);
    });
  }

  Future<void> _selectReminderDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? existingDate = isStart
        ? _reminderStartDate
        : _reminderEndDate;
    final DateTime initialDate = existingDate ?? _reminderStartDate ?? now;

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _reminderStartDate = selectedDate;

        if (_reminderEndDate != null &&
            _reminderEndDate!.isBefore(_reminderStartDate!)) {
          _reminderEndDate = _reminderStartDate;
        }
      } else {
        _reminderEndDate = selectedDate;
      }
    });
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay initialTime = _reminderTime ?? TimeOfDay.now();
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null) {
      return;
    }

    setState(() {
      _reminderTime = time;
    });
  }

  String? _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }

    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final DateTime dateTime = DateTime(
      2000,
      1,
      1,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    return TimeOfDay.fromDateTime(dateTime).format(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToTab(int index) {
    setState(() {
      _currentTabIndex = index;
    });
  }

  Future<void> _startScheduleTutorial() async {
    await startScheduleTutorial(
      context: context,
      isMounted: () => mounted,
      currentTabIndex: _currentTabIndex,
      goToTab: _goToTab,
      introSteps: buildScheduleTutorialIntroSteps(
        scheduleDetailsShowcaseKey: _scheduleDetailsShowcaseKey,
      ),
      dosageSteps: buildScheduleTutorialSteps(
        scheduleIconShowcaseKey: _scheduleIconShowcaseKey,
        scheduleDoseShowcaseKey: _scheduleDoseShowcaseKey,
        scheduleFrequencyShowcaseKey: _scheduleFrequencyShowcaseKey,
        scheduleRangeShowcaseKey: _scheduleRangeShowcaseKey,
        scheduleSaveShowcaseKey: _scheduleSaveShowcaseKey,
      ),
    );
  }

  Future<void> _loadMedicineNamesFromStocks() async {
    final List<StockRecord> stocks = await StockStorage.loadStocks();
    final Map<String, int> stockCountByMedicine = <String, int>{};
    for (final StockRecord stock in stocks) {
      final String name = stock.medicineName.trim();
      if (name.isNotEmpty) {
        stockCountByMedicine[name] =
            (stockCountByMedicine[name] ?? 0) + stock.currentStock;
      }
    }

    final List<String> stockNames = stockCountByMedicine.keys.toList()..sort();
    for (final String selected in _selectedMedicines) {
      if (!stockNames.contains(selected)) {
        stockNames.insert(0, selected);
        stockCountByMedicine[selected] = stockCountByMedicine[selected] ?? 0;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _stockMedicineNames = stockNames;
      _stockCountByMedicine = stockCountByMedicine;
      _isLoadingStockNames = false;
    });
  }

  void _populateInitialValues() {
    final MedicineRecord? initial = widget.initialMedicine;
    if (initial == null) {
      return;
    }

    _selectedIconKey = initial.iconKey;
    _selectedMedicines = <String>[initial.name];
    _doseAmountController.text = initial.doseAmount;
    _frequencyController.text = initial.frequency;

    final DateTime? fallbackReminderDate = initial.specificTime == null
        ? null
        : DateTime(
            initial.specificTime!.year,
            initial.specificTime!.month,
            initial.specificTime!.day,
          );

    _reminderStartDate = initial.reminderStartDate ?? fallbackReminderDate;
    _reminderEndDate =
        initial.reminderEndDate ?? _reminderStartDate ?? fallbackReminderDate;
    if (initial.specificTime != null) {
      _reminderTime = TimeOfDay(
        hour: initial.specificTime!.hour,
        minute: initial.specificTime!.minute,
      );
    }
  }
}
