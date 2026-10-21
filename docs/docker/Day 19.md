# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 19 — DOCKER IN PRODUCTION: DEPLOYMENT ARCHITECTURE, HTTPS/TLS, HEALTH MONITORING, RESTART POLICIES, RESOURCE MANAGEMENT, OBSERVABILITY, PERSISTENT DATA PROTECTION, BACKUPS, AND OPERATIONAL READINESS

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 19 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 6–8 hours  
**Lecture Type:** Formal Academic Lecture, Production-Inspired Systems Laboratory, Reliability Assessment, and Operational Examination

**Prerequisites:** Lectures 01–18, particularly Docker networking, volumes, Compose, health checks, image optimization, container security, troubleshooting, and image registries.

---

# 1. PURPOSE OF THE LECTURE

The successful execution of a containerized application is an important engineering achievement.

However, successful execution alone does not establish that an application is suitable for production operation.

A production application must satisfy requirements that extend beyond starting containers and responding to requests.

These requirements may include:

- Reliable application startup.
- Continued service availability.
- Appropriate application health monitoring.
- Controlled recovery after process failures.
- Resource utilization management.
- Secure network communication.
- Appropriate handling of credentials.
- Persistent data protection.
- Backup and restoration procedures.
- Operational logging.
- Incident investigation.
- Software release control.
- Secure infrastructure configuration.
- Maintenance planning.
- Recovery from infrastructure failure.

Production engineering involves coordinating these requirements into an operational system.

Lecture 19 examines the transition from a functional Docker Compose application to a production-inspired deployment architecture.

The central emphasis is on understanding the responsibilities of the application, containers, Docker Engine, storage infrastructure, reverse proxy, and system operator.

The practical laboratory uses three services:

1. Nginx — HTTPS entry point and reverse proxy.
2. Flask — HTTP application logic.
3. Redis — Persistent counter storage.

The deployment also introduces resource limits, restart policies, health checks, network segmentation, bounded logs, a read-only application filesystem, and a verifiable backup procedure.

---

# 2. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define production deployment.
2. Distinguish functional correctness from operational readiness.
3. Explain the principal requirements of a production containerized application.
4. Define reliability, availability, and resilience.
5. Distinguish service-level indicators, objectives, and agreements.
6. Explain error budgets.
7. Define Recovery Point Objective.
8. Define Recovery Time Objective.
9. Distinguish stateful and stateless services.
10. Identify failure domains in a containerized system.
11. Explain the limitations of single-host Docker Compose deployment.
12. Define immutable application releases.
13. Explain release promotion and rollback.
14. Configure Docker Compose restart policies.
15. Distinguish manual restart from runtime restart policy behavior.
16. Explain why unhealthy containers are not necessarily restarted automatically.
17. Configure liveness and readiness checks.
18. Explain startup dependencies.
19. Describe graceful process termination.
20. Configure shutdown grace periods.
21. Explain container resource isolation through cgroups.
22. Configure memory limits.
23. Configure CPU constraints.
24. Configure process-count limits.
25. Interpret out-of-memory events.
26. Explain the purpose of bounded container logging.
27. Configure Docker's local logging driver.
28. Describe metrics, logs, and traces.
29. Define observability.
30. Explain basic alerting and incident response.
31. Describe Docker network segmentation.
32. Explain HTTPS and TLS.
33. Distinguish encryption in transit from encryption at rest.
34. Configure Nginx as a TLS termination proxy.
35. Generate a short-lived self-signed certificate for local testing.
36. Verify certificate subject alternative names and expiration.
37. Explain why public deployment requires trusted certificates.
38. Configure appropriate HTTP security response headers.
39. Explain the role of runtime secrets.
40. Configure non-root application execution.
41. Configure a read-only application root filesystem.
42. Describe Docker volume durability.
43. Distinguish persistence from backup.
44. Explain Redis append-only persistence.
45. Describe consistent database backup requirements.
46. Create a Docker volume archive.
47. Restore database files into an independent volume.
48. Verify recovery through a new Redis container.
49. Describe operational runbooks.
50. Complete a production readiness assessment.

---

# PART I — PRODUCTION ENGINEERING FOUNDATIONS

# 3. DEFINITION OF PRODUCTION DEPLOYMENT

A production deployment is a software system operating in an environment intended to provide its required service to actual users or business processes.

Production environments are generally subject to formal operational expectations.

These may concern:

- Availability.
- Security.
- Performance.
- Data integrity.
- Capacity.
- Recoverability.
- Change management.
- Monitoring.
- Compliance.

A production environment is not defined solely by the use of a particular Docker command.

For example:

```bash
docker compose up -d
```

may be used during both development and production-like deployment.

The command alone does not establish the operational maturity of the resulting service.

---

# 4. FUNCTIONAL CORRECTNESS VERSUS OPERATIONAL READINESS

## 4.1 Functional Correctness

Functional correctness means the application performs its intended operations.

For example:

- A webpage loads.
- A counter increments.
- A database query succeeds.
- An API returns valid JSON.

## 4.2 Operational Readiness

Operational readiness concerns whether the application can be responsibly maintained under expected conditions.

It includes:

- Monitoring.
- Recovery procedures.
- Backup verification.
- Access control.
- Resource capacity.
- Update procedures.
- Failure response.
- Security maintenance.

## 4.3 Comparison

| Property | Functional correctness | Operational readiness |
|---|---|---|
| HTTP request succeeds | Yes | Relevant but insufficient |
| Database stores data | Yes | Requires durability and recovery planning |
| Container starts | Yes | Requires lifecycle management |
| Application has logs | Helpful | Requires retention and investigation procedures |
| Backup is restorable | Not usually a functional requirement | Essential for relevant stateful systems |
| Certificate is trusted | Not necessary for local HTTP testing | Necessary for appropriate public HTTPS deployment |
| Service has monitoring | Not required for basic functionality | Important for ongoing operation |

**Engineering principle:** A functioning application is not automatically an operationally prepared service.

---

# 5. RELIABILITY, AVAILABILITY, AND RESILIENCE

## 5.1 Reliability

Reliability is the ability of a system to perform its required functions correctly over a specified period and under specified conditions.

## 5.2 Availability

Availability concerns whether a service is accessible when required.

A service may become unavailable because of:

- Process failure.
- Host failure.
- Network outage.
- Database failure.
- Incorrect configuration.
- Storage exhaustion.
- Deployment error.

## 5.3 Resilience

Resilience is the ability of a system to withstand, adapt to, and recover from disruptions.

## 5.4 Relationship

```text
                  APPLICATION
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
    RELIABILITY    AVAILABILITY    RESILIENCE
        |              |              |
        v              v              v
   Correct work     Accessible     Recovery from
   over time        when needed    disruption
```

These properties are related but not identical.

---

# 6. SERVICE-LEVEL INDICATORS

A Service-Level Indicator, abbreviated SLI, is a quantitative measurement of a service's behavior.

Examples include:

- Percentage of successful HTTP requests.
- Request latency.
- Percentage of time a service is available.
- Database operation success rate.
- Error response percentage.

An SLI provides measurable evidence about a particular operational property.

For example, the HTTP success-rate SLI may be defined as:

\[
SLI = \frac{\text{Successful Eligible Requests}}{\text{Total Eligible Requests}}
\]

The definition of an eligible request must be established clearly.

Not every HTTP 4xx response necessarily indicates a service failure.

A correctly rejected unauthorized request may represent appropriate application behavior.

---

# 7. SERVICE-LEVEL OBJECTIVES

A Service-Level Objective, abbreviated SLO, defines a target value for a service-level indicator.

Example:

```text
At least 99.9% of eligible requests should succeed
during the defined measurement period.
```

An SLO is an operational engineering target.

It should specify:

1. What is measured.
2. How it is measured.
3. The target value.
4. The measurement period.
5. Any exclusions.

An SLO without a defined measurement methodology can be ambiguous.

---

# 8. SERVICE-LEVEL AGREEMENTS

A Service-Level Agreement, abbreviated SLA, is a formal commitment concerning specified service performance.

An SLA may include:

- Availability commitments.
- Support obligations.
- Response expectations.
- Measurement definitions.
- Remedies for unmet commitments.

An SLO is an engineering objective.

An SLA is a contractual or formal service commitment.

They are related but should not be treated as interchangeable.

---

# 9. ERROR BUDGETS

An error budget represents the amount of failure permitted by an applicable reliability target over a defined measurement period.

For example, a service with a 99.9% availability objective permits approximately 0.1% unavailability during its measurement period.

The error budget can help teams balance deployment changes against reliability requirements.

## Engineering Interpretation

A team might reduce risky deployment frequency when the error budget has been heavily consumed.

Conversely, a system operating consistently above its reliability objective may have greater capacity for controlled change.

An error budget is a decision-support mechanism, not a guarantee against failure.

---

# 10. RECOVERY POINT OBJECTIVE

## 10.1 Definition

Recovery Point Objective, abbreviated RPO, describes the maximum acceptable amount of data loss measured in time.

Example:

```text
RPO = 15 minutes
```

This indicates a recovery requirement intended to limit data loss to no more than the specified interval.

## 10.2 Example

If a database is restored from a backup created 10 minutes before an incident, writes made after the backup may be unavailable.

The actual data-loss interval depends on the backup, replication, and recovery mechanisms.

## 10.3 Importance

An organization must decide how much data loss is acceptable before selecting a backup or replication strategy.

---

# 11. RECOVERY TIME OBJECTIVE

## 11.1 Definition

Recovery Time Objective, abbreviated RTO, describes the targeted maximum duration for restoring a required service after a disruption.

Example:

```text
RTO = 30 minutes
```

## 11.2 Recovery Tasks

Recovery may require:

- Detecting the incident.
- Identifying the cause.
- Replacing failed infrastructure.
- Restoring application images.
- Restoring database contents.
- Verifying application functionality.
- Reopening the service.

## 11.3 Relationship

RPO addresses acceptable data loss.

RTO addresses acceptable recovery time.

A system may have a low RTO but a comparatively high RPO, or the reverse.

---

# 12. STATEFUL AND STATELESS SERVICES

## 12.1 Stateless Service

A stateless service does not depend on persistent local process state to retain its authoritative application information between requests.

A Flask application using Redis as its source of persistent data can be designed to operate mostly statelessly.

## 12.2 Stateful Service

A stateful service maintains information requiring persistence or coordinated recovery.

Redis is the stateful component in the capstone.

## 12.3 Architecture

```text
                    HTTP CLIENT
                         |
                         v
                  NGINX REVERSE PROXY
                         |
                         v
                   FLASK APPLICATION
                    (mostly stateless)
                         |
                         v
                    REDIS DATABASE
                       (stateful)
                         |
                         v
                    PERSISTENT VOLUME
```

## 12.4 Engineering Importance

Stateless components can often be replaced more easily than stateful components.

Stateful services require explicit attention to storage, data integrity, durability, and recovery.

---

# 13. FAILURE DOMAINS

A failure domain is a component or collection of components that may fail together due to a shared dependency.

Examples include:

- One container.
- One Docker Engine instance.
- One physical host.
- One virtual machine.
- One storage device.
- One network connection.
- One availability zone.
- One data center.

## 13.1 Single-Host Failure Domain

A Docker Compose project running entirely on one host may contain several containers.

However, a failure of the host or Docker Engine can affect all of them.

## 13.2 Critical Distinction

Three containers running on one Docker host do not automatically constitute a highly available system.

---

# 14. LIMITATIONS OF SINGLE-HOST COMPOSE

Docker Compose is useful for defining and operating applications on a single Docker environment.

It can provide:

- Declarative service configuration.
- Network creation.
- Named volume management.
- Health checks.
- Startup dependencies.
- Restart policies.
- Reconciliation of configuration changes.

However, a basic single-host Compose deployment does not inherently provide:

- Multi-host failover.
- Distributed service scheduling.
- Automatic migration after host failure.
- Distributed database replication.
- Geographic redundancy.
- Complete production monitoring.
- Off-site backup.

