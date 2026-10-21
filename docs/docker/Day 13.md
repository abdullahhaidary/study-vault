# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 13 — ADVANCED DOCKER COMPOSE: HEALTH CHECKS, SERVICE DEPENDENCIES, RESTART POLICIES, CONFIGURATION PRECEDENCE, MULTIPLE COMPOSE FILES, AND DEVELOPMENT WORKFLOWS

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 13 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 5–6 hours  
**Assessment Type:** Theoretical Examination, Practical Laboratory, and Configuration Analysis

**Prerequisites:**

- Lectures 01–07 — Docker Fundamentals.
- Lecture 08 — Ports and Environment Variables.
- Lecture 09 — Docker Storage and Persistence.
- Lecture 10 — Networking and Service Discovery.
- Lecture 11 — Docker Compose Fundamentals.
- Lecture 12 — Flask and Redis Multi-Container Application.

---

# 1. LECTURE OVERVIEW

## 1.1 Purpose

Docker Compose provides a declarative mechanism for defining and operating multi-container applications.

The preceding lectures introduced the fundamental Compose model and demonstrated the integration of a Flask web application with a Redis data service.

However, an application that starts successfully is not necessarily ready for reliable operation.

Real applications may experience:

- Slow service initialization.
- Temporary dependency failures.
- Container process crashes.
- Configuration inconsistencies.
- Incorrect environment variable values.
- Application source-code changes.
- Dependency updates.
- Conflicting deployment settings.
- Storage and filesystem permission failures.
- Unintended differences between development and staging environments.

These conditions require mechanisms beyond basic service creation.

Lecture 13 introduces the operational and configuration facilities used to address such requirements.

The principal topics are:

1. Container health monitoring.
2. Service readiness.
3. Dependency management.
4. Runtime restart policies.
5. Compose-controlled dependency restarts.
6. Environment variable precedence.
7. Configuration interpolation.
8. Multiple Compose files.
9. Development and staging overrides.
10. Service profiles.
11. Compose Watch.
12. Bind-mounted development workflows.
13. Configuration validation.
14. Operational diagnostics.
15. Controlled recovery and service recreation.

## 1.2 Academic Significance

Advanced Compose configuration requires understanding several independent mechanisms.

The process lifecycle of a container is controlled differently from the health of its application.

The configuration used to construct an image is different from the configuration applied during container creation.

The operation that restarts an existing container is different from the operation that recreates a container with modified settings.

Application dependency ordering is different from runtime dependency recovery.

These distinctions are essential to correct container operations.

---

# 2. LEARNING OBJECTIVES

Upon successful completion of the lecture, the student should be able to:

1. Explain the advanced operational responsibilities of Docker Compose.
2. Distinguish container execution state from application health.
3. Define liveness, readiness, and health checking.
4. Explain how Docker executes container health checks.
5. Interpret healthy, unhealthy, and starting states.
6. Configure health checks using the Compose service model.
7. Explain the meaning of health-check intervals, timeouts, retries, and startup grace periods.
8. Describe the three principal Compose dependency conditions.
9. Distinguish dependency startup ordering from application readiness.
10. Explain health-aware dependency management.
11. Interpret Compose dependency restart propagation.
12. Distinguish Compose dependency restarts from Docker runtime restart policies.
13. Explain the principal container restart policies.
14. Describe why an unhealthy container is not necessarily restarted automatically.
15. Explain runtime configuration precedence.
16. Distinguish project `.env` files from service-level `env_file`.
17. Explain the relationship between Dockerfile `ENV` and Compose environment settings.
18. Apply variable interpolation.
19. Use default and required-value interpolation expressions.
20. Verify effective container environment variables.
21. Explain how Compose merges multiple configuration files.
22. Construct development and staging configuration overrides.
23. Describe the principal limitations of file merging.
24. Explain the purpose of Compose profiles.
25. Configure optional diagnostic services.
26. Define the Compose development specification.
27. Explain Compose Watch and its supported actions.
28. Distinguish source synchronization from image rebuilding.
29. Compare Compose Watch with bind-mounted development files.
30. Configure a non-root application compatible with source synchronization.
31. Apply a read-only root filesystem to a suitable service.
32. Use temporary filesystems for required writable runtime paths.
33. Validate effective Compose configurations before deployment.
34. Diagnose startup and readiness problems.
35. Demonstrate persistent data retention across deployment changes.
36. Complete a reproducible advanced Compose laboratory.

---

# PART I — ADVANCED COMPOSE THEORY

# 3. APPLICATION LIFECYCLE VERSUS APPLICATION HEALTH

## 3.1 Process State

A Docker container ordinarily remains running while its designated principal process remains active.

For example, a container executing Gunicorn may continue running as long as the Gunicorn process remains active.

However, the Flask application may have lost access to Redis.

The application process is running, but its primary functionality is unavailable.

## 3.2 Application Health

Application health describes whether selected operational conditions are satisfied.

A health check evaluates a particular condition and reports its result.

Examples include:

- Whether an HTTP endpoint responds.
- Whether a database accepts commands.
- Whether a required local file exists.
- Whether an application can reach a critical dependency.

## 3.3 Two Independent Properties

Consider:

```text
Container State: Running

Application Readiness: Unavailable
```

This situation is possible.

A running container does not imply that every application operation is successful.

## 3.4 Conceptual Architecture

```text
DOCKER CONTAINER → PRINCIPAL PROCESS
PRINCIPAL PROCESS → RUNNING
PRINCIPAL PROCESS → APPLICATION HEALTH
APPLICATION HEALTH → HEALTHY
APPLICATION HEALTH → UNHEALTHY
```

The process state and health state provide different information about the system.

---

# 4. LIVENESS, READINESS, AND STARTUP CONDITIONS

## 4.1 Liveness

Liveness asks:

**Is the application process responsive enough to satisfy a basic operational check?**

A liveness endpoint may verify that the HTTP server can return a simple response.

Example:

```text
GET /health/live
```

## 4.2 Readiness

Readiness asks:

**Can the application perform the operations it is expected to provide?**

A counter application may require Redis connectivity.

Example:

```text
GET /health/ready
```

The endpoint can attempt a Redis `PING` operation.

## 4.3 Startup Conditions

An application may require additional initialization time before becoming ready.

Examples include:

- Loading configuration.
- Connecting to a database.
- Performing migrations.
- Initializing caches.
- Loading application models.

A health-check startup grace period can prevent certain early failures from immediately contributing toward an unhealthy classification.

## 4.4 Comparison

| Concept | Primary concern | Example |
|---|---|---|
| Container running state | Whether the principal process is active | Gunicorn process exists |
| Liveness | Basic process responsiveness | HTTP liveness endpoint returns 200 |
| Readiness | Ability to perform required work | Flask can communicate with Redis |
| Startup grace period | Initial allowance for service initialization | Health-check failures during startup |

## 4.5 Important Qualification

Docker Engine provides a container health-check mechanism.

It does not maintain separate first-class Kubernetes-style liveness and readiness probes.

An application may expose distinct endpoints, but the Docker health-check configuration selects the particular test used to classify the container as healthy or unhealthy.

---

# 5. DOCKER HEALTH-CHECK STATES

Docker commonly reports three health states.

## 5.1 Starting

The container's health check has not yet established a successful health state.

The application may still be initializing.

## 5.2 Healthy

The configured health check has returned successful results according to the applicable evaluation rules.

## 5.3 Unhealthy

The configured health check has failed sufficiently often to satisfy the unhealthy threshold.

## 5.4 State Model

```text
CONTAINER STARTS → STARTING
STARTING → HEALTH CHECK
HEALTH CHECK → SUCCESS
HEALTH CHECK → REPEATED FAILURE
SUCCESS → HEALTHY
REPEATED FAILURE → UNHEALTHY
HEALTHY → SUBSEQUENT CHECKS
UNHEALTHY → SUBSEQUENT CHECKS
```

A container can move between healthy and unhealthy states while remaining in the running state.

---

# 6. HEALTH-CHECK CONFIGURATION

## 6.1 Compose Syntax

Example:

```yaml
services:
  redis:
    image: redis:7-alpine

    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
```

## 6.2 test

Defines the command used to evaluate health.

The command executes within the container environment.

## 6.3 interval

Defines the interval between health-check executions according to Docker's scheduling behavior.

Example:

```yaml
interval: 5s
```

## 6.4 timeout

Defines how long a health-check execution may run before it is considered unsuccessful due to timeout.

Example:

```yaml
timeout: 3s
```

## 6.5 retries

Defines the number of consecutive qualifying failures required before the container is classified as unhealthy.

Example:

```yaml
retries: 5
```

## 6.6 start_period

Defines an initial grace period during which failures do not ordinarily contribute to the unhealthy threshold.

A successful health check during the startup period can end the startup grace behavior.

## 6.7 Interpretation

A service requiring significant initialization time may need a longer startup grace period than a simple in-memory application.

Health-check settings should correspond to actual startup and operational behavior.

---

# 7. HEALTH-CHECK COMMAND FORMS

## 7.1 CMD

The exec-style form executes a command directly.

Example:

```yaml
test: ["CMD", "redis-cli", "ping"]
```

## 7.2 CMD-SHELL

The shell form executes through the relevant command shell.

Example:

```yaml
test:
  - CMD-SHELL
  - "redis-cli ping | grep -q PONG"
```

