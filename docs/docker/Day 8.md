# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 08 — DOCKER PORT PUBLISHING, NETWORK COMMUNICATION, ENVIRONMENT VARIABLES, AND RUNTIME APPLICATION CONFIGURATION

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 08 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Completion of Module 01 — Docker Fundamentals.
- Understanding of images, containers, and Dockerfiles.
- Familiarity with `docker run`, `docker ps`, `docker inspect`, and `docker logs`.
- Elementary knowledge of operating-system processes and client-server applications.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Explain the relationship between containerization and computer networking.
2. Describe fundamental TCP/IP communication principles.
3. Define IP addresses, transport protocols, ports, and network endpoints.
4. Distinguish between host network environments and container network namespaces.
5. Explain the role of Docker's default bridge networking.
6. Differentiate between inbound and outbound container network communication.
7. Describe the technical purpose of port publishing.
8. Interpret Docker's host-port-to-container-port mapping syntax.
9. Distinguish between TCP and UDP port mappings.
10. Explain the relationship between `EXPOSE`, `--expose`, `-p`, and `-P`.
11. Describe network address translation in container networking.
12. Explain the security implications of publishing ports on different host interfaces.
13. Interpret the meaning of `127.0.0.1`, `localhost`, and `0.0.0.0`.
14. Explain why `localhost` inside a container ordinarily differs from `localhost` on the host.
15. Identify the networking requirements of a containerized web server.
16. Describe how container port publishing is represented in Docker metadata.
17. Use `docker port` to investigate published endpoints.
18. Define environment variables and explain their role in application configuration.
19. Distinguish Dockerfile `ENV` from runtime environment overrides.
20. Supply environment variables using `docker run -e`.
21. Configure containers using `--env-file`.
22. Explain the differences between build arguments and runtime environment variables.
23. Describe precedence between image defaults and runtime environment configuration.
24. Explain why container environment and port mappings are normally established at creation.
25. Identify security risks related to environment variables.
26. Explain the principle of separating application configuration from application images.
27. Construct and run multiple containers using one image but different configurations.
28. Investigate common Docker networking and configuration errors.
29. Complete an integrated laboratory involving a configurable HTTP application.

---

# 2. INTRODUCTION TO CONTAINER NETWORKING

## 2.1 Background

An application executing inside a Docker container frequently needs to exchange information with other software systems.

Examples include:

- A web server receiving HTTP requests.
- An application connecting to a database.
- A service communicating with an external API.
- A background worker interacting with a message broker.
- A client application accessing a containerized development server.

These activities require network communication.

Docker provides networking functionality that enables containers to communicate within configured network environments.

However, container isolation introduces an important distinction between the network environment of a container and the network environment of its host.

A container may execute a functioning web server without that service automatically becoming accessible through a browser on the host computer.

The necessary communication pathway depends upon networking configuration.

## 2.2 Definition of Container Networking

Container networking refers to the mechanisms through which containerized processes communicate with other containers, the host system, and external networks.

**Formal definition:**

Container networking is the configuration and management of network interfaces, addresses, routing, name resolution, and traffic forwarding associated with isolated container execution environments.

In Linux-based Docker systems, network namespaces are a central mechanism supporting container network isolation.

Docker provides network drivers and management interfaces for establishing communication between containers and other systems.

## 2.3 Importance of Networking in Docker

Without appropriate networking configuration, containerized applications may be unable to communicate with their required users or services.

Consider a web application running inside a container.

The application may successfully start an HTTP server on TCP port 8000.

However, a browser running on the host must have a valid network route and accessible endpoint through which it can reach that service.

Docker port publishing provides one common solution.

The distinction between an application listening on a port and that port being published to the host is therefore fundamental.

---

# 3. FUNDAMENTALS OF TCP/IP NETWORKING

## 3.1 Computer Networks

A computer network is a collection of computing systems capable of exchanging information through agreed communication protocols.

Networks may include:

- Physical computers.
- Virtual machines.
- Containers.
- Routers.
- Network switches.
- Internet services.
- Cloud-hosted applications.

Communication requires mechanisms for identifying destinations and transporting data.

The TCP/IP protocol suite provides the foundation of contemporary internet networking.

## 3.2 Internet Protocol

Internet Protocol, or IP, provides mechanisms for addressing and routing packets between networked systems.

An IP address identifies a network interface or logical endpoint within an IP network.

Two major IP versions are:

**IPv4:** Uses 32-bit addresses.

**IPv6:** Uses 128-bit addresses.

An example IPv4 address is:

`192.168.1.20`

An example IPv6 address is:

`2001:db8::1`

The addresses used by Docker containers depend on network configuration, platform, and available address families.

## 3.3 Transport Protocols

Applications commonly use transport protocols that operate above IP.

Two important transport protocols are:

**Transmission Control Protocol (TCP)**

TCP provides a connection-oriented communication service with ordered byte delivery and mechanisms for reliability and congestion control.

It is commonly used by:

- HTTP/1.1.
- HTTP/2 over TCP.
- SSH.
- Many database connections.
- Email protocols.

**User Datagram Protocol (UDP)**

UDP provides a connectionless datagram transport service.

It does not independently guarantee reliable or ordered delivery.

UDP is used in applications such as:

- DNS communication.
- Real-time communication protocols.
- Selected streaming and gaming systems.
- QUIC-based communications.

The choice between TCP and UDP depends on application requirements.

## 3.4 Network Ports

A network port is a numeric identifier used by transport protocols to distinguish communication endpoints.

TCP and UDP each use 16-bit port numbers.

Valid numeric port values range from:

`0` to `65535`

Port zero has special uses and is not normally assigned as an ordinary public application listening port.

Some commonly encountered ports include:

| Port | Protocol | Typical service           |
| ---- | -------- | ------------------------- |
| 22   | TCP      | SSH                       |
| 53   | UDP/TCP  | DNS                       |
| 80   | TCP      | HTTP                      |
| 443  | TCP/UDP  | HTTPS-related protocols   |
| 5432 | TCP      | PostgreSQL                |
| 6379 | TCP      | Redis                     |
| 8000 | TCP      | Development HTTP service  |
| 8080 | TCP      | Alternative HTTP endpoint |

These assignments represent common conventions.

An application may be configured to use a different port when the relevant protocol and network configuration permit it.

## 3.5 Network Endpoints

A network endpoint is commonly identified by a combination of:

- IP address.
- Transport protocol.
- Port number.

For example:

`127.0.0.1:8080`

represents an IPv4 address and port.

When interpreted as a TCP endpoint, it refers to TCP port 8080 on the local loopback address.

The destination address and destination port determine where a connection is directed.

---

# 4. NETWORK ISOLATION IN DOCKER

## 4.1 Linux Network Namespaces

Linux network namespaces provide isolated views of selected networking resources.

These resources may include:

- Network interfaces.
- IP addresses.
- Routing tables.
- Network-related kernel settings.
- Listening sockets.
- Firewall-related resources.

A container using its own network namespace can possess a network configuration distinct from the host.

## 4.2 Container Network Interfaces

A Docker container attached to a bridge network generally receives a network interface within its network namespace.

The interface may be assigned a private IP address.

Docker configures the networking infrastructure necessary for communication according to the selected network driver.

For example, a container might receive an address similar to:

`172.17.0.2`

This is illustrative.

Container IP addresses must not be assumed to be permanent or identical across Docker installations.

## 4.3 Loopback Interfaces

A network namespace normally contains a loopback interface.

The IPv4 loopback address is:

`127.0.0.1`

The IPv6 loopback address is:

`::1`

A connection directed to the loopback interface remains within the corresponding network namespace.

This creates an important distinction.

The host operating system has its own loopback environment.

A container using a separate network namespace has its own loopback environment.

Therefore, `localhost` inside a container does not ordinarily refer to the host computer's loopback interface.

## 4.4 Container Isolation Model

```text id="r5wqzk"
           DOCKER HOST
                |
       +--------+--------+
       |                 |
       v                 v
  HOST NETWORK      DOCKER NETWORK
   NAMESPACE             |
       |           +-----+-----+
       |           |           |
       v           v           v
  Host localhost Container A Container B
   127.0.0.1      Network     Network
                  Namespace   Namespace
                     |           |
                     v           v
                  localhost   localhost
                  127.0.0.1   127.0.0.1
```

Each loopback interface belongs to its own networking environment.

The loopback address has the same numerical representation but refers to a different namespace.

---

# 5. DOCKER BRIDGE NETWORKING

## 5.1 Definition

A bridge network provides network connectivity between containers and their associated Docker host networking infrastructure.

On Linux, Docker bridge networking commonly uses Linux bridge-related and packet-forwarding mechanisms.

A newly created Docker Engine installation ordinarily provides a default bridge network.

The default network is commonly named:

`bridge`

## 5.2 Default Bridge Network

Containers started without an explicit network selection are commonly attached to Docker's default bridge network.

Example:

