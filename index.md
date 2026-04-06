# Blueprint Index

Organized catalog of all available blueprints. New blueprints should follow the **[Template](TEMPLATE.md)**.

---

## Project Setup

Bootstrapping new projects with proper conventions and structure.

| Blueprint | Summary |
|-----------|---------|
| [Flutter Project Kickoff](project-setup/flutter-project-kickoff.md) | Git branching, testing tiers, SemVer, PR conventions |
| [CLAUDE.md Conventions](project-setup/claude-md-conventions.md) | How to write an effective CLAUDE.md for AI-assisted development |

## CI/CD & Deployment

Continuous integration, delivery pipelines, and deployment automation.

| Blueprint | Summary |
|-----------|---------|
| [iOS TestFlight Deploy](ci-cd/ios-testflight-deploy.md) | App Store Connect, certificates, GitHub Actions, automatic signing |
| [GitHub Actions for Flutter](ci-cd/github-actions-flutter.md) | PR checks, deploy on merge/tag, caching, build numbers |
| [Git LFS in CI](ci-cd/git-lfs-in-ci.md) | When to use LFS, `.gitattributes` setup, CI checkout config |
| [Targeted CI Checks](ci-cd/targeted-ci-checks.md) | Run linters and tests only on changed files + their dependents |
| [Android Play Store Deploy](ci-cd/android-play-store-deploy.md) | GitHub Actions, Play App Signing, Fastlane supply, staged rollouts |

## Architecture

Proven architectural patterns and design decisions.

| Blueprint | Summary |
|-----------|---------|
| [Drift Database Migrations](architecture/drift-database-migrations.md) | Idempotent migrations, schema sync, testing with in-memory DB |
| [Multilingual Content Resolution](architecture/multilingual-content-resolution.md) | Layered fallback, locale immutability, corpus stack pattern |
| [Sealed Class Modeling](architecture/sealed-class-modeling.md) | Dart sealed classes, exhaustive switch, JSON discriminator |
| [Embedding Model Management](architecture/embedding-model-management.md) | ONNX model swap, re-generation, version bump, dimension checks |
| [Dual Database Pattern](architecture/dual-database-pattern.md) | Separate reference DB from user DB for independent content updates |
| [OAuth / Auth Flow](architecture/oauth-auth-flow.md) | OAuth 2.0 + PKCE, token lifecycle, social login, secure storage |
| [State Management Decision](architecture/state-management-decision.md) | Decision framework: Riverpod vs Bloc vs Provider, state categories |
| [Offline-First Architecture](architecture/offline-first-architecture.md) | Sync engine, conflict resolution, operation queue, CRDT |
| [Navigation & Routing](architecture/navigation-routing.md) | go_router, deep links, route guards, nested navigation, tab state |
| [Push Notifications](architecture/push-notifications.md) | FCM/APNs, permissions, local notifications, background handling |
| [Local Storage Decision](architecture/local-storage-decision.md) | SharedPreferences vs Hive vs SQLite vs SecureStorage decision guide |
| [Database Asset Versioning](architecture/database-asset-versioning.md) | PRAGMA user_version as single source of truth, bundled/downloaded/manifest comparison |
| [Corpus Download & Hot-Swap](architecture/corpus-download-hot-swap.md) | Safe DB download, SHA-256 verify, WAL cleanup, CorpusManager lifecycle, rollback |

## Workflow

Development processes, conventions, and knowledge management.

| Blueprint | Summary |
|-----------|---------|
| [KnowLoop Integration](workflow/knowloop-integration.md) | Warm-up, plan→task→commit linking, knowledge capture rules |
| [App Store Release Checklist](workflow/app-store-release-checklist.md) | End-to-end iOS + Android release process, review gotchas |
| [PR Strategy](workflow/pr-strategy.md) | Split vs merge PRs, QA-ability criterion, consolidation pattern |
| [Screen Interaction Graph](workflow/screen-interaction-graph.md) | Map all screens, navigations, overlays before coding — design gate |
| [Accessibility Checklist](workflow/accessibility-checklist.md) | Semantics, contrast, Dynamic Type, screen readers, touch targets |

