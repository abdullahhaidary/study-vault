# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 02 — DOCKER CONTAINERS: CREATION, EXECUTION, LIFECYCLE MANAGEMENT, AND RUNTIME OPERATIONS

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 02 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 3–4 hours  
**Prerequisite:** Lecture 01 — Introduction to Docker and Containerization Technology

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Explain the technical nature of a Docker container as an isolated execution environment.
2. Describe the relationship between container images, container instances, and operating-system processes.
3. Identify and explain the principal stages of the Docker container lifecycle.
4. Distinguish between the creation, execution, termination, restarting, and removal of containers.
5. Explain the difference between foreground, detached, and interactive container execution.
6. Interpret the purpose of standard input, standard output, standard error, and pseudo-terminals.
7. Create containers using the `docker run` command.
8. Identify containers through unique identifiers and assigned names.
9. Examine running and stopped containers using Docker command-line operations.
10. Explain the fundamental principles of container port publishing.
11. Manage containers using start, stop, restart, and removal operations.
12. Retrieve and interpret basic container logs.
13. Describe how the termination of a container's principal process affects its lifecycle.
14. Explain the distinction between a stopped container and a removed container.
15. Diagnose elementary errors related to container startup and management.
16. Complete a practical container administration laboratory.

---

# 2. THE TECHNICAL NATURE OF A DOCKER CONTAINER

## 2.1 Definition of a Container

A Docker container is a runtime instance created from a container image and executed within an isolated operating-system environment.

A container consists of an application execution configuration, a filesystem environment, and one or more processes operating under isolation mechanisms provided by the container runtime and the underlying operating system.

A container is not a complete operating system. It is an execution environment in which processes operate with a restricted and configured view of system resources.

In Linux-based Docker environments, containerized processes ordinarily share the kernel of the Linux operating system on which the container engine operates.

The environment presented to these processes may include isolated process identifiers, filesystem mounts, network interfaces, and hostname information.

From the operating system's perspective, the processes are still actual operating-system processes. Their isolation is established through kernel-supported mechanisms rather than through the creation of a separate operating-system kernel.

**Formal definition:**

A Docker container is an isolated and configurable execution instance derived from a container image, within which application processes execute using a defined filesystem, runtime configuration, and operating-system resource boundaries.

## 2.2 Containers as Process Execution Environments

One of the most important concepts in Docker is the relationship between containers and processes.

A process is an executing instance of a computer program.

An operating system manages processes by allocating CPU time, memory, and access to other system resources.

Docker containers operate through this same underlying process model.

When a container starts, Docker launches a designated initial process within the container's execution environment.

This process may be:

- A web server.
- A database server.
- A programming language interpreter.
- An application executable.
- A shell.
- A background processing program.
- A short-lived utility.

A container may contain several processes, but its lifecycle is normally governed by its designated principal process.

For example, an Nginx container typically starts an Nginx server process that remains active while the web service is operating.

By contrast, a container executing a command that prints a message and exits may operate for only a fraction of a second.

Both are valid examples of container execution.

## 2.3 The Relationship Between Images and Containers

Docker images and Docker containers represent different stages of application packaging and execution.

A Docker image contains a standardized set of filesystem layers and image configuration information.

A Docker container represents an instance created from that image.

The relationship can be represented as follows. The image holds the application files, dependencies, libraries, and configuration; container creation produces separate containers from it:

```text
DOCKER IMAGE → Container A (container creation)
DOCKER IMAGE → Container B (container creation)
DOCKER IMAGE → Container C (container creation)
```

Each container is created from the same image but may have different runtime configurations and execution states.

For example, three containers may originate from the `nginx:alpine` image.

One container may listen through host port 8080, another through host port 8081, and a third may remain stopped.

These containers are separate instances even though they share the same image.

## 2.4 Container Configuration and Runtime State

A container can be understood in terms of two related categories of information.

**Container configuration** specifies how the container should operate.

This may include:

1. The source image.
2. The initial executable or command.
3. Environment variables.
4. Network configuration.
5. Published ports.
6. Mounted storage.
7. Resource limits.
8. Security settings.
9. Container name.
10. Restart policy.

**Container runtime state** describes the container's current operational condition.

This may include:

1. Whether the container has started.
2. Whether its principal process is running.
3. Its process identifier.
4. The time at which it started.
5. Whether it has exited.
6. Its exit status.
7. Whether it is paused.
8. Whether it is restarting.

The distinction between configuration and runtime state is important because a container can retain its configuration after its processes terminate.

A stopped container remains a Docker object until it is removed.

---

# 3. THE DOCKER CONTAINER LIFECYCLE

## 3.1 Definition of Container Lifecycle

The container lifecycle refers to the sequence of operational states and management transitions experienced by a container from its creation until its removal.

A Docker container does not necessarily begin executing immediately after its configuration is created.

The container may first be created without starting its processes.

Similarly, termination of its processes does not necessarily cause the container object to be deleted.

Docker separates the management of container objects from the execution of their processes.

## 3.2 Principal Container States

Docker recognizes several container states.

### 3.2.1 Created

The *created* state indicates that a container object has been created but has not yet been started.

Docker has established its configuration and relevant metadata.

However, the container's principal application process has not begun executing.

A container may enter this state when created explicitly with:

`docker create`

### 3.2.2 Running

The *running* state indicates that the container's principal process has been started and the container is considered active.

Running containers may execute web servers, databases, scripts, or other applications.

A container normally remains running while its designated principal process remains active.

### 3.2.3 Exited

The *exited* state indicates that the container's principal process has terminated.

Termination may occur because:

- The application completed its work.
- The process terminated normally.
- The process encountered an error.
- The container received a termination signal.
- A user requested that Docker stop the container.

An exited container ordinarily retains its object metadata and writable filesystem layer unless it is configured for automatic removal.

### 3.2.4 Paused

The *paused* state indicates that execution of the container's processes has been temporarily suspended.

On Linux, Docker can use kernel mechanisms to freeze the container's processes.

Pausing a container differs from stopping it.

A paused container retains its running processes in a suspended condition, whereas a stopped container has no running principal process.

### 3.2.5 Restarting

The *restarting* state indicates that Docker is attempting to restart a container under an applicable restart policy.