```bash
docker run -d --name example nginx:alpine
```

Under ordinary default Docker networking conditions, the container is connected to the default bridge network.

The container can use that network for supported communication with other destinations.

## 5.3 Default Bridge Limitations

The default bridge network has several limitations compared with user-defined bridge networks.

For example, automatic name-based discovery between ordinary containers is not provided in the same manner as on user-defined bridges.

User-defined bridge networks provide integrated DNS-based container-name resolution.

These mechanisms will be studied in detail during Lecture 10.

## 5.4 Outbound Communication

Containers connected to suitable bridge networks can commonly initiate outbound network connections.

For example, a containerized application may contact an external HTTP API.

The host's networking configuration provides the necessary forwarding and address translation where applicable.

## 5.5 Inbound Communication

Inbound access from systems outside the container's network requires an appropriate communication path.

Docker port publishing provides a standard mechanism for making containerized services available through host network endpoints.

The need for port publishing depends on the source of the traffic and the network configuration.

Containers sharing a suitable Docker network do not necessarily need published host ports to communicate with one another.

This distinction becomes essential in multi-container applications.

---

# 6. UNDERSTANDING HOST PORTS AND CONTAINER PORTS

## 6.1 Host Port

A host port is a transport-layer port associated with a selected network address on the Docker host.

A published host port allows clients to access a service through the host's networking environment.

For example:

`127.0.0.1:8181`

represents host port 8181 bound to the IPv4 loopback interface.

## 6.2 Container Port

A container port is a transport-layer port used by an application within the container's network environment.

For example, a Python HTTP server may listen on:

`0.0.0.0:8000`

inside its container.

## 6.3 Port Mapping

Docker port mapping associates a host endpoint with a container endpoint.

For example:

```text
Host TCP port:      8181
Container TCP port: 8000
```

A browser sends traffic to host port 8181.

Docker forwards the traffic to the containerized service on port 8000.

## 6.4 Architectural Representation

```text id="9mw0ru"
             WEB BROWSER
                  |
                  |
       http://127.0.0.1:8181
                  |
                  v
           HOST PORT 8181
                  |
                  v
           DOCKER NETWORKING
                  |
                  v
         CONTAINER PORT 8000
                  |
                  v
           PYTHON HTTP SERVER
                  |
                  v
            HTTP RESPONSE
```

This arrangement permits the application to retain its internal listening port while using a different external host port.

## 6.5 Port Independence

The host port and container port do not need to be equal.

For example:

`8181:8000`

maps host port 8181 to container port 8000.

Similarly:

`8182:8000`

maps host port 8182 to container port 8000.

This allows multiple containers to run identical applications while using different host endpoints.

---

# 7. THE DOCKER PORT PUBLISHING MECHANISM

## 7.1 Definition

Port publishing is the operation of making a container's transport-layer port accessible through a selected host network endpoint.

Docker provides the option:

`-p`

Its long form is:

`--publish`

## 7.2 General Syntax

```text
docker run -p HOST_PORT:CONTAINER_PORT IMAGE
```

Example:

```bash
docker run -d -p 8181:80 nginx:alpine
```

This publishes container TCP port 80 through host port 8181.

## 7.3 Explicit Host Address

Docker also supports selecting a host IP address.

Example:

```bash
docker run -d \
  -p 127.0.0.1:8181:80 \
  nginx:alpine
```

This binds the published IPv4 endpoint to the host's loopback address under ordinary Docker networking behavior.

It is appropriate for many local development exercises.

## 7.4 Full Port Publishing Syntax

A general form is:

```text
HOST_IP:HOST_PORT:CONTAINER_PORT/PROTOCOL
```

Example:

```bash
docker run -d \
  -p 127.0.0.1:8181:80/tcp \
  nginx:alpine
```

The protocol is TCP.

If the protocol is omitted, TCP is normally assumed.

## 7.5 UDP Publishing

Docker also supports UDP mappings.

Example:

```bash
docker run -d \
  -p 127.0.0.1:5353:53/udp \
  IMAGE
```

This example represents the syntax for publishing container UDP port 53 through host UDP port 5353.

A functioning service must actually listen for UDP traffic on the selected container port.

A TCP service does not become a UDP service merely because the publishing syntax specifies UDP.

---

# 8. PORT PUBLISHING AND NETWORK ADDRESS TRANSLATION

## 8.1 Definition of Network Address Translation

Network Address Translation, commonly abbreviated NAT, is a networking mechanism through which packet address information is modified as traffic passes through a forwarding system.

Port Address Translation, or PAT, also involves transport-layer port information.

Docker bridge networking commonly uses NAT and related forwarding mechanisms to support published ports and outbound connectivity.

## 8.2 Example

A client connects to:

`127.0.0.1:8181`

The Docker host's networking mechanisms direct the connection toward the selected container endpoint:

`CONTAINER_IP:8000`

The containerized HTTP server processes the request.

The response is returned through the established communication path.

## 8.3 Logical Packet Flow

```text id="irh8c9"
       HTTP CLIENT
           |
           v
   Destination: Host:8181
           |
           v
     DOCKER PORT MAPPING
           |
           v
   Destination: Container:8000
           |
           v
       APPLICATION
           |
           v
       HTTP RESPONSE
           |
           v
       HTTP CLIENT
```

This is a simplified representation.

Docker's internal implementation differs according to platform, network driver, firewall configuration, and port-forwarding backend.

For example, Docker Desktop commonly uses a networking backend to forward host connections into its Linux execution environment.

## 8.4 Port Publishing Does Not Start an Application

Port publishing establishes networking configuration.

It does not independently create an application listener.

If no application is listening on the configured container port, the published host port cannot provide the expected service.

This is a frequent cause of troubleshooting failures.

---

# 9. EXPOSE VERSUS PUBLISH

## 9.1 The EXPOSE Instruction

The Dockerfile instruction:

```dockerfile
EXPOSE 8000
```

declares that the image expects an application to use container port 8000.

It records image configuration metadata.

It does not publish host port 8000.

## 9.2 The --expose Option

Docker also supports:

```bash
docker run --expose 8000 IMAGE
```

This declares an exposed container port through runtime configuration.

It does not establish a host port mapping.

## 9.3 The -p Option

The command:

```bash
docker run -p 127.0.0.1:8181:8000 IMAGE
```

establishes a published host endpoint.

## 9.4 The -P Option

Docker supports:

`-P`

Its long form is:

`--publish-all`

It publishes exposed container ports to automatically selected host ports.

Example:

```bash
docker run -P nginx:alpine
```

Docker assigns available host ports for the exposed ports.

Because these ports may bind to all host interfaces by default, automatic publishing should be used carefully on computers connected to untrusted networks.

## 9.5 Comparative Analysis

| Mechanism             | Declares port               | Creates host mapping | Selects host port                  |
| --------------------- | --------------------------- | -------------------- | ---------------------------------- |
| Dockerfile `EXPOSE`   | Yes                         | No                   | No                                 |
| `docker run --expose` | Yes                         | No                   | No                                 |
| `docker run -p`       | Yes, through mapping        | Yes                  | Explicit or automatically assigned |
| `docker run -P`       | Uses declared exposed ports | Yes                  | Automatically assigned             |

**Important principle:** An exposed port and a published port are not equivalent.

---

# 10. LOCALHOST, 127.0.0.1, AND 0.0.0.0

## 10.1 The Localhost Name

The hostname:

`localhost`

ordinarily resolves to a loopback address.

Common loopback addresses include:

- `127.0.0.1` for IPv4.
- `::1` for IPv6.

A request to `localhost` stays within the corresponding network environment.

## 10.2 Binding to 127.0.0.1

When an application binds to:

`127.0.0.1`

it listens through the IPv4 loopback interface of its network namespace.

Inside an ordinary bridge-networked container, this is the container's loopback interface.

It is not the same as the host's loopback interface.

## 10.3 Binding to 0.0.0.0

The address:

`0.0.0.0`

has several uses depending on context.

When used as an IPv4 application bind address, it generally means that the application listens on all available IPv4 interfaces in its network namespace.

For example:

```text
0.0.0.0:8000
```

means that the application accepts connections addressed to the appropriate local IPv4 interfaces on TCP port 8000.

It is not a specific remote destination address.

## 10.4 Why This Matters in Docker

Consider an application inside a bridge-networked container.

If it listens only on:

`127.0.0.1:8000`

the application is restricted to the container's loopback interface.

A host-to-container published port normally forwards traffic toward the container's network-facing address.

Consequently, the application may not be reachable through the published host port.

If the application instead listens on:

`0.0.0.0:8000`

it can accept connections through the container's relevant IPv4 network interface, subject to network and security configuration.

## 10.5 Application Bind Address Versus Published Host Address

Two different configurations must not be confused.

**Application bind address:**

Where the application listens inside the container.

**Published host address:**

Where Docker accepts connections on the host.

For example:

Application configuration:

```text
0.0.0.0:8000
```