This form requires an appropriate shell and any referenced utilities to be present in the container image.

## 7.3 Exit Codes

A health-check command uses its exit status to communicate success or failure.

Conventionally:

```text
0 = Success

1 = Failure
```

Other exit statuses may have specialized meanings.

Docker's health-check system interprets the result according to its documented rules.

## 7.4 Important Principle

A health-check command must be compatible with the tools actually included in the image.

A minimal image may not contain Bash, curl, or other familiar utilities.

---

# 8. HEALTH-CHECK DESIGN

## 8.1 Incorrectly Weak Checks

A health check that merely verifies a process exists may miss application failures.

For example, Gunicorn may continue running when Redis is unavailable.

## 8.2 Incorrectly Expensive Checks

A health check should not normally execute a costly operation every few seconds.

Frequent expensive checks can create unnecessary load.

## 8.3 Destructive Checks

A health check should avoid modifying important application data.

A database health check should not delete records or execute complex migrations.

## 8.4 Practical Design Principles

A useful health check should be:

- Relevant.
- Relatively inexpensive.
- Bounded by timeouts.
- Reliable.
- Non-destructive.
- Compatible with the image.
- Representative of the condition being assessed.

## 8.5 Health-Check Limitations

A successful health check does not prove that every application function is correct.

It establishes only that the selected test succeeded.

---

# 9. SERVICE DEPENDENCIES

## 9.1 Definition

A service dependency expresses a relationship between components whose startup or shutdown operations must be coordinated.

Compose provides the `depends_on` attribute.

## 9.2 Short Syntax

```yaml
services:
  web:
    depends_on:
      - redis
```

The short syntax establishes startup ordering.

Redis is started before the web service.

## 9.3 Limitation

The short syntax does not ordinarily require Redis to complete application initialization or become healthy before the web service starts.

## 9.4 Long Syntax

```yaml
services:
  web:
    depends_on:
      redis:
        condition: service_healthy
```

The long syntax allows more precise dependency conditions.

---

# 10. DEPENDENCY CONDITIONS

Compose supports three principal dependency conditions.

## 10.1 service_started

The dependency must have been started.

This is equivalent to the essential short-form dependency behavior.

## 10.2 service_healthy

The dependency must satisfy its configured health check.

Example:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

## 10.3 service_completed_successfully

The dependency must complete successfully.

This is useful for one-off initialization operations.

For example, a database migration service may need to complete before the main application starts.

## 10.4 Comparison

| Condition | Required state | Typical use |
|---|---|---|
| `service_started` | Dependency started | Simple ordering |
| `service_healthy` | Dependency health check successful | Databases and support services |
| `service_completed_successfully` | Dependency exits successfully | Initialization or migration jobs |

## 10.5 Important Distinction

Dependency conditions are primarily concerned with coordinated startup.

They do not guarantee that an application dependency will remain available indefinitely.

---

# 11. DEPENDENCY RESTART PROPAGATION

## 11.1 Configuration

Compose supports:

```yaml
depends_on:
  redis:
    condition: service_healthy
    restart: true
```

## 11.2 Meaning

The `restart: true` setting inside the dependency definition instructs Compose to restart the dependent service following applicable explicit Compose operations that update or restart the dependency.

For example, an administrator may explicitly restart Redis through Compose.

The dependent web service may then be restarted to reestablish connections.

## 11.3 Important Limitation

This setting does not mean that every unexpected Redis process crash automatically triggers a restart of Flask.

Automated runtime restarts and explicit Compose-managed dependency operations are different mechanisms.

## 11.4 Example

```text
        COMPOSE RESTART REDIS
                  |
                  v
             REDIS RESTART
                  |
                  v
        DEPENDENT WEB RESTART
```

This behavior is relevant to explicitly Compose-controlled operations.

It must not be confused with general service-health remediation.

---

# 12. CONTAINER RESTART POLICIES

## 12.1 Definition

A restart policy configures how Docker manages a container after its principal process terminates.

Compose supports the service attribute:

```yaml
restart: unless-stopped
```

## 12.2 Principal Policies

| Policy | General behavior |
|---|---|
| `no` | No automatic restart |
| `always` | Restart after eligible termination |
| `on-failure` | Restart after eligible nonzero process exit |
| `unless-stopped` | Restart unless explicitly stopped according to Docker's policy semantics |

## 12.3 on-failure

A restart policy may use a retry limit.

Example:

```yaml
restart: "on-failure:3"
```

This requests restart behavior following qualifying failures, with the specified retry limit.

## 12.4 always

The `always` policy attempts to keep the container running according to Docker's documented restart behavior.

## 12.5 unless-stopped

The `unless-stopped` policy restarts eligible terminated containers while respecting explicit stop behavior.

## 12.6 no

The `no` policy disables automatic restart management.

---

# 13. RESTART POLICIES VERSUS HEALTH CHECKS

A critical distinction exists between process termination and health-check failure.

Consider:

```text
Container Process: Running

Health Status: Unhealthy
```

The container may remain running.

The restart policy does not automatically restart it merely because the health check reports unhealthy.

## 13.1 Runtime Restart

A process terminates.

Docker may restart the container according to its restart policy.

## 13.2 Health-Check Failure

The process remains running.

The health check repeatedly fails.

Docker records the unhealthy status.

Additional monitoring or remediation mechanisms may be required.

## 13.3 Compose Dependency Restart

Compose explicitly updates or restarts a dependency.

The `depends_on` dependency-level `restart: true` setting may cause the dependent service to restart.

## 13.4 Summary

These are three distinct mechanisms:

1. Runtime restart policy.
2. Docker health-check classification.
3. Compose dependency restart propagation.

They should not be treated as interchangeable.

---

# 14. CONFIGURATION PRECEDENCE

## 14.1 Definition

Configuration precedence determines which value becomes effective when the same setting is defined through multiple sources.

For container environment variables, relevant sources include:

- Dockerfile `ENV`.
- Compose service `env_file`.
- Compose service `environment`.
- Values interpolated from the shell or Compose environment files.
- Explicit `docker compose run -e` overrides.

## 14.2 Dockerfile Default

An image may define:

```dockerfile
ENV APP_MODE=image-default
```

## 14.3 Service Environment File

A Compose service may define:

```yaml
env_file:
  - ./runtime.env
```

The referenced file may contain:

```text
APP_MODE=runtime-file
```

## 14.4 Service Environment Mapping

The service may also define:

```yaml
environment:
  APP_MODE: compose-value
```

The explicit Compose environment setting overrides the corresponding service environment-file value.

## 14.5 One-Off CLI Override

An administrator may execute:

```bash
docker compose run --rm -e APP_MODE=cli-value web python -c "import os; print(os.getenv('APP_MODE'))"
```

This explicitly supplies a value for the new one-off container.

---

# 15. CONTAINER ENVIRONMENT PRECEDENCE MODEL

For ordinary Compose container environment configuration, the relevant precedence order from highest to lowest is:

| Priority | Source |
|---|---|
| 1 | Explicit `docker compose run -e` value |
| 2 | `environment` or `env_file` with values interpolated from shell or Compose environment input |
| 3 | Literal Compose `environment` value |
| 4 | Literal service `env_file` value |
| 5 | Dockerfile `ENV` default |

The complete rules depend on the forms in which values are defined.

## 15.1 Important Qualification

A variable in a shell or project `.env` file is not automatically injected into a container.

It must be referenced by an applicable Compose configuration or supplied through another supported mechanism.

## 15.2 Example

The project `.env` contains:

```text
APP_MODE=project-value
```

The Compose file contains:

```yaml
environment:
  APP_MODE: "${APP_MODE}"
```

The effective container environment receives the interpolated value.

Without the Compose reference, the project `.env` value would not automatically become a container environment variable.

---

# 16. PROJECT INTERPOLATION PRECEDENCE

Compose interpolation also has a precedence model.

For the ordinary explicit configuration-file workflow used in this lecture, relevant sources include:

1. Shell environment variables.
2. A file supplied through `docker compose --env-file`.
3. The default project `.env` file when no explicit interpolation file overrides it.

Special project-directory and `COMPOSE_FILE` behavior can introduce additional cases.

## 16.1 Direct Substitution

```yaml
APP_NAME: "${APP_NAME}"
```

## 16.2 Default If Unset or Empty

```yaml
APP_NAME: "${APP_NAME:-Academic Application}"
```

## 16.3 Default If Unset

```yaml
APP_NAME: "${APP_NAME-Academic Application}"
```

## 16.4 Required Value

```yaml
APP_NAME: "${APP_NAME:?APP_NAME must be configured}"
```

If the value is unset or empty, Compose reports an error.

## 16.5 Important Difference

Interpolation determines the effective Compose model.

Container environment injection determines values supplied to an executing process.

The two mechanisms may interact, but they operate at different configuration stages.

---

# 17. INSPECTING THE EFFECTIVE CONFIGURATION

## 17.1 Render the Model

```bash
docker compose config
```

Displays the resolved Compose configuration.

## 17.2 Validate Only

```bash
docker compose config -q
```

Validates without printing the complete model.

## 17.3 Show Interpolation Environment

```bash
docker compose config --environment
```

Displays variables used for interpolation.

## 17.4 Inspect Container Environment

```bash
docker compose exec web printenv APP_MODE
```

Retrieves the value from the running container.

## 17.5 Security Consideration

