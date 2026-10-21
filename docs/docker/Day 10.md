# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 10 — DOCKER NETWORKING ARCHITECTURE: BRIDGE NETWORKS, NETWORK ISOLATION, CONTAINER DNS, SERVICE DISCOVERY, AND INTER-CONTAINER COMMUNICATION

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 10 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Lecture 01 — Docker Architecture and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Container Inspection and Diagnostics.
- Lecture 04 — Docker Images and Registries.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Configuration.
- Lecture 07 — Week One Comprehensive Review.
- Lecture 08 — Port Publishing and Environment Variables.
- Lecture 09 — Persistent Storage and Docker Volumes.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define container networking and explain its importance in multi-container applications.
2. Describe how Linux network namespaces provide isolated networking environments.
3. Explain the roles of virtual Ethernet interfaces and Linux bridges.
4. Distinguish Docker's default bridge from user-defined bridge networks.
5. Describe the principal Docker network drivers.
6. Explain the purpose of Docker's network management subsystem.
7. Create and inspect Docker networks.
8. Connect containers to specific networks.
9. Explain how containers communicate using IP addresses.
10. Describe the purpose of the Docker embedded DNS resolver.
11. Explain how container names can function as network-resolvable hostnames.
12. Distinguish network-scoped DNS resolution from host-level DNS resolution.
13. Define service discovery and explain its role in containerized systems.
14. Configure and examine network aliases.
15. Describe the relationship between container network identity and container IP addresses.
16. Explain why container IP addresses should not ordinarily be hard-coded into application configuration.
17. Explain the difference between internal container communication and host port publishing.
18. Describe network isolation between separate user-defined bridge networks.
19. Attach a running container to an additional Docker network.
20. Disconnect a container from a network.
21. Explain how multi-homed containers participate in more than one network.
22. Describe Docker's host, none, overlay, macvlan, and ipvlan networking modes conceptually.
23. Explain basic network address management.
24. Identify networking security boundaries and limitations.
25. Investigate container DNS configuration.
26. Diagnose common inter-container communication failures.
27. Establish communication between a Redis server and a Redis client container.
28. Demonstrate HTTP communication between Nginx and a temporary client container.
29. Explain how Docker networking supports multi-container application architecture.
30. Complete a structured practical laboratory and defend the resulting architecture.

---

# 2. INTRODUCTION TO MULTI-CONTAINER NETWORKING

## 2.1 Background

Applications rarely operate as completely isolated software systems.

A modern application may depend on several cooperating components.

Examples include:

- An HTTP web server.
- An application backend.
- A relational database.
- A cache.
- A message queue.
- A background worker.
- An authentication service.
- A monitoring service.

In a containerized architecture, these components may execute in separate containers.

Each container has an independent process lifecycle and, under ordinary bridge networking, its own networking environment.

For the application to function, the components must exchange information through correctly configured communication channels.

Docker networking provides mechanisms for organizing these relationships.

## 2.2 Definition of Inter-Container Communication

Inter-container communication is the exchange of information between processes executing in separate container environments.

The exchange may occur through:

- TCP connections.
- UDP datagrams.
- Application-layer protocols.
- Unix domain sockets, where appropriately shared.
- Other supported communication mechanisms.

This lecture focuses primarily on communication over Docker-managed IP networks.

## 2.3 Example: A Three-Service Application

Consider an application containing:

1. A frontend server.
2. An application backend.
3. A database.

A simplified architecture is:

```text
                 CLIENT BROWSER
                       |
                       v
                 WEB FRONTEND
                       |
                       v
                APPLICATION API
                       |
                       v
                    DATABASE
```

The frontend receives client requests.

The application backend implements business logic.

The database stores the application data.

In a Docker deployment, each component may execute in a separate container.

The containers require connectivity, but not every component requires direct access from outside the Docker environment.

## 2.4 Architectural Principle

An application component should receive the network connectivity necessary for its function.

A database normally needs to accept connections from authorized application components.

It does not necessarily need to be accessible directly from the internet.

This distinction supports both application organization and network security.

---

# 3. FUNDAMENTAL NETWORKING CONCEPTS

## 3.1 Internet Protocol Addresses

An IP address identifies a network endpoint within an IP addressing and routing system.

Docker commonly assigns IP addresses to containers attached to bridge networks.

An illustrative container address is:

```text
172.18.0.2
```

This address is only an example.

Actual addressing depends on the Docker Engine configuration and network allocation.

## 3.2 Subnets

A subnet identifies a defined portion of an IP address space.

For IPv4 networks, a subnet is commonly represented using Classless Inter-Domain Routing notation.

For example:

```text
172.18.0.0/16
```

The suffix `/16` indicates the length of the network prefix.

Docker can allocate container addresses from a subnet associated with a selected network.

## 3.3 Network Gateways

A gateway is a network endpoint through which traffic may be forwarded toward other networks.

Docker bridge networks commonly provide a gateway associated with the Docker host's networking infrastructure.

The gateway helps support routing beyond the local container network when such communication is permitted.

## 3.4 Transport-Layer Ports

An IP address identifies a network endpoint.

A transport-layer port distinguishes a service or communication endpoint associated with that address.

Examples include:

- HTTP over TCP port 80.
- Redis over TCP port 6379.
- PostgreSQL over TCP port 5432.

A container may provide multiple services on different ports.

## 3.5 Network Communication Requirements

Successful communication generally requires:

1. A destination address or hostname.
2. A destination port.
3. A compatible transport protocol.
4. A functioning network route.
5. Permission for the traffic to pass through relevant network controls.
6. An application listening on the expected endpoint.
7. Compatible application-layer communication.

Network connectivity alone does not guarantee successful application interaction.

---

# 4. LINUX NETWORK NAMESPACES

## 4.1 Definition

A Linux network namespace provides an isolated view of networking resources.

These resources include:

- Network interfaces.
- IP addresses.
- Routing tables.
- Network-related kernel state.
- Socket-related network configuration.
- Selected firewall and connection-tracking resources.

The isolation allows processes in different namespaces to use distinct network configurations while sharing the same Linux kernel.

## 4.2 Container Network Isolation

Under ordinary bridge networking, each Docker container receives a separate network namespace.

The container may have:

- A loopback interface.
- An Ethernet-like virtual interface.
- An assigned IP address.
- A routing table.
- DNS configuration.

The application inside the container sees its network environment rather than the complete host networking environment.

## 4.3 Namespace Architecture

```text
                   LINUX HOST
                       |
       +---------------+---------------+
       |               |               |
       v               v               v
   HOST NETWORK     CONTAINER A     CONTAINER B
    NAMESPACE        NAMESPACE       NAMESPACE
       |               |               |
       v               v               v
 Host Interfaces    Interface A     Interface B
 Host Routes        Routes A        Routes B
 Host Loopback      Loopback A      Loopback B
```

## 4.4 Network Namespace Consequences

Container A can have an application listening on TCP port 8000.

Container B can independently have an application listening on TCP port 8000.

The identical port numbers do not necessarily conflict because they exist in different network namespaces.

This behavior was introduced through port-publishing examples in Lecture 08.

## 4.5 Loopback Isolation

The address:

```text
127.0.0.1
```

refers to the local IPv4 loopback interface of the current network namespace.

Therefore, a connection from Container A to `127.0.0.1` does not ordinarily connect to Container B.

The destination remains within Container A's namespace.

For communication with Container B, Container A normally uses a network address or hostname associated with Container B.

---

# 5. VIRTUAL ETHERNET INTERFACES

## 5.1 Definition

A virtual Ethernet interface, commonly called a veth interface, is a Linux networking device used to connect networking environments.

A veth pair behaves conceptually like two linked Ethernet endpoints.

Traffic transmitted through one endpoint can be received through the other.

## 5.2 Container Connections

In a conventional Linux bridge-based Docker network, one end of a veth pair is associated with the container's network namespace.

The other end is associated with the host-side networking infrastructure.

This creates a communication path between the container and the Docker network.

## 5.3 Simplified Architecture

```text
            CONTAINER NAMESPACE
                     |
                     v
                  eth0
                     |
                     v
                VETH PAIR
                     |
                     v
           HOST-SIDE INTERFACE
                     |
                     v
                LINUX BRIDGE
```

## 5.4 Significance

The virtual interface allows the container to participate in network communication without requiring a dedicated physical network adapter.

Several containers can use separate virtual interfaces connected to a common virtual bridge.

The actual interface names and implementation details depend on Docker and Linux configuration.

---

# 6. LINUX BRIDGES

## 6.1 Definition

A network bridge connects network interfaces and forwards traffic according to link-layer forwarding mechanisms.

A Linux bridge is a software implementation of bridging functionality.

In a conventional Docker bridge network, the bridge provides connectivity among attached container interfaces.

## 6.2 Simplified Bridge Architecture

```text
               DOCKER HOST
                    |
               LINUX BRIDGE
                    |
       +------------+------------+
       |            |            |
       v            v            v
   Container A  Container B  Container C
```

## 6.3 Communication Through a Bridge

When Container A communicates with Container B on the same suitable bridge network, traffic travels through the networking infrastructure connecting their virtual interfaces.

The Linux kernel performs the applicable forwarding and delivery operations.

This communication does not ordinarily require a host-published port.

## 6.4 Network Separation

Two different Docker bridge networks normally use separate virtual bridging environments.

Docker applies network isolation and forwarding policies to control communication across those boundaries.

The exact implementation depends on the Docker Engine platform and firewall configuration.

---

# 7. DOCKER NETWORK DRIVERS

## 7.1 Definition

A Docker network driver is a component responsible for implementing the connectivity behavior of a Docker network.

Different network drivers support different deployment requirements.

## 7.2 Principal Drivers

| Network driver | Primary purpose |
|---|---|
| `bridge` | Container connectivity on one Docker Engine host |
| `host` | Share the host network stack in supported environments |
| `none` | Disable ordinary container networking |
| `overlay` | Connect services or containers across multiple Docker Engine hosts using supported orchestration |
| `macvlan` | Present containers through MAC-address-based network integration |
| `ipvlan` | Provide container networking using supported IP-layer integration |
| Network plugins | Integrate specialized external networking systems |

