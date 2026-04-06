# Blueprint: Database Asset Versioning with PRAGMA user_version

<!--
tags:        [sqlite, versioning, pragma, assets, updates]
category:    architecture
difficulty:  intermediate
time:        2 hours
stack:       [flutter, dart, sqlite]
-->

> Use `PRAGMA user_version` as the single source of truth for database asset versions — no external Dart constants, no JSON version files, no drift between code and data.

## TL;DR

Embed the version number directly inside the `.db` file using SQLite's built-in `PRAGMA user_version`. Your CI pipeline writes it when building the database; your app reads it at startup to decide whether to silently apply a bundled update or prompt the user to download a newer corpus. All version logic flows from the database file itself.

## When to Use

- Apps that ship a content database (corpus, catalog, reference data) as an asset
- The content database updates more frequently than the app binary
- Multiple version sources exist: bundled in the binary, downloaded to device, and available on a remote server
- When **not** to use: the database is user-generated data only (use Drift's `schemaVersion` for schema migrations instead); pure API-backed apps with no local content

## Prerequisites

- [ ] Flutter app with `sqflite` or `sqflite_common_ffi` and `path_provider`
- [ ] A content pipeline that builds the `.db` file (shell scripts, Python, Dart scripts, etc.)
- [ ] A CDN or storage bucket to host downloadable `.db` files
- [ ] A remote manifest (JSON) updated by the pipeline after each build
- [ ] Familiarity with the [Dual Database Pattern](dual-database-pattern.md) (reference DB vs user DB separation)

## Overview

```mermaid
flowchart TD
    START([App startup]) --> OPEN_LOCAL[Open local DB]
    OPEN_LOCAL --> READ_LOCAL[Read PRAGMA user_version\n→ localV]
    READ_LOCAL --> OPEN_BUNDLED[Open bundled asset DB]
    OPEN_BUNDLED --> READ_BUNDLED[Read PRAGMA user_version\n→ bundledV]

    READ_BUNDLED --> CMP1{bundledV > localV?}
    CMP1 -->|Yes — silent update| REPLACE_BUNDLED[Replace local DB\nwith bundled DB]
    REPLACE_BUNDLED --> UPDATE_LOCAL_V[localV = bundledV]
    CMP1 -->|No — keep current| UPDATE_LOCAL_V

    UPDATE_LOCAL_V --> FETCH_MANIFEST[Fetch remote manifest\n→ manifestV]
    FETCH_MANIFEST --> OFFLINE{Offline?}
    OFFLINE -->|Yes| DONE([Use local DB])
    OFFLINE -->|No| CMP2{manifestV > localV?}

    CMP2 -->|No| DONE
    CMP2 -->|Yes| NOTIFY[Offer download\nto user]
    NOTIFY --> DOWNLOAD[Download .db to .tmp]
    DOWNLOAD --> VERIFY[Verify SHA-256]
    VERIFY --> SWAP[Atomic swap via\nDB manager]
    SWAP --> CHANGELOG[Read corpus_changelog\nbetween oldV and newV]
    CHANGELOG --> WHATS_NEW[Show "What's new" UI]
    WHATS_NEW --> DONE

    style REPLACE_BUNDLED fill:#e1f5fe
    style SWAP fill:#e1f5fe
    style NOTIFY fill:#fff3e0
    style WHATS_NEW fill:#fff3e0
```

## Steps

### 1. Understand PRAGMA user_version

**Why**: Before wiring up the logic, you need to understand exactly what you are relying on. `PRAGMA user_version` is a 32-bit signed integer stored at byte offset 60 in the SQLite file header. It is part of the database file itself — not a sidecar file, not an environment variable. Reading it requires opening the database; writing it requires a write transaction. It defaults to `0` on any freshly created database.

This makes it ideal as a single source of truth for asset versioning:

- **Atomic with the data**: the version lives in the same file as the content. There is no separate constants file that can drift out of sync.
- **Readable without opening tables**: you can query it immediately after opening the database, before any application-level queries.
- **Zero overhead**: it is a header field, not a table scan.

```dart
// Read the version from any open Database connection
Future<int> getDbVersion(Database db) async {
  final result = await db.rawQuery('PRAGMA user_version');
  return result.first.values.first as int;
}
```

```sql
-- Write the version (pipeline / build script)
PRAGMA user_version = 42;
```

**Expected outcome**: You can open any `.db` file and read its embedded version with a single query, with no external files involved.

---

### 2. Set the version in your pipeline

**Why**: The pipeline is the only place that should write `PRAGMA user_version`. If you maintain the version number in Dart code or a JSON file separately, they will eventually drift. Let the database carry its own identity.

The pipeline builds the database from source data, sets the pragma, then reads it back to populate the manifest. This ensures the manifest version is always exactly what is in the file.

**Pipeline script (example in shell + sqlite3 CLI)**:

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION=42
OUTPUT="output/corpus_en.db"

# 1. Build the database from source
python3 pipeline/seed.py --output "$OUTPUT"

# 2. Stamp the version into the file header
sqlite3 "$OUTPUT" "PRAGMA user_version = $VERSION;"

# 3. Verify the stamp was written correctly
STAMPED=$(sqlite3 "$OUTPUT" "PRAGMA user_version;")
if [ "$STAMPED" != "$VERSION" ]; then
  echo "ERROR: version stamp mismatch (expected $VERSION, got $STAMPED)"
  exit 1
fi

# 4. Compute SHA-256 for the manifest
SHA=$(shasum -a 256 "$OUTPUT" | awk '{print $1}')

# 5. Generate manifest — version comes FROM the DB, never from a constant
cat > output/manifest.json <<EOF
{
  "version": $STAMPED,
  "sha256": "$SHA",
  "url": "https://cdn.example.com/corpus/en/v${VERSION}/corpus_en.db",
  "locale": "en",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "Built corpus_en.db version $VERSION (sha256: $SHA)"
```

**For multi-locale pipelines**, generate one manifest entry per locale and combine:

```bash
# manifest_multi.json
{
  "en": { "version": 42, "sha256": "abc123...", "url": "..." },
  "fr": { "version": 38, "sha256": "def456...", "url": "..." },
  "vi": { "version": 31, "sha256": "ghi789...", "url": "..." }
}
```

**Expected outcome**: Each `.db` file has `PRAGMA user_version` set, the manifest is generated by reading that value back (not by a separate counter), and the SHA-256 in the manifest matches the actual file.

---

### 3. Add corpus_changelog for "What's new"

**Why**: When the user downloads a new corpus, showing them a changelog builds trust and explains why the download is worth it. The changelog lives inside the `.db` file itself, seeded by the pipeline at each build. This means it is always in sync with the actual content changes.

**Schema** (included in your pipeline's `schema.sql`):

```sql
CREATE TABLE IF NOT EXISTS corpus_changelog (
  version     INTEGER NOT NULL,
  locale      TEXT    NOT NULL,
  change_type TEXT    NOT NULL,  -- 'new_content' | 'corrections' | 'new_language'
  summary     TEXT    NOT NULL,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Index for the common query: "give me everything newer than localV"
CREATE INDEX IF NOT EXISTS idx_corpus_changelog_version
  ON corpus_changelog (version);
```

**Pipeline seeding** (Python example):

```python
import sqlite3

def seed_changelog(db_path: str, version: int, locale: str, entries: list[dict]):
    conn = sqlite3.connect(db_path)
    conn.executemany(
        """
        INSERT INTO corpus_changelog (version, locale, change_type, summary)
        VALUES (:version, :locale, :change_type, :summary)
        """,
        [{"version": version, "locale": locale, **e} for e in entries],
    )
    conn.commit()
    conn.close()

# Called after stamping PRAGMA user_version
seed_changelog("output/corpus_en.db", version=42, locale="en", entries=[
    {"change_type": "new_content", "summary": "Added 150 new suttas from the Majjhima Nikaya"},
    {"change_type": "corrections", "summary": "Fixed Pali diacritics in 200+ entries"},
])
```

**Dart query** — called after a successful swap to show the "What's new" sheet:

```dart
Future<List<ChangelogEntry>> getChangelogSince({
  required Database db,
  required int fromVersion,
  required int toVersion,
  required String locale,
}) async {
  final rows = await db.rawQuery(
    '''
    SELECT version, change_type, summary, created_at
    FROM corpus_changelog
    WHERE version > ? AND version <= ? AND locale = ?
    ORDER BY version DESC
    ''',
    [fromVersion, toVersion, locale],
  );
  return rows.map(ChangelogEntry.fromMap).toList();
}
```

**Expected outcome**: After every corpus update, the app can show the user exactly what changed between their previous version and the new one, with no network request and no separate API endpoint.

---

### 4. Implement getDbVersion and the version comparison helper

**Why**: Centralising version-reading logic in one place prevents scattered `rawQuery('PRAGMA user_version')` calls and makes it easy to mock in tests.

```dart
// lib/core/database/db_version.dart

import 'package:sqflite/sqflite.dart';

/// Reads the embedded version from a SQLite database file header.
/// Returns 0 if the database has never been stamped (pipeline omission).
Future<int> getDbVersion(Database db) async {
  final result = await db.rawQuery('PRAGMA user_version');
  final value = result.firstOrNull?.values.firstOrNull;
  if (value is int) return value;
  // user_version is always an int, but guard against unexpected null
  return 0;
}

/// Opens [path] read-only, reads PRAGMA user_version, closes immediately.
/// Use for bundled assets copied to a temp location.
Future<int> readDbVersionFromPath(String path) async {
  final db = await openDatabase(path, readOnly: true);
  try {
    return await getDbVersion(db);
  } finally {
    await db.close();
  }
}
```

**Version comparison logic** — this is the core decision table:

```dart
// lib/core/database/version_resolver.dart

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

import 'db_version.dart';

class VersionResolution {
  final int localVersion;
  final int bundledVersion;
  final int? manifestVersion;

  /// True when the bundled DB was silently copied over the local DB.
  final bool appliedBundledUpdate;

  const VersionResolution({
    required this.localVersion,
    required this.bundledVersion,
    this.manifestVersion,
    this.appliedBundledUpdate = false,
  });

  /// A remote update is available and should be offered to the user.
  bool get remoteUpdateAvailable =>
      manifestVersion != null && manifestVersion! > localVersion;
}

class VersionResolver {
  final String assetPath;       // e.g. 'assets/corpus_en.db'
  final String localDbFileName; // e.g. 'corpus_en.db'
  final Future<int?> Function() fetchManifestVersion;
  final DatabaseManager dbManager;

  const VersionResolver({
    required this.assetPath,
    required this.localDbFileName,
    required this.fetchManifestVersion,
    required this.dbManager,
  });

  Future<VersionResolution> resolve() async {
    final appDir = await getApplicationSupportDirectory();
    final localPath = '${appDir.path}/$localDbFileName';

    // --- Step A: ensure a local DB exists (first install) ---
    if (!File(localPath).existsSync()) {
      await _copyBundledToLocal(localPath);
    }

    // --- Step B: read local version ---
    final localV = await readDbVersionFromPath(localPath);

    // --- Step C: read bundled version ---
    final bundledPath = await _extractBundledToTemp();
    final bundledV = await readDbVersionFromPath(bundledPath);

    // --- Step D: silent bundled update (app was updated with newer corpus) ---
    bool appliedBundled = false;
    int effectiveLocalV = localV;

    if (bundledV > localV) {
      // Downgrade protection: never go backwards
      await dbManager.replaceDatabase(localDbFileName, File(bundledPath));
      effectiveLocalV = bundledV;
      appliedBundled = true;
    }

    // --- Step E: fetch manifest (best-effort, may be offline) ---
    final manifestV = await fetchManifestVersion().catchError((_) => null);

    return VersionResolution(
      localVersion: effectiveLocalV,
      bundledVersion: bundledV,
      manifestVersion: manifestV,
      appliedBundledUpdate: appliedBundled,
    );
  }

  Future<String> _extractBundledToTemp() async {
    final bytes = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/bundled_check.db';
    await File(tempPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return tempPath;
  }

  Future<void> _copyBundledToLocal(String localPath) async {
    final bytes = await rootBundle.load(assetPath);
    await File(localPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
}
```

**Expected outcome**: A single `resolve()` call handles all three version sources (bundled, local, manifest), applies the silent bundled update if needed, and returns a `VersionResolution` object the app can act on.

---

### 5. Wire the download flow

**Why**: The manifest tells the app a newer corpus exists. Downloading it safely means: write to a temp file, verify integrity, then atomically swap. Never write directly over the live database file.

```dart
// lib/core/database/corpus_updater.dart

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CorpusUpdater {
  final DatabaseManager dbManager;
  final String localDbFileName;

  const CorpusUpdater({
    required this.dbManager,
    required this.localDbFileName,
  });

  /// Downloads the corpus from [url], verifies SHA-256, swaps atomically.
  /// Throws [CorpusUpdateException] on integrity failure or download error.
  /// Returns the new version read from the swapped database.
  Future<int> downloadAndApply({
    required String url,
    required String expectedSha256,
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$localDbFileName.tmp');

    // 1. Stream download to temp file
    await _downloadToFile(url, tempFile, onProgress: onProgress);

    // 2. Verify integrity before touching anything live
    final actualSha = await _computeSha256(tempFile);
    if (actualSha != expectedSha256) {
      await tempFile.delete();
      throw CorpusUpdateException(
        'SHA-256 mismatch: expected $expectedSha256, got $actualSha',
      );
    }

    // 3. Downgrade protection: read version from temp file
    final newVersion = await readDbVersionFromPath(tempFile.path);
    final db = await dbManager.getDatabase(localDbFileName);
    final currentVersion = await getDbVersion(db);

    if (newVersion <= currentVersion) {
      await tempFile.delete();
      throw CorpusUpdateException(
        'Downgrade rejected: new=$newVersion current=$currentVersion',
      );
    }

    // 4. Atomic swap via DB manager (closes connection, swaps file, reopens)
    await dbManager.replaceDatabase(localDbFileName, tempFile);

    return newVersion;
  }

  Future<void> _downloadToFile(
    String url,
    File dest, {
    void Function(double)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw CorpusUpdateException('Download failed: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    int received = 0;
    final sink = dest.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }

    await sink.close();
  }

  Future<String> _computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}

class CorpusUpdateException implements Exception {
  final String message;
  const CorpusUpdateException(this.message);

  @override
  String toString() => 'CorpusUpdateException: $message';
}
```

**Expected outcome**: Downloads go to a temp file, integrity is verified before touching the live database, and downgrade attempts are rejected with a clear exception.

---

### 6. Handle staging vs production manifests

**Why**: You need to test new corpus builds on TestFlight or internal builds before they reach production users. Using the same manifest URL for both means you cannot test a new corpus without immediately exposing it to everyone. Separate manifest endpoints solve this with zero change to the DB files themselves.

The DB files are identical between staging and production — only the manifest URL differs. This means a staging user gets exactly the same bytes that will ship to production.

```dart
// lib/core/config/environment.dart

enum AppEnvironment { staging, production }

class EnvironmentConfig {
  final AppEnvironment environment;

  const EnvironmentConfig(this.environment);

  String get manifestUrl {
    switch (environment) {
      case AppEnvironment.staging:
        return 'https://cdn.example.com/corpus/staging/manifest.json';
      case AppEnvironment.production:
        return 'https://cdn.example.com/corpus/production/manifest.json';
    }
  }
}
```

**Pipeline publishing step**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# After building and validating the DB:

STAGE="${1:-staging}"  # ./publish.sh staging | ./publish.sh production

MANIFEST_DEST="s3://cdn.example.com/corpus/${STAGE}/manifest.json"
DB_DEST="s3://cdn.example.com/corpus/${STAGE}/v${VERSION}/corpus_en.db"

# Upload DB (same file for both environments)
aws s3 cp output/corpus_en.db "$DB_DEST" --content-type application/octet-stream

# Upload manifest pointing to the correct URL
jq --arg url "$DB_DEST" '.url = $url' output/manifest.json \
  | aws s3 cp - "$MANIFEST_DEST" --content-type application/json

echo "Published v${VERSION} to ${STAGE}"
```

**Manifest fetcher in Dart**:

```dart
// lib/core/database/manifest_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ManifestEntry {
  final int version;
  final String sha256;
  final String url;
  final String locale;

  const ManifestEntry({
    required this.version,
    required this.sha256,
    required this.url,
    required this.locale,
  });

  factory ManifestEntry.fromJson(Map<String, dynamic> json) => ManifestEntry(
        version: json['version'] as int,
        sha256: json['sha256'] as String,
        url: json['url'] as String,
        locale: json['locale'] as String,
      );
}

class ManifestClient {
  final String manifestUrl;
  final http.Client _client;

  const ManifestClient({required this.manifestUrl, http.Client? client})
      : _client = client ?? const http.Client();

  /// Returns null if offline or the manifest cannot be parsed.
  Future<ManifestEntry?> fetch({String locale = 'en'}) async {
    try {
      final response = await _client
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Support both single-locale and multi-locale manifests
      final payload = json.containsKey('version')
          ? json
          : json[locale] as Map<String, dynamic>?;

      if (payload == null) return null;
      return ManifestEntry.fromJson(payload);
    } catch (_) {
      return null; // offline-safe: silently return null
    }
  }
}
```

**Expected outcome**: Staging builds check a staging manifest; production builds check the production manifest. No code changes between environments — only the injected `manifestUrl` differs.

---

### 7. Integrate at app startup

**Why**: Version resolution must happen early, before the app serves any content. Doing it lazily (on first query) risks showing stale data. Doing it synchronously on the main thread risks a jank spike on first launch. The right place is in your app initialisation future, before `runApp`.

```dart
// lib/main.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = EnvironmentConfig(
    const String.fromEnvironment('APP_ENV', defaultValue: 'production') ==
            'staging'
        ? AppEnvironment.staging
        : AppEnvironment.production,
  );

  final manifestClient = ManifestClient(manifestUrl: env.manifestUrl);
  final dbManager = DatabaseManager();

  final resolver = VersionResolver(
    assetPath: 'assets/corpus_en.db',
    localDbFileName: 'corpus_en.db',
    fetchManifestVersion: () async => (await manifestClient.fetch())?.version,
    dbManager: dbManager,
  );

  final resolution = await resolver.resolve();

  runApp(
    ProviderScope(
      overrides: [
        dbManagerProvider.overrideWithValue(dbManager),
        versionResolutionProvider.overrideWithValue(resolution),
        manifestClientProvider.overrideWithValue(manifestClient),
      ],
      child: const MyApp(),
    ),
  );
}
```

**Reacting to the resolution in the UI**:

```dart
// lib/features/home/home_screen.dart

class HomeScreen extends ConsumerStatefulWidget { ... }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final resolution = ref.read(versionResolutionProvider);

    if (!resolution.remoteUpdateAvailable) return;

    // Offer non-blocking banner or bottom sheet
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => CorpusUpdateSheet(resolution: resolution),
    );
  }
}
```

**Expected outcome**: Bundled updates are applied silently before `runApp`. Remote update availability is resolved before the first frame. The update UI appears once, non-intrusively, after the home screen renders.

---

### 8. Show the changelog after a successful update

**Why**: Users who accepted a download need feedback that something happened. Reading the changelog from the newly swapped database closes the loop without any additional network request.

```dart
// lib/features/corpus_update/corpus_update_notifier.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CorpusUpdateNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<CorpusUpdateResult> applyUpdate(ManifestEntry entry) async {
    state = const AsyncLoading();

    try {
      final updater = ref.read(corpusUpdaterProvider);
      final db = await ref.read(dbManagerProvider).getDatabase('corpus_en.db');
      final oldVersion = await getDbVersion(db);

      final newVersion = await updater.downloadAndApply(
        url: entry.url,
        expectedSha256: entry.sha256,
        onProgress: (p) { /* update progress bar */ },
      );

      // Read changelog from the freshly swapped DB
      final freshDb = await ref.read(dbManagerProvider).getDatabase('corpus_en.db');
      final changelog = await getChangelogSince(
        db: freshDb,
        fromVersion: oldVersion,
        toVersion: newVersion,
        locale: 'en',
      );

      state = const AsyncData(null);
      return CorpusUpdateResult(
        previousVersion: oldVersion,
        newVersion: newVersion,
        changelog: changelog,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

class CorpusUpdateResult {
  final int previousVersion;
  final int newVersion;
  final List<ChangelogEntry> changelog;

  const CorpusUpdateResult({
    required this.previousVersion,
    required this.newVersion,
    required this.changelog,
  });
}
```

**Expected outcome**: After a successful download and swap, the app shows a summary of changes sourced directly from the new database, then the user is done.

---

### 9. Validate the full flow in tests

**Why**: Version logic has multiple branches (fresh install, bundled update, remote update, downgrade rejection, offline). Each branch is cheap to test in isolation and expensive to discover broken in production.

```dart
// test/core/database/version_resolver_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatabaseManager extends Mock implements DatabaseManager {}
class MockDatabase extends Mock implements Database {}

void main() {
  group('VersionResolver', () {
    test('applies bundled update silently when bundledV > localV', () async {
      // Arrange: local=10, bundled=12, manifest=null (offline)
      final resolution = await _resolve(
        localV: 10,
        bundledV: 12,
        manifestV: null,
      );

      expect(resolution.appliedBundledUpdate, isTrue);
      expect(resolution.localVersion, 12);
      expect(resolution.remoteUpdateAvailable, isFalse);
    });

    test('does not downgrade when bundledV < localV', () async {
      // Arrange: user downloaded v15, bundled is v12
      final resolution = await _resolve(
        localV: 15,
        bundledV: 12,
        manifestV: null,
      );

      expect(resolution.appliedBundledUpdate, isFalse);
      expect(resolution.localVersion, 15); // unchanged
    });

    test('flags remote update available when manifestV > localV', () async {
      final resolution = await _resolve(
        localV: 12,
        bundledV: 12,
        manifestV: 20,
      );

      expect(resolution.remoteUpdateAvailable, isTrue);
      expect(resolution.manifestVersion, 20);
    });

    test('is safe offline (manifest fetch returns null)', () async {
      final resolution = await _resolve(
        localV: 12,
        bundledV: 12,
        manifestV: null, // offline
      );

      expect(resolution.remoteUpdateAvailable, isFalse);
    });
  });

  group('CorpusUpdater', () {
    test('rejects download with mismatched SHA-256', () async {
      // Arrange: serve a valid DB file but provide wrong expectedSha256
      expect(
        () => updater.downloadAndApply(
          url: fakeUrl,
          expectedSha256: 'wrong_hash',
        ),
        throwsA(isA<CorpusUpdateException>()),
      );
    });

    test('rejects downgrade', () async {
      // Arrange: current local is v15, download has PRAGMA user_version = 10
      expect(
        () => updater.downloadAndApply(
          url: fakeUrl,
          expectedSha256: correctSha,
        ),
        throwsA(
          isA<CorpusUpdateException>()
            .having((e) => e.message, 'message', contains('Downgrade rejected')),
        ),
      );
    });
  });
}
```

**Expected outcome**: Version logic is verified in unit tests. Any regression in the comparison branches fails the test suite before reaching CI.

## Variants

<details>
<summary><strong>Variant: Bundled-only (no remote updates)</strong></summary>

If your app ships infrequently and the corpus always travels with the binary, you only need the bundled vs local comparison. Skip steps 5, 6, and 7 (download flow, staging manifests, manifest fetcher).

The resolver simplifies to:

```dart
Future<int> resolveVersionBundledOnly() async {
  final appDir = await getApplicationSupportDirectory();
  final localPath = '${appDir.path}/corpus_en.db';

  if (!File(localPath).existsSync()) {
    await _copyBundledToLocal(localPath);
    return await readDbVersionFromPath(localPath);
  }

  final localV = await readDbVersionFromPath(localPath);
  final bundledPath = await _extractBundledToTemp();
  final bundledV = await readDbVersionFromPath(bundledPath);

  if (bundledV > localV) {
    // App updated with a newer corpus — silent copy
    await File(bundledPath).copy(localPath);
    return bundledV;
  }

  return localV;
}
```

The pipeline still stamps `PRAGMA user_version`. The only difference is the app never checks a manifest and never shows a download prompt.

**When to use this variant**: Small apps, corpus changes only alongside app releases, strict offline requirements, no CDN infrastructure.

</details>

<details>
<summary><strong>Variant: Multiple locales</strong></summary>

Extend the resolver to handle per-locale databases. Each locale has its own `.db` file and its own entry in the manifest.

```dart
class MultiLocaleVersionResolver {
  final List<String> supportedLocales;
  final ManifestClient manifestClient;
  final DatabaseManager dbManager;

  Future<Map<String, VersionResolution>> resolveAll() async {
    final manifest = await manifestClient.fetchMultiLocale();
    final results = <String, VersionResolution>{};

    for (final locale in supportedLocales) {
      final resolver = VersionResolver(
        assetPath: 'assets/corpus_$locale.db',
        localDbFileName: 'corpus_$locale.db',
        fetchManifestVersion: () async => manifest?[locale]?.version,
        dbManager: dbManager,
      );
      results[locale] = await resolver.resolve();
    }

    return results;
  }
}
```

The multi-locale manifest:

```json
{
  "en": { "version": 42, "sha256": "abc...", "url": "..." },
  "fr": { "version": 38, "sha256": "def...", "url": "..." },
  "vi": { "version": 31, "sha256": "ghi...", "url": "..." }
}
```

Users see a per-language update badge. They choose which languages to download. The bundled asset is the default locale only (usually English).

</details>

<details>
<summary><strong>Variant: Background update check (no startup cost)</strong></summary>

If the manifest fetch is too slow to block startup, move it to a background task after the first frame.

```dart
// Startup: resolve bundled vs local only (fast, no network)
final resolution = await resolver.resolveBundledOnly();
runApp(MyApp(resolution: resolution));

// After first frame: check manifest in background
WidgetsBinding.instance.addPostFrameCallback((_) async {
  final manifestV = await manifestClient.fetch();
  if (manifestV != null && manifestV.version > resolution.localVersion) {
    // Emit to a stream; the home screen subscribes and shows the banner
    ref.read(updateAvailableStreamProvider.notifier).emit(manifestV);
  }
});
```

This keeps cold-start time at local-file-read speed while still surfacing remote updates within seconds of the first frame.

</details>

## Gotchas

> **Default PRAGMA user_version is 0**: Every `.db` file created by SQLite starts with `user_version = 0`. If your pipeline forgets to stamp it, all databases appear to be version 0. The app will treat the bundled DB as the same version as a freshly created empty file. **Fix**: Always assert `PRAGMA user_version != 0` as the last step of your pipeline build, and fail the build if the assertion fails.

> **Confusing PRAGMA user_version with Drift's schemaVersion**: Drift uses `PRAGMA user_version` internally as its schema migration counter for the user database. If you use Drift on your reference DB, it will overwrite the version you stamped. **Fix**: Never use Drift on the reference/asset database. Use raw `sqflite` for the reference DB. Keep Drift exclusively for the user DB.

> **32-bit signed integer range**: `PRAGMA user_version` stores a 32-bit signed integer (max ~2.1 billion). This is more than sufficient for build numbers but do not use negative values — SQLite will store them, but comparison logic expecting positive-monotonic versions will break. **Fix**: Use positive monotonic build numbers. Zero is "unstamped", positive is versioned, negative is reserved for nothing.

> **Reading PRAGMA user_version from the bundled asset**: Flutter's `rootBundle.load` gives you bytes. You cannot call `openDatabase` on an asset path directly — you must copy the bytes to a temp file first. **Fix**: Always extract the bundled asset to a temp path before calling `readDbVersionFromPath`. Clean up the temp file when done.

> **Replacing a DB file while a connection is open**: SQLite's WAL mode holds `.db-wal` and `.db-shm` sidecar files that remain locked during active transactions. Writing over the main `.db` file while connections are open causes "database disk image is malformed" errors on the next open. **Fix**: Always close all connections through the DB manager before file operations. Delete `.db-wal` and `.db-shm` files after closing and before swapping.

> **Manifest generated before the DB is built**: If your pipeline generates the manifest from a constant in a script (not by reading `PRAGMA user_version` from the finished file), the manifest version can be wrong. **Fix**: Always generate the manifest by querying `PRAGMA user_version` from the final output file. The canonical order is: build → stamp → read back → generate manifest → upload.

> **Downgrade after a bad release**: If you accidentally ship a corpus with bugs and push a corrected version, users who already downloaded the bad version have a higher local version than the corrected one (assuming you reverted the version number). The downgrade protection will block the fix. **Fix**: Never reuse or decrement version numbers. Always increment. If you need to ship a correction, bump the version to `oldBadVersion + 1` and push that.

> **SHA-256 computed on the wrong file**: Computing the hash before stamping `PRAGMA user_version` means the manifest hash does not match the distributed file (the stamp writes to the header). **Fix**: Compute the SHA-256 after stamping and after any post-processing. The manifest generation script must run after all file modifications are complete.

> **No WAL/SHM cleanup on iOS**: On iOS, `getApplicationSupportDirectory` paths persist across installs but the file system enforces strict permissions. Leftover `.db-wal` files from a crash during a previous swap can prevent the next open. **Fix**: On startup, check for orphaned WAL/SHM files (WAL exists but main DB is fresh/absent) and delete them before opening.

## Checklist

- [ ] Pipeline stamps `PRAGMA user_version` before computing SHA-256
- [ ] Pipeline asserts version != 0 and fails build if so
- [ ] Pipeline generates manifest by reading `PRAGMA user_version` from the output file, not from a constant
- [ ] `getDbVersion` helper is the single place `PRAGMA user_version` is read in Dart
- [ ] Bundled vs local comparison applied at startup before first frame
- [ ] Downgrade protection in place: never replace a higher-version DB with a lower one
- [ ] Download writes to `.tmp` file, verifies SHA-256, then swaps atomically
- [ ] DB manager closes connections and cleans up WAL/SHM before file swap
- [ ] Staging and production manifests point to separate endpoints
- [ ] `corpus_changelog` table seeded by pipeline at each build
- [ ] Changelog query uses `version > oldV AND version <= newV` (exclusive lower bound)
- [ ] Version resolver handles offline (manifest fetch returns null gracefully)
- [ ] Unit tests cover: fresh install, silent bundled update, no update needed, remote update available, downgrade rejection, offline
- [ ] Reference DB uses raw `sqflite`, not Drift (to avoid Drift overwriting `PRAGMA user_version`)
- [ ] Orphaned WAL/SHM files are cleaned up on startup

## Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Version helper | `lib/core/database/db_version.dart` | `getDbVersion` and `readDbVersionFromPath` |
| Version resolver | `lib/core/database/version_resolver.dart` | Startup comparison logic (bundled / local / manifest) |
| Corpus updater | `lib/core/database/corpus_updater.dart` | Download, verify SHA-256, atomic swap |
| Manifest client | `lib/core/database/manifest_client.dart` | Fetches and parses remote manifest |
| Environment config | `lib/core/config/environment.dart` | Staging vs production manifest URLs |
| Pipeline stamp script | `pipeline/build_all.sh` | Builds DB, stamps PRAGMA, generates manifest |
| corpus_changelog schema | `pipeline/schema.sql` | Changelog table definition |
| Bundled reference DB | `assets/corpus_en.db` | Shipped with app binary |
| Remote manifest | CDN / S3 bucket | `manifest.json` per environment |

## References

- [SQLite PRAGMA user_version](https://www.sqlite.org/pragma.html#pragma_user_version) — official documentation for the header field
- [SQLite file format](https://www.sqlite.org/fileformat.html#user_version_number) — byte offset 60, 32-bit big-endian integer
- [Dual Database Pattern](dual-database-pattern.md) — companion blueprint: reference DB vs user DB separation
- [Drift Database Migrations](drift-database-migrations.md) — for schema migrations in the user DB (not the asset DB)
- [sqflite package](https://pub.dev/packages/sqflite) — Flutter SQLite driver used for `rawQuery('PRAGMA user_version')`
- [crypto package](https://pub.dev/packages/crypto) — SHA-256 computation for download integrity verification
