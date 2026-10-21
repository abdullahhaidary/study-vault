# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 16 — DOCKER IMAGE AND CONTAINER SECURITY: LEAST PRIVILEGE, LINUX CAPABILITIES, SECURITY PROFILES, SECRET MANAGEMENT, VULNERABILITY ANALYSIS, AND SUPPLY-CHAIN PROTECTION

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 16 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 5–7 hours  
**Lecture Type:** Formal Academic Lecture, Security Laboratory, Risk Assessment, and Technical Examination

**Prerequisites:**

- Lecture 01 — Docker Architecture and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Runtime Inspection.
- Lecture 04 — Docker Images and Registries.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Configuration.
- Lecture 07 — Week One Capstone.
- Lecture 08 — Networking and Runtime Configuration.
- Lecture 09 — Persistent Storage.
- Lecture 10 — Network Isolation and Service Discovery.
- Lecture 11 — Docker Compose.
- Lecture 12 — Flask and Redis Application Engineering.
- Lecture 13 — Advanced Docker Compose.
- Lecture 14 — Week Two Capstone.
- Lecture 15 — Multi-Stage Builds and Image Optimization.

---

# 1. PURPOSE OF THE LECTURE

Container security is the systematic protection of containerized applications, container images, the container runtime, and their supporting infrastructure against unauthorized access, unintended privilege, exploitation, data exposure, and operational disruption.

Docker containers provide process isolation using operating-system mechanisms.

However, process isolation should not be confused with absolute separation from the host.

Containers ordinarily share the kernel of the system running Docker Engine.

An attacker who compromises a containerized application may attempt to access resources beyond the intended boundaries of that application.

The consequences depend on factors including:

1. The privileges of the compromised application process.
2. The Linux capabilities available to the container.
3. Filesystem and device access.
4. Network configuration.
5. Security profile enforcement.
6. Kernel and runtime vulnerabilities.
7. Docker daemon access.
8. Mounted secrets.
9. Host configuration.
10. Additional protective controls.

A secure container deployment therefore requires multiple coordinated safeguards.

The lecture introduces the principle of defense in depth.

Rather than relying on one setting, a secure system combines several controls that reduce the opportunities available to an attacker.

The practical laboratory will compare two versions of the same Python HTTP application.

The first uses comparatively permissive default settings.

The second introduces a structured set of hardening measures.

The objective is to observe and explain their effects without performing attacks against external systems.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Define container security.
2. Explain the container threat model.
3. Identify important security assets and trust boundaries.
4. Explain the shared-kernel security implications of containers.
5. Distinguish container isolation from virtual-machine isolation.
6. Define least privilege.
7. Explain the significance of UID and GID.
8. Configure non-root container execution.
9. Distinguish non-root application execution from rootless Docker Engine.
10. Explain Linux user namespaces.
11. Describe Docker user namespace remapping.
12. Define Linux capabilities.
13. Explain why capabilities provide more precise privilege management than unrestricted root execution.
14. Use `cap_drop`.
15. Explain the risks of privileged containers.
16. Define the `no-new-privileges` security restriction.
17. Explain seccomp syscall filtering.
18. Describe AppArmor and SELinux.
19. Explain the security role of network namespaces.
20. Apply least-connectivity network design.
21. Define a read-only root filesystem.
22. Configure temporary writable filesystems.
23. Explain the security considerations of bind mounts and volumes.
24. Describe the risks associated with Docker daemon socket access.
25. Define a secret.
26. Distinguish secrets from ordinary environment variables.
27. Explain Docker Compose runtime secrets.
28. Explain BuildKit build-time secrets.
29. Explain why Dockerfile ARG and ENV are unsuitable for confidential credentials.
30. Define image vulnerability scanning.
31. Explain CVEs and severity ratings.
32. Describe the purpose of an SBOM.
33. Explain image provenance.
34. Distinguish image tags and digests.
35. Identify common software supply-chain risks.
36. Explain resource constraints as a security-relevant operational control.
37. Configure memory, CPU, and process limits.
38. Build baseline and hardened container images.
39. Inspect container security configuration.
40. Demonstrate the effect of a read-only filesystem.
41. Inspect runtime secrets without exposing their values.
42. Analyze container security profiles.
43. Complete a structured security assessment.
44. Evaluate the limitations of the resulting hardened deployment.

---

# PART I — CONTAINER SECURITY FOUNDATIONS

# 3. INFORMATION SECURITY OBJECTIVES

## 3.1 Confidentiality

Confidentiality concerns preventing unauthorized disclosure of information.

Examples include protecting:

- Database credentials.
- API tokens.
- Private customer data.
- Encryption keys.
- Internal application configuration.

## 3.2 Integrity

Integrity concerns preventing unauthorized modification of data and software.

Examples include:

- Preventing modification of application binaries.
- Protecting database records.
- Detecting unauthorized image changes.
- Preserving the correctness of configuration files.

## 3.3 Availability

Availability concerns maintaining access to required services.

Examples include:

- Preventing resource exhaustion.
- Recovering from process failures.
- Protecting application dependencies.
- Maintaining service health.

## 3.4 Security Model

```text
             INFORMATION SECURITY
                       |
           +-----------+-----------+
           |           |           |
           v           v           v
    CONFIDENTIALITY  INTEGRITY  AVAILABILITY
           |           |           |
           +-----------+-----------+
                       |
                       v
               CONTAINER SECURITY
```

These objectives are interconnected.

A container security control may improve one objective while introducing tradeoffs relevant to another.

---

# 4. THE CONTAINER THREAT MODEL

## 4.1 Definition

A threat model is a structured description of a system's assets, trust boundaries, potential threats, and security controls.

The purpose of threat modeling is to identify what must be protected and how it might be exposed.

## 4.2 Important Assets

For a containerized application, assets may include:

- Application source code.
- Container image artifacts.
- Runtime credentials.
- Persistent database files.
- Network communication.
- Host filesystem data.
- Docker daemon permissions.
- Registry authentication credentials.
- Build pipeline configuration.

## 4.3 Potential Threat Sources

Threats may originate from:

- Malicious external clients.
- Compromised application dependencies.
- Untrusted container images.
- Incorrectly configured services.
- Insider misuse.
- Compromised build infrastructure.
- Exposed management interfaces.
- Vulnerable application code.

## 4.4 Trust Boundaries

A trust boundary separates components with different privileges or trust assumptions.

Examples include:

1. Internet client to web application.
2. Web application to internal database.
3. Container process to host kernel.
4. Container process to mounted host storage.
5. Docker client to Docker daemon.
6. Build infrastructure to container registry.

## 4.5 Architectural Principle

Security controls should correspond to the capabilities an application actually requires.

A web service that only returns HTTP responses does not ordinarily require broad host filesystem access or unrestricted administrative capabilities.

---

# 5. CONTAINERS AND THE SHARED KERNEL

## 5.1 Docker Container Architecture

On a conventional Linux Docker Engine host, containers share the host's Linux kernel.

Isolation is implemented through kernel mechanisms and runtime configuration.

## 5.2 Namespace Isolation

Linux namespaces isolate selected resource views.

Relevant namespace types include:

- PID.
- Network.
- Mount.
- UTS.
- IPC.
- User.
- Cgroup.

## 5.3 Shared Kernel Consequence

A process inside a container continues to interact with the Linux kernel through system calls.

The kernel therefore remains an important security boundary.

## 5.4 Conceptual Diagram

```text
                  DOCKER HOST
                       |
             SHARED LINUX KERNEL
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
    CONTAINER A    CONTAINER B    CONTAINER C
        |              |              |
        v              v              v
   APPLICATION     DATABASE        WORKER
```

## 5.5 Security Interpretation

A container is not automatically equivalent to a separate virtual machine.

However, Docker Desktop commonly runs Linux containers inside a managed Linux virtual machine on non-Linux host systems.

The exact boundary between the containers and the physical host therefore depends on the deployment architecture.

---

# 6. DEFENSE IN DEPTH

## 6.1 Definition

Defense in depth is the use of multiple security controls so that failure of one control does not necessarily expose the entire system.

## 6.2 Container Defense Layers

A container deployment may implement:

1. Trusted images.
2. Dependency updates.
3. Non-root execution.
4. Restricted Linux capabilities.
5. Default seccomp filtering.
6. Mandatory access-control profiles.
7. Network separation.
8. Read-only filesystems.
9. Controlled secrets.
10. Resource constraints.
11. Protected Docker daemon access.
12. Monitoring and vulnerability assessment.

## 6.3 Diagram

```text
                APPLICATION
                     |
              NON-ROOT USER
                     |
             CAPABILITY LIMITS
                     |
               SECCOMP RULES
                     |
             FILESYSTEM POLICY
                     |
             NETWORK CONTROLS
                     |
              CONTAINER RUNTIME
                     |
                 HOST SECURITY
```

No single layer guarantees complete security.

---

# 7. PRINCIPLE OF LEAST PRIVILEGE

## 7.1 Definition

The principle of least privilege states that a process or user should receive only the permissions required to perform its intended responsibilities.

## 7.2 Example

An HTTP application may need permission to:

- Read its application files.
- Bind to an unprivileged TCP port.
- Send responses to clients.
- Read selected configuration files.

It does not ordinarily require permission to:

- Modify arbitrary host files.
- Manage host network interfaces.
- Access Docker's administrative API.
- Create device nodes.
- Load kernel modules.
- Alter system time.

## 7.3 Engineering Application

Least privilege can be applied through:

- Process identity.
- Linux capabilities.
- Filesystem permissions.
- Network membership.
- Device access.
- Security profiles.
- Secrets authorization.

---

# 8. ROOT AND NON-ROOT PROCESSES

## 8.1 UID

A user identifier, or UID, identifies a user in a Unix-like operating-system security model.

The numeric UID:

```text
0
```

traditionally identifies the root user.

## 8.2 GID

A group identifier, or GID, identifies a group.

File permissions and process credentials may depend on user and group identities.

## 8.3 Container Root

A process running as UID 0 inside a container has root identity within its relevant user namespace.

However, its effective authority also depends on capabilities, namespace configuration, security profiles, and other controls.

## 8.4 Default Image Behavior

Some container images execute as root unless a different user is configured.

