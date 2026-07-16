import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wood_quote/models/estimate.dart';
import 'package:wood_quote/models/estimate_stats.dart';
import 'package:wood_quote/models/line_item.dart';

class DatabaseHelper {
  // ── Singleton ──────────────────────────────────────────────────────
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  static const String _dbName = 'woodquote.db';
  static const int _dbVersion = 5;

  // ── Initialisation ─────────────────────────────────────────────────

  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onConfigure: _configureDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDatabase(Database db, int version) async {
    // All content columns allow NULL — a draft can be saved at any stage
    await db.execute('''
      CREATE TABLE estimates (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name    TEXT,
        address          TEXT,
        date             TEXT,
        job_description  TEXT,
        validity         TEXT,
        terms_of_payment TEXT,
        amount           REAL    NOT NULL DEFAULT 0,
        status           INTEGER NOT NULL DEFAULT 2,
        pdf_path         TEXT,
        pdf_generated_at TEXT,
        shared_at        TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE line_items (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_id          INTEGER NOT NULL,
        description          TEXT,
        quantity             REAL,
        unit_price           REAL,
        header_value         REAL,
        add_blank_row_before INTEGER NOT NULL DEFAULT 1,
        type                 INTEGER NOT NULL DEFAULT 0,
        sort_order           INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (estimate_id) REFERENCES estimates (id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE estimates ADD COLUMN pdf_path TEXT;');
      await db.execute(
        'ALTER TABLE estimates ADD COLUMN pdf_generated_at TEXT;',
      );
      await db.execute('ALTER TABLE estimates ADD COLUMN shared_at TEXT;');
    }

    if (oldVersion < 3) {
      // SQLite cannot remove a NOT NULL constraint directly, so the
      // line_items table must be reconstructed.
      await db.execute('ALTER TABLE line_items RENAME TO line_items_old;');

      await db.execute('''
      CREATE TABLE line_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_id   INTEGER NOT NULL,
        description   TEXT,
        quantity      REAL,
        unit_price    REAL,
        header_value  REAL,
        type          INTEGER NOT NULL DEFAULT 0,
        sort_order    INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (estimate_id)
          REFERENCES estimates (id)
          ON DELETE CASCADE
      );
    ''');

      await db.execute('''
      INSERT INTO line_items (
        id,
        estimate_id,
        description,
        quantity,
        unit_price,
        header_value,
        type,
        sort_order
      )
      SELECT
        id,
        estimate_id,
        description,

        -- Older blank fields were stored as zero.
        CASE
          WHEN quantity = 0 THEN NULL
          ELSE quantity
        END,

        CASE
          WHEN unit_price = 0 THEN NULL
          ELSE unit_price
        END,

        NULL,
        type,
        sort_order
      FROM line_items_old;
    ''');

      await db.execute('DROP TABLE line_items_old;');
    }

    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE line_items
        ADD COLUMN add_blank_row_before INTEGER NOT NULL DEFAULT 1;
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE estimates ADD COLUMN validity TEXT;');

      await db.execute(
        'ALTER TABLE estimates ADD COLUMN terms_of_payment TEXT;',
      );
    }
  }

  Future<Estimate> insertEstimate(Estimate estimate) async {
    final db = await database;
    final total = estimate.computedTotal;

    return db.transaction((txn) async {
      final estimateId = await txn.insert(
        'estimates',
        estimate.copyWith(amount: total).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final item in estimate.lineItems) {
        await txn.insert(
          'line_items',
          item.copyWith(estimateId: estimateId).toMap(),
        );
      }

      return estimate.copyWith(id: estimateId, amount: total);
    });
  }

  Future<void> updateEstimate(Estimate estimate) async {
    assert(estimate.id != null, 'Cannot update an estimate without an id');
    final db = await database;
    final total = estimate.computedTotal;

    await db.transaction((txn) async {
      final estimateMap = estimate.copyWith(amount: total).toMap();
      estimateMap['pdf_path'] = null;
      estimateMap['pdf_generated_at'] = null;

      await txn.update(
        'estimates',
        estimateMap,
        where: 'id = ?',
        whereArgs: [estimate.id],
      );

      await txn.delete(
        'line_items',
        where: 'estimate_id = ?',
        whereArgs: [estimate.id],
      );

      for (final item in estimate.lineItems) {
        await txn.insert(
          'line_items',
          item.copyWith(estimateId: estimate.id).toMap(),
        );
      }
    });
  }

  Future<void> deleteEstimate(int id) async {
    final db = await database;
    await db.delete('estimates', where: 'id = ?', whereArgs: [id]);
  }

  Future<Estimate?> getEstimate(int id) async {
    final db = await database;
    final rows = await db.query('estimates', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final items = await _getLineItemsForEstimate(db, id);
    return Estimate.fromMap(rows.first, lineItems: items);
  }

  Future<List<Estimate>> getAllEstimates() async {
    final db = await database;
    final rows = await db.query('estimates', orderBy: 'date DESC');
    return rows.map((row) => Estimate.fromMap(row)).toList();
  }

  Future<List<Estimate>> getEstimatesByStatus(EstimateStatus status) async {
    final db = await database;
    final rows = await db.query(
      'estimates',
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'date DESC',
    );
    return rows.map((row) => Estimate.fromMap(row)).toList();
  }

  Future<EstimateStats> getStats() async {
    final db = await database;

    final rows = await db.query('estimates', columns: ['status', 'amount']);

    if (rows.isEmpty) return const EstimateStats.empty();

    int drafts = 0, shared = 0, finalised = 0;
    double totalValue = 0;

    for (final row in rows) {
      final status = EstimateStatus.values[row['status'] as int];
      totalValue += (row['amount'] as num).toDouble();

      switch (status) {
        case EstimateStatus.draft:
          drafts++;
          break;
        case EstimateStatus.shared:
          shared++;
          break;
        case EstimateStatus.finalised:
          finalised++;
          break;
      }
    }

    return EstimateStats(
      total: rows.length,
      drafts: drafts,
      shared: shared,
      finalised: finalised,
      totalValue: totalValue,
    );
  }

  Future<void> finaliseEstimateWithPdf({
    required int estimateId,
    required String pdfPath,
    DateTime? generatedAt,
  }) async {
    final db = await database;

    final now = generatedAt ?? DateTime.now();

    await db.update(
      'estimates',
      {
        'status': EstimateStatus.finalised.index,
        'pdf_path': pdfPath,
        'pdf_generated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [estimateId],
    );
  }

  Future<void> markEstimateAsShared({
    required int estimateId,
    DateTime? sharedAt,
  }) async {
    final db = await database;

    final now = sharedAt ?? DateTime.now();

    await db.update(
      'estimates',
      {
        'status': EstimateStatus.shared.index,
        'shared_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [estimateId],
    );
  }

  Future<void> updateEstimatePdfPath({
    required int estimateId,
    required String pdfPath,
    DateTime? generatedAt,
  }) async {
    final db = await database;

    final now = generatedAt ?? DateTime.now();

    await db.update(
      'estimates',
      {'pdf_path': pdfPath, 'pdf_generated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [estimateId],
    );
  }

  Future<void> clearEstimatePdf({required int estimateId}) async {
    final db = await database;

    await db.update(
      'estimates',
      {'pdf_path': null, 'pdf_generated_at': null},
      where: 'id = ?',
      whereArgs: [estimateId],
    );
  }

  Future<List<LineItem>> _getLineItemsForEstimate(
    Database db,
    int estimateId,
  ) async {
    final rows = await db.query(
      'line_items',
      where: 'estimate_id = ?',
      whereArgs: [estimateId],
      orderBy: 'sort_order ASC',
    );
    return rows.map((row) => LineItem.fromMap(row)).toList();
  }
}