Compose configuration output and container environment inspection may expose sensitive values.

Do not publish full output from production environments without reviewing it.

---

# 18. MULTIPLE COMPOSE FILES

## 18.1 Purpose

A single application may require different settings across environments.

For example:

**Development**

- Source synchronization.
- Diagnostic logging.
- Rapid feedback.
- Frequent code changes.

**Staging**

- Production-like startup.
- Controlled configuration.
- Reduced filesystem write access.
- Testing before deployment.

Rather than duplicating the entire Compose configuration, files can be merged.

## 18.2 Base Configuration

```text
compose.yaml
```

Defines common application resources.

## 18.3 Development Override

```text
compose.dev.yaml
```

Defines additional development-specific configuration.

## 18.4 Staging Override

```text
compose.staging.yaml
```

Defines staging-specific settings.

## 18.5 File Selection

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d
```

Compose merges the selected files.

The files are processed in the supplied order.

Later files can override or extend applicable settings from earlier files.

---

# 19. COMPOSE FILE MERGING RULES

## 19.1 General Principle

Compose merges application models rather than simply replacing every service definition.

## 19.2 Scalar Values

A scalar value in a later file generally replaces the corresponding scalar value from an earlier file.

Example:

Base:

```yaml
services:
  web:
    restart: "no"
```

Override:

```yaml
services:
  web:
    restart: unless-stopped
```

The effective value is the override.

## 19.3 Mappings

Mappings such as `environment` are generally combined.

When the same key appears more than once, the later value overrides the earlier value.

## 19.4 Sequences

Many sequence-valued settings are combined rather than replaced.

However, certain Compose attributes have special uniqueness rules.

Examples include port mappings and volume mount targets.

## 19.5 Important Limitation

A later configuration file does not always replace an earlier sequence in the way an administrator might expect.

When changing published ports or mount definitions, the merged model must be inspected carefully.

## 19.6 Path Resolution

When files are merged through `-f`, relative paths are generally interpreted relative to the first, or base, Compose file.

This allows override files to be maintained separately while retaining consistent path resolution.

---

# 20. AUTOMATIC OVERRIDE FILES

Docker Compose may automatically load a conventional override file such as:

```text
compose.override.yaml
```

when using the default file-discovery workflow.

This behavior can be convenient.

However, it can also make the effective application configuration less obvious.

The present laboratory deliberately uses:

```text
compose.dev.yaml
compose.staging.yaml
```

and selects them explicitly with `-f`.

This makes the active configuration easier to identify.

---

# 21. COMPOSE PROFILES

## 21.1 Definition

A Compose profile allows selected services to be enabled only for particular application workflows.

## 21.2 Example

```yaml
services:
  diagnostics:
    image: alpine:3.20
    profiles:
      - tools
```

The diagnostics service is associated with the `tools` profile.

## 21.3 Enabling a Profile

```bash
docker compose --profile tools up -d
```

## 21.4 Service Selection

A service without a profile is normally active.

A service with a profile is active when its profile is selected or when it is explicitly targeted under supported Compose behavior.

## 21.5 Uses

Profiles are useful for optional components such as:

- Diagnostic utilities.
- Development interfaces.
- Debugging services.
- Database administration tools.
- Optional monitoring components.

## 21.6 Important Qualification

Profiles do not automatically alter every part of an application's configuration.

They principally control which services participate in the active application model.

---

# 22. DEVELOPMENT WORKFLOWS

## 22.1 The Development Problem

A container image may include source code copied during construction.

After changing a source file, the developer may need to:

1. Rebuild the image.
2. Recreate the container.
3. Restart the application.
4. Verify the change.

Repeating these operations after every code change can reduce development efficiency.

## 22.2 Common Solutions

Two common approaches are:

- Bind-mounted source code.
- Compose Watch.

## 22.3 Bind Mounts

A bind mount makes a host directory available inside the container.

Example:

```yaml
volumes:
  - ./app:/app
```

Changes to the host files become visible within the mounted directory.

However, the application process may still need to reload or restart to use those changes.

## 22.4 Compose Watch

Compose Watch observes selected files and performs configured development actions.

It can synchronize source files, rebuild images, or restart services.

---

# 23. COMPOSE WATCH

## 23.1 Definition

Compose Watch is a development workflow mechanism that monitors selected host files and updates Compose services when changes are detected.

## 23.2 Version Requirement

The Compose development watch capability requires Docker Compose 2.22.0 or later.

Some watch actions require newer versions.

In particular, `sync+restart` requires Compose 2.23.0 or later.

## 23.3 Syntax

```yaml
develop:
  watch:
    - action: sync
      path: ./app
      target: /app
```

## 23.4 Principal Watch Actions

| Action | Behavior |
|---|---|
| `sync` | Synchronize file changes into a running container |
| `rebuild` | Rebuild the image and recreate the service |
| `sync+restart` | Synchronize files and restart the service |
| `restart` | Restart the service when watched files change; requires newer Compose |
| `sync+exec` | Synchronize and execute a command; requires newer Compose |

## 23.5 Scope

The laboratory will use:

- `sync+restart` for Python source files.
- `rebuild` for dependency-manifest changes.

This corresponds to the different effects of application source changes and dependency changes.

---

# 24. WATCH AND NON-ROOT CONTAINERS

## 24.1 Filesystem Permissions

Source synchronization writes files into a container filesystem.

The target location must support the required operations.

A non-root container may lack write access to a root-owned directory.

## 24.2 Dockerfile Configuration

The Dockerfile can assign appropriate ownership using:

```dockerfile
COPY --chown=10001:10001 app/ /app/
```

The working directory can also be configured with compatible ownership.

## 24.3 Security Principle

Development convenience should not automatically require running the complete application as root.

Filesystem permissions should be configured explicitly where possible.

---

# 25. WATCH VERSUS BIND MOUNTS

| Characteristic | Bind mount | Compose Watch |
|---|---|---|
| Host source files visible in container | Yes | Through synchronization |
| Requires rebuild for every code change | No | No, when using sync actions |
| Supports automatic service restart | Not by itself | Yes, with suitable watch actions |
| Requires explicit filesystem mount | Yes | Not necessarily |
| Depends on file synchronization rules | No direct copying model | Yes |
| Appropriate for development | Yes | Yes |
| Requires compatible Compose version | Basic Compose support | Compose 2.22+ for Watch |
| Image rebuild on dependency change | Separate operation | Can be automated |

## 25.1 Engineering Choice

Bind mounts are often useful when applications already support automatic reloading.

Compose Watch is useful when explicit source synchronization and controlled restart or rebuild actions are desired.

These approaches should be selected according to the application framework and development environment.

---

# 26. READ-ONLY ROOT FILESYSTEMS

## 26.1 Definition

A container may be configured so that its root filesystem is mounted read-only.

Compose provides:

```yaml
read_only: true
```

## 26.2 Purpose

A read-only root filesystem reduces the filesystem locations that a process can modify.

This may limit some forms of accidental or malicious modification.

## 26.3 Limitations

Applications may require writable runtime paths.

Examples include:

- Temporary files.
- Process sockets.
- Runtime caches.
- Application data directories.

These requirements must be accommodated through appropriate mounts or filesystem configuration.

## 26.4 Temporary Filesystem Example

```yaml
tmpfs:
  - /tmp
```

This provides a writable temporary filesystem at `/tmp`.

## 26.5 Security Qualification

A read-only root filesystem is a useful security measure.

It is not a complete container security solution.

Privileges, capabilities, network access, mounts, application vulnerabilities, and Docker daemon access remain relevant.

---

# 27. ADVANCED COMPOSE OPERATIONS

## 27.1 Configuration Validation

```bash
docker compose config -q
```

## 27.2 Environment Inspection

```bash
docker compose config --environment
```

## 27.3 Service Listing

```bash
docker compose config --services
```

## 27.4 Profile Listing

```bash
docker compose config --profiles
```

## 27.5 Reconciliation

```bash
docker compose up -d
```

## 27.6 Image Rebuilding

```bash
docker compose up -d --build
```

## 27.7 Service Restart

```bash
docker compose restart web
```

## 27.8 Service Recreation

```bash
docker compose up -d --force-recreate web
```

This recreates the selected service container rather than merely restarting it.

## 27.9 Controlled Teardown

```bash
docker compose down
```

Named volumes are ordinarily retained.

The option `-v` introduces different data-removal consequences.

---

# PART II — PRACTICAL LABORATORY 13

# 28. LABORATORY OVERVIEW

## 28.1 Title

**Advanced Compose Operations Laboratory: Health-Aware Dependencies, Restart Behavior, Environment Precedence, Configuration Overrides, Profiles, and Compose Watch**

## 28.2 Project Objective

The student will construct and operate a Flask-and-Redis application supporting:

1. Independent web and Redis services.
2. Named persistent Redis storage.
3. Health checks.
4. Health-aware startup dependencies.
5. Runtime restart policies.
6. Dependency restart propagation.
7. Environment configuration precedence.
8. Optional diagnostic services.
9. Development configuration overrides.
10. Staging configuration overrides.
11. Compose Watch.
12. Non-root execution.
13. Read-only root filesystem configuration.
14. Persistent application state across deployment changes.

## 28.3 Required Software

- Docker Engine or Docker Desktop.
- Docker Compose 2.23.0 or later for the full Watch laboratory.
- Terminal.
- Text editor.
- HTTP client or browser.
- Internet access for obtaining required images and Python dependencies.

## 28.4 Relationship to Lecture 12

This laboratory extends the architecture studied in Lecture 12.

A complete independent project definition is provided so the laboratory can be reconstructed without needing to copy files from the previous exercise.

---

# 29. PROJECT DIRECTORY STRUCTURE

Create:

```text
docker-lecture13/
├── Dockerfile
├── compose.yaml
├── compose.dev.yaml
├── compose.staging.yaml
├── requirements.txt
├── .dockerignore
├── .env
├── .env.staging
├── runtime.env
└── app/
    └── app.py
