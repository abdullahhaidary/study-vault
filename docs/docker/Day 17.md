# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 17 — DOCKER TROUBLESHOOTING AND OPERATIONAL DIAGNOSTICS: CONTAINER LOGS, EXIT CODES, RESOURCE MONITORING, NETWORK FAILURES, STORAGE PROBLEMS, EVENTS, AND SYSTEMATIC ROOT-CAUSE ANALYSIS

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 17 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 6–8 hours  
**Lecture Type:** Formal Theory, Operational Laboratory, Failure Analysis, and Academic Examination

**Prerequisites:**

- Lecture 01 — Docker Architecture and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Runtime Inspection and Diagnostics.
- Lecture 04 — Images, Tags, and Layers.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Instructions.
- Lecture 07 — Week One Capstone.
- Lecture 08 — Ports and Runtime Environment Variables.
- Lecture 09 — Storage and Persistence.
- Lecture 10 — Networking and Service Discovery.
- Lecture 11 — Docker Compose Fundamentals.
- Lecture 12 — Flask and Redis Application Engineering.
- Lecture 13 — Advanced Docker Compose.
- Lecture 14 — Week Two Capstone.
- Lecture 15 — Multi-Stage Builds and BuildKit.
- Lecture 16 — Docker Security and Hardening.

---

# 1. PURPOSE OF THE LECTURE

Operational troubleshooting is the systematic investigation of software and infrastructure behavior to identify the causes of failures and restore correct functionality.

A containerized application may fail for several independent reasons.

These include:

- Incorrect container startup commands.
- Application exceptions.
- Missing dependencies.
- Unavailable network services.
- Port conflicts.
- Incorrect environment variables.
- Insufficient filesystem permissions.
- Unavailable or incorrectly mounted volumes.
- Resource exhaustion.
- Image build failures.
- Health-check failures.
- Configuration inconsistencies.
- Docker Engine problems.

The principal challenge is determining which component or configuration is responsible for the observed behavior.

For example, a web browser may display:

```text
502 Bad Gateway
```

This message indicates a problem associated with the gateway's attempt to provide a response.

It does not identify the complete underlying cause.

The Flask container might have stopped.

Flask might be listening on the wrong port.

Docker DNS resolution might be failing.

The reverse proxy might have incorrect upstream configuration.

Network connectivity might be interrupted.

A reliable engineer must distinguish these possibilities using evidence.

This lecture introduces the methods and commands required to conduct that investigation.

---

# 2. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define operational troubleshooting.
2. Distinguish symptoms from underlying causes.
3. Explain the purpose of a diagnostic hypothesis.
4. Apply a structured root-cause analysis methodology.
5. Explain the importance of preserving diagnostic evidence.
6. Distinguish application failures from infrastructure failures.
7. Interpret Docker container lifecycle states.
8. Identify running, exited, restarting, paused, and unhealthy containers.
9. Explain container exit codes.
10. Distinguish normal termination from signal-related termination.
11. Explain the relationship between exit code 137 and SIGKILL.
12. Investigate possible out-of-memory termination.
13. Use `docker inspect` to examine runtime state.
14. Use formatted Docker inspection queries.
15. Retrieve container logs.
16. Apply log filtering by time and line count.
17. Use Docker Compose to retrieve multi-service logs.
18. Explain Docker logging drivers.
19. Identify limitations of local log retrieval.
20. Interpret application health-check results.
21. Examine Docker Engine events.
22. Correlate events with application log timestamps.
23. Measure container CPU, memory, network, and process usage.
24. Inspect running processes inside containers.
25. Investigate Docker filesystem changes.
26. Distinguish image storage, writable layers, and named volumes.
27. Diagnose Docker disk-space problems.
28. Investigate Docker network connectivity.
29. Diagnose service-name resolution failures.
30. Distinguish DNS failures from TCP connection failures.
31. Explain common HTTP gateway error responses.
32. Diagnose incorrect host port publishing.
33. Examine Compose configuration interpolation.
34. Investigate incorrect environment variable values.
35. Diagnose storage configuration and persistence failures.
36. Distinguish image build errors from container runtime errors.
37. Demonstrate a controlled application process failure.
38. Demonstrate a controlled Redis dependency failure.
39. Diagnose and correct an incorrect service hostname.
40. Diagnose and correct a network attachment failure.
41. Investigate a deliberate host port conflict.
42. Demonstrate how configuration changes can resemble data loss.
43. Restore services after controlled failures.
44. Produce an evidence-based incident report.
45. Apply safe operational troubleshooting procedures.

---

# PART I — FOUNDATIONS OF SYSTEMATIC TROUBLESHOOTING

# 3. DEFINITION OF TROUBLESHOOTING

Troubleshooting is the process of identifying, analyzing, and resolving abnormal system behavior.

A complete troubleshooting process should establish:

1. What was expected.
2. What actually occurred.
3. Which evidence is available.
4. Which hypotheses could explain the behavior.
5. Which tests can distinguish those hypotheses.
6. What the underlying cause is.
7. Which correction is appropriate.
8. Whether normal operation has been restored.

A correction should not be considered complete merely because an error message temporarily disappears.

The underlying failure condition should be understood and verified.

---

# 4. SYMPTOMS AND ROOT CAUSES

## 4.1 Symptom

A symptom is an observable consequence of a problem.

Examples:

```text
Container exited.
```

```text
HTTP 503 returned.
```

```text
Redis connection refused.
```

```text
Volume appears empty.
```

## 4.2 Root Cause

A root cause is an underlying condition that explains why the failure occurred.

Examples:

- Invalid application configuration.
- Incorrect Redis hostname.
- Missing network attachment.
- Insufficient memory.
- Wrong volume selection.
- Invalid application startup command.

## 4.3 Example

**Symptom:** The counter API returns HTTP 503.

**Possible root cause:** The Flask application cannot connect to Redis because its configured hostname is incorrect.

Restarting Flask may temporarily change its logs or status, but it does not correct the hostname.

## 4.4 Engineering Principle

**A symptom indicates where a problem becomes visible; it does not necessarily indicate where the problem originates.**

---

# 5. OBSERVATION, HYPOTHESIS, AND VERIFICATION

An effective diagnostic investigation resembles an experimental scientific process.

## 5.1 Observation

Record the actual behavior.

Example:

```text
GET /health/ready returns HTTP 503.
```

## 5.2 Hypothesis

Propose a possible explanation.

Example:

```text
The Redis hostname cannot be resolved.
```

## 5.3 Test

Execute a command capable of evaluating the hypothesis.

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('redis'))"
```

## 5.4 Interpretation

Evaluate the result.

A DNS resolution failure supports a name-resolution problem.

A successful DNS result means that further tests are necessary to determine whether the Redis port and protocol are functioning.

## 5.5 Verification

After applying a correction, repeat the relevant tests.

The investigation should verify restoration rather than assume success.

---

# 6. A SYSTEMATIC DIAGNOSTIC METHOD

The following eight-stage process will be used throughout this lecture.

**Stage 1 — Identify the symptom**

Determine precisely what is failing.

**Stage 2 — Establish expected behavior**

Identify the correct application response or system state.

**Stage 3 — Define the affected scope**

Determine which services, containers, users, or requests are affected.

**Stage 4 — Collect evidence**

Gather logs, states, events, configuration, and resource measurements.

**Stage 5 — Form hypotheses**

Identify plausible causes supported by the available evidence.

**Stage 6 — Test hypotheses**

Perform controlled checks that distinguish between possible causes.

**Stage 7 — Apply a correction**

Modify only the configuration or component required to resolve the confirmed problem.

**Stage 8 — Verify and document**

Confirm normal functionality and record the findings.

---

# 7. DIAGNOSTIC PROCESS DIAGRAM

```text
                 FAILURE REPORTED
                        |
                        v
                IDENTIFY SYMPTOM
                        |
                        v
              ESTABLISH EXPECTATION
                        |
                        v
                COLLECT EVIDENCE
                        |
                        v
                FORM HYPOTHESES
                        |
                        v
                PERFORM TESTS
                        |
                        v
               CAUSE IDENTIFIED?
                   /         \
                  /           \
                 NO           YES
                 |             |
                 v             v
          COLLECT FURTHER    APPLY FIX
             EVIDENCE          |
                 |             v
                 |         VERIFY RESULT
                 |             |
                 +----<--------+
                               |
                               v
                       DOCUMENT FINDINGS
