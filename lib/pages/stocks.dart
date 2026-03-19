import 'package:flutter/material.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

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
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined, color: textFaint, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Meditrack',
                        style: TextStyle(
                          color: textFaint,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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

              const SizedBox(height: 32),

              // 2. Title
              Text(
                'Stock',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                  color: textDark,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 16),

              // 3. Low Stock Section
              _buildSectionTitle('Low Stock'),
              _buildMedicineCard(
                name: 'Medicine 1',
                doses: '2 doses left',
                bgColor: lowStockColor,
                showExpiring: false,
              ),
              _buildMedicineCard(
                name: 'Medicine 4',
                doses: '3 doses left',
                bgColor: lowStockColor,
                showExpiring: false,
              ),

              const SizedBox(height: 8),

              // 4. Refill Soon Section
              _buildSectionTitle('Refill Soon'),
              _buildMedicineCard(
                name: 'Medicine 2',
                doses: '7 doses left',
                bgColor: refillSoonColor,
                showExpiring: true, // Shows the warning icon
              ),

              const SizedBox(height: 8),

              // 5. In Stock Section
              _buildSectionTitle('In Stock'),
              _buildMedicineCard(
                name: 'Medicine 3',
                doses: '20 doses left',
                bgColor: inStockColor,
                showExpiring: false,
              ),
              _buildMedicineCard(
                name: 'Medicine 5',
                doses: '23 doses left',
                bgColor: inStockColor,
                showExpiring: true, // Shows the warning icon
              ),

              const SizedBox(height: 24),

              // 6. View Report Button
              Align(
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
    required String name,
    required String doses,
    required Color bgColor,
    required bool showExpiring,
  }) {
    return Container(
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
          // Expiring Alert Icon
          if (showExpiring) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: textDark, size: 20),
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

          // Medicine Name
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textDark,
            ),
          ),

          const SizedBox(width: 16),

          // Doses Left (Uses Monospace font for typewriter effect)
          Text(
            doses,
            style: const TextStyle(
              fontFamily: 'monospace', // Gives exactly that faded tracking look
              color: Color(0xFF8C8C8C),
              fontSize: 13,
            ),
          ),

          const Spacer(),

          // Refill Button Area
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 32, color: textDark),
              Text(
                'Refill',
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
    );
  }
}
