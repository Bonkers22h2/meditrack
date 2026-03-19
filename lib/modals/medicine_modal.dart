import 'package:flutter/material.dart';

import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';

class MedicineModal extends StatefulWidget {
  const MedicineModal({super.key, this.initialMedicine});

  final MedicineRecord? initialMedicine;

  @override
  State<MedicineModal> createState() => _MedicineModalState();
}

class _MedicineModalState extends State<MedicineModal>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;
  late final TabController _tabController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  DateTime? _reminderStartDate;
  DateTime? _reminderEndDate;
  TimeOfDay? _reminderTime;
  String _selectedIconKey = MedicineIcons.defaultIconKey;
  bool _isSaving = false;
  bool? _notificationsEnabled;
  bool _isCheckingNotificationStatus = true;
  bool _isSendingTestNotification = false;

  // Custom colors matching your new design
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
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        }
      });
    _populateInitialValues();
    _refreshNotificationStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _doseAmountController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.initialMedicine != null;
    final double maxModalHeight = MediaQuery.of(context).size.height * 0.9;

    // Wrap in a GestureDetector to dismiss keyboard on tap outside
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        // Adjust for system keyboard
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showIconPicker,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              MedicineIcons.resolve(_selectedIconKey),
                              color: sectionHeaderColor,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medicine Icon',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap icon to change',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textDark.withOpacity(0.75),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _showIconPicker,
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: sectionHeaderColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (int index) {
                        setState(() {
                          _currentTabIndex = index;
                        });
                      },
                      labelColor: textDark,
                      unselectedLabelColor: textDark.withOpacity(0.75),
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Details'),
                        Tab(text: 'Dosage'),
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

                  // 5. Bottom Buttons Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Row(
                      children: [
                        // Clear Button
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

                        // Save Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    if (_currentTabIndex < 1) {
                                      _goToTab(_currentTabIndex + 1);
                                      return;
                                    }
                                    _saveMedicine();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: saveBtnColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentTabIndex < 1
                                  ? 'Next'
                                  : _isSaving
                                  ? (isEditMode ? 'Updating...' : 'Saving...')
                                  : (isEditMode ? 'Update' : 'Save'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
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
    switch (_currentTabIndex) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputGroup(
                label: 'Medication name',
                hint: 'Name..',
                controller: _nameController,
              ),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputGroup(
                label: 'Dose Amount',
                hint: '1 pill..',
                controller: _doseAmountController,
              ),
              _buildInputGroup(
                label: 'Frequency',
                hint: 'Daily..',
                controller: _frequencyController,
              ),
              _buildReminderRangeGroup(),
              _buildNotificationTestCard(),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNotificationTestCard() {
    final String statusText;
    if (_isCheckingNotificationStatus) {
      statusText = 'Checking notification permission...';
    } else if (_notificationsEnabled == true) {
      statusText = 'Notifications: Enabled';
    } else {
      statusText = 'Notifications: Disabled';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inputBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 13, color: textDark),
                  ),
                ),
                TextButton(
                  onPressed: _isCheckingNotificationStatus
                      ? null
                      : _refreshNotificationStatus,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSendingTestNotification
                        ? null
                        : _sendInstantTestNotification,
                    child: const Text('Test now'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSendingTestNotification
                        ? null
                        : _sendDelayedTestNotification,
                    child: const Text('Test in 10s'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshNotificationStatus() async {
    setState(() {
      _isCheckingNotificationStatus = true;
    });

    bool enabled = true;
    try {
      enabled = await NotificationService.areNotificationsEnabled();
    } catch (_) {
      enabled = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = enabled;
      _isCheckingNotificationStatus = false;
    });
  }

  Future<void> _sendInstantTestNotification() async {
    await _sendTestNotification(delayedSeconds: 0);
  }

  Future<void> _sendDelayedTestNotification() async {
    await _sendTestNotification(delayedSeconds: 10);
  }

  Future<void> _sendTestNotification({required int delayedSeconds}) async {
    setState(() {
      _isSendingTestNotification = true;
    });

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String medicineName = _nameController.text.trim().isEmpty
        ? 'your medicine'
        : _nameController.text.trim();

    try {
      if (delayedSeconds == 0) {
        await NotificationService.showInstantTestNotification(
          notificationId: notificationId,
          title: 'Test Reminder',
          body: 'This is an instant reminder for $medicineName.',
        );
        _showSnackBar('Instant test notification sent.');
      } else {
        await NotificationService.scheduleTestNotificationInSeconds(
          notificationId: notificationId,
          seconds: delayedSeconds,
          title: 'Test Reminder',
          body: 'Time to take $medicineName.',
        );
        _showSnackBar('Test notification scheduled in 10 seconds.');
      }
    } catch (_) {
      _showSnackBar('Unable to send test notification. Check permission.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTestNotification = false;
        });
        await _refreshNotificationStatus();
      }
    }
  }

  // Widget builder for the standard Input fields (Label + TextField)
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
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
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
                            color: const Color(0xFFF0F0F0),
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
                            color: const Color(0xFFF0F0F0),
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
                      color: const Color(0xFFF0F0F0),
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
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Medication name is required');
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

    setState(() {
      _isSaving = true;
    });

    final MedicineRecord record = MedicineRecord(
      iconKey: _selectedIconKey,
      name: _nameController.text.trim(),
      doseAmount: _doseAmountController.text.trim(),
      frequency: _frequencyController.text.trim(),
      specificTime: reminderDateTime,
      reminderStartDate: _reminderStartDate,
      reminderEndDate: _reminderEndDate,
      createdAt: widget.initialMedicine?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.initialMedicine == null) {
        await MedicineStorage.addMedicine(record);
      } else {
        await MedicineStorage.updateMedicine(record);
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
        final int scheduledCount =
            await NotificationService.scheduleMedicineReminderRange(
              baseNotificationId:
                  record.createdAt.millisecondsSinceEpoch ~/ 1000,
              medicineName: record.name,
              startDate: _reminderStartDate!,
              endDate: _reminderEndDate!,
              hour: _reminderTime!.hour,
              minute: _reminderTime!.minute,
              doseAmount: record.doseAmount,
            );

        if (scheduledCount == 0) {
          postSaveMessage =
              'Medicine saved, but no reminders were scheduled because all selected dates are in the past.';
        }
      } catch (_) {
        postSaveMessage =
            'Medicine saved, but reminder could not be scheduled. Check notification permission.';
      }
    } else if (reminderDateTime != null) {
      try {
        await NotificationService.scheduleMedicineReminder(
          notificationId: record.createdAt.millisecondsSinceEpoch ~/ 1000,
          medicineName: record.name,
          scheduledAt: reminderDateTime,
          doseAmount: record.doseAmount,
        );
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
      _nameController.clear();
      _doseAmountController.clear();
      _frequencyController.clear();
      _reminderStartDate = null;
      _reminderEndDate = null;
      _reminderTime = null;
      _selectedIconKey = MedicineIcons.defaultIconKey;
    });
  }

  Future<void> _showIconPicker() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose medicine icon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MedicineIcons.options.map((
                    MedicineIconOption option,
                  ) {
                    final bool isSelected = option.key == _selectedIconKey;
                    return ChoiceChip(
                      label: Text(option.label),
                      avatar: Icon(option.icon, size: 18),
                      selected: isSelected,
                      onSelected: (_) => Navigator.pop(context, option.key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedIconKey = selected;
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
    _tabController.animateTo(index);
    setState(() {
      _currentTabIndex = index;
    });
  }

  void _populateInitialValues() {
    final MedicineRecord? initial = widget.initialMedicine;
    if (initial == null) {
      return;
    }

    _selectedIconKey = initial.iconKey;
    _nameController.text = initial.name;
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