These requirements must be addressed through additional architecture and operational processes when necessary.

---

# 15. IMMUTABLE APPLICATION RELEASES

An immutable release approach treats an approved application image as a fixed deployable artifact.

A release may be identified by:

```text
registry.example.com/application@sha256:<actual-digest>
```

The application is configured at runtime rather than modified inside its running container.

## Benefits

- Improved release traceability.
- Consistent artifact distribution.
- Easier rollback to a previously approved image.
- Reduced differences between test and deployment artifacts.

## Limitations

Deploying an immutable image does not make runtime databases, network services, or credentials immutable.

---

# 16. PRODUCTION COMPOSE CONFIGURATION

A production-oriented Compose deployment may differ from development in several ways.

Development commonly uses:

- Source-code bind mounts.
- Automatic reload.
- Verbose debugging.
- Rapid local rebuilding.
- Additional development tools.

Production commonly prefers:

- Approved image artifacts.
- Explicit image versions or digests.
- Controlled environment variables.
- Appropriate restart policies.
- Resource constraints.
- Security restrictions.
- Persistent logs or log collection.
- Health monitoring.
- Limited published endpoints.
- Documented operational procedures.

## Important Principle

A production deployment should not ordinarily depend on manually editing the source code inside running containers.

---

# 17. HEALTH CHECKS IN PRODUCTION

Health checks provide selected evidence about an application's operational condition.

## 17.1 Liveness

Liveness asks whether the application can respond at a basic level.

Example:

```text
GET /health/live
```

## 17.2 Readiness

Readiness asks whether selected required application functionality is available.

Example:

```text
GET /health/ready
```

A counter application may require Redis connectivity.

## 17.3 Difference

Flask may remain alive even when Redis becomes unavailable.

The liveness endpoint can return HTTP 200 while readiness returns HTTP 503.

## 17.4 Important Qualification

Docker Engine supports a health-check mechanism.

It does not automatically provide separate Kubernetes-style liveness and readiness controllers.

---

# 18. HEALTH-CHECK PARAMETERS

A Compose health check can define:

```yaml
healthcheck:
  test: ["CMD", "python", "-c", "print('ok')"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 15s
```

## interval

Defines the scheduling interval for health-check executions.

## timeout

Limits execution time.

## retries

Defines the threshold for qualifying consecutive failures.

## start_period

Provides an initial period during which failures ordinarily do not count toward the unhealthy threshold.

## Engineering Principle

Health checks must be inexpensive, bounded, and relevant to the actual service.

---

# 19. SERVICE STARTUP DEPENDENCIES

Docker Compose supports health-aware dependency conditions.

Example:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

This allows Compose to wait for Redis to pass its health check during an applicable startup operation.

## Limitation

The condition does not guarantee permanent Redis availability.

Application code must handle dependency failures after startup.

---

# 20. RESTART POLICIES

Docker supports several principal container restart policies.

| Policy | General behavior |
|---|---|
| `no` | No automatic restart |
| `always` | Restart following eligible termination |
| `on-failure` | Restart after qualifying nonzero process exits |
| `unless-stopped` | Restart eligible terminated containers while respecting explicit stop behavior |

For the laboratory:

```yaml
restart: unless-stopped
```

will be used.

## Important Distinction

A restart policy responds to container process lifecycle conditions.

A container becoming unhealthy without its principal process exiting is not automatically restarted merely because its health check reports failure.

---

# 21. DEPENDENCY RESTART PROPAGATION

Compose supports dependency-level restart propagation.

Example:

```yaml
depends_on:
  redis:
    condition: service_healthy
    restart: true
```

This permits Compose to restart a dependent service after certain explicit Compose operations affecting the dependency.

It is different from runtime restart policies.

It does not mean that every unexpected Redis process crash automatically restarts the Flask application.

---

# 22. GRACEFUL SHUTDOWN

A production application should have an appropriate termination strategy.

When a container is stopped, Docker ordinarily sends a termination signal to the principal container process.

The application can use this opportunity to:

- Stop accepting new work.
- Complete or terminate active requests.
- Flush selected buffers.
- Close network connections.
- Release resources.

After the applicable timeout, Docker may forcibly terminate remaining processes.

## Compose Configuration

```yaml
stop_grace_period: 30s
```

## Important Qualification

Graceful termination is not automatically guaranteed by specifying a grace period.

The application and process manager must actually support appropriate signal handling.

---

# 23. GUNICORN PROCESS MANAGEMENT

Gunicorn manages Python web application workers.

A typical configuration may include:

```text
--workers 2
--timeout 30
--graceful-timeout 25
```

## workers

Controls the number of application worker processes.

## timeout

Defines a timeout for workers considered silent according to Gunicorn's worker-management behavior.

## graceful-timeout

Defines an interval relevant to graceful worker restart or shutdown behavior.

## Operational Principle

The Docker shutdown grace period should be consistent with the application process manager's shutdown expectations.

Worker count must also be selected according to available CPU, memory, and workload characteristics.

---

# 24. RESOURCE MANAGEMENT THROUGH CGROUPS

Linux control groups, abbreviated cgroups, provide mechanisms for accounting and controlling selected resources.

Docker uses applicable host mechanisms to enforce resource limits.

Resources may include:

- CPU.
- Memory.
- Process count.
- Block I/O.

These controls help prevent one workload from consuming unlimited resources.

However, resource limits must be selected carefully.

Limits that are too restrictive can reduce service availability.

---

# 25. MEMORY LIMITS

Compose supports:

```yaml
mem_limit: 256m
```

This defines a memory limit for the selected container under supported Docker Engine configurations.

## Consequences

If a process exceeds relevant memory constraints and memory cannot be reclaimed, it may be terminated.

## Diagnostic Evidence

Useful commands include:

```bash
docker stats
```

and:

```bash
docker inspect CONTAINER --format '{{.State.OOMKilled}}'
```

## Important Distinction

An exit code of 137 does not independently prove out-of-memory termination.

The investigation must consider supporting evidence.

---

# 26. CPU CONSTRAINTS

Compose supports:

```yaml
cpus: 0.75
```

This configures an applicable CPU resource constraint.

The value should be interpreted according to Docker's scheduling and quota behavior.

It does not mean that an application possesses a dedicated physical CPU.

CPU restrictions should be selected based on observed workload requirements.

---

# 27. PROCESS LIMITS

Compose supports:

```yaml
pids_limit: 96
```

This limits the permitted number of processes and threads according to the applicable cgroup mechanism.

The restriction can reduce the impact of certain runaway process-creation conditions.

However, applications that legitimately require many workers or threads may fail if the limit is too low.

---

# 28. RESOURCE LIMIT SELECTION

Resource limits should be determined through observation and workload testing.

Useful questions include:

1. What is typical memory consumption?
2. What is peak memory consumption?
3. How many processes are created?
4. How much CPU is required during normal operation?
5. How does the service behave under expected concurrency?
6. What happens when resource limits are reached?
7. What recovery action is appropriate?

## Engineering Principle

Resource limits are a combination of capacity planning, availability management, and security-relevant containment.

They should not be selected solely to minimize displayed resource allocations.

---

# 29. LOGGING IN PRODUCTION

Operational logs should help identify:

- Application startup.
- Request failures.
- Dependency failures.
- Configuration errors.
- Shutdown behavior.
- Recovery events.
- Unexpected process termination.

Containerized applications commonly write logs to standard output and standard error.

Docker then handles those streams through the configured logging driver.

This approach reduces dependence on files stored inside disposable container writable layers.

---

# 30. BOUNDED LOGGING

Unbounded logging can consume excessive storage.

Docker's `local` logging driver supports log rotation and compression.

Example:

```yaml
logging:
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
```

## Benefits

- Limits retained local log volume.
- Reduces uncontrolled log-file growth.
- Supports retrieval through Docker logging tools.
- Provides predictable local retention bounds.

## Important Qualification

Local log rotation is not equivalent to long-term centralized log retention.

A production application may require independent collection and durable storage.

---

# 31. OBSERVABILITY

Observability is the ability to understand a system's internal behavior through its externally available signals.

Three commonly discussed observability signal categories are:

1. Logs.
2. Metrics.
3. Traces.

## Logs

Describe discrete events.

## Metrics

Provide quantitative measurements.

## Traces

Describe the flow of operations through one or more services.

## Architecture

```text
                  APPLICATION
                       |
           +-----------+-----------+
           |           |           |
           v           v           v
          LOGS       METRICS      TRACES
           |           |           |
           +-----------+-----------+
                       |
                       v
               OPERATIONAL ANALYSIS
                       |
                       v
                  ALERTING
```

---

# 32. LOGS, METRICS, AND TRACES ARE DIFFERENT

A request failure can be investigated through several signals.

**Log example:**

```text
Redis operation failed: connection unavailable.
```

**Metric example:**

```text
HTTP request error rate increased.
```

**Trace example:**

```text
HTTP request -> Flask handler -> Redis request -> timeout
```

Each signal provides different information.

A system with only logs can still be useful, but comprehensive observability often requires additional instrumentation and collection infrastructure.

---

# 33. ALERTING AND INCIDENT RESPONSE

Monitoring identifies conditions of interest.

Alerting communicates selected conditions requiring attention.

Examples include:

- Sustained readiness failure.
- Repeated container process crashes.
- Excessive HTTP error rate.
- High memory utilization.
- Database storage exhaustion.
- Approaching TLS certificate expiration.
- Failed scheduled backup.

## Important Principle

A health check that nobody observes may provide limited operational benefit.

Monitoring should be connected to appropriate notification and incident-response procedures.

---

# 34. DOCKER NETWORK SEGMENTATION

A production-oriented application should avoid unnecessary communication pathways.

For the practical laboratory:

```text
Nginx -> Flask -> Redis
```

The services will use two networks.

```text
frontend
backend
```

Nginx will join only `frontend`.

Flask will join both.

Redis will join only `backend`.

The backend network will be configured as internal.

---

# 35. INTERNAL DOCKER NETWORKS

Compose supports:

```yaml
networks:
  backend:
    internal: true
```

An internal network is isolated from ordinary external routing through that network.

This is useful for database communication.

## Important Qualification

A service attached to both an internal and a non-internal network can still have external connectivity through the non-internal network.

Network segmentation does not replace application authentication or authorization.

---

# PART II — HTTPS AND TRANSPORT SECURITY

# 36. HTTP COMMUNICATION

HTTP is an application-layer protocol.

When HTTP is used without TLS, application data is not encrypted by HTTP itself.

Depending on the surrounding network environment, traffic may be observable or modifiable by parties with access to the communication path.

This is unsuitable for many production scenarios involving sensitive application data.

---

# 37. HTTPS

HTTPS is HTTP carried over a TLS-protected connection.

TLS provides security properties including:

- Encryption in transit.
- Server authentication through certificates.
- Integrity protection for protected traffic.

The effectiveness of these properties depends on correct protocol and certificate configuration.

---

# 38. TLS TERMINATION

A reverse proxy may terminate HTTPS connections.

The client establishes TLS with Nginx.

Nginx decrypts the received HTTP requests and forwards them to the backend application through an internal connection.

## Architecture

```text
                    BROWSER
                       |
                       |
                    HTTPS/TLS
                       |
                       v
                  NGINX GATEWAY
                 TLS TERMINATION
                       |
                       |
                INTERNAL HTTP
                       |
                       v
                 FLASK SERVICE
                       |
                       |
                 REDIS PROTOCOL
                       |
                       v
                    REDIS
```

## Important Qualification

TLS termination protects the client-to-proxy connection.

It does not automatically encrypt the proxy-to-application or application-to-database connection.

Additional transport protection may be required for systems with different threat models or distributed network boundaries.

---

# 39. DIGITAL CERTIFICATES

A TLS server certificate associates information about a server identity with a public key.

Certificates are normally evaluated through a trust relationship involving certificate authorities and client trust stores.

A certificate may contain:

- Subject information.
- Subject Alternative Names.
- Public key.
- Validity period.
- Issuer information.
- Digital signature.