## 8.5 Recommended Practice

Where practical, application containers should run using a non-root identity.

---

# 9. THE DOCKERFILE USER INSTRUCTION

## 9.1 Definition

The Dockerfile `USER` instruction configures the default identity used for subsequent supported build and runtime operations.

## 9.2 Example

```dockerfile
USER 10001:10001
```

The image specifies UID and GID 10001.

## 9.3 Named Users

An image may create a named application user.

Example:

```dockerfile
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 \
       --gid 10001 \
       --no-create-home \
       appuser
```

Then:

```dockerfile
USER appuser
```

## 9.4 Numeric Identities

Numeric identities can also be used without relying on a username lookup.

## 9.5 Important Qualification

Non-root execution reduces ordinary process privileges.

It does not eliminate application vulnerabilities or prevent access to files and network services that the non-root process is authorized to use.

---

# 10. NON-ROOT EXECUTION VERSUS ROOTLESS DOCKER

These concepts are different.

## 10.1 Non-Root Application Container

The Docker daemon may still operate with elevated host privileges.

Only the application process is configured to run as a non-root user.

## 10.2 Rootless Docker

Rootless Docker is a Docker Engine operating mode in which the Docker daemon and containers run without ordinary root privileges on the host, using supported user namespace mechanisms.

## 10.3 Comparison

| Characteristic | Non-root application | Rootless Docker Engine |
|---|---|---|
| Application process non-root | Yes | Depends on container configuration and namespace mapping |
| Docker daemon rootless | Not necessarily | Yes |
| Uses user namespaces for daemon isolation | Not necessarily | Yes |
| Requires Docker Engine configuration changes | Usually no | Yes |
| Protects against every container vulnerability | No | No |

## 10.4 Important Principle

Configuring `USER 10001` in a Dockerfile does not automatically enable rootless Docker Engine.

---

# 11. USER NAMESPACES

## 11.1 Definition

A Linux user namespace allows user and group identifiers to have different meanings or mappings inside and outside the namespace.

## 11.2 Security Benefit

A process may appear to have UID 0 within a container's user namespace while being mapped to a less-privileged identity on the host.

## 11.3 User Namespace Remapping

Docker supports user namespace remapping in suitable Engine configurations.

## 11.4 Limitation

In Docker's userns-remap mode, the Docker daemon itself may still run with root privileges.

Rootless Docker addresses the daemon privilege model differently.

## 11.5 Filesystem Consequences

UID and GID mapping affects ownership and permission interpretation, especially for bind-mounted host directories.

---

# 12. LINUX CAPABILITIES

## 12.1 Definition

Linux capabilities divide certain traditionally root-associated privileges into more specific units.

Instead of treating all administrative powers as one indivisible privilege, the kernel can evaluate specific capability requirements.

## 12.2 Examples

| Capability | General purpose |
|---|---|
| `CAP_CHOWN` | Change file ownership under supported conditions |
| `CAP_DAC_OVERRIDE` | Bypass selected filesystem permission checks |
| `CAP_NET_BIND_SERVICE` | Bind privileged network ports |
| `CAP_NET_RAW` | Use raw network sockets |
| `CAP_NET_ADMIN` | Perform selected network administration operations |
| `CAP_SYS_ADMIN` | Broad range of privileged system operations |
| `CAP_SETUID` | Modify process user identity under supported conditions |
| `CAP_SETGID` | Modify process group identity under supported conditions |
| `CAP_SYS_TIME` | Modify system time under supported conditions |

## 12.3 Default Capability Set

Docker ordinarily provides a restricted default set of Linux capabilities rather than every possible capability.

## 12.4 Security Importance

Applications should not retain capabilities that are unnecessary for their function.

---

# 13. CAPABILITY DROPPING

## 13.1 Docker CLI

Docker supports:

```text
--cap-drop
```

Example:

```bash
docker run --cap-drop ALL IMAGE
```

## 13.2 Compose

```yaml
cap_drop:
  - ALL
```

## 13.3 Result

The container's permitted capabilities are reduced according to the runtime configuration.

## 13.4 Compatibility

Not every application can function with every capability removed.

Applications that need specialized system operations may require selected capabilities.

## 13.5 Recommended Approach

Start from the smallest practical privilege set.

Add only capabilities demonstrated to be necessary.

---

# 14. PRIVILEGED CONTAINERS

## 14.1 Definition

Docker supports an extended privilege mode:

```text
--privileged
```

Compose also supports:

```yaml
privileged: true
```

## 14.2 Consequences

Privileged mode substantially relaxes normal container restrictions, including device and capability access and aspects of security profile enforcement.

## 14.3 Security Risk

A privileged container may have access to powerful host-related operations unavailable to an ordinary container.

## 14.4 Recommended Practice

Do not use privileged mode to resolve routine application errors.

For example, an inability to write a file should be investigated as a filesystem permissions problem, not automatically addressed by granting broad privileges.

## 14.5 Laboratory Restriction

The practical laboratory will not create privileged containers.

---

# 15. NO NEW PRIVILEGES

## 15.1 Definition

The Linux `no_new_privs` mechanism restricts processes from gaining additional privileges through subsequent execution of programs.

## 15.2 Compose Configuration

```yaml
security_opt:
  - no-new-privileges:true
```

## 15.3 Security Purpose

This reduces opportunities for certain forms of privilege escalation through executable transitions.

## 15.4 Limitation

The mechanism does not remove privileges that a process already possesses.

It should be combined with an appropriately restricted initial process identity and capability set.

---

# 16. SECCOMP

## 16.1 Definition

Seccomp, or secure computing mode, is a Linux kernel mechanism used to restrict system-call operations available to a process.

## 16.2 System Calls

A system call is an interface through which userspace software requests operations from the kernel.

Examples of kernel-mediated activities include:

- Opening files.
- Creating processes.
- Managing sockets.
- Modifying memory mappings.
- Performing selected administrative operations.

## 16.3 Security Role

Seccomp can restrict a process from executing certain categories of system calls.

## 16.4 Docker Default Profile

Docker normally applies a default seccomp profile in supported Linux environments.

The default profile blocks selected system calls while permitting those needed by common containerized applications.

## 16.5 Recommended Practice

Keep Docker's default seccomp protections enabled unless a documented application requirement justifies a carefully reviewed alternative.

## 16.6 Dangerous Override

Disabling seccomp restrictions unnecessarily weakens container isolation.

It should not be treated as a standard troubleshooting solution.

---

# 17. APPARMOR AND SELINUX

## 17.1 Mandatory Access Control

Mandatory Access Control, abbreviated MAC, enforces security policies independent of ordinary user discretion.

## 17.2 AppArmor

AppArmor is a Linux security module that applies policy profiles to processes.

Docker can apply the `docker-default` AppArmor profile in supported environments.

## 17.3 SELinux

Security-Enhanced Linux, or SELinux, provides label-based mandatory access-control mechanisms.

Docker can integrate with SELinux policies on supported systems.

## 17.4 Relationship to Other Controls

Capabilities, seccomp, and mandatory access controls restrict different aspects of process behavior.

They are complementary rather than interchangeable.

## 17.5 Platform Qualification

The availability and enforcement of these mechanisms depend on the host kernel, Linux distribution, Docker configuration, and deployment platform.

---

# 18. FILESYSTEM SECURITY

## 18.1 Writable Root Filesystem

By default, a container commonly has a writable container filesystem layer.

Application processes can modify paths allowed by filesystem permissions and runtime policy.

## 18.2 Risk

An unnecessary writable filesystem may permit unauthorized modifications after application compromise.

## 18.3 Read-Only Root Filesystem

Compose supports:

```yaml
read_only: true
```

This prevents ordinary modifications to the container's root filesystem.

## 18.4 Important Qualification

Explicit writable mounts and suitable virtual filesystem locations may still provide write access.

A read-only root filesystem does not imply that every filesystem path inside the container is immutable.

---

# 19. TEMPORARY FILESYSTEMS

## 19.1 Definition

A tmpfs mount provides temporary filesystem storage.

## 19.2 Example

```yaml
tmpfs:
  - /tmp:size=16m
```

## 19.3 Purpose

Applications may require temporary writable storage even when the root filesystem is read-only.

## 19.4 Persistence

Tmpfs data is not intended to provide durable storage across container destruction.

## 19.5 Security Role

Using selected writable directories is often preferable to granting write access to the complete root filesystem.

## 19.6 Limitations

Temporary storage still consumes system resources and requires suitable access controls.

---

# 20. BIND MOUNT SECURITY

## 20.1 Definition

A bind mount exposes a selected host filesystem path inside a container.

## 20.2 Security Risk

A container with write access to a sensitive host path may modify or destroy host-managed files within the permissions available to the process.

## 20.3 Read-Only Bind Mount

Example:

```yaml
volumes:
  - ./config:/app/config:ro
```

The `ro` option requests read-only access through the mount.

## 20.4 Sensitive Paths

Avoid mounting unnecessary host paths such as:

- System configuration directories.
- Credential directories.
- Administrative private keys.
- Docker daemon sockets.
- Host device paths.

## 20.5 Architectural Principle

Mount only the required directories and provide the minimum required permissions.

---

# 21. THE DOCKER DAEMON SOCKET

## 21.1 Definition

The Docker daemon exposes a management API through configured transport endpoints.

On many Linux Engine installations, a Unix-domain socket is used for local Docker client communication.

A common socket path is:

```text
/var/run/docker.sock
```

## 21.2 Authority

A client that can control a privileged Docker daemon may gain extensive control over containers, images, networks, mounts, and host-related resources.

## 21.3 Security Consequence

Giving an untrusted container access to the Docker daemon socket is dangerous.

A process with sufficient daemon API access may be able to request operations far beyond its original application responsibilities.

## 21.4 Recommended Practice

Do not mount the Docker daemon socket into application containers unless the use case has been explicitly evaluated and appropriately protected.

## 21.5 Important Distinction

A process may be non-root inside its container yet still hold highly dangerous authority if it has unrestricted access to a privileged Docker daemon.

---

# 22. NETWORK SECURITY

## 22.1 Network Membership

Containers attached to the same suitable Docker network can communicate with one another through permitted network endpoints.