```

## 29.1 File Responsibilities

**Dockerfile:** Packages the Python application.

**compose.yaml:** Defines the common application infrastructure.

**compose.dev.yaml:** Adds development behavior.

**compose.staging.yaml:** Adds staging-specific configuration.

**requirements.txt:** Declares Python dependencies.

**.dockerignore:** Excludes unnecessary build inputs.

**.env:** Supplies default interpolation values.

**.env.staging:** Supplies alternative interpolation values.

**runtime.env:** Supplies service container environment values.

**app/app.py:** Implements the Flask application.

---

# 30. PYTHON DEPENDENCY FILE

Create:

```text
requirements.txt
```

Insert:

```text
Flask==3.1.3
redis==6.2.0
gunicorn==26.2.0
```

## 30.1 Purpose

The file records the selected direct dependencies.

## 30.2 Reproducibility

Pinning direct dependencies improves consistency but does not independently guarantee fully reproducible builds.

Transitive dependencies, base images, operating-system packages, and external build inputs may still change.

---

# 31. COMPLETE APPLICATION SOURCE

Create:

```text
app/app.py
```

Insert:

```python
import os

import redis

from flask import Flask, jsonify, render_template_string

from redis.exceptions import RedisError


app = Flask(__name__)


APP_NAME = os.getenv(
    "APP_NAME",
    "Advanced Docker Compose Laboratory"
)

APP_MODE = os.getenv(
    "APP_MODE",
    "development"
)

LOG_LEVEL = os.getenv(
    "LOG_LEVEL",
    "info"
)

REDIS_HOST = os.getenv(
    "REDIS_HOST",
    "redis"
)

REDIS_PORT = int(
    os.getenv("REDIS_PORT", "6379")
)

COUNTER_KEY = os.getenv(
    "COUNTER_KEY",
    "lecture13:counter"
)


client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)


PAGE = """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Advanced Docker Compose</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            padding: 45px;
            color: #0f172a;
        }

        main {
            max-width: 720px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 12px;
            text-align: center;
        }

        h1 {
            color: #2563eb;
        }

        #counter {
            font-size: 56px;
            font-weight: bold;
            margin: 28px;
        }

        button {
            background: #2563eb;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 15px 25px;
            cursor: pointer;
        }
    </style>
</head>

<body>
    <main>

        <h1>{{ app_name }}</h1>

        <h2>Docker Lecture 13</h2>

        <p>
            Application Mode: {{ app_mode }}
        </p>

        <p>
            Persistent Redis Counter
        </p>

        <div id="counter">...</div>

        <button id="increment">
            Increment Counter
        </button>

        <p id="message"></p>

    </main>

    <script>

        const counter = document.getElementById("counter");
        const message = document.getElementById("message");
        const button = document.getElementById("increment");

        async function load() {

            try {

                const response = await fetch(
                    "/api/count",
                    { cache: "no-store" }
                );

                if (!response.ok) {
                    throw new Error("Counter unavailable");
                }

                const data = await response.json();

                counter.textContent = String(data.count);

                message.textContent = "Connected to Redis";

            } catch (error) {

                counter.textContent = "--";

                message.textContent = error.message;
            }
        }

        async function increment() {

            button.disabled = true;

            try {

                const response = await fetch(
                    "/api/increment",
                    { method: "POST" }
                );

                if (!response.ok) {
                    throw new Error("Increment failed");
                }

                const data = await response.json();

                counter.textContent = String(data.count);

                message.textContent = "Counter updated";

            } catch (error) {

                message.textContent = error.message;

            } finally {

                button.disabled = false;
            }
        }

        button.addEventListener("click", increment);

        load();

    </script>

</body>
</html>
"""


@app.get("/")
def home():

    return render_template_string(
        PAGE,
        app_name=APP_NAME,
        app_mode=APP_MODE
    )


@app.get("/health/live")
def live():

    return jsonify(
        status="alive",
        service="web"
    ), 200


@app.get("/health/ready")
def ready():

    try:

        client.ping()

        return jsonify(
            status="ready",
            redis="available"
        ), 200

    except RedisError:

        return jsonify(
            status="not_ready",
            redis="unavailable"
        ), 503


@app.get("/api/count")
def get_count():

    try:

        value = client.get(COUNTER_KEY)

        count = int(value) if value is not None else 0

        return jsonify(
            count=count
        ), 200

    except RedisError:

        return jsonify(
            error="Redis unavailable"
        ), 503

    except (ValueError, TypeError):

        return jsonify(
            error="Invalid stored counter"
        ), 500


@app.post("/api/increment")
def increment_count():

    try:

        count = client.incr(COUNTER_KEY)

        return jsonify(
            count=count
        ), 200

    except RedisError:

        return jsonify(
            error="Redis unavailable"
        ), 503


@app.get("/api/config")
def configuration():

    return jsonify(
        application=APP_NAME,
        mode=APP_MODE,
        log_level=LOG_LEVEL,
        counter_key=COUNTER_KEY
    ), 200
```

## 31.1 Application Analysis

The application exposes:

- A browser interface.
- A counter retrieval endpoint.
- An increment endpoint.
- A liveness endpoint.
- A readiness endpoint.
- A non-sensitive configuration endpoint.

The readiness endpoint checks Redis availability.

The counter uses Redis atomic increment operations.

The configuration endpoint deliberately returns only values selected for instructional use.

Real secrets must not be exposed through application diagnostic endpoints.

---

# 32. DOCKERFILE CONSTRUCTION

Create:

```text
Dockerfile
```

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Lecture 13" \
      org.opencontainers.image.description="Advanced Compose Operations Laboratory"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_MODE=image-default \
    LOG_LEVEL=warning

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=10001:10001 app/ /app/

RUN chown -R 10001:10001 /app

USER 10001:10001

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
```

## 32.1 Important Design Features

The image uses a Python runtime.

Dependencies are installed before application source code is copied.

The application runs with a numeric non-root identity.

The application directory is writable by that identity.

This supports the Compose Watch synchronization experiment.

The image also defines default environment variables for precedence testing.

---

# 33. DOCKERIGNORE CONFIGURATION

Create:

```text
.dockerignore
```

Insert:

```dockerignore
.git
.gitignore
.env
.env.staging
runtime.env
compose.yaml
compose.dev.yaml
compose.staging.yaml
*.log
*.tmp
*.pyc
__pycache__/
.venv/
venv/
laboratory-notes.md
```

## 33.1 Purpose

Exclude unnecessary configuration and development files from the image build context.

The Compose configuration remains available to the Compose CLI on the host.

It does not need to be copied into the application image.

---

# 34. PROJECT ENVIRONMENT FILE

Create:

```text
.env
```

Insert:

```text
WEB_PORT=8233
APP_NAME=Advanced Compose Laboratory
APP_MODE=project-env
```

This file supplies default interpolation values.

---

# 35. SERVICE ENVIRONMENT FILE

Create:

```text
runtime.env
```

Insert:

```text
APP_MODE=runtime-env
LOG_LEVEL=info
COUNTER_KEY=lecture13:counter
```

## 35.1 Purpose

This file is supplied through the service-level `env_file` attribute.

It establishes runtime environment values.

## 35.2 Precedence Experiment

The two files deliberately contain different values for `APP_MODE`.

The Dockerfile also contains an `APP_MODE` default.

This makes it possible to investigate which configuration source takes effect.

---

# 36. STAGING ENVIRONMENT FILE

Create:

```text
.env.staging
```

Insert:

```text
WEB_PORT=8234
APP_NAME=Staging Compose Laboratory
APP_MODE=staging-project-env
```

This file will be supplied explicitly through the Compose CLI during the staging laboratory.

The staging overlay will also define a literal application mode, permitting another precedence comparison.

---

# 37. BASE COMPOSE FILE

Create:

```text
compose.yaml
```

Insert:

```yaml
name: lecture13-course

services:

  redis:
    image: redis:7-alpine

    command:
      - redis-server
      - --appendonly
      - "yes"
      - --appendfsync
      - everysec
      - --dir
      - /data

    volumes:
      - redis-data:/data

    networks:
      - backend

    healthcheck:
      test:
        - CMD
        - redis-cli
        - ping
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s

    restart: unless-stopped


  web:
    build:
      context: .
      dockerfile: Dockerfile

    image: lecture13-web:v1

    ports:
      - "127.0.0.1:${WEB_PORT:-8233}:8000"

    env_file:
      - ./runtime.env

    environment:
      APP_NAME: "${APP_NAME:-Advanced Compose Laboratory}"
      APP_MODE: "${APP_MODE:-compose-default}"
      REDIS_HOST: redis
      REDIS_PORT: "6379"

    depends_on:
      redis:
        condition: service_healthy
        restart: true

    networks:
      - backend

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=2)"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 15s

    restart: unless-stopped


  diagnostics:
    image: redis:7-alpine

    profiles:
      - tools

    entrypoint:
      - redis-cli
      - -h
      - redis

    command:
      - PING

    networks:
      - backend

    depends_on:
      redis:
        condition: service_healthy


networks:
  backend:
    driver: bridge


volumes:
  redis-data:
```

