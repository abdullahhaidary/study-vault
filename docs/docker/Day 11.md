# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 11 — INTRODUCTION TO DOCKER COMPOSE: DECLARATIVE MULTI-CONTAINER CONFIGURATION, YAML STRUCTURE, SERVICES, NETWORKS, VOLUMES, AND APPLICATION LIFECYCLE MANAGEMENT

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 11 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Lecture 01 — Docker Architecture and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Runtime Inspection and Diagnostics.
- Lecture 04 — Docker Images and Registries.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Instructions.
- Lecture 07 — Week One Comprehensive Review.
- Lecture 08 — Port Publishing and Environment Variables.
- Lecture 09 — Docker Storage and Persistent Volumes.
- Lecture 10 — Docker Networking and Service Discovery.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define Docker Compose and describe its role in containerized application management.
2. Explain the limitations of manually managing complex applications using separate Docker CLI commands.
3. Distinguish imperative container management from declarative application configuration.
4. Explain the architecture and execution model of Docker Compose.
5. Describe the Compose Specification and its purpose.
6. Identify the modern Docker Compose command syntax.
7. Distinguish `docker compose` from the historical `docker-compose` command.
8. Identify the conventional Compose configuration filenames.
9. Explain the syntax and structure of YAML.
10. Distinguish YAML mappings, sequences, and scalar values.
11. Identify the principal top-level elements of a Compose file.
12. Define a Compose project.
13. Define a Compose service.
14. Explain the relationship between a Compose service and its container instances.
15. Configure services using existing Docker images.
16. Explain the purpose of the `image`, `build`, `command`, and `entrypoint` attributes.
17. Define host port mappings through a Compose file.
18. Configure container environment variables.
19. Distinguish Compose variable interpolation from container environment injection.
20. Explain the purpose of the Compose `.env` file.
21. Declare Docker networks within a Compose project.
22. Explain automatic network creation and DNS-based service discovery.
23. Declare named volumes for persistent application storage.
24. Configure bind mounts for application development.
25. Explain the purpose and limitations of `depends_on`.
26. Validate a Compose file before deployment.
27. Start and stop a multi-container application.
28. Inspect services and containers belonging to a Compose project.
29. Retrieve application logs through Compose.
30. Execute diagnostic commands inside managed containers.
31. Distinguish `docker compose exec` from `docker compose run`.
32. Explain the differences among `stop`, `start`, `restart`, `up`, and `down`.
33. Describe how Compose responds to changes in service configuration.
34. Explain the effects of `docker compose down` on networks, containers, and volumes.
35. Construct a functioning Nginx-and-Redis Compose application.
36. Demonstrate data persistence across complete application teardown and recreation.
37. Investigate networking, YAML, and configuration errors.
38. Apply fundamental Compose security and maintenance practices.

---

# 2. INTRODUCTION TO DOCKER COMPOSE

## 2.1 Background

The preceding lectures demonstrated how Docker containers can be managed through individual commands.

For example, a developer may create a network:

```bash
docker network create application-network
```

Create a volume:

```bash
docker volume create application-data
```

Start a Redis database:

```bash
docker run -d \
  --name application-redis \
  --network application-network \
  -v application-data:/data \
  redis:7-alpine \
  redis-server --appendonly yes
```

Then start a web server:

```bash
docker run -d \
  --name application-web \
  --network application-network \
  -p 127.0.0.1:8080:80 \
  nginx:alpine
```

These operations demonstrate important Docker capabilities.

However, a multi-container application may contain many services, networks, volumes, environment variables, and other configuration parameters.

Managing each element manually introduces operational complexity.

The administrator must remember:

- Which images are required.
- Which containers belong to the application.
- Which networks they use.
- Which ports must be published.
- Which volumes contain persistent data.
- Which environment variables must be supplied.
- Which services depend on one another.
- How the application should be started and stopped.
- How the environment should be reconstructed.

Docker Compose provides a mechanism for recording and managing these relationships in a structured application definition.

## 2.2 Definition

**Docker Compose is a tool for defining and managing multi-container applications through a declarative configuration model.**

Its configuration commonly describes:

1. Services.
2. Container images.
3. Build specifications.
4. Networks.
5. Volumes.
6. Environment variables.
7. Port mappings.
8. Mounts.
9. Dependencies.
10. Additional runtime configuration.

The application is normally described in a YAML file.

Compose interprets that file and coordinates the necessary Docker Engine operations.

## 2.3 Academic Definition

Docker Compose is a declarative application composition and lifecycle-management system that transforms a structured specification of services and supporting resources into Docker-managed containers, networks, volumes, and related runtime configuration.

It simplifies application deployment by expressing the required infrastructure as a model rather than as an unrelated sequence of individual shell commands.

---

# 3. IMPERATIVE VERSUS DECLARATIVE MANAGEMENT

## 3.1 Imperative Management

An imperative management approach specifies the sequence of operations that a system should perform.

Examples include:

```bash
docker network create academic-network
```

```bash
docker volume create academic-data
```

```bash
docker run -d --name academic-redis --network academic-network redis:7-alpine
```

In this approach, the administrator explicitly submits each operation.

The commands describe what actions should occur.

## 3.2 Declarative Management

A declarative approach describes the desired configuration of a system.

For example:

```yaml
services:
  redis:
    image: redis:7-alpine
```

The configuration specifies that the application contains a Redis service.

Compose determines the required Docker operations to establish the configuration.

## 3.3 Comparison

| Characteristic | Imperative approach | Declarative approach |
|---|---|---|
| Main representation | Individual commands | Structured configuration |
| Focus | Actions to perform | Desired application configuration |
| Repetition | Often requires repeating commands | Configuration can be reused |
| Application structure | Distributed across commands | Centralized in a project model |
| Version control | Possible through scripts | Natural fit for configuration files |
| Resource relationships | Manually coordinated | Defined as part of the model |
| Reconstruction | Requires preserving procedures | Uses the application specification |

## 3.4 Important Qualification

Declarative configuration does not eliminate imperative operations.

Commands such as:

```bash
docker compose up
```

and:

```bash
docker compose down
```

remain imperative requests.

The distinction is that these commands operate on a previously declared application model.

## 3.5 Engineering Significance

Declarative application configuration improves consistency by making important infrastructure relationships explicit and reviewable.

This is a foundational idea in modern infrastructure management.

---

# 4. DOCKER COMPOSE ARCHITECTURE

## 4.1 Principal Components

Docker Compose operates through several related elements.

**Compose CLI**

Interprets Compose commands submitted by the user.

**Compose configuration file**

Describes the application's services and supporting resources.

**Docker Engine**

Creates and manages the required containers, networks, volumes, and images.

**Compose project**

Provides a logical identity and resource grouping for the application.

## 4.2 Logical Architecture

```text
                   DEVELOPER
                       |
                       v
              DOCKER COMPOSE CLI
                       |
                       v
                 compose.yaml
                       |
                       v
             COMPOSE APPLICATION
                    MODEL
                       |
                       v
                  DOCKER ENGINE
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
     SERVICES        NETWORKS       VOLUMES
        |
        v
     CONTAINERS
        |
        v
     APPLICATION
      PROCESSES
```

## 4.3 Compose and Docker Engine

Docker Compose does not replace Docker Engine.

It uses Docker Engine to perform the required container-management operations.

The resulting containers are ordinary Docker containers.

Therefore, they can still be examined using commands such as:

```bash
docker ps
docker inspect
docker logs
```

Compose provides a higher-level organizational and management interface.

## 4.4 Compose Is Not a Complete Orchestration Platform

Compose is particularly useful for:

- Local development.
- Testing.
- Multi-service demonstrations.
- Single-host application deployments.
- Reproducible training environments.
- Selected production workloads.

However, basic Docker Compose should not be confused with a distributed container orchestrator.

Capabilities such as automated multi-node scheduling, cluster-wide service recovery, and advanced traffic routing require additional infrastructure.

---

# 5. MODERN DOCKER COMPOSE

## 5.1 Docker Compose V2

Modern Docker installations ordinarily provide Compose through the Docker CLI plugin architecture.

The principal command syntax is:

```bash
docker compose
```

The command consists of two words.

## 5.2 Historical Syntax

Older Docker Compose installations used:

```bash
docker-compose
```

This was commonly associated with the original standalone Compose implementation.

Current course examples use:

```bash
docker compose
```

## 5.3 Verifying Installation

Execute:

```bash
docker compose version
```

The command displays the installed Compose version.

## 5.4 Relationship to Docker Desktop

Docker Desktop commonly includes Docker Compose.

Linux Docker Engine installations may require the Compose plugin to be installed separately, depending on the installation method.

The required capability is the availability of a compatible modern Compose implementation.

---

# 6. THE COMPOSE SPECIFICATION

## 6.1 Definition

The Compose Specification defines a platform-neutral model for describing multi-container applications.

It specifies the structure and meaning of Compose configuration elements.

## 6.2 Principal Configuration Categories

The specification supports resources such as:

- Services.
- Networks.
- Volumes.
- Configurations.
- Secrets.

Individual service definitions also support many runtime attributes.

## 6.3 Modern Compose Files

Modern Compose follows the Compose Specification.

A top-level field such as:

```yaml
version: "3.8"
```

is no longer required.

In current Compose implementations, the top-level `version` attribute is obsolete and may generate a warning.

