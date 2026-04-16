// lib/modals/stock_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/stock_tutorial.dart';
import 'package:showcaseview/showcaseview.dart';

class StockEditModal extends StatefulWidget {
  final StockRecord? initialRecord;
  final String initialMedicineName;
  final int initialStock;
  final int lowStockThreshold;
  final DateTime? initialExpiryDate;
  final bool startTutorial;

  const StockEditModal({
    super.key,
    this.initialRecord,
    this.initialMedicineName = '',
    this.initialStock = 7,
    this.lowStockThreshold = 4,
    this.initialExpiryDate,
    this.startTutorial = false,
  });

  @override
  State<StockEditModal> createState() => _StockEditModalState();
}

class _StockEditModalState extends State<StockEditModal> {
  final GlobalKey _iconShowcaseKey = GlobalKey();
  final GlobalKey _medicineNameShowcaseKey = GlobalKey();
  final GlobalKey _lowStockShowcaseKey = GlobalKey();
  final GlobalKey _expiryDateShowcaseKey = GlobalKey();
  final GlobalKey _currentStockShowcaseKey = GlobalKey();
  final GlobalKey _saveShowcaseKey = GlobalKey();

  late int _currentStock;
  late final TextEditingController _medicineNameController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _currentStockController;
  String _selectedIconKey = MedicineIcons.defaultIconKey;
  DateTime? _selectedExpiryDate;
  String? _inlineValidationError;

  // Colors based on the provided design
  final Color modalBgColor = const Color(0xFFF7F7F4);
  final Color circlePlaceholderColor = const Color(0xFFD9D9D9);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color labelColor = const Color(0xFF9E9E9E);
  final Color saveBtnBgColor = const Color(0xFFEFEFE8);

