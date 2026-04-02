// services/medicine_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:meditrack/services/medicine_icons.dart';

class MedicineRecord {
  MedicineRecord({
    this.iconKey = MedicineIcons.defaultIconKey,
    this.patientId,
    required this.name,
    required this.doseAmount,
    required this.frequency,
    this.specificTime,
    this.reminderStartDate,
    this.reminderEndDate,
    required this.createdAt,
  });

  final String iconKey;
  final String? patientId;
  final String name;
  final String doseAmount;
  final String frequency;
  final DateTime? specificTime;
  final DateTime? reminderStartDate;
  final DateTime? reminderEndDate;
  final DateTime createdAt;

  factory MedicineRecord.fromJson(Map<String, dynamic> json) {
    return MedicineRecord(
      iconKey: (json['iconKey'] as String?) ?? MedicineIcons.defaultIconKey,
      patientId: json['patientId'] as String?,
      name: (json['name'] as String?) ?? '',
      doseAmount: (json['doseAmount'] as String?) ?? '',
      frequency: (json['frequency'] as String?) ?? '',
      specificTime: _tryParseDateTime(json['specificTime'] as String?),
      reminderStartDate: _tryParseDateTime(
        json['reminderStartDate'] as String?,
      ),
      reminderEndDate: _tryParseDateTime(json['reminderEndDate'] as String?),
      createdAt:
          _tryParseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'iconKey': iconKey,
      'patientId': patientId,
      'name': name,
      'doseAmount': doseAmount,
      'frequency': frequency,
      'specificTime': specificTime?.toIso8601String(),
      'reminderStartDate': reminderStartDate?.toIso8601String(),
      'reminderEndDate': reminderEndDate?.toIso8601String(),
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

class MedicineStorage {
  static const String _storageKey = 'saved_medicines_v1';

  static Future<List<MedicineRecord>> loadMedicines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <MedicineRecord>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MedicineRecord.fromJson)
        .toList();
  }

  static Future<void> saveMedicines(List<MedicineRecord> medicines) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      medicines.map((MedicineRecord record) => record.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> addMedicine(MedicineRecord medicine) async {
    final List<MedicineRecord> medicines = await loadMedicines();
    medicines.add(medicine);
    await saveMedicines(medicines);
  }

  static Future<void> updateMedicine(MedicineRecord updatedMedicine) async {
    final List<MedicineRecord> medicines = await loadMedicines();
    final int index = medicines.indexWhere(
      (MedicineRecord medicine) =>
          medicine.createdAt.isAtSameMomentAs(updatedMedicine.createdAt),
    );

    if (index >= 0) {
      medicines[index] = updatedMedicine;
    } else {
      medicines.add(updatedMedicine);
    }

    await saveMedicines(medicines);
  }

  static Future<void> deleteMedicine(MedicineRecord medicineToDelete) async {
    final List<MedicineRecord> medicines = await loadMedicines();
    medicines.removeWhere(
      (MedicineRecord medicine) =>
          medicine.createdAt.isAtSameMomentAs(medicineToDelete.createdAt),
    );
    await saveMedicines(medicines);
  }

  static Future<void> clearMedicines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static Future<void> addMedicines(List<MedicineRecord> newRecords) async {
    final List<MedicineRecord> medicines = await loadMedicines();
    medicines.addAll(newRecords);
    await saveMedicines(medicines);
  }
}
