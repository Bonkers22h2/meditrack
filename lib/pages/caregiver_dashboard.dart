import 'package:flutter/material.dart';
import 'package:meditrack/pages/patient_profile.dart';
import 'package:meditrack/pages/reports.dart';
import 'package:meditrack/pages/stocks.dart';
import 'package:meditrack/services/medicine_storage.dart';
import 'package:meditrack/services/patient_storage.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  int _selectedTabIndex = 0;
  List<PatientRecord> _patients = <PatientRecord>[];
  Map<String, int> _reminderCountByPatientId = <String, int>{};
  String? _selectedPatientId;
  bool _isLoading = true;

  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF757575);
  final Color textFaint = const Color(0xFF8B9084);
  final Color actionColor = const Color(0xFF6E765D);

  InputDecoration _patientFieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F8F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: actionColor.withValues(alpha: 0.5)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String _patientIdFor(PatientRecord patient) {
    return patient.createdAt.toIso8601String();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait<void>(<Future<void>>[
      _loadPatients(),
      _loadReminderCounts(),
    ]);
  }

  Future<void> _loadPatients() async {
    final List<PatientRecord> patients = await PatientStorage.loadPatients();
    if (!mounted) {
      return;
    }
    setState(() {
      _patients = patients;
      if (_selectedPatientId == null ||
          !_patients.any(
            (PatientRecord patient) =>
                _patientIdFor(patient) == _selectedPatientId,
          )) {
        _selectedPatientId = patients.isNotEmpty
            ? _patientIdFor(patients.first)
            : null;
      }
      _isLoading = false;
    });
  }

  Future<void> _loadReminderCounts() async {
    final List<MedicineRecord> allRecords =
        await MedicineStorage.loadMedicines();
    final Map<String, int> counts = <String, int>{};

    for (final MedicineRecord record in allRecords) {
      final String? patientId = record.patientId;
      if (patientId == null || patientId.isEmpty) {
        continue;
      }
      counts[patientId] = (counts[patientId] ?? 0) + 1;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _reminderCountByPatientId = counts;
    });
  }

  Future<void> _showAddPatientDialog() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String fullName = '';
    String ageText = '';
    String relationship = '';
    String emergencyContactNumber = '';

    final PatientRecord? patient = await showDialog<PatientRecord>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          title: const Text('Add Patient'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: _patientFieldDecoration(
                        label: 'Full Name',
                        hint: 'Enter full name',
                        icon: Icons.badge_outlined,
                      ),
                      onChanged: (String value) {
                        fullName = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: _patientFieldDecoration(
                        label: 'Age',
                        hint: 'Enter age',
                        icon: Icons.cake_outlined,
                      ),
                      onChanged: (String value) {
                        ageText = value;
                      },
                      validator: (String? value) {
                        final int? age = int.tryParse((value ?? '').trim());
                        if (age == null || age <= 0) {
                          return 'Enter a valid age';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      textCapitalization: TextCapitalization.words,
                      decoration: _patientFieldDecoration(
                        label: 'Relationship',
                        hint: 'e.g. Parent, Spouse',
                        icon: Icons.people_outline,
                      ),
                      onChanged: (String value) {
                        relationship = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Relationship is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      keyboardType: TextInputType.phone,
                      decoration: _patientFieldDecoration(
                        label: 'Emergency Contact Number',
                        hint: 'Enter contact number',
                        icon: Icons.phone_outlined,
                      ),
                      onChanged: (String value) {
                        emergencyContactNumber = value;
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Emergency contact is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                Navigator.of(context).pop(
                  PatientRecord(
                    fullName: fullName.trim(),
                    age: int.parse(ageText.trim()),
                    relationship: relationship.trim(),
                    emergencyContactNumber: emergencyContactNumber.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (patient == null) {
      return;
    }

    await PatientStorage.addPatient(patient);
    if (!mounted) {
      return;
    }

    setState(() {
      _patients.add(patient);
      if (_selectedPatientId == null) {
        _selectedPatientId = _patientIdFor(patient);
      }
    });
  }

  Future<void> _openPatientProfile(PatientRecord patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PatientProfileScreen(patient: patient),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadReminderCounts();
  }

  String? _selectedPatientName() {
    if (_selectedPatientId == null) {
      return null;
    }

    for (final PatientRecord patient in _patients) {
      if (_patientIdFor(patient) == _selectedPatientId) {
        return patient.fullName;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Widget currentTab = _selectedTabIndex == 0
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                            tooltip: 'Help Center',
                            icon: Icon(
                              Icons.help_outline,
                              color: textLight,
                              size: 24,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Caregiver help center is coming soon.',
                                  ),
                                ),
                              );
                            },
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
                            tooltip: 'Caregiver options',
                            icon: Icon(
                              Icons.settings_outlined,
                              color: textLight,
                              size: 24,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Caregiver settings will be added soon.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Caregiver Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor patients and quickly add people you care for.',
                  style: TextStyle(
                    color: textFaint,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddPatientDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, color: textDark),
                      const SizedBox(width: 10),
                      Text(
                        '${_patients.length} patient${_patients.length == 1 ? '' : 's'} under care',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Patients',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _patients.isEmpty
                      ? Center(
                          child: Text(
                            'No patients yet. Tap Add Patient to begin.',
                            style: TextStyle(
                              color: textFaint,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _patients.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final PatientRecord patient = _patients[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openPatientProfile(patient),
                              child: _buildPatientCard(patient),
                            );
                          },
                        ),
                ),
              ],
            ),
          )
        : _selectedTabIndex == 1
        ? const StockScreen()
        : _buildReportsTab();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: currentTab),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (int index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        backgroundColor: cardColor,
        selectedItemColor: textDark,
        unselectedItemColor: textFaint,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Stocks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patients.isEmpty) {
      return Center(
        child: Text(
          'Add a patient to view caregiver reports.',
          style: TextStyle(
            color: textFaint,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final String selectedPatientId =
        _selectedPatientId ?? _patientIdFor(_patients.first);

    final String? selectedPatientName = _selectedPatientName();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Caregiver Reports',
            style: TextStyle(
              color: textDark,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch between patients to review adherence and missed doses.',
            style: TextStyle(
              color: textFaint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: selectedPatientId,
                decoration: const InputDecoration(border: InputBorder.none),
                items: _patients
                    .map(
                      (PatientRecord patient) => DropdownMenuItem<String>(
                        value: _patientIdFor(patient),
                        child: Text(patient.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedPatientId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReportsScreen(
              key: ValueKey<String?>(selectedPatientId),
              patientId: selectedPatientId,
              patientLabel: selectedPatientName,
              takenRemindersStorageKey: 'patient_taken_reminders_v1',
              title: 'Adherence Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(PatientRecord patient) {
    final String patientId = _patientIdFor(patient);
    final int reminderCount = _reminderCountByPatientId[patientId] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EFE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF5C7A58),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                patient.fullName,
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${patient.age} yrs',
                style: TextStyle(
                  color: textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              patient.relationship,
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EFE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$reminderCount reminder${reminderCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: textLight, size: 22),
        ],
      ),
    );
  }
}