```

This model encourages deliberate investigation instead of random command execution.

---

# 8. PRESERVING EVIDENCE

## 8.1 Importance

Some troubleshooting actions destroy information.

For example:

```bash
docker rm CONTAINER
```

removes the container object and may eliminate convenient access to its previous runtime state and local logs.

Similarly:

```bash
docker compose down
```

removes service containers and project networks.

## 8.2 Recommended Evidence

Before removing or recreating a failing container, collect:

- Container identifier.
- Image reference.
- Exit code.
- Start and finish timestamps.
- Health-check results.
- Recent logs.
- Environment configuration, excluding secrets.
- Network attachments.
- Mount configuration.
- Relevant Docker events.

## 8.3 Operational Principle

**Preserve relevant evidence before performing destructive corrective actions whenever practical.**

---

# 9. TROUBLESHOOTING WITHOUT INCREASING RISK

Diagnostics should not introduce greater problems than the original failure.

Avoid immediately executing:

```bash
docker system prune -a --volumes
```

against an environment containing important application resources.

Avoid modifying production data merely to test whether a database works.

Avoid publishing internal services through additional host ports without evaluating the exposure.

Avoid logging sensitive environment variables.

Prefer read-only inspection operations before changing runtime configuration.

---

# PART II — CONTAINER LIFECYCLE DIAGNOSTICS

# 10. DOCKER CONTAINER STATES

Docker containers may be observed in states such as:

- Created.
- Running.
- Paused.
- Restarting.
- Exited.
- Removing.
- Dead.

The meaning of each state must be distinguished from the health of the application process.

## 10.1 Running

The container's principal process is active.

## 10.2 Exited

The container's principal process has terminated.

## 10.3 Restarting

Docker is performing restart behavior for a container.

## 10.4 Paused

Container processes have been suspended through Docker's pause mechanism.

## 10.5 Created

The container object exists but has not yet entered its normal running state.

---

# 11. LISTING CONTAINERS

## 11.1 Running Containers

```bash
docker ps
```

## 11.2 All Containers

```bash
docker ps -a
```

## 11.3 Compose Project Containers

```bash
docker compose ps
```

## 11.4 Include Stopped Compose Containers

```bash
docker compose ps -a
```

## 11.5 Diagnostic Significance

The first diagnostic question is often whether the expected container exists and is running.

A container that has exited requires a different investigation from a running but unhealthy container.

---

# 12. CONTAINER EXIT CODES

## 12.1 Definition

An exit code is a numeric result associated with the termination of a process.

The principal process's exit status becomes an important part of the container's recorded exit information.

## 12.2 Common Values

| Exit code | General interpretation |
|---|---|
| `0` | Successful or normal termination |
| `1` | General application error, by convention |
| `2` | Application-defined error; meaning varies |
| `42` | Arbitrary application-defined code used in this laboratory |
| `126` | Often indicates a command was found but could not be executed in shell conventions |
| `127` | Often indicates a command was not found in shell conventions |
| `137` | Commonly indicates termination by SIGKILL |
| `143` | Commonly indicates termination by SIGTERM |

## 12.3 Important Qualification

Exit codes are not a universal database of root causes.

Applications can define their own status meanings.

Shell exit conventions and Docker CLI errors should also be distinguished from the exit status recorded for a container's principal process.

---

# 13. SIGNALS AND CONTAINER TERMINATION

## 13.1 SIGTERM

SIGTERM requests process termination.

Applications may intercept the signal and attempt graceful shutdown.

## 13.2 SIGKILL

SIGKILL forcibly terminates a process and cannot be caught or ignored by that process.

## 13.3 Common Shell Convention

Signal-related exit statuses are often represented by:

\[
128 + \text{Signal Number}
\]

For example:

\[
128 + 9 = 137
\]

and:

\[
128 + 15 = 143
\]

## 13.4 Important Limitation

An exit code of 137 does not, by itself, prove that the container exceeded its memory limit.

The process may have been terminated by SIGKILL for another reason.

Additional evidence is required.

---

# 14. OUT-OF-MEMORY TERMINATION

## 14.1 Definition

Out-of-memory termination may occur when resource constraints or memory pressure cause a process to be killed.

## 14.2 Relevant Evidence

Investigate:

- Container exit code.
- OOMKilled state.
- Configured memory limits.
- Docker events.
- Host memory conditions.
- Application memory behavior.

## 14.3 Inspection

```bash
docker inspect CONTAINER --format '{{.State.OOMKilled}}'
```

## 14.4 Interpretation

An OOMKilled value of `true` provides relevant evidence of an out-of-memory termination.

An exit code of 137 without supporting evidence is insufficient to establish an OOM root cause.

## 14.5 Safe Laboratory Practice

This lecture does not require deliberately exhausting the host's memory.

Resource exhaustion will be analyzed using inspection and controlled reasoning rather than dangerous stress tests.

---

# 15. DOCKER INSPECT

## 15.1 Definition

`docker inspect` retrieves low-level information about Docker-managed objects.

## 15.2 Basic Command

```bash
docker inspect CONTAINER
```

## 15.3 Container State

```bash
docker inspect CONTAINER --format '{{json .State}}'
```

## 15.4 Exit Code

```bash
docker inspect CONTAINER --format '{{.State.ExitCode}}'
```

## 15.5 OOM Status

```bash
docker inspect CONTAINER --format '{{.State.OOMKilled}}'
```

## 15.6 Runtime Configuration

Docker inspection can also reveal:

- Mounts.
- Network endpoints.
- Port mappings.
- Restart policy.
- Resource limits.
- Image identifier.
- Container process configuration.

## 15.7 Security Consideration

Complete inspection output may contain sensitive runtime configuration.

Do not publish unreviewed inspection results from production systems.

---

# 16. FORMATTED INSPECTION

Docker supports formatting output using Go templates.

For example:

```bash
docker inspect CONTAINER --format '{{.State.Status}}'
```

A more detailed expression is:

```bash
docker inspect CONTAINER --format '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}'
```

## 16.1 Benefit

Formatted inspection extracts specific information without displaying the entire JSON representation.

## 16.2 Limitation

The requested fields must exist in the object's inspection structure.

Container, image, volume, and network objects do not all have the same schema.

---

# PART III — APPLICATION LOGGING

# 17. APPLICATION LOGS

## 17.1 Definition

A log is a time-ordered record of events or messages generated by software.

Application logs may contain:

- Startup information.
- Requests.
- Errors.
- Warnings.
- Dependency failures.
- Recovery messages.
- Operational transitions.

## 17.2 Standard Output

Many containerized applications write operational output to standard output.

## 17.3 Standard Error

Errors and diagnostic messages may be written to standard error.

## 17.4 Container Logging

Docker can collect these streams using a configured logging mechanism.

---

# 18. THE docker logs COMMAND

## 18.1 Basic Retrieval

```bash
docker logs CONTAINER
```

## 18.2 Recent Lines

```bash
docker logs --tail 30 CONTAINER
```

## 18.3 Timestamps

```bash
docker logs --timestamps CONTAINER
```

## 18.4 Recent Time Window

```bash
docker logs --since 10m CONTAINER
```

## 18.5 Follow Output

```bash
docker logs -f CONTAINER
```

Press `Ctrl+C` to stop following the output.

This does not normally stop the container itself.

---

# 19. LOG TIME CORRELATION

## 19.1 Importance

Distributed applications generate logs in different components.

A request may pass through:

1. Nginx.
2. Flask.
3. Redis.

A failure may be reported at different times in each service.

## 19.2 Timestamped Logs

Use timestamps to compare the sequence of events.

## 19.3 Diagnostic Example

```text
14:00:01 — Redis container stops.
14:00:02 — Flask reports connection failure.
14:00:03 — Counter API returns HTTP 503.
14:00:04 — Nginx records the HTTP response.
```

The timestamps are illustrative.

## 19.4 Qualification

A reliable investigation must consider clock synchronization and differences in timestamp representation.

---

# 20. DOCKER COMPOSE LOGS

## 20.1 All Services

```bash
docker compose logs
```

## 20.2 Specific Service

```bash
docker compose logs web
```

## 20.3 Multiple Services

```bash
docker compose logs gateway web redis
```

## 20.4 Recent Messages

```bash
docker compose logs --tail 30
```

## 20.5 Timestamped Output

```bash
docker compose logs --timestamps
```

## 20.6 Time Filtering

```bash
docker compose logs --since 10m
```

## 20.7 Significance

Compose provides a convenient interface for correlating output from services belonging to the same application project.

---

# 21. DOCKER LOGGING DRIVERS

## 21.1 Definition

A logging driver determines how Docker handles container output.

## 21.2 Examples

Docker supports logging mechanisms including:

- `json-file`.
- `local`.
- `journald`, where available.
- Remote logging drivers.
- `none`.

## 21.3 Inspection

```bash
docker inspect CONTAINER --format '{{.HostConfig.LogConfig.Type}}'
```

## 21.4 Local Log Availability

The ability to retrieve logs through `docker logs` depends on logging-driver support and any applicable local log cache.

## 21.5 Important Limitation

A container configured with the `none` logging driver does not provide ordinary Docker-managed container logs.

A remote logging configuration without local read support may require investigation through the relevant logging backend.

---

# 22. LOG QUALITY

Useful application logs should contain:

- Meaningful event descriptions.
- Appropriate severity.
- Consistent timestamps.
- Relevant service identity.
- Safe request context.
- Useful error categories.

## 22.1 Poor Logging

```text
Something went wrong.
```

## 22.2 Better Logging

```text
Redis request failed: connection unavailable.
```

## 22.3 Sensitive Information

Avoid recording:

- Passwords.
- Authentication tokens.
- Private keys.
- Full confidential database records.
- Sensitive request payloads.

## 22.4 Principle

Good logging provides sufficient context to diagnose a failure without unnecessarily disclosing protected information.

---

# PART IV — HEALTH CHECKS AND ENGINE EVENTS

# 23. APPLICATION HEALTH

## 23.1 Running Versus Healthy

A process may continue running after one of its dependencies becomes unavailable.

## 23.2 Liveness

Liveness evaluates basic process responsiveness.

## 23.3 Readiness

Readiness evaluates whether required functionality is available.

## 23.4 Docker Health Check

A Docker health check executes a configured test and records the result.

## 23.5 Important Qualification

Docker does not automatically restart every unhealthy container.

Runtime restart policies primarily address eligible principal-process termination events.

---

# 24. HEALTH-CHECK INSPECTION

## 24.1 Health Status

```bash
docker inspect CONTAINER --format '{{.State.Health.Status}}'
```

This requires a container with a configured health check.

## 24.2 Complete Health Data

```bash
docker inspect CONTAINER --format '{{json .State.Health}}'
```

## 24.3 Recorded Information

Health data may include:

- Current status.
- Consecutive failure count.
- Test execution timestamps.
- Exit codes.
- Recent test output.

## 24.4 Diagnostic Importance

A health-check error provides evidence about the particular check.

It does not automatically identify every failing application component.

---

# 25. DOCKER EVENTS

## 25.1 Definition

Docker events are records of selected Docker Engine object lifecycle activities.

## 25.2 Examples

Container events may include:

- Create.
- Start.
- Stop.
- Die.
- Restart.
- Health status change.
- OOM.
- Network connect.
- Network disconnect.

## 25.3 Basic Command

```bash
docker events
```

The command streams events.

## 25.4 Container Filter

```bash
docker events --filter type=container
```

## 25.5 Event Filter

```bash
docker events --filter event=die
```

## 25.6 Time Window

```bash
docker events --since 15m
```

## 25.7 Important Limitation

Docker event retrieval is not a substitute for an indefinitely retained audit log.

Historical event retrieval has buffering and retention limitations.

Persistent operational auditing requires an appropriate external collection strategy.

---

# 26. EVENT CORRELATION

An application incident may involve multiple events.

Example:

```text
Container start
       |
       v
Health status: healthy
       |
       v
Redis container stop
       |
       v
Web health status: unhealthy
       |
       v
Redis container start
       |
       v
