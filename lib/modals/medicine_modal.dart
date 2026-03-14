import 'package:flutter/material.dart';

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

  DateTime? _specificDateTime;
  DateTime? _expirationDate;
  bool _isSaving = false;

  // Custom colors matching your new design
  final Color modalBgColor = const Color(0xFFC0D1BD);
  final Color sectionHeaderColor = const Color(0xFF8BBA91);
  final Color inputBgColor = Colors.white;
  final Color clearBtnColor = const Color(0xFFB53434);
  final Color saveBtnColor = const Color(0xFF3B5E3C);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textHint = const Color(0xFFC5C5C5);

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
                      _buildSpecificTimeGroup('Specific Time'),
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
                      _buildSpecificTimeGroup(
                        'Expiration Date',
                        isDateOnly: true,
                      ),
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

  // Widget builder for the Special "Select Time/Date" rows
  Widget _buildSpecificTimeGroup(String label, {bool isDateOnly = false}) {
    final DateTime? value = isDateOnly ? _expirationDate : _specificDateTime;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'Select:',
                  style: TextStyle(fontSize: 15, color: textDark),
                ),
                const SizedBox(width: 12),
                // Date Pill
                GestureDetector(
                  onTap: () => _selectDate(isDateOnly: isDateOnly),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_formatDate(value) ?? 'Select date'),
                  ),
                ),
                if (!isDateOnly) ...[
                  const SizedBox(width: 8),
                  // Time Pill
                  GestureDetector(
                    onTap: _selectTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_formatTime(value) ?? 'Select time'),
                    ),
                  ),
                ],
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

    setState(() {
      _isSaving = true;
    });

    final MedicineRecord record = MedicineRecord(
      name: _nameController.text.trim(),
      strength: _strengthController.text.trim(),
      details: _detailsController.text.trim(),
      doseAmount: _doseAmountController.text.trim(),
      frequency: _frequencyController.text.trim(),
      specificTime: _specificDateTime,
      currentStock: int.tryParse(_currentStockController.text.trim()),
      alarmStock: int.tryParse(_alarmStockController.text.trim()),
      expirationDate: _expirationDate,
      createdAt: DateTime.now(),
    );

    await MedicineStorage.addMedicine(record);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
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
      _specificDateTime = null;
      _expirationDate = null;
    });
  }

  Future<void> _selectDate({required bool isDateOnly}) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isDateOnly
        ? (_expirationDate ?? now)
        : (_specificDateTime ?? now);
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
      if (isDateOnly) {
        _expirationDate = selectedDate;
      } else {
        final DateTime current = _specificDateTime ?? now;
        _specificDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          current.hour,
          current.minute,
        );
      }
    });
  }

  Future<void> _selectTime() async {
    final DateTime now = DateTime.now();
    final DateTime current = _specificDateTime ?? now;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (time == null) {
      return;
    }

    setState(() {
      final DateTime baseDate = _specificDateTime ?? now;
      _specificDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        time.hour,
        time.minute,
      );
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

  String? _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }

    final TimeOfDay timeOfDay = TimeOfDay.fromDateTime(dateTime);
    return timeOfDay.format(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