For example, a container configured to restart after certain failures may temporarily appear in the restarting state while Docker attempts to start it again.

### 3.2.6 Removing

The *removing* state represents the process through which Docker deletes a container object and releases associated resources.

### 3.2.7 Dead

The *dead* state identifies a container that is no longer functioning normally and could not be fully removed or cleaned up.

This state may be associated with unusual runtime or resource-management failures.

It is not part of ordinary successful container operation.

## 3.3 Container Lifecycle State Model

A simplified lifecycle can be represented as:

```text
IMAGE → CREATED (docker create)
CREATED → RUNNING (docker start)
RUNNING → EXITED (docker stop)
RUNNING → EXITED (main process exits)
EXITED → RUNNING (docker start)
EXITED → REMOVED (docker rm, from an eligible stopped state)
```

This diagram describes the principal lifecycle operations.

Additional transitions exist for pausing, unpausing, automatic restarting, and abnormal container states.

## 3.4 Container Creation Versus Container Execution

The operations of creating and starting a container must be distinguished.

The command:

`docker create nginx:alpine`

creates a new container without starting its application process.

The command:

`docker start CONTAINER_NAME`

starts an existing container.

The command:

`docker run nginx:alpine`

combines container creation and startup into a single operation.

Conceptually:

**docker run ≈ docker create + docker start**

This represents the general sequence of operations rather than an exact description of every internal Docker Engine procedure.

## 3.5 Container Termination and Removal

Stopping a container and removing a container are fundamentally different operations.

**Stopping a container** ends the execution of its principal process while retaining the container object.

**Removing a container** deletes the container object and its associated writable filesystem layer.

The container's underlying image is not automatically deleted when the container is removed.

Consequently, the same image may be used to create additional containers after earlier containers have been removed.

---

# 4. CONTAINER IDENTIFICATION AND NAMING

## 4.1 Container Identifiers

Every Docker container is assigned a unique container identifier.

The identifier allows Docker to distinguish one container object from another.

Docker commonly displays shortened identifiers in command output.

An illustrative identifier is:

`b73c8e2f914a`

The complete identifier is substantially longer.

Docker commands may accept a sufficiently unique prefix of the container identifier instead of requiring the entire identifier.

## 4.2 Container Names

Docker also supports human-readable container names.

Names provide a convenient method for identifying and managing containers.

A container can be assigned a name through the `--name` option.

Example:

```bash
docker run -d --name web-server nginx:alpine
```

In this command:

- `docker` invokes the Docker client.
- `run` requests container creation and execution.
- `-d` specifies detached execution.
- `--name web-server` assigns the container name.
- `nginx:alpine` identifies the source image.

The container can subsequently be referenced by its name.

For example:

```bash
docker stop web-server
```

## 4.3 Automatically Generated Names

When no explicit name is supplied, Docker generates a name automatically.

An illustrative generated name might be:

`hopeful_turing`

Generated names are valid container identifiers for command-line management.

However, explicitly assigned names are often preferable in development and instructional environments because they provide more recognizable references.

## 4.4 Naming Constraints

Within a Docker daemon's container namespace, container names must be unique among existing containers.

An attempt to create a container using a name already assigned to another container normally produces a naming conflict.

This rule applies even if the existing container is stopped.

A stopped container still exists and retains its name.

To reuse the name, the existing container must be removed or renamed.

## 4.5 Container Identity and Persistence

A stopped container normally retains its identifier, name, and configuration.

Starting the stopped container does not create a new container identity.

However, removing a container and subsequently creating another container from the same image creates a distinct container with a new identifier.

This distinction is significant when examining application state and persistent storage.

---

# 5. CONTAINER EXECUTION MODES

Docker supports different ways of interacting with container processes.

The principal execution patterns discussed in this lecture are foreground execution, detached execution, and interactive execution.

These patterns are determined by process behavior and configuration flags.

## 5.1 Foreground Execution

Foreground execution is the default behavior of `docker run` when detached mode is not specified.

In foreground mode, the Docker client remains attached to the container's configured output streams and waits for the container's execution to complete.

For example:

```bash
docker run --rm alpine:3.20 echo "Container executed"
```

This command starts a temporary Alpine Linux container, executes the `echo` program, prints the message, and exits.

The terminal displays the application output.

Because the container is short-lived, execution completes almost immediately.

The `--rm` option requests automatic removal of the container after termination.

Foreground execution does not imply that a container must provide an interactive command prompt.

A program may execute in the foreground without requesting any input from the user.

## 5.2 Detached Execution

Detached execution allows a container to operate without occupying the terminal session through which it was started.

The detached execution option is:

`-d`

Its long form is:

`--detach`

Example:

```bash
docker run -d --name web-server nginx:alpine
```

Docker starts the container and returns control to the terminal.

The command normally prints the new container's identifier.

The Nginx server continues executing independently of the command-line client's attachment.

Detached execution is commonly used for:

1. Web servers.
2. Database services.
3. Background workers.
4. Message brokers.
5. API services.
6. Long-running applications.

Detached mode should not be confused with persistence or high availability.

A detached container may still terminate if its application exits or fails.

## 5.3 Interactive Execution

Interactive execution allows a user to communicate with a containerized process through standard input.

The principal option is:

`-i`

Its long form is:

`--interactive`

This option keeps the standard input stream open.

Interactive execution is frequently combined with terminal allocation.

## 5.4 Pseudo-Terminal Allocation

The option:

`-t`

requests allocation of a pseudo-terminal.

A pseudo-terminal provides terminal-like facilities to a process, supporting interactive command-line applications.

The `-i` and `-t` options are commonly combined as:

`-it`

Example:

```bash
docker run --rm -it alpine:3.20 sh
```

This command creates and executes a container using the Alpine Linux image.

The `sh` command launches a shell within the container.

The shell accepts user commands through the terminal.

When the shell exits, the container's principal process terminates.

Because `--rm` was specified, the container is automatically removed.

## 5.5 Foreground, Detached, and Interactive Comparison