Modern hostname verification relies on appropriate Subject Alternative Name entries.

---

# 40. PRIVATE KEYS

A TLS private key must remain confidential.

The public certificate can be distributed to clients.

The corresponding private key should be readable only by appropriately authorized server processes.

For this laboratory:

```text
certs/server.crt
certs/server.key
```

The certificate is a public artifact.

The private key is sensitive.

The Nginx master process must be able to read the key.

---

# 41. SELF-SIGNED CERTIFICATES

A self-signed certificate is signed using its own associated private key.

Such certificates are useful for:

- Local development.
- Controlled laboratory testing.
- Internal experiments with an explicitly established trust relationship.

However, a browser will not ordinarily trust an arbitrary self-signed certificate automatically.

## Important Limitation

The presence of HTTPS does not alone mean that a browser can authenticate the server successfully.

Certificate trust must also be established.

---

# 42. PRODUCTION CERTIFICATE REQUIREMENTS

A public production service ordinarily requires:

1. An appropriate DNS identity.
2. A trusted certificate.
3. A valid certificate chain.
4. Protection of private keys.
5. Certificate renewal procedures.
6. Expiration monitoring.
7. Suitable TLS protocol configuration.

Certificate-management tools may automate renewal and deployment.

The present lecture will use a short-lived certificate only for localhost testing.

---

# 43. HTTP SECURITY HEADERS

A reverse proxy can add selected HTTP response headers.

Examples include:

- `X-Content-Type-Options`.
- `Referrer-Policy`.
- `Content-Security-Policy`.

These headers can contribute to browser security when configured appropriately.

## Important Qualification

Security headers complement application security.

They do not repair vulnerable application logic.

A Content Security Policy must match the resources actually used by the application.

---

# 44. HTTP STRICT TRANSPORT SECURITY

HTTP Strict Transport Security, abbreviated HSTS, allows a website to instruct supported browsers to use HTTPS for future connections.

It can be useful in correctly configured production deployments.

However, careless HSTS configuration can interfere with local development and certificate troubleshooting.

The laboratory will not enable HSTS for its short-lived, self-signed localhost certificate.

---

# PART III — DATA PROTECTION AND RECOVERY

# 45. PERSISTENT VOLUMES

A named Docker volume maintains data independently of a particular container's writable layer.

For Redis:

```yaml
volumes:
  - redis-data:/data
```

The Redis persistence directory is mounted to Docker-managed storage.

## Important Distinction

Volume persistence does not automatically guarantee data consistency, backups, or disaster recovery.

---

# 46. REDIS APPEND-ONLY PERSISTENCE

Redis can persist database modifications through an append-only file mechanism.

The laboratory uses:

```text
appendonly yes
appendfsync everysec
```

## Meaning

AOF records database modifications in a recoverable form.

The `everysec` synchronization policy requests periodic synchronization.

## Durability Limitation

Unexpected failure can still result in loss of recent writes.

The exact behavior depends on operating-system, filesystem, and storage conditions.

---

# 47. MEMORY MANAGEMENT IN REDIS

Redis can be configured with a maximum memory target.

Example:

```text
maxmemory 128mb
```

A corresponding policy:

```text
maxmemory-policy noeviction
```

prevents ordinary key eviction as the response to certain memory-pressure conditions.

## Important Qualification

This configuration does not guarantee that every write will succeed.

When Redis cannot satisfy memory requirements, write operations may fail.

The application must handle errors rather than assume unlimited database capacity.

---

# 48. DATA PERSISTENCE VERSUS BACKUP

A named volume is the active storage location of an application.

A backup is a separate recoverable copy.

## Comparison

| Property | Persistent volume | Backup |
|---|---|---|
| Stores active application data | Yes | Usually not the active dataset |
| Survives ordinary container removal | Yes | Depends on backup location |
| Protects against deletion of the only volume | No | Potentially |
| Supports historical recovery points | Not inherently | Potentially |
| Requires restoration procedures | Usually not for ordinary restart | Yes |
| Protects against total host loss | Not by itself | Only with suitable independent storage |

---

# 49. CONSISTENT DATABASE BACKUPS

Copying files while a database is actively modifying them can produce an inconsistent backup.

A suitable backup procedure may involve:

- Database-native backup tools.
- Application-consistent snapshots.
- Coordinated filesystem snapshots.
- Quiescing database writes.
- Graceful database shutdown.

For the laboratory, the procedure will:

1. Record the counter value.
2. Request a Redis snapshot.
3. Stop the application through Compose.
4. Archive the stopped Redis volume.
5. Restart the application.
6. Restore the archive to a separate volume.
7. Verify recovered data.

This procedure deliberately introduces downtime.

It is a training example, not a universal production backup strategy.

---

# 50. BACKUP STORAGE INDEPENDENCE

A backup stored on the same physical host as the original data may be destroyed by the same host-level incident.

More resilient backup strategies commonly require:

- Off-host storage.
- Appropriate access controls.
- Retention periods.
- Backup integrity checking.
- Restore testing.
- Recovery documentation.
- Encryption where required.

The laboratory will store its archive in a local host directory so its contents can be inspected.

A production system would require stronger storage independence.

---

# 51. BACKUP VERIFICATION

A successful archive operation does not establish complete recoverability.

A useful recovery test should confirm:

1. The archive exists.
2. The archive can be read.
3. The expected files can be extracted.
4. The database starts from the restored files.
5. The expected application data is present.
6. The resulting service behaves correctly.

The practical laboratory will test restoration through an independent Redis container.

---

# 52. OPERATIONAL RUNBOOKS

An operational runbook documents procedures for maintaining or recovering a service.

A runbook may include:

- Service architecture.
- Important commands.
- Health-check URLs.
- Recovery procedures.
- Backup locations.
- Restart procedures.
- Contact and escalation details.
- Known failure scenarios.
- Security precautions.

## Importance

During an incident, an operator should not need to reconstruct the entire architecture from memory.

A tested runbook reduces ambiguity and operational risk.

---

# PART IV — PRODUCTION-INSPIRED CAPSTONE PROJECT

# 53. PROJECT TITLE

**Secure and Resilient Containerized Counter Service: Nginx HTTPS Gateway, Flask Application, Redis Persistence, Resource Controls, Monitoring, and Tested Recovery**

## Project Objective

Construct and evaluate a three-service application that demonstrates the principal operational controls discussed in the lecture.

The project is deliberately restricted to a local Docker environment.

---

# 54. SYSTEM REQUIREMENTS

## Functional Requirements

The system must:

1. Display a webpage.
2. Retrieve a persistent counter.
3. Increment the counter.
4. Return JSON API responses.
5. Provide liveness and readiness endpoints.
6. Preserve Redis data across container recreation.

## Operational Requirements

The system must:

1. Publish Nginx on localhost.
2. Support HTTPS.
3. Use a short-lived self-signed certificate for testing.
4. Separate frontend and backend networks.
5. Avoid publishing Redis.
6. Run Flask without root privileges.
7. Use a read-only Flask root filesystem.
8. Apply resource limits.
9. Apply restart policies.
10. Use bounded local logging.
11. Support graceful shutdown.
12. Support backup and restoration.

---

# 55. SYSTEM ARCHITECTURE

```text id="kw8unv"
                    LOCAL BROWSER
                         |
                         |
                HTTPS localhost:8443
                         |
                         v
                +------------------+
                |      NGINX       |
                |   TLS GATEWAY    |
                | Container :443   |
                +------------------+
                         |
                         |
                  FRONTEND NETWORK
                         |
                         v
                +------------------+
                |      FLASK       |
                |     GUNICORN     |
                | Container :8000  |
                |    NON-ROOT      |
                | READ-ONLY ROOT   |
                +------------------+
                         |
                         |
                 INTERNAL BACKEND
                         |
                         v
                +------------------+
                |      REDIS       |
                | Container :6379  |
                |    AOF ENABLED   |
                +------------------+
                         |
                         |
                       /data
                         |
                         v
                +------------------+
                |   NAMED VOLUME   |
                |    redis-data    |
                +------------------+
                         |
                         |
                 CONTROLLED BACKUP
                         |
                         v
                +------------------+
                |    TAR ARCHIVE   |
                |   HOST BACKUPS   |
                +------------------+
```

The system separates the browser-facing HTTPS connection from internal application communication.

Only Nginx publishes host ports.

---

# 56. PROJECT DIRECTORY STRUCTURE

Create:

```text id="kzfppx"
docker-lecture19/
├── compose.yaml
├── compose.ops.yaml
├── .env
├── .gitignore
├── certs/
│   ├── server.crt
│   └── server.key
├── backups/
├── gateway/
│   └── default.conf
└── web/
    ├── Dockerfile
    ├── .dockerignore
    ├── requirements.txt
    ├── app.py
    ├── templates/
    │   └── index.html
    └── static/
        ├── app.js
        └── style.css
```

The certificate files will be generated during the laboratory.

The backup archive will also be generated during the laboratory.

---

# 57. APPLICATION DEPENDENCIES

Create:

`web/requirements.txt`

Insert:

```text id="1lm3jv"
Flask==3.1.3
redis==6.2.0
gunicorn==26.2.0
```

These are explicitly selected direct dependencies for the training project.

For rigorous production reproducibility, additional controls may include:

- Fully resolved dependency locks.
- Package hashes.
- Base-image digests.
- Dependency scanning.
- Tested update procedures.

---

# 58. COMPLETE FLASK APPLICATION

Create:

`web/app.py`

Insert:

```python id="ubthwb"
import logging
import os

import redis

from flask import (
    Flask,
    jsonify,
    render_template,
)

from redis.exceptions import RedisError


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

logger = logging.getLogger("lecture19")


app = Flask(__name__)


APP_TITLE = os.getenv(
    "APP_TITLE",
    "Production-Inspired Docker Laboratory",
)

APP_ENV = os.getenv(
    "APP_ENV",
    "training",
)

REDIS_HOST = os.getenv(
    "REDIS_HOST",
    "redis",
)

REDIS_PORT = int(
    os.getenv("REDIS_PORT", "6379")
)

COUNTER_KEY = os.getenv(
    "COUNTER_KEY",
    "lecture19:counter",
)


client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)


@app.get("/")
def home():

    return render_template(
        "index.html",
        app_title=APP_TITLE,
        app_env=APP_ENV,
    )


@app.get("/health/live")
def live():

    return jsonify(
        service="web",
        status="alive",
    ), 200


@app.get("/health/ready")
def ready():

    try:

        client.ping()

        return jsonify(
            service="web",
            status="ready",
            redis="available",
        ), 200

    except RedisError as error:

        logger.warning(
            "Readiness failed: %s",
            type(error).__name__,
        )

        return jsonify(
            service="web",
            status="not_ready",
            redis="unavailable",
        ), 503


@app.get("/api/count")
def count():

    try:

        value = client.get(COUNTER_KEY)

        count_value = (
            int(value)
            if value is not None
            else 0
        )

        return jsonify(
            count=count_value,
        ), 200

    except RedisError as error:

        logger.error(
            "Counter retrieval failed: %s",
            type(error).__name__,
        )

        return jsonify(
            error="Counter service unavailable",
        ), 503

    except (ValueError, TypeError):

        logger.error(
            "Invalid counter data"
        )

        return jsonify(
            error="Invalid stored counter",
        ), 500


@app.post("/api/increment")
def increment():

    try:

        new_value = client.incr(COUNTER_KEY)

        logger.info(
            "Counter increment succeeded"
        )

        return jsonify(
            count=new_value,
        ), 200

    except RedisError as error:

        logger.error(
            "Counter increment failed: %s",
            type(error).__name__,
        )

        return jsonify(
            error="Counter service unavailable",
        ), 503
```

## Application Analysis

The Flask application does not store the authoritative counter in its own process memory.

Redis maintains the counter value.

The application can remain alive when Redis becomes unavailable.

The readiness endpoint provides evidence of Redis accessibility.

Counter operations return controlled error responses when the database cannot be used.

