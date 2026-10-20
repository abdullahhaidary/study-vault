# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 06 — ADVANCED DOCKERFILE INSTRUCTIONS, BUILD-TIME AND RUNTIME CONFIGURATION, IMAGE OPTIMIZATION, AND DOCKERFILE BEST PRACTICES

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 06 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Lecture 01 — Introduction to Docker and Containerization Technology.
- Lecture 02 — Docker Containers and Lifecycle Management.
- Lecture 03 — Container Inspection and Runtime Diagnostics.
- Lecture 04 — Docker Images, Layers, and Registries.
- Lecture 05 — Dockerfile Fundamentals and Custom Image Construction.
- Elementary understanding of operating-system processes, environment variables, and filesystem permissions.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Explain the role of advanced Dockerfile instructions in container image construction.
2. Distinguish between build-time configuration and runtime configuration.
3. Explain the purpose and operation of the `ENTRYPOINT` instruction.
4. Analyze the interaction between `ENTRYPOINT` and `CMD`.
5. Distinguish shell-form and exec-form instruction syntax.
6. Explain the significance of PID 1 and Unix signal handling.
7. Define Docker build arguments and explain the `ARG` instruction.
8. Describe the purpose and behavior of the `ENV` instruction.
9. Explain the differences between `ARG` and `ENV`.
10. Describe the scope and lifetime of build arguments.
11. Explain Dockerfile variable substitution.
12. Describe the additional functionality provided by `ADD`.
13. Compare `ADD` and `COPY`.
14. Explain the `USER` instruction and its relationship to filesystem permissions.
15. Apply ownership and permission options to copied files.
16. Explain the purpose of the `LABEL` instruction.
17. Describe the roles of `SHELL`, `VOLUME`, `STOPSIGNAL`, `HEALTHCHECK`, and `ONBUILD`.
18. Explain why container running status is not equivalent to application health.
19. Identify factors influencing Docker build caching.
20. Describe build cache invalidation and cache optimization.
21. Explain the use of temporary build mounts.
22. Describe how BuildKit secret mounts differ from build arguments.
23. Explain the foundations of multi-stage image construction.
24. Construct a Dockerfile using multiple build stages.
25. Develop an application image that executes using a non-root user.
26. Inspect image metadata and verify runtime configuration.
27. Analyze common Dockerfile design errors.
28. Apply fundamental security, efficiency, and reproducibility principles.
29. Complete a practical laboratory involving advanced Dockerfile operations.

---

# 2. INTRODUCTION TO ADVANCED DOCKERFILE CONFIGURATION

## 2.1 Background

The preceding lecture introduced the fundamental Dockerfile instructions used to construct container images.

These included:

- `FROM`
- `WORKDIR`
- `COPY`
- `RUN`
- `CMD`
- `EXPOSE`

These instructions are sufficient to construct many simple images.

However, production-oriented applications frequently require more sophisticated configuration.

For example, an application may require:

- A designated executable that should always be started.
- Configurable startup arguments.
- Build-time version selection.
- Persistent runtime environment variables.
- Execution under a restricted user identity.
- Explicit file ownership.
- Health monitoring.
- Controlled process termination.
- Metadata describing the image.
- Optimization of dependency installation.
- Separation of compilation tools from runtime artifacts.

Advanced Dockerfile instructions provide mechanisms for addressing these requirements.

## 2.2 Build-Time Configuration Versus Runtime Configuration

Docker image construction and container execution are distinct phases.

**Build time** refers to the period during which the image builder executes instructions and assembles image content.

**Runtime** refers to the period during which a container instance executes processes using a constructed image.

The distinction can be represented as:

```text
         APPLICATION SOURCE
                 |
                 v
             DOCKERFILE
                 |
                 v
            BUILD PHASE
                 |
          RUN / ARG / COPY
                 |
                 v
             IMAGE
                 |
                 v
           RUNTIME PHASE
                 |
       ENTRYPOINT / CMD / ENV
                 |
                 v
          RUNNING APPLICATION
```

This representation is simplified.

Some instructions, particularly `ENV` and `USER`, affect both subsequent build operations and the configuration inherited by running containers.

The essential principle is that some instructions perform operations during image construction, while others define parameters for later container execution.

## 2.3 Configuration Versus Execution

A Dockerfile instruction may produce one of several effects.

**Filesystem modification:** Changes the content represented by the image.

**Image metadata modification:** Changes the image's configuration without necessarily changing its filesystem.

**Build environment modification:** Influences subsequent build operations.

**Runtime configuration:** Establishes default behavior when containers start.

For example:

```dockerfile
RUN mkdir /app
```

performs a build-time operation.

```dockerfile
ENV APP_MODE=production
```

establishes an environment variable for subsequent build operations and the resulting image.

```dockerfile
ENTRYPOINT ["python", "app.py"]
```

specifies an executable to run when the container starts.

Correct Dockerfile design requires understanding these different categories of behavior.

---

# 3. THE ENTRYPOINT INSTRUCTION

## 3.1 Definition

The `ENTRYPOINT` instruction specifies an executable or startup command that forms the principal execution behavior of containers created from an image.

**Formal definition:**

`ENTRYPOINT` is a Dockerfile instruction that configures the executable and optional fixed arguments used as the primary command when a container is started.

The instruction is especially useful for images designed to perform a particular function.

Examples include:

- Web server images.
- Database server images.
- Command-line utility images.
- Application server images.
- Background processing applications.

## 3.2 Basic Syntax

Docker supports two principal forms.

**Exec form:**

```dockerfile
ENTRYPOINT ["executable", "argument1", "argument2"]
```

**Shell form:**

```dockerfile
ENTRYPOINT command argument1 argument2
```

The two forms have different execution semantics.

## 3.3 Exec Form

Consider:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY app.py .

ENTRYPOINT ["python", "app.py"]
```

The resulting image is configured to execute:

```text
python app.py
```

when a container starts.

The executable and arguments are represented as a JSON array.

The exec form does not automatically invoke an intermediate command shell.

This provides more explicit command execution behavior.

## 3.4 Shell Form

Consider:

```dockerfile
FROM alpine:3.20

ENTRYPOINT echo "Container started"
```

The shell form executes the command through the configured command shell.

For a conventional Linux image, the default shell is commonly:

```text
/bin/sh -c
```

The shell interprets the command string.

This allows shell features such as:

- Variable expansion.
- Pipes.
- Redirection.
- Command chaining.

However, shell-form execution may introduce complications involving process identity and signal propagation.

## 3.5 ENTRYPOINT and Container Purpose

An image with an entrypoint commonly behaves like a packaged executable.

For example:

```dockerfile
FROM alpine:3.20

ENTRYPOINT ["echo"]
```

If a container is started with:

```bash
docker run --rm my-echo-image "Hello Docker"
```

the additional argument is passed to the configured entrypoint.

The effective command becomes:

```text
echo "Hello Docker"
```

This demonstrates that the image can provide a fixed executable while allowing callers to supply arguments.

## 3.6 Overriding ENTRYPOINT

Docker allows the configured entrypoint to be overridden at container creation.

Example:

```bash
docker run --rm --entrypoint sh my-image
```

The `--entrypoint` option replaces the executable specified by the image's entrypoint configuration.

The replacement executable must be available in the container environment.

This capability is useful for diagnostics and special-purpose execution.

However, replacing an entrypoint may bypass initialization behavior expected by the application image.

---

# 4. ENTRYPOINT VERSUS CMD

## 4.1 Fundamental Difference

Both `ENTRYPOINT` and `CMD` influence container startup behavior.

Their intended roles are different.

**ENTRYPOINT:** Defines the executable or primary command that the container is configured to run.

**CMD:** Defines a default command or default arguments, depending on whether an entrypoint is configured.

The distinction becomes particularly important when both are used together.

## 4.2 Combined Configuration

Consider:

```dockerfile
FROM python:3.12-slim

ENTRYPOINT ["python", "-m", "http.server"]

CMD ["8000"]
```

The entrypoint specifies the executable and Python module.

The `CMD` instruction supplies the default port argument.

When the container starts without additional command arguments, the effective command becomes:

```text
python -m http.server 8000
```

## 4.3 Overriding Default Arguments

Suppose the image is named:

`academic-http:v1`

Execute:

```bash
docker run --rm academic-http:v1 9000
```

Because the image defines an exec-form entrypoint, the supplied argument replaces the default `CMD` arguments.

The effective command becomes:

```text
python -m http.server 9000
```

The configured entrypoint remains unchanged.

Only the default argument is replaced.

## 4.4 Command Resolution

Consider four possible configurations.

**Configuration A: CMD only**

```dockerfile
CMD ["python", "app.py"]
```

The default executable is Python.

Supplying an alternative command through `docker run` normally replaces the default command.

**Configuration B: ENTRYPOINT only**

```dockerfile
ENTRYPOINT ["python", "app.py"]
```

The executable is established by the entrypoint.

Additional command arguments are appended to the entrypoint.

**Configuration C: ENTRYPOINT and CMD**

```dockerfile
ENTRYPOINT ["python", "app.py"]

