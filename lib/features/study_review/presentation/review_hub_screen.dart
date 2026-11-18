import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../flashcards/presentation/flashcards_list_screen.dart';
import '../../study_schedule/presentation/study_schedule_screen.dart';
import '../domain/review_models.dart';
import 'recent_reviews_screen.dart';
import 'review_setup_screen.dart';

class ReviewHubScreen extends StatelessWidget {
  const ReviewHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppSpacing.contentWidth(context),
          ),
          child: ListView(
            padding: AppSpacing.pageInsets(context),
            children: [
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('Due Lessons'),
                subtitle: const Text('Open your study schedule'),
                onTap: () => StudyScheduleScreen.open(context),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pins'),
                subtitle: const Text('Review your starred annotations'),
                onTap: () => openReviewSetup(
                  context,
                  scope: const ReviewScope(
                    type: ReviewScopeType.favorites,
                    title: 'Favorite Pins',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('Flashcards'),
                subtitle: const Text(
                  'Browse and study cards from your library',
                ),
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.flashcardsList,
                  arguments: const FlashcardsListScope.all(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                subtitle: const Text('See recent pin review sessions'),
                onTap: () => RecentReviewsScreen.open(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