---

# 59. HTML USER INTERFACE

Create:

`web/templates/index.html`

Insert:

```html id="ae13di"
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Docker Lecture 19</title>

    <link
        rel="stylesheet"
        href="{{ url_for('static', filename='style.css') }}"
    >

    <script
        src="{{ url_for('static', filename='app.js') }}"
        defer>
    </script>

</head>

<body>

    <main>

        <h1>{{ app_title }}</h1>

        <h2>Docker Lecture 19</h2>

        <p>
            Production-Inspired Container Operations
        </p>

        <p>
            HTTPS Gateway + Flask + Redis
        </p>

        <div id="counter">...</div>

        <button id="increment">
            Increment Counter
        </button>

        <p id="message"></p>

        <p class="environment">
            Application Environment:
            {{ app_env }}
        </p>

    </main>

</body>

</html>
```

The page loads its JavaScript and CSS from separate same-origin files.

This permits the gateway to apply a Content Security Policy without enabling inline application scripts.

---

# 60. JAVASCRIPT APPLICATION

Create:

`web/static/app.js`

Insert:

```javascript id="uxvtyy"
const counterElement =
    document.getElementById("counter");

const messageElement =
    document.getElementById("message");

const incrementButton =
    document.getElementById("increment");


async function loadCounter() {

    try {

        const response = await fetch(
            "/api/count",
            { cache: "no-store" }
        );

        const data = await response.json();

        if (!response.ok) {
            throw new Error(
                data.error || "Counter unavailable"
            );
        }

        counterElement.textContent =
            String(data.count);

        messageElement.textContent =
            "Redis counter is available";

    } catch (error) {

        counterElement.textContent = "--";

        messageElement.textContent =
            error.message;
    }
}


async function incrementCounter() {

    incrementButton.disabled = true;

    try {

        const response = await fetch(
            "/api/increment",
            {
                method: "POST"
            }
        );

        const data = await response.json();

        if (!response.ok) {
            throw new Error(
                data.error || "Increment failed"
            );
        }

        counterElement.textContent =
            String(data.count);

        messageElement.textContent =
            "Counter updated successfully";

    } catch (error) {

        messageElement.textContent =
            error.message;

    } finally {

        incrementButton.disabled = false;
    }
}


incrementButton.addEventListener(
    "click",
    incrementCounter
);

loadCounter();
```

The application uses HTTP GET to retrieve state and HTTP POST to increment the counter.

The browser communicates with Nginx over HTTPS.

---

# 61. CSS CONFIGURATION

Create:

`web/static/style.css`

Insert:

```css id="w0gzhp"
body {
    font-family: Arial, sans-serif;
    background: #f1f5f9;
    color: #0f172a;
    padding: 40px;
}

main {
    max-width: 720px;
    margin: 0 auto;
    background: white;
    padding: 42px;
    border-radius: 14px;
    text-align: center;
}

h1 {
    color: #2563eb;
}

#counter {
    font-size: 68px;
    font-weight: bold;
    margin: 32px 0;
}

button {
    background: #2563eb;
    color: white;
    border: none;
    border-radius: 8px;
    padding: 16px 28px;
    cursor: pointer;
    font-size: 16px;
}

button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

#message {
    margin-top: 25px;
}

.environment {
    margin-top: 30px;
    color: #64748b;
    font-size: 14px;
}
```

---

# 62. WEB APPLICATION DOCKERFILE

Create:

`web/Dockerfile`

Insert:

```dockerfile id="1cymgp"
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Lecture 19" \
      org.opencontainers.image.description="Production-Inspired Flask Counter"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=10001:10001 app.py ./app.py

COPY --chown=10001:10001 templates/ ./templates/

COPY --chown=10001:10001 static/ ./static/

USER 10001:10001

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "30", "--graceful-timeout", "25", "--worker-tmp-dir", "/tmp", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
```

## Dockerfile Design

The image:

- Uses a Python runtime.
- Installs application dependencies.
- Copies only the required application files.
- Runs under a non-root identity.
- Sends Gunicorn logs to standard output and standard error.
- Uses `/tmp` for worker temporary files.
- Declares container port 8000.

The Compose configuration will provide a writable tmpfs mount at `/tmp`.

---

# 63. BUILD-CONTEXT EXCLUSIONS

Create:

`web/.dockerignore`

Insert:

```dockerignore id="2fbgak"
.git
.env
*.log
*.tmp
*.pyc
__pycache__/
.venv/
venv/
```

Create the project root `.gitignore`:

```gitignore id="fkek59"
.env
certs/
backups/
__pycache__/
*.pyc
```

The certificate private key and local backup archives must not be committed to an ordinary source repository.

The Docker build context is `./web`, so its `.dockerignore` belongs inside that directory.

---

# 64. COMPLETE NGINX TLS CONFIGURATION

Create:

`gateway/default.conf`

Insert:

```nginx id="zb9w7h"
server {

    listen 80;

    server_name localhost;

    server_tokens off;

    location = /health/edge {

        default_type text/plain;

        return 200 "edge alive\n";
    }

    location = /nginx-status {

        allow 127.0.0.1;

        deny all;

        stub_status;
    }

    location / {

        return 308 https://localhost:8443$request_uri;
    }
}


server {

    listen 443 ssl;

    server_name localhost;

    server_tokens off;

    ssl_certificate
        /etc/nginx/certs/server.crt;

    ssl_certificate_key
        /etc/nginx/certs/server.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    ssl_session_cache shared:TLS:10m;

    ssl_session_timeout 10m;

    resolver 127.0.0.11 valid=10s ipv6=off;

    set $web_backend web;

    client_max_body_size 1m;

    add_header X-Content-Type-Options
        "nosniff" always;

    add_header Referrer-Policy
        "no-referrer" always;

    add_header Content-Security-Policy
        "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
        always;

    location / {

        proxy_pass http://$web_backend:8000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;

        proxy_set_header X-Real-IP
            $remote_addr;

        proxy_set_header X-Forwarded-For
            $proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto
            $scheme;

        proxy_connect_timeout 3s;

        proxy_read_timeout 10s;

    }
}
```

## Configuration Analysis

The first server block listens on HTTP port 80.

It provides a local gateway health endpoint and redirects ordinary requests to the laboratory HTTPS endpoint.

The second server block listens on HTTPS port 443.

It loads the certificate and private key.

It forwards application requests to Flask through the frontend Docker network.

The resolver allows the proxy to resolve the Flask service name through Docker DNS.

The `nginx-status` endpoint is restricted to the Nginx container's loopback environment.

## Important Limitation

The redirect uses the fixed laboratory address:

```text
https://localhost:8443
```

A public deployment would require the correct public hostname and port configuration instead.

---

# 65. GENERATING A SELF-SIGNED CERTIFICATE

Create the certificate directory:

```bash id="ovrnle"
mkdir -p certs
```

Generate a short-lived certificate:

```bash id="7rqx1n"
openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -days 3 \
  -nodes \
  -keyout certs/server.key \
  -out certs/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

Restrict the private key on a Unix-like host:

```bash id="lzspne"
chmod 600 certs/server.key
```

Inspect the certificate:

```bash id="q3fujc"
openssl x509 \
  -in certs/server.crt \
  -noout \
  -subject \
  -dates \
  -ext subjectAltName
```

## Security Considerations

The certificate is self-signed.

It is intended for local training.

Do not use this certificate as a public production credential.

Do not publish `server.key`.

Certificate generation and host file permissions may require different commands on Windows.

---

# 66. PROJECT ENVIRONMENT VARIABLES

Create:

`.env`

Insert:

```text id="c6bp3e"
HTTP_PORT=8088
HTTPS_PORT=8443
APP_TITLE="Production-Inspired Docker Laboratory"
APP_ENV=training
COUNTER_KEY=lecture19:counter
```

## Explanation

`HTTP_PORT` selects the local redirect endpoint.

`HTTPS_PORT` selects the local secure endpoint.

`APP_TITLE` configures the displayed application name.

`APP_ENV` identifies the laboratory environment.

`COUNTER_KEY` selects the Redis key storing persistent counter data.

These variables are non-sensitive.

---

# 67. COMPLETE DOCKER COMPOSE FILE

Create:

`compose.yaml`

Insert:

```yaml id="m2rlyc"
name: lecture19-prod


x-logging: &bounded-logging
  driver: local
  options:
    max-size: "10m"
    max-file: "3"


services:

  redis:
    image: redis:7-alpine

    command:
      - redis-server
      - --appendonly
      - "yes"
      - --appendfsync
      - everysec
      - --dir
      - /data
      - --maxmemory
      - 128mb
      - --maxmemory-policy
      - noeviction

    volumes:
      - redis-data:/data

    networks:
      - backend

    healthcheck:
      test:
        - CMD
        - redis-cli
        - ping
      interval: 5s
      timeout: 3s
      retries: 6
      start_period: 10s

    restart: unless-stopped

    stop_grace_period: 30s

    mem_limit: 256m

    cpus: 0.50

    pids_limit: 80

    logging: *bounded-logging


  web:
    build:
      context: ./web
      dockerfile: Dockerfile

    image: lecture19-web:v1

    environment:
      APP_TITLE: "${APP_TITLE:-Docker Lecture 19}"
      APP_ENV: "${APP_ENV:-training}"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      COUNTER_KEY: "${COUNTER_KEY:-lecture19:counter}"

    depends_on:
      redis:
        condition: service_healthy
        restart: true

    networks:
      - frontend
      - backend

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=2)"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 15s

    user: "10001:10001"

    read_only: true

    tmpfs:
      - /tmp:size=32m

    cap_drop:
      - ALL

    security_opt:
      - no-new-privileges:true

    init: true

    restart: unless-stopped

    stop_grace_period: 30s

    mem_limit: 256m

    cpus: 0.75

    pids_limit: 96

    logging: *bounded-logging


  gateway:
    image: nginx:stable-alpine

    ports:
      - "127.0.0.1:${HTTP_PORT:-8088}:80"
      - "127.0.0.1:${HTTPS_PORT:-8443}:443"

    volumes:
      - ./gateway/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/nginx/certs:ro

    depends_on:
      web:
        condition: service_healthy
        restart: true

    networks:
      - frontend

    healthcheck:
      test:
        - CMD-SHELL
        - "wget -q -O /dev/null http://127.0.0.1/health/edge || exit 1"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s

    restart: unless-stopped

    stop_grace_period: 20s

    mem_limit: 128m

    cpus: 0.50

    pids_limit: 96

    logging: *bounded-logging


networks:

  frontend:
    driver: bridge

  backend:
    driver: bridge
    internal: true


volumes:

  redis-data:
```

---

# 68. COMPOSE CONFIGURATION ANALYSIS

## 68.1 Project Name

The project is named:

```text id="bdle14"
lecture19-prod
```

The Redis volume will therefore ordinarily use a project-scoped name such as:

```text id="tm8xzn"
lecture19-prod_redis-data
```

## 68.2 Logging Extension

The top-level `x-logging` block defines reusable logging configuration.

The YAML anchor:

```text id="xkb7op"
&bounded-logging
```

and aliases reduce repetition.

## 68.3 Redis

Redis uses:

- Append-only persistence.
- A named volume.
- An internal backend network.
- A health check.
- A restart policy.
- Resource limits.
- Bounded logging.

## 68.4 Flask

Flask uses:

- A custom image.
- A non-root identity.
- A read-only root filesystem.
- A writable tmpfs at `/tmp`.
- Dropped Linux capabilities.
- No-new-privileges.
- A health-aware Redis dependency.
- Resource limits.
- A graceful shutdown period.

## 68.5 Nginx

Nginx provides:

- HTTP redirect.
- HTTPS termination.
- Security response headers.
- Reverse proxying.
- Local gateway health monitoring.

## 68.6 Network Segmentation

The frontend network connects Nginx and Flask.

The backend network connects Flask and Redis.

Redis does not publish a host port.

---

# 69. OPTIONAL OPERATIONS OVERRIDE

Create:

`compose.ops.yaml`

Insert:

```yaml id="uqv27x"
services:

  web:
    environment:
      APP_ENV: operations-review

    mem_limit: 384m

    cpus: 1.0