CMD ["--port", "8000"]
```

The default effective command is:

```text
python app.py --port 8000
```

**Configuration D: Overridden ENTRYPOINT**

A runtime `--entrypoint` option changes the executable to another selected program.

## 4.5 Comparison

| Characteristic               | ENTRYPOINT                                 | CMD                                         |
| ---------------------------- | ------------------------------------------ | ------------------------------------------- |
| Primary purpose              | Define principal executable                | Define default command or arguments         |
| Applied at runtime           | Yes                                        | Yes                                         |
| Runs during image build      | No                                         | No                                          |
| Normal command-line override | Additional arguments appended in exec form | Supplied command arguments replace defaults |
| Explicit override mechanism  | `--entrypoint`                             | Arguments after image reference             |
| Multiple instructions        | Last applicable instruction takes effect   | Last applicable instruction takes effect    |
| Common use                   | Dedicated application image                | Default behavior and parameters             |

## 4.6 Important Interaction Rules

When combining `ENTRYPOINT` and `CMD`, using exec form for both is generally recommended.

For example:

```dockerfile
ENTRYPOINT ["python", "server.py"]

CMD ["--port", "8000"]
```

This produces predictable argument handling.

Shell-form entrypoints behave differently.

In particular, shell-form entrypoints generally do not append command-line arguments in the same manner as exec-form entrypoints.

A new `ENTRYPOINT` instruction may also reset a `CMD` inherited from a base image.

Therefore, inheritance and command resolution should be inspected rather than assumed.

---

# 5. SHELL FORM VERSUS EXEC FORM

## 5.1 Shell Form

Example:

```dockerfile
RUN echo "Hello Docker"
```

A command shell interprets the instruction.

Shell-form execution supports command-language features.

For example:

```dockerfile
RUN mkdir -p /app && echo "Ready" > /app/status.txt
```

The `&&` operator and redirection are interpreted by the shell.

## 5.2 Exec Form

Example:

```dockerfile
RUN ["echo", "Hello Docker"]
```

Exec form represents the command and its arguments as a JSON array.

It does not automatically provide shell interpretation.

For example:

```dockerfile
RUN ["echo", "$HOME"]
```

does not perform ordinary shell variable expansion.

The literal argument `$HOME` is passed to the executable.

## 5.3 Explicit Shell Execution

Shell behavior can be requested through exec form.

Example:

```dockerfile
RUN ["sh", "-c", "echo $HOME"]
```

In this case, the `sh` executable interprets the supplied command.

## 5.4 The Importance of Signal Handling

Unix-like operating systems use signals to communicate events to processes.

Important signals include:

- `SIGTERM`: Request process termination.
- `SIGINT`: Interrupt a process.
- `SIGKILL`: Force process termination.
- `SIGHUP`: Commonly used for terminal disconnection or configuration reload behavior.

When Docker stops a container, it ordinarily sends the configured stop signal to the principal process.

If the application runs as a child of a shell that does not forward signals appropriately, graceful shutdown may fail.

## 5.5 PID 1

The initial process in a typical Linux container PID namespace commonly has PID 1.

PID 1 has special process-management behavior.

Container applications should be configured so that termination signals reach the appropriate application process.

The exec form of `ENTRYPOINT` is generally preferred because it avoids an unnecessary shell layer and provides more direct process execution.

## 5.6 The Shell exec Command

When shell execution is necessary, a shell can replace itself with another executable through the `exec` command.

Example:

```dockerfile
ENTRYPOINT exec python app.py
```

This can improve signal delivery by replacing the shell with the application process.

Nevertheless, exec-form instructions are usually clearer when shell functionality is unnecessary.

---

# 6. THE ENV INSTRUCTION

## 6.1 Definition

The `ENV` instruction establishes environment variables within an image build stage and records their resulting values in the image's runtime configuration.

**Formal definition:**

`ENV` is a Dockerfile instruction that defines named environment variables available to subsequent build operations and, unless overridden, to processes started from the resulting image.

## 6.2 Syntax

```dockerfile
ENV VARIABLE=value
```

Example:

```dockerfile
ENV APP_MODE=production
```

Multiple variables may also be declared:

```dockerfile
ENV APP_MODE=production \
    APP_PORT=8000
```

## 6.3 Environment Variables During Build

Consider:

```dockerfile
FROM alpine:3.20

ENV COURSE_NAME=Docker

RUN echo "$COURSE_NAME"
```

The `RUN` instruction can access the configured environment variable.

The build output may display:

```text
Docker
```

## 6.4 Runtime Persistence

Environment variables defined using `ENV` generally remain available to processes in containers created from the image.

Consider:

```dockerfile
FROM alpine:3.20

ENV APP_MODE=production

CMD ["env"]
```

Running the container displays its environment variables, including:

```text
APP_MODE=production
```

## 6.5 Runtime Overrides

A user can supply an alternative environment variable value when creating a container.

Example:

```bash
docker run --rm -e APP_MODE=development my-image
```

The runtime-supplied value overrides the image's default value for that container.

The underlying image is not modified.

## 6.6 Environment Variable Uses

Environment variables are commonly used for:

1. Application mode selection.
2. Logging configuration.
3. Runtime-specific behavior.
4. Service addresses.
5. Application paths.
6. Language runtime settings.
7. Feature configuration.

However, environment variables should not automatically be treated as secure storage for confidential information.

---

# 7. THE ARG INSTRUCTION

## 7.1 Definition

The `ARG` instruction defines a variable that can be supplied to the Docker image builder during construction.

**Formal definition:**

`ARG` is a Dockerfile instruction that declares a build-time variable whose value can influence subsequent applicable build operations.

## 7.2 Syntax

```dockerfile
ARG VARIABLE_NAME
```

A default value can also be specified:

```dockerfile
ARG APP_VERSION=1.0
```

## 7.3 Supplying Build Arguments

Consider:

```dockerfile
FROM alpine:3.20

ARG APP_VERSION=1.0

RUN echo "Building version $APP_VERSION"
```

The image may be built using the default value:

```bash
docker build -t my-app:v1 .
```

Alternatively:

```bash
docker build --build-arg APP_VERSION=2.0 -t my-app:v2 .
```

The second command supplies a different build-time value.

## 7.4 ARG Lifetime

Build arguments are primarily associated with image construction.

Unlike `ENV`, an `ARG` declaration does not automatically create a persistent runtime environment variable.

For example:

```dockerfile
FROM alpine:3.20

ARG BUILD_VERSION=1.0

CMD ["env"]
```

The `BUILD_VERSION` value is not automatically included as a runtime environment variable.

## 7.5 Important Security Qualification

The absence of an `ARG` value from the normal runtime environment does not make it confidential.

Build argument values may become visible through:

- Image history.
- Build metadata.
- Provenance attestations.
- Build logs.
- Files generated during construction.

Therefore, build arguments must not be used to transmit passwords, private keys, or other sensitive credentials.

---

# 8. ARG VERSUS ENV

## 8.1 Comparative Analysis

| Characteristic                                         | ARG                  | ENV                           |
| ------------------------------------------------------ | -------------------- | ----------------------------- |
| Principal purpose                                      | Build-time parameter | Build and runtime environment |
| Declared in Dockerfile                                 | Yes                  | Yes                           |
| Available to subsequent build operations               | Yes, within scope    | Yes                           |
| Automatically persists as runtime environment variable | No                   | Yes                           |
| Set through `--build-arg`                              | Yes                  | Not directly                  |
| Overridden through `docker run -e`                     | Not as an ARG        | Yes                           |
| Appropriate for secrets                                | No                   | No, not inherently            |
| Can affect build cache                                 | Yes                  | Yes                           |

## 8.2 Combining ARG and ENV

A common pattern is:

```dockerfile
FROM alpine:3.20

ARG APP_MODE=production

ENV APP_MODE=${APP_MODE}

CMD ["env"]
```

This permits the runtime environment value to be selected during image construction.

Build command:

```bash
docker build --build-arg APP_MODE=testing -t my-app:test .
```

The resulting image contains the runtime environment variable:

```text
APP_MODE=testing
```

The `ARG` supplies the build-time value.

The `ENV` persists the selected value in the image configuration.

## 8.3 ARG Scope

Build arguments have defined scopes.

An argument declared before the first `FROM` instruction is available for certain global build operations, including base-image selection.

However, it is not automatically available to commands inside every build stage.

Example:

```dockerfile
ARG BASE_VERSION=3.20

FROM alpine:${BASE_VERSION}

ARG BASE_VERSION

RUN echo "$BASE_VERSION"
```

The second `ARG` declaration makes the argument available within that stage.

## 8.4 ARG and Multi-Stage Builds

An argument declared within one build stage is not automatically available to all unrelated stages.

Stages based on a preceding stage can inherit declared arguments under Docker's stage-scoping rules.

For independently defined stages, the relevant argument may need to be declared again.

This behavior is important when using build arguments to select compiler versions, platform settings, or application release information.

---

# 9. DOCKERFILE VARIABLE SUBSTITUTION

## 9.1 Definition

Variable substitution is the process of replacing a variable reference with its corresponding value.

Docker supports variable substitution in several Dockerfile instructions.

Examples include:

```dockerfile
ARG APP_DIR=/app

WORKDIR ${APP_DIR}
```

The working directory is established using the supplied variable value.

## 9.2 Dockerfile-Level Substitution

The builder performs substitution in supported instruction fields.

For example:

```dockerfile
FROM alpine:3.20

ENV APP_DIR=/application

