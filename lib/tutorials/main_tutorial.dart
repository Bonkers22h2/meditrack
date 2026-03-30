// tutorials/main_tutorial.dart
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:meditrack/tutorials/tutorial_preferences.dart';

List<GlobalKey> buildMainTutorialSteps({
  required GlobalKey roleCardShowcaseKey,
  required GlobalKey caregiverButtonShowcaseKey,
  required GlobalKey normalUserButtonShowcaseKey,
}) {
  return <GlobalKey>[
    roleCardShowcaseKey,
    caregiverButtonShowcaseKey,
    normalUserButtonShowcaseKey,
  ];
}

Future<void> startMainTutorial({
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

Future<void> startMainTutorialIfNeeded({
  required BuildContext context,
  required bool Function() isMounted,
  required List<GlobalKey> steps,
}) async {
  final bool hasSeenTutorial = await TutorialPreferences.hasSeen(
    TutorialPreferences.mainTutorialSeenKey,
  );

  if (hasSeenTutorial || !isMounted()) {
    return;
  }

  await startMainTutorial(context: context, isMounted: isMounted, steps: steps);

  await TutorialPreferences.markSeen(TutorialPreferences.mainTutorialSeenKey);
}
