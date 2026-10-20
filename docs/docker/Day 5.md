# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 05 — DOCKERFILE FUNDAMENTALS: IMAGE CONSTRUCTION, BUILD CONTEXTS, DOCKERFILE INSTRUCTIONS, AND BUILDING CUSTOM DOCKER IMAGES

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 05 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Lecture 01 — Introduction to Docker and Containerization Technology.
- Lecture 02 — Docker Container Lifecycle and Runtime Operations.
- Lecture 03 — Working Inside Docker Containers and Runtime Diagnostics.
- Lecture 04 — Docker Images, Image Architecture, and Image Registries.
- Basic knowledge of command-line interfaces and filesystem operations.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define a Dockerfile and explain its role in container image construction.
2. Describe the process of building custom container images.
3. Explain the relationship between Dockerfiles, build contexts, images, and containers.
4. Identify the major components of the Docker image-building architecture.
5. Describe the responsibilities of Docker Engine and BuildKit during image construction.
6. Explain the general syntax and structure of a Dockerfile.
7. Define and distinguish build-time instructions from runtime configuration instructions.
8. Explain the purpose and behavior of the `FROM` instruction.
9. Describe the significance of selecting an appropriate base image.
10. Explain the `WORKDIR` instruction and its effect on subsequent build operations.
11. Describe how the `COPY` instruction transfers files into an image.
12. Explain the function of the `RUN` instruction.
13. Distinguish between the `RUN` and `CMD` instructions.
14. Explain the purpose of the `EXPOSE` instruction.
15. Describe Dockerfile instruction ordering.
16. Define a Docker build context and explain its boundaries.
17. Explain the purpose of the `.dockerignore` file.
18. Describe the Docker build cache and fundamental cache invalidation.
19. Construct a custom Dockerfile for a web application.
20. Build a Docker image using the `docker build` command.
21. Assign a repository name and tag to a locally constructed image.
22. Execute a container from the custom image.
23. Inspect the resulting image and container configuration.
24. Explain common image-building errors and their causes.
25. Evaluate elementary security and reproducibility considerations.
26. Complete a laboratory involving the construction and execution of a containerized website.

---

# 2. INTRODUCTION TO CONTAINER IMAGE CONSTRUCTION

## 2.1 Background

The preceding lectures examined the operation of containers and the management of existing container images.

An image obtained from Docker Hub can be downloaded and used to create a container.

However, general-purpose images do not necessarily contain the application software or configuration required by a particular development project.

For example, a standard Nginx image contains an Nginx web server and its supporting environment.

It does not automatically contain the HTML, CSS, JavaScript, or application-specific configuration of an individual developer's website.

To deploy a specific website using Docker, the required application files must be incorporated into an appropriate image or supplied to the container through another supported mechanism.

Docker provides an image construction system for this purpose.

A common method involves defining the image through a text file called a **Dockerfile**.

## 2.2 Definition of Image Construction

Image construction is the process of producing a container image by applying a defined sequence of operations to an initial filesystem and execution configuration.

These operations may include:

- Selecting an existing image as a foundation.
- Creating directories.
- Installing operating-system packages.
- Copying application files.
- Installing application dependencies.
- Configuring environment variables.
- Establishing a working directory.
- Specifying default execution behavior.
- Defining image metadata.

The result is a new image that can be identified, stored, distributed, and used to instantiate containers.

**Formal definition:**

Container image construction is a controlled build process through which filesystem content and runtime configuration are assembled into a standardized, content-addressable container image artifact.

## 2.3 Motivation for Custom Images

Custom image construction addresses several requirements in software development.

### Application Packaging

Developers need to package their own application files into a deployable environment.

### Dependency Management

Applications frequently require specific versions of runtime libraries or supporting programs.

### Environment Reproducibility

A defined build procedure allows the application environment to be reconstructed under appropriate conditions.

### Deployment Consistency

The same constructed image can be used in development, testing, and deployment environments.

### Automation

Image builds can be executed automatically by development pipelines.

### Configuration Management

Build specifications provide a recorded description of the operations used to construct an application image.

Custom image construction therefore separates application packaging from the manual configuration of individual deployment hosts.

---

# 3. THE DOCKERFILE

## 3.1 Definition

A Dockerfile is a text-based build specification containing instructions that Docker's image-building system interprets to construct a container image.

A Dockerfile describes how the desired image should be assembled.

The instructions are written using a declarative and procedural build-oriented syntax.

Some instructions perform operations that modify the image filesystem.

Other instructions establish image configuration metadata.

**Formal definition:**

A Dockerfile is a structured text document containing Docker-supported build instructions that define the filesystem composition, build operations, and execution configuration of a container image.

## 3.2 Characteristics of a Dockerfile

A Dockerfile has several important characteristics.

1. It is a plain-text file.
2. It normally uses the filename `Dockerfile`.
3. It contains one instruction per logical instruction statement.
4. Instructions are processed according to the build system's dependency model.
5. Instruction ordering affects build results and caching.
6. It commonly begins with a `FROM` instruction.
7. It may reference files within a defined build context.
8. It can specify both filesystem changes and image metadata.
9. It can be maintained in a version-control repository.
10. It supports repeatable image construction when the relevant inputs are controlled.

Dockerfiles are not general-purpose shell scripts.

Although some Dockerfile instructions execute shell commands, the Dockerfile itself is interpreted by the Docker build frontend.

## 3.3 Dockerfile Naming Convention

The conventional filename is:

`Dockerfile`

It normally has no file extension.

Examples of filenames that may also be used in controlled build environments include:

- `Dockerfile`
- `Dockerfile.dev`
- `Dockerfile.prod`
- `Dockerfile.test`

When using a non-default filename, the appropriate file can be selected through the Docker build command.

For example:

```bash
docker build -f Dockerfile.dev -t application:development .
```

The `-f` option identifies the Dockerfile used for the build.

The final period identifies the build context.

## 3.4 Basic Dockerfile Structure

A simple Dockerfile may contain:

```dockerfile
FROM nginx:alpine

WORKDIR /usr/share/nginx/html

COPY index.html ./index.html

EXPOSE 80
```

This file defines an image based on Nginx.

It establishes a working directory, copies an HTML document into the image, and declares the application's intended network port.

The resulting image inherits additional configuration from the selected Nginx base image.

## 3.5 Comments

Dockerfiles support comments beginning with the hash symbol.

Example:

```dockerfile
# Select a base image
FROM nginx:alpine

# Copy application content
COPY index.html /usr/share/nginx/html/index.html
```

Comments are useful for explaining the purpose of operations and recording non-obvious design decisions.

Dockerfiles also support special parser directives using comment-like syntax.

For example:

```dockerfile
# syntax=docker/dockerfile:1
```

This directive identifies a Dockerfile syntax frontend.

Unlike an ordinary explanatory comment, it can influence how the Dockerfile is parsed and which supported syntax features are available.

---

# 4. DOCKER IMAGE-BUILDING ARCHITECTURE

## 4.1 General Architecture

Docker image construction involves several related components.

These include:

1. Docker client.
2. Dockerfile.
3. Build context.
4. Image builder.
5. Base images.
6. Filesystem layers.
7. Image configuration.
8. Local image store.

The Docker client initiates the build.

The build system interprets the Dockerfile and resolves required inputs.

The resulting image is stored or exported according to the selected build configuration.

## 4.2 Logical Build Architecture

```text
APPLICATION PROJECT → Dockerfile
APPLICATION PROJECT → Build Context
Dockerfile → DOCKER CLIENT
Build Context → DOCKER CLIENT
DOCKER CLIENT → IMAGE BUILDER, BuildKit (build request)
IMAGE BUILDER → Base Image
IMAGE BUILDER → Build Inputs
Base Image → BUILD OPERATIONS
Build Inputs → BUILD OPERATIONS
BUILD OPERATIONS → IMAGE FILESYSTEM + METADATA
IMAGE FILESYSTEM + METADATA → CUSTOM IMAGE
CUSTOM IMAGE → RUNNING CONTAINER (docker run)
```

This diagram represents the logical construction process rather than every internal implementation detail.

## 4.3 Docker BuildKit

BuildKit is Docker's modern image-building backend.

It provides functionality for executing image builds using a structured dependency model.

BuildKit supports capabilities such as:

- Build caching.
- Parallel execution of independent build operations.
- Efficient dependency resolution.
- Build secrets.
- Advanced filesystem mounts.
- Multi-stage builds.
- External cache integration.
- Multi-platform image construction.

BuildKit uses a build representation known as Low-Level Build, or LLB.

