# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 20 — DOCKER CONTINUOUS INTEGRATION AND CONTINUOUS DELIVERY: GITHUB ACTIONS, AUTOMATED TESTING, BUILDKIT, DOCKER HUB PUBLICATION, SOFTWARE RELEASE SECURITY, AND DEPLOYMENT AUTOMATION

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 20 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 6–8 hours  
**Lecture Type:** Formal Theory, Complete CI/CD Project, Practical Laboratory, Troubleshooting, and Final Examination

**Prerequisites:** Lectures 01–19, particularly Dockerfiles, multi-stage builds, Docker Compose, BuildKit, container security, registries, and production deployment.

---

# 1. PURPOSE OF THE LECTURE

During the previous lectures, Docker images were created and operated through commands executed directly by the student.

For example:

```bash
docker build -t application:1.0.0 .
```

```bash
docker run application:1.0.0
```

```bash
docker push username/application:1.0.0
```

These commands remain important.

However, manual execution creates operational challenges.

A developer may forget to run a test.

An administrator may build an image using the wrong source revision.

A release may be published under an incorrect tag.

A deployment may contain a different artifact from the one that passed testing.

A credential may be handled insecurely.

Continuous Integration and Continuous Delivery provide systematic mechanisms for reducing these risks.

The purpose of Lecture 20 is to demonstrate how Docker image construction, application testing, image verification, and registry publication can be expressed as a repeatable automated workflow.

The principal automation platform used in this lecture is GitHub Actions.

By the end of the laboratory, the student will have a complete project containing:

1. A Python HTTP application.
2. Automated Python tests.
3. A multi-stage Dockerfile.
4. A pull-request CI workflow.
5. A separate release-publishing workflow.
6. Docker Buildx configuration.
7. Build cache configuration.
8. Docker Hub credential integration.
9. Semantic release tags.
10. Image provenance and SBOM generation.
11. A deployment Compose file.
12. A release verification and rollback procedure.

The workflows are designed to distinguish application validation from authorization to publish software.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Define Continuous Integration.
2. Define Continuous Delivery.
3. Define Continuous Deployment.
4. Distinguish CI from CD.
5. Explain the purpose of automated build pipelines.
6. Describe the software development lifecycle.
7. Explain the role of source control in release engineering.
8. Describe the relationship between Git commits and Docker image artifacts.
9. Define a CI/CD workflow.
10. Explain GitHub Actions architecture.
11. Distinguish workflows, events, jobs, steps, actions, and runners.
12. Identify workflow configuration files.
13. Explain GitHub Actions YAML syntax.
14. Configure push-triggered workflows.
15. Configure pull-request-triggered workflows.
16. Explain tag-triggered release workflows.
17. Explain manual workflow dispatch.
18. Use workflow-level and job-level permissions.
19. Explain the purpose of the GitHub-provided token.
20. Describe GitHub Actions secrets and variables.
21. Explain the security risks of untrusted pull-request code.
22. Distinguish pull_request from pull_request_target.
23. Describe GitHub-hosted and self-hosted runners.
24. Explain runner isolation requirements.
25. Use actions/checkout.
26. Use actions/setup-python.
27. Execute automated Python unit tests.
28. Construct a multi-stage Docker image.
29. Execute tests inside a Docker build stage.
30. Perform an HTTP smoke test against a container.
31. Explain the role of Docker Buildx.
32. Configure Docker's official GitHub Actions.
33. Explain build cache import and export.
34. Use the GitHub Actions cache backend.
35. Describe the importance of cache isolation.
36. Explain Docker Hub authentication in CI/CD.
37. Use registry access tokens without hardcoding them.
38. Generate release tags using Docker Metadata Action.
39. Publish images using Docker Build Push Action.
40. Explain immutable image digests.
41. Describe SBOM and provenance attestations.
42. Explain the security implications of build arguments.
43. Distinguish artifact publication from deployment.
44. Deploy a released image using Docker Compose.
45. Verify the deployed application.
46. Describe deployment rollback.
47. Diagnose common CI/CD failures.
48. Construct a formal release engineering report.

---

# PART I — CI/CD THEORY

# 3. SOFTWARE DEVELOPMENT AND DELIVERY

A software project passes through several engineering activities.

These commonly include:

- Requirements analysis.
- Application design.
- Implementation.
- Source code review.
- Testing.
- Building.
- Packaging.
- Publication.
- Deployment.
- Monitoring.
- Maintenance.

Without automation, these activities depend heavily on manual execution.

Automation allows selected procedures to run consistently in response to well-defined events.

A simplified delivery process is:

```text
                  SOURCE CODE
                      |
                      v
                   COMMIT
                      |
                      v
                AUTOMATED TESTS
                      |
                      v
                PACKAGE SOFTWARE
                      |
                      v
                VERIFY ARTIFACT
                      |
                      v
                 PUBLISH IMAGE
                      |
                      v
                   DEPLOY
                      |
                      v
                   MONITOR
```

The purpose of CI/CD is not to remove engineering judgment.

It is to automate repeatable technical work so that engineers can focus on review, risk evaluation, and system design.

---

# 4. CONTINUOUS INTEGRATION

## 4.1 Definition

Continuous Integration, abbreviated CI, is a software development practice in which code changes are integrated frequently and validated through automated processes.

Typical CI activities include:

1. Retrieving source code.
2. Installing dependencies.
3. Running automated tests.
4. Performing static analysis.
5. Building the application.
6. Reporting results.

## 4.2 Primary Objective

CI helps identify defects early in the development process.

## 4.3 Example

A developer modifies a Python application.

GitHub Actions runs unit tests and verifies that a Docker image can be built.

If the tests fail, the workflow reports failure.

The change should not be treated as validated until the relevant checks succeed.

---

# 5. CONTINUOUS DELIVERY

## 5.1 Definition

Continuous Delivery is a software engineering practice in which software is maintained in a condition suitable for release through repeatable build, test, and packaging processes.

The final production deployment may still require a manual approval or scheduled release operation.

## 5.2 Example

A workflow automatically:

- Tests an application.
- Builds a Docker image.
- Publishes an approved release candidate.
- Records its content digest.

An operator later decides when to deploy it.

## 5.3 Principal Benefit

The organization separates the ability to release software from the decision to release it immediately.

---

# 6. CONTINUOUS DEPLOYMENT

## 6.1 Definition

Continuous Deployment extends automation so that changes satisfying the required checks can be deployed automatically to the target environment without a separate manual release decision.

## 6.2 Example

A production deployment workflow may automatically execute after all required tests and controls pass.

## 6.3 Risk

Automatically deploying every successful change may be inappropriate for systems requiring:

- Formal change approval.
- Regulatory review.
- Coordinated database migration.
- Restricted maintenance windows.
- Human operational authorization.

## 6.4 Important Principle

Continuous Delivery and Continuous Deployment are related but distinct concepts.

---

# 7. COMPARISON OF CI, DELIVERY, AND DEPLOYMENT

| Practice | Principal activity | Typical result |
|---|---|---|
| Continuous Integration | Validate code changes | Tested build or validation result |
| Continuous Delivery | Prepare verified software for release | Deployable artifact |
| Continuous Deployment | Automatically release approved changes | Updated running environment |

A project may implement CI without implementing automatic deployment.

A Docker image may be published without being deployed.

---

# 8. AUTOMATED PIPELINES

A pipeline is an organized sequence or graph of automated operations.

A pipeline may contain:

```text
                  SOURCE COMMIT
                        |
                        v
                    UNIT TESTS
                        |
                        v
                DOCKER BUILD TEST
                        |
                        v
                 CONTAINER SMOKE
                        |
                        v
                 SECURITY CHECK
                        |
                        v
                 RELEASE APPROVAL
                        |
                        v
                 REGISTRY PUBLISH
```

A pipeline should stop or report failure when a required validation step fails.

A later publication stage should not ignore a failed required test.

---

# 9. PIPELINE QUALITY GATES

A quality gate is a condition that must be satisfied before the process proceeds.

Examples include:

- Unit tests pass.
- Docker build succeeds.
- Image smoke test succeeds.
- Required review is complete.
- Vulnerability policy is satisfied.
- Release tag is valid.
- Publishing credentials are authorized.

## Example

If a unit test fails, the image must not be considered ready for publication.

## Important Qualification

A passing pipeline provides evidence that the configured tests succeeded.

It does not prove that the application has no defects.

---

# 10. SOURCE CONTROL AS THE FOUNDATION

Git records changes to source code and project configuration.

A Git commit identifies a particular repository state.

CI/CD systems use source-control events to initiate automated workflows.

Examples include:

- New commits.
- Pull requests.
- Release tags.
- Manually initiated workflow runs.

## Engineering Importance

A release should be traceable to the source revision from which it was built.

This relationship helps operators determine which code is running in a particular environment.

---

# 11. GIT COMMITS AND IMAGE DIGESTS

A Git commit and a Docker image digest represent different things.

## Git Commit

Identifies a source repository state.

## Docker Image Digest

Identifies specific image manifest or index content stored in a registry.

## Relationship

```text
                    GIT COMMIT
                        |
                        v
                   BUILD PROCESS
                        |
                        v
                   DOCKER IMAGE
                        |
                        v
                  IMAGE DIGEST
```

One Git commit can produce different image artifacts when build parameters, dependencies, platforms, or toolchains differ.

Therefore, a Git commit hash and an image digest should not be treated as interchangeable identifiers.

---

# 12. INTRODUCTION TO GITHUB ACTIONS

GitHub Actions is an automation platform integrated with GitHub repositories.

It allows workflows to execute in response to selected repository or platform events.

GitHub Actions can automate:

- Testing.
- Building.
- Packaging.
- Publishing.
- Documentation generation.
- Security checks.
- Deployment.
- Scheduled maintenance tasks.

The automation behavior is defined through workflow files stored in the repository.

---

# 13. GITHUB ACTIONS ARCHITECTURE

```text
GITHUB REPOSITORY → EVENT
EVENT → WORKFLOW FILE
WORKFLOW FILE → JOBS
JOBS → TEST JOB
TEST JOB → STEPS
STEPS → RESULTS
JOBS → BUILD JOB
BUILD JOB → STEPS
STEPS → ARTIFACTS
```

The central components are:

1. Workflow.
2. Event.
3. Job.
4. Step.
5. Action.
6. Runner.

---

# 14. WORKFLOWS

A workflow is an automated process defined by a YAML file.

GitHub Actions workflow files reside in:

```text
.github/workflows/
```

Example:

```text
.github/workflows/ci.yaml
```

A repository may contain multiple workflows.

Separating validation workflows from release workflows helps establish clear security and operational boundaries.

---

# 15. WORKFLOW EVENTS

The `on` section determines which events trigger a workflow.

Example:

```yaml
on:
  push:
    branches:
      - main
```

This starts the workflow when a qualifying push occurs on the main branch.

Other event types include:

- `pull_request`.
- `workflow_dispatch`.
- `schedule`.
- `release`.
- `workflow_run`.

Each event has its own semantics and security considerations.

---

# 16. PULL REQUEST EVENTS

A pull request proposes changes to a repository branch.

CI can run automatically when a pull request is opened or updated.

Example:

```yaml
on:
  pull_request:
    branches:
      - main
```

## Benefit

The proposed change is validated before it is merged.

## Security Concern

The code submitted in a pull request may originate from an untrusted contributor.

A pull-request workflow should therefore avoid exposing privileged credentials unnecessarily.

---

# 17. PUSH EVENTS

A workflow can execute when code is pushed to a branch.

Example:

```yaml
on:
  push:
    branches:
      - main
```

## Purpose

A push workflow can validate code after it has been integrated.

## Important Distinction

A push to main is not automatically the same as a production release.

The organization should define how releases are selected and approved.

---

# 18. TAG EVENTS

Git tags may identify software releases.

Example:

```text
v1.0.0
```

A workflow can respond to selected tags:

```yaml
on:
  push:
    tags:
      - 'v*'
```

## Purpose

A release-tag event can initiate packaging and publication.

## Important Qualification

The pattern `v*` is broader than a strict Semantic Versioning expression.

A validation step should confirm that the tag follows the intended version format.

---

# 19. MANUAL WORKFLOW DISPATCH

GitHub Actions supports manually initiated workflows.

Example:

```yaml
on:
  workflow_dispatch:
```

This can be useful for:

- Controlled maintenance.
- Release approval operations.
- Manual smoke tests.
- Selected deployment operations.

## Important Principle

Manual initiation is not automatically secure.

The workflow must still verify permissions, configuration, and requested operations.

---

# 20. JOBS

A job is a collection of steps executed on a selected runner.

Example:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Display Python version
        run: python --version
```

A workflow can contain multiple jobs.

Jobs may execute in parallel when their dependencies permit.

---

# 21. STEPS

A step is an individual operation within a job.

A step may execute a shell command:

```yaml
- name: Run tests
  run: python -m unittest discover -s tests -v
```

Or use a reusable action:

```yaml
- name: Check out source
  uses: actions/checkout@v7
```

Steps within the same job ordinarily execute in their configured order.

---

# 22. ACTIONS

An action is a reusable automation component.

Examples include:

- `actions/checkout`.
- `actions/setup-python`.
- `docker/setup-buildx-action`.
- `docker/login-action`.
- `docker/metadata-action`.
- `docker/build-push-action`.

Actions may perform complex tasks such as installing a toolchain, authenticating to a registry, or building an image.

## Security Qualification

Third-party actions should be reviewed and selected carefully.

For high-assurance environments, actions should be pinned to reviewed full commit SHAs rather than only floating major-version references.

Major versions are used in this educational laboratory for clarity.

---

# 23. RUNNERS

A runner is the execution environment that performs a GitHub Actions job.

GitHub supports:

- GitHub-hosted runners.
- Self-hosted runners.

## GitHub-Hosted Runners

GitHub manages the underlying runner environment.

## Self-Hosted Runners

An organization operates the machine or environment executing the workflow.

## Security Consideration

Self-hosted runners require careful isolation, update management, and protection of internal resources.

Untrusted pull-request code should not execute on a persistent privileged runner with access to sensitive internal infrastructure.

---

# 24. RUNNER EPHEMERALITY

Ephemeral execution environments help reduce state sharing between unrelated workflow runs.

A build runner may temporarily contain:

- Source files.
- Build artifacts.
- Container images.
- Registry credentials.
- Temporary logs.
- Cache data.

A secure CI/CD system must prevent inappropriate access to this information.

GitHub-hosted runners are commonly suitable for introductory CI/CD exercises.

---

# 25. JOB DEPENDENCIES

GitHub Actions supports the `needs` keyword.

Example:

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest

    steps:
      - run: echo "Verification"

  publish:
    needs: verify
    runs-on: ubuntu-latest

    steps:
      - run: echo "Publication"
```

The `publish` job depends on the successful completion of the `verify` job under the normal job dependency rules.

## Engineering Benefit

This is a mechanism for implementing quality gates between jobs.

---

# 26. WORKFLOW PERMISSIONS

GitHub provides a job token commonly called `GITHUB_TOKEN`.

Its effective permissions depend on repository, organization, event, and workflow configuration.

A workflow should explicitly request only the required permissions.

Example:

```yaml
permissions:
  contents: read
```

This is suitable for a job that only needs to read repository content.

## Important Principle

A testing job should not receive registry publication or repository modification privileges unless required.

---

# 27. GITHUB SECRETS

GitHub Actions can expose configured secret values to authorized workflow contexts.

Examples include:

- Docker Hub access token.
- Cloud deployment credentials.
- Private package registry token.

Secrets should not be written directly in workflow source code.

Example reference:

```yaml
${{ secrets.DOCKERHUB_TOKEN }}
```

The actual value is configured through GitHub's secret-management interface.

## Critical Qualification

Secrets are generally not made available to ordinary pull-request workflows originating from untrusted forks.

This is an intentional security boundary.

---

# 28. GITHUB VARIABLES

GitHub Actions also supports configuration variables.

Example:

```yaml
${{ vars.DOCKERHUB_USERNAME }}
```

Variables are useful for non-secret information.

Examples include:

- Registry username.
- Repository name.
- Deployment region.
- Logical environment name.

## Important Distinction

Variables are not equivalent to secrets.

Sensitive credentials should be stored using an appropriate secret mechanism.

---

# 29. PULL REQUEST SECURITY

The distinction between `pull_request` and `pull_request_target` is particularly important.

## pull_request

Ordinary pull-request workflows generally execute with restricted privileges for untrusted fork contributions.

Repository secrets are not supplied to untrusted fork workflows under the normal security model.

## pull_request_target

This event can execute with elevated trust associated with the base repository.

Executing untrusted pull-request code in such a workflow while privileged tokens or secrets are available can create a serious security vulnerability.

## Recommended Laboratory Policy

Use:

```yaml
on:
  pull_request:
```

for unprivileged validation.

Use a separate protected release workflow for registry publication.

---

# 30. CONTINUOUS INTEGRATION SECURITY BOUNDARY

The lecture uses two independent workflows.

```text
              PULL REQUEST
                   |
                   v
              CI WORKFLOW
                   |
               UNIT TESTS
                   |
              DOCKER BUILD
                   |
               SMOKE TEST
                   |
                   v
            PASS OR FAILURE


             VERSIONED GIT TAG
                   |
                   v
             RELEASE WORKFLOW
                   |
              VALIDATION JOB
                   |
                SUCCESS?
                   |
                   v
              PUBLISH JOB
                   |
              REGISTRY TOKEN
                   |
                   v
                DOCKER HUB
```

The pull-request workflow does not require Docker Hub credentials.

The release workflow accesses publication credentials only in its publishing job.

---

# PART II — DOCKER BUILD AUTOMATION

# 31. AUTOMATING DOCKER IMAGE BUILDS

A Docker image can be constructed in CI using the same Dockerfile employed during local development.

Example:

```bash
docker build -t application:ci .
```

The build should be reproducible enough that its behavior can be understood and verified.

## Benefits

- Reduced manual inconsistency.
- Automatic failure detection.
- Repeatable build instructions.
- Clear relationship between source revision and artifact.

---

# 32. MULTI-STAGE BUILDS IN CI

A multi-stage Dockerfile can separate:

1. Test environment.
2. Runtime environment.

Example:

```dockerfile
FROM python:3.12-slim AS test

# Copy and test application.

FROM python:3.12-slim AS runtime

# Copy only required runtime artifacts.
```

## Important Principle

The final runtime stage should have an explicit dependency on validated build output when the build itself is intended to enforce testing.

This prevents a successful runtime build from silently bypassing the required test stage.

---

# 33. TESTING INSIDE DOCKER

Tests can execute directly on the runner or inside Docker build stages.

## Runner-Based Testing

Advantages:

- Fast feedback for simple projects.
- Convenient test reports.
- No image build required for the earliest checks.

## Container-Based Testing

Advantages:

- Tests execute inside the selected container build environment.
- Dependency and runtime compatibility can be evaluated.
- The build fails when a required test stage fails.

## Recommended Approach

Use both methods when their benefits justify the added time.

The laboratory will include runner-based Python tests and Docker build-stage testing.

---

# 34. CONTAINER SMOKE TESTS

A smoke test is a limited test confirming that an application can start and perform essential functions.

A Docker smoke test may:

1. Build the runtime image.
2. Start a container.
3. Wait for an HTTP endpoint.
4. Check the health response.
5. Verify an application API response.
6. Stop and remove the container.

## Important Distinction

A smoke test is not a complete load test, security audit, or integration test.

It establishes a basic operational baseline.

---

# 35. DOCKER BUILDX IN CI

Buildx is Docker's extended interface for BuildKit.

GitHub Actions can configure a Buildx builder using:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v4
```

Buildx supports:

- Multi-stage builds.
- Build caching.
- Multi-platform builds.
- Registry publishing.
- Additional build metadata.
- Advanced build outputs.

---

# 36. DOCKER BUILD PUSH ACTION

The official Docker Build Push Action supports image construction and publication through Buildx.

Example:

```yaml
- name: Build image
  uses: docker/build-push-action@v7

  with:
    context: .
    push: false
```

When configured appropriately:

```yaml
push: true
```

publishes the build output to a registry.

## Important Requirement

Registry authentication and a valid destination image reference must be configured before publication.

---

# 37. BUILD CACHE IN CI

Build caching improves repeated build performance.

Without an external cache, each new ephemeral runner may have limited access to results from previous runs.

BuildKit supports external cache backends.

For GitHub Actions, the `gha` backend can provide cache import and export.

Example:

```yaml
cache-from: type=gha,scope=lecture20
cache-to: type=gha,mode=max,scope=lecture20
```

## Important Qualification

Cache availability depends on GitHub's cache access rules, retention, size limits, and builder configuration.

Caching is a performance optimization.

A correct build must succeed without a warm cache.

---

# 38. GITHUB ACTIONS CACHE API

GitHub Actions cache integration uses a dedicated service API.

Current BuildKit integrations use the supported GitHub Actions cache API v2.

Older unsupported tools may fail when attempting to use the retired API v1.

Modern GitHub-hosted runners and maintained Docker Actions generally provide appropriate tooling.

Self-hosted runners require more deliberate version management.

---

# 39. CACHE SCOPE

A cache scope identifies an independently managed cache entry or namespace.

Example:

```text
lecture20-ci
```

and:

```text
lecture20-release
```

Using separate scopes can help distinguish validation and release build caches.

## Security and Reliability

Cache entries should not be treated as trusted release artifacts.

Their contents are inputs to build optimization, not replacements for source validation and testing.

---

# 40. IMAGE TAG AUTOMATION

Image tags can be generated from repository metadata.

For example:

```text
Git tag: v1.0.0