## 22.2 Least Connectivity

An application should only join networks required for its responsibilities.

## 22.3 Port Publishing

Internal services should not publish host ports unless necessary.

## 22.4 Host Networking

Host networking reduces ordinary network namespace separation.

Use it only when justified.

## 22.5 Transport Encryption

Docker bridge networking does not automatically encrypt all application traffic.

Sensitive communication may require TLS or another suitable security mechanism.

## 22.6 Network Isolation Limitations

A Docker network boundary is not a substitute for authentication or authorization.

---

# 23. RESOURCE EXHAUSTION

## 23.1 Definition

Resource exhaustion occurs when a process or collection of processes consumes enough system resources to impair the operation of itself or other workloads.

## 23.2 Examples

- Excessive memory allocation.
- Unbounded process creation.
- High CPU consumption.
- Excessive disk writes.
- Excessive network activity.

## 23.3 Container Resource Controls

Docker supports limits for resources such as:

- Memory.
- CPU.
- Process count.

## 23.4 Security Significance

Resource limits can reduce the impact of certain application faults and resource-exhaustion conditions.

However, resource limits alone do not provide complete protection against denial-of-service attacks.

---

# 24. RESOURCE LIMITS IN COMPOSE

## 24.1 Memory

Example:

```yaml
mem_limit: 256m
```

## 24.2 CPU

Example:

```yaml
cpus: 0.50
```

## 24.3 Process Count

Example:

```yaml
pids_limit: 128
```

## 24.4 Interpretation

These settings constrain selected resources used by the container.

Their enforcement depends on supported host and Docker Engine capabilities.

## 24.5 Engineering Principle

Set limits according to measured application requirements rather than arbitrary minimum values.

Excessively restrictive limits can create availability problems.

---

# PART II — SECRETS AND CREDENTIAL MANAGEMENT

# 25. DEFINITION OF A SECRET

A secret is sensitive information that should not be exposed to unauthorized parties.

Examples include:

- Database passwords.
- API authentication tokens.
- Private cryptographic keys.
- Service credentials.
- Certificates containing private-key material.

A secret may be needed during application execution or during image construction.

These are distinct lifecycle requirements.

---

# 26. WHY HARDCODED CREDENTIALS ARE DANGEROUS

## 26.1 Source-Code Exposure

A credential embedded in source code may be exposed through:

- Source repositories.
- Code reviews.
- Build archives.
- Debugging output.
- Accidental file sharing.

## 26.2 Image Exposure

A credential included in an image may be accessible to parties who can inspect the image or its filesystem layers.

## 26.3 Credential Rotation

Hardcoded credentials often require code or image changes when rotated.

## 26.4 Recommended Principle

Separate sensitive configuration from source code and image construction artifacts.

---

# 27. ENVIRONMENT VARIABLES AND SECRETS

## 27.1 Common Usage

Applications sometimes receive credentials through environment variables.

## 27.2 Risks

Environment values may be exposed through:

- Container inspection.
- Process environment access.
- Logging.
- Diagnostic tooling.
- Incorrect error reporting.

## 27.3 Qualification

Environment variables remain useful for ordinary non-sensitive runtime configuration.

However, their use for secrets requires careful consideration of the exposure model.

## 27.4 Important Distinction

Using an environment variable does not automatically encrypt or protect a credential.

---

# 28. DOCKER COMPOSE RUNTIME SECRETS

## 28.1 Definition

Compose supports declaring secrets as resources and granting access to selected services.

## 28.2 Example

```yaml
services:
  application:
    image: example/application
    secrets:
      - application_token

secrets:
  application_token:
    file: ./secrets/application-token.txt
```

## 28.3 Runtime Location

Secrets are commonly mounted under:

```text
/run/secrets/
```

A particular secret may be available as:

```text
/run/secrets/application_token
```

## 28.4 Access Control

Only services granted the secret through their configuration receive the corresponding secret mount.

## 28.5 Important Qualification

For local non-Swarm Docker Compose deployments, file-backed secrets are implemented using bind mounts.

They are not equivalent to an automatically encrypted distributed secret-management service.

Source-file permissions and host access remain relevant.

---

# 29. SECRET FILE PERMISSIONS

## 29.1 File Access

A non-root application must have appropriate permission to read a mounted secret file.

## 29.2 Compose Attributes

Compose supports selected secret-related ownership and mode attributes.

However, support differs according to the secret source.

For file-backed Compose secrets, UID and GID remapping and mode overrides may not behave as they do for other secret source types because the implementation uses bind mounts.

## 29.3 Operational Requirement

Verify that the intended application process can read the secret.

Do not respond to access problems by granting broad privileges to the complete container.

## 29.4 Security Principle

Real secret files should be protected by an appropriate source-storage and access-control policy.

---

# 30. BUILDKIT BUILD SECRETS

## 30.1 Definition

BuildKit can provide temporary secret values to selected Dockerfile build instructions.

## 30.2 Syntax

```dockerfile
RUN --mount=type=secret,id=build_token \
    some-build-operation
```

## 30.3 Build Invocation

```bash
docker build \
  --secret id=build_token,src=./secrets/build-token.txt \
  .
```

## 30.4 Lifetime

The secret is available during the selected build operation.

It is not automatically copied into the resulting image layer.

## 30.5 Limitation

A build command that deliberately prints or copies a secret can still expose it.

Secret mounts are a safer delivery mechanism, not a guarantee against careless build instructions.

---

# 31. BUILD SECRETS VERSUS RUNTIME SECRETS

| Characteristic | BuildKit secret | Compose runtime secret |
|---|---|---|
| Principal purpose | Build-time confidential input | Runtime confidential input |
| Typical mechanism | Temporary BuildKit mount | Service-specific secret mount |
| Common path | `/run/secrets/<id>` | `/run/secrets/<name>` |
| Automatically included in image | No | No |
| Requires explicit configuration | Yes | Yes |
| Automatically encrypted everywhere | No | No |
| Suitable for private credentials when carefully configured | Yes | Yes |

## Important Principle

Build-time credentials should not remain in the image unless the deployed application explicitly requires the corresponding data and an appropriate secure mechanism has been designed.

---

# PART III — IMAGE SECURITY AND SOFTWARE SUPPLY CHAINS

# 32. CONTAINER IMAGE TRUST

## 32.1 Definition

Image trust concerns confidence in the origin, integrity, contents, and maintenance of a container image.

## 32.2 Risks

An image may contain:

- Vulnerable operating-system packages.
- Vulnerable application libraries.
- Malicious software.
- Unnecessary privileged utilities.
- Misconfigured applications.
- Embedded credentials.
- Untrusted executable scripts.

## 32.3 Recommended Practices

1. Use reputable image sources.
2. Review image maintenance status.
3. Prefer explicit version references.
4. Review Dockerfiles and dependencies.
5. Scan images for known vulnerabilities.
6. Remove unnecessary software.
7. Maintain update procedures.

---

# 33. IMAGE TAGS AND DIGESTS

## 33.1 Tags

Example:

```text
python:3.12-slim
```

A tag identifies a named image version or variant.

Tags can be updated by publishers.

## 33.2 Digests

A digest identifies specific image content.

Conceptual example:

```text
python@sha256:<digest>
```

## 33.3 Supply-Chain Significance

Digest pinning improves control over the exact base image used.

## 33.4 Maintenance Tradeoff

Digest pinning requires deliberate updates to receive newly published fixes.

An immutable image reference does not guarantee that its contents are free of vulnerabilities.

---

# 34. COMMON VULNERABILITIES AND EXPOSURES

## 34.1 Definition

The Common Vulnerabilities and Exposures system, abbreviated CVE, assigns identifiers to publicly disclosed vulnerabilities.

## 34.2 Example Format

```text
CVE-YYYY-NNNNN
```

This represents the structure of a CVE identifier.

## 34.3 Important Distinction

A CVE identifier identifies a vulnerability record.

It does not by itself determine how exploitable the vulnerability is in a particular deployment.

## 34.4 Vulnerability Context

Risk evaluation may consider:

- Affected software version.
- Application exposure.
- Required attacker privileges.
- Exploit availability.
- Compensating controls.
- Whether the vulnerable component is reachable or used.

---

# 35. VULNERABILITY SEVERITY

## 35.1 CVSS

The Common Vulnerability Scoring System, or CVSS, provides standardized measures of vulnerability severity.

## 35.2 Severity Versus Risk

A high severity score does not automatically mean the vulnerability is equally dangerous in every deployment.

Actual operational risk depends on exposure and system context.

## 35.3 Remediation Priorities

A security team may prioritize:

1. Known exploited vulnerabilities.
2. Internet-reachable attack paths.
3. High-impact vulnerabilities.
4. Vulnerabilities in privileged components.
5. Available fixes.
6. Business-critical workloads.

## 35.4 Important Principle

Vulnerability management requires judgment informed by evidence.

It is not simply a process of counting CVEs.

---

# 36. DOCKER SCOUT

## 36.1 Definition

Docker Scout is a Docker tool for analyzing image contents, software packages, and known vulnerabilities.

## 36.2 CLI Example

```bash
docker scout cves IMAGE
```

## 36.3 Example

```bash
docker scout cves lecture16:hardened
```

## 36.4 Requirements

Docker Scout availability may depend on:

- Docker installation.
- Installed CLI components.
- Authentication.
- Organization configuration.
- Supported service features.

## 36.5 Output

The tool may report:

- Detected packages.
- Vulnerability identifiers.
- Severity.
- Affected versions.
- Available fixes.
- Image metadata.

## 36.6 Limitation

A scan reporting no known vulnerabilities does not prove that an image contains no unknown security defects.

---

# 37. SOFTWARE BILL OF MATERIALS

## 37.1 Definition

A Software Bill of Materials, abbreviated SBOM, is a structured inventory of software components.

## 37.2 Typical Information

An SBOM may identify:

- Package names.
- Versions.
- Component relationships.
- Package identifiers.
- Licenses.
- Other metadata.

## 37.3 Purpose

SBOMs support:

- Dependency analysis.
- Vulnerability identification.
- Software inventory.
- Supply-chain transparency.
- Compliance processes.

## 37.4 Important Qualification

An SBOM describes identified software components.