## 7.3 Scope of Lecture 10

The principal subject is the bridge network driver.

The other drivers are introduced conceptually to establish their architectural differences.

More advanced multi-host networking and orchestration are outside the scope of this introductory lecture.

---

# 8. THE DEFAULT BRIDGE NETWORK

## 8.1 Definition

Docker Engine ordinarily creates a built-in bridge network during installation.

This network is conventionally named:

```text
bridge
```

Containers started without an explicit `--network` option are normally connected to it.

## 8.2 Example

```bash
docker run -d --name example-web nginx:alpine
```

Under default Docker Engine networking, the container joins the default bridge.

## 8.3 Characteristics

The default bridge generally provides:

- Container network interfaces.
- Container IP addressing.
- Connectivity between attached containers using IP addresses.
- Supported outbound network connectivity.
- Host port publishing when requested.

However, it has limitations compared with user-defined bridge networks.

## 8.4 Name Resolution Limitation

Containers on the default bridge do not ordinarily receive automatic DNS resolution of other containers by their Docker names.

For example, a container may be named:

```text
example-web
```

Another container on the default bridge cannot ordinarily assume that `example-web` resolves automatically through Docker DNS.

Legacy mechanisms such as container links may provide particular name-resolution behavior, but these are not the preferred model for new applications.

## 8.5 Engineering Consequence

Applications configured using fixed container IP addresses may become fragile when containers are replaced or network assignments change.

User-defined bridge networks provide a more convenient naming mechanism.

---

# 9. USER-DEFINED BRIDGE NETWORKS

## 9.1 Definition

A user-defined bridge network is a Docker-managed network explicitly created by the administrator using the bridge driver.

The network can be given a meaningful name and used to organize related containers.

**Formal definition:**

A user-defined Docker bridge network is a named, single-host container network that provides managed connectivity, isolation, addressing, and embedded DNS-based name resolution for attached containers.

## 9.2 Creating a Network

Docker provides:

```text
docker network create
```

Example:

```bash
docker network create --driver bridge academic-network
```

The command creates a network named:

```text
academic-network
```

## 9.3 Attaching a Container

A container can join the network during creation.

Example:

```bash
docker run -d --name academic-web --network academic-network nginx:alpine
```

## 9.4 Container Communication

Other containers attached to `academic-network` can normally communicate with `academic-web` using its name as a hostname.

This behavior is supported by Docker's embedded DNS functionality.

## 9.5 Benefits

User-defined bridge networks provide:

1. Network-level organization.
2. Automatic name resolution between attached containers.
3. Better separation of application groups.
4. Dynamic network attachment.
5. Explicit management.
6. Network-specific aliases.
7. Improved support for multi-container applications.

## 9.6 Comparison with the Default Bridge

| Characteristic | Default bridge | User-defined bridge |
|---|---|---|
| Created automatically | Yes | No |
| Administrator-defined name | Built-in name | Yes |
| Container IP connectivity | Yes | Yes |
| Automatic container-name DNS | Not ordinarily | Yes |
| Easy dynamic attachment | More limited | Supported |
| Network-scoped aliases | Not in the same manner | Supported |
| Application grouping | Limited | Supported |
| Recommended for related application containers | Less suitable | Generally preferable |

---

# 10. DOCKER NETWORK MANAGEMENT COMMANDS

Docker provides a network-management command group:

```text
docker network
```

Principal subcommands include:

| Command | Purpose |
|---|---|
| `docker network ls` | List networks |
| `docker network create` | Create a network |
| `docker network inspect` | Examine network configuration |
| `docker network connect` | Attach a container to a network |
| `docker network disconnect` | Detach a container from a network |
| `docker network rm` | Remove selected networks |
| `docker network prune` | Remove eligible unused networks |

## 10.1 Listing Networks

```bash
docker network ls
```

Typical output includes:

- Network ID.
- Name.
- Driver.
- Scope.

## 10.2 Creating a Bridge Network

```bash
docker network create -d bridge academic-network
```

The `-d` option selects the network driver.

## 10.3 Inspecting a Network

```bash
docker network inspect academic-network
```

The command returns structured JSON describing the network.

## 10.4 Removing a Network

```bash
docker network rm academic-network
```

A user-defined network normally cannot be removed while existing containers remain attached to it.

The built-in default networks are not ordinary removable user-created network resources.

---

# 11. NETWORK INSPECTION

## 11.1 Purpose

Network inspection provides information about:

- Network identity.
- Network driver.
- Network scope.
- Subnet configuration.
- Gateway configuration.
- Attached containers.
- Network options.
- Internal or external connectivity settings.

## 11.2 Example

```bash
docker network inspect academic-network
```

## 11.3 Important Fields

| Field | Interpretation |
|---|---|
| `Name` | Network name |
| `Id` | Network identifier |
| `Driver` | Network implementation |
| `Scope` | Network scope |
| `IPAM` | IP Address Management configuration |
| `Internal` | Internal network designation |
| `Containers` | Attached container information |
| `Options` | Driver-specific settings |

## 11.4 IP Address Management

IP Address Management, abbreviated IPAM, is responsible for configuring and allocating network address information.

Docker can automatically allocate a non-overlapping subnet when a new bridge network is created.

Administrators can also provide explicit subnet settings when appropriate.

## 11.5 Important Warning

Do not assume that every Docker environment uses the same default subnet.

Hard-coded examples of container addresses should be treated as illustrations rather than universal configuration values.

---

# 12. CONTAINER IP ADDRESSES

## 12.1 IP Assignment

When a container attaches to a bridge network, Docker commonly assigns it an IP address from the network's configured address range.

The address is associated with the container's endpoint on that network.

## 12.2 Example

An illustrative network may contain:

```text
Network: 172.20.0.0/16

Container A: 172.20.0.2
Container B: 172.20.0.3
Container C: 172.20.0.4
```

The addresses in this example are not fixed requirements.

Docker may allocate different values.

## 12.3 IP Address Changes

Container addressing can change when:

- Containers are replaced.
- Network endpoints are recreated.
- Network configuration changes.
- An address is released and reassigned.

## 12.4 Static IP Configuration

Docker permits static IP assignment within suitable configured network address ranges.

However, static addresses create additional administrative responsibilities.

They require careful management of address ranges and possible conflicts.

## 12.5 Preferred Application Configuration

For ordinary multi-container applications on user-defined networks, container names or appropriate service names are generally more maintainable than hard-coded container IP addresses.

This allows network addressing to change while the logical service reference remains stable.

---

# 13. THE DOMAIN NAME SYSTEM

## 13.1 Definition

The Domain Name System, or DNS, is a distributed naming system that resolves domain names and other supported hostnames into resource records.

A common DNS operation converts a hostname into an IP address.

For example:

```text
service.example.com
          |
          v
       IP ADDRESS
```

## 13.2 Why DNS Is Necessary

Human-readable names are easier to maintain than manually recorded IP addresses.

Applications can use stable logical names to locate services.

The underlying addresses may change independently of the application configuration.

## 13.3 DNS and Containerized Systems

In a dynamic container environment, containers may be created, removed, and replaced.

A service name provides a useful abstraction over the container's changing IP address.

Docker's embedded DNS supports this concept on user-defined networks.

---

# 14. DOCKER'S EMBEDDED DNS SERVER

## 14.1 Definition

Docker provides an embedded DNS resolver for containers connected to user-defined networks.

The embedded resolver supports container-name and network-alias resolution.

## 14.2 Resolver Address

The embedded DNS resolver is commonly configured at:

```text
127.0.0.11
```

This address is used within the container networking environment.

It should not be confused with the host's ordinary loopback address or with another container's application endpoint.

## 14.3 DNS Resolution Process

Suppose two containers share a user-defined bridge network.

Container A requests the hostname:

```text
application-db
```

Docker's embedded DNS resolver can identify the appropriate network endpoint associated with that name.

The requesting application receives address information and can initiate a connection.

## 14.4 Logical Diagram

```text
               APPLICATION CONTAINER
                        |
                        |
             DNS Query: application-db
                        |
                        v
                DOCKER EMBEDDED DNS
                    127.0.0.11
                        |
                        v
                 NETWORK ENDPOINT
                        |
                        v
                 DATABASE CONTAINER
```

## 14.5 External Name Resolution

The embedded resolver can also forward external DNS queries to configured upstream DNS services.

Thus, internal container-name resolution and external domain-name resolution can coexist.

Successful external resolution still depends on valid upstream DNS and network connectivity.

---

# 15. CONTAINER NAMES AS HOSTNAMES

## 15.1 Example

Create a container named:

```text
application-db
```

and connect it to a user-defined network.

Another container on the same network may connect using:

```text
application-db
```

as the destination hostname.

## 15.2 Application Configuration

A database client may use a connection configuration similar to:

```text
Host: application-db
Port: 5432
```

The port identifies the database service inside the destination container.

The container name provides a logical network reference.

## 15.3 Important Distinction

A container name is not a globally published internet domain name.

Docker's embedded DNS resolution is scoped to relevant container network attachments.

A browser on the host computer does not automatically resolve arbitrary Docker container names through the operating system's ordinary DNS configuration.

## 15.4 Container Replacement

When a container is replaced, the new instance can join the same network under the intended name or alias.

The application can continue using that logical hostname.

However, existing connections may break during replacement.

DNS naming does not automatically guarantee uninterrupted connections or application availability.

---

# 16. SERVICE DISCOVERY

## 16.1 Definition

Service discovery is the process through which a software component identifies the network location of another service.

**Formal definition:**

Service discovery is a mechanism that associates logical service identities with reachable network endpoints, allowing clients to locate and communicate with service providers.

## 16.2 Static Addressing Versus Service Discovery

A static-addressing configuration may use:

```text
DATABASE_HOST=172.20.0.3
```

A name-based configuration may use:

```text
DATABASE_HOST=application-db
```

