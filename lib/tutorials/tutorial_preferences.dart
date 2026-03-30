// tutorials/tutorial_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

class TutorialPreferences {
  TutorialPreferences._();

  static const String dashboardTutorialSeenKey = 'dashboard_tutorial_seen_v1';
  static const String loginIntroSeenKey = 'login_intro_popup_seen_v1';
  static const String firstLoginSectionsSeenKey =
      'first_login_sections_popup_seen_v1';
  static const String scheduleTutorialSeenKey = 'schedule_tutorial_seen_v1';
  static const String stockTutorialSeenKey = 'stock_tutorial_seen_v1';
  static const String mainTutorialSeenKey = 'main_tutorial_seen_v1';

  static const List<String> allTutorialSeenKeys = <String>[
    dashboardTutorialSeenKey,
    loginIntroSeenKey,
    firstLoginSectionsSeenKey,
    scheduleTutorialSeenKey,
    stockTutorialSeenKey,
    mainTutorialSeenKey,
  ];

  static Future<bool> hasSeen(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> markSeen(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  static Future<void> resetSeen(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> resetAllSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String key in allTutorialSeenKeys) {
      await prefs.remove(key);
    }
  }
}
