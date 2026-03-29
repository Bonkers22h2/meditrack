import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/stock_storage.dart';

class StockEditModal extends StatefulWidget {
  final StockRecord? initialRecord;
  final String initialMedicineName;
  final int initialStock;
  final int lowStockThreshold;
  final DateTime? initialExpiryDate;

  const StockEditModal({
    super.key,
    this.initialRecord,
    this.initialMedicineName = 'Medicine 2',
    this.initialStock = 7,
    this.lowStockThreshold = 4,
    this.initialExpiryDate,
  });

  @override
  State<StockEditModal> createState() => _StockEditModalState();
}

class _StockEditModalState extends State<StockEditModal> {
  late int _currentStock;
  late final TextEditingController _medicineNameController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _currentStockController;
  String _selectedIconKey = MedicineIcons.defaultIconKey;
  DateTime? _selectedExpiryDate;

  // Colors based on the provided design
  final Color modalBgColor = const Color(0xFFF7F7F4);
  final Color circlePlaceholderColor = const Color(0xFFD9D9D9);
  final Color progressActiveColor = const Color(0xFFF8B600);
  final Color progressInactiveColor = const Color(0xFFE0E0E0);
  final Color labelColor = const Color(0xFF9E9E9E);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color saveBtnBgColor = const Color(0xFFEFEFE8);

  @override
  void initState() {
    super.initState();
    final StockRecord? initialRecord = widget.initialRecord;
    _currentStock = initialRecord?.currentStock ?? widget.initialStock;
    _medicineNameController = TextEditingController(
      text: initialRecord?.medicineName ?? widget.initialMedicineName,
    );
    _lowStockController = TextEditingController(
      text: (initialRecord?.lowStockThreshold ?? widget.lowStockThreshold)
          .toString(),
    );
    _currentStockController = TextEditingController(
      text: _currentStock.toString(),
    );
    _selectedIconKey = initialRecord?.iconKey ?? MedicineIcons.defaultIconKey;
    _selectedExpiryDate = initialRecord?.expiryDate ?? widget.initialExpiryDate;
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _lowStockController.dispose();
    _currentStockController.dispose();
    super.dispose();
  }

  void _incrementStock() {
    setState(() {
      _currentStock++;
      _currentStockController.text = _currentStock.toString();
    });
  }

  void _decrementStock() {
    if (_currentStock > 0) {
      setState(() {
        _currentStock--;
        _currentStockController.text = _currentStock.toString();
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1);
    final DateTime lastDate = DateTime(now.year + 20);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  void _saveStock() {
    final String medicineName = _medicineNameController.text.trim();
    final int? lowStock = int.tryParse(_lowStockController.text.trim());
    final int? currentStock = int.tryParse(_currentStockController.text.trim());

    if (medicineName.isEmpty) {
      _showError('Medicine name is required.');
      return;
    }

    if (lowStock == null || lowStock < 0) {
      _showError('Low stock threshold must be a valid number.');
      return;
    }

    if (currentStock == null || currentStock < 0) {
      _showError('Current stock must be a valid number.');
      return;
    }

    _currentStock = currentStock;

    final StockRecord result = StockRecord(
      iconKey: _selectedIconKey,
      medicineName: medicineName,
      currentStock: _currentStock,
      lowStockThreshold: lowStock,
      expiryDate: _selectedExpiryDate,
      createdAt: widget.initialRecord?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, result);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
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
                  'Choose stock icon',
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

  String? _expiringLabel() {
    if (_selectedExpiryDate == null) {
      return null;
    }

    final DateTime today = DateTime.now();
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime normalizedExpiry = DateTime(
      _selectedExpiryDate!.year,
      _selectedExpiryDate!.month,
      _selectedExpiryDate!.day,
    );
    final int days = normalizedExpiry.difference(normalizedToday).inDays;

    if (days < 0) {
      return 'Already expired';
    }

    return 'Expires in $days day${days == 1 ? '' : 's'}';
  }

  double _progressFactor(int lowStockThreshold) {
    final int safeThreshold = lowStockThreshold <= 0 ? 1 : lowStockThreshold;
    final double value = _currentStock / (safeThreshold * 2);
    return value.clamp(0.05, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final int lowThreshold = int.tryParse(_lowStockController.text) ?? 1;
    final String? expiryText = _expiringLabel();

    return Dialog(
      backgroundColor: modalBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrinks to fit content
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Close Button & Image Placeholder
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Image Circle
                GestureDetector(
                  onTap: _showIconPicker,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: circlePlaceholderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      MedicineIcons.resolve(_selectedIconKey),
                      size: 70,
                      color: const Color(0xFF6F6F6F),
                    ),
                  ),
                ),
                // Close Button (Top Right)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 32,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showIconPicker,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit icon'),
            ),

            const SizedBox(height: 20),

            // 2. Editable medicine name
            TextField(
              controller: _medicineNameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Medicine name',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: textDark.withOpacity(0.45),
                ),
              ),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),

            // 3. Doses Left (Monospace)
            Text(
              '$_currentStock doses left',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF8C8C8C),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Progress Bar
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: progressInactiveColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressFactor(lowThreshold),
                child: Container(
                  decoration: BoxDecoration(
                    color: progressActiveColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Details Form Fields
            _buildDetailInputRow(
              label: 'Low Stock:',
              controller: _lowStockController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildDateRow(),

            // Expiry Warning Label
            if (expiryText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 90),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: progressActiveColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expiryText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progressActiveColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // 6. Current Stock Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current Stock:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),

            // Stepper Control (+ / -)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove,
                    size: 36,
                    color: Colors.black87,
                  ),
                  onPressed: _decrementStock,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: TextField(
                        controller: _currentStockController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        onChanged: (String value) {
                          final int? parsed = int.tryParse(value);
                          setState(() {
                            _currentStock = parsed ?? 0;
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: textDark,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.add, size: 36, color: Colors.black87),
                  onPressed: _incrementStock,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 7. Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: saveBtnBgColor,
                  foregroundColor: textDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInputRow({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: const InputDecoration(border: InputBorder.none),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'Expiry Date:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickExpiryDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _formatDate(_selectedExpiryDate),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_month, size: 18, color: textDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