| Property | Foreground | Detached | Interactive |
|---|---|---|---|
| Primary purpose | Attach to process execution | Run without terminal attachment | Communicate with an application |
| Common flag | Default behavior | `-d` | `-i` |
| Terminal allocation | Optional | Not required | Often combined with `-t` |
| Typical application | Short commands | Long-running services | Shell sessions |
| Client waits for execution | Usually yes | No | Usually yes when attached |
| Container can terminate | Yes | Yes | Yes |

Foreground and interactive execution are not identical concepts.

Foreground execution concerns attachment to the process.

Interactive execution concerns input communication.

A container may execute in the foreground without being interactive.

## 5.6 Standard Input, Output, and Error

Operating systems commonly provide processes with three standard communication streams.

**Standard Input (STDIN):**

The input stream through which a program receives data.

**Standard Output (STDOUT):**

The output stream through which a program writes ordinary output.

**Standard Error (STDERR):**

The output stream through which a program writes diagnostic information and error messages.

Docker can connect these streams to a terminal or route their output to a configured logging system.

Understanding these streams is essential for troubleshooting and operating containerized applications.

---

# 6. THE DOCKER RUN COMMAND

## 6.1 Definition

The `docker run` command creates and starts a container using a specified image and execution configuration.

Its general syntax is:

```text
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

Where:

**OPTIONS** define container execution characteristics.

**IMAGE** identifies the container image.

**COMMAND** optionally overrides the image's default command.

**ARG** represents arguments provided to the command.

## 6.2 Example Analysis

Consider:

```bash
docker run -d --name my-nginx -p 8080:80 nginx:alpine
```

The components are interpreted as follows:

| Component | Meaning |
|---|---|
| `docker` | Docker command-line client |
| `run` | Create and start a container |
| `-d` | Detached execution |
| `--name my-nginx` | Assign a container name |
| `-p 8080:80` | Publish container port 80 on host port 8080 |
| `nginx:alpine` | Container image |

The image name includes a tag.

In this example, `nginx` identifies the image repository and `alpine` identifies a particular image variant.

The container executes the default command configured by the selected image.

## 6.3 The Image Availability Process

When `docker run` is executed, Docker checks whether the requested image is locally available.

If the image is not available, Docker normally attempts to retrieve it from a configured image registry.

After the image becomes available, Docker proceeds with container creation and startup.

The image retrieval operation does not need to occur every time a container is started.

An already available image can normally be reused.

## 6.4 Creation of Multiple Containers from One Image

The following commands create two independent containers from the same image:

```bash
docker run -d --name web-one -p 8081:80 nginx:alpine