It does not select a separate legacy schema in the way older tutorials sometimes suggest.

## 6.4 Recommended Practice

Use the current Compose Specification and omit the obsolete top-level `version` attribute in newly created configurations.

---

# 7. COMPOSE CONFIGURATION FILES

## 7.1 Conventional Filenames

Common configuration filenames include:

```text
compose.yaml
compose.yml
docker-compose.yaml
docker-compose.yml
```

For a new project, the recommended conventional filename is:

```text
compose.yaml
```

## 7.2 Project Directory

A typical Compose project may contain:

```text
academic-project/
├── compose.yaml
├── .env
├── site/
│   └── index.html
└── documentation/
    └── laboratory-notes.md
```

The Compose file describes the application.

The remaining files may provide source content, runtime configuration, and documentation.

## 7.3 Automatic File Discovery

When executed from a suitable project directory, Compose can locate a conventional configuration file without requiring its filename to be specified explicitly.

Example:

```bash
docker compose up -d
```

## 7.4 Explicit File Selection

A different file can be selected using:

```bash
docker compose -f custom-compose.yaml up -d
```

The `-f` option identifies the Compose configuration to use.

Multiple Compose files and overrides will be examined in a later lecture.

---

# 8. INTRODUCTION TO YAML

## 8.1 Definition

YAML is a human-readable data serialization language frequently used for configuration.

Its syntax represents structured information using mappings, sequences, and scalar values.

Compose uses YAML to express application configuration.

## 8.2 Mappings

A mapping associates keys with values.

Example:

```yaml
application:
  name: academic-service
  environment: development
```

The `application` key contains a nested mapping.

The nested mapping contains the keys `name` and `environment`.

## 8.3 Sequences

A sequence represents an ordered collection.

Example:

```yaml
services:
  - web
  - redis
  - database
```

The hyphen marks sequence entries.

## 8.4 Nested Structures

YAML combines mappings and sequences.

Example:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
```

The top-level `services` key contains a mapping.

The `web` key identifies a service definition.

The `ports` key contains a sequence.

## 8.5 Indentation

YAML uses indentation to represent structure.

Example:

```yaml
services:
  web:
    image: nginx:alpine
```

The indentation indicates that `web` is located under `services` and that `image` belongs to the `web` service.

## 8.6 Important Syntax Rules

- Use spaces consistently for indentation.
- Do not use tab characters for structural indentation.
- Preserve the correct nesting of keys.
- Use quotation marks when they improve clarity.
- Do not assume every YAML scalar is interpreted as a string.
- Validate configuration before deployment.

## 8.7 Quoting Values

A port mapping is commonly written as:

```yaml
ports:
  - "8080:80"
```

Quoting makes the value clearly represent a string.

Similarly, environment variable values that resemble numbers or Boolean values can be quoted.

Example:

```yaml
environment:
  DEBUG: "false"
  APPLICATION_VERSION: "2.0"
```

---

# 9. THE STRUCTURE OF A COMPOSE FILE

## 9.1 Principal Elements

A basic Compose file may contain:

```yaml
name: academic-application

services:
  web:
    image: nginx:alpine

networks:
  application-network:

volumes:
  application-data:
```

These are top-level elements.

## 9.2 name

The `name` element establishes a default project name.

## 9.3 services

The `services` element defines the application's executable components.

## 9.4 networks

The `networks` element defines managed networks used by services.

## 9.5 volumes

The `volumes` element declares persistent storage resources.

## 9.6 Other Elements

Compose also supports additional top-level elements, including `configs` and `secrets`.

These will be examined in more advanced configuration and security contexts.

---

# 10. COMPOSE PROJECTS

## 10.1 Definition

A Compose project is a logical grouping of services, networks, volumes, and other resources associated with one application definition.

**Formal definition:**

A Compose project is an identified application configuration whose declared resources are managed collectively through the Compose lifecycle interface.

## 10.2 Project Name

A project can be named using:

```yaml
name: lecture11-course
```

Compose uses the project name when identifying and organizing managed resources.

## 10.3 Resource Names

Suppose the project name is:

```text
lecture11-course
```

A service named `web` may receive a container name similar to:

```text
lecture11-course-web-1
```

A network named `app-net` may receive a Docker network name similar to:

```text
lecture11-course_app-net
```

A volume named `redis-data` may receive a Docker volume name similar to:

```text
lecture11-course_redis-data
```

The exact names should be confirmed through Docker inspection rather than inferred for every possible configuration.

## 10.4 Project Isolation

Compose uses project identity to distinguish resources belonging to different applications.

This allows two separate projects to define services with identical logical names without necessarily creating identical Docker resource names.

## 10.5 Project Name Overrides

The project name may also be selected using Compose CLI options and supported environment configuration.

Example:

```bash
docker compose -p alternate-project up -d
```

The `-p` option selects an explicit project identity.

---

# 11. COMPOSE SERVICES

## 11.1 Definition

A service is a logical application component defined in a Compose configuration.

A service describes how one or more corresponding containers should be created and operated.

## 11.2 Example

```yaml
services:
  web:
    image: nginx:alpine
```

This configuration defines a service named:

```text
web
```

The service uses the image:

```text
nginx:alpine
```

## 11.3 Service Versus Container

A Compose service is a logical specification.

A Docker container is a runtime instance.

A service may be represented by one or more containers, depending on its configuration and supported scaling arrangements.

## 11.4 Conceptual Model

```text
             COMPOSE SERVICE
                   |
                   v
            SERVICE DEFINITION
                   |
          +--------+--------+
          |                 |
          v                 v
      CONTAINER 1       CONTAINER 2
```

This distinction becomes important in later discussions of scaling and replicated services.

## 11.5 Service Names and DNS

Services connected to an appropriate Compose network are ordinarily discoverable through their service names.

For example:

```text
web
redis
```

can function as DNS names within the relevant application network.

---

# 12. THE image ATTRIBUTE

## 12.1 Definition

The `image` attribute identifies the container image associated with a service.

Example:

```yaml
services:
  redis:
    image: redis:7-alpine
```

## 12.2 Image Retrieval

If a required image is unavailable locally, Compose may retrieve it according to the applicable image-pull policy.

## 12.3 Image Versioning

Explicit image tags improve clarity.

Example:

```yaml
image: redis:7-alpine
```

is more specific than:

```yaml
image: redis:latest
```

However, version tags may still be mutable.

Exact reproducibility requires additional control over image references and other build inputs.

---

# 13. THE build ATTRIBUTE

## 13.1 Definition

The `build` attribute defines how Compose should construct an image from a build context.

Example:

```yaml
services:
  application:
    build: .
```

The period identifies the current project context according to Compose path-resolution rules.

## 13.2 Build Configuration

A more explicit representation is:

```yaml
services:
  application:
    build:
      context: .
      dockerfile: Dockerfile
```

This specifies:

- The build context.
- The Dockerfile path.

## 13.3 The image and build Attributes Together

A service may define both a build specification and an image reference.

Example:

```yaml
services:
  application:
    build: .
    image: academic-application:v1
```

The image reference can identify the image produced by the build.

The exact pull-versus-build behavior also depends on Compose's applicable policies and command options.

## 13.4 Building Explicitly

Execute:

```bash
docker compose build
```

This builds services with build definitions.

## 13.5 Build Before Startup

Execute:

```bash
docker compose up --build
```

This requests that applicable images be built before starting services.

**Important distinction:** A service that specifies only an existing image reference and no build definition does not acquire a new Dockerfile build merely because `--build` is supplied.

---

# 14. THE ports ATTRIBUTE

## 14.1 Definition

The `ports` attribute defines host-to-container port publishing.

Example:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
```

This maps host port 8080 to container port 80 using the default TCP protocol.

## 14.2 Loopback Binding

For local development:

```yaml
ports:
  - "127.0.0.1:8211:80"
```

This requests publication through the Docker host's IPv4 loopback interface.

## 14.3 Multiple Ports

```yaml
ports:
  - "8080:80"
  - "8443:443"
```

This defines two host-to-container mappings.

## 14.4 Short and Long Syntax

Compose supports a compact syntax:

```yaml
ports:
  - "127.0.0.1:8211:80"
```

It also supports a structured long syntax:

```yaml
ports:
  - target: 80
    published: "8211"
    host_ip: 127.0.0.1
    protocol: tcp
```

## 14.5 Important Principle

The `ports` attribute publishes a service through the host.

Services communicating directly over a shared Compose network ordinarily use internal container ports instead.

---

# 15. THE environment ATTRIBUTE

## 15.1 Definition

The `environment` attribute supplies environment variables to a service container.

Example:

```yaml
services:
  application:
    image: alpine:3.20
    environment:
      APP_MODE: development
```

## 15.2 Mapping Syntax

```yaml
environment:
  APP_NAME: "Academic Application"
  APP_MODE: development
```

## 15.3 List Syntax

```yaml
environment:
  - APP_NAME=Academic Application
  - APP_MODE=development
```

Both forms are supported.

## 15.4 Purpose

Environment variables are commonly used to configure:

- Application environments.
- Logging levels.
- Service hostnames.
- Service ports.
- Feature selection.
- Runtime paths.

## 15.5 Application Responsibility

Setting an environment variable does not automatically make an application use it.

The application must be designed to read the relevant variable.