## 37.1 Redis Service

Provides persistent Redis data storage.

The service uses a named volume and a health check.

## 37.2 Web Service

Provides the Flask HTTP application.

The service builds a custom image and receives its configuration through environment variables and files.

## 37.3 Dependency Relationship

The web service waits for Redis to satisfy its health check during applicable startup operations.

The dependency-level restart setting also enables restart propagation for appropriate explicit Compose operations.

## 37.4 Diagnostics Service

The diagnostics service uses a profile named:

```text
tools
```

It is not part of the ordinary default service startup.

It can be explicitly invoked when Redis diagnostics are required.

---

# 38. DEVELOPMENT OVERRIDE FILE

Create:

```text
compose.dev.yaml
```

Insert:

```yaml
services:

  web:
    environment:
      APP_MODE: development
      LOG_LEVEL: debug

    develop:
      watch:
        - action: sync+restart
          path: ./app
          target: /app
          initial_sync: true

        - action: rebuild
          path: ./requirements.txt
```

## 38.1 Purpose

This file defines development-specific behavior.

It:

- Changes the application mode.
- Changes the log-level configuration.
- Synchronizes application source changes.
- Restarts the web service after synchronization.
- Rebuilds the web image when the dependency manifest changes.

## 38.2 Important Requirement

The `sync+restart` action requires Docker Compose 2.23.0 or later.

The Python application directory has been configured with appropriate ownership for non-root synchronization.

---

# 39. STAGING OVERRIDE FILE

Create:

```text
compose.staging.yaml
```

Insert:

```yaml
services:

  web:
    environment:
      APP_MODE: staging
      LOG_LEVEL: warning

    read_only: true

    tmpfs:
      - /tmp

    restart: unless-stopped
```

## 39.1 Purpose

The staging override defines:

- A staging application mode.
- A different log-level configuration.
- A read-only root filesystem.
- A writable temporary filesystem at `/tmp`.

## 39.2 Important Distinction

The staging configuration is intended to demonstrate production-oriented configuration principles.

It is not a complete production deployment specification.

Authentication, TLS, monitoring, backup, resource management, and other controls would still be required.

---

# PART III — PRACTICAL LABORATORY EXPERIMENTS

# 40. EXPERIMENT 1 — VERIFY COMPOSE CAPABILITIES

Execute:

```bash
docker version
```

Then:

```bash
docker compose version
```

## Objective

Verify Docker Engine and Docker Compose availability.

## Required Observation

Record the versions.

Confirm that the Compose version supports `sync+restart` before attempting the development watch experiments.

---

# 41. EXPERIMENT 2 — CREATE THE PROJECT

Create the required project directory and files.

Verify that the directory contains:

```text
Dockerfile
compose.yaml
compose.dev.yaml
compose.staging.yaml
requirements.txt
.dockerignore
.env
.env.staging
runtime.env
app/app.py
```

## Objective

Establish a complete reproducible advanced Compose application.

---

# 42. EXPERIMENT 3 — VALIDATE THE BASE MODEL

From the project directory, execute:

```bash
docker compose config -q
```

Then:

```bash
docker compose config
```

## Objective

Validate the base configuration and inspect the effective model.

## Required Observations

Identify:

1. Project name.
2. Redis image.
3. Web image.
4. Published host port.
5. Network.
6. Named volume.
7. Health checks.
8. Dependency restart setting.
9. Diagnostics profile.

---

# 43. EXPERIMENT 4 — INSPECT INTERPOLATION VALUES

Execute:

```bash
docker compose config --environment
```

## Objective

Examine the environment values used for Compose interpolation.

## Required Analysis

Explain why `WEB_PORT` influences host port publishing.

Explain why this does not automatically imply that `WEB_PORT` exists inside the Flask process environment.

---

# 44. EXPERIMENT 5 — BUILD THE APPLICATION IMAGE

Execute:

```bash
docker compose build web
```

Verify:

```bash
docker image ls lecture13-web
```

## Objective

Construct the custom Flask image.

## Required Analysis

Identify which configuration values originate from Dockerfile `ENV` and which will later be overridden by Compose.

---

# 45. EXPERIMENT 6 — START THE BASE APPLICATION

Execute:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

## Expected Result

The Redis and web services become available.

The diagnostics service is not ordinarily started because its profile has not been enabled.

## Required Analysis

Explain why Redis is started and checked before the web service begins its dependent startup operation.

---

# 46. EXPERIMENT 7 — ACCESS THE APPLICATION

Open:

http://127.0.0.1:8233

## Expected Result

The application displays:

**Advanced Compose Laboratory**

The application mode corresponds to the effective base configuration.

The Redis counter initially displays zero if the database has no previously stored value.

## Objective

Verify that the application infrastructure is functioning.

---

# 47. EXPERIMENT 8 — VERIFY ENVIRONMENT PRECEDENCE

Execute:

```bash
docker compose exec web printenv APP_MODE
```

## Expected Result

```text
project-env
```

Execute:

```bash
docker compose exec web printenv LOG_LEVEL
```

## Expected Result

```text
info
```

## Interpretation

`APP_MODE` is defined in several places.

The effective value comes from the Compose `environment` mapping after interpolation from the project `.env` file.

`LOG_LEVEL` is not overridden by the base Compose environment mapping.

Its effective value comes from `runtime.env`.

## Required Analysis

Explain why the Dockerfile defaults do not become the final values for these variables.

---

# 48. EXPERIMENT 9 — INSPECT APPLICATION CONFIGURATION

Open:

http://127.0.0.1:8233/api/config

## Expected Response

The JSON response includes:

```json
{
  "application": "Advanced Compose Laboratory",
  "mode": "project-env",
  "log_level": "info",
  "counter_key": "lecture13:counter"
}
```

The ordering of JSON properties may differ.

## Objective

Confirm that Flask receives the configuration values supplied during container creation.

---

# 49. EXPERIMENT 10 — TEST AN EXPLICIT CLI OVERRIDE

Execute:

```bash
docker compose run --rm --no-deps -e APP_MODE=cli-override web python -c "import os; print(os.getenv('APP_MODE'))"
```

## Expected Result

```text
cli-override
```

## Objective

Demonstrate the precedence of an explicit `docker compose run -e` assignment for the new one-off container.

## Required Analysis

Explain why this does not permanently change the environment of the already running web service container.

---

# 50. EXPERIMENT 11 — TEST REDIS COMMUNICATION

Execute:

```bash
docker compose exec redis redis-cli PING
```

Expected:

```text
PONG
```

Now invoke the optional diagnostics service:

```bash
docker compose run --rm diagnostics PING
```

Expected:

```text
PONG
```

## Objective

Demonstrate that an explicitly targeted profile-associated diagnostics service can run an application command.

## Required Analysis

Explain the relationship between the diagnostics container, the backend network, and Redis service-name resolution.

---

# 51. EXPERIMENT 12 — STORE PERSISTENT APPLICATION DATA

Open:

http://127.0.0.1:8233

Increment the counter several times.

Alternatively, execute:

```bash
curl -X POST http://127.0.0.1:8233/api/increment
```

Retrieve the value:

```bash
curl http://127.0.0.1:8233/api/count
```

## Objective

Create application data for subsequent persistence experiments.

## Required Observation

Record the counter value.

---

# 52. EXPERIMENT 13 — EXAMINE HEALTH STATES

Execute:

```bash
docker compose ps
```

Inspect Redis health:

```bash
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q redis)"
```

Inspect web health:

```bash
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q web)"
```

The formatted inspection examples use shell command substitution supported by Unix-like shells.

For other terminals, retrieve each container identifier separately with `docker compose ps -q` and supply it to `docker inspect`.

## Objective

Examine the recorded health-check states and recent check results.

---

# 53. EXPERIMENT 14 — TEST REDIS UNAVAILABILITY

Execute:

```bash
docker compose stop redis
```

Now request:

```bash
curl -i http://127.0.0.1:8233/health/live
```

Then:

```bash
curl -i http://127.0.0.1:8233/health/ready
```

## Expected Results

The liveness endpoint may continue returning HTTP 200.

The readiness endpoint returns HTTP 503 while Redis is unavailable.

After sufficient failed health checks, the web container may become unhealthy.

## Required Analysis

Explain why the web container remains running even though its readiness check fails.

---

# 54. EXPERIMENT 15 — RESTORE REDIS

Execute:

```bash
docker compose start redis
```

Verify:

```bash
docker compose exec redis redis-cli PING
```

Then:

```bash
curl -i http://127.0.0.1:8233/health/ready
```

## Expected Result

Redis becomes available.

The readiness endpoint returns HTTP 200 after successful recovery.

## Objective

Demonstrate recovery of application dependency connectivity.

---

# 55. EXPERIMENT 16 — TEST EXPLICIT DEPENDENCY RESTART

Execute:

```bash
docker compose restart redis
```

## Objective

Investigate dependency restart propagation.

Because the web service declares:

```yaml
depends_on:
  redis:
    condition: service_healthy
    restart: true
```

