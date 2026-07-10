import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Local parcel store. This is the primary database for the single-user app.
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

  /// Dedupe key: one row per courier/tracking number pair.
  @override
  List<Set<Column>> get uniqueKeys => [
    {courierCode, trackingNumber},
  ];
}

/// Per-parcel status history shown on the detail timeline.
class TrackingEventRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get parcelId => text()();
  DateTimeColumn get eventTime => dateTime()();
  TextColumn get statusCode => text()();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
}

/// Captures screened out as suspected phishing, kept for user review.
/// Never auto-deleted: a false positive must stay recoverable. The body
/// is rendered as plain, non-clickable text only.
class QuarantineRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channel => text()();
  TextColumn get sender => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  TextColumn get reason => text()();
  DateTimeColumn get capturedAt => dateTime()();
}

/// Legacy single-row local profile table from the early PC-mode prototype.
/// Kept for schema compatibility; the app no longer uses login/profile state.
class LocalProfileRows extends Table {
  IntColumn get id => integer()();
  TextColumn get displayName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [ParcelRows, LocalProfileRows, TrackingEventRows, QuarantineRows],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for widget/unit tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(trackingEventRows);
      }
      if (from < 3) {
        await m.createTable(quarantineRows);
      }
    },
  );

  static QueryExecutor _openConnection() {
    // drift_flutter picks the right sqlite3 setup per platform
    // (Windows/Android/iOS), no manual ffi init needed.
    return driftDatabase(name: 'check_shipping');
  }
}
