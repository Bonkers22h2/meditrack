import 'package:flutter/material.dart';

class IntroPopupPage {
  final String title;
  final String? subtitle;
  final String description;
  final bool useQuoteBlockForIntroText;
  final List<String> steps;
  final String? action;
  final String? extra;
  final String? note;

  const IntroPopupPage({
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

class IntroPopupDialog extends StatefulWidget {
  final List<IntroPopupPage> pages;

  const IntroPopupDialog({super.key, required this.pages});

  @override
  State<IntroPopupDialog> createState() => _IntroPopupDialogState();
}

class _IntroPopupDialogState extends State<IntroPopupDialog> {
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
                    final IntroPopupPage page = widget.pages[index];

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
                                    ...page.steps.asMap().entries.map(
                                      (MapEntry<int, String> entry) {
                                        final int stepNumber = entry.key + 1;
                                        final String step = entry.value;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 20,
                                                alignment: Alignment.topLeft,
                                                child: Text(
                                                  '$stepNumber.',
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: const Color(
                                                          0xFF6E765D,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.4,
                                                      ),
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
                                      },
                                    ),
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