The second approach is generally easier to maintain in environments where container addresses may change.

## 16.3 Service Discovery in Docker

Docker's embedded DNS provides basic service discovery through container names and network aliases on user-defined networks.

This mechanism is appropriate for many single-host multi-container systems.

## 16.4 Limitations

Basic DNS-based discovery does not automatically provide:

- Application health verification.
- Authentication.
- Encryption.
- Automatic retries.
- Connection failover.
- Transaction recovery.
- Guaranteed load balancing.
- Service authorization.

These require additional application or infrastructure mechanisms.

---

# 17. NETWORK ALIASES

## 17.1 Definition

A network alias is an additional hostname associated with a container endpoint on a particular Docker network.

Aliases provide alternative logical names through which a container can be discovered.

## 17.2 Example

A container named:

```text
redis-instance
```

might also have a network alias:

```text
cache
```

Applications can then use:

```text
cache
```

as a logical service reference.

## 17.3 Creating an Alias

Docker supports the option:

```text
--network-alias
```

Example:

```bash
docker run -d --name redis-instance --network academic-network --network-alias cache redis:7-alpine
```

The alias is associated with the selected network attachment.

## 17.4 Network Scope

An alias belongs to a particular network context.

A container may have different aliases on different networks.

## 17.5 Shared Aliases

Docker can allow multiple containers to use the same network alias.

However, clients must not assume a particular destination container will always be selected.

An alias shared across multiple endpoints is not by itself a complete high-availability or load-balancing mechanism.

---

# 18. INTER-CONTAINER COMMUNICATION WITHOUT PORT PUBLISHING

## 18.1 Fundamental Principle

Containers connected to the same suitable user-defined bridge network can communicate using their internal network endpoints.

They do not need host-published ports for this communication.

## 18.2 Example

```text
Container A: application
Container B: redis
```

Both containers are connected to:

```text
academic-network
```

Container A connects to:

```text
redis:6379
```

The database's internal TCP port is sufficient for this connection.

## 18.3 Architecture

```text
              DOCKER NETWORK
                   |
         +---------+---------+
         |                   |
         v                   v
    APPLICATION           DATABASE
     CONTAINER            CONTAINER
         |                   |
         +------ TCP --------+
                 6379
```

No host port publishing is required for the internal connection.

## 18.4 EXPOSE Is Not an Access-Control Mechanism

A Dockerfile's `EXPOSE` instruction does not establish a firewall that restricts communication to the declared ports.

On a normal user-defined bridge network, attached containers can reach listening services on one another's container ports, subject to application and network security controls.

A service may therefore be reachable internally even if it is not declared through `EXPOSE`.

## 18.5 Security Consequence

Not publishing a database port to the host reduces one form of external exposure.

However, containers with access to the same network may still reach the database.

Network membership should therefore be treated as a meaningful security consideration.

---

# 19. NETWORK ISOLATION

## 19.1 Definition

Network isolation is the restriction of communication between network environments according to established boundaries and policies.

Docker user-defined bridge networks provide a useful method of separating groups of containers.

## 19.2 Example

Consider two networks:

```text
frontend-network
database-network
```

Containers attached only to `frontend-network` should not automatically have connectivity to every container attached only to `database-network`.

## 19.3 Isolation Diagram

```text
           DOCKER HOST
                |
      +---------+---------+
      |                   |
      v                   v
  NETWORK A           NETWORK B
      |                   |
      v                   v
 CONTAINER A          CONTAINER B
      |                   |
      +---- ISOLATED -----+
```

The drawing represents the ordinary isolation model.

Actual network reachability can be influenced by routing, published ports, host networking, firewall policy, and advanced Docker configuration.

## 19.4 Network Isolation Limitations

Network isolation is not equivalent to a complete application security policy.

Additional security mechanisms may be required, including:

- Authentication.
- Authorization.
- Transport encryption.
- Firewall rules.
- Restricted container privileges.
- Secure host configuration.
- Appropriate secret management.

---

# 20. CONNECTING CONTAINERS TO MULTIPLE NETWORKS

## 20.1 Multi-Homed Containers

A container connected to multiple Docker networks is commonly described as multi-homed.

It can possess a separate network endpoint on each attached network.

## 20.2 Example

An application container may participate in:

```text
frontend-network
```

and:

```text
backend-network
```

A database container may participate only in:

```text
backend-network
```

## 20.3 Architecture

```text
                FRONTEND NETWORK
                       |
                       v
                APPLICATION
                  CONTAINER
                       |
                       |
                BACKEND NETWORK
                       |
                       v
                   DATABASE
                  CONTAINER
```

The application container can communicate through both networks.

The frontend component need not have direct membership in the backend network.

## 20.4 Communication Boundary

A multi-homed container is not automatically a router between every network to which it is connected.

Ordinary application containers do not automatically forward arbitrary traffic between their attached Docker networks.

Additional forwarding, routing, or application-proxy behavior would need to be established.

---

# 21. THE DOCKER NETWORK CONNECT COMMAND

## 21.1 Definition

The command:

```text
docker network connect
```

attaches an existing container to a Docker network.

## 21.2 Syntax

```text
docker network connect NETWORK CONTAINER
```

Example:

```bash
docker network connect academic-network application
```

## 21.3 Runtime Attachment

A running container can normally be connected to an additional user-defined bridge network without being recreated.

Docker establishes the appropriate network endpoint and configuration.

## 21.4 Verification

The attachment can be verified through:

```bash
docker network inspect academic-network
```

or:

```bash
docker inspect application
```

## 21.5 Network Aliases During Connection

Aliases can also be supplied during a network connection operation.

Example:

```bash
docker network connect --alias api academic-network application
```

The alias applies to that network attachment.

---

# 22. THE DOCKER NETWORK DISCONNECT COMMAND

## 22.1 Definition

The command:

```text
docker network disconnect
```

removes a container's attachment to a specified network.

## 22.2 Syntax

```text
docker network disconnect NETWORK CONTAINER
```

Example:

```bash
docker network disconnect academic-network application
```

## 22.3 Effect

Disconnecting a container may remove its ability to communicate with services available only through the removed network.

Existing network connections may fail.

## 22.4 Application Consequences

An application may remain running after a network is disconnected.

However, it can lose access to dependencies.

This demonstrates that container execution state and application connectivity are different properties.

---

# 23. INTERNAL DOCKER NETWORKS

## 23.1 Definition

Docker provides an `--internal` option when creating suitable networks.

An internal network is configured to restrict external connectivity.

## 23.2 Example

```bash
docker network create --driver bridge --internal private-network
```

## 23.3 Intended Behavior

Containers attached exclusively to an internal network can communicate with appropriate peers on that network.

Their ordinary access to external networks is restricted.

## 23.4 Important Qualification

An internal Docker network should not be interpreted as an absolute security barrier against the host.

On Linux, the host may still have direct access to network endpoints through the associated networking infrastructure, subject to configuration.

Docker's documented internal-network behavior can also allow communication with relevant gateway endpoints.

## 23.5 Security Use

Internal networks are useful for services that do not require ordinary outbound internet connectivity.

Examples may include selected:

- Databases.
- Caches.
- Internal processing systems.
- Application support services.

Security-sensitive environments still require additional access controls.

---

# 24. HOST NETWORKING

## 24.1 Definition

Host networking is a Docker network mode in which a container uses the host's network stack rather than a separate ordinary bridge-network namespace.

## 24.2 Example

```bash
docker run --network host IMAGE
```

## 24.3 Consequences

In supported host-network configurations:

- The container does not receive a separate ordinary bridge-network IP address.
- The application uses the host networking environment.
- Host-port publishing options do not apply in the normal manner.
- Port conflicts occur in the shared network namespace.

## 24.4 Platform Support

Host networking is available on Linux Docker Engine.

Docker Desktop also supports selected host-networking functionality in supported versions and configurations.

Its behavior should not automatically be assumed identical across every operating system.

## 24.5 Security Considerations

Host networking reduces network-namespace isolation.

It should be selected only when its operational requirements justify the reduced separation.

---

# 25. NONE NETWORKING

## 25.1 Definition

The `none` networking mode disables the container's ordinary external networking attachment.

## 25.2 Example

```bash
docker run --rm --network none alpine:3.20 ip addr
```

The container normally retains a loopback interface but lacks the ordinary network connectivity provided by a bridge network.

## 25.3 Uses

This mode can be useful for:

- Offline processing.
- Restricted computational tasks.
- Network-isolation experiments.
- Programs requiring no external communication.

## 25.4 Limitation

A process running with `--network none` cannot ordinarily communicate with services on a Docker bridge network through standard network routing.

---

# 26. OVERLAY NETWORKING

## 26.1 Definition

An overlay network can provide network connectivity across multiple Docker Engine hosts in supported orchestration configurations.

Docker Swarm uses overlay networks to support communication among services deployed across nodes.

## 26.2 Conceptual Architecture

```text
           DOCKER HOST A
                |
             CONTAINER A
                |
                v
           OVERLAY NETWORK
                |
                v
             CONTAINER B
                |
           DOCKER HOST B
```

## 26.3 Purpose

Overlay networks address problems involving distributed services that operate across multiple physical or virtual hosts.

## 26.4 Scope

The present lecture focuses on single-host bridge networking.

Overlay network design, swarm routing, and distributed orchestration require further study.

---

# 27. MACVLAN AND IPVLAN

## 27.1 Macvlan

Macvlan networking can provide containers with network identities that integrate with a physical network at the Ethernet layer.

This may allow containers to appear as distinct network devices from the perspective of external infrastructure.

## 27.2 Ipvlan

Ipvlan provides alternative mechanisms for integrating container IP networking with host and external network configurations.

## 27.3 Use Cases

These drivers may be useful when applications require:

- Direct network addressing.
- Integration with existing network infrastructure.
- Specialized routing.
- Particular network segmentation arrangements.

## 27.4 Limitations

These drivers require additional consideration of:

- Host interfaces.
- Address allocation.
- Routing.
- Network equipment.
- Security controls.
- Platform support.