Docker publishing:

```text
127.0.0.1:8181:8000
```

The application listens on container IPv4 interfaces.

Docker publishes it only through the host IPv4 loopback endpoint.

These settings serve different purposes.

---

# 11. PORT PUBLISHING AND SECURITY

## 11.1 Default Published Interfaces

When Docker publishes a port without a specific host address, it normally makes the port available on all applicable host interfaces.

Example:

```bash
docker run -p 8181:8000 IMAGE
```

Depending on the Docker installation and network configuration, the service may be reachable from other computers.

This can create unintended exposure.

## 11.2 Local Development Binding

For a local training environment, an explicit loopback binding is preferable.

Example:

```bash
docker run \
  -p 127.0.0.1:8181:8000 \
  IMAGE
```

This requests local IPv4 access only under standard supported Docker port-publishing behavior.

Docker Engine versions before 28.0.0 had a documented caveat in which some localhost-published ports could be reached by hosts on the same Layer 2 network.

Thus, engine version and host networking configuration remain relevant.

## 11.3 Public Service Exposure

A production web service may intentionally require access through a public network interface.

Such deployment requires additional considerations, including:

- Firewall configuration.
- Application authentication.
- TLS encryption.
- Reverse proxy configuration.
- Operating-system security.
- Container security.
- Monitoring.
- Access restrictions.

Publishing a port is a connectivity decision and may also be a security decision.

## 11.4 Basic Security Principle

**Only publish ports that must be accessible from outside the relevant container network.**

Internal services should not automatically receive externally accessible host port mappings.

For example, an internal database may need to communicate with an application container without being directly accessible from the public internet.

This design principle will be developed during Lecture 10 and the Docker Compose lectures.

---

# 12. MULTIPLE CONTAINERS AND HOST PORT ALLOCATION

## 12.1 Independent Container Ports

Several containers can run applications that listen on the same internal port.

For example:

```text
Container A → TCP 8000
Container B → TCP 8000
Container C → TCP 8000
```

Each container may possess an independent network namespace.

The internal port numbers therefore do not necessarily conflict.

## 12.2 Host Port Uniqueness

Two containers ordinarily cannot both bind an incompatible published endpoint on the same host address, port, and transport protocol.

For example:

```text
127.0.0.1:8181/tcp
```

cannot normally be assigned to two independent container publishing operations at the same time.

## 12.3 Valid Configuration

```text id="0o8acm"
           DOCKER HOST
                |
      +---------+---------+
      |                   |
      v                   v
  Port 8181            Port 8182
      |                   |
      v                   v
 Container A          Container B
   Port 8000            Port 8000
      |                   |
      v                   v
   HTTP App             HTTP App
```

Both applications use internal port 8000.

Their published host ports differ.

## 12.4 Importance for Development

This capability allows developers to:

- Compare application versions.
- Run separate development environments.
- Operate multiple test configurations.
- Test application behavior under different environment variables.
- Develop several services on one machine.

---

# 13. INSPECTING PORT MAPPINGS

## 13.1 docker ps

The command:

```bash
docker ps
```

displays running containers and their published port information.

The `PORTS` column may show mappings such as:

```text
127.0.0.1:8181->8000/tcp
```

This indicates that host TCP port 8181 is mapped to container TCP port 8000.

## 13.2 docker port

Docker provides:

```bash
docker port CONTAINER
```

Example:

```bash
docker port my-application
```

The command lists published port mappings.

To inspect a specific container port:

```bash
docker port my-application 8000/tcp
```

## 13.3 docker inspect

Port mappings can also be examined through structured metadata.

Example:

```bash
docker inspect --format '{{json .NetworkSettings.Ports}}' my-application
```

This retrieves the network port information associated with the container.

## 13.4 Host Configuration Versus Network Settings

Docker inspection data contains different representations of network configuration.

`HostConfig.PortBindings` records requested host publishing configuration.

`NetworkSettings.Ports` provides information about the resulting port mappings.

These fields are related but should not be assumed to be identical in every situation.

---

# 14. INTRODUCTION TO ENVIRONMENT VARIABLES

## 14.1 Definition

An environment variable is a named value supplied to a process as part of its execution environment.

Operating systems use environment variables to communicate configuration information to programs.

Examples include:

```text
APP_MODE=development
APP_PORT=8000
LOG_LEVEL=info
```

The variable name identifies a configuration parameter.

Its value provides the selected configuration.

## 14.2 Process Environments

When an operating system starts a process, it supplies an execution environment containing zero or more variables.

A child process normally inherits an appropriate environment from its parent, subject to execution and operating-system rules.

Container runtimes establish an environment for the container's initial process.

This environment may include:

- Values defined by the image.
- Values supplied through Docker runtime options.
- Runtime-generated variables.
- Selected user configuration.

## 14.3 Application Configuration

Applications can read environment variables to determine their behavior.

For example, a Python application may use:

```python
import os

port = os.getenv("APP_PORT", "8000")
```

The program reads the variable named `APP_PORT`.

If the variable is unavailable, the specified default string is returned.

An application can therefore use different configurations without requiring separate source-code implementations.

---

# 15. WHY ENVIRONMENT VARIABLES MATTER IN DOCKER

## 15.1 Configuration Separation

Software applications commonly require environment-specific configuration.

For example:

**Development environment**

```text
APP_ENV=development
```

**Testing environment**

```text
APP_ENV=testing
```

**Production environment**

```text
APP_ENV=production
```

The application program may remain unchanged while its configuration differs.

## 15.2 One Image, Multiple Configurations

Consider a Docker image named:

`academic-api:v1`

The image can be used to create multiple containers.

Container A:

```text
APP_ENV=development
```

Container B:

```text
APP_ENV=testing
```

Container C:

```text
APP_ENV=production
```

All three containers originate from the same image.

Their application behavior may differ according to the variables supplied at runtime.

## 15.3 Architectural Significance

This design separates:

**Application artifact:** The packaged application image.

**Deployment configuration:** Values supplied to the container during creation.

The separation reduces the need to rebuild an image for every environment-specific configuration.

However, configuration values must still be validated, documented, and managed appropriately.

---

# 16. THE DOCKER RUN -e OPTION

## 16.1 Definition

Docker provides the runtime option:

`-e`

Its long form is:

`--env`

This option supplies environment variables to a newly created container.

## 16.2 Syntax

```text
docker run -e NAME=value IMAGE
```

Example:

```bash
docker run --rm \
  -e APP_ENV=testing \
  alpine:3.20 env
```

This starts a temporary Alpine container and displays its environment variables.

The supplied variable should appear as:

```text
APP_ENV=testing
```

## 16.3 Multiple Variables

Several variables can be supplied.

Example:

```bash
docker run --rm \
  -e APP_NAME=AcademicApplication \
  -e APP_ENV=development \
  alpine:3.20 env
```

Each `-e` option contributes an environment variable assignment.

## 16.4 Host Environment Inheritance

Docker also supports passing through a variable from the Docker client's local environment.

For example:

```text
-e APP_ENV
```

When the variable is available in the client's environment, Docker can pass the corresponding value.

This differs from explicitly assigning a value through:

```text
-e APP_ENV=testing
```

The latter specifies the container value directly.

---

# 17. THE DOCKERFILE ENV INSTRUCTION

## 17.1 Review

Lecture 06 introduced the Dockerfile instruction:

```dockerfile
ENV APP_ENV=development
```

This defines a default environment variable for the image.

The value is normally available to processes in containers created from that image.

## 17.2 Runtime Override

Suppose an image defines:

```dockerfile
ENV APP_ENV=development
```

A container may be created using:

```bash
docker run -e APP_ENV=testing IMAGE
```

The runtime value overrides the image's default value for that container.

The original image remains unchanged.

## 17.3 Comparison

| Configuration source  | Example                   | Principal effect                      |
| --------------------- | ------------------------- | ------------------------------------- |
| Dockerfile ENV        | `ENV APP_ENV=development` | Establishes image default             |
| Docker run -e         | `-e APP_ENV=testing`      | Supplies container-specific value     |
| Docker run --env-file | `--env-file config.env`   | Loads container variables from a file |
| Dockerfile ARG        | `ARG VERSION=1.0`         | Supplies build-time parameter         |

---

# 18. ENVIRONMENT VARIABLE PRECEDENCE

## 18.1 Definition of Precedence

Precedence refers to the rules used to determine which configuration value takes effect when multiple sources define the same parameter.

## 18.2 Image Defaults

An image may contain:

```text
APP_ENV=development
```

If no applicable runtime override is supplied, the image default normally remains effective.

## 18.3 Runtime Overrides

A container created with:

```text
-e APP_ENV=testing
```

receives the specified runtime value.

This takes precedence over the image's default.

## 18.4 Environment File Overrides

An environment file may also define:

```text
APP_ENV=staging
```

If supplied through `--env-file`, the value is applied to the container.