WORKDIR ${APP_DIR}
```

The builder interprets `${APP_DIR}` using the defined value.

## 9.3 Shell-Level Expansion

Shell commands also support variable expansion.

Example:

```dockerfile
RUN echo "$HOME"
```

Here, the command shell performs expansion.

This differs from Dockerfile frontend substitution.

## 9.4 Exec Form Limitations

Consider:

```dockerfile
CMD ["echo", "$HOME"]
```

The JSON-array form does not automatically invoke a shell.

Consequently, `$HOME` is not expanded through normal shell rules.

If shell expansion is required, the Dockerfile can explicitly invoke a shell.

Example:

```dockerfile
CMD ["sh", "-c", "echo \"$HOME\""]
```

Understanding which component performs expansion is necessary to avoid configuration errors.

---

# 10. THE ADD INSTRUCTION

## 10.1 Definition

The `ADD` instruction introduces files or directories into the image filesystem.

It resembles `COPY`, but supports additional source types and behaviors.

**Formal definition:**

`ADD` is a Dockerfile instruction that incorporates local or supported remote resources into a build-stage filesystem, including certain automatic archive-extraction capabilities.

## 10.2 Basic Syntax

```dockerfile
ADD source destination
```

Example:

```dockerfile
ADD application.txt /app/
```

For ordinary local files, this resembles the behavior of `COPY`.

## 10.3 Local Archive Extraction

One important feature of `ADD` is automatic extraction of recognized local archive formats.

Example:

```dockerfile
FROM alpine:3.20

ADD application.tar.gz /app/
```

When the source is a recognized local tar archive, Docker extracts its contents into the destination directory.

This behavior is different from ordinary `COPY`.

## 10.4 COPY Behavior

Consider:

```dockerfile
COPY application.tar.gz /app/
```

This copies the archive file into the image.

It does not automatically extract the archive.

## 10.5 Remote Sources

`ADD` supports certain remote sources, including HTTP or HTTPS resources and Git repositories.

However, remote-source behavior depends on the source type and Dockerfile syntax.

In particular, local tar archive extraction should not be generalized to mean that every remote archive is automatically extracted.

## 10.6 ADD Versus COPY

| Characteristic                                      | COPY                                     | ADD                        |
| --------------------------------------------------- | ---------------------------------------- | -------------------------- |
| Copy local files                                    | Yes                                      | Yes                        |
| Copy directories                                    | Yes                                      | Yes                        |
| Automatically extract recognized local tar archives | No                                       | Yes                        |
| Support certain remote URLs                         | Not through ordinary local-source syntax | Yes                        |
| Basic behavior                                      | Explicit file copying                    | Additional source handling |
| Preferred for simple local file copying             | Generally yes                            | Usually unnecessary        |

## 10.7 Recommended Practice

Use `COPY` when the requirement is simply to include local application files.

Use `ADD` when its additional functionality is intentionally required.

Unnecessary use of `ADD` can make the build's behavior less obvious.

---

# 11. THE USER INSTRUCTION

## 11.1 Definition

The `USER` instruction defines the user and optionally the group under which subsequent applicable build commands and the resulting container process execute.

**Formal definition:**

`USER` is a Dockerfile instruction that establishes the default execution identity for later applicable build operations and container runtime processes.

## 11.2 Syntax

```dockerfile
USER username
```

Or:

```dockerfile
USER UID:GID
```

Example:

```dockerfile
USER 10001:10001
```

## 11.3 Default Root Execution

Many base images initially configure execution as the root user.

Root is the conventional Unix account associated with user identifier zero.

Running applications as root may provide more permissions than the application requires.

Although container security mechanisms can restrict root capabilities, unnecessary root execution should generally be avoided.

## 11.4 Non-Root Execution

Example:

```dockerfile
FROM alpine:3.20

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

USER appuser

CMD ["id"]
```

This example creates an application group and user using Alpine-supported account-management utilities.

The resulting container uses the configured application identity by default.

## 11.5 Numeric User Identifiers

An alternative approach uses numeric identifiers.

Example:

```dockerfile
USER 10001:10001
```

A numeric identity can be used even when the corresponding username is not defined in the container's `/etc/passwd` file.

However, some applications require valid user-database entries or a writable home directory.

Therefore, numeric-user execution should be tested against the application's actual requirements.

## 11.6 Filesystem Permissions

Changing the execution user does not automatically change ownership of application files.

For example:

```dockerfile
WORKDIR /app

COPY . /app

USER 10001:10001
```

may produce permission problems if the application needs to write to files or directories owned by another identity.

The filesystem must be configured appropriately.

This introduces the importance of `COPY --chown`.

---

# 12. ADVANCED COPY OPTIONS

## 12.1 COPY --chown

Docker supports ownership configuration for copied files on supported Linux image builds.

Example:

```dockerfile
COPY --chown=10001:10001 app.py /app/app.py
```

This sets the ownership of the copied content.

The user and group may be specified through names or numeric identifiers.

Numeric identifiers avoid dependence on user and group name resolution.

## 12.2 COPY --chmod

Docker also supports setting permissions on copied files.

Example:

```dockerfile
COPY --chmod=644 config.txt /app/config.txt
```

The numeric value `644` represents a conventional Unix permission mode.

It commonly permits:

- Owner: read and write.
- Group: read.
- Others: read.

## 12.3 Executable Permissions

A script intended for direct execution may require execute permission.

Example:

```dockerfile
COPY --chmod=755 start.sh /app/start.sh
```

The permission mode `755` commonly grants:

- Owner: read, write, execute.
- Group: read, execute.
- Others: read, execute.

## 12.4 Ownership and Security

Correct file ownership supports least-privilege execution.

However, changing ownership or permissions must be consistent with application requirements.

Granting broad write access to application directories may reduce security.

The objective is to provide the minimum required access rather than unrestricted filesystem modification.

---

# 13. THE LABEL INSTRUCTION

## 13.1 Definition

The `LABEL` instruction adds metadata to a container image.

Labels are represented as key-value pairs.

**Formal definition:**

`LABEL` is a Dockerfile instruction that records descriptive metadata in the image configuration without directly establishing an application execution process.

## 13.2 Syntax

```dockerfile
LABEL key=value
```

Example:

```dockerfile
LABEL version="1.0"
```

Multiple labels may be declared:

```dockerfile
LABEL org.opencontainers.image.title="Academic Docker Application" \
      org.opencontainers.image.version="1.0"
```

## 13.3 Applications

Labels may describe:

- Application title.
- Software version.
- Maintainer information.
- Project documentation.
- Source repository.
- Licensing information.
- Build-related metadata.

## 13.4 OCI Annotation Keys

The Open Container Initiative defines conventional metadata keys that can be used for image-related descriptions.

Examples include:

- `org.opencontainers.image.title`
- `org.opencontainers.image.description`
- `org.opencontainers.image.version`
- `org.opencontainers.image.source`
- `org.opencontainers.image.licenses`

Use of standard metadata keys improves interoperability and consistency.

## 13.5 Inspecting Labels

Example:

```bash
docker image inspect --format '{{json .Config.Labels}}' my-image:v1
```

This retrieves the labels recorded in the image configuration.

---

# 14. THE SHELL INSTRUCTION

## 14.1 Definition

The `SHELL` instruction changes the default shell used by shell-form instructions.

## 14.2 Syntax

```dockerfile
SHELL ["executable", "parameter"]
```

Example:

```dockerfile
SHELL ["/bin/sh", "-c"]
```

This specifies the shell used for subsequent shell-form instructions.

## 14.3 Why SHELL Matters

Different shells support different language features.

For example:

- Bash supports certain extensions not provided by basic POSIX shells.
- PowerShell uses a different command language.
- Windows command execution differs from Linux shell execution.

An image may therefore require a particular shell for its build commands.

## 14.4 Shell Availability

A `SHELL` instruction does not install the selected shell.

For example:

```dockerfile
SHELL ["/bin/bash", "-c"]
```

requires Bash to exist in the image filesystem.

If Bash is unavailable, subsequent shell-form operations may fail.

---

# 15. THE VOLUME INSTRUCTION

## 15.1 Definition

The `VOLUME` instruction declares a filesystem path intended to be used as a container volume mount point.

Example:

```dockerfile
VOLUME /data
```

## 15.2 Purpose

Volume declarations identify locations associated with data storage.

For example, an application image might designate `/data` as a location for application-generated files.

## 15.3 Runtime Behavior

A volume declaration can cause Docker to create an anonymous volume when a container is instantiated without another mount assigned to that destination.

Consequently, the path's data-management behavior may differ from an ordinary container writable-layer directory.

## 15.4 VOLUME Limitations

The instruction does not establish a complete backup strategy.

It does not automatically configure replication or external storage.

It also does not give the image author direct control over the host path used for an automatically created anonymous volume.

Persistent storage and Docker volumes will be studied comprehensively during Lecture 09.

---

# 16. THE STOPSIGNAL INSTRUCTION

## 16.1 Definition

The `STOPSIGNAL` instruction specifies the signal Docker should send when requesting termination of the container's principal process.

Example:

```dockerfile
STOPSIGNAL SIGTERM
```

## 16.2 Signal Handling

During a normal stop operation, Docker sends the configured stop signal.

The application is expected to handle the signal appropriately.

For example, it may:

1. Stop accepting new requests.
2. Complete active operations.
3. Flush buffered data.
4. Close resources.
5. Terminate its processes.

## 16.3 Forced Termination

If the application does not terminate within the permitted grace period, Docker may force termination.

Therefore, graceful shutdown depends on both Docker configuration and application behavior.

## 16.4 Runtime Override

The image's configured stop signal can be overridden through supported runtime options.

This provides additional flexibility for applications with special termination requirements.

---

# 17. THE HEALTHCHECK INSTRUCTION

## 17.1 Definition

The `HEALTHCHECK` instruction defines a command used to evaluate whether a running container's application is functioning according to a specified condition.

**Formal definition:**

`HEALTHCHECK` is a Dockerfile instruction that configures periodic runtime tests whose results contribute to a container's recorded health status.

## 17.2 Why Health Checks Are Necessary

A container can remain in the running state even when its application is malfunctioning.

For example, a web server process may remain active while failing to respond correctly to HTTP requests.

Therefore:

**Container running status is not equivalent to application health.**

Health checks provide an additional observational mechanism.

## 17.3 Basic Syntax

```dockerfile
HEALTHCHECK CMD command
```

A health check can include timing and retry options.

Example:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost/ || exit 1
```