Web health status: healthy
```

The event sequence can help establish whether the reported application failure followed a container lifecycle event.

---

# PART V — RESOURCE DIAGNOSTICS

# 27. THE docker stats COMMAND

## 27.1 Definition

`docker stats` displays resource usage statistics for containers.

## 27.2 Basic Command

```bash
docker stats
```

## 27.3 Single Observation

```bash
docker stats --no-stream
```

## 27.4 Specific Container

```bash
docker stats --no-stream CONTAINER
```

## 27.5 Common Metrics

The output may include:

- CPU percentage.
- Memory usage.
- Memory limit.
- Network input and output.
- Block input and output.
- Process and thread count.

---

# 28. INTERPRETING RESOURCE METRICS

## 28.1 CPU

CPU usage can indicate processing demand.

However, a momentary high value does not automatically prove a problem.

## 28.2 Memory

Memory usage should be evaluated relative to configured limits and expected application behavior.

## 28.3 Network I/O

Network traffic metrics can help identify whether a container is sending and receiving data.

They do not independently prove successful application communication.

## 28.4 Block I/O

Block input and output can provide evidence of filesystem activity.

## 28.5 PIDs

The PIDs metric can include processes and kernel threads.

A value greater than the visible process count does not necessarily indicate an error.

---

# 29. PROCESS INSPECTION

## 29.1 Docker Top

```bash
docker top CONTAINER
```

Displays processes associated with the container.

## 29.2 Docker Exec

```bash
docker exec CONTAINER ps
```

This requires an appropriate process-inspection utility inside the container.

## 29.3 Distinction

`docker top` uses Docker's runtime inspection interface and does not require the container image to include the same command-line utilities.

## 29.4 Minimal Images

A scratch-based image may not contain a shell or `ps`.

Runtime inspection should therefore not depend exclusively on interactive access inside the container.

---

# 30. HOST AND ENGINE INFORMATION

## 30.1 Docker System Information

```bash
docker info
```

## 30.2 Relevant Information

Depending on platform, output may include:

- Docker Engine version.
- Server operating system.
- Storage driver.
- Logging driver.
- Cgroup information.
- Runtime configuration.
- Available resources.

## 30.3 Diagnostic Importance

A problem affecting several unrelated containers may originate from Docker Engine or host configuration rather than a particular application.

---

# 31. DISK-SPACE DIAGNOSTICS

## 31.1 Docker Storage Categories

Docker uses storage for:

- Images.
- Containers.
- Volumes.
- Build caches.
- Logs.
- Other internal resources.

## 31.2 Disk Usage

```bash
docker system df
```

## 31.3 Detailed Usage

```bash
docker system df -v
```

## 31.4 Important Distinction

The size of a Docker image is different from the size of persistent application data stored in volumes.

## 31.5 Safe Cleanup

Do not immediately execute aggressive prune commands to solve disk-space problems.

Identify which objects consume storage and whether they are still required.

---

# 32. FILESYSTEM CHANGE INSPECTION

## 32.1 Docker Diff

```bash
docker diff CONTAINER
```

## 32.2 Symbols

| Symbol | Meaning |
|---|---|
| `A` | Added |
| `C` | Changed |
| `D` | Deleted |

## 32.3 Scope

`docker diff` primarily describes changes associated with the container's writable filesystem.

It should not be treated as a complete inventory of changes to independently mounted volumes or host bind mounts.

## 32.4 Use Case

The command can help identify whether an application writes files into unexpected locations.

---

# 33. COPYING DIAGNOSTIC FILES

## 33.1 Docker CP

```bash
docker cp CONTAINER:/path/to/file ./local-file
```

## 33.2 Purpose

This can retrieve relevant files from containers for analysis.

## 33.3 Examples

- Application-generated reports.
- Temporary diagnostic output.
- Configuration snapshots.
- Non-sensitive runtime artifacts.

## 33.4 Security Principle

Do not copy or publish sensitive files merely because a diagnostic tool makes them accessible.

---

# PART VI — NETWORK AND HTTP DIAGNOSTICS

# 34. NETWORK TROUBLESHOOTING LAYERS

Container networking failures can occur at several levels.

```text
            APPLICATION PROTOCOL
                     |
                     v
                 HTTP / REDIS
                     |
                     v
                   TCP
                     |
                     v
                IP ROUTING
                     |
                     v
              DOCKER NETWORK
                     |
                     v
                HOST NETWORK
```

An investigation should identify which level is failing.

---

# 35. NETWORK ATTACHMENTS

## 35.1 List Networks

```bash
docker network ls
```

## 35.2 Inspect a Network

```bash
docker network inspect NETWORK
```

## 35.3 Inspect Container Networks

```bash
docker inspect CONTAINER --format '{{json .NetworkSettings.Networks}}'
```

## 35.4 Diagnostic Questions

1. Is the container attached to the expected network?
2. Are the required services on a shared network?
3. Is the network driver appropriate?
4. Does the container have the expected address?
5. Are the service aliases present?

---

# 36. DNS RESOLUTION

## 36.1 Definition

DNS resolution converts a hostname into a network address.

## 36.2 Compose Services

Services connected to a shared suitable Compose network can ordinarily be discovered using their service names.

## 36.3 Example

```text
redis
```

is resolved to an address associated with the Redis service.

## 36.4 Failure Causes

- Incorrect service name.
- Missing shared network.
- Container network disconnection.
- Incorrect application hostname.
- Resolver configuration problems.

## 36.5 Important Distinction

Successful DNS resolution does not guarantee that the destination service is accepting connections.

---

# 37. TCP CONNECTIVITY

## 37.1 Definition

A successful TCP connection indicates that a network connection was established with a destination endpoint.

## 37.2 Failure Types

Possible failures include:

- Connection refused.
- Connection timed out.
- No route to host.
- Name resolution failure.

## 37.3 Distinction

A DNS error occurs before the application can use the resolved destination address.

A connection-refused error ordinarily indicates that a connection attempt reached a condition in which the requested TCP service was not accepting the connection.

A timeout can have several causes and must be interpreted in context.

---

# 38. HTTP RESPONSE CODES

## 38.1 HTTP 200

The request succeeded.

## 38.2 HTTP 404

The requested resource was not found.

## 38.3 HTTP 500

The application encountered an internal server error.

## 38.4 HTTP 502

A gateway or proxy received an invalid response or could not successfully complete communication with the upstream in a manner represented as Bad Gateway.

## 38.5 HTTP 503

The service is currently unable to handle the request.

## 38.6 HTTP 504

A gateway or proxy did not receive an appropriate upstream response within the applicable timeout.

## 38.7 Important Principle

HTTP response codes classify observable outcomes.

They must be combined with application logs and infrastructure evidence to identify root causes.

---

# 39. HOST PORT CONFLICTS

## 39.1 Definition

A port conflict occurs when incompatible processes or container port mappings attempt to use the same host network endpoint.

## 39.2 Typical Symptom

```text
Bind for address already in use.
```

The exact message varies.

## 39.3 Investigation

```bash
docker ps
```

```bash
docker compose ps
```

```bash
docker compose config
```

## 39.4 Correction

Select an available port or deliberately stop the conflicting workload when appropriate.

Never terminate an unrelated application without evaluating the consequences.

---

# PART VII — STORAGE AND CONFIGURATION DIAGNOSTICS

# 40. STORAGE FAILURE CATEGORIES

Persistent storage problems may involve:

1. Missing volumes.
2. Wrong volume names.
3. Incorrect mount destinations.
4. File permission errors.
5. Application persistence disabled.
6. Incorrect storage directories.
7. Corrupted application data.
8. Exhausted storage capacity.
9. Unexpected project names.
10. Destructive volume removal.

---

# 41. INSPECTING MOUNTS

## 41.1 Container Mounts

```bash
docker inspect CONTAINER --format '{{json .Mounts}}'
```

## 41.2 Volume Inspection

```bash
docker volume inspect VOLUME
```

## 41.3 Required Analysis

Identify:

- Mount type.
- Source.
- Destination.
- Read/write status.
- Volume identifier.

## 41.4 Important Distinction

A successful volume mount does not prove that the application writes recoverable data to that mounted path.

The application's storage configuration must also be correct.

---

# 42. DATA APPEARS MISSING

An application may return an empty result even though its previous data still exists.

For example, the application may now use a different Redis key.

Alternatively, a different Compose project name may cause Docker to create a new named volume.

## 42.1 Diagnostic Sequence

1. Confirm the application key.
2. Confirm the Compose project name.
3. Confirm the volume name.
4. Confirm the mount destination.
5. Inspect the original data volume.
6. Verify persistence settings.
7. Avoid deleting either dataset during investigation.

---

# 43. CONFIGURATION INTERPOLATION

## 43.1 Project .env

The Compose project may load interpolation values from an `.env` file.

## 43.2 Container Environment

The application receives environment variables through applicable service configuration.

## 43.3 Inspection

```bash
docker compose config
```

## 43.4 Container Verification

```bash
docker compose exec web printenv REDIS_HOST
```

## 43.5 Important Principle

The value the administrator intended to configure is not necessarily the value currently used by a running container.

Always verify the effective runtime configuration.

---

# 44. IMAGE BUILD FAILURE VERSUS RUNTIME FAILURE

## 44.1 Build Failure

The image cannot be constructed.

Examples:

- Missing build context file.
- Invalid Dockerfile instruction.
- Dependency installation failure.
- Compilation error.

## 44.2 Runtime Failure

The image builds, but the application cannot execute correctly.

Examples:

- Incorrect entrypoint.
- Missing runtime library.
- Wrong environment variable.
- Invalid mount.
- Unavailable database.
- Incorrect listening address.

## 44.3 Diagnosis

Use build output and image inspection for build failures.

Use container state, logs, and runtime inspection for execution failures.

---

# 45. COMPOSE CONFIGURATION RECONCILIATION

## 45.1 Restart

```bash
docker compose restart web
```

Restarts an existing service container.

## 45.2 Reconciliation

```bash
docker compose up -d
```

Applies the current Compose model, recreating relevant containers when necessary.

## 45.3 Rebuild

```bash
docker compose up -d --build
```

Builds applicable images and reconciles services.

## 45.4 Important Distinction

Restarting an existing container does not automatically apply every configuration or image change.

A service may need to be recreated.

---

# PART VIII — OPERATIONAL DIAGNOSTIC FRAMEWORK

# 46. DIAGNOSTIC CHECKLIST

The following sequence provides a practical starting point for multi-container incidents.

```bash
docker compose config -q
```

```bash
docker compose ps -a
```

```bash
docker compose logs --tail 50
```

```bash
docker network ls
```

```bash
docker volume ls
```

```bash
docker stats --no-stream
```

```bash
docker system df
```

These commands provide different categories of evidence.

They should be selected according to the symptoms rather than executed indiscriminately.

---

# 47. DIAGNOSTIC EVIDENCE MATRIX

| Symptom | Primary evidence | Secondary evidence |
|---|---|---|
| Container exits immediately | Logs, exit code | Entrypoint, image configuration |
| Container repeatedly restarts | State, restart count | Application logs, events |
| Container unhealthy | Health-check output | Dependency status |
| HTTP 502 | Proxy logs | Upstream state and DNS |
| HTTP 503 | Application logs | Database connectivity |
| DNS resolution failure | Network attachments | Service names and aliases |
| Connection refused | Listener configuration | Port and process state |
| Host port conflict | Published ports | Existing host listeners |
| Data appears missing | Volume and application key | Compose project name |
| Permission denied | UID/GID and mounts | Filesystem permissions |
| Possible OOM | OOMKilled and events | Memory limits and stats |
| Disk-space problem | Docker disk usage | Volumes, logs, build cache |

---

# 48. INCIDENT REPORTING

A professional incident report should record:

1. Incident identifier.
2. Date and time.
3. Affected application.
4. User-visible symptoms.
5. Impact.
6. Technical evidence.
7. Hypotheses investigated.
8. Confirmed cause.
9. Corrective actions.
10. Verification results.
11. Preventive recommendations.

A report should distinguish confirmed facts from assumptions.

---

# PART IX — PRACTICAL LABORATORY 17

# 49. LABORATORY TITLE

**Controlled Docker Failure Analysis: Nginx, Flask, and Redis Troubleshooting with Compose**

## 49.1 Objective

Construct a functioning three-service application and investigate controlled failures affecting:

- Application processes.
- Redis connectivity.
- DNS configuration.
- Docker networks.
- Host port publishing.
- Health checks.
- Storage identity.
- Container writable layers.
- Docker Engine events.
- Runtime resource inspection.

## 49.2 Safety Requirements

The laboratory must use isolated project resources.

Do not modify unrelated Docker workloads.

Do not remove unrelated volumes.

Do not intentionally exhaust host memory or CPU.

Do not expose Redis directly to public interfaces.

Preserve evidence before removing containers.

---

# 50. LABORATORY ARCHITECTURE

```text
                  LOCAL BROWSER
                        |
                        |
               127.0.0.1:8270
                        |
                        v
                  NGINX GATEWAY
                        |
                 FRONTEND NETWORK
                        |
                        v
                   FLASK WEB
                        |
                  BACKEND NETWORK
                        |
                        v
                      REDIS
                        |
                        v
                   NAMED VOLUME