an explicit Compose-controlled Redis restart can also cause Compose to restart the dependent web service.

Inspect:

```bash
docker compose ps
```

And:

```bash
docker compose logs --tail 30 web
```

## Required Analysis

Explain why this behavior is distinct from an unexpected Redis process crash or a health-check failure.

---

# 56. EXPERIMENT 17 — VERIFY PERSISTENCE ACROSS RESTARTS

Execute:

```bash
docker compose exec redis redis-cli GET lecture13:counter
```

Compare the result with the value recorded in Experiment 12.

## Expected Result

The counter value remains available.

## Required Analysis

Explain why restarting application containers does not ordinarily delete the named Redis volume.

---

# 57. EXPERIMENT 18 — INSPECT THE DEVELOPMENT OVERRIDE

Execute:

```bash
docker compose -f compose.yaml -f compose.dev.yaml config
```

## Objective

Examine the merged development configuration.

## Expected Observations

The effective web service configuration includes:

```text
APP_MODE=development
LOG_LEVEL=debug
```

The model also includes the `develop.watch` rules.

## Required Analysis

Explain how the development override changes selected service attributes without duplicating the entire base Compose file.

---

# 58. EXPERIMENT 19 — SWITCH TO DEVELOPMENT CONFIGURATION

First remove the base application while retaining the named volume:

```bash
docker compose down
```

Now start the development configuration:

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d
```

Verify:

```bash
docker compose -f compose.yaml -f compose.dev.yaml ps
```

Open:

http://127.0.0.1:8233/api/config

## Expected Result

The application reports:

```text
mode: development
log_level: debug
```

## Required Analysis

Explain which values originated from the development override and which remain inherited from the base file.

---

# 59. EXPERIMENT 20 — ENABLE COMPOSE WATCH

Keep the development application running.

Open a second terminal in the project directory.

Execute:

```bash
docker compose -f compose.yaml -f compose.dev.yaml watch
```

## Objective

Start automatic source monitoring.

## Expected Behavior

Compose monitors the paths declared in the development watch configuration.

The watcher remains active while the command is running.

## Important Note

The watch command is an interactive development operation.

Use `Ctrl+C` to stop the watcher when the experiment is complete.

The application itself can be managed separately through Compose lifecycle commands.

---

# 60. EXPERIMENT 21 — SYNCHRONIZE A SOURCE CHANGE

While Compose Watch is active, open:

```text
app/app.py
```

Locate:

```html
<h2>Docker Lecture 13</h2>
```

Change it to:

```html
<h2>Docker Lecture 13 — Watch Updated</h2>
```

Save the file.

## Expected Behavior

Compose Watch detects the source change.

The configured `sync+restart` action synchronizes the updated source code into the web container and restarts that service.

Refresh:

http://127.0.0.1:8233

## Expected Result

The updated heading appears.

## Required Analysis

Explain why the web image does not necessarily need to be rebuilt for this source-only change.

---

# 61. EXPERIMENT 22 — INVESTIGATE DEPENDENCY REBUILDS

While Compose Watch is active, open:

```text
requirements.txt
```

Add a harmless comment:

```text
# Lecture 13 dependency watch experiment
```

Save the file.

## Objective

Trigger the watch rule associated with the dependency manifest.

## Expected Behavior

Compose Watch detects the change and initiates an image rebuild and service recreation.

The existing named Redis volume remains independent of the web image rebuild.

## Required Analysis

Explain why dependency changes often require an image rebuild, while ordinary source changes may be handled through synchronization.

---

# 62. EXPERIMENT 23 — STOP THE WATCH SESSION

Return to the terminal running Compose Watch.

Press:

```text
Ctrl+C
```

## Objective

Stop the active file-watch process.

Inspect the application separately:

```bash
docker compose -f compose.yaml -f compose.dev.yaml ps
```

## Required Analysis

Explain why a development watcher and an application service are not the same operating-system process or management responsibility.

---

# 63. EXPERIMENT 24 — INSPECT STAGING CONFIGURATION

First remove the development application:

```bash
docker compose -f compose.yaml -f compose.dev.yaml down
```

Now inspect the staging configuration:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml config
```

## Expected Observations

The resolved model includes:

```text
WEB_PORT=8234
APP_MODE=staging
LOG_LEVEL=warning
```

The web service also includes:

```yaml
read_only: true
```

and a temporary filesystem mount at `/tmp`.

## Required Analysis

Explain why the staging override's literal `APP_MODE` value takes precedence over the corresponding interpolated value from the staging environment file.

---

# 64. EXPERIMENT 25 — START THE STAGING CONFIGURATION

Execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml up -d
```

## Objective

Deploy the staging configuration.

Open:

http://127.0.0.1:8234

## Expected Result

The application is accessible through host port 8234.

The application mode is:

```text
staging
```

The application name originates from the staging interpolation file.

## Required Analysis

Explain how the same application image can support different runtime configurations.

---

# 65. EXPERIMENT 26 — VERIFY READ-ONLY ROOT FILESYSTEM

Execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml exec web sh -c 'touch /restricted-test'
```

## Expected Result

The write attempt fails.

Now execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml exec web sh -c 'touch /tmp/temporary-test && ls -l /tmp/temporary-test'
```

## Expected Result

The temporary file can be created under `/tmp`.

## Objective

Demonstrate the difference between a read-only root filesystem and an explicitly writable temporary filesystem.

## Required Analysis

Explain why some applications require writable runtime paths even when their root filesystem is configured as read-only.

---

# 66. EXPERIMENT 27 — VERIFY REDIS DATA RETENTION

Execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml exec redis redis-cli GET lecture13:counter
```

## Expected Result

The counter value recorded during the earlier experiments remains available.

## Objective

Demonstrate persistence across transitions between base, development, and staging configurations.

## Required Analysis

Explain why the named volume remains usable across these changes when the Compose project name and volume definition remain consistent.

---

# 67. EXPERIMENT 28 — VALIDATE EFFECTIVE SETTINGS

Execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml config -q
```

Then:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml ps
```

## Objective

Verify configuration validity and running service status.

## Required Observations

Record:

1. Effective web host port.
2. Web health state.
3. Redis health state.
4. Network name.
5. Volume name.
6. Staging environment values.
7. Root filesystem configuration.

---

# 68. EXPERIMENT 29 — CONTROLLED APPLICATION TEARDOWN

