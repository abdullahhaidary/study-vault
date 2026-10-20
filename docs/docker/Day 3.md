# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 03 — WORKING INSIDE DOCKER CONTAINERS: PROCESS INSPECTION, FILESYSTEM EXPLORATION, RUNTIME DIAGNOSTICS, AND CONTAINER INTERNALS

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 03 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 3–4 hours  
**Prerequisites:**

- Lecture 01 — Introduction to Docker and Containerization Technology.
- Lecture 02 — Docker Containers: Creation, Execution, Lifecycle Management, and Runtime Operations.
- Elementary familiarity with command-line operations and filesystem navigation.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Explain the internal execution environment of a Docker container.
2. Distinguish between container execution and command execution within an existing container.
3. Describe the function and syntax of the `docker exec` command.
4. Establish an interactive shell session inside a running container.
5. Execute non-interactive commands within an existing container.
6. Explain the relationship between container processes and operating-system process management.
7. Identify the significance of the principal container process and PID 1.
8. Examine processes associated with a container.
9. Explain the structure of a container filesystem.
10. Identify common Linux directories and their functions.
11. Distinguish between read-only image layers and writable container layers.
12. Explain the principles of copy-on-write storage.
13. Inspect container configuration and runtime metadata.
14. Transfer files between a container and a host filesystem.
15. Identify filesystem modifications made during container execution.
16. Observe container resource utilization.
17. Explain the relationship between environment variables, users, processes, and container configuration.
18. Describe fundamental container troubleshooting procedures.
19. Identify security considerations associated with container inspection and modification.
20. Complete a practical laboratory involving the inspection and modification of a running web-server container.

---

# 2. INTRODUCTION TO CONTAINER INTERNALS

## 2.1 Overview

In the previous lectures, Docker was introduced as a platform for packaging applications into container images and executing those applications within isolated environments.

The container lifecycle was examined through operations such as creation, execution, stopping, restarting, and removal.

However, managing the lifecycle of a container represents only one aspect of container administration.

In practical software engineering, it is frequently necessary to investigate the internal state of a container while an application is running.

Examples of such investigations include:

- Determining which application processes are executing.
- Examining application configuration files.
- Verifying the presence of installed dependencies.
- Investigating filesystem paths.
- Inspecting environment variables.
- Examining process permissions.
- Identifying changes to container files.
- Investigating application failures.
- Transferring diagnostic files.
- Monitoring resource consumption.

Docker provides mechanisms for performing these operations without requiring direct administrative access to the container's underlying filesystem through the host operating system.

## 2.2 Definition of Container Inspection

Container inspection is the systematic examination of a container's configuration, runtime state, processes, filesystem, resource utilization, and related metadata.

Inspection operations can be divided into two principal categories.

**External inspection:**

Examination of a container through commands executed outside the container, generally using the Docker client and Docker Engine.

Examples include:

- `docker inspect`
- `docker top`
- `docker stats`
- `docker logs`
- `docker diff`

**Internal inspection:**

Examination of a container by executing commands within its existing execution environment.

Examples include:

- Listing directories.
- Reading configuration files.
- Examining environment variables.
- Inspecting process-related information.
- Running diagnostic utilities.

Docker provides the `docker exec` command as an important mechanism for internal inspection.

## 2.3 Container Isolation and Observability

Containerization introduces isolation boundaries between applications.

These boundaries control how containerized processes interact with operating-system resources.

However, isolation does not imply that container administrators are unable to observe or manage the contained environment.

Docker Engine maintains information about the containers it manages and provides interfaces for examining their configuration and execution.

A sufficiently authorized Docker client may therefore request information about a container or initiate commands within it.

This capability is essential for maintenance and debugging.

It also creates security responsibilities, because access to a Docker daemon can provide extensive control over containerized workloads and the host.

---

# 3. EXECUTING COMMANDS INSIDE CONTAINERS

## 3.1 The Docker Exec Command

Docker provides the command:

`docker exec`

Its primary purpose is to execute an additional command within the execution environment of an existing running container.

**Formal definition:**

The `docker exec` command instructs Docker Engine to start an additional process inside an existing running container, using the container's configured execution environment and selected runtime settings.

The general syntax is:

```text
docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
```

Where:

**OPTIONS:** Optional settings controlling command execution.

**CONTAINER:** The name or identifier of the target container.

**COMMAND:** The executable to start.

**ARG:** Arguments passed to the executable.

For example:

```bash
docker exec my-nginx ls
```

This command executes the `ls` program inside the running container named `my-nginx`.

The output is returned through the Docker client.

## 3.2 Relationship Between Docker Run and Docker Exec

The distinction between `docker run` and `docker exec` is fundamental.

The command:

```bash
docker run nginx:alpine
```

creates and starts a new container based on the selected image.

By contrast:

```bash
docker exec my-nginx ls
```

executes an additional process inside an already existing, running container.

These operations do not have the same effect.

| Characteristic                         | `docker run`          | `docker exec`                     |
| -------------------------------------- | --------------------- | --------------------------------- |
| Creates a container                    | Yes                   | No                                |
| Starts an existing container           | No                    | No                                |
| Requires an existing running target    | No                    | Yes                               |
| Executes a process                     | Yes                   | Yes                               |
| Establishes a new container identity   | Yes                   | No                                |
| Uses an existing container environment | No                    | Yes                               |
| Typical purpose                        | Application execution | Inspection or additional commands |

The `docker exec` command does not create an independent container.

It creates an additional process within the selected container.

## 3.3 Requirement for an Active Container

In ordinary operation, `docker exec` requires the target container to be running.

For example, if the container named `my-nginx` has been stopped, the following command cannot start a shell within it:

```bash
docker exec -it my-nginx sh
```

The command fails because the container does not have an active execution environment in which the additional process can be started.

To execute commands within the container again, it must first be started:

```bash
docker start my-nginx
```

Afterward, `docker exec` may be used.

A paused container must generally be unpaused before an exec command can proceed.

## 3.4 Commands Must Be Executable Programs

An important technical restriction is that `docker exec` expects a valid executable command.

For example:

```bash
docker exec my-nginx ls
```

starts the `ls` executable.

However, shell operators such as `&&`, pipes, and redirection are interpreted by a shell rather than directly by Docker.

Therefore, to execute a compound command, a shell can be invoked explicitly.

Example:

```bash
docker exec my-nginx sh -c 'echo First && echo Second'
```

In this command:

- `sh` starts a shell.
- `-c` instructs the shell to interpret a command string.
- `&&` is interpreted by the shell.
- The second command runs if the first succeeds.

The Docker client does not independently implement the shell's command language.

---

# 4. INTERACTIVE SHELL ACCESS

## 4.1 Definition of a Shell

A shell is a program that provides an interface through which users or scripts can interact with operating-system facilities.

A shell interprets commands, starts programs, manages command arguments, and may support features such as:

- Variables.
- Pipes.
- Redirection.
- Conditional execution.
- Command substitution.
- Shell scripts.

Common shells on Unix-like systems include:

- Bourne shell (`sh`).
- Bash (`bash`).
- Z shell (`zsh`).
- Dash (`dash`).
- BusyBox shell implementations.

Not every container image includes all these shells.

Some minimal container images contain only a basic shell, and certain highly restricted or distroless images contain no shell at all.

## 4.2 Starting a Shell in a Running Container

The command:

```bash
docker exec -it my-nginx sh
```

starts an interactive shell process inside the running container.

The components have the following meanings:

| Component  | Function                        |
| ---------- | ------------------------------- |
| `docker`   | Invokes Docker CLI              |
| `exec`     | Executes an additional process  |
| `-i`       | Keeps standard input available  |
| `-t`       | Allocates a pseudo-terminal     |
| `my-nginx` | Identifies the target container |
| `sh`       | Specifies the shell executable  |

After successful execution, the user receives a shell prompt associated with the container environment.

The user can then execute commands to explore that environment.

## 4.3 Bash Versus Shell

A common example found in Docker tutorials is:

```bash
docker exec -it my-container bash
```

This command works only if the target container contains an executable named `bash` accessible through the execution environment.

Minimal images such as Alpine-based images commonly include `sh` but may not include Bash.

Consequently:

```bash
docker exec -it my-container sh
```

is often more appropriate for minimal Linux containers.

A failure to start Bash does not necessarily indicate that the container is malfunctioning.

It may simply indicate that Bash was never installed in the image.

## 4.4 Shell Session Versus Container Execution

An interactive shell started using `docker exec` is an additional process.

It does not normally replace the container's principal process.

Consider a running Nginx container.

Its principal process operates the web server.

The administrator executes:

```bash
docker exec -it my-nginx sh
```

A shell process is created.

The Nginx server continues operating independently.

When the administrator enters:

```sh
exit
```

the interactive shell terminates.

The Nginx container normally continues running because its principal process remains active.

This differs from a container created with a shell as its principal process.

In that case, terminating the shell may cause the entire container to exit.

## 4.5 The Docker Attach Command

Docker also provides:

`docker attach`

This command attaches the local terminal to the standard streams of a running container's principal process.

It should not be confused with `docker exec`.

**Docker exec:** Starts an additional process within the container.

**Docker attach:** Connects to the streams of an existing container process.

Attaching directly to an application may have operational consequences.

For example, sending an interrupt signal through an attached terminal may affect the container's principal process.

For routine interactive inspection, `docker exec` is often a safer and more convenient approach when an appropriate shell is available.

---

# 5. CONTAINER FILESYSTEM STRUCTURE

## 5.1 Definition of a Filesystem

A filesystem is an operating-system mechanism used to organize, store, retrieve, and manage files and directories.

A filesystem provides a hierarchical namespace that applications use to access data.

Linux systems commonly organize filesystem paths beneath a root directory represented by:

`/`

Files and directories are referenced through paths beginning at this root or relative to a working directory.

## 5.2 Filesystem Isolation

A Linux container normally operates with a filesystem view established through container runtime configuration and operating-system mount mechanisms.

The container's root filesystem is ordinarily assembled using image content and additional runtime filesystem resources.

From the perspective of a process inside the container, this environment may resemble a conventional Linux filesystem.

However, the visible filesystem is not necessarily the host's complete filesystem.

The container runtime determines which filesystem resources are made accessible.

The isolation boundaries may be modified through configuration such as mounted volumes or bind mounts.

## 5.3 Common Linux Filesystem Directories

Many Linux container images contain familiar Unix filesystem directories.

The precise directory structure varies according to the image and distribution.

| Directory | Typical function                                     |
| --------- | ---------------------------------------------------- |
| `/`       | Root of the filesystem hierarchy                     |
| `/bin`    | Essential command executables or links to them       |
| `/sbin`   | System administration executables or links           |
| `/etc`    | System and application configuration                 |
| `/usr`    | User-space programs, libraries, and shared resources |
| `/var`    | Variable application and system data                 |
| `/tmp`    | Temporary files                                      |
| `/home`   | User home directories                                |
| `/root`   | Home directory commonly associated with root         |
| `/dev`    | Device-related filesystem entries                    |
| `/proc`   | Process and kernel information                       |
| `/sys`    | Kernel and device-related information                |
| `/run`    | Runtime state information                            |
| `/opt`    | Optional application software                        |
| `/lib`    | Shared libraries or links to library directories     |

Not all directories must exist in every image.

Container images may be intentionally minimal and include only the resources required by a specific application.

## 5.4 The Root Filesystem

The root filesystem is the filesystem hierarchy made available to a container process beneath `/`.

It provides access to the application binaries, libraries, and configuration files required for execution.

For example, an Nginx container may contain:

```text
/
├── bin/
├── dev/
├── etc/
│   └── nginx/
├── proc/
├── run/
├── tmp/
├── usr/
│   └── share/
│       └── nginx/
│           └── html/
└── var/
```

This structure is illustrative.

The actual filesystem organization depends on the image, configured mounts, and runtime environment.

## 5.5 Application Files in Containers

Applications commonly store executable files, source code, static assets, and configuration files in locations selected by the image maintainer.

For example, the official Nginx image commonly provides static website content under:

`/usr/share/nginx/html`

Its principal configuration commonly resides under:

`/etc/nginx`

These locations are useful when inspecting Nginx-based containers.

However, application directories are not universally standardized across all images.

The image documentation remains the authoritative source for application-specific locations.

---

# 6. NAVIGATING A CONTAINER FILESYSTEM

## 6.1 The pwd Command

The command:

`pwd`

prints the current working directory.

Example:

```bash
docker exec my-nginx pwd
```

The result identifies the working directory configured for the executed process.

The working directory may be established by image configuration or overridden during execution.

## 6.2 The ls Command

The command:

`ls`

lists directory contents.

Example:

```bash
docker exec my-nginx ls /
```

This displays visible entries in the container's root directory.

A more detailed listing may be requested using:

```bash
docker exec my-nginx ls -la /
```

The exact output depends on the available `ls` implementation.

The options generally provide a detailed listing that includes hidden entries.

## 6.3 The cd Command

The command:

`cd`

changes the current working directory of a shell process.

Because `cd` is typically a shell built-in, it is normally used within a shell session.

Example:

```sh
cd /etc/nginx
```

The shell's working directory changes to the specified location.

Executing `cd` in one temporary shell process does not permanently modify the working directory of subsequent independent `docker exec` commands.

## 6.4 The cat Command

The command:

`cat`

can display the contents of text files.

Example:

```bash
docker exec my-nginx cat /etc/os-release
```

This reads distribution-identification information from within the container's filesystem.

The file `/etc/os-release` commonly contains information identifying the user-space operating-system distribution.

It should not be interpreted as proof that the container possesses a separate operating-system kernel.

## 6.5 The Working Directory Option

Docker supports the `--workdir` option for `docker exec`.

Example:

```bash
docker exec --workdir /etc/nginx my-nginx pwd
```

This specifies the working directory for the additional process.

It does not permanently modify the configured working directory of the container.

## 6.6 Filesystem Permissions

Linux filesystem operations are subject to access-control mechanisms involving user and group identities and file permissions.

A file may permit or restrict:

- Reading.
- Writing.
- Execution.

A container process does not automatically possess unrestricted access to every file visible within the container.

The process's effective user and group identities influence its permitted operations.

Container filesystem permissions can therefore explain why an application can read a configuration file but cannot modify it.

---

# 7. CONTAINER IMAGES AND WRITABLE FILESYSTEM LAYERS

## 7.1 Read-Only Image Layers

Docker container images commonly consist of multiple filesystem layers.

Image layers provide packaged content that can be reused when creating containers.

These layers are treated as immutable image content during ordinary container execution.