It does not automatically establish that all components are secure or correctly configured.

---

# 38. IMAGE PROVENANCE

## 38.1 Definition

Build provenance records information about how an artifact was constructed.

## 38.2 Possible Information

Provenance may include:

- Source repository.
- Build system.
- Build parameters.
- Builder identity.
- Source revision.
- Build materials.

## 38.3 Purpose

Provenance helps establish the relationship between source code, build processes, and produced artifacts.

## 38.4 BuildKit Support

BuildKit supports generating provenance attestations.

## 38.5 Qualification

The value of provenance depends on the trustworthiness of the build system and the verification of its metadata.

Provenance alone does not prove that application code is safe.

---

# 39. SOFTWARE SUPPLY-CHAIN SECURITY

## 39.1 Definition

Software supply-chain security concerns the integrity and trustworthiness of the components and processes used to produce and distribute software.

## 39.2 Supply-Chain Stages

```text
             SOURCE CODE
                  |
                  v
              DEPENDENCIES
                  |
                  v
               BUILD SYSTEM
                  |
                  v
             CONTAINER IMAGE
                  |
                  v
                REGISTRY
                  |
                  v
               DEPLOYMENT
                  |
                  v
              RUNNING SERVICE
```

## 39.3 Potential Risks

A compromise at any stage may affect the resulting application.

Examples include:

- Compromised source repository.
- Malicious dependency.
- Compromised build agent.
- Unauthorized image replacement.
- Stolen registry credentials.
- Incorrect deployment configuration.

## 39.4 Security Principle

Protect the software creation and delivery process, not only the running container.

---

# 40. SECURITY HARDENING AS A TRADEOFF

Security controls can introduce operational requirements.

Examples include:

- A non-root process may need adjusted file ownership.
- A read-only filesystem may require tmpfs mounts.
- Capability removal may affect specialized applications.
- Tight memory limits may cause process termination.
- Minimal images may complicate interactive debugging.
- Network isolation may require explicit service connections.

The objective is not to maximize restrictions without analysis.

The objective is to establish the minimum privileges compatible with correct application behavior.

---

# PART IV — SECURITY LABORATORY DESIGN

# 41. PROJECT TITLE

**Docker Security Laboratory: Comparative Analysis of Baseline and Hardened Python HTTP Containers**

## 41.1 Project Objective

Construct two versions of the same application.

**Baseline container:**

Uses comparatively permissive defaults to establish a reference point.

**Hardened container:**

Applies explicit security restrictions.

The laboratory compares:

1. Runtime identity.
2. Writable filesystem access.
3. Linux capabilities.
4. No-new-privileges.
5. Seccomp status.
6. Secret availability.
7. Network isolation.
8. Resource limits.
9. Application functionality.
10. Image vulnerability information.

## 41.2 Scope

All experiments are intended for an isolated local training environment.

The exercises inspect security controls rather than attempting unauthorized exploitation.

---

# 42. SECURITY LABORATORY ARCHITECTURE

```text
                    DOCKER HOST
                         |
              +----------+----------+
              |                     |
              v                     v
         BASELINE APP          HARDENED APP
              |                     |
        UID 0 by default      UID 10001
              |                     |
        Writable root         Read-only root
              |                     |
        Default caps          Drop all caps
              |                     |
        Default NNP           No new privileges
              |                     |
        No secret grant       Demo secret mount
              |                     |
       Baseline network       Hardened network
              |                     |
          Port 8260              Port 8261
```

Both HTTP services provide the same primary application functionality.

The configuration of their container security boundaries differs.

---

# 43. FUNCTIONAL REQUIREMENTS

The application must provide:

- A root HTML endpoint.
- A health endpoint.
- A non-sensitive runtime information endpoint.
- A secret-presence diagnostic endpoint.

The application must listen on TCP port 8000.

It must not require a database or external Python package.

The application must not reveal secret contents.

---

# 44. PROJECT DIRECTORY

Create:

```text
docker-lecture16/
├── compose.yaml
├── Dockerfile.baseline
├── Dockerfile.hardened
├── Dockerfile.buildsecret
├── app.py
├── .dockerignore
├── .gitignore
└── secrets/
    └── training_token.txt
```

The secret file contains a synthetic instructional value.

No actual credentials should be used.

---

# 45. COMPLETE PYTHON APPLICATION

Create:

`app.py`

Insert:

```python
import json
import os
import platform

from http.server import (
    BaseHTTPRequestHandler,
    ThreadingHTTPServer,
)


class ApplicationHandler(BaseHTTPRequestHandler):

    def send_json(self, data, status=200):

        body = json.dumps(data).encode("utf-8")

        self.send_response(status)

        self.send_header(
            "Content-Type",
            "application/json"
        )

        self.send_header(
            "Content-Length",
            str(len(body))
        )

        self.end_headers()

        self.wfile.write(body)


    def do_GET(self):

        if self.path == "/health":

            self.send_json({
                "status": "healthy"
            })

            return


        if self.path == "/api/runtime":

            self.send_json({
                "uid": os.getuid(),
                "gid": os.getgid(),
                "python": platform.python_version(),
                "platform": platform.system()
            })

            return


        if self.path == "/api/secret-status":

            secret_path = (
                "/run/secrets/training_token"
            )

            present = os.path.isfile(
                secret_path
            )

            readable = False

            if present:

                try:

                    with open(
                        secret_path,
                        "rb"
                    ) as secret_file:

                        readable = bool(
                            secret_file.read(1)
                        )

                except OSError:

                    readable = False


            self.send_json({
                "secret_provided": present,
                "secret_readable": readable
            })

            return


        if self.path == "/":

            body = b"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Docker Security Laboratory</title>
</head>
<body>
<h1>Docker Lecture 16</h1>
<h2>Container Security Laboratory</h2>
<p>Baseline and hardened runtime comparison.</p>
<p>Visit /api/runtime for process information.</p>
<p>Visit /health for the health endpoint.</p>
</body>
</html>
"""

            self.send_response(200)

            self.send_header(
                "Content-Type",
                "text/html; charset=utf-8"
            )

            self.send_header(
                "Content-Length",
                str(len(body))
            )

            self.end_headers()

            self.wfile.write(body)

            return


        self.send_json({
            "error": "Not found"
        }, 404)


    def do_POST(self):

        self.send_json({
            "error": "Method not allowed"
        }, 405)


def main():

    server = ThreadingHTTPServer(
        ("0.0.0.0", 8000),
        ApplicationHandler
    )

    print(
        "Starting Docker security laboratory "
        "HTTP service on port 8000",
        flush=True
    )

    server.serve_forever()


if __name__ == "__main__":

    main()
```

## 45.1 Application Analysis

The application uses only Python's standard library.

It provides equivalent HTTP behavior in both containers.

The runtime information endpoint reports numeric UID and GID values.

The secret-status endpoint reports only whether the synthetic secret is present and readable.

It does not return the secret itself.

This permits a controlled comparison of security configuration.

---

# 46. BASELINE DOCKERFILE

Create:

`Dockerfile.baseline`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY app.py ./app.py

EXPOSE 8000

CMD ["python", "-B", "app.py"]
```

## 46.1 Characteristics

The image:

- Uses Python 3.12.
- Includes the application source.
- Uses the base image's default execution identity.
- Does not explicitly configure a non-root user.
- Does not itself configure a read-only root filesystem.
- Does not itself restrict Linux capabilities.

## 46.2 Important Qualification

Docker's ordinary default isolation mechanisms still apply.

The baseline should not be described as completely unrestricted.

It is a comparative reference, not an intentionally exploitable image.

---

# 47. HARDENED DOCKERFILE

Create:

`Dockerfile.hardened`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Lecture 16 Hardened Application" \
      org.opencontainers.image.description="Non-root Python security laboratory"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --gid 10001 appgroup \
    && useradd \
       --uid 10001 \
       --gid 10001 \
       --no-create-home \
       --shell /usr/sbin/nologin \
       appuser

WORKDIR /opt/app

COPY --chown=10001:10001 app.py ./app.py

USER 10001:10001

EXPOSE 8000

CMD ["python", "-B", "app.py"]
```

## 47.1 Security Characteristics

The image defines an unprivileged application identity.

The application source is owned by the corresponding numeric identity.

The application executes on an unprivileged TCP port.

Further restrictions will be configured by Docker Compose.

---

# 48. BUILDKIT SECRET DEMONSTRATION DOCKERFILE

Create:

`Dockerfile.buildsecret`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

WORKDIR /app

RUN --mount=type=secret,id=training_token,required=true \
    python -c "from pathlib import Path; assert Path('/run/secrets/training_token').is_file()"

COPY app.py ./app.py

EXPOSE 8000

CMD ["python", "-B", "app.py"]
```

## 48.1 Purpose

This Dockerfile demonstrates that BuildKit can make a secret available during a selected build operation.

The secret is not copied into the final image.

## 48.2 Limitations

The Dockerfile is an isolated build-secret demonstration.

It is not intended to replace the hardened runtime Dockerfile.

---

# 49. SYNTHETIC SECRET FILE

Create:

`secrets/training_token.txt`

Insert:

```text
lecture16-demo-only-not-a-real-secret
```

## 49.1 Critical Requirement

This is not a real credential.

Never substitute an actual API key, database password, or private token into these instructional examples.

## 49.2 File Permissions

The non-root container must be able to read the file for the laboratory.

For file-backed Compose secrets, access depends on the bind-mounted source-file permissions and platform behavior.

Use an appropriately readable file for this synthetic demonstration.

In production, do not make real secrets broadly readable merely to resolve a container permission problem.

---

# 50. DOCKERIGNORE AND GITIGNORE

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.gitignore
secrets/
.env
*.log
*.tmp
*.pyc
__pycache__/
.venv/
venv/
```

Create:

`.gitignore`

Insert:

```text
secrets/
.env
__pycache__/
*.pyc
```

## 50.1 Purpose

These files help prevent local secrets and development artifacts from being unintentionally included in an image or committed to a repository.

## 50.2 Limitation

Ignore files do not remove information already committed or embedded in previous image layers.

Sensitive-data exposure requires an appropriate incident response and credential rotation procedure.

---