An explicit runtime `-e APP_ENV=testing` can override the corresponding file value.

## 18.5 Simplified Precedence Model

For an ordinary Docker run configuration:

```text id="mkn9o0"
        DOCKERFILE ENV DEFAULT
                 |
                 v
          ENV-FILE VALUE
                 |
                 v
       EXPLICIT -e OVERRIDE
                 |
                 v
      EFFECTIVE CONTAINER VALUE
```

This illustrates the conceptual precedence for the same variable.

When multiple definitions occur within the same source or command invocation, ordering and the documented CLI rules may also matter.

---

# 19. THE --ENV-FILE OPTION

## 19.1 Definition

Docker provides:

`--env-file`

This option reads environment variable assignments from a file and supplies them to a newly created container.

## 19.2 Example File

Create a file named:

`application.env`

With:

```text
APP_NAME=Academic HTTP Service
APP_ENV=staging
APP_PORT=8000
```

This file contains three variable assignments.

## 19.3 Using the File

```bash
docker run --env-file application.env IMAGE
```

Docker reads the selected file and applies the variables during container creation.

## 19.4 File Syntax

A Docker CLI environment file typically uses:

```text
NAME=value
```

Lines beginning with `#` may be used for comments.

For predictable behavior, keep values in simple assignment format.

Docker's `docker run --env-file` syntax should not automatically be assumed to support every interpolation and quoting feature available in Docker Compose or shell scripts.

## 19.5 Environment Files Versus Dockerfiles

An environment file is not a Dockerfile.

A Dockerfile describes image construction.

An environment file supplies configuration values to a container.

The two artifacts serve different engineering purposes.

## 19.6 Environment Files Versus Compose .env Files

Docker Compose also supports environment-related files and variable interpolation.

However, Docker CLI `--env-file` and Docker Compose's `.env` handling are not universally identical.

Their precedence and parsing rules should be examined according to the relevant tool.

Docker Compose environment handling will be studied during Lectures 11–13.

---

# 20. BUILD ARGUMENTS VERSUS RUNTIME ENVIRONMENT VARIABLES

## 20.1 Build Arguments

A Dockerfile build argument is defined using:

```dockerfile
ARG APP_VERSION=1.0
```

It can be supplied through:

```bash
docker build --build-arg APP_VERSION=2.0 .
```

The value affects applicable build operations.

It does not automatically become a runtime environment variable.

## 20.2 Runtime Variables

A runtime variable is supplied through Dockerfile `ENV`, `docker run -e`, or `--env-file`.

It becomes available to the corresponding container process environment.

## 20.3 Comparative Analysis

| Characteristic                     | ARG                              | ENV                                |
| ---------------------------------- | -------------------------------- | ---------------------------------- |
| Main purpose                       | Image construction parameter     | Process configuration              |
| Set during image build             | Yes                              | Defined by Dockerfile              |
| Available at runtime automatically | No                               | Yes                                |
| Runtime override with `-e`         | Not as ARG                       | Yes                                |
| Appropriate for secrets            | No                               | Not inherently                     |
| Can influence application behavior | Indirectly through build results | Directly when application reads it |

## 20.4 Engineering Principle

Build parameters should generally describe the construction process.

Runtime variables should generally describe the configuration required when the application executes.

Confusing these roles can produce images that behave unexpectedly or require unnecessary rebuilding.

---

# 21. ENVIRONMENT VARIABLES AND SECURITY

## 21.1 Security Risks

Environment variables are convenient but are not inherently confidential.

Their values may be accessible through:

- Docker inspection.
- Process environments.
- Diagnostic utilities.
- Application logs.
- Container administration interfaces.
- Error reporting systems.

## 21.2 Docker Inspect

Docker inspection output may reveal configured environment values.

Example:

```bash
docker inspect --format '{{json .Config.Env}}' my-container
```

If the container has sensitive values in its environment configuration, the output may expose them.

Therefore, complete inspection output should not be published without review.

## 21.3 Credentials and Secrets

Passwords, private keys, and authentication tokens require appropriate protection.

An application may need to obtain such values at runtime.

However, placing them directly into image configuration is undesirable.

For production systems, dedicated secret-management approaches are preferable.

These may include orchestrator-managed secrets, external secret stores, or appropriately protected mounted files.

## 21.4 Configuration Validation

Environment variables are generally supplied as strings.

Applications must validate their contents before using them.

For example:

```text
APP_PORT=abc
```

is not a valid numeric TCP port.

An application that attempts to interpret it as an integer may fail during startup.

Configuration validation is therefore an important part of application reliability.

---

# 22. CONTAINER CONFIGURATION AND IMMUTABILITY

## 22.1 Image Configuration

An image contains default configuration values.

Examples include:

- Environment variables.
- Startup executable.
- Default command.
- Working directory.
- User identity.
- Declared ports.

## 22.2 Container Creation Configuration

When a container is created, Docker combines the image defaults with runtime options.

Examples include:

- Host port mappings.
- Environment variable overrides.
- Network configuration.
- Mount definitions.
- Restart policies.

## 22.3 Configuration Persistence

An existing container retains its established creation configuration across ordinary stop and start operations.

For example, stopping and starting a container does not normally change its published host port or its initially configured environment variables.

## 22.4 Configuration Changes

To change a container's environment configuration or ordinary port publishing arrangement, a common approach is:

1. Stop the existing container.
2. Remove or replace it appropriately.
3. Create a new container using the desired configuration.

Some runtime settings can be updated through specialized Docker commands, but environment variables and ordinary port bindings are not generally changed through a simple container restart.

This reinforces the distinction between modifying an existing container's execution state and creating a new configured container instance.

---

# PART II — PRACTICAL APPLICATION DESIGN

# 23. LABORATORY PROJECT OVERVIEW

## 23.1 Project Title

**Configurable Containerized HTTP Service with Docker Port Publishing and Environment-Based Configuration**

## 23.2 Project Objective

The objective is to construct a small Python HTTP server that demonstrates:

1. Application listening ports.
2. Container network interfaces.
3. Host port publishing.
4. Environment variable defaults.
5. Runtime environment overrides.
6. Environment file configuration.
7. Multiple containers using the same image.
8. Configuration inspection.
9. Network troubleshooting.
10. Controlled container lifecycle management.

## 23.3 Application Selection

The project uses Python's standard library.

The server will be implemented using:

`http.server`

No external Python package installations are required.

This reduces dependency complexity and permits the laboratory to concentrate on Docker networking and runtime configuration.

## 23.4 Project Structure

```text id="1zdo55"
docker-lecture08/
├── Dockerfile
├── .dockerignore
├── app.py
└── laboratory.env
```

The Dockerfile defines the application image.

The Python program provides the HTTP server.

The environment file defines one runtime configuration.

---

# 24. APPLICATION ARCHITECTURE

```text id="9cq8if"
                 WEB BROWSER
                      |
                      v
           http://127.0.0.1:8181
                      |
                      v
              DOCKER HOST
                      |
             Host TCP Port 8181
                      |
                      v
              PORT PUBLISHING
                      |
                      v
           CONTAINER TCP PORT 8000
                      |
                      v
             PYTHON HTTP SERVER
                      |
              APPLICATION LOGIC
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       APP_NAME     APP_ENV     APP_PORT
          |           |           |
          +-----------+-----------+
                      |
                      v
                 HTTP RESPONSE
```

The application will retrieve its configuration from environment variables.

Different containers will use the same image while receiving different values.

---

# 25. APPLICATION SOURCE CODE

Create:

`app.py`

Insert:

```python
import json
import os
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


APP_NAME = os.getenv("APP_NAME", "Docker Academic Service")
APP_ENV = os.getenv("APP_ENV", "development")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
BIND_HOST = os.getenv("BIND_HOST", "0.0.0.0")


class RequestHandler(BaseHTTPRequestHandler):

    def respond(self, status, content_type, text):
        payload = text.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()

        self.wfile.write(payload)

    def do_GET(self):

        if self.path == "/health":
            self.respond(
                200,
                "text/plain; charset=utf-8",
                "OK"
            )
            return

        if self.path == "/config":
            configuration = {
                "application": APP_NAME,
                "environment": APP_ENV,
                "container_port": APP_PORT,
            }

            self.respond(
                200,
                "application/json; charset=utf-8",
                json.dumps(configuration, indent=2)
            )
            return

        if self.path == "/":

            document = f"""
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <title>Docker Lecture 08</title>
            </head>

            <body style="font-family: Arial; padding: 40px;">

                <h1>{escape(APP_NAME)}</h1>

                <h2>Docker Lecture 08</h2>

                <p>
                    Environment: {escape(APP_ENV)}
                </p>

                <p>
                    Container Port: {APP_PORT}
                </p>

                <p>
                    The application is configured
                    through environment variables.
                </p>

                <a href="/config">
                    View Application Configuration
                </a>

            </body>
            </html>
            """

            self.respond(
                200,
                "text/html; charset=utf-8",
                document
            )
            return

        self.send_error(404, "Resource Not Found")


if __name__ == "__main__":

    server = ThreadingHTTPServer(
        (BIND_HOST, APP_PORT),
        RequestHandler
    )

    print(
        f"Starting {APP_NAME} "
        f"in {APP_ENV} mode "
        f"on {BIND_HOST}:{APP_PORT}",
        flush=True
    )

    server.serve_forever()
```