LLB describes build operations and their dependencies.

Dockerfile instructions are translated into a representation that BuildKit can execute.

For a conventional Dockerfile, the logical effects of instructions remain ordered as required, even when BuildKit can optimize the execution of independent operations.

## 4.4 The Build Process

A typical build follows these general stages.

**Stage 1: Build initialization**

The developer issues a Docker build command.

**Stage 2: Dockerfile loading**

The builder obtains the Dockerfile and parses its instructions.

**Stage 3: Build context preparation**

The required application files and directory information are made available to the builder according to the selected context.

**Stage 4: Base image resolution**

The builder resolves the base image or images required by the Dockerfile.

**Stage 5: Instruction execution**

The builder performs filesystem operations and constructs image configuration according to the build instructions.

**Stage 6: Build cache evaluation**

The builder determines whether previous build results can be reused.

**Stage 7: Image assembly**

The resulting filesystem and configuration information are represented as a container image.

**Stage 8: Image output**

The image is stored locally or exported to the selected destination.

---

# 5. UNDERSTANDING THE BUILD CONTEXT

## 5.1 Definition

The build context is the collection of files and directories made available to the image-building system for a particular build.

The build context establishes the source material from which instructions such as `COPY` can obtain local files.

**Formal definition:**

A Docker build context is a designated collection of filesystem content or other supported source material made accessible to the builder during image construction.

A build context can originate from a local directory, remote repository, archive, or another supported source.

This lecture concentrates on local-directory build contexts.

## 5.2 The Current Directory as Build Context

Consider the command:

```bash
docker build -t my-website:v1 .
```

The final character:

`.`

represents the current directory.

Docker treats the selected directory as the root of the build context.

For example:

```text
my-website/
├── Dockerfile
├── index.html
├── styles.css
└── README.md
```

If the command is executed from the `my-website` directory, the context includes the relevant contents of that directory, subject to ignore rules.

## 5.3 Build Context Versus Working Directory

The build context and Dockerfile working directory are different concepts.

The build context refers to source material available to the image builder.

The `WORKDIR` instruction specifies a working directory within the image's filesystem environment.

For example:

```dockerfile
FROM nginx:alpine

WORKDIR /usr/share/nginx/html

COPY index.html ./index.html
```

The source file `index.html` is obtained from the build context.

The destination `./index.html` is interpreted relative to the configured working directory inside the image.

These are two distinct filesystem locations.

## 5.4 Build Context Boundaries

Ordinary `COPY` instructions cannot arbitrarily access files outside the designated default build context.

For example:

```text
project/
├── Dockerfile
└── index.html

private/
└── secret.txt
```

If `project/` is the build context, the sibling `private/` directory is outside that context.

The builder does not treat it as part of the normal source material for `COPY`.

Docker's modern build frontend also normalizes attempts to navigate outside a build context using parent-directory paths.

Consequently, developers should not rely on `../` to access arbitrary external files during image construction.

Advanced build mechanisms support explicitly named additional contexts, but those mechanisms are beyond this lecture.

## 5.5 Why Build Context Size Matters

A large build context may include unnecessary files.

Examples include:

- Version-control metadata.
- Temporary files.
- Dependency directories.
- Generated output.
- Archives.
- Local databases.
- Diagnostic logs.
- Sensitive configuration files.

Unnecessary context content can increase build processing overhead, particularly when remote builders are involved.

It may also increase the possibility that unwanted files are included in an image.

The `.dockerignore` mechanism helps control this issue.

---

# 6. THE DOCKER BUILD COMMAND

## 6.1 Definition

The `docker build` command initiates construction of a Docker image using a selected build definition and context.

The general syntax is:

```text
docker build [OPTIONS] PATH | URL | -
```

For a conventional local project:

```bash
docker build -t my-application:v1 .
```

## 6.2 Command Components

| Component           | Function                                       |
| ------------------- | ---------------------------------------------- |
| `docker`            | Docker command-line client                     |
| `build`             | Initiates image construction                   |
| `-t`                | Assigns an image reference                     |
| `my-application:v1` | Repository name and tag                        |
| `.`                 | Selects the current directory as build context |

## 6.3 Tagging During Construction

The `-t` option allows the image to receive a repository name and tag as part of the build operation.

Example:

```bash
docker build -t academic-site:v1 .
```

The result is a locally available image associated with:

`academic-site:v1`

Without an explicitly assigned tag, a build can produce image content that is not associated with a convenient human-readable repository reference.

Assigning a clear tag makes subsequent execution and inspection easier.

## 6.4 Selecting a Dockerfile

The command:

```bash
docker build -f Dockerfile.dev -t academic-site:dev .
```

uses `Dockerfile.dev` as the build definition.

The build context is still the current directory.

This demonstrates that the Dockerfile path and the context path are separate parameters.

## 6.5 Build Output

A successful build normally displays information about the operations performed.

Modern BuildKit output may include:

- Loading the Dockerfile.
- Resolving the base image.
- Loading the build context.
- Executing build operations.
- Using cached results.
- Exporting image content.
- Assigning the image reference.

The exact display format depends on Docker and BuildKit versions.

---

# 7. THE FROM INSTRUCTION

## 7.1 Definition

The `FROM` instruction defines the base image used to begin an image-building stage.

It establishes the initial filesystem and image configuration from which additional build operations proceed.

General syntax:

```dockerfile
FROM image:tag
```

Example:

```dockerfile
FROM nginx:alpine
```

This statement uses the Nginx image associated with the `alpine` tag as the starting point.

## 7.2 Base Images

A base image is an image that provides the initial content and configuration for another image.

Examples include:

- `alpine:3.20`
- `nginx:alpine`
- `python:3.12-slim`
- `node:22-alpine`

These images provide different application environments.

The selected base image influences:

1. Available executables.
2. Operating-system user-space components.
3. Installed system libraries.
4. Runtime dependencies.
5. Image size.
6. Security considerations.
7. Application compatibility.
8. Available configuration defaults.

## 7.3 Inheritance from Base Images

When an image is built using a base image, it inherits the base image's filesystem and applicable image configuration.

For example:

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html
```

The new image contains the selected Nginx image content together with the website file introduced through `COPY`.

The image also inherits relevant Nginx execution configuration unless it is explicitly overridden.

## 7.4 The FROM scratch Form

Docker also supports:

```dockerfile
FROM scratch
```

The keyword `scratch` represents an empty starting point.

It is not an ordinary registry image containing a complete Linux user-space environment.

Building from `scratch` is useful in certain circumstances, particularly when packaging statically linked executables with minimal runtime dependencies.

However, images built from `scratch` do not automatically contain a shell, package manager, or ordinary Linux utilities.

Therefore, it is not an appropriate default choice for every application.

## 7.5 Selecting an Appropriate Base Image

Base-image selection should consider:

- Application requirements.
- Required runtime versions.
- Processor compatibility.
- Image maintenance.
- Security updates.
- Package availability.
- Filesystem requirements.
- Debugging needs.
- Image size.

A smaller image is not automatically a better image.

An image must contain the components necessary for correct and secure application execution.

---

# 8. THE WORKDIR INSTRUCTION

## 8.1 Definition

The `WORKDIR` instruction establishes the working directory for subsequent applicable build instructions and the default execution directory for the resulting image.

General syntax:

```dockerfile
WORKDIR /path/to/directory
```

Example:

```dockerfile
WORKDIR /app
```

## 8.2 Working Directory Semantics

The working directory influences where relative filesystem paths are interpreted.

For example:

```dockerfile
FROM alpine:3.20

WORKDIR /app

RUN pwd
```

The `RUN pwd` instruction executes with `/app` as its working directory.

If the specified directory does not exist, Docker creates it.

## 8.3 Relative Working Directories

Multiple `WORKDIR` instructions may be used.

Example:

```dockerfile
FROM alpine:3.20

WORKDIR /app

WORKDIR source

WORKDIR backend

RUN pwd
```

The resulting working directory is:

`/app/source/backend`

This occurs because relative paths are resolved from the preceding working directory.

## 8.4 WORKDIR Versus Shell cd

A shell command such as:

```dockerfile
RUN cd /app
```

changes the current directory only within the shell process executing that particular `RUN` instruction.

It does not establish the persistent working directory for later instructions.

By contrast:

```dockerfile
WORKDIR /app
```

sets working-directory configuration that applies to subsequent relevant instructions.

**Fundamental distinction:**

`RUN cd` affects a temporary shell process.

`WORKDIR` changes the working-directory configuration of the build stage and resulting image.

---

# 9. THE COPY INSTRUCTION

## 9.1 Definition

The `COPY` instruction transfers files or directories from a supported source into the filesystem of the image being constructed.

For ordinary local builds, the source is normally obtained from the build context.

General syntax:

```dockerfile
COPY source destination
```

Example:

```dockerfile
COPY index.html /usr/share/nginx/html/index.html
```

## 9.2 Source and Destination

The source identifies content available to the builder.

The destination identifies where the content should be placed within the image filesystem.

Consider:

```text
project/
├── Dockerfile
└── index.html
```

With:

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html
```

