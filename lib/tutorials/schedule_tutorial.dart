// tutorials/schedule_tutorial.dart
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:meditrack/tutorials/tutorial_preferences.dart';

typedef ScheduleTutorialContinuation = Future<void> Function();

GlobalKey? _pendingScheduleTutorialIntroKey;
ScheduleTutorialContinuation? _pendingScheduleTutorialContinuation;

void prepareScheduleTutorialContinuation({
  required GlobalKey handoffStepKey,
  required ScheduleTutorialContinuation continuation,
}) {
  _pendingScheduleTutorialIntroKey = handoffStepKey;
  _pendingScheduleTutorialContinuation = continuation;
}

void clearScheduleTutorialContinuation() {
  _pendingScheduleTutorialIntroKey = null;
  _pendingScheduleTutorialContinuation = null;
}

Future<void> handleScheduleTutorialShowcaseComplete(
  GlobalKey? completedKey,
) async {
  if (completedKey == null ||
      completedKey != _pendingScheduleTutorialIntroKey) {
    return;
  }

  final ScheduleTutorialContinuation? continuation =
      _pendingScheduleTutorialContinuation;
  clearScheduleTutorialContinuation();

  if (continuation != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      continuation();
    });
  }
}

List<GlobalKey> buildScheduleTutorialIntroSteps({
  required GlobalKey scheduleDetailsShowcaseKey,
}) {
  return <GlobalKey>[scheduleDetailsShowcaseKey];
}

List<GlobalKey> buildScheduleTutorialSteps({
  required GlobalKey scheduleIconShowcaseKey,
  required GlobalKey scheduleDoseShowcaseKey,
  required GlobalKey scheduleFrequencyShowcaseKey,
  required GlobalKey scheduleRangeShowcaseKey,
  required GlobalKey scheduleSaveShowcaseKey,
}) {
  return <GlobalKey>[
    scheduleIconShowcaseKey,
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
  required List<GlobalKey> introSteps,
  required List<GlobalKey> dosageSteps,
  int dosageTabIndex = 1,
}) async {
  if (currentTabIndex != 0) {
    goToTab(0);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  if (!isMounted()) {
    return;
  }

  prepareScheduleTutorialContinuation(
    handoffStepKey: introSteps.last,
    continuation: () async {
      if (!isMounted()) {
        return;
      }

      goToTab(dosageTabIndex);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!isMounted()) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!isMounted()) {
        return;
      }

      ShowCaseWidget.of(context).startShowCase(dosageSteps);
    },
  );

  await Future<void>.delayed(const Duration(milliseconds: 200));

  if (!isMounted()) {
    return;
  }

  ShowCaseWidget.of(context).startShowCase(introSteps);
}

Future<void> startScheduleTutorialIfNeeded({
  required BuildContext context,
  required bool Function() isMounted,
  required int currentTabIndex,
  required void Function(int index) goToTab,
  required List<GlobalKey> introSteps,
  required List<GlobalKey> dosageSteps,
}) async {
  final bool hasSeenTutorial = await TutorialPreferences.hasSeen(
    TutorialPreferences.scheduleTutorialSeenKey,
  );

  if (hasSeenTutorial || !isMounted()) {
    return;
  }

  await startScheduleTutorial(
    context: context,
    isMounted: isMounted,
    currentTabIndex: currentTabIndex,
    goToTab: goToTab,
    introSteps: introSteps,
    dosageSteps: dosageSteps,
  );

  await TutorialPreferences.markSeen(
    TutorialPreferences.scheduleTutorialSeenKey,
  );
}
