import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the current scroll index of the Journal carousel.
///
/// This ensures the user returns to the same trip after viewing details.
final journalCarouselIndexProvider = StateProvider<int>((ref) => 0);