They are not generally necessary for ordinary local Docker development.

---

# 28. DNS CONFIGURATION IN CONTAINERS

## 28.1 The resolv.conf File

Linux applications commonly use resolver configuration from:

```text
/etc/resolv.conf
```

This file may identify DNS servers and related resolver settings.

## 28.2 Docker DNS

Containers connected to user-defined networks commonly use Docker's embedded DNS server at:

```text
127.0.0.11
```

## 28.3 Examining DNS Configuration

Example:

```bash
docker exec CONTAINER cat /etc/resolv.conf
```

## 28.4 Custom DNS Servers

Docker permits DNS settings to be supplied through supported runtime options.

Example:

```text
--dns DNS_SERVER_ADDRESS
```

## 28.5 Limitations

A custom DNS server configuration does not automatically provide container-name discovery outside the Docker network model.

Docker's embedded DNS remains the standard mechanism for automatic name resolution on user-defined networks.

---

# 29. DNS TROUBLESHOOTING

## 29.1 Name Resolution Failure

A container may fail to resolve another container's name.

Possible causes include:

1. Containers on different networks.
2. Destination container not running or attached.
3. Incorrect container name.
4. Incorrect alias.
5. Use of the default bridge without supported name-resolution configuration.
6. Incorrect resolver configuration.
7. DNS service problems.

## 29.2 Diagnostic Commands

```bash
docker network ls
```

```bash
docker network inspect NETWORK_NAME
```

```bash
docker inspect CONTAINER_NAME
```

Inside a suitable diagnostic container:

```bash
nslookup SERVICE_NAME
```

The availability of `nslookup` depends on the image.

## 29.3 Name Resolution Versus Service Availability

Successful DNS resolution establishes that an address can be obtained.

It does not prove that:

- A service process is running.
- The target port is correct.
- A firewall permits access.
- Application authentication succeeds.
- The service is healthy.

These must be investigated separately.

---

# 30. APPLICATION-LEVEL NETWORK COMMUNICATION

## 30.1 HTTP

HTTP is an application-layer protocol used by web clients and servers.

A Docker container running Nginx can provide HTTP responses to another container connected to a suitable network.

## 30.2 Redis Protocol

Redis clients use the Redis application protocol over supported transport connections, commonly TCP.

A Redis client container can communicate with a Redis server container using the server's network hostname and configured port.

## 30.3 Application Protocol Compatibility

Communication requires both network reachability and compatible protocols.

An HTTP client cannot automatically interpret a Redis server response as a normal HTTP document.

The network transports data.

The applications determine how that data is structured and interpreted.

---

# 31. NETWORK SECURITY PRINCIPLES

## 31.1 Least Connectivity

A container should be attached only to networks required for its responsibilities.

Excessive network membership increases potential communication pathways.

## 31.2 Avoid Unnecessary Port Publishing

Internal services generally do not need published host ports unless external access is specifically required.

## 31.3 Authentication

Applications must protect sensitive operations using appropriate authentication and authorization.

Network isolation alone is insufficient.

## 31.4 Redis Security

Redis is designed to operate within appropriately trusted environments.

Exposing an unauthenticated Redis instance to untrusted clients is dangerous.

The laboratory will use a demonstration-only authentication value and will not publish Redis port 6379 to the host.

The demonstration credential must not be reused in real deployments.

## 31.5 Transport Encryption

Traffic exchanged inside a Docker network is not automatically encrypted merely because it remains inside the Docker environment.

Applications requiring confidential communication may need TLS or another appropriate encryption mechanism.

## 31.6 Firewall Integration

Docker Engine on Linux manages firewall and packet-filtering rules to implement bridge networking, published ports, and network isolation.

Administrators should not arbitrarily alter Docker-managed firewall rules.

Advanced firewall configuration requires knowledge of the selected Docker Engine backend.

---

# 32. NETWORK DESIGN BEST PRACTICES

Recommended practices include:

1. Create user-defined networks for related application components.
2. Use meaningful network names.
3. Use container or service names rather than hard-coded container IP addresses.
4. Avoid publishing internal service ports unnecessarily.
5. Attach containers only to required networks.
6. Separate public-facing and internal services where useful.
7. Use application authentication even when internal networking is employed.
8. Treat DNS resolution as separate from application readiness.
9. Validate the correct destination hostname and port.
10. Inspect network attachments during troubleshooting.
11. Avoid assuming that Docker Desktop networking is identical to native Linux networking.
12. Use explicit network configuration in repeatable deployment definitions.

These principles prepare students for Docker Compose.

---

# PART II — PRACTICAL LABORATORY 10

# 33. LABORATORY OVERVIEW

## 33.1 Title

**Docker Network Isolation and Service Discovery Laboratory: User-Defined Bridge Networks, Nginx, DNS, Redis, and Dynamic Network Attachment**

## 33.2 Objective

The laboratory demonstrates:

1. Docker network discovery.
2. Custom bridge-network creation.
3. Network inspection.
4. Container attachment.
5. Automatic container-name resolution.
6. Network aliases.
7. HTTP communication without host port publishing.
8. Host port publishing.
9. Isolation between Docker networks.
10. Dynamic network connection.
11. Dynamic network disconnection.
12. Container DNS configuration.
13. Redis client-server communication.
14. Separation between application execution and network connectivity.
15. Basic network troubleshooting.
16. Controlled cleanup.

## 33.3 Requirements

- Docker Engine or Docker Desktop.
- Docker CLI.
- Internet access for pulling images.
- Terminal access.
- Optional web browser.

Required images:

```text
alpine:3.20
nginx:alpine
redis:7-alpine
```

The images may already exist from earlier course lectures.

## 33.4 Laboratory Naming

The laboratory uses the following network names:

```text
lecture10-net
lecture10-isolated
```

And the following container names:

```text
lecture10-web
lecture10-public
lecture10-outsider
lecture10-redis
```

These names are intentionally specific to reduce conflicts with unrelated Docker objects.

## 33.5 Security Requirement

The Redis service will remain unpublished on the host.

Its authentication value is a demonstration-only value.

Do not reuse this authentication value in any production or shared environment.

---

# 34. EXPERIMENT 1 — VERIFY DOCKER NETWORK AVAILABILITY

Execute:

```bash
docker version
```

Then:

```bash
docker network ls
```

## Objective

Confirm Docker availability and identify existing networks.

## Required Observations

Record:

1. Docker Engine version.
2. Available network names.
3. Network drivers.
4. Network scopes.

## Expected Result

The network list ordinarily includes built-in networks named:

- `bridge`
- `host`
- `none`

The exact list depends on the Docker environment.

---

# 35. EXPERIMENT 2 — INSPECT THE DEFAULT BRIDGE

Execute:

```bash
docker network inspect bridge
```

## Objective

Examine the configuration of Docker's default bridge network.

## Required Observations

Identify:

1. Network identifier.
2. Driver.
3. Subnet.
4. Gateway.
5. Attached containers.

## Analytical Question

Explain the relationship between Docker's bridge network and the network namespaces of containers attached to it.

---

# 36. EXPERIMENT 3 — CREATE TWO USER-DEFINED NETWORKS

Execute:

```bash
docker network create --driver bridge lecture10-net
```

Then:

```bash
docker network create --driver bridge lecture10-isolated
```

Verify:

```bash
docker network ls
```

## Objective

Create two independent bridge networks.

## Expected Result

Both network names appear in Docker's network list.

## Required Analysis

Explain why the two networks provide separate communication environments despite operating on the same Docker Engine host.

---

# 37. EXPERIMENT 4 — INSPECT THE NEW NETWORKS

Execute:

```bash
docker network inspect lecture10-net
```

Then:

```bash
docker network inspect lecture10-isolated
```

## Objective

Compare the addressing and gateway configuration of two user-defined networks.

## Required Observations

Record:

| Property | lecture10-net | lecture10-isolated |
|---|---|---|
| Driver | | |
| Network ID | | |
| Subnet | | |
| Gateway | | |
| Attached containers | | |

## Analysis

Explain why Docker normally allocates non-overlapping address ranges to distinct bridge networks.

---

# 38. EXPERIMENT 5 — START AN INTERNAL NGINX SERVICE

Execute:

```bash
docker run -d --name lecture10-web --network lecture10-net --network-alias lecture10-site nginx:alpine
```

## Objective

Start a web server attached to the first user-defined network.

## Technical Interpretation

The container:

- Uses the Nginx image.
- Is named `lecture10-web`.
- Joins `lecture10-net`.
- Receives an additional network alias, `lecture10-site`.
- Does not publish a host port.

## Expected Result

The container starts successfully.

Verify:

```bash
docker ps
```

---

# 39. EXPERIMENT 6 — INSPECT THE NGINX NETWORK ATTACHMENT

Execute:

```bash
docker inspect --format '{{json .NetworkSettings.Networks}}' lecture10-web
```

## Objective

Examine the container's network configuration.

## Required Observations

Identify:

1. Network name.
2. Assigned IP address.
3. Gateway.
4. Network aliases, if displayed.
5. Network endpoint information.

## Analytical Question

Explain why the assigned container IP address should not normally be treated as a permanent application configuration value.

---

# 40. EXPERIMENT 7 — VERIFY CONTAINER DNS RESOLUTION

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 nslookup lecture10-web
```

## Objective

Test whether a temporary container can resolve the name of another container on the same user-defined network.

## Expected Result

The name `lecture10-web` resolves to the Nginx container's network address.

The exact IP address depends on the Docker network.

## Technical Interpretation

The temporary Alpine container uses Docker's network-aware DNS resolution mechanism.

The name is resolved because both containers participate in the same appropriate user-defined bridge network.

---

# 41. EXPERIMENT 8 — EXAMINE THE DNS RESOLVER

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 cat /etc/resolv.conf
```

## Objective

Inspect resolver configuration within a user-defined Docker network.

## Expected Observation

The output should ordinarily identify Docker's embedded DNS resolver:

```text
nameserver 127.0.0.11
```

