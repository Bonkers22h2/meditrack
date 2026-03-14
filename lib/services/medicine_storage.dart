import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MedicineRecord {
  MedicineRecord({
    required this.name,
    required this.strength,
    required this.details,
    required this.doseAmount,
    required this.frequency,
    this.specificTime,
    this.currentStock,
    this.alarmStock,
    this.expirationDate,
    required this.createdAt,
  });

  final String name;
  final String strength;
  final String details;
  final String doseAmount;
  final String frequency;
  final DateTime? specificTime;
  final int? currentStock;
  final int? alarmStock;
  final DateTime? expirationDate;
  final DateTime createdAt;

  factory MedicineRecord.fromJson(Map<String, dynamic> json) {
    return MedicineRecord(
      name: (json['name'] as String?) ?? '',
      strength: (json['strength'] as String?) ?? '',
      details: (json['details'] as String?) ?? '',
      doseAmount: (json['doseAmount'] as String?) ?? '',
      frequency: (json['frequency'] as String?) ?? '',
      specificTime: _tryParseDateTime(json['specificTime'] as String?),
      currentStock: json['currentStock'] as int?,
      alarmStock: json['alarmStock'] as int?,
      expirationDate: _tryParseDateTime(json['expirationDate'] as String?),
      createdAt:
          _tryParseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'strength': strength,
      'details': details,
      'doseAmount': doseAmount,
      'frequency': frequency,
      'specificTime': specificTime?.toIso8601String(),
      'currentStock': currentStock,
      'alarmStock': alarmStock,
      'expirationDate': expirationDate?.toIso8601String(),
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

  static Future<void> clearMedicines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