## 25.1 Technical Analysis

The application reads four environment variables.

**APP_NAME**

Specifies the application name shown in HTTP responses.

**APP_ENV**

Specifies the logical deployment environment.

**APP_PORT**

Specifies the TCP port on which the server listens inside the container.

**BIND_HOST**

Specifies the IPv4 interface address used by the application server.

The application provides three HTTP endpoints.

**/**

Displays an HTML page.

**/config**

Returns non-sensitive application configuration as JSON.

**/health**

Returns a basic success response.

The `/config` endpoint is included for educational purposes and exposes only the harmless variables selected in the example.

Production applications should avoid exposing confidential runtime configuration through public endpoints.

---

# 26. DOCKERFILE CONSTRUCTION

Create:

`Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Lecture 08" \
      org.opencontainers.image.description="Networking and Environment Configuration Laboratory"

WORKDIR /app

ENV APP_NAME="Docker Academic Service" \
    APP_ENV=development \
    APP_PORT=8000 \
    BIND_HOST=0.0.0.0

COPY app.py /app/app.py

USER 10001:10001

EXPOSE 8000

CMD ["python", "-u", "app.py"]
```

## 26.1 Technical Explanation

`FROM` selects the Python runtime environment.

`LABEL` defines descriptive image metadata.

`WORKDIR` establishes `/app` as the application working directory.

`ENV` provides default runtime configuration.

`COPY` incorporates the Python application into the image.

`USER` configures non-root execution using numeric user and group identifiers.

`EXPOSE` declares the application's expected container TCP port.

`CMD` starts the Python HTTP server when the container runs.

The `-u` Python option enables unbuffered output, assisting the observation of application logs.

---

# 27. ENVIRONMENT FILE

Create:

`laboratory.env`

Insert:

```text
APP_NAME=Environment File Service
APP_ENV=staging
APP_PORT=8000
BIND_HOST=0.0.0.0
```

This file will be used to demonstrate external runtime configuration.

The values are deliberately non-sensitive.

---

# 28. DOCKERIGNORE CONFIGURATION

Create:

`.dockerignore`

Insert:

```dockerignore
.git
*.log
*.tar
__pycache__/
*.pyc
laboratory.env
```

The environment file is excluded from the image-building context because it is intended to configure containers at runtime rather than become part of the application image.

The file remains available locally for use with `docker run --env-file`.

---

# PART III — PRACTICAL LABORATORY 08

# 29. EXPERIMENT 1 — VERIFY DOCKER AVAILABILITY

Execute:

```bash
docker version
```

Then:

```bash
docker info
```

**Objective:**

Verify the Docker client and Docker Engine are functioning.

**Required observations:**

1. Record Docker client version.
2. Record Docker server version.
3. Identify the operating-system environment used by Docker Engine.
4. Confirm that the daemon is accessible.

---

# 30. EXPERIMENT 2 — BUILD THE APPLICATION IMAGE

From the project directory, execute:

```bash
docker build -t lecture08-http:v1 .
```

**Objective:**

Construct a reusable image containing the configurable Python HTTP service.

**Expected result:**

The build completes successfully.

Verify:

```bash
docker image ls lecture08-http
```

**Required observations:**

Record the image identifier and reported size.

---

# 31. EXPERIMENT 3 — RUN WITH DEFAULT ENVIRONMENT VARIABLES

Execute:

```bash
docker run -d \
  --name day08-default \
  -p 127.0.0.1:8181:8000 \
  lecture08-http:v1
```

Alternatively, enter the command on one line if your terminal does not support Unix-style continuation.

**Objective:**

Start the application using the environment values defined in the Dockerfile.

Open:

http://127.0.0.1:8181

**Expected result:**

The page displays:

- Application name: Docker Academic Service.
- Environment: development.
- Container port: 8000.

Open:

http://127.0.0.1:8181/config

**Expected result:**

A JSON document describing the non-sensitive application configuration is displayed.

**Required analysis:**

Explain why the application can receive HTTP requests through host port 8181 while listening on container port 8000.

---

# 32. EXPERIMENT 4 — INSPECT THE PUBLISHED PORT

Execute:

```bash
docker ps
```

Then:

```bash
docker port day08-default
```

Then:

```bash
docker inspect --format '{{json .NetworkSettings.Ports}}' day08-default
```

**Objective:**

Examine the relationship between requested port publishing and Docker's recorded network configuration.

**Required observations:**

1. Identify the container port.
2. Identify the published host port.
3. Identify the published host IP address.
4. Explain the meaning of `8000/tcp`.
5. Explain why the host and container port numbers differ.

---

# 33. EXPERIMENT 5 — RUN A SECOND CONFIGURATION

Execute:

```bash
docker run -d \
  --name day08-testing \
  -e APP_NAME="Testing Service" \
  -e APP_ENV=testing \
  -p 127.0.0.1:8182:8000 \
  lecture08-http:v1
```

**Objective:**

Demonstrate that a single image can produce containers with different environment configurations.

Open:

http://127.0.0.1:8182

**Expected result:**

The page displays:

- Application name: Testing Service.
- Environment: testing.
- Container port: 8000.

Compare it with:

http://127.0.0.1:8181

**Required analysis:**

Explain why the two containers display different configurations even though they were created from the same image.

---

# 34. EXPERIMENT 6 — COMPARE CONTAINER ENVIRONMENTS

Execute:

```bash
docker inspect --format '{{json .Config.Env}}' day08-default
```

Then:

```bash
docker inspect --format '{{json .Config.Env}}' day08-testing
```

**Objective:**

Compare the configured runtime environments of two containers.

**Expected result:**

The environment information contains different values for selected variables.

**Required analysis:**

Explain the distinction between:

1. Image environment defaults.
2. Container environment overrides.
3. Application source code.
4. Container runtime configuration.

---

# 35. EXPERIMENT 7 — RUN USING AN ENVIRONMENT FILE

Execute:

```bash
docker run -d \
  --name day08-envfile \
  --env-file laboratory.env \
  -p 127.0.0.1:8183:8000 \
  lecture08-http:v1
```

**Objective:**

Configure the application using an external file.

Open:

http://127.0.0.1:8183/config

**Expected result:**

The JSON response contains:

```json
{
  "application": "Environment File Service",
  "environment": "staging",
  "container_port": 8000
}
```

**Required analysis:**

Explain why the application image did not need to be rebuilt to use the staging configuration.

---

# 36. EXPERIMENT 8 — OVERRIDE AN ENVIRONMENT FILE VALUE

Execute:

```bash
docker run -d \
  --name day08-override \
  --env-file laboratory.env \
  -e APP_ENV=review \
  -p 127.0.0.1:8184:8000 \
  lecture08-http:v1
```

**Objective:**

Investigate configuration precedence.

Open:

http://127.0.0.1:8184/config

**Expected result:**

The application name originates from the environment file.

The effective environment value is:

`review`

because the explicit runtime override replaces the corresponding file value.

**Required analysis:**

Explain how image defaults, environment-file configuration, and explicit command-line overrides interact.

---

# 37. EXPERIMENT 9 — EXAMINE APPLICATION LOGS

Execute:

```bash
docker logs day08-default
```

Then:

```bash
docker logs --tail 20 day08-testing
```

**Objective:**

Inspect application startup and HTTP request information.

**Expected result:**

The logs contain startup information and may include HTTP request records.

**Required analysis:**

1. Identify the application listening address.
2. Identify the configured container port.
3. Explain why application logs assist network troubleshooting.
4. Explain why a running process can still be incorrectly configured.

---

# 38. EXPERIMENT 10 — EXPOSE WITHOUT PUBLISHING

Execute:

```bash
docker run -d \
  --name day08-unpublished \
  lecture08-http:v1
```

**Objective:**

Demonstrate the difference between an exposed container port and a published host port.

Verify:

```bash
docker ps
```

Then:

```bash
docker port day08-unpublished
```

**Expected result:**

The container is running.

Its image declares container port 8000.

However, no host port mapping was requested.

The `docker port` command should not show a published host endpoint for port 8000.

**Required analysis:**

Explain why `EXPOSE 8000` does not automatically make the application accessible through a specified host port.

---

# 39. EXPERIMENT 11 — INVESTIGATE CONTAINER LOOPBACK BINDING

Execute:

```bash
docker run -d \
  --name day08-loopback \
  -e BIND_HOST=127.0.0.1 \
  -p 127.0.0.1:8185:8000 \
  lecture08-http:v1
```

**Objective:**

Examine the effect of binding an application to the container's loopback interface.

