import 'package:flutter/material.dart';
import 'package:meditrack/services/notification_service.dart';
import 'package:meditrack/tutorials/tutorial_preferences.dart';

class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key});

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  bool? _notificationsEnabled;
  bool _isCheckingNotificationStatus = true;
  bool _isTestingEscalationSound = false;
  bool _isResettingTutorials = false;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  Future<void> _refreshNotificationStatus() async {
    setState(() {
      _isCheckingNotificationStatus = true;
    });
    bool enabled = true;
    try {
      enabled = await NotificationService.areNotificationsEnabled();
    } catch (_) {
      enabled = false;
    }
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _isCheckingNotificationStatus = false;
    });
  }

  Future<void> _runEscalationSoundTest() async {
    if (_isTestingEscalationSound) return;
    setState(() {
      _isTestingEscalationSound = true;
    });
    try {
      final bool hasAccess =
          await NotificationService.ensureNotificationAccess();
      if (!hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are disabled. Enable them in system settings.',
            ),
          ),
        );
        return;
      }
      await NotificationService.scheduleEscalationTestSequence(
        baseNotificationId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escalation test scheduled: in 5 seconds, then +10s and +20s.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to schedule escalation test right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingEscalationSound = false;
        });
      }
    }
  }

  Future<void> _resetTutorials() async {
    if (_isResettingTutorials) return;

    setState(() {
      _isResettingTutorials = true;
    });

    try {
      await TutorialPreferences.resetAllSeen();
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tutorials have been reset.')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingTutorials = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color modalBgColor = const Color(0xFFC0D1BD);
    final Color cardColor = Colors.white;
    final Color textDark = const Color(0xFF1A1A1A);
    final Color textFaint = const Color(0xFF8B9084);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 24, left: 0, right: 0, bottom: 0),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: modalBgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: textDark),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isCheckingNotificationStatus
                                ? 'Checking notification permission...'
                                : (_notificationsEnabled == true
                                      ? 'Notifications: Enabled'
                                      : 'Notifications: Disabled'),
                            style: TextStyle(fontSize: 15, color: textDark),
                          ),
                        ),
                        TextButton(
                          onPressed: _isCheckingNotificationStatus
                              ? null
                              : _refreshNotificationStatus,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.volume_up, color: textFaint),
                        label: Text(
                          _isTestingEscalationSound
                              ? 'Testing...'
                              : 'Test Escalation Sound',
                          style: TextStyle(
                            color: textFaint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: textFaint.withOpacity(0.35)),
                          backgroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isTestingEscalationSound
                            ? null
                            : _runEscalationSoundTest,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.restart_alt, color: textFaint),
                        label: Text(
                          _isResettingTutorials
                              ? 'Resetting...'
                              : 'Reset Tutorials',
                          style: TextStyle(
                            color: textFaint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: textFaint.withOpacity(0.35)),
                          backgroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isResettingTutorials ? null : _resetTutorials,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