Additional resolver options may be present.

## Analysis

Explain the purpose of the embedded DNS resolver and distinguish it from an application listening on a TCP port.

---

# 42. EXPERIMENT 9 — REQUEST THE NGINX WEBPAGE INTERNALLY

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 wget -q -O - http://lecture10-web/
```

## Objective

Demonstrate HTTP communication between two containers on the same Docker network.

## Expected Result

The temporary Alpine container retrieves the default Nginx HTML page.

## Technical Interpretation

The communication path is:

```text
TEMPORARY ALPINE CONTAINER
             |
             v
        DOCKER DNS
             |
             v
       lecture10-web
             |
             v
      NGINX TCP PORT 80
             |
             v
         HTTP RESPONSE
```

No host port is needed for this communication.

## Required Analysis

Explain the difference between internal container-to-container communication and the host port publishing studied in Lecture 08.

---

# 43. EXPERIMENT 10 — VERIFY THE NETWORK ALIAS

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 nslookup lecture10-site
```

Then:

```bash
docker run --rm --network lecture10-net alpine:3.20 wget -q -O - http://lecture10-site/
```

## Objective

Demonstrate that a network alias can be used as an alternative hostname.

## Expected Result

The alias resolves to the Nginx network endpoint.

The HTTP request succeeds.

## Required Analysis

Explain why network aliases are useful when application configuration should not depend on a container's particular administrative name.

---

# 44. EXPERIMENT 11 — EXAMINE UNPUBLISHED PORTS

Execute:

```bash
docker port lecture10-web
```

## Objective

Verify that no host port has been published for the Nginx container.

## Expected Result

No published host mapping is displayed.

## Technical Interpretation

The Nginx process remains available to compatible peers on `lecture10-net`.

Its internal service does not require Docker host port publishing for communication with those peers.

## Analytical Question

Does the absence of a published host port guarantee that no other container can reach the Nginx service?

Explain.

---

# 45. EXPERIMENT 12 — PUBLISH A SECOND NGINX CONTAINER

Execute:

```bash
docker run -d --name lecture10-public --network lecture10-net -p 127.0.0.1:8210:80 nginx:alpine
```

## Objective

Compare internally available service endpoints with a host-published endpoint.

Open in a browser:

http://127.0.0.1:8210

## Expected Result

The Nginx default welcome page appears.

Now execute:

```bash
docker port lecture10-public
```

The command should display a mapping equivalent to:

```text
80/tcp -> 127.0.0.1:8210
```

## Required Analysis

Explain why the application listens on container port 80 while the browser communicates through host port 8210.

---

# 46. EXPERIMENT 13 — ACCESS THE PUBLISHED CONTAINER INTERNALLY

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 wget -q -O - http://lecture10-public/
```

## Objective

Demonstrate that another container on the same network uses the internal destination hostname and port.

## Expected Result

The request succeeds without referring to host port 8210.

## Technical Interpretation

For internal communication, the destination is:

```text
lecture10-public:80
```

The published host port is not required.

## Required Analysis

Explain why using host-published ports for internal service discovery is generally unnecessary in this architecture.

---

# 47. EXPERIMENT 14 — CREATE A CONTAINER ON THE ISOLATED NETWORK

Execute:

```bash
docker run -d --name lecture10-outsider --network lecture10-isolated alpine:3.20 sleep 3600
```

## Objective

Create a running container that is attached only to the second Docker network.

Verify:

```bash
docker inspect --format '{{json .NetworkSettings.Networks}}' lecture10-outsider
```

## Expected Result

The container is attached to:

```text
lecture10-isolated
```

It is not yet attached to:

```text
lecture10-net
```

---

# 48. EXPERIMENT 15 — TEST NAME RESOLUTION ACROSS NETWORKS

Execute:

```bash
docker exec lecture10-outsider nslookup lecture10-web
```

## Objective

Investigate name resolution when the source and destination containers do not share a user-defined network.

## Expected Result

Under the ordinary isolated-network configuration, the name `lecture10-web` is not resolved through Docker's network-scoped container discovery.

The command may report an unresolved hostname.

## Required Analysis

1. Explain why the two containers cannot use automatic Docker DNS discovery across their separate networks.
2. Distinguish a name-resolution failure from an application connection failure.
3. Explain why this test does not prove every possible host-level or externally routed network path is blocked.

---

# 49. EXPERIMENT 16 — CONNECT THE CONTAINER TO THE FIRST NETWORK

Execute:

```bash
docker network connect lecture10-net lecture10-outsider
```

Verify:

```bash
docker inspect --format '{{json .NetworkSettings.Networks}}' lecture10-outsider
```

## Objective

Attach an already running container to a second network.

## Expected Result

The container now has network attachments associated with:

- `lecture10-isolated`.
- `lecture10-net`.

## Technical Interpretation

The container is now multi-homed.

It can participate in the networking environments of both attached networks.

---

# 50. EXPERIMENT 17 — TEST DNS AFTER NETWORK ATTACHMENT

Execute:

```bash
docker exec lecture10-outsider nslookup lecture10-web
```

Then:

```bash
docker exec lecture10-outsider wget -q -O - http://lecture10-web/
```

## Objective

Determine whether joining the target network enables name resolution and HTTP communication.

## Expected Result

The hostname resolves and the HTTP request succeeds.

## Required Analysis

Explain why network attachment changed the connectivity available to the running container without requiring the Nginx image to be rebuilt.

---

# 51. EXPERIMENT 18 — DISCONNECT THE NETWORK

Execute:

```bash
docker network disconnect lecture10-net lecture10-outsider
```

Verify:

```bash
docker inspect --format '{{json .NetworkSettings.Networks}}' lecture10-outsider
```

Now retry:

```bash
docker exec lecture10-outsider nslookup lecture10-web
```

## Objective

Investigate the consequences of removing the shared network attachment.

## Expected Result

The Docker-specific hostname is no longer ordinarily resolvable from the isolated container.

## Required Analysis

Explain why the container may remain in the running state even though it has lost access to a service dependency.

---

# 52. EXPERIMENT 19 — START A REDIS SERVICE

Execute:

```bash
docker run -d --name lecture10-redis --network lecture10-net redis:7-alpine redis-server --save "" --appendonly no --requirepass lecture10-only-demonstration
```

## Objective

Start a Redis server on the first Docker network without publishing a host port.

## Configuration

The command:

- Creates a Redis container.
- Connects it to `lecture10-net`.
- Does not publish port 6379 to the host.
- Disables database persistence for this temporary exercise.
- Configures a demonstration-only authentication password.

## Security Note

The value `lecture10-only-demonstration` is public instructional data, not a real secret.

The purpose of the value is to avoid creating an entirely unauthenticated Redis service.

In production, credentials must be strong, confidential, and managed through suitable secret mechanisms rather than embedded directly in commands.

## Expected Result

The Redis container starts successfully.

Verify:

```bash
docker ps
```

---

# 53. EXPERIMENT 20 — CONNECT TO REDIS BY CONTAINER NAME

Execute:

```bash
docker run --rm --network lecture10-net -e REDISCLI_AUTH=lecture10-only-demonstration redis:7-alpine redis-cli -h lecture10-redis PING
```

## Objective

Use a temporary Redis client container to communicate with the Redis server by hostname.

## Expected Result

Redis returns:

```text
PONG
```

## Technical Interpretation

The Redis client connects using:

```text
Hostname: lecture10-redis
Port:     6379
Protocol: Redis over TCP
```

The application does not need a host-published Redis port.

## Required Analysis

Explain the role of Docker DNS in locating the Redis server.

---

# 54. EXPERIMENT 21 — EXCHANGE APPLICATION DATA THROUGH REDIS

Store a value:

```bash
docker run --rm --network lecture10-net -e REDISCLI_AUTH=lecture10-only-demonstration redis:7-alpine redis-cli -h lecture10-redis SET course:network "Docker Lecture 10"
```

Expected response:

```text
OK
```

Retrieve the value using a separate temporary client container:

```bash
docker run --rm --network lecture10-net -e REDISCLI_AUTH=lecture10-only-demonstration redis:7-alpine redis-cli -h lecture10-redis GET course:network
```

Expected response:

```text
Docker Lecture 10
```

## Objective

Demonstrate communication between a persistent server process and multiple independently created client containers.

## Required Analysis

1. Identify the Redis server container.
2. Identify the client container role.
3. Explain why the client containers can be removed without stopping Redis.
4. Explain why the Redis data in this laboratory should not be regarded as durable persistent storage.

---

# 55. EXPERIMENT 22 — INVESTIGATE REDIS PORT PUBLISHING

Execute:

```bash
docker port lecture10-redis
```

## Objective

Verify that Redis has not been published to the Docker host.

## Expected Result

No host port binding is displayed.

Now inspect its network attachment:

```bash
docker inspect --format '{{json .NetworkSettings.Networks}}' lecture10-redis
```

## Required Analysis

Explain how Redis can accept connections from temporary client containers while remaining unpublished on the host.

**Security qualification:** Lack of a published port reduces ordinary external exposure, but it is not a replacement for authentication or a complete guarantee against host-level or specially routed access.

---

# 56. EXPERIMENT 23 — TEST REDIS DNS ISOLATION

Execute:

```bash
docker exec lecture10-outsider nslookup lecture10-redis
```

## Objective

Examine whether the isolated Alpine container can discover the Redis server by Docker hostname.

## Expected Result

Because `lecture10-outsider` has been disconnected from `lecture10-net`, the Redis container's network-scoped name should not ordinarily resolve.

## Required Analysis

Explain why network membership determines which Docker-managed service names are discoverable.

---

# 57. EXPERIMENT 24 — EXAMINE MULTIPLE NETWORK ENDPOINTS

Execute:

```bash
docker network inspect lecture10-net
```

Then:

```bash
docker network inspect lecture10-isolated
```

## Objective

Compare the container membership of the two networks.

## Expected Membership

**lecture10-net:**

- lecture10-web
- lecture10-public
- lecture10-redis

**lecture10-isolated:**

- lecture10-outsider

The exact network metadata may contain additional fields.

## Required Analysis

Explain how network inspection can be used to establish whether two containers share a communication environment.

---

# 58. EXPERIMENT 25 — INVESTIGATE CONTAINER LOOPBACK

Execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 wget -q -O - http://127.0.0.1/
```