Attempt to access:

http://127.0.0.1:8185

**Expected result under ordinary bridge-networked Docker configurations:**

The application may not be reachable through the published host endpoint.

Inspect its logs:

```bash
docker logs day08-loopback
```

The application should report that it started using:

`127.0.0.1:8000`

**Technical interpretation:**

The server is listening on the container's loopback interface.

The published host port ordinarily forwards traffic toward the container's network-facing address.

The service is not listening on that address.

**Required analysis:**

Explain why a host loopback binding and a container loopback binding are different networking concepts.

---

# 40. EXPERIMENT 12 — INVESTIGATE A PORT MISMATCH

Execute:

```bash
docker run -d \
  --name day08-wrong-port \
  -e APP_PORT=9000 \
  -p 127.0.0.1:8186:8000 \
  lecture08-http:v1
```

**Objective:**

Create a controlled networking configuration error.

The application is configured to listen on container TCP port 9000.

Docker is instructed to publish container TCP port 8000.

Attempt to open:

http://127.0.0.1:8186

**Expected result:**

The HTTP request does not reach the intended application successfully.

Inspect the logs:

```bash
docker logs day08-wrong-port
```

The application should report that it is listening on port 9000.

Inspect the mapping:

```bash
docker port day08-wrong-port
```

Docker should report a mapping to container port 8000.

**Required analysis:**

Identify the mismatch and explain why Docker port publishing does not automatically modify the application's listening configuration.

---

# 41. EXPERIMENT 13 — CORRECT THE PORT MISMATCH

Execute:

```bash
docker run -d \
  --name day08-correct-port \
  -e APP_PORT=9000 \
  -p 127.0.0.1:8187:9000 \
  lecture08-http:v1
```

**Objective:**

Correct the previous configuration error.

Open:

http://127.0.0.1:8187/config

**Expected result:**

The application responds successfully.

The displayed container port is:

`9000`

**Required analysis:**

Explain why both the application configuration and the Docker port mapping must refer to the intended internal listening port.

---

# 42. EXPERIMENT 14 — VERIFY PORT INDEPENDENCE

At this stage, several containers should be running using the same image.

Execute:

```bash
docker ps
```

**Objective:**

Compare their published endpoints.

**Required observations:**

| Container          | Host port | Container port | Configuration |
| ------------------ | --------: | -------------: | ------------- |
| day08-default      |      8181 |           8000 | development   |
| day08-testing      |      8182 |           8000 | testing       |
| day08-envfile      |      8183 |           8000 | staging       |
| day08-override     |      8184 |           8000 | review        |
| day08-correct-port |      8187 |           9000 | development   |

**Required analysis:**

Explain why several applications can use the same container port while remaining accessible through different host ports.

---

# 43. EXPERIMENT 15 — VERIFY CONTAINER CONFIGURATION PERSISTENCE

Stop:

```bash
docker stop day08-testing
```

Start:

```bash
docker start day08-testing
```

Open:

http://127.0.0.1:8182/config

**Expected result:**

The application still uses:

```text
APP_NAME=Testing Service
APP_ENV=testing
APP_PORT=8000
```

**Technical interpretation:**

The existing container retains its creation configuration across normal stop and start operations.

**Required analysis:**

Explain why stopping and restarting a container does not automatically restore its environment variables to the Dockerfile defaults.

---

# 44. EXPERIMENT 16 — EXAMINE AN APPLICATION CONFIGURATION ERROR

Create another container:

```bash
docker run \
  --name day08-invalid \
  -e APP_PORT=invalid \
  lecture08-http:v1
```

**Objective:**

Investigate application-level configuration validation.

**Expected result:**

The Python program fails when attempting to convert the invalid port string into an integer.

The container exits.

Inspect:

```bash
docker ps -a
```

Then:

```bash
docker logs day08-invalid
```

**Required analysis:**

1. Identify the application error.
2. Explain why Docker accepted the environment variable assignment.
3. Explain why applications must validate environment variable values.
4. Describe the relationship between process failure and container lifecycle termination.

---

# 45. EXPERIMENT 17 — OPTIONAL HOST PORT CONFLICT

This experiment is optional and should be performed only in the controlled local laboratory.

The existing container `day08-default` uses:

`127.0.0.1:8181/tcp`

Attempt to create another container using the same host endpoint:

```bash
docker run -d \
  --name day08-conflict \
  -p 127.0.0.1:8181:8000 \
  lecture08-http:v1
```

**Expected result:**

Docker reports a port allocation or binding conflict.

Depending on the failure stage, a container object may remain and require cleanup.

**Required analysis:**

Explain why identical internal container port numbers are permissible while conflicting host port bindings are not.

---

# 46. EXPERIMENT 18 — CONTROLLED LABORATORY CLEANUP

Stop the running laboratory containers:

```bash
docker stop \
  day08-default \
  day08-testing \
  day08-envfile \
  day08-override \
  day08-unpublished \
  day08-loopback \
  day08-wrong-port \
  day08-correct-port
```

Remove those containers:

```bash
docker rm \
  day08-default \
  day08-testing \
  day08-envfile \
  day08-override \
  day08-unpublished \
  day08-loopback \
  day08-wrong-port \
  day08-correct-port \
  day08-invalid
```

If the optional conflict experiment left a `day08-conflict` container object, inspect and remove that object separately.

Verify:

```bash
docker ps -a
```

The laboratory image can remain available for later experiments.

**Safety requirement:**

Do not execute global container-pruning commands on a system containing unrelated workloads.

---

# PART IV — SYSTEMATIC TROUBLESHOOTING

# 47. ERROR CATEGORY: CONNECTION REFUSED

## 47.1 Description

A connection-refused error commonly indicates that a network endpoint was reached but no suitable service accepted the connection.

Possible causes include:

- Application not running.
- Incorrect application listening port.
- Incorrect bind address.
- Incorrect port mapping.
- Application startup failure.

## 47.2 Investigation

Execute:

```bash
docker ps -a
```

Then:

```bash
docker logs CONTAINER_NAME
```

Then:

```bash
docker port CONTAINER_NAME
```

Compare the application listening configuration with the Docker port mapping.

---

# 48. ERROR CATEGORY: HOST PORT ALREADY ALLOCATED

## 48.1 Description

Docker cannot establish a host port binding because an incompatible endpoint is already occupied.

## 48.2 Investigation

Examine existing containers:

```bash
docker ps
```

Determine whether the requested host port is already published.

If appropriate, select a different host port.

For example:

```text
8188:8000
```

instead of:

```text
8181:8000
```

Avoid terminating unrelated applications simply to free a port.

---

# 49. ERROR CATEGORY: CONTAINER RUNNING BUT UNREACHABLE

## 49.1 Description

A container appears in the running state but its application cannot be reached through the expected host endpoint.

## 49.2 Possible Causes

1. No host port was published.
2. Incorrect host port.
3. Incorrect container port.
4. Application bound only to container loopback.
5. Application listening on another protocol.
6. Firewall restrictions.
7. Docker network configuration problems.
8. Application-level failure.

## 49.3 Diagnostic Procedure

1. Confirm that the container is running.
2. Retrieve its logs.
3. Inspect the application listening configuration.
4. Verify the published port.
5. Verify the selected transport protocol.
6. Test the expected endpoint.
7. Inspect the relevant network configuration.

---

# 50. ERROR CATEGORY: ENVIRONMENT VARIABLE NOT APPLIED

## 50.1 Description

The container does not use the expected runtime configuration.

## 50.2 Possible Causes

- Incorrect variable name.
- Incorrect environment file path.
- Typographical error.
- Dockerfile default not overridden.
- Unexpected precedence.
- Application does not read the variable.
- Application reads configuration only at startup.
- Incorrect container instance being inspected.

## 50.3 Investigation

Inspect the container's configured environment:

```bash
docker inspect --format '{{json .Config.Env}}' CONTAINER_NAME
```

This command may reveal sensitive values.

Use it only in an appropriately controlled environment and avoid exposing its output publicly.

Then examine the application's configuration-loading logic.

---

# 51. ERROR CATEGORY: ENVIRONMENT FILE NOT FOUND

## 51.1 Description

Docker cannot locate the file supplied through `--env-file`.

## 51.2 Possible Causes

- Incorrect filename.
- Incorrect relative path.
- Incorrect working directory.
- Missing file.
- File permissions.

## 51.3 Investigation

Verify the local file's existence.

Use an appropriate relative or absolute path.

Remember that `--env-file` identifies a file accessed by the Docker client during container creation.

It does not automatically refer to a file inside the container image.

---

# 52. ERROR CATEGORY: INVALID PORT VARIABLE

## 52.1 Description

The application exits because its configured port value cannot be interpreted correctly.

## 52.2 Example

```text
APP_PORT=hello
```

The application expects an integer port value.

If it cannot convert the supplied string into a valid port number, startup may fail.

## 52.3 Technical Principle

