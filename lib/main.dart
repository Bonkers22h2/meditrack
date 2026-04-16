// main.dart
import 'package:flutter/material.dart';
import 'package:meditrack/pages/caregiver_dashboard.dart';
import 'package:meditrack/pages/dashboard.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/tutorials/main_tutorial.dart';
import 'package:meditrack/tutorials/schedule_tutorial.dart';
import 'package:meditrack/widgets/intro_popup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MeditrackApp());
}

const String selectedUserRoleKey = 'selected_user_role_v1';
const String caregiverRole = 'caregiver';
const String normalUserRole = 'normal_user';

class MeditrackApp extends StatelessWidget {
  const MeditrackApp({super.key});

  static const String startupRoute = '/startup';
  static const String loginRoute = '/login';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditrack',
      debugShowCheckedModeBanner: false,
      routes: <String, WidgetBuilder>{
        startupRoute: (BuildContext context) => const AppStartupScreen(),
        loginRoute: (BuildContext context) => const MeditrackLoginScreen(),
      },
      builder: (BuildContext context, Widget? child) {
        return ShowCaseWidget(
          onComplete: (int? index, GlobalKey key) {
            handleScheduleTutorialShowcaseComplete(key);
          },
          onFinish: clearScheduleTutorialContinuation,
          builder: (BuildContext context) => child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily:
            'Roboto', // Default flutter font, resembles the clean sans-serif in the image
      ),
      home: const AppStartupScreen(),
    );
  }
}

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    _routeFromSavedRole();
  }

  Future<void> _routeFromSavedRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? selectedRole = prefs.getString(selectedUserRoleKey);

    if (!mounted) {
      return;
    }

    final Widget destination;
    if (selectedRole == caregiverRole) {
      destination = const CaregiverDashboardScreen();
    } else if (selectedRole == normalUserRole) {
      destination = const DashboardScreen(showFirstLoginSectionsPopup: true);
    } else {
      destination = const MeditrackLoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (BuildContext context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class MeditrackLoginScreen extends StatefulWidget {
  const MeditrackLoginScreen({super.key});

  @override
  State<MeditrackLoginScreen> createState() => _MeditrackLoginScreenState();
}

class _MeditrackLoginScreenState extends State<MeditrackLoginScreen> {
  static const String _loginIntroSeenKey = 'login_intro_popup_seen_v1';

  final GlobalKey _roleCardShowcaseKey = GlobalKey();
  final GlobalKey _caregiverButtonShowcaseKey = GlobalKey();
  final GlobalKey _normalUserButtonShowcaseKey = GlobalKey();

  /// This is the content for the introductory popup that appears on the first launch of the app.
  final List<IntroPopupPage> _introPages = const <IntroPopupPage>[
    IntroPopupPage(
      title: 'Welcome To MediTrack!',
      description:
          'Our goal is to make managing your medications as simple as possible. Instead of typing long medical names, we use icons, colors, and simple taps to help you stay on track. This short guide will walk you through the first few steps, so you feel comfortable using the app.',
    ),
    IntroPopupPage(
      title: 'Choose Your Role',
      subtitle: 'Caregiver or normal user?',
      description:
          'On the first screen, select whether you are a caregiver or a normal user taking maintenance medication. This helps open the right dashboard for your role.',
      useQuoteBlockForIntroText: true,
      steps: <String>[
        'Tap “Caregiver” if you are assisting someone else.',
        'Tap “Normal User (Maintenance Medication)” if the medications are yours.',
        'You will be sent directly to the correct dashboard.',
      ],
      note:
          'You can update this flow later when full account features are added.',
    ),
    IntroPopupPage(
      title: 'Adding a Family Member or Caregiver',
      description:
          'You are the main user. If you have a family member or caregiver who helps you manage your meds, you can invite them in this app to help you.',
      action:
          'After creating an account. Tap “Invite Caregiver” and enter their email address. The app will send them an invitation.',
      note:
          'Inviting a caregiver allows them to see if you missed a dose, but they cannot change your settings or see your password.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await _showIntroPopupIfNeeded();
      await _startMainTutorialIfNeeded();
    });
  }

  Future<void> _startMainTutorialIfNeeded() async {
    await startMainTutorialIfNeeded(
      context: context,
      isMounted: () => mounted,
      steps: buildMainTutorialSteps(
        roleCardShowcaseKey: _roleCardShowcaseKey,
        caregiverButtonShowcaseKey: _caregiverButtonShowcaseKey,
        normalUserButtonShowcaseKey: _normalUserButtonShowcaseKey,
      ),
    );
  }

  /// Show intro popup for first time users.
  Future<void> _showIntroPopupIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasSeenIntro = prefs.getBool(_loginIntroSeenKey) ?? false;

    if (hasSeenIntro || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return IntroPopupDialog(pages: _introPages);
      },
    );

    await prefs.setBool(_loginIntroSeenKey, true);
  }

  // Custom Colors extracted from the image
  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color buttonColor = const Color(0xFF6E765D);
  final Color iconGreenColor = const Color(0xFF87A884);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF9E9E9E);

  Future<void> _openUserDashboard() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedUserRoleKey, normalUserRole);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AppStartupScreen(),
      ),
    );
  }

  Future<void> _openCaregiverDashboard() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedUserRoleKey, caregiverRole);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AppStartupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // 1. Logo Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.star_border_rounded,
                      color: iconGreenColor,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Title
                Text(
                  'Meditrack',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // 3. Subtitle
                Text(
                  'Who are you?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textLight,
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Role Selection Card
                Showcase(
                  key: _roleCardShowcaseKey,
                  title: 'Choose your role',
                  description:
                      'Pick caregiver if you assist someone else, or normal user if you take maintenance medication.',
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select your role to continue',
                          style: TextStyle(
                            fontSize: 18,
                            color: textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'If you are helping someone else, choose caregiver. If you are taking maintenance medication, choose normal user.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textLight,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 5. Caregiver Button
                Showcase(
                  key: _caregiverButtonShowcaseKey,
                  title: 'Caregiver dashboard',
                  description:
                      'Tap here if you are monitoring someone else\'s medication routine.',
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _openCaregiverDashboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Caregiver',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 6. Normal User Button
                Showcase(
                  key: _normalUserButtonShowcaseKey,
                  title: 'Normal user dashboard',
                  description:
                      'Tap here if you are taking maintenance medication and tracking your own reminders.',
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _openUserDashboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Normal User (Maintenance Medication)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