```

## Purpose

This file demonstrates controlled changes to operational configuration.

It is not automatically loaded when using the ordinary `compose.yaml` selection.

It must be selected explicitly through `-f`.

The laboratory will inspect the merged configuration and temporarily apply it.

---

# 70. PROJECT ACCEPTANCE CRITERIA

The application should satisfy the following conditions.

| Requirement | Verification |
|---|---|
| Nginx responds over HTTPS | HTTPS request succeeds |
| Certificate identifies localhost | Subject Alternative Name inspection |
| HTTP redirects to HTTPS | HTTP 308 response |
| Flask operates as non-root | UID inspection |
| Flask root filesystem is read-only | Write attempt fails |
| Temporary storage works | `/tmp` write succeeds |
| Redis is healthy | Redis health check |
| Web readiness depends on Redis | Controlled Redis stop |
| Only Nginx publishes ports | Compose service listing |
| Logs have retention limits | Logging driver inspection |
| Resource limits are configured | Docker inspection |
| Counter survives application recreation | Persistence test |
| Backup archive is produced | Archive inspection |
| Independent restore works | Redis recovery container |
| System can be restored | Final functionality test |

---

# PART V — PRACTICAL LABORATORY 19

# 71. EXPERIMENT 1 — VERIFY THE ENVIRONMENT

Execute:

```bash id="c4wnux"
docker version
```

```bash id="wpgb42"
docker compose version
```

```bash id="ctu91a"
openssl version
```

**Objective:** Confirm Docker, Compose, and OpenSSL availability.

**Required observations:** Record relevant versions and identify the active Docker environment.

---

# 72. EXPERIMENT 2 — CREATE THE PROJECT

For a Unix-like shell:

```bash id="x7nb2e"
mkdir -p docker-lecture19/web/templates
mkdir -p docker-lecture19/web/static
mkdir -p docker-lecture19/gateway
mkdir -p docker-lecture19/certs
mkdir -p docker-lecture19/backups
cd docker-lecture19
```

Create the files provided in Sections 57–69.

**Objective:** Establish a complete reproducible application project.

---

# 73. EXPERIMENT 3 — GENERATE THE TLS CERTIFICATE

Execute the OpenSSL command from Section 65.

Inspect:

```bash id="mfsweb"
openssl x509 \
  -in certs/server.crt \
  -noout \
  -dates \
  -ext subjectAltName
```

**Objective:** Generate and inspect a certificate for localhost.

**Required observations:**

1. Validity start.
2. Expiration date.
3. DNS Subject Alternative Name.
4. IP Subject Alternative Name.

---

# 74. EXPERIMENT 4 — VALIDATE COMPOSE

Execute:

```bash id="q8qn3d"
docker compose config -q
```

Then:

```bash id="7ehf8g"
docker compose config
```

**Objective:** Validate the production-inspired Compose model.

**Required observations:**

Identify:

- Three services.
- Two networks.
- Named volume.
- Resource constraints.
- Restart policies.
- Logging driver.
- Health checks.
- Published ports.

---

# 75. EXPERIMENT 5 — BUILD THE APPLICATION

Execute:

```bash id="e7trz3"
docker compose build web
```

Verify:

```bash id="b5ygnj"
docker image ls lecture19-web
```

**Objective:** Construct the Flask application image.

**Required analysis:** Explain why source code is packaged into the image rather than bind-mounted for this production-inspired deployment.

---

# 76. EXPERIMENT 6 — START THE COMPLETE SYSTEM

Execute:

```bash id="lg6ywk"
docker compose up -d
```

Verify:

```bash id="r1id9n"
docker compose ps
```

**Objective:** Start Redis, Flask, and Nginx.

**Expected behavior:**

Redis becomes healthy.

Flask starts after the applicable Redis health condition is satisfied.

Nginx starts after Flask becomes healthy.

---

# 77. EXPERIMENT 7 — VERIFY THE HTTP REDIRECT

Execute:

```bash id="u6idrc"
curl -I http://localhost:8088/
```

**Objective:** Test the HTTP-to-HTTPS redirect.

**Expected result:**

The response uses HTTP status 308 and provides a Location header pointing to:

```text id="k60pr4"
https://localhost:8443/
```

**Required analysis:** Explain why the redirect is configured at the reverse proxy.

---

# 78. EXPERIMENT 8 — VERIFY THE TLS CONNECTION

Execute:

```bash id="u9elgn"
curl \
  --cacert certs/server.crt \
  https://localhost:8443/
```

**Objective:** Test HTTPS using the generated certificate as an explicitly trusted certificate for this command.

**Expected result:** The application HTML is returned.

**Required analysis:** Explain why the `--cacert` option is appropriate for this controlled self-signed certificate test.

**Important note:** A normal browser may still display a certificate trust warning because the certificate is not in the browser's trusted certificate-authority store.

---

# 79. EXPERIMENT 9 — VERIFY THE TLS CERTIFICATE

Execute:

```bash id="3vay2q"
openssl s_client \
  -connect localhost:8443 \
  -servername localhost \
  </dev/null
```

**Objective:** Inspect the TLS connection and presented certificate.

**Required observations:**

- Server certificate.
- TLS protocol.
- Cipher selection.
- Verification information.

**Required analysis:** Explain why server identity verification is important even when the connection is encrypted.

---

# 80. EXPERIMENT 10 — TEST APPLICATION FUNCTIONALITY

Open:

https://localhost:8443

Use the browser's counter button.

Alternatively:

```bash id="9capwg"
curl \
  --cacert certs/server.crt \
  -X POST \
  https://localhost:8443/api/increment
```

Retrieve:

```bash id="89u4yt"
curl \
  --cacert certs/server.crt \
  https://localhost:8443/api/count
```

**Objective:** Verify the complete HTTPS-to-Redis request path.

**Required analysis:** Trace the request from the HTTP client through Nginx, Flask, and Redis.

---

# 81. EXPERIMENT 11 — VERIFY SECURITY RESPONSE HEADERS

Execute:

```bash id="u6kzv1"
curl \
  --cacert certs/server.crt \
  -I \
  https://localhost:8443/
```

**Objective:** Inspect the security-related response headers.

**Expected observations:**

- Content Security Policy.
- Referrer Policy.
- X-Content-Type-Options.

**Required analysis:** Explain what each header attempts to protect and why headers do not replace secure application logic.

---

# 82. EXPERIMENT 12 — VERIFY NETWORK MEMBERSHIP

Execute:

```bash id="mv38ff"
docker network inspect lecture19-prod_frontend
```

Then:

```bash id="h6p99c"
docker network inspect lecture19-prod_backend
```

**Objective:** Verify segmented network architecture.

**Expected membership:**

| Network | Services |
|---|---|
| frontend | gateway, web |
| backend | web, redis |

**Required analysis:** Explain why Redis does not require direct frontend network membership.

---

# 83. EXPERIMENT 13 — VERIFY PUBLISHED PORTS

Execute:

```bash id="5ytsl0"
docker compose ps
```

**Objective:** Identify externally published endpoints.

**Expected result:**

Only the gateway service publishes host ports.

The Flask and Redis service ports are used internally.

**Required analysis:** Explain why port publishing and internal container service communication are different mechanisms.

---

# 84. EXPERIMENT 14 — EXAMINE HEALTH CHECKS

Execute:

```bash id="dojd3i"
docker compose ps
```

Inspect Redis:

```bash id="bnc32a"
docker inspect \
  "$(docker compose ps -q redis)" \
  --format '{{json .State.Health}}'
```

Inspect Flask:

```bash id="68zu37"
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{json .State.Health}}'
```

**Objective:** Examine service health data.

**Required analysis:** Distinguish healthy, unhealthy, starting, and running states.

---

# 85. EXPERIMENT 15 — VERIFY NON-ROOT EXECUTION

Execute:

```bash id="z9zeqy"
docker compose exec web id
```

**Expected result:** UID and GID 10001.

**Objective:** Verify Flask's runtime identity.

**Required analysis:** Explain why the non-root identity is useful and which security concerns it does not solve.

---

# 86. EXPERIMENT 16 — VERIFY FILESYSTEM HARDENING

Attempt:

```bash id="fz3zfj"
docker compose exec web sh -c 'touch /restricted-test'
```

**Expected result:** The write fails.

Now execute:

```bash id="3lsgng"
docker compose exec web sh -c 'touch /tmp/temporary-test && echo "temporary write successful"'
```

**Expected result:** The temporary write succeeds.

**Objective:** Distinguish root filesystem restrictions from selected writable tmpfs paths.

---

# 87. EXPERIMENT 17 — VERIFY RESOURCE LIMITS

Execute:

```bash id="hzlygv"
docker stats --no-stream
```

Inspect memory:

```bash id="j6t5si"
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{.HostConfig.Memory}}'
```

Inspect process limits:

```bash id="ydov3b"
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{.HostConfig.PidsLimit}}'
```

**Objective:** Verify configured resource controls.

**Required analysis:** Explain why limits must be selected according to realistic workload behavior.

---

# 88. EXPERIMENT 18 — VERIFY LOG RETENTION CONFIGURATION

Execute:

```bash id="aon7cz"
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{json .HostConfig.LogConfig}}'
```

Then:

```bash id="o3f5cl"
docker compose logs --tail 30 web
```

**Objective:** Inspect the local logging driver and its rotation settings.

**Required analysis:** Explain why bounded local logs are useful but not equivalent to centralized logging.

---

# 89. EXPERIMENT 19 — INSPECT NGINX STATUS

Execute:

```bash id="uq0gfj"
docker compose exec gateway \
  wget -q -O - http://127.0.0.1/nginx-status
```

**Objective:** Inspect basic Nginx connection statistics.

**Expected result:** Nginx returns connection and request-related statistics when the status module is available.

**Required analysis:** Explain why gateway statistics do not provide a complete measure of application correctness or database performance.

---

# 90. EXPERIMENT 20 — TEST REDIS DEPENDENCY FAILURE

Stop Redis:

```bash id="c8xt8p"
docker compose stop redis
```

Test liveness:

```bash id="zuxzyd"
curl \
  --cacert certs/server.crt \
  -i \
  https://localhost:8443/health/live
```

Test readiness:

```bash id="0gmqic"
curl \
  --cacert certs/server.crt \
  -i \
  https://localhost:8443/health/ready
```

**Expected result:**

Liveness may continue to return HTTP 200.

Readiness returns HTTP 503.

**Objective:** Demonstrate failure of a required application dependency.

---

# 91. EXPERIMENT 21 — INSPECT HEALTH DURING FAILURE

Execute:

```bash id="51qzod"
docker compose ps
```

Then:

```bash id="pd1xcb"
docker compose logs --timestamps --tail 30 web
```

Then:

```bash id="b40to0"
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{json .State.Health}}'
```

**Objective:** Correlate application errors with health-check results.

**Required analysis:** Explain why the container's runtime restart policy does not necessarily restart it while the Gunicorn process remains alive.

---

# 92. EXPERIMENT 22 — RESTORE REDIS

Execute:

```bash id="hnfqj3"
docker compose start redis
```

Verify:

```bash id="b0onb2"
docker compose exec redis redis-cli PING
```

Then:

```bash id="pm4cvb"
curl \
  --cacert certs/server.crt \
  -i \
  https://localhost:8443/health/ready
```

**Objective:** Verify recovery after the Redis service becomes available.

**Expected result:** The readiness endpoint returns HTTP 200 after successful recovery.

---

# 93. EXPERIMENT 23 — TEST A RUNTIME RESTART POLICY

Record the current Flask container identifier:

```bash id="bmhhp7"
docker compose ps -q web
```

Simulate abrupt termination of the web container's principal process:

```bash id="ylqh0y"
docker compose kill web
```

Inspect:

```bash id="nuffub"
docker compose ps
```

**Objective:** Investigate the effect of the `unless-stopped` restart policy.

**Expected behavior:** Docker ordinarily restarts the eligible container after the forced process termination.

**Required analysis:** Explain the difference between automatic recovery from process termination and failure of an application readiness check.

---

# 94. EXPERIMENT 24 — INSPECT THE OPERATIONS OVERRIDE

Execute:

```bash id="p4ixbt"
docker compose \
  -f compose.yaml \
  -f compose.ops.yaml \
  config