For example, setting:

```text
COURSE_MODULE=02
```

inside an Nginx container does not automatically insert that text into HTML pages.

The variable is part of the process environment, not a general website templating mechanism.

---

# 16. THE .env FILE AND VARIABLE INTERPOLATION

## 16.1 Definition

Docker Compose can use an `.env` file to provide values for interpolation into the Compose model.

## 16.2 Example

Create:

```text
.env
```

with:

```text
WEB_PORT=8211
```

Then reference it:

```yaml
ports:
  - "127.0.0.1:${WEB_PORT}:80"
```

Compose substitutes the configured value while resolving the application model.

## 16.3 Default Values

Compose also supports default expressions.

Example:

```yaml
ports:
  - "127.0.0.1:${WEB_PORT:-8211}:80"
```

If `WEB_PORT` is unset or empty, Compose uses the fallback value `8211`.

## 16.4 Interpolation Versus Container Environment

A variable in `.env` is not automatically injected into every container.

For example:

```text
WEB_PORT=8211
```

may be used by Compose to determine a host port mapping.

The value does not automatically appear inside the Nginx process environment unless it is explicitly supplied through a relevant service configuration.

## 16.5 Environment File Attribute

Compose also supports:

```yaml
env_file:
  - ./application.env
```

This loads variables into the associated service container's environment.

## 16.6 Fundamental Distinction

| Mechanism | Primary purpose |
|---|---|
| Project `.env` | Supplies Compose interpolation values |
| Service `environment` | Supplies container environment variables |
| Service `env_file` | Loads container environment variables from a file |
| `docker compose --env-file` | Selects a file used for Compose interpolation |

These mechanisms can interact, but they are not equivalent.

Full environment precedence will be studied in Lecture 13.

---

# 17. THE volumes ATTRIBUTE

## 17.1 Definition

The service-level `volumes` attribute declares filesystem mounts for a container.

These mounts may include:

- Named volumes.
- Bind mounts.
- Other supported mount types.

## 17.2 Named Volume Example

```yaml
services:
  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```

The service receives a Docker-managed volume mounted at `/data`.

## 17.3 Bind Mount Example

```yaml
services:
  web:
    image: nginx:alpine
    volumes:
      - ./site:/usr/share/nginx/html:ro
```

The local `site` directory is mounted into the container read-only.

## 17.4 Important Distinction

The top-level `volumes` section declares named volume resources.

The `volumes` entry inside a service describes how the service uses mounted storage.

These elements serve different purposes.

## 17.5 Persistence

Named volumes are normally preserved by:

```bash
docker compose down
```

They are generally removed when the appropriate destructive volume-removal option is used.

This distinction is essential for stateful services.

---

# 18. THE networks ATTRIBUTE

## 18.1 Definition

The service-level `networks` attribute identifies the networks a service should join.

Example:

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - app-net

networks:
  app-net:
    driver: bridge
```

## 18.2 Automatic Network Creation

Compose can create the declared network during application startup.

## 18.3 Default Network

If no network configuration is specified, Compose ordinarily creates a default network for the project.

Services join this network and can discover one another by service name.

## 18.4 Explicit Networks

An explicit network definition is useful when:

- Separating groups of services.
- Controlling network membership.
- Configuring driver-specific behavior.
- Documenting application topology.

## 18.5 Internal Communication

A service named `redis` attached to the same network as another service can ordinarily be reached through:

```text
redis:6379
```

No host port publishing is required for this internal communication.

---

# 19. THE command ATTRIBUTE

## 19.1 Definition

The `command` attribute overrides a container image's default `CMD` configuration.

Example:

```yaml
services:
  redis:
    image: redis:7-alpine
    command:
      - redis-server
      - --appendonly
      - "yes"
```

## 19.2 Purpose

The attribute can define application-specific startup arguments.

## 19.3 Important Distinction

The `command` attribute is not equivalent to the `entrypoint` attribute.

Its behavior depends on the image's entrypoint configuration.

The interaction follows the Docker command-resolution principles studied in Lecture 06.

---

# 20. THE entrypoint ATTRIBUTE

## 20.1 Definition

The `entrypoint` attribute overrides the image's entrypoint configuration.

Example:

```yaml
services:
  tool:
    image: alpine:3.20
    entrypoint:
      - /bin/sh
```

## 20.2 Significance

The entrypoint determines the principal executable behavior for the service.

Changing it may bypass initialization logic inherited from the image.

## 20.3 Recommended Practice

Only override a service's entrypoint when the intended application behavior is understood.

Do not replace an image's startup process merely to work around an unrelated configuration error.

---

# 21. THE depends_on ATTRIBUTE

## 21.1 Definition

The `depends_on` attribute expresses startup and shutdown ordering relationships between services.

Example:

```yaml
services:
  api:
    image: example-api
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
```

## 21.2 Short Syntax Behavior

With short syntax, Compose ensures that the dependency service is started before the dependent service.

## 21.3 Important Limitation

Starting a service is not equivalent to confirming that the service is ready to accept application requests.

For example, a database may require initialization after its container starts.

The short form of `depends_on` does not ordinarily wait until the application has become healthy.

## 21.4 Health-Aware Dependencies

Compose also supports dependency conditions associated with health checks.

Example:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

This requires an appropriate health check to be configured for the dependency.

Health-aware startup and recovery behavior will be examined in Lecture 13.

## 21.5 Application Resilience

Even when dependencies are checked during startup, applications should handle temporary connection failures and interruptions.

Dependency ordering is not a substitute for application-level error handling.

---

# 22. THE COMPOSE APPLICATION LIFECYCLE

## 22.1 Overview

Compose provides commands for creating, starting, inspecting, stopping, and removing applications.

The fundamental operations include:

```text
config
pull
build
up
ps
logs
exec
run
stop
start
restart
down
```

## 22.2 Lifecycle Model

```text
              COMPOSE FILE
                   |
                   v
            CONFIG VALIDATION
                   |
                   v
             docker compose up
                   |
                   v
          SERVICES AND RESOURCES
                   |
                   v
            RUNNING CONTAINERS
                   |
          +--------+--------+
          |                 |
          v                 v
        INSPECT            LOGS
          |                 |
          +--------+--------+
                   |
                   v
            docker compose stop
                   |
                   v
             STOPPED SERVICES
                   |
                   v
           docker compose start
                   |
                   v
             RUNNING SERVICES
                   |
                   v
            docker compose down
                   |
                   v
         CONTAINERS AND NETWORKS
                 REMOVED
