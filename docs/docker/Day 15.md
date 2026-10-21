# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 15 — ADVANCED DOCKER IMAGE ENGINEERING: MULTI-STAGE BUILDS, BUILDKIT, CACHE OPTIMIZATION, IMAGE SIZE REDUCTION, AND REPRODUCIBLE BUILDS

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 15 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 5–7 hours  
**Lecture Type:** Formal Theory, Engineering Laboratory, Technical Assessment, and Independent Study

**Prerequisites:**

- Lecture 01 — Docker Architecture and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Container Inspection.
- Lecture 04 — Image Layers and Registries.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Instructions.
- Lecture 07 — Week One Capstone.
- Lectures 08–14 — Networking, Storage, Compose, and Multi-Container Applications.

---

# 1. PURPOSE OF THE LECTURE

The construction of a container image is a software engineering process.

An image must contain the components required to execute an application while avoiding unnecessary build tools, temporary files, development dependencies, and unrelated resources.

During introductory Docker development, images are often created using a direct sequence of Dockerfile instructions.

For example, a development image may contain:

- Programming language compilers.
- Build tools.
- Package managers.
- Source code.
- Temporary build artifacts.
- Test dependencies.
- Debugging utilities.
- Runtime executables.

Such an image may function correctly.

However, it may contain significantly more software than the deployed application requires.

This increases image size and may introduce unnecessary deployment, maintenance, and security concerns.

Lecture 15 introduces advanced image construction techniques intended to address these problems.

The primary mechanisms are:

1. Multi-stage Dockerfiles.
2. BuildKit.
3. Efficient build caching.
4. Dependency-aware instruction ordering.
5. Build-context reduction.
6. Temporary build mounts.
7. External build cache.
8. Runtime artifact isolation.
9. Image inspection and measurement.
10. Reproducibility practices.
11. Build-stage testing.
12. Controlled image optimization.

The central goal is not simply to create the smallest possible image.

The goal is to construct an image that is appropriately sized, reliable, maintainable, verifiable, and suitable for its intended deployment environment.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Explain image construction as an engineering process.
2. Distinguish build-time dependencies from runtime dependencies.
3. Define image optimization and identify its principal objectives.
4. Explain the relationship between Dockerfile instructions and image layers.
5. Describe the purpose of Docker's build cache.
6. Explain cache invalidation.
7. Identify how Dockerfile instruction ordering influences rebuild performance.
8. Describe the role of the build context.
9. Construct an effective `.dockerignore` file.
10. Explain why deleting files in later layers may not reduce total image size.
11. Define a multi-stage build.
12. Describe how multiple `FROM` instructions create independent build stages.
13. Use meaningful stage names.
14. Explain `COPY --from`.
15. Identify which stage becomes the final image.
16. Use the `--target` build option.
17. Distinguish builder images from runtime images.
18. Explain the purpose of `FROM scratch`.
19. Evaluate the limitations of minimal runtime images.
20. Define BuildKit and describe its responsibilities.
21. Explain the role of Docker Buildx.
22. Distinguish the builder backend from the Buildx client.
23. Configure BuildKit cache mounts.
24. Explain temporary build bind mounts.
25. Distinguish cache mounts from final image layers.
26. Explain external build caches.
27. Distinguish `--cache-from` and `--cache-to`.
28. Explain the difference between minimum and maximum external cache export.
29. Explain why build-time secrets should not use Dockerfile `ARG` or `ENV`.
30. Describe the role of BuildKit secret mounts.
31. Distinguish image tags and immutable digest references.
32. Explain the principal limitations of reproducible image builds.
33. Apply non-root execution to a minimal runtime image.
34. Build a statically linked Go application.
35. Compare a single-stage image with a multi-stage image.
36. Measure image size using Docker inspection commands.
37. Test image functionality independently of image size.
38. Validate build stages and application tests.
39. Analyze cache reuse after source-code modification.
40. Evaluate production-image construction tradeoffs.

---

# PART I — THEORETICAL FOUNDATIONS

# 3. IMAGE ENGINEERING AS A SOFTWARE DISCIPLINE

## 3.1 Definition

Image engineering is the systematic design, construction, inspection, testing, optimization, and maintenance of container images.

A container image is a deployable software artifact.

It represents an application execution environment, not merely a collection of files.

## 3.2 Engineering Objectives

A well-engineered image should support:

- Correct application execution.
- Controlled dependencies.
- Reasonable image size.
- Efficient rebuilding.
- Predictable runtime behavior.
- Appropriate security controls.
- Reproducible deployment.
- Operational observability.
- Maintainable construction instructions.

## 3.3 Image Quality Is Multidimensional

An image may be small but difficult to debug.

An image may build quickly but use outdated dependencies.

An image may contain few packages but lack the certificates required for outbound TLS connections.

Therefore, image optimization must account for multiple requirements.

## 3.4 Quality Model

```text
                IMAGE QUALITY
                     |
       +-------------+-------------+
       |             |             |
       v             v             v
  CORRECTNESS     EFFICIENCY    SECURITY
       |             |             |
       +-------------+-------------+
                     |
                     v
                MAINTAINABILITY
                     |
                     v
               REPRODUCIBILITY
```

No single measurement completely describes image quality.

---

# 4. BUILD-TIME AND RUNTIME DEPENDENCIES

## 4.1 Build-Time Dependencies

Build-time dependencies are tools or libraries required to produce an application artifact.

Examples include:

- Go compiler.
- C compiler.
- Rust compiler.
- Java build tools.
- Node.js development tooling.
- Asset minifiers.
- Test frameworks.
- Code generators.

## 4.2 Runtime Dependencies

Runtime dependencies are components required while the compiled or packaged application executes.

Examples include:

- Language runtime.
- Shared system libraries.
- Configuration files.
- Trusted CA certificates.
- Application assets.
- Executable program files.

## 4.3 Example: Go Application

A Go application may require the Go toolchain to compile.

After compilation, a statically linked executable may run without the Go compiler.

This creates an opportunity to separate the build environment from the runtime environment.

## 4.4 Example: Frontend Application

A frontend project may require Node.js and npm to construct static HTML, CSS, and JavaScript assets.

The resulting static website may be served by Nginx without including the Node.js build toolchain in the final image.

## 4.5 Architectural Principle

**The build environment and the runtime environment should be treated as distinct engineering requirements.**

Multi-stage builds provide a Docker-native mechanism for implementing this separation.

---

# 5. REVIEW OF DOCKER IMAGE LAYERS

## 5.1 Layered Image Model

Docker images are assembled using filesystem layers and image configuration metadata.

Many Dockerfile instructions affect the filesystem state used to construct the image.

## 5.2 Simplified Representation

```text
               FINAL IMAGE
          +---------------------+
          | Application Files   |
          +---------------------+
          | Installed Packages  |
          +---------------------+
          | Base Image Content  |
          +---------------------+
```

The image exposes a unified filesystem when a container executes.

## 5.3 Important Qualification

Not every Dockerfile instruction creates a filesystem layer.

Instructions such as `CMD`, `ENTRYPOINT`, and `ENV` generally modify image configuration metadata.

The exact build representation depends on the builder and instruction behavior.

## 5.4 Layer Reuse

Image layers and build results may be shared or reused when identical build inputs produce reusable cached output.

This supports more efficient image construction.

---

# 6. WHY IMAGE SIZE MATTERS

## 6.1 Image Distribution

Container images must often be transferred from a registry to a deployment environment.

Larger images may require more network transfer and storage resources.

## 6.2 Deployment Performance

An image that is already available locally may start quickly regardless of its compressed registry size.

However, deployments requiring image downloads can be affected by the amount of data transferred.

## 6.3 Storage Requirements

Images consume storage within Docker's image and content management systems.

Multiple images may share layers, so their displayed sizes should not simply be added together to estimate unique physical storage consumption.

## 6.4 Maintenance

Unnecessary development tooling increases the number of components that must be reviewed and maintained.

## 6.5 Security Considerations

Reducing unnecessary software can reduce the number of potentially vulnerable components in a runtime image.

However, a smaller image is not automatically secure.

Security depends on package versions, application vulnerabilities, configuration, privileges, and many other factors.

---

# 7. THE PROBLEM OF SINGLE-STAGE BUILDS

## 7.1 Definition

A single-stage Dockerfile contains one principal build stage.

It commonly starts with one `FROM` instruction and constructs the complete image within that environment.

## 7.2 Example

```dockerfile
FROM golang:1.26-alpine

WORKDIR /app

COPY . .

RUN go build -o server .

CMD ["./server"]
```

This example builds and runs the application using the same environment.

## 7.3 Consequence

The final image inherits the Go toolchain and other contents of its base image.

The application may no longer need the compiler after the executable has been produced.

Nevertheless, the compiler remains in the final image.

## 7.4 Simplified Architecture

```text
            SINGLE-STAGE IMAGE
        +---------------------------+
        | Application Executable    |
        | Application Source        |
        | Go Compiler               |
        | Build Tools               |
        | Base Operating System     |
        +---------------------------+
```

## 7.5 Limitation

The runtime environment contains both construction tools and execution requirements.

This often results in a larger-than-necessary deployment artifact.

---

# 8. DELETING FILES DOES NOT NECESSARILY REDUCE IMAGE SIZE

## 8.1 Layer Persistence

Consider:

```dockerfile
FROM alpine:3.22

RUN dd if=/dev/zero of=/large-file bs=1M count=100

RUN rm /large-file
```

The example is conceptual and should not be executed merely to create unnecessary storage usage.

## 8.2 Interpretation

The first `RUN` creates a filesystem layer containing a large file.

The second `RUN` removes the file from the final visible filesystem.

However, the data introduced in the earlier layer can remain part of the image's layer content.

## 8.3 Whiteouts

Layered filesystems can represent file removal through metadata commonly described as whiteouts.

The final container filesystem no longer displays the deleted file.

The earlier layer content is not necessarily eliminated from the distributable image.