The runtime does not directly modify the source image when a container application writes to its filesystem.

## 7.2 The Container Writable Layer

When a container is created, Docker normally establishes a writable filesystem layer associated with that container.

This layer accommodates filesystem changes made during execution.

Such changes may include:

- Creating files.
- Modifying configuration files.
- Deleting files.
- Writing temporary data.
- Creating application runtime directories.

The writable layer is specific to the container.

Two containers created from the same image ordinarily have separate writable layers.

## 7.3 Layered Filesystem Model

The relationship can be represented as follows:

```text
CONTAINER FILESYSTEM
[ Writable Container Layer ]
[ Image Layer 3 ]
[ Image Layer 2 ]
[ Image Layer 1 ]
[ Base Image Content ]
```

The application observes a unified filesystem view rather than having to interact directly with each layer.

The storage implementation is responsible for presenting the resulting filesystem.

The precise mechanism depends on the image store and storage backend used by Docker Engine.

## 7.4 Copy-on-Write

Copy-on-write is a storage technique in which existing data can be shared until a modification requires a separate writable representation.

In a layered container filesystem, modifying content originally supplied by an image may cause the storage system to create the appropriate writable representation.

The original image data remains unchanged.

The modification becomes visible to the particular container.

This approach supports efficient reuse of image content across multiple containers.

The precise implementation differs between storage backends.

## 7.5 Filesystem State After Container Restart

Ordinary stop and start operations do not remove the container's writable layer.

Therefore, a file created inside a container may remain available after the container is stopped and restarted.

For example:

1. A container starts.
2. A file is created in `/tmp`.
3. The container stops.
4. The same container starts again.
5. The file may still be present.

This behavior must not be confused with long-term persistent storage.

The writable layer is associated with the existence of that particular container.

## 7.6 Filesystem State After Container Removal

When a container is removed, its writable layer is ordinarily deleted.

Files that existed only in that layer are therefore lost.

Creating a new container from the same original image does not reproduce modifications made inside the removed container.

Consequently, direct modifications to running containers should not be considered a reliable application deployment strategy.

Durable application changes should normally be represented through controlled image builds and configuration management.

Persistent application data should be stored using appropriate storage mechanisms.

## 7.7 Storage Backend Considerations

Docker has historically supported storage drivers such as `overlay2`.

Modern Docker Engine installations may instead use containerd-based image storage and snapshotter implementations.

The underlying storage implementation may vary by installation and Docker Engine version.

Therefore, it is inaccurate to assume that every modern Docker installation uses an identical host filesystem layout or storage driver.

The conceptual distinction between reusable image content and container-specific writable state remains essential.

---

# 8. PROCESS MANAGEMENT INSIDE CONTAINERS

## 8.1 Definition of a Process

A process is an executing instance of a computer program.

The operating system assigns resources and scheduling information to processes.

Important process-related information may include:

- Process identifier.
- Parent process identifier.
- Executable.
- User identity.
- Current state.
- Memory usage.
- CPU utilization.
- Open file descriptors.

A container typically executes one or more processes under its configured isolation boundaries.

## 8.2 The Principal Container Process

When Docker starts a container, a designated principal process is launched.

This process is central to the container's lifecycle.

For Linux containers using a dedicated PID namespace, the principal process commonly has PID 1 within that namespace.

The same process may have a different process identifier in the host's PID namespace.

Consequently, process identifiers must be interpreted relative to their namespace.

## 8.3 PID Namespaces

Linux PID namespaces provide isolated views of process identifiers.

A process may be represented by different PID values depending on the namespace from which it is observed.

For example:

```text
HOST OPERATING SYSTEM

PID 1200 — Docker-related process
PID 4250 — Nginx master process
PID 4260 — Nginx worker process

CONTAINER PID NAMESPACE

PID 1 — Nginx master process
PID 7 — Nginx worker process
```

These values are illustrative rather than fixed.

The example demonstrates that a container can have its own process numbering perspective.

## 8.4 Why PID 1 Matters

PID 1 has special significance in Linux process management.

In a PID namespace, the initial process has responsibilities and signal-handling characteristics that differ from those of ordinary processes.

The principal container process should therefore be designed or configured to handle termination signals appropriately.

Potential problems include:

- Failure to handle shutdown signals.
- Improper management of child processes.
- Failure to reap terminated child processes.
- Unexpected behavior during container shutdown.

These concerns are particularly relevant when an application launches multiple subprocesses.

## 8.5 Process Reaping

When a child process terminates, its parent ordinarily needs to collect its termination status.

This operation is commonly called _reaping_.

Failure to reap terminated child processes can result in zombie process entries.

Container images running complex process hierarchies may require careful process management.

Docker provides mechanisms, including an optional lightweight init process, to assist with some signal-handling and process-reaping requirements.

This topic becomes more important in advanced application containerization.

---

# 9. INSPECTING CONTAINER PROCESSES

## 9.1 The Docker Top Command

The command:

`docker top`

displays processes associated with a running container.

Its general syntax is:

```text
docker top CONTAINER
```

Example:

```bash
docker top my-nginx
```

The output may include process information such as:

- Process identifiers.
- User identifiers.
- Parent processes.
- Execution commands.
- Process-related metadata.

The exact output format depends on the Docker environment and operating system.

## 9.2 Docker Top Versus Process Tools Inside a Container

The `docker top` command is executed from the Docker client and obtains process information through Docker Engine.

It does not require the container image to contain an executable named `top`.

This distinction is important.

Minimal container images may not include process inspection programs such as `ps` or `top`.

Nevertheless, the Docker daemon may still provide process information through `docker top`.

## 9.3 Inspecting the proc Filesystem

Linux provides a virtual filesystem commonly mounted at:

`/proc`

The proc filesystem exposes information about running processes and selected kernel characteristics.

For example:

```bash
docker exec my-nginx cat /proc/1/status
```

This command reads process status information for PID 1 as visible inside the container.

The output may include:

- Process name.
- Process state.
- Process identifier.
- Parent process identifier.
- User and group identifiers.
- Memory-related information.

The proc filesystem does not represent an ordinary collection of files stored in the container image.

Its contents are generated through operating-system facilities and reflect runtime information.

## 9.4 Process Inspection and Container Troubleshooting

Process inspection can help determine:

1. Whether the intended application started.
2. Which processes are active.
3. Whether worker processes exist.
4. Whether unexpected processes are running.
5. Whether process relationships appear correct.
6. Whether an application is repeatedly starting or terminating.

However, the existence of a process does not guarantee correct application behavior.

A process may remain active while the associated service is malfunctioning.

---

# 10. INSPECTING CONTAINER METADATA

## 10.1 Definition of Container Metadata

Container metadata consists of structured information maintained by Docker about a container's configuration, identity, runtime state, and associated resources.

Docker Engine uses this information to manage containers.

Metadata is distinct from the application data stored within a container's filesystem.

## 10.2 The Docker Inspect Command

Docker provides:

`docker inspect`

This command returns detailed information about supported Docker objects.

For a container:

```bash
docker inspect my-nginx
```

The output is commonly represented as JSON.

JSON, or JavaScript Object Notation, is a structured data representation commonly used by APIs and configuration systems.

## 10.3 Important Metadata Categories

Container inspection may expose information about:

**Identity**

- Container ID.
- Name.
- Creation timestamp.

**Runtime state**