Docker image tag: 1.0.0
```

A release workflow can also generate a source-revision tag.

Example:

```text
sha-<full-commit-hash>
```

## Benefit

This establishes traceability between a Git commit and a published image reference.

---

# 41. DOCKER METADATA ACTION

Docker Metadata Action generates image tags and OCI labels from GitHub event information.

Example:

```yaml
- name: Generate Docker metadata
  id: meta
  uses: docker/metadata-action@v6

  with:
    images: example-user/lecture20-api
    flavor: |
      latest=false
    tags: |
      type=semver,pattern={{version}}
      type=sha,format=long
```

## Interpretation

A tag such as `v1.0.0` produces a version-oriented image tag.

A source-revision tag supports traceability.

The `latest=false` configuration explicitly avoids automatically assigning the mutable `latest` tag.

---

# 42. AUTOMATED REGISTRY AUTHENTICATION

Docker Login Action supports registry authentication.

For Docker Hub:

```yaml
- name: Log in to Docker Hub
  uses: docker/login-action@v4

  with:
    username: ${{ vars.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

## Important Security Principle

The token should be authorized only for the required registry operations.

Avoid using an ordinary account password when an appropriate access token is available.

---

# 43. GITHUB_TOKEN VERSUS DOCKER HUB TOKEN

The automatically provided GitHub token is associated with GitHub repository permissions.

A Docker Hub access token is associated with Docker Hub authentication and authorization.

These are not interchangeable.

| Credential | Primary purpose |
|---|---|
| `GITHUB_TOKEN` | Selected GitHub API and repository operations |
| Docker Hub token | Docker Hub registry authentication |
| Cloud deployment token | Authorized cloud environment operations |

A CI job should receive only the credentials it actually requires.

---

# 44. BUILD ARGUMENTS AND RELEASE METADATA

Dockerfiles can receive non-sensitive release metadata through build arguments.

Example:

```dockerfile
ARG APP_VERSION=development

ARG VCS_REF=unknown
```

During a release build, the pipeline supplies the intended values.

## Security Warning

Build arguments must not be used to transport secrets.

Build provenance can record build argument values.

Secret values may therefore be exposed if incorrectly passed as ordinary build arguments.

---

# 45. SOFTWARE BILL OF MATERIALS

A Software Bill of Materials, abbreviated SBOM, is a structured inventory of components associated with a software artifact.

BuildKit can generate SBOM-related attestations.

A Docker Build Push Action configuration can request:

```yaml
sbom: true
```

## Benefit

SBOMs can support:

- Dependency analysis.
- Vulnerability response.
- Software inventory.
- Supply-chain transparency.

## Limitation

An SBOM is not a substitute for vulnerability assessment or application testing.

---

# 46. BUILD PROVENANCE

Build provenance records information concerning the production of an artifact.

A workflow can request:

```yaml
provenance: mode=max
```

## Possible Information

Build provenance may include:

- Source revision.
- Builder information.
- Build inputs.
- Build parameters.
- Build relationships.

## Important Security Consideration

Maximum provenance can expose non-secret build parameters.

Never include real credentials in build arguments.

---

# 47. ATTESTATIONS

Attestations associate an artifact with structured statements about its origin or contents.

Examples include:

- Provenance attestations.
- SBOM attestations.

These can improve software supply-chain transparency.

However, an attestation is only useful when its source, integrity, and meaning are appropriately verified.

The presence of an attestation does not independently guarantee that the application is secure.

---

# 48. ARTIFACT IDENTIFICATION

A release should be traceable through several identifiers.

| Identifier | Purpose |
|---|---|
| Git commit SHA | Source revision |
| Git release tag | Human-readable release |
| Docker image tag | Registry version reference |
| Image digest | Exact published image content |
| Build run identifier | Automation execution record |

A professional release record should preserve these relationships.

---

# 49. PUBLISHING IS NOT DEPLOYMENT

Publishing an image to Docker Hub does not automatically update any running application.

The registry receives the image artifact.

A deployment system must subsequently retrieve or select that artifact and update the running service.

## Example

```text
GitHub Actions
      |
      v
Docker Hub
      |
      v
Image available for deployment
      |
      v
Separate deployment action
      |
      v
Running service updated
```

The distinction is essential for responsible release management.

---

# 50. CONTINUOUS DEPLOYMENT SECURITY

A deployment pipeline may require:

- Protected environments.
- Deployment approvals.
- Restricted credentials.
- Branch or tag protection.
- Health verification.
- Rollback procedures.
- Audit records.

GitHub environment protections can support some of these controls when correctly configured.

## Important Principle

Publishing a successful build is not automatically authorization to deploy it into production.

---

# PART III — COMPLETE CI/CD PROJECT

# 51. PROJECT TITLE

**Automated Container Release Pipeline: Python HTTP Application, GitHub Actions Continuous Integration, Docker Hub Publication, and Compose-Based Release Verification**

## Project Objective

Construct a repository in which:

1. Pull requests trigger automated tests.
2. Main-branch pushes trigger validation.
3. Validation builds and smoke-tests the Docker application.
4. Versioned Git tags trigger a separate release workflow.
5. The release workflow performs its own validation.
6. Docker Hub credentials are used only in the publication job.
7. A Docker image is published with version and commit-based tags.
8. Build provenance and SBOM metadata are requested.
9. The published digest is recorded.
10. A deployment environment can pull and run the selected image.

---

# 52. PROJECT DIRECTORY STRUCTURE

Create:

```text
docker-lecture20/
├── app.py
├── Dockerfile
├── .dockerignore
├── .gitignore
├── tests/
│   └── test_app.py
├── .github/
│   └── workflows/
│       ├── ci.yaml
│       └── release.yaml
├── compose.deploy.yaml
├── deploy.env.example
└── README.md
```

The project contains separate application, validation, release, and deployment configurations.

---

# 53. PYTHON APPLICATION REQUIREMENTS

The application must provide:

1. An HTML homepage.
2. A health endpoint.
3. A JSON release-information endpoint.
4. A correct 404 response for unknown paths.
5. Version metadata.
6. Source revision metadata.
7. HTTP listening on container port 8000.

The project uses only Python's standard library.

This avoids introducing external Python dependencies into the introductory CI/CD example.

---

# 54. COMPLETE PYTHON APPLICATION

Create:

`app.py`

Insert:

```python
import html
import json
import os

from http.server import (
    BaseHTTPRequestHandler,
    ThreadingHTTPServer,
)

from urllib.parse import urlsplit


def release_info():

    return {
        "application": "lecture20-api",
        "version": os.getenv(
            "APP_VERSION",
            "development",
        ),
        "revision": os.getenv(
            "VCS_REF",
            "unknown",
        ),
    }


class ApplicationHandler(BaseHTTPRequestHandler):

    def respond(
        self,
        status,
        content_type,
        body,
    ):

        self.send_response(status)

        self.send_header(
            "Content-Type",
            content_type,
        )

        self.send_header(
            "Content-Length",
            str(len(body)),
        )

        self.end_headers()

        self.wfile.write(body)


    def do_GET(self):

        path = urlsplit(self.path).path

        if path == "/healthz":

            self.respond(
                200,
                "text/plain; charset=utf-8",
                b"ok\n",
            )

            return


        if path == "/api/info":

            body = json.dumps(
                release_info(),
                sort_keys=True,
            ).encode("utf-8")

            self.respond(
                200,
                "application/json",
                body,
            )

            return


        if path == "/":

            info = release_info()

            version = html.escape(
                info["version"]
            )

            revision = html.escape(
                info["revision"]
            )

            page = f"""<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Docker Lecture 20</title>

</head>

<body style="font-family:Arial;padding:40px;">

    <h1>Docker Lecture 20</h1>

    <h2>GitHub Actions CI/CD Laboratory</h2>

    <p>Application Version: {version}</p>

    <p>Source Revision: {revision}</p>

    <p>
        This application was packaged as a
        Docker image and validated by an
        automated CI/CD workflow.
    </p>

    <p>
        API endpoint: /api/info
    </p>

</body>

</html>
"""

            self.respond(
                200,
                "text/html; charset=utf-8",
                page.encode("utf-8"),
            )

            return


        body = json.dumps({
            "error": "Not found",
        }).encode("utf-8")

        self.respond(
            404,
            "application/json",
            body,
        )


def main():

    server = ThreadingHTTPServer(
        ("0.0.0.0", 8000),
        ApplicationHandler,
    )

    print(
        "Docker Lecture 20 HTTP service started",
        flush=True,
    )

    server.serve_forever()


if __name__ == "__main__":

    main()
```

---

# 55. APPLICATION ARCHITECTURE

The application is intentionally small.

It allows the laboratory to focus on delivery automation rather than framework configuration.

The endpoint `/healthz` returns a successful basic health response.

The endpoint `/api/info` returns non-sensitive release metadata.

The homepage displays the same metadata through an HTML response.

The application reads its version and source revision from environment variables.

This information will be incorporated into the image during the release build.

---

# 56. COMPLETE PYTHON TEST SUITE

Create:

`tests/test_app.py`

Insert:

```python
import json
import os
import threading
import unittest

from unittest.mock import patch

from urllib.error import HTTPError
from urllib.request import urlopen

from http.server import ThreadingHTTPServer

from app import (
    ApplicationHandler,
    release_info,
)


class ReleaseInformationTests(unittest.TestCase):

    def test_application_name(self):

        result = release_info()

        self.assertEqual(
            result["application"],
            "lecture20-api",
        )


    def test_default_fields_exist(self):

        result = release_info()

        self.assertIn(
            "version",
            result,
        )

        self.assertIn(
            "revision",
            result,
        )


    def test_environment_metadata(self):

        with patch.dict(
            os.environ,
            {
                "APP_VERSION": "9.9.9",
                "VCS_REF": "test-revision",
            },
        ):

            result = release_info()

            self.assertEqual(
                result["version"],
                "9.9.9",
            )

            self.assertEqual(
                result["revision"],
                "test-revision",
            )


class HttpApplicationTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):

        cls.server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            ApplicationHandler,
        )

        cls.port = cls.server.server_port

        cls.thread = threading.Thread(
            target=cls.server.serve_forever,
            daemon=True,
        )

        cls.thread.start()


    @classmethod
    def tearDownClass(cls):

        cls.server.shutdown()

        cls.server.server_close()

        cls.thread.join(timeout=5)


    def request(self, path):

        address = (
            f"http://127.0.0.1:{self.port}{path}"
        )

        return urlopen(
            address,
            timeout=3,
        )


    def test_health_endpoint(self):

        with self.request("/healthz") as response:

            self.assertEqual(
                response.status,
                200,
            )

            self.assertEqual(
                response.read(),
                b"ok\n",
            )


    def test_info_endpoint(self):

        with self.request("/api/info") as response:

            data = json.load(response)

            self.assertEqual(
                response.status,
                200,
            )

            self.assertEqual(
                data["application"],
                "lecture20-api",
            )


    def test_homepage(self):

        with self.request("/") as response:

            body = response.read().decode(
                "utf-8"
            )

            self.assertEqual(
                response.status,
                200,
            )

            self.assertIn(
                "Docker Lecture 20",
                body,
            )


    def test_unknown_route(self):

        with self.assertRaises(HTTPError) as result:

            self.request(
                "/not-a-valid-route"
            )

        self.assertEqual(
            result.exception.code,
            404,
        )


if __name__ == "__main__":

    unittest.main()
```

---

# 57. TEST DESIGN ANALYSIS

The test suite provides two categories of validation.

## Unit-Level Validation

The release-information tests verify:

- Application identity.
- Presence of version fields.
- Environment-based metadata.

## HTTP-Level Validation

The HTTP tests create a temporary server on a dynamically selected loopback port.

They verify:

- Health response.
- JSON API response.
- Homepage.
- Unknown-path handling.

## Important Engineering Detail

Using an automatically allocated local port reduces the likelihood of a port conflict during testing.

The server is shut down after the tests complete.

---

# 58. COMPLETE MULTI-STAGE DOCKERFILE

Create:

`Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim AS test

WORKDIR /app

COPY app.py ./app.py

COPY tests/ ./tests/

RUN python -m unittest discover -s tests -v


FROM python:3.12-slim AS runtime

ARG APP_VERSION=development

ARG VCS_REF=unknown

LABEL org.opencontainers.image.title="Docker Lecture 20 API" \
      org.opencontainers.image.description="GitHub Actions CI/CD Laboratory"

ENV APP_VERSION=${APP_VERSION} \
    VCS_REF=${VCS_REF} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=test --chown=10001:10001 \
    /app/app.py \
    /app/app.py

USER 10001:10001

EXPOSE 8000

CMD ["python", "-B", "app.py"]
```

---

# 59. DOCKERFILE DESIGN ANALYSIS

## Test Stage

The test stage executes the unit and HTTP test suite.

A failing test causes the relevant build operation to fail.

## Runtime Stage

The runtime stage contains the required Python interpreter and application file.

The tests themselves are not copied into the runtime image.

## Build Dependency

The runtime image copies its application file from the completed test stage.

This creates a dependency between construction of the runtime artifact and execution of the test stage.

## Non-Root Execution

The image executes with UID and GID 10001.

## Release Metadata

Version and source revision values are passed through non-secret build arguments.

---

# 60. BUILD CONTEXT EXCLUSIONS

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.github
.env
deploy.env
__pycache__/
*.pyc
*.log
*.tmp
artifacts/
```

Create:

`.gitignore`

Insert:

```gitignore
.env
deploy.env
__pycache__/
*.pyc
artifacts/
```

## Important Distinction

The `.github` directory must remain in the Git repository.

It is excluded only from the Docker build context.

The CI/CD workflow files must be available to GitHub even though they are not required inside the application image.

---

# PART IV — COMPLETE GITHUB ACTIONS CONFIGURATION

# 61. WORKFLOW ONE: CONTINUOUS INTEGRATION

Create:

`.github/workflows/ci.yaml`

Insert:

```yaml
name: Docker Continuous Integration

on:
  pull_request:
    branches:
      - main

  push:
    branches:
      - main


permissions:
  contents: read


concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true


jobs:

  validate:
    name: Test, Build, and Smoke Test

    runs-on: ubuntu-latest

    timeout-minutes: 20

    steps:

      - name: Check out repository
        uses: actions/checkout@v7

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: '3.12'

      - name: Compile Python source
        run: |
          python -m py_compile app.py
          python -m py_compile tests/test_app.py

      - name: Run unit and HTTP tests
        run: |
          python -m unittest discover -s tests -v

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Validate Docker test stage
        uses: docker/build-push-action@v7
        with:
          context: .
          target: test
          push: false
          cache-from: type=gha,scope=lecture20-ci
          cache-to: type=gha,mode=max,scope=lecture20-ci

      - name: Build runtime image
        run: |
          docker build \
            --target runtime \
            --tag lecture20-api:ci \
            .

      - name: Smoke test application container
        shell: bash
        run: |
          set -euo pipefail

          trap 'docker rm -f lecture20-ci-test >/dev/null 2>&1 || true' EXIT

          docker run -d \
            --name lecture20-ci-test \
            -p 127.0.0.1:8290:8000 \
            lecture20-api:ci

          ready=0

          for attempt in {1..20}; do
            if curl --fail --silent \
              http://127.0.0.1:8290/healthz \
              >/dev/null; then
              ready=1
              break
            fi

            sleep 1
          done

          if [ "$ready" -ne 1 ]; then
            docker logs lecture20-ci-test
            exit 1
          fi

          curl --fail --show-error \
            http://127.0.0.1:8290/api/info

          echo "Container smoke test passed"
```

---

# 62. CI WORKFLOW ANALYSIS

The CI workflow has one primary validation job.

It runs for:

- Pull requests targeting main.
- Pushes to main.

The job performs several checks.

## Step 1 — Checkout

The repository source is retrieved.

## Step 2 — Python Setup

Python 3.12 is selected.

## Step 3 — Syntax Verification

The Python source files are compiled to verify basic syntax.

## Step 4 — Application Tests

The test suite executes on the runner.

## Step 5 — Buildx Setup

A modern BuildKit builder is configured.

## Step 6 — Docker Test Stage

The Dockerfile test stage is built.

The tests run inside the image-construction environment.

## Step 7 — Runtime Image

A local runtime image is constructed.

## Step 8 — Smoke Test

The image is started as a container.

The workflow waits for the health endpoint and verifies the release-information API.

## Security Property

This workflow does not require Docker Hub credentials.

It does not publish images.

---

# 63. CI WORKFLOW FAILURE BEHAVIOR

A required failing step normally causes the job to fail.

Examples include:

- Invalid Python syntax.
- Failed assertion.
- Dockerfile build error.
- Missing Docker image.
- Container startup failure.
- Unsuccessful health check.
- API request failure.

The pipeline should be treated as a validation gate.

A failure should be diagnosed and corrected rather than bypassed without justification.

---

# 64. WORKFLOW TWO: RELEASE PUBLICATION

Create:

`.github/workflows/release.yaml`

Insert:

```yaml
name: Docker Release Publication

on:
  push:
    tags:
      - 'v*'


permissions:
  contents: read


concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false


jobs:

  verify:
    name: Verify Release Source and Tests

    runs-on: ubuntu-latest

    timeout-minutes: 20

    steps:

      - name: Check out tagged source
        uses: actions/checkout@v7

      - name: Validate release tag
        shell: bash
        run: |
          set -euo pipefail

          if [[ ! "$GITHUB_REF_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Release tags must use vMAJOR.MINOR.PATCH"
            exit 1
          fi

          echo "Release tag accepted: $GITHUB_REF_NAME"

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Build and execute test stage
        uses: docker/build-push-action@v7
        with:
          context: .
          target: test
          push: false
          cache-from: type=gha,scope=lecture20-release
          cache-to: type=gha,mode=max,scope=lecture20-release


  publish:
    name: Publish Approved Image

    needs: verify

    runs-on: ubuntu-latest

    timeout-minutes: 30

    permissions:
      contents: read

    steps:

      - name: Check out tagged source
        uses: actions/checkout@v7

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Log in to Docker Hub
        uses: docker/login-action@v4
        with:
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Generate image tags and labels
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ vars.DOCKERHUB_USERNAME }}/lecture20-api
          flavor: |
            latest=false
          tags: |
            type=semver,pattern={{version}}
            type=sha,format=long

      - name: Build and publish release image
        id: publish_image
        uses: docker/build-push-action@v7
        with:
          context: .
          file: ./Dockerfile
          target: runtime
          platforms: linux/amd64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            APP_VERSION=${{ steps.meta.outputs.version }}
            VCS_REF=${{ github.sha }}
          cache-from: type=gha,scope=lecture20-release
          cache-to: type=gha,mode=max,scope=lecture20-release
          sbom: true
          provenance: mode=max

      - name: Record published digest
        env:
          IMAGE_DIGEST: ${{ steps.publish_image.outputs.digest }}
          RELEASE_VERSION: ${{ steps.meta.outputs.version }}
        shell: bash
        run: |
          {
            echo "## Docker Release"
            echo ""
            echo "Version: $RELEASE_VERSION"
            echo ""
            echo "Digest: $IMAGE_DIGEST"
          } >> "$GITHUB_STEP_SUMMARY"
```

---

# 65. RELEASE WORKFLOW ANALYSIS

The release workflow executes when a Git tag beginning with `v` is pushed.

The workflow contains two jobs.

## Verify Job

The verify job:

1. Checks out the tagged source.
2. Verifies the release version format.
3. Configures Buildx.
4. Executes the Dockerfile test stage.

## Publish Job

The publish job:

1. Depends on verification.
2. Checks out the tagged source.
3. Configures Buildx.
4. Authenticates to Docker Hub.
5. Generates tags and labels.
6. Builds and publishes the runtime image.
7. Requests SBOM and provenance attestations.
8. Records the published image digest.

## Critical Security Boundary

The Docker Hub token is used only in the publication job.

The release must pass its required verification job before the publishing job proceeds under normal GitHub Actions dependency behavior.

---

# 66. RELEASE TAGGING STRATEGY

A Git tag:

```text
v1.0.0
```

generates a Docker image version tag:

```text
1.0.0
```

The workflow also generates a source-revision tag:

```text
sha-<full-commit-hash>
```

The exact tags are generated by Docker Metadata Action.

## Important Decision

The workflow deliberately does not publish an automatic `latest` tag.

This reduces ambiguity about which release should be selected.

---

# 67. RELEASE IMAGE METADATA

The image build receives:

```text
APP_VERSION=1.0.0
```

and an actual Git commit SHA as:

```text
VCS_REF=<commit-sha>
```

The running application exposes this information through:

```text
/api/info
```

## Benefit

An operator can compare the running application's reported metadata with the release record.

## Limitation

Application-reported version information is not sufficient by itself to prove artifact identity.

The image digest remains the stronger registry artifact reference.

---

# 68. SBOM AND PROVENANCE CONFIGURATION

The publication workflow uses:

```yaml
sbom: true
provenance: mode=max
```

These settings request additional build attestations.

## Important Conditions

The builder and registry must support the relevant attestation output.

An image loaded only into the conventional local Docker image store may not retain the same attestation representation as a registry-published image.

The laboratory uses direct registry publication for the release artifact.

---

# 69. DOCKER HUB CONFIGURATION

Before running the publication workflow, prepare Docker Hub.

## Required Repository

Create a repository named:

```text
lecture20-api
```

under a Docker Hub namespace for which you have permission.

## Required GitHub Variable

Create a GitHub Actions variable:

```text
DOCKERHUB_USERNAME
```

Its value must be the authorized Docker Hub namespace.

For the standard username-based laboratory, use the actual Docker Hub username.

## Required GitHub Secret

Create a GitHub Actions secret:

```text
DOCKERHUB_TOKEN
```

Its value must be an appropriate Docker Hub access token with the required publishing permission.

## Important Security Principle

Never place the actual token directly in the YAML workflow file.

---

# 70. REPOSITORY CONFIGURATION

The GitHub repository must contain the project source code and workflow files.

Its default branch is assumed to be:

```text
main
```

If the repository uses another default branch name, update the workflow branch filters accordingly.

The release workflow requires valid tag pushes.

Publication requires correctly configured Docker Hub credentials.

---

# 71. LOCAL DEPLOYMENT COMPOSE FILE

Create:

`compose.deploy.yaml`

Insert:

```yaml
name: lecture20-release-check

services:

  web:
    image: "${IMAGE_REF:?Set IMAGE_REF in deploy.env}"

    pull_policy: always

    ports:
      - "127.0.0.1:${WEB_PORT:-8290}:8000"

    user: "10001:10001"

    read_only: true

    tmpfs:
      - /tmp:size=16m

    cap_drop:
      - ALL

    security_opt:
      - no-new-privileges:true

    restart: unless-stopped

    stop_grace_period: 15s

    mem_limit: 256m

    cpus: 0.50

    pids_limit: 96

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s

    logging:
      driver: local
      options:
        max-size: "10m"
        max-file: "3"
```

---

# 72. DEPLOYMENT ENVIRONMENT TEMPLATE

Create:

`deploy.env.example`

Insert:

```text
IMAGE_REF=YOUR_DOCKER_ID/lecture20-api:1.0.0
WEB_PORT=8290
```

After publishing the release, copy the template to:

```text
deploy.env
```

Replace `YOUR_DOCKER_ID` with the correct Docker Hub namespace.

The file is intended for local demonstration.

It is excluded from the Git repository by `.gitignore`.

## Important Qualification

The deployment environment file uses non-sensitive values.

It should not be used as a general-purpose secrets store.

---

# 73. DEPLOYMENT ARCHITECTURE

```text
                GITHUB RELEASE TAG
                         |
                         v
                 GITHUB ACTIONS
                         |
                         v
                   DOCKER HUB
                         |
                         v
                 APPROVED IMAGE
                         |
                         v
                 DOCKER COMPOSE
                         |
                         v
                 RUNNING CONTAINER
                         |
                         v
                   HTTP CLIENT
```

The Compose file does not build the application.

It selects an image that has already been published.

This is an important transition from development-oriented Docker Compose to artifact-oriented deployment.

---

# 74. REPRODUCIBLE DEPLOYMENT REFERENCE

For stricter artifact selection, the value of `IMAGE_REF` may use a registry digest.

Example:

```text
IMAGE_REF=YOUR_DOCKER_ID/lecture20-api@sha256:ACTUAL_DIGEST
```

The placeholder must be replaced with the actual digest from the publication workflow.

## Benefit

A digest reference selects specific registry content.

## Important Qualification

Digest selection does not guarantee that the application is operationally compatible with its environment.

Health checks and deployment verification remain necessary.

---

# PART V — PRACTICAL LABORATORY 20

# 75. LABORATORY OVERVIEW

**Laboratory Title:** Automated Docker Image Testing and Release Publication with GitHub Actions.

**Principal Objective:** Implement a functioning CI/CD process that tests code and Docker images, publishes versioned releases, and deploys an approved image reference.

The laboratory consists of 30 experiments.

The initial experiments can be performed locally.

The GitHub and Docker Hub experiments require appropriately configured accounts and repository access.

No actual registry credentials will be included in these lecture notes.

---

# 76. EXPERIMENT 1 — VERIFY LOCAL DEVELOPMENT TOOLS

Execute:

```bash
docker version
```

```bash
docker buildx version
```

```bash
git --version
```

```bash
python --version
```

**Objective:** Verify the local development environment.

**Required observations:**

1. Docker version.
2. Buildx version.
3. Git version.
4. Python version.

Python 3.12 is the target version used in the project.

---

# 77. EXPERIMENT 2 — CREATE THE PROJECT DIRECTORY

For a Unix-like shell:

```bash
mkdir -p docker-lecture20/tests
mkdir -p docker-lecture20/.github/workflows
cd docker-lecture20
```

Create all files from Sections 54–72.

**Objective:** Establish the complete application and automation repository.

**Expected result:** The project contains the Dockerfile, tests, workflows, and deployment configuration.

---

# 78. EXPERIMENT 3 — RUN PYTHON TESTS LOCALLY

Execute:

```bash
python -m unittest discover -s tests -v
```

**Objective:** Verify application behavior before building an image.

**Expected result:** All defined tests pass.

**Required analysis:** Explain why local test execution is useful even when CI will run the same tests again.

---

# 79. EXPERIMENT 4 — VERIFY PYTHON SYNTAX

Execute:

```bash
python -m py_compile app.py
```

Then:

```bash
python -m py_compile tests/test_app.py
```

**Objective:** Verify basic Python syntax.

**Required analysis:** Explain why successful syntax verification does not guarantee correct application behavior.

---

# 80. EXPERIMENT 5 — BUILD THE DOCKER TEST STAGE

Execute:

```bash
docker build \
  --target test \
  -t lecture20:test \
  .
```

**Objective:** Execute the Python tests inside the Docker build environment.

**Expected result:** The Dockerfile test stage completes successfully.

**Required analysis:** Explain why this validates application behavior under the selected Python container environment.

---

# 81. EXPERIMENT 6 — BUILD THE RUNTIME IMAGE

Execute:

```bash
docker build \
  --target runtime \
  --build-arg APP_VERSION=local-test \
  --build-arg VCS_REF=local \
  -t lecture20:local \
  .
```

**Objective:** Construct the deployable runtime image.

**Expected result:** The image builds successfully.

**Required analysis:** Explain why the runtime image does not contain the test suite.

---

# 82. EXPERIMENT 7 — INSPECT THE RUNTIME IMAGE

Execute:

```bash
docker image inspect lecture20:local
```

**Objective:** Inspect the application image.

**Required observations:**

- Image ID.
- Runtime user.
- Exposed port.
- Command.
- Environment variables.
- Image size.

---

# 83. EXPERIMENT 8 — RUN THE LOCAL IMAGE

Execute:

```bash
docker run -d \
  --name lecture20-local \
  -p 127.0.0.1:8290:8000 \
  lecture20:local
```

Open:

http://127.0.0.1:8290

**Objective:** Verify runtime functionality.

**Expected result:** The lecture webpage is displayed.

---

# 84. EXPERIMENT 9 — TEST THE HEALTH ENDPOINT

Execute:

```bash
curl -i http://127.0.0.1:8290/healthz
```

**Expected result:**

HTTP 200 with:

```text
ok
```

**Objective:** Verify the application's basic health behavior.

---

# 85. EXPERIMENT 10 — TEST RELEASE METADATA

Execute:

```bash
curl http://127.0.0.1:8290/api/info
```

**Expected result:** JSON identifying the application, local version, and local revision.

**Required analysis:** Explain how build arguments became runtime application metadata.

---

# 86. EXPERIMENT 11 — REMOVE THE LOCAL TEST CONTAINER

Execute:

```bash
docker stop lecture20-local
```

Then:

```bash
docker rm lecture20-local
```

**Objective:** Remove the temporary runtime container without deleting the local Docker image.

---

# 87. EXPERIMENT 12 — INITIALIZE THE GIT REPOSITORY

Execute:

```bash
git init -b main
```

Add the project files:

```bash
git add .
```

Inspect:

```bash
git status
```

**Objective:** Create a source-controlled project.

**Required analysis:** Explain why `.gitignore` is important for excluding local deployment files and credentials.

---

# 88. EXPERIMENT 13 — COMMIT THE PROJECT

Configure a Git author identity if necessary.

Then execute:

```bash
git commit -m "Initial Docker CI/CD laboratory"
```

Inspect:

```bash
git log --oneline -1
```

**Objective:** Establish a traceable source revision.

**Required analysis:** Explain why source revision identity matters for image release engineering.

---

# 89. EXPERIMENT 14 — CREATE THE GITHUB REPOSITORY

Create a new GitHub repository named:

```text
docker-lecture20
```

Use your own GitHub account or authorized organization.

Avoid initializing the remote repository with conflicting starter files when following the exact Git commands below.

Connect the remote:

```bash
git remote add origin YOUR_GITHUB_REPOSITORY_URL
```

Push:

```bash
git push -u origin main
```

**Objective:** Publish the project source and workflow configuration to GitHub.

**Important Requirement:** Replace the placeholder with the actual repository URL.

---

# 90. EXPERIMENT 15 — INSPECT THE CI WORKFLOW

Open the repository's GitHub Actions interface.

Locate:

```text
Docker Continuous Integration
```

Inspect its configuration.

**Objective:** Verify that GitHub recognizes the workflow.

**Required observations:**

1. Workflow name.
2. Trigger event.
3. Job name.
4. Runner platform.
5. Completed steps.
6. Pass or failure status.

---

# 91. EXPERIMENT 16 — VERIFY AUTOMATED TEST EXECUTION

Inspect the CI workflow run.

Locate the Python test step:

```text
Run unit and HTTP tests
```

**Objective:** Confirm that tests execute on the GitHub-hosted runner.

**Expected result:** All application tests pass.

**Required analysis:** Explain why successful local tests alone do not prove that the GitHub workflow is configured correctly.

---

# 92. EXPERIMENT 17 — VERIFY THE DOCKER BUILD STAGE

Inspect the step:

```text
Validate Docker test stage
```

**Objective:** Confirm Buildx executes the Dockerfile test stage.

**Expected result:** The step completes successfully.

**Required analysis:** Explain the role of BuildKit in the pipeline.

---

# 93. EXPERIMENT 18 — VERIFY THE CONTAINER SMOKE TEST

Inspect:

```text
Smoke test application container
```

**Objective:** Confirm that the image starts as a running HTTP service.

**Expected result:** The workflow successfully retrieves the health endpoint and release-information API.

**Required analysis:** Explain how this test differs from Python unit testing.

---

# 94. EXPERIMENT 19 — CREATE A CONTROLLED FAILING TEST

Temporarily modify one test assertion so that it expects an incorrect result.

For example, change:

```python
self.assertEqual(
    result["application"],
    "lecture20-api",
)
```

to:

```python
self.assertEqual(
    result["application"],
    "incorrect-value",
)
```

Commit the change to a temporary feature branch and open a pull request.

**Objective:** Demonstrate a CI quality gate.

**Expected result:** The CI workflow reports failure.

**Required analysis:** Explain why a failing test should prevent treating the change as validated.

---

# 95. EXPERIMENT 20 — REPAIR THE TEST

Restore the correct assertion.

Commit and push the correction.

Inspect the updated pull-request checks.

**Objective:** Verify that the pipeline recovers after correcting the source defect.

**Expected result:** The CI workflow passes.

**Required analysis:** Explain why the earlier failed run remains useful as a diagnostic record.

---

# 96. EXPERIMENT 21 — MERGE THE APPROVED CHANGE

After confirming that the relevant checks pass, merge the pull request into main according to the repository's review policy.

**Objective:** Demonstrate controlled source integration.

**Expected result:** A push to main triggers the CI workflow.

**Required analysis:** Explain the difference between a successful pull-request workflow and the subsequent main-branch workflow.

---

# 97. EXPERIMENT 22 — CONFIGURE DOCKER HUB

Create or identify the authorized Docker Hub repository:

```text
lecture20-api
```

Create an access token with the minimum required publishing permission.

In GitHub, configure:

```text
Variable: DOCKERHUB_USERNAME
Secret:   DOCKERHUB_TOKEN
```

**Objective:** Establish secure registry publication configuration.

**Important Requirement:** Do not paste the token into source code or workflow YAML.

---

# 98. EXPERIMENT 23 — CREATE THE FIRST RELEASE TAG

Ensure the intended release commit has been merged and verified.

Execute:

```bash
git switch main
```

Update local main:

```bash
git pull --ff-only origin main
```

Create an annotated release tag:

```bash
git tag -a v1.0.0 -m "Docker Lecture 20 release 1.0.0"
```

Push the tag:

```bash
git push origin v1.0.0
```

**Objective:** Trigger the release publication workflow.

**Expected result:** GitHub Actions starts the Docker Release Publication workflow.

---

# 99. EXPERIMENT 24 — VERIFY THE RELEASE GATE

Inspect the release workflow's verify job.

Confirm that:

1. The release tag was accepted.
2. The Dockerfile test stage completed successfully.
3. The publish job depended on verification.

**Objective:** Demonstrate a release quality gate.

**Required analysis:** Explain why the release workflow performs validation even though the main branch was already tested.

---

# 100. EXPERIMENT 25 — VERIFY DOCKER HUB PUBLICATION

Inspect the publish job.

Confirm that:

- Authentication succeeded.
- Docker Metadata Action generated tags.
- Docker Build Push Action published the image.
- A digest was recorded.

Inspect the Docker Hub repository.

**Objective:** Verify actual image publication.

**Expected result:** An image version such as:

```text
YOUR_DOCKER_ID/lecture20-api:1.0.0
```

appears in the authorized repository.

---

# 101. EXPERIMENT 26 — INSPECT THE IMAGE DIGEST

In the GitHub Actions release run, examine the published digest recorded in the job summary.

On a suitable Docker environment, inspect:

```bash
docker buildx imagetools inspect \
  YOUR_DOCKER_ID/lecture20-api:1.0.0
```

**Objective:** Identify the exact published registry artifact.

**Required analysis:** Distinguish the image's version tag from the digest of the published manifest or image index.

---

# 102. EXPERIMENT 27 — DEPLOY THE RELEASED IMAGE

Copy:

```text
deploy.env.example
```

to:

```text
deploy.env
```

Set:

```text
IMAGE_REF=YOUR_DOCKER_ID/lecture20-api:1.0.0
WEB_PORT=8290
```

If the repository is private, authenticate with Docker Hub using an authorized local credential.

Execute:

```bash
docker compose \
  --env-file deploy.env \
  -f compose.deploy.yaml \
  config -q
```

Deploy:

```bash
docker compose \
  --env-file deploy.env \
  -f compose.deploy.yaml \
  up -d
```

**Objective:** Deploy an image that was previously published by the release workflow.

---

# 103. EXPERIMENT 28 — VERIFY THE DEPLOYED RELEASE

Inspect:

```bash
docker compose \
  --env-file deploy.env \
  -f compose.deploy.yaml \
  ps
```

Retrieve:

```bash
curl http://127.0.0.1:8290/api/info
```

**Expected result:** The application reports the published release metadata.

**Objective:** Confirm that the released image functions in the deployment environment.

**Required analysis:** Explain why this is a deployment verification step rather than another image build.

---

# 104. EXPERIMENT 29 — DEPLOY BY EXACT DIGEST

Replace the deployment image reference with the actual published digest:

```text
IMAGE_REF=YOUR_DOCKER_ID/lecture20-api@sha256:ACTUAL_DIGEST
```

Use the actual digest produced by the release workflow.

Apply:

```bash
docker compose \
  --env-file deploy.env \
  -f compose.deploy.yaml \
  up -d
```

**Objective:** Demonstrate exact artifact selection.

**Required analysis:** Explain why a digest provides stronger artifact identity than a mutable tag.

---

# 105. EXPERIMENT 30 — FINAL PIPELINE REVIEW AND CLEANUP

Inspect the complete delivery process:

1. Git source revision.
2. Pull-request validation.
3. Main-branch validation.
4. Release tag.
5. Release verification.
6. Registry publication.
7. Published digest.
8. Deployment verification.

Remove the local deployment:

```bash
docker compose \
  --env-file deploy.env \
  -f compose.deploy.yaml \
  down
```

The published Docker Hub image remains available unless deliberately removed through authorized repository management.

**Objective:** Conclude the laboratory with a complete release trace.

---

# PART VI — ADVANCED CI/CD ENGINEERING

# 106. DEPLOYMENT ENVIRONMENTS

A software organization may use several environments.

```text
                 DEVELOPMENT
                      |
                      v
                    TEST
                      |
                      v
                   STAGING
                      |
                      v
                  PRODUCTION
```

Each environment may differ in:

- Secrets.
- Networking.
- Data.
- Resource capacity.
- TLS configuration.
- Access controls.
- Availability architecture.

However, the approved application image should ideally remain traceable to the same tested artifact.

---

# 107. ENVIRONMENT PROTECTION RULES

GitHub supports deployment environments with selected protection controls.

Depending on repository and plan capabilities, these may include:

- Required reviewers.
- Deployment branch or tag restrictions.
- Environment-specific secrets.
- Waiting periods.

## Engineering Benefit

A workflow can separate automated verification from a controlled deployment approval.

## Important Qualification

The publication workflow in this laboratory does not automatically deploy to production.

Adding a production deployment job would require appropriate environment configuration and access controls.

---

# 108. OPENID CONNECT

OpenID Connect, abbreviated OIDC, provides a method for federated identity.

In supported cloud and registry environments, GitHub Actions can exchange an appropriate workload identity assertion for short-lived access.

This can reduce dependence on long-lived stored credentials.

## Security Benefit

Credentials can be scoped according to repository, branch, environment, and other trust conditions.

## Important Qualification

OIDC requires explicit configuration on the destination provider.

Adding:

```yaml
permissions:
  id-token: write
```

does not automatically establish a trusted cloud identity or registry connection.

The appropriate federation relationship must also exist.

---

# 109. REGISTRY AUTHENTICATION OPTIONS

Docker Hub supports conventional token-based authentication.

Some eligible Docker Hub organization configurations also support OIDC-based authentication.

The introductory project uses a Docker Hub access token because it is simpler to demonstrate.

In more advanced environments, short-lived identity federation may reduce credential lifecycle risks.

---

# 110. PINNING GITHUB ACTIONS

A workflow may reference an action using a major version:

```yaml
uses: actions/checkout@v7
```

This is convenient but can resolve to updated action implementation content.

A more controlled approach uses a reviewed full commit SHA.

Conceptually:

```yaml
uses: actions/checkout@FULL_COMMIT_SHA
```

## Security Importance

Pinning helps control third-party action code changes.

## Maintenance Tradeoff

Pinned actions require deliberate updates to receive fixes and new features.

---

# 111. DEPENDENCY SECURITY

CI/CD pipelines execute software from several sources.

These may include:

- Repository source code.
- Python packages.
- Docker base images.
- GitHub Actions.
- Build tools.
- External scripts.

Each source represents a potential supply-chain dependency.

## Recommended Practices

1. Review third-party actions.
2. Pin dependencies appropriately.
3. Protect credentials.
4. Avoid unnecessary downloads.
5. Scan relevant artifacts.
6. Maintain update procedures.

---

# 112. AUTOMATED VULNERABILITY SCANNING

A CI/CD pipeline may integrate vulnerability analysis.

For Docker images, this can be done through supported image scanning tools.

Possible approaches include:

- Docker Scout.
- Trivy.
- Other approved organizational scanners.

## Important Qualification

Tool capabilities and authentication requirements vary.

The complete reproducible publishing workflow provided earlier does not make a vulnerability scan a mandatory gate, because no scanning policy, service entitlement, or threshold has been configured.

A production pipeline should establish explicit vulnerability handling requirements rather than simply adding an unverified scanning command.

---

# 113. VULNERABILITY GATES

A vulnerability gate may fail a build when findings exceed defined acceptance criteria.

However, organizations should account for:

- Severity.
- Known exploitation.
- Reachability.
- Available patches.
- Business criticality.
- False positives.
- Accepted exceptions.

## Important Principle

A scan with many results is not automatically less secure than a scan with fewer results unless the findings and exposure contexts are evaluated.

---

# 114. BUILD REPRODUCIBILITY

A CI/CD pipeline can improve consistency.

However, identical source commits do not always produce byte-identical image content.

Factors include:

- Mutable base image tags.
- Toolchain updates.
- Build timestamps.
- External dependencies.
- Platform differences.
- Build metadata.
- Dependency resolution.

For stricter reproducibility, organizations may use pinned base-image digests and locked dependency sets.

---

# 115. RELEASE PROMOTION

A release can be built once and promoted through environments.

```text
VERIFIED IMAGE → DIGEST
DIGEST → STAGING
DIGEST → PRODUCTION
```

The environments can use distinct runtime configuration while selecting the same image digest.

This reduces the risk of differences introduced by environment-specific rebuilding.

---

# 116. ROLLBACK

Rollback returns a deployment to a previous approved version.

For example:

```text
Current release: 1.0.1

Previous release: 1.0.0
```

A deployment configuration may be changed to select the previous image digest.

## Important Limitation

Application image rollback does not automatically reverse:

- Database schema changes.
- Persistent data modifications.
- External service state.
- Credential rotation.
- Infrastructure changes.

Rollback requires an appropriate compatibility and recovery plan.

---

# 117. WORKFLOW CONCURRENCY

GitHub Actions supports concurrency controls.

Example:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

## Purpose

This can cancel superseded CI runs when newer changes arrive for the same logical workflow reference.

## Release Consideration

Release publication workflows may use:

```yaml
cancel-in-progress: false
```

to avoid deliberately cancelling an earlier ongoing release run.

## Important Qualification

Concurrency configuration does not replace a complete deployment serialization or release approval strategy.

---

# 118. PIPELINE OBSERVABILITY

CI/CD operations also require monitoring.

Useful information includes:

- Workflow run identifier.
- Triggering event.
- Source commit.
- Job status.
- Test output.
- Build duration.
- Image reference.
- Published digest.
- Failure category.

These records support investigation when an automation step fails.

---

# PART VII — TROUBLESHOOTING CI/CD

# 119. GITHUB WORKFLOW DOES NOT RUN

Possible causes include:

- Workflow path is incorrect.
- YAML syntax is invalid.
- Trigger event does not match.
- Branch filter does not match.
- Tag filter does not match.
- GitHub Actions is disabled.
- Repository policy prevents execution.

## Investigation

Inspect:

```text
.github/workflows/
```

Verify the workflow event and branch configuration.

Check repository Actions settings and workflow run history.

---

# 120. PYTHON TEST FAILURE

A test job may fail because:

- An assertion is incorrect.
- Application behavior changed.
- Python syntax is invalid.
- Required files are missing.
- Test environment differs.
- A network-dependent test is unstable.

## Investigation

Read the failed test output.

Identify the specific assertion or exception.

Correct the underlying issue.

Do not remove meaningful tests merely to make the workflow report success.

---

# 121. DOCKER BUILD FAILURE

Possible causes include:

- Incorrect Dockerfile path.
- Incorrect build context.
- Missing source file.
- Invalid Dockerfile instruction.
- Test-stage failure.
- Base image retrieval failure.
- BuildKit configuration problem.

## Investigation

Inspect the Docker Buildx output.

Determine which build stage failed.

Distinguish dependency retrieval failures from compilation and test failures.

---

# 122. CONTAINER SMOKE TEST FAILURE

Possible causes include:

- Application process terminated.
- Wrong listening port.
- Port binding conflict.
- HTTP endpoint unavailable.
- Incorrect entrypoint.
- Slow startup.
- Missing runtime resource.

## Investigation

Inspect container logs.

Verify the listening endpoint.

Examine the Dockerfile command.

Do not simply increase the waiting period without identifying the cause.

---

# 123. DOCKER HUB AUTHENTICATION FAILURE

Possible causes include:

- Missing GitHub secret.
- Invalid access token.
- Incorrect username.
- Token expiration.
- Token revocation.
- Incorrect repository permissions.

## Investigation

Verify:

```text
DOCKERHUB_USERNAME
```

and:

```text
DOCKERHUB_TOKEN
```

exist in the intended GitHub scope.

Do not print the secret value into workflow logs.

---

# 124. DOCKER HUB PUSH DENIED

A successful registry login does not guarantee authorization to publish to every repository.

Possible causes include:

- Wrong namespace.
- Missing write permission.
- Incorrect repository name.
- Organization policy.
- Repository settings.

## Corrective Principle

Verify authorization and repository identity before changing the application build.

---

# 125. RELEASE WORKFLOW DOES NOT TRIGGER

Possible causes include:

- Tag was created locally but not pushed.
- Tag name does not match the workflow filter.
- Workflow file was not available in the tagged source revision.
- Repository policy prevents execution.
- GitHub Actions is disabled or restricted.

## Investigation

Inspect:

```bash
git tag --list
```

and:

```bash
git ls-remote --tags origin
```

Confirm that the intended tag exists on the remote.

---

# 126. INVALID RELEASE TAG

The workflow validates:

```text
vMAJOR.MINOR.PATCH
```

Examples accepted by the laboratory include:

```text
v1.0.0
v2.3.4
```

Examples rejected include:

```text
release-1
v1.0
v1.0.0-beta
```

The laboratory intentionally uses a restricted version format.

It does not implement every valid Semantic Versioning feature, such as prerelease and build metadata identifiers.

---

# 127. IMAGE WAS PUBLISHED BUT IS NOT RUNNING

A successful `docker push` only publishes the image.

It does not update the application deployment.

## Investigation

Inspect:

1. Published image tag.
2. Registry digest.
3. Deployment configuration.
4. Running image reference.
5. Container health.

## Corrective Principle

Distinguish successful release publication from successful deployment.

---

# 128. CACHE ERRORS

Build cache failures may result from:

- Cache access restrictions.
- Expired cache data.
- Cache eviction.
- Outdated BuildKit tools.
- GitHub cache service limits.
- Incorrect cache scope.
- Unsupported cache driver configuration.

## Corrective Principle

A correct build should not require pre-existing cache content.

Cache misses may make a build slower without making the artifact invalid.

---

# 129. ATTESTATION FAILURES

Potential causes include:

- Unsupported registry behavior.
- Incorrect build exporter.
- Outdated tooling.
- Missing metadata permissions.
- Invalid attestation configuration.

## Important Distinction

Loading an image into the local Docker image store and publishing an OCI image with attestations can involve different output capabilities.

The laboratory publication workflow uses registry output.

---

# PART VIII — ACADEMIC SECURITY ANALYSIS

# 130. CI/CD THREAT MODEL

A CI/CD system may contain:

- Source code.
- Build scripts.
- Third-party actions.
- Package dependencies.
- Registry credentials.
- Deployment credentials.
- Build caches.
- Release artifacts.

Potential risks include:

1. Malicious source contributions.
2. Dependency compromise.
3. Secret exposure.
4. Unauthorized registry publication.
5. Compromised runner environments.
6. Mutable action references.
7. Incorrect image tagging.
8. Artifact substitution.
9. Insecure deployment permissions.
10. Unreviewed workflow changes.

The pipeline must protect both its build output and the systems it can access.

---

# 131. TRUST BOUNDARIES

The principal trust boundaries in the laboratory are:

```text
                UNTRUSTED PR CODE
                        |
                        v
                   CI VALIDATION
                        |
              NO REGISTRY SECRET
                        |
                        v
                  REVIEW PROCESS
                        |
                        v
                 APPROVED SOURCE
                        |
                        v
                 RELEASE WORKFLOW
                        |
                   TEST GATE
                        |
                        v
                  PUBLISH JOB
                        |
                 REGISTRY TOKEN
                        |
                        v
                    DOCKER HUB
```

The most important boundary separates untrusted contribution testing from privileged publication.

---

# 132. PRINCIPLE OF LEAST PRIVILEGE IN CI/CD

Least privilege applies to automation as well as running containers.

Examples:

- CI jobs need repository read access.
- Release jobs need registry publishing authority.
- Deployment jobs need only the relevant deployment permissions.
- Untrusted pull-request tests should not receive production credentials.

Avoid granting broad write permissions to every job.

---

# 133. SECRET HANDLING RULES

A secure pipeline should:

1. Store credentials in appropriate secret storage.
2. Avoid hardcoding tokens.
3. Avoid passing secrets as build arguments.
4. Avoid printing credentials.
5. Use minimum necessary permissions.
6. Limit credential exposure to relevant jobs.
7. Rotate compromised credentials.
8. Prefer short-lived credentials when appropriate.

GitHub's log masking features provide useful protection but should not be treated as a guarantee against every accidental disclosure.

---

# 134. SOURCE AND RELEASE APPROVAL

A release tag should identify source that has been appropriately reviewed and validated.

Organizations may use:

- Protected branches.
- Pull-request reviews.
- Required status checks.
- Tag protection or repository rulesets.
- Protected deployment environments.

## Important Qualification

The example tag-triggered release workflow does not independently prove that the tag points to a reviewed main-branch commit.

That requirement must be enforced through repository policy and release procedures.

---

# PART IX — FORMAL ACADEMIC ASSESSMENT

# 135. TECHNICAL DEFINITIONS

Define precisely:

1. Continuous Integration.
2. Continuous Delivery.
3. Continuous Deployment.
4. CI/CD pipeline.
5. Quality gate.
6. GitHub Actions workflow.
7. Event.
8. Job.
9. Step.
10. Action.
11. Runner.
12. GitHub-hosted runner.
13. Self-hosted runner.
14. Repository secret.
15. GitHub Actions variable.
16. GitHub token.
17. Docker Hub access token.
18. Build cache.
19. Software Bill of Materials.
20. Build provenance.
21. Image digest.
22. Release tag.
23. Artifact promotion.
24. Deployment rollback.
25. OpenID Connect.

---

# 136. SHORT-ANSWER QUESTIONS

**Question 1.**

Distinguish Continuous Integration from Continuous Delivery.

**Question 2.**

Explain the difference between Continuous Delivery and Continuous Deployment.

**Question 3.**

Describe why source control is fundamental to CI/CD.

**Question 4.**

Explain the relationship between Git commits and Docker image digests.

**Question 5.**

Describe the purpose of GitHub Actions workflows.

**Question 6.**

Distinguish jobs from steps.

**Question 7.**

Explain why tests should execute before image publication.

**Question 8.**

Describe the role of Docker Buildx in GitHub Actions.

**Question 9.**

Explain why registry credentials should not be available to untrusted pull-request workflows.

**Question 10.**

Describe the purpose of Docker Metadata Action.

**Question 11.**

Explain why Semantic Versioning tags are useful.

**Question 12.**

Describe the difference between image publication and deployment.

**Question 13.**

Explain why the published image digest should be recorded.

**Question 14.**

Describe the purpose of SBOM and provenance attestations.

**Question 15.**

Explain the limitations of application-only rollback.

---

# 137. WORKFLOW INTERPRETATION

Consider:

```yaml
on:
  pull_request:
    branches:
      - main
```

Answer:

1. Which event triggers the workflow?
2. Why is it suitable for CI?
3. Why should the workflow avoid publishing credentials?

Consider:

```yaml
permissions:
  contents: read
```

Answer:

4. What permission is requested?
5. Why is it a useful default for validation?

Consider:

```yaml
needs: verify
```

Answer:

6. Which job relationship is expressed?
7. Why is it useful before registry publication?

Consider:

```yaml
push: true
```

Answer:

8. What does this request from Docker Build Push Action?
9. Which additional configuration is necessary?

Consider:

```yaml
provenance: mode=max
sbom: true
```

Answer:

10. Which artifact metadata is requested?
11. Why must sensitive values be excluded from ordinary build arguments?

---

# 138. ANALYTICAL CASE STUDIES

## Case Study 1 — Failed Pull Request

A developer submits a pull request containing a failing test.

Explain how CI should report the result.

Describe why the code should not be treated as validated.

## Case Study 2 — Exposed Registry Credential

A workflow stores the Docker Hub token directly inside YAML.

Explain the security risks.

Recommend a correction.

## Case Study 3 — Untrusted Pull Request

A workflow uses a privileged event and executes source code from an untrusted fork.

Explain the potential consequences.

Recommend a safer workflow design.

## Case Study 4 — Wrong Release Tag

A developer creates a tag with an invalid version format.

Explain how the release workflow should respond.

## Case Study 5 — Publication Without Deployment

A Docker image appears successfully on Docker Hub.

The running application still uses the previous version.

Explain why this is not necessarily an automation failure.

## Case Study 6 — Digest Mismatch

A deployment uses the same human-readable tag as an earlier deployment, but the registry content has changed.

Explain why the resulting artifact may differ.

Recommend a digest-based release policy.

---

# 139. PRACTICAL EXAMINATION

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| CI/CD theory | 15 |
| Python application and automated tests | 15 |
| Multi-stage Docker image | 15 |
| GitHub Actions CI workflow | 15 |
| Release verification workflow | 10 |
| Docker Hub publication | 15 |
| Deployment verification and digest tracking | 10 |
| Documentation and security analysis | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student should demonstrate both successful automation and accurate understanding of the security boundaries between testing, publication, and deployment.

---

# 140. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Automated Docker Image Release Engineering with GitHub Actions

Prepare a technical report of approximately 1,600–2,200 words addressing:

**“Continuous Integration and Continuous Delivery for Containerized Applications: GitHub Actions, Docker BuildKit, Automated Testing, Registry Publication, and Secure Software Release Management.”**

The report must include:

1. Introduction to CI/CD.
2. Continuous Integration.
3. Continuous Delivery.
4. Continuous Deployment.
5. Pipeline architecture.
6. Source control integration.
7. GitHub Actions architecture.
8. Workflow events.
9. Jobs and steps.
10. Automated Python tests.
11. Multi-stage Docker builds.
12. Buildx.
13. External build cache.
14. Pull-request security.
15. GitHub secrets and variables.
16. Docker Hub authentication.
17. Image tagging.
18. Release verification.
19. Registry publication.
20. SBOM and provenance.
21. Image digests.
22. Deployment configuration.
23. Rollback.
24. CI/CD troubleshooting.
25. Technical conclusion.

Required report evidence:

- A CI/CD architecture diagram.
- The completed workflow files.
- Test results.
- Build results.
- A published release tag.
- The actual registry digest.
- Deployment verification.
- A short security assessment.

---

# 141. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 21, verify the following.

## CI/CD Fundamentals

- [ ] I can define Continuous Integration.
- [ ] I can define Continuous Delivery.
- [ ] I can define Continuous Deployment.
- [ ] I can explain a quality gate.
- [ ] I understand pipeline dependencies.
- [ ] I understand source revision tracking.

## GitHub Actions

- [ ] I can create a workflow file.
- [ ] I understand workflow events.
- [ ] I can configure pull-request triggers.
- [ ] I can configure push triggers.
- [ ] I can configure tag triggers.
- [ ] I understand manual workflow dispatch.
- [ ] I can define jobs and steps.
- [ ] I can configure job dependencies.
- [ ] I can inspect workflow results.

## Security

- [ ] I understand least-privilege workflow permissions.
- [ ] I can distinguish secrets from variables.
- [ ] I understand the GitHub token.
- [ ] I understand Docker Hub token authentication.
- [ ] I know why untrusted pull requests must not receive privileged secrets.
- [ ] I can explain the dangers of pull_request_target misuse.
- [ ] I understand action pinning.
- [ ] I understand OIDC at a conceptual level.

## Docker Automation

- [ ] I can build an image in CI.
- [ ] I can construct a Docker test stage.
- [ ] I can use Buildx.
- [ ] I can configure build caching.
- [ ] I can perform a container smoke test.
- [ ] I can generate image tags.
- [ ] I can publish an image.
- [ ] I can inspect a registry digest.

## Release Engineering

- [ ] I understand Semantic Versioning.
- [ ] I can create a Git release tag.
- [ ] I can trigger a release workflow.
- [ ] I understand release verification gates.
- [ ] I can explain provenance.
- [ ] I can explain SBOMs.
- [ ] I can deploy a published image.
- [ ] I can select an image by digest.
- [ ] I understand rollback limitations.

## Practical Laboratory

- [ ] I created the Python application.
- [ ] I created automated tests.
- [ ] I ran tests locally.
- [ ] I built the Docker test stage.
- [ ] I built the runtime image.
- [ ] I tested the local container.
- [ ] I initialized the Git repository.
- [ ] I created a GitHub repository.
- [ ] I pushed the source code.
- [ ] I verified the CI workflow.
- [ ] I observed a deliberate test failure.
- [ ] I repaired the test.
- [ ] I merged an approved change.
- [ ] I configured Docker Hub authentication.
- [ ] I created a release tag.
- [ ] I verified release tests.
- [ ] I verified registry publication.
- [ ] I recorded the actual image digest.
- [ ] I deployed the released image.
- [ ] I verified application metadata.
- [ ] I tested a digest-based reference.
- [ ] I completed the examination.
- [ ] I prepared the academic report.

**Completion standard:** The student should be able to construct, validate, publish, and verify a versioned Docker image using a structured GitHub Actions workflow while maintaining appropriate security boundaries between untrusted code validation and authorized software release operations.

---

# 142. LECTURE SUMMARY

Lecture 20 introduces automated software delivery as a core component of container engineering.

Continuous Integration validates frequent code changes through repeatable tests and build procedures.

Continuous Delivery prepares verified software artifacts for release.

Continuous Deployment extends automation into the running environment when appropriate authorization and operational controls exist.

GitHub Actions provides a workflow system integrated with source control.

Workflows are triggered by events.

Jobs execute on runners.

Steps run commands or reusable actions.

Dependency relationships determine which jobs must succeed before later work begins.

Docker integrates naturally with this model.

A CI workflow can test Python source, execute Docker build stages, construct runtime images, and verify HTTP functionality through smoke tests.

A separate release workflow can validate a versioned Git tag, authenticate to Docker Hub, generate semantic image tags, and publish an approved image.

BuildKit supports efficient image construction and caching.

Docker Metadata Action provides consistent tags and labels.

Build Push Action publishes the resulting image artifact.

SBOM and provenance attestations provide additional software supply-chain information.

Digest-based references permit precise selection of published image content.

The practical laboratory combines these capabilities into a complete project.

It also illustrates the distinction between publication and deployment.

A Docker image can be successfully published without changing any running application.

A deployment process must separately select the approved image and verify that the resulting service is operating correctly.

**The central principle of this lecture is that reliable CI/CD must combine repeatable automation, explicit validation gates, controlled publication credentials, immutable artifact identification, and independent deployment verification.**

---

# 143. REFERENCES AND RECOMMENDED READING

## GitHub Actions Fundamentals

[1] GitHub. *GitHub Actions Documentation.*  
https://docs.github.com/en/actions

[2] GitHub. *Workflow Syntax for GitHub Actions.*  
https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax

[3] GitHub. *Events That Trigger Workflows.*  
https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows

[4] GitHub. *Using Secrets in GitHub Actions.*  
https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets

[5] GitHub. *Secure Use of GitHub Actions.*  
https://docs.github.com/en/actions/reference/security/secure-use

[6] GitHub. *Securely Using pull_request_target.*  
https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target

## Docker and GitHub Actions

[7] Docker Inc. *Docker Build GitHub Actions.*  
https://docs.docker.com/build/ci/github-actions/

[8] Docker Inc. *Manage Cache with GitHub Actions.*  
https://docs.docker.com/build/ci/github-actions/cache/

[9] Docker Inc. *GitHub Actions Cache Backend.*  
https://docs.docker.com/build/cache/backends/gha/

[10] Docker Inc. *SBOM and Provenance Attestations with GitHub Actions.*  
https://docs.docker.com/build/ci/github-actions/attestations/

## Official Actions

[11] GitHub. *actions/checkout.*  
https://github.com/actions/checkout

[12] GitHub. *actions/setup-python.*  
https://github.com/actions/setup-python

[13] Docker. *docker/setup-buildx-action.*  
https://github.com/docker/setup-buildx-action

[14] Docker. *docker/login-action.*  
https://github.com/docker/login-action

[15] Docker. *docker/metadata-action.*  
https://github.com/docker/metadata-action

[16] Docker. *docker/build-push-action.*  
https://github.com/docker/build-push-action

## Registry Publication and Deployment

[17] GitHub. *Publishing Docker Images.*  
https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images

[18] Docker Inc. *Docker Hub Documentation.*  
https://docs.docker.com/docker-hub/

[19] Docker Inc. *Docker Image Push.*  
https://docs.docker.com/reference/cli/docker/image/push/

[20] Docker Inc. *Buildx Imagetools Inspect.*  
https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/

[21] Docker Inc. *Docker Compose Documentation.*  
https://docs.docker.com/compose/

## Software Engineering and Release Management

[22] Semantic Versioning. *Semantic Versioning Specification.*  
https://semver.org/

[23] Open Container Initiative. *Image Specification.*  
https://github.com/opencontainers/image-spec

[24] OpenTelemetry. *Observability Documentation.*  
https://opentelemetry.io/docs/

## Recommended Reading Sequence

Begin with references [1] through [6] to understand GitHub Actions architecture, triggers, and security.

Continue with references [7] through [10] to examine Docker build automation, caching, SBOMs, and provenance.

Study references [11] through [16] to understand the reusable GitHub and Docker Actions used in the laboratory.

References [17] through [21] explain registry publication and deployment.

Finally, review references [22] through [24] to connect image versioning with wider release engineering and observability practices.

---

# 144. FINAL LECTURE CONCLUSION

Continuous Integration and Continuous Delivery represent the transition from manually executed Docker operations to systematic software release engineering.

A production-oriented software process must provide confidence that source code was tested, the intended image was built, the release was authorized, and the correct artifact was published.

GitHub Actions provides a platform for implementing these activities through declarative workflows.

The student has now examined workflows, events, jobs, steps, runners, reusable actions, permissions, secrets, and dependency relationships.

The laboratory demonstrates how Python tests can be executed automatically, how Docker BuildKit can construct validated images, and how container smoke tests can verify runtime functionality.

It also demonstrates the separation between testing and publication.

Pull-request workflows validate potentially untrusted source code without requiring Docker Hub credentials.

A release-tag workflow performs verification before executing a separate publication job.

The publication job authenticates to Docker Hub using a configured access token, generates versioned image references, and pushes an image artifact.

The resulting image digest is recorded for traceability.

The application can then be retrieved and deployed independently of the build environment.

This approach establishes a reproducible relationship between source code, build execution, release metadata, registry artifacts, and running software.

However, automation alone does not guarantee safe deployment.

A complete production delivery process must also address protected source branches, trusted actions, dependency security, credentials, vulnerability assessment, rollback, data compatibility, and environment-specific operational requirements.

Those concerns become especially important in systems containing persistent databases and multiple application services.

Lecture 21 will integrate all three course modules into one comprehensive final project.

The final capstone will construct a PostgreSQL-backed task-management application with multiple Docker services, persistent data, a reverse proxy, appropriate runtime security, health checks, testing, CI/CD integration, backup and restoration, and a formal final examination.

---

**END OF LECTURE 20**

**Next Lecture:** Lecture 21 — Final Docker Capstone: Design, Build, Secure, Deploy, Test, and Automate a Complete PostgreSQL-Backed Multi-Container Task Management Application.

**Course Status:** Twenty of twenty-one lectures completed.
