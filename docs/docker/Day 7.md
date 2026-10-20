# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 07 — WEEK ONE COMPREHENSIVE REVIEW, TECHNICAL ASSESSMENT, AND PRACTICAL CAPSTONE PROJECT

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 07 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–6 hours  
**Assessment Type:** Theoretical Examination and Practical Laboratory  
**Prerequisites:** Successful study of Lectures 01–06.

---

# 1. LECTURE OVERVIEW

## 1.1 Purpose of the Lecture

The purpose of Lecture 07 is to consolidate the theoretical knowledge and practical skills developed throughout the first six lectures of the course.

The previous lectures established the following technical foundations:

- Containerization architecture.
- Docker Engine and Docker components.
- Container creation and lifecycle management.
- Runtime inspection and diagnostics.
- Container filesystems and process isolation.
- Docker image architecture and registries.
- Image construction using Dockerfiles.
- Build-time and runtime configuration.
- Dockerfile instruction semantics.
- Image tagging and version management.
- Build caching and reproducibility.
- Introductory container security practices.

These topics represent related components of a single container-based software delivery system.

A student who understands the individual commands but cannot explain how they interact has not yet achieved comprehensive technical competence.

The present lecture therefore adopts an integrated approach.

It requires the student to construct a complete application image, instantiate and manage containers, investigate execution behavior, modify the application, and demonstrate understanding of the underlying mechanisms.

## 1.2 Academic Significance

Containerization is not merely a collection of command-line operations.

It is an engineering approach involving:

1. Operating-system isolation.
2. Application packaging.
3. Process execution.
4. Filesystem management.
5. Network configuration.
6. Software distribution.
7. Reproducible construction.
8. Runtime diagnostics.
9. Security configuration.
10. Deployment lifecycle management.

These elements must operate together to support a functioning containerized application.

The capstone project serves as a practical demonstration of this relationship.

---

# 2. LEARNING OBJECTIVES

Upon completion of Lecture 07, the student should be able to:

1. Explain Docker's architecture without relying on introductory definitions alone.
2. Describe how operating-system isolation supports container execution.
3. Distinguish containers from conventional virtual machines.
4. Explain the complete lifecycle of a Docker container.
5. Distinguish image configuration from container runtime configuration.
6. Retrieve, inspect, and manage Docker images.
7. Explain image layers, tags, and identifiers.
8. Execute applications using foreground, detached, and interactive modes.
9. Inspect container processes, metadata, logs, and filesystem content.
10. Explain container writable-layer behavior.
11. Create an application-specific Dockerfile.
12. Identify and control a Docker build context.
13. Apply Dockerfile instructions correctly.
14. Construct and version custom Docker images.
15. Explain the interaction between `CMD` and `ENTRYPOINT`.
16. Distinguish `ARG` from `ENV`.
17. Explain fundamental build-cache behavior.
18. Publish a containerized web application through a host port.
19. Demonstrate the difference between application changes and image rebuilding.
20. Explain why rebuilding an image does not automatically update running containers.
21. Troubleshoot common build and runtime errors.
22. Apply elementary security and reproducibility practices.
23. Complete the Week One capstone project.
24. Present and defend the technical decisions used in the project.

---

# PART I — COMPREHENSIVE THEORETICAL REVIEW

# 3. REVIEW OF DOCKER ARCHITECTURE

## 3.1 Containerization as an Operating-System Mechanism

Containerization is a form of operating-system-level virtualization in which processes execute within isolated environments while sharing a compatible operating-system kernel.

In Linux container environments, process isolation relies on mechanisms such as namespaces and control groups.

Namespaces control the visibility of selected system resources.

Control groups support the organization and management of resource consumption.

A container therefore represents an isolated process environment rather than a complete independent operating system.

## 3.2 Docker as a Container Management Platform

Docker provides tools and services for constructing, distributing, and executing containerized applications.

The principal Docker components include:

**Docker Client**

Provides a command-line interface through which users submit operations.

**Docker Daemon**

Processes Docker API requests and coordinates container, image, network, and storage operations.

**Docker Engine**

Provides the core container management infrastructure.

**Container Runtime**

Performs lower-level operations required for creating and executing container processes.

**Image Registry**

Stores and distributes container image content.

## 3.3 Integrated Docker Architecture

```text
DEVELOPER → Docker CLI
Docker CLI → Docker Daemon, dockerd (Docker API)
Docker Daemon → IMAGE STORE
Docker Daemon → NETWORKS
Docker Daemon → VOLUMES
IMAGE STORE → CONTAINER RUNTIME
CONTAINER RUNTIME → RUNNING CONTAINERS
RUNNING CONTAINERS → APPLICATION PROCESSES
EXTERNAL IMAGE REGISTRY → IMAGE STORE (image distribution)
```

The diagram represents logical responsibilities.

It does not reproduce every internal component of a modern Docker installation.

## 3.4 Containers Versus Virtual Machines

Conventional virtual machines generally execute independent guest operating-system kernels through a hypervisor.

Linux containers instead share a Linux kernel while isolating application processes.

The shared-kernel model can reduce some operating-system overhead.

However, containers and virtual machines provide different isolation characteristics.

Docker Desktop may itself use a virtualized Linux environment on non-Linux operating systems.

Therefore, containers and virtual machines should be regarded as complementary technologies rather than universally interchangeable alternatives.

---

# 4. REVIEW OF CONTAINER LIFECYCLE MANAGEMENT

## 4.1 Lifecycle Definition

The container lifecycle is the sequence of state transitions through which a container passes from creation to removal.

Principal states include:

- Created.
- Running.
- Paused.
- Restarting.
- Exited.
- Removing.
- Dead.

The lifecycle is closely associated with the execution state of the container's designated principal process.

## 4.2 Lifecycle Operations

| Command          | Operation                    |
| ---------------- | ---------------------------- |
| `docker create`  | Create without starting      |
| `docker run`     | Create and start             |
| `docker start`   | Start an existing container  |
| `docker stop`    | Request process termination  |
| `docker restart` | Restart a container          |
| `docker ps`      | List running containers      |
| `docker ps -a`   | List all existing containers |
| `docker rm`      | Remove a container           |

## 4.3 Container State Versus Container Identity

Stopping a container ordinarily preserves its identifier, configuration, and writable filesystem layer.

Starting the same container again preserves its identity.

Removing a container deletes the corresponding container object.

Creating a replacement container from the same image produces a new container identity.

## 4.4 Principal Process Behavior

A container's running state normally depends on whether its principal process remains active.

For example:

A container executing a short-lived utility may terminate immediately after successful completion.

A container executing a web server generally remains active while that server continues running.

Detached execution does not guarantee indefinite execution.

---

# 5. REVIEW OF CONTAINER INTERNALS

## 5.1 Internal Command Execution

Docker provides:

`docker exec`

This command starts an additional process within an existing running container.

Example:

```bash
docker exec -it my-container sh
```

An interactive shell created through `docker exec` is normally separate from the container's principal process.

Exiting that shell does not ordinarily terminate the container.

## 5.2 External Inspection

Important commands include:

```bash
docker inspect my-container
docker top my-container
docker stats my-container
docker logs my-container
docker diff my-container
```

These commands provide access to different categories of operational information.

## 5.3 Filesystem Architecture

A container filesystem commonly combines immutable image content with container-specific writable filesystem state.

```text
CONTAINER FILESYSTEM
[ Container Writable Layer ]
[ Image Filesystem Layer 3 ]
[ Image Filesystem Layer 2 ]
[ Image Filesystem Layer 1 ]
```

An ordinary container restart preserves its writable layer.

Container removal ordinarily deletes that layer.

Important data should not depend exclusively on the lifecycle of a particular container object.

## 5.4 Filesystem Inspection

A container administrator may examine files using commands such as:

```bash
docker exec my-container ls /
docker exec my-container cat /etc/os-release
```

The available commands depend on the tools included in the image.

A minimal image may not contain a complete collection of Linux utilities.

---

# 6. REVIEW OF DOCKER IMAGE TECHNOLOGY

## 6.1 Definition

A Docker image is an immutable package of filesystem content and execution metadata used to instantiate containers.

Images may contain multiple reusable filesystem layers.

An image does not execute processes until an appropriate runtime creates and starts a container from it.

## 6.2 Image Identification

Images may be identified through:

1. Repository references.
2. Tags.
3. Image identifiers.
4. Content digests.

A tag is a human-readable reference that may change.

A digest identifies content through a cryptographic hash.

An image identifier and a registry manifest digest may identify different objects.

## 6.3 Principal Image Operations

```bash
docker pull nginx:alpine

docker image ls

docker image inspect nginx:alpine

docker history nginx:alpine

docker tag nginx:alpine study-nginx:v1
```

The commands perform image retrieval, listing, inspection, history examination, and tagging.

## 6.4 Registries

Container registries store and distribute images.

Docker Hub is a widely used hosted registry.

A registry does not ordinarily execute the containerized application it stores.

Execution occurs in a compatible container runtime environment.

---

# 7. REVIEW OF DOCKERFILE CONSTRUCTION

## 7.1 Dockerfile Definition

A Dockerfile is a text-based build specification that defines image construction operations and execution configuration.

The Docker build system interprets its instructions to produce an image artifact.

## 7.2 Fundamental Instructions

| Instruction   | Purpose                                     |
| ------------- | ------------------------------------------- |
| `FROM`        | Select base image                           |
| `WORKDIR`     | Establish working directory                 |
| `COPY`        | Include application content                 |
| `RUN`         | Execute build-time commands                 |
| `CMD`         | Define default startup command or arguments |
| `EXPOSE`      | Declare intended container port             |
| `ENV`         | Define environment variables                |
| `ARG`         | Declare build-time parameters               |
| `ENTRYPOINT`  | Establish startup executable                |
| `USER`        | Define execution identity                   |
| `LABEL`       | Record image metadata                       |
| `ADD`         | Include supported source material           |
| `HEALTHCHECK` | Define runtime health checks                |

## 7.3 Build Context

The build context defines the source material made available to the builder.

In:

```bash
docker build -t application:v1 .
```

the final period identifies the current directory as the build context.

Files excluded through `.dockerignore` are not ordinarily available to regular context-based `COPY` instructions.

## 7.4 Build-Time Versus Runtime Behavior

A `RUN` instruction executes during image construction.

A `CMD` instruction establishes default runtime command configuration.

An `ENTRYPOINT` instruction establishes the principal executable.

An `ARG` instruction defines a build-time value.

An `ENV` instruction can persist environment configuration into the resulting image.

These distinctions are essential for correctly understanding Dockerfile behavior.

---

# 8. REVIEW OF IMAGE BUILD CACHING

## 8.1 Purpose

Docker BuildKit can reuse results from earlier build operations when the relevant inputs and execution conditions remain compatible.

This reduces unnecessary construction work.

## 8.2 Cache Invalidation

A cache result may become ineligible for reuse when required inputs change.

Common examples include:

- Modified Dockerfile instructions.
- Modified copied application files.
- Changed build arguments.
- Updated base images.
- Changed build dependencies.

Changes to copied source content commonly invalidate the corresponding copy operation and dependent operations.

## 8.3 Importance of Instruction Ordering

Stable and expensive build operations should generally be placed before frequently changing application content when dependency correctness permits.

For example, application dependencies may be installed after copying dependency manifests but before copying the rest of the source code.

This can improve cache reuse.

## 8.4 Limits of Caching

Build caching improves performance.

It does not automatically guarantee updated dependencies, complete reproducibility, or application correctness.

External sources, dependency versions, platform differences, and build configuration remain important.

---

# PART II — WEEK ONE CAPSTONE PROJECT

# 9. PROJECT INTRODUCTION

## 9.1 Project Title

**Containerization of a Personal Portfolio Website Using Docker and Nginx**

## 9.2 Project Classification

Academic software engineering laboratory and practical competency assessment.

## 9.3 Project Objective

The objective is to design, construct, execute, inspect, modify, version, and manage a containerized static website.

The project requires the student to apply the concepts studied throughout Lectures 01–06.

The website will be served using Nginx inside Docker.

The image will contain the website's HTML, CSS, and JavaScript resources.

The project must support:

1. Custom image construction.
2. Dockerfile-based packaging.
3. Explicit image versioning.
4. Container lifecycle management.
5. Port publishing.
6. Filesystem inspection.
7. Image metadata inspection.
8. Application log examination.
9. Image rebuilds.
10. Verification of version independence.

## 9.4 Project Scope

The required application is a static personal portfolio website.

It will contain:

- A home page.
- An about page.
- A stylesheet.
- A JavaScript file.
- A navigation menu.
- Basic responsive layout.
- A visible application version identifier.

The website does not require a database or external application server.

Database connectivity, Docker networking between multiple services, and persistent volume management belong to the second week of the course.

## 9.5 Project Deliverables

The student must submit:

1. Complete project directory.
2. Application source files.
3. Dockerfile.
4. `.dockerignore` file.
5. Two locally constructed image versions.
6. Evidence of successful container execution.
7. Container inspection results.
8. Image inspection results.
9. Evidence of successful image rebuilding.
10. Written answers to technical analysis questions.
11. Laboratory report.
12. Final project conclusion.

---

# 10. PROJECT ARCHITECTURE

## 10.1 Logical System Architecture

```text
WEB BROWSER → DOCKER HOST (http://127.0.0.1:8087)
DOCKER HOST → DOCKER NETWORK (host port 8087)
DOCKER NETWORK → NGINX CONTAINER
NGINX CONTAINER → NGINX SERVER (port 80/TCP)
NGINX SERVER → STATIC WEBSITE FILES
STATIC WEBSITE FILES → HTML
STATIC WEBSITE FILES → CSS
STATIC WEBSITE FILES → JavaScript
```

## 10.2 Build Architecture

```text
PROJECT SOURCE → Dockerfile
PROJECT SOURCE → Website Files
Dockerfile → BUILD CONTEXT
Website Files → BUILD CONTEXT
BUILD CONTEXT → BUILD SYSTEM
BUILD SYSTEM → CUSTOM IMAGE
CUSTOM IMAGE → DOCKER CONTAINER
DOCKER CONTAINER → NGINX WEB SERVER
```