## 8.4 Engineering Consequence

Deleting build tools in a later Dockerfile instruction is not equivalent to preventing those tools from entering the final image layers.

Multi-stage builds provide a better separation.

---

# 9. INTRODUCTION TO MULTI-STAGE BUILDS

## 9.1 Definition

A multi-stage build is a Docker image construction process containing multiple stages, typically introduced through multiple `FROM` instructions.

Each stage has its own base image and filesystem environment.

Files can be selectively copied from one stage into another.

## 9.2 General Structure

```dockerfile
FROM builder-image AS build

# Install dependencies.
# Compile application.
# Produce output artifact.

FROM runtime-image AS runtime

COPY --from=build /output/application /application

CMD ["/application"]
```

## 9.3 Principal Benefit

The final image can contain the required application artifact without including the compiler and other intermediate build tools.

## 9.4 Architecture

```text
                SOURCE CODE
                     |
                     v
               BUILD STAGE
        +-------------------------+
        | Compiler                |
        | Build Tools             |
        | Source Code             |
        | Compiled Application    |
        +-------------------------+
                     |
                     | COPY --from
                     v
               RUNTIME STAGE
        +-------------------------+
        | Compiled Application    |
        | Required Runtime Files  |
        +-------------------------+
                     |
                     v
                 FINAL IMAGE
```

---

# 10. BUILD STAGES

## 10.1 Stage Creation

Every new `FROM` instruction begins a new build stage.

Example:

```dockerfile
FROM golang:1.26-alpine AS build

FROM scratch AS runtime
```

The first stage uses the Go toolchain.

The second stage starts from an empty base filesystem.

## 10.2 Stage Naming

The syntax:

```dockerfile
AS build
```

assigns a name to the stage.

## 10.3 Named Stages

Named stages are preferable to numerical references when a Dockerfile becomes complex.

For example:

```dockerfile
COPY --from=build /out/server /server
```

is generally clearer than:

```dockerfile
COPY --from=0 /out/server /server
```

## 10.4 Refactoring Benefit

A named stage reference remains meaningful even if other stages are inserted earlier in the Dockerfile.

---

# 11. THE COPY --from INSTRUCTION

## 11.1 Definition

`COPY --from` copies selected filesystem content from another build stage, image, or supported build source.

## 11.2 Syntax

```dockerfile
COPY --from=build /source/path /destination/path
```

## 11.3 Example

```dockerfile
COPY --from=build /out/server /server
```

The runtime stage receives the compiled executable.

## 11.4 Important Principle

The instruction does not automatically copy every filesystem layer from the source stage.

It copies the selected filesystem content.

## 11.5 Consequence

Build tools and other intermediate files remain outside the final runtime image unless they are explicitly included through the final stage's base or copy operations.

---

# 12. BUILDING A SPECIFIC STAGE

## 12.1 The --target Option

Docker supports building a particular stage.

Example:

```bash
docker build --target build -t application:build-env .
```

## 12.2 Purpose

This allows an administrator to inspect an intermediate stage or use it for development or testing.

## 12.3 Common Targets

A multi-stage Dockerfile may contain:

- `build`
- `test`
- `runtime`

## 12.4 Example

```bash
docker build --target test -t application:test .
```

The builder stops at the selected target stage.

## 12.5 Engineering Application

Build-stage targets are useful for:

- Automated tests.
- Diagnostic inspection.
- Intermediate artifact verification.
- Development tooling.
- Build pipeline separation.

---

# 13. THE SCRATCH BASE IMAGE

## 13.1 Definition

`scratch` is Docker's special empty base image.

Example:

```dockerfile
FROM scratch
```

It provides an empty filesystem starting point.

## 13.2 Purpose

The scratch base is useful when the application can execute without requiring a conventional userspace operating-system filesystem.

## 13.3 Common Example

A statically linked Go executable may run from scratch when it does not require additional external files.

## 13.4 Important Limitations

A scratch image ordinarily does not contain:

- Shell.
- Package manager.
- Standard command-line utilities.
- CA certificates.
- Timezone database files.
- User and group databases.

Such resources must be supplied when the application requires them.

## 13.5 Debugging Consequence

A command such as:

```bash
docker exec CONTAINER sh
```

will normally fail if the scratch image does not contain a shell.

This is expected.

## 13.6 Engineering Tradeoff

A minimal runtime image can reduce unnecessary software but may require different debugging procedures.

---

# 14. STATIC AND DYNAMIC LINKING

## 14.1 Static Linking

A statically linked executable incorporates the required compiled library components into the executable or otherwise avoids runtime dependence on separately installed shared libraries.

## 14.2 Dynamic Linking

A dynamically linked executable depends on compatible shared libraries being available at runtime.

## 14.3 Runtime Implications

A dynamically linked application placed into scratch may fail because required shared libraries are absent.

## 14.4 Go and CGO

The Go toolchain supports producing binaries that do not depend on C shared libraries for suitable applications.

Example:

```text
CGO_ENABLED=0
```

This disables cgo for the relevant build.

## 14.5 Important Qualification

Disabling cgo is not a universal solution for every Go program.

Applications requiring native C libraries or cgo-dependent functionality may need a different build and runtime strategy.

---

# 15. BUILD BASE IMAGE SELECTION

## 15.1 Common Image Categories

Runtime and build environments may use:

- Full operating-system images.
- Language SDK images.
- Slim variants.
- Alpine-based images.
- Distroless images.
- Scratch.

## 15.2 Alpine

Alpine-based images are commonly relatively compact.

However, Alpine uses musl libc rather than glibc.

Compatibility must be considered for applications and dependencies expecting particular libc behavior.

## 15.3 Slim Images

Slim variants provide reduced package sets while retaining selected operating-system facilities.

## 15.4 Distroless Images

Distroless images are intended to contain only the components required for selected application runtimes.

They generally omit conventional package-management and interactive-shell tooling.

## 15.5 Scratch

Scratch contains no preinstalled userspace filesystem.

It is appropriate only when the required runtime files are supplied explicitly or embedded in the application.

## 15.6 Selection Principle

**Select the smallest suitable runtime environment that still satisfies the application's operational requirements.**

The smallest available base is not necessarily the most appropriate base.

---

# 16. INTRODUCTION TO BUILDKIT

## 16.1 Definition

BuildKit is Docker's modern build engine.

It interprets build definitions and executes the operations required to produce images and other build artifacts.

## 16.2 Responsibilities

BuildKit supports:

- Build dependency analysis.
- Cache management.
- Multi-stage builds.
- Parallelizable build execution.
- Build mounts.
- Secret mounts.
- Build output generation.
- External cache import and export.
- Advanced build configuration.

## 16.3 BuildKit and Dockerfiles

BuildKit processes Dockerfile instructions through a supported Dockerfile frontend.

The frontend translates the build definition into operations that the BuildKit engine can execute.

## 16.4 Build Graph

The build can be represented as a dependency graph rather than merely as a flat list of commands.

This permits BuildKit to identify independent operations and avoid unnecessary work.

---

# 17. BUILDKIT EXECUTION MODEL

## 17.1 Simplified Architecture

```text
                DOCKERFILE
                    |
                    v
             DOCKERFILE FRONTEND
                    |
                    v
              BUILD OPERATIONS
                    |
                    v
               BUILDKIT ENGINE
                    |
          +---------+---------+
          |                   |
          v                   v
      CACHE LOOKUP        EXECUTION
          |                   |
          +---------+---------+
                    |
                    v
              BUILD OUTPUT
                    |
                    v
                IMAGE
```

## 17.2 Optimization

If a build operation has reusable cached output, BuildKit may avoid repeating the corresponding expensive work.

## 17.3 Parallelization

Independent build stages or operations may be processed in parallel when their dependencies allow it.

## 17.4 Important Qualification

Parallel execution does not mean every Dockerfile instruction executes simultaneously.

Build operations with dependencies must respect the required execution order.

---

# 18. DOCKER BUILDX

## 18.1 Definition

Buildx is Docker's extended build interface for BuildKit.

It provides commands for managing builders and performing advanced builds.

## 18.2 Version Inspection

```bash
docker buildx version
```

## 18.3 Builder Listing

```bash
docker buildx ls
```

## 18.4 Selected Builder Inspection

```bash
docker buildx inspect
```

## 18.5 Builder Drivers

Common Buildx drivers include:

| Driver | General responsibility |
|---|---|
| `docker` | Uses BuildKit integrated with Docker Engine |
| `docker-container` | Runs BuildKit in a dedicated Docker container |
| `kubernetes` | Uses BuildKit in Kubernetes |
| `remote` | Connects to an externally managed BuildKit daemon |

## 18.6 Important Distinction

Buildx is the build-management interface.

BuildKit is the build engine.

---

# 19. DOCKER BUILD AND BUILDX BUILD

## 19.1 Basic Docker Build

```bash
docker build -t academic-image:v1 .
```

This builds an image using the Docker environment's applicable builder.

## 19.2 Buildx Build

```bash
docker buildx build -t academic-image:v1 .
```

Buildx supports selecting advanced builders and output configurations.

## 19.3 Local Image Availability

When using a builder that does not automatically load output into Docker's local image store, an explicit load operation may be required.

Example:

```bash
docker buildx build --load -t academic-image:v1 .
```

## 19.4 Important Qualification

The exact output behavior depends on the selected builder driver and image store.

A successful build does not always imply that the image is available through ordinary `docker image ls` commands.

---

# 20. THE DOCKERFILE SYNTAX DIRECTIVE

## 20.1 Definition

A Dockerfile may begin with:

```dockerfile
# syntax=docker/dockerfile:1
```

## 20.2 Purpose

This selects the Dockerfile frontend syntax used by supported BuildKit builds.

## 20.3 Benefits

The directive allows the Dockerfile to use supported modern instructions and build features.

## 20.4 Reproducibility Consideration

A floating frontend reference such as `docker/dockerfile:1` can receive compatible updates.