- Current status.
- Whether the container is running.
- Process identifier.
- Start time.
- Finish time.
- Exit code.

**Image configuration**

- Source image.
- Configured command.
- Entrypoint.
- Working directory.
- Environment variables.
- Configured user.

**Networking**

- Network attachments.
- Port mappings.
- IP address information.
- Networking mode.

**Storage**

- Mounts.
- Storage configuration.
- Container filesystem-related information.

**Host configuration**

- Resource constraints.
- Restart policy.
- Privilege settings.
- Selected runtime options.

## 10.4 Filtering Inspection Output

The complete JSON output may contain substantial information.

Docker supports formatted output through the `--format` option.

Example:

```bash
docker inspect --format '{{.State.Status}}' my-nginx
```

This displays the container's recorded state.

Another example:

```bash
docker inspect --format '{{.Config.Image}}' my-nginx
```

This displays the configured image reference.

Another example:

```bash
docker inspect --format '{{.State.Pid}}' my-nginx
```

This displays the container's principal process identifier as recorded by Docker Engine.

On Docker Desktop, the relevant engine operates within a Linux environment, so the reported process identifier must not automatically be interpreted as a native process identifier of the Windows or macOS host.

## 10.5 Inspecting Network Information

Network-related metadata can be examined using:

```bash
docker inspect --format '{{json .NetworkSettings.Ports}}' my-nginx
```

The `json` formatting function serializes the selected information into JSON.

This output can help determine which container ports have published host endpoints.

## 10.6 Security Considerations

Container metadata may contain sensitive operational information.

For example, environment variable configuration can sometimes include credentials, tokens, or other confidential values.

Users should not publish unfiltered container inspection output without first verifying that it does not disclose secrets or infrastructure details.

The ability to inspect a container is therefore an administrative privilege requiring appropriate access control.

---

# 11. TRANSFERRING FILES BETWEEN HOSTS AND CONTAINERS

## 11.1 Introduction

Container inspection and troubleshooting frequently require transferring files between the Docker client environment and a container.

Examples include:

- Exporting diagnostic logs.
- Retrieving generated reports.
- Copying a test configuration.
- Transferring example files.
- Examining application output.
- Extracting temporary diagnostic artifacts.

Docker provides a command for these operations.

## 11.2 The Docker CP Command

The command:

`docker cp`

copies files or directories between a container and the local filesystem associated with the Docker client.

It supports transfers in both directions.

General syntax:

```text
docker cp SOURCE DESTINATION
```

One path identifies a local filesystem location.

The other identifies a path associated with a container.

## 11.3 Copying from Container to Host

Example:

```bash
docker cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf
```

This copies the specified Nginx configuration file from the container into the current local directory.

The command does not require an interactive shell session inside the container.

## 11.4 Copying from Host to Container

Example:

```bash
docker cp ./example.txt my-nginx:/tmp/example.txt
```

This copies the local file into the container.

The destination directory must satisfy the relevant path and permission requirements.

The operation may modify the container's writable filesystem state.

## 11.5 Copying Files from Stopped Containers

Unlike `docker exec`, which requires a running container, `docker cp` can operate with running or stopped containers.

This makes the command valuable for post-failure analysis.

For example, an application may have terminated but left a diagnostic report in its writable filesystem.

An administrator may retrieve the report before removing the container.

## 11.6 File Ownership and Permissions

File copy operations are affected by ownership, permission, and archive-handling rules.

The resulting ownership metadata depends on the copy direction and selected command options.

The `-a` option provides archive-mode behavior for preserving ownership information according to Docker's documented semantics.

Administrators should verify ownership and permissions after copying files used by security-sensitive applications.

## 11.7 Copying Is Not Persistent Storage

The `docker cp` command is a file transfer mechanism.

It does not automatically create continuous synchronization between the host and container.

If a file is copied into a container, subsequent modifications to the original host file do not automatically update the copied container file.

For ongoing data sharing or durable storage, Docker supports other mechanisms, including bind mounts and volumes.

These will be examined in the storage lecture.

---

# 12. INSPECTING FILESYSTEM MODIFICATIONS

## 12.1 The Docker Diff Command

Docker provides:

`docker diff`

This command identifies certain filesystem changes associated with a container relative to its initial image-based filesystem state.

Its general syntax is:

```text
docker diff CONTAINER
```

Example:

```bash
docker diff my-nginx
```

## 12.2 Change Categories

Docker represents changes using three principal symbols.

| Symbol | Interpretation            |
| ------ | ------------------------- |
| `A`    | Added file or directory   |
| `C`    | Changed file or directory |
| `D`    | Deleted file or directory |

For example:

```text
A /tmp/report.txt
C /etc/example.conf
D /tmp/old-data.txt
```

The output indicates that one file was added, one file was changed, and one file was deleted.

These paths are illustrative.

## 12.3 Diagnostic Applications

The `docker diff` command can assist with:

- Identifying unexpected filesystem modifications.
- Discovering temporary files.
- Examining application-generated artifacts.
- Investigating runtime configuration changes.
- Understanding container writable-layer behavior.

The output may include modifications associated with ordinary application execution and system-generated runtime files.

It should not be interpreted as a complete audit record of all application activity.

Changes within separately mounted storage resources may not be represented in the same way as changes to the container's writable layer.

---

# 13. CONTAINER RESOURCE MONITORING

## 13.1 Resource Utilization

Containerized processes consume computing resources supplied by the host environment.

Important resource categories include:

- CPU processing time.
- Physical and virtual memory.
- Network traffic.
- Storage I/O.
- Process and thread resources.

Observing resource consumption can help administrators investigate performance problems and identify abnormal application behavior.

## 13.2 The Docker Stats Command

Docker provides:

`docker stats`

This command displays resource usage statistics for running containers.

Example:

```bash
docker stats
```

The output is updated continuously in normal streaming mode.

To observe one container:

```bash
docker stats my-nginx
```

## 13.3 One-Time Statistics Collection

Docker supports the option:

`--no-stream`

Example:

```bash
docker stats --no-stream my-nginx
```

This requests a single statistics sample rather than a continuous stream.

It is useful when recording observations in laboratory reports.

## 13.4 Important Statistics Fields

| Field     | Meaning                                      |
| --------- | -------------------------------------------- |
| CPU %     | Reported CPU utilization                     |
| MEM USAGE | Reported memory consumption                  |
| MEM LIMIT | Applicable reported memory limit             |
| MEM %     | Reported percentage of memory limit used     |
| NET I/O   | Network data transfer statistics             |
| BLOCK I/O | Storage-related I/O statistics               |
| PIDS      | Count of reported processes and kernel tasks |

The precise output depends on the operating system and Docker configuration.

The `PIDS` measurement can include threads and should not always be interpreted as a count of independent application programs.

## 13.5 Interpretation of Statistics

Resource measurements must be interpreted in context.

For example:

A web server may use very little CPU while idle.

CPU usage may increase when it processes large numbers of requests.

Memory usage may remain relatively stable or increase depending on application behavior, caching, and workload.

A single statistics sample cannot establish long-term performance characteristics.

Performance analysis ordinarily requires repeated measurements, workload context, and knowledge of configured resource constraints.

## 13.6 Monitoring Versus Resource Limitation

Monitoring resource usage is different from restricting resource usage.

`docker stats` provides observational information.

Docker also supports resource-management configuration through mechanisms such as CPU and memory limits.