```

**Objective:** Examine a production-oriented configuration override.

**Expected observations:**

The web service receives:

```text id="k8ejvk"
APP_ENV=operations-review
```

Its memory and CPU settings are modified.

**Required analysis:** Explain why the effective merged configuration should be reviewed before deployment.

---

# 95. EXPERIMENT 25 — APPLY AND REVERT THE OVERRIDE

Apply:

```bash id="ak29p4"
docker compose \
  -f compose.yaml \
  -f compose.ops.yaml \
  up -d
```

Inspect the merged runtime configuration.

Then restore the base model:

```bash id="upxigc"
docker compose up -d
```

**Objective:** Demonstrate controlled deployment configuration changes.

**Required analysis:** Explain why Compose may recreate the web container when its effective environment or resource settings change.

---

# 96. EXPERIMENT 26 — VERIFY DATA PERSISTENCE

Retrieve the current counter:

```bash id="e8hmqg"
docker compose exec redis redis-cli GET lecture19:counter
```

Record the value.

Recreate the web container:

```bash id="87b3ha"
docker compose up -d --force-recreate web
```

Verify the Redis data remains available.

**Objective:** Demonstrate independence between Flask container replacement and Redis persistent state.

---

# 97. EXPERIMENT 27 — PREPARE A CONSISTENT BACKUP

First verify that Redis is available.

Execute:

```bash id="gh3vai"
docker compose exec redis redis-cli PING
```

Record the counter:

```bash id="z11hxx"
docker compose exec redis redis-cli GET lecture19:counter
```

Request a snapshot:

```bash id="c678y4"
docker compose exec redis redis-cli SAVE
```

Now stop and remove the application containers while retaining the named volume:

```bash id="vvsdcu"
docker compose down
```

**Objective:** Establish a stable Redis dataset for filesystem backup.

**Required analysis:** Explain why this laboratory backup involves downtime and why it is different from an online database backup procedure.

---

# 98. EXPERIMENT 28 — CREATE AND INSPECT THE BACKUP ARCHIVE

Create the host backup directory if it does not exist:

```bash id="b0qo5q"
mkdir -p backups
```

Archive the stopped Redis volume:

```bash id="5hzhjd"
docker run --rm \
  --mount type=volume,source=lecture19-prod_redis-data,target=/source,readonly \
  --mount type=bind,source="$(pwd)/backups",target=/backup \
  alpine:3.20 \
  sh -c 'tar -czf /backup/redis-data.tar.gz -C /source .'
```

List the archive contents:

```bash id="oqhggu"
docker run --rm \
  --mount type=bind,source="$(pwd)/backups",target=/backup,readonly \
  alpine:3.20 \
  tar -tzf /backup/redis-data.tar.gz
```

**Objective:** Create and inspect a consistent filesystem archive.

**Required analysis:** Explain why listing the archive contents is useful but does not independently prove successful database recovery.

---

# 99. EXPERIMENT 29 — RESTORE INTO AN INDEPENDENT VOLUME

Create a separate restoration volume:

```bash id="xwx61l"
docker volume create lecture19-restore
```

Restore the archive:

```bash id="99ziw2"
docker run --rm \
  --mount type=bind,source="$(pwd)/backups",target=/backup,readonly \
  --mount type=volume,source=lecture19-restore,target=/restore \
  alpine:3.20 \
  sh -c 'tar -xzf /backup/redis-data.tar.gz -C /restore'
```

**Objective:** Restore the database files without overwriting the original volume.

**Required analysis:** Explain why independent restoration is valuable for safe recovery testing.

---

# 100. EXPERIMENT 30 — VERIFY DATABASE RECOVERY

Start a recovery container using the restored volume:

```bash id="a7hrhi"
docker run -d \
  --name lecture19-restore-check \
  --network none \
  --mount type=volume,source=lecture19-restore,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes --dir /data
```

Verify the recovered counter:

```bash id="jnzvsx"
docker exec lecture19-restore-check \
  redis-cli GET lecture19:counter
```

**Expected result:** The value matches the counter recorded before backup.

**Objective:** Demonstrate successful database recovery from the archive.

**Required analysis:** Explain why this is stronger evidence than merely verifying that the archive file exists.

---

# 101. EXPERIMENT 31 — RESTORE NORMAL OPERATIONS

Stop and remove the recovery container:

```bash id="d8kw0p"
docker stop lecture19-restore-check
```

```bash id="83rqxh"
docker rm lecture19-restore-check
```

Restart the original Compose application:

```bash id="8qno4s"
docker compose up -d
```

Verify:

```bash id="kann2c"
docker compose ps
```

Then:

```bash id="vxrmcp"
curl \
  --cacert certs/server.crt \
  https://localhost:8443/health/ready
```

**Objective:** Return the original application to service.

**Expected result:** Flask and Redis operate normally using the original named volume.

---

# 102. EXPERIMENT 32 — FINAL OPERATIONAL READINESS REVIEW

Inspect:

```bash id="0vjpkc"
docker compose ps
```

```bash id="qfrppv"
docker compose logs --tail 30
```

```bash id="gbrg50"
docker stats --no-stream
```

```bash id="ov3zq2"
docker volume inspect lecture19-prod_redis-data
```

```bash id="pp2s4r"
docker network inspect lecture19-prod_backend
```

Verify HTTPS:

```bash id="z9c8el"
curl \
  --cacert certs/server.crt \
  https://localhost:8443/api/count