The builder reads the local source file and incorporates it into the image at the selected destination.

## 9.3 Relative Destination Paths

A relative destination path is resolved using the configured working directory.

Example:

```dockerfile
FROM nginx:alpine

WORKDIR /usr/share/nginx/html

COPY index.html ./index.html
```

This places the source file at:

`/usr/share/nginx/html/index.html`

## 9.4 Copying Directories

The `COPY` instruction can transfer entire directories.

Example:

```dockerfile
COPY public/ /usr/share/nginx/html/
```

This copies the contents of the selected source directory into the destination directory.

The exact resulting structure depends on the source and destination syntax.

## 9.5 Copying Multiple Files

Docker supports copying several sources into one destination.

Example:

```dockerfile
COPY index.html styles.css /app/
```

When multiple sources are specified, the destination must be a directory.

The destination syntax must therefore satisfy the documented directory requirements.

## 9.6 COPY and Build Context Restrictions

For ordinary local builds, a source must be available within the selected context and must not be excluded by applicable ignore rules.

For example:

```dockerfile
COPY missing-file.txt /app/
```

will fail if `missing-file.txt` is not available to the builder through the specified context.

## 9.7 COPY Versus ADD

Docker also supports an `ADD` instruction.

Both `COPY` and `ADD` can introduce filesystem content.

However, `ADD` provides additional capabilities, including certain archive extraction and remote-source behaviors.

For straightforward local file transfers, `COPY` is generally preferable because its behavior is more explicit.

The advanced semantics of `ADD` will be examined in Lecture 06.

---

# 10. THE RUN INSTRUCTION

## 10.1 Definition

The `RUN` instruction executes a command during the image-building process.

Its purpose is commonly to install dependencies, generate files, create directories, or perform build-time configuration operations.

General syntax:

```dockerfile
RUN command
```

Example:

```dockerfile
RUN mkdir -p /app/logs
```

## 10.2 Build-Time Execution

The `RUN` instruction executes while the image is being constructed.

It does not automatically execute every time a container is created from the resulting image.

For example:

```dockerfile
FROM alpine:3.20

RUN mkdir -p /application
```

The directory is created during image construction and becomes part of the image filesystem.

A container created from this image observes that directory unless subsequent runtime behavior or mounts alter the filesystem view.

## 10.3 Filesystem Modification

`RUN` instructions often introduce filesystem changes.

For example:

```dockerfile
RUN mkdir -p /app/data
```

This creates a directory.

Another example:

```dockerfile
RUN echo "Docker course" > /app/information.txt
```

This writes a file.

The resulting changes can become part of the constructed image.

## 10.4 Shell Form

The shell form uses a command string.

Example:

```dockerfile
RUN echo "Building application"
```

For Linux images, Docker commonly executes this through a shell such as:

`/bin/sh -c`

The command is interpreted using that shell's facilities.

## 10.5 Exec Form

Docker also supports an exec form:

```dockerfile
RUN ["echo", "Building application"]
```

This form identifies the executable and its arguments explicitly.

It does not automatically invoke a command shell.

The executable must exist in the build environment.

## 10.6 RUN and Filesystem Layers

Build operations that alter the image filesystem produce changesets represented within the image's layer structure.

For example:

```dockerfile
FROM alpine:3.20

RUN mkdir -p /app

RUN echo "Example" > /app/example.txt
```

The build creates filesystem state containing the directory and file.

Modern BuildKit may optimize intermediate operations and cache their results.

The exact number of final filesystem layers and history entries should be determined through image inspection rather than assumed solely from the number of Dockerfile instructions.

---

# 11. THE CMD INSTRUCTION

## 11.1 Definition

The `CMD` instruction specifies a default command or default arguments for containers created from an image.

General example:

```dockerfile
CMD ["executable", "argument"]
```

Unlike `RUN`, the `CMD` instruction does not execute the specified application during image construction.

Instead, it establishes runtime configuration.

## 11.2 Example

Consider:

```dockerfile
FROM alpine:3.20

CMD ["echo", "Hello from Docker"]
```

The image can be constructed with:

```bash
docker build -t hello-image:v1 .
```

When executed:

```bash
docker run --rm hello-image:v1
```

the container prints:

```text
Hello from Docker
```

The `echo` command executes when the container starts.

It is not executed as the application command during the image-building process.

## 11.3 Overriding CMD

The default command can often be overridden through the `docker run` command.

For example:

```bash
docker run --rm hello-image:v1 echo "Alternative command"
```

For the simple Alpine-based image described above, the supplied command replaces the image's default `CMD`.

The resulting output is:

```text
Alternative command
```

## 11.4 CMD and ENTRYPOINT

The precise behavior of `CMD` depends partly on whether the image also defines an `ENTRYPOINT`.

An image may use `CMD` to establish default arguments for its entrypoint executable.

When a container is started with additional command arguments, those arguments interact with the image's entrypoint configuration according to Docker's execution rules.

The relationship between `CMD` and `ENTRYPOINT` will be studied in depth during Lecture 06.

## 11.5 Multiple CMD Instructions

A Dockerfile may syntactically contain more than one `CMD` instruction.

However, only the last applicable `CMD` instruction within a build stage determines that stage's resulting default command.

Example:

```dockerfile
FROM alpine:3.20

CMD ["echo", "First"]

CMD ["echo", "Second"]
```

The resulting default command prints:

`Second`

This illustrates that `CMD` defines execution metadata rather than a sequential collection of runtime commands.

---

# 12. RUN VERSUS CMD

The difference between `RUN` and `CMD` is one of the most important Dockerfile concepts.

## 12.1 Technical Comparison

| Characteristic                                           | RUN                      | CMD                                   |
| -------------------------------------------------------- | ------------------------ | ------------------------------------- |
| Execution phase                                          | Image build              | Container runtime                     |
| Primary purpose                                          | Perform build operations | Define default execution behavior     |
| Executes during `docker build`                           | Yes                      | No                                    |
| Defines default startup command                          | No                       | Yes                                   |
| Can modify image filesystem                              | Yes                      | Not directly                          |
| Creates filesystem changesets                            | May do so                | No filesystem changeset by itself     |
| Can be overridden through `docker run` command arguments | Not directly             | Often, subject to ENTRYPOINT behavior |

## 12.2 Example

```dockerfile
FROM alpine:3.20

WORKDIR /app

RUN echo "Created during build" > build.txt

CMD ["cat", "/app/build.txt"]
```

During image construction:

1. The Alpine base image is selected.
2. The working directory is established.
3. The `RUN` command creates `build.txt`.
4. The `CMD` instruction records the default runtime command.

When a container starts:

1. The image filesystem contains `build.txt`.
2. The default command executes.
3. The file content is displayed.
4. The process exits.
5. The container stops.

## 12.3 Conceptual Execution Sequence

```text
              DOCKER BUILD
                   |
                   v
              FROM alpine
                   |
                   v
              WORKDIR /app
                   |
                   v
              RUN command
             Executes now
                   |
                   v
              CMD command
             Stored as config
                   |
                   v
              IMAGE CREATED
                   |
                   |
                docker run
                   |
                   v
              CONTAINER STARTS
                   |
                   v
              CMD EXECUTES
```

The distinction between build-time operations and runtime execution is essential for constructing reliable images.

---

# 13. THE EXPOSE INSTRUCTION

## 13.1 Definition

The `EXPOSE` instruction declares a network port and protocol that the application is expected to use during container execution.

General syntax:

```dockerfile
EXPOSE port
```

Example:

```dockerfile
EXPOSE 80
```

The default protocol is TCP.

A UDP declaration may be written as:

```dockerfile
EXPOSE 53/udp
```

## 13.2 EXPOSE as Image Metadata

The `EXPOSE` instruction contributes information to the image configuration.

It does not automatically publish the specified port on the Docker host.

For example:

```dockerfile
FROM nginx:alpine

EXPOSE 80
```

indicates that the application is expected to use port 80.

