// modals/medicine_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/patient_storage.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/schedule_tutorial.dart';
import 'package:showcaseview/showcaseview.dart';

enum DailyPreset { once, twice, four, custom }

class MedicineModal extends StatefulWidget {
  const MedicineModal({
    super.key,
    this.initialMedicine,
    this.patientId,
    this.startScheduleTutorial = false,
  });

  final MedicineRecord? initialMedicine;
  final String? patientId;
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
  bool _userTappedPresetRecently = false;
  int _presetTapTimestamp = 0;
  final TextEditingController _medicineInputController =
      TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController(
    text: '1 Pill',
  );
  final TextEditingController _frequencyCountController =
      TextEditingController();

  DailyPreset _selectedDailyPreset = DailyPreset.once;
  List<bool> _selectedWeekdays = List<bool>.filled(
    7,
    true,
  ); // All days selected by default

  DateTime? _reminderStartDate = DateTime.now();
  DateTime? _reminderEndDate;
  TimeOfDay? _reminderTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(minutes: 1)),
  );
  String _selectedIconKey = MedicineIcons.defaultIconKey;
  bool _isSaving = false;
  List<String> _selectedMedicines = <String>[];
  List<String> _stockMedicineNames = <String>[];
  Map<String, int> _stockCountByMedicine = <String, int>{};
  Map<String, String> _blockedStockReasonByMedicine = <String, String>{};
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
    _frequencyCountController.text = '24';
    _frequencyCountController.addListener(_onIntervalChanged);
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
    _frequencyCountController.removeListener(_onIntervalChanged);
    _medicineInputController.dispose();
    _doseAmountController.dispose();
    _frequencyCountController.dispose();
    super.dispose();
  }

  void _onIntervalChanged() {
    // Prevent auto-reset if user just tapped a preset (within 600ms)
    if (_userTappedPresetRecently &&
        DateTime.now().millisecondsSinceEpoch - _presetTapTimestamp < 600) {
      return;
    }
    final String text = _frequencyCountController.text;
    final double? hours = double.tryParse(text);
    if (hours != null) {
      DailyPreset newPreset;
      if (hours == 24) {
        newPreset = DailyPreset.once;
      } else if (hours == 12) {
        newPreset = DailyPreset.twice;
      } else if (hours == 6) {
        newPreset = DailyPreset.four;
      } else {
        newPreset = DailyPreset.custom;
      }
      if (_selectedDailyPreset != newPreset) {
        setState(() {
          _selectedDailyPreset = newPreset;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      color: Colors.white.withValues(alpha: 0.7),
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
                                  color: Colors.black.withValues(alpha: 0.08),
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
                                  color: textDark.withValues(alpha: 0.75),
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
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: textDark.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textDark.withValues(alpha: 0.9),
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
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                    ? (widget.initialMedicine != null
                                          ? 'Updating...'
                                          : 'Saving...')
                                    : (widget.initialMedicine != null
                                          ? 'Update'
                                          : 'Save'),
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
            child: _buildInputGroup(
              label: 'Dose Amount',
              hint: '1.0',
              controller: _doseAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d*')),
              ],
            ),
          ),
          Showcase(
            key: _scheduleFrequencyShowcaseKey,
            title: 'Frequency',
            description:
                'Set how often this medicine should be taken using predefined options.',
            child: _buildSectionCard(child: _buildFrequencyGroup()),
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
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFrequencyGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: TextStyle(
            fontSize: 14,
            color: textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: _buildFrequencyPresets(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: _buildInputGroup(
            label: 'Interval (hours)',
            hint: '24',
            controller: _frequencyCountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d*')),
            ],
            readOnly: _selectedDailyPreset != DailyPreset.custom,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: _buildTimePicker(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: _buildDaySelection(),
        ),
      ],
    );
  }

  Widget _buildDaySelection() {
    const List<String> dayLabels = <String>[
      'Su',
      'Mo',
      'Tu',
      'We',
      'Th',
      'Fr',
      'Sa',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Select days:',
          style: TextStyle(
            fontSize: 14,
            color: textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Ensures exactly 1 row and handles overflow gracefully
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(7, (int index) {
              final bool isSelected = _selectedWeekdays[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWeekdays[index] = !isSelected;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? sectionHeaderColor
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? sectionHeaderColor
                            : const Color(0xFFCBCBCB),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      dayLabels[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : textDark,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildPresetChip('Once', DailyPreset.once, '24'),
            _buildPresetChip('Twice', DailyPreset.twice, '12'),
            _buildPresetChip('Four', DailyPreset.four, '6'),
            _buildPresetChip('Custom', DailyPreset.custom, null),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, DailyPreset preset, String? hours) {
    final bool selected = _selectedDailyPreset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) {
        _markPresetTapped();
        setState(() {
          _selectedDailyPreset = preset;

          // WORKAROUND: When Custom is selected, clear the controller
          // so onChange listener doesn't match old value (24/12/6) and revert
          if (preset == DailyPreset.custom) {
            _frequencyCountController.clear();
          } else if (hours != null) {
            _frequencyCountController.text = hours;
          }
        });
      },
      backgroundColor: Colors.white,
      selectedColor: sectionHeaderColor.withValues(alpha: 0.2),
      checkmarkColor: sectionHeaderColor,
    );
  }

  Widget _buildTimePicker() {
    final String timeText = _reminderTime == null
        ? 'Select time'
        : _formatTimeOfDay(_reminderTime!);
    return Container(
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
            'First intake:',
            style: TextStyle(fontSize: 15, color: textDark),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectReminderTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4EE),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              child: Text(timeText, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
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
                    autofocus: false,
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
              style: TextStyle(
                fontSize: 12,
                color: textDark.withValues(alpha: 0.65),
              ),
            ),
          const SizedBox(height: 10),
          if (_selectedMedicines.isEmpty)
            Text(
              'Added medicines will appear below. Tap X to remove one.',
              style: TextStyle(
                fontSize: 12,
                color: textDark.withValues(alpha: 0.65),
              ),
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
                              color: textDark.withValues(alpha: 0.7),
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
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
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
              autofocus: false,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              readOnly: readOnly,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Dates',
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
                  'Select dates:',
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

    final String doseText = _doseAmountController.text.trim();
    final String hoursText = _frequencyCountController.text.trim();
    final double? hours = double.tryParse(hoursText);

    if (doseText.isEmpty || hours == null || _reminderTime == null) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final DateTime now = DateTime.now();
      final List<MedicineRecord> recordsToSave = [];
      final int remindersPerDay = (24 / hours).round();

      // --- NEW FREQUENCY FORMATTING LOGIC ---
      final String formattedHours = hours % 1 == 0
          ? hours.toInt().toString()
          : hours.toString();

      final List<String> dayLabelsFull = [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ];
      final List<String> selectedDayNames = [];
      for (int i = 0; i < 7; i++) {
        if (_selectedWeekdays[i]) selectedDayNames.add(dayLabelsFull[i]);
      }

      String freqText;
      if (selectedDayNames.length == 7) {
        freqText = 'Every $formattedHours hours';
      } else {
        freqText =
            'Every $formattedHours hours on ${selectedDayNames.join(', ')}';
      }
      // ---------------------------------------

      for (int i = 0; i < _selectedMedicines.length; i++) {
        final DateTime createdAt = widget.initialMedicine != null && i == 0
            ? widget.initialMedicine!.createdAt
            : now.add(Duration(microseconds: i + 1));

        for (int j = 0; j < (remindersPerDay > 0 ? remindersPerDay : 1); j++) {
          final int intervalHour =
              (_reminderTime!.hour +
                  (j * (24 ~/ (remindersPerDay > 0 ? remindersPerDay : 1)))) %
              24;
          final DateTime baseDate = _reminderStartDate ?? now;

          DateTime intervalTime = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            intervalHour,
            _reminderTime!.minute,
          );

          recordsToSave.add(
            MedicineRecord(
              iconKey: _selectedIconKey,
              patientId: widget.patientId ?? widget.initialMedicine?.patientId,
              name: _selectedMedicines[i],
              doseAmount: doseText,
              frequency: freqText, // Used the new formatted text here
              specificTime: intervalTime,
              reminderStartDate: _reminderStartDate,
              reminderEndDate: _reminderEndDate,
              createdAt: createdAt.add(Duration(milliseconds: j)),
            ),
          );
        }
      }

      if (widget.initialMedicine == null) {
        await MedicineStorage.addMedicines(recordsToSave);
      } else {
        await MedicineStorage.updateMedicine(recordsToSave.first);
        if (recordsToSave.length > 1) {
          await MedicineStorage.addMedicines(recordsToSave.skip(1).toList());
        }
      }

      _scheduleNotificationsInBackground(recordsToSave);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error saving: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Separate method to prevent UI blocking
  Future<void> _scheduleNotificationsInBackground(
    List<MedicineRecord> records,
  ) async {
    final bool hasAccess = await NotificationService.ensureNotificationAccess();
    if (!hasAccess) return;

    final bool hasPatientLinkedRecord = records.any(
      (MedicineRecord record) =>
          record.patientId != null && record.patientId!.isNotEmpty,
    );

    final Map<String, String> patientNameById = <String, String>{};
    if (hasPatientLinkedRecord) {
      final List<PatientRecord> patients = await PatientStorage.loadPatients();
      for (final PatientRecord patient in patients) {
        patientNameById[patient.createdAt.toIso8601String()] = patient.fullName;
      }
    }

    for (final record in records) {
      final String patientName =
          patientNameById[record.patientId ?? '']?.trim() ?? '';

      if (record.reminderStartDate != null && record.reminderEndDate != null) {
        await NotificationService.scheduleMedicineReminderRange(
          medicineCreatedAtMillis: record.createdAt.millisecondsSinceEpoch,
          medicineName: record.name,
          startDate: record.reminderStartDate!,
          endDate: record.reminderEndDate!,
          hour: record.specificTime!.hour,
          minute: record.specificTime!.minute,
          frequency: record.frequency,
          patientName: patientName,
          doseAmount: record.doseAmount,
        );
      } else if (record.specificTime != null) {
        await NotificationService.scheduleMedicineReminder(
          medicineCreatedAtMillis: record.createdAt.millisecondsSinceEpoch,
          medicineName: record.name,
          scheduledAt: record.specificTime!,
          patientName: patientName,
          doseAmount: record.doseAmount,
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _medicineInputController.clear();
      _selectedMedicines = <String>[];
      _doseAmountController.clear();
      _frequencyCountController.text = '24';
      _selectedDailyPreset = DailyPreset.once;
      _selectedWeekdays = List<bool>.filled(7, true); // All days selected
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

    final String lowered = name.toLowerCase();
    final String? blockedReason = _blockedStockReasonByMedicine.entries
        .where(
          (MapEntry<String, String> entry) =>
              entry.key.toLowerCase() == lowered,
        )
        .map((MapEntry<String, String> entry) => entry.value)
        .cast<String?>()
        .firstWhere((String? reason) => reason != null, orElse: () => null);
    if (blockedReason != null) {
      _showSnackBar('Cannot add "$name": $blockedReason');
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

  // ✅ CRITICAL FIX: Block Past Dates in Picker
  Future<void> _selectReminderDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    // Normalize to today's start (date only) to block picking yesterday
    final DateTime normalizedNow = DateTime(now.year, now.month, now.day);

    final DateTime? existingDate = isStart
        ? _reminderStartDate
        : _reminderEndDate;
    final DateTime initialDate =
        existingDate ?? _reminderStartDate ?? normalizedNow;

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: normalizedNow, // ← This ensures NO PAST dates are selectable
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
    final Map<String, int> totalStockByMedicine = <String, int>{};
    final Map<String, int> validStockByMedicine = <String, int>{};
    final Map<String, bool> hasExpiredBatchByMedicine = <String, bool>{};

    for (final StockRecord stock in stocks) {
      final String name = stock.medicineName.trim();
      if (name.isNotEmpty) {
        totalStockByMedicine[name] =
            (totalStockByMedicine[name] ?? 0) + stock.currentStock;

        if (stock.isExpired) {
          hasExpiredBatchByMedicine[name] = true;
          continue;
        }

        validStockByMedicine[name] =
            (validStockByMedicine[name] ?? 0) + stock.currentStock;
      }
    }

    final Map<String, String> blockedReasons = <String, String>{};
    for (final MapEntry<String, int> entry in totalStockByMedicine.entries) {
      final String name = entry.key;
      final int validStock = validStockByMedicine[name] ?? 0;
      if (validStock <= 0) {
        if (entry.value <= 0) {
          blockedReasons[name] = 'stock is 0';
        } else if (hasExpiredBatchByMedicine[name] == true) {
          blockedReasons[name] = 'stock is expired';
        } else {
          blockedReasons[name] = 'no usable stock';
        }
      }
    }

    final List<String> stockNames =
        validStockByMedicine.entries
            .where((MapEntry<String, int> entry) => entry.value > 0)
            .map((MapEntry<String, int> entry) => entry.key)
            .toList()
          ..sort();

    for (final String selected in _selectedMedicines) {
      if (!stockNames.contains(selected)) {
        stockNames.insert(0, selected);
        validStockByMedicine[selected] = validStockByMedicine[selected] ?? 0;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _stockMedicineNames = stockNames;
      _stockCountByMedicine = validStockByMedicine;
      _blockedStockReasonByMedicine = blockedReasons;
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
    final String frequencyValue = initial.frequency.trim();
    final RegExp everyHoursRegex = RegExp(
      r'^Every (\d+(?:\.\d+)?) hours$',
      caseSensitive: false,
    );
    final RegExp everyHoursOnDaysRegex = RegExp(
      r'^Every (\d+(?:\.\d+)?) hours on (.+)$',
      caseSensitive: false,
    );
    if (everyHoursOnDaysRegex.hasMatch(frequencyValue)) {
      final Match match = everyHoursOnDaysRegex.firstMatch(frequencyValue)!;
      _frequencyCountController.text = match.group(1)!;
      final double hours = double.parse(_frequencyCountController.text);
      if (hours == 24) {
        _selectedDailyPreset = DailyPreset.once;
      } else if (hours == 12) {
        _selectedDailyPreset = DailyPreset.twice;
      } else if (hours == 6) {
        _selectedDailyPreset = DailyPreset.four;
      } else {
        _selectedDailyPreset = DailyPreset.custom;
      }
      final String daysPart = match.group(2)!;
      final List<String> days = daysPart
          .split(', ')
          .map((String s) => s.trim())
          .toList();
      const List<String> dayLabels = <String>[
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ];
      _selectedWeekdays = List<bool>.filled(7, false);
      for (final String day in days) {
        final int index = dayLabels.indexOf(day);
        if (index != -1) {
          _selectedWeekdays[index] = true;
        }
      }
    } else if (everyHoursRegex.hasMatch(frequencyValue)) {
      _frequencyCountController.text = everyHoursRegex
          .firstMatch(frequencyValue)!
          .group(1)!;
      final double hours = double.parse(_frequencyCountController.text);
      if (hours == 24) {
        _selectedDailyPreset = DailyPreset.once;
      } else if (hours == 12) {
        _selectedDailyPreset = DailyPreset.twice;
      } else if (hours == 6) {
        _selectedDailyPreset = DailyPreset.four;
      } else {
        _selectedDailyPreset = DailyPreset.custom;
      }
      // For simple format, set all days selected
      _selectedWeekdays = List<bool>.filled(7, true);
    } else if (frequencyValue.toLowerCase() == 'daily') {
      _frequencyCountController.text = '24';
      _selectedDailyPreset = DailyPreset.once;
      _selectedWeekdays = List<bool>.filled(7, true);
    } else {
      // Unknown format, default to daily
      _frequencyCountController.text = '24';
      _selectedDailyPreset = DailyPreset.once;
      _selectedWeekdays = List<bool>.filled(7, true);
    }

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

  void _markPresetTapped() {
    _userTappedPresetRecently = true;
    _presetTapTimestamp = DateTime.now().millisecondsSinceEpoch;
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _userTappedPresetRecently = false;
      });
    });
  }
}