```

Named volumes are normally retained by `down` unless the appropriate removal option is supplied.

---

# 23. THE docker compose config COMMAND

## 23.1 Definition

The `docker compose config` command parses, resolves, validates, and renders a Compose application model.

## 23.2 Basic Command

```bash
docker compose config
```

This displays the resolved application configuration.

## 23.3 Validation Only

```bash
docker compose config -q
```

The quiet option validates the configuration without printing the rendered model.

A successful validation normally produces no output and returns a successful exit status.

## 23.4 List Services

```bash
docker compose config --services
```

## 23.5 List Networks

```bash
docker compose config --networks
```

## 23.6 List Volumes

```bash
docker compose config --volumes
```

## 23.7 Significance

Configuration validation should be performed before creating application resources.

However, syntactic and structural validation does not guarantee that:

- Required images exist.
- Host ports are available.
- Mount permissions are correct.
- Application processes can start.
- Dependencies are healthy.

---

# 24. THE docker compose up COMMAND

## 24.1 Definition

The `docker compose up` command creates and starts services and required project resources.

## 24.2 Foreground Execution

```bash
docker compose up
```

This normally attaches to application output.

## 24.3 Detached Execution

```bash
docker compose up -d
```

The `-d` option starts the services in detached mode.

## 24.4 What up Can Do

Depending on the application definition and existing state, Compose may:

1. Resolve the application configuration.
2. Create networks.
3. Create named volumes.
4. Retrieve required images.
5. Build applicable images.
6. Create containers.
7. Recreate containers when required.
8. Start services.
9. Attach requested logging output.

## 24.5 Existing Services

Running `up` repeatedly does not ordinarily create a new independent project every time.

Compose identifies the existing project resources and attempts to reconcile them with the current configuration.

If a service's configuration or image changes, Compose may recreate the corresponding container.

## 24.6 Rebuild Option

```bash
docker compose up --build -d
```

This builds applicable service images before starting the application.

---

# 25. THE docker compose ps COMMAND

## 25.1 Definition

The command:

```bash
docker compose ps
```

lists containers associated with the current Compose project.

## 25.2 Information Provided

The output can include:

- Container name.
- Image.
- Command.
- Service name.
- Creation time.
- Status.
- Port mappings.

## 25.3 Include Stopped Containers

```bash
docker compose ps -a
```

This includes stopped containers.

## 25.4 Comparison with docker ps

`docker ps` lists running Docker containers more broadly.

`docker compose ps` is scoped to the selected Compose application.

This makes project-specific inspection more convenient.

---

# 26. THE docker compose logs COMMAND

## 26.1 Definition

The `logs` command retrieves application output from containers associated with a Compose project.

## 26.2 All Services

```bash
docker compose logs
```

## 26.3 One Service

```bash
docker compose logs web
```

## 26.4 Recent Logs

```bash
docker compose logs --tail 20
```

## 26.5 Follow Output

```bash
docker compose logs -f
```

The `-f` option follows new log output.

## 26.6 Operational Significance

Compose can combine logs from multiple services and identify their origins.

This helps administrators investigate problems involving multiple containers.

## 26.7 Important Limitation

Logs provide evidence of application behavior.

They do not establish a complete picture of network health, storage integrity, or application correctness.

---

# 27. THE docker compose exec COMMAND

## 27.1 Definition

The `exec` command starts an additional process inside an existing running service container.

Example:

```bash
docker compose exec web sh
```

## 27.2 Service-Based Addressing

The command uses a Compose service name rather than requiring the administrator to know the generated container name.

## 27.3 Example

```bash
docker compose exec redis redis-cli PING
```

This executes Redis CLI inside the running Redis service container.

## 27.4 Requirements

The target service container must exist and be running.

The requested executable must exist within the container image.

---

# 28. THE docker compose run COMMAND

## 28.1 Definition

The `run` command creates a new one-off container based on a service configuration.

Example:

```bash
docker compose run --rm web nginx -v
```

## 28.2 Difference from exec

`exec` starts a process inside an existing running container.

`run` creates a separate container for a one-off command.

## 28.3 Comparison

| Characteristic | compose exec | compose run |
|---|---|---|
| Uses an existing running service container | Yes | No |
| Creates a new one-off container | No | Yes |
| Useful for diagnostics | Yes | Yes |
| Useful for migrations and utility commands | Yes | Yes |
| Can override service command | Executes supplied process | Yes |
| Publishes declared service ports by default | Existing container's bindings remain | No |
| `--rm` one-off cleanup | Not applicable | Supported |

## 28.4 One-Off Port Behavior

Compose does not normally publish a service's declared host ports when using `docker compose run`.

This helps prevent accidental port conflicts with an already running service.

Explicit options are available when one-off port publishing is required.

---

# 29. STOP, START, AND RESTART

## 29.1 Stopping Services

```bash
docker compose stop
```

Stops running service containers without ordinarily removing them.

## 29.2 Starting Existing Services

```bash
docker compose start
```

Starts previously created service containers.

## 29.3 Restarting Services

```bash
docker compose restart
```

Restarts existing service containers.

## 29.4 Important Limitation

`restart` does not automatically rebuild images or apply every change made to a Compose configuration file.

For configuration changes requiring container recreation, `docker compose up -d` is generally the appropriate operation.

## 29.5 Service Selection

These operations can target particular services.

Example:

```bash
docker compose stop web
```

```bash
docker compose start web
```

This is useful when one service requires maintenance without intentionally stopping the complete application.

---

# 30. THE docker compose down COMMAND

## 30.1 Definition

The `down` command stops and removes selected Compose-managed application resources.

Example:

```bash
docker compose down
```

## 30.2 Default Behavior

Under ordinary operation, `down` removes:

- Containers associated with defined services.
- Project-defined networks.
- The default project network, if present.

It does not normally remove named volumes.

## 30.3 Removing Volumes

```bash
docker compose down -v
```

The `-v` option removes named volumes declared by the Compose project and eligible attached anonymous volumes.

## 30.4 Critical Warning

A named volume may contain important database records.

Executing:

```bash
docker compose down -v
```

can permanently destroy the application's only copy of its data.

Do not use `-v` as a routine cleanup option unless the intended data-loss consequences are understood.

## 30.5 down Versus stop

| Operation | stop | down |
|---|---|---|
| Stop service processes | Yes | Yes |
| Preserve service containers | Yes | No |
| Preserve project networks | Yes | Normally no |
| Preserve named volumes by default | Yes | Yes |
| Require recreation for next deployment | No | Yes |

---

# 31. COMPLETE COMPOSE APPLICATION ARCHITECTURE

The laboratory application consists of two principal services.

**Nginx**

Provides an HTTP web service.

**Redis**

Provides an in-memory key-value database with disk persistence enabled.

The two services will be attached to the same Docker-managed bridge network.

The Redis service will use a named volume for persistent data.

The Nginx service will use a read-only bind mount for website files.

## 31.1 Logical Architecture

```text
                 WEB BROWSER
                      |
                      v
           http://127.0.0.1:8211
                      |
                      v
                 DOCKER HOST
                      |
               Published Port
                      |
                      v
              +---------------+
              | NGINX SERVICE |
              |   Port 80     |
              +---------------+
                      |
                  APP NETWORK
                      |
              +---------------+
              | REDIS SERVICE |
              |   Port 6379   |
              +---------------+
                      |
                      v
                  NAMED VOLUME
                  redis-data
```

## 31.2 Important Architectural Qualification

Nginx and Redis will belong to the same Compose application.

However, the basic Nginx web server does not automatically communicate with Redis.

Compose creates the infrastructure through which services can communicate.

It does not automatically implement application-level integration.

A later lecture will introduce a Python application that actively uses Redis.

---

# PART II — PRACTICAL LABORATORY 11

# 32. LABORATORY OVERVIEW

## 32.1 Title

**Docker Compose Fundamentals: A Declarative Nginx and Redis Application with Networking, Persistent Storage, Environment Interpolation, and Lifecycle Management**

## 32.2 Laboratory Objectives

The student will:

1. Create a Compose project.
2. Write a valid YAML configuration.
3. Define two application services.
4. Configure host port publishing.
5. Configure a read-only bind mount.
6. Declare a named volume.
7. Configure a user-defined network.
8. Use environment variable interpolation.
9. Validate the Compose model.
10. Start and inspect the application.
11. Retrieve service logs.
12. Execute commands in running services.
13. Demonstrate internal DNS resolution.
14. Use a one-off client container.
15. Write and retrieve Redis data.
16. Test Redis persistence across service replacement.
17. Modify website content through a bind mount.
18. Change host port configuration.
19. Compare `stop` and `down`.
20. Complete controlled cleanup.

## 32.3 Laboratory Requirements

Required software:

- Docker Engine or Docker Desktop.
- Docker Compose V2.
- Terminal.
- Text editor.
- Web browser.
- Internet access for obtaining Nginx and Redis images.

The laboratory uses:

```text
nginx:alpine
redis:7-alpine
```

**Security note:** The Redis service is used without authentication in this isolated educational demonstration. Its port is not published to the host. Do not reuse this configuration for a publicly accessible or untrusted environment. Production deployments require appropriate authentication, network controls, and secret management.

---

# 33. EXPERIMENT 1 — VERIFY DOCKER COMPOSE

Execute:

```bash
docker compose version
```

Then:

```bash
docker version
```

**Objective:**

Confirm that Docker Engine and Docker Compose are available.

**Required observations:**

1. Docker Compose version.
2. Docker client version.
3. Docker server version.
4. Whether Docker Engine is accessible.

---

# 34. EXPERIMENT 2 — CREATE THE PROJECT DIRECTORY

Create a directory:

```text
docker-lecture11
```

For a Unix-like shell:

```bash
mkdir docker-lecture11
cd docker-lecture11
mkdir site
```

Create the following project structure:

```text
docker-lecture11/
├── compose.yaml
├── .env
├── site/
│   └── index.html
└── laboratory-notes.md
```

The laboratory notes file is optional during initial setup.

**Objective:**

Create an organized project directory containing the application definition and source content.

---

# 35. EXPERIMENT 3 — CREATE THE WEBSITE

Create:

```text
site/index.html
```

Insert:

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Docker Compose Lecture 11</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            padding: 45px;
            color: #0f172a;
        }

        main {
            max-width: 760px;
            margin: auto;
            background: white;
            padding: 40px;
            border-radius: 12px;
        }

        h1 {
            color: #2563eb;
        }

        p {
            line-height: 1.7;
        }

        .version {
            background: #dbeafe;
            padding: 12px;
            border-radius: 8px;
        }
    </style>
</head>

<body>
    <main>

        <h1>Docker Compose Laboratory</h1>

        <h2>Lecture 11</h2>

        <p>
            This website is served by Nginx
            in a Docker Compose application.
        </p>

        <p>
            The Compose project also contains
            a Redis service with persistent storage.
        </p>

        <p>
            Both services are managed through
            one declarative configuration file.
        </p>

        <p class="version">
            Website Version: 1.0
        </p>

    </main>
</body>

</html>
```

**Objective:**

Provide static content that Nginx can serve through a bind mount.

---

# 36. EXPERIMENT 4 — CREATE THE ENVIRONMENT FILE

Create:

```text
.env
```

Insert:

```text
WEB_PORT=8211
```

**Objective:**

Provide a configurable host port for the Compose application.

**Technical interpretation:**

Compose will use the value during variable interpolation.

The variable is not automatically injected into every container.

---

# 37. EXPERIMENT 5 — CREATE THE COMPOSE CONFIGURATION

Create:

```text
compose.yaml
```

Insert:

```yaml
name: lecture11-course

services:

  web:
    image: nginx:alpine

    ports:
      - "127.0.0.1:${WEB_PORT:-8211}:80"

    volumes:
      - ./site:/usr/share/nginx/html:ro

    environment:
      COURSE_MODULE: "02"
      COURSE_LECTURE: "11"

    networks:
      - app-net

  redis:
    image: redis:7-alpine

    command:
      - redis-server
      - --appendonly
      - "yes"
      - --dir
      - /data

    volumes:
      - redis-data:/data

    networks:
      - app-net

networks:
  app-net:
    driver: bridge

volumes:
  redis-data:
```

