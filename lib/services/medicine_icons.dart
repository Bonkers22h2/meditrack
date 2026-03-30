// services/medicine_icons.dart
import 'package:flutter/material.dart';

class MedicineIconOption {
  const MedicineIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class MedicineIcons {
  static const String defaultIconKey = 'pill';

  static const List<MedicineIconOption> options = <MedicineIconOption>[
    MedicineIconOption(
      key: 'pill',
      label: 'Pill',
      icon: Icons.medication_outlined,
    ),
    MedicineIconOption(key: 'capsule', label: 'Capsule', icon: Icons.vaccines),
    MedicineIconOption(
      key: 'syringe',
      label: 'Syringe',
      icon: Icons.vaccines_outlined,
    ),
    MedicineIconOption(
      key: 'liquid',
      label: 'Liquid',
      icon: Icons.local_drink_outlined,
    ),
    MedicineIconOption(
      key: 'heart',
      label: 'Heart',
      icon: Icons.favorite_outline,
    ),
    MedicineIconOption(
      key: 'timer',
      label: 'Timer',
      icon: Icons.timer_outlined,
    ),
    MedicineIconOption(
      key: 'sun',
      label: 'Morning',
      icon: Icons.wb_sunny_outlined,
    ),
    MedicineIconOption(
      key: 'moon',
      label: 'Night',
      icon: Icons.dark_mode_outlined,
    ),
  ];

  static IconData resolve(String? key) {
    for (final MedicineIconOption option in options) {
      if (option.key == key) {
        return option.icon;
      }
    }
    return options.first.icon;
  }
}