## Patterns

Reusable design and code patterns extracted from production.

| Blueprint | Summary |
|-----------|---------|
| [Data Fallback Resolution](patterns/data-fallback-resolution.md) | Multi-layer fallback when data is incomplete or missing |
| [Riverpod Provider Wiring](patterns/riverpod-provider-wiring.md) | End-to-end provider wiring: bootstrap, ConsumerWidget wrapper, null-guard, tests |
| [Flutter UI Gotchas](patterns/flutter-ui-gotchas.md) | Stack clip, gesture detection, hit-testing, async state traps, i18n-first |
| [Data Pipeline i18n](patterns/data-pipeline-i18n.md) | Export→translate→seed pattern, JSON dicts, schema sync |
| [Error Handling & Logging](patterns/error-handling-logging.md) | Result type, error classification, Sentry, structured logging |
| [ViewModel Pure Functions](patterns/viewmodel-pure-functions.md) | Pure top-level functions, immutable state, IO-free, testable without Flutter |
| [Service Layer Pattern](patterns/service-layer-pattern.md) | Interface-based deps, cache+fallback chain, hand-written mocks, offline support |
| [AsyncNotifier Lifecycle](patterns/async-notifier-lifecycle.md) | build→state→mutate→invalidateSelf→rebuild cycle, settings persistence example |
| [API Integration Pattern](patterns/api-integration-pattern.md) | Dio interceptors, retry, caching, pagination, request dedup |
| [Testing Strategy](patterns/testing-strategy.md) | Unit, widget, golden, integration tests, CI shards, coverage gates |
| [Dependency Injection](patterns/dependency-injection.md) | Constructor injection, get_it, scoped deps, async init, test overrides |
| [Theming & Design System](patterns/theming-design-system.md) | Material 3 tokens, dark mode, responsive layout, component library |
| [Feature Flags & Remote Config](patterns/feature-flags-remote-config.md) | Staged rollouts, A/B testing, kill switches, flag lifecycle |
| [Money & Currency Handling](patterns/money-currency-handling.md) | Value object (int cents), signed amounts, exchange rates, formatting |
| [Onboarding Flow](patterns/onboarding-flow.md) | Multi-step wizard, first-launch gate, skip logic, progressive setup |
| [Data Export/Import & Backup](patterns/data-export-import.md) | CSV/JSON export, UTF-8 BOM, conflict detection, Google Drive backup |
| [Recurring Events & Scheduling](patterns/recurring-events-scheduling.md) | Recurrence rules, next occurrence, materialization, series editing |
| [Drift DAO Patterns](patterns/drift-dao-patterns.md) | @DriftAccessor, watch streams, aggregates, type converters (companion to Drift Migrations) |
| [Pagination & Infinite Scroll](patterns/pagination-infinite-scroll.md) | Cursor/offset/keyset pagination, scroll trigger, pull-to-refresh |
| [Form Validation](patterns/form-validation.md) | Reactive validation, field-level errors, submit gate, custom inputs |
| [Search Implementation](patterns/search-implementation.md) | Local + remote search, debounce, FTS5, suggestions, recent searches |
| [Spaced Repetition System](patterns/spaced-repetition-system.md) | SM-2/FSRS algorithm, card scheduling, review queue, analytics |
| [On-Device ML Inference](patterns/on-device-ml-inference.md) | ONNX Runtime mobile, embeddings, tokenization, batched inference, memory management |
| [Content Progress Tracking](patterns/content-progress-tracking.md) | Reading position, completion detection, streaks, session tracking, stats |
| [Block-Based Content Modeling](patterns/block-based-content-modeling.md) | Sealed class blocks, JSON discriminator, rendering pipeline, ordering |
