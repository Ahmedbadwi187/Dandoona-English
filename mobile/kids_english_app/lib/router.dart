import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/activities/activity_screen.dart';
import 'features/certificate/certificate_screen.dart';
import 'features/certificate/unit_celebration_screen.dart';
import 'features/child/lesson_screen.dart';
import 'features/child/letter_map_screen.dart';
import 'features/child/profile_picker_screen.dart';
import 'features/onboarding/language_route.dart';
import 'features/parent/child_form_screen.dart';
import 'features/rewards/wardrobe_screen.dart';
import 'features/parent/children_screen.dart';
import 'features/parent/onboarding_screen.dart';
import 'features/parent/parent_home_screen.dart';
import 'features/parent/settings_screen.dart';
import 'features/profiles/child_profile.dart';
import 'features/router_state.dart';
import 'features/settings/settings.dart';
import 'features/units/unit_map_screen.dart';

/// Where a path may go, given the current state. Pure so it can be unit-tested.
String? guardRoute({
  required String location,
  required bool onboarded,
  required bool hasProfiles,
  required bool parentUnlocked,
  required bool hasActiveChild,
  bool languageChosen = true,
}) {
  // First launch: the language screen comes before anything else.
  if (!languageChosen && location != '/language') return '/language';
  if (location == '/') return onboarded && hasProfiles ? '/who' : '/onboarding';
  if (location == '/who' && !hasProfiles) return '/onboarding';
  // Parent area is only reachable through the parental gate.
  if (location.startsWith('/parent') && !parentUnlocked) return '/who';
  if ((location == '/map' || location == '/wardrobe' || location.startsWith('/lesson/') || location.startsWith('/unit/') || location.startsWith('/certificate/')) && !hasActiveChild) return '/who';
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
      languageChosen: ref.read(settingsProvider).languageChosen,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()), // redirected by guardRoute
      GoRoute(path: '/language', builder: (_, _) => const LanguageRoute()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/child', builder: (_, _) => const ChildFormScreen(firstRun: true)),
      GoRoute(path: '/who', builder: (_, _) => const ProfilePickerScreen()),
      GoRoute(path: '/map', builder: (_, _) => const UnitMapScreen()),
      GoRoute(path: '/unit/:id', builder: (_, state) => LetterMapScreen(unitId: state.pathParameters['id'])),
      GoRoute(path: '/unit/:id/celebrate', builder: (_, state) => UnitCelebrationScreen(unitId: state.pathParameters['id']!)),
      GoRoute(path: '/certificate/:unitId', builder: (_, state) => CertificateScreen(unitId: state.pathParameters['unitId']!)),
      GoRoute(path: '/wardrobe', builder: (_, _) => const WardrobeScreen()),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) => LessonScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id/:activity',
        builder: (_, state) => ActivityScreen(
          lessonId: state.pathParameters['id']!,
          activity: state.pathParameters['activity']!,
        ),
      ),
      GoRoute(path: '/parent', builder: (_, _) => const ParentHomeScreen()),
      GoRoute(path: '/parent/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/parent/children', builder: (_, _) => const ChildrenScreen()),
      // 'new' must be declared before ':id'.
      GoRoute(path: '/parent/children/new', builder: (_, _) => const ChildFormScreen()),
      GoRoute(
        path: '/parent/children/:id',
        builder: (_, state) => ChildFormScreen(childId: state.pathParameters['id']),
      ),
    ],
  );
});
