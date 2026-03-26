import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:meditrack/tutorials/tutorial_preferences.dart';

List<GlobalKey> buildScheduleTutorialSteps({
  required GlobalKey medicineIconShowcaseKey,
  required GlobalKey scheduleDoseShowcaseKey,
  required GlobalKey scheduleFrequencyShowcaseKey,
  required GlobalKey scheduleRangeShowcaseKey,
  required GlobalKey scheduleSaveShowcaseKey,
}) {
  return <GlobalKey>[
    medicineIconShowcaseKey,
    scheduleDoseShowcaseKey,
    scheduleFrequencyShowcaseKey,
    scheduleRangeShowcaseKey,
    scheduleSaveShowcaseKey,
  ];
}

Future<void> startScheduleTutorial({
  required BuildContext context,
  required bool Function() isMounted,
  required int currentTabIndex,
  required void Function(int index) goToTab,
  required List<GlobalKey> steps,
  int dosageTabIndex = 1,
}) async {
  if (currentTabIndex != dosageTabIndex) {
    goToTab(dosageTabIndex);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  if (!isMounted()) {
    return;
  }

  await Future<void>.delayed(const Duration(milliseconds: 200));

  if (!isMounted()) {
    return;
  }

  ShowCaseWidget.of(context).startShowCase(steps);
}

Future<void> startScheduleTutorialIfNeeded({
  required BuildContext context,
  required bool Function() isMounted,
  required int currentTabIndex,
  required void Function(int index) goToTab,
  required List<GlobalKey> steps,
}) async {
  final bool hasSeenTutorial =
      await TutorialPreferences.hasSeen(TutorialPreferences.scheduleTutorialSeenKey);

  if (hasSeenTutorial || !isMounted()) {
    return;
  }

  await startScheduleTutorial(
    context: context,
    isMounted: isMounted,
    currentTabIndex: currentTabIndex,
    goToTab: goToTab,
    steps: steps,
  );

  await TutorialPreferences.markSeen(TutorialPreferences.scheduleTutorialSeenKey);
}