Strictly controlled builds may require more specific frontend references in addition to controlled base images and dependencies.

---

# 21. THE DOCKER BUILD CACHE

## 21.1 Definition

The Docker build cache stores reusable results from previous image-construction operations.

## 21.2 Purpose

Reusing cached results can avoid repeating:

- Dependency installation.
- Package downloads.
- Compilation.
- Source processing.
- Other expensive build operations.

## 21.3 Cache Model

```text
           DOCKERFILE INSTRUCTION
                     |
                     v
                CACHE LOOKUP
                     |
          +----------+----------+
          |                     |
          v                     v
       CACHE HIT             CACHE MISS
          |                     |
          v                     v
     REUSE RESULT        EXECUTE OPERATION
                                |
                                v
                           STORE RESULT
```

## 21.4 Cache Correctness

A cache result must correspond to sufficiently equivalent build inputs.

Docker therefore evaluates relevant instruction configuration and input data when determining whether reuse is valid.

---

# 22. CACHE INVALIDATION

## 22.1 Definition

Cache invalidation occurs when a previously cached build result cannot be reused because relevant inputs or configuration have changed.

## 22.2 Common Causes

Cache invalidation may result from:

- Dockerfile instruction changes.
- Source-file content changes.
- Dependency manifest changes.
- Build argument changes.
- Base-image changes.
- Explicit cache invalidation.

## 22.3 Consequence

When an operation is invalidated, dependent later operations may also require reevaluation or execution.

## 22.4 Important Detail

Docker does not simply compare every file's modification timestamp to decide whether every build instruction needs to run again.

For COPY and ADD operations, BuildKit uses relevant file metadata and content checks.

Modification time alone is not generally a cache invalidation input for those operations.

---

# 23. DOCKERFILE INSTRUCTION ORDERING

## 23.1 Inefficient Structure

Consider:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt
```

Every source-code change may invalidate the broad COPY operation and require reevaluation of the dependency installation step.

## 23.2 Improved Structure

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./

RUN pip install -r requirements.txt

COPY . .
```

## 23.3 Interpretation

The dependency manifest is copied before the frequently changing application source.

If the source code changes but the dependency manifest remains unchanged, the dependency installation result may be reused.

## 23.4 General Principle

Place relatively stable and expensive build operations before frequently changing application content when dependencies and correctness permit.

---

# 24. BUILD CONTEXT

## 24.1 Definition

The build context is the set of files and directories made available to the builder for a build operation.

## 24.2 Example

```bash
docker build .
```

The period identifies the current directory as the build context.

## 24.3 Contents

The context may include:

- Source code.
- Dependency manifests.
- Assets.
- Dockerfiles.
- Documentation.
- Temporary files.
- Local development artifacts.

## 24.4 Problem

Unnecessary build-context files can increase transfer and processing overhead.

They can also influence cache invalidation when copied by broad instructions.

## 24.5 Security Consideration

Sensitive files should not be included in build contexts unnecessarily.

Even if an application does not use a file directly, broad copying patterns may accidentally introduce it into an image.

---

# 25. THE DOCKERIGNORE FILE

## 25.1 Definition

A `.dockerignore` file defines patterns for excluding files and directories from a Docker build context.

## 25.2 Example

```dockerignore
.git
.env
__pycache__/
node_modules/
*.log
coverage/
```

## 25.3 Benefits

A correct `.dockerignore` file can:

1. Reduce context size.
2. Avoid unnecessary copying.
3. Improve cache effectiveness.
4. Reduce build overhead.
5. Reduce accidental inclusion of local files.

## 25.4 Important Qualification

`.dockerignore` is not a complete security control.

Secrets should be handled through appropriate secure build mechanisms and should not be copied into runtime image layers.

---

# 26. BUILDKIT CACHE MOUNTS

## 26.1 Definition

A BuildKit cache mount provides a persistent build cache directory to a selected `RUN` operation.

Example:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /out/server .
```

## 26.2 Purpose

The cache directory may retain reusable compiler or package-manager data between builds.

## 26.3 Cache Mount Versus Image Layer

The cache mount is separate from the final image filesystem.

Its contents are not automatically included in the resulting image.

## 26.4 Important Qualification

Cache mounts are performance optimizations.

Build instructions must still be correct when the cache is empty.

A valid build should not require a particular previous cache state to produce a functioning artifact.

---

# 27. PACKAGE MANAGER CACHE MOUNTS

## 27.1 Go Example

```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
```

This can preserve downloaded Go modules between builds.

## 27.2 Compiler Cache

```dockerfile
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /out/server .
```

This can preserve compiler cache data.

## 27.3 Other Ecosystems

The same principle applies to other package managers when configured correctly.

Examples include:

- npm.
- pip.
- Maven.
- Gradle.
- Cargo.

## 27.4 Application-Specific Configuration

Not every package manager uses the same cache directory or behaves identically.

Cache mount paths and sharing behavior must match the selected tool.

---

# 28. BUILD-TIME BIND MOUNTS

## 28.1 Definition

BuildKit supports temporary bind mounts during `RUN` operations.

Example:

```dockerfile
RUN --mount=type=bind,source=.,target=/src,readonly \
    some-build-command
```

## 28.2 Purpose

A build operation can access selected source files without necessarily copying those files into a persistent image layer first.

## 28.3 Distinction from Runtime Bind Mounts

A runtime bind mount is configured when a container is created.

A BuildKit bind mount exists for the relevant build operation.

These mechanisms serve different purposes.

## 28.4 Important Limitation

Files written only into an ephemeral build bind mount are not automatically preserved as image output.

Build artifacts must be written to an appropriate persistent build-stage location if they are to be copied into a later stage.

---

# 29. EXTERNAL BUILD CACHE

## 29.1 Definition

An external build cache stores reusable build information outside the local builder's ordinary cache storage.

## 29.2 Use Cases

External caches are useful when builds run on different machines.

For example:

- Continuous integration agents.
- Ephemeral build environments.
- Multiple development workstations.
- Distributed build pipelines.

## 29.3 Cache Export

Buildx supports:

```text
--cache-to
```

## 29.4 Cache Import

Buildx supports:

```text
--cache-from
```

## 29.5 General Model

```text
               BUILD MACHINE A
                      |
                      v
                 CACHE EXPORT
                      |
                      v
                REMOTE CACHE
                      |
                      v
                 CACHE IMPORT
                      |
                      v
               BUILD MACHINE B
```

---

# 30. EXTERNAL CACHE BACKENDS

Common external cache backends include:

| Backend | General purpose |
|---|---|
| Inline | Associates cache metadata with an image |
| Registry | Stores cache separately in a container registry |
| Local | Stores cache files in a local directory |
| GitHub Actions | Uses GitHub Actions cache infrastructure |
| Other supported backends | Specialized storage configurations |

## 30.1 Registry Cache

A registry cache can be useful for multi-stage builds because it supports exporting cache information independently from the final runtime image.

## 30.2 Minimum Cache Mode

The `min` mode exports cache for layers needed in the final image.

## 30.3 Maximum Cache Mode

The `max` mode can export intermediate-stage cache results as well.

## 30.4 Tradeoff

Maximum cache mode may improve reuse in complex builds but can require more cache storage and transfer.

The appropriate setting depends on build patterns and infrastructure.

---

# 31. BUILD CACHE AND SECRETS

## 31.1 Sensitive Build Inputs

Some builds require confidential resources.

Examples include:

- Private package registry credentials.
- Temporary repository access tokens.
- Private source repository authentication.
- Selected signing or retrieval credentials.

## 31.2 Incorrect Mechanisms

Sensitive values should not be supplied through ordinary Dockerfile `ARG` or `ENV` instructions merely because they are convenient.

These mechanisms may expose values through image configuration, history, provenance, or other build metadata.

## 31.3 BuildKit Secret Mounts

BuildKit supports temporary secret mounts.

General syntax:

```dockerfile
RUN --mount=type=secret,id=credential \
    some-command