# 51. COMPLETE COMPOSE CONFIGURATION

Create:

`compose.yaml`

Insert:

```yaml
name: lecture16-security

services:

  baseline:
    build:
      context: .
      dockerfile: Dockerfile.baseline

    image: lecture16:baseline

    ports:
      - "127.0.0.1:8260:8000"

    networks:
      - baseline-net


  hardened:
    build:
      context: .
      dockerfile: Dockerfile.hardened

    image: lecture16:hardened

    user: "10001:10001"

    ports:
      - "127.0.0.1:8261:8000"

    read_only: true

    tmpfs:
      - /tmp:size=16m

    cap_drop:
      - ALL

    security_opt:
      - no-new-privileges:true

    pids_limit: 128

    mem_limit: 256m

    cpus: 0.50

    secrets:
      - training_token

    networks:
      - hardened-net

    healthcheck:
      test:
        - CMD
        - python
        - -B
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s


networks:

  baseline-net:
    driver: bridge

  hardened-net:
    driver: bridge


secrets:

  training_token:
    file: ./secrets/training_token.txt
```

---

# 52. SECURITY CONFIGURATION ANALYSIS

## 52.1 Runtime Identity

```yaml
user: "10001:10001"
```

Explicitly selects a non-root identity.

## 52.2 Read-Only Root

```yaml
read_only: true
```

Prevents ordinary writes to the container root filesystem.

## 52.3 Temporary Writable Storage

```yaml
tmpfs:
  - /tmp:size=16m
```

Provides temporary storage for applications that require it.

## 52.4 Capabilities

```yaml
cap_drop:
  - ALL
```

Removes the container's available Linux capabilities according to the applicable runtime configuration.

## 52.5 Privilege Escalation

```yaml
security_opt:
  - no-new-privileges:true
```

Restricts privilege acquisition through later process execution.

## 52.6 Process Limit

```yaml
pids_limit: 128
```

Constrains the available process identifiers.

## 52.7 Memory

```yaml
mem_limit: 256m
```

Sets the configured memory limit.

## 52.8 CPU

```yaml
cpus: 0.50
```

Sets an approximate CPU allocation limit using the supported container resource mechanism.

## 52.9 Secret Grant

The hardened service receives the synthetic runtime secret.

The baseline service does not.

## 52.10 Network Isolation

Each service joins a separate user-defined bridge network.

Neither service requires direct application communication with the other.

---

# PART V — PRACTICAL LABORATORY 16

# 53. EXPERIMENT 1 — VERIFY DOCKER AVAILABILITY

Execute:

```bash
docker version
```

Then:

```bash
docker compose version
```

**Objective:**

Confirm Docker Engine and Docker Compose availability.

**Required observations:**

1. Docker version.
2. Compose version.
3. Linux container support.
4. Docker Engine accessibility.

---

# 54. EXPERIMENT 2 — CREATE THE PROJECT

Create:

```text
docker-lecture16/
```

For a Unix-like shell:

```bash
mkdir -p docker-lecture16/secrets
cd docker-lecture16
```

Create all the files from Sections 44–51.

**Objective:**

Construct the complete security laboratory.

---

# 55. EXPERIMENT 3 — VALIDATE THE COMPOSE FILE

Execute:

```bash
docker compose config -q
```

Then:

```bash
docker compose config
```

**Objective:**

Verify the security configuration.

**Required observations:**

Identify:

- Two services.
- Two networks.
- Loopback port publishing.
- Read-only filesystem setting.
- Capability dropping.
- No-new-privileges configuration.
- Resource limits.
- Secret grant.

---

# 56. EXPERIMENT 4 — BUILD BOTH IMAGES

Execute:

```bash
docker compose build
```

**Objective:**

Construct baseline and hardened images.

Verify:

```bash
docker image ls lecture16
```

**Expected result:**

Both image tags appear.

---

# 57. EXPERIMENT 5 — START THE APPLICATIONS

Execute:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

**Objective:**

Start both application containers.

**Expected result:**

The baseline and hardened services execute successfully.

The hardened service should become healthy after its configured checks succeed.

---

# 58. EXPERIMENT 6 — TEST FUNCTIONAL EQUIVALENCE

Open:

http://127.0.0.1:8260

Then:

http://127.0.0.1:8261

**Objective:**

Verify that both images provide the same principal HTTP service.

**Expected result:**

Both display the Docker security laboratory page.

**Required analysis:**

Explain why security configuration should preserve required application functionality.

---

# 59. EXPERIMENT 7 — VERIFY HEALTH ENDPOINTS

Execute:

```bash
curl -i http://127.0.0.1:8260/health
```

Then:

```bash
curl -i http://127.0.0.1:8261/health
```

**Objective:**

Verify both applications remain responsive.

**Expected result:**

Both return HTTP 200 with JSON containing a healthy status.

---

# 60. EXPERIMENT 8 — COMPARE RUNTIME IDENTITIES

Execute:

```bash
curl http://127.0.0.1:8260/api/runtime
```

Then:

```bash
curl http://127.0.0.1:8261/api/runtime
```

**Objective:**

Compare process identities.

**Expected result:**

The baseline ordinarily reports UID 0.

The hardened service reports UID 10001.

**Required analysis:**

Explain why these identities imply different ordinary filesystem privileges inside their containers.

---

# 61. EXPERIMENT 9 — INSPECT USER CONFIGURATION

Execute:

```bash
docker image inspect lecture16:baseline --format '{{.Config.User}}'
```

Then:

```bash
docker image inspect lecture16:hardened --format '{{.Config.User}}'
```

**Objective:**

Inspect the identity configured by each image.

**Expected result:**

The baseline image may contain an empty user setting, implying the image's default runtime identity.

The hardened image specifies:

```text
10001:10001
```

**Required analysis:**

Explain the difference between an image's default user and a Compose runtime user override.

---

# 62. EXPERIMENT 10 — COMPARE FILESYSTEM WRITABILITY

Execute:

```bash
docker compose exec baseline sh -c 'touch /app/baseline-test && echo "write successful"'
```

**Expected result:**

The baseline process can create the file.

Now execute:

```bash
docker compose exec hardened sh -c 'touch /opt/app/hardened-test'
```

**Expected result:**

The write attempt fails because the hardened root filesystem is read-only.

**Objective:**

Demonstrate the practical effect of the `read_only` configuration.

**Required analysis:**

Explain why a read-only root filesystem protects against some unauthorized filesystem modifications.

---

# 63. EXPERIMENT 11 — TEST TEMPORARY STORAGE

Execute:

```bash
docker compose exec hardened sh -c 'touch /tmp/temporary-test && echo "temporary write successful"'
```

**Objective:**

Verify that `/tmp` remains writable through its temporary filesystem mount.

**Expected result:**

The file creation succeeds.

**Required analysis:**

Explain why a container may need selected writable directories even when its root filesystem is read-only.

---

# 64. EXPERIMENT 12 — INSPECT LINUX CAPABILITIES

Execute:

```bash
docker compose exec baseline sh -c 'grep -E "^(CapEff|CapBnd):" /proc/self/status'
```

Then:

```bash
docker compose exec hardened sh -c 'grep -E "^(CapEff|CapBnd):" /proc/self/status'
```

**Objective:**

Examine process capability information.

**Expected observation:**

The hardened container's effective and bounding capability masks should reflect its dropped capability configuration.

The baseline container may retain a restricted default Docker capability set.

**Required analysis:**

Explain why the capability model is more precise than simply treating a process as root or non-root.

---

# 65. EXPERIMENT 13 — INSPECT NO-NEW-PRIVILEGES

Execute:

```bash
docker compose exec hardened sh -c 'grep "^NoNewPrivs:" /proc/self/status'
```

**Expected result:**

The reported setting should indicate that no-new-privileges is enabled.

Compare with:

```bash
docker compose exec baseline sh -c 'grep "^NoNewPrivs:" /proc/self/status'
```

**Objective:**

Examine the security setting recorded by the Linux kernel.

**Required analysis:**

Explain why no-new-privileges should be combined with non-root execution and capability reduction.

---

# 66. EXPERIMENT 14 — INSPECT SECCOMP STATUS

Execute:

```bash
docker compose exec hardened sh -c 'grep "^Seccomp:" /proc/self/status'
```

**Objective:**

Inspect the process seccomp mode.

**Expected result:**

On a supported Docker environment using the default seccomp filter, the process commonly reports seccomp filtering mode.

**Required analysis:**

Explain why the exact observation depends on host and runtime support.

Also explain why disabling seccomp is not an appropriate routine troubleshooting strategy.

---

# 67. EXPERIMENT 15 — VERIFY RUNTIME SECRET GRANTS

Open:

http://127.0.0.1:8260/api/secret-status

Then:

http://127.0.0.1:8261/api/secret-status

**Objective:**

Compare service-level access to the synthetic secret.

**Expected result:**

The baseline service reports that the secret is not provided.

The hardened service reports that the secret is provided.

If the synthetic secret file has suitable read permissions, it also reports that the file is readable.

**Required analysis:**

Explain why declaring a secret at the top level of a Compose file does not automatically grant it to every service.

---

# 68. EXPERIMENT 16 — VERIFY SECRET CONTENT IS NOT EXPOSED

Execute:

```bash
docker compose exec hardened sh -c 'test -r /run/secrets/training_token && echo "secret readable"'
```

**Objective:**

Verify secret accessibility without displaying its contents.

**Expected result:**

The command reports the secret is readable when host file permissions and platform behavior permit.

**Required analysis:**

Explain why diagnostics should avoid printing real credentials into terminal histories and logs.

---

# 69. EXPERIMENT 17 — VERIFY THE SECRET IS NOT AN IMAGE FILE

Inspect the hardened image through a temporary container without the Compose secret mount:

```bash
docker run --rm \
  --entrypoint sh \
  lecture16:hardened \
  -c 'test ! -e /run/secrets/training_token && echo "not embedded in image"'
```

**Objective:**

Verify that the runtime secret is not part of the hardened image filesystem.

**Expected result:**

The test reports that the secret is not embedded in the image.

**Required analysis:**

Explain the difference between an image artifact and a secret mounted into a container at runtime.

---

