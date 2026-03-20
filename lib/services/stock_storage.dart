import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class StockRecord {
  StockRecord({
    required this.medicineName,
    required this.currentStock,
    required this.lowStockThreshold,
    this.expiryDate,
    required this.createdAt,
  });

  final String medicineName;
  final int currentStock;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final DateTime createdAt;

  factory StockRecord.fromJson(Map<String, dynamic> json) {
    return StockRecord(
      medicineName: (json['medicineName'] as String?) ?? '',
      currentStock: (json['currentStock'] as int?) ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as int?) ?? 0,
      expiryDate: _tryParseDateTime(json['expiryDate'] as String?),
      createdAt:
          _tryParseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'medicineName': medicineName,
      'currentStock': currentStock,
      'lowStockThreshold': lowStockThreshold,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isLowStock => currentStock <= lowStockThreshold;

  bool get isRefillSoon => !isLowStock && currentStock <= lowStockThreshold + 3;

  bool get isExpiringSoon {
    if (expiryDate == null) {
      return false;
    }

    final DateTime today = DateTime.now();
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime normalizedExpiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );
    final int daysLeft = normalizedExpiry.difference(normalizedToday).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class StockStorage {
  static const String _storageKey = 'saved_stocks_v1';

  static Future<List<StockRecord>> loadStocks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <StockRecord>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StockRecord.fromJson)
        .toList();
  }

  static Future<void> saveStocks(List<StockRecord> stocks) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      stocks.map((StockRecord record) => record.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> addStock(StockRecord stock) async {
    final List<StockRecord> stocks = await loadStocks();
    stocks.add(stock);
    await saveStocks(stocks);
  }

  static Future<void> upsertStock(StockRecord updatedStock) async {
    final List<StockRecord> stocks = await loadStocks();
    final int index = stocks.indexWhere(
      (StockRecord stock) =>
          stock.createdAt.isAtSameMomentAs(updatedStock.createdAt),
    );

    if (index >= 0) {
      stocks[index] = updatedStock;
    } else {
      stocks.add(updatedStock);
    }

    await saveStocks(stocks);
  }

  static Future<void> deleteStock(StockRecord stockToDelete) async {
    final List<StockRecord> stocks = await loadStocks();
    stocks.removeWhere(
      (StockRecord stock) =>
          stock.createdAt.isAtSameMomentAs(stockToDelete.createdAt),
    );
    await saveStocks(stocks);
  }

  static Future<bool> deductStockForMedicine({
    required String medicineName,
    required int amount,
  }) async {
    if (amount <= 0) {
      return false;
    }

    final String normalizedName = medicineName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return false;
    }

    final List<StockRecord> stocks = await loadStocks();
    final int index = stocks.indexWhere(
      (StockRecord stock) =>
          stock.medicineName.trim().toLowerCase() == normalizedName,
    );

    if (index < 0) {
      return false;
    }

    final StockRecord existing = stocks[index];
    final int updatedStock = max(0, existing.currentStock - amount);
    stocks[index] = StockRecord(
      medicineName: existing.medicineName,
      currentStock: updatedStock,
      lowStockThreshold: existing.lowStockThreshold,
      expiryDate: existing.expiryDate,
      createdAt: existing.createdAt,
    );

    await saveStocks(stocks);
    return true;
  }
}