```

## 31.4 Example

The command-line invocation may supply:

```bash
docker build --secret id=credential,src=./local-credential.txt .
```

The Dockerfile can access the secret through:

```text
/run/secrets/credential
```

during the selected build operation.

## 31.5 Important Qualification

Secret mounts reduce the risk of persisting secrets in image layers.

However, a build command can still accidentally disclose a secret through logs, generated artifacts, or explicit copying.

Correct secret handling remains the responsibility of the build implementation.

---

# 32. ARG AND ENV IN IMAGE CONSTRUCTION

## 32.1 Build Arguments

`ARG` defines values used during image construction.

Example:

```dockerfile
ARG APP_VERSION=1.0.0
```

## 32.2 Environment Variables

`ENV` establishes image environment configuration.

Example:

```dockerfile
ENV APP_MODE=production
```

## 32.3 Distinction

| Characteristic | ARG | ENV |
|---|---|---|
| Main purpose | Build-time parameter | Image/runtime environment setting |
| Used during build | Yes | Yes |
| Automatically inherited as runtime environment | No | Yes |
| Suitable for secrets | No | No |
| Can affect build caching | Yes | Yes |

## 32.4 Stage Scope

Build arguments have scope rules.

An argument declared in one stage is not automatically available in every unrelated stage.

Arguments needed within a stage must be declared in the appropriate scope.

---

# 33. REPRODUCIBLE BUILDS

## 33.1 Definition

A reproducible build is a build process intended to produce equivalent, and under stricter definitions byte-identical, artifacts from identical controlled inputs.

## 33.2 Required Controls

Reproducibility may depend on:

- Base image identity.
- Dependency versions.
- Source code revision.
- Compiler version.
- Build arguments.
- Build timestamps.
- Operating-system packages.
- Build platform.
- External downloads.
- Build frontend version.

## 33.3 Image Tags

An image reference such as:

```text
golang:1.26-alpine
```

selects an image tag.

Tags can be updated by publishers.

## 33.4 Image Digests

An image can also be referenced by an immutable content digest.

Conceptually:

```text
golang@sha256:<digest>
```

A digest reference identifies specific image content.

## 33.5 Reproducibility Tradeoff

Digest pinning improves control over base image identity.

However, a pinned base image does not automatically receive newly published security fixes.

A maintenance process must deliberately update pinned references.

---

# 34. BUILD METADATA

## 34.1 Application Version

A build may include:

```text
APP_VERSION=1.0.0
```

## 34.2 Source Revision

A build may also include:

```text
VCS_REF=development
```

## 34.3 Purpose

Metadata supports identification of deployed application versions.

## 34.4 Implementation

A compiled application can receive version information through build flags.

Alternatively, an image can contain metadata labels.

## 34.5 Security and Privacy

Do not place sensitive credentials or confidential internal data in image labels or build metadata.

Such information may be visible to anyone with access to the image or registry.

---

# 35. IMAGE INSPECTION AND MEASUREMENT

## 35.1 List Images

```bash
docker image ls
```

## 35.2 Inspect Image Size

```bash
docker image inspect IMAGE --format '{{.Size}}'
```

This reports the image's size value in bytes.

## 35.3 Image History

```bash
docker history IMAGE
```

Displays image history information.

## 35.4 Detailed Storage Usage

```bash
docker system df -v
```

Provides detailed Docker storage usage information.

## 35.5 Measurement Qualification

Different tools may report:

- Uncompressed image size.
- Compressed registry transfer size.
- Shared layer usage.
- Unique disk usage.
- Build cache storage.

These measurements should not be treated as interchangeable.

---

# 36. IMAGE OPTIMIZATION METRICS

A useful optimization comparison may examine:

1. Final image size.
2. Number of runtime dependencies.
3. Build duration.
4. Rebuild duration.
5. Registry transfer size.
6. Application startup behavior.
7. Security exposure.
8. Operational compatibility.

## 36.1 Example Assessment Table

| Metric | Baseline image | Optimized image |
|---|---|---|
| Base environment | Go SDK | Scratch |
| Compiler included | Yes | No |
| Application source included | Yes | No |
| Runtime executable | Yes | Yes |
| Shell available | Yes | No |
| Build cache optimization | Limited | Explicit |
| Runtime user | Depends on configuration | Non-root |
| Final image size | To be measured | To be measured |

The laboratory will produce the actual measurements.

---

# PART II — PRACTICAL CAPSTONE PROJECT

# 37. PROJECT TITLE

**Optimized Go HTTP Service: Comparative Single-Stage and Multi-Stage Docker Image Engineering**

## 37.1 Project Objective

The student will construct one Go HTTP application and package it in two different ways.

**Baseline image:** Uses the Go SDK as the final runtime environment.

**Optimized image:** Uses a multi-stage build and copies the compiled application into a scratch runtime image.

The student will compare both images for:

- Correctness.
- Runtime behavior.
- Image size.
- Build history.
- Cache reuse.
- Dependency separation.
- Maintainability.

---

# 38. PROJECT REQUIREMENTS

The HTTP application must provide:

1. A webpage.
2. A health endpoint.
3. A JSON build-information endpoint.
4. Application version metadata.
5. Source revision metadata.
6. HTTP listening on container port 8080.

The optimized image must:

1. Use multiple build stages.
2. Compile the application in a Go SDK stage.
3. Execute application tests.
4. Copy only the required runtime executable into the final stage.
5. Use scratch as the runtime base.
6. Execute under a numeric non-root identity.
7. Avoid requiring a shell in the runtime image.
8. Support local HTTP access through a published port.

---

# 39. PROJECT DIRECTORY

Create:

```text
docker-lecture15/
├── go.mod
├── main.go
├── main_test.go
├── Dockerfile.baseline
├── Dockerfile.optimized
├── .dockerignore
└── static/
    └── index.html
```

## File Responsibilities

`go.mod`: Defines the Go module.

`main.go`: Implements the HTTP application.

`main_test.go`: Contains application tests.

`Dockerfile.baseline`: Defines the single-stage image.

`Dockerfile.optimized`: Defines the multi-stage image.

`.dockerignore`: Excludes unnecessary build inputs.

`static/index.html`: Provides the embedded webpage.

---

# 40. GO MODULE DEFINITION

Create:

`go.mod`

Insert:

```go
module example.com/docker-lecture15

go 1.26
```

## 40.1 Explanation

The module name identifies the Go module.

The Go version specifies the language and module compatibility requirement.

## 40.2 Dependencies

The application uses only Go's standard library.

Therefore, no third-party runtime dependencies are required for the exercise.

## 40.3 Laboratory Benefit

Avoiding third-party libraries makes the differences between the build environment and runtime environment particularly clear.

---

# 41. COMPLETE GO APPLICATION

Create:

`main.go`

Insert:

```go
package main

import (
    "embed"
    "encoding/json"
    "log"
    "net/http"
    "runtime"
    "time"
)

var version = "development"
var revision = "unknown"

//go:embed static/index.html
var staticFiles embed.FS

func newHandler() http.Handler {
    mux := http.NewServeMux()

    mux.HandleFunc("/", func(
        w http.ResponseWriter,
        r *http.Request,
    ) {
        if r.URL.Path != "/" {
            http.NotFound(w, r)
            return
        }

        content, err := staticFiles.ReadFile(
            "static/index.html",
        )

        if err != nil {
            http.Error(
                w,
                "Application asset unavailable",
                http.StatusInternalServerError,
            )
            return
        }

        w.Header().Set(
            "Content-Type",
            "text/html; charset=utf-8",
        )

        w.WriteHeader(http.StatusOK)

        _, _ = w.Write(content)
    })

    mux.HandleFunc("/healthz", func(
        w http.ResponseWriter,
        r *http.Request,
    ) {
        if r.Method != http.MethodGet {
            w.Header().Set("Allow", http.MethodGet)

            http.Error(
                w,
                "Method not allowed",
                http.StatusMethodNotAllowed,
            )
            return
        }

        w.Header().Set(
            "Content-Type",
            "text/plain; charset=utf-8",
        )

        _, _ = w.Write([]byte("ok\n"))
    })

    mux.HandleFunc("/api/build-info", func(
        w http.ResponseWriter,
        r *http.Request,
    ) {
        if r.Method != http.MethodGet {
            w.Header().Set("Allow", http.MethodGet)

            http.Error(
                w,
                "Method not allowed",
                http.StatusMethodNotAllowed,
            )
            return
        }

        w.Header().Set(
            "Content-Type",
            "application/json",
        )

        data := map[string]string{
            "version":   version,
            "revision":  revision,
            "go":        runtime.Version(),
            "os":        runtime.GOOS,
            "arch":      runtime.GOARCH,
        }

        if err := json.NewEncoder(w).Encode(data); err != nil {
            log.Printf("JSON response error: %v", err)
        }
    })

    return mux
}

func main() {
    server := &http.Server{
        Addr:              ":8080",
        Handler:           newHandler(),
        ReadHeaderTimeout: 5 * time.Second,
    }

    log.Printf(
        "Starting application version=%s revision=%s",
        version,
        revision,
    )

    if err := server.ListenAndServe(); err != nil {
        log.Fatal(err)
    }
}
```

## 41.1 Application Behavior

The application listens on TCP port 8080.

It serves an embedded HTML page.

It exposes a basic health endpoint.

It exposes build-information metadata through JSON.

## 41.2 Embedded Assets

The declaration:

```go
//go:embed static/index.html
```

instructs Go to embed the selected file in the compiled program.

The application therefore does not need to load its webpage from a separate runtime filesystem path.

## 41.3 Runtime Advantage

The final runtime image can contain only the application executable while still serving the webpage.

---

# 42. HTML APPLICATION CONTENT

Create:

`static/index.html`

Insert:

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Docker Lecture 15</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            padding: 40px;
            color: #0f172a;
        }

        main {
            max-width: 720px;
            margin: auto;
            background: white;
            padding: 40px;
            border-radius: 12px;
        }

        h1 {
            color: #2563eb;
        }

        pre {
            background: #e2e8f0;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
        }
    </style>
</head>

<body>

    <main>

        <h1>Docker Lecture 15</h1>

        <h2>Advanced Image Engineering</h2>

        <p>
            This application is written in Go
            and packaged using Docker.
        </p>

        <p>
            The optimized runtime image contains
            only the compiled application.
        </p>

        <h3>Build Information</h3>

        <pre id="build-info">Loading...</pre>

    </main>

    <script>
        fetch("/api/build-info")
            .then(response => response.json())
            .then(data => {
                document.getElementById(
                    "build-info"
                ).textContent = JSON.stringify(
                    data,
                    null,
                    2
                );
            })
            .catch(() => {
                document.getElementById(
                    "build-info"
                ).textContent =
                    "Build information unavailable";
            });
    </script>

</body>

</html>
```

The webpage requests the build-information API.

The returned JSON is displayed in the browser.

---

# 43. AUTOMATED GO TESTS

Create:

`main_test.go`

Insert:

```go
package main

import (
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"
)

func TestHealthEndpoint(t *testing.T) {
    request := httptest.NewRequest(
        http.MethodGet,
        "/healthz",
        nil,
    )

    response := httptest.NewRecorder()

    newHandler().ServeHTTP(
        response,
        request,
    )

    if response.Code != http.StatusOK {
        t.Fatalf(
            "Expected status 200, got %d",
            response.Code,
        )
    }

    if strings.TrimSpace(
        response.Body.String(),
    ) != "ok" {
        t.Fatalf(
            "Unexpected health response: %q",
            response.Body.String(),
        )
    }
}

func TestBuildInformation(t *testing.T) {
    request := httptest.NewRequest(
        http.MethodGet,
        "/api/build-info",
        nil,
    )

    response := httptest.NewRecorder()

    newHandler().ServeHTTP(
        response,
        request,
    )

    if response.Code != http.StatusOK {
        t.Fatalf(
            "Expected status 200, got %d",
            response.Code,
        )
    }

    if !strings.Contains(
        response.Body.String(),
        "revision",
    ) {
        t.Fatal(
            "Build information is missing revision",
        )
    }
}

func TestUnknownPath(t *testing.T) {
    request := httptest.NewRequest(
        http.MethodGet,
        "/does-not-exist",
        nil,
    )

    response := httptest.NewRecorder()

    newHandler().ServeHTTP(
        response,
        request,
    )

    if response.Code != http.StatusNotFound {
        t.Fatalf(
            "Expected status 404, got %d",
            response.Code,
        )
    }
}
```