Docker transports environment variable values.

The application is responsible for interpreting and validating those values.

Docker does not automatically know the semantic requirements of every application configuration parameter.

---

# PART V — ACADEMIC ANALYSIS

# 53. PORT PUBLISHING VERSUS INTERNAL CONTAINER COMMUNICATION

## 53.1 Published Communication

Published ports provide access through host network endpoints.

Example:

```text
Host:8181 → Container:8000
```

This is appropriate when an external client must access a containerized application through the host.

## 53.2 Internal Communication

Two containers connected to a suitable Docker network can communicate using their network connectivity without necessarily publishing their services on the host.

For example:

```text id="o7rs12"
      APPLICATION CONTAINER
               |
               |
         DOCKER NETWORK
               |
               v
        DATABASE CONTAINER
```

The application may contact a database using its internal network endpoint.

The database does not necessarily require an externally published host port.

## 53.3 Architectural Importance

Minimizing unnecessary host port publishing can reduce external exposure and clarify application communication boundaries.

This principle becomes increasingly important in multi-container applications.

The design and configuration of user-defined Docker networks will be examined comprehensively in Lecture 10.

---

# 54. DOCKER DESKTOP NETWORKING CONSIDERATIONS

## 54.1 Virtualized Execution Environments

On Windows and macOS, Docker Desktop ordinarily uses a Linux execution environment provided through virtualization mechanisms.

Consequently, the Docker Engine may operate inside a lightweight Linux virtual machine.

Docker Desktop provides networking integration between containers and the desktop host.

## 54.2 Host Access

Published container ports can ordinarily be accessed from the desktop host through the configured host endpoint.

For example:

`http://127.0.0.1:8181`

## 54.3 Accessing Host Services from Containers

Docker Desktop supports the special hostname:

`host.docker.internal`

This hostname can be used by containers to reach suitable services on the host.

For Docker Engine installations on Linux, equivalent behavior may require additional configuration, such as a supported host-gateway mapping.

## 54.4 Important Distinction

The hostname `host.docker.internal` is not equivalent to ordinary container `localhost`.

`localhost` refers to the container's own loopback interface.

`host.docker.internal` is a special mechanism for accessing the host environment on supported Docker configurations.

The details of container-to-host and container-to-container networking will be examined further in Lecture 10.

---

# 55. IMPORTANT COMMAND REFERENCE

| Command or option       | Purpose                                                    |
| ----------------------- | ---------------------------------------------------------- |
| `docker run -p`         | Publish a container port                                   |
| `docker run --publish`  | Long form of port publishing                               |
| `docker run -P`         | Publish exposed ports to automatically selected host ports |
| `docker run --expose`   | Declare an exposed container port                          |
| `docker run -e`         | Supply a runtime environment variable                      |
| `docker run --env-file` | Load runtime variables from a file                         |
| `docker ps`             | Examine running containers and published ports             |
| `docker port`           | Display container port mappings                            |
| `docker inspect`        | Examine container configuration and networking metadata    |
| `docker logs`           | Retrieve available application logs                        |
| `docker exec`           | Execute a command inside a running container               |
| `docker stop`           | Stop a container                                           |
| `docker start`          | Start an existing container                                |
| `docker rm`             | Remove a container                                         |
| `docker image inspect`  | Examine image defaults and metadata                        |

---

# 56. IMPORTANT TECHNICAL TERMINOLOGY

| Term                     | Academic definition                                                |
| ------------------------ | ------------------------------------------------------------------ |
| TCP/IP                   | Protocol suite supporting internet communication                   |
| IPv4                     | Internet Protocol using 32-bit addresses                           |
| IPv6                     | Internet Protocol using 128-bit addresses                          |
| TCP                      | Connection-oriented transport protocol                             |
| UDP                      | Datagram-oriented transport protocol                               |
| Port number              | Transport-layer endpoint identifier                                |
| Network endpoint         | Address and transport-port combination                             |
| Network namespace        | Isolated view of networking resources                              |
| Bridge network           | Network providing connectivity among attached containers           |
| Loopback interface       | Interface for communication within a local network namespace       |
| Localhost                | Hostname conventionally resolving to loopback addresses            |
| Bind address             | Local address on which an application accepts connections          |
| Host port                | Published endpoint port on the Docker host                         |
| Container port           | Port used by an application within the container                   |
| Port publishing          | Making a container service accessible through a host endpoint      |
| NAT                      | Network Address Translation                                        |
| PAT                      | Port Address Translation                                           |
| Inbound traffic          | Traffic entering a networked environment                           |
| Outbound traffic         | Traffic initiated toward another network endpoint                  |
| EXPOSE                   | Image instruction declaring an intended container port             |
| Environment variable     | Named configuration value supplied to a process                    |
| Runtime configuration    | Settings applied when a container is created or executed           |
| ENV                      | Dockerfile instruction establishing environment variables          |
| ARG                      | Dockerfile build-time variable declaration                         |
| Environment file         | File containing variable assignments for runtime configuration     |
| Configuration precedence | Rules determining effective values from multiple sources           |
| Configuration validation | Verification that supplied values satisfy application requirements |
| Host interface           | Network interface associated with the host environment             |
| Container interface      | Network interface within a container network namespace             |
| Port conflict            | Incompatible attempts to bind the same network endpoint            |
| External exposure        | Availability of a service to clients outside its intended boundary |

---

# PART VI — FORMAL ACADEMIC ASSESSMENT

# 57. PART A — DEFINITION QUESTIONS

Provide technically precise definitions for:

1. Network namespace.
2. TCP.
3. UDP.
4. Host port.
5. Container port.
6. Port publishing.
7. Loopback interface.
8. Network Address Translation.
9. Environment variable.
10. Runtime configuration.
11. Environment file.
12. Configuration precedence.
13. Application bind address.
14. Docker bridge network.
15. Container-to-host communication.

---

# 58. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why applications inside Docker containers require networking configuration.

**Question 2.**

Distinguish between a container port and a host port.

**Question 3.**

Explain the difference between `127.0.0.1` and `0.0.0.0` when used as application bind addresses.

**Question 4.**

Explain why `localhost` inside an ordinary bridge-networked container does not refer to the host's loopback interface.

**Question 5.**

Describe the role of Docker bridge networking.

**Question 6.**

Explain how port publishing allows a browser on the host to access a containerized web server.

**Question 7.**

Distinguish between the Dockerfile `EXPOSE` instruction and the `docker run -p` option.

**Question 8.**

Explain why two containers may use the same internal port without producing a conflict.

**Question 9.**

Describe why two containers generally cannot publish conflicting host endpoints.

**Question 10.**

Explain the purpose of the `docker port` command.

**Question 11.**

Describe how environment variables influence application behavior.

**Question 12.**

Explain how runtime environment variables differ from Dockerfile build arguments.

**Question 13.**

Describe the purpose of `--env-file`.

**Question 14.**

Explain why an existing container's environment variables are normally not changed through a simple restart.

**Question 15.**

Describe the security implications of exposing sensitive configuration through environment variables.

---

# 59. PART C — COMMAND INTERPRETATION

Consider:

```bash
docker run -d \
  --name academic-server \
  -p 127.0.0.1:8181:8000 \
  -e APP_ENV=testing \
  lecture08-http:v1
```

Answer:

1. What operation does Docker perform?
2. What is the container name?
3. What is the image reference?
4. What execution mode is requested?
5. Which host address is used?
6. Which host port is published?
7. Which container port receives the traffic?
8. What is the intended transport protocol?
9. Which environment variable is overridden?
10. What command can display the container's published port mapping?

---

# 60. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Incorrect Listening Address

A developer starts a web server inside a container using:

```text
127.0.0.1:8000
```

Docker publishes:

```text
127.0.0.1:8181:8000
```

The developer cannot access the application through the host port.

Analyze the problem.

Explain the difference between the application's listening interface and Docker's published host interface.

Propose an appropriate correction.

## Case Study 2 — Multiple Application Configurations

An organization uses a single Docker image to operate development, testing, and staging containers.

Each environment requires different configuration values.

Explain how environment variables and environment files can support this architecture.

Discuss the benefits and operational limitations.

## Case Study 3 — Port Publishing Security

A developer publishes an internal administration interface using:

```bash
docker run -p 9000:9000 IMAGE
```

The developer expects the interface to be reachable only from the local computer.

Evaluate whether this assumption is technically justified.

Recommend an appropriate local-development binding configuration.

## Case Study 4 — Container Configuration Persistence

A developer creates a container using:

```text
APP_ENV=testing
```

Later, the developer modifies the environment file to contain:

```text
APP_ENV=production
```

The developer restarts the existing container.

The application still reports:

```text
APP_ENV=testing
```

Explain the behavior.

Describe an appropriate procedure for applying the new runtime configuration.

## Case Study 5 — Incorrect Internal Port

An application listens on TCP port 9000.

Docker publishes host port 8181 to container port 8000.

