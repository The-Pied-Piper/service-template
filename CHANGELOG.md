# Changelog

Notes on each release. Anything a service must do by hand after `./dev.sh upgrade`
is listed under "Manual steps".

## v0.1.0

First public release.

- Spec-first Python service template: OpenAPI contract, Connexion 3, hexagonal layout,
  Postgres, Alembic migrations, tests and CI, all run in Docker.
- Vendored generator that owns only `app/generated/`; `./dev.sh sync` regenerates it.
- `./dev.sh upgrade [ref]` pulls newer template-owned files into an existing service.
- Layer rules enforced by import-linter, with a test that plants a violation for each rule.

Manual steps: none (first release).