## 43.1 Purpose

The test suite verifies:

1. Health endpoint correctness.
2. Build-information endpoint availability.
3. Unknown-path handling.

## 43.2 Engineering Value

The tests can be executed during image construction.

A failed test can prevent successful completion of the final image build.

---

# 44. BASELINE SINGLE-STAGE DOCKERFILE

Create:

`Dockerfile.baseline`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.26-alpine

WORKDIR /src

ARG APP_VERSION=1.0.0
ARG VCS_REF=unknown

COPY . .

RUN CGO_ENABLED=0 GOOS=linux \
    go build \
    -trimpath \
    -buildvcs=false \
    -ldflags="-X main.version=${APP_VERSION} -X main.revision=${VCS_REF}" \
    -o /usr/local/bin/server \
    .

EXPOSE 8080

CMD ["/usr/local/bin/server"]
```

## 44.1 Interpretation

The final image contains the Go SDK environment.

The compiler and other development resources remain in the image.

## 44.2 Functionality

The image can run the HTTP service correctly.

## 44.3 Limitation

It contains more development tooling than the runtime application requires.

---

# 45. OPTIMIZED MULTI-STAGE DOCKERFILE

Create:

`Dockerfile.optimized`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.26-alpine AS build

WORKDIR /src

ARG APP_VERSION=1.0.0
ARG VCS_REF=unknown

COPY go.mod ./

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY main.go main_test.go ./

COPY static/ ./static/

RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build \
    -trimpath \
    -buildvcs=false \
    -ldflags="-s -w -X main.version=${APP_VERSION} -X main.revision=${VCS_REF}" \
    -o /out/server \
    .


FROM build AS test

RUN --mount=type=cache,target=/root/.cache/go-build \
    go test ./...


FROM scratch AS runtime

COPY --from=test /out/server /server

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["/server"]
```

---

# 46. OPTIMIZED DOCKERFILE ANALYSIS

## 46.1 Build Stage

The stage:

```dockerfile
FROM golang:1.26-alpine AS build
```

contains the Go toolchain.

It compiles the application.

## 46.2 Dependency Handling

The Go module manifest is copied before source code.

This supports dependency-related cache reuse.

Because the project has no third-party modules, the module-download operation is intentionally simple.

The benefits become more significant in larger projects.

## 46.3 Source Copying

The application source and embedded assets are copied after the module manifest.

## 46.4 Compiler Cache

The build operation uses a BuildKit cache mount.

The compiler cache can be reused during later builds.

## 46.5 Linker Flags

The `-s` and `-w` linker options reduce certain symbol and debugging information stored in the executable.

They can reduce executable size.

## 46.6 Build Metadata

The build arguments inject the application version and revision into the compiled program.

## 46.7 Test Stage

The stage:

```dockerfile
FROM build AS test
```

inherits the completed build environment.

It executes the Go tests.

## 46.8 Runtime Stage

The runtime stage begins from:

```dockerfile
FROM scratch AS runtime
```

It contains no inherited Go SDK filesystem.

## 46.9 Artifact Copy

```dockerfile
COPY --from=test /out/server /server
```

copies the compiled executable into the runtime stage.

Because the runtime stage depends on the test stage, the test-stage operation is part of the dependency path for the final image.

## 46.10 Non-Root Execution

The image specifies:

```dockerfile
USER 10001:10001
```

The runtime process executes with a numeric non-root identity.

## 46.11 No Shell

The runtime image has no shell unless one is explicitly copied into it.

This is expected.

---

# 47. DOCKERIGNORE CONFIGURATION

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.gitignore
.env
*.log
*.tmp
*.tar
*.zip
coverage/
node_modules/
vendor/
scratch-data/
dist/
bin/
Dockerfile.baseline
Dockerfile.optimized
```

## 47.1 Purpose

The build context excludes unnecessary files.

## 47.2 Dockerfiles

The Dockerfiles can still be selected using the `-f` build option.

They do not need to be copied as ordinary application source files.

## 47.3 Security

The exclusion of `.env` reduces the risk of unintentionally copying environment files into images.

It does not replace secure credential management.

---

# PART III — PRACTICAL LABORATORY 15

# 48. LABORATORY OVERVIEW

**Laboratory Title:** Comparative Docker Image Construction and Build Cache Analysis.

**Primary Objective:** Demonstrate that a correctly designed multi-stage build can produce a substantially smaller runtime image while maintaining the same application functionality.

The laboratory consists of 26 experiments.

Required software:

- Docker Engine or Docker Desktop.
- Docker Buildx and BuildKit.
- Terminal.
- Text editor.
- Browser or HTTP client.
- Internet access for initial image retrieval.

The commands assume a Unix-like shell unless otherwise indicated.

---

# 49. EXPERIMENT 1 — VERIFY THE BUILD ENVIRONMENT

Execute:

```bash
docker version
```

Then:

```bash
docker buildx version
```

Then:

```bash
docker buildx ls
```

**Objective:**

Identify the installed Docker and Buildx environment.

**Required observations:**

1. Docker Engine version.
2. Buildx version.
3. Available builders.
4. Selected builder.
5. Builder driver.

---

# 50. EXPERIMENT 2 — CREATE THE PROJECT

Create the project directory:

```bash
mkdir docker-lecture15
cd docker-lecture15
mkdir static
```

Create the required files using Sections 40–47.

**Objective:**

Establish the complete application source and Dockerfile configurations.

**Expected result:**

The project directory contains all the required files.

---

# 51. EXPERIMENT 3 — BUILD THE BASELINE IMAGE

Execute:

```bash
docker build \
  --progress=plain \
  -f Dockerfile.baseline \
  -t lecture15:baseline \
  .
```

**Objective:**

Build the single-stage application image.

**Expected behavior:**

Docker retrieves the Go base image if necessary.

The builder copies the context.

The application is compiled.

The final image is created.

**Required observations:**

1. Build operations.
2. Compilation step.
3. Image tag.
4. Build completion status.

---

# 52. EXPERIMENT 4 — BUILD THE OPTIMIZED IMAGE

Execute:

```bash
docker build \
  --progress=plain \
  -f Dockerfile.optimized \
  -t lecture15:optimized \
  .
```

**Objective:**

Build the optimized multi-stage runtime image.

**Expected behavior:**

The builder processes the build stage.

The Go application is compiled.

The test stage executes.

The runtime stage copies the compiled executable.

The final image is created.

**Required analysis:**

Identify which stage becomes the final image and which stages contain the Go compiler.

---

# 53. EXPERIMENT 5 — VERIFY THE TEST STAGE

Execute:

```bash
docker build \
  --progress=plain \
  --target test \
  -f Dockerfile.optimized \
  -t lecture15:test \
  .
```

**Objective:**

Build the intermediate test stage explicitly.

**Expected result:**

The Go test suite succeeds.

**Required analysis:**

Explain why automated tests can form part of the final image's build dependency path.

---

# 54. EXPERIMENT 6 — INSPECT IMAGE SIZES

Execute:

```bash
docker image ls lecture15
```

Then:

```bash
docker image inspect lecture15:baseline --format '{{.Size}}'
```

And:

```bash
docker image inspect lecture15:optimized --format '{{.Size}}'
```

**Objective:**

Compare the two images.

**Required observations:**

Record the sizes in bytes.

The optimized runtime image should generally be substantially smaller than the baseline image.

The exact values depend on the base image versions, platform, and build output.

---

# 55. EXPERIMENT 7 — EXPLAIN THE SIZE DIFFERENCE

Inspect the baseline image:

```bash
docker history lecture15:baseline
```

Then the optimized image:

```bash
docker history lecture15:optimized
```

**Objective:**

Investigate how the two images were assembled.

**Required analysis:**

Explain:

1. Why the Go toolchain remains in the baseline image.
2. Why the final runtime image does not contain the toolchain.
3. How `COPY --from` affects the final image.
4. Why scratch is appropriate for this particular application.

---

# 56. EXPERIMENT 8 — START THE BASELINE CONTAINER

Execute:

```bash
docker run -d \
  --name lecture15-baseline \
  -p 127.0.0.1:8251:8080 \
  lecture15:baseline
```

**Objective:**

Verify that the single-stage image functions correctly.

Open:

http://127.0.0.1:8251

**Expected result:**

The webpage appears.

---

# 57. EXPERIMENT 9 — START THE OPTIMIZED CONTAINER

Execute:

```bash
docker run -d \
  --name lecture15-optimized \
  -p 127.0.0.1:8250:8080 \
  lecture15:optimized