However, publishing the port on the host normally requires separate runtime configuration.

## 13.3 Publishing a Port at Runtime

Example:

```bash
docker run -d -p 8080:80 my-website:v1
```

This command publishes container port 80 through host port 8080.

The `-p` option performs the relevant runtime networking configuration.

## 13.4 EXPOSE Versus Port Publishing

| Characteristic                 | EXPOSE             | docker run -p         |
| ------------------------------ | ------------------ | --------------------- |
| Configuration phase            | Image construction | Container creation    |
| Declares an application port   | Yes                | Establishes a mapping |
| Publishes a host port directly | No                 | Yes                   |
| Provides image metadata        | Yes                | Runtime configuration |
| Example                        | `EXPOSE 80`        | `-p 8080:80`          |

## 13.5 Important Limitation

The `EXPOSE` instruction does not cause a process to listen on the declared port.

A functioning network service requires an application process that is configured to listen on an appropriate interface and port.

Therefore, an image declaring port 80 does not automatically contain a functioning HTTP server.

---

# 14. DOCKERFILE INSTRUCTION ORDER

## 14.1 Importance of Ordering

Dockerfile instructions are not independent statements whose positions can always be changed arbitrarily.

Instruction order affects:

- Filesystem content.
- Available executables.
- Working directories.
- Build dependencies.
- Build cache behavior.
- Final image configuration.

For example, copying application files into an expected working directory may depend on a preceding `WORKDIR` instruction.

## 14.2 Example of Logical Ordering

```dockerfile
FROM nginx:alpine

WORKDIR /usr/share/nginx/html

COPY index.html ./index.html

EXPOSE 80
```

The sequence has a clear logical structure:

1. Select the base environment.
2. Establish the destination working directory.
3. Introduce application files.
4. Declare the intended application port.

## 14.3 Build Dependencies

Later operations can depend on earlier filesystem modifications.

For example:

```dockerfile
FROM alpine:3.20

RUN mkdir -p /application

RUN echo "Example" > /application/data.txt
```

The second operation depends on the availability of the target directory.

Although the build system can optimize execution, the resulting state must respect the logical dependencies established by the build instructions.

## 14.4 Cache-Oriented Instruction Ordering

Instruction ordering also influences build cache efficiency.

Suppose a Node.js application requires dependencies defined by package metadata.

A poorly ordered build might copy all source files before installing dependencies.

Changing one source file could then invalidate the dependency installation step.

A more effective structure often copies dependency metadata first, installs dependencies, and introduces frequently changing application files afterward.

This subject will be examined more deeply in the next lecture.

---

# 15. THE DOCKER BUILD CACHE

## 15.1 Definition

The Docker build cache is a mechanism that allows the builder to reuse results from previous image-building operations when the required inputs and relevant build conditions have not changed.

**Formal definition:**

The Docker build cache is a collection of previously computed build results that can be reused when the builder determines that an operation's required inputs correspond to an existing cached result.

## 15.2 Purpose

Without build caching, repeated image construction could require every build operation to be executed again.

This might involve:

- Reinstalling dependencies.
- Recreating unchanged files.
- Repeating compilation operations.
- Reprocessing identical source content.

Caching reduces unnecessary work.

## 15.3 Simplified Cache Model

Consider:

```dockerfile
FROM alpine:3.20

RUN mkdir -p /app

COPY index.html /app/index.html
```

During the first build, the required operations are performed.

During a later identical build, Docker may reuse cached results.

If `index.html` changes, the result associated with the `COPY` operation must be reevaluated.

Earlier unaffected operations may still use their cached results.

## 15.4 Cache Invalidation

Cache invalidation occurs when an existing cached result can no longer be reused for an operation.

Reasons may include:

- An instruction changing.
- Required source files changing.
- A preceding build dependency changing.
- The selected base image changing.
- Relevant build arguments changing.
- Required cache content being unavailable.

For `COPY` operations, BuildKit evaluates relevant source content and file metadata when determining cache validity.

Simple file modification timestamps alone do not necessarily invalidate the cache.

## 15.5 Cache Dependency Structure

```text
            BASE IMAGE
                |
                v
           RUN operation
                |
                v
           COPY files
                |
                v
           FINAL IMAGE
```

If a required input to an earlier operation changes, operations depending on its result may need to be reevaluated.

The build cache is therefore based on dependencies rather than only on elapsed time since the previous build.

## 15.6 Build Cache Limitations

Build caching improves efficiency but does not automatically guarantee correctness or reproducibility.

For example, a `RUN` instruction that downloads software from an external source may reuse cached results even if the external source has changed.

Likewise, disabling cache does not guarantee deterministic builds when dependencies are unpinned or external content is mutable.

A reproducible build requires appropriate control of external inputs and versions in addition to cache management.

---

# 16. THE .DOCKERIGNORE FILE

## 16.1 Definition

The `.dockerignore` file specifies patterns used to exclude files or directories from the Docker build context.

Its purpose is to prevent unnecessary source material from becoming available to the builder through the default context.

## 16.2 Example

Consider:

```text
project/
├── Dockerfile
├── .dockerignore
├── index.html
├── styles.css
├── notes/
├── logs/
└── .git/
```

The `.dockerignore` file might contain:

```dockerignore
.git
notes/
logs/
*.log
```

When the default build context is prepared, matching content is excluded according to the documented pattern rules.

## 16.3 Benefits

The `.dockerignore` file can improve:

1. Build context efficiency.
2. Build performance.
3. Build organization.
4. Cache behavior.
5. Control over which local files are available for copying.
6. Reduction of accidental inclusion of unwanted content.

## 16.4 Security Considerations

Sensitive files should not be included in build contexts unnecessarily.

Examples include:

- Private keys.
- Local credential files.
- Authentication tokens.
- Confidential configuration.
- Database backups.

The `.dockerignore` file can help exclude these resources.

However, it is not a complete secrets-management solution.

Sensitive information should not be placed in an image through build arguments, image layers, or insecure build commands.

## 16.5 Important Distinction

A `.dockerignore` file is not the same as `.gitignore`.

`.gitignore` controls which files Git normally treats as untracked candidates for version control.

`.dockerignore` controls which files are excluded from the Docker build context.

The two mechanisms serve different purposes.

---

# 17. CONSTRUCTING A SIMPLE WEB APPLICATION IMAGE

## 17.1 Project Objective

The objective is to create a custom Docker image containing a static website served by Nginx.

The website will consist of:

1. An HTML document.
2. A CSS stylesheet.
3. A Dockerfile.
4. A `.dockerignore` file.

## 17.2 Project Directory Structure

```text
docker-lecture05/
├── Dockerfile
├── .dockerignore
├── index.html
└── styles.css
```

This structure separates application files from the Docker build specification.

## 17.3 Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

FROM nginx:alpine

WORKDIR /usr/share/nginx/html

RUN mkdir -p assets

COPY index.html ./index.html

COPY styles.css ./assets/styles.css

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## 17.4 Explanation

**FROM nginx:alpine**

Selects the Nginx base image.

**WORKDIR /usr/share/nginx/html**

Establishes the working directory for the following operations.

**RUN mkdir -p assets**

Creates an `assets` directory in the image filesystem.

**COPY index.html ./index.html**

Copies the website document from the build context into the image.

**COPY styles.css ./assets/styles.css**

Copies the stylesheet into the assets directory.

**EXPOSE 80**

Declares TCP port 80 as the application's expected network port.

**CMD ["nginx", "-g", "daemon off;"]**

Specifies the default command for running Nginx in the foreground.

This command is compatible with the startup arrangement of the selected official Nginx image, including its inherited entrypoint behavior.

The `daemon off;` setting prevents Nginx from detaching its main server process in the usual daemonizing manner.

This is appropriate for a container whose lifecycle should remain associated with the running web-server process.

---

# 18. UNDERSTANDING THE GENERATED IMAGE

The build specification produces a new image based on the Nginx image.

The resulting image contains:

- The Nginx web server.
- Its supporting runtime dependencies.
- Default Nginx configuration.
- Custom website HTML.
- Custom CSS.
- An additional assets directory.
- Image configuration specifying the runtime command and declared port.

The custom image is not yet a running web server.

It becomes an execution environment when Docker creates and starts a container from it.

The relationship can be represented as:

```text
OFFICIAL NGINX IMAGE → CUSTOM DOCKERFILE
CUSTOM DOCKERFILE → index.html
CUSTOM DOCKERFILE → styles.css
index.html → BUILD
styles.css → BUILD
BUILD → CUSTOM WEBSITE IMAGE
CUSTOM WEBSITE IMAGE → NGINX CONTAINER (docker run)
NGINX CONTAINER → HTTP WEB SERVICE
```