# 70. EXPERIMENT 18 — INSPECT COMPOSE SECURITY CONFIGURATION

Execute:

```bash
docker inspect \
  --format '{{json .HostConfig.SecurityOpt}}' \
  "$(docker compose ps -q hardened)"
```

Then:

```bash
docker inspect \
  --format '{{json .HostConfig.CapDrop}}' \
  "$(docker compose ps -q hardened)"
```

**Objective:**

Inspect selected runtime security settings.

The commands use Unix-style shell substitution.

For other terminals, retrieve the container identifier separately using `docker compose ps -q hardened`.

**Required analysis:**

Explain why application source code alone does not provide a complete description of a container's security configuration.

---

# 71. EXPERIMENT 19 — VERIFY RESOURCE LIMITS

Execute:

```bash
docker inspect \
  --format '{{.HostConfig.Memory}}' \
  "$(docker compose ps -q hardened)"
```

Then:

```bash
docker inspect \
  --format '{{.HostConfig.PidsLimit}}' \
  "$(docker compose ps -q hardened)"
```

**Objective:**

Inspect configured resource constraints.

**Required analysis:**

Explain why memory and process limits can reduce the consequences of certain application faults.

Do not deliberately attempt to exhaust the host's resources.

---

# 72. EXPERIMENT 20 — INSPECT NETWORK SEPARATION

Execute:

```bash
docker network inspect lecture16-security_baseline-net
```

Then:

```bash
docker network inspect lecture16-security_hardened-net
```

**Objective:**

Verify that the two services occupy separate Docker networks.

**Expected result:**

Each network contains its corresponding application container.

**Required analysis:**

Explain why separate networks can reduce unnecessary service discovery and communication pathways.

---

# 73. EXPERIMENT 21 — TEST NETWORK-SCOPED DNS

Execute:

```bash
docker compose exec baseline python -c "import socket; print(socket.gethostbyname('hardened'))"
```

**Objective:**

Investigate whether the baseline container can resolve the hardened service name through Docker's internal DNS.

**Expected result:**

Under ordinary separate user-defined bridge network configuration, the lookup fails.

**Required analysis:**

Explain why this demonstrates network-scoped DNS behavior rather than proving that every possible routed path between the containers is blocked.

---

# 74. EXPERIMENT 22 — BUILD WITH A BUILDKIT SECRET

Execute:

```bash
docker build \
  --secret id=training_token,src=./secrets/training_token.txt \
  -f Dockerfile.buildsecret \
  -t lecture16:buildsecret \
  .
```

**Objective:**

Demonstrate a temporary build-time secret mount.

**Expected result:**

The BuildKit instruction verifies the presence of the synthetic secret.

The build completes.

**Required analysis:**

Explain why a build-time secret is different from a runtime Compose secret.

---

# 75. EXPERIMENT 23 — VERIFY BUILDKIT SECRET NONPERSISTENCE

Execute:

```bash
docker run --rm \
  --entrypoint sh \
  lecture16:buildsecret \
  -c 'test ! -e /run/secrets/training_token && echo "build secret absent"'
```

**Objective:**

Verify that the BuildKit secret mount did not automatically become part of the image filesystem.

**Expected result:**

The test reports that the build secret is absent.

**Required analysis:**

Explain why secret mounts are preferable to placing confidential values directly into Dockerfile `ARG` or `ENV`.

---

# 76. EXPERIMENT 24 — OPTIONAL IMAGE VULNERABILITY SCAN

If Docker Scout is available and properly configured, execute:

```bash
docker scout cves local://lecture16:baseline
```

Then:

```bash
docker scout cves local://lecture16:hardened
```

**Objective:**

Analyze known vulnerabilities associated with the image contents.

**Expected result:**

Docker Scout generates a report or indicates that configuration or authentication is required.

The detected vulnerability information depends on current advisory data and image contents.

**Required analysis:**

Explain why non-root execution and filesystem hardening do not remove known vulnerabilities from application or operating-system packages.

---

# 77. EXPERIMENT 25 — COMPARE IMAGE SECURITY METADATA

Execute:

```bash
docker image inspect lecture16:baseline
```

Then:

```bash
docker image inspect lecture16:hardened
```

**Objective:**

Compare image-level configuration.

**Required observations:**

1. Base image.
2. Image user.
3. Entrypoint or command.
4. Environment variables.
5. Exposed ports.
6. Image layers and metadata.

**Required analysis:**

Explain why some security properties are recorded in the image while others belong to container runtime configuration.

---

# 78. EXPERIMENT 26 — CONTROLLED CLEANUP

Execute:

```bash
docker compose down
```

**Objective:**

Remove the laboratory containers and networks.

The synthetic secret source file remains in the local project directory.

The built images also remain unless deliberately removed.

Optional image cleanup:

```bash
docker image rm lecture16:baseline
```

```bash
docker image rm lecture16:hardened
```

```bash
docker image rm lecture16:buildsecret
```

**Important requirement:**

Remove only the objects created for the laboratory.

Do not delete unrelated images, volumes, or host files.

---

# 79. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Security control or property | Observed result |
|---|---|---|
| 1 | Docker environment | |
| 2 | Project construction | |
| 3 | Compose validation | |
| 4 | Image construction | |
| 5 | Container startup | |
| 6 | Functional equivalence | |
| 7 | Application health | |
| 8 | Runtime process identity | |
| 9 | Image user configuration | |
| 10 | Root filesystem writability | |
| 11 | Temporary filesystem | |
| 12 | Linux capabilities | |
| 13 | No-new-privileges | |
| 14 | Seccomp status | |
| 15 | Secret grants | |
| 16 | Secret accessibility | |
| 17 | Image versus runtime secret | |
| 18 | Security configuration inspection | |
| 19 | Resource constraints | |
| 20 | Network separation | |
| 21 | Network-scoped DNS | |
| 22 | BuildKit secret mount | |
| 23 | Build secret nonpersistence | |
| 24 | Optional vulnerability scanning | |
| 25 | Image metadata comparison | |
| 26 | Controlled cleanup | |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 350–500 words explaining:

1. Why non-root execution reduces ordinary process privileges.
2. Why non-root execution differs from rootless Docker.
3. How Linux capabilities can be reduced.
4. What no-new-privileges contributes.
5. How a read-only filesystem changes runtime behavior.
6. Why selected writable temporary storage may still be required.
7. How Compose secrets differ from embedded image configuration.
8. How BuildKit build secrets differ from runtime secrets.
9. Why network membership affects service discovery.
10. Why vulnerability scanning remains necessary after hardening.
11. What security limitations remain in the demonstration.

---

# PART VI — CONTAINER SECURITY TROUBLESHOOTING

# 80. APPLICATION FAILS AFTER NON-ROOT CONFIGURATION

## Symptoms

The application executes correctly as root but fails when configured under a non-root identity.

## Possible Causes

- Incorrect file ownership.
- Insufficient directory permissions.
- Inaccessible configuration files.
- Privileged port binding requirements.
- Application attempts to modify protected locations.

## Investigation

Examine:

```bash
docker compose logs hardened
```

Inspect process identity and file permissions.

## Corrective Principle

Modify the minimum necessary permissions.

Do not automatically restore root execution merely to avoid diagnosing the underlying problem.

---

# 81. APPLICATION FAILS WITH READ-ONLY FILESYSTEM

## Symptoms

The container starts and then reports permission errors when creating files.

## Possible Causes

- Application writes into its source directory.
- Temporary files use a non-writable path.
- Runtime caches require storage.
- Logging writes to ordinary files instead of standard output.
- Application attempts to modify installed packages.

## Correction

Identify the required writable paths.

Provide appropriately controlled tmpfs or volume mounts.

---

# 82. SECRET ACCESS FAILS

## Symptoms

A non-root application cannot read a mounted Compose secret.

## Possible Causes

- Secret not granted to the service.
- Incorrect secret name.
- Source file absent.
- Insufficient source-file permissions.
- Host platform-specific mount behavior.

## Investigation

Inspect the resolved Compose model.

Verify the source path.

Verify file permissions.

## Corrective Principle

Grant only the required access rather than broadening permissions for the entire application.

---

# 83. APPLICATION FAILS AFTER DROPPING CAPABILITIES

## Symptoms

An application works with default capabilities but fails with:

```yaml
cap_drop:
  - ALL
```

## Possible Causes

The application requires a particular privileged operation.

## Investigation

Identify the failed operation.

Determine which capability, if any, is necessary.

Evaluate whether the operation can be redesigned to avoid the privilege.

## Corrective Principle

Add only specifically justified capabilities.

Do not use `privileged: true` as a general solution.

---

# 84. RESOURCE LIMITS CAUSE FAILURES

## Symptoms

The container terminates or becomes unresponsive under load.

## Possible Causes

- Insufficient memory limit.
- Excessively restrictive process limit.
- Insufficient CPU allocation.
- Application memory leak.
- Excessive concurrency.

## Investigation

Use:

```bash
docker stats
```

Inspect container state and logs.

## Corrective Principle

Resource limits must reflect measured workload requirements.

---

# 85. VULNERABILITY SCAN REPORTS MANY FINDINGS

## Problem

An image scan identifies several CVEs.

## Incorrect Reaction

Assume every finding is equally exploitable.

## Correct Analysis

Evaluate:

1. Affected component.
2. Vulnerable version.
3. Availability of fixes.
4. Exposure.
5. Exploitability.
6. Application privilege.
7. Compensating controls.
8. Business impact.

## Corrective Principle

Prioritize remediation based on evidence rather than raw vulnerability counts alone.

---

# 86. IMAGE IS SMALL BUT STILL INSECURE

A highly optimized image may contain few operating-system packages.

However, it may still include a vulnerable application binary or unsafe configuration.

## Important Principle

Image minimization is one security-relevant practice.

It does not replace application security testing, patch management, or runtime access controls.

---

# PART VII — COMPREHENSIVE SECURITY ANALYSIS

# 87. COMPARATIVE SECURITY TABLE