```

**Objective:**

Verify that the optimized image functions correctly.

Open:

http://127.0.0.1:8250

**Expected result:**

The same application interface appears.

**Required analysis:**

Explain why a smaller runtime image can provide equivalent application functionality.

---

# 58. EXPERIMENT 10 — VERIFY HEALTH ENDPOINTS

Execute:

```bash
curl -i http://127.0.0.1:8250/healthz
```

Then:

```bash
curl -i http://127.0.0.1:8251/healthz
```

**Expected result:**

Both endpoints return HTTP 200 and:

```text
ok
```

**Objective:**

Verify functional equivalence across the two image configurations.

---

# 59. EXPERIMENT 11 — INSPECT BUILD INFORMATION

Execute:

```bash
curl http://127.0.0.1:8250/api/build-info
```

Then:

```bash
curl http://127.0.0.1:8251/api/build-info
```

**Objective:**

Inspect embedded application version information.

**Expected result:**

The responses contain fields similar to:

```json
{
  "version": "1.0.0",
  "revision": "unknown",
  "go": "go1.26...",
  "os": "linux",
  "arch": "amd64"
}
```

The reported Go version and architecture depend on the build environment.

**Required analysis:**

Explain how build-time arguments were incorporated into the executable.

---

# 60. EXPERIMENT 12 — VERIFY NON-ROOT EXECUTION

Execute:

```bash
docker inspect lecture15-optimized --format '{{.Config.User}}'
```

**Expected result:**

```text
10001:10001
```

**Objective:**

Verify the image's configured runtime identity.

**Required analysis:**

Explain why numeric user identifiers can be used even when the runtime image contains no `/etc/passwd` file.

---

# 61. EXPERIMENT 13 — INVESTIGATE THE ABSENCE OF A SHELL

Attempt:

```bash
docker exec lecture15-optimized sh
```

**Expected result:**

The command fails because the scratch image does not contain a shell.

**Objective:**

Understand the debugging implications of minimal runtime images.

**Required analysis:**

Explain why the failed shell command does not imply that the HTTP application is malfunctioning.

---

# 62. EXPERIMENT 14 — INSPECT THE BUILD STAGE

Execute:

```bash
docker build \
  --target build \
  -f Dockerfile.optimized \
  -t lecture15:build-stage \
  .
```

Now execute:

```bash
docker run --rm \
  --entrypoint go \
  lecture15:build-stage \
  version
```

**Objective:**

Demonstrate that the build stage contains the Go toolchain.

**Expected result:**

The container reports its Go version.

**Required analysis:**

Explain why this development tooling is not included in the optimized runtime image.

---

# 63. EXPERIMENT 15 — REBUILD WITHOUT SOURCE CHANGES

Execute:

```bash
docker build \
  --progress=plain \
  -f Dockerfile.optimized \
  -t lecture15:optimized \
  .
```

**Objective:**

Observe build cache reuse.

**Expected result:**

Previously completed operations may be reused from cache.

The displayed build output may indicate cached steps.

**Required analysis:**

Identify which operations were reused and explain why their inputs remained unchanged.

---

# 64. EXPERIMENT 16 — MODIFY ONLY THE HTML SOURCE

Open:

`static/index.html`

Change:

```html
<h2>Advanced Image Engineering</h2>
```

to:

```html
<h2>Advanced Image Engineering — Updated</h2>
```

Save the file.

Execute:

```bash
docker build \
  --progress=plain \
  -f Dockerfile.optimized \
  -t lecture15:optimized-v2 \
  .
```

**Objective:**

Investigate cache invalidation after a source asset changes.

**Expected behavior:**

The module-manifest-related operation may remain cached.

The source copying, compilation, and dependent test operations may require reevaluation.

**Required analysis:**

Explain why changing application source does not necessarily require repeating unrelated dependency download work.

---

# 65. EXPERIMENT 17 — RUN THE UPDATED IMAGE

Execute:

```bash
docker run -d \
  --name lecture15-v2 \
  -p 127.0.0.1:8252:8080 \
  lecture15:optimized-v2
```

Open:

http://127.0.0.1:8252

**Expected result:**

The updated heading appears.

**Objective:**

Verify that the changed source content was incorporated into the newly built executable.

---

# 66. EXPERIMENT 18 — CHANGE BUILD METADATA

Execute:

```bash
docker build \
  --progress=plain \
  --build-arg APP_VERSION=1.0.1 \
  --build-arg VCS_REF=lecture15-lab \
  -f Dockerfile.optimized \
  -t lecture15:optimized-v3 \
  .
```

**Objective:**

Produce another application build with explicit version metadata.

Start the image:

```bash
docker run -d \
  --name lecture15-v3 \
  -p 127.0.0.1:8253:8080 \
  lecture15:optimized-v3
```

Retrieve:

```bash
curl http://127.0.0.1:8253/api/build-info
```

**Expected result:**

The JSON contains:

```text
version: 1.0.1
revision: lecture15-lab
```

**Required analysis:**

Explain how a build argument differs from a runtime environment variable.

---

# 67. EXPERIMENT 19 — INSPECT THE BUILD CACHE

Execute:

```bash
docker buildx du
```

**Objective:**

Examine build cache storage usage.

**Required observations:**

Record the reported cache size and available cache information.

**Required analysis:**

Explain why build cache storage should not be confused with the size of the final runtime image.

---

# 68. EXPERIMENT 20 — EXAMINE THE BUILD CONTEXT

Create a directory containing irrelevant laboratory content:

```bash
mkdir -p scratch-data
```

Create a small file:

```bash
echo "This file is not needed for the image" > scratch-data/note.txt
```

Confirm that `.dockerignore` contains:

```text
scratch-data/
```

Execute:

```bash
docker build \
  --progress=plain \
  -f Dockerfile.optimized \
  -t lecture15:context-test \
  .
```

**Objective:**

Demonstrate that irrelevant files can be excluded from the build context.

**Required analysis:**

Explain how context exclusion can reduce unnecessary input processing and prevent accidental copying.

---

# 69. EXPERIMENT 21 — VERIFY RUNTIME IMAGE CONTENT

Execute:

```bash
docker image inspect lecture15:optimized-v3
```

**Objective:**

Examine the optimized image configuration.

Identify:

1. Entrypoint.
2. Exposed port.
3. User identity.
4. Image architecture.
5. Image size.

**Required analysis:**

Explain why the runtime image contains only a small number of filesystem components.

---

# 70. EXPERIMENT 22 — VERIFY CONTAINER LOGGING

Execute:

```bash
docker logs lecture15-optimized
```

Then:

```bash
docker logs lecture15-v3
```

**Objective:**

Verify that the minimal runtime application still provides usable logs.

**Expected result:**

The application prints startup information and any relevant runtime messages.

**Required analysis:**

Explain why a shell is not required for an application to write useful logs to standard output and standard error.

---

# 71. EXPERIMENT 23 — EXAMINE IMAGE STORAGE

Execute:

```bash
docker system df -v
```

**Objective:**

Examine images, container storage, and build cache usage.

**Required analysis:**

Distinguish:

- Image size.
- Shared layer storage.
- Unique storage usage.
- Build cache storage.
- Container writable-layer storage.

---

# 72. EXPERIMENT 24 — REVIEW MULTI-PLATFORM OPTIONS

Execute:

```bash
docker buildx ls
```

Inspect the platforms supported by the selected builder.

**Objective:**

Introduce the relationship between image architecture and builder capability.

**Required analysis:**

Explain why an application compiled for `linux/amd64` cannot automatically be assumed to execute on every other processor architecture.

Do not perform a multi-platform registry push during this introductory laboratory.

---

# 73. EXPERIMENT 25 — COMPARE THE FINAL IMAGES

Complete the following table.

| Property | Baseline | Optimized |
|---|---|---|
| Image tag | lecture15:baseline | lecture15:optimized |
| Base image | Go SDK | Scratch |
| Go compiler in runtime | Yes | No |
| Application executable | Yes | Yes |
| Shell available | Yes | No |
| Runtime user | Image default | UID 10001 |
| HTTP endpoint | Functional | Functional |
| Health endpoint | Functional | Functional |
| Image size in bytes | Record | Record |
| Build duration | Record | Record |
| Rebuild duration | Record | Record |

**Objective:**

Produce a structured engineering comparison.

**Required conclusion:**

Identify which image is more appropriate for deployment and explain the tradeoffs.

---

# 74. EXPERIMENT 26 — CONTROLLED CLEANUP

Remove the laboratory containers:

```bash
docker rm -f \
  lecture15-baseline \
  lecture15-optimized \
  lecture15-v2 \
  lecture15-v3
```

The command removes only the named laboratory containers.

Do not apply broad container-removal commands to unrelated workloads.

The built images may be retained for further inspection.

If no longer required, remove selected laboratory tags deliberately using `docker image rm`.

Do not indiscriminately prune the complete Docker build cache or image store.

---

# PART IV — ADVANCED BUILD ENGINEERING

# 75. MULTI-STAGE BUILDS FOR OTHER LANGUAGES

The principles demonstrated with Go also apply to other language ecosystems.

## 75.1 Node.js

A Node.js frontend may be built using npm.

The resulting static files can be copied into an Nginx runtime image.

Conceptual example:

```dockerfile
FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


FROM nginx:alpine AS runtime

COPY --from=build /app/dist/ /usr/share/nginx/html/
```

The output directory depends on the frontend framework.

## 75.2 Java

A Java application may be built using Maven or Gradle.

The resulting JAR can be copied into a runtime image containing an appropriate Java Runtime Environment.

## 75.3 Python

Python applications can use multi-stage builds to separate compilation and package construction from runtime execution.

However, Python applications generally still require a compatible Python runtime and the appropriate installed dependencies.

Copying only Python source files into scratch is not ordinarily sufficient.

## 75.4 C and C++

Compiled applications may require static linking or an appropriate runtime image containing compatible shared libraries.

---

# 76. MULTI-PLATFORM BUILDS

## 76.1 Definition

A multi-platform image is an image distribution that provides suitable variants for more than one operating-system or processor architecture combination.

Examples include:

```text
linux/amd64
linux/arm64
```

## 76.2 Buildx Support

Buildx supports multi-platform builds when the builder configuration provides the required capabilities.

## 76.3 General Example

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag example/application:1.0 \
  --push \
  .
```

This is an illustrative command.

It requires a suitable builder and permission to publish the named image.

## 76.4 Execution Mechanisms

Multi-platform builds may use:

- Native architecture builders.
- CPU emulation.
- Language-level cross-compilation.
- Multiple build nodes.

## 76.5 Important Qualification

The presence of Buildx does not automatically guarantee that every architecture can be built successfully.

Build dependencies and available builder platforms must be compatible.

---