```

**Objective:** Confirm the complete application's operational state.

**Required conclusion:** The system is functioning with the intended HTTPS, health, networking, logging, resource, and persistence configuration.

---

# 103. EXPERIMENT 33 — CONTROLLED CLEANUP

Remove the application without deleting its persistent volume:

```bash id="45h8h0"
docker compose down
```

Inspect:

```bash id="88ezlr"
docker volume ls
```

The original and restored Redis volumes remain available.

The host backup archive also remains in the `backups` directory.

**Optional destructive cleanup:**

Only if all laboratory data is no longer needed, remove the two training volumes:

```bash id="0y5zir"
docker volume rm lecture19-prod_redis-data
```

```bash id="anv2j1"
docker volume rm lecture19-restore
```

**Critical warning:** These commands permanently remove the specified stored datasets.

Do not delete the host backup archive or TLS private key until you have confirmed that they are no longer needed for further study.

---

# PART VI — LABORATORY ANALYSIS

# 104. LABORATORY OBSERVATION TABLE

Complete the following table.

| Experiment | Operational objective | Recorded result |
|---|---|---|
| 1 | Environment verification | |
| 2 | Project construction | |
| 3 | Certificate generation | |
| 4 | Compose validation | |
| 5 | Application image build | |
| 6 | Service startup | |
| 7 | HTTP redirect | |
| 8 | HTTPS request | |
| 9 | TLS certificate inspection | |
| 10 | Counter functionality | |
| 11 | Security headers | |
| 12 | Network separation | |
| 13 | Published ports | |
| 14 | Health-check inspection | |
| 15 | Non-root execution | |
| 16 | Filesystem hardening | |
| 17 | Resource limits | |
| 18 | Bounded logging | |
| 19 | Nginx status | |
| 20 | Redis failure | |
| 21 | Failure monitoring | |
| 22 | Redis recovery | |
| 23 | Restart policy | |
| 24 | Compose override | |
| 25 | Configuration reconciliation | |
| 26 | Data persistence | |
| 27 | Backup preparation | |
| 28 | Backup archive | |
| 29 | Independent restoration | |
| 30 | Recovery verification | |
| 31 | Service restoration | |
| 32 | Operational readiness | |
| 33 | Controlled cleanup | |

---

# 105. LABORATORY CONCLUSION

Prepare a formal technical conclusion of approximately 400–600 words addressing:

1. Why a functioning application is not necessarily production-ready.
2. What HTTPS protects.
3. Why self-signed certificates are insufficient for ordinary public deployment.
4. How health-aware dependencies improve startup.
5. Why restart policies do not solve every application failure.
6. How resource limits influence system operation.
7. What bounded logging provides.
8. Why local logs do not replace centralized observability.
9. Why a read-only filesystem may still need temporary writable storage.
10. Why a named volume does not constitute a complete backup.
11. How consistent backup and restoration were verified.
12. What limitations remain in the single-host Compose architecture.

---

# PART VII — PRODUCTION OPERATIONAL PROCEDURES

# 106. DEPLOYMENT RUNBOOK

A basic deployment runbook may include:

**Step 1:** Verify the intended image version.

**Step 2:** Validate the Compose model.

```bash
docker compose config -q
```

**Step 3:** Verify required configuration and secrets.

**Step 4:** Verify TLS certificates are available.

**Step 5:** Verify persistent storage requirements.

**Step 6:** Deploy or reconcile the application.

```bash
docker compose up -d
```

**Step 7:** Check service status.

```bash
docker compose ps
```

**Step 8:** Verify application readiness.

**Step 9:** Perform a representative functional request.

**Step 10:** Record the deployed version and operational results.

## Production Qualification

A genuine production deployment would ordinarily use approved registry images and controlled image references rather than depending on rebuilding application source code on the deployment host.

---

# 107. APPLICATION RESTART RUNBOOK

When a container process requires a controlled restart:

1. Identify the affected service.
2. Inspect the current state.
3. Collect relevant logs.
4. Determine whether a restart is appropriate.
5. Restart the selected service.
6. Verify readiness.
7. Confirm expected functionality.
8. Record the action.

Example:

```bash
docker compose restart web
```

## Important Limitation

Restarting an existing container does not automatically apply changed environment variables, mounts, or image content.

Configuration changes may require recreation.

---

# 108. DATABASE FAILURE RUNBOOK

When Redis becomes unavailable:

1. Confirm the reported symptom.
2. Inspect Redis container state.
3. Retrieve Redis logs.
4. Check health-check output.
5. Inspect storage and network configuration.
6. Determine whether the process or host is failing.
7. Restore service safely.
8. Verify the counter data.
9. Confirm Flask readiness.
10. Document the incident.

Avoid deleting the Redis volume to solve an unidentified startup problem.

---

# 109. BACKUP RUNBOOK

A backup runbook should define:

1. Dataset to protect.
2. Backup method.
3. Backup schedule.
4. Consistency requirements.
5. Backup destination.
6. Access controls.
7. Encryption requirements.
8. Retention policy.
9. Verification procedure.
10. Restoration procedure.
11. Recovery objectives.
12. Responsible operator.

The laboratory demonstrates one manually executed consistent backup.

A production workflow would require automation and ongoing verification.

---

# 110. CERTIFICATE RENEWAL RUNBOOK

Certificate management should document:

1. Certificate location.
2. Private-key location.
3. Certificate authority.
4. Certificate expiration.
5. Renewal method.
6. Deployment or reload procedure.
7. Post-renewal validation.
8. Failure recovery.

A service can become unavailable or produce browser security errors when its certificate expires.

Certificate expiration should be monitored before the deadline.

---

# 111. DEPLOYMENT ROLLBACK RUNBOOK

A rollback procedure should identify:

1. The previous approved image digest.
2. The current release version.
3. Database migration compatibility.
4. Configuration compatibility.
5. Expected downtime.
6. Validation steps.
7. Recovery alternatives.

## Important Principle

Application image rollback does not automatically reverse changes made to a persistent database.

This issue becomes especially important when deploying schema migrations.

---

# PART VIII — PRODUCTION TROUBLESHOOTING

# 112. TLS CERTIFICATE FAILURE

## Symptoms

- Browser trust warning.
- Certificate expired.
- Hostname mismatch.
- TLS handshake failure.

## Investigation

Inspect the certificate:

```bash
openssl x509 -in certs/server.crt -noout -dates -subject
```

Examine:

- Subject Alternative Names.
- Validity period.
- Certificate chain.
- Private-key configuration.
- Nginx logs.

## Corrective Principle

Fix certificate identity and trust configuration rather than suppressing certificate verification in a public deployment.

---

# 113. NGINX FAILS TO START

Possible causes include:

- Missing certificate.
- Missing private key.
- Incorrect file permissions.
- Invalid Nginx syntax.
- Occupied host port.
- Invalid configuration mount.

## Investigation

```bash
docker compose logs gateway
```

Validate configuration when the container can execute the command:

```bash
docker compose exec gateway nginx -t
```

## Corrective Principle

Differentiate configuration syntax errors from filesystem access and network binding errors.

---

# 114. FLASK FAILS UNDER READ-ONLY ROOT

Possible causes include:

- Application writing to its source directory.
- Temporary files created outside `/tmp`.
- Unexpected runtime cache directories.
- Incorrect Gunicorn temporary directory.
- Missing write permissions on intended writable mounts.

## Corrective Principle

Identify required write locations.

Provide minimum necessary writable mounts rather than making the entire root filesystem writable.

---

# 115. CONTAINER IS UNHEALTHY

A container may remain running while reporting unhealthy.

Investigate:

1. Principal process status.
2. Health-check command.
3. Dependency availability.
4. Check timeout.
5. Startup grace period.
6. Recent health-check output.

## Important Principle

Health classification is diagnostic information.

It does not automatically guarantee remedial action.

---

# 116. RESTART LOOP

A container may repeatedly terminate and restart.

Possible causes include:

- Invalid startup command.
- Missing runtime dependency.
- Configuration error.
- Permission problem.
- Resource exhaustion.
- Application exception.

## Investigation

Use:

```bash
docker compose ps -a
```

and:

```bash
docker compose logs --tail 50
```

Inspect exit codes and resource limits.

Repeated restarts are symptoms that require diagnosis.

---

# 117. REDIS MEMORY FAILURE

The configured Redis memory limit may prevent further writes under selected conditions.

Possible symptoms include application database errors.

## Investigation

Inspect:

```bash
docker compose exec redis redis-cli INFO memory
```

Review Redis logs and application error responses.

## Corrective Principle

Memory planning must consider actual dataset size, Redis overhead, persistence activity, and expected workload growth.

---

# 118. BACKUP FAILURE

Potential problems include:

- Insufficient storage.
- Wrong source volume.
- Missing archive file.
- Inconsistent database files.
- Restore permission problems.
- Wrong Redis version.
- Incorrect restoration path.

## Corrective Principle

A backup should be evaluated through actual recovery testing.

Do not assume that the existence of an archive guarantees recoverability.

---

# 119. HOST FAILURE

A single-host Compose deployment may become unavailable if the host fails.

Container restart policies cannot restore service on infrastructure that is no longer functioning.

## Possible Recovery Requirements

- Replacement host.
- Docker installation.
- Access to image artifacts.
- Compose configuration.
- Secrets and certificates.
- Restored persistent data.
- Correct network configuration.

## Architectural Conclusion

Host-level high availability requires additional infrastructure beyond a basic single-host Compose deployment.

---

# PART IX — PRODUCTION READINESS ASSESSMENT

# 120. PRODUCTION READINESS MATRIX

| Category | Laboratory implementation | Production requirement |
|---|---|---|
| HTTP application | Flask and Gunicorn | Tested application release |
| HTTPS | Self-signed localhost certificate | Trusted certificate and renewal |
| Gateway | Nginx | Appropriate public exposure and hardened configuration |
| Runtime identity | Non-root Flask | Least privilege throughout |
| Filesystem | Read-only Flask root | Tested writable-path policy |
| Networking | Segmented Docker networks | Verified production network controls |
| Redis | Internal, unauthenticated training service | Appropriate authentication, access control, and protection |
| Storage | Named Docker volume | Durable storage aligned with recovery requirements |
| Backup | Local manual archive | Automated, protected, independent backups |
| Restoration | Tested separate volume | Tested operational recovery plan |
| Monitoring | CLI logs and health checks | Centralized metrics, logs, and alerting |
| Restart | Docker restart policies | Broader availability and failure-domain planning |
| Resource constraints | Explicit limits | Capacity-tested limits |
| Image distribution | Locally built image | Approved registry artifact and digest |
| Deployment | Manual Compose workflow | Controlled release process |
| Availability | Single Docker host | Architecture matching required SLO |
| Incident response | Educational runbook | Maintained operational runbooks and escalation |

## Interpretation

The laboratory demonstrates valuable production engineering practices.

It does not satisfy every requirement of a publicly exposed production service.

The missing controls should be treated as explicit architectural requirements rather than ignored limitations.

---

# 121. COMMON CONCEPTUAL MISUNDERSTANDINGS

**Misunderstanding 1:** An application is production-ready because `docker compose up -d` succeeds.

Incorrect. Successful startup is only one operational condition.

**Misunderstanding 2:** A restart policy guarantees high availability.

Incorrect. It cannot independently recover a failed host or unavailable persistent storage.

**Misunderstanding 3:** An unhealthy container is always restarted automatically.

Incorrect. Docker health status and runtime restart behavior are distinct.

**Misunderstanding 4:** A successful health check proves every application function works.

Incorrect. It evaluates only the configured condition.

**Misunderstanding 5:** TLS termination automatically encrypts all internal application traffic.

Incorrect. Internal connections require separate protection where appropriate.

**Misunderstanding 6:** A self-signed certificate provides ordinary public browser trust.

Incorrect. It must be explicitly trusted by the client or replaced with a suitable trusted certificate.

**Misunderstanding 7:** A named Docker volume is a complete backup solution.

Incorrect. It is active storage.

**Misunderstanding 8:** A backup archive is verified merely because it exists.

Incorrect. Restoration and data checks are necessary.

**Misunderstanding 9:** Local log rotation constitutes comprehensive observability.

Incorrect. Metrics, trace information, centralized retention, and alerting may still be required.

**Misunderstanding 10:** A small memory limit always improves reliability.

Incorrect. Limits below real application requirements may cause failures.

**Misunderstanding 11:** Three containers on one Docker host create a highly available system.

Incorrect. The host remains a shared failure domain.

**Misunderstanding 12:** Application image rollback also restores database state.

Incorrect. State recovery requires a separate strategy.

---

# PART X — ACADEMIC GLOSSARY

# 122. TECHNICAL TERMINOLOGY

| Term | Definition |
|---|---|
| Production deployment | Operating environment intended to provide a required live service |
| Operational readiness | Preparedness for ongoing maintenance, monitoring, and recovery |
| Reliability | Ability to perform correctly over a defined period |
| Availability | Accessibility of a service when required |
| Resilience | Ability to withstand and recover from disruption |
| SLI | Service-Level Indicator |
| SLO | Service-Level Objective |
| SLA | Service-Level Agreement |
| Error budget | Permitted failure allowance under a defined reliability objective |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| Failure domain | Component or infrastructure grouping that may fail together |
| Stateless service | Service not relying on persistent local process state as authoritative state |
| Stateful service | Service maintaining data requiring persistence or coordinated recovery |
| Immutable image | Approved image artifact treated as fixed content |
| Release promotion | Movement of approved software artifacts through deployment stages |
| Rollback | Return to a previous approved application version |
| Health check | Test evaluating a selected operational condition |
| Liveness | Basic process responsiveness |
| Readiness | Ability to perform selected required work |
| Restart policy | Runtime configuration controlling eligible container restarts |
| Graceful shutdown | Controlled process termination |
| Cgroups | Linux resource-control mechanisms |
| OOM | Out of Memory |
| CPU quota | CPU scheduling constraint |
| PIDs limit | Process and thread count restriction |
| Logging driver | Mechanism handling container output |
| Log rotation | Controlled replacement of retained log segments |
| Observability | Understanding system behavior through operational signals |
| Metric | Quantitative operational measurement |
| Trace | Record of an operation's flow across components |
| Alert | Notification about a selected condition |
| TLS | Transport Layer Security |
| HTTPS | HTTP over TLS |
| TLS termination | Processing of TLS connections at a gateway or proxy |
| Certificate | Signed data associating identity information with a public key |
| Private key | Confidential cryptographic key |
| Self-signed certificate | Certificate signed by its own associated private key |
| Subject Alternative Name | Certificate extension identifying valid service identities |
| HSTS | HTTP Strict Transport Security |
| CSP | Content Security Policy |
| Reverse proxy | Server forwarding client requests to backend services |
| Internal network | Docker network configured without ordinary external routing |
| Named volume | Docker-managed storage with a stable identifier |
| AOF | Redis append-only persistence |
| Backup | Independent recoverable copy of data |
| Restore | Reconstruction of data from backup |
| Disaster recovery | Recovery of required systems after major disruption |
| Runbook | Documented operational procedure |
| Incident response | Organized process for addressing operational or security incidents |

---

# PART XI — FORMAL ACADEMIC ASSESSMENT

# 123. PART A — TECHNICAL DEFINITIONS

Provide academically precise definitions for:

1. Production deployment.
2. Reliability.
3. Availability.
4. Resilience.
5. Service-Level Indicator.
6. Service-Level Objective.
7. Recovery Point Objective.
8. Recovery Time Objective.
9. Failure domain.
10. Immutable release.
11. Restart policy.
12. Graceful shutdown.
13. TLS termination.
14. Observability.
15. Consistent backup.

---

# 124. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why functional correctness does not guarantee operational readiness.

**Question 2.**

Distinguish reliability from availability.

**Question 3.**

Explain the purpose of an SLO.

**Question 4.**

Distinguish RPO from RTO.

**Question 5.**

Explain why a single-host Docker Compose deployment is not automatically highly available.

**Question 6.**

Describe the difference between liveness and readiness.

**Question 7.**

Explain why an unhealthy container may remain running.

**Question 8.**

Describe the purpose of restart policies.

**Question 9.**

Explain graceful shutdown.

**Question 10.**

Describe why resource limits must reflect application requirements.

**Question 11.**

Explain the purpose of bounded local logging.

**Question 12.**

Distinguish logs, metrics, and traces.

**Question 13.**

Describe the purpose of TLS termination.

**Question 14.**

Explain why a self-signed certificate is unsuitable for ordinary public deployment without explicit trust configuration.

**Question 15.**

Explain why a successful database backup must be followed by restoration testing.

---

# 125. PART C — CONFIGURATION INTERPRETATION

Consider:

```yaml
restart: unless-stopped
```

Answer:

1. What behavior is requested?
2. Does this guarantee host-failure recovery?
3. Does this automatically restart every unhealthy container?

Consider:

```yaml
read_only: true

tmpfs:
  - /tmp:size=32m
```

Answer:

4. Which filesystem restriction is applied?
5. Why can `/tmp` remain writable?
6. Why might the application require it?

Consider:

```yaml
logging:
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
```

Answer:

7. Which logging driver is selected?
8. What do the rotation options control?
9. Does this provide off-host log retention?

Consider:

```yaml
networks:
  backend:
    internal: true