## Objective

Demonstrate the distinction between a container's local loopback interface and another container's network endpoint.

## Expected Result

The request normally fails because the temporary Alpine container does not run an HTTP server on its own loopback port 80.

Now execute:

```bash
docker run --rm --network lecture10-net alpine:3.20 wget -q -O - http://lecture10-web/
```

The second request should succeed.

## Required Analysis

Explain why `localhost` is not an appropriate hostname for connecting to a different container in this arrangement.

---

# 59. EXPERIMENT 26 — INVESTIGATE NETWORK NONE

Execute:

```bash
docker run --rm --network none alpine:3.20 ip addr
```

## Objective

Examine the network interfaces available to a container using the `none` network mode.

## Expected Result

The container ordinarily displays a loopback interface without the normal bridge-network interface.

## Required Analysis

Explain how the `none` network mode differs from ordinary bridge networking.

---

# 60. EXPERIMENT 27 — EXAMINE AN INTERNAL NETWORK

Create a dedicated internal network:

```bash
docker network create --driver bridge --internal lecture10-internal
```

Inspect it:

```bash
docker network inspect lecture10-internal
```

## Objective

Examine Docker's internal-network configuration.

## Required Observation

The network metadata should identify the internal-network setting.

## Analytical Questions

1. What is the intended purpose of the `--internal` option?
2. Why can two containers on the same internal network still communicate?
3. Why should an internal network not be treated as an absolute security boundary against host-level access?
4. Why might an internal network be useful for application support services?

---

# 61. EXPERIMENT 28 — EXAMINE NETWORK-RELATED LOGS

Execute:

```bash
docker logs --tail 20 lecture10-web
```

Then:

```bash
docker logs --tail 20 lecture10-redis
```

## Objective

Inspect application output after the network communication experiments.

## Expected Observations

The Nginx logs may contain HTTP access records.

The Redis logs may contain startup and configuration information.

## Required Analysis

1. Distinguish network diagnostic results from application logs.
2. Explain why successful DNS resolution does not guarantee a healthy application.
3. Explain why application authentication failures may occur even when network connectivity is functioning.

---

# 62. EXPERIMENT 29 — CONTROLLED LABORATORY CLEANUP

Remove the laboratory containers:

```bash
docker rm -f lecture10-web lecture10-public lecture10-outsider lecture10-redis
```

The `-f` option forcibly removes the specified laboratory containers.

It must not be applied indiscriminately to unrelated containers.

Now remove the user-defined networks:

```bash
docker network rm lecture10-net lecture10-isolated lecture10-internal
```

Verify:

```bash
docker network ls
```

And:

```bash
docker ps -a
```

## Expected Result

The named laboratory networks and containers are removed.

The built-in default Docker networks remain available.

## Data Note

The Redis demonstration deliberately used nonpersistent storage.

Removing its container can therefore discard the training dataset.

This behavior is distinct from the persistent-volume configuration studied in Lecture 09.

---

# 63. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Technical objective | Observed result |
|---|---|---|
| 1 | Docker network discovery | |
| 2 | Default bridge inspection | |
| 3 | Network creation | |
| 4 | Network addressing inspection | |
| 5 | Internal Nginx startup | |
| 6 | Nginx network attachment | |
| 7 | Docker DNS resolution | |
| 8 | DNS resolver configuration | |
| 9 | Internal HTTP request | |
| 10 | Network alias resolution | |
| 11 | Unpublished port analysis | |
| 12 | Host port publishing | |
| 13 | Internal access to published service | |
| 14 | Isolated container creation | |
| 15 | Cross-network DNS failure | |
| 16 | Dynamic network connection | |
| 17 | DNS resolution after connection | |
| 18 | Dynamic network disconnection | |
| 19 | Redis service startup | |
| 20 | Redis client communication | |
| 21 | Redis application data exchange | |
| 22 | Redis port publishing examination | |
| 23 | Redis DNS isolation | |
| 24 | Network membership inspection | |
| 25 | Container loopback investigation | |
| 26 | None network investigation | |
| 27 | Internal network examination | |
| 28 | Application log investigation | |
| 29 | Controlled cleanup | |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 300–400 words explaining:

1. Why user-defined bridge networks support container-name resolution.
2. How Docker's embedded DNS participates in container communication.
3. Why host port publishing is not required for internal communication.
4. How Docker networks establish separation between application groups.
5. How dynamic network attachment changes available communication pathways.
6. Why a functioning network does not automatically guarantee a functioning application.
7. How Redis client-server communication demonstrates multi-container architecture.

---

# PART III — SYSTEMATIC NETWORK TROUBLESHOOTING

# 64. NETWORK FAILURE CATEGORIES

Networking failures should be classified before corrective action is attempted.

Common categories include:

1. Network attachment failure.
2. DNS resolution failure.
3. Routing failure.
4. Incorrect destination port.
5. Application not listening.
6. Application interface-binding error.
7. Firewall or filtering restrictions.
8. Authentication failure.
9. Application protocol error.
10. Service initialization failure.

Each category requires a different investigative procedure.

---

# 65. TROUBLESHOOTING: CONTAINER NAME NOT RESOLVED

## Scenario

An application container attempts to connect to:

```text
database
```

but DNS resolution fails.

## Possible Causes

- Incorrect hostname.
- Containers attached to different networks.
- Destination container not connected.
- Incorrect alias.
- Default bridge network limitations.
- Resolver configuration problems.

## Investigation

Examine the network list:

```bash
docker network ls
```

Inspect the source container:

```bash
docker inspect SOURCE_CONTAINER
```

Inspect the destination container:

```bash
docker inspect DESTINATION_CONTAINER
```

Compare their network attachments.

## Corrective Principle

Both containers must participate in a suitable shared networking environment for ordinary user-defined bridge DNS discovery.

---

# 66. TROUBLESHOOTING: DNS SUCCEEDS BUT CONNECTION FAILS

## Scenario

A client resolves:

```text
application-api
```

to an IP address.

However, its TCP connection fails.

## Interpretation

DNS resolution demonstrates address discovery.

It does not establish that the application is accepting connections.

## Possible Causes

- Service process not running.
- Wrong port.
- Application listening only on loopback.
- Firewall restriction.
- Application startup failure.
- Service not yet ready.

## Investigation

1. Inspect the destination container's state.
2. Read application logs.
3. Verify the listening configuration.
4. Verify the destination port.
5. Test the expected endpoint.

---

# 67. TROUBLESHOOTING: INCORRECT USE OF LOCALHOST

## Scenario

A backend container has the configuration:

```text
REDIS_HOST=localhost
```

Redis runs in another container.

## Problem

The backend attempts to reach its own loopback interface instead of the Redis container.

## Correction

On an appropriate user-defined network, use the logical Redis service hostname.

Example:

```text
REDIS_HOST=lecture10-redis
```

## Required Understanding

A separate container is not automatically reachable through the local loopback interface of the application container.

---

# 68. TROUBLESHOOTING: WRONG APPLICATION PORT

## Scenario

A database server listens on TCP port 6379.

A client attempts to connect to:

```text
database:6380
```

## Problem

The client uses an incorrect destination port.

## Correction

Verify the actual application listening port and update the client configuration.

## Important Distinction

Host-published port mappings do not ordinarily determine the internal port used for same-network container communication.

---

# 69. TROUBLESHOOTING: PORT PUBLISHING CONFUSION

## Scenario

A developer publishes:

```text
127.0.0.1:8210:80
```

Another container attempts to connect to:

```text
lecture10-public:8210
```

## Problem

The application inside the destination container listens on port 80.

Host port 8210 belongs to the published host endpoint.

## Correct Internal Endpoint

```text
lecture10-public:80
```

## Principle

Internal container networking and host port publishing involve different destination endpoints.

---

# 70. TROUBLESHOOTING: APPLICATION AUTHENTICATION FAILURE

## Scenario

A Redis client successfully reaches the Redis server but receives an authentication error.

## Interpretation

The network may be functioning correctly.

The failure occurs at the application authorization or authentication layer.

## Investigation

1. Verify that Redis is running.
2. Verify name resolution.
3. Verify the destination port.
4. Examine the Redis authentication configuration.
5. Verify that the client provides the appropriate credentials.

## Principle

Network reachability does not imply permission to use an application service.

---

# 71. TROUBLESHOOTING: NETWORK REMOVAL FAILURE

## Scenario

The administrator executes:

```bash
docker network rm academic-network
```

Docker reports that the network remains in use.

## Explanation

Existing container endpoints remain attached.

## Investigation

```bash
docker network inspect academic-network
```

Identify the attached containers.

## Correction

Determine whether the containers should be disconnected or removed.

Do not forcibly disrupt unrelated workloads merely to remove a network.

---

# 72. TROUBLESHOOTING: UNEXPECTED CONTAINER IP ADDRESS

## Scenario

An administrator expects a container to use a specific IP address.

After recreation, the container receives a different one.

## Explanation

Docker dynamically manages address assignment unless the network and endpoint have been configured otherwise.

## Recommended Solution

Prefer stable logical hostnames for application-to-application communication.

Use explicit IP address management only when operational requirements justify it.

---

# PART IV — CONCEPTUAL SYNTHESIS

# 73. NETWORKING AND CONTAINER LIFECYCLES

## 73.1 Application Identity Versus Network Identity

A container has an administrative identity.

It also possesses network endpoints associated with its attached networks.

These should not be treated as identical concepts.

## 73.2 Container Replacement

Replacing a container may change its:

- Container identifier.
- Network endpoint.
- IP address.
- Process identifiers.

However, the replacement may reuse:

- The same image.
- The same network.
- The same logical container name.
- The same application configuration.
- The same persistent volume.