```

The gateway forwards HTTP requests.

Flask implements application logic.

Redis stores persistent counter data.

The two networks separate client-facing and database communication.

---

# 51. PROJECT STRUCTURE

Create:

```text
docker-lecture17/
├── compose.yaml
├── .env
├── web/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
├── gateway/
│   └── default.conf
├── faults/
│   ├── bad-redis-host.yaml
│   ├── localhost-redis.yaml
│   └── wrong-counter-key.yaml
└── evidence/
```

The `faults` directory contains deliberately incorrect configuration overlays.

Each fault will be applied individually and then removed.

The `evidence` directory stores selected non-sensitive laboratory observations.

---

# 52. PYTHON DEPENDENCIES

Create:

`web/requirements.txt`

Insert:

```text
Flask==3.1.3
redis==6.2.0
gunicorn==26.2.0
```

These direct dependency versions match the earlier Flask and Redis laboratories.

A production application should additionally manage transitive dependencies and ongoing security updates.

---

# 53. COMPLETE DIAGNOSTIC FLASK APPLICATION

Create:

`web/app.py`

Insert:

```python
import logging
import os

import redis

from flask import (
    Flask,
    jsonify,
    render_template_string,
)

from redis.exceptions import RedisError


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

logger = logging.getLogger("lecture17")


app = Flask(__name__)


REDIS_HOST = os.getenv(
    "REDIS_HOST",
    "redis",
)

REDIS_PORT = int(
    os.getenv("REDIS_PORT", "6379")
)

COUNTER_KEY = os.getenv(
    "COUNTER_KEY",
    "lecture17:counter",
)

APP_MODE = os.getenv(
    "APP_MODE",
    "diagnostic",
)


client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)


PAGE = """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Docker Lecture 17</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            padding: 40px;
            color: #0f172a;
        }

        main {
            max-width: 700px;
            margin: auto;
            padding: 40px;
            background: white;
            border-radius: 12px;
            text-align: center;
        }

        h1 {
            color: #2563eb;
        }

        #count {
            font-size: 64px;
            font-weight: bold;
            margin: 30px;
        }

        button {
            background: #2563eb;
            color: white;
            border: none;
            padding: 15px 28px;
            border-radius: 8px;
            cursor: pointer;
        }

        #message {
            margin-top: 20px;
        }
    </style>
</head>

<body>

    <main>

        <h1>Docker Lecture 17</h1>

        <h2>Operational Diagnostics Laboratory</h2>

        <p>Application mode: {{ app_mode }}</p>

        <div id="count">...</div>

        <button id="increment">
            Increment Redis Counter
        </button>

        <p id="message"></p>

    </main>

    <script>

        const countElement =
            document.getElementById("count");

        const messageElement =
            document.getElementById("message");

        const button =
            document.getElementById("increment");


        async function refreshCount() {

            try {

                const response = await fetch(
                    "/api/count",
                    {cache: "no-store"}
                );

                const data = await response.json();

                if (!response.ok) {
                    throw new Error(
                        data.error || "Request failed"
                    );
                }

                countElement.textContent =
                    String(data.count);

                messageElement.textContent =
                    "Counter available";

            } catch (error) {

                countElement.textContent = "--";

                messageElement.textContent =
                    error.message;
            }
        }


        async function incrementCount() {

            try {

                const response = await fetch(
                    "/api/increment",
                    {method: "POST"}
                );

                const data = await response.json();

                if (!response.ok) {
                    throw new Error(
                        data.error || "Increment failed"
                    );
                }

                countElement.textContent =
                    String(data.count);

                messageElement.textContent =
                    "Increment completed";

            } catch (error) {

                messageElement.textContent =
                    error.message;
            }
        }


        button.addEventListener(
            "click",
            incrementCount
        );

        refreshCount();

    </script>

</body>
</html>
"""


@app.get("/")
def home():

    return render_template_string(
        PAGE,
        app_mode=APP_MODE,
    )


@app.get("/health/live")
def live():

    return jsonify(
        status="alive",
        service="web",
    ), 200


@app.get("/health/ready")
def ready():

    try:

        client.ping()

        return jsonify(
            status="ready",
            redis="available",
        ), 200

    except RedisError as error:

        logger.warning(
            "Readiness failed: %s",
            type(error).__name__,
        )

        return jsonify(
            status="not_ready",
            redis="unavailable",
        ), 503


@app.get("/api/count")
def get_count():

    try:

        value = client.get(COUNTER_KEY)

        count = (
            int(value)
            if value is not None
            else 0
        )

        return jsonify(
            count=count,
        ), 200

    except RedisError as error:

        logger.error(
            "Counter read failed: %s",
            type(error).__name__,
        )

        return jsonify(
            error="Redis temporarily unavailable",
        ), 503

    except (ValueError, TypeError):

        logger.error(
            "Counter data is invalid"
        )

        return jsonify(
            error="Invalid stored counter",
        ), 500


@app.post("/api/increment")
def increment_count():

    try:

        count = client.incr(COUNTER_KEY)

        logger.info(
            "Counter increment succeeded"
        )

        return jsonify(
            count=count,
        ), 200

    except RedisError as error:

        logger.error(
            "Counter increment failed: %s",
            type(error).__name__,
        )

        return jsonify(
            error="Redis temporarily unavailable",
        ), 503


@app.get("/api/config")
def configuration():

    return jsonify(
        mode=APP_MODE,
        redis_host=REDIS_HOST,
        redis_port=REDIS_PORT,
        counter_key=COUNTER_KEY,
    ), 200
```

## 53.1 Application Purpose

The application provides deterministic diagnostic endpoints.

It exposes:

- A browser interface.
- A counter retrieval API.
- A counter increment API.
- A liveness endpoint.
- A readiness endpoint.
- A non-sensitive configuration endpoint.

## 53.2 Logging

The application records selected successful and failed database operations.

## 53.3 Important Limitation

The configuration endpoint is included for academic diagnosis.

Production diagnostic endpoints should not reveal sensitive infrastructure information without appropriate access controls.

---

# 54. WEB DOCKERFILE

Create:

`web/Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=10001:10001 app.py ./app.py

