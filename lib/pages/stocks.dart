import 'package:flutter/material.dart';
import 'package:meditrack/modals/stock_modal.dart';
import 'package:meditrack/services/stock_storage.dart';
import 'package:meditrack/tutorials/stock_tutorial.dart';
import 'package:showcaseview/showcaseview.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key, this.startTutorial = false});

  final bool startTutorial;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockRecord> _stocks = <StockRecord>[];
  bool _isLoading = true;

  final GlobalKey _titleShowcaseKey = GlobalKey();
  final GlobalKey _addMedicationShowcaseKey = GlobalKey();
  final GlobalKey _stockListShowcaseKey = GlobalKey();
  final GlobalKey _reportShowcaseKey = GlobalKey();

  // Reusing the core colors
  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);

  // Custom Section Header color
  final Color textSection = const Color(0xFFA1A69B);

  // Exact card background colors matched from the image
  final Color lowStockColor = const Color(0xFFFFC4CD); // Pastel Pink
  final Color refillSoonColor = const Color(0xFFFFF1BD); // Pastel Yellow
  final Color inStockColor = const Color(0xFFC0E5C4); // Pastel Green

  @override
  void initState() {
    super.initState();
    _loadStocks();
    if (widget.startTutorial) {
      _startStockTutorial();
    } else {
      startStockTutorialIfNeeded(
        context: context,
        isMounted: () => mounted,
        steps: buildStockTutorialSteps(
          titleShowcaseKey: _titleShowcaseKey,
          addMedicationShowcaseKey: _addMedicationShowcaseKey,
          stockListShowcaseKey: _stockListShowcaseKey,
          reportShowcaseKey: _reportShowcaseKey,
        ),
      );
    }
  }

  Future<void> _loadStocks() async {
    final List<StockRecord> records = await StockStorage.loadStocks();
    if (!mounted) {
      return;
    }

    setState(() {
      _stocks = records.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> _openAddStockModal() async {
    final StockRecord? newStock = await showDialog<StockRecord>(
      context: context,
      builder: (BuildContext context) => const StockEditModal(),
    );

    if (newStock == null) {
      return;
    }

    await StockStorage.addStock(newStock);
    await _loadStocks();
  }

  Future<void> _openEditStockModal(StockRecord record) async {
    final StockRecord? updatedStock = await showDialog<StockRecord>(
      context: context,
      builder: (BuildContext context) => StockEditModal(initialRecord: record),
    );

    if (updatedStock == null) {
      return;
    }

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
        reportShowcaseKey: _reportShowcaseKey,
      ),
    );
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

    final List<StockRecord> lowStock = _stocks
        .where((StockRecord stock) => stock.isLowStock)
        .toList();
    final List<StockRecord> refillSoon = _stocks
        .where((StockRecord stock) => stock.isRefillSoon)
        .toList();
    final List<StockRecord> inStock = _stocks
        .where((StockRecord stock) => !stock.isLowStock && !stock.isRefillSoon)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Low Stock'),
        ...lowStock.map(
          (StockRecord stock) => _buildMedicineCard(
            stock: stock,
            doses: _dosesText(stock.currentStock),
            bgColor: lowStockColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildSectionTitle('Refill Soon'),
        ...refillSoon.map(
          (StockRecord stock) => _buildMedicineCard(
            stock: stock,
            doses: _dosesText(stock.currentStock),
            bgColor: refillSoonColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildSectionTitle('In Stock'),
        ...inStock.map(
          (StockRecord stock) => _buildMedicineCard(
            stock: stock,
            doses: _dosesText(stock.currentStock),
            bgColor: inStockColor,
          ),
        ),
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

              // 1. Top Bar (Logo + Settings)
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
                              color: Colors.black.withOpacity(0.03),
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
                          onPressed: _startStockTutorial,
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
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 2. Title
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
                      side: BorderSide(color: textFaint.withOpacity(0.35)),
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
                    'Low stock, refill soon, and in-stock items are grouped so you can prioritize what needs attention.',
                child: _buildStockListBySection(),
              ),

              const SizedBox(height: 24),

              // 6. View Report Button
              Showcase(
                key: _reportShowcaseKey,
                title: 'View reports',
                description:
                    'Use reports to review your stock history and spot items that need attention.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDCDCDC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          // View report logic
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                          child: Text(
                            'View Report',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for Section Titles (e.g. "Low Stock")
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

  // Helper method for the Medicine Pill Cards
  Widget _buildMedicineCard({
    required StockRecord stock,
    required String doses,
    required Color bgColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openEditStockModal(stock),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (stock.isExpiringSoon) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: textDark,
                      size: 20,
                    ),
                    Text(
                      'Expiring',
                      style: TextStyle(
                        fontSize: 8,
                        color: textDark,
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
                  color: textDark,
                ),
              ),

              const SizedBox(width: 16),

              Text(
                doses,
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
                  Icon(Icons.edit, size: 24, color: textDark),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 10,
                      color: textDark,
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