## 10.3 Architectural Requirements

The application must:

- Use an Nginx base image.
- Include static website files in the image.
- Use a Dockerfile.
- Publish the Nginx service through a host port.
- Execute successfully in detached mode.
- Produce accessible HTML and CSS content.
- Support reproducible image construction under controlled inputs.
- Preserve separately identified image versions.

---

# 11. PROJECT DIRECTORY STRUCTURE

Create the following directory:

```text
docker-week1-capstone/
├── Dockerfile
├── .dockerignore
├── site/
│   ├── index.html
│   ├── about.html
│   └── assets/
│       ├── styles.css
│       └── app.js
└── documentation/
    └── laboratory-notes.md
```

**Directory responsibilities:**

`Dockerfile` defines the container image construction.

`.dockerignore` controls unnecessary build-context content.

`site/` contains the static website.

`assets/` contains CSS and JavaScript resources.

`documentation/` contains laboratory observations and written analysis.

The complete project should be constructed within a single directory so that the intended build context is clearly defined.

---

# 12. APPLICATION SOURCE — HOME PAGE

Create:

`site/index.html`

Insert the following document:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />

    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>Docker Portfolio - Home</title>

    <link rel="stylesheet" href="/assets/styles.css" />

    <script src="/assets/app.js" defer></script>
  </head>

  <body>
    <header class="site-header">
      <h1>Docker Portfolio</h1>

      <nav>
        <a href="/">Home</a>
        <a href="/about.html">About</a>
      </nav>
    </header>

    <main class="container">
      <section class="hero">
        <p class="eyebrow">DOCKER WEEK ONE PROJECT</p>

        <h2>Containerized Personal Website</h2>

        <p>
          This website is packaged inside a custom Docker image and served by an
          Nginx container.
        </p>

        <p>
          The application demonstrates image construction, container execution,
          and static content delivery.
        </p>

        <div class="version">Application Version: 1.0</div>
      </section>

      <section class="features">
        <article>
          <h3>Docker Images</h3>
          <p>The website files are packaged into a reusable image.</p>
        </article>

        <article>
          <h3>Docker Containers</h3>
          <p>Nginx runs inside an isolated execution environment.</p>
        </article>

        <article>
          <h3>Docker Networking</h3>
          <p>The application is accessible through a published host port.</p>
        </article>
      </section>
    </main>

    <footer>
      <p>
        Docker Foundations Course -
        <span id="year"></span>
      </p>
    </footer>
  </body>
</html>
```

## Technical Interpretation

The HTML document defines the application's user interface.

It references an external stylesheet and JavaScript file.

These resources must be available in the filesystem served by Nginx.

The website content is introduced into the Docker image during the build process.

The visible application version will later be modified to demonstrate image rebuilding and version management.

---

# 13. APPLICATION SOURCE — ABOUT PAGE

Create:

`site/about.html`

Insert:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />

    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>Docker Portfolio - About</title>

    <link rel="stylesheet" href="/assets/styles.css" />

    <script src="/assets/app.js" defer></script>
  </head>

  <body>
    <header class="site-header">
      <h1>Docker Portfolio</h1>

      <nav>
        <a href="/">Home</a>
        <a href="/about.html">About</a>
      </nav>
    </header>

    <main class="container">
      <section class="hero">
        <p class="eyebrow">ABOUT THE PROJECT</p>

        <h2>Docker Containerization Laboratory</h2>

        <p>
          This project was developed as the final practical exercise of the
          first module of a Docker course.
        </p>

        <p>
          The application uses Nginx to serve static web resources from within a
          Docker container.
        </p>

        <p>
          Its purpose is to demonstrate the relationship between Dockerfiles,
          images, containers, and network ports.
        </p>
      </section>
    </main>

    <footer>
      <p>
        Docker Foundations Course -
        <span id="year"></span>
      </p>
    </footer>
  </body>
</html>
```

---

# 14. APPLICATION SOURCE — CSS

Create:

`site/assets/styles.css`

Insert:

```css
* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: Arial, Helvetica, sans-serif;
  background-color: #f1f5f9;
  color: #1e293b;
}

.site-header {
  background-color: #0f172a;
  color: white;
  padding: 24px 8%;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.site-header h1 {
  font-size: 23px;
  margin: 0;
}

nav a {
  color: white;
  margin-left: 20px;
  text-decoration: none;
}

nav a:hover {
  text-decoration: underline;
}

.container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 50px 24px;
}

.hero {
  background-color: white;
  padding: 50px;
  border-radius: 12px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.06);
}

.eyebrow {
  color: #2563eb;
  font-weight: bold;
  letter-spacing: 2px;
  font-size: 12px;
}

.hero h2 {
  font-size: 36px;
}

.hero p {
  line-height: 1.8;
  color: #475569;
}

.version {
  margin-top: 25px;
  background-color: #dbeafe;
  color: #1d4ed8;
  display: inline-block;
  padding: 12px 18px;
  border-radius: 8px;
  font-weight: bold;
}

.features {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  margin-top: 30px;
}

.features article {
  background-color: white;
  padding: 25px;
  border-radius: 10px;
}

.features h3 {
  color: #1d4ed8;
}

features p {
  color: #475569;
}

footer {
  text-align: center;
  padding: 30px;
  color: #64748b;
}

@media (max-width: 700px) {
  .site-header {
    flex-direction: column;
    gap: 15px;
  }

  .features {
    grid-template-columns: 1fr;
  }

  .hero {
    padding: 25px;
  }

  .hero h2 {
    font-size: 27px;
  }
}
```

**Laboratory note:** The selector for feature-paragraph styling should be written as `.features p` if that additional rule is desired. Correcting the selector provides an optional elementary source-code debugging exercise.

---

# 15. APPLICATION SOURCE — JAVASCRIPT

Create:

`site/assets/app.js`

Insert:

```javascript
document.addEventListener("DOMContentLoaded", function () {
  const yearElement = document.getElementById("year");

  if (yearElement) {
    yearElement.textContent = new Date().getFullYear();
  }

  console.log("Docker Week One Capstone loaded successfully");
});
```

## Technical Interpretation

The JavaScript file executes in the user's browser.

It does not require a Node.js runtime inside the Docker container.

Nginx simply serves the JavaScript file as a static resource.

This distinction is important.

A static web server delivers HTML, CSS, and JavaScript to the browser.

The browser interprets and executes the client-side JavaScript.

---

# 16. DOCKERFILE CONSTRUCTION

Create a file named:

`Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM nginx:alpine

ARG COURSE_RELEASE=1.0

LABEL org.opencontainers.image.title="Docker Week One Portfolio" \
      org.opencontainers.image.version="${COURSE_RELEASE}" \
      org.opencontainers.image.description="Docker Foundations Capstone"

ENV COURSE_PHASE=week1

WORKDIR /usr/share/nginx/html

RUN mkdir -p resources

COPY site/ ./

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## 16.1 Technical Analysis

### FROM

```dockerfile
FROM nginx:alpine
```

Selects an Nginx image as the base environment.

This supplies the web-server application and its supporting dependencies.

### ARG

```dockerfile
ARG COURSE_RELEASE=1.0
```

Declares a build-time variable with a default value.

The value is used to configure image metadata.

### LABEL

```dockerfile
LABEL org.opencontainers.image.title="Docker Week One Portfolio"
```

Adds descriptive information to the image configuration.

The version label is also configured using the build argument.

### ENV

```dockerfile
ENV COURSE_PHASE=week1
```

Defines an environment variable that remains available to processes created from the image unless overridden.

### WORKDIR

```dockerfile
WORKDIR /usr/share/nginx/html
```

Establishes the working directory for subsequent relevant operations.

### RUN

```dockerfile
RUN mkdir -p resources
```

Creates a directory during image construction.

The directory becomes part of the image filesystem.

### COPY

```dockerfile
COPY site/ ./
```

Copies the contents of the local `site/` directory into the working directory of the image.

### EXPOSE

```dockerfile
EXPOSE 80
```

Declares the application's intended TCP port.

It does not independently publish port 80 on the host.

### CMD

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

Defines the default runtime command.

The official Nginx image also provides an entrypoint configuration, which is inherited unless explicitly overridden.

The resulting startup behavior should therefore be understood in terms of both `ENTRYPOINT` and `CMD`.

---

# 17. CONFIGURING .DOCKERIGNORE

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.gitignore
*.log
*.tar
*.tmp
.env
secrets/
documentation/
node_modules/
```

## 17.1 Purpose

The `.dockerignore` file excludes selected files and directories from the ordinary build context.

This reduces unnecessary build inputs.

It also lowers the risk of accidentally introducing unrelated files or sensitive data into the image.

## 17.2 Security Qualification

Excluding confidential files from the build context is a useful precaution.

However, `.dockerignore` is not a complete secrets-management system.

Credentials should not be placed in the Dockerfile, image layers, or insecure build parameters.

---

# PART III — CAPSTONE PRACTICAL LABORATORY

# 18. EXPERIMENT 1 — VERIFY THE DOCKER ENVIRONMENT

Execute:

```bash
docker version
```

Then:

```bash
docker info
```

**Objective:**

Verify that Docker CLI and Docker Engine are available.

**Expected result:**

Docker displays client and server information.

**Required observations:**

Record:

- Docker client version.
- Docker server version.
- Host operating-system information.
- Available container information.
- Available image information.

---

# 19. EXPERIMENT 2 — BUILD IMAGE VERSION 1

Open a terminal inside the project directory.

Execute:

```bash
docker build \
  --build-arg COURSE_RELEASE=1.0 \
  -t week1-portfolio:v1 .
```

The command is shown using Unix-style line continuation. It may also be entered on one line in any supported terminal:

```bash
docker build --build-arg COURSE_RELEASE=1.0 -t week1-portfolio:v1 .
```

## 19.1 Purpose

Construct the first version of the custom website image.

## 19.2 Expected Operations

The builder:

1. Loads the Dockerfile.
2. Loads the build context.
3. Resolves the Nginx base image.
4. Evaluates the build argument.
5. Establishes image metadata.
6. Configures the working directory.
7. Creates the resources directory.
8. Copies the website files.
9. Records runtime configuration.
10. Exports the image.

## 19.3 Expected Result

The image is available locally using the reference:

`week1-portfolio:v1`

## 19.4 Required Observation

Execute:

```bash
docker image ls week1-portfolio
```

Record the image identifier and reported size.

---

# 20. EXPERIMENT 3 — INSPECT THE CUSTOM IMAGE

Execute:

```bash
docker image inspect week1-portfolio:v1
```

Now retrieve selected metadata.

**Image identifier:**

```bash
docker image inspect --format '{{.Id}}' week1-portfolio:v1
```

**Working directory:**

```bash
docker image inspect --format '{{.Config.WorkingDir}}' week1-portfolio:v1
```

**Default command:**

```bash
docker image inspect --format '{{json .Config.Cmd}}' week1-portfolio:v1
```

**Entrypoint:**

```bash
docker image inspect --format '{{json .Config.Entrypoint}}' week1-portfolio:v1
```

**Environment variables:**

```bash
docker image inspect --format '{{json .Config.Env}}' week1-portfolio:v1
```

**Version metadata:**

```bash
docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' week1-portfolio:v1
```

## Required Analysis

Explain which metadata fields originated from the custom Dockerfile and which behavior was inherited from the base image.

---

# 21. EXPERIMENT 4 — EXAMINE IMAGE HISTORY

Execute:

```bash
docker history week1-portfolio:v1
```

Then:

```bash
docker history --no-trunc week1-portfolio:v1
```

**Objective:**

Examine the image's recorded construction history.

**Required analysis:**

1. Identify selected instructions originating from the custom Dockerfile.
2. Identify records associated with the base image.
3. Explain why image history may contain metadata-only operations.
4. Describe the relationship between image history and filesystem layers.

---

# 22. EXPERIMENT 5 — RUN THE WEBSITE CONTAINER

Execute:

```bash
docker run -d --name week1-v1 -p 127.0.0.1:8087:80 week1-portfolio:v1
```

## 22.1 Purpose

Create and start a container from the custom image.

## 22.2 Expected Result

Docker returns the container identifier.

Verify:

```bash
docker ps
```

## 22.3 Browser Verification

Open:

http://127.0.0.1:8087

The webpage should display:

**Containerized Personal Website**

It should also display:

**Application Version: 1.0**

Navigate to:

http://127.0.0.1:8087/about.html

The About page should load successfully.

## Required Analysis

Explain the relationship between:

- Host port 8087.
- Container port 80.
- Docker networking.
- The Nginx application process.
- The website files included in the image.

---

# 23. EXPERIMENT 6 — INSPECT CONTAINER PROCESSES

Execute:

```bash
docker top week1-v1
```

**Objective:**

Examine the processes associated with the running Nginx container.

Next, execute:

```bash
docker exec week1-v1 cat /proc/1/status
```

## Required Analysis

1. Identify the principal container process.
2. Identify any visible worker processes.
3. Explain the significance of PID 1.
4. Explain why container process identifiers may differ from those visible in the Docker Engine host environment.
5. Explain why the container normally stops when its principal application process terminates.

---

# 24. EXPERIMENT 7 — INSPECT THE WEBSITE FILESYSTEM

Execute:

```bash
docker exec -it week1-v1 sh
```

Inside the container:

```sh
pwd
```

Then:

```sh
ls -la /usr/share/nginx/html
```

Then:

```sh
ls -la /usr/share/nginx/html/assets
```

Read the HTML:

```sh
cat /usr/share/nginx/html/index.html
```

Finally:

```sh
exit
```

## Expected Result

The application files are visible inside the container filesystem.

The Nginx server should continue running after the interactive shell exits.

## Required Analysis

Explain why exiting the additional shell process does not ordinarily terminate the container.

---

# 25. EXPERIMENT 8 — EXAMINE CONTAINER LOGS

Execute:

```bash
docker logs week1-v1
```

Now:

```bash
docker logs --tail 20 week1-v1
```

Then:

```bash
docker logs -t --tail 20 week1-v1
```

**Objective:**

Inspect application output and available diagnostic information.

Open the website several times in the browser.

Repeat the log inspection.

## Required Analysis

1. Identify any recorded HTTP requests.
2. Explain the role of standard output and standard error.
3. Explain why a container may remain running despite application warnings.
4. Describe the limitations of evaluating application health solely through logs.

---

# 26. EXPERIMENT 9 — EXAMINE RUNTIME CONFIGURATION

Execute:

```bash
docker inspect week1-v1
```

Retrieve the container's status:

```bash
docker inspect --format '{{.State.Status}}' week1-v1
```

Retrieve the source image reference:

```bash
docker inspect --format '{{.Config.Image}}' week1-v1
```

Retrieve the published ports:

```bash
docker inspect --format '{{json .HostConfig.PortBindings}}' week1-v1
```

Retrieve resource statistics:

```bash
docker stats --no-stream week1-v1
```

## Required Analysis

Differentiate among:

1. Image configuration.
2. Container creation configuration.
3. Runtime state.
4. Resource utilization measurements.

---

# 27. EXPERIMENT 10 — EXAMINE THE CONTAINER WRITABLE LAYER

Create a temporary file inside the container:

```bash
docker exec week1-v1 sh -c 'printf "Week One Runtime Observation\n" > /tmp/week1-observation.txt'
```

Read the file:

```bash
docker exec week1-v1 cat /tmp/week1-observation.txt
```

Now inspect filesystem changes:

```bash
docker diff week1-v1
```

## Expected Result

The newly created file should appear among the container's filesystem modifications.

Additional changes may have been generated by the Nginx application.

## Required Analysis

Explain:

- Why the file is visible inside the container.
- Why its creation does not modify the original image.
- How the writable layer relates to container identity.

---

# 28. EXPERIMENT 11 — COPY A FILE FROM THE CONTAINER

Execute from the project directory:

```bash
docker cp week1-v1:/tmp/week1-observation.txt ./week1-observation.txt
```

**Objective:**

Demonstrate file transfer between the container filesystem and the local filesystem.

## Expected Result

A file named:

`week1-observation.txt`

appears in the current local directory.

## Required Analysis

Explain why `docker cp` does not require a shell session inside the container.

---

# 29. EXPERIMENT 12 — VERIFY CONTAINER RESTART BEHAVIOR

Stop the container:

```bash
docker stop week1-v1
```

Verify:

```bash
docker ps -a
```

Start the container again:

```bash
docker start week1-v1
```

Read the temporary file:

```bash
docker exec week1-v1 cat /tmp/week1-observation.txt
```

## Expected Result

The file remains present.

## Technical Interpretation

Ordinary container stopping and starting preserves the existing container object and its writable filesystem layer.

## Required Analysis

Explain why this behavior differs from creating a completely new container from the original image.

---

# 30. EXPERIMENT 13 — BUILD IMAGE VERSION 2

Open:

`site/index.html`

Locate:

```html
Application Version: 1.0
```

Change it to:

```html
Application Version: 2.0
```

Save the file.

Build a new image:

```bash
docker build --build-arg COURSE_RELEASE=2.0 -t week1-portfolio:v2 .
```

## Purpose

Produce a new image containing updated application content and updated version metadata.

## Expected Result

The build succeeds and creates the `week1-portfolio:v2` image reference.

Inspect the image list:

```bash
docker image ls week1-portfolio
```

## Required Analysis

1. Compare the identifiers of versions 1 and 2.
2. Explain why the two versions represent different image content.
3. Examine which build operations reused cached results.
4. Explain why changing the HTML source affects the result of the relevant `COPY` operation.

---

# 31. EXPERIMENT 14 — RUN BOTH APPLICATION VERSIONS

Create a second container:

```bash
docker run -d --name week1-v2 -p 127.0.0.1:8088:80 week1-portfolio:v2
```

Open:

http://127.0.0.1:8087

Then:

http://127.0.0.1:8088

## Expected Results

**Port 8087:** Application Version 1.0

**Port 8088:** Application Version 2.0

Both containers should be running independently.

## Technical Analysis

The first container was created from image version 1.

The second container was created from image version 2.

Rebuilding the source project does not automatically modify an existing container.

Each container retains its own configured image and runtime filesystem environment.

The two host ports allow both Nginx services to be accessed simultaneously.

---

# 32. EXPERIMENT 15 — IMAGE TAGGING

Create an additional tag:

```bash
docker tag week1-portfolio:v2 week1-portfolio:reviewed
```

Verify:

```bash
docker image ls week1-portfolio
```

Inspect the identifiers:

```bash
docker image inspect --format '{{.Id}}' week1-portfolio:v2
```

```bash
docker image inspect --format '{{.Id}}' week1-portfolio:reviewed
```

## Expected Result

Both references identify the same image content.

## Required Analysis

Explain why the creation of an additional tag does not require rebuilding the complete filesystem.

---

# 33. EXPERIMENT 16 — VERIFY REMOVAL AND RECREATION

This experiment examines the relationship between container removal and writable filesystem state.

First, stop the original version 1 container:

```bash
docker stop week1-v1
```

Remove it:

```bash
docker rm week1-v1
```

Create a replacement container from the original version 1 image:

```bash
docker run -d --name week1-recreated -p 127.0.0.1:8087:80 week1-portfolio:v1
```

Check whether the temporary observation file exists:

```bash
docker exec week1-recreated sh -c 'if [ -e /tmp/week1-observation.txt ]; then echo PRESENT; else echo ABSENT; fi'
```

## Expected Result

The output should be:

```text
ABSENT
```

## Technical Interpretation

The original container's writable layer was removed with its container object.

The new container was instantiated from the original image.

It does not inherit the previous container's temporary filesystem modifications.

## Required Analysis

Compare:

- Container restart.
- Container removal.
- Container recreation.
- Image reuse.
- Writable-layer persistence.

---

# 34. EXPERIMENT 17 — FINAL VERIFICATION

Execute:

```bash
docker ps
```

Expected running laboratory containers:

- `week1-recreated`
- `week1-v2`

Verify that the two application versions remain accessible.

Inspect their image references:

```bash
docker inspect --format '{{.Config.Image}}' week1-recreated
```

```bash
docker inspect --format '{{.Config.Image}}' week1-v2
```

Retrieve their logs:

```bash
docker logs --tail 10 week1-recreated
```

```bash
docker logs --tail 10 week1-v2
```

## Required Analysis

Explain why a newly created container can execute from an existing image without requiring the image to be rebuilt.

---

# 35. EXPERIMENT 18 — CONTROLLED CLEANUP

Stop both remaining containers:

```bash
docker stop week1-recreated week1-v2
```

Remove both:

```bash
docker rm week1-recreated week1-v2
```

Verify:

```bash
docker ps -a
```

The project image versions can be retained for future study.

Inspect them:

```bash
docker image ls week1-portfolio
```

The additional `reviewed` tag may be removed when no longer needed:

```bash
docker image rm week1-portfolio:reviewed
```

Do not perform broad image or container pruning on systems containing unrelated workloads.

---

# PART IV — ADVANCED WEEK ONE CONSOLIDATION

# 36. EXTENSION TASK A — HEALTH CHECK CONFIGURATION

This extension revisits the `HEALTHCHECK` instruction studied in Lecture 06.

The objective is to establish a periodic check that evaluates whether the Nginx application responds to an HTTP request.

An example health-check instruction is:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
```

This example requires a compatible `wget` executable within the image.

Students must first verify that the selected image contains the required executable and supports its options.

A successful health-check command returns exit status zero.

Repeated failures can cause the container to be marked unhealthy.

**Required analysis:**

1. Explain the difference between running and healthy states.
2. Describe the significance of health-check exit codes.
3. Explain why a health check does not automatically repair the application.
4. Identify limitations of using only the root webpage as a health indicator.

---

# 37. EXTENSION TASK B — MULTI-STAGE IMAGE CONSTRUCTION

Create an alternative Dockerfile:

`Dockerfile.multistage`

Use:

```dockerfile
# syntax=docker/dockerfile:1

FROM alpine:3.20 AS preparation

RUN mkdir -p /output && \
    printf 'Week One Multi-Stage Build\n' \
    > /output/build-information.txt


FROM nginx:alpine AS runtime

WORKDIR /usr/share/nginx/html

COPY site/ ./

COPY --from=preparation \
     /output/build-information.txt \
     ./build-information.txt

EXPOSE 80
```

Build the image:

```bash
docker build -f Dockerfile.multistage -t week1-portfolio:multistage .
```

Run a temporary container:

```bash
docker run --rm --entrypoint cat week1-portfolio:multistage /usr/share/nginx/html/build-information.txt
```

**Expected output:**

```text
Week One Multi-Stage Build
```

## Required Analysis

1. Identify the preparation stage.
2. Identify the runtime stage.
3. Explain the purpose of `COPY --from`.
4. Explain why the complete preparation-stage filesystem is not automatically incorporated into the final image.
5. Describe how multi-stage builds can separate build tools from runtime dependencies.

---

# 38. EXTENSION TASK C — BUILD REPRODUCIBILITY

Investigate the statement:

**“A Dockerfile guarantees identical image content whenever it is built.”**

The student must evaluate this claim with reference to:

1. Mutable base-image tags.
2. External dependency versions.
3. Processor architecture.
4. Build arguments.
5. Build timestamps and metadata.
6. Build cache behavior.
7. Network-accessible build inputs.

**Expected conclusion:**

A Dockerfile supports repeatable image construction, but complete reproducibility requires sufficient control over all relevant build inputs and conditions.

---

# PART V — TECHNICAL TROUBLESHOOTING EXAMINATION

# 39. TROUBLESHOOTING SCENARIO 1 — CONTAINER NOT RUNNING

A developer executes:

```bash
docker run --name application alpine:3.20 echo "Hello"
```

Afterward:

```bash
docker ps
```

does not display the container.

## Questions

1. Does this necessarily indicate a failure?
2. What command can reveal the stopped container?
3. What determines the container's lifecycle?
4. What exit status would normally indicate successful completion?
5. How could the container be automatically removed after execution?

---

# 40. TROUBLESHOOTING SCENARIO 2 — MISSING APPLICATION FILE

A Dockerfile contains:

```dockerfile
FROM nginx:alpine

COPY website.html /usr/share/nginx/html/index.html
```

The build fails.

The project structure is:

```text
project/
├── Dockerfile
└── site/
    └── website.html