USER 10001:10001

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
```

## 54.1 Purpose

The Dockerfile constructs a Python application image.

The process runs under a non-root identity.

Gunicorn serves the application on TCP port 8000.

The image includes a shell and Python tooling suitable for the controlled diagnostic laboratory.

---

# 55. NGINX CONFIGURATION

Create:

`gateway/default.conf`

Insert:

```nginx
server {

    listen 80;

    server_name _;

    resolver 127.0.0.11 valid=5s ipv6=off;

    set $web_backend web;

    location = /gateway-health {

        default_type text/plain;

        return 200 "gateway alive\n";

    }

    location / {

        proxy_pass http://$web_backend:8000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;

        proxy_set_header X-Real-IP $remote_addr;

        proxy_set_header X-Forwarded-For
                         $proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 2s;

        proxy_read_timeout 5s;

    }

}
```

## 55.1 Gateway Health

The `/gateway-health` endpoint is handled directly by Nginx.

It does not require Flask or Redis.

This makes it possible to observe a healthy gateway while its upstream application is unavailable.

## 55.2 Upstream Resolution

Nginx uses the logical Compose service name:

```text
web
```

The configured Docker DNS resolver supports resolution of that name within the frontend network.

## 55.3 Operational Value

The gateway and application have separate health conditions.

This helps distinguish reverse proxy availability from application readiness.

---

# 56. ENVIRONMENT FILE

Create:

`.env`

Insert:

```text
WEB_PORT=8270
APP_MODE=diagnostic
REDIS_HOST=redis
COUNTER_KEY=lecture17:counter
```

These values are non-sensitive instructional configuration.

---

# 57. COMPOSE APPLICATION

Create:

`compose.yaml`

Insert:

```yaml
name: lecture17-diagnostics

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
      retries: 5
      start_period: 10s


  web:
    build:
      context: ./web
      dockerfile: Dockerfile

    image: lecture17-web:v1

    environment:
      REDIS_HOST: "${REDIS_HOST:-redis}"
      REDIS_PORT: "6379"
      COUNTER_KEY: "${COUNTER_KEY:-lecture17:counter}"
      APP_MODE: "${APP_MODE:-diagnostic}"

    depends_on:
      redis:
        condition: service_healthy

    networks:
      - frontend
      - backend

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=2)"
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 10s


  gateway:
    image: nginx:alpine

    ports:
      - "127.0.0.1:${WEB_PORT:-8270}:80"

    volumes:
      - ./gateway/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      web:
        condition: service_started

    networks:
      - frontend

    healthcheck:
      test:
        - CMD-SHELL
        - "wget -q -O /dev/null http://127.0.0.1/gateway-health || exit 1"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s


networks:

  frontend:
    driver: bridge

  backend:
    driver: bridge


volumes:

  redis-data:
```

---

# 58. COMPOSE ARCHITECTURE ANALYSIS

## 58.1 Redis

Redis uses the backend network and a persistent named volume.

Its health check tests the Redis service.

## 58.2 Web

Flask uses both networks.

It connects to Redis through the backend network.

It receives client-facing traffic from Nginx through the frontend network.

## 58.3 Gateway

Nginx joins only the frontend network.

It publishes host port 8270.

## 58.4 Health Checks

Three independent checks are configured.

| Service | Health test |
|---|---|
| Redis | `redis-cli ping` |
| Web | Flask readiness endpoint |
| Gateway | Nginx-local gateway endpoint |

## 58.5 Dependency Conditions

Flask waits for Redis health during startup.

Nginx requires Flask to be started, but not necessarily healthy.

This deliberate choice permits the laboratory to demonstrate gateway availability during web-application dependency failure.

---

# 59. FAULT CONFIGURATION FILES

Create:

`faults/bad-redis-host.yaml`

Insert:

```yaml
services:
  web:
    environment:
      REDIS_HOST: redis-host-does-not-exist
```

Create:

`faults/localhost-redis.yaml`

Insert:

```yaml
services:
  web:
    environment:
      REDIS_HOST: localhost
```

Create:

`faults/wrong-counter-key.yaml`

Insert:

```yaml
services:
  web:
    environment:
      COUNTER_KEY: lecture17:wrong-counter
```

## 59.1 Purpose

These overlays introduce distinct configuration faults.

They will be applied individually using the Compose `-f` option.

## 59.2 Recovery

After each fault experiment, the base configuration can be restored using:

```bash
docker compose up -d
```

The effective model should be verified before assuming that the original configuration has been restored.

---

# PART X — CONTROLLED LABORATORY EXPERIMENTS

# 60. EXPERIMENT 1 — VERIFY DOCKER AND COMPOSE

Execute:

```bash
docker version
```

Then:

```bash
docker compose version
```

Then:

```bash
docker info
```

**Objective:**

Confirm Docker Engine availability and record basic platform information.

**Required observations:**

1. Docker Engine version.
2. Compose version.
3. Engine operating system.
4. Storage driver.
5. Default logging driver.

---

# 61. EXPERIMENT 2 — CREATE THE PROJECT

Create the project directory:

```bash
mkdir -p docker-lecture17/web
mkdir -p docker-lecture17/gateway
mkdir -p docker-lecture17/faults
mkdir -p docker-lecture17/evidence
```

Enter it:

```bash
cd docker-lecture17
```

Create the files described in Sections 52–59.

**Objective:**

Establish a reproducible troubleshooting environment.

---

# 62. EXPERIMENT 3 — VALIDATE THE COMPOSE MODEL

Execute:

```bash
docker compose config -q
```

Then:

```bash
docker compose config
```

**Objective:**

Verify the application definition before deployment.

**Required observations:**

Identify:

1. The project name.
2. Three services.
3. Two networks.
4. The named volume.
5. Published port.
6. Environment variables.
7. Health checks.
8. Service dependencies.

---

# 63. EXPERIMENT 4 — BUILD AND START THE APPLICATION

Execute:

```bash
docker compose up -d --build
```

Verify:

```bash
docker compose ps
```

**Objective:**

Construct and start the complete application.

**Expected result:**

The three services start.

Their health checks should eventually report healthy status.

---

# 64. EXPERIMENT 5 — VERIFY BASELINE APPLICATION FUNCTIONALITY

Open:

http://127.0.0.1:8270

Then:

http://127.0.0.1:8270/health/live

Then:

http://127.0.0.1:8270/health/ready

**Objective:**

Establish normal application behavior before introducing faults.

**Expected result:**

The browser interface is accessible.

The health endpoints return successful responses.

**Required analysis:**

Explain why recording the normal state is important for later comparison.

---

# 65. EXPERIMENT 6 — CREATE REFERENCE APPLICATION DATA

Execute:

```bash
curl -X POST http://127.0.0.1:8270/api/increment
```

Repeat several times.

Then:

```bash
curl http://127.0.0.1:8270/api/count
```

Record the resulting counter value.

**Objective:**

Create persistent data for later storage diagnostics.

---

# 66. EXPERIMENT 7 — INSPECT SERVICE STATES

Execute:

```bash
docker compose ps -a
```

Then:

```bash
docker compose ps --format json
```

**Objective:**

Compare the standard service listing with machine-readable status output.

**Required analysis:**

Identify the service name, state, health, image, and published ports.

---

# 67. EXPERIMENT 8 — COLLECT TIMESTAMPED LOGS

Execute:

```bash
docker compose logs --timestamps --tail 30
```

Then:

```bash
docker compose logs --since 10m web
```

**Objective:**

Collect application evidence.

**Required observations:**

1. Gunicorn startup messages.
2. Redis startup information.
3. Nginx request logs.
4. Counter-related application messages.

---

# 68. EXPERIMENT 9 — INSPECT THE WEB CONTAINER

Execute:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{json .State}}'
```

Then:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{json .NetworkSettings.Networks}}'
```

**Objective:**

Inspect container state and network attachments.

**Required analysis:**

Explain why this information cannot be obtained completely from the application logs alone.

---

# 69. EXPERIMENT 10 — INSPECT APPLICATION HEALTH

Execute:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{json .State.Health}}'
```

**Objective:**

Examine health-check results.

**Required observations:**

1. Health status.
2. Consecutive failure count.
3. Recent health-check executions.
4. Health-check output.

---

# 70. EXPERIMENT 11 — CAPTURE RESOURCE METRICS

Execute:

```bash
docker stats --no-stream
```

Optionally inspect only the project containers using their identifiers.

**Objective:**

Record baseline CPU, memory, network, and process usage.

**Required analysis:**

Explain why a single measurement is insufficient to characterize long-term resource behavior.

---

# 71. EXPERIMENT 12 — INSPECT PROCESS ACTIVITY

Execute:

```bash
docker top "$(docker compose ps -q web)"
```

Then:

```bash
docker top "$(docker compose ps -q redis)"
```

**Objective:**

Identify running processes associated with the services.

**Required analysis:**

Explain the relationship between Gunicorn's principal process and its worker processes.

---

# 72. EXPERIMENT 13 — INTRODUCE A CONTROLLED PROCESS EXIT

Create a temporary container:

```bash
docker run -d \
  --name lecture17-exit-probe \
  alpine:3.20 \
  sh -c 'sleep 1; exit 42'
```

Wait for completion:

```bash
docker wait lecture17-exit-probe
```

**Expected result:**

```text
42
```

**Objective:**

Demonstrate an application-defined nonzero process exit.

Inspect:

```bash
docker inspect lecture17-exit-probe --format '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}'
```

**Required analysis:**

Explain why exit code 42 in this experiment does not imply an OOM condition.

---

# 73. EXPERIMENT 14 — INSPECT DOCKER EVENTS

Execute:

```bash
docker events --since 15m --filter container=lecture17-exit-probe
```

Inspect the container creation, start, and termination events.

Press `Ctrl+C` when finished.

**Objective:**

Correlate Docker lifecycle events with the controlled process exit.

**Required analysis:**

Explain the difference between an event record and an application log message.

---

# 74. EXPERIMENT 15 — INVESTIGATE A GATEWAY FAILURE

Stop the web service:

```bash
docker compose stop web
```

Now request:

```bash
curl -i http://127.0.0.1:8270/
```

**Expected result:**

Nginx cannot successfully proxy the request to Flask.

An HTTP 502 response is expected under the normal laboratory configuration.

Check Nginx's own health:

```bash
curl -i http://127.0.0.1:8270/gateway-health
```

**Expected result:**

The gateway's local endpoint continues to respond.

**Objective:**

Demonstrate that reverse proxy availability and upstream application availability are different properties.

---

# 75. EXPERIMENT 16 — DIAGNOSE THE GATEWAY FAILURE

Execute:

```bash
docker compose ps -a
```

Then:

```bash
docker compose logs --tail 30 gateway
```

Then:

```bash
docker compose logs --tail 30 web
```

**Objective:**

Identify the actual cause of the gateway response failure.

**Required conclusion:**

The web service has been intentionally stopped.

The gateway itself remains active.

**Recovery:**

```bash
docker compose start web
```

Verify:

```bash
curl -i http://127.0.0.1:8270/health/live
```

---

# 76. EXPERIMENT 17 — INTRODUCE REDIS DEPENDENCY FAILURE

Execute:

```bash
docker compose stop redis
```

Now request:

```bash
curl -i http://127.0.0.1:8270/health/live
```

Then:

```bash
curl -i http://127.0.0.1:8270/health/ready
```

Then:

```bash
curl -i http://127.0.0.1:8270/api/count
```

**Objective:**

Observe the difference between process liveness and application readiness.

**Expected result:**

The liveness endpoint may remain successful.

The readiness and counter endpoints report the unavailable Redis dependency.

---

# 77. EXPERIMENT 18 — CORRELATE REDIS FAILURE EVIDENCE

Execute:

```bash
docker compose ps -a
```

Then:

```bash
docker compose logs --timestamps --tail 40 web
```

Then:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{json .State.Health}}'
```

**Objective:**

Correlate dependency failure with application logs and health-check state.

**Required analysis:**

Explain why the web container can remain running while its health status becomes unhealthy.

**Recovery:**

```bash
docker compose start redis
```

Verify:

```bash
docker compose exec redis redis-cli PING
```

Then verify the web readiness endpoint.

---

# 78. EXPERIMENT 19 — INTRODUCE AN INVALID REDIS HOSTNAME

Apply the fault configuration:

```bash
docker compose \
  -f compose.yaml \
  -f faults/bad-redis-host.yaml \
  up -d
```

Inspect:

```bash
docker compose \
  -f compose.yaml \
  -f faults/bad-redis-host.yaml \
  config
```

**Objective:**

Change the Flask container's Redis hostname.

**Expected result:**

Flask starts with:

```text
REDIS_HOST=redis-host-does-not-exist
```

The web readiness check fails because the configured hostname does not identify the Redis service.

---

# 79. EXPERIMENT 20 — DIAGNOSE THE INVALID HOSTNAME

Execute:

```bash
docker compose exec web printenv REDIS_HOST
```

Then:

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('redis-host-does-not-exist'))"
```

**Expected result:**

The hostname lookup fails.

Check:

```bash
curl -i http://127.0.0.1:8270/health/ready
```

**Expected result:**

HTTP 503.

**Required analysis:**

Explain why restarting the same incorrectly configured container would not correct the hostname.

**Recovery:**

```bash
docker compose up -d
```

Verify the effective `REDIS_HOST` value and successful readiness.

---

# 80. EXPERIMENT 21 — INTRODUCE THE LOCALHOST ERROR

Apply:

```bash
docker compose \
  -f compose.yaml \
  -f faults/localhost-redis.yaml \
  up -d
```

Inspect:

```bash
docker compose exec web printenv REDIS_HOST
```

**Expected result:**

```text
localhost
```

**Objective:**

Demonstrate incorrect use of container loopback for a dependency running in another container.

**Expected result:**

Flask cannot reach Redis through its own loopback interface.

**Required analysis:**

Explain why the correct hostname is `redis`.

**Recovery:**

```bash
docker compose up -d
```

---

# 81. EXPERIMENT 22 — DISCONNECT A CONTAINER NETWORK

Record the normal network state:

```bash
docker network inspect lecture17-diagnostics_backend
```

Now disconnect the web container from the backend network:

```bash
docker network disconnect \
  lecture17-diagnostics_backend \
  "$(docker compose ps -q web)"
```

**Objective:**

Introduce a controlled network attachment failure.

**Expected result:**

Flask loses its direct backend-network access to Redis.

**Important note:**

This deliberately changes a resource managed by Compose outside the Compose configuration process.

Such manual runtime drift should be corrected deliberately.

---

# 82. EXPERIMENT 23 — DIAGNOSE THE NETWORK FAILURE

Inspect the web container's current networks:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{json .NetworkSettings.Networks}}'
```

Inspect Redis:

```bash
docker network inspect lecture17-diagnostics_backend
```

Test:

```bash
curl -i http://127.0.0.1:8270/health/ready
```

**Expected result:**

Redis readiness fails.

**Required analysis:**

Explain why the application hostname may be correct while the service still cannot communicate with Redis.

**Recovery:**

Recreate the web service from the declared Compose model:

```bash
docker compose up -d --force-recreate web
```

Verify that the web service is again attached to the backend network.

---

# 83. EXPERIMENT 24 — INTRODUCE A WRONG COUNTER KEY

Record the current counter:

```bash
docker compose exec redis redis-cli GET lecture17:counter
```

Apply the fault:

```bash
docker compose \
  -f compose.yaml \
  -f faults/wrong-counter-key.yaml \
  up -d
```

Now request:

```bash
curl http://127.0.0.1:8270/api/count
```

**Expected result:**

The application may return zero because the new key does not exist.

**Objective:**

Demonstrate an apparent data-loss symptom caused by application configuration.

---

# 84. EXPERIMENT 25 — INVESTIGATE APPARENT DATA LOSS

Inspect the effective key:

```bash
docker compose exec web printenv COUNTER_KEY
```

Query both keys:

```bash
docker compose exec redis redis-cli GET lecture17:counter
```

```bash
docker compose exec redis redis-cli GET lecture17:wrong-counter
```

**Objective:**

Verify whether the original data still exists.

**Required conclusion:**

The original counter remains stored under its original Redis key.

The application was instructed to query a different key.

**Recovery:**

```bash
docker compose up -d
```

Verify that the original count is visible again.

---

# 85. EXPERIMENT 26 — INVESTIGATE COMPOSE PROJECT IDENTITY

Create a separate disposable Redis-only project:

```bash
docker compose -p lecture17-alternative up -d redis
```

Query its counter:

```bash
docker compose -p lecture17-alternative exec redis redis-cli GET lecture17:counter
```

**Expected result:**

The new Redis instance ordinarily has no counter value.

**Objective:**

Demonstrate that a different Compose project name can result in a different named volume.

Inspect:

```bash
docker volume ls
```

**Required analysis:**

Explain why data in the original project has not necessarily been deleted.

**Cleanup of the disposable alternative project:**

```bash
docker compose -p lecture17-alternative down -v
```

This command targets the deliberately created alternative project.

Do not use it against the main laboratory project, whose persistent data is still required.

---

# 86. EXPERIMENT 27 — INTRODUCE A CONTROLLED PORT CONFLICT

First ensure that host port 8271 is available.

Create a temporary port-occupying container:

```bash
docker run -d \
  --name lecture17-port-blocker \
  -p 127.0.0.1:8271:80 \
  nginx:alpine
```

**Objective:**

Occupy the host port that will be requested by the gateway.

On a Unix-like shell, attempt:

```bash
WEB_PORT=8271 docker compose up -d gateway
```

**Expected result:**

Compose cannot successfully bind the gateway to the already occupied host endpoint.

**Required analysis:**

Explain why this problem concerns host port allocation rather than Redis or internal Docker DNS.

---

# 87. EXPERIMENT 28 — RESTORE THE PORT CONFIGURATION

Remove the temporary blocker:

```bash
docker stop lecture17-port-blocker
```

```bash
docker rm lecture17-port-blocker
```

Restore the base application:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

Then:

```bash
curl -i http://127.0.0.1:8270/gateway-health
```

**Objective:**

Demonstrate recovery from a port allocation conflict.

**Required analysis:**

Explain how an environment variable changes the requested host binding.

---

# 88. EXPERIMENT 29 — INSPECT CONTAINER FILESYSTEM CHANGES

Create a temporary marker inside the web container:

```bash
docker compose exec web sh -c 'echo diagnostic-marker > /tmp/lecture17-marker'
```

Inspect changes:

```bash
docker diff "$(docker compose ps -q web)"
```

**Objective:**

Observe the container writable-layer differences.

**Expected result:**

The diagnostic marker appears among the relevant filesystem changes.

**Required analysis:**

Explain why this command does not provide a complete history of mounted Redis volume modifications.

---

# 89. EXPERIMENT 30 — COPY A DIAGNOSTIC ARTIFACT

Execute:

```bash
docker cp \
  "$(docker compose ps -q web)":/tmp/lecture17-marker \
  ./evidence/marker.txt
