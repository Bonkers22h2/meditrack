import 'package:flutter/material.dart';
import 'package:meditrack/pages/dashboard.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MeditrackApp());
}

class MeditrackApp extends StatelessWidget {
  const MeditrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditrack Login',
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        return ShowCaseWidget(
          builder: (BuildContext context) => child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily:
            'Roboto', // Default flutter font, resembles the clean sans-serif in the image
      ),
      home: const MeditrackLoginScreen(),
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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /**
   * Intro Popup Pages 
   * This is the content for the introductory popup that appears on the first login. 
   * Each page has a title, description, and optional steps or notes to guide the user 
   * through the initial setup of the app.
   */
  final List<_IntroPopupPage> _introPages = const <_IntroPopupPage>[
    _IntroPopupPage(
      title: 'Welcome To MediTrack!',
      description:
          'Our goal is to make managing your medications as simple as possible. Instead of typing long medical names, we use icons, colors, and simple taps to help you stay on track. This short guide will walk you through the first few steps, so you feel comfortable using the app.',
    ),
    _IntroPopupPage(
      title: 'Create Your Account',
      subtitle: 'Why do I need an account?',
      description:
          'Your account helps us keep your medicine information private and secure. It lets you share access with a family member if you want, and makes sure your reminders are saved even if you switch phones. All your information is private and can only be accessed by you and your caregivers.',
      useQuoteBlockForIntroText: true,
      steps: <String>[
        'Tap “Register”.',
        'Enter your Email Address or Phone Number.',
        'Enter the one-time code (OTP) sent to verify your identity.',
        'Enter a secure password.',
      ],
      note:
          'If you forget your password later, tap "Forgot Password?" on the login screen to reset it by email or SMS.',
    ),
    _IntroPopupPage(
      title: 'Adding a Family Member or Caregiver',
      description:
          'You are the main user. If you have a family member or caregiver who helps you manage your meds, you can invite them in this app to help you.',
      action: 'After creating an account. Tap “Invite Caregiver” and enter their email address. The app will send them an invitation.',
      note:
          'Inviting a caregiver allows them to see if you missed a dose, but they cannot change your settings or see your password.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _showIntroPopupIfNeeded();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Show intro popup for first time users
  Future<void> _showIntroPopupIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasSeenIntro = prefs.getBool(_loginIntroSeenKey) ?? false;

    if (hasSeenIntro || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _IntroPopupDialog(pages: _introPages);
        },
      );

      await prefs.setBool(_loginIntroSeenKey, true);
    });
  }

  // Custom Colors extracted from the image
  final Color backgroundColor = const Color(0xFFF4F5F0);
  final Color cardColor = Colors.white;
  final Color textFieldColor = const Color(0xFFE8E8E2);
  final Color buttonColor = const Color(0xFF6E765D);
  final Color iconGreenColor = const Color(0xFF87A884);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF9E9E9E);

  void _handleLogin() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email == 'user' && password == 'user') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DashboardScreen(),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Invalid email or password')),
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
                  'Login / Sign up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textLight,
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Input Card
                Container(
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
                      // Email Label
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Email TextField
                      _buildTextField(
                        obscureText: false,
                        controller: _emailController,
                      ),

                      const SizedBox(height: 20),

                      // Password Label
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          color: textDark,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Password TextField
                      _buildTextField(
                        obscureText: true,
                        controller: _passwordController,
                      ),

                      const SizedBox(height: 16),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: textLight,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 5. Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
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
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
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

  // Helper method to build the rounded, filled text fields
  Widget _buildTextField({
    required bool obscureText,
    required TextEditingController controller,
  }) {
    return TextField(
      obscureText: obscureText,
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: textFieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none, // Removes the border completely
        ),
      ),
    );
  }
}

class _IntroPopupPage {
  final String title;
  final String? subtitle;
  final String description;
  final bool useQuoteBlockForIntroText;
  final List<String> steps;
  final String? action;
  final String? extra;
  final String? note;

  const _IntroPopupPage({
    required this.title,
    this.subtitle,
    required this.description,
    this.useQuoteBlockForIntroText = false,
    this.steps = const <String>[],
    this.action,
    this.extra,
    this.note,
  });
}

class _IntroPopupDialog extends StatefulWidget {
  final List<_IntroPopupPage> pages;

  const _IntroPopupDialog({required this.pages});

  @override
  State<_IntroPopupDialog> createState() => _IntroPopupDialogState();
}

class _IntroPopupDialogState extends State<_IntroPopupDialog> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToNext() async {
    if (_currentPage == widget.pages.length - 1) {
      Navigator.of(context).pop();
      return;
    }

    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToPrevious() async {
    if (_currentPage == 0) {
      return;
    }

    await _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.pages.length,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _IntroPopupPage page = widget.pages[index];

                    return LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      page.title,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (page.useQuoteBlockForIntroText) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F8F4),
                                        borderRadius: BorderRadius.circular(10),
                                        border: const Border(
                                          left: BorderSide(
                                            color: Color(0xFF6E765D),
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (page.subtitle != null) ...[
                                            Text(
                                              page.subtitle!,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontStyle: FontStyle.italic,
                                                    color: const Color(
                                                      0xFF1A1A1A,
                                                    ),
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Text(
                                            page.description,
                                            textAlign: TextAlign.justify,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  height: 1.45,
                                                  color: const Color(
                                                    0xFF565656,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    if (page.subtitle != null) ...[
                                      Text(
                                        page.subtitle!,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: const Color(0xFF1A1A1A),
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Text(
                                      page.description,
                                      textAlign: TextAlign.justify,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.45,
                                            color: const Color(0xFF565656),
                                          ),
                                    ),
                                  ],
                                  if (page.steps.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Steps:',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...page.steps.map((String step) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Icon(
                                                Icons.circle,
                                                size: 7,
                                                color: Color(0xFF6E765D),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                step,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: const Color(
                                                        0xFF565656,
                                                      ),
                                                      height: 1.4,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  if (page.action != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Action: ${page.action!}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                    ),
                                  ],
                                  if (page.extra != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      page.extra!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.4,
                                            color: const Color(0xFF565656),
                                          ),
                                    ),
                                  ],
                                  if (page.note != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'Note: ${page.note!}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            height: 1.45,
                                            color: const Color(0xFF565656),
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentPage == 0 ? null : _goToPrevious,
                    child: const Text('Previous'),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page ${_currentPage + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _goToNext,
                    child: Text(
                      _currentPage == widget.pages.length - 1 ? 'Finish' : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