```

Answer:

10. What network behavior is requested?
11. Why is this useful for database services?
12. Why does it not replace database authentication?

---

# 126. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Unhealthy but Running

Flask remains running.

Redis has stopped.

The readiness endpoint returns HTTP 503.

Explain why Docker's restart policy may not restart Flask.

Recommend an appropriate operational response.

## Case Study 2 — Expired TLS Certificate

Nginx is running and Flask is healthy.

Browser clients reject the HTTPS certificate.

Explain why process health does not imply trusted HTTPS availability.

Recommend a certificate-management procedure.

## Case Study 3 — Memory Constraint

A Python application is configured with a very low memory limit.

It repeatedly exits under moderate traffic.

Explain the probable operational consequences.

Describe how to investigate the resource configuration.

## Case Study 4 — Single-Host Failure

A Docker host fails.

All three application containers become unavailable.

Explain why individual container restart policies cannot restore the application without a functioning host.

Discuss additional availability requirements.

## Case Study 5 — Volume Loss

An administrator removes the only Redis volume.

No independent backup exists.

Explain why the volume's previous persistence properties do not solve the recovery problem.

## Case Study 6 — Backup Restoration Failure

A database archive exists.

Redis cannot read the restored files.

Explain why backup creation and backup verification are different tasks.

Develop an investigation procedure.

---

# 127. PRACTICAL EXAMINATION

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Production engineering theory | 15 |
| HTTPS and certificate configuration | 15 |
| Health monitoring and restart behavior | 15 |
| Resource limits and logging | 15 |
| Security and network segmentation | 10 |
| Persistent storage and backup | 15 |
| Restoration and recovery verification | 10 |
| Technical documentation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student must demonstrate that the application is functional and that the required operational controls have been verified.

A successful backup command without an actual restoration test does not receive full recovery-related marks.

---

# 128. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Production Readiness Engineering for Docker Compose Applications

Prepare an academic report of approximately 1,600–2,200 words addressing:

**“Operational Reliability, Transport Security, Resource Isolation, Observability, and Data Protection in Docker-Based Production Systems.”**

The report must include:

1. Introduction to production engineering.
2. Functional correctness versus operational readiness.
3. Reliability and availability.
4. Service-level indicators and objectives.
5. Recovery Point Objective.
6. Recovery Time Objective.
7. Single-host failure domains.
8. Docker Compose in production.
9. Application health monitoring.
10. Restart policies.
11. Graceful shutdown.
12. Resource constraints.
13. Container logging.
14. Observability.
15. Network segmentation.
16. HTTPS and TLS.
17. Certificate trust and renewal.
18. Non-root execution.
19. Read-only filesystem configuration.
20. Persistent Redis data.
21. Database backup consistency.
22. Independent restoration testing.
23. Operational runbooks.
24. Production readiness assessment.
25. Technical conclusion.

The report should include:

- An architectural diagram.
- An operational readiness table.
- A resource-management table.
- A TLS architecture diagram.
- A backup-and-restoration diagram.
- Evidence from the completed laboratory.

---

# 129. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 20, verify the following competencies.

## Production Fundamentals

- [ ] I can define production deployment.
- [ ] I understand operational readiness.
- [ ] I can distinguish reliability and availability.
- [ ] I understand resilience.
- [ ] I can define SLI and SLO.
- [ ] I can define RPO and RTO.
- [ ] I understand single-host failure domains.

## Docker Operations

- [ ] I can configure health checks.
- [ ] I can explain liveness and readiness.
- [ ] I can configure service dependencies.
- [ ] I understand Docker restart policies.
- [ ] I understand dependency restart propagation.
- [ ] I can configure shutdown grace periods.
- [ ] I can distinguish container restart from recreation.

## Resource Management

- [ ] I can configure memory limits.
- [ ] I can configure CPU limits.
- [ ] I can configure process limits.
- [ ] I can inspect resource usage.
- [ ] I can investigate possible OOM conditions.
- [ ] I understand that resource limits require capacity planning.

## Observability

- [ ] I can retrieve container logs.
- [ ] I can configure bounded logging.
- [ ] I understand Docker's local logging driver.
- [ ] I can distinguish logs and metrics.
- [ ] I can explain traces.
- [ ] I understand the need for alerting.
- [ ] I understand the limitations of local-only monitoring.

## HTTPS

- [ ] I can describe TLS.
- [ ] I can distinguish HTTPS and HTTP.
- [ ] I understand TLS termination.
- [ ] I can generate a self-signed certificate.
- [ ] I can inspect certificate expiration.
- [ ] I can inspect Subject Alternative Names.
- [ ] I can configure Nginx TLS.
- [ ] I can test HTTPS with explicit certificate trust.
- [ ] I understand why public production requires trusted certificates.
- [ ] I understand the importance of certificate renewal.

## Security

- [ ] I can configure non-root execution.
- [ ] I can configure read-only root filesystems.
- [ ] I can configure tmpfs.
- [ ] I can drop unnecessary capabilities.
- [ ] I can apply no-new-privileges.
- [ ] I can explain network segmentation.
- [ ] I understand why internal networks do not replace authentication.

## Data Protection

- [ ] I can configure Redis persistence.
- [ ] I can inspect a named volume.
- [ ] I can explain the difference between persistence and backup.
- [ ] I can explain backup consistency.
- [ ] I can create a Redis data archive.
- [ ] I can inspect the archive.
- [ ] I can restore it into a separate volume.
- [ ] I can start Redis using the restored files.
- [ ] I can verify recovered application data.
- [ ] I understand the limitations of same-host backups.

## Practical Laboratory

- [ ] I constructed the complete application.
- [ ] I generated the training certificate.
- [ ] I validated Compose configuration.
- [ ] I built the Flask image.
- [ ] I started all three services.
- [ ] I verified HTTP-to-HTTPS redirection.
- [ ] I verified HTTPS functionality.
- [ ] I inspected security response headers.
- [ ] I verified network membership.
- [ ] I inspected health checks.
- [ ] I verified non-root execution.
- [ ] I tested filesystem restrictions.
- [ ] I inspected resource limits.
- [ ] I verified bounded logging.
- [ ] I tested Redis failure.
- [ ] I verified application recovery.
- [ ] I examined restart policy behavior.
- [ ] I inspected a Compose override.
- [ ] I verified counter persistence.
- [ ] I created a consistent backup.
- [ ] I restored the backup.
- [ ] I verified recovered Redis data.
- [ ] I restored the original service.
- [ ] I completed the final readiness review.
- [ ] I prepared the academic report.

**Completion standard:**

The student should be capable of constructing a production-inspired multi-container Docker application, verifying its operational controls, diagnosing selected failures, protecting persistent data, and evaluating the remaining requirements for responsible production deployment.

---

# 130. LECTURE SUMMARY

Lecture 19 examines the transition from functioning Docker applications to operationally managed services.

Production readiness requires more than correct application responses.

A dependable system must address service reliability, availability, resource capacity, transport security, observability, persistent storage, recovery, and maintenance.

Service-level indicators and objectives provide mechanisms for expressing measurable reliability expectations.

Recovery Point Objective and Recovery Time Objective define important data-loss and service-restoration requirements.

Docker Compose provides useful single-host operational capabilities, including health checks, dependency coordination, restart policies, networks, and resource configuration.

However, these capabilities do not automatically provide multi-host high availability.

Health checks evaluate selected application conditions.

Restart policies address eligible container termination events.

Graceful shutdown allows applications to terminate with greater control.

Resource limits constrain CPU, memory, and process usage.

Bounded logging helps prevent uncontrolled local log growth.

Observability requires appropriate operational signals and collection processes.

Nginx can terminate HTTPS connections and forward requests to internal application services.

TLS protects the client-to-gateway connection, but internal communication requires separate consideration.

Named volumes preserve Redis data across ordinary container lifecycle operations.

Redis persistence writes recoverable state to the mounted volume.

Backups protect data through independent recoverable copies.

The laboratory verifies backup recovery by restoring an archive into a new volume and starting Redis with the restored files.

The most important operational conclusion is that **a production service must be designed not only to function when everything is working, but also to be observable, maintainable, and recoverable when components fail**.

---

# 131. REFERENCES AND RECOMMENDED READING

## Docker Compose Production Operations

[1] Docker Inc. *Use Compose in Production.*  
https://docs.docker.com/compose/how-tos/production/

[2] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[3] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[4] Docker Inc. *Merge Compose Files.*  
https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/

[5] Docker Inc. *Compose Deploy Specification.*  
https://docs.docker.com/reference/compose-file/deploy/

## Runtime Resources and Logging

[6] Docker Inc. *Resource Constraints.*  
https://docs.docker.com/engine/containers/resource_constraints/

[7] Docker Inc. *Local File Logging Driver.*  
https://docs.docker.com/engine/logging/drivers/local/

[8] Docker Inc. *Configure Logging Drivers.*  
https://docs.docker.com/engine/logging/configure/

[9] Docker Inc. *Docker Container Stats.*  
https://docs.docker.com/reference/cli/docker/container/stats/

[10] Docker Inc. *Docker Inspect.*  
https://docs.docker.com/reference/cli/docker/inspect/

## Networking and HTTPS

[11] Docker Inc. *Networking in Compose.*  
https://docs.docker.com/compose/how-tos/networking/

[12] NGINX. *Configuring HTTPS Servers.*  
https://nginx.org/en/docs/http/configuring_https_servers.html

[13] NGINX. *Reverse Proxy Documentation.*  
https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

[14] NGINX. *ngx_http_stub_status_module.*  
https://nginx.org/en/docs/http/ngx_http_stub_status_module.html

[15] OpenSSL. *OpenSSL Documentation.*  
https://docs.openssl.org/

## Storage and Backup

[16] Docker Inc. *Docker Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[17] Docker Inc. *Compose Volumes Reference.*  
https://docs.docker.com/reference/compose-file/volumes/

[18] Redis. *Redis Persistence.*  
https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

[19] Redis. *Redis Configuration.*  
https://redis.io/docs/latest/operate/oss_and_stack/management/config/

## Application Operations

[20] Flask. *Flask Documentation.*  
https://flask.palletsprojects.com/

[21] Gunicorn. *Gunicorn Documentation.*  
https://docs.gunicorn.org/

[22] Google. *Site Reliability Engineering.*  
https://sre.google/books/

[23] OpenTelemetry. *Observability Documentation.*  
https://opentelemetry.io/docs/

## Recommended Reading Sequence

Begin with references [1] through [5] to develop an understanding of Docker Compose operations in production.

Continue with references [6] through [10] to study resource management and logging.

References [11] through [15] provide the networking and TLS concepts required for secure HTTP deployment.

References [16] through [19] explain storage persistence and database recovery.

Finally, references [20] through [23] connect the practical application architecture with wider production operations and site reliability engineering concepts.

---

# 132. FINAL LECTURE CONCLUSION

Docker production engineering requires the integration of application design and infrastructure operations.

An application must be constructed, configured, secured, monitored, maintained, and recoverable.

No individual Docker setting provides all these qualities.

A restart policy can restore eligible terminated containers, but it cannot repair every dependency failure or recover an unavailable host.

A health check can reveal selected application problems, but it does not guarantee automatic remediation.

Resource limits can constrain excessive resource consumption, but poorly selected limits may reduce availability.

A named volume can preserve data across container replacement, but it does not provide independent backup.

HTTPS can protect client-to-proxy communication, but it does not automatically encrypt every internal service connection.

A valid image release can be deployed consistently, but application rollback may still require compatible database and infrastructure state.

The practical laboratory demonstrates a coordinated operational architecture built from Nginx, Flask, and Redis.

Nginx terminates HTTPS connections using a short-lived local training certificate.

Flask executes under a non-root identity with a read-only root filesystem and selected writable temporary storage.

Redis maintains persistent counter data through a named volume.

Compose provides networking, resource constraints, bounded logging, startup dependencies, and restart policies.

The system's behavior is evaluated through controlled dependency failures, resource inspection, health checks, and operational verification.

Finally, the database is backed up and independently restored to demonstrate recoverability.

These practices establish an important engineering foundation for operating containerized applications.

However, a genuine production deployment may also require trusted certificate automation, database authentication, independent backup infrastructure, monitoring and alerting, approved image digests, release automation, and multi-host availability planning.

The next lecture introduces automation of the software delivery process.

Lecture 20 will demonstrate how GitHub Actions can build, test, scan, tag, and publish Docker images through a repeatable CI/CD pipeline.

---

**END OF LECTURE 19**

**Next Lecture:** Lecture 20 — Docker Continuous Integration and Continuous Deployment: GitHub Actions, Automated Testing, Image Builds, Registry Authentication, Docker Hub Publication, Release Tagging, and Deployment Automation.