---

# 19. PRACTICAL LABORATORY 05 — BUILDING A CUSTOM WEBSITE IMAGE

## 19.1 Laboratory Title

**Construction, Execution, Inspection, and Modification of a Custom Docker Image Using a Dockerfile**

## 19.2 Laboratory Objective

The purpose of this laboratory is to demonstrate the complete image-building workflow.

The laboratory will provide practical experience in:

1. Creating a Docker project.
2. Writing application files.
3. Constructing a Dockerfile.
4. Defining a build context.
5. Configuring ignored files.
6. Building a custom image.
7. Assigning an image tag.
8. Running the custom image.
9. Inspecting the resulting container.
10. Examining filesystem contents.
11. Observing image history.
12. Rebuilding after an application change.
13. Investigating build caching.
14. Understanding runtime command configuration.
15. Performing controlled cleanup.

## 19.3 Laboratory Requirements

Required materials:

- Docker Engine or Docker Desktop.
- Terminal access.
- Text editor.
- Web browser.
- Internet access for obtaining the Nginx base image.
- A writable project directory.

The commands assume that the required project files are created exactly as shown.

---

## EXPERIMENT 1 — CREATE THE PROJECT DIRECTORY

Create a new directory named:

`docker-lecture05`

Open it in a terminal.

For a Unix-like shell:

```bash
mkdir docker-lecture05
cd docker-lecture05
```

On Windows, an equivalent directory can be created through PowerShell or a file manager.

**Purpose:**

To establish a dedicated directory for the application's source files and Docker build context.

**Expected result:**

The terminal's current working directory is the new project directory.

---

## EXPERIMENT 2 — CREATE THE HTML DOCUMENT

Create a file named:

`index.html`

Insert the following content:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>Docker Lecture 05</title>

    <link rel="stylesheet" href="/assets/styles.css" />
  </head>

  <body>
    <main>
      <h1>Docker Lecture 05</h1>

      <h2>Custom Docker Image</h2>

      <p>This website is served by Nginx inside a Docker container.</p>

      <p>
        The application files were included during Docker image construction.
      </p>
    </main>
  </body>
</html>
```

**Purpose:**

To provide static application content for the custom image.

---

## EXPERIMENT 3 — CREATE THE CSS STYLESHEET

Create a file named:

`styles.css`

Insert:

```css
body {
  font-family: Arial, sans-serif;
  background-color: #f1f5f9;
  margin: 0;
  padding: 50px;
}

main {
  max-width: 750px;
  margin: auto;
  padding: 35px;
  background-color: white;
  border-radius: 12px;
}

h1 {
  color: #1d4ed8;
}

h2 {
  color: #334155;
}

p {
  color: #475569;
  line-height: 1.7;
}
```

**Purpose:**

To create an additional application asset that can be incorporated into the custom image.

---

## EXPERIMENT 4 — CREATE THE DOCKERFILE

Create a file named:

`Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM nginx:alpine

WORKDIR /usr/share/nginx/html

RUN mkdir -p assets

COPY index.html ./index.html

COPY styles.css ./assets/styles.css

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Purpose:**

To define the image's base filesystem, build operations, application content, and runtime configuration.

**Required analysis:**

Identify every Dockerfile instruction and explain its role.

---

## EXPERIMENT 5 — CREATE THE DOCKERIGNORE FILE

Create a file named:

`.dockerignore`

Insert:

```dockerignore
.git
*.log
notes/
*.tar
secret.txt
```

**Purpose:**

To define file patterns that should be excluded from the default build context.

**Analysis question:**

Explain why excluding unnecessary files can improve image-building efficiency and reduce the risk of accidental file inclusion.

---

## EXPERIMENT 6 — VERIFY PROJECT STRUCTURE

Confirm that the project directory contains:

```text
docker-lecture05/
├── Dockerfile
├── .dockerignore
├── index.html
└── styles.css
```

**Important requirement:**

The Dockerfile must be named correctly.

The application source files must exist inside the selected build context.

---

## EXPERIMENT 7 — BUILD THE FIRST CUSTOM IMAGE

Execute:

```bash
docker build -t lecture05-site:v1 .
```

**Purpose:**

To construct a custom image from the Dockerfile and source files in the current directory.

**Expected behavior:**

Docker performs the following general operations:

1. Loads the Dockerfile.
2. Loads the build context.
3. Resolves the Nginx base image.
4. Establishes the working directory.
5. Creates the assets directory.
6. Copies the HTML file.
7. Copies the CSS file.
8. Records image execution configuration.
9. Exports the resulting image.
10. Associates the image with the reference `lecture05-site:v1`.

**Expected result:**

The build completes successfully and the new image is available locally.

**Observation:**

Record the result of the build.

---

## EXPERIMENT 8 — VERIFY THE BUILT IMAGE

Execute:

```bash
docker image ls lecture05-site
```

**Purpose:**

To verify that the custom image exists.

**Required observations:**

Record:

- Repository name.
- Image tag.
- Image identifier.
- Reported image size.

**Analysis question:**

Why does the new image contain more than the HTML and CSS files created for this laboratory?

---

## EXPERIMENT 9 — RUN THE CUSTOM WEBSITE

Execute:

```bash
docker run -d --name lecture05-web -p 127.0.0.1:8085:80 lecture05-site:v1
```

**Purpose:**

To instantiate a container from the custom image and publish its HTTP service.

**Command interpretation:**

`-d` requests detached execution.

`--name lecture05-web` assigns a container name.

`-p 127.0.0.1:8085:80` publishes the container's TCP port 80 through host loopback port 8085.

`lecture05-site:v1` identifies the locally constructed image.

**Expected result:**

The container starts and Docker returns its identifier.

---

## EXPERIMENT 10 — ACCESS THE WEBSITE

Open:

http://127.0.0.1:8085

**Expected result:**

The browser displays the custom website containing the heading:

**Docker Lecture 05**

The stylesheet should control the appearance of the page.

**Technical interpretation:**

The browser communicates with the Docker host's published port.

Docker forwards the connection to the Nginx process running inside the container.

Nginx retrieves the HTML and CSS files incorporated during image construction and returns them to the browser.

---

## EXPERIMENT 11 — INSPECT THE CONTAINER FILESYSTEM

Execute:

```bash
docker exec lecture05-web ls -la /usr/share/nginx/html
```

Then:

```bash
docker exec lecture05-web ls -la /usr/share/nginx/html/assets
```

Finally:

```bash
docker exec lecture05-web cat /usr/share/nginx/html/index.html
```

**Purpose:**

To verify that the application files were incorporated into the image and are visible in the running container.

**Required observations:**

1. Confirm that `index.html` exists.
2. Confirm that the `assets` directory exists.
3. Confirm that `styles.css` exists.
4. Verify that the HTML content corresponds to the original project file.

---

## EXPERIMENT 12 — INSPECT IMAGE CONFIGURATION

Execute:

```bash
docker image inspect lecture05-site:v1
```

Now retrieve selected fields.

**Default command:**

```bash
docker image inspect --format '{{json .Config.Cmd}}' lecture05-site:v1
```

**Working directory:**

```bash
docker image inspect --format '{{.Config.WorkingDir}}' lecture05-site:v1
```

**Exposed ports:**

```bash
docker image inspect --format '{{json .Config.ExposedPorts}}' lecture05-site:v1
```

**Purpose:**

To verify that Dockerfile metadata instructions are represented in the constructed image configuration.

---

## EXPERIMENT 13 — EXAMINE IMAGE HISTORY

Execute:

```bash
docker history lecture05-site:v1
```

**Purpose:**

To examine the construction history of the custom image.

**Required observations:**

1. Identify records associated with the custom Dockerfile.
2. Identify information inherited from the Nginx base image.
3. Determine whether the history contains entries for metadata instructions.
4. Explain why a `CMD` instruction does not require a filesystem-changing layer.

---

## EXPERIMENT 14 — EXAMINE BUILD CACHE REUSE

Execute the original build command again:

```bash
docker build -t lecture05-site:v1 .
```

**Purpose:**

To investigate the behavior of the build cache when the Dockerfile and source files are unchanged.

**Expected result:**

Docker should normally reuse eligible cached build results.

The exact progress output depends on the builder.

**Required observations:**

1. Record whether cached results were used.
2. Compare the build behavior with Experiment 7.
3. Explain why the builder can reuse previously computed operations.

---

