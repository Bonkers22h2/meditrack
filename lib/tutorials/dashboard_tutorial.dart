import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:meditrack/tutorials/tutorial_preferences.dart';

enum DashboardHelpSection {
  dashboardOverview,
  addSchedule,
  manageStocks,
}

List<GlobalKey> buildDashboardTutorialSteps({
  required GlobalKey titleShowcaseKey,
  required GlobalKey dateSelectorShowcaseKey,
  required GlobalKey addReminderShowcaseKey,
  required GlobalKey stockShowcaseKey,
}) {
  return <GlobalKey>[
    titleShowcaseKey,
    dateSelectorShowcaseKey,
    addReminderShowcaseKey,
    stockShowcaseKey,
  ];
}

Future<void> startDashboardTutorial({
  required BuildContext context,
  required bool Function() isMounted,
  required List<GlobalKey> steps,
}) async {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) {
      return;
    }

    ShowCaseWidget.of(context).startShowCase(steps);
  });
}

Future<void> startDashboardTutorialIfNeeded({
  required BuildContext context,
  required bool Function() isMounted,
  required List<GlobalKey> steps,
}) async {
  final bool hasSeenTutorial =
      await TutorialPreferences.hasSeen(TutorialPreferences.dashboardTutorialSeenKey);

  if (hasSeenTutorial || !isMounted()) {
    return;
  }

  await startDashboardTutorial(
    context: context,
    isMounted: isMounted,
    steps: steps,
  );

  await TutorialPreferences.markSeen(TutorialPreferences.dashboardTutorialSeenKey);
}

String dashboardHelpSectionTitle(DashboardHelpSection section) {
  switch (section) {
    case DashboardHelpSection.dashboardOverview:
      return 'Dashboard Overview';
    case DashboardHelpSection.addSchedule:
      return 'Add a Medication Schedule';
    case DashboardHelpSection.manageStocks:
      return 'Manage Medication Stocks';
  }
}

Future<DashboardHelpSection?> showDashboardHelpSectionsPopup({
  required BuildContext context,
  required Color textDark,
  required Color textLight,
  required Color textFaint,
}) {
  return showDialog<DashboardHelpSection>(
    context: context,
    builder: (BuildContext context) {
      final List<DashboardHelpSection> sections = DashboardHelpSection.values;

      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help Sections',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: sections.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DashboardHelpSection section = sections[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          dashboardHelpSectionTitle(section),
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: textLight,
                        ),
                        onTap: () {
                          Navigator.of(context).pop(section);
                        },
                      );
                    },
                    separatorBuilder: (_, __) {
                      return Divider(
                        color: textFaint.withOpacity(0.25),
                        height: 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}