## 37.1 Configuration Analysis

**name**

Defines the Compose project name.

**services**

Defines the application's two executable components.

**web**

Provides the Nginx web server.

**redis**

Provides the Redis server.

**image**

Identifies each service's container image.

**ports**

Publishes the Nginx service through a selected host port.

**volumes**

Configures filesystem mounts.

**environment**

Supplies additional runtime variables to Nginx.

**command**

Configures Redis startup arguments.

**networks**

Attaches both services to a managed bridge network.

**Top-level volumes**

Declares the Redis persistent storage resource.

---

# 38. EXPERIMENT 6 — VALIDATE THE CONFIGURATION

Execute:

```bash
docker compose config -q
```

**Expected result:**

The configuration validates successfully without displaying the complete model.

Then execute:

```bash
docker compose config
```

**Objective:**

Inspect the resolved Compose model.

**Required observations:**

1. Verify the two service definitions.
2. Identify the published host port.
3. Identify the bind mount.
4. Identify the named volume.
5. Identify the network.
6. Identify the Redis startup command.

---

# 39. EXPERIMENT 7 — EXAMINE THE SERVICE LIST

Execute:

```bash
docker compose config --services
```

**Expected output:**

The command lists:

```text
web
redis
```

The display order may depend on the resolved configuration.

**Required analysis:**

Explain why a service is a logical application component rather than an image or a container identifier.

---

# 40. EXPERIMENT 8 — START THE APPLICATION

Execute:

```bash
docker compose up -d
```

**Objective:**

Create and start the declared Compose application.

**Expected behavior:**

Compose performs the required operations.

These may include:

1. Resolving the project configuration.
2. Retrieving missing images.
3. Creating the application network.
4. Creating the named Redis volume.
5. Creating the Nginx container.
6. Creating the Redis container.
7. Attaching both containers to the network.
8. Configuring mounts and runtime settings.
9. Starting both services.

**Expected result:**

The two services start successfully.

---

# 41. EXPERIMENT 9 — INSPECT SERVICE STATUS

Execute:

```bash
docker compose ps
```

**Objective:**

Inspect running services in the Compose project.

**Expected result:**

The output contains service containers associated with:

```text
web
redis
```

The Nginx service should have a published host endpoint.

The Redis service should not have a host-published port.

**Required analysis:**

Explain why Redis can operate without host port publishing.

---

# 42. EXPERIMENT 10 — ACCESS THE WEBSITE

Open:

http://127.0.0.1:8211

**Expected result:**

The page displays:

**Docker Compose Laboratory**

It should also show:

**Website Version: 1.0**

**Objective:**

Verify that Compose successfully configured Nginx, the bind mount, and host port publishing.

---

# 43. EXPERIMENT 11 — INSPECT NGINX FILES

Execute:

```bash
docker compose exec web ls -la /usr/share/nginx/html
```

Then:

```bash
docker compose exec web cat /usr/share/nginx/html/index.html
```

**Objective:**

Verify that the host website directory is mounted inside the Nginx container.

**Required analysis:**

Explain why modifying the local HTML file does not necessarily require rebuilding the Nginx image.

---

# 44. EXPERIMENT 12 — INSPECT RUNTIME ENVIRONMENT

Execute:

```bash
docker compose exec web printenv COURSE_MODULE
```

Expected output:

```text
02
```

Then:

```bash
docker compose exec web printenv COURSE_LECTURE
```

Expected output:

```text
11
```

**Objective:**

Verify the service-level `environment` configuration.

**Required analysis:**

Explain why these environment variables exist inside the Nginx container but do not automatically appear in the HTML page.

---

# 45. EXPERIMENT 13 — INSPECT APPLICATION LOGS

Execute:

```bash
docker compose logs
```

Then:

```bash
docker compose logs --tail 20 web
```

Then:

```bash
docker compose logs --tail 20 redis
```

**Objective:**

Examine service-specific logs.

**Required observations:**

1. Identify Nginx startup or request information.
2. Identify Redis startup information.
3. Explain how Compose associates log output with individual services.

Optional:

```bash
docker compose logs -f web
```

Press `Ctrl+C` to stop following the logs.

This stops the log-following command, not the Nginx service.

---

# 46. EXPERIMENT 14 — INSPECT THE COMPOSE NETWORK

Execute:

```bash
docker network ls
```

Locate the project network.

Its name should normally be:

```text
lecture11-course_app-net
```

Inspect it:

```bash
docker network inspect lecture11-course_app-net
```

**Objective:**

Examine the network automatically created by Compose.

**Required observations:**

1. Network driver.
2. Network subnet.
3. Gateway.
4. Attached service containers.
5. Assigned network addresses.

---

# 47. EXPERIMENT 15 — VERIFY SERVICE-NAME DISCOVERY

Execute:

```bash
docker compose run --rm --no-deps web wget -q -O - http://web/
```

**Objective:**

Create a temporary one-off container based on the `web` service definition and use it to access the running Nginx service by hostname.

**Expected result:**

The command retrieves the HTML webpage.

**Technical interpretation:**

The temporary container joins the service's Compose network.

Docker's embedded DNS resolves the hostname:

```text
web
```

to the running Nginx service endpoint.

The temporary container is removed after the command finishes.

**Required analysis:**

Explain why the request uses `web` rather than the host address `127.0.0.1:8211`.

---

# 48. EXPERIMENT 16 — VERIFY REDIS OPERATION

Execute:

```bash
docker compose exec redis redis-cli PING
```

**Expected output:**

```text
PONG
```

**Objective:**

Verify that Redis is running and responding to its client protocol.

**Required analysis:**

Explain the difference between testing a Redis process locally through `exec` and connecting through a separate client container.

---

# 49. EXPERIMENT 17 — USE A SEPARATE REDIS CLIENT

Execute:

```bash
docker compose run --rm --no-deps redis redis-cli -h redis PING
```

**Expected output:**

```text
PONG
```

**Objective:**

Demonstrate Redis client-server communication across the Compose network.

**Technical interpretation:**

Compose creates a temporary container based on the Redis service definition.

The temporary container runs `redis-cli` instead of starting another Redis server.

The client connects to the existing Redis server using:

```text
Hostname: redis
Port: 6379
```

Because the one-off container inherits the service's volume configuration, it can also mount the Redis named volume. In this experiment it only runs the client program and does not independently operate a second database server.

In production, diagnostic client containers should normally be defined without unnecessary database-data mounts.

**Required analysis:**

Explain why name resolution and application protocol compatibility are both necessary for successful Redis communication.

---

# 50. EXPERIMENT 18 — STORE REDIS DATA

Execute:

```bash
docker compose exec redis redis-cli SET course:lecture "Docker Compose Lecture 11"
```

Expected response:

```text
OK
```

Retrieve the value:

```bash
docker compose exec redis redis-cli GET course:lecture
```

Expected response:

```text
Docker Compose Lecture 11
```

Create a counter:

```bash
docker compose exec redis redis-cli SET course:counter 10
```

Increment it:

```bash
docker compose exec redis redis-cli INCR course:counter
```

Expected result:

```text
11
```

**Objective:**

Create application data that can be used to verify persistence.

---

# 51. EXPERIMENT 19 — EXAMINE THE REDIS VOLUME

Execute:

```bash
docker volume ls
```

Locate:

```text
lecture11-course_redis-data
```

Inspect:

```bash
docker volume inspect lecture11-course_redis-data
```

**Objective:**

Verify that Compose created a named Docker volume.

**Required observations:**

1. Volume name.
2. Driver.
3. Mountpoint.
4. Project-related metadata.

**Required analysis:**

Explain how Compose's top-level volume declaration relates to the actual Docker volume.

---

# 52. EXPERIMENT 20 — MODIFY THE WEBSITE WITHOUT REBUILDING

Open:

```text
site/index.html
```

Change:

```html
Website Version: 1.0
```

to:

```html
Website Version: 2.0
```

Save the file.

Refresh:

http://127.0.0.1:8211

**Expected result:**

The browser displays:

**Website Version: 2.0**

**Objective:**

Demonstrate live changes through a bind mount.

**Required analysis:**

Explain the difference between bind-mounted development content and files incorporated into a Docker image through `COPY`.

---

# 53. EXPERIMENT 21 — STOP AND RESTART SERVICES

Execute:

```bash
docker compose stop
```

Verify:

```bash
docker compose ps -a
```

Now start the existing containers:

```bash
docker compose start
```

Verify:

```bash
docker compose ps
```

**Objective:**

Observe Compose service lifecycle management.

**Required analysis:**

Explain why `stop` and `start` preserve existing container configuration and named volumes.

---

# 54. EXPERIMENT 22 — VERIFY REDIS DATA AFTER RESTART

Execute:

```bash
docker compose exec redis redis-cli GET course:lecture
```

Then:

```bash
docker compose exec redis redis-cli GET course:counter
```

**Expected results:**

```text
Docker Compose Lecture 11
```

and:

```text
11
```

**Objective:**

Verify that Redis data remains accessible after ordinary service stopping and starting.

**Required analysis:**

Explain why this experiment alone does not prove that data survives removal of the Redis container.

---