Those mechanisms will be examined in later operational lectures.

---

# 14. ENVIRONMENT VARIABLES WITHIN CONTAINERS

## 14.1 Definition

An environment variable is a named value supplied to a process as part of its execution environment.

Environment variables are commonly used to control software behavior without directly modifying application source code.

Examples may include:

- Application mode.
- Logging level.
- Service hostname.
- Port configuration.
- Runtime-specific settings.

## 14.2 Examining Environment Variables

The command:

```bash
docker exec my-nginx env
```

displays environment variables available to the executed command.

Common environment variables may include:

- `PATH`
- `HOME`
- `HOSTNAME`

The exact set depends on image configuration, container settings, the selected user, and the executed program.

## 14.3 Setting Variables for an Exec Process

Docker supports the `-e` option for additional processes started through `docker exec`.

Example:

```bash
docker exec -e COURSE_MODULE=03 my-nginx sh -c 'echo "$COURSE_MODULE"'
```

This command supplies an environment variable to the executed shell process.

The output should be:

```text
03
```

This does not permanently modify the container's original configuration.

It affects the environment of the additional process and processes that inherit its environment.

## 14.4 Environment Variables and Security

Environment variables are commonly used for configuration.

However, they are not inherently a secure secrets-management mechanism.

Sensitive values may be exposed through process environments, inspection interfaces, diagnostics, or application logging.

Secure handling of credentials requires appropriate access control and secrets-management practices.

These topics will be studied in the Docker security lecture.

---

# 15. USER IDENTITIES AND PERMISSIONS

## 15.1 Process User Identity

Operating systems use user and group identities as part of access-control enforcement.

Containerized processes also execute under user and group identities.

The effective user identity can influence whether a process is permitted to access a file or perform an operation.

## 15.2 Examining User Identity

The command:

```bash
docker exec my-nginx id
```

displays identity information for the executed process.

The output may include:

- User identifier.
- Group identifier.
- Additional group membership.

The exact result depends on the image and execution configuration.

## 15.3 Executing as a Selected User

Docker supports the `-u` or `--user` option.

For example:

```bash
docker exec -u 1000 my-nginx id
```

This requests command execution using the specified numeric user identifier.

The result depends on runtime configuration and the permissions associated with that identity.

## 15.4 Root Inside a Container

A process running as root inside a container should not automatically be understood as having unrestricted host-level root privileges.

Namespace configurations, Linux capabilities, security policies, and other runtime settings influence the process's effective authority.

However, root execution within containers still creates important security considerations.

A container configured with excessive privileges or sensitive host mounts can present serious risks.

The general principle of least privilege recommends assigning only the permissions required for application execution.

---

# 16. CONTAINER INSPECTION AND SECURITY

## 16.1 Administrative Access

The ability to execute commands inside a container is an administrative capability.

A user authorized to control a Docker daemon may be able to inspect sensitive container data, change application state, or access significant host resources.

Accordingly, Docker daemon access should be granted carefully.

## 16.2 Risks of Direct Modification

Directly modifying a running production container can cause:

1. Configuration inconsistency.
2. Unexpected application behavior.
3. Loss of reproducibility.
4. Unrecorded operational changes.
5. Security problems.
6. Differences between deployed containers.

Such modifications may also disappear when a container is removed and replaced.

## 16.3 Immutable Infrastructure Principles

Modern container workflows often favor an immutable deployment model.

In this model, application changes are introduced through new image builds rather than ad hoc modifications to running containers.

For example, instead of installing a missing dependency manually within a running production container, the dependency should generally be added to the application's image build specification.

A new image can then be constructed, tested, and deployed.

This improves traceability, reproducibility, and consistency.

## 16.4 Safe Diagnostic Practices

Administrators should follow several principles:

1. Prefer read-only inspection when possible.
2. Avoid installing unnecessary diagnostic programs in production containers.
3. Do not expose sensitive metadata or environment variables.
4. Avoid arbitrary privilege escalation.
5. Record important diagnostic findings.
6. Preserve relevant information before removing failed containers.
7. Rebuild images to implement permanent application changes.
8. Avoid changing host-mounted files without understanding their significance.

Container inspection should be systematic and controlled.

---

# 17. SYSTEMATIC CONTAINER TROUBLESHOOTING

## 17.1 Definition

Troubleshooting is the systematic process of identifying, analyzing, and correcting the causes of unexpected system behavior.

Effective troubleshooting begins with observation and evidence collection rather than arbitrary configuration changes.

## 17.2 Diagnostic Sequence

A practical diagnostic sequence consists of the following stages.

### Stage 1 — Identify the Container

Execute:

```bash
docker ps -a
```

Determine:

- Container name.
- Container ID.
- Image.
- Execution status.

### Stage 2 — Examine Logs

Execute:

```bash
docker logs CONTAINER_NAME
```

Search for application initialization failures, exceptions, and error messages.

### Stage 3 — Inspect Runtime State

Execute:

```bash
docker inspect CONTAINER_NAME
```

Examine the container's execution state, configuration, and relevant error information.

### Stage 4 — Examine Processes

If the container is running, execute:

```bash
docker top CONTAINER_NAME
```

Determine whether the expected application processes are active.

### Stage 5 — Examine Filesystem and Configuration

If the container is running and contains a suitable shell, execute:

```bash
docker exec -it CONTAINER_NAME sh
```

Inspect the relevant directories, configuration files, and runtime environment.

### Stage 6 — Examine Resource Usage

Execute:

```bash
docker stats --no-stream CONTAINER_NAME
```

Determine whether resource usage suggests a possible performance problem.

### Stage 7 — Inspect Filesystem Changes

Execute:

```bash
docker diff CONTAINER_NAME
```

Review filesystem changes that may be relevant to the problem.

### Stage 8 — Form and Test a Hypothesis

Develop a technically justified explanation based on the collected evidence.

Test the explanation using controlled actions.

### Stage 9 — Document the Resolution

Record:

- The observed symptoms.
- The evidence collected.
- The identified cause.
- The corrective action.
- The result of the correction.

## 17.3 Example Diagnostic Scenario

**Problem statement:**

A web application is reported as unavailable even though its Docker container appears to be running.

**Initial observation:**

`docker ps` indicates that the container remains active.

**Possible explanations:**

1. The application is listening on an unexpected port.
2. The required host port is not published.
3. Application configuration is incorrect.
4. A required file is missing.
5. The application process is active but unable to serve requests.

**Diagnostic approach:**

1. Inspect container port mappings.
2. Read application logs.
3. Examine running processes.
4. Inspect configuration files.
5. Verify the expected application listening configuration.

**Technical conclusion:**

Container running status alone does not establish application correctness.

Runtime state must be evaluated together with configuration and application-level evidence.

---

# 18. ESSENTIAL COMMAND REFERENCE

The following commands constitute the principal operational vocabulary of Lecture 03.

| Command                    | Function                                          |
| -------------------------- | ------------------------------------------------- |
| `docker exec`              | Execute a command inside a running container      |
| `docker exec -it`          | Start an interactive command session              |
| `docker exec -e`           | Supply environment variables to an exec process   |
| `docker exec -u`           | Execute a command using a selected user           |
| `docker exec -w`           | Select an execution working directory             |
| `docker inspect`           | Retrieve detailed object metadata                 |
| `docker top`               | Inspect container processes                       |
| `docker cp`                | Copy files between container and local filesystem |
| `docker diff`              | Inspect container filesystem changes              |
| `docker stats`             | Observe resource usage statistics                 |
| `docker stats --no-stream` | Retrieve a single resource statistics sample      |
| `docker logs`              | Retrieve available application logs               |
| `docker attach`            | Attach to an existing container process's streams |

