import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Local parcel store. In PC mode this is the primary store;
/// after Wave 4 it doubles as the offline cache/queue for Supabase.
class ParcelRows extends Table {
  TextColumn get id => text()();
  TextColumn get courierCode => text()();
  TextColumn get trackingNumber => text()();
  TextColumn get status => text()();
  TextColumn get productName => text().nullable()();
  TextColumn get mallName => text().nullable()();

  /// Comma-separated set of source channels ('kakao,sms,...').
  TextColumn get sourceChannels => text().withDefault(const Constant(''))();
  DateTimeColumn get expectedArrivalDate => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get registeredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  /// Same dedupe key as the future Supabase table:
  /// unique (courier_code, tracking_number).
  @override
  List<Set<Column>> get uniqueKeys => [
        {courierCode, trackingNumber},
      ];
}

/// Per-parcel status history shown on the detail timeline.
/// Mirrors the future Supabase `tracking_events` table.
class TrackingEventRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get parcelId => text()();
  DateTimeColumn get eventTime => dateTime()();
  TextColumn get statusCode => text()();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
}

/// Single-row local profile used by the PC-mode fake auth.
class LocalProfileRows extends Table {
  IntColumn get id => integer()();
  TextColumn get displayName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ParcelRows, LocalProfileRows, TrackingEventRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for widget/unit tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(trackingEventRows);
          }
        },
      );

  static QueryExecutor _openConnection() {
    // drift_flutter picks the right sqlite3 setup per platform
    // (Windows/Android/iOS), no manual ffi init needed.
    return driftDatabase(name: 'check_shipping');
  }
}