  // Dynamic Progress Colors (Synced with Dashboard)
  final Color progressInactiveColor = const Color(0xFFE0E0E0);
  final Color progressRedColor = const Color(0xFFFFC4CD); // Low Stock (Red)
  final Color progressYellowColor = const Color(
    0xFFFFF1BD,
  ); // Refill Soon (Yellow)
  final Color progressGreenColor = const Color(0xFFC0E5C4); // In Stock (Green)
  final Color progressExpiredColor = const Color(
    0xFFFF6B6B,
  ); // Strong Red (Expired)

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
    _medicineNameController.addListener(_clearInlineValidationError);
    _lowStockController.addListener(_clearInlineValidationError);
    _currentStockController.addListener(_clearInlineValidationError);
    _selectedIconKey = initialRecord?.iconKey ?? MedicineIcons.defaultIconKey;
    _selectedExpiryDate = initialRecord?.expiryDate ?? widget.initialExpiryDate;
    if (widget.startTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _startStockModalTutorial();
      });
    }
  }

  Future<void> _startStockModalTutorial() async {
    await startStockTutorial(
      context: context,
      isMounted: () => mounted,
      steps: buildStockModalTutorialSteps(
        iconShowcaseKey: _iconShowcaseKey,
        medicineNameShowcaseKey: _medicineNameShowcaseKey,
        lowStockShowcaseKey: _lowStockShowcaseKey,
        expiryDateShowcaseKey: _expiryDateShowcaseKey,
        currentStockShowcaseKey: _currentStockShowcaseKey,
        saveShowcaseKey: _saveShowcaseKey,
      ),
    );
  }

  @override
  void dispose() {
    _medicineNameController.removeListener(_clearInlineValidationError);
    _lowStockController.removeListener(_clearInlineValidationError);
    _currentStockController.removeListener(_clearInlineValidationError);
    _medicineNameController.dispose();
    _lowStockController.dispose();
    _currentStockController.dispose();
    super.dispose();
  }

  void _clearInlineValidationError() {
    if (_inlineValidationError == null || !mounted) {
      return;
    }
    setState(() {
      _inlineValidationError = null;
    });
  }

  void _incrementStock() {
    setState(() {
      _currentStock++;
      _currentStockController.text = _currentStock.toString();
      _inlineValidationError = null;
    });
  }

  void _decrementStock() {
    if (_currentStock > 0) {
      setState(() {
        _currentStock--;
        _currentStockController.text = _currentStock.toString();
        _inlineValidationError = null;
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
        _inlineValidationError = null;
      });
    }
  }

  void _saveStock() {
    final String medicineName = _medicineNameController.text.trim();
    final int? lowStock = int.tryParse(_lowStockController.text.trim());
    final int? currentStock = int.tryParse(_currentStockController.text.trim());

    if (medicineName.isEmpty) {
      setState(() {
        _inlineValidationError = 'Medicine name is required.';
      });
      return;
    }

    if (lowStock == null || lowStock < 0) {
      setState(() {
        _inlineValidationError = 'Low stock threshold must be a valid number.';
      });
      return;
    }

    if (currentStock == null || currentStock < 0) {
      setState(() {
        _inlineValidationError = 'Current stock must be a valid number.';
      });
      return;
    }

    if (_selectedExpiryDate == null) {
      setState(() {
        _inlineValidationError = 'Expiry date is required.';
      });
      return;
    }

    if (_inlineValidationError != null) {
      setState(() {
        _inlineValidationError = null;
      });
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const List<String> months = [
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
                  children: MedicineIcons.options.map((option) {
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

    if (selected != null) {
      setState(() {
        _selectedIconKey = selected;
      });
    }
  }

  String? _expiringLabel() {
    if (_selectedExpiryDate == null) return null;

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

    if (days < 0) return 'Already expired';
    return 'Expires in $days day${days == 1 ? '' : 's'}';
  }

  // --- SYNCED COLOR LOGIC ---
  Color _getProgressColor() {
    // 1. Check Expiration first
    if (_selectedExpiryDate != null &&
        _selectedExpiryDate!.isBefore(DateTime.now())) {
      return progressExpiredColor;
    }

    // 2. Parse the current threshold from the controller
    final int lowThreshold = int.tryParse(_lowStockController.text) ?? 0;

    // 3. Apply the synced rules
    if (_currentStock <= lowThreshold) {
      return progressRedColor;
    } else if (_currentStock <= lowThreshold + 3) {
      return progressYellowColor;
    } else {
      return progressGreenColor;
    }
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
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Showcase(
                    key: _iconShowcaseKey,
                    title: 'Choose icon',
                    description:
                        'Tap this icon area to pick the medicine icon for stock tracking.',
                    child: GestureDetector(
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
                  ),
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
              Showcase(
                key: _medicineNameShowcaseKey,
                title: 'Enter medicine name',
                description:
                    'Type the medicine name here so it can be matched with reminders and reports.',
                child: TextField(
                  controller: _medicineNameController,
                  autofocus: false,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'e.g., Paracetamol 500mg',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: textDark.withValues(alpha: 0.45),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                '$_currentStock doses left',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF8C8C8C),
                ),
              ),
              const SizedBox(height: 16),
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
                      color: _getProgressColor(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Showcase(
                key: _lowStockShowcaseKey,
                title: 'Set low-stock threshold',
                description:
                    'This number controls when the app flags a medicine as low stock.',
                child: _buildDetailInputRow(
                  label: 'Low Stock:',
                  controller: _lowStockController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 12),
              Showcase(
                key: _expiryDateShowcaseKey,
                title: 'Set expiry date',
                description:
                    'Choose the expiration date so expired medicines are highlighted automatically.',
                child: _buildDateRow(),
              ),
              if (expiryText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 90),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: progressYellowColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expiryText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: progressYellowColor,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
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
              Showcase(
                key: _currentStockShowcaseKey,
                title: 'Set current stock count',
                description:
                    'Use minus, plus, or direct input to set how many doses are currently available.',
                child: Row(
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
                            autofocus: false,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            onChanged: (value) {
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
                      icon: const Icon(
                        Icons.add,
                        size: 36,
                        color: Colors.black87,
                      ),
                      onPressed: _incrementStock,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_inlineValidationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE57373)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Color(0xFFC62828),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inlineValidationError!,
                            style: const TextStyle(
                              color: Color(0xFFB71C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Showcase(
                key: _saveShowcaseKey,
                title: 'Save stock entry',
                description:
                    'After filling out details, tap Save to add this medicine to stock tracking.',
                child: SizedBox(
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
              ),
            ],
          ),
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
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              autofocus: false,
              keyboardType: keyboardType,
              // Live Color Sync:
              onChanged: (_) => setState(() {}),
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
                    color: Colors.black.withValues(alpha: 0.04),
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