## 73.3 Architectural Benefit

Network naming allows application components to refer to logical service identities rather than particular network endpoint addresses.

This supports repeatable application deployment.

---

# 74. NETWORKING AND PERSISTENT STORAGE

Lecture 09 established that application data can be stored independently of container execution.

Lecture 10 establishes that application communication can be organized independently of host port publishing.

These principles can be combined.

```text
               APPLICATION CONTAINER
                        |
                        |
                  DOCKER NETWORK
                        |
                        v
                 REDIS CONTAINER
                        |
                        |
                    /data
                        |
                        v
                  NAMED VOLUME
```

The Redis container provides a network service.

The named volume provides persistent storage.

The two mechanisms address different system requirements.

A complete application often needs both.

---

# 75. NETWORKING AND ENVIRONMENT VARIABLES

Applications should generally receive network destination information through configurable settings.

For example:

```text
REDIS_HOST=redis
REDIS_PORT=6379
```

This avoids hard-coding container-specific network addresses in application source code.

The application image can remain unchanged across environments.

The runtime configuration supplies the appropriate service hostname and port.

This combines the concepts studied in Lectures 08 and 10.

---

# 76. INTRODUCTION TO MULTI-CONTAINER APPLICATION DESIGN

Consider an application with three services.

**Frontend:** Receives browser requests.

**Backend:** Implements application logic.

**Database:** Stores application data.

A possible Docker network architecture is:

```text
                   WEB BROWSER
                        |
                        v
               PUBLISHED HOST PORT
                        |
                        v
                 FRONTEND CONTAINER
                        |
                        |
                 FRONTEND NETWORK
                        |
                        v
                  API CONTAINER
                        |
                        |
                  BACKEND NETWORK
                        |
                        v
                 DATABASE CONTAINER
                        |
                        v
                    VOLUME
```

The frontend can communicate with the API.

The API can communicate with the database.

The database need not be attached to the frontend network.

The database also need not publish its port to the host.

This architecture illustrates how networking and storage can be combined to organize a multi-service system.

---

# 77. LIMITATIONS OF MANUAL MULTI-CONTAINER MANAGEMENT

The laboratory demonstrates that Docker CLI commands can create and operate multi-container architectures.

However, manually configuring several containers introduces complexity.

Administrators must manage:

- Container creation.
- Image references.
- Network creation.
- Network attachments.
- Environment variables.
- Port publishing.
- Persistent volumes.
- Startup configuration.
- Logs.
- Cleanup.

As the number of services increases, maintaining these settings through individual commands becomes more difficult.

A declarative application configuration can reduce this complexity.

Docker Compose provides such an approach.

The following lectures will introduce its structure and operation.

---

# PART V — COMMON MISUNDERSTANDINGS

# 78. CONCEPTUAL ERRORS

## Misunderstanding 1

**All Docker containers automatically communicate by name.**

Incorrect.

Automatic name-based discovery depends on appropriate network configuration.

## Misunderstanding 2

**Containers require published host ports to communicate with one another.**

Incorrect.

Containers sharing a suitable network can communicate using internal endpoints.

## Misunderstanding 3

**EXPOSE creates a network access rule.**

Incorrect.

The `EXPOSE` instruction declares image metadata.

## Misunderstanding 4

**Container IP addresses remain fixed forever.**

Incorrect.

Addresses can change when containers or network endpoints are recreated.

## Misunderstanding 5

**localhost refers to the Docker host from inside every container.**

Incorrect.

It ordinarily refers to the container's own network namespace.

## Misunderstanding 6

**Docker DNS resolves every container name from every network.**

Incorrect.

Automatic container-name resolution is network-scoped.

## Misunderstanding 7

**A successful DNS lookup proves that the service is healthy.**

Incorrect.

DNS resolution does not establish application readiness.

## Misunderstanding 8

**Two containers on different user-defined bridge networks can always communicate directly.**

Incorrect.

Network isolation ordinarily restricts direct communication between separate bridge networks.

## Misunderstanding 9

**Attaching a container to a second network changes its image.**

Incorrect.

Network attachment modifies runtime networking configuration.

It does not rebuild the image.

## Misunderstanding 10

**A running container always has access to its required dependencies.**

Incorrect.

The container may remain running after losing network connectivity.

## Misunderstanding 11

**An internal Docker network guarantees complete isolation from the host.**

Incorrect.

Internal networking restricts ordinary external connectivity but is not an absolute host security boundary.

## Misunderstanding 12

**An unpublished Redis port is automatically secure.**

Incorrect.

Connected containers and other permitted network paths may still reach it.

Application-level security remains necessary.

## Misunderstanding 13

**Docker automatically encrypts all communication between containers.**

Incorrect.

Transport encryption requires appropriate configuration and protocols.

## Misunderstanding 14

**Multiple containers sharing an alias form a complete load-balanced application.**

Incorrect.

Alias-based DNS resolution alone does not provide all required load balancing, health checking, and failure-management behavior.

## Misunderstanding 15

**Host networking is equivalent to bridge networking.**

Incorrect.

Host networking changes the network isolation model.

---

# 79. IMPORTANT TECHNICAL TERMINOLOGY

| Term | Academic definition |
|---|---|
| Container networking | Communication infrastructure associated with container processes |
| Network namespace | Isolated Linux network environment |
| Virtual Ethernet pair | Connected virtual interfaces used between networking environments |
| Linux bridge | Software mechanism connecting network interfaces |
| Network driver | Component implementing a Docker network type |
| Default bridge | Built-in Docker bridge network |
| User-defined bridge | Explicitly created Docker bridge network |
| Network endpoint | Container attachment to a network |
| IPAM | IP Address Management |
| Subnet | Defined portion of an IP address space |
| Gateway | Endpoint used for routing toward other networks |
| DNS | Domain Name System |
| DNS resolver | Component responsible for resolving names |
| Embedded DNS | Docker-provided resolver supporting container discovery |
| Service discovery | Identification of service network endpoints |
| Container hostname | Logical name used to identify a container or endpoint |
| Network alias | Additional network-scoped hostname |
| Network isolation | Separation and restriction of network communication paths |
| Network attachment | Association between a container and a network |
| Multi-homed container | Container attached to multiple networks |
| Bridge driver | Docker driver supporting single-host bridge networking |
| Host networking | Network mode sharing host network facilities |
| None networking | Network mode disabling ordinary external connectivity |
| Overlay network | Network spanning supported multi-host environments |
| Macvlan | Driver integrating containers with Ethernet addressing |
| Ipvlan | Driver providing selected IP-layer integration |
| Internal network | Network configured to restrict external connectivity |
| TCP endpoint | IP address and TCP port combination |
| Application listener | Process accepting network connections |
| Network reachability | Ability to exchange traffic with an endpoint |
| Application readiness | State in which a service can perform intended work |
| Port publishing | Mapping of host endpoints to container ports |
| Transport encryption | Protection of network communication through cryptographic mechanisms |

---

# PART VI — FORMAL ACADEMIC ASSESSMENT

# 80. PART A — FORMAL DEFINITIONS

Provide precise technical definitions for:

1. Network namespace.
2. Virtual Ethernet pair.
3. Linux bridge.
4. Docker network driver.
5. User-defined bridge network.
6. DNS.
7. Embedded DNS resolver.
8. Network alias.
9. Service discovery.
10. Network isolation.
11. Network endpoint.
12. Multi-homed container.
13. Internal network.
14. Host networking.
15. Overlay networking.

---

# 81. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain how Linux network namespaces contribute to container isolation.

**Question 2.**

Describe the purpose of virtual Ethernet interfaces in Docker bridge networking.

**Question 3.**

Explain the differences between Docker's default bridge and user-defined bridge networks.

**Question 4.**

Describe how Docker's embedded DNS resolver supports container-name discovery.

**Question 5.**

Explain why the address `127.0.0.11` appears in resolver configuration on user-defined Docker networks.

**Question 6.**

Explain why a container name is not automatically resolvable from the host computer.

**Question 7.**

Describe why internal container communication does not ordinarily require host port publishing.

**Question 8.**

Explain the role of a network alias.

**Question 9.**

Describe why applications should generally avoid hard-coded container IP addresses.

**Question 10.**

Explain how network isolation can support application security.

**Question 11.**

Describe the purpose of `docker network connect`.

**Question 12.**

Explain how a container attached to two networks differs from a container attached to only one.

**Question 13.**

Describe the effect of `docker network disconnect`.

**Question 14.**

Explain why successful DNS resolution does not guarantee successful application communication.

**Question 15.**

Compare bridge, host, none, and overlay networking.

---

# 82. PART C — COMMAND INTERPRETATION

Analyze:

```bash
docker network create --driver bridge application-network
```

Answer:

1. What Docker object is created?
2. What is the selected network driver?
3. What is the network name?
4. Does the command automatically start an application container?

Analyze:

```bash
docker run -d --name web --network application-network nginx:alpine
```

Answer:

5. What is the container name?
6. What is the selected network?
7. Is a host port published?
8. Can a suitable peer on the same user-defined network normally resolve `web`?

Analyze:

```bash
docker network connect application-network existing-container
```

Answer:

9. What operation is performed?
10. Does the operation require image rebuilding?
11. Can a container be connected to more than one Docker network?

Analyze:

```bash
docker network disconnect application-network existing-container
```

Answer:

12. What attachment is removed?
13. What may happen to application connections using that network?
14. Does the container necessarily stop?
15. Does the command remove the original container image?

---

# 83. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Database Hostname Failure

A backend container contains the configuration:

```text
DATABASE_HOST=localhost
```

The database runs in a separate container.

The backend cannot connect.

Analyze the cause.

Explain the correct use of Docker service names in a user-defined network.

## Case Study 2 — Incorrect Network Membership

A web application container is connected to `frontend-network`.

Its database is connected only to `backend-network`.

The application cannot resolve the database hostname.

Explain the architecture problem.

Propose a configuration that provides the required communication without granting unnecessary network access.

## Case Study 3 — Dynamic IP Address Changes

