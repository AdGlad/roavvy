/// Platform-agnostic domain models for Roavvy.
///
/// Zero external dependencies. Consumed by both the Flutter mobile app
/// and (via the `ts/` directory) the Next.js web app.
library shared_models;

export 'src/inferred_country_visit.dart';
export 'src/user_added_country.dart';
export 'src/user_removed_country.dart';
export 'src/effective_visited_country.dart';
export 'src/scan_summary.dart';
export 'src/effective_visit_merge.dart';
export 'src/travel_summary.dart';