# 77. MULTI-PLATFORM GO COMPILATION

Go can compile for selected target platforms using environment variables such as:

```text
GOOS
GOARCH
```

## 77.1 Example

```text
GOOS=linux
GOARCH=arm64
```

## 77.2 BuildKit Platform Arguments

BuildKit provides predefined platform arguments including:

```text
BUILDPLATFORM
TARGETPLATFORM
TARGETOS
TARGETARCH
```

These can be used to organize cross-compilation workflows.

## 77.3 Engineering Concern

If the build and target architectures differ, executing target binaries during the build may require suitable emulation.

A test stage intended to execute on the build platform should be designed accordingly.

---

# 78. IMAGE REPRODUCIBILITY LIMITATIONS

## 78.1 Mutable Tags

A base image tag may be updated.

A later build may therefore retrieve different base content.

## 78.2 Dependency Resolution

Unpinned external packages may change.

## 78.3 Timestamps

Build timestamps can influence file contents or image metadata.

## 78.4 Architecture

Different processor architectures may produce different binaries.

## 78.5 Toolchain Versions

Compiler changes may influence output.

## 78.6 Build Metadata

Application version values and source revision information may intentionally differ between builds.

## 78.7 Correct Conclusion

A multi-stage Dockerfile improves build organization but does not by itself guarantee byte-for-byte reproducibility.

---

# 79. BUILD SECURITY FUNDAMENTALS

## 79.1 Trusted Base Images

Prefer reputable, maintained base images appropriate to the application.

## 79.2 Avoid Unnecessary Software

Do not retain compilers, package managers, or debugging utilities in a runtime image unless justified.

## 79.3 Non-Root Execution

Use an appropriate non-root identity when the application permits it.

## 79.4 Secret Handling

Do not embed credentials in Dockerfile `ARG`, `ENV`, or source files.

Use supported secret mechanisms.

## 79.5 Image Updates

Small images still require maintenance.

Vulnerable application code and outdated runtime components can remain security risks even in highly optimized images.

The next lecture will examine these subjects in greater depth.

---

# 80. IMAGE TESTING PRINCIPLES

A production image should be tested at several levels.

## 80.1 Build Validation

Does the Dockerfile build successfully?

## 80.2 Unit Tests

Does the application logic pass its test suite?

## 80.3 Runtime Tests

Does the resulting container start and provide the expected endpoints?

## 80.4 Configuration Tests

Does the image contain the intended environment configuration, user identity, and entrypoint?

## 80.5 Integration Tests

Can the application communicate correctly with its dependencies?

## 80.6 Security Tests

Does the image comply with the organization's security requirements?

## 80.7 Important Principle

An image that builds successfully is not necessarily an image that runs correctly.

---

# PART V — TROUBLESHOOTING

# 81. BUILD FAILS BECAUSE COPY CANNOT FIND A FILE

## Possible Causes

- Incorrect build context.
- Incorrect relative path.
- File excluded by `.dockerignore`.
- Filename mismatch.
- Incorrect Dockerfile selection.

## Investigation

Verify the project directory and Dockerfile copy paths.

Inspect the `.dockerignore` patterns.

## Corrective Principle

The source path of a Dockerfile `COPY` instruction is interpreted relative to the applicable build context, not arbitrarily relative to the user's current terminal directory.

---

# 82. MULTI-STAGE COPY FAILS

## Scenario

The runtime stage contains:

```dockerfile
COPY --from=build /out/server /server
```

but the build stage does not produce `/out/server`.

## Explanation

The requested artifact does not exist at the specified source path.

## Correction

Verify the compiler output path and stage name.

The runtime copy path must match the actual build artifact.

---

# 83. SCRATCH CONTAINER FAILS TO START

## Possible Causes

- Executable missing.
- Incorrect executable permissions.
- Incorrect processor architecture.
- Dynamically linked executable missing shared libraries.
- Incorrect entrypoint.
- Missing runtime resources.

## Investigation

Inspect the build stage.

Verify the executable exists.

Confirm the target platform.

Determine whether runtime shared libraries are required.

---

# 84. IMAGE SIZE DOES NOT DECREASE

## Possible Causes

- Final stage still uses the SDK image.
- Unnecessary files are copied into the runtime stage.
- Static binary is unexpectedly large.
- Runtime image contains additional packages.
- Image comparison uses incompatible size metrics.

## Corrective Principle

Inspect the actual final stage and resulting image layers.

Do not assume that a Dockerfile is optimized merely because it contains multiple `FROM` instructions.

---

# 85. CACHE IS NOT REUSED

## Possible Causes

- Source files copied before stable dependency installation.
- Changing build arguments.
- Different base image content.
- Different builder.
- Cleared cache.
- Changed build context.
- Different build platforms.
- Explicit `--no-cache`.

## Investigation

Use:

```bash
docker build --progress=plain ...
```

Review which operations are rebuilt and which are cached.

---

# 86. BUILDX IMAGE DOES NOT APPEAR LOCALLY

## Scenario

A Buildx build reports success, but `docker image ls` does not show the image.

## Possible Cause

The selected builder exported the result to its build cache without loading the image into the local Docker image store.

## Correction

Use an appropriate output option.

For a suitable single-platform build:

```bash
docker buildx build --load -t application:local .
```

The exact behavior depends on the builder and image store.

---

# 87. APPLICATION STARTS BUT HTTP FAILS

## Possible Causes

- Incorrect container listening port.
- Application bound only to loopback.
- Incorrect published host port.
- Application process exited.
- Network route unavailable.

## Investigation

```bash
docker ps
```

```bash
docker logs CONTAINER
```

```bash
docker port CONTAINER
```

## Corrective Principle

Distinguish image construction problems from runtime networking problems.

---

# 88. CONTAINER HAS NO SHELL

## Scenario

An administrator attempts:

```bash
docker exec CONTAINER sh
```

against a scratch-based runtime image.

## Interpretation

The absence of a shell is expected.

## Recommended Approaches

Use:

- Application logs.
- Container inspection.
- HTTP diagnostic endpoints.
- Appropriate debugging images or controlled debugging environments.
- Intermediate build stages.

Do not add unnecessary debugging tools to a production image merely because an interactive shell is familiar.

---

# PART VI — FORMAL ACADEMIC ASSESSMENT

# 89. PART A — TECHNICAL DEFINITIONS

Provide academically precise definitions for:

1. Image optimization.
2. Build-time dependency.
3. Runtime dependency.
4. Multi-stage build.
5. Build stage.
6. Stage alias.
7. Build artifact.
8. Static linking.
9. Dynamic linking.
10. Scratch image.
11. BuildKit.
12. Buildx.
13. Build cache.
14. Cache invalidation.
15. Build context.
16. `.dockerignore`.
17. Cache mount.
18. Build-time bind mount.
19. External build cache.
20. Reproducible build.

---

# 90. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why build-time dependencies should not necessarily remain in a production image.

**Question 2.**

Describe how multi-stage builds reduce unnecessary runtime content.

**Question 3.**

Explain the role of `COPY --from`.

**Question 4.**

Describe why a scratch image may not contain a shell.

**Question 5.**

Explain the relationship between static linking and minimal runtime images.

**Question 6.**

Describe the purpose of BuildKit.

**Question 7.**

Distinguish BuildKit from Buildx.

**Question 8.**

Explain why Dockerfile instruction ordering affects cache reuse.

**Question 9.**

Describe the purpose of `.dockerignore`.

**Question 10.**

Explain why deleting files in a later filesystem layer does not necessarily reduce the image's total size.

**Question 11.**

Describe the purpose of BuildKit cache mounts.

**Question 12.**

Explain how an external cache can benefit continuous integration.

**Question 13.**

Distinguish image tags from digest references.

**Question 14.**

Explain why multi-stage builds alone do not guarantee reproducible artifacts.

**Question 15.**

Describe the benefits and limitations of non-root execution in a scratch-based image.

---

# 91. PART C — COMMAND INTERPRETATION

Analyze:

```bash
docker build --target test -t academic:test .
```

Answer:

1. What stage is selected?
2. Why might the command be used in a build pipeline?
3. Does this necessarily produce the intended production runtime image?

Analyze:

```bash
docker buildx build --load -t academic:local .
```

Answer:

4. What build interface is used?
5. What does `--load` request?
6. Why may this option be necessary with some builder configurations?

Analyze:

```dockerfile
COPY --from=build /out/server /server
```

Answer:

7. Where does the source file originate?
8. Where is it placed?
9. Does this copy every file from the build stage?