This example assumes that `curl` is installed.

If the executable is missing, the health check cannot perform its intended test.

## 17.4 Common Health States

Docker commonly reports:

**Starting:** The health check has not yet established a successful or failed steady-state result.

**Healthy:** The configured test is succeeding.

**Unhealthy:** The configured test has failed according to the applicable retry criteria.

## 17.5 Health Check Exit Codes

For ordinary health checks:

- Exit code `0` indicates success.
- Exit code `1` indicates failure.
- Exit code `2` is reserved and should not be used.

The status is determined by the configured test rather than by a universal understanding of application correctness.

## 17.6 Health Check Options

| Option             | Purpose                                                            |
| ------------------ | ------------------------------------------------------------------ |
| `--interval`       | Time between scheduled checks                                      |
| `--timeout`        | Maximum allowed duration of one check                              |
| `--retries`        | Consecutive failures required for unhealthy status                 |
| `--start-period`   | Initialization period used in failure accounting                   |
| `--start-interval` | Optional check interval during startup, supported by newer engines |

## 17.7 Important Limitation

A health check does not automatically repair an application.

Likewise, a container becoming unhealthy does not, by itself, guarantee that Docker will restart the container.

Additional monitoring, orchestration, or remediation mechanisms may be required.

Health checks provide diagnostic state information.

They are not a complete self-healing system.

---

# 18. THE ONBUILD INSTRUCTION

## 18.1 Definition

The `ONBUILD` instruction registers a trigger that is executed when another Dockerfile uses the resulting image as a base image.

## 18.2 Syntax

```dockerfile
ONBUILD RUN command
```

Example:

```dockerfile
FROM alpine:3.20

ONBUILD RUN echo "Child image build triggered"
```

The registered instruction does not execute during the construction of this base image.

Instead, it is retained as a trigger for an appropriate descendant build.

## 18.3 Purpose

`ONBUILD` can be used to create reusable parent images intended to apply standardized build operations to descendant images.

Historically, this mechanism has been used in application build templates.

## 18.4 Limitations

Implicit build triggers can make image behavior more difficult to understand.

They may also impose assumptions on child images.

For this reason, `ONBUILD` should be used deliberately and documented carefully.

---

# 19. ADVANCED DOCKERFILE INSTRUCTION SUMMARY

| Instruction    | Main purpose                              | Primary phase                                     |
| -------------- | ----------------------------------------- | ------------------------------------------------- |
| `ENTRYPOINT`   | Define principal executable               | Runtime configuration                             |
| `CMD`          | Define default command or arguments       | Runtime configuration                             |
| `ENV`          | Define environment variables              | Build and runtime                                 |
| `ARG`          | Define build parameters                   | Build                                             |
| `ADD`          | Include supported local or remote content | Build                                             |
| `COPY --chown` | Copy content with selected ownership      | Build                                             |
| `COPY --chmod` | Copy content with selected permissions    | Build                                             |
| `USER`         | Define execution identity                 | Build and runtime                                 |
| `LABEL`        | Define image metadata                     | Image configuration                               |
| `SHELL`        | Select default shell                      | Build and possibly runtime command interpretation |
| `VOLUME`       | Declare volume mount points               | Image configuration and runtime                   |
| `STOPSIGNAL`   | Select container stop signal              | Runtime configuration                             |
| `HEALTHCHECK`  | Define application health tests           | Runtime monitoring configuration                  |
| `ONBUILD`      | Register descendant-build triggers        | Future build                                      |
| `WORKDIR`      | Establish working directory               | Build and runtime                                 |
| `RUN`          | Execute build operations                  | Build                                             |

---

# 20. DOCKER BUILD CACHE OPTIMIZATION

## 20.1 Review of Build Caching

Docker BuildKit can reuse previously computed results when the required inputs and relevant operation configuration have not changed.

This reduces repeated work.

However, Dockerfile organization influences how effectively the cache can be reused.

## 20.2 Cache Invalidation

A cached result may become invalid when:

- An instruction changes.
- Relevant copied files change.
- A required earlier build result changes.
- A base image changes.
- Relevant build arguments change.
- The required cached content is unavailable.

An invalidated operation may require dependent build operations to be reevaluated.

## 20.3 Inefficient Dockerfile Example

Consider a Python application:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

CMD ["python", "app.py"]
```

The `COPY . .` instruction introduces all included application files before dependency installation.

If application source files change, the copied filesystem content changes.

This can invalidate the following dependency-installation operation.

As a result, dependencies may be installed again even when the dependency list has not changed.

## 20.4 Improved Instruction Ordering

A more efficient structure is:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

CMD ["python", "app.py"]
```

The dependency manifest is copied first.

Dependencies are installed before the remaining application files are introduced.

When only application source code changes, the dependency installation step may reuse its cached result.

## 20.5 Dependency Stability

Cache optimization relies on separating inputs according to their frequency of change.

Relatively stable dependencies should generally be processed before frequently changing application files when doing so preserves correct build behavior.

This principle applies to many software ecosystems.

Examples include:

- Python dependency manifests.
- Node.js package manifests and lockfiles.
- Java dependency configuration.
- Go module files.
- Rust package manifests.

## 20.6 Cache Correctness

Build cache reuse must not be confused with ensuring that dependencies are current.

For example:

```dockerfile
RUN apt-get update && apt-get install -y package-name
```

may be reused from a previous cached result.

The passage of time does not automatically invalidate the operation.

Similarly, changing remote package repositories does not guarantee automatic cache invalidation.

Build maintenance may require explicit updates, controlled dependency versions, and deliberate cache invalidation.

---

# 21. BUILDKIT CACHE MOUNTS

## 21.1 Definition

A BuildKit cache mount is a temporary build-operation mount that provides access to a persistent cache directory managed by the builder.

It is commonly used to improve package-manager performance.

## 21.2 Example

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

The cache mount provides a reusable location for downloaded package data.

## 21.3 Layer Cache Versus Cache Mount

A regular build cache can reuse the entire result of an operation.

A cache mount can preserve reusable data even when the corresponding build operation must execute again.

For example, package-manager downloads may remain available through the cache mount after a dependency manifest changes.

## 21.4 Characteristics

Build cache mounts:

1. Exist within the builder's cache infrastructure.
2. May be reused across compatible builds.
3. Are not ordinary persistent runtime volumes.
4. Should not contain files required exclusively from the cache for correctness.
5. Can be removed through builder cache cleanup operations.

The final image should not depend on a cache mount continuing to exist after construction.

---

# 22. BUILDKIT SECRET MOUNTS

## 22.1 Definition

A build secret is sensitive information needed temporarily during image construction.

Examples include:

- Private package registry credentials.
- API authentication tokens.
- Repository access credentials.
- Certificate-related authentication material.

## 22.2 Why ARG and ENV Are Inappropriate

Build arguments may appear in image history, metadata, or provenance information.

Environment variables established using `ENV` persist in the image configuration.

Therefore, neither mechanism should be treated as secure secret storage.

## 22.3 Secret Mounts

BuildKit provides temporary secret mounts for individual build operations.

Example:

```dockerfile
# syntax=docker/dockerfile:1

FROM alpine:3.20

RUN --mount=type=secret,id=example_token \
    test -s /run/secrets/example_token
```

The instruction checks whether the expected secret file exists and contains data.

The secret is made available to the selected build operation.

It is not automatically incorporated into a final image layer.

## 22.4 Supplying a Secret

A secret can be passed from the build client using:

```bash
docker build --secret id=example_token,src=token.txt .
```

Here, `token.txt` represents a local file supplied for the build.

Actual sensitive files must be handled according to appropriate security policies.

## 22.5 Important Limitation

Secret mounts reduce the likelihood of exposing confidential data through ordinary image layers.

However, a build command can still explicitly copy, print, or transmit the contents of a secret.

Security therefore depends on how the build operation uses the secret.

The use of a secret mount does not guarantee confidentiality if the Dockerfile itself is malicious or incorrectly designed.

---

# 23. INTRODUCTION TO MULTI-STAGE BUILDS

## 23.1 Definition

A multi-stage build is an image-building technique in which a Dockerfile contains multiple build stages, each beginning with a `FROM` instruction.

Stages may serve different purposes.

For example:

- Compilation.
- Dependency preparation.
- Asset generation.
- Testing.
- Final runtime packaging.

**Formal definition:**

A multi-stage Docker build is a structured build process containing multiple image-construction stages through which selected artifacts can be transferred into a designated final image.

## 23.2 Motivation

Application compilation may require tools that are unnecessary at runtime.

For example, a compiled application may need:

- A compiler.
- Build libraries.
- Development utilities.
- Testing frameworks.
- Source code.

After compilation, the final application may require only:

- A compiled executable.
- Runtime libraries.
- Configuration files.

Including every development tool in the final image may increase image size and maintenance requirements.

## 23.3 Multi-Stage Architecture

```text
          APPLICATION SOURCE
                  |
                  v
           BUILD STAGE
        Compiler / Toolchain
                  |
                  v
          COMPILED ARTIFACT
                  |
                  | COPY --from
                  v
           RUNTIME STAGE
        Minimal Runtime Image
                  |
                  v
             FINAL IMAGE
                  |
                  v
              CONTAINER
```

## 23.4 Named Build Stages

Example:

```dockerfile
FROM alpine:3.20 AS preparation

RUN mkdir -p /output

RUN echo "Prepared artifact" > /output/info.txt

FROM alpine:3.20 AS runtime

COPY --from=preparation /output/info.txt /app/info.txt

CMD ["cat", "/app/info.txt"]
```

The first stage is named `preparation`.

The second stage is named `runtime`.

The final stage copies only the selected artifact from the first stage.

## 23.5 The COPY --from Option

The syntax:

```dockerfile
COPY --from=preparation /output/info.txt /app/info.txt
```

copies content from the specified build stage.

It does not copy the entire earlier stage into the final image.

This permits separation of build-related resources from runtime requirements.

## 23.6 Benefits

Multi-stage builds can provide:

1. Reduced runtime image size.
2. Separation of build tools and runtime dependencies.
3. Clearer build organization.
4. Improved security posture.
5. Better control over distributed artifacts.
6. Reusable build stages.
7. Support for testing and compilation workflows.

Multi-stage builds will be studied more deeply during the image optimization lecture in Week 3.

---

# 24. DOCKERFILE DESIGN BEST PRACTICES

## 24.1 Use Appropriate Base Images

Select images according to application requirements.

Consider:

- Runtime compatibility.
- Maintenance status.
- Security updates.
- Image size.
- Available dependencies.
- Processor architecture.

Avoid selecting an image only because it is the smallest available option.

## 24.2 Use Explicit Versions

Avoid uncontrolled reliance on mutable image references when exact reproducibility is important.

Version tags improve clarity, while digest pinning can identify specific image content.

However, pinned images must be updated deliberately.

## 24.3 Use .dockerignore

Exclude unnecessary files from the build context.

Particularly important exclusions include:

- Version-control metadata.
- Local credentials.
- Temporary logs.
- Development artifacts.
- Large unrelated directories.
- Local virtual environments.

## 24.4 Minimize Installed Dependencies

Install only the system packages and application components required for the intended image.

Remove unnecessary build tools from final runtime images where possible.

## 24.5 Apply Least Privilege

Avoid running application processes as root unless required.

Use `USER` and appropriate filesystem permissions.

## 24.6 Prefer Exec-Form Entrypoints

Exec-form entrypoints generally provide more predictable argument handling and signal delivery.

## 24.7 Design for Graceful Shutdown

Ensure the principal application process receives and handles termination signals appropriately.

## 24.8 Separate Build and Runtime Requirements

Use multi-stage builds when compilation or asset generation requires tools that are not needed in the final image.

## 24.9 Avoid Embedding Secrets

Do not store confidential credentials in:

- Dockerfile source.
- Build arguments.
- Image environment variables.
- Image layers.
- Build logs.

Use appropriate secret-management mechanisms.

## 24.10 Optimize Build Cache Usage

Organize Dockerfile operations so that frequently changing source files do not unnecessarily invalidate expensive dependency operations.

## 24.11 Include Useful Metadata

Use labels to describe important information about the image.

## 24.12 Validate Application Health

Where appropriate, implement a health check that evaluates meaningful application behavior.

A process merely existing is not sufficient evidence of application correctness.

---

# 25. PRACTICAL LABORATORY 06 — ADVANCED DOCKERFILE CONSTRUCTION

## 25.1 Laboratory Title

**Advanced Dockerfile Configuration: Multi-Stage Builds, Runtime Arguments, Environment Variables, Non-Root Execution, Health Checks, and Build Optimization**

## 25.2 Laboratory Objective

The objective of this laboratory is to construct and examine a custom application image using advanced Dockerfile mechanisms.

The laboratory will demonstrate:

1. Multiple build stages.
2. Runtime executable configuration.
3. Default command arguments.
4. Build-time variables.
5. Persistent image environment variables.
6. Image labels.
7. Explicit working directories.
8. File ownership and permissions.
9. Non-root execution.
10. Health checks.
11. Termination signal configuration.
12. Build cache behavior.
13. Runtime configuration overrides.
14. Temporary build-secret access.
15. Controlled image versioning.

## 25.3 Laboratory Environment

The laboratory uses a small Python HTTP server.

The application is based on Python's standard library.

No Flask or additional Python packages are required.

The selected base image is:

`python:3.12-slim`

A separate Alpine image will be used for an intermediate build stage.

A compatible Docker installation and internet access are required for the initial image downloads.

---

## EXPERIMENT 1 — CREATE THE PROJECT DIRECTORY

Create:

`docker-lecture06`

Inside it, create the following structure:

```text
docker-lecture06/
├── Dockerfile
├── .dockerignore
├── site/
│   └── index.html
└── config/
    └── settings.txt
```

**Purpose:**

To establish a controlled build context containing application content, configuration, and Dockerfile instructions.

---

## EXPERIMENT 2 — CREATE THE APPLICATION CONTENT

Create:

`site/index.html`

Insert:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>Docker Lecture 06</title>
  </head>

  <body>
    <h1>Docker Lecture 06</h1>

    <h2>Advanced Dockerfile Application</h2>

    <p>This application uses a custom Docker image.</p>

    <p>The server runs as a non-root user.</p>

    <p>
      The image includes runtime configuration, metadata, and a health check.
    </p>
  </body>
</html>
```

**Purpose:**

To provide the application content served by the containerized HTTP server.

---

## EXPERIMENT 3 — CREATE THE CONFIGURATION FILE

Create:

`config/settings.txt`

Insert:

```text
Course: Docker and Containerization Technology
Lecture: 06
Application: Academic HTTP Server
Environment: Training
```

**Purpose:**

To provide an example file for examining `COPY --chown` and `COPY --chmod`.

---

## EXPERIMENT 4 — CREATE THE ADVANCED DOCKERFILE

Create a file named:

`Dockerfile`

Insert the following complete configuration:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Artifact preparation
FROM alpine:3.20 AS preparation

RUN mkdir -p /output && \
    printf 'Generated during the preparation stage\n' \
    > /output/build-info.txt


# Stage 2: Final runtime image
FROM python:3.12-slim AS runtime

ARG COURSE_EDITION=academic

ENV COURSE_EDITION=${COURSE_EDITION} \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.title="Docker Lecture 06" \
      org.opencontainers.image.description="Advanced Dockerfile laboratory"

WORKDIR /app

RUN mkdir -p /app/site

COPY --chown=10001:10001 site/ /app/site/

COPY --from=preparation \
     --chown=10001:10001 \
     /output/build-info.txt \
     /app/site/build-info.txt

COPY --chown=10001:10001 --chmod=644 \
     config/settings.txt /app/settings.txt

USER 10001:10001

EXPOSE 8000

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=10s --timeout=3s \
    --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/', timeout=2)" || exit 1

ENTRYPOINT ["python", "-m", "http.server"]

CMD ["8000", "--bind", "0.0.0.0", "--directory", "/app/site"]
```

**Required analysis:**

Identify the purpose of every instruction.

Explain why the Dockerfile contains two `FROM` instructions.

Describe the relationship between `ENTRYPOINT` and `CMD`.

Identify where the non-root execution identity is configured.

Explain which instructions establish application health-monitoring behavior.

---

## EXPERIMENT 5 — CREATE .DOCKERIGNORE

Create:

`.dockerignore`

Insert:

```dockerignore
.git
*.log
*.tar
__pycache__/
*.pyc
demo-value.txt
```

**Purpose:**

To exclude unnecessary development artifacts and the later laboratory-only secret source from the ordinary build context.

---

## EXPERIMENT 6 — BUILD THE IMAGE

Execute:

```bash
docker build -t lecture06-web:v1 .
```

**Expected behavior:**

Docker resolves both base images.

The preparation stage creates a build artifact.

The runtime stage incorporates application content and the selected artifact.

The builder establishes environment variables, labels, ownership, execution identity, health checks, and startup configuration.

**Expected result:**

The image is built successfully.

**Observation:**

Record the image identifier and reported size.

---

## EXPERIMENT 7 — EXAMINE IMAGE METADATA

Execute:

```bash
docker image inspect lecture06-web:v1
```

Now retrieve specific metadata fields.

**Execution identity:**

```bash
docker image inspect --format '{{.Config.User}}' lecture06-web:v1
```

**Entrypoint:**

```bash
docker image inspect --format '{{json .Config.Entrypoint}}' lecture06-web:v1
```

**Default command:**

```bash
docker image inspect --format '{{json .Config.Cmd}}' lecture06-web:v1
```

**Environment variables:**

```bash
docker image inspect --format '{{json .Config.Env}}' lecture06-web:v1
```

**Labels:**

```bash
docker image inspect --format '{{json .Config.Labels}}' lecture06-web:v1
```

**Health check:**

