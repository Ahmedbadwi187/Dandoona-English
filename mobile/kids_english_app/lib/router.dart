import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/child/lesson_screen.dart';
import 'features/child/letter_map_screen.dart';
import 'features/child/profile_picker_screen.dart';
import 'features/parent/child_form_screen.dart';
import 'features/parent/children_screen.dart';
import 'features/parent/onboarding_screen.dart';
import 'features/parent/parent_home_screen.dart';
import 'features/parent/settings_screen.dart';
import 'features/profiles/child_profile.dart';
import 'features/router_state.dart';
import 'features/settings/settings.dart';

/// Where a path may go, given the current state. Pure so it can be unit-tested.
String? guardRoute({
  required String location,
  required bool onboarded,
  required bool hasProfiles,
  required bool parentUnlocked,
  required bool hasActiveChild,
}) {
  if (location == '/') return onboarded && hasProfiles ? '/who' : '/onboarding';
  if (location == '/who' && !hasProfiles) return '/onboarding';
  // Parent area is only reachable through the parental gate.
  if (location.startsWith('/parent') && !parentUnlocked) return '/who';
  if ((location == '/map' || location.startsWith('/lesson/')) && !hasActiveChild) return '/who';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => guardRoute(
      location: state.matchedLocation,
      onboarded: ref.read(settingsProvider).onboarded,
      hasProfiles: ref.read(profilesProvider).isNotEmpty,
      parentUnlocked: ref.read(parentSessionProvider),
      hasActiveChild: ref.read(activeChildIdProvider) != null,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const OnboardingScreen()), // redirected by guardRoute
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/child', builder: (_, __) => const ChildFormScreen(firstRun: true)),
      GoRoute(path: '/who', builder: (_, __) => const ProfilePickerScreen()),
      GoRoute(path: '/map', builder: (_, __) => const LetterMapScreen()),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) => LessonScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/parent', builder: (_, __) => const ParentHomeScreen()),
      GoRoute(path: '/parent/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/parent/children', builder: (_, __) => const ChildrenScreen()),
      // 'new' must be declared before ':id'.
      GoRoute(path: '/parent/children/new', builder: (_, __) => const ChildFormScreen()),
      GoRoute(
        path: '/parent/children/:id',
        builder: (_, state) => ChildFormScreen(childId: state.pathParameters['id']),
      ),
    ],
  );
});
