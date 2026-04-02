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

## Architecture

Proven architectural patterns and design decisions.

| Blueprint | Summary |
|-----------|---------|
| [Drift Database Migrations](architecture/drift-database-migrations.md) | Idempotent migrations, schema sync, testing with in-memory DB |
| [Multilingual Content Resolution](architecture/multilingual-content-resolution.md) | Layered fallback, locale immutability, corpus stack pattern |
| [Sealed Class Modeling](architecture/sealed-class-modeling.md) | Dart sealed classes, exhaustive switch, JSON discriminator |
| [Embedding Model Management](architecture/embedding-model-management.md) | ONNX model swap, re-generation, version bump, dimension checks |

## Workflow

Development processes, conventions, and knowledge management.

| Blueprint | Summary |
|-----------|---------|
| [KnowLoop Integration](workflow/knowloop-integration.md) | Warm-up, plan→task→commit linking, knowledge capture rules |

## Patterns

Reusable design and code patterns extracted from production.

| Blueprint | Summary |
|-----------|---------|
| [Data Fallback Resolution](patterns/data-fallback-resolution.md) | Multi-layer fallback when data is incomplete or missing |
| [Flutter UI Gotchas](patterns/flutter-ui-gotchas.md) | Stack clip, gesture detection, hit-testing, positioned children |
| [Data Pipeline i18n](patterns/data-pipeline-i18n.md) | Export→translate→seed pattern, JSON dicts, schema sync |