```bash
docker image inspect --format '{{json .Config.Healthcheck}}' lecture06-web:v1
```

**Required observations:**

1. Identify the configured user identity.
2. Identify the entrypoint executable.
3. Identify the default command arguments.
4. Record the configured course environment variable.
5. Identify the custom image labels.
6. Determine whether a health check is present.

---

## EXPERIMENT 8 — START THE APPLICATION

Execute:

```bash
docker run -d --name lecture06-web \
  -p 127.0.0.1:8096:8000 \
  lecture06-web:v1
```

**Purpose:**

To create a running container from the advanced Docker image.

**Expected result:**

The container starts.

Open:

http://127.0.0.1:8096

The laboratory website should appear.

---

## EXPERIMENT 9 — INSPECT CONTAINER HEALTH

Execute:

```bash
docker ps
```

Observe the container status.

After the health check has completed successfully, the status should indicate that the container is healthy.

Now execute:

```bash
docker inspect --format '{{json .State.Health}}' lecture06-web
```

**Purpose:**

To examine the recorded health-check status and related diagnostic information.

**Required analysis:**

Explain the distinction between a container being in the running state and a container being in the healthy state.

---

## EXPERIMENT 10 — VERIFY NON-ROOT EXECUTION

Execute:

```bash
docker exec lecture06-web id
```

**Expected result:**

The output should indicate the configured numeric user and group identifiers.

The image was configured using:

```dockerfile
USER 10001:10001
```

**Technical interpretation:**

The application process does not use UID 0 as its default execution identity.

**Analysis question:**

Why is running an application under a restricted identity generally preferable to granting unnecessary root privileges?

---

## EXPERIMENT 11 — VERIFY FILE OWNERSHIP

Execute:

```bash
docker exec lecture06-web ls -l /app/settings.txt
```

Then:

```bash
docker exec lecture06-web ls -l /app/site
```

**Purpose:**

To examine ownership and permission information associated with copied files.

**Expected result:**

The copied files should reflect the configured ownership settings.

**Analysis question:**

Explain why file ownership must be considered when configuring a container to execute as a non-root user.

---

## EXPERIMENT 12 — EXAMINE ENVIRONMENT VARIABLES

Execute:

```bash
docker exec lecture06-web python -c "import os; print(os.environ.get('COURSE_EDITION'))"
```

**Expected output:**

```text
academic
```

**Purpose:**

To verify that the build-time argument was incorporated into the final image's runtime environment.

**Analysis question:**

Why is the value available at runtime when its original source was an `ARG` instruction?

---

## EXPERIMENT 13 — OVERRIDE AN ENVIRONMENT VARIABLE

Create a second container:

```bash
docker run -d --name lecture06-env \
  -e COURSE_EDITION=testing \
  -p 127.0.0.1:8097:8000 \
  lecture06-web:v1
```

Inspect the value:

```bash
docker exec lecture06-env python -c "import os; print(os.environ.get('COURSE_EDITION'))"
```

**Expected output:**

```text
testing
```

**Technical interpretation:**

The runtime-supplied environment variable overrides the default image value for this container.

The image itself remains unchanged.

---

## EXPERIMENT 14 — OVERRIDE THE DEFAULT CMD

Execute:

```bash
docker run --rm lecture06-web:v1 --help
```

**Purpose:**

To examine how additional command-line arguments interact with the configured exec-form entrypoint.

**Expected result:**

The Python HTTP server module displays its command-line help information and exits.

**Technical interpretation:**

The supplied `--help` argument replaces the image's default `CMD` argument list.

The configured entrypoint remains:

```text
python -m http.server
```

---

## EXPERIMENT 15 — OVERRIDE ENTRYPOINT

Execute:

```bash
docker run --rm --entrypoint python lecture06-web:v1 --version
```

**Purpose:**

To replace the image's normal server startup executable for one container execution.

**Expected result:**

The Python interpreter displays its version and terminates.

**Analysis question:**

Explain the difference between overriding `CMD` and overriding `ENTRYPOINT`.

---

## EXPERIMENT 16 — INSPECT THE MULTI-STAGE ARTIFACT

Execute:

```bash
docker exec lecture06-web cat /app/site/build-info.txt
```

**Expected output:**

```text
Generated during the preparation stage
```

**Purpose:**

To verify that the final image contains an artifact created by the earlier build stage.

**Technical interpretation:**

The `COPY --from=preparation` instruction transferred the selected file into the runtime stage.

The first stage's complete filesystem and tool collection were not automatically incorporated into the final image.

---

## EXPERIMENT 17 — REBUILD USING A DIFFERENT ARG VALUE

Execute:

```bash
docker build \
  --build-arg COURSE_EDITION=advanced \
  -t lecture06-web:v2 .
```

**Purpose:**

To construct a second image with a different build-time parameter.

**Expected result:**

The new image contains:

```text
COURSE_EDITION=advanced
```

as its configured runtime environment variable.

Verify:

```bash
docker image inspect --format '{{json .Config.Env}}' lecture06-web:v2
```

**Analysis question:**

Explain why changing a build argument may invalidate cached build results.

---

## EXPERIMENT 18 — EXAMINE BUILD CACHE REUSE

Rebuild the second image using the same command:

```bash
docker build \
  --build-arg COURSE_EDITION=advanced \
  -t lecture06-web:v2 .
```

**Purpose:**

To observe build caching when the relevant source files and configuration remain unchanged.

**Expected result:**

Eligible build operations should reuse cached results.

Now modify a paragraph in:

`site/index.html`

Rebuild the image with a new tag:

```bash
docker build \
  --build-arg COURSE_EDITION=advanced \
  -t lecture06-web:v3 .
```

**Required observations:**

1. Identify operations that reuse cached results.
2. Identify operations affected by the source modification.
3. Explain why an earlier independent build stage may remain cached.
4. Discuss why source-code placement affects cache performance.

---

## EXPERIMENT 19 — TEST A BUILD SECRET MOUNT

Create a file named:

`demo-value.txt`

Insert:

```text
laboratory-demo-value
```

This is a harmless demonstration value, not an actual password or credential.

Create a second Dockerfile named:

`Dockerfile.secret`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM alpine:3.20

RUN --mount=type=secret,id=demo,required=true \
    test -s /run/secrets/demo

CMD ["sh", "-c", "test ! -e /run/secrets/demo && echo 'Secret mount is not present at runtime'"]
```

Build:

```bash
docker build \
  -f Dockerfile.secret \
  --secret id=demo,src=demo-value.txt \
  -t lecture06-secret:v1 .