Analyze:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /out/server .
```

Answer:

10. What is the purpose of the cache mount?
11. Is the cache directory automatically copied into the final runtime image?
12. Why must the build remain correct when the cache is empty?

---

# 92. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Oversized Go Image

An application image contains the complete Go compiler and SDK, even though the deployed service requires only a compiled executable.

Explain the problem.

Propose a multi-stage Dockerfile architecture.

## Case Study 2 — Slow Python Rebuilds

A Python Dockerfile copies all source files before installing requirements.

Every source change causes dependency installation work to be repeated.

Explain the caching problem.

Recommend a more efficient instruction order.

## Case Study 3 — Failed Scratch Deployment

A dynamically linked executable is copied into scratch.

The container fails during startup.

Explain a likely cause.

Describe how to determine which runtime components are missing.

## Case Study 4 — Cache Does Not Improve Build Time

A team uses BuildKit cache mounts.

However, every build retrieves dependencies from the network.

Investigate:

- Cache directory selection.
- Package-manager behavior.
- Builder persistence.
- Build context.
- Cache sharing.
- Cache invalidation.

## Case Study 5 — Mutable Base Image

An organization builds an image twice using the same Dockerfile.

The base image tag was updated between builds.

The resulting images differ.

Explain why.

Discuss digest pinning and its maintenance consequences.

## Case Study 6 — Missing Image After Buildx

A developer runs Buildx using a container-based builder.

The build completes successfully.

The image does not appear in the local Docker image list.

Explain the likely cause and identify an appropriate output option.

---

# 93. PRACTICAL ASSESSMENT

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Image engineering theory | 15 |
| Baseline image construction | 10 |
| Multi-stage Dockerfile construction | 20 |
| BuildKit and cache configuration | 15 |
| Functional testing | 15 |
| Image measurement and comparison | 10 |
| Reproducibility and security analysis | 10 |
| Technical documentation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

Successful completion requires an optimized image that operates correctly and a technically accurate explanation of how its construction differs from the baseline.

---

# 94. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Comparative Image Engineering Using Docker Multi-Stage Builds and BuildKit

Prepare an academic report of approximately 1,400–1,900 words addressing:

**“Optimization of Container Image Construction: Multi-Stage Builds, BuildKit Caching, Runtime Dependency Isolation, and Reproducibility.”**

The report must include:

1. Introduction to image engineering.
2. Explanation of build-time and runtime dependencies.
3. Discussion of layered image architecture.
4. Analysis of single-stage build limitations.
5. Explanation of multi-stage Dockerfiles.
6. Discussion of scratch images.
7. Explanation of BuildKit.
8. Explanation of Buildx.
9. Analysis of cache invalidation.
10. Discussion of Dockerfile instruction ordering.
11. Explanation of build-context reduction.
12. Analysis of `.dockerignore`.
13. Discussion of cache mounts.
14. Explanation of external build caches.
15. Analysis of reproducibility.
16. Discussion of image security.
17. Comparison of baseline and optimized image measurements.
18. Evaluation of practical laboratory results.
19. Technical conclusion.

The report must contain at least one multi-stage architecture diagram and a table comparing the two constructed images.

---

# 95. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 16, verify the following.

## Image Architecture

- [ ] I can define a container image layer.
- [ ] I understand build-time dependencies.
- [ ] I understand runtime dependencies.
- [ ] I can explain why an SDK may be unnecessary at runtime.
- [ ] I can explain why later file deletion may not reduce layer size.

## Multi-Stage Builds

- [ ] I can write a Dockerfile with multiple stages.
- [ ] I can name build stages.
- [ ] I can use `COPY --from`.
- [ ] I can select a build target.
- [ ] I can distinguish build, test, and runtime stages.
- [ ] I understand the purpose of scratch.
- [ ] I understand static and dynamic linking.

## BuildKit

- [ ] I can define BuildKit.
- [ ] I can define Buildx.
- [ ] I can inspect available builders.
- [ ] I understand build cache reuse.
- [ ] I can identify cache invalidation.
- [ ] I can configure cache mounts.
- [ ] I understand external cache concepts.
- [ ] I can explain cache import and export.

## Build Context

- [ ] I can identify the build context.
- [ ] I can create `.dockerignore`.
- [ ] I can exclude unnecessary files.
- [ ] I understand how context changes affect caching.
- [ ] I understand the risks of copying sensitive files.

## Runtime Image

- [ ] I can create a minimal runtime image.
- [ ] I can configure a numeric non-root user.
- [ ] I can expose a container service port.
- [ ] I can verify application startup.
- [ ] I can test HTTP endpoints.
- [ ] I understand why scratch has no shell.

## Reproducibility

- [ ] I can distinguish tags and digests.
- [ ] I can explain dependency pinning.
- [ ] I can identify build-time metadata.
- [ ] I understand platform-dependent builds.
- [ ] I understand why identical Dockerfiles do not always guarantee byte-identical output.

## Practical Laboratory

- [ ] I created the Go application.
- [ ] I created automated tests.
- [ ] I built the baseline image.
- [ ] I built the optimized image.
- [ ] I verified the test stage.
- [ ] I measured both images.
- [ ] I inspected image history.
- [ ] I tested both HTTP applications.
- [ ] I verified non-root runtime configuration.
- [ ] I inspected the build stage.
- [ ] I examined cache reuse.
- [ ] I modified source and rebuilt.
- [ ] I changed build metadata.
- [ ] I inspected build cache storage.
- [ ] I verified build context exclusions.
- [ ] I produced a technical comparison.
- [ ] I completed the academic assessment.

**Completion standard:**

The student should be able to construct a tested multi-stage Docker image, explain the relationship between build and runtime environments, analyze cache reuse, measure image optimization results, and evaluate the resulting artifact's suitability for deployment.

---

# 96. LECTURE SUMMARY

Lecture 15 introduces Docker image construction as a systematic engineering discipline.

Container images should contain the software required to execute an application without unnecessarily retaining the tools used to build it.

Single-stage Dockerfiles are often convenient but may produce images containing compilers, development tools, source files, and intermediate artifacts.

Multi-stage builds separate these responsibilities through independent build stages.

The build stage creates application artifacts.

The test stage verifies selected behavior.

The runtime stage includes only the required execution components.

BuildKit improves the construction process through build dependency analysis, caching, parallelizable execution, temporary mounts, and external cache support.

Dockerfile instruction ordering influences cache efficiency.

The build context and `.dockerignore` determine which local files are made available to the builder.

Cache mounts can preserve reusable package-manager and compiler data without adding those caches to the runtime image.

External caches support reuse across build environments.

Reproducibility requires broader controls involving base images, dependencies, toolchains, platforms, and build metadata.

The Go laboratory demonstrates these principles through direct comparison.

The baseline image includes the Go development environment.

The optimized image uses a multi-stage build and a scratch runtime containing the compiled executable.

Both images provide the same required HTTP functionality.

Their construction, size, tooling, and operational characteristics differ substantially.

**The central principle of this lecture is that production-quality Docker images should be engineered to separate build requirements from runtime requirements while preserving correctness, maintainability, cache efficiency, and appropriate security controls.**

---

# 97. REFERENCES AND RECOMMENDED READING

## Docker Image Construction

[1] Docker Inc. *Multi-Stage Builds.*  
https://docs.docker.com/build/building/multi-stage/

[2] Docker Inc. *Building Best Practices.*  
https://docs.docker.com/build/building/best-practices/

[3] Docker Inc. *Dockerfile Reference.*  
https://docs.docker.com/reference/dockerfile/

[4] Docker Inc. *Docker Base Images.*  
https://docs.docker.com/build/building/base-images/

## BuildKit and Buildx

[5] Docker Inc. *BuildKit.*  
https://docs.docker.com/build/buildkit/

[6] Docker Inc. *Docker Builders.*  
https://docs.docker.com/build/builders/

[7] Docker Inc. *Docker Buildx Reference.*  
https://docs.docker.com/reference/cli/docker/buildx/

[8] Docker Inc. *Buildx Build Command.*  
https://docs.docker.com/reference/cli/docker/buildx/build/

## Build Cache

[9] Docker Inc. *Optimize Cache Usage.*  
https://docs.docker.com/build/cache/optimize/

[10] Docker Inc. *Build Cache Invalidation.*  
https://docs.docker.com/build/cache/invalidation/

[11] Docker Inc. *Cache Storage Backends.*  
https://docs.docker.com/build/cache/backends/

[12] Docker Inc. *Registry Cache.*  
https://docs.docker.com/build/cache/backends/registry/

[13] Docker Inc. *Inline Cache.*  
https://docs.docker.com/build/cache/backends/inline/

## Build Configuration and Security

[14] Docker Inc. *Build Variables.*  
https://docs.docker.com/build/building/variables/

[15] Docker Inc. *Build Secrets.*  
https://docs.docker.com/build/building/secrets/

[16] Docker Inc. *Build Policies and Reproducibility.*  
https://docs.docker.com/build/policies/examples/

## Go Application Development

[17] The Go Authors. *Go Documentation.*  
https://go.dev/doc/

[18] The Go Authors. *The Go Command.*  
https://pkg.go.dev/cmd/go

[19] The Go Authors. *The net/http Package.*  
https://pkg.go.dev/net/http

[20] The Go Authors. *The embed Package.*  
https://pkg.go.dev/embed

## Recommended Reading Sequence

Begin with references [1] through [4] to establish the principles of multi-stage image construction.

Continue with references [5] through [8] to understand BuildKit and Buildx architecture.

References [9] through [13] explain caching and build performance optimization.

References [14] through [16] introduce reproducibility and secure handling of build inputs.

Finally, references [17] through [20] provide the programming background for the practical Go laboratory.

---

# 98. FINAL LECTURE CONCLUSION

Advanced Docker image engineering represents an important transition from constructing functional application containers to producing controlled deployment artifacts.

An application image should be designed according to the requirements of its runtime environment.

The software used to compile, package, test, or generate an application is not necessarily required after those activities are complete.

Multi-stage builds allow these different responsibilities to be separated within a single Dockerfile.

The Go application laboratory demonstrates how the compiler and source code can remain in intermediate build stages while the final runtime image contains only the compiled application.

BuildKit provides additional mechanisms for improving construction efficiency.

Dependency-aware caching reduces unnecessary work.

Cache mounts preserve reusable build data.

External cache backends support repeated builds across different environments.

Context exclusions prevent unrelated files from participating unnecessarily in the build.

The resulting optimized image can provide the same application functionality as a much larger baseline image.

However, optimization must be evaluated alongside operational requirements.

Minimal images may lack shells, certificates, timezone information, shared libraries, and debugging tools.

These limitations must be understood rather than discovered accidentally during deployment.

Reproducibility also requires more than a well-organized Dockerfile.

Base image identity, dependency versions, build metadata, compiler versions, and execution platforms may influence the resulting artifact.

Finally, image minimization and build correctness do not replace security engineering.

The application must still be maintained, inspected, configured appropriately, and protected against vulnerabilities.

These considerations lead directly to Lecture 16, which will examine container image security, least privilege, secret management, Linux capabilities, and vulnerability assessment.

---

**END OF LECTURE 15**

**Next Lecture:** Lecture 16 — Docker Image and Container Security: Non-Root Execution, Least Privilege, Linux Capabilities, Secret Management, Vulnerability Scanning, and Supply-Chain Security.