## EXPERIMENT 15 — MODIFY THE APPLICATION

Open:

`index.html`

Change:

```html
<h1>Docker Lecture 05</h1>
```

To:

```html
<h1>Docker Lecture 05 — Updated Version</h1>
```

Save the file.

**Purpose:**

To introduce a controlled modification to a build-context input.

---

## EXPERIMENT 16 — BUILD A NEW IMAGE VERSION

Execute:

```bash
docker build -t lecture05-site:v2 .
```

**Purpose:**

To produce a new image containing the modified application content.

**Expected behavior:**

Docker reevaluates build operations depending on the modified HTML file.

Earlier unaffected build operations may reuse cached results.

**Required observations:**

1. Identify which operations appear to use cached results.
2. Identify which operations are rebuilt.
3. Compare the identifiers of the `v1` and `v2` images.
4. Explain why application source modifications can produce a new image.

---

## EXPERIMENT 17 — RUN THE UPDATED IMAGE

Execute:

```bash
docker run -d --name lecture05-web-v2 -p 127.0.0.1:8086:80 lecture05-site:v2
```

Open:

http://127.0.0.1:8086

**Expected result:**

The browser displays the updated website.

The original container remains available through port 8085.

**Technical interpretation:**

Two containers can operate from separate image versions.

An existing container is not automatically updated when another image is built from modified source files.

---

## EXPERIMENT 18 — COMPARE BOTH APPLICATION VERSIONS

Visit:

http://127.0.0.1:8085

Then:

http://127.0.0.1:8086

**Required observations:**

Compare the headings displayed by both websites.

**Analysis questions:**

1. Why does the first container continue displaying the earlier version?
2. Why did building `v2` not automatically modify the running `v1` container?
3. What are the deployment advantages of maintaining separately identified image versions?

---

## EXPERIMENT 19 — STUDY RUN AND CMD SEPARATELY

Create an additional file named:

`Dockerfile.command`

Insert:

```dockerfile
FROM alpine:3.20

WORKDIR /lesson

RUN echo "Created during image build" > message.txt

CMD ["cat", "/lesson/message.txt"]
```

Build the image:

```bash
docker build -f Dockerfile.command -t lecture05-command:v1 .
```

Run:

```bash
docker run --rm lecture05-command:v1
```

**Expected output:**

```text
Created during image build
```

**Technical interpretation:**

The `RUN` instruction created the file during image construction.

The `CMD` instruction configured the command that reads the file during container execution.

Now execute:

```bash
docker run --rm lecture05-command:v1 echo "CMD overridden"
```

**Expected output:**

```text
CMD overridden
```

**Analysis question:**

Why does the second execution not display the content of `message.txt`?

---

## EXPERIMENT 20 — TEST A BUILD-CONTEXT ERROR

Create a file named:

`Dockerfile.error`

Insert:

```dockerfile
FROM alpine:3.20

COPY file-that-does-not-exist.txt /app/
```

Attempt to build:

```bash
docker build -f Dockerfile.error -t lecture05-error:v1 .
```

**Expected result:**

The build fails because the required source file is unavailable in the build context.

**Purpose:**

To investigate the relationship between Dockerfile instructions and the build context.

**Required analysis:**

Identify the failed operation and explain its cause.

Do not create the missing file until the initial failure has been observed and recorded.

---

## EXPERIMENT 21 — CORRECT THE BUILD ERROR

Create a file named:

`file-that-does-not-exist.txt`

Insert:

```text
This file is used to demonstrate build context resolution.
```

Run:

```bash
docker build -f Dockerfile.error -t lecture05-error:v1 .
```

**Expected result:**

The build now succeeds.

**Technical interpretation:**

The required source file has become available within the selected build context.

The `COPY` operation can therefore complete.

---

## EXPERIMENT 22 — CONTROLLED CLEANUP

Stop the two Nginx containers:

```bash
docker stop lecture05-web lecture05-web-v2
```

Remove them:

```bash
docker rm lecture05-web lecture05-web-v2
```

Examine the images:

```bash
docker image ls
```

The laboratory images may be retained for future study.

If they are no longer required and are not used by existing containers, remove their references individually.

Example:

```bash
docker image rm lecture05-site:v1
```

Avoid broad image pruning during this experiment.

The objective is controlled resource management.

---

# 20. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation                         | Observed result |
| ---------- | --------------------------------- | --------------- |
| 1          | Project creation                  |                 |
| 2          | HTML file creation                |                 |
| 3          | CSS file creation                 |                 |
| 4          | Dockerfile construction           |                 |
| 5          | Dockerignore configuration        |                 |
| 6          | Project structure verification    |                 |
| 7          | First image build                 |                 |
| 8          | Image verification                |                 |
| 9          | Container startup                 |                 |
| 10         | Browser access                    |                 |
| 11         | Container filesystem inspection   |                 |
| 12         | Image configuration inspection    |                 |
| 13         | Image history examination         |                 |
| 14         | Build cache reuse                 |                 |
| 15         | Application modification          |                 |
| 16         | Updated image build               |                 |
| 17         | Updated container startup         |                 |
| 18         | Image version comparison          |                 |
| 19         | RUN and CMD investigation         |                 |
| 20         | Build-context error investigation |                 |
| 21         | Build error correction            |                 |
| 22         | Laboratory cleanup                |                 |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 250–350 words.

The conclusion should discuss:

1. The role of Dockerfiles in image construction.
2. The relationship between the build context and copied application files.
3. The distinction between build-time and runtime instructions.
4. The effects of Dockerfile instruction ordering.
5. The purpose of build caching.
6. The relationship between image versions and running containers.
7. The importance of controlled and reproducible image construction.

---

# 21. COMMON BUILD ERRORS AND TROUBLESHOOTING

## 21.1 Dockerfile Not Found

**Problem:**

Docker cannot locate a Dockerfile.

**Possible causes:**

- Incorrect working directory.
- Missing Dockerfile.
- Incorrect filename.
- Incorrect `-f` argument.

**Corrective procedure:**

Verify the selected context and Dockerfile path.

## 21.2 COPY Source Not Found

**Problem:**

A `COPY` instruction fails because a source file is unavailable.

**Possible causes:**

- Incorrect filename.
- File outside the build context.
- File excluded by `.dockerignore`.
- Incorrect directory structure.

**Corrective procedure:**

Inspect the project directory and confirm that the required file is available to the builder.

## 21.3 Invalid Dockerfile Instruction

**Problem:**

The builder encounters an unsupported instruction or incorrect instruction syntax.

**Possible causes:**

- Typographical error.
- Invalid argument structure.
- Unsupported syntax feature.
- Incorrect Dockerfile frontend configuration.

**Corrective procedure:**

Compare the instruction with the official Dockerfile reference.

## 21.4 RUN Command Failure

**Problem:**

A `RUN` instruction exits with an error.

**Possible causes:**

- Missing executable.
- Invalid command syntax.
- Dependency installation failure.
- Filesystem permission failure.
- Incorrect working directory.

**Corrective procedure:**

Examine the build output and identify the failing command.

Determine whether the required executable and resources exist in the selected base image.

## 21.5 Container Exits Immediately

**Problem:**

A container created from the custom image terminates shortly after startup.

**Possible causes:**

- Invalid default command.
- Application initialization failure.
- Short-lived command.
- Missing configuration.
- Unsupported executable.

**Corrective procedure:**

Inspect the container state and retrieve application logs.

Do not assume that the image-building process itself failed merely because the resulting container exited.

## 21.6 Website Unavailable

**Problem:**

The custom Nginx website cannot be accessed through the expected host port.

**Possible causes:**

- Container not running.
- Incorrect host port.
- Port publishing not configured.
- Host port conflict.
- Application startup failure.
- Networking restrictions.

**Corrective procedure:**

Verify the container state, port mappings, and logs.

## 21.7 Unexpected Old Application Content

**Problem:**

The browser continues displaying older application content after the source file has been modified.

**Possible causes:**

- The image has not been rebuilt.
- The running container was created from an earlier image.
- The wrong image tag was used.
- The browser is displaying cached content.
- The file was copied from an unintended location.

**Corrective procedure:**

Confirm the modified source, build the intended image version, and create a container from that version.

A new build does not automatically replace an existing container.

---

# 22. BASIC SECURITY AND REPRODUCIBILITY CONSIDERATIONS

## 22.1 Build Reproducibility

A reproducible build is one in which sufficiently controlled build inputs and conditions produce the same intended result.

Dockerfiles contribute to reproducibility by recording build operations.

