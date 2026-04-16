// lib/pages/stocks.dart
import 'package:flutter/material.dart';
import 'package:meditrack/modals/settings_modal.dart';
import 'package:meditrack/modals/stock_modal.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/stock_tutorial.dart';
import 'package:showcaseview/showcaseview.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({
    super.key,
    this.startTutorial = false,
    this.startAddMedicationTutorial = false,
    this.onStockTutorialLaunched,
    this.onAddMedicationTutorialLaunched,
    this.onHelpPressed,
  });

  final bool startTutorial;
  final bool startAddMedicationTutorial;
  final VoidCallback? onStockTutorialLaunched;
  final VoidCallback? onAddMedicationTutorialLaunched;
  final VoidCallback? onHelpPressed;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockRecord> _stocks = <StockRecord>[];
  bool _isLoading = true;

  final GlobalKey _titleShowcaseKey = GlobalKey();
  final GlobalKey _addMedicationShowcaseKey = GlobalKey();
  final GlobalKey _stockListShowcaseKey = GlobalKey();

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);
  final Color textSection = const Color(0xFFA1A69B);

  // Synchronized color constants
  final Color lowStockColor = const Color(0xFFFFC4CD); // Red
  final Color refillSoonColor = const Color(0xFFFFF1BD); // Yellow
  final Color inStockColor = const Color(0xFFC0E5C4); // Green
  final Color expiredColor = const Color(0xFFFF6B6B); // Strong Red

  @override
  void initState() {
    super.initState();
    _loadStocks();
    if (widget.startAddMedicationTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onAddMedicationTutorialLaunched?.call();
        _startAddMedicationTutorial();
      });
    } else if (widget.startTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onStockTutorialLaunched?.call();
        _startStockTutorial();
      });
    } else {
      startStockTutorialIfNeeded(
        context: context,
        isMounted: () => mounted,
        steps: buildStockTutorialSteps(
          titleShowcaseKey: _titleShowcaseKey,
          addMedicationShowcaseKey: _addMedicationShowcaseKey,
          stockListShowcaseKey: _stockListShowcaseKey,
        ),
      );
    }
  }

  Future<void> _loadStocks() async {
    final List<StockRecord> records = await StockStorage.loadStocks();
    if (!mounted) return;

    setState(() {
      _stocks = records.reversed.toList();
      _isLoading = false;
    });
  }

  // --- SYNC HELPER METHOD ---
  // This ensures the dashboard always matches the dialog logic
  Color _getStockCardColor(StockRecord stock) {
    if (stock.isExpired) return expiredColor;
    if (stock.isLowStock) return lowStockColor;
    if (stock.isRefillSoon) return refillSoonColor;
    return inStockColor;
  }

  Future<void> _openAddStockModal({bool startTutorial = false}) async {
    final StockRecord? newStock = await showDialog<StockRecord>(
      context: context,
      builder: (BuildContext context) =>
          StockEditModal(startTutorial: startTutorial),
    );

    if (newStock == null) return;

    await StockStorage.addStock(newStock);
    await _loadStocks();
  }

  Future<void> _openEditStockModal(StockRecord record) async {
    final StockRecord? updatedStock = await showDialog<StockRecord>(
      context: context,
      builder: (BuildContext context) => StockEditModal(initialRecord: record),
    );

    if (updatedStock == null) return;

    await StockStorage.upsertStock(updatedStock);
    await _loadStocks();
  }

  Future<void> _startStockTutorial() async {
    await startStockTutorial(
      context: context,
      isMounted: () => mounted,
      steps: buildStockTutorialSteps(
        titleShowcaseKey: _titleShowcaseKey,
        addMedicationShowcaseKey: _addMedicationShowcaseKey,
        stockListShowcaseKey: _stockListShowcaseKey,
      ),
    );
  }

  Future<void> _startAddMedicationTutorial() async {
    await _openAddStockModal(startTutorial: true);
  }

  String _dosesText(int count) {
    return '$count dose${count == 1 ? '' : 's'} left';
  }

  Widget _buildStockListBySection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_stocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Text(
          'No stock items yet. Tap Add Medication to create one.',
          style: TextStyle(
            color: textFaint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final List<StockRecord> expired = _stocks
        .where((s) => s.isExpired)
        .toList();
    final List<StockRecord> lowStock = _stocks
        .where((s) => s.isLowStock && !s.isExpired)
        .toList();
    final List<StockRecord> refillSoon = _stocks
        .where((s) => s.isRefillSoon && !s.isExpired)
        .toList();
    final List<StockRecord> inStock = _stocks
        .where((s) => !s.isLowStock && !s.isRefillSoon && !s.isExpired)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expired.isNotEmpty) ...[
          _buildSectionTitle('Expired'),
          ...expired.map((stock) => _buildMedicineCard(stock: stock)),
          const SizedBox(height: 8),
        ],
        if (lowStock.isNotEmpty) ...[
          _buildSectionTitle('Low Stock'),
          ...lowStock.map((stock) => _buildMedicineCard(stock: stock)),
          const SizedBox(height: 8),
        ],
        if (refillSoon.isNotEmpty) ...[
          _buildSectionTitle('Refill Soon'),
          ...refillSoon.map((stock) => _buildMedicineCard(stock: stock)),
          const SizedBox(height: 8),
        ],
        if (inStock.isNotEmpty) ...[
          _buildSectionTitle('In Stock'),
          ...inStock.map((stock) => _buildMedicineCard(stock: stock)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
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
                          tooltip: 'Stock tutorial',
                          icon: Icon(
                            Icons.help_outline,
                            color: textLight,
                            size: 24,
                          ),
                          onPressed:
                              widget.onHelpPressed ?? _startStockTutorial,
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
              const SizedBox(height: 32),
              Showcase(
                key: _titleShowcaseKey,
                title: 'Stock management',
                description:
                    'This page helps you keep track of medication inventory, refill timing, and expiring items.',
                child: Text(
                  'Stock',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w400,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Showcase(
                key: _addMedicationShowcaseKey,
                title: 'Add medication stock',
                description:
                    'Create a stock entry for a medicine so the app can track how many doses are left.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _openAddStockModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: textDark,
                      elevation: 0,
                      side: BorderSide(
                        color: textFaint.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Showcase(
                key: _stockListShowcaseKey,
                title: 'Track inventory',
                description:
                    'Low stock, refill soon, expired, and in-stock items are grouped so you can prioritize what needs attention.',
                child: _buildStockListBySection(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: textSection,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMedicineCard({required StockRecord stock}) {
    final bool showWarning = stock.isExpired || stock.isExpiringSoon;
    final IconData warningIcon = stock.isExpired
        ? Icons.error_rounded
        : Icons.warning_amber_rounded;
    final String warningLabel = stock.isExpired ? 'Expired' : 'Expiring';

    // Logic Sync: Card determines its own color via helper
    final Color cardBgColor = _getStockCardColor(stock);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openEditStockModal(stock),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showWarning) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(warningIcon, color: Colors.white, size: 20),
                    Text(
                      warningLabel,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              Text(
                stock.medicineName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: stock.isExpired ? Colors.white : textDark,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _dosesText(stock.currentStock),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF8C8C8C),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    size: 24,
                    color: stock.isExpired ? Colors.white : textDark,
                  ),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 10,
                      color: stock.isExpired ? Colors.white : textDark,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
