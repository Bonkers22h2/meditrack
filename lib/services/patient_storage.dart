import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PatientRecord {
  PatientRecord({
    required this.fullName,
    required this.age,
    required this.relationship,
    required this.emergencyContactNumber,
    required this.createdAt,
  });

  final String fullName;
  final int age;
  final String relationship;
  final String emergencyContactNumber;
  final DateTime createdAt;

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      fullName: (json['fullName'] as String?) ?? '',
      age: (json['age'] as int?) ?? 0,
      relationship: (json['relationship'] as String?) ?? '',
      emergencyContactNumber: (json['emergencyContactNumber'] as String?) ?? '',
      createdAt:
          _tryParseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fullName': fullName,
      'age': age,
      'relationship': relationship,
      'emergencyContactNumber': emergencyContactNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class PatientStorage {
  static const String _storageKey = 'saved_patients_v1';

  static Future<List<PatientRecord>> loadPatients() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <PatientRecord>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PatientRecord.fromJson)
        .toList();
  }

  static Future<void> savePatients(List<PatientRecord> patients) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      patients.map((PatientRecord record) => record.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> addPatient(PatientRecord patient) async {
    final List<PatientRecord> patients = await loadPatients();
    patients.add(patient);
    await savePatients(patients);
  }

  static Future<void> updatePatient(PatientRecord updatedPatient) async {
    final List<PatientRecord> patients = await loadPatients();
    final int index = patients.indexWhere(
      (PatientRecord patient) =>
          patient.createdAt.isAtSameMomentAs(updatedPatient.createdAt),
    );

    if (index >= 0) {
      patients[index] = updatedPatient;
      await savePatients(patients);
    }
  }

  static Future<void> deletePatient(PatientRecord patientToDelete) async {
    final List<PatientRecord> patients = await loadPatients();
    patients.removeWhere(
      (PatientRecord patient) =>
          patient.createdAt.isAtSameMomentAs(patientToDelete.createdAt),
    );
    await savePatients(patients);
  }
}