docker run -d --name web-two -p 8082:80 nginx:alpine
```

Both containers are based on the `nginx:alpine` image.

However, they have distinct names, container identifiers, runtime states, and host port mappings.

This demonstrates that a container image is reusable and is not limited to producing a single container.

---

# 7. INSPECTING CONTAINER STATUS

## 7.1 The Docker PS Command

The command:

`docker ps`

displays containers that are currently running.

The command is equivalent to:

`docker container ls`

Typical output includes the following fields:

- CONTAINER ID.
- IMAGE.
- COMMAND.
- CREATED.
- STATUS.
- PORTS.
- NAMES.

## 7.2 Understanding the Output Fields

**CONTAINER ID:** A shortened representation of the unique identifier assigned to the container.

**IMAGE:** The image reference associated with the container.

**COMMAND:** The configured command used to start the container.

**CREATED:** Information describing when the container was created.

**STATUS:** Information about the container's current execution condition.

**PORTS:** Information about exposed and published container ports.

**NAMES:** The name assigned to the container.

## 7.3 Listing All Containers

The command:

```bash
docker ps -a
```

displays all existing containers, including stopped containers.

The option:

`-a`

means:

`--all`

This distinction is essential for container administration.

A container that does not appear in the normal `docker ps` output may still exist.

It may simply be stopped.

## 7.4 Interpreting Container Status Information

Common status expressions include:

`Up 5 minutes`

This indicates that the container has been running for approximately five minutes.

`Exited (0)`

This indicates that the container's principal process terminated with exit status zero.

`Exited (1)`

This indicates that the process terminated with exit status one, commonly associated with an application or command error.

`Created`

This indicates that the container has been created but not started.

`Restarting`

This indicates that Docker is attempting to restart the container.

An exit status of zero conventionally indicates successful program termination.

A nonzero exit status generally indicates an error or exceptional termination condition, although the precise interpretation depends on the application.

## 7.5 Filtering Container Listings

Docker supports filtering the container list.

For example:

```bash
docker ps -a --filter status=exited
```

This command lists containers in the exited state.

Another example:

```bash
docker ps --filter name=web
```

This command filters the running container list according to names matching the specified text.

Filtering becomes particularly useful when a Docker host operates a large number of containers.

---

# 8. STARTING, STOPPING, AND RESTARTING CONTAINERS

## 8.1 Starting an Existing Container

The command:

`docker start`

starts an existing container.

General syntax:

```text
docker start CONTAINER
```

Example:

```bash
docker start my-nginx
```

This operation differs from `docker run`.

`docker run` creates a new container.

`docker start` starts an existing container using its previously established configuration.

## 8.2 Stopping a Container

The command:

`docker stop`

requests the termination of a running container.

Example:

```bash
docker stop my-nginx
```

Docker normally attempts a graceful shutdown by delivering a termination signal to the container's principal process.

For a typical Linux container, the default termination signal is `SIGTERM`, unless another stop signal has been configured.

The process is given an opportunity to terminate.

If it does not exit within the configured grace period, Docker may send `SIGKILL` to force termination.

This procedure supports orderly shutdown when the application handles termination signals appropriately.

## 8.3 Graceful Shutdown

Graceful shutdown refers to the controlled termination of an application.

During graceful shutdown, an application may perform operations such as:

- Completing active requests.
- Closing network connections.
- Releasing resources.
- Writing buffered information.
- Finalizing transactions.
- Closing open files.

Not all applications implement graceful shutdown correctly.

A container may therefore terminate without completing all desirable shutdown procedures.

## 8.4 Restarting a Container

The command:

`docker restart`

requests that Docker restart an existing container.

Example:

```bash
docker restart my-nginx
```

For a running container, Docker normally initiates a stop operation followed by a start operation.

For an eligible stopped container, restarting causes it to start again.

The container retains its established identity and basic configuration.

Restarting is distinct from deleting and recreating a container.

## 8.5 Stopping Versus Restarting Versus Removing

| Operation | Process execution | Container object | Original image |
|---|---|---|---|
| Stop | Terminates | Retained | Retained |
| Start | Begins again | Retained | Retained |
| Restart | Stops and starts | Retained | Retained |
| Remove | Not running afterward | Deleted | Retained |

These distinctions form a fundamental part of Docker lifecycle management.

## 8.6 Stopping and Starting Do Not Create a New Image

An important conceptual point is that ordinary container lifecycle management does not require rebuilding the underlying image.

For example:

```bash
docker stop my-nginx
docker start my-nginx
```

These commands operate on the existing container object.

They do not create a new image.

Similarly, the container's writable filesystem layer generally remains associated with the container through normal stop and start operations.

---

# 9. REMOVING DOCKER CONTAINERS

## 9.1 Definition of Container Removal

Container removal is the process of deleting a Docker container object and releasing its associated container-specific resources.

Docker provides the command:

`docker rm`

Example:

```bash
docker rm my-nginx
```

The container normally must be stopped before it can be removed using the standard command.

## 9.2 Removal of a Running Container

Docker also supports forced container removal.

Example:

```bash
docker rm -f my-nginx
```

The option:

`-f`

requests forced removal.

For a running container, this can abruptly terminate execution.

Forced removal should be used carefully because it may interrupt active operations and prevent graceful application shutdown.

In routine container administration, a controlled stop operation followed by normal removal is generally preferable.

## 9.3 Automatic Container Removal

Docker supports an automatic removal option:

`--rm`

Example:

```bash
docker run --rm alpine:3.20 echo "Temporary execution"
```

When the container exits, Docker automatically removes the container object.

This is useful for short-lived commands and temporary development operations.

However, a container created with `--rm` cannot ordinarily be restarted after it exits because Docker has already removed the container object.

Automatic removal also affects certain associated temporary storage resources.

It does not automatically delete the original image or all possible persistent storage resources.

## 9.4 Container Removal and Data Loss

A container's writable filesystem layer is normally deleted when the container is removed.

Files stored only within that writable layer may therefore be lost.

For applications requiring durable data storage, Docker provides mechanisms such as named volumes and bind mounts.

These mechanisms will be studied in the storage lecture.

The distinction between removing a container and deleting persistent storage is extremely important for database administration.

## 9.5 Container Removal Versus Image Removal

The command:

`docker rm`

removes a container.

The command:

`docker rmi`

removes an image, subject to image usage and dependency constraints.

These commands perform different operations.

Removing a container does not automatically remove its image.

Conversely, Docker may prevent removal of an image that is still required by existing containers unless the relevant conflicts are resolved.

---

# 10. CONTAINER NETWORK PORT PUBLISHING

## 10.1 Introduction

Containerized applications frequently need to communicate with software or users outside their own execution environment.

A web server running in a container may need to accept requests from a browser running on the host computer.

Docker provides port publishing mechanisms to facilitate this communication.

A port is a transport-layer communication identifier associated with a network endpoint.

In commonly used TCP/IP networking, port numbers help direct network traffic to the appropriate application service.

## 10.2 Host Ports and Container Ports

Docker distinguishes between ports associated with the host network environment and ports used by processes inside containers.

**Host port:** A port on the Docker host to which incoming connections may be directed.

**Container port:** A port on which an application inside the container listens.

For example, an Nginx web server may listen on TCP port 80 inside its container.

The Docker host may provide access to this service through TCP port 8080.

## 10.3 Port Publishing Syntax

Docker provides the option:

`-p`

Its long form is:

`--publish`

A common syntax is:

```text
-p HOST_PORT:CONTAINER_PORT
```

Example:

```bash
docker run -d -p 8080:80 nginx:alpine
```

This command publishes container TCP port 80 through host port 8080.

The traffic path can be expressed as:

```text
          WEB BROWSER
               |
               |
       http://localhost:8080
               |
               v
         HOST PORT 8080
               |
         Docker Networking
               |
               v
       CONTAINER PORT 80
               |
               v
          NGINX SERVER
```

Docker performs the necessary network configuration to enable the mapping in supported networking modes.

## 10.4 Understanding localhost

The term `localhost` normally refers to the local loopback interface of a computing environment.

The IPv4 loopback address is:

`127.0.0.1`

When a user opens:

`http://localhost:8080`

the browser attempts to establish a connection to TCP port 8080 on the local computer.

If Docker has published that host port to a container, the connection can be forwarded to the containerized service.

It is important to understand that `localhost` inside a container ordinarily refers to that container's own network namespace, not directly to the host computer.

## 10.5 Publishing to a Specific Host Interface

A port mapping can include a host IP address.

Example:

```bash
docker run -d \
  -p 127.0.0.1:8080:80 \
  nginx:alpine
```

This configuration restricts the published endpoint to the host's IPv4 loopback interface under normal supported Docker networking behavior.

The more general command:

```bash
docker run -d -p 8080:80 nginx:alpine
```

normally publishes the port on the host's available network interfaces by default.

Depending on host firewall and networking configuration, the service may therefore become reachable by other computers.

Restricting the host address is preferable for many local development exercises.

## 10.6 Port Publishing Does Not Create a Web Server

Port publishing is a networking operation.

It does not itself start an application or cause a program to listen on a port.

For a published service to function, a process inside the container must listen on the appropriate container port.

For example, mapping host port 8080 to container port 80 does not produce a functioning HTTP service if no application is listening on TCP port 80.

## 10.7 Port Conflicts

A port conflict occurs when an application attempts to use a host address and port combination already occupied by another service.

For example, if one container has already published host port 8080, attempting to start another container with an incompatible binding to the same port may fail.

An alternative host port can resolve this problem.

Example:

```bash
docker run -d --name nginx-one -p 127.0.0.1:8080:80 nginx:alpine

docker run -d --name nginx-two -p 127.0.0.1:8081:80 nginx:alpine
```

Both containers listen on port 80 internally.

However, their host port assignments differ.

The first is accessible through host port 8080.

The second is accessible through host port 8081.

