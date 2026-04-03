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

## Workflow

Development processes, conventions, and knowledge management.

| Blueprint | Summary |
|-----------|---------|
| [KnowLoop Integration](workflow/knowloop-integration.md) | Warm-up, plan→task→commit linking, knowledge capture rules |
| [App Store Release Checklist](workflow/app-store-release-checklist.md) | End-to-end iOS + Android release process, review gotchas |

## Patterns

Reusable design and code patterns extracted from production.

| Blueprint | Summary |
|-----------|---------|
| [Data Fallback Resolution](patterns/data-fallback-resolution.md) | Multi-layer fallback when data is incomplete or missing |
| [Flutter UI Gotchas](patterns/flutter-ui-gotchas.md) | Stack clip, gesture detection, hit-testing, positioned children |
| [Data Pipeline i18n](patterns/data-pipeline-i18n.md) | Export→translate→seed pattern, JSON dicts, schema sync |
| [Error Handling & Logging](patterns/error-handling-logging.md) | Result type, error classification, Sentry, structured logging |
| [API Integration Pattern](patterns/api-integration-pattern.md) | Dio interceptors, retry, caching, pagination, request dedup |