Execute:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml down
```

## Objective

Remove the staging application while retaining persistent Redis data.

Verify:

```bash
docker volume ls
```

## Expected Result

The named Redis volume remains available.

## Required Analysis

Explain why `down` is appropriate for removing containers and project networks without intentionally destroying persistent data.

---

# 69. EXPERIMENT 30 — OPTIONAL DESTRUCTIVE CLEANUP

**Execute this experiment only if the laboratory's Redis data is no longer required.**

After confirming no container references the volume, execute:

```bash
docker volume rm lecture13-course_redis-data
```

## Critical Warning

Removing this volume deletes its associated persistent database files.

Do not remove the volume if the data must be retained.

Avoid global Docker volume-pruning commands during an educational laboratory containing unrelated resources.

---

# 70. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Technical objective | Observed result |
|---|---|---|
| 1 | Compose capability verification | |
| 2 | Project creation | |
| 3 | Base configuration validation | |
| 4 | Interpolation inspection | |
| 5 | Application image build | |
| 6 | Base application startup | |
| 7 | HTTP application verification | |
| 8 | Environment precedence | |
| 9 | Application configuration endpoint | |
| 10 | CLI environment override | |
| 11 | Diagnostics profile | |
| 12 | Redis counter creation | |
| 13 | Health state inspection | |
| 14 | Dependency failure | |
| 15 | Dependency recovery | |
| 16 | Explicit dependency restart | |
| 17 | Persistence verification | |
| 18 | Development model merge | |
| 19 | Development deployment | |
| 20 | Compose Watch activation | |
| 21 | Source synchronization | |
| 22 | Dependency rebuild | |
| 23 | Watch termination | |
| 24 | Staging configuration inspection | |
| 25 | Staging deployment | |
| 26 | Read-only filesystem test | |
| 27 | Data retention after environment changes | |
| 28 | Final configuration validation | |
| 29 | Non-destructive teardown | |
| 30 | Optional volume cleanup | |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 350–500 words addressing:

1. The differences between container running state and application health.
2. The operation of health-aware dependencies.
3. The differences among restart policies and dependency restart propagation.
4. The meaning of environment variable precedence.
5. The advantages and limitations of multiple Compose files.
6. The role of Compose profiles.
7. The differences between source synchronization and image rebuilding.
8. The purpose of read-only filesystems.
9. The persistence of Redis data across application configuration changes.
10. The remaining limitations of this system as a production deployment.

---

# PART IV — SYSTEMATIC TROUBLESHOOTING

# 71. HEALTH CHECK FAILURE

## Scenario

The web container is running but reports an unhealthy state.

## Possible Causes

- Redis is unavailable.
- The readiness endpoint returns HTTP 503.
- The health-check command is incorrect.
- The configured timeout is too short.
- The application is listening on another port.
- The health-check executable is missing.

## Investigation

```bash
docker compose ps
```

Then inspect health results using Docker inspection.

## Corrective Principle

Diagnose the failing condition rather than assuming the entire container must be recreated.

---

# 72. DEPENDENCY NEVER BECOMES HEALTHY

## Scenario

Compose waits for Redis, but the Redis health check never succeeds.

## Possible Causes

- Redis startup failure.
- Incorrect health-check command.
- Invalid Redis configuration.
- Volume permission problem.
- Dependency initialization delay.
- Health-check timeout.

## Investigation

```bash
docker compose logs redis
```

Then:

```bash
docker compose exec redis redis-cli PING
```

when the container is running.

## Corrective Principle

Dependency waiting depends on the correctness of the dependency's health check.

---

# 73. RESTART POLICY DOES NOT RESTART AN UNHEALTHY CONTAINER

## Scenario

A container is unhealthy but remains running.

## Explanation

A runtime restart policy is primarily associated with eligible principal-process termination.

Health-check failure is not necessarily a process termination event.

## Corrective Principle

Use appropriate monitoring and remediation mechanisms rather than assuming health classification causes automatic restart.

---

# 74. UNEXPECTED ENVIRONMENT VALUE

## Scenario

An application displays an environment value different from the value in `runtime.env`.

## Possible Causes

- Explicit Compose `environment` override.
- Interpolated value from `.env`.
- Shell environment precedence.
- Staging or development override file.
- One-off command-line override.
- Existing container not recreated.

## Investigation

```bash
docker compose config
```

```bash
docker compose config --environment
```

```bash
docker compose exec web printenv APP_MODE
```

## Corrective Principle

Trace the configuration source and precedence rules before modifying the application source.

---

# 75. OVERRIDE FILE DOES NOT REPLACE EXPECTED VALUES

## Scenario

A developer changes a port list in an override file, but the merged configuration contains unexpected mappings.

## Explanation

Compose file merging is not universally simple replacement.

Some sequences are combined or merged according to special uniqueness rules.

## Corrective Principle

Always inspect:

```bash
docker compose -f compose.yaml -f compose.dev.yaml config
```

before deployment.

---

# 76. COMPOSE WATCH DOES NOT SYNCHRONIZE

## Possible Causes

- Compose version too old.
- Incorrect watched source path.
- Incorrect synchronization target.
- File excluded by ignore rules.
- Insufficient destination permissions.
- Watch process not running.
- Filesystem notification limitation.

## Investigation

1. Verify Compose version.
2. Inspect the effective `develop.watch` configuration.
3. Confirm the source path.
4. Confirm the destination directory.
5. Verify container filesystem permissions.
6. Examine Compose Watch output.

## Corrective Principle

Development automation requires both a valid watch configuration and an application capable of using updated source files.

---

# 77. SOURCE CODE UPDATES BUT APPLICATION OUTPUT DOES NOT

## Scenario

A Python source file changes inside the container.

The HTTP response still displays old content.

## Possible Causes

- Application process has not reloaded.
- Wrong file was modified.
- Multiple code copies exist.
- Watch synchronization target is incorrect.
- Browser displays cached content.

## Corrective Principle

Determine whether the application requires a restart or reload.

The laboratory uses `sync+restart` because copying Python source files does not automatically cause a conventional Gunicorn deployment to reload them.

---

# 78. READ-ONLY FILESYSTEM FAILURE

## Scenario

A staging service exits because it cannot create temporary files.

## Explanation

The root filesystem is read-only.

The application may require selected writable paths.

## Corrective Principle

Identify the minimum required write locations.

Use appropriate tmpfs mounts or writable volumes where justified.

Avoid making the entire root filesystem writable merely because one temporary directory requires access.

---

# 79. DATA APPEARS MISSING AFTER ENVIRONMENT SWITCH

## Scenario

The application changes from development to staging and Redis appears empty.

## Possible Causes

- Different Compose project name.
- Different named volume.
- Different Redis key name.
- Different persistence configuration.
- A newly created empty volume.
- Database state not saved.

## Corrective Principle

Verify the project name, storage resource, Redis directory, and application counter key.

The same logical service name does not automatically guarantee the same underlying volume across different Compose projects.

---

# PART V — ACADEMIC CASE STUDIES

# 80. CASE STUDY: STARTUP RACE CONDITION

A web service starts before Redis has completed initialization.

The first database connection fails.

## Questions

1. Why is container startup insufficient to establish readiness?
2. How does `service_healthy` improve startup coordination?
3. What limitations remain after startup?
4. Why should the application still handle connection errors?

---

# 81. CASE STUDY: HEALTHY PROCESS, FAILED APPLICATION

Gunicorn remains running.

Redis is unavailable.

The web liveness endpoint returns HTTP 200.

The readiness endpoint returns HTTP 503.

## Questions

1. Is the container running?
2. Is the primary application function ready?
3. Should a runtime restart policy automatically restart the container solely because its health check fails?
4. What diagnostic information should an administrator examine?

---

# 82. CASE STUDY: CONFIGURATION PRECEDENCE

An image defines:

```dockerfile
ENV APP_MODE=image-default
```

A service environment file defines:

```text
APP_MODE=file-value
```

The Compose service contains:

```yaml
environment:
  APP_MODE: compose-value
```

A one-off container is started with:

```text
-e APP_MODE=cli-value
```

## Questions

1. What is the effective one-off container value?
2. Which value would ordinarily apply without the one-off CLI override?
3. Why does the Dockerfile default not take precedence?
4. What is the difference between runtime environment injection and Compose interpolation?

---

# 83. CASE STUDY: DEPENDENCY RESTART PROPAGATION

A Compose project defines:

```yaml
depends_on:
  redis:
    condition: service_healthy
    restart: true
