# service-template

[![CI](https://github.com/The-Pied-Piper/service-template/actions/workflows/ci.yml/badge.svg)](https://github.com/The-Pied-Piper/service-template/actions/workflows/ci.yml)

A GitHub template for **spec-first Python services**. You write an OpenAPI 3
contract; the template gives you a hexagonal-architecture
[Connexion 3](https://connexion.readthedocs.io/) (ASGI) service with Postgres,
migrations, tests and CI. When the contract changes you regenerate the plumbing
and keep every line of code you wrote by hand.

```
HTTP -> Connexion -> generated handler -> request adapter -> port -> service -> domain
                     (validates DTOs,     (DTO <-> domain)   (Protocol) (yours)
                      picks status)
```

## Why it exists

The opinion is **spec-first**: the contract comes first and the code follows it.
[Connexion](https://connexion.readthedocs.io/) follows from that choice. It is
the mainstream Python framework where the contract drives the code, whereas
FastAPI is code-first and derives the contract from the code afterwards.

Generating a service from a spec is easy once. The hard part is the second
change: most generators either overwrite your code or leave you to merge by hand.
Here the generator is vendored into the repo, owns only `app/generated/`, and
never touches files you own (see [Ownership](#ownership)). Template improvements
reach existing services through one command (`./dev.sh upgrade`).

### When an agent writes the code

When an AI agent writes most of the code, the contract is what a human still
reads and signs off: it is short, reviewable, and states what the service
promises. The boundary between generated and owned code also keeps the agent
away from the plumbing. `app/generated/` is rewritten from the spec and nothing
else, and CI's `check-generated` step fails if it has been edited by hand, so
any edit, by a person or an agent, belongs in the files you own. The human owns
the spec and the domain; the generator owns the rest.

## Everything runs in Docker

Everything runs in Docker: the app and Postgres via Compose, plain `pip` inside
the image. **You need Docker with Compose v2, plus bash and git** (the `./dev.sh` scripts
run on the host). No local Python, virtualenv or package manager, and there is
no non-Docker path. That is a
deliberate choice, so every machine and CI run uses the same environment.

## Try it

Docker with Compose v2 is the only thing to install (plus bash and git, which
most machines already have). The first build downloads images and takes a few
minutes.

```sh
git clone <your copy of this repo> my-service && cd my-service
./dev.sh init        # writes app/, tests/, README.md from the spec
./dev.sh up          # postgres + app with hot reload on :8080 (stays in the foreground)
```

In a second terminal, call the first endpoint:

```console
$ curl -i http://localhost:8080/api/v1/status/livez
HTTP/1.1 200 OK
date: Sun, 08 Nov 2026 07:03:04 GMT
server: uvicorn
content-type: application/json
content-length: 17

{"status": "ok"}
```

The example `openapi/openapi.yml` is a small Widget service, so this works out
of the box. The business endpoints answer `501 Not Implemented` until you fill in
the matching method in `app/application/services/<tag>_service.py`:

```console
$ curl -i http://localhost:8080/api/v1/widgets
HTTP/1.1 501 Not Implemented
date: Sun, 08 Nov 2026 07:03:04 GMT
server: uvicorn
content-type: application/problem+json
content-length: 91

{"type": "about:blank", "title": "Not Implemented", "detail": "listWidgets", "status": 501}
```

The Swagger UI is at `http://localhost:8080/api/v1/ui` (`./dev.sh docs` opens
it). `/api/v1` is the path in the contract's `servers` entry, so it changes with your contract.

The database login `app` / `app` in `compose.yaml` is for local development only.
Never reuse it anywhere reachable from a network.

## Who it is for

- You want a Python HTTP service where the OpenAPI contract is the source of
  truth and the code follows it.
- You are happy with the opinions here: Connexion 3, Pydantic, async SQLAlchemy
  and Alembic on Postgres, a hexagonal layout, Docker only.

- You are building a service you will keep changing, and you want to change the
  contract, not hand-edit generated code.

It is **not** for you if you need another web framework, another database, a
non-Docker workflow, or a generator that covers all of OpenAPI. It is also not
for generating client libraries or for languages other than Python.

How it differs from the usual alternatives:

- **cookiecutter** renders a project once. Afterwards the template and your
  project drift apart. Here `./dev.sh sync` regenerates from the spec at any time
  and `./dev.sh upgrade` pulls in template changes.
- **openapi-generator** is a general generator for many languages and
  frameworks. This is one opinionated stack, with the project scaffolding, tests,
  migrations and CI included, and a clear rule for which files are overwritten.

## Create a service

1. **Use this template** on GitHub (or clone and re-init), then clone your new repo.
2. Replace `openapi/openapi.yml` with your contract. Every operation needs an
   `operationId` (a tag is recommended; untagged operations go under `default`); bodies should `$ref` schemas under `components/schemas`.
3. Run `./dev.sh init` once, then `./dev.sh up`.
4. Commit. The generated `README.md` documents the service layout and day-to-day
   workflow (`./dev.sh help` lists every command). Copy `.env.example` to `.env`
   to change host ports or log level.

`./dev.sh` works from the host and from inside the app container (e.g. a VS Code
dev container). Inside, `compose.yaml` sets `IN_APP_CONTAINER=1` and commands run
directly; from the host they run in a one-off app container. Commands that manage
containers (`up`, `down`, `build`, `logs`, `fresh`, `psql`, `init`) run from the host.

## Evolve a service

Edit `openapi/openapi.yml`, then:

```sh
./dev.sh sync
```

`sync` rewrites `app/generated/` (Pydantic models + handlers) and creates
adapter/port/service stubs for any new tag. It never touches files you own; if a
new tag appeared it tells you to wire the adapter into `app/main.py`.

## Ownership

| Path | Owner | On `sync` | On `upgrade` |
| --- | --- | --- | --- |
| `app/generated/**` | generator | overwritten | overwritten (via sync) |
| `app/adapters/inbound/*_adapter.py`, `app/application/ports/*_port.py`, `app/application/services/*_service.py` | you (scaffolded once) | created if missing | untouched |
| `app/main.py`, `app/worker.py`, `app/wiring.py`, `app/__main__.py`, `app/settings.py`, `app/adapters/inbound/http_errors.py`, `app/adapters/inbound/jobs_*.py`, `app/domain/**`, `app/adapters/outbound/**`, `app/application/ports/*.py`, `app/application/services/{job_registry,run_due_jobs}.py`, `tests/**`, `README.md` | you (written by `init`) | untouched | untouched |
| `Dockerfile`, `compose.yaml`, the root `requirements*.in` and `requirements*.txt`, `pyproject.toml`, `alembic.ini`, `migrations/` | you (shipped plain; `init` adds the `job_runs` migration) | untouched | untouched |
| `dev.sh`, `scripts/`, `tools/service_gen/`, `.github/workflows/ci.yml` | template | untouched | **replaced** |
| `service_scripts/` (the service's own `./dev.sh` commands) | you (shipped with a README) | untouched | untouched |

## Scheduled jobs

A service can run work on a schedule (a nightly purge, a monthly report) without a scheduler
of its own, and without being tied to any one cloud. It works like Django's cron
apps: the service keeps a list of jobs, each with a cron schedule, and one command, **run due
jobs**, runs whatever is due. Something outside the service fires that command on a clock
(EventBridge, `cron`, a Kubernetes CronJob). Nothing is scheduled inside the process.

```sh
./dev.sh run-due-jobs              # the same as: python -m app run-due-jobs
python -m app serve                # the HTTP server (the same as the image's default uvicorn command)
```

**Register a job** in `register_jobs` in `app/wiring.py`. A job is an async function with no
arguments, built from the same repositories the endpoints use. The template ships none.

```python
registry.register("purge-old-messages", "0 0 * * *", purge_service.run)
```

The schedule is five-field cron in UTC: `*`, lists, ranges and steps, numbers only; day of week
is 0-6 with 0 as Sunday. A bad schedule or a duplicate name raises when the job runner builds its
list, so the generated tests (which build it without a database) fail in CI instead of at midnight.

**What happens on each run.** For every job: read its row in `job_runs`; it is due when it
never ran, or when its schedule has fired since it last started, so a tick that was missed is
picked up by the next one. A due job is claimed with one atomic database write (it succeeds
only if nobody else started the job since the row was read), run, and marked finished with
its error text if it raised. Two overlapping ticks never run a job twice. A run that has been
going for more than an hour is taken as crashed and its lock is ignored, so keep every job
shorter than that (a job that outlives it is started again by a later tick, and the first run's
late finish is ignored). One job failing never stops the others; the command exits 1 if any
failed. A failed job is not retried until its next scheduled time.

Extra ticks cost nothing, because a job that is not due is skipped. Trigger the command more often
than your finest schedule, for example hourly, or a few minutes past the fire time: a tick that
lands a second early (the runner's own clock decides) skips the job until the next tick. If the
trigger dies partway through the list, the jobs not reached run at the next tick.

**Layout.** The "is it due" rule and cron parsing are in the domain (`schedule.py`,
`job_run.py`). The application has the registry and the `RunDueJobs` service, which talks only to
ports (`JobRunStore`, `Clock`). Postgres and the system clock are outbound adapters. The
`run-due-jobs` command and the Lambda handler are inbound adapters that call the `JobRunner` port.
There are two composition roots, `app/main.py` (HTTP server) and `app/worker.py` (job runner),
and both take their engine, clock and repositories from the shared `app/wiring.py`. Put a
repository that a job and an endpoint both use on `Wiring`.

**Images.** The `prod` target is the HTTP server. The `jobs` target runs `python -m app
run-due-jobs`, for a CronJob or a scheduled container task. The `jobs-lambda` target is the same
as an AWS Lambda container image (handler `app.worker.handler`, via the Runtime Interface
Client). Both are built from the stage before `prod`, so a Lambda Web Adapter you add to `prod`
is not in them. That matters because the adapter waits for a web server on its port before it
serves anything, so a job invocation cannot share the web image. A handler failure means a job
raised, so Lambda's error metric shows it. Use the same database settings as the web service. The
`jobs-lambda` target's pins are in `requirements-lambda.txt`. Anything you add to `prod` that the
job runner also needs (system packages, `ENV`) belongs in the `runtime` stage instead.

An existing service adopts this by hand: see "Unreleased" in `CHANGELOG.md`.

## Known limits

The generator is small on purpose. It does not try to cover all of OpenAPI:

- **Every operation needs an `operationId`.** A missing or duplicate one stops
  `init` and `sync` with an error.
- **External `$ref`s are not supported** (anything not starting with `#/`); the
  tool stops with an error. Keep the contract in one file.
- **Only the first tag** of an operation is used to group it; operations without
  a tag go under `default`.
- **Only JSON bodies are typed.** Other media types are passed through as `Any`.
- **Only the lowest 2xx response** is used for the handler's status and return
  type; other responses are not generated.
- **Paging is recognised by name.** An operation with a `pageToken` parameter gets a
  port that takes a `cursor`, and a plain `limit` when it also has an integer
  `pageSize` or `maxPageSize`. The adapter keeps the page size policy (the spec's
  default, capped at its maximum; a size below 1 gets the default). If the spec names
  no default or maximum, or one that is not a whole number from 1 to 10,000, the adapter uses 50 and 100 in its place
  (each value on its own; the default is then capped at the maximum). A page
  size that is not an integer, or is named otherwise, stays an ordinary parameter.
  A token named anything else, or a parameter or body property already called `limit` (with a page
  size) or `cursor`, leaves the port HTTP-shaped, for you to reshape by hand.
- **It generates the HTTP layer, not your business logic.** Services, domain,
  outbound adapters (database access), migrations and tests are yours to write.
- Postgres and Docker only, as above.

## Troubleshooting

**`git pull` or `git push` over ssh fails inside the container.** Your ssh agent
(never your keys) and your git name and email are shared with the container, and
how depends on how you started it.

- **VS Code dev container:** VS Code forwards your host agent itself. Start your
  agent on the host first, then reopen the container.
- **`./dev.sh shell` and other `./dev.sh` commands:** `./dev.sh` mounts your agent's
  socket and passes your git name and email. Start the agent and add your key
  first (`eval "$(ssh-agent -s)"` and `ssh-add`), then start the container again.
  On Docker Desktop (macOS, or Linux with a `desktop-*` Docker context) it uses
  Docker Desktop's agent socket (`/run/host-services/ssh-auth.sock`), which is
  untested here and may be root-only for the container's non-root user. Other
  engines (Colima, OrbStack, Podman) may not provide that path, and a remote
  `DOCKER_HOST` cannot see your local socket. If starting the container fails on
  the agent mount, or you do not want the agent shared, run
  `DEV_SSH_AGENT=0 ./dev.sh <command>` (an `SSH_AGENT_SOCKET` already set in your
  shell wins over this, so `unset SSH_AGENT_SOCKET` first if you exported one). To
  mount a different socket, set `SSH_AGENT_SOCKET` to its path; if that path does
  not exist, starting the container fails with "bind source path does not exist".
- **Plain `docker compose run app`:** no agent is shared, and git name and email
  are passed only if the `GIT_*` variables are already set in your shell. Set
  `SSH_AGENT_SOCKET` and the `GIT_*` variables yourself. This also
  needs a recent Docker Compose v2, and your uid and gid to be 1000 or exported as
  `UID` and `GID`.

Over HTTPS no agent is needed. The first ssh connection to a host asks you to trust
its key, and asks again in each new one-off container (`run --rm`), because the
container's `~/.ssh` is not kept.

**`gh` says you are not logged in.** Export `GH_TOKEN` in your host shell before
starting the container (compose passes it through), or run `gh auth login` inside
it. The image's `gh` is the version Debian ships, which can lag behind GitHub's
newest release. `ping` relies on Docker's default setting for unprivileged ping, so
it fails under a custom `--sysctl net.ipv4.ping_group_range` or a hardened runtime.

## CI

Every service gets `.github/workflows/ci.yml` out of the box. On pushes to `main`
and `dev` and on pull requests it builds the dev image (cached) and runs `./dev.sh check` — the
same image and command as locally — and builds the production image once
`app/` exists. `check` is, in order:

| Step | Fails when |
| --- | --- |
| `check-generated` | `app/generated/` doesn't match what `sync` produces from the spec |
| `lint` | ruff check / format, `openapi/openapi.yml` is not valid OpenAPI 3, or (once `app/` exists) a layer rule is broken, see below |
| `typecheck` | mypy `--strict` |
| `test` | pytest (against the compose Postgres) |
| `check-migrations` | `alembic upgrade head` fails, or ORM models drifted from the migrations |

The layer rules are `[tool.importlinter]` contracts in `pyproject.toml`, which the
service owns: add contracts as it grows.

- Layers point inward: `app.__main__`, then the two composition roots `app.main` and
  `app.worker` (which never import each other), then `app.wiring` (what both share),
  `app.adapters`, `app.application`, `app.domain`.
  Any other module under `app/` must be added to the layers (`app.generated` and
  `app.settings` are exempt), so a new module cannot slip in unchecked.
- The domain and application import none of Connexion, FastAPI, Starlette, httpx,
  jsonschema, Pydantic, SQLAlchemy, asyncpg, Alembic, `asyncio`, `app.generated` or
  `app.settings`.
- Outbound adapters import none of Connexion, FastAPI, Starlette, jsonschema, Pydantic
  or `app.generated`, directly. An outbound HTTP client (httpx) is allowed there.
- Every module or folder under `app.adapters` is `inbound` or `outbound`, and the two
  sides never import each other.
- Adapters and generated code never import `app.application.services`: only `app.main`
  knows the services. Adapters import ports; generated code does not (next rule).
- `app.application` holds only `services` and `ports`, and services import ports, never
  the reverse. A new module or folder there must be placed in one of them or in the rule.
- Generated code (`app.generated`) directly imports nothing from the application, domain,
  outbound adapters, settings or `app.main`; its handlers reach the application through
  the inbound adapter they call (indirect imports are allowed).
- Inbound adapters touch no database library (SQLAlchemy, asyncpg, Alembic) and no settings.
- `app.settings` imports nothing else from the app.
- `app.main`, `app.worker` and `app.wiring` are the composition roots and their shared factory.
  They directly import concretes only: no ports, domain
  modules, generated models, Pydantic or `pydantic_core` (pass a longer list of probes
  inline or as a tuple: annotating it with the port type is not allowed). Translating errors
  into responses belongs to the inbound adapter `http_errors.py`.
- `app.worker` loads no web framework, `app.generated` or `app.main`, even through another
  module, so the job runner stays small and never builds the web application.

A folder without an `__init__.py` is invisible to import-linter, so ruff's `INP001`
fails the lint step for one under `app/`. Every contract has a planted-violation test
(`test_each_layer_rule_catches_its_planted_violation`) for each module it forbids and each
direction it checks. Import-linter denies named libraries only: a library not named in
a rule (`requests`, `redis`) is not caught.

The CI workflow is template-owned, so put service-specific jobs (deploy, publish) in
separate workflow files.

## Upgrading a service to a newer template

```sh
./dev.sh upgrade            # latest main
./dev.sh upgrade v0.1.0     # a release tag
./dev.sh upgrade <branch>   # another branch of the template
```

Replaces the template-owned paths from this repo, records the version in
`TEMPLATE_VERSION`, rebuilds the dev image and runs `sync`. Review the result as
one PR: generator diff + regenerated code + any manual edits that are needed.
If the generator's pins changed, recompile `requirements-dev.txt` (the command is in
its header) so it matches `tools/service_gen/requirements.txt`; a test checks they agree.

Where the template is fetched from, in order: the `TEMPLATE_REPO` environment
variable, then the `TEMPLATE_REPO` file that `./dev.sh init` writes. By default
`init` records this template at the same host and scheme (SSH or HTTPS) as the
service's own `origin`, so access that works for the service works for the
template; pass `./dev.sh init --template-repo URL` to record a fork or mirror
instead. The `OWNER/REPO.git` used for the default comes from `$TEMPLATE_PATH`,
else the `TEMPLATE_HOME` file; a copy of the template points it at its own
repository.

## Layout of this repo (= an un-initialised service)

```
openapi/openapi.yml      example contract; a service replaces this
Dockerfile               dev target (tooling, git, ssh, gh, psql, bind mount), prod (slim), and the job runner targets jobs and jobs-lambda
compose.yaml             app + postgres:16 (.env.example lists the knobs)
requirements*.txt        pinned versions: runtime, tooling, and tools/service_gen/ (generator); compiled with uv (see the header of requirements.txt)
requirements*.in         the loose lists those are compiled from
pyproject.toml           ruff / mypy / pytest config only
alembic.ini, migrations/ async Alembic wired to app.settings
dev.sh                   dispatcher: ./dev.sh <cmd> -> scripts/<cmd>.sh, else service_scripts/<cmd>.sh
scripts/                 one command per file; line 2 is its help text
service_scripts/         a service's own commands, same shape; never replaced by upgrade
tools/service_gen/       the generator: cli.py, spec.py, render.py, templates/, tests/
.github/workflows/ci.yml lint + typecheck + test in Docker; prod image build
TEMPLATE_VERSION         what a service was last upgraded to
```

The service package is always `app/` and settings use the `APP_` env prefix, so
Dockerfile, compose and Alembic are plain files rather than templates.

## Maintenance

This is a small project, maintained on a best-effort basis. Contributions are
welcome: issues, questions and pull requests. Replies may take a few days. See
[CONTRIBUTING.md](CONTRIBUTING.md) to get started and [SECURITY.md](SECURITY.md)
to report a vulnerability. Issues labelled "good first issue" are a good place
to begin.

## Roadmap

Plans are tracked as [milestones](../../milestones) on GitHub:

- **After launch**: CI that creates a fresh service and runs its full check on
  Linux and macOS, pinned GitHub Actions, documenting which choices are options
  and which are opinions, a release process, and launch material.
- **1.0**: the generator published as a Python package, and the skeleton as a
  Copier template.

## Developing the template

```sh
./dev.sh test tools/service_gen/tests    # generator tests (init + sync + a full request flow)
./dev.sh lint && ./dev.sh typecheck
./dev.sh init && ./dev.sh up             # try the result; `git clean -fd app tests && git checkout README.md` to reset
```

Templates live in `tools/service_gen/templates/`: `project/` is written once by
`init`, `generated/` is rewritten by every `sync`, `stubs/` are created only when
missing. If a change needs manual steps in services, say so in the PR description.

## License

This template is licensed under Apache-2.0; see [LICENSE](LICENSE). A service you
create from it does not inherit any licence obligation from the template: you
choose your service's licence.
