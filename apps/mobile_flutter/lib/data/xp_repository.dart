import 'package:drift/drift.dart';

import 'db/roavvy_database.dart';
import '../features/xp/xp_event.dart';

/// Persists and queries [XpEvent] records in the local Drift database.
class XpRepository {
  XpRepository(this._db);

  final RoavvyDatabase _db;

  /// Inserts an [XpEvent] award record.
  Future<void> award(XpEvent event) async {
    await _db.into(_db.xpEvents).insert(
          XpEventsCompanion.insert(
            id: event.id,
            reason: event.reason.name,
            amount: event.amount,
            awardedAt: event.awardedAt,
          ),
        );
  }

  /// Returns all XP events, ordered by [awardedAt] ascending.
  Future<List<XpEvent>> loadAll() async {
    final rows = await (_db.select(_db.xpEvents)
          ..orderBy([(t) => OrderingTerm.asc(t.awardedAt)]))
        .get();
    return rows.map(_rowToEvent).toList();
  }

  /// Returns the sum of all awarded XP.
  Future<int> totalXp() async {
    final query = _db.selectOnly(_db.xpEvents)
      ..addColumns([_db.xpEvents.amount.sum()]);
    final result = await query.getSingleOrNull();
    return result?.read(_db.xpEvents.amount.sum()) ?? 0;
  }

  /// Deletes all XP events.
  Future<void> clearAll() async {
    await _db.delete(_db.xpEvents).go();
  }

  XpEvent _rowToEvent(XpEventRow row) => XpEvent(
        id: row.id,
        reason: XpReason.values.byName(row.reason),
        amount: row.amount,
        awardedAt: row.awardedAt,
      );
}