```

**Expected result:**

The build succeeds.

The `RUN` operation verifies that the secret mount exists and contains data.

Run the image:

```bash
docker run --rm lecture06-secret:v1
```

**Expected output:**

```text
Secret mount is not present at runtime
```

**Technical interpretation:**

The build secret was provided temporarily to the selected build operation.

It was not automatically retained as a runtime filesystem file.

**Important qualification:**

This experiment does not establish that every use of secret mounts is secure. A malicious or incorrect build command could still disclose secret contents.

---

## EXPERIMENT 20 — INSPECT CONTAINER STOP BEHAVIOR

Execute:

```bash
docker inspect --format '{{.Config.StopSignal}}' lecture06-web
```

**Purpose:**

To inspect the configured stop signal.

Now stop the container:

```bash
docker stop lecture06-web
```

**Expected result:**

Docker requests termination of the principal container process.

**Required analysis:**

Explain the relationship between:

- `STOPSIGNAL`.
- PID 1.
- `ENTRYPOINT`.
- Graceful shutdown.

---

## EXPERIMENT 21 — CONTROLLED CLEANUP

Stop the remaining laboratory application container:

```bash
docker stop lecture06-env
```

Remove the containers:

```bash
docker rm lecture06-web lecture06-env
```

Verify:

```bash
docker ps -a
```

The laboratory images can be retained for review or removed individually when no longer required.

Do not execute broad pruning commands on a Docker environment containing unrelated workloads.

---

# 26. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation                         | Observed result |
| ---------- | --------------------------------- | --------------- |
| 1          | Project directory creation        |                 |
| 2          | Application content creation      |                 |
| 3          | Configuration file creation       |                 |
| 4          | Advanced Dockerfile construction  |                 |
| 5          | Dockerignore configuration        |                 |
| 6          | Image build                       |                 |
| 7          | Image metadata inspection         |                 |
| 8          | Application startup               |                 |
| 9          | Container health inspection       |                 |
| 10         | Non-root execution verification   |                 |
| 11         | File ownership inspection         |                 |
| 12         | Runtime environment inspection    |                 |
| 13         | Environment variable override     |                 |
| 14         | CMD override                      |                 |
| 15         | ENTRYPOINT override               |                 |
| 16         | Multi-stage artifact verification |                 |
| 17         | Build argument override           |                 |
| 18         | Build cache investigation         |                 |
| 19         | Build secret investigation        |                 |
| 20         | Stop signal investigation         |                 |
| 21         | Laboratory cleanup                |                 |

## Laboratory Conclusion

Prepare a written conclusion of approximately 250–350 words explaining:

1. The interaction between `ENTRYPOINT` and `CMD`.
2. The differences between `ARG` and `ENV`.
3. The role of non-root execution and filesystem ownership.
4. The purpose of health checks.
5. The distinction between ordinary build arguments and build secrets.
6. The benefits of multi-stage image construction.
7. The significance of build caching and instruction ordering.

---

# 27. COMMON DOCKERFILE ERRORS AND TROUBLESHOOTING

## 27.1 Entrypoint Executable Not Found

**Problem:**

The container fails because the configured executable does not exist.

**Possible causes:**

- Incorrect executable name.
- Missing runtime dependency.
- Invalid executable path.
- Incorrect image stage.
- Missing execution permissions.

**Corrective procedure:**

Inspect the image's entrypoint configuration and verify the executable's presence.

## 27.2 Incorrect CMD and ENTRYPOINT Interaction

**Problem:**

Unexpected arguments are passed to the startup executable.

**Possible causes:**

- Incorrect use of shell form.
- Misunderstood argument replacement.
- Inherited entrypoint behavior.
- Incorrect command ordering.

**Corrective procedure:**

Inspect both `.Config.Entrypoint` and `.Config.Cmd`.

Determine the effective command produced at runtime.

## 27.3 Environment Variable Unavailable

**Problem:**

An expected variable is unavailable inside a running container.

**Possible causes:**

- Variable declared using `ARG` only.
- Variable defined outside its intended scope.
- Variable not transferred to `ENV`.
- Incorrect runtime configuration.
- Unexpected variable override.

## 27.4 File Permission Denied

**Problem:**

An application cannot read, write, or execute a required file.

**Possible causes:**

- Incorrect file ownership.
- Incorrect permission mode.
- Non-root process lacking access.
- Read-only filesystem configuration.
- Incorrect mount permissions.

**Corrective procedure:**

Inspect the process identity, file ownership, and permission requirements.

Do not resolve permission errors by granting unrestricted permissions without evaluating the consequences.

## 27.5 Health Check Fails

**Problem:**

A container remains running but is marked unhealthy.

**Possible causes:**

- Application unavailable.
- Wrong health-check port.
- Missing diagnostic executable.
- Incorrect health-check command.
- Excessively short timeout.
- Application initialization delay.
- Actual application failure.

**Corrective procedure:**

Inspect the recorded health-check results and application logs.

Verify the application independently.

## 27.6 Build Cache Unexpectedly Invalidated

**Problem:**

A build repeats expensive operations despite a small source-code change.

**Possible causes:**

- Broad `COPY` operation.
- Modified dependency inputs.
- Changed build arguments.
- Updated base image.
- Missing cached results.
- Changes to earlier build dependencies.

**Corrective procedure:**

Examine Dockerfile instruction order and the dependencies of the affected operation.

## 27.7 Secret Mount Missing

**Problem:**

A build operation expects a secret but cannot access it.

**Possible causes:**

- Incorrect secret identifier.
- Missing secret source.
- Incorrect build command.
- Missing builder support.
- Incorrect target path.

**Corrective procedure:**

Verify the `--secret` build option and the corresponding `RUN --mount=type=secret` configuration.

---

# 28. COMMON CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1: ENTRYPOINT and CMD are identical.

Incorrect.

They have different roles in constructing the effective container startup command.

## Misunderstanding 2: ENTRYPOINT cannot be overridden.

Incorrect.

Docker provides an explicit runtime option for overriding the configured entrypoint.

## Misunderstanding 3: The shell and exec forms always behave identically.

Incorrect.

They differ in command interpretation, argument handling, and process execution.

## Misunderstanding 4: ARG values automatically persist in running containers.

Incorrect.

Build arguments are not automatically persisted as runtime environment variables.

## Misunderstanding 5: ARG is suitable for confidential credentials.

Incorrect.

Build argument values may be exposed through build metadata, history, or logs.

## Misunderstanding 6: ENV values are never accessible outside the application.

Incorrect.

Environment configuration can be inspected through multiple runtime and administrative interfaces.

## Misunderstanding 7: ADD and COPY have identical capabilities.

Incorrect.

`ADD` supports additional source-handling behavior.

## Misunderstanding 8: USER automatically changes file ownership.

Incorrect.

Execution identity and filesystem ownership are separate concepts.

## Misunderstanding 9: HEALTHCHECK restarts unhealthy containers automatically.

Incorrect.

Health checks report application health; automatic remediation requires additional mechanisms.

## Misunderstanding 10: A successful image build guarantees a healthy container.

Incorrect.

Build success and runtime health are separate conditions.

## Misunderstanding 11: Every build argument changes every build operation.

Incorrect.

Cache invalidation depends on argument usage, instruction dependencies, and build behavior.

## Misunderstanding 12: Multi-stage builds always include all stages in the final image.

Incorrect.

The final image includes the selected final stage and explicitly transferred artifacts, not every intermediate build environment.

## Misunderstanding 13: Cache mounts are runtime volumes.

Incorrect.

Build cache mounts are builder-managed resources used during image construction.

## Misunderstanding 14: A secret mount guarantees that secrets can never leak.

Incorrect.

Build commands can still disclose sensitive information if they are incorrectly written.

---

# 29. IMPORTANT TERMINOLOGY

| Term                  | Academic definition                                                 |
| --------------------- | ------------------------------------------------------------------- |
| ENTRYPOINT            | Instruction defining the principal runtime executable               |
| CMD                   | Instruction defining default runtime command or arguments           |
| Exec form             | JSON-array representation of an executable and its arguments        |
| Shell form            | Command-string representation interpreted through a shell           |
| PID 1                 | Initial process identifier in a process namespace                   |
| Unix signal           | Operating-system mechanism for process notification                 |
| ARG                   | Build-time variable declaration                                     |
| ENV                   | Environment variable configuration instruction                      |
| Variable substitution | Replacement of variable references with their values                |
| ADD                   | Instruction supporting local and selected remote resource inclusion |
| USER                  | Instruction defining execution identity                             |
| UID                   | Numeric user identifier                                             |
| GID                   | Numeric group identifier                                            |
| File ownership        | Association of filesystem objects with user/group identities        |
| COPY --chown          | Copy operation with ownership configuration                         |
| COPY --chmod          | Copy operation with permission configuration                        |
| LABEL                 | Image metadata instruction                                          |
| SHELL                 | Instruction selecting command-shell interpretation                  |
| VOLUME                | Declaration of a runtime volume mount point                         |
| STOPSIGNAL            | Instruction defining the requested termination signal               |
| HEALTHCHECK           | Instruction configuring periodic application tests                  |
| ONBUILD               | Instruction defining descendant-build triggers                      |
| Build cache           | Reusable build-operation results                                    |
| Cache invalidation    | Reevaluation caused by changed build dependencies                   |
| Cache mount           | BuildKit-managed temporary mount for reusable cached data           |
| Build secret          | Sensitive information temporarily supplied to a build               |
| Secret mount          | Temporary build mount exposing selected confidential input          |
| Multi-stage build     | Build composed of multiple image-construction stages                |
| Build artifact        | File or output produced by a build operation                        |
| Least privilege       | Security principle of granting only necessary access                |
| Health status         | Recorded assessment of configured application checks                |
| Graceful shutdown     | Controlled application termination                                  |

---

# 30. ACADEMIC ASSESSMENT

## Part A — Formal Definitions

Provide technically accurate definitions for:

1. ENTRYPOINT.
2. CMD.
3. Build argument.
4. Environment variable.
5. Exec-form instruction.
6. Shell-form instruction.
7. PID 1.
8. File ownership.
9. USER instruction.
10. Health check.
11. Stop signal.
12. Build cache mount.
13. Secret mount.
14. Multi-stage build.
15. Dockerfile metadata.

## Part B — Short-Answer Questions

**Question 1.**

Explain the difference between `ENTRYPOINT` and `CMD`.

**Question 2.**

Describe why exec-form entrypoints are generally preferred for long-running applications.

**Question 3.**

Explain how Unix signals influence container termination.

**Question 4.**

Describe the difference between `ARG` and `ENV`.

**Question 5.**

Explain how a build argument can be used to configure a persistent runtime environment variable.

**Question 6.**

Describe the security limitations of passing confidential values through build arguments.

**Question 7.**

Explain how `ADD` differs from `COPY`.

**Question 8.**

Describe why `USER` may cause filesystem permission problems.

**Question 9.**

Explain how `COPY --chown` can support non-root execution.

**Question 10.**

Describe the purpose of image labels.

**Question 11.**

Explain why running status does not guarantee application health.

**Question 12.**

Describe how Docker health checks determine container health status.

**Question 13.**

Explain why health checks do not constitute a complete remediation system.

**Question 14.**

Describe the difference between a regular build cache and a BuildKit cache mount.

**Question 15.**

Explain why multi-stage builds can reduce runtime image size.

---

# 31. COMMAND INTERPRETATION ASSESSMENT

Consider:

```dockerfile
FROM alpine:3.20

ARG COURSE_VERSION=1.0

ENV COURSE_VERSION=${COURSE_VERSION}

ENTRYPOINT ["echo"]

CMD ["Docker Course"]
```

Answer:

1. What is the base image?
2. What does `ARG` establish?
3. Why is `ENV` required if the value should persist at runtime?
4. What is the entrypoint executable?
5. What is the default argument?
6. What output is expected when the container runs?
7. What happens when an alternative argument is supplied after the image reference?

Consider:

```dockerfile
FROM alpine:3.20

RUN mkdir -p /app

COPY --chown=10001:10001 \
    application.txt /app/application.txt