However, a Dockerfile alone does not guarantee identical output across time and platforms.

External dependencies may change.

Base-image tags may be updated.

Package repositories may publish new versions.

Build tools may behave differently across environments.

Therefore, reproducibility requires attention to all relevant build inputs.

## 22.2 Base Image Versioning

Using a moving image tag can produce different results on different dates.

For example:

```dockerfile
FROM nginx:alpine
```

may resolve to updated image content when the publisher changes the tag target.

Using a digest-based reference provides more precise identification of base image content.

However, digest pinning also requires a process for reviewing and adopting security updates.

## 22.3 Secrets During Builds

Application images should not contain confidential credentials.

Examples include:

- Passwords.
- API tokens.
- Private keys.
- Cloud credentials.
- Database connection secrets.

Secrets should not be embedded in Dockerfile instructions or copied into images.

Deleting a sensitive file in a later layer does not necessarily remove its content from earlier image layers.

Modern build mechanisms provide dedicated secret-handling features.

These will be examined during later security lectures.

## 22.4 Minimal Dependencies

An image should contain the dependencies necessary for its intended application.

Unnecessary packages may increase:

- Image size.
- Maintenance burden.
- Vulnerability exposure.
- Build complexity.

However, excessive minimization can remove libraries or tools required for correct execution.

Appropriate image construction balances functionality, maintainability, security, and efficiency.

## 22.5 Non-Root Execution

Applications should generally avoid unnecessary root privileges.

The Dockerfile `USER` instruction can establish an alternative default user.

However, some application images require additional permission configuration to execute successfully as a non-root user.

This topic will be studied in greater detail in Lecture 06 and the Docker security lecture.

---

# 23. IMPORTANT DOCKERFILE TERMINOLOGY

| Term                  | Academic definition                                                     |
| --------------------- | ----------------------------------------------------------------------- |
| Dockerfile            | Text specification for constructing container images                    |
| Image build           | Process of assembling a container image                                 |
| Build context         | Source material made available to the builder                           |
| BuildKit              | Modern Docker image-building backend                                    |
| LLB                   | Low-Level Build representation used by BuildKit                         |
| Base image            | Starting image for a build stage                                        |
| Build instruction     | Directive controlling an aspect of image construction                   |
| FROM                  | Instruction selecting a base image                                      |
| WORKDIR               | Instruction establishing a working directory                            |
| COPY                  | Instruction introducing filesystem content                              |
| RUN                   | Instruction executing a build-time command                              |
| CMD                   | Instruction defining default runtime command or arguments               |
| EXPOSE                | Instruction documenting an intended container port                      |
| Build cache           | Reusable results of previous build operations                           |
| Cache invalidation    | Condition requiring reevaluation of a cached operation                  |
| `.dockerignore`       | File defining build-context exclusion patterns                          |
| Image tag             | Human-readable image reference                                          |
| Build artifact        | Output produced by a build process                                      |
| Image configuration   | Metadata affecting container execution                                  |
| Runtime configuration | Settings used when creating or starting containers                      |
| Shell form            | Instruction syntax using shell command interpretation                   |
| Exec form             | Instruction syntax explicitly specifying executable and arguments       |
| Image reproducibility | Ability to reconstruct equivalent image results under controlled inputs |
| Immutable image       | Image whose content objects are not modified in place                   |
| Build dependency      | Input or prior operation required by another build operation            |
| Entrypoint            | Executable configuration defining the container's startup program       |

---

# 24. COMMON CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1: A Dockerfile is a Docker image.

Incorrect.

A Dockerfile is a build specification.

An image is the resulting packaged artifact.

## Misunderstanding 2: Building an image automatically starts a container.

Incorrect.

Image construction and container execution are separate operations.

## Misunderstanding 3: RUN executes whenever the container starts.

Incorrect.

`RUN` executes during image construction.

## Misunderstanding 4: CMD executes while the image is being built.

Incorrect.

`CMD` establishes runtime command configuration.

## Misunderstanding 5: EXPOSE publishes the port on the host.

Incorrect.

`EXPOSE` declares image metadata.

Runtime port publishing is configured separately.

## Misunderstanding 6: WORKDIR changes the host terminal's directory.

Incorrect.

`WORKDIR` establishes a directory within the build stage and image configuration.

## Misunderstanding 7: COPY can read any file on the developer's computer.

Incorrect.

Ordinary context-based copying is restricted to the files available through the selected build context and its filtering rules.

## Misunderstanding 8: A successful Docker build guarantees successful application execution.

Incorrect.

Build success establishes that the required build operations completed.

The application may still fail during container startup or runtime.

## Misunderstanding 9: Every Dockerfile instruction creates a filesystem layer.

Incorrect.

Some instructions modify image configuration without producing filesystem changesets.

## Misunderstanding 10: Docker always rebuilds every operation.

Incorrect.

BuildKit can reuse cached build results when their requirements are satisfied.

## Misunderstanding 11: Changing a source file updates an already running container.

Incorrect.

Existing containers do not automatically incorporate newly rebuilt images.

## Misunderstanding 12: A .dockerignore file is equivalent to .gitignore.

Incorrect.

The files affect different systems and serve different purposes.

## Misunderstanding 13: A Dockerfile guarantees identical images forever.

Incorrect.

Uncontrolled external dependencies, mutable references, architecture differences, and other build inputs can affect the result.

## Misunderstanding 14: A smaller image is always better.

Incorrect.

An image must contain the components required for correct, maintainable, and secure execution.

---

# 25. ACADEMIC ASSESSMENT

## Part A — Formal Definitions

Provide technically precise definitions for:

1. Dockerfile.
2. Image construction.
3. Build context.
4. Base image.
5. Docker BuildKit.
6. Build cache.
7. Cache invalidation.
8. Dockerfile instruction.
9. Build-time operation.
10. Runtime configuration.
11. Docker image tag.
12. `.dockerignore`.
13. Image reproducibility.
14. Dockerfile working directory.
15. Build artifact.

## Part B — Short-Answer Questions

**Question 1.**

Explain why custom Docker images are required for application-specific deployment.

**Question 2.**

Describe the relationship between a Dockerfile, an image, and a container.

**Question 3.**

Explain the role of the build context.

**Question 4.**

Describe why a `COPY` instruction may fail when a file exists outside the selected build context.

**Question 5.**

Explain the purpose of the `FROM` instruction.

**Question 6.**

Describe the difference between `WORKDIR` and executing `cd` through a `RUN` command.

**Question 7.**

Explain how `COPY` modifies the content of a constructed image.

**Question 8.**

Distinguish between `RUN` and `CMD`.

**Question 9.**

Explain why `EXPOSE 80` does not automatically publish port 80 on the Docker host.

**Question 10.**

Describe why instruction order can influence build cache efficiency.

**Question 11.**

Explain the purpose of `.dockerignore`.

**Question 12.**

Describe why Dockerfile-based builds may still produce different results on different dates.

**Question 13.**

Explain the difference between building a new image version and restarting an existing container.

**Question 14.**

Describe the significance of the Docker BuildKit system.

**Question 15.**

Explain why sensitive information should not be copied into image filesystem layers.

---

# 26. COMMAND INTERPRETATION ASSESSMENT

Consider:

```bash
docker build -t academic-app:v1 .
```

Answer the following:

1. What operation is requested?
2. What does `-t` represent?
3. What is the image repository name?
4. What is the image tag?
5. What does the final period represent?
6. Does the command start a container?
7. Where is the resulting image normally made available?

Now consider:

```dockerfile
FROM alpine:3.20

WORKDIR /course

RUN mkdir -p examples

COPY notes.txt ./notes.txt

CMD ["cat", "/course/notes.txt"]
```

Answer:

8. Which instruction selects the base image?
9. Which instruction defines the working directory?
10. Which instruction creates a directory during build?
11. Which instruction introduces source content?
12. Which instruction defines runtime behavior?
13. Where will `notes.txt` be located inside the image?
14. What happens when a container is started without overriding its default command?
15. What happens if the source file is unavailable in the build context?

---

# 27. ANALYTICAL CASE STUDIES

## Case Study 1 — Missing Build Context File

A developer creates a Dockerfile containing:

```dockerfile
FROM alpine:3.20

COPY application.py /app/application.py
```

The build fails because the source file cannot be located.

Analyze the possible reasons.

Explain how the selected build context affects source-file resolution.

Recommend a systematic investigation procedure.

## Case Study 2 — RUN and CMD Confusion

A developer writes:

```dockerfile
FROM alpine:3.20

RUN echo "Application started"
```