This arrangement demonstrates the independence between a container's internal service port and the external host port through which the service is published.

---

# 11. CONTAINER LOGGING

## 11.1 Definition of Application Logs

Application logs are records produced by software during execution.

Logs may describe:

- Application startup.
- Successful operations.
- Incoming requests.
- Warning conditions.
- Errors.
- Process termination.
- Diagnostic information.

Logs are important for troubleshooting, operational monitoring, and understanding application behavior.

## 11.2 Docker Logging Mechanisms

Containerized applications commonly write output to standard output and standard error.

Docker captures and processes these output streams according to the configured logging driver.

Depending on the logging configuration, output can be retained locally or transmitted to other logging systems.

The availability of logs through Docker commands depends upon the logging driver and its supported operations.

## 11.3 Retrieving Container Logs

The command:

`docker logs`

retrieves available log records associated with a container.

Example:

```bash
docker logs my-nginx
```

This command displays available log output from the specified container.

## 11.4 Following Logs in Real Time

The option:

`-f`

means:

`--follow`

Example:

```bash
docker logs -f my-nginx
```

This command follows the container's available log stream, displaying additional records as they become available.

The operation is useful when observing a running application.

The user can ordinarily stop following the logs through the terminal's interrupt key combination.

Stopping the `docker logs -f` client operation does not normally terminate the underlying container.

## 11.5 Displaying a Limited Number of Records

The option:

`--tail`

restricts output to a specified number of recent log lines.

Example:

```bash
docker logs --tail 20 my-nginx
```

This displays up to 20 of the most recent available log lines.

## 11.6 Displaying Timestamps

The option:

`-t`

or:

`--timestamps`

includes timestamps in log output.

Example:

```bash
docker logs -t my-nginx
```

Timestamps can assist in determining when application events occurred.

## 11.7 Logs and Container Status

Logs should be interpreted together with container state.

A container may exit because its application completed successfully, not because an error occurred.

Similarly, a container may remain running while its application produces warnings or encounters partial failures.

Therefore, neither log output nor running status alone provides a complete assessment of application health.

---

# 12. THE PRINCIPAL PROCESS AND CONTAINER TERMINATION

## 12.1 Process Lifecycle and Container Lifecycle

The execution lifecycle of a container is closely associated with the lifecycle of its designated principal process.

In a typical Linux container using its own PID namespace, the initial process commonly has process identifier 1 within that namespace.

This process plays a central role in the container's execution.

When it exits, Docker normally considers the container's execution complete.

## 12.2 Short-Lived Processes

Consider a container executing:

```bash
docker run --rm alpine:3.20 echo "Hello Docker"
```

The process prints its message and exits.

Because the principal process has terminated, the container stops.

There is no requirement for the container to remain active after its task is complete.

This makes containers useful for batch operations and one-time computational tasks.

## 12.3 Long-Running Processes

Consider:

```bash
docker run -d --name web-server nginx:alpine
```

The Nginx image is configured to start a long-running server process.

The container ordinarily remains active while this principal process continues operating.

If the server exits, the container normally exits as well.

## 12.4 Why a Container May Stop Immediately

A newly started container may terminate almost immediately for several reasons:

1. The assigned command completed successfully.
2. The configured executable was invalid.
3. The application encountered an error.
4. Required configuration was missing.
5. The application could not access a required resource.
6. The application failed to initialize.
7. An execution dependency was unavailable.

An immediately exited container should not automatically be interpreted as a Docker Engine failure.

The cause may be normal application behavior.

## 12.5 Exit Codes

An exit code is a numeric value indicating how a program terminated.

In conventional Unix-like process environments:

- Exit code `0` normally indicates successful completion.
- A nonzero exit code generally indicates an error or exceptional condition.

Certain exit codes have commonly recognized meanings.

For example, termination through `SIGKILL` is frequently represented as exit code 137, although the underlying reason for receiving that signal must still be investigated.

Docker reports process exit information through container state metadata.

Exit codes are therefore useful diagnostic information, but they must be interpreted in the context of the application's behavior.

---

# 13. ESSENTIAL DOCKER CONTAINER COMMANDS

The following commands form the core command-line vocabulary of Lecture 02.

| Command | Principal function |
|---|---|
| `docker run` | Create and start a new container |
| `docker create` | Create a container without starting it |
| `docker ps` | Display running containers |
| `docker ps -a` | Display all existing containers |
| `docker start` | Start a stopped container |
| `docker stop` | Request a container to stop |
| `docker restart` | Restart an existing container |
| `docker rm` | Remove a container |
| `docker logs` | Retrieve available container logs |
| `docker logs -f` | Follow container log output |
| `docker logs --tail N` | Display recent log lines |
| `docker port` | Display published port mappings |
| `docker inspect` | Display detailed object information |
| `docker kill` | Send a signal to a container process |
| `docker pause` | Suspend container processes |
| `docker unpause` | Resume paused processes |

The final four commands provide additional administrative capabilities and will be examined in greater depth in the following lecture.

## 13.1 Important Docker Run Options

| Option | Meaning |
|---|---|
| `-d` | Detached execution |
| `-i` | Keep standard input open |
| `-t` | Allocate a pseudo-terminal |
| `-it` | Combine interactive input and terminal allocation |
| `--name` | Assign a container name |
| `-p` | Publish a container port |
| `--rm` | Automatically remove the container after exit |
| `--restart` | Define a restart policy |
| `-e` | Supply an environment variable |
| `--network` | Select a network configuration |
| `-v` | Configure a volume or bind mount |

Not all options are examined experimentally in this lecture. Some belong to later topics involving storage, networking, and application configuration.

---

# 14. PRACTICAL LABORATORY 02 — DOCKER CONTAINER ADMINISTRATION

## 14.1 Laboratory Title

**Creation, Execution, Monitoring, Lifecycle Management, and Removal of Docker Containers**

## 14.2 Laboratory Objective

The purpose of this laboratory is to demonstrate the behavior of Docker containers under different lifecycle operations and execution modes.

Upon completion, the student should be able to create and manage a functioning web-server container, inspect its execution state, examine its logs, and remove it without deleting its underlying image.

## 14.3 Laboratory Requirements

Required materials:

1. A computer with Docker Engine or Docker Desktop installed.
2. Access to a terminal.
3. Network access to obtain the required images.
4. A web browser.
5. Basic familiarity with Docker commands from Lecture 01.

The examples use the following images:

`nginx:alpine`

`alpine:3.20`

Some systems may already have these images cached locally.

For consistency, commands in this laboratory are written on individual lines.

---

## Experiment 1 — Verify Docker Engine Availability

Execute:

```bash
docker version
```

**Purpose:**

To examine the installed Docker client and the connected Docker Engine.

**Expected result:**

The command displays version information for the client and server when both are accessible.

**Observation:**

Confirm that a server section is present and that Docker Engine is operational.

---

## Experiment 2 — Create and Start an Nginx Container

Execute:

```bash
docker run -d --name lecture02-nginx -p 127.0.0.1:8080:80 nginx:alpine
```

**Purpose:**

To create a named Nginx container, execute it in detached mode, and publish its HTTP service on the host's IPv4 loopback interface.

**Expected result:**

Docker displays the container identifier after the container is started.

If the image is not locally available, Docker may first download it.

**Technical interpretation:**

The container is created from the Nginx image.

The default Nginx application is launched.

The terminal is released because detached execution was specified.

The container's port 80 is published through the host's port 8080.

**Record:**

Container name: __________________

Container ID: ____________________

Image: ___________________________

Host port: ________________________

Container port: ___________________

---

## Experiment 3 — Verify the Running Container

Execute:

```bash
docker ps
```

**Purpose:**

To inspect running Docker containers.

**Expected result:**

The newly created Nginx container appears in the output if its server process is still running.

**Required observations:**

1. Record the container identifier.
2. Record the image name.
3. Identify the container's current status.
4. Identify its published port.
5. Identify its assigned name.

**Analysis question:**

Why does the container remain running even though the original `docker run` command has returned control to the terminal?

---

## Experiment 4 — Access the Containerized Web Server

Open a browser and navigate to:

http://localhost:8080

Alternatively, use:

http://127.0.0.1:8080

**Expected result:**

The browser displays the default Nginx welcome page.

**Technical interpretation:**

The browser sends an HTTP request to the host's published TCP port.

Docker's networking configuration directs the request to the Nginx process listening on port 80 inside the container.

The response is returned to the browser.

**Analysis question:**

Why is the browser using port 8080 while the Nginx process inside the container listens on port 80?

---

## Experiment 5 — Inspect Container Logs

Execute:

```bash
docker logs lecture02-nginx
```

**Purpose:**

To retrieve available application log output associated with the container.

**Expected result:**

The terminal displays log records produced by the Nginx container.

Depending on the image and activity, these records may include startup information and HTTP request information.

Now execute:

```bash
docker logs --tail 10 lecture02-nginx
```

**Purpose:**

To retrieve a limited number of recent log records.

**Observation:**

Record at least one meaningful log entry and explain its apparent function.

---

## Experiment 6 — Stop the Container

Execute:

```bash
docker stop lecture02-nginx
```

**Purpose:**

To terminate the execution of the Nginx container.

**Expected result:**

Docker reports the container name after the stop operation completes.

Execute:

```bash
docker ps
```

The stopped container should no longer appear in the ordinary running-container list.

Now execute:

```bash
docker ps -a
```

The container should remain visible with an exited status.

**Technical interpretation:**

The application process has terminated, but the container object has not been removed.

**Analysis question:**

Why does the container appear in `docker ps -a` but not in `docker ps`?

---

## Experiment 7 — Restart the Stopped Container

Execute:

```bash
docker start lecture02-nginx
```

Now execute:

```bash
docker ps
```

**Expected result:**

The Nginx container appears in the running-container list.

Open the browser again:

http://localhost:8080

The Nginx service should once again be accessible.

**Technical interpretation:**

Docker starts the existing container using its previously configured execution settings.

The operation does not create a new image or an independent container identity.

**Observation:**

Compare the container identifier before and after restarting.

---

## Experiment 8 — Execute a Container Restart

Execute:

```bash
docker restart lecture02-nginx
```

**Purpose:**

To initiate a controlled stop-and-start operation for the existing container.

**Expected result:**

Docker reports the container name after completing the restart operation.

Verify:

```bash
docker ps
```

**Observation:**

Confirm that the container continues to use its established name and identifier.

---

## Experiment 9 — Examine Interactive Execution

Execute:

```bash
docker run --rm -it --name lecture02-shell alpine:3.20 sh
```

**Purpose:**

To start an interactive Alpine Linux container containing a shell process.

**Expected result:**

The terminal presents a shell prompt.

Inside the container, execute:

```sh
pwd
```

Then:

```sh
ls
```

Then:

```sh
echo "Docker interactive execution"
```

Finally, execute:

```sh
exit
```

**Expected result:**

The shell terminates, causing the container to exit.

Because automatic removal was enabled, Docker deletes the container object.

Verify from the host terminal:

```bash
docker ps -a
```

The `lecture02-shell` container should not remain listed.

**Technical interpretation:**

The container's lifecycle was associated with the interactive shell process.

The `--rm` option ensured cleanup after termination.

---

## Experiment 10 — Create a Container Without Starting It

Execute:

```bash
docker create --name lecture02-created nginx:alpine
```

**Purpose:**

To create a Docker container object without starting its application process.

Execute:

```bash
docker ps -a
```

**Expected result:**

The container appears with a created status.

Now execute:

```bash
docker start lecture02-created
```

Check its state:

```bash
docker ps
```

Stop it:

```bash
docker stop lecture02-created
```

Remove it:

```bash
docker rm lecture02-created
```

**Technical interpretation:**

This experiment demonstrates that container creation and container startup are separate operations.

---

## Experiment 11 — Remove the Main Laboratory Container

First stop the container:

```bash
docker stop lecture02-nginx
```

Then remove it:

```bash
docker rm lecture02-nginx
```

Finally, execute:

```bash
docker ps -a
```

**Expected result:**

The removed container no longer appears in the Docker container list.

**Analysis question:**

Does removing the container also remove the `nginx:alpine` image?

Explain the distinction between the container object and its source image.

---