# 55. EXPERIMENT 23 — REMOVE THE APPLICATION WITHOUT DELETING DATA

Execute:

```bash
docker compose exec redis redis-cli SAVE
```

This requests a Redis snapshot.

Now execute:

```bash
docker compose down
```

**Objective:**

Remove the Compose containers and project network while retaining the named Redis volume.

Verify:

```bash
docker compose ps -a
```

Inspect the volume:

```bash
docker volume inspect lecture11-course_redis-data
```

**Expected result:**

The service containers have been removed.

The named volume remains available.

**Required analysis:**

Explain why the storage resource survives the removal of the application containers.

---

# 56. EXPERIMENT 24 — RECREATE THE APPLICATION

Execute:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

Retrieve the stored value:

```bash
docker compose exec redis redis-cli GET course:lecture
```

**Expected result:**

```text
Docker Compose Lecture 11
```

Retrieve the counter:

```bash
docker compose exec redis redis-cli GET course:counter
```

Expected:

```text
11
```

**Objective:**

Demonstrate data persistence across complete Compose container removal and recreation.

**Technical interpretation:**

Compose recreates the service containers and network.

The previously created named volume remains available and is mounted into the replacement Redis container.

Redis loads the saved data using its configured persistence mechanism.

---

# 57. EXPERIMENT 25 — MODIFY PORT CONFIGURATION

Open:

```text
.env
```

Change:

```text
WEB_PORT=8211
```

to:

```text
WEB_PORT=8212
```

Save the file.

Validate:

```bash
docker compose config
```

Confirm that the resolved port mapping now uses host port 8212.

Apply the configuration:

```bash
docker compose up -d
```

**Objective:**

Demonstrate how Compose applies a change in service creation configuration.

Open:

http://127.0.0.1:8212

**Expected result:**

The website is available through the new host port.

**Required analysis:**

Explain why Compose may need to recreate the web container to change its published host port.

---

# 58. EXPERIMENT 26 — INVESTIGATE SERVICE RESTART

Execute:

```bash
docker compose restart web
```

Verify:

```bash
docker compose ps
```

**Objective:**

Restart a particular Compose service.

**Required analysis:**

Explain why the `restart` command should not be treated as a universal mechanism for applying changed Compose configuration.

---

# 59. EXPERIMENT 27 — COMPARE EXEC AND RUN

Execute:

```bash
docker compose exec web nginx -v
```

Then:

```bash
docker compose run --rm --no-deps web nginx -v
```

**Objective:**

Compare the execution of a command inside an existing service container with execution through a temporary one-off container.

**Required analysis:**

1. Which command operates inside an existing container?
2. Which command creates a new container?
3. Which operation is appropriate for inspecting an already running service?
4. Why does `compose run` not ordinarily publish the service's host ports?

---

# 60. EXPERIMENT 28 — EXAMINE THE EFFECT OF DOWN

Execute:

```bash
docker compose down
```

Verify the project containers are removed:

```bash
docker compose ps -a
```

Verify the Redis volume still exists:

```bash
docker volume inspect lecture11-course_redis-data
```

**Objective:**

Establish the ordinary resource-removal behavior of `docker compose down`.

**Required analysis:**

Explain which resources are removed and which remain available.

---

# 61. EXPERIMENT 29 — OPTIONAL DESTRUCTIVE CLEANUP

**This experiment is optional. Execute it only if the Redis laboratory data is no longer required.**

First recreate the project if it is currently down:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

Now execute:

```bash
docker compose down -v
```

**Expected result:**

Compose removes its service containers, project networks, and declared named Redis volume.

The Redis laboratory data is deleted.

**Critical warning:**

Do not use this command against a Compose application containing important persistent data without an appropriate recovery plan.

## Required Analysis

Explain why:

```bash
docker compose down
```

and:

```bash
docker compose down -v
```

have materially different data-retention consequences.

---

# 62. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation | Observed result |
|---|---|---|
| 1 | Compose installation verification | |
| 2 | Project creation | |
| 3 | Website creation | |
| 4 | Environment file creation | |
| 5 | Compose file construction | |
| 6 | Compose validation | |
| 7 | Service discovery | |
| 8 | Application startup | |
| 9 | Service inspection | |
| 10 | Website access | |
| 11 | Mounted file inspection | |
| 12 | Environment variable inspection | |
| 13 | Application log inspection | |
| 14 | Network inspection | |
| 15 | Service-name resolution | |
| 16 | Redis startup verification | |
| 17 | One-off Redis client | |
| 18 | Redis data operations | |
| 19 | Volume inspection | |
| 20 | Bind mount update | |
| 21 | Service stop/start | |
| 22 | Data verification after restart | |
| 23 | Application teardown | |
| 24 | Application recreation | |
| 25 | Host port modification | |
| 26 | Service restart | |
| 27 | Exec versus run | |
| 28 | Down behavior | |
| 29 | Optional destructive cleanup | |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 300–400 words discussing:

1. The role of Compose in multi-container applications.
2. The difference between a service definition and a container instance.
3. The relationship between YAML configuration and Docker Engine resources.
4. Automatic network creation and service-name discovery.
5. The difference between bind mounts and named volumes.
6. The role of environment variable interpolation.
7. The effects of Compose lifecycle commands.
8. Why Redis data survived application recreation.
9. Why Compose infrastructure does not automatically implement application-level integration.

---

# PART III — DOCKER COMPOSE TROUBLESHOOTING

# 63. YAML INDENTATION ERRORS

## 63.1 Problem

A Compose file fails to parse because of incorrect indentation.

Example of an invalid structure:

```yaml
services:
web:
  image: nginx:alpine
```

The `web` mapping is not properly nested under `services`.

## 63.2 Correction

```yaml
services:
  web:
    image: nginx:alpine
```

## 63.3 Investigation

Execute:

```bash
docker compose config -q
```

Read the reported error.

Correct the YAML structure before attempting deployment.

---

# 64. INCORRECT CONFIGURATION KEYS

## 64.1 Problem

A service definition uses an incorrect attribute name.

For example:

```yaml
services:
  web:
    images: nginx:alpine
```

The intended key is `image`, not `images`.

## 64.2 Correction

```yaml
services:
  web:
    image: nginx:alpine
```

## 64.3 Lesson

Compose configuration keys must conform to the Compose Specification.

Unlike arbitrary application data, unknown structural keys are not generally accepted as valid service attributes.

---

# 65. HOST PORT CONFLICTS

## 65.1 Problem

Two applications request incompatible bindings for the same host port.

Example:

```yaml
ports:
  - "127.0.0.1:8211:80"
```

If another process already occupies the requested endpoint, Compose may fail to start the service.

## 65.2 Investigation

Inspect running containers:

```bash
docker ps
```

Inspect the Compose model:

```bash
docker compose config
```

## 65.3 Correction

Select an available host port or deliberately stop the conflicting workload when appropriate.

Do not terminate unrelated applications without evaluating the consequences.

---

# 66. INVALID BIND MOUNT SOURCE

## 66.1 Problem

A service expects a local directory:

```yaml
volumes:
  - ./site:/usr/share/nginx/html:ro
```

However, the host directory does not exist or contains unexpected files.

## 66.2 Consequences

The service may:

- Start with missing application content.
- Display an unexpected page.
- Fail because of an invalid mount.
- Encounter filesystem permission errors.

## 66.3 Correction

Verify that the source path exists and contains the intended files.

Inspect the container's mounts if necessary.

---

# 67. SERVICE NAME RESOLUTION FAILURE

## 67.1 Problem

An application attempts to connect to:

```text
localhost:6379
```

while Redis runs in another container.

## 67.2 Explanation

Inside the application container, `localhost` ordinarily refers to that same container's loopback interface.

It does not identify the Redis service.

## 67.3 Correction

Use the Compose service hostname:

```text
redis:6379
```

provided both services are attached to an appropriate shared Compose network.

---

# 68. REDIS DATA DISAPPEARS

## 68.1 Possible Causes

- The named volume was removed.
- Redis persistence was disabled.
- The wrong volume was mounted.
- Data was written outside the expected directory.
- The project name changed, causing Compose to use a different volume.
- The application failed to save recoverable data.
- A new, empty volume was attached.

## 68.2 Investigation

Inspect:

```bash
docker compose config
```

Then:

```bash
docker volume ls
```

And:

```bash
docker compose exec redis redis-cli CONFIG GET dir
```

## 68.3 Principle

A persistent volume and an application persistence mechanism must be correctly configured together.

---

# 69. COMPOSE CONFIGURATION DOES NOT UPDATE

## 69.1 Scenario

A developer changes the Compose file and executes:

```bash
docker compose restart
```

The expected configuration change does not appear.

## 69.2 Explanation

Restarting an existing container does not automatically recreate it with new port mappings, environment variables, or mounts.

## 69.3 Correction

Use the appropriate Compose reconciliation operation.

For example:

```bash
docker compose up -d
```

When a service image is built from local source, rebuilding may also be required.

---

# 70. DEPENDENCY STARTUP FAILURE

## 70.1 Scenario

An application service starts before its database is ready.

The application attempts to connect immediately and receives an error.

## 70.2 Explanation

Service startup and service readiness are separate properties.

A container may be running before its application has completed initialization.

## 70.3 Correction

Possible approaches include:

- Health checks.
- Health-aware dependency conditions.
- Connection retries.
- Appropriate application initialization logic.

These mechanisms will be covered more deeply during Lecture 13.

---

# 71. ENVIRONMENT INTERPOLATION FAILURE

## 71.1 Scenario

A Compose file contains:

```yaml
ports:
  - "127.0.0.1:${WEB_PORT}:80"
```

The variable `WEB_PORT` is not defined.

## 71.2 Explanation

Compose may substitute an empty string and display a warning when an interpolation variable is missing and has no specified default.

The resulting configuration may not have the intended meaning.

## 71.3 Correction

Define the variable in the appropriate environment or `.env` file.

Alternatively, supply a fallback:

```yaml
ports:
  - "127.0.0.1:${WEB_PORT:-8211}:80"
```

## 71.4 Verification

```bash
docker compose config
```

This displays the resolved configuration.

---

# PART IV — COMMON CONCEPTUAL MISUNDERSTANDINGS

# 72. FREQUENT ERRORS

## Misunderstanding 1

**Docker Compose replaces Docker Engine.**

Incorrect.

Compose coordinates Docker Engine operations.

## Misunderstanding 2

**A Compose service is identical to a Docker image.**

Incorrect.

A service is a logical runtime specification.

An image is a packaged artifact.

## Misunderstanding 3

**A Compose file must contain a version: "3" field.**

Incorrect.

The modern Compose Specification no longer requires this obsolete top-level field.

## Misunderstanding 4

**Docker Compose always requires multiple services.**

Incorrect.

A Compose application can contain one service, although its principal value becomes especially evident with multiple services.

## Misunderstanding 5

**Services must publish ports to communicate internally.**

Incorrect.

Services sharing an appropriate Compose network can communicate using internal endpoints.

## Misunderstanding 6

**The .env file automatically injects every variable into every container.**

Incorrect.

The project `.env` file primarily provides Compose interpolation values.

Container environment injection must be configured appropriately.

## Misunderstanding 7

**Every service needs a separate network.**

Incorrect.

Multiple services may share a common application network.

## Misunderstanding 8

**Docker Compose automatically connects Nginx application logic to Redis.**

Incorrect.

Compose creates the infrastructure.

Applications must implement their own communication logic.

## Misunderstanding 9

**depends_on guarantees complete application readiness.**

Incorrect.

Short-form dependency configuration establishes startup ordering but does not guarantee health.

## Misunderstanding 10

**docker compose run is identical to docker compose exec.**

Incorrect.

`run` creates a one-off container.

`exec` operates inside an existing container.

## Misunderstanding 11

**docker compose restart always applies configuration changes.**

Incorrect.

Container recreation may be necessary.

## Misunderstanding 12

**docker compose down always removes named volumes.**

Incorrect.

Named volumes normally remain unless the relevant removal option is used.

## Misunderstanding 13

**docker compose down -v is harmless cleanup.**

Incorrect.

It can delete persistent application data.

## Misunderstanding 14

**A valid Compose YAML file guarantees successful deployment.**

Incorrect.

Images, networking, ports, mounts, permissions, and applications may still fail.

## Misunderstanding 15

**Compose service names are globally resolvable DNS names.**

Incorrect.

Name resolution is ordinarily scoped to appropriate Compose network environments.

## Misunderstanding 16

**Adding an environment variable automatically changes application behavior.**

Incorrect.

The application must explicitly support and interpret that variable.

---

# PART V — IMPORTANT TECHNICAL TERMINOLOGY

# 73. ACADEMIC GLOSSARY

| Term | Academic definition |
|---|---|
| Docker Compose | Declarative multi-container application management tool |
| Compose Specification | Standardized application configuration model |
| Compose file | YAML document describing a Compose application |
| YAML | Human-readable structured data serialization language |
| Mapping | Collection of key-value associations |
| Sequence | Ordered collection of elements |
| Scalar | Individual YAML value |
| Indentation | Whitespace defining YAML structure |
| Compose project | Named logical application resource group |
| Service | Logical definition of an executable application component |
| Service instance | Container implementing a service definition |
| Declarative configuration | Description of desired system state |
| Imperative operation | Explicit instruction requesting an action |
| image attribute | Service image reference |
| build attribute | Image-construction configuration |
| ports attribute | Host port publishing configuration |
| environment attribute | Container environment variable configuration |
| env_file attribute | Container environment variables loaded from files |
| Variable interpolation | Substitution of configuration variables |
| Project .env | File supplying Compose interpolation values |
| volumes attribute | Filesystem mount configuration |
| Named volume | Docker-managed persistent storage resource |
| Bind mount | Mapping of a host path into a container |
| networks attribute | Service network attachment configuration |
| Default network | Automatically created Compose project network |
| Embedded DNS | Docker resolver supporting service-name discovery |
| command attribute | Override of default command configuration |
| entrypoint attribute | Override of image entrypoint configuration |
| depends_on | Service dependency ordering configuration |
| Service readiness | State in which an application can perform its intended operations |
| docker compose config | Compose model validation and rendering |
| docker compose up | Application creation and startup operation |
| docker compose ps | Project container inspection |
| docker compose logs | Service log retrieval |
| docker compose exec | Execute a process inside an existing service container |
| docker compose run | Create a one-off service-based container |
| docker compose stop | Stop existing service containers |
| docker compose start | Start existing service containers |
| docker compose restart | Restart existing service containers |
| docker compose down | Remove selected project application resources |
| Configuration reconciliation | Aligning deployed resources with the current application specification |
| Resource lifecycle | Creation, execution, stopping, replacement, and deletion of resources |

---

# PART VI — ACADEMIC ASSESSMENT

# 74. PART A — FORMAL DEFINITIONS

Provide academically precise definitions for:

1. Docker Compose.
2. Compose Specification.
3. Declarative configuration.
4. Compose project.
5. Compose service.
6. YAML mapping.
7. YAML sequence.
8. Environment interpolation.
9. Service-level environment variable.
10. Compose network.
11. Named volume.
12. Bind mount.
13. Service dependency.
14. One-off container.
15. Configuration reconciliation.

---

# 75. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why manually managing several containers through individual Docker commands can become difficult.

**Question 2.**

Describe the architectural relationship between Docker Compose and Docker Engine.

**Question 3.**

Explain the differences between imperative and declarative infrastructure management.

**Question 4.**

Describe the purpose of the Compose Specification.

**Question 5.**

Explain why the modern Compose file does not require the legacy top-level `version` field.

**Question 6.**

Describe the difference between a Compose service and a container instance.

**Question 7.**

Explain the purpose of the `image` and `build` attributes.

**Question 8.**

Describe how Compose implements host port publishing.

**Question 9.**

Explain the difference between a Compose project `.env` file and a service-level `environment` attribute.

**Question 10.**

Explain why Compose services can discover one another using service names.

**Question 11.**

Describe the purpose of named volumes in Compose.

**Question 12.**

Explain why a bind mount is useful during web development.

**Question 13.**

Describe the limitations of short-form `depends_on`.

**Question 14.**

Explain the difference between `docker compose run` and `docker compose exec`.

**Question 15.**

Explain the data-retention differences between `docker compose down` and `docker compose down -v`.

---

# 76. PART C — COMMAND INTERPRETATION

Consider:

```bash
docker compose up -d
```

Answer:

1. What operation is requested?
2. What does `-d` mean?
3. Does Compose necessarily rebuild every image?
4. What types of Docker resources may be created?

Consider:

```bash
docker compose config -q
```

Answer:

5. What is the purpose of this command?
6. Does it start application containers?
7. Can a valid configuration still fail during deployment?

Consider:

```bash
docker compose exec redis redis-cli PING
```

Answer:

8. Which service is selected?
9. Which executable is started?
10. Does the operation create a new container?

Consider:

```bash
docker compose run --rm web nginx -v
```

Answer:

11. Does this operate inside the existing web container?
12. What is the purpose of `--rm`?
13. Are the service's published host ports enabled by default?

Consider:

```bash
docker compose down -v
```

Answer:

14. Which classes of project resources may be removed?
15. Why must this command be used with caution?

---

# 77. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Incorrect YAML Structure

A developer writes:

```yaml
services:
web:
  image: nginx:alpine
```

Compose reports a configuration error.

Explain the problem.

Correct the YAML and describe why indentation matters.

## Case Study 2 — Database Connectivity

A backend service uses:

```text
REDIS_HOST=localhost
```

Redis runs as a separate service in the same Compose application.

The backend cannot connect.

Explain the cause and recommend the correct logical service hostname.

## Case Study 3 — Persistent Data Loss

A developer executes:

```bash
docker compose down -v
```

The application's Redis volume is removed.

After recreation, the Redis data is missing.

Explain why this happened.

Recommend a safer operational procedure.

## Case Study 4 — Configuration Changes

A developer changes a service's host port in `compose.yaml`.

The developer then executes:

```bash
docker compose restart
```

The old port configuration remains.

Explain why the operation was insufficient.

Describe the role of container recreation.

## Case Study 5 — Application Readiness

An API service uses:

```yaml
depends_on:
  - database
```

The API starts before the database has finished initializing.

Its first connection attempt fails.

Explain why short-form dependency ordering did not prevent the error.

Describe appropriate readiness and retry mechanisms.

## Case Study 6 — Misunderstood Integration

A Compose file defines:

- Nginx.
- Redis.

Both services start successfully.

A developer assumes that the Nginx page will automatically display Redis data.

Explain why this assumption is incorrect.

Describe the additional application component or logic required for dynamic database-backed web content.

---

# 78. PRACTICAL ASSESSMENT

**Total available marks: 100**

| Assessment component | Marks |
|---|---:|
| Docker Compose theory | 15 |
| YAML and Compose model construction | 20 |
| Multi-service deployment | 20 |
| Network and volume configuration | 15 |
| Application lifecycle management | 15 |
| Troubleshooting and technical analysis | 10 |
| Documentation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student should demonstrate both successful operation and an accurate explanation of the underlying Compose configuration.

---

# 79. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Declarative Multi-Container Application Management with Docker Compose

Prepare an academic report of approximately 1,200–1,700 words addressing:

**“Docker Compose as a Declarative Application Management System: Services, Networks, Volumes, Environment Configuration, and Runtime Lifecycle.”**

The report must contain:

1. An introduction to multi-container application management.
2. A description of the limitations of manual Docker commands.
3. An explanation of declarative configuration.
4. A definition of Docker Compose.
5. A discussion of the Compose Specification.
6. An explanation of YAML structure.
7. A description of Compose projects and services.
8. An examination of image and build configuration.
9. An explanation of networking and service discovery.
10. An examination of persistent volumes and bind mounts.
11. A discussion of environment configuration.
12. An explanation of service dependencies.
13. A comparison of fundamental Compose lifecycle commands.
14. An analysis of the Nginx-and-Redis laboratory.
15. A discussion of security considerations.
16. A technical conclusion.

The report must include at least one complete Compose example and one application architecture diagram.

---

# 80. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 12, verify that you can independently complete the following tasks.

## Foundational Concepts

- [ ] Define Docker Compose.
- [ ] Explain declarative configuration.
- [ ] Describe the Compose Specification.
- [ ] Explain the relationship between Compose and Docker Engine.
- [ ] Distinguish services from container instances.

## YAML Configuration

- [ ] Recognize YAML mappings.
- [ ] Recognize YAML sequences.
- [ ] Use correct indentation.
- [ ] Write a valid `compose.yaml`.
- [ ] Explain the `services` top-level element.
- [ ] Explain the `networks` top-level element.
- [ ] Explain the `volumes` top-level element.
- [ ] Understand the purpose of the project `name` field.

## Services

- [ ] Configure an image-based service.
- [ ] Explain the `build` attribute.
- [ ] Configure port publishing.
- [ ] Configure environment variables.
- [ ] Explain `env_file`.
- [ ] Configure a service command.
- [ ] Explain an entrypoint override.
- [ ] Describe `depends_on`.

## Networking

- [ ] Explain the default Compose network.
- [ ] Configure an explicit bridge network.
- [ ] Explain service-name DNS discovery.
- [ ] Access a service through an internal hostname.
- [ ] Distinguish host ports from container ports.
- [ ] Explain why Redis does not need a published host port.

## Storage

- [ ] Declare a named volume.
- [ ] Mount a volume into Redis.
- [ ] Create a read-only bind mount.
- [ ] Verify host-file changes through the bind mount.
- [ ] Inspect the created Docker volume.
- [ ] Explain persistence across container recreation.
- [ ] Explain the danger of `down -v`.

## Lifecycle Management

- [ ] Validate a Compose file.
- [ ] Start an application using `up -d`.
- [ ] List running services.
- [ ] Retrieve service logs.
- [ ] Execute commands using `exec`.
- [ ] Create one-off containers using `run`.
- [ ] Stop services.
- [ ] Start existing services.
- [ ] Restart a service.
- [ ] Remove an application using `down`.
- [ ] Explain when container recreation is required.

## Laboratory Completion

- [ ] Create the complete Nginx-and-Redis project.
- [ ] Access the Nginx website.
- [ ] Verify Redis operation.
- [ ] Store and retrieve Redis data.
- [ ] Demonstrate service-name discovery.
- [ ] Inspect the Compose network.
- [ ] Inspect the persistent volume.
- [ ] Demonstrate data persistence across application recreation.
- [ ] Modify the host port through `.env`.
- [ ] Complete the laboratory report.

**Completion standard:**

The student should be able to describe, deploy, inspect, modify, and remove a basic multi-container application using one Compose configuration file.

The student must also understand the effects of each operation on containers, networks, and persistent data.

---

# 81. LECTURE SUMMARY

Docker Compose introduces a declarative approach to multi-container application configuration and lifecycle management.

Rather than creating containers, networks, and volumes through separate commands, developers can describe these resources in a structured YAML application definition.

The Compose Specification establishes the configuration model.

A Compose project provides a logical identity for the resulting application resources.

Services describe executable application components.

A service can define an image, build instructions, ports, environment variables, mounted storage, networking, and runtime command behavior.

Compose networks support internal communication and DNS-based service discovery.

Named volumes preserve application data independently of container replacement.

Bind mounts provide a convenient mechanism for accessing host-managed development files.

Environment interpolation enables selected configuration values to be supplied separately from the main Compose file.

The Compose command interface supports application validation, creation, startup, inspection, logging, command execution, stopping, restarting, and removal.

The Nginx-and-Redis laboratory demonstrates how two separate services can be operated within a single application model.

It also demonstrates that Compose does not automatically implement application-level integration between those services.

The key management distinction is that `docker compose up` creates or reconciles the required application resources, while `docker compose down` removes selected resources without ordinarily deleting named volumes.

**The central principle of this lecture is that Docker Compose converts multi-container deployment from a collection of individually managed Docker commands into a structured, repeatable, and inspectable application configuration.**

---

# 82. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. *Docker Compose Overview.*  
https://docs.docker.com/compose/

[2] Docker Inc. *Docker Compose Quickstart.*  
https://docs.docker.com/compose/gettingstarted/

[3] Docker Inc. *Compose File Reference.*  
https://docs.docker.com/reference/compose-file/

[4] Docker Inc. *Version and Name Top-Level Elements.*  
https://docs.docker.com/reference/compose-file/version-and-name/

[5] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[6] Docker Inc. *Compose Networks Reference.*  
https://docs.docker.com/reference/compose-file/networks/

[7] Docker Inc. *Compose Volumes Reference.*  
https://docs.docker.com/reference/compose-file/volumes/

[8] Docker Inc. *Networking in Compose.*  
https://docs.docker.com/compose/how-tos/networking/

[9] Docker Inc. *Docker Compose CLI Reference.*  
https://docs.docker.com/reference/cli/docker/compose/

[10] Docker Inc. *docker compose up.*  
https://docs.docker.com/reference/cli/docker/compose/up/

[11] Docker Inc. *docker compose down.*  
https://docs.docker.com/reference/cli/docker/compose/down/

[12] Docker Inc. *docker compose config.*  
https://docs.docker.com/reference/cli/docker/compose/config/

[13] Docker Inc. *docker compose run.*  
https://docs.docker.com/reference/cli/docker/compose/run/

[14] Docker Inc. *Compose Variable Interpolation.*  
https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/

[15] Docker Inc. *Setting Environment Variables in Compose.*  
https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/

[16] Docker Inc. *Environment Variable Precedence.*  
https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/

[17] Docker Inc. *Docker Compose Build Specification.*  
https://docs.docker.com/reference/compose-file/build/

[18] Docker Inc. *Dockerfile Reference.*  
https://docs.docker.com/reference/dockerfile/

## Recommended Reading Sequence

Begin with references [1], [2], and [3] to establish the architecture, execution model, and configuration syntax of Docker Compose.

Continue with references [4], [5], [6], and [7] to understand project names, services, networks, and volumes.

References [9] through [13] provide detailed command-line semantics.

References [14], [15], and [16] explain environment interpolation and configuration precedence.

Reference [17] prepares students for building application-specific images through Compose.

---

# 83. FINAL LECTURE CONCLUSION

Docker Compose represents an important progression from individual container management to application-level infrastructure management.

The preceding lectures established the technical foundations required to understand Docker containers, images, networks, storage, and runtime configuration.

Compose integrates these capabilities into a unified application specification.

A Compose file describes the services required by an application and the resources necessary for their execution.

The configuration identifies container images, startup commands, network attachments, persistent volumes, bind mounts, environment settings, and host port mappings.

The Compose command-line interface uses this model to create and operate the application through Docker Engine.

This approach improves repeatability and reduces the need to maintain complex sequences of individual Docker commands.

However, the declarative application model does not eliminate the need for technical understanding.

Administrators must still evaluate storage persistence, network security, service readiness, configuration precedence, and application behavior.

The practical laboratory demonstrates that a multi-container environment can be constructed, inspected, stopped, removed, and recreated from a single configuration file.

It also shows that named volumes can preserve application data across the recreation of the service containers.

The distinction between infrastructure composition and application integration is especially important.

Docker Compose creates and manages the environment in which services operate.

The application components must still implement the protocols and logic required to exchange useful data.

These principles establish the foundation for the next lecture, which will combine a Python application with Redis to construct a genuinely integrated multi-container system.

---

**END OF LECTURE 11**

**Next Lecture:** Lecture 12 — Building a Multi-Container Application with Docker Compose: Python Flask, Redis, Service Communication, Environment Configuration, and Persistent Application State.
