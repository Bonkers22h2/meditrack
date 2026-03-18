import 'package:flutter/material.dart';
import 'package:meditrack/modals/medicine_details_modal.dart';
import 'package:meditrack/modals/medicine_modal.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/medicine_storage.dart';

void main() {
  runApp(const MeditrackApp());
}

class MeditrackApp extends StatelessWidget {
  const MeditrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: const DashboardScreen(),
    );
  }
}

// ---------------------------------------------------------
// DASHBOARD SCREEN (Reminders) - UPDATED CONTRAST
// ---------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<MedicineRecord> _medicines = <MedicineRecord>[];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // Updated color palette for better visibility
  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color textDark = const Color(0xFF1A1A1A); // High contrast black
  final Color textLight = const Color(
    0xFF757575,
  ); // Darker grey for settings icon & standard light text
  final Color textFaint = const Color(
    0xFF8B9084,
  ); // Much darker olive-grey for hints, now highly visible!

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final List<MedicineRecord> medicines =
        await MedicineStorage.loadMedicines();
    if (!mounted) {
      return;
    }

    setState(() {
      _medicines = medicines.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> _openMedicineModal() async {
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const MedicineModal(),
    );

    if (didSave == true) {
      await _loadMedicines();
    }
  }

  Future<void> _openMedicineDetailsModal(MedicineRecord medicine) async {
    final bool? didChange = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MedicineDetailsModal(medicine: medicine);
      },
    );

    if (didChange == true) {
      await _loadMedicines();
    }
  }

  String _buildSubtitle(MedicineRecord medicine) {
    final String dose = medicine.doseAmount.trim();
    final String frequency = medicine.frequency.trim();
    if (dose.isEmpty && frequency.isEmpty) {
      return medicine.strength.isEmpty
          ? 'No dosage details'
          : medicine.strength;
    }

    if (dose.isEmpty) {
      return frequency;
    }
    if (frequency.isEmpty) {
      return dose;
    }
    return '$dose • $frequency';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 1. Top Bar (Logo + Settings)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Sun icon and App Name
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

                  // Right side: Settings Button
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
                'Reminders',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight
                      .w400, // Slightly bolder than w300 for better reading
                  color: textDark,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 24),

              // Date selector row
              _buildDateSelector(),
              const SizedBox(height: 24),

              // 3. Floating Input Box (Turned into a button to trigger modal)
              GestureDetector(
                onTap: _openMedicineModal,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Simulated Text Input Field
                      Expanded(
                        child: Text(
                          'Schedule Medications..',
                          style: TextStyle(
                            color: textFaint,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      // Add (+) Button
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: textFieldColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Helper Text below input
              Row(
                children: [
                  Text(
                    'Try: "urgent" for Priority',
                    style: TextStyle(
                      color: textFaint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Icon(Icons.circle, size: 5, color: textFaint),
                  ),
                  Text(
                    '"tomorrow" for Date',
                    style: TextStyle(
                      color: textFaint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildRemindersForSelectedDate(),
              ),

              const SizedBox(height: 16),

              // 5. Bottom Status Text
              Text(
                '${_medicines.length} reminder${_medicines.length == 1 ? '' : 's'} saved',
                style: TextStyle(
                  color: textFaint,
                  fontSize: 16,
                  fontWeight: FontWeight.w600, // Thicker weight for visibility
                ),
              ),

              // Bottom padding
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Methods scoped correctly within the State class
  Widget _buildDateSelector() {
    // Show 7 days: 3 before, today, 3 after
    final DateTime today = DateTime.now();
    final List<DateTime> days = List.generate(
      7,
      (i) => today.add(Duration(days: i - 3)),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...days.map((date) {
            final bool isSelected = _isSameDay(date, _selectedDate);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  _dateLabel(date, today),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textDark,
                    fontSize: 15,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF8BBA91),
                backgroundColor: cardColor,
                onSelected: (_) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildRemindersForSelectedDate() {
    // Gather all reminders for the selected date
    final List<_ReminderInstance> reminders = _expandRemindersForDate(
      _selectedDate,
    );
    if (reminders.isEmpty) {
      return Center(
        child: Text(
          'No reminders for this day',
          style: TextStyle(
            color: textFaint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Group by time of day
    final Map<String, List<_ReminderInstance>> grouped = {
      'Morning': [],
      'Afternoon': [],
      'Night': [],
    };
    for (final r in reminders) {
      final int hour = r.time.hour;
      if (hour >= 5 && hour < 12) {
        grouped['Morning']!.add(r);
      } else if (hour >= 12 && hour < 18) {
        grouped['Afternoon']!.add(r);
      } else {
        grouped['Night']!.add(r);
      }
    }
    // Sort each group by time
    for (final group in grouped.values) {
      group.sort((a, b) => a.time.compareTo(b.time));
    }

    return ListView(
      children: [
        for (final period in ['Morning', 'Afternoon', 'Night'])
          if (grouped[period]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6, left: 4),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            ...grouped[period]!.map((reminder) => _buildReminderCard(reminder)),
          ],
      ],
    );
  }

  Widget _buildReminderCard(_ReminderInstance reminder) {
    final medicine = reminder.medicine;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openMedicineDetailsModal(medicine),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EFE4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  MedicineIcons.resolve(medicine.iconKey),
                  color: const Color(0xFF5C7A58),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                reminder.time.format(context),
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(medicine),
                      style: TextStyle(
                        color: textFaint,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textFaint, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  List<_ReminderInstance> _expandRemindersForDate(DateTime date) {
    final List<_ReminderInstance> result = [];
    for (final medicine in _medicines) {
      // If range is set, show for each day in range
      if (medicine.reminderStartDate != null &&
          medicine.reminderEndDate != null &&
          medicine.specificTime != null) {
        final DateTime d = DateTime(date.year, date.month, date.day);
        final DateTime start = DateTime(
          medicine.reminderStartDate!.year,
          medicine.reminderStartDate!.month,
          medicine.reminderStartDate!.day,
        );
        final DateTime end = DateTime(
          medicine.reminderEndDate!.year,
          medicine.reminderEndDate!.month,
          medicine.reminderEndDate!.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          result.add(
            _ReminderInstance(
              medicine: medicine,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      } else if (medicine.specificTime != null) {
        // Single reminder
        final DateTime d = DateTime(date.year, date.month, date.day);
        final DateTime t = DateTime(
          medicine.specificTime!.year,
          medicine.specificTime!.month,
          medicine.specificTime!.day,
        );
        if (d == t) {
          result.add(
            _ReminderInstance(
              medicine: medicine,
              time: TimeOfDay(
                hour: medicine.specificTime!.hour,
                minute: medicine.specificTime!.minute,
              ),
            ),
          );
        }
      }
    }
    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateLabel(DateTime date, DateTime today) {
    if (_isSameDay(date, today)) return 'Today';
    if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Tomorrow';
    if (_isSameDay(date, today.subtract(const Duration(days: 1))))
      return 'Yesterday';
    return '${date.month}/${date.day}';
  }
}

// Helper class defined completely outside the widget build block
class _ReminderInstance {
  final MedicineRecord medicine;
  final TimeOfDay time;
  _ReminderInstance({required this.medicine, required this.time});
}

// ---------------------------------------------------------
// LOGIN SCREEN (Updated contrast colors to match)
// ---------------------------------------------------------
class MeditrackLoginScreen extends StatelessWidget {
  const MeditrackLoginScreen({super.key});

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color buttonColor = const Color(0xFF6E765D);
  final Color iconGreenColor = const Color(0xFF87A884);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575); // Darkened for visibility

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.star_border_rounded,
                      color: iconGreenColor,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Meditrack',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login / Sign up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(obscureText: false),
                      const SizedBox(height: 20),
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(obscureText: true),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to dashboard on click
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required bool obscureText}) {
    return TextField(
      obscureText: obscureText,
      style: TextStyle(color: textDark, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: textFieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