# 15. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation | Observed result |
|---|---|---|
| 1 | Docker version verification | |
| 2 | Nginx container creation | |
| 3 | Running-container inspection | |
| 4 | HTTP service access | |
| 5 | Log retrieval | |
| 6 | Container stop | |
| 7 | Container start | |
| 8 | Container restart | |
| 9 | Interactive shell execution | |
| 10 | Creation without startup | |
| 11 | Container removal | |

## Laboratory Conclusion

Write a technical conclusion of approximately 150–250 words addressing:

1. The relationship between a container and its principal process.
2. The differences between creating, starting, stopping, and removing a container.
3. The significance of detached and interactive execution.
4. The purpose of port publishing.
5. The importance of logs in container management.

---

# 16. COMMON CONTAINER ERRORS AND TROUBLESHOOTING

## 16.1 Container Name Already Exists

**Problem:**

Docker reports that a container name is already assigned.

**Cause:**

An existing container, including a stopped container, retains the requested name.

**Corrective procedure:**

Inspect existing containers:

```bash
docker ps -a
```

Determine whether the existing container should be restarted, removed, or renamed.

Do not remove containers whose purpose or ownership is unknown.

## 16.2 Port Already Allocated

**Problem:**

Docker cannot establish the requested host port binding.

**Cause:**

Another process or container may already be using the specified address and port combination.

**Corrective procedure:**

Inspect running containers:

```bash
docker ps
```

If appropriate, choose a different host port.

For example:

```bash
docker run -d --name alternate-nginx -p 127.0.0.1:8081:80 nginx:alpine
```

The container continues listening internally on port 80.

## 16.3 Container Exits Immediately

**Problem:**

A container starts but quickly enters an exited state.

**Possible causes:**

1. Normal completion of a short-lived command.
2. Missing executable.
3. Invalid command arguments.
4. Application configuration error.
5. Missing application dependencies.
6. Failed initialization.

**Corrective procedure:**

Inspect all containers:

```bash
docker ps -a
```

Retrieve logs:

```bash
docker logs CONTAINER_NAME
```

Interpret the exit status and application output.

## 16.4 Cannot Remove a Running Container

**Problem:**

Docker refuses to remove a container that is currently executing.

**Cause:**

Standard container removal normally expects the container to be stopped.

**Corrective procedure:**

```bash
docker stop CONTAINER_NAME
docker rm CONTAINER_NAME
```

Forced removal should be reserved for situations where its consequences are understood.

## 16.5 Container Not Found

**Problem:**

Docker reports that the specified container does not exist.

**Possible causes:**

- Incorrect name.
- Incorrect identifier.
- The container was already removed.
- The command is connected to a different Docker context or daemon.

**Corrective procedure:**

```bash
docker ps -a
```

Confirm that the expected container exists within the currently selected Docker environment.

---

# 17. CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1: docker run and docker start are equivalent.

They are not equivalent.

`docker run` creates and starts a new container.

`docker start` starts an existing container.

## Misunderstanding 2: Stopping a container deletes it.

Stopping a container terminates its execution but normally retains the container object.

Removal is a separate operation.

## Misunderstanding 3: A detached container always remains running.

Detached execution only separates the container's process attachment from the initiating terminal.

The container may terminate when its principal process exits.

## Misunderstanding 4: An interactive container must be a long-running service.

Interactive containers can be temporary environments used for shell sessions, diagnostic commands, or other tasks.

## Misunderstanding 5: Every container must publish a port.

Port publishing is necessary only when an application needs the corresponding host-level network access.

Containers performing internal computations may not require published ports.

## Misunderstanding 6: A running container always represents a healthy application.

A container can remain running while the application experiences errors, degraded functionality, or failed dependencies.

Running status is not equivalent to application health.

## Misunderstanding 7: A stopped container loses all its data.

An ordinary stopped container retains its writable filesystem layer until the container is removed.

However, data durability requires additional storage design.

## Misunderstanding 8: Removing a container removes its original image.

Removing a container does not ordinarily remove the image from which it was created.

## Misunderstanding 9: Foreground execution and interactive execution mean the same thing.

Foreground execution concerns attachment to an executing process.

Interactive execution concerns the availability of an input stream.

They are related but distinct concepts.

## Misunderstanding 10: Port publishing automatically starts a network service.

Port publishing configures access to a container port.

An application must still be listening on that port for the service to function.

---

# 18. IMPORTANT TERMINOLOGY

| Term | Definition |
|---|---|
| Container lifecycle | Sequence of states and transitions in container operation |
| Created state | Container exists but has not started |
| Running state | Container's principal process is active |
| Exited state | Container execution has terminated |
| Paused state | Container processes are temporarily suspended |
| Restarting state | Docker is attempting to restart a container |
| Container ID | Unique identifier assigned to a container |
| Container name | Human-readable identifier assigned to a container |
| Foreground execution | Execution with client attachment to process streams |
| Detached execution | Container execution without maintaining terminal attachment |
| Interactive execution | Execution supporting input communication |
| STDIN | Standard input stream |
| STDOUT | Standard output stream |
| STDERR | Standard error stream |
| Pseudo-terminal | Software interface providing terminal-like capabilities |
| Host port | Network port associated with the Docker host |
| Container port | Network port used within a container's network environment |
| Port publishing | Configuration allowing access through a host network endpoint |
| Graceful shutdown | Controlled application termination |
| Exit code | Numeric value describing program termination status |
| Principal process | Process whose termination ordinarily determines the container lifecycle |
| Container logs | Application output records collected through Docker logging mechanisms |
| Automatic removal | Deletion of a container following termination when configured |
| Restart policy | Rules controlling whether Docker attempts automatic container restart |

---

# 19. LECTURE SUMMARY

Docker containers are isolated runtime instances created from standardized container images.

They operate as process execution environments rather than independent virtual machines.

A container possesses an identity, configuration, runtime state, and associated resources.

The lifecycle of a container includes creation, execution, termination, possible restarting, and eventual removal.

Container creation and container startup represent separate operations, although `docker run` combines them into a single command.

Docker provides several execution patterns, including foreground, detached, and interactive execution.

Foreground execution maintains a client attachment to application execution.

Detached execution allows a container to continue operating without occupying the initiating terminal.

