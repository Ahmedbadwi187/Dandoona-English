import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while an adult has passed the parental gate. Parent routes redirect away unless this is set,
/// so a deep link or back-stack cannot reach the parent area without the gate.
class ParentSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}

final parentSessionProvider = NotifierProvider<ParentSessionNotifier, bool>(ParentSessionNotifier.new);
