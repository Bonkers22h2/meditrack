// tutorials/stock_tutorial.dart
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:meditrack/tutorials/tutorial_preferences.dart';

List<GlobalKey> buildStockTutorialSteps({
  required GlobalKey titleShowcaseKey,
  required GlobalKey addMedicationShowcaseKey,
  required GlobalKey stockListShowcaseKey,
}) {
  return <GlobalKey>[
    titleShowcaseKey,
    addMedicationShowcaseKey,
    stockListShowcaseKey,
  ];
}

List<GlobalKey> buildStockModalTutorialSteps({
  required GlobalKey iconShowcaseKey,
  required GlobalKey medicineNameShowcaseKey,
  required GlobalKey lowStockShowcaseKey,
  required GlobalKey expiryDateShowcaseKey,
  required GlobalKey currentStockShowcaseKey,
  required GlobalKey saveShowcaseKey,
}) {
  return <GlobalKey>[
    iconShowcaseKey,
    medicineNameShowcaseKey,
    lowStockShowcaseKey,
    expiryDateShowcaseKey,
    currentStockShowcaseKey,
    saveShowcaseKey,
  ];
}

Future<void> startStockTutorial({
  required BuildContext context,
  required bool Function() isMounted,
  required List<GlobalKey> steps,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 250));

  if (!isMounted()) {
    return;
  }

  ShowCaseWidget.of(context).startShowCase(steps);
}

Future<void> startStockTutorialIfNeeded({
  required BuildContext context,
  required bool Function() isMounted,
  required List<GlobalKey> steps,
}) async {
  final bool hasSeenTutorial = await TutorialPreferences.hasSeen(
    TutorialPreferences.stockTutorialSeenKey,
  );

  if (hasSeenTutorial || !isMounted()) {
    return;
  }

  await startStockTutorial(
    context: context,
    isMounted: isMounted,
    steps: steps,
  );

  await TutorialPreferences.markSeen(TutorialPreferences.stockTutorialSeenKey);
}