## Commands Commonly Used Inside a Container

| Command  | Purpose                                   |
| -------- | ----------------------------------------- |
| `pwd`    | Display working directory                 |
| `ls`     | List directory contents                   |
| `cd`     | Change shell working directory            |
| `cat`    | Display file contents                     |
| `echo`   | Write text to standard output             |
| `printf` | Produce formatted text output             |
| `env`    | Display environment variables             |
| `id`     | Display user and group identities         |
| `mkdir`  | Create directories                        |
| `touch`  | Create or update a file                   |
| `rm`     | Remove files or directories               |
| `ps`     | Display process information, if available |
| `exit`   | Terminate the current shell               |

The availability of these commands depends on the container image.

---

# 19. PRACTICAL LABORATORY 03 — INSPECTION AND MODIFICATION OF A RUNNING CONTAINER

## 19.1 Laboratory Title

**Container Runtime Inspection, Filesystem Analysis, Process Observation, and File Transfer**

## 19.2 Laboratory Objective

The purpose of this laboratory is to demonstrate the practical techniques used to investigate and manage the internal environment of an existing running Docker container.

The laboratory uses an Nginx web-server container as its principal subject.

## 19.3 Requirements

- Docker Engine or Docker Desktop.
- Docker command-line access.
- A terminal.
- Internet access for image retrieval if necessary.
- A web browser.
- A writable local directory for laboratory files.

Commands are intended for a shell-compatible terminal such as Bash or PowerShell unless otherwise indicated.

Some command-line quoting details may require adaptation in Windows Command Prompt.

## Experiment 1 — Create the Laboratory Container

Execute:

```bash
docker run -d --name lecture03-nginx -p 127.0.0.1:8083:80 nginx:alpine
```

**Purpose:**

To create and start a controlled Nginx container for inspection.

**Expected result:**

Docker starts the container and displays its container identifier.

Verify:

```bash
docker ps
```

Open:

http://127.0.0.1:8083

The Nginx welcome page should appear.

**Observation record:**

Container ID: ********\_\_\_\_********

Image: ************\_\_************

Container name: ********\_\_********

Host port: **********\_\_\_**********

Container port: ********\_\_\_********

## Experiment 2 — Establish an Interactive Shell

Execute:

```bash
docker exec -it lecture03-nginx sh
```

**Purpose:**

To create an additional interactive shell process inside the running Nginx container.

Inside the container, execute:

```sh
pwd
```

Then:

```sh
ls -la /
```

Then:

```sh
cat /etc/os-release
```

**Required observations:**

1. Identify the shell's working directory.
2. Record at least five visible root directories.
3. Identify the user-space operating-system distribution reported by `/etc/os-release`.
4. Explain why this distribution information does not imply that the container has an independent kernel.

Exit the shell:

```sh
exit
```

Verify that the Nginx container is still running:

```bash
docker ps
```

**Analysis question:**

Why does terminating the additional shell process not ordinarily terminate the Nginx server?

## Experiment 3 — Examine Application Files

Execute:

```bash
docker exec lecture03-nginx ls -la /usr/share/nginx/html
```

Then:

```bash
docker exec lecture03-nginx cat /usr/share/nginx/html/index.html
```

**Purpose:**

To identify and examine the static content used by the Nginx web server.

**Expected result:**

The commands display directory information and the contents of the default website file.

**Analysis question:**

Explain the relationship between the filesystem content inside the container and the webpage returned by the Nginx service.

## Experiment 4 — Inspect Nginx Configuration

Execute:

```bash
docker exec lecture03-nginx ls -la /etc/nginx
```

Then:

```bash
docker exec lecture03-nginx cat /etc/nginx/nginx.conf
```

**Purpose:**

To examine the application configuration files included in the container image.

**Required observations:**

1. Identify the Nginx configuration directory.
2. Determine whether a principal configuration file exists.
3. Identify any referenced configuration directories.
4. Explain why application configuration may influence runtime behavior.

No modification to the Nginx configuration is required in this experiment.

## Experiment 5 — Examine Process Information

Execute from the host terminal:

```bash
docker top lecture03-nginx
```

**Purpose:**

To examine processes associated with the running container.

Record:

1. The principal server process.
2. Any visible worker processes.
3. Process identifiers, if displayed.
4. User identities associated with the processes, if displayed.

Now execute:

```bash
docker exec lecture03-nginx cat /proc/1/status
```

**Purpose:**

To examine information associated with PID 1 inside the container.

**Analysis question:**

Why may PID 1 inside the container correspond to a different PID in the Docker Engine host environment?

## Experiment 6 — Inspect Container Metadata

Execute:

```bash
docker inspect lecture03-nginx
```

**Purpose:**

To obtain a structured representation of the container's configuration and runtime state.

Because the output may be extensive, execute the following filtered queries.

**Determine current status:**

```bash
docker inspect --format '{{.State.Status}}' lecture03-nginx
```

**Determine configured image:**

```bash
docker inspect --format '{{.Config.Image}}' lecture03-nginx
```

**Determine principal process identifier:**

```bash
docker inspect --format '{{.State.Pid}}' lecture03-nginx
```

**Determine published port configuration:**

```bash
docker inspect --format '{{json .NetworkSettings.Ports}}' lecture03-nginx
```

**Required observations:**

Record the results of all four queries.

Explain the difference between configuration metadata and runtime state information.

## Experiment 7 — Examine Environment Variables

Execute:

```bash
docker exec lecture03-nginx env
```

**Purpose:**

To inspect the environment variables supplied to the executed process.

Identify:

- `PATH`, if present.
- `HOSTNAME`, if present.
- Any additional variables relevant to the image.

Now execute:

```bash
docker exec -e COURSE_LECTURE=03 lecture03-nginx sh -c 'echo "$COURSE_LECTURE"'
```

**Expected result:**

```text
03
```

**Analysis question:**

Does this operation permanently modify the container's original environment configuration?

Explain your answer.

Do not copy sensitive variable values into a publicly accessible laboratory report.

## Experiment 8 — Create a File Inside the Container

Execute:

```bash
docker exec lecture03-nginx sh -c 'printf "Docker Lecture 03 Laboratory\n" > /tmp/lecture03-note.txt'
```

**Purpose:**

To create a text file inside the container's writable filesystem.

Verify:

```bash
docker exec lecture03-nginx cat /tmp/lecture03-note.txt
```

**Expected result:**

```text
Docker Lecture 03 Laboratory
```

**Technical interpretation:**

The command creates a file within the container's filesystem environment.

For this laboratory's ordinary unmounted `/tmp` location, the file is stored in the container's writable filesystem state.

## Experiment 9 — Inspect Filesystem Changes

Execute:

```bash
docker diff lecture03-nginx
```

**Purpose:**

To examine filesystem modifications associated with the container.

Locate the entry corresponding to:

`/tmp/lecture03-note.txt`

**Expected observation:**

The created file should generally appear as an added filesystem object.

Other entries may be present because the Nginx application itself can create or modify runtime files.

**Analysis question:**

Why can filesystem changes appear even when the administrator has not manually modified application configuration?

