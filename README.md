# Blueprint

A collection of **reusable blueprints** extracted from real-world projects.

Each blueprint is a standalone, human-readable markdown document capturing proven patterns, step-by-step guides, and hard-won gotchas — so you never start from zero.

## Philosophy

- **Generic first** — blueprints work across projects, not tied to one codebase
- **Battle-tested** — every blueprint comes from real production experience
- **Actionable** — checklists and steps you can follow, not abstract theory
- **Living documents** — blueprints evolve as we learn more

## Structure

```
blueprint/
├── README.md
├── project-setup/        # New project bootstrapping
├── ci-cd/                # CI/CD pipelines & deployment
├── architecture/         # Architectural patterns & decisions
├── workflow/             # Development workflow & conventions
└── patterns/             # Reusable code & design patterns
```

## Blueprint Format

Each blueprint follows a consistent structure:

```markdown
# Blueprint: <Title>

> One-line summary of what this blueprint covers.

## When to Use
Context and situations where this blueprint applies.

## Prerequisites
What you need before starting.

## Steps
Numbered, actionable checklist.

## Gotchas
Known pitfalls and how to avoid them.

## Checklist
Quick validation checklist before considering it "done".

## References
Links to source material, KnowLoop notes, external docs.
```

## Categories

| Category | Description |
|----------|-------------|
| **project-setup** | Bootstrapping new projects with proper conventions |
| **ci-cd** | Continuous integration, deployment pipelines, TestFlight, GitHub Actions |
| **architecture** | Proven architectural patterns (DB migrations, multilingual, sealed classes...) |
| **workflow** | Git conventions, code review, knowledge capture processes |
| **patterns** | Reusable design patterns extracted from production code |

## Source

Blueprints are extracted and generalized from knowledge captured in [KnowLoop](https://github.com/Lsh0x/KnowLoop) across multiple projects.

## License

MIT
