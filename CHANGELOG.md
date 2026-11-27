# Changelog

Notes on each release. Anything a service must do by hand after `./dev.sh upgrade`
is listed under "Manual steps".

## Unreleased

- Scheduled jobs: a registry of `(name, cron schedule, function)`, a `run-due-jobs` command that
  runs what is due and records each run in a `job_runs` table, and a Lambda handler for the same.
  The trigger is left to infrastructure. See "Scheduled jobs" in the README.
- `python -m app serve | run-due-jobs`; `./dev.sh run-due-jobs`.
- Two composition roots (`app/main.py`, `app/worker.py`) share `app/wiring.py`.
- Dockerfile: new `runtime` stage that `prod` builds on, plus `jobs` and `jobs-lambda` targets.
- Layer rules: `__main__`, `worker` and `wiring` are placed in the layers; the domain and
  application may not import `asyncio`; the job runner loads no web framework.

Manual steps for an existing service (`init` has already written all of this into a new one):
copy the new files `./dev.sh init` writes (in a scratch checkout) into `app/` and `tests/` and the
`job_runs` migration into `migrations/versions/`, chaining its `down_revision` onto your latest
revision; point `app/main.py` at `build_wiring` as the new template's `main.py` does (its
`build_adapters` now takes the wiring instead of the engine); update the `layers`,
`core-framework-free` and `main-wires-concretes-only` contracts and add `worker-is-web-free` in
`pyproject.toml`; and replace the `prod` section of your Dockerfile as in the template's.
If your `prod` stage adds the Lambda Web Adapter, keep that in `prod` only.

## v0.1.0

First public release.

- Spec-first Python service template: OpenAPI contract, Connexion 3, hexagonal layout,
  Postgres, Alembic migrations, tests and CI, all run in Docker.
- Vendored generator that owns only `app/generated/`; `./dev.sh sync` regenerates it.
- `./dev.sh upgrade [ref]` pulls newer template-owned files into an existing service.
- Layer rules enforced by import-linter, with a test that plants a violation for each rule.
- Runs on Python 3.15 (`python:3.15-slim` base image); the pinned requirements are still compiled for Python 3.12.

Manual steps: none (first release).