```

Inspect:

```bash
cat ./evidence/marker.txt
```

**Objective:**

Retrieve a non-sensitive artifact from the container for evidence preservation.

**Required analysis:**

Explain why evidence collection should occur before recreating a container when its writable-layer files are relevant.

---

# 90. EXPERIMENT 31 — EXAMINE LOGGING CONFIGURATION

Execute:

```bash
docker inspect "$(docker compose ps -q web)" --format '{{.HostConfig.LogConfig.Type}}'
```

Then:

```bash
docker logs --tail 20 "$(docker compose ps -q web)"
```

**Objective:**

Identify the selected Docker logging driver and verify local log retrieval.

**Required analysis:**

Explain why logging-driver configuration affects how diagnostic records are stored and retrieved.

---

# 91. EXPERIMENT 32 — INSPECT DISK USAGE

Execute:

```bash
docker system df
```

Then:

```bash
docker system df -v
```

**Objective:**

Inspect Docker-managed storage usage.

**Required analysis:**

Distinguish the space associated with images, containers, volumes, and build caches.

No disk cleanup is required for this experiment.

---

# 92. EXPERIMENT 33 — VERIFY DATA PERSISTENCE

Request an explicit Redis snapshot:

```bash
docker compose exec redis redis-cli SAVE
```

Remove the main application without deleting volumes:

```bash
docker compose down
```

Inspect:

```bash
docker volume inspect lecture17-diagnostics_redis-data
```

Recreate the application:

```bash
docker compose up -d
```

Retrieve:

```bash
docker compose exec redis redis-cli GET lecture17:counter
```

**Objective:**

Verify that the original named Redis volume retains recoverable data.

**Required analysis:**

Explain why ordinary Compose teardown and recreation do not automatically delete the named volume.

---

# 93. EXPERIMENT 34 — COLLECT A FINAL DIAGNOSTIC SNAPSHOT

Execute:

```bash
docker compose config
```

```bash
docker compose ps -a
```

```bash
docker compose logs --timestamps --tail 30
```

```bash
docker network inspect lecture17-diagnostics_frontend
```

```bash
docker network inspect lecture17-diagnostics_backend
```

```bash
docker volume inspect lecture17-diagnostics_redis-data
```

**Objective:**

Verify that the complete application has returned to its intended configuration.

**Required conclusion:**

The three services are available.

The expected networks exist.

The Redis volume remains available.

The counter operates correctly.

---

# 94. EXPERIMENT 35 — CONTROLLED LABORATORY CLEANUP

Before cleanup, confirm that all required evidence has been collected.

Remove the main Compose application:

```bash
docker compose down
```

Remove the controlled process-exit probe:

```bash
docker rm lecture17-exit-probe
```

The original Redis named volume remains available.

**Optional destructive cleanup:**

Only if the laboratory data is no longer required, remove the specific named volume after confirming no container references it:

```bash
docker volume rm lecture17-diagnostics_redis-data
```

**Critical warning:**

The optional command deletes the Redis laboratory data.

Do not execute broad pruning operations against unrelated Docker resources.

---

# PART XI — LABORATORY EVIDENCE AND ASSESSMENT

# 95. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Diagnostic focus | Observation |
|---|---|---|
| 1 | Docker environment | |
| 2 | Project creation | |
| 3 | Compose validation | |
| 4 | Application startup | |
| 5 | Baseline functionality | |
| 6 | Redis counter creation | |
| 7 | Service states | |
| 8 | Timestamped logs | |
| 9 | Container inspection | |
| 10 | Health inspection | |
| 11 | Resource metrics | |
| 12 | Process inspection | |
| 13 | Controlled exit code | |
| 14 | Docker events | |
| 15 | Gateway failure | |
| 16 | Gateway diagnosis | |
| 17 | Redis dependency failure | |
| 18 | Failure evidence | |
| 19 | Invalid Redis hostname | |
| 20 | DNS diagnosis | |
| 21 | Localhost configuration error | |
| 22 | Network disconnection | |
| 23 | Network fault recovery | |
| 24 | Wrong counter key | |
| 25 | Data-loss diagnosis | |
| 26 | Project identity | |
| 27 | Port conflict | |
| 28 | Port conflict recovery | |
| 29 | Filesystem changes | |
| 30 | Evidence retrieval | |
| 31 | Logging driver | |
| 32 | Docker disk usage | |
| 33 | Persistent data recovery | |
| 34 | Final system verification | |
| 35 | Controlled cleanup | |

---

# 96. LABORATORY CONCLUSION

Prepare a 400–600-word technical conclusion addressing:

1. Why a symptom is not equivalent to a root cause.
2. How container states and exit codes contribute to diagnosis.
3. Why exit code 137 should not automatically be interpreted as OOM.
4. How logs and Docker events complement each other.
5. Why health checks and process states must be examined separately.
6. How network attachment failures differ from incorrect service hostnames.
7. Why a port conflict differs from internal container networking failure.
8. How a changed Redis key can resemble data loss.
9. Why Compose project identity matters for named volumes.
10. Why preserving evidence before container recreation is important.
11. How successful recovery should be verified.
12. Why safe troubleshooting requires controlled changes.

---

# PART XII — ADDITIONAL OPERATIONAL CASE STUDIES

# 97. CASE STUDY 1 — EXITED CONTAINER

An application container exits immediately after startup.

The administrator sees:

```text
Exited (1)
```

Possible explanations include:

- Application exception.
- Missing dependency.
- Invalid startup command.
- Incorrect configuration.
- Permission failure.

**Required procedure:**

1. Inspect the exit code.
2. Retrieve application logs.
3. Inspect the image command and entrypoint.
4. Verify environment configuration.
5. Identify the actual cause.
6. Apply the correction.
7. Recreate or restart the container as appropriate.

---

# 98. CASE STUDY 2 — EXIT CODE 137

A container exits with code 137.

The administrator assumes it was killed by the OOM system.

**Required analysis:**

Explain why this assumption is not sufficiently supported.

Investigate:

- OOMKilled state.
- Docker events.
- Container memory configuration.
- Relevant host conditions.
- Administrative signals.

Distinguish confirmed evidence from possible causes.

---

# 99. CASE STUDY 3 — HTTP 502

Nginx returns HTTP 502.

Its own gateway-health endpoint continues returning HTTP 200.

**Required analysis:**

Explain why the gateway can remain healthy while the application request fails.

Investigate:

- Flask container state.
- Upstream hostname.
- Upstream port.
- Docker network attachments.
- Nginx error logs.

---

# 100. CASE STUDY 4 — HTTP 503

Flask returns HTTP 503.

The Redis container appears to be running.

**Required analysis:**

Explain why process existence does not guarantee successful application communication.

Investigate:

- Redis health.
- Network connectivity.
- Service hostname.
- Redis listening port.
- Application logs.
- Effective environment variables.

---

# 101. CASE STUDY 5 — MISSING DATA

A newly deployed Flask container displays a counter value of zero.

The administrator concludes that the Redis database was deleted.

However, Redis still contains the original counter key.

**Required analysis:**

Explain how application configuration can produce this symptom.

Describe a safe investigation that avoids modifying the original data.

---

# 102. CASE STUDY 6 — DISK-SPACE EXHAUSTION

Docker Engine reports insufficient storage.

The environment contains:

- Several old images.
- Build cache.
- Active named volumes.
- Container logs.

**Required analysis:**

Explain how to inspect Docker disk usage.

Identify which categories may be candidates for controlled cleanup.

Explain why deleting all unused volumes without inspection may destroy valuable data.

---

# 103. CASE STUDY 7 — PERMISSION DENIED

A non-root application receives:

```text
Permission denied.
```

when attempting to write to a mounted directory.

**Required analysis:**

Consider:

- Container UID and GID.
- Host filesystem ownership.
- Mount read/write status.
- User namespace mapping.
- Read-only filesystem settings.
- Application target path.

Explain why privileged mode is not an appropriate default solution.

---

# PART XIII — FORMAL ACADEMIC EXAMINATION

# 104. PART A — TECHNICAL DEFINITIONS

Provide academically precise definitions for:

1. Troubleshooting.
2. Root-cause analysis.
3. Symptom.
4. Diagnostic hypothesis.
5. Container exit code.
6. SIGTERM.
7. SIGKILL.
8. Out-of-memory termination.
9. Container health check.
10. Docker logging driver.
11. Docker event.
12. Container resource metric.
13. DNS resolution.
14. Connection refusal.
15. Connection timeout.
16. Port conflict.
17. Named volume.
18. Filesystem diff.
19. Configuration drift.
20. Incident report.

---

# 105. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why restarting a container is not always an appropriate first troubleshooting action.

**Question 2.**

Describe the relationship between a container's principal process and its exit code.

**Question 3.**

Explain why exit code 137 does not necessarily prove out-of-memory termination.

**Question 4.**

Describe the purpose of `docker inspect`.

**Question 5.**

Explain the difference between `docker logs` and `docker compose logs`.

**Question 6.**

Describe the role of Docker logging drivers.

**Question 7.**

Explain why Docker events are useful for reconstructing container lifecycle transitions.

**Question 8.**

Describe what information is available through `docker stats`.

**Question 9.**

Explain the differences between `docker top` and `docker exec`.

**Question 10.**

Describe the purpose of `docker diff`.

**Question 11.**

Explain why DNS resolution success does not guarantee successful TCP communication.

**Question 12.**

Describe the likely meaning of HTTP 502 and HTTP 503 in a reverse-proxy application.

**Question 13.**

Explain how incorrect environment variables can cause application failures.

**Question 14.**

Explain why a changed Compose project name can affect which named volume is used.

**Question 15.**

Describe why diagnostic evidence should be preserved before deleting failed containers.

---

# 106. PART C — COMMAND INTERPRETATION

Consider:

```bash
docker inspect example --format '{{.State.ExitCode}}'
```

Answer:

1. Which information is requested?
2. Does the value alone prove the root cause?
3. What additional evidence may be required?

Consider:

```bash
docker logs --since 10m --tail 30 example
```

Answer:

4. What does `--since` mean?
5. What does `--tail` mean?
6. Why are these options useful during incidents?

Consider:

```bash
docker stats --no-stream
```

Answer:

7. What information is displayed?
8. Why should the observation be interpreted cautiously?

Consider:

```bash
docker network inspect lecture17-diagnostics_backend
```

Answer:

9. What Docker object is inspected?
10. How can the output help diagnose a Redis connectivity problem?

Consider:

```bash
docker compose down -v
```

Answer:

11. Which resource categories may be removed?
12. Why is the command potentially destructive?
13. What evidence should be preserved before using such an operation?

---

# 107. PRACTICAL EXAMINATION

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Diagnostic methodology and theory | 15 |
| Container state and exit-code analysis | 15 |
| Logs and Docker events | 15 |
| Resource and filesystem inspection | 10 |
| Network and HTTP troubleshooting | 20 |
| Storage and configuration troubleshooting | 15 |
| Incident documentation | 10 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

A correct repair without an evidence-based explanation does not receive full marks.

The student must demonstrate:

1. Symptom identification.
2. Hypothesis development.
3. Selection of appropriate tests.
4. Accurate interpretation.
5. Controlled correction.
6. Verification of recovery.

---

# 108. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Evidence-Based Troubleshooting of Docker and Compose Applications

Prepare a technical report of approximately 1,500–2,000 words addressing:

**“Systematic Root-Cause Analysis in Containerized Applications: Lifecycle Events, Logs, Health Monitoring, Networking, Storage, and Configuration Failure.”**

The report must include:

1. Introduction to container troubleshooting.
2. Symptom classification.
3. Root-cause analysis methodology.
4. Container lifecycle and exit codes.
5. Docker inspection.
6. Application logging.
7. Docker logging drivers.
8. Docker Engine events.
9. Health monitoring.
10. Resource inspection.
11. Process inspection.
12. Networking and DNS troubleshooting.
13. HTTP error analysis.
14. Storage and volume diagnosis.
15. Environment configuration.
16. Controlled failure experiments.
17. Recovery verification.
18. Evidence preservation.
19. Operational safety considerations.
20. Technical conclusion.

The report should contain:

- A diagnostic flowchart.
- An application architecture diagram.
- A table of observed incidents.
- Commands used during diagnosis.
- Confirmed causes and verified corrections.

---

# 109. INCIDENT REPORT TEMPLATE

Complete one report for at least three laboratory failures.

## Incident Identifier

Example:

```text
INC-LECTURE17-001
```

## Application

Docker Lecture 17 Diagnostics.

## Reported Symptom

Describe the observed failure.

## Expected Behavior

Describe the correct system behavior.

## Affected Components

Identify the relevant services.

## Evidence

Record:

- Container state.
- Logs.
- Health status.
- Network information.
- Environment configuration.
- Relevant events.

## Hypotheses

List possible explanations.

## Diagnostic Tests

Identify the commands used.

## Confirmed Root Cause

Describe the evidence-supported cause.

## Corrective Action

Record the applied correction.

## Verification

Explain how normal behavior was confirmed.

## Preventive Recommendation

Suggest an improvement that could reduce the likelihood or impact of similar failures.

---

# 110. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 18, verify the following.

## Diagnostic Methodology

- [ ] I can distinguish symptoms from root causes.
- [ ] I can form diagnostic hypotheses.
- [ ] I can select tests that evaluate hypotheses.
- [ ] I can preserve evidence.
- [ ] I can apply controlled corrections.
- [ ] I can verify recovery.

## Container Lifecycle

- [ ] I can list running containers.
- [ ] I can list exited containers.
- [ ] I can identify a restarting container.
- [ ] I can retrieve an exit code.
- [ ] I understand SIGTERM and SIGKILL.
- [ ] I can explain the limitations of exit-code interpretation.
- [ ] I can inspect OOMKilled status.

## Logging

- [ ] I can retrieve container logs.
- [ ] I can follow live logs.
- [ ] I can filter logs by time.
- [ ] I can filter recent log lines.
- [ ] I can retrieve multi-service Compose logs.
- [ ] I understand logging-driver differences.
- [ ] I can correlate log timestamps.

## Events

- [ ] I can inspect Docker events.
- [ ] I can filter events by container.
- [ ] I can identify lifecycle events.
- [ ] I can distinguish Docker events from application logs.
- [ ] I understand event-history limitations.

## Resource Monitoring

- [ ] I can use `docker stats`.
- [ ] I can interpret CPU usage.
- [ ] I can interpret memory usage.
- [ ] I can inspect process counts.
- [ ] I can use `docker top`.
- [ ] I can inspect Docker disk usage.

## Networking

- [ ] I can inspect Docker networks.
- [ ] I can inspect container network attachments.
- [ ] I can test service-name resolution.
- [ ] I understand container loopback.
- [ ] I can distinguish DNS and TCP failures.
- [ ] I can diagnose a port conflict.
- [ ] I understand HTTP 502.
- [ ] I understand HTTP 503.

## Storage

- [ ] I can inspect Docker mounts.
- [ ] I can inspect named volumes.
- [ ] I can explain the container writable layer.
- [ ] I can use `docker diff`.
- [ ] I can use `docker cp`.
- [ ] I can distinguish missing data from wrong application configuration.
- [ ] I can explain Compose volume naming.

## Practical Laboratory

- [ ] I created the complete project.
- [ ] I validated the Compose configuration.
- [ ] I started Nginx, Flask, and Redis.
- [ ] I created Redis application data.
- [ ] I inspected service states.
- [ ] I collected logs.
- [ ] I inspected container health.
- [ ] I measured resource usage.
- [ ] I diagnosed a controlled process exit.
- [ ] I inspected Docker events.
- [ ] I diagnosed an HTTP gateway failure.
- [ ] I diagnosed Redis dependency failure.
- [ ] I diagnosed an invalid hostname.
- [ ] I diagnosed incorrect localhost usage.
- [ ] I diagnosed a network attachment failure.
- [ ] I diagnosed a wrong counter key.
- [ ] I demonstrated Compose project identity effects.
- [ ] I diagnosed a host port conflict.
- [ ] I examined filesystem changes.
- [ ] I copied a diagnostic artifact.
- [ ] I verified persistent data.
- [ ] I restored the complete application.
- [ ] I completed the incident reports.
- [ ] I completed the academic assessment.

**Completion standard:**

The student should be capable of investigating a failing Docker Compose application through an organized, evidence-based method and distinguishing application problems from container, networking, storage, configuration, and host-related failures.

---

# 111. LECTURE SUMMARY

Lecture 17 establishes operational troubleshooting as a systematic engineering discipline.

Containerized applications can fail for many reasons, and the visible symptom often does not identify the underlying cause.

A container exit may result from application failure, termination signals, invalid configuration, or resource conditions.

A running container may be unhealthy because a dependency is unavailable.

An HTTP gateway error may originate from an upstream service rather than from the gateway process itself.

A DNS failure may result from an incorrect hostname or missing network membership.

A database appearing empty may result from a changed application key or Compose project name rather than actual data deletion.

Docker provides several complementary diagnostic interfaces.

`docker ps` and `docker compose ps` expose lifecycle state.

`docker inspect` provides detailed runtime configuration.

`docker logs` and `docker compose logs` expose application output.

`docker events` records selected Docker Engine lifecycle activities.

`docker stats` provides resource measurements.

`docker top` provides process information.

`docker network inspect` provides network configuration.

`docker volume inspect` provides storage metadata.

`docker diff` exposes changes to the container's writable filesystem.

No single command provides the complete explanation for every incident.

Effective troubleshooting requires combining evidence from several sources, developing hypotheses, and testing them in a controlled manner.

The laboratory demonstrates this approach through intentional application, networking, configuration, and storage faults.

Each fault provides an opportunity to identify the symptom, collect relevant evidence, confirm the cause, apply a correction, and verify recovery.

**The central principle of this lecture is that Docker troubleshooting must be based on evidence and controlled verification rather than repeated restarts, arbitrary configuration changes, or assumptions derived from isolated error messages.**

---

# 112. REFERENCES AND RECOMMENDED READING

## Docker Container Inspection

[1] Docker Inc. *Docker Inspect.*  
https://docs.docker.com/reference/cli/docker/inspect/

[2] Docker Inc. *Docker Container LS.*  
https://docs.docker.com/reference/cli/docker/container/ls/

[3] Docker Inc. *Docker Container Wait.*  
https://docs.docker.com/reference/cli/docker/container/wait/

[4] Docker Inc. *Docker Container Top.*  
https://docs.docker.com/reference/cli/docker/container/top/

[5] Docker Inc. *Docker Container Diff.*  
https://docs.docker.com/reference/cli/docker/container/diff/

## Logging and Events

[6] Docker Inc. *Docker Container Logs.*  
https://docs.docker.com/reference/cli/docker/container/logs/

[7] Docker Inc. *Docker Compose Logs.*  
https://docs.docker.com/reference/cli/docker/compose/logs/

[8] Docker Inc. *Configure Logging Drivers.*  
https://docs.docker.com/engine/logging/configure/

[9] Docker Inc. *Docker System Events.*  
https://docs.docker.com/reference/cli/docker/system/events/

[10] Docker Inc. *Docker Compose Events.*  
https://docs.docker.com/reference/cli/docker/compose/events/

## Resource Monitoring

[11] Docker Inc. *Docker Container Stats.*  
https://docs.docker.com/reference/cli/docker/container/stats/

[12] Docker Inc. *Docker System DF.*  
https://docs.docker.com/reference/cli/docker/system/df/

[13] Docker Inc. *Docker System Info.*  
https://docs.docker.com/reference/cli/docker/system/info/

## Networking

[14] Docker Inc. *Docker Networking Overview.*  
https://docs.docker.com/engine/network/

[15] Docker Inc. *Bridge Network Driver.*  
https://docs.docker.com/engine/network/drivers/bridge/

[16] Docker Inc. *Compose Networking.*  
https://docs.docker.com/compose/how-tos/networking/

[17] Docker Inc. *Port Publishing and Mapping.*  
https://docs.docker.com/engine/network/port-publishing/

## Compose and Storage

[18] Docker Inc. *Docker Compose PS.*  
https://docs.docker.com/reference/cli/docker/compose/ps/

[19] Docker Inc. *Docker Compose Config.*  
https://docs.docker.com/reference/cli/docker/compose/config/

[20] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[21] Docker Inc. *Docker Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[22] Docker Inc. *Compose Volumes Reference.*  
https://docs.docker.com/reference/compose-file/volumes/

[23] Redis. *Redis Persistence.*  
https://redis.io/docs/latest/management/persistence/

[24] NGINX. *NGINX Reverse Proxy.*  
https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

## Recommended Reading Sequence

Begin with references [1] through [5] to understand container state inspection.

Continue with references [6] through [10] to develop log and event analysis techniques.

References [11] through [13] explain resource observation and Docker storage usage.

References [14] through [17] provide the networking foundation for diagnosing service connectivity.

Finally, study references [18] through [24] to connect Compose application configuration, persistent storage, and reverse-proxy operation.

---

# 113. FINAL LECTURE CONCLUSION

Operational diagnostics is an essential part of professional Docker engineering.

The ability to build and deploy an application does not guarantee the ability to maintain it under failure conditions.

Production applications operate within complex environments involving processes, networks, filesystems, dependencies, resource limits, and runtime configuration.

Any of these components can introduce failures.

A rigorous troubleshooting method begins with accurate observation.

The engineer establishes expected behavior, collects evidence, and evaluates possible explanations.

Docker provides detailed tools for this purpose.

Container inspection exposes lifecycle and configuration state.

Application logs provide information about software behavior.

Health checks record selected readiness conditions.

Events reveal important runtime transitions.

Resource statistics help identify utilization and constraint problems.

Network inspection reveals service connectivity and attachment configuration.

Volume inspection clarifies persistent storage identity and mounting behavior.

These sources of evidence must be considered together.

For example, a running Flask container does not prove that Redis is available.

A successful DNS lookup does not establish successful application communication.

An exit code of 137 does not independently prove memory exhaustion.

A persistent volume does not guarantee that the application is using the correct database key.

A successful restart does not prove that a configuration defect has been corrected.

The controlled laboratory demonstrates these distinctions through repeated diagnosis and recovery.

The student introduces individual failures, gathers evidence, identifies the corresponding causes, and restores the application.

The value of these exercises lies not merely in memorizing Docker commands but in developing disciplined engineering judgment.

This judgment becomes increasingly important as containerized applications are deployed through registries, automated pipelines, and production infrastructure.

Lecture 18 will extend the course into image publication, registry authentication, image tagging, digest verification, and controlled software distribution.

---

**END OF LECTURE 17**

**Next Lecture:** Lecture 18 — Docker Registries and Image Distribution: Docker Hub, Image Tagging, Authentication, Push and Pull Operations, Registry Security, Digests, and Software Release Management.