The developer expects the message to appear every time a container starts.

Explain why this expectation is incorrect.

Propose an appropriate Dockerfile modification.

## Case Study 3 — Image Versioning

An organization builds application image version 1.0 and starts several containers.

Later, the source code is modified and image version 2.0 is constructed.

Explain why the original containers continue operating with the earlier application content.

Discuss the role of controlled image replacement during deployment.

## Case Study 4 — Build Cache Efficiency

A development team repeatedly rebuilds an application image.

The build installs a large collection of dependencies.

Every small source-code modification appears to cause the dependency installation operation to be repeated.

Explain how Dockerfile instruction ordering may influence this behavior.

Recommend a build organization strategy that improves cache reuse.

## Case Study 5 — Sensitive Build Files

A development project contains:

```text
project/
├── Dockerfile
├── application.py
├── requirements.txt
├── private-key.pem
└── local-database-backup.sql
```

The Dockerfile uses:

```dockerfile
COPY . /app
```

Analyze the security risks.

Discuss how the build context and `.dockerignore` can reduce accidental inclusion.

Explain why confidential resources should generally be managed outside the application image.

---

# 28. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Dockerfile-Based Image Construction and Reproducible Application Packaging

Prepare an academic report of approximately 900–1,300 words addressing:

**“Dockerfiles as Build Specifications: Architecture, Build Contexts, Instruction Semantics, and Container Image Reproducibility.”**

The report must contain:

1. An introduction to custom container image construction.
2. A formal definition of the Dockerfile.
3. A description of Docker's image-building architecture.
4. An explanation of build contexts.
5. A technical analysis of `FROM`.
6. A technical analysis of `WORKDIR`.
7. A technical analysis of `COPY`.
8. A comparison of `RUN` and `CMD`.
9. An explanation of `EXPOSE`.
10. A discussion of Docker build caching.
11. An explanation of `.dockerignore`.
12. An examination of build reproducibility.
13. A security discussion concerning image construction.
14. A conclusion assessing the role of Dockerfiles in modern software deployment.

The report should include at least one Dockerfile example and an architectural representation of the build process.

---

# 29. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 06, the student should be able to complete the following tasks independently.

- [ ] Define a Dockerfile.
- [ ] Explain the image-building process.
- [ ] Describe the relationship between Dockerfiles, images, and containers.
- [ ] Explain the purpose of a build context.
- [ ] Identify the difference between Dockerfile location and build-context location.
- [ ] Write a valid Dockerfile.
- [ ] Use the `FROM` instruction.
- [ ] Select an appropriate base image.
- [ ] Use the `WORKDIR` instruction.
- [ ] Explain relative destination paths.
- [ ] Use the `COPY` instruction.
- [ ] Explain build-context file restrictions.
- [ ] Use the `RUN` instruction.
- [ ] Use the `CMD` instruction.
- [ ] Distinguish build-time and runtime behavior.
- [ ] Explain the purpose of `EXPOSE`.
- [ ] Configure a `.dockerignore` file.
- [ ] Build an image using `docker build`.
- [ ] Assign an image tag.
- [ ] Inspect the resulting image.
- [ ] Examine image construction history.
- [ ] Run a container from a custom image.
- [ ] Access a containerized website.
- [ ] Modify the application and rebuild the image.
- [ ] Compare two image versions.
- [ ] Observe build cache reuse.
- [ ] Diagnose a missing-file build failure.
- [ ] Explain basic build reproducibility limitations.
- [ ] Identify security risks associated with including confidential files.
- [ ] Complete the laboratory and document its results.

**Completion standard:**

The student should demonstrate the ability to create a functioning custom image without copying an unexplained Dockerfile from an external source.

The student must also understand the effects of each instruction used and be able to diagnose elementary build failures.

---

# 30. LECTURE SUMMARY

Dockerfiles provide a standardized method for defining custom container image construction.

A Dockerfile contains instructions interpreted by the Docker build system to establish the filesystem content and execution configuration of an image.

Docker BuildKit provides the modern backend used to evaluate build dependencies, perform operations, and reuse eligible cached results.

The build context defines the source material available to the builder.

The `FROM` instruction establishes a base image.

The `WORKDIR` instruction establishes the working directory used by subsequent relevant operations.

The `COPY` instruction introduces files and directories into the image filesystem.

The `RUN` instruction executes commands during image construction.

The `CMD` instruction defines default runtime command behavior.

The `EXPOSE` instruction documents expected application ports without publishing them directly on the host.

Dockerfile instruction ordering influences both the logical results of the build and the efficiency of build caching.

The `.dockerignore` file provides control over unwanted files in the build context.

Image construction produces a deployment artifact that is distinct from running container instances.

A newly built image does not automatically modify containers created from earlier image content.

Dockerfiles improve software packaging consistency, but true reproducibility also requires control of base-image references, dependencies, platforms, and other build inputs.

Secure image construction requires careful handling of sensitive information and the selection of appropriate base images and dependencies.

A fundamental conclusion is that **Dockerfiles transform application packaging into a defined, inspectable, and automatable build process.**

---

# 31. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. _Dockerfile Reference._  
https://docs.docker.com/reference/dockerfile/

[2] Docker Inc. _Writing a Dockerfile._  
https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/

[3] Docker Inc. _Build, Tag, and Publish an Image._  
https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/

[4] Docker Inc. _Docker Build Context._  
https://docs.docker.com/build/concepts/context/

[5] Docker Inc. _Docker Build Overview._  
https://docs.docker.com/build/concepts/overview/

[6] Docker Inc. _Docker Build Cache._  
https://docs.docker.com/build/cache/

[7] Docker Inc. _Build Cache Invalidation._  
https://docs.docker.com/build/cache/invalidation/

[8] Docker Inc. _Optimize Build Cache Usage._  
https://docs.docker.com/build/cache/optimize/

[9] Docker Inc. _Docker Build Best Practices._  
https://docs.docker.com/build/building/best-practices/

[10] Docker Inc. _Docker Image Build Command._  
https://docs.docker.com/reference/cli/docker/image/build/

[11] Docker Inc. _BuildKit._  
https://docs.docker.com/build/buildkit/

[12] Docker Inc. _Dockerfile Overview._  
https://docs.docker.com/build/concepts/dockerfile/

[13] Docker Inc. _Docker Image Inspect._  
https://docs.docker.com/reference/cli/docker/image/inspect/

[14] Docker Inc. _Docker Image History._  
https://docs.docker.com/reference/cli/docker/image/history/

[15] Docker Inc. _Building Images._  
https://docs.docker.com/get-started/docker-concepts/building-images/

## Recommended Reading Sequence

Students should begin with references [1], [2], and [3] to establish Dockerfile syntax and image construction fundamentals.

References [4] and [5] explain the build context and overall build architecture.

References [6], [7], and [8] provide detailed information about build caching.

Reference [9] describes recommended image construction practices.

References [10] through [14] provide command-level and implementation-related details.

---

# 32. FINAL LECTURE CONCLUSION

Dockerfile-based image construction is a foundational capability in containerized software engineering.

While downloading and running existing images is sufficient for many basic development activities, application-specific deployment generally requires controlled packaging of application files, runtime dependencies, and execution configuration.

Dockerfiles provide a structured mechanism through which these requirements can be expressed.

Their instructions define the relationship between a base image and the additional content required by a particular application.

The image-building system transforms these instructions and their associated source material into a standardized container image.

The distinction between build-time execution and runtime configuration is especially significant.

Build-time instructions prepare the environment.

Runtime configuration specifies how applications should operate when containers are instantiated.

Understanding this separation prevents common errors involving the misuse of `RUN`, `CMD`, and related instructions.

Build contexts and ignore rules establish important boundaries around which source files are available during construction.

Build caching introduces further considerations concerning instruction order, dependency changes, and computational efficiency.

A correctly constructed image can be stored, inspected, versioned, distributed, and used to create multiple independent container instances.

This supports standardized software deployment and automated development workflows.

However, image construction must also address security, dependency management, platform compatibility, and reproducibility.

The successful completion of this lecture demonstrates the student's transition from an operator of existing container images to a developer capable of constructing original Docker images.

These capabilities provide the foundation for more advanced Dockerfile instructions, optimization techniques, and multi-stage image construction.

---

**END OF LECTURE 05**

**Next Lecture:** Lecture 06 — Advanced Dockerfile Instructions: ENTRYPOINT, ENV, ARG, ADD, USER, Image Metadata, Build Cache Optimization, and Dockerfile Best Practices.