Interactive execution provides facilities for supplying input to containerized processes.

Docker identifies containers through unique identifiers and optional human-readable names.

The commands `docker ps` and `docker ps -a` support container inspection, while `docker start`, `docker stop`, `docker restart`, and `docker rm` manage important lifecycle transitions.

Container port publishing provides controlled communication between containerized services and host network endpoints.

Container logging provides access to diagnostic information generated during application execution.

The lifecycle of a container is closely related to the termination of its designated principal process.

Understanding these mechanisms is essential for subsequent studies of container introspection, image management, networking, persistent storage, and multi-container application deployment.

---

# 20. ACADEMIC ASSESSMENT

## Part A — Definition Questions

Provide precise technical definitions for the following terms.

1. Docker container.
2. Container lifecycle.
3. Container state.
4. Container identifier.
5. Detached execution.
6. Interactive execution.
7. Pseudo-terminal.
8. Container port.
9. Host port.
10. Graceful shutdown.
11. Exit code.
12. Container log.

## Part B — Short-Answer Questions

**Question 1.**

Explain the relationship between the principal process of a container and the container's running state.

**Question 2.**

Distinguish between the `docker run` and `docker start` commands.

**Question 3.**

Explain the significance of the `-d` option.

**Question 4.**

Describe the purpose of the `-i` and `-t` options.

**Question 5.**

Explain why a stopped container may still appear in Docker's container list.

**Question 6.**

Describe the difference between `docker stop` and `docker rm`.

**Question 7.**

Explain why a container executing a short-lived command may terminate immediately.

**Question 8.**

Describe the purpose of `docker logs`.

**Question 9.**

Explain why two containers created from the same Nginx image may operate independently.

**Question 10.**

Describe the significance of the `--rm` option.

## Part C — Command Interpretation

Analyze the following command:

```bash
docker run -d --name production-web -p 8080:80 nginx:alpine
```

Answer the following questions:

1. What operation is requested?
2. What is the source image?
3. What is the container name?
4. What is the execution mode?
5. Which port is published on the host?
6. Which container port receives the forwarded traffic?
7. Is the container removed automatically when it stops?
8. What command can identify whether the container is running?
9. What command can retrieve its logs?
10. What command can stop the container?

## Part D — Analytical Questions

**Question 11.**

A developer executes the following commands:

```bash
docker run -d --name app-one nginx:alpine
docker stop app-one
docker start app-one
```

Explain the lifecycle transitions that occur.

Determine whether the container's identity changes.

**Question 12.**

A developer runs an Alpine container using a command that prints a message and exits successfully.

The developer observes that the container no longer appears in the running-container list.

Analyze whether this indicates an application failure.

**Question 13.**

Two containers execute the same Nginx image.

The first publishes host port 8080 to container port 80.

The second publishes host port 8081 to container port 80.

Explain how both services can operate concurrently.

**Question 14.**

Compare a graceful container stop operation with an abrupt forced termination.

Discuss possible consequences for applications processing data or active network requests.

**Question 15.**

A container remains in the running state, but users report that its application is not functioning correctly.

Explain why container running status alone is insufficient to determine application health.

Describe the diagnostic information that should be examined.

---

# 21. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Analysis of Docker Container Lifecycle and Runtime Behavior

Prepare a technical report of approximately 700–1,000 words addressing:

**“The Docker Container Lifecycle: Process Execution, State Transitions, and Administrative Control.”**

The report must include:

1. An introduction to container execution.
2. A formal explanation of container lifecycle states.
3. A discussion of container identity and configuration.
4. A comparison of foreground, detached, and interactive execution.
5. An analysis of starting, stopping, and restarting containers.
6. An explanation of container removal and its effects.
7. An overview of host-to-container port publishing.
8. A description of container logging and elementary troubleshooting.
9. A conclusion discussing the importance of lifecycle management in container-based application deployment.

Students should use correct technical terminology and provide command examples where appropriate.

---

# 22. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 03, verify that you can perform the following operations without consulting a step-by-step tutorial.

- [ ] Create a container using an existing image.
- [ ] Assign a custom container name.
- [ ] Execute a container in detached mode.
- [ ] Execute a container interactively.
- [ ] Identify a running container.
- [ ] List stopped containers.
- [ ] Explain the difference between `docker run` and `docker start`.
- [ ] Stop a running container.
- [ ] Restart an existing container.
- [ ] Publish a container port to the host.
- [ ] Access a containerized web service.
- [ ] Retrieve container logs.
- [ ] Explain why a container exited.
- [ ] Remove a stopped container.
- [ ] Explain the effect of automatic container removal.

**Completion standard:**

The student should demonstrate not only the ability to execute these commands but also an understanding of the operating-system and container-management principles that explain their behavior.

---

# 23. REFERENCES AND RECOMMENDED READING

## Primary Sources

[1] Docker Inc. *Docker Container Run — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/run/

[2] Docker Inc. *Docker Container Management — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/

[3] Docker Inc. *Docker Container List — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/ls/

[4] Docker Inc. *Docker Container Stop — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/stop/

[5] Docker Inc. *Docker Container Start — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/start/

[6] Docker Inc. *Docker Container Restart — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/restart/

[7] Docker Inc. *Docker Container Remove — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/rm/

[8] Docker Inc. *Docker Container Logs — Command-Line Reference.*  
https://docs.docker.com/reference/cli/docker/container/logs/

[9] Docker Inc. *Port Publishing and Mapping.*  
https://docs.docker.com/engine/network/port-publishing/

[10] Docker Inc. *Running Containers.*  
https://docs.docker.com/engine/containers/run/

[11] Docker Inc. *What Is a Container?*  
https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/

## Recommended Reading Sequence

Students should begin with references [1], [2], and [3] to establish a command-line foundation.

References [4] through [8] provide detailed lifecycle and logging documentation.

Reference [9] explains the underlying behavior and implications of Docker port publishing.

Reference [10] provides additional information about execution modes and container runtime behavior.

---

**END OF LECTURE 02**

**Next Lecture:** Lecture 03 — Working Inside Docker Containers: Process Inspection, Filesystem Exploration, Runtime Diagnostics, and Container Internals.