## Experiment 10 — Copy a File from Container to Host

Execute from a writable local directory:

```bash
docker cp lecture03-nginx:/tmp/lecture03-note.txt ./lecture03-note.txt
```

**Purpose:**

To transfer the laboratory file from the container to the Docker client's local filesystem.

**Expected result:**

A file named `lecture03-note.txt` appears in the current directory.

Verify its contents using an appropriate local file-viewing command or text editor.

**Analysis question:**

Explain why Docker can copy a file from a container without requiring an interactive shell session.

## Experiment 11 — Copy a File from Host to Container

Execute:

```bash
docker cp ./lecture03-note.txt lecture03-nginx:/tmp/lecture03-imported.txt
```

Verify:

```bash
docker exec lecture03-nginx cat /tmp/lecture03-imported.txt
```

**Purpose:**

To demonstrate file transfer from the host environment into the existing container.

**Expected result:**

The imported file contains the text copied from the local file.

**Analysis question:**

Does copying the file into the container permanently modify the original image?

Explain the distinction between image content and container-specific writable state.

## Experiment 12 — Observe Resource Usage

Execute:

```bash
docker stats --no-stream lecture03-nginx
```

**Purpose:**

To collect one sample of container resource utilization.

Record:

- CPU percentage.
- Memory usage.
- Memory limit.
- Network I/O.
- Block I/O.
- PIDs value.

**Analysis question:**

Explain why these values may change between successive executions of the command.

## Experiment 13 — Verify Filesystem Persistence Across Restart

Stop the container:

```bash
docker stop lecture03-nginx
```

Start it again:

```bash
docker start lecture03-nginx
```

Verify that the original file remains available:

```bash
docker exec lecture03-nginx cat /tmp/lecture03-note.txt
```

**Expected result:**

The laboratory file remains present.

**Technical interpretation:**

Ordinary stop and start operations preserve the container object and its associated writable filesystem layer.

## Experiment 14 — Copy Data from a Stopped Container

Stop the container:

```bash
docker stop lecture03-nginx
```

Without restarting it, execute:

```bash
docker cp lecture03-nginx:/tmp/lecture03-note.txt ./lecture03-stopped-copy.txt
```

**Expected result:**

The file is copied successfully from the stopped container.

**Technical significance:**

The experiment demonstrates that Docker can access an existing container's filesystem even when its principal application process is no longer executing.

Now try:

```bash
docker exec lecture03-nginx pwd
```

**Expected result:**

The command fails because the container is not running.

**Analysis question:**

Explain why `docker cp` can operate on a stopped container while `docker exec` ordinarily cannot.

## Experiment 15 — Remove and Recreate the Container

Remove the stopped container:

```bash
docker rm lecture03-nginx
```

Create a new container using the same image:

```bash
docker run -d --name lecture03-nginx -p 127.0.0.1:8083:80 nginx:alpine
```

Attempt to read the previously created laboratory file:

```bash
docker exec lecture03-nginx cat /tmp/lecture03-note.txt
```

**Expected result:**

The file should not exist in the newly created container.

The new container was created from the original image and does not inherit the removed container's writable filesystem changes.

**Analysis question:**

Explain why a restart preserved the file but removal and recreation did not.

Finally, clean up the laboratory container:

```bash
docker stop lecture03-nginx
```

```bash
docker rm lecture03-nginx
```

These cleanup commands affect only the specifically named laboratory container.

The downloaded image may remain available for later lectures.

---

# 20. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Principal objective                | Observed result |
| ---------- | ---------------------------------- | --------------- |
| 1          | Container creation                 |                 |
| 2          | Interactive shell access           |                 |
| 3          | Application filesystem inspection  |                 |
| 4          | Configuration inspection           |                 |
| 5          | Process examination                |                 |
| 6          | Metadata inspection                |                 |
| 7          | Environment variable examination   |                 |
| 8          | File creation                      |                 |
| 9          | Filesystem change inspection       |                 |
| 10         | Container-to-host copying          |                 |
| 11         | Host-to-container copying          |                 |
| 12         | Resource monitoring                |                 |
| 13         | Restart persistence                |                 |
| 14         | Stopped-container file copying     |                 |
| 15         | Container recreation and data loss |                 |

## Laboratory Conclusion

Prepare a written conclusion of approximately 200–300 words explaining:

1. The role of `docker exec` in container administration.
2. The distinction between a container shell and the principal application process.
3. The organization of the container filesystem.
4. The relationship between image layers and writable container state.
5. The importance of container metadata and process inspection.
6. The difference between temporary container data and durable storage.
7. The significance of systematic diagnostic procedures.

---

# 21. COMMON ERRORS AND CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1: docker exec creates a new container.

Incorrect.

`docker exec` executes an additional process inside an existing running container.

It does not establish a new container identity.

## Misunderstanding 2: Every container contains Bash.

Incorrect.

Minimal container images may contain only `sh`, and some images contain no shell.

Command availability depends on the contents of the image.

## Misunderstanding 3: Exiting an exec shell stops the entire container.

Not ordinarily.

The additional shell process terminates, but the container's principal application process may continue running.

## Misunderstanding 4: Containers contain complete independent operating systems.

Incorrect.

A Linux container normally uses a shared Linux kernel while providing an isolated user-space execution environment.

## Misunderstanding 5: Changes made inside a running container modify its image.

Incorrect.

Ordinary filesystem writes affect the container's writable layer or mounted storage, not the immutable source image.

## Misunderstanding 6: Restarting a container removes its internal files.

Incorrect as a general statement.

Ordinary restarting retains the existing container's writable filesystem state.

However, independently mounted temporary resources or application-specific cleanup procedures may behave differently.

## Misunderstanding 7: Container removal and container restart have equivalent effects.

Incorrect.

Restarting retains the existing container object.

Removal deletes the container object and its associated writable layer.

## Misunderstanding 8: docker cp requires a running container.

Incorrect.

Docker can copy files to or from stopped containers as well as running containers.

## Misunderstanding 9: docker top requires the top program to be installed in the container.

Incorrect.

`docker top` retrieves process information through Docker Engine.

## Misunderstanding 10: A container that is running must be operating correctly.

Incorrect.

An application's principal process may remain active even when application-level functionality is impaired.

## Misunderstanding 11: Environment variables are automatically secure.

Incorrect.

Environment variables may become visible through application diagnostics, process inspection, or Docker metadata.

## Misunderstanding 12: Changes made during troubleshooting should remain in production containers.

Not generally recommended.

Permanent application changes should ordinarily be expressed through reproducible image builds and controlled deployments.

## Misunderstanding 13: Every Docker installation exposes the same host storage directories.

Incorrect.

Storage implementations and image-management backends vary according to Docker Engine version, configuration, and platform.

---

# 22. ACADEMIC ASSESSMENT

## Part A — Formal Definitions

Provide technically precise definitions of the following concepts.

1. Container inspection.
2. Docker exec.
3. Interactive shell.
4. Principal container process.
5. Process identifier.
6. PID namespace.
7. Container root filesystem.
8. Writable container layer.
9. Copy-on-write.
10. Container metadata.
11. Container filesystem modification.
12. Resource monitoring.
13. Environment variable.
14. Process user identity.
15. Immutable infrastructure.

## Part B — Short-Answer Questions

**Question 1.**

Explain the difference between `docker run` and `docker exec`.