```

## Questions

1. Identify the source-path error.
2. Explain how the build context influences file resolution.
3. Correct the `COPY` instruction.
4. Explain why the destination path is located inside the image filesystem.

---

# 41. TROUBLESHOOTING SCENARIO 3 — PORT CONFLICT

A developer executes:

```bash
docker run -d --name server-one -p 8080:80 nginx:alpine
```

A second command attempts to use the same host port:

```bash
docker run -d --name server-two -p 8080:80 nginx:alpine
```

The second operation fails because the requested port binding is unavailable.

## Questions

1. Explain the cause.
2. Distinguish host ports from container ports.
3. Propose a working port configuration for the second container.
4. Explain why both Nginx containers may continue using internal port 80.

---

# 42. TROUBLESHOOTING SCENARIO 4 — OLD APPLICATION VERSION

A developer modifies `index.html`.

The developer then executes:

```bash
docker build -t website:v2 .
```

However, an existing container continues displaying the old content.

## Questions

1. Explain why the existing container was not updated.
2. Describe the relationship between images and containers.
3. Explain how to start the newly built version.
4. Discuss why versioned images support controlled deployment.

---

# 43. TROUBLESHOOTING SCENARIO 5 — INTERACTIVE SHELL FAILURE

A developer executes:

```bash
docker exec -it application bash
```

Docker reports that the executable is unavailable.

## Questions

1. Does this necessarily indicate a container failure?
2. Why might a minimal image lack Bash?
3. What alternative shell might be available?
4. Explain how image contents determine executable availability.

---

# 44. TROUBLESHOOTING SCENARIO 6 — FILESYSTEM DATA LOSS

A developer creates a file inside a running container.

The developer stops and restarts the same container.

The file remains available.

Later, the developer removes the container and creates a new one from the original image.

The file is absent.

## Questions

1. Explain the behavior using the layered filesystem model.
2. Distinguish stopping from removal.
3. Explain the purpose of a writable container layer.
4. Describe why important application data requires a suitable persistence strategy.

---

# PART VI — FORMAL WEEK ONE EXAMINATION

# 45. EXAMINATION STRUCTURE

The Week One examination evaluates both theoretical knowledge and practical competence.

**Total available marks: 100**

| Assessment component            |   Marks |
| ------------------------------- | ------: |
| Part A — Technical definitions  |      10 |
| Part B — Short-answer questions |      15 |
| Part C — Analytical questions   |      15 |
| Part D — Practical capstone     |      50 |
| Part E — Technical defense      |      10 |
| **Total**                       | **100** |

Recommended passing score: 75/100.

A score of 85/100 or higher indicates strong readiness for the second module.

The scoring thresholds are course assessment recommendations, not externally standardized certification levels.

---

# 46. PART A — TECHNICAL DEFINITIONS

**10 marks — 1 mark per definition**

Provide precise definitions for the following:

1. Docker Engine.
2. Containerization.
3. Docker image.
4. Docker container.
5. Container lifecycle.
6. Dockerfile.
7. Build context.
8. Image tag.
9. Container writable layer.
10. ENTRYPOINT.

Answers must demonstrate correct conceptual distinctions.

---

# 47. PART B — SHORT-ANSWER QUESTIONS

**15 marks — 3 marks per question**

**Question 1.**

Explain the architectural differences between containers and conventional virtual machines.

**Question 2.**

Describe the relationship between the Docker client, Docker daemon, and container runtime.

**Question 3.**

Explain the differences among `docker run`, `docker start`, and `docker exec`.

**Question 4.**

Explain the relationship between image filesystem layers and container writable state.

**Question 5.**

Compare `ARG`, `ENV`, `CMD`, and `ENTRYPOINT` according to their roles in Docker image construction and execution.

---

# 48. PART C — ANALYTICAL QUESTIONS

**15 marks — 5 marks per question**

## Question 1 — Container Lifecycle Analysis

A developer starts an Nginx container, stops it, restarts it, and finally removes it.

Analyze the effects of each operation on:

- Container identity.
- Process execution.
- Writable filesystem state.
- Underlying image content.

## Question 2 — Build Cache Analysis

An application image contains several build operations.

The developer modifies one application source file.

Explain which build operations may be reevaluated and how Dockerfile instruction ordering can improve efficiency.

## Question 3 — Application Versioning

An organization maintains image versions 1.0 and 2.0.

Both versions run simultaneously on separate host ports.

Explain the technical mechanisms that make this possible.

Discuss the significance of immutable image content, container independence, and host port publishing.

---

# 49. PART D — PRACTICAL CAPSTONE ASSESSMENT

**50 marks**

The practical assessment is based on the completed personal portfolio project.

## Category 1 — Application and Project Structure

**10 marks**

Requirements:

- Correct project directory structure.
- Valid HTML files.
- Functional stylesheet.
- JavaScript asset.
- Correct resource references.
- Working navigation.

## Category 2 — Dockerfile and Image Construction

**10 marks**

Requirements:

- Valid Dockerfile.
- Appropriate base image.
- Correct build context.
- Functional `COPY` instructions.
- Correct working directory.
- Image versioning.
- Relevant configuration metadata.

## Category 3 — Container Execution

**10 marks**

Requirements:

- Successful image build.
- Successful container startup.
- Correct host port mapping.
- Accessible webpage.
- Functional navigation.
- Successful start/stop/restart operations.

## Category 4 — Inspection and Diagnostics

**10 marks**

Requirements:

- Container status inspection.
- Log inspection.
- Process inspection.
- Filesystem exploration.
- Image metadata inspection.
- Resource observation.
- Writable-layer investigation.

## Category 5 — Image Rebuilding and Version Management

**10 marks**

Requirements:

- Modification of the application.
- Construction of version 2.
- Separate image references.
- Two concurrently running application versions.
- Verification of version independence.
- Correct explanation of image and container relationships.

---

# 50. PART E — TECHNICAL DEFENSE

**10 marks**

The student must explain and defend the following decisions.

1. Why was Nginx selected as the base image?
2. Why is the Dockerfile necessary?
3. Why are website files copied during construction?
4. Why is the `EXPOSE` instruction not sufficient for host access?
5. Why does an image rebuild not update an existing container?
6. Why do the two application versions have different host ports?
7. Why can the same image create multiple containers?
8. Why does the temporary file survive restart but not removal?
9. Why is image tagging important?
10. What limitations would need to be addressed before treating this project as a production deployment?

A successful technical defense must demonstrate causal understanding rather than memorized command descriptions.

---

# PART VII — EVALUATION AND ACADEMIC CONCLUSION

# 51. PRACTICAL COMPLETION CHECKLIST

The following checklist should be completed before the Week One module is considered finished.

## Docker Fundamentals

- [ ] I can define Docker.
- [ ] I understand containerization.
- [ ] I can distinguish containers and virtual machines.
- [ ] I understand the Docker client-server architecture.
- [ ] I can explain the roles of namespaces and cgroups.

## Container Management

- [ ] I can create a container.
- [ ] I can start and stop containers.
- [ ] I can restart existing containers.
- [ ] I can list running and stopped containers.
- [ ] I understand detached execution.
- [ ] I understand interactive execution.
- [ ] I can explain the principal process and container termination.

## Container Inspection

- [ ] I can execute commands inside containers.
- [ ] I can examine container filesystems.
- [ ] I can retrieve container logs.
- [ ] I can inspect process information.
- [ ] I can inspect Docker metadata.
- [ ] I can copy files to or from containers.
- [ ] I understand writable-layer behavior.

## Image Management

- [ ] I can retrieve images.
- [ ] I can list images.
- [ ] I can inspect image metadata.
- [ ] I can examine image history.
- [ ] I understand image tags and identifiers.
- [ ] I can create new image tags.
- [ ] I understand the role of image registries.

## Dockerfile Construction

- [ ] I can write a Dockerfile.
- [ ] I understand build contexts.
- [ ] I can use `FROM`.
- [ ] I can use `WORKDIR`.
- [ ] I can use `COPY`.
- [ ] I can use `RUN`.
- [ ] I understand `CMD`.
- [ ] I understand `ENTRYPOINT`.
- [ ] I can explain `ARG` and `ENV`.
- [ ] I can configure `.dockerignore`.
- [ ] I understand basic build caching.

## Practical Application

- [ ] I created the personal portfolio project.
- [ ] I built the first image.
- [ ] I ran the application.
- [ ] I accessed it through a browser.
- [ ] I inspected the running container.
- [ ] I modified the source code.
- [ ] I built a second image version.
- [ ] I ran both versions simultaneously.
- [ ] I investigated filesystem persistence.
- [ ] I completed the laboratory report.
- [ ] I completed the theoretical examination.

---

# 52. LABORATORY REPORT REQUIREMENTS

Prepare a formal report containing the following sections.

## 52.1 Introduction

Describe the purpose of the practical project and its relationship to the first module of the course.

Recommended length: 150–200 words.

## 52.2 System Architecture

Explain the relationship among:

- Application files.
- Dockerfile.
- Build context.
- Base image.
- Custom image.
- Docker container.
- Nginx process.
- Published port.
- Web browser.

Include one architectural diagram.

## 52.3 Implementation Methodology

Describe the procedure used to create and build the project.

Explain the function of each major Dockerfile instruction.

## 52.4 Experimental Results

Present evidence of:

1. Successful image construction.
2. Running container.
3. Accessible application.
4. Correct file placement.
5. Container log output.
6. Image version comparison.
7. Successful runtime inspection.

## 52.5 Technical Analysis

Discuss the relationships among images, containers, and runtime state.

Explain the significance of build cache reuse and image versioning.

## 52.6 Problems Encountered

Document any build or execution failures.

For each problem, record:

- Observed symptom.
- Suspected cause.
- Diagnostic procedure.
- Corrective action.
- Final result.

## 52.7 Conclusion

Evaluate whether the project fulfilled its technical objectives.

Recommended conclusion length: 250–350 words.

---

# 53. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Integration of Docker Fundamentals in a Containerized Web Application

Prepare a report of approximately 1,200–1,800 words addressing:

**“From Containerization Theory to Practical Deployment: A Technical Evaluation of Docker Image Construction, Container Execution, and Application Version Management.”**

The report must contain:

1. Introduction to Docker's role in software deployment.
2. Explanation of operating-system-level containerization.
3. Analysis of Docker architecture.
4. Description of container lifecycle management.
5. Explanation of images and layered filesystems.
6. Technical description of Dockerfile construction.
7. Analysis of build-time and runtime configuration.
8. Explanation of the implemented personal website.
9. Evaluation of container port publishing.
10. Explanation of filesystem inspection and runtime diagnostics.
11. Analysis of image rebuilding and version management.
12. Discussion of basic security considerations.
13. Discussion of current project limitations.
14. Conclusion identifying the foundational Docker competencies acquired.

The report should contain appropriate command examples and relevant technical references.

---

# 54. WEEK ONE COMPETENCY STANDARD

At the conclusion of the first module, a student should possess the following capabilities.

## Theoretical Competence

The student can explain how Docker uses containerization technologies to execute isolated application processes.

The student understands the distinctions among images, containers, Dockerfiles, and registries.

The student can explain why image construction and container execution are separate activities.

## Operational Competence

The student can manage basic Docker objects through the command-line interface.

The student can inspect application processes, logs, metadata, and filesystem state.

The student can identify common build and runtime failures.

## Development Competence

The student can package a simple application into a custom Docker image.

The student can construct and tag image versions.

The student can run application containers and publish their services through host network ports.

## Analytical Competence

The student can explain the effects of container restarting, removal, and recreation.

The student can distinguish runtime modifications from image changes.

The student can analyze image-building behavior and basic build-cache decisions.

## Security Awareness

The student understands that container isolation does not establish complete security.

The student recognizes the importance of selecting appropriate base images, restricting unnecessary permissions, and avoiding confidential information in image layers.

---

# 55. PREPARATION FOR MODULE TWO

The second module introduces Docker networking, storage, and multi-container application management.

These topics extend the capabilities developed during the first module.

The first module focuses primarily on packaging and operating an individual containerized application.

The second module will examine how multiple containers exchange information and how applications preserve data independently of individual container lifecycles.

The transition is represented as:

```text
MODULE ONE: Fundamental Containerization → Custom Images
Custom Images → Running Containers
Running Containers → Container Inspection
Container Inspection → MODULE TWO: Multi-Container Systems
MODULE TWO: Multi-Container Systems → Networking
MODULE TWO: Multi-Container Systems → Storage
MODULE TWO: Multi-Container Systems → Compose
Networking → Complete Applications
Storage → Complete Applications
Compose → Complete Applications
```

**Upcoming topics:**

**Lecture 08:** Docker Ports, Environment Variables, and Application Configuration.

**Lecture 09:** Docker Volumes, Bind Mounts, and Persistent Storage.

**Lecture 10:** Docker Networking Architecture and Container Communication.

**Lecture 11:** Introduction to Docker Compose.

**Lecture 12:** Multi-Container Application Construction.

**Lecture 13:** Advanced Docker Compose Configuration.

**Lecture 14:** Week Two Comprehensive Review and Practical Project.

---

# 56. LECTURE SUMMARY

The first six lectures introduced the fundamental technologies and management operations associated with Docker containerization.

Lecture 07 integrates those concepts through the construction and administration of a complete containerized web application.

The project demonstrates how application source files are transformed into a custom Docker image through a Dockerfile-based build process.

The constructed image provides the filesystem content and execution configuration necessary for Docker to instantiate an Nginx container.

The running container exposes a web service through a published host port.

Administrative commands allow the developer to inspect container state, processes, logs, filesystem content, and associated metadata.

The project also demonstrates the distinction between container-specific writable state and immutable image content.

Temporary modifications associated with a container can survive ordinary restart operations but are not automatically inherited by a replacement container created from the original image.

Image versioning enables separate versions of an application to be constructed, identified, and executed independently.

Docker build caching can reduce unnecessary reconstruction work when unchanged operations remain eligible for reuse.

The theoretical examination and practical assessment evaluate whether the student understands these mechanisms as an integrated system.

A fundamental conclusion of this lecture is that **effective Docker competence requires the ability to connect operating-system concepts, image construction, container lifecycle management, networking configuration, and runtime diagnostics into a coherent application deployment workflow.**

---

# 57. REFERENCES AND RECOMMENDED READING

## Primary References

[1] Docker Inc. _Docker Overview._  
https://docs.docker.com/get-started/docker-overview/

[2] Docker Inc. _Docker Concepts._  
https://docs.docker.com/get-started/docker-concepts/

[3] Docker Inc. _Dockerfile Reference._  
https://docs.docker.com/reference/dockerfile/

[4] Docker Inc. _Docker Container Run._  
https://docs.docker.com/reference/cli/docker/container/run/

[5] Docker Inc. _Docker Container Exec._  
https://docs.docker.com/reference/cli/docker/container/exec/

[6] Docker Inc. _Docker Container Inspect._  
https://docs.docker.com/reference/cli/docker/container/inspect/

[7] Docker Inc. _Docker Image Build._  
https://docs.docker.com/reference/cli/docker/image/build/

[8] Docker Inc. _Docker Image Inspect._  
https://docs.docker.com/reference/cli/docker/image/inspect/

[9] Docker Inc. _Docker Image History._  
https://docs.docker.com/reference/cli/docker/image/history/

[10] Docker Inc. _Build Cache._  
https://docs.docker.com/build/cache/

[11] Docker Inc. _Build Cache Invalidation._  
https://docs.docker.com/build/cache/invalidation/

[12] Docker Inc. _Port Publishing and Mapping._  
https://docs.docker.com/engine/network/port-publishing/

[13] Docker Inc. _Docker Storage._  
https://docs.docker.com/engine/storage/

[14] Docker Inc. _Build Best Practices._  
https://docs.docker.com/build/building/best-practices/

[15] Docker Inc. _Multi-Stage Builds._  
https://docs.docker.com/build/building/multi-stage/

## Recommended Reading Sequence

Review references [1], [2], and [3] to consolidate Docker architecture and image-construction knowledge.

Continue with references [4] through [9] to review container and image administration.

References [10] and [11] provide additional depth on build-cache behavior.

Reference [12] explains the networking principles used in the capstone project.

References [13], [14], and [15] provide the foundation for more advanced work.

---

# 58. FINAL MODULE CONCLUSION

The successful completion of Week One demonstrates foundational competence in Docker containerization.

The student has progressed from an initial understanding of Docker architecture to the construction and execution of application-specific container images.

This progression requires knowledge of operating-system isolation, application processes, layered filesystems, Docker image architecture, runtime configuration, and command-line management.

The capstone project provides practical evidence that these concepts can be applied together.

A properly constructed Docker image can package an application and its supporting runtime environment.

A Docker container can instantiate that image within an isolated execution environment.

Docker networking mechanisms can expose the application's services to the host.

Inspection commands can provide evidence about processes, application files, configuration, and operational state.

Versioned images allow application changes to be managed without automatically changing existing container instances.

These capabilities represent essential prerequisites for developing and operating more complex containerized systems.

However, the completion of this module does not establish expertise in persistent storage, advanced networking, orchestration, production security, or distributed application management.

Those subjects require additional study.

The next module will extend the foundational single-container model toward interconnected and stateful application systems.

---

**END OF LECTURE 07**

**END OF MODULE 01 — DOCKER FUNDAMENTALS**

**Next Lecture:** Lecture 08 — Docker Ports, Environment Variables, and Application Configuration.