A developer records a database container's IP address and places it in the application configuration.

After the database container is replaced, the application cannot connect.

Explain why the configuration failed.

Discuss how network-scoped DNS can improve reliability.

## Case Study 4 — Internal Service Exposure

A Redis container is connected to a user-defined network.

Its host port is not published.

Another container on the same network can reach Redis.

Evaluate whether this behavior is expected.

Explain why Redis authentication and access control remain important.

## Case Study 5 — Running but Unavailable

A backend container remains running after it loses its network connection to Redis.

The application begins returning errors.

Explain why Docker process state and application dependency availability are different properties.

Recommend an investigation procedure.

## Case Study 6 — Shared Network Alias

Several application containers share the alias:

```text
application
```

A client uses the alias to select a destination.

Explain why this arrangement does not guarantee that every request is distributed evenly or sent only to healthy containers.

Discuss the additional mechanisms required for robust service availability.

---

# 84. PRACTICAL ASSESSMENT

**Total available marks: 100**

| Assessment category | Marks |
|---|---:|
| Networking architecture | 15 |
| User-defined network creation | 15 |
| DNS and name resolution | 20 |
| Container-to-container communication | 20 |
| Network isolation and dynamic attachment | 15 |
| Redis service communication | 10 |
| Laboratory documentation | 5 |
| **Total** | **100** |

**Recommended passing score:** 80/100.

The student must demonstrate both successful networking operations and accurate explanations of the mechanisms involved.

---

# 85. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Container Network Architecture and Service Discovery in Docker

Prepare an academic report of approximately 1,200–1,700 words addressing:

**“Docker Networking: Namespace Isolation, Bridge Network Architecture, DNS-Based Service Discovery, and Secure Multi-Container Communication.”**

The report must include:

1. An introduction to container networking.
2. An explanation of Linux network namespaces.
3. A description of virtual Ethernet interfaces.
4. A discussion of Linux bridges.
5. A comparison of Docker network drivers.
6. A comparison of default and user-defined bridge networks.
7. An explanation of Docker's embedded DNS resolver.
8. An analysis of network aliases.
9. A discussion of service discovery.
10. An explanation of network isolation.
11. An examination of dynamic network attachment.
12. A discussion of multi-homed containers.
13. An analysis of internal versus host-published communication.
14. A security evaluation.
15. An explanation of the Nginx and Redis laboratory.
16. A technical conclusion.

The report must contain at least two networking architecture diagrams and appropriate Docker CLI examples.

---

# 86. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 11, the student should be able to complete the following tasks independently.

## Architecture

- [ ] Explain a Linux network namespace.
- [ ] Describe virtual Ethernet pairs.
- [ ] Explain Linux bridge networking.
- [ ] Distinguish container and host networking environments.
- [ ] Explain the purpose of Docker network drivers.

## Docker Networks

- [ ] List Docker networks.
- [ ] Inspect the default bridge.
- [ ] Create a user-defined bridge.
- [ ] Inspect network subnet and gateway information.
- [ ] Remove a user-defined network safely.
- [ ] Explain network isolation.
- [ ] Describe internal networks.

## DNS and Discovery

- [ ] Explain DNS resolution.
- [ ] Identify Docker's embedded DNS address.
- [ ] Resolve a container name on a user-defined network.
- [ ] Configure a network alias.
- [ ] Explain network-scoped service discovery.
- [ ] Explain why hard-coded IP addresses can be fragile.

## Container Communication

- [ ] Run Nginx on a user-defined network.
- [ ] Retrieve its webpage from another container.
- [ ] Explain why host port publishing is unnecessary for internal communication.
- [ ] Connect a running container to an additional network.
- [ ] Verify network connectivity after attachment.
- [ ] Disconnect a container from a network.
- [ ] Investigate name resolution across isolated networks.
- [ ] Distinguish network reachability from application readiness.

## Redis Communication

- [ ] Start Redis on a user-defined network.
- [ ] Connect a Redis client by hostname.
- [ ] Verify the Redis PING response.
- [ ] Store and retrieve a Redis value.
- [ ] Explain why Redis does not require a host-published port in this laboratory.
- [ ] Explain why authentication remains important.

## Troubleshooting

- [ ] Inspect container network attachments.
- [ ] Diagnose an incorrect hostname.
- [ ] Diagnose an incorrect port.
- [ ] Explain localhost behavior.
- [ ] Diagnose isolated-network communication failures.
- [ ] Identify application-level authentication failures.
- [ ] Examine network-related application logs.
- [ ] Complete controlled laboratory cleanup.

**Completion standard:**

The student should be able to construct user-defined Docker networks, attach and isolate containers, perform name-based service discovery, and establish application-level communication without relying on unnecessary host port publishing.

---

# 87. LECTURE SUMMARY

Docker networking provides the infrastructure through which isolated container processes communicate with one another and with external systems.

Linux network namespaces establish separate network environments for containerized workloads.

Virtual Ethernet interfaces and Linux bridges support connectivity among containers attached to conventional bridge networks.

Docker provides multiple network drivers, each designed for particular deployment requirements.

The bridge driver is especially important for ordinary single-host multi-container applications.

User-defined bridge networks offer advantages over the default bridge, including automatic name-based resolution and explicit grouping of related containers.

Docker's embedded DNS resolver enables containers to discover one another through network-scoped hostnames and aliases.

This reduces dependence on dynamically assigned container IP addresses.

Containers on the same suitable network can communicate directly using their internal listening ports.

They do not require host-published ports for this communication.

Separate user-defined networks provide useful communication boundaries.

Dynamic network attachment allows a running container to join additional networking environments.

Network disconnection can remove communication pathways without necessarily terminating the container's main process.

The practical laboratory demonstrates these principles using Nginx and Redis.

The exercises establish that successful service communication depends on several related factors:

- Appropriate network membership.
- Correct name resolution.
- Correct destination port.
- A functioning application listener.
- Compatible application protocols.
- Satisfied authentication requirements.

The laboratory also demonstrates that network reachability, application readiness, and data persistence are separate system properties.

**The central principle of this lecture is that Docker networking enables modular applications to communicate through explicitly defined, discoverable, and controllable network relationships while preserving meaningful boundaries between services.**

---

# 88. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. *Docker Networking Overview.*  
https://docs.docker.com/engine/network/

[2] Docker Inc. *Docker Bridge Network Driver.*  
https://docs.docker.com/engine/network/drivers/bridge/

[3] Docker Inc. *Docker Network Drivers.*  
https://docs.docker.com/engine/network/drivers/

[4] Docker Inc. *Docker Network Command Reference.*  
https://docs.docker.com/reference/cli/docker/network/

[5] Docker Inc. *Docker Network Create.*  
https://docs.docker.com/reference/cli/docker/network/create/

[6] Docker Inc. *Docker Network Inspect.*  
https://docs.docker.com/reference/cli/docker/network/inspect/

[7] Docker Inc. *Docker Network Connect.*  
https://docs.docker.com/reference/cli/docker/network/connect/

[8] Docker Inc. *Docker Network Disconnect.*  
https://docs.docker.com/reference/cli/docker/network/disconnect/

[9] Docker Inc. *Docker Host Network Driver.*  
https://docs.docker.com/engine/network/drivers/host/

[10] Docker Inc. *Docker Overlay Network Driver.*  
https://docs.docker.com/engine/network/drivers/overlay/

[11] Docker Inc. *Docker Port Publishing.*  
https://docs.docker.com/engine/network/port-publishing/

[12] Docker Inc. *Packet Filtering and Firewalls.*  
https://docs.docker.com/engine/network/packet-filtering-firewalls/

[13] Docker Inc. *Networking on Docker Desktop.*  
https://docs.docker.com/desktop/features/networking/

[14] Redis. *Redis Security.*  
https://redis.io/docs/latest/operate/oss_and_stack/management/security/

[15] Docker Inc. *Docker Container Run.*  
https://docs.docker.com/reference/cli/docker/container/run/

## Recommended Reading Sequence

Begin with references [1], [2], and [3] to establish Docker's networking architecture and the differences among its network drivers.

Continue with references [4] through [8] to understand network creation, inspection, connection, and disconnection.

References [9] and [10] introduce networking models beyond ordinary single-host bridge networking.

References [11] and [12] provide further information about port publishing and network security.

Reference [14] is important for understanding why Redis should not be exposed to untrusted clients without suitable protection.

---

# 89. FINAL LECTURE CONCLUSION

Docker networking is an essential component of containerized application architecture.

Container isolation provides independent execution environments, but modern applications frequently depend on communication among multiple services.

The Docker networking subsystem establishes controlled pathways through which these services can exchange information.

User-defined bridge networks provide a practical foundation for organizing multi-container applications on a single Docker Engine host.

Their integrated DNS functionality allows containers to communicate using logical names rather than fixed IP addresses.

This capability improves maintainability when containers are replaced and network endpoints change.

Network aliases introduce further flexibility by allowing service identities to be separated from particular administrative container names.

Network attachment and disconnection operations demonstrate that a container's communication environment can change independently of its image or principal process.

Network isolation offers useful separation among application groups, but it must be combined with appropriate authentication, authorization, transport security, and host configuration.

The Nginx and Redis experiments illustrate an important deployment pattern.

Application components can communicate over internal Docker networks without exposing every service through the host's networking interfaces.

This pattern supports modular architecture and reduces unnecessary external exposure.

Finally, Docker network management must be considered together with the storage and runtime-configuration mechanisms developed in preceding lectures.

A complete multi-container application requires coordinated management of:

1. Application images.
2. Container processes.
3. Runtime configuration.
4. Network communication.
5. Persistent storage.
6. Application dependencies.

These concepts form the foundation for Docker Compose, which introduces a declarative method for configuring and operating multi-container applications.

---

**END OF LECTURE 10**

**Next Lecture:** Lecture 11 — Introduction to Docker Compose: Declarative Multi-Container Configuration, YAML Structure, Services, Networks, Volumes, and Application Lifecycle Management.