The container remains running but the application cannot be reached through the host port.

Analyze the error.

Explain why running status does not establish correct networking behavior.

---

# 61. PRACTICAL ASSESSMENT

The practical assessment evaluates the student's ability to configure and investigate a containerized HTTP service.

**Total available marks: 100**

| Category                                |   Marks |
| --------------------------------------- | ------: |
| Networking theory                       |      15 |
| Port publishing and inspection          |      20 |
| Environment variable configuration      |      20 |
| Application construction and execution  |      20 |
| Troubleshooting and analysis            |      15 |
| Documentation and technical explanation |      10 |
| **Total**                               | **100** |

**Recommended completion standard:** 80/100.

The student should demonstrate correct execution and technical understanding.

Successful commands without the ability to explain their effects do not establish complete competence.

---

# 62. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Docker Networking and Runtime Configuration

Prepare an academic report of approximately 1,000–1,500 words addressing:

**“Port Publishing and Environment-Based Application Configuration in Docker Container Environments.”**

The report must contain:

1. An introduction to container networking.
2. An explanation of TCP/IP ports and endpoints.
3. A description of Docker network namespaces.
4. An explanation of bridge networking.
5. A technical analysis of host and container ports.
6. An examination of Docker port publishing.
7. A comparison of `EXPOSE`, `-p`, and `-P`.
8. A discussion of localhost and container interface binding.
9. An explanation of environment variable configuration.
10. A comparison of `ENV`, `ARG`, `-e`, and `--env-file`.
11. An analysis of configuration precedence.
12. A discussion of networking and configuration security.
13. An explanation of the implemented Python application.
14. A technical evaluation of the laboratory results.
15. A conclusion identifying the engineering principles learned.

The report should contain at least one networking architecture diagram and several relevant Docker commands.

---

# 63. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 09, the student should be able to complete the following tasks independently.

## Networking Concepts

- [ ] Define TCP and UDP.
- [ ] Explain IP addresses and port numbers.
- [ ] Explain network endpoints.
- [ ] Describe a network namespace.
- [ ] Explain container loopback interfaces.
- [ ] Distinguish host localhost from container localhost.
- [ ] Explain Docker bridge networking.
- [ ] Distinguish inbound and outbound communication.
- [ ] Explain the purpose of port publishing.

## Port Publishing

- [ ] Interpret `HOST_PORT:CONTAINER_PORT`.
- [ ] Publish a TCP port.
- [ ] Recognize UDP port publishing syntax.
- [ ] Restrict a published port to host loopback.
- [ ] Explain `EXPOSE`.
- [ ] Explain `--expose`.
- [ ] Explain `-p`.
- [ ] Explain `-P`.
- [ ] Inspect mappings using `docker port`.
- [ ] Inspect mappings using `docker inspect`.
- [ ] Run two containers using the same internal port.
- [ ] Diagnose a host port conflict.
- [ ] Diagnose an incorrect container port mapping.
- [ ] Explain why an application must listen on an appropriate container interface.

## Environment Configuration

- [ ] Define an environment variable.
- [ ] Explain the Dockerfile `ENV` instruction.
- [ ] Override an environment variable using `-e`.
- [ ] Create a valid environment file.
- [ ] Use `--env-file`.
- [ ] Explain variable precedence.
- [ ] Distinguish `ARG` from `ENV`.
- [ ] Explain why runtime configuration does not necessarily require rebuilding an image.
- [ ] Inspect container environment configuration.
- [ ] Explain environment variable security considerations.
- [ ] Validate application configuration values.

## Practical Application

- [ ] Create the Python HTTP application.
- [ ] Construct the application Dockerfile.
- [ ] Build the custom image.
- [ ] Run the application with default configuration.
- [ ] Access the application through a browser.
- [ ] Run a second container using different environment values.
- [ ] Run a container using an environment file.
- [ ] Demonstrate configuration precedence.
- [ ] Investigate an unpublished port.
- [ ] Investigate container loopback binding.
- [ ] Investigate an incorrect port mapping.
- [ ] Correct the port mapping.
- [ ] Inspect application logs.
- [ ] Explain configuration persistence across restart.
- [ ] Investigate invalid environment values.
- [ ] Complete the laboratory report.

**Completion standard:**

The student should be able to construct a network-accessible containerized application, configure its runtime behavior independently of the image, and diagnose elementary connectivity and configuration failures.

---

# 64. LECTURE SUMMARY

Docker networking provides mechanisms for communication between containerized applications and external systems.

Linux network namespaces allow containers to operate with network interfaces, addresses, routing information, and loopback environments that are separate from those of the host.

Docker bridge networking provides connectivity among containers and their associated host networking infrastructure.

Port publishing establishes mappings between selected host endpoints and ports used by applications inside containers.

The `-p` option creates an explicit mapping.

The `-P` option publishes declared exposed ports through automatically selected host ports.

The `EXPOSE` instruction declares an expected container port but does not independently publish a host endpoint.

Understanding the distinction between host ports and container ports is essential for correct network configuration.

The difference between `127.0.0.1` and `0.0.0.0` is equally important because application interface binding determines which network interfaces can accept connections.

Environment variables provide a mechanism for configuring applications without modifying their source code or rebuilding their images.

Dockerfile `ENV` instructions establish defaults.

Runtime `-e` options and environment files can provide container-specific values.

Runtime configuration is generally established during container creation and retained during ordinary stop and start operations.

Configuration data must be validated and handled securely.

The practical laboratory demonstrates that one Docker image can support multiple containers operating with different configurations and published host ports.

**The central principle of this lecture is that application packaging, container networking, and runtime configuration are separate engineering concerns that must be coordinated for reliable containerized application operation.**

---

# 65. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. _Port Publishing and Mapping._  
https://docs.docker.com/engine/network/port-publishing/

[2] Docker Inc. _Docker Container Run._  
https://docs.docker.com/reference/cli/docker/container/run/

[3] Docker Inc. _Docker Container Port._  
https://docs.docker.com/reference/cli/docker/container/port/

[4] Docker Inc. _Bridge Network Driver._  
https://docs.docker.com/engine/network/drivers/bridge/

[5] Docker Inc. _Docker Networking Overview._  
https://docs.docker.com/engine/network/

[6] Docker Inc. _Networking on Docker Desktop._  
https://docs.docker.com/desktop/features/networking/

[7] Docker Inc. _Networking How-Tos on Docker Desktop._  
https://docs.docker.com/desktop/features/networking/networking-how-tos/

[8] Docker Inc. _Dockerfile Reference._  
https://docs.docker.com/reference/dockerfile/

[9] Docker Inc. _Build Variables._  
https://docs.docker.com/build/building/variables/

[10] Docker Inc. _Docker Container Inspect._  
https://docs.docker.com/reference/cli/docker/container/inspect/

[11] Docker Inc. _Build Secrets._  
https://docs.docker.com/build/building/secrets/

[12] Docker Inc. _Docker Compose Environment Variables._  
https://docs.docker.com/compose/how-tos/environment-variables/

## Recommended Reading Sequence

Begin with references [1] and [2] to establish a detailed understanding of Docker port publishing and runtime command options.

Continue with references [3] and [4] to examine inspection operations and bridge networking.

References [6] and [7] explain the networking differences introduced by Docker Desktop.

References [8] and [9] provide the foundation for understanding Dockerfile defaults and runtime configuration.

Reference [11] introduces the security considerations associated with configuration values.

Reference [12] prepares students for the more advanced environment-management mechanisms introduced with Docker Compose.

---

# 66. FINAL LECTURE CONCLUSION

The ability to connect containerized applications to their users and supporting services is a fundamental requirement of modern software engineering.

Docker's networking model introduces isolation boundaries that distinguish a container's internal network environment from its host's network environment.

These boundaries improve separation between application workloads but require explicit configuration when external access is necessary.

Port publishing provides a mechanism for establishing that communication.

A developer must understand the relationship between application listening ports, container interfaces, published host addresses, and transport protocols.

Incorrect configuration of any of these elements can prevent a functioning application from being accessible.

Runtime environment variables introduce a second major capability: the separation of application configuration from application packaging.

An image can contain a standardized application environment while separate container instances receive different runtime values.

This enables controlled configuration across development, testing, staging, and production environments.

However, configuration flexibility introduces responsibilities concerning validation, precedence, confidentiality, and deployment consistency.

The laboratory demonstrates how one Python HTTP server image can produce several independently configured containers.

It also demonstrates that container startup success does not necessarily establish correct network connectivity or valid application configuration.

Effective Docker administration therefore requires systematic inspection of processes, environment values, application listening behavior, port mappings, and logs.

These concepts establish the necessary foundation for persistent storage and multi-container networking.

---

**END OF LECTURE 08**

**Next Lecture:** Lecture 09 — Docker Storage and Data Persistence: Container Writable Layers, Volumes, Bind Mounts, Data Lifecycle, and Backup Fundamentals.