USER 10001:10001
```

Answer:

8. What does the `RUN` instruction perform?
9. What does `COPY --chown` control?
10. What is the configured execution identity?
11. Why might filesystem permissions still matter?
12. Does the Dockerfile necessarily define a valid application startup command on its own?

---

# 32. ANALYTICAL CASE STUDIES

## Case Study 1 — Incorrect ENTRYPOINT Configuration

A developer uses:

```dockerfile
ENTRYPOINT python application.py
```

The application does not respond correctly to termination requests.

Analyze the relationship between shell-form entrypoints, process hierarchy, PID 1, and signal handling.

Recommend a more appropriate configuration.

## Case Study 2 — Build Argument Exposure

An organization passes private registry credentials through:

```bash
docker build --build-arg TOKEN=example-value .
```

Evaluate the security risks.

Explain how BuildKit secret mounts provide an alternative mechanism.

## Case Study 3 — Non-Root Execution Failure

An application image changes from root execution to UID 10001.

The application can read configuration files but cannot write to its data directory.

Analyze the possible causes.

Recommend a solution based on filesystem ownership and least privilege.

## Case Study 4 — Inefficient Dependency Installation

A Python application repeatedly installs dependencies during every source-code modification.

The Dockerfile copies the entire project before installing dependencies.

Explain how instruction ordering influences cache reuse.

Recommend a more efficient Dockerfile organization.

## Case Study 5 — Unhealthy Application

A web-server container appears as running but is marked unhealthy.

The configured health check requests an HTTP endpoint.

Develop a systematic diagnostic procedure.

Explain why it is necessary to distinguish application failure from health-check misconfiguration.

## Case Study 6 — Multi-Stage Image Construction

An application requires a large compiler toolchain but produces a small executable.

Explain how multi-stage builds can separate the compilation environment from the runtime image.

Discuss the security and maintenance advantages.

---

# 33. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Advanced Dockerfile Configuration and Efficient Image Construction

Prepare an academic report of approximately 1,000–1,500 words addressing:

**“Advanced Dockerfile Instructions: Runtime Execution, Build Configuration, Security, and Image Construction Optimization.”**

The report must include:

1. An introduction to advanced Dockerfile configuration.
2. A technical explanation of `ENTRYPOINT`.
3. A comparison of `ENTRYPOINT` and `CMD`.
4. An examination of shell form and exec form.
5. An explanation of build arguments and environment variables.
6. A comparison of `ADD` and `COPY`.
7. A discussion of non-root execution and filesystem ownership.
8. An examination of image labels and runtime metadata.
9. A discussion of health checks and shutdown signals.
10. An explanation of Docker build caching.
11. An analysis of BuildKit cache mounts and secret mounts.
12. An explanation of multi-stage builds.
13. A security evaluation of Dockerfile best practices.
14. A conclusion assessing the importance of correct Dockerfile design.

The report should include at least two Dockerfile examples and one architectural diagram.

---

# 34. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 07, verify that you can independently perform the following operations.

- [ ] Explain the purpose of `ENTRYPOINT`.
- [ ] Explain the purpose of `CMD`.
- [ ] Describe their interaction.
- [ ] Override default command arguments.
- [ ] Override an entrypoint.
- [ ] Distinguish shell form from exec form.
- [ ] Explain the significance of PID 1.
- [ ] Describe container signal handling.
- [ ] Configure environment variables using `ENV`.
- [ ] Declare build arguments using `ARG`.
- [ ] Supply build arguments during image construction.
- [ ] Explain variable scope.
- [ ] Distinguish `ARG` from `ENV`.
- [ ] Explain the additional functionality of `ADD`.
- [ ] Configure a non-root execution identity.
- [ ] Set ownership using `COPY --chown`.
- [ ] Configure permissions using `COPY --chmod`.
- [ ] Add image metadata using `LABEL`.
- [ ] Explain the purpose of `SHELL`.
- [ ] Explain the purpose of `VOLUME`.
- [ ] Configure a stop signal.
- [ ] Define a health check.
- [ ] Inspect container health status.
- [ ] Explain the purpose of `ONBUILD`.
- [ ] Optimize basic Dockerfile instruction ordering.
- [ ] Explain cache invalidation.
- [ ] Identify a BuildKit cache mount.
- [ ] Explain secure build-secret handling.
- [ ] Construct a multi-stage Dockerfile.
- [ ] Copy artifacts between build stages.
- [ ] Build an advanced custom image.
- [ ] Run the application successfully.
- [ ] Verify its runtime identity and configuration.
- [ ] Complete the laboratory and document the results.

**Completion standard:**

The student should be capable of constructing a Docker image with controlled runtime behavior, explicit environment configuration, appropriate execution permissions, and inspectable application health.

The student must understand the reasons behind the configuration choices rather than merely reproduce Dockerfile instructions.

---

# 35. LECTURE SUMMARY

Advanced Dockerfile instructions provide mechanisms for controlling image construction, container startup behavior, execution permissions, metadata, and application monitoring.

The `ENTRYPOINT` instruction defines the principal executable used during container startup.

The `CMD` instruction defines default command behavior or arguments.

Their interaction determines the effective startup command.

Shell-form and exec-form instructions differ in command interpretation, variable expansion, process hierarchy, and signal handling.

The `ARG` instruction supports build-time parameterization, while the `ENV` instruction establishes environment variables that can persist into the resulting runtime environment.

The `ADD` instruction provides additional source-handling functionality beyond ordinary file copying.

The `USER` instruction defines execution identity, while ownership and permission controls determine access to filesystem resources.

The `LABEL` instruction records descriptive image metadata.

The `SHELL`, `VOLUME`, `STOPSIGNAL`, `HEALTHCHECK`, and `ONBUILD` instructions establish additional configuration and build behavior.

BuildKit provides advanced image construction functionality, including caching, temporary build mounts, and secret handling.

Multi-stage builds allow developers to separate build-time dependencies from final runtime artifacts.

Correct Dockerfile design requires balancing application functionality, reproducibility, efficiency, and security.

**The central principle of this lecture is that advanced Dockerfile configuration should create an image whose construction is reproducible, whose startup behavior is explicit, whose permissions are restricted, and whose runtime behavior can be inspected and diagnosed.**

---

# 36. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. _Dockerfile Reference._  
https://docs.docker.com/reference/dockerfile/

[2] Docker Inc. _Build Variables._  
https://docs.docker.com/build/building/variables/

[3] Docker Inc. _Docker Build Best Practices._  
https://docs.docker.com/build/building/best-practices/

[4] Docker Inc. _Docker Build Cache._  
https://docs.docker.com/build/cache/

[5] Docker Inc. _Optimize Build Cache Usage._  
https://docs.docker.com/build/cache/optimize/

[6] Docker Inc. _Build Cache Invalidation._  
https://docs.docker.com/build/cache/invalidation/

[7] Docker Inc. _Build Secrets._  
https://docs.docker.com/build/building/secrets/

[8] Docker Inc. _Multi-Stage Builds._  
https://docs.docker.com/build/building/multi-stage/

[9] Docker Inc. _Multi-Platform Builds._  
https://docs.docker.com/build/building/multi-platform/

[10] Docker Inc. _Docker BuildKit._  
https://docs.docker.com/build/buildkit/

[11] Docker Inc. _Docker Image Build._  
https://docs.docker.com/reference/cli/docker/image/build/

[12] Docker Inc. _Docker Container Run._  
https://docs.docker.com/reference/cli/docker/container/run/

[13] Docker Inc. _Docker Container Inspect._  
https://docs.docker.com/reference/cli/docker/container/inspect/

[14] Open Container Initiative. _OCI Image Format Specification._  
https://specs.opencontainers.org/image-spec/

## Recommended Reading Sequence

Begin with reference [1], concentrating on `ENTRYPOINT`, `CMD`, `ARG`, `ENV`, `USER`, `HEALTHCHECK`, and `COPY`.

Continue with reference [2] to understand variable scope and persistence.

Study references [4], [5], and [6] to examine caching and cache invalidation.

Reference [7] provides the foundation for secure build-secret handling.

Reference [8] introduces the complete multi-stage construction model.

Reference [3] provides additional guidance on image construction practices.

---

# 37. FINAL LECTURE CONCLUSION

Advanced Dockerfile configuration is essential for developing reliable and maintainable containerized applications.

Basic Dockerfiles can package application files and define simple startup commands.

However, more complex applications require precise control over execution behavior, configuration variables, filesystem permissions, health monitoring, and build dependencies.

The distinction between `ENTRYPOINT` and `CMD` is particularly important because it determines the executable and arguments used when containers start.

Similarly, the distinction between `ARG` and `ENV` establishes the boundary between build-time configuration and persistent runtime environment variables.

Execution identity and filesystem permissions must be considered together to implement least-privilege principles.

Health checks provide additional visibility into application functionality, while stop-signal configuration supports controlled termination.

BuildKit caching and advanced mounts provide opportunities to improve efficiency and handle sensitive build requirements more appropriately.

Multi-stage builds further improve image construction by separating intermediate build environments from final runtime artifacts.

These capabilities demonstrate that a Dockerfile is not merely a list of installation commands.

It is a structured specification for producing an application environment with defined filesystem content, runtime behavior, metadata, and operational characteristics.

Mastery of these principles enables developers to construct container images that are more predictable, efficient, secure, and suitable for systematic deployment.

---

**END OF LECTURE 06**

**Next Lecture:** Lecture 07 — Week One Comprehensive Review, Docker Fundamentals Assessment, and Practical Project: Containerizing a Complete Personal Website.