**Question 2.**

Describe why a container must ordinarily be running before an additional command can be executed within it.

**Question 3.**

Explain the function of `-i` and `-t` in interactive container execution.

**Question 4.**

Explain why Bash may be unavailable inside an Alpine-based container.

**Question 5.**

Describe the relationship between a container's principal process and an interactive shell started using `docker exec`.

**Question 6.**

Identify the purpose of the `/proc` filesystem.

**Question 7.**

Explain the distinction between read-only image layers and writable container layers.

**Question 8.**

Describe how copy-on-write contributes to efficient image reuse.

**Question 9.**

Explain the purpose of `docker inspect`.

**Question 10.**

Describe how `docker cp` differs from a persistent volume or bind mount.

**Question 11.**

Explain the meaning of the `A`, `C`, and `D` indicators produced by `docker diff`.

**Question 12.**

Explain why a running container's CPU and memory utilization may change over time.

## Part C — Command Interpretation

Consider the command:

```bash
docker exec -it application-server sh
```

Answer:

1. Which container is targeted?
2. Does the command create a new container?
3. What executable is started?
4. What is the function of `-i`?
5. What is the function of `-t`?
6. What happens when the user exits the shell?
7. Under what circumstances will this command fail?

Now analyze:

```bash
docker cp application-server:/tmp/report.txt ./report.txt
```

Answer:

8. What is the source?
9. What is the destination?
10. Does the container need to be running?
11. Does this operation create a persistent synchronization relationship?

## Part D — Analytical Questions

**Question 13.**

A developer modifies an application configuration file through an interactive container shell.

The application continues operating correctly after the container is stopped and restarted.

However, the configuration change disappears after the container is removed and recreated.

Explain this behavior in terms of image layers, writable container storage, and container lifecycle management.

**Question 14.**

An application container does not contain the `ps` command.

Describe how an administrator can still obtain process information associated with that container.

**Question 15.**

A web service appears in the running-container list but does not respond to HTTP requests.

Develop a systematic troubleshooting procedure using Docker commands.

**Question 16.**

Explain why PID 1 inside a container may have a different identifier from the corresponding process viewed from the host environment.

**Question 17.**

Evaluate the risks associated with directly modifying the filesystem of a running production container.

Discuss how immutable deployment practices reduce these risks.

**Question 18.**

A container has exited unexpectedly.

The administrator needs to retrieve a diagnostic file stored in its writable filesystem.

Explain which Docker commands remain useful and which commands require the container to be running.

---

# 23. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Technical Investigation of Docker Container Execution Environments

Prepare an academic report of approximately 800–1,200 words addressing:

**“Inspection and Diagnostics of Docker Containers: Processes, Filesystems, Metadata, and Runtime State.”**

The report must contain:

1. An introduction explaining the importance of container inspection.
2. A description of the `docker exec` mechanism.
3. An explanation of interactive and non-interactive process execution.
4. A technical discussion of Linux process namespaces and PID 1.
5. An explanation of the container filesystem hierarchy.
6. A discussion of image layers and copy-on-write storage.
7. An analysis of Docker metadata inspection.
8. A discussion of file transfer between containers and hosts.
9. An explanation of resource monitoring and diagnostic commands.
10. A security analysis of direct container modifications.
11. A conclusion explaining the importance of systematic container troubleshooting.

The report should include technical command examples and appropriate references.

---

# 24. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 04, the student should be able to complete the following tasks independently.

- [ ] Start a container for inspection.
- [ ] Execute commands inside a running container.
- [ ] Start and exit an interactive shell.
- [ ] Explain the difference between `docker run` and `docker exec`.
- [ ] Identify major container filesystem directories.
- [ ] Inspect an application configuration file.
- [ ] Explain the role of PID 1.
- [ ] Inspect container processes using `docker top`.
- [ ] Read information from `/proc/1/status`.
- [ ] Retrieve container metadata with `docker inspect`.
- [ ] Extract individual inspection fields.
- [ ] Inspect environment variables.
- [ ] Determine the effective user identity of an executed process.
- [ ] Create a file in the container writable layer.
- [ ] Examine changes using `docker diff`.
- [ ] Copy a file from a container to the local filesystem.
- [ ] Copy a file from the local filesystem to a container.
- [ ] Obtain resource statistics using `docker stats`.
- [ ] Explain why files survive an ordinary container restart.
- [ ] Explain why writable-layer changes disappear after container removal.
- [ ] Retrieve a file from a stopped container.
- [ ] Follow a systematic diagnostic procedure without making unnecessary destructive changes.

**Completion standard:**

The student should demonstrate both operational competence and a technically accurate understanding of the mechanisms involved.

---

# 25. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. _Docker Container Exec — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/exec/

[2] Docker Inc. _Docker Container Inspect — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/inspect/

[3] Docker Inc. _Docker Container Top — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/top/

[4] Docker Inc. _Docker Container Copy — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/cp/

[5] Docker Inc. _Docker Container Diff — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/diff/

[6] Docker Inc. _Docker Container Stats — Command-Line Reference._  
https://docs.docker.com/reference/cli/docker/container/stats/

[7] Docker Inc. _Docker Storage Documentation._  
https://docs.docker.com/engine/storage/

[8] Docker Inc. _Docker Storage Drivers._  
https://docs.docker.com/engine/storage/drivers/

[9] Docker Inc. _Docker Container Management._  
https://docs.docker.com/reference/cli/docker/container/

[10] Docker Inc. _Running Containers._  
https://docs.docker.com/engine/containers/run/

## Recommended Reading Sequence

Students should begin with references [1] and [2] to establish an understanding of command execution and metadata inspection.

References [3], [4], [5], and [6] provide detailed descriptions of process inspection, file transfer, filesystem change tracking, and resource monitoring.

References [7] and [8] provide the necessary background for understanding image layers and container writable storage.

References [9] and [10] provide broader operational context.

---

# 26. FINAL LECTURE CONCLUSION

Docker container inspection is an essential component of container-based software development, operations, and troubleshooting.

While container lifecycle commands permit administrators to create, start, stop, and remove execution environments, inspection commands provide the mechanisms required to understand their internal operation.

The `docker exec` command enables additional processes to execute inside an existing running container.

The `docker inspect` command exposes configuration and runtime metadata.

The `docker top` command provides process visibility.

The `docker cp` command facilitates file transfer between local and container filesystems.

The `docker diff` command exposes changes associated with container filesystem state.

The `docker stats` command supports the observation of resource consumption.

Together, these capabilities allow administrators to investigate containerized applications systematically.

A fundamental conclusion of this lecture is that a Docker container is not an independent virtual computer, but an isolated execution environment consisting of processes, configuration, filesystem state, and managed resources.

The ability to inspect these elements individually is necessary for diagnosing application problems and understanding container behavior.

A second important conclusion concerns filesystem persistence.

Container writable layers are associated with specific container instances. While ordinary restarting preserves this state, removing and recreating a container ordinarily discards it.

For this reason, reproducible software images and independently managed persistent storage are fundamental principles of reliable container-based systems.

Mastery of these concepts establishes the technical foundation for understanding Docker images, image construction, advanced networking, persistent storage, and multi-container application architectures.

---

**END OF LECTURE 03**

**Next Lecture:** Lecture 04 — Docker Images and Image Registries: Image Architecture, Layers, Tags, Distribution, and Docker Hub.