```

An administrator executes an explicit Compose restart of Redis.

## Questions

1. Why may Compose restart the dependent web service?
2. Is this the same as a runtime restart policy?
3. What happens if Redis becomes unavailable without an explicit Compose restart?
4. Why is application-level connection recovery still necessary?

---

# 84. CASE STUDY: DEVELOPMENT AND STAGING

A developer uses the same Flask image in two configurations.

The development configuration enables rapid source synchronization.

The staging configuration enables a read-only root filesystem.

## Questions

1. Why is the same image useful in both environments?
2. Which differences belong to runtime configuration?
3. Why might a development watch target be incompatible with a read-only filesystem?
4. Why should staging avoid unnecessary development tools?
5. What limitations remain before production deployment?

---

# PART VI — FORMAL ACADEMIC ASSESSMENT

# 85. PART A — TECHNICAL DEFINITIONS

Provide precise definitions for:

1. Container health check.
2. Liveness.
3. Readiness.
4. Health-check interval.
5. Health-check timeout.
6. Startup grace period.
7. Service dependency.
8. Dependency restart propagation.
9. Runtime restart policy.
10. Environment interpolation.
11. Configuration precedence.
12. Compose override file.
13. Compose profile.
14. Compose Watch.
15. Read-only root filesystem.

---

# 86. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why a running container is not necessarily a healthy application.

**Question 2.**

Distinguish liveness from readiness.

**Question 3.**

Describe the significance of `healthcheck.interval`, `timeout`, `retries`, and `start_period`.

**Question 4.**

Compare `service_started`, `service_healthy`, and `service_completed_successfully`.

**Question 5.**

Explain the purpose of dependency-level `restart: true`.

**Question 6.**

Distinguish dependency restart propagation from runtime restart policies.

**Question 7.**

Explain why a Docker container marked unhealthy is not necessarily restarted automatically.

**Question 8.**

Describe the difference between project `.env` and service `env_file`.

**Question 9.**

Explain how an explicit Compose `environment` value interacts with a Dockerfile `ENV` default.

**Question 10.**

Describe the purpose of `docker compose config --environment`.

**Question 11.**

Explain the purpose of multiple Compose files.

**Question 12.**

Describe why file merging should be inspected before deployment.

**Question 13.**

Explain the function of a Compose profile.

**Question 14.**

Compare Compose Watch `sync`, `rebuild`, and `sync+restart`.

**Question 15.**

Explain why a read-only root filesystem may require a writable tmpfs mount.

---

# 87. PART C — COMMAND INTERPRETATION

Interpret:

```bash
docker compose -f compose.yaml -f compose.dev.yaml config
```

Explain:

1. Which files are selected.
2. Which file is processed first.
3. Why values from the later file may override earlier values.
4. Why the rendered configuration should be inspected.

Interpret:

```bash
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml up -d
```

Explain:

5. Which interpolation file is selected.
6. Which Compose models are merged.
7. What `up -d` does.
8. Whether the operation necessarily rebuilds every image.

Interpret:

```bash
docker compose watch
```

Explain:

9. What the command monitors.
10. What determines the action performed after a file changes.
11. Why source synchronization is different from image rebuilding.

Interpret:

```bash
docker compose restart redis
```

Explain:

12. What service is restarted.
13. How dependency restart propagation may affect the web service.
14. Why the operation differs from recreating a container.
15. Why the operation does not guarantee permanent Redis availability.

---

# 88. PRACTICAL ASSESSMENT

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Advanced Compose theory | 15 |
| Health checks and dependencies | 20 |
| Restart behavior | 15 |
| Environment configuration and precedence | 15 |
| Multiple Compose files and profiles | 15 |
| Compose Watch and development workflow | 10 |
| Security and filesystem configuration | 5 |
| Documentation and technical explanation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student should demonstrate successful configuration, correct observation of runtime behavior, and a technically accurate explanation of the underlying mechanisms.

---

# 89. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Advanced Docker Compose Configuration and Operational Management

Prepare an academic report of approximately 1,400–1,900 words addressing:

**“Operational Reliability and Configuration Management in Docker Compose: Health Monitoring, Dependency Coordination, Restart Policies, Environment Precedence, and Development Automation.”**

The report must include:

1. Introduction to operational challenges in multi-container applications.
2. Explanation of container health checking.
3. Comparison of liveness and readiness.
4. Analysis of health-check parameters.
5. Explanation of dependency conditions.
6. Discussion of dependency restart propagation.
7. Comparison of Docker restart policies.
8. Explanation of environment variable precedence.
9. Analysis of Compose interpolation.
10. Comparison of project `.env` and service `env_file`.
11. Examination of multiple Compose configuration files.
12. Explanation of Compose profiles.
13. Description of Compose Watch.
14. Comparison of source synchronization and image rebuilding.
15. Analysis of read-only root filesystem configuration.
16. Explanation of the Flask-and-Redis laboratory.
17. Discussion of failure and recovery experiments.
18. Security assessment.
19. Conclusion.

The report should contain at least two architectural diagrams and a discussion of the observed application behavior.

---

# 90. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 14, verify the following competencies.

## Application Health

- [ ] I can distinguish running, healthy, and unhealthy states.
- [ ] I understand liveness.
- [ ] I understand readiness.
- [ ] I can configure a health check.
- [ ] I can interpret health-check failures.
- [ ] I can explain startup grace periods.
- [ ] I understand the limitations of health checks.

## Dependency Management

- [ ] I can configure `depends_on`.
- [ ] I understand `service_started`.
- [ ] I understand `service_healthy`.
- [ ] I understand `service_completed_successfully`.
- [ ] I can explain dependency restart propagation.
- [ ] I understand that startup ordering does not guarantee runtime availability.

## Restart Policies

- [ ] I understand the `no` policy.
- [ ] I understand `always`.
- [ ] I understand `on-failure`.
- [ ] I understand `unless-stopped`.
- [ ] I can distinguish restart policies from health checks.
- [ ] I can explain when container recreation is required.

## Environment Configuration

- [ ] I can configure Dockerfile `ENV`.
- [ ] I can create service environment files.
- [ ] I can use a project `.env` file.
- [ ] I understand interpolation.
- [ ] I can use default-value expressions.
- [ ] I can explain configuration precedence.
- [ ] I can inspect effective environment values.

## Multiple Compose Files

- [ ] I can create a base Compose file.
- [ ] I can create a development override.
- [ ] I can create a staging override.
- [ ] I can merge files using `-f`.
- [ ] I can inspect the merged configuration.
- [ ] I understand the risks of sequence merging.
- [ ] I can explain relative path resolution.

## Profiles

- [ ] I can define a Compose profile.
- [ ] I can enable an optional service.
- [ ] I understand that ordinary services remain active without a profile.
- [ ] I can invoke a profile-associated diagnostics service.

## Development Workflows

- [ ] I understand bind-mounted development files.
- [ ] I understand Compose Watch.
- [ ] I can configure source synchronization.
- [ ] I can configure automatic service restart.
- [ ] I can configure dependency rebuild.
- [ ] I understand Watch version requirements.
- [ ] I can explain filesystem permission requirements.

## Security

- [ ] I can configure non-root execution.
- [ ] I can configure a read-only root filesystem.
- [ ] I can provide a writable tmpfs mount.
- [ ] I understand the limitations of read-only storage.
- [ ] I can explain why runtime configuration is not a complete secrets-management system.

## Practical Laboratory

- [ ] I created all required project files.
- [ ] I validated the base Compose configuration.
- [ ] I built the Flask image.
- [ ] I started the application.
- [ ] I inspected container health.
- [ ] I tested Redis unavailability.
- [ ] I tested Redis recovery.
- [ ] I investigated dependency restart behavior.
- [ ] I verified environment precedence.
- [ ] I invoked the diagnostics service.
- [ ] I created development and staging configurations.
- [ ] I used Compose Watch.
- [ ] I observed source synchronization.
- [ ] I observed an image rebuild.
- [ ] I tested read-only filesystem behavior.
- [ ] I verified Redis data persistence.
- [ ] I completed the technical report.

**Completion standard:**

The student should be able to operate a multi-container Compose application under several configurations, evaluate its readiness, investigate failures, update application source code, and manage persistent data without confusing the lifecycles of images, containers, networks, or volumes.

---

# 91. LECTURE SUMMARY

Advanced Docker Compose configuration extends declarative application management into operational reliability and development workflow management.

Container health checks allow Docker to evaluate selected application conditions.

These conditions are distinct from the principal process lifecycle.

A container may remain running while its health check reports failure.

Service dependencies provide startup coordination.

Health-aware dependencies allow Compose to wait for an application dependency to become healthy before starting a dependent service.

However, dependency ordering does not guarantee continued runtime availability.

Restart policies control eligible container process restarts.

Dependency-level restart propagation coordinates certain explicit Compose operations affecting related services.

These mechanisms are different from health-check classification.

Environment variable precedence determines which runtime configuration values become effective when several sources define the same variable.

Compose interpolation operates during configuration resolution, while service environment settings determine which values are provided to container processes.

Multiple Compose files support reusable configuration across development and staging environments.

Profiles allow selected optional services to participate only in particular workflows.

Compose Watch introduces automated source synchronization, service restarting, and image rebuilding in development environments.

Read-only root filesystems and selected writable mounts provide additional control over application filesystem behavior.

The Flask-and-Redis laboratory demonstrates these concepts through a persistent, networked, two-service application.

**The central principle of this lecture is that reliable Docker Compose operations require deliberate coordination of configuration resolution, application health, dependency behavior, restart semantics, development workflows, and persistent storage.**

---

# 92. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. *Compose File Reference.*  
https://docs.docker.com/reference/compose-file/

[2] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[3] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[4] Docker Inc. *Environment Variables Precedence in Compose.*  
https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/

[5] Docker Inc. *Variable Interpolation in Compose.*  
https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/

[6] Docker Inc. *Set Environment Variables in Compose.*  
https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/

[7] Docker Inc. *Use Multiple Compose Files.*  
https://docs.docker.com/compose/how-tos/multiple-compose-files/

[8] Docker Inc. *Merge Compose Files.*  
https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/

[9] Docker Inc. *Compose Profiles.*  
https://docs.docker.com/compose/how-tos/profiles/

[10] Docker Inc. *Use Compose Watch.*  
https://docs.docker.com/compose/how-tos/file-watch/

[11] Docker Inc. *Compose Develop Specification.*  
https://docs.docker.com/reference/compose-file/develop/

[12] Docker Inc. *docker compose config.*  
https://docs.docker.com/reference/cli/docker/compose/config/

[13] Docker Inc. *docker compose up.*  
https://docs.docker.com/reference/cli/docker/compose/up/

[14] Docker Inc. *docker compose watch.*  
https://docs.docker.com/reference/cli/docker/compose/watch/

[15] Docker Inc. *Dockerfile Reference.*  
https://docs.docker.com/reference/dockerfile/

[16] Docker Inc. *Docker Storage and Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[17] Redis. *Redis Persistence Documentation.*  
https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

[18] Flask. *Flask Documentation.*  
https://flask.palletsprojects.com/

## Recommended Reading Sequence

Begin with references [2] and [3] to develop a precise understanding of health checks and dependency management.

Continue with references [4], [5], and [6] to study environment interpolation and precedence.

References [7] and [8] explain multi-file configuration merging.

Reference [9] introduces optional services through profiles.

References [10] and [11] describe the Compose development model and Watch behavior.

Reference [12] provides the command-level foundation for inspecting the effective configuration.

Finally, review references [15] through [18] to connect container configuration with application image construction, storage, and runtime behavior.

---

# 93. FINAL LECTURE CONCLUSION

The transition from simple container execution to reliable multi-container operations requires a broader understanding of configuration and lifecycle management.

Docker Compose provides a declarative application model, but successful operation depends on how that model interacts with application processes, networks, storage, and dependencies.

Health checks provide evidence about selected operational conditions.

They do not establish universal application correctness.

Dependency conditions improve startup coordination but do not remove the need for runtime failure handling.

Container restart policies govern qualifying process termination events, while Compose dependency restart propagation coordinates certain explicitly requested operations.

These mechanisms must be understood separately.

Environment variables allow application images to remain reusable across multiple deployment configurations.

Correct environment management requires understanding how Dockerfile defaults, Compose environment files, interpolation inputs, and explicit overrides interact.

Multiple Compose files provide a mechanism for expressing development-specific and staging-specific requirements without duplicating an entire application definition.

Compose profiles support optional application components.

Compose Watch supports rapid development by responding to source and dependency changes through synchronization, restarting, and rebuilding.

Read-only root filesystems provide one additional mechanism for reducing unnecessary filesystem modification.

The practical laboratory integrates these capabilities in a Flask-and-Redis application that preserves its persistent state while application configuration and development behavior change.

The resulting system demonstrates the operational responsibilities required to manage a multi-container application beyond its initial successful startup.

These competencies prepare the student for the comprehensive Week Two assessment and practical project.

---

**END OF LECTURE 13**

**Next Lecture:** Lecture 14 — Week Two Comprehensive Review and Capstone Project: Docker Networking, Persistent Storage, and Compose-Based Multi-Container Application Engineering.
