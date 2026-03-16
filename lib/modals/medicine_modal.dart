import 'package:flutter/material.dart';

import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/services/medicine_storage.dart';

class MedicineModal extends StatefulWidget {
  const MedicineModal({super.key});

  @override
  State<MedicineModal> createState() => _MedicineModalState();
}

class _MedicineModalState extends State<MedicineModal> {
  // State for which section is currently expanded
  bool _isDetailsExpanded = true;
  bool _isDosageExpanded = false;
  bool _isInventoryExpanded = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _currentStockController = TextEditingController();
  final TextEditingController _alarmStockController = TextEditingController();

  DateTime? _reminderStartDate;
  DateTime? _reminderEndDate;
  TimeOfDay? _reminderTime;
  DateTime? _expirationDate;
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
    _refreshNotificationStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _detailsController.dispose();
    _doseAmountController.dispose();
    _frequencyController.dispose();
    _currentStockController.dispose();
    _alarmStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in a GestureDetector to dismiss keyboard on tap outside
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: modalBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        // Adjust for system keyboard
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // 1. Header (Icon + Text)
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Edit Medicine Icon',
                          style: TextStyle(
                            fontSize: 16,
                            color: textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 2. Medication Details Section
                    _buildSectionHeader(
                      title: 'Medication Details',
                      isExpanded: _isDetailsExpanded,
                      onTap: () {
                        setState(() {
                          _isDetailsExpanded = !_isDetailsExpanded;
                        });
                      },
                    ),
                    if (_isDetailsExpanded) ...[
                      const SizedBox(height: 16),
                      _buildInputGroup(
                        label: 'Medication name',
                        hint: 'Name..',
                        controller: _nameController,
                      ),
                      _buildInputGroup(
                        label: 'Strength',
                        hint: '500mg..',
                        controller: _strengthController,
                      ),
                      _buildInputGroup(
                        label: 'Details',
                        hint: 'For Diabetes..',
                        controller: _detailsController,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 3. Dosage Section
                    _buildSectionHeader(
                      title: 'Dosage',
                      isExpanded: _isDosageExpanded,
                      onTap: () {
                        setState(() {
                          _isDosageExpanded = !_isDosageExpanded;
                        });
                      },
                    ),
                    if (_isDosageExpanded) ...[
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 12),

                    // 4. Inventory Section
                    _buildSectionHeader(
                      title: 'Inventory',
                      isExpanded: _isInventoryExpanded,
                      onTap: () {
                        setState(() {
                          _isInventoryExpanded = !_isInventoryExpanded;
                        });
                      },
                    ),
                    if (_isInventoryExpanded) ...[
                      const SizedBox(height: 16),
                      _buildInputGroup(
                        label: 'Current stock',
                        hint: 'Total medicine..',
                        controller: _currentStockController,
                        keyboardType: TextInputType.number,
                      ),
                      _buildInputGroup(
                        label: 'Alarm when Stock hits:',
                        hint: '1..',
                        controller: _alarmStockController,
                        keyboardType: TextInputType.number,
                      ),
                      _buildExpirationDateGroup(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
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
                      onPressed: _isSaving ? null : _saveMedicine,
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
                        _isSaving ? 'Saving...' : 'Save',
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
    );
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

  // Widget builder for the Green Expandable Headers
  Widget _buildSectionHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: sectionHeaderColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
              color: textDark,
              size: 24,
            ),
          ],
        ),
      ),
    );
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () => _selectReminderDate(isStart: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatDate(_reminderStartDate) ?? 'Start date',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _selectReminderDate(isStart: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatDate(_reminderEndDate) ?? 'End date',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _selectReminderTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationDateGroup() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expiration Date',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: _selectExpirationDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatDate(_expirationDate) ?? 'Select date',
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
      name: _nameController.text.trim(),
      strength: _strengthController.text.trim(),
      details: _detailsController.text.trim(),
      doseAmount: _doseAmountController.text.trim(),
      frequency: _frequencyController.text.trim(),
      specificTime: reminderDateTime,
      reminderStartDate: _reminderStartDate,
      reminderEndDate: _reminderEndDate,
      currentStock: int.tryParse(_currentStockController.text.trim()),
      alarmStock: int.tryParse(_alarmStockController.text.trim()),
      expirationDate: _expirationDate,
      createdAt: DateTime.now(),
    );

    try {
      await MedicineStorage.addMedicine(record);
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
      _strengthController.clear();
      _detailsController.clear();
      _doseAmountController.clear();
      _frequencyController.clear();
      _currentStockController.clear();
      _alarmStockController.clear();
      _reminderStartDate = null;
      _reminderEndDate = null;
      _reminderTime = null;
      _expirationDate = null;
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

  Future<void> _selectExpirationDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _expirationDate ?? now;

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
      _expirationDate = selectedDate;
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
}