| Security property | Baseline container | Hardened container |
|---|---|---|
| Application process identity | Root by default | UID 10001 |
| Root filesystem | Writable | Read-only |
| Temporary writable storage | Default filesystem behavior | Explicit tmpfs |
| Linux capabilities | Docker defaults | All dropped |
| No-new-privileges | Not explicitly requested | Enabled |
| Seccomp | Docker default, where supported | Docker default, where supported |
| Secret grant | None | Synthetic runtime secret |
| Docker network | Baseline network | Hardened network |
| Published endpoint | Host loopback | Host loopback |
| Process count limit | Not explicitly defined | Explicit |
| Memory limit | Not explicitly defined | Explicit |
| CPU limit | Not explicitly defined | Explicit |
| Image vulnerability scanning | Optional assessment | Optional assessment |
| Complete production security | No | No |

## Important Interpretation

The hardened configuration restricts several categories of runtime authority.

It is not a mathematical guarantee against compromise.

The actual security posture depends on the complete application, host, runtime, dependencies, and operational environment.

---

# 88. COMMON CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1

**A container provides the same isolation as a conventional virtual machine.**

Incorrect.

The isolation architectures are different.

## Misunderstanding 2

**Running as a non-root user enables rootless Docker.**

Incorrect.

Application identity and Docker daemon identity are separate concerns.

## Misunderstanding 3

**Root inside a container always has unrestricted root authority on the host.**

Incorrect.

Capabilities, namespaces, and security profiles affect its authority.

Nevertheless, container-root privileges can still create substantial risks.

## Misunderstanding 4

**Docker containers always have every Linux capability.**

Incorrect.

Docker ordinarily applies a restricted default capability set.

## Misunderstanding 5

**Privileged mode is necessary for ordinary web applications.**

Incorrect.

Ordinary HTTP services generally do not require it.

## Misunderstanding 6

**Dropping all capabilities prevents every possible attack.**

Incorrect.

Capabilities are only one part of the container security model.

## Misunderstanding 7

**A read-only root filesystem makes all data inside a container immutable.**

Incorrect.

Explicit mounts and selected virtual filesystem paths may remain writable.

## Misunderstanding 8

**Docker Compose secrets are automatically encrypted distributed secret storage.**

Incorrect.

Local file-backed Compose secrets use bind-mount mechanisms.

## Misunderstanding 9

**An environment variable is automatically confidential.**

Incorrect.

Environment values may be exposed through inspection or process access.

## Misunderstanding 10

**BuildKit secret mounts make careless build scripts completely safe.**

Incorrect.

A build command can still disclose a secret.

## Misunderstanding 11

**A smaller image cannot contain vulnerable software.**

Incorrect.

Application vulnerabilities may exist independently of image size.

## Misunderstanding 12

**A vulnerability scan reporting no CVEs proves the image is secure.**

Incorrect.

Unknown vulnerabilities and configuration weaknesses may remain.

## Misunderstanding 13

**A named volume is always safe from unauthorized access.**

Incorrect.

Access depends on container privileges, mounts, host security, and storage permissions.

## Misunderstanding 14

**Docker network isolation replaces authentication.**

Incorrect.

Application security must still be enforced.

## Misunderstanding 15

**Docker daemon socket access is harmless when the process is non-root.**

Incorrect.

Daemon API access can confer extensive administrative authority.

---

# PART VIII — ACADEMIC TERMINOLOGY

# 89. GLOSSARY

| Term | Academic definition |
|---|---|
| Container security | Protection of containerized applications and supporting infrastructure |
| Confidentiality | Prevention of unauthorized information disclosure |
| Integrity | Protection against unauthorized modification |
| Availability | Continued accessibility of required services |
| Threat model | Structured analysis of assets, threats, and trust boundaries |
| Trust boundary | Separation between components with different security assumptions |
| Attack surface | Set of accessible interfaces and operations available to a potential attacker |
| Defense in depth | Use of multiple complementary security controls |
| Least privilege | Granting only necessary permissions |
| UID | User identifier |
| GID | Group identifier |
| Root user | Traditional Unix administrative identity |
| Non-root execution | Running an application under an unprivileged identity |
| Rootless Docker | Docker daemon and container operation without ordinary host-root privileges |
| User namespace | Isolated mapping of user and group identities |
| Userns-remap | Docker user identity remapping configuration |
| Linux capability | Fine-grained unit of privileged kernel authority |
| cap_drop | Runtime configuration for removing capabilities |
| Privileged container | Container with greatly expanded authority |
| No-new-privileges | Kernel restriction on acquisition of additional execution privileges |
| Seccomp | Linux system-call filtering mechanism |
| System call | Userspace request for kernel functionality |
| AppArmor | Linux mandatory access-control mechanism |
| SELinux | Label-based Linux mandatory access-control system |
| Read-only root | Container root filesystem configured against ordinary writes |
| tmpfs | Temporary filesystem storage |
| Bind mount | Exposure of a host filesystem path inside a container |
| Docker daemon socket | Management API endpoint used to control Docker Engine |
| Secret | Confidential application or infrastructure information |
| Compose secret | Service-scoped runtime secret resource |
| BuildKit secret | Temporary confidential build input |
| CVE | Common Vulnerabilities and Exposures identifier |
| CVSS | Common Vulnerability Scoring System |
| Vulnerability scanner | Tool for identifying known vulnerable software components |
| Docker Scout | Docker image analysis and vulnerability assessment tool |
| SBOM | Software Bill of Materials |
| Provenance | Information describing how a software artifact was built |
| Supply-chain security | Protection of software development and delivery processes |
| Image digest | Content-addressed image identifier |
| Resource limit | Restriction on container resource consumption |
| Cgroups | Linux control-group resource management mechanisms |
| Security hardening | Configuration changes intended to reduce unnecessary exposure or privilege |

---

# PART IX — FORMAL ACADEMIC ASSESSMENT

# 90. PART A — THEORETICAL DEFINITIONS

Define the following terms precisely:

1. Container security.
2. Least privilege.
3. Defense in depth.
4. Linux capability.
5. User namespace.
6. Rootless Docker.
7. Seccomp.
8. AppArmor.
9. Read-only root filesystem.
10. Runtime secret.
11. Build-time secret.
12. CVE.
13. SBOM.
14. Build provenance.
15. Software supply-chain security.

---

# 91. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain the shared-kernel security architecture of Linux containers.

**Question 2.**

Describe why a non-root application process is preferable to root execution when practical.

**Question 3.**

Distinguish non-root execution, user namespace remapping, and rootless Docker.

**Question 4.**

Explain why Linux capabilities provide finer-grained control than unrestricted administrative privileges.

**Question 5.**

Describe the purpose of `cap_drop: ALL`.

**Question 6.**

Explain why privileged containers should be avoided for ordinary applications.

**Question 7.**

Describe the role of no-new-privileges.

**Question 8.**

Explain how seccomp restricts container processes.

**Question 9.**

Compare seccomp, AppArmor, and SELinux.

**Question 10.**

Explain why a read-only root filesystem may require temporary writable mounts.

**Question 11.**

Describe the security risks associated with bind mounts.

**Question 12.**

Explain why Docker daemon socket access is sensitive.

**Question 13.**

Compare Compose runtime secrets and BuildKit build secrets.

**Question 14.**

Explain why Dockerfile ARG and ENV should not contain real credentials.

**Question 15.**

Describe why image vulnerability scanning is necessary but insufficient for comprehensive security assurance.

---

# 92. PART C — CONFIGURATION INTERPRETATION

Consider:

```yaml
user: "10001:10001"

read_only: true

cap_drop:
  - ALL

security_opt:
  - no-new-privileges:true
```

Answer:

1. Which process identity is configured?
2. Which filesystem restriction is applied?
3. Which capability restriction is applied?
4. What does no-new-privileges prevent?
5. Does the configuration eliminate all security risks?

Consider:

```yaml
secrets:
  - application_token
```

Answer:

6. What is the purpose of the setting?
7. Where is the secret commonly mounted?
8. Does the setting automatically include the secret in the image?
9. Is the secret automatically available to unrelated services?

Consider:

```yaml
mem_limit: 256m

cpus: 0.50

pids_limit: 128
```

Answer:

10. Which system resources are restricted?
11. Why can these controls improve operational resilience?
12. Why might excessively restrictive limits cause application failures?

---

# 93. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Excessive Container Privileges

A web service fails because it cannot write to a configuration directory.

An administrator proposes enabling privileged mode.

Analyze the proposal.

Recommend a more appropriate troubleshooting and permissions strategy.

## Case Study 2 — Docker Socket Exposure

An application container receives a bind mount exposing the Docker daemon socket.

The application is not designed to administer Docker resources.

Evaluate the security risk.

Explain why running the application as non-root does not automatically eliminate the concern.

## Case Study 3 — Embedded Credentials

A developer writes a database password directly into a Dockerfile using `ENV`.

The image is pushed to a registry.

Explain the potential exposure.

Recommend a safer runtime configuration.

## Case Study 4 — Build-Time Token

A build process must retrieve a package from a private repository.

The developer proposes passing the access token using Dockerfile `ARG`.

Explain the risks.

Describe how BuildKit secret mounts can improve the design.

## Case Study 5 — Read-Only Filesystem Failure

A Python web application starts under a read-only root filesystem.

It fails when attempting to create a temporary file.

Explain why this occurs.

Recommend an appropriate writable temporary storage configuration.

## Case Study 6 — High Vulnerability Count

Two images contain different numbers of reported CVEs.

One image is smaller but contains a vulnerability in a network-exposed component.

The other image is larger but contains mostly inaccessible optional packages.

Explain why vulnerability count alone may not accurately represent comparative risk.

---

# 94. PRACTICAL ASSESSMENT

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Container security theory | 15 |
| Non-root execution | 15 |
| Linux capabilities and privilege restrictions | 15 |
| Filesystem security | 15 |
| Secret management | 15 |
| Network and resource controls | 10 |
| Vulnerability and supply-chain analysis | 10 |
| Technical documentation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student must demonstrate both successful security configuration and an accurate explanation of the protective effect and limitations of each measure.

---

# 95. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Security Hardening of Containerized Applications Using Docker

Prepare an academic report of approximately 1,400–1,900 words addressing:

**“Docker Container Security: Isolation Boundaries, Least Privilege, Capability Restrictions, Secret Management, Runtime Hardening, and Software Supply-Chain Protection.”**

The report must include:

1. Introduction to container security.
2. Confidentiality, integrity, and availability.
3. Container threat modeling.
4. Shared-kernel security implications.
5. Defense in depth.
6. Non-root execution.
7. Rootless Docker and user namespaces.
8. Linux capabilities.
9. Seccomp.
10. AppArmor and SELinux.
11. Filesystem restrictions.
12. Network security.
13. Docker daemon protection.
14. Runtime secret management.
15. Build-time secret management.
16. Vulnerability scanning.
17. SBOMs and provenance.
18. Comparative analysis of the baseline and hardened containers.
19. Security limitations of the laboratory.
20. Technical conclusion.

The report must contain:

- At least two architectural diagrams.
- A comparative security table.
- Selected Dockerfile or Compose examples.
- Laboratory evidence.

---

# 96. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 17, verify the following.

## Security Foundations

- [ ] I can define container security.
- [ ] I understand confidentiality, integrity, and availability.
- [ ] I can describe a container threat model.
- [ ] I understand the shared-kernel model.
- [ ] I can explain defense in depth.
- [ ] I understand least privilege.

## Identity and Privilege

- [ ] I can configure a non-root Dockerfile user.
- [ ] I understand UID and GID.
- [ ] I can inspect runtime identity.
- [ ] I can distinguish non-root containers from rootless Docker.
- [ ] I can explain user namespace remapping.
- [ ] I understand the limitations of non-root execution.

## Linux Security Mechanisms

- [ ] I can define Linux capabilities.
- [ ] I can use cap_drop.
- [ ] I understand the risks of privileged mode.
- [ ] I can configure no-new-privileges.
- [ ] I understand seccomp.
- [ ] I can describe AppArmor.
- [ ] I can describe SELinux.
- [ ] I can inspect process security status.

## Filesystem and Resources

- [ ] I can configure a read-only root filesystem.
- [ ] I can configure tmpfs.
- [ ] I understand bind mount security.
- [ ] I can configure memory limits.
- [ ] I can configure CPU limits.
- [ ] I can configure process limits.
- [ ] I understand that resource limits can affect availability.

## Secrets

- [ ] I can identify sensitive configuration.
- [ ] I understand why secrets should not be hardcoded.
- [ ] I can declare a Compose secret.
- [ ] I can grant a secret to a specific service.
- [ ] I can inspect secret presence without printing values.
- [ ] I understand BuildKit secret mounts.
- [ ] I can distinguish build-time and runtime secrets.
- [ ] I understand the limitations of file-backed Compose secrets.

## Image and Supply-Chain Security

- [ ] I can explain image trust.
- [ ] I can distinguish image tags and digests.
- [ ] I can define a CVE.
- [ ] I understand vulnerability severity.
- [ ] I can explain vulnerability scanning.
- [ ] I understand the purpose of Docker Scout.
- [ ] I can define an SBOM.
- [ ] I can explain build provenance.
- [ ] I understand supply-chain risks.

## Practical Laboratory

- [ ] I created the baseline image.
- [ ] I created the hardened image.
- [ ] I validated the Compose configuration.
- [ ] I started both application containers.
- [ ] I verified HTTP functionality.
- [ ] I compared runtime identities.
- [ ] I tested filesystem writability.
- [ ] I verified temporary storage.
- [ ] I inspected Linux capabilities.
- [ ] I inspected no-new-privileges.
- [ ] I inspected seccomp status.
- [ ] I verified runtime secret grants.
- [ ] I verified the secret was not embedded in the image.
- [ ] I inspected resource limits.
- [ ] I examined network separation.
- [ ] I tested BuildKit secret mounts.
- [ ] I completed the comparative security table.
- [ ] I completed the academic assessment.
- [ ] I prepared the final laboratory report.

**Completion standard:**

The student should be able to construct and evaluate a hardened Docker application configuration, explain the purpose of its security restrictions, and identify the remaining risks that require further controls.

---

# 97. LECTURE SUMMARY

Docker security requires more than using a container image or selecting an unprivileged process identity.

Containers share important infrastructure with their host systems.

Their security therefore depends on isolation mechanisms, process privileges, runtime configuration, image integrity, and host administration.

The principle of least privilege recommends granting applications only the authority required for their function.

Non-root execution reduces ordinary process privileges.

Linux user namespaces can map container identities to different host identities.

Rootless Docker changes the privilege model of the Docker daemon itself.

Linux capabilities divide selected administrative privileges into more precise units.

Capability dropping can reduce unnecessary authority.

No-new-privileges limits certain privilege escalation mechanisms.

Seccomp restricts system-call operations.

AppArmor and SELinux provide additional mandatory access-control mechanisms in supported environments.

Read-only filesystems reduce opportunities for modification.

Temporary writable mounts accommodate applications that require selected write access.

Runtime secrets provide a mechanism for granting confidential information to specified services without embedding it into the image.

BuildKit secret mounts provide temporary access to confidential build inputs.

Image scanning, SBOMs, and provenance support software supply-chain transparency.

However, these mechanisms do not eliminate the need for application security analysis and ongoing maintenance.

The practical laboratory demonstrates that a hardened application can preserve required HTTP functionality while operating under more restrictive privileges, filesystem access, network configuration, and resource limits.

**The central principle of this lecture is that Docker security is achieved through coordinated, layered controls that restrict unnecessary authority at build time, runtime, and host-management boundaries.**

---

# 98. REFERENCES AND RECOMMENDED READING

## Docker Security Architecture

[1] Docker Inc. *Docker Engine Security.*  
https://docs.docker.com/engine/security/

[2] Docker Inc. *Running Containers — Runtime Privileges and Linux Capabilities.*  
https://docs.docker.com/engine/containers/run/

[3] Docker Inc. *Rootless Mode.*  
https://docs.docker.com/engine/security/rootless/

[4] Docker Inc. *User Namespace Remapping.*  
https://docs.docker.com/engine/security/userns-remap/

[5] Docker Inc. *Seccomp Security Profiles.*  
https://docs.docker.com/engine/security/seccomp/

[6] Docker Inc. *AppArmor Security Profiles.*  
https://docs.docker.com/engine/security/apparmor/

[7] Docker Inc. *Protect the Docker Daemon Socket.*  
https://docs.docker.com/engine/security/protect-access/

## Compose Runtime Security

[8] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[9] Docker Inc. *Compose Secrets Reference.*  
https://docs.docker.com/reference/compose-file/secrets/

[10] Docker Inc. *Manage Secrets in Docker Compose.*  
https://docs.docker.com/compose/how-tos/use-secrets/

## Build-Time Security

[11] Docker Inc. *Build Secrets.*  
https://docs.docker.com/build/building/secrets/

[12] Docker Inc. *Docker Build Variables.*  
https://docs.docker.com/build/building/variables/

[13] Docker Inc. *Docker Image Building Best Practices.*  
https://docs.docker.com/build/building/best-practices/

## Image Vulnerabilities and Supply Chains

[14] Docker Inc. *Docker Scout Overview.*  
https://docs.docker.com/scout/

[15] Docker Inc. *Docker Scout Quickstart.*  
https://docs.docker.com/scout/quickstart/

[16] Docker Inc. *Docker Scout CVEs Command.*  
https://docs.docker.com/reference/cli/docker/scout/cves/

[17] Docker Inc. *Build Attestations.*  
https://docs.docker.com/build/metadata/attestations/

[18] Docker Inc. *SBOM Attestations.*  
https://docs.docker.com/build/metadata/attestations/sbom/

[19] Docker Inc. *Provenance Attestations.*  
https://docs.docker.com/build/metadata/attestations/slsa-provenance/

## Security Standards and Background

[20] MITRE. *Common Vulnerabilities and Exposures.*  
https://www.cve.org/

[21] FIRST. *Common Vulnerability Scoring System.*  
https://www.first.org/cvss/

[22] OWASP. *OWASP Application Security Verification Standard.*  
https://owasp.org/www-project-application-security-verification-standard/

## Recommended Reading Sequence

Begin with references [1] and [2] to understand Docker's security architecture and runtime privilege mechanisms.

Continue with references [3] through [7] to study rootless operation, user namespace remapping, seccomp, AppArmor, and daemon protection.

References [8] through [10] provide the Compose security configuration model.

References [11] and [12] explain secure treatment of build-time credentials.

Finally, references [14] through [19] introduce vulnerability scanning, software component inventories, and build provenance.

---

# 99. FINAL LECTURE CONCLUSION

Container security is a fundamental responsibility in software engineering and infrastructure operations.

The ability to start an application inside Docker does not automatically establish that the application is appropriately protected.

Security depends on the privileges granted to its processes, the resources exposed through mounts and networks, the integrity of its image, the configuration of the container runtime, and the protection of the Docker host.

Non-root execution reduces unnecessary application privileges.

Linux capabilities provide more precise control over selected privileged operations.

Seccomp and mandatory access-control systems restrict additional categories of process behavior.

Read-only filesystems limit ordinary modification of the container runtime environment.

Secrets mechanisms help separate sensitive information from source code and image artifacts.

Resource constraints reduce selected operational risks associated with excessive resource consumption.

Image scanning and supply-chain metadata provide information about the software used to construct and distribute images.

The comparative laboratory illustrates how these measures can be applied without changing the principal behavior of a simple HTTP application.

The baseline and hardened services provide equivalent functionality.

Their runtime authority and exposure differ.

The hardened container executes under a non-root identity, drops Linux capabilities, restricts privilege acquisition, uses a read-only root filesystem, receives a scoped synthetic secret, and operates under explicit resource constraints.

Nevertheless, these controls do not guarantee complete security.

Application vulnerabilities, dependency risks, host configuration, daemon permissions, and operational procedures remain important.

The correct engineering approach is to combine multiple protective mechanisms, verify their behavior, and continuously reassess the system as software and infrastructure change.

These principles establish the security foundation for the next lecture, which examines systematic Docker troubleshooting and operational diagnostics.

---

**END OF LECTURE 16**

**Next Lecture:** Lecture 17 — Docker Troubleshooting and Operational Diagnostics: Container Logs, Exit Codes, Resource Monitoring, Network Failures, Volume Problems, Docker Events, and Systematic Root-Cause Analysis.
