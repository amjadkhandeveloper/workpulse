import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _controller = PageController();
  int _index = 0;

  final _pages = const [
    (Icons.assignment_turned_in, 'Track every job', 'Assign, accept, check in and close work with photo proof.'),
    (Icons.access_time, 'Standby attendance', 'Clock standby in and out so the team knows who is ready.'),
    (Icons.location_on, 'Live monitoring', 'See where field users are while they are on duty or on a job.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(page.$1, size: 56, color: AppColors.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.$2,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  width: _index == i ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _index == i ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: PrimaryButton(
                label: _index == _pages.length - 1 ? 'Get started' : 'Next',
                onPressed: () {
                  if (_index < _pages.length - 1) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  } else {
                    ref.read(sessionControllerProvider.notifier).completeIntro();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
