# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 14 — WEEK TWO COMPREHENSIVE REVIEW, TECHNICAL ASSESSMENT, AND MULTI-CONTAINER CAPSTONE PROJECT

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 14 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 6–8 hours  
**Lecture Type:** Comprehensive Review, Practical Capstone, Technical Examination, and Independent Assessment

**Prerequisites:**

- Lecture 01 — Introduction to Docker.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Container Inspection and Diagnostics.
- Lecture 04 — Docker Images and Registries.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Configuration.
- Lecture 07 — Week One Comprehensive Review.
- Lecture 08 — Port Publishing and Runtime Configuration.
- Lecture 09 — Docker Storage and Data Persistence.
- Lecture 10 — Networking and Service Discovery.
- Lecture 11 — Docker Compose Fundamentals.
- Lecture 12 — Flask and Redis Multi-Container Application.
- Lecture 13 — Advanced Docker Compose.

---

# 1. PURPOSE OF THE LECTURE

Lecture 14 concludes the second module of the course.

The objective is to consolidate the principles introduced during Lectures 08–13 and demonstrate their application through the design, construction, operation, and evaluation of an integrated containerized software system.

During Week One, the student studied individual Docker images and containers.

During Week Two, the scope expanded to application architecture involving multiple independently managed components.

The present lecture combines these areas.

The student will design a system consisting of:

1. An Nginx reverse proxy.
2. A Flask application server.
3. A Redis database.
4. Two user-defined Docker networks.
5. A persistent Docker volume.
6. Environment-based configuration.
7. Service health checks.
8. Health-aware startup dependencies.
9. Controlled application recovery.
10. Data backup and restoration procedures.

The capstone also evaluates the student's ability to interpret architectural requirements, investigate failures, and explain the engineering consequences of configuration decisions.

Successful completion should establish the foundational competence required to proceed to production-oriented Docker topics in Week Three.

---

# 2. LEARNING OBJECTIVES

Upon completion of this lecture, the student should be able to:

1. Explain the purpose of Docker port publishing.
2. Distinguish host network endpoints from container network endpoints.
3. Explain the significance of loopback interfaces.
4. Describe the network consequences of binding applications to `0.0.0.0`.
5. Distinguish Dockerfile `EXPOSE` from published ports.
6. Explain runtime environment variable configuration.
7. Distinguish Dockerfile `ARG` and `ENV`.
8. Explain Compose environment interpolation and precedence.
9. Describe the container writable layer.
10. Explain the purpose of Docker named volumes.
11. Distinguish named volumes, anonymous volumes, and bind mounts.
12. Explain the storage requirements of a stateful application.
13. Describe Redis application-level persistence.
14. Explain why persistent storage is not equivalent to backup.
15. Describe Docker network namespaces.
16. Explain user-defined bridge networking.
17. Explain Docker's embedded DNS-based service discovery.
18. Describe the significance of network-scoped service names.
19. Explain network isolation between application components.
20. Construct a multi-network Compose architecture.
21. Define and manage services through Compose.
22. Explain the difference between a Compose project and a container.
23. Construct a Python Flask application.
24. Implement appropriate HTTP GET and POST operations.
25. Integrate Flask with Redis.
26. Explain atomic Redis increments.
27. Configure Nginx as a reverse proxy.
28. Describe the purpose of a reverse proxy.
29. Construct a non-root application image.
30. Configure dependency health checks.
31. Distinguish process liveness from application readiness.
32. Configure startup dependency conditions.
33. Diagnose dependency failures.
34. Inspect running application networks and volumes.
35. Demonstrate data survival across container replacement.
36. Create and inspect a Redis storage backup.
37. Restore database files into an independent volume.
38. Verify application data recovery.
39. Evaluate the security limitations of a training deployment.
40. Complete a formal technical examination and independent project report.

---

# PART I — COMPREHENSIVE WEEK TWO THEORY REVIEW

# 3. REVIEW OF WEEK TWO ARCHITECTURE

Week Two introduced several independent infrastructure concepts.

**Lecture 08:** Port publishing and runtime configuration.

**Lecture 09:** Container storage and persistence.

**Lecture 10:** Networks and service discovery.

**Lecture 11:** Declarative application management through Compose.

**Lecture 12:** Application-level integration using Flask and Redis.

**Lecture 13:** Health checks, dependencies, restart behavior, configuration precedence, and development workflows.

These topics are interconnected.

For example, a web application may require:

- A published port for browser access.
- An internal network for database communication.
- Environment variables for service configuration.
- A Dockerfile for image construction.
- A named volume for database persistence.
- Compose for application lifecycle management.
- Health checks for operational monitoring.

No single Docker mechanism implements all these responsibilities.

A functioning system emerges from their coordinated configuration.

---

# 4. PORTS AND NETWORK ENDPOINTS

## 4.1 Review

A network endpoint identifies an address and transport-layer port.

For example:

```text
127.0.0.1:8240
```

The address identifies the host's IPv4 loopback interface.

The port identifies a transport endpoint.

## 4.2 Host and Container Ports

Docker can associate a host endpoint with a container endpoint.

Example:

```text
127.0.0.1:8240:80
```

The first port is the host port.

The second port is the container port.

The browser communicates with port 8240 on the host.

Docker forwards the traffic to port 80 in the selected container.

## 4.3 Application Listening Address

A containerized application commonly listens on:

```text
0.0.0.0:8000
```

This allows it to accept IPv4 connections through suitable container interfaces.

Binding only to the container's loopback interface may prevent communication from other containers.

## 4.4 Security Principle

Publishing a port without an explicit host IP may expose the service through multiple host interfaces.

For local development, explicit loopback publishing reduces unnecessary exposure.

---

# 5. EXPOSE AND PORT PUBLISHING

## 5.1 EXPOSE

The Dockerfile instruction:

```dockerfile
EXPOSE 8000
```

declares an expected container service port.

It does not publish that port on the host.

## 5.2 Compose ports

The configuration:

```yaml
ports:
  - "127.0.0.1:8240:80"
```

publishes an actual host endpoint.

## 5.3 Internal Communication

Two containers attached to the same appropriate Docker network can communicate directly through their container endpoints.

Such communication does not require host port publishing.

## 5.4 Assessment Principle

The ability to distinguish exposed metadata, internal network connectivity, and externally published ports is a required Week Two competency.

---

# 6. ENVIRONMENT VARIABLES AND APPLICATION CONFIGURATION

## 6.1 Definition

An environment variable is a named value supplied to a process.

Examples include:

```text
APP_MODE=assessment
REDIS_HOST=redis
REDIS_PORT=6379
```

## 6.2 Dockerfile Defaults

The instruction:

```dockerfile
ENV APP_MODE=development
```

establishes a default image environment value.

## 6.3 Runtime Configuration

Compose can supply:

```yaml
environment:
  APP_MODE: assessment
```

The runtime value takes precedence over the image default for the created container.

## 6.4 Configuration Separation

The purpose is to avoid rebuilding application images for every environment-specific setting.

The same image can be configured for development, testing, or staging.

## 6.5 Security Qualification

Environment variables are not an inherently confidential storage mechanism.

Sensitive values may be exposed through inspection, logs, process environments, or operational tooling.

---

# 7. DOCKER COMPOSE INTERPOLATION

## 7.1 Project Configuration

A project may contain:

```text
WEB_PORT=8240
```

inside a `.env` file.

## 7.2 Compose Reference

The Compose model may use:

```yaml
ports:
  - "127.0.0.1:${WEB_PORT:-8240}:80"
```

Compose substitutes the configured value while resolving the application model.

## 7.3 Interpolation Versus Injection

A value used by Compose for interpolation does not automatically become an environment variable inside every container.

A service must explicitly receive the relevant value through its environment configuration.

## 7.4 Verification

Use:

```bash
docker compose config
```

to inspect the resolved model.

Use:

```bash
docker compose exec SERVICE printenv VARIABLE
```

to inspect an effective variable within a running service container.

---

# 8. CONTAINER WRITABLE LAYERS

## 8.1 Definition

A container writable layer stores filesystem modifications associated with a particular container instance.

## 8.2 Restart Behavior

Stopping and restarting the same container ordinarily preserves its writable-layer content.

## 8.3 Removal Behavior

Removing the container ordinarily removes its writable layer.

## 8.4 Architectural Consequence

Important database data should not depend exclusively on an individual container's writable layer.

Persistent application state should use a storage mechanism with an appropriate independent lifecycle.

---

# 9. DOCKER VOLUMES

## 9.1 Definition

A Docker volume is a storage resource managed through Docker's volume subsystem.

## 9.2 Named Volumes

A named volume possesses a stable identifier.

Example:

```text
week2-capstone_redis-data
```

A replacement container can mount the same named volume.

## 9.3 Anonymous Volumes

Anonymous volumes receive automatically generated identifiers.

They can support persistent storage, but deliberate reattachment and management are less convenient without recording their identifiers.

## 9.4 Bind Mounts

Bind mounts expose selected host paths inside containers.

They are useful for development source code, configuration files, and selected host resources.

## 9.5 Selection Principle

Named volumes are often appropriate for Docker-managed database storage.

Bind mounts are useful when host-managed files must be directly available to a container.

---

# 10. PERSISTENCE AND BACKUP

## 10.1 Persistent Storage

Persistence allows data to survive specified process or container lifecycle events.

## 10.2 Backup

A backup is an independently maintained copy of data that can be used for recovery.

## 10.3 Fundamental Distinction

A named volume is not automatically a backup.

Deleting the only volume containing a database can destroy the only available copy of its information.

## 10.4 Recovery Verification

An archive must be tested through an actual restoration procedure.

The existence of a backup file does not alone prove that recovery will succeed.

---

# 11. REDIS PERSISTENCE

## 11.1 Redis Data Model

Redis maintains in-memory application data.

It can write recoverable state to files using supported persistence mechanisms.

## 11.2 RDB Snapshots

RDB persistence creates point-in-time dataset snapshots.

## 11.3 Append-Only Files

AOF persistence records database-changing operations in a form that can be replayed during recovery.

## 11.4 Durability

The configuration:

```text
appendfsync everysec
```

provides periodic synchronization but does not guarantee that every acknowledged write survives every possible failure.

## 11.5 Docker Integration

Redis must write its recoverable files into a mounted persistent storage location.

For this capstone:

```text
/data
```

will be backed by a named Docker volume.

---

# 12. DOCKER NETWORK NAMESPACES

## 12.1 Definition

A Linux network namespace provides an isolated view of networking resources.

## 12.2 Consequence

Two ordinary bridge-networked containers possess separate loopback environments.

The address:

```text
127.0.0.1
```

inside the Flask container ordinarily refers to the Flask container, not the Redis container.

## 12.3 Correct Database Reference

The application should use a hostname associated with Redis's network endpoint.

For this course, that hostname is:

```text
redis
```

---

# 13. USER-DEFINED BRIDGE NETWORKS

## 13.1 Definition

A user-defined bridge network provides Docker-managed networking among attached containers on a Docker Engine host.

## 13.2 Embedded DNS

Docker normally provides automatic name resolution for attached containers on user-defined networks.

## 13.3 Application Benefit

The application can refer to Redis using:

```text
redis:6379
```

instead of hard-coding a dynamically allocated IP address.

## 13.4 Lifecycle Consequence

Container replacement may change the Redis container's IP address.

The logical service name can remain stable.

Existing network connections may still require reconnection.

---

# 14. NETWORK ISOLATION

## 14.1 Architectural Requirement

Not every service requires direct network access to every other service.

For example:

- Nginx must reach Flask.
- Flask must reach Redis.
- Nginx does not need direct access to Redis.
- Redis does not need a published host port.

## 14.2 Network Separation

The capstone will define:

```text
frontend
backend
```

The Nginx service will join `frontend`.

The Flask service will join both networks.

The Redis service will join `backend`.

## 14.3 Architecture

```text
FRONTEND NETWORK → NGINX
FRONTEND NETWORK → FLASK
FLASK → BACKEND NETWORK
BACKEND NETWORK → REDIS
```

The Flask container is attached to two networks.

It is not automatically functioning as a general-purpose router between those networks.

---

# 15. DOCKER COMPOSE

## 15.1 Definition

Docker Compose manages multi-container application resources through a declarative configuration model.

## 15.2 Principal Resources

A Compose file may define:

- Services.
- Networks.
- Volumes.
- Environment configuration.
- Port mappings.
- Health checks.
- Dependencies.
- Build specifications.

## 15.3 Principal Commands

| Command | Purpose |
|---|---|
| `docker compose config` | Validate and render the model |
| `docker compose build` | Build applicable service images |
| `docker compose up -d` | Create and start the application |
| `docker compose ps` | Inspect project containers |
| `docker compose logs` | Retrieve service logs |
| `docker compose exec` | Run commands in existing service containers |
| `docker compose run` | Create one-off service containers |
| `docker compose restart` | Restart existing service containers |
| `docker compose stop` | Stop services |
| `docker compose down` | Remove selected project resources |

## 15.4 Lifecycle Principle

Compose services are logical application definitions.

Containers are runtime instances created according to those definitions.

---

# 16. SERVICE HEALTH CHECKS

## 16.1 Liveness

A liveness check evaluates basic application responsiveness.

## 16.2 Readiness

A readiness check evaluates the application's ability to perform selected required work.

## 16.3 Example

A Flask application may expose:

```text
/health/live
/health/ready
```

The first checks basic HTTP responsiveness.

The second checks Redis connectivity.

## 16.4 Dependency Health

Compose can wait for a dependency to become healthy during startup.

## 16.5 Limitation

Health-check failure does not, by itself, guarantee automatic container restart.

Application error handling remains necessary.

---

# 17. SERVICE DEPENDENCIES

## 17.1 Health-Aware Startup

Example:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

The application service waits for Redis to satisfy its configured health check during applicable startup operations.

## 17.2 Startup Order

For the capstone:

```text
Redis
  |
  v
Flask
  |
  v
Nginx
```

Each dependent service will wait for the relevant dependency to become healthy.

## 17.3 Limitation

Startup ordering does not guarantee that a service remains available throughout the application's lifetime.

A database can fail after the web application has started.

---

# 18. APPLICATION-LEVEL INTEGRATION

## 18.1 Infrastructure Is Not Application Logic

Compose can create containers and networks.

It does not automatically cause Nginx to query Redis or Flask to update database records.

## 18.2 Application Logic

The Flask program must explicitly implement:

- HTTP routes.
- Redis client connections.
- Counter retrieval.
- Counter updates.
- Error handling.

## 18.3 Atomic Updates

Redis `INCR` performs an atomic increment operation.

This avoids the lost-update problem associated with independent GET-and-SET operations under concurrent requests.

---

# 19. INTRODUCTION TO REVERSE PROXIES

## 19.1 Definition

A reverse proxy is a server that receives client requests and forwards them to one or more backend services.

## 19.2 Architectural Role

For this capstone, Nginx serves as the reverse proxy.

The browser communicates with Nginx.

Nginx forwards requests to Flask.

Flask returns the application response.

Nginx forwards that response back to the browser.

## 19.3 Request Path

```text
Browser
   |
   v
Nginx
   |
   v
Flask
   |
   v
Response
   |
   v
Nginx
   |
   v
Browser
```

## 19.4 Benefits

Reverse proxies may provide:

- A centralized HTTP entry point.
- Request forwarding.
- Header management.
- TLS termination in appropriately configured deployments.
- Traffic distribution.
- Separation between client-facing and application services.

## 19.5 Scope

The capstone introduces basic HTTP reverse proxying.

It does not implement production TLS termination or advanced load balancing.

---

# PART II — WEEK TWO CAPSTONE PROJECT

# 20. CAPSTONE PROJECT TITLE

**Containerized Visitor Analytics Portal: A Three-Service Docker Compose Application with Network Segmentation, Persistent Redis State, Nginx Reverse Proxying, and Health Monitoring**

---

# 21. PROJECT SCENARIO

A small organization requires a browser-accessible application that maintains a persistent visit counter.

The system must:

1. Provide a webpage.
2. Allow the user to retrieve the current count.
3. Allow the user to increment the count.
4. Store the count outside the web application's process memory.
5. Preserve the count across container replacement.
6. Separate public-facing and internal services.
7. Avoid exposing Redis directly through the host.
8. Provide application health endpoints.
9. Use environment-based runtime configuration.
10. Support controlled backup and recovery.

The organization has selected Docker Compose to describe and manage the deployment.

---

# 22. FUNCTIONAL REQUIREMENTS

The application must implement the following functionality.

| Requirement | Description |
|---|---|
| FR-01 | Display an HTML web interface |
| FR-02 | Retrieve the current counter value |
| FR-03 | Increment the counter |
| FR-04 | Return JSON API responses |
| FR-05 | Store counter state in Redis |
| FR-06 | Preserve data across container replacement |
| FR-07 | Provide a liveness endpoint |
| FR-08 | Provide a readiness endpoint |
| FR-09 | Display non-sensitive deployment information |
| FR-10 | Permit administrative inspection through Docker CLI |

---

# 23. NONFUNCTIONAL REQUIREMENTS

The application must satisfy the following architectural properties.

| Requirement | Description |
|---|---|
| NFR-01 | Use a declarative Compose configuration |
| NFR-02 | Use separate Nginx, Flask, and Redis services |
| NFR-03 | Publish only the Nginx HTTP endpoint |
| NFR-04 | Bind the published endpoint to host loopback |
| NFR-05 | Use user-defined Docker networks |
| NFR-06 | Isolate Redis from the Nginx-facing network |
| NFR-07 | Run Flask without root privileges |
| NFR-08 | Store Redis data in a named volume |
| NFR-09 | Configure service health checks |
| NFR-10 | Use health-aware startup dependencies |
| NFR-11 | Return controlled errors when Redis is unavailable |
| NFR-12 | Support application recreation without planned data loss |
| NFR-13 | Permit controlled data backup and restoration |

---

# 24. COMPLETE APPLICATION ARCHITECTURE

```text
[ WEB BROWSER ]
[ http://127.0.0.1:8240 ]
[ DOCKER HOST ]
[ PORT PUBLISHING ]
[ NGINX PROXY ]
[ Container :80 ]
[ FRONTEND NETWORK ]
[ FLASK WEB ]
[ GUNICORN ]
[ Container :8000 ]
[ BACKEND NETWORK ]
[ REDIS ]
[ Container :6379 ]
[ /data ]
[ NAMED VOLUME ]
[ redis-data ]
```

The architecture contains three application services and two internal networks.

Only the reverse proxy publishes a host port.

The application and Redis use internal Docker networking.

Redis data is maintained independently of the Redis container's writable layer.

---

# 25. SECURITY ARCHITECTURE

The application uses several controlled design choices.

**Host loopback publishing**

Nginx is published at:

```text
127.0.0.1:8240
```

This is intended for local access.

**Non-root application process**

Flask executes through Gunicorn under a numeric non-root identity.

**No Redis host publishing**

Redis communicates through the backend network.

**Network separation**

Nginx and Redis do not share a Docker network.

**Read-only Nginx configuration mount**

The proxy configuration is mounted from the host as read-only.

**Persistent storage isolation**

Redis uses a named Docker volume.

## Important Limitations

These measures do not make the application production-secure.

The demonstration lacks:

- User authentication.
- Production TLS.
- Redis authentication.
- CSRF protection.
- Public-service rate limits.
- Off-host backup.
- Comprehensive monitoring.

The environment is intended for local academic study.

---

# 26. PROJECT DIRECTORY STRUCTURE

Create the following directory:

```text
docker-week2-capstone/
├── compose.yaml
├── .env
├── .dockerignore
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
└── gateway/
    └── default.conf
```

Each file has a distinct responsibility.

| File | Purpose |
|---|---|
| `compose.yaml` | Application infrastructure |
| `.env` | Compose interpolation values |
| `.dockerignore` | Build-context exclusions |
| `backend/Dockerfile` | Flask image construction |
| `backend/requirements.txt` | Python dependencies |
| `backend/app.py` | HTTP application logic |
| `gateway/default.conf` | Nginx reverse proxy configuration |

---

# 27. PROJECT ENVIRONMENT CONFIGURATION

Create:

`.env`

Insert:

```text
WEB_PORT=8240
APP_TITLE=Week Two Container Engineering Capstone
APP_MODE=assessment
REDIS_KEY=week2:visits
```

## Technical Explanation

`WEB_PORT` selects the host port.

`APP_TITLE` configures the displayed application title.

`APP_MODE` identifies the logical deployment mode.

`REDIS_KEY` determines which Redis key stores the visitor count.

These values are non-sensitive and intended for demonstration.

---

# 28. PYTHON DEPENDENCIES

Create:

`backend/requirements.txt`

Insert:

```text
Flask==3.1.3
redis==6.2.0
gunicorn==26.2.0
```

## Explanation

Flask implements the HTTP application.

The Redis client library implements database communication.

Gunicorn provides the WSGI application server.

The versions are explicitly selected for the laboratory.

For more rigorous reproducibility, transitive dependencies and base-image references would also need appropriate controls.

---

# 29. COMPLETE FLASK APPLICATION

Create:

`backend/app.py`

Insert the following code:

```python
import os

import redis

from flask import Flask, jsonify, render_template_string
from redis.exceptions import RedisError


app = Flask(__name__)


APP_TITLE = os.getenv(
    "APP_TITLE",
    "Week Two Capstone"
)

APP_MODE = os.getenv(
    "APP_MODE",
    "development"
)

REDIS_HOST = os.getenv(
    "REDIS_HOST",
    "redis"
)

REDIS_PORT = int(
    os.getenv("REDIS_PORT", "6379")
)

REDIS_KEY = os.getenv(
    "REDIS_KEY",
    "week2:visits"
)


client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)


HTML_PAGE = """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Week Two Docker Capstone</title>

    <style>

        body {
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            color: #0f172a;
            padding: 40px;
        }

        main {
            max-width: 700px;
            margin: 0 auto;
            padding: 40px;
            background: white;
            border-radius: 14px;
            text-align: center;
        }

        h1 {
            color: #2563eb;
        }

        .counter {
            font-size: 70px;
            font-weight: bold;
            margin: 35px 0;
        }

        button {
            border: none;
            border-radius: 8px;
            padding: 15px 28px;
            background: #2563eb;
            color: white;
            font-size: 17px;
            cursor: pointer;
        }

        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .mode {
            margin-top: 20px;
            color: #64748b;
        }

        #message {
            margin-top: 25px;
        }

    </style>

</head>

<body>

    <main>

        <h1>{{ app_title }}</h1>

        <h2>Docker Week Two Capstone</h2>

        <p>
            Three-Service Containerized Application
        </p>

        <p>
            Nginx + Flask + Redis
        </p>

        <div id="counter" class="counter">...</div>

        <button id="increment">
            Increment Counter
        </button>

        <p id="message"></p>

        <p class="mode">
            Deployment Mode: {{ app_mode }}
        </p>

    </main>

    <script>

        const counterElement =
            document.getElementById("counter");

        const messageElement =
            document.getElementById("message");

        const button =
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
                        data.error || "Service unavailable"
                    );
                }

                counterElement.textContent =
                    String(data.count);

                messageElement.textContent =
                    "Counter retrieved from Redis";

            } catch (error) {

                counterElement.textContent = "--";

                messageElement.textContent =
                    error.message;
            }

        }


        async function incrementCounter() {

            button.disabled = true;

            try {

                const response = await fetch(
                    "/api/increment",
                    { method: "POST" }
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

                button.disabled = false;
            }

        }


        button.addEventListener(
            "click",
            incrementCounter
        );

        loadCounter();

    </script>

</body>

</html>
"""


@app.get("/")
def home():

    return render_template_string(
        HTML_PAGE,
        app_title=APP_TITLE,
        app_mode=APP_MODE
    )


@app.get("/health/live")
def live():

    return jsonify(
        service="flask",
        status="alive"
    ), 200


@app.get("/health/ready")
def ready():

    try:

        client.ping()

        return jsonify(
            status="ready",
            redis="available"
        ), 200

    except RedisError:

        return jsonify(
            status="not_ready",
            redis="unavailable"
        ), 503


@app.get("/api/count")
def get_count():

    try:

        value = client.get(REDIS_KEY)

        count = int(value) if value is not None else 0

        return jsonify(
            count=count
        ), 200

    except RedisError:

        return jsonify(
            error="Database temporarily unavailable"
        ), 503

    except (ValueError, TypeError):

        return jsonify(
            error="Stored counter value is invalid"
        ), 500


@app.post("/api/increment")
def increment_count():

    try:

        count = client.incr(REDIS_KEY)

        return jsonify(
            count=count,
            result="incremented"
        ), 200

    except RedisError:

        return jsonify(
            error="Database temporarily unavailable"
        ), 503


@app.get("/api/info")
def information():

    return jsonify(
        application=APP_TITLE,
        mode=APP_MODE,
        storage="Redis",
        architecture="Nginx-Flask-Redis"
    ), 200
```

---

# 30. FLASK APPLICATION ANALYSIS

## 30.1 Application Object

```python
app = Flask(__name__)
```

creates the Flask application.

## 30.2 Environment Configuration

The application retrieves its Redis hostname, port, key, and display settings from environment variables.

## 30.3 Redis Client

```python
client = redis.Redis(...)
```

creates a client configured to connect to Redis.

## 30.4 Counter Retrieval

The GET endpoint retrieves the existing Redis value.

If the key does not exist, the application returns zero.

## 30.5 Counter Increment

The POST endpoint uses Redis `INCR`.

The update is performed atomically by Redis.

## 30.6 Controlled Failure

If Redis is unavailable, the application returns HTTP 503.

The Flask application process does not necessarily terminate.

## 30.7 Liveness

The liveness endpoint confirms that Flask can respond to a basic HTTP request.

## 30.8 Readiness

The readiness endpoint attempts a Redis connection.

This checks a dependency necessary for the counter functionality.

## 30.9 Data Independence

The Flask application does not store the authoritative counter in its own process memory.

The counter is maintained in Redis.

---

# 31. FLASK DOCKERFILE

Create:

`backend/Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Week Two Capstone" \
      org.opencontainers.image.description="Flask Application Service"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=10001:10001 app.py /app/app.py

USER 10001:10001

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
```

## Analysis

The image uses Python 3.12.

The dependency manifest is copied before application source code to improve build cache reuse.

The application executes under numeric UID and GID 10001.

Gunicorn listens on TCP port 8000.

The `EXPOSE` instruction declares the intended port.

The Compose file will not publish this port directly to the host.

---

# 32. NGINX REVERSE PROXY CONFIGURATION

Create:

`gateway/default.conf`

Insert:

```nginx
server {

    listen 80;

    server_name _;

    resolver 127.0.0.11 valid=10s ipv6=off;

    set $web_service web;

    location / {

        proxy_pass http://$web_service:8000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;

        proxy_set_header X-Real-IP $remote_addr;

        proxy_set_header X-Forwarded-For
                         $proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 3s;

        proxy_read_timeout 10s;

    }

}
```

## 32.1 listen

Nginx listens on container TCP port 80.

## 32.2 resolver

The resolver address identifies Docker's embedded DNS resolver for containers attached to user-defined networks.

## 32.3 Backend Service

The hostname:

```text
web
```

identifies the Flask service on the shared frontend network.

## 32.4 proxy_pass

Nginx forwards HTTP requests to Flask on TCP port 8000.

## 32.5 Proxy Headers

The proxy forwards selected information about the original HTTP request.

Such headers are useful for application and logging behavior.

A production deployment must also define which proxies are trusted before relying on client-provided forwarding information.

## 32.6 Dynamic Name Resolution

Using an Nginx resolver and a variable-based upstream reference permits repeated hostname resolution through Docker DNS.

This helps accommodate changed container IP addresses after service replacement.

It does not eliminate all connection interruptions or guarantee zero-downtime deployment.

---

# 33. DOCKERIGNORE CONFIGURATION

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.gitignore
.env
*.log
*.tmp
*.tar
*.pyc
__pycache__/
.venv/
venv/
backups/
```

The build context used in this project is `./backend`.

Therefore, the corresponding build-context exclusions should also be placed in:

`backend/.dockerignore`

with the following contents:

```dockerignore
__pycache__/
*.pyc
*.log
.venv/
venv/
```

The root `.dockerignore` is not automatically applied when Compose builds from `./backend`; the file inside that build context is the one relevant to the backend image build.

This distinction should be understood and documented.

---

# 34. COMPLETE COMPOSE CONFIGURATION

Create:

`compose.yaml`

Insert:

```yaml
name: week2-capstone

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
      retries: 6
      start_period: 10s

    restart: unless-stopped


  web:
    build:
      context: ./backend
      dockerfile: Dockerfile

    image: week2-capstone-web:v1

    environment:
      APP_TITLE: "${APP_TITLE:-Week Two Capstone}"
      APP_MODE: "${APP_MODE:-assessment}"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      REDIS_KEY: "${REDIS_KEY:-week2:visits}"

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

    restart: unless-stopped


  gateway:
    image: nginx:alpine

    ports:
      - "127.0.0.1:${WEB_PORT:-8240}:80"

    volumes:
      - ./gateway/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      web:
        condition: service_healthy
        restart: true

    networks:
      - frontend

    healthcheck:
      test:
        - CMD-SHELL
        - "wget -q -O /dev/null http://127.0.0.1/health/live || exit 1"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s

    restart: unless-stopped


networks:

  frontend:
    driver: bridge

  backend:
    driver: bridge


volumes:

  redis-data:
```

---

# 35. COMPOSE ARCHITECTURE ANALYSIS

## 35.1 Project Identity

```yaml
name: week2-capstone
```

defines the Compose project.

## 35.2 Redis Service

Redis:

- Uses a public Redis image.
- Stores persistence files in `/data`.
- Uses a named volume.
- Joins the backend network.
- Provides a health check.
- Does not publish a host port.

## 35.3 Web Service

Flask:

- Uses a custom-built image.
- Receives environment variables.
- Joins the frontend and backend networks.
- Waits for Redis to become healthy.
- Provides a readiness health check.
- Does not publish a host port.

## 35.4 Gateway Service

Nginx:

- Uses the official Nginx Alpine image.
- Publishes host port 8240.
- Mounts a host-managed configuration file.
- Joins the frontend network.
- Waits for the Flask service to become healthy.

## 35.5 Network Segmentation

The architecture has two separate Docker networks.

Nginx and Redis do not share direct network membership.

Flask has access to both networks.

## 35.6 Persistent State

The named volume:

```text
week2-capstone_redis-data
```

retains Redis persistence files independently of container recreation.

---

# PART III — CAPSTONE PRACTICAL LABORATORY

# 36. EXPERIMENT 1 — VERIFY DOCKER AVAILABILITY

Execute:

```bash
docker version
```

Then:

```bash
docker compose version
```

**Objective:**

Confirm that Docker Engine and Docker Compose are available.

**Required observations:**

1. Docker client version.
2. Docker server version.
3. Compose version.
4. Engine accessibility.

---

# 37. EXPERIMENT 2 — CREATE THE PROJECT

Create the required directory structure.

For a Unix-like shell:

```bash
mkdir -p docker-week2-capstone/backend
mkdir -p docker-week2-capstone/gateway
cd docker-week2-capstone
```

Create the files described in Sections 27–34.

**Objective:**

Establish the complete source and configuration environment.

**Required result:**

All files exist under the intended paths.

---

# 38. EXPERIMENT 3 — VALIDATE THE COMPOSE MODEL

Execute:

```bash
docker compose config -q
```

Then:

```bash
docker compose config
```

**Objective:**

Validate the application definition.

**Required observations:**

Identify:

1. Three services.
2. Two networks.
3. One named volume.
4. Published host port.
5. Application environment variables.
6. Dependency conditions.
7. Health checks.

---

# 39. EXPERIMENT 4 — BUILD THE FLASK IMAGE

Execute:

```bash
docker compose build web
```

Verify:

```bash
docker image ls week2-capstone-web
```

**Objective:**

Construct the custom application image.

**Required analysis:**

Explain why Nginx and Redis do not require custom Dockerfile builds in this project.

---

# 40. EXPERIMENT 5 — START THE COMPLETE APPLICATION

Execute:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

**Objective:**

Start the complete application stack.

**Expected behavior:**

Redis starts first.

Flask starts after Redis satisfies its health check.

Nginx starts after Flask satisfies its health check.

**Required analysis:**

Explain why startup order matters in this particular application.

---

# 41. EXPERIMENT 6 — ACCESS THE WEB APPLICATION

Open:

http://127.0.0.1:8240

**Objective:**

Verify the browser-to-Nginx-to-Flask communication path.

**Expected result:**

The application displays:

**Week Two Container Engineering Capstone**

A counter value appears.

If no existing counter data is present, the value should initially be zero.

---

# 42. EXPERIMENT 7 — TEST THE READ API

Open:

http://127.0.0.1:8240/api/count

**Expected response for a new database:**

```json
{
  "count": 0
}
```

**Objective:**

Verify that the HTTP GET endpoint retrieves the Redis value without modifying it.

---

# 43. EXPERIMENT 8 — TEST THE INCREMENT API

Use the browser's increment button.

Alternatively, execute:

```bash
curl -i -X POST http://127.0.0.1:8240/api/increment
```

**Objective:**

Demonstrate the complete state-changing operation.

**Expected result:**

A JSON response containing the new counter value.

**Required analysis:**

Trace the request through:

1. Browser or HTTP client.
2. Nginx.
3. Gunicorn.
4. Flask.
5. Redis.
6. Response path.

---

# 44. EXPERIMENT 9 — VERIFY REDIS STORAGE

Execute:

```bash
docker compose exec redis redis-cli GET week2:visits
```

**Objective:**

Verify that Redis maintains the counter.

**Required analysis:**

Explain why the authoritative counter is not stored in the Flask container's writable layer.

---

# 45. EXPERIMENT 10 — INSPECT SERVICE LOGS

Execute:

```bash
docker compose logs --tail 30 gateway
```

Then:

```bash
docker compose logs --tail 30 web
```

Then:

```bash
docker compose logs --tail 30 redis
```

**Objective:**

Inspect the different application components.

**Required analysis:**

Explain what diagnostic information each service contributes.

---

# 46. EXPERIMENT 11 — INSPECT NETWORK MEMBERSHIP

Execute:

```bash
docker network inspect week2-capstone_frontend
```

Then:

```bash
docker network inspect week2-capstone_backend
```

**Objective:**

Examine the two network environments.

**Expected membership:**

| Network | Services |
|---|---|
| frontend | gateway, web |
| backend | web, redis |

**Required analysis:**

Explain why the web service is attached to two networks.

---

# 47. EXPERIMENT 12 — VERIFY INTERNAL SERVICE DISCOVERY

Execute:

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('redis'))"
```

**Objective:**

Demonstrate DNS resolution of the Redis service.

**Expected result:**

An IP address associated with the Redis endpoint.

**Required analysis:**

Explain why the application should use the hostname `redis` instead of hard-coding this IP address.

---

# 48. EXPERIMENT 13 — VERIFY NGINX-TO-FLASK COMMUNICATION

Execute:

```bash
docker compose exec gateway wget -q -O - http://web:8000/health/live
```

**Objective:**

Verify that Nginx can reach Flask over the frontend network.

**Expected result:**

A successful JSON response from the Flask liveness endpoint.

**Required analysis:**

Explain why host port 8240 is not required for this internal request.

---

# 49. EXPERIMENT 14 — EXAMINE REDIS NETWORK ISOLATION

Execute:

```bash
docker compose exec gateway sh -c 'nslookup redis'
```

**Objective:**

Investigate service discovery from the Nginx network environment.

**Expected result:**

Under ordinary Docker network-scoped DNS behavior, Nginx cannot resolve the Redis container through Docker's internal service name because they do not share a network.

**Required analysis:**

Explain why the gateway should not require direct network membership in the backend network.

**Important qualification:**

A name-resolution failure is evidence about DNS discovery, not a complete proof of every possible network isolation property.

Advanced host routing and network configuration can affect broader reachability.

---

# 50. EXPERIMENT 15 — VERIFY PORT PUBLICATION

Execute:

```bash
docker compose ps
```

**Objective:**

Identify the published and internal ports.

**Expected observations:**

- Nginx publishes host port 8240.
- Flask uses internal port 8000.
- Redis uses internal port 6379.
- Flask and Redis do not publish host ports.

**Required analysis:**

Explain why publishing only Nginx reduces unnecessary external service exposure.

---

# 51. EXPERIMENT 16 — TEST LIVENESS AND READINESS

Execute:

```bash
curl -i http://127.0.0.1:8240/health/live
```

Then:

```bash
curl -i http://127.0.0.1:8240/health/ready
```

**Objective:**

Compare the health endpoints.

**Expected result:**

Both should return HTTP 200 while the application is functioning normally.

**Required analysis:**

Explain what each endpoint actually tests.

---

# 52. EXPERIMENT 17 — TEST COUNTER CONCURRENCY

First retrieve the current value:

```bash
curl http://127.0.0.1:8240/api/count
```

Record the result.

Now execute the following from inside the Flask container:

```bash
docker compose exec web python -c "from concurrent.futures import ThreadPoolExecutor; import urllib.request; request=lambda _: urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8000/api/increment', method='POST'), timeout=5).read(); list(ThreadPoolExecutor(max_workers=5).map(request, range(20))); print('20 increments completed')"
```

Retrieve the counter again.

**Objective:**

Test concurrent Redis increment operations.

**Expected result:**

If all 20 requests succeed and no other increments occur, the final value should be 20 greater than the initial value.

**Required analysis:**

Explain why `INCR` avoids the lost-update behavior of separate read-and-write operations.

---

# 53. EXPERIMENT 18 — INSPECT THE REDIS VOLUME

Execute:

```bash
docker volume ls
```

Identify:

```text
week2-capstone_redis-data
```

Inspect:

```bash
docker volume inspect week2-capstone_redis-data
```

**Objective:**

Verify that Redis uses Docker-managed persistent storage.

**Required observations:**

1. Volume name.
2. Driver.
3. Mountpoint.
4. Volume metadata.

---

# 54. EXPERIMENT 19 — VERIFY REDIS PERSISTENCE CONFIGURATION

Execute:

```bash
docker compose exec redis redis-cli CONFIG GET appendonly
```

Then:

```bash
docker compose exec redis redis-cli CONFIG GET dir
```

**Objective:**

Verify the Redis persistence settings.

**Expected result:**

Append-only persistence is enabled.

The configured data directory is `/data`.

**Required analysis:**

Explain why both the Redis persistence mechanism and the Docker named volume are necessary.

---

# 55. EXPERIMENT 20 — TEST DEPENDENCY FAILURE

Stop Redis:

```bash
docker compose stop redis
```

Now execute:

```bash
curl -i http://127.0.0.1:8240/health/live
```

Then:

```bash
curl -i http://127.0.0.1:8240/health/ready
```

**Objective:**

Introduce a controlled Redis dependency failure.

**Expected result:**

The Flask liveness endpoint may continue to return HTTP 200.

The readiness endpoint should return HTTP 503.

**Required analysis:**

Explain why a running Flask process can be unable to perform its counter operations.

---

# 56. EXPERIMENT 21 — EXAMINE HEALTH STATUS DURING FAILURE

Execute:

```bash
docker compose ps
```

Inspect the web service's health information.

**Objective:**

Investigate the relationship between process state and application health.

**Expected behavior:**

After enough failed readiness checks, the web container may be classified as unhealthy while its Gunicorn process remains running.

**Required analysis:**

Explain why Docker does not automatically restart a running container solely because its health check fails.

---

# 57. EXPERIMENT 22 — RESTORE REDIS SERVICE

Execute:

```bash
docker compose start redis
```

Verify:

```bash
docker compose exec redis redis-cli PING
```

Expected:

```text
PONG
```

Now execute:

```bash
curl -i http://127.0.0.1:8240/health/ready
```

**Objective:**

Demonstrate application recovery after Redis becomes available.

**Required analysis:**

Explain why Flask can recover without requiring its source code or image to change.

---

# 58. EXPERIMENT 23 — REPLACE THE WEB CONTAINER

Execute:

```bash
docker compose up -d --force-recreate web
```

**Objective:**

Create a replacement Flask container.

Verify:

```bash
docker compose ps
```

Open:

http://127.0.0.1:8240/api/count

**Expected result:**

The existing counter data remains accessible.

**Required analysis:**

Explain why the Redis named volume is independent of the Flask container lifecycle.

---

# 59. EXPERIMENT 24 — REPLACE THE REDIS CONTAINER

Request a snapshot:

```bash
docker compose exec redis redis-cli SAVE
```

Recreate Redis:

```bash
docker compose up -d --force-recreate redis
```

The Compose dependency restart configuration may also cause dependent services to restart during the explicit Compose update.

Verify:

```bash
docker compose ps
```

Then:

```bash
docker compose exec redis redis-cli GET week2:visits
```

**Objective:**

Test replacement of the stateful database container.

**Expected result:**

The previously recorded count remains available.

**Required analysis:**

Explain the relationship between container replacement, Redis persistence, and the named volume.

---

# 60. EXPERIMENT 25 — MODIFY HOST PORT CONFIGURATION

Open `.env`.

Change:

```text
WEB_PORT=8240
```

to:

```text
WEB_PORT=8241
```

Validate:

```bash
docker compose config
```

Apply:

```bash
docker compose up -d
```

Open:

http://127.0.0.1:8241

**Objective:**

Demonstrate environment-based deployment configuration.

**Required analysis:**

Explain why Compose may recreate the gateway container to apply a new host port mapping.

---

# 61. EXPERIMENT 26 — VERIFY DATA AFTER CONFIGURATION CHANGE

Execute:

```bash
curl http://127.0.0.1:8241/api/count
```

**Objective:**

Confirm that changing the externally published gateway endpoint does not require deleting the Redis database.

**Required analysis:**

Identify which configuration changed and which stateful resources remained unchanged.

---

# 62. EXPERIMENT 27 — REMOVE THE APPLICATION NON-DESTRUCTIVELY

Request an explicit Redis snapshot:

```bash
docker compose exec redis redis-cli SAVE
```

Now execute:

```bash
docker compose down
```

Verify the Redis volume:

```bash
docker volume inspect week2-capstone_redis-data
```

**Objective:**

Demonstrate that the application can be removed without automatically deleting its persistent data.

**Required analysis:**

Explain the difference between removing containers and removing the named volume.

---

# 63. EXPERIMENT 28 — RECREATE THE COMPLETE APPLICATION

Execute:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

Retrieve the counter:

```bash
curl http://127.0.0.1:8241/api/count
```

**Objective:**

Reconstruct the application using its declarative Compose configuration.

**Expected result:**

The counter value remains available.

**Required analysis:**

Explain which resources were recreated and which resource retained the data.

---

# PART IV — BACKUP AND RECOVERY ASSESSMENT

# 64. BACKUP DESIGN REQUIREMENTS

The capstone requires evidence that the Redis data can be archived and recovered independently.

The laboratory will use:

1. The original Redis data volume.
2. A separate backup volume.
3. A separate restoration volume.
4. A temporary Alpine archive container.
5. A temporary Redis recovery container.

## Important Qualification

The backup volume is located in the same Docker environment.

This demonstrates the mechanics of backup and restoration.

It does not provide complete protection against host failure.

A production backup must also address off-host copies, access protection, retention, verification, and recovery objectives.

---

# 65. EXPERIMENT 29 — PREPARE A CONSISTENT BACKUP

First ensure Redis is running.

Execute:

```bash
docker compose exec redis redis-cli SAVE
```

Stop and remove the application:

```bash
docker compose down
```

**Objective:**

Establish stable database files before creating a filesystem archive.

**Required analysis:**

Explain why archiving a database while it is modifying several related files can produce an inconsistent backup.

---

# 66. EXPERIMENT 30 — CREATE A BACKUP VOLUME

Execute:

```bash
docker volume create week2-capstone-backup
```

**Objective:**

Create a storage resource for the backup archive.

Verify:

```bash
docker volume inspect week2-capstone-backup
```

---

# 67. EXPERIMENT 31 — ARCHIVE THE REDIS DATA

Execute:

```bash
docker run --rm \
  --mount type=volume,source=week2-capstone_redis-data,target=/source,readonly \
  --mount type=volume,source=week2-capstone-backup,target=/backup \
  alpine:3.20 \
  sh -c 'tar -cf /backup/redis-backup.tar -C /source .'
```

**Objective:**

Create a filesystem archive of the stopped Redis database's persistent files.

**Technical explanation:**

The original volume is mounted read-only.

The backup volume is mounted read-write.

The Alpine container executes `tar`.

The archive is stored in the backup volume.

The temporary Alpine container is removed after completing the operation.

---

# 68. EXPERIMENT 32 — INSPECT THE ARCHIVE

Execute:

```bash
docker run --rm \
  --mount type=volume,source=week2-capstone-backup,target=/backup,readonly \
  alpine:3.20 \
  tar -tf /backup/redis-backup.tar
```

**Objective:**

Verify that the archive exists and contains Redis persistence-related files.

**Required analysis:**

Explain why listing archive contents is useful but does not by itself prove successful database recovery.

---

# 69. EXPERIMENT 33 — CREATE A RESTORATION VOLUME

Execute:

```bash
docker volume create week2-capstone-restore
```

**Objective:**

Create an independent storage destination.

The original Redis data volume must remain unchanged for comparison.

---

# 70. EXPERIMENT 34 — RESTORE THE ARCHIVE

Execute:

```bash
docker run --rm \
  --mount type=volume,source=week2-capstone-backup,target=/backup,readonly \
  --mount type=volume,source=week2-capstone-restore,target=/restore \
  alpine:3.20 \
  sh -c 'tar -xf /backup/redis-backup.tar -C /restore'
```

**Objective:**

Restore the database files into an independent Docker volume.

**Required analysis:**

Explain why restoration into a new volume is preferable to overwriting the original data during an initial recovery test.

---

# 71. EXPERIMENT 35 — VERIFY REDIS RECOVERY

Start a Redis recovery container:

```bash
docker run -d \
  --name week2-restore-check \
  --network none \
  --mount type=volume,source=week2-capstone-restore,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes --dir /data
```

**Objective:**

Load the restored database files in an isolated Redis container.

Check the counter:

```bash
docker exec week2-restore-check redis-cli GET week2:visits
```

**Expected result:**

The previously stored counter value is available.

**Required analysis:**

Explain what the successful result demonstrates about the archive.

Also explain why this still does not establish full disaster-recovery readiness.

---

# 72. EXPERIMENT 36 — CONTROLLED RECOVERY CLEANUP

Stop the recovery container:

```bash
docker stop week2-restore-check
```

Remove it:

```bash
docker rm week2-restore-check
```

Verify:

```bash
docker volume ls
```

The original, backup, and restored data volumes remain available unless deliberately removed.

**Optional destructive cleanup:**

Only after determining that the training data is no longer required, remove individual laboratory volumes.

```bash
docker volume rm week2-capstone_redis-data
```

```bash
docker volume rm week2-capstone-backup
```

```bash
docker volume rm week2-capstone-restore
```

**Critical warning:**

These commands delete stored laboratory data.

Do not execute them if any of the datasets must be preserved.

Avoid broad volume pruning when unrelated Docker data may exist.

---

# PART V — INDEPENDENT ENGINEERING TASKS

# 73. INDEPENDENT TASK 1 — CONFIGURATION ANALYSIS

Without consulting the completed code, explain how the application obtains:

- Its display title.
- Its deployment mode.
- Its Redis hostname.
- Its Redis port.
- Its Redis counter key.
- Its published host port.

For each setting, identify:

1. The configuration source.
2. The software component that interprets it.
3. The effect of changing it.
4. Whether a container must be recreated.

---

# 74. INDEPENDENT TASK 2 — NETWORK SECURITY ANALYSIS

Analyze the two-network architecture.

Explain:

1. Why Nginx joins only the frontend network.
2. Why Redis joins only the backend network.
3. Why Flask joins both networks.
4. Why Redis does not publish a host port.
5. Why network isolation is not equivalent to complete application security.

Prepare a network architecture diagram showing all communication paths.

---

# 75. INDEPENDENT TASK 3 — HEALTH MODEL ANALYSIS

Evaluate the application's three health checks.

For each service, explain:

- The command executed.
- The dependency or endpoint being tested.
- The meaning of a successful result.
- The meaning of a failed result.
- The limitations of the test.

Explain why a healthy gateway does not guarantee that the complete application will remain available indefinitely.

---

# 76. INDEPENDENT TASK 4 — DATA LIFECYCLE ANALYSIS

Construct a data lifecycle diagram showing:

1. Redis memory.
2. Redis persistence operations.
3. Files in `/data`.
4. The named volume.
5. Container replacement.
6. Backup archive creation.
7. Restoration into a new volume.
8. Recovery verification.

Distinguish persistence, backup, and disaster recovery.

---

# 77. INDEPENDENT TASK 5 — CONTROLLED APPLICATION CHANGE

Modify the Flask application so that the HTML page displays a different heading.

Rebuild only the relevant custom application image.

Apply the updated configuration.

Verify that:

1. The new heading appears.
2. Nginx still forwards requests.
3. Redis remains available.
4. The stored counter retains its value.

Explain which Docker resources changed.

---

# PART VI — TROUBLESHOOTING EXAMINATION

# 78. SCENARIO 1 — NGINX RETURNS A BAD GATEWAY RESPONSE

A user receives an HTTP 502 response.

The Nginx container remains running.

Possible causes include:

- Flask is unavailable.
- Flask is not listening on port 8000.
- Nginx cannot resolve the web service.
- The backend connection fails.
- A container was recreated and an old connection is no longer valid.

**Required analysis:**

Identify an appropriate investigation sequence using Compose logs, container status, health checks, and network inspection.

---

# 79. SCENARIO 2 — FLASK CANNOT CONNECT TO REDIS

Flask reports that Redis is unavailable.

The Redis container appears in `docker compose ps`.

**Required analysis:**

Explain why container existence is not sufficient evidence of application readiness.

Investigate:

- Network membership.
- Service hostname.
- Destination port.
- Redis health.
- Redis logs.
- Application error handling.

---

# 80. SCENARIO 3 — REDIS DATA DISAPPEARS

The application is recreated.

The counter value is zero.

**Possible causes:**

1. Different named volume.
2. Changed Compose project name.
3. Data volume deletion.
4. Redis persistence disabled.
5. Incorrect Redis data directory.
6. Different Redis key.
7. Persistence file recovery failure.

**Required analysis:**

Explain how to distinguish these causes without immediately deleting or modifying the remaining data.

---

# 81. SCENARIO 4 — PORT ALLOCATION FAILURE

Docker reports that host port 8240 is already allocated.

**Required analysis:**

Explain:

1. Why the conflict occurs.
2. Which service publishes the port.
3. Why Redis and Flask internal ports are not the source of this host binding conflict.
4. How an alternate host port can be selected safely.

---

# 82. SCENARIO 5 — HEALTH CHECK IS UNHEALTHY

The Flask container remains running.

Its health check reports unhealthy.

**Required analysis:**

Explain the difference between:

- Process execution.
- Liveness.
- Readiness.
- Runtime restart policy.
- Compose dependency configuration.

Describe an appropriate diagnostic procedure.

---

# 83. SCENARIO 6 — INCORRECT CONTAINER LOOPBACK CONFIGURATION

The Flask server binds only to:

```text
127.0.0.1:8000
```

Nginx attempts to connect to:

```text
web:8000
```

The connection fails.

**Required analysis:**

Explain why the Flask server must listen on an appropriate container network interface.

Describe the significance of:

```text
0.0.0.0:8000
```

---

# 84. SCENARIO 7 — APPLICATION REBUILD DOES NOT CHANGE THE PAGE

A developer modifies `backend/app.py`.

The browser continues displaying the old application interface.

**Required analysis:**

Investigate:

1. Whether the image was rebuilt.
2. Whether the web container was recreated.
3. Whether the correct source file was modified.
4. Whether a browser cache is involved.
5. Whether Nginx continues forwarding to the intended backend.

---

# 85. SCENARIO 8 — BACKUP EXISTS BUT RESTORE FAILS

An administrator creates a Redis archive.

The archive file exists.

A recovery container cannot load the restored data.

**Possible causes:**

- Inconsistent archive.
- Missing files.
- Incorrect restoration directory.
- Insufficient permissions.
- Incompatible Redis version.
- Damaged archive.

**Required analysis:**

Explain why backup verification must include actual restoration and application-level data checks.

---

# PART VII — WEEK TWO TERMINOLOGY REVIEW

# 86. ACADEMIC GLOSSARY

| Term | Definition |
|---|---|
| TCP | Reliable, connection-oriented transport protocol |
| UDP | Datagram-oriented transport protocol |
| IP address | Network-layer addressing identifier |
| Port | Transport-layer endpoint identifier |
| Host port | Published port in the Docker host environment |
| Container port | Port used by an application inside its container |
| Port publishing | Host-to-container endpoint mapping |
| EXPOSE | Declaration of an expected container port |
| Environment variable | Named configuration value supplied to a process |
| ARG | Dockerfile build-time argument |
| ENV | Dockerfile environment variable instruction |
| Runtime configuration | Settings supplied when a container is created |
| Interpolation | Substitution of variables into a configuration model |
| Configuration precedence | Rules selecting effective values from multiple sources |
| Writable layer | Container-specific filesystem modification layer |
| Named volume | Docker-managed storage with an explicit identifier |
| Anonymous volume | Docker-managed storage with a generated identifier |
| Bind mount | Mapping of a selected host filesystem path |
| tmpfs | Temporary memory-backed filesystem mount |
| Data persistence | Retention of data beyond selected process lifecycles |
| RDB | Redis point-in-time persistence mechanism |
| AOF | Redis append-only persistence mechanism |
| Backup | Recoverable independent copy of data |
| Restoration | Reconstruction of data from a backup |
| Network namespace | Isolated Linux network environment |
| Bridge network | Network connecting selected container endpoints |
| Embedded DNS | Docker-managed service-name resolution |
| Service discovery | Locating services through logical network identities |
| Network isolation | Restriction of communication between network environments |
| Multi-homed container | Container attached to multiple networks |
| Docker Compose | Declarative multi-container application management tool |
| Compose project | Logical group of application resources |
| Compose service | Definition of an executable application component |
| YAML | Structured configuration serialization language |
| Flask | Python web application framework |
| Gunicorn | Python WSGI HTTP server |
| Redis | In-memory data system |
| Reverse proxy | Server forwarding client requests to backend services |
| Nginx | HTTP server and reverse proxy software |
| Health check | Test evaluating a selected application condition |
| Liveness | Basic process responsiveness |
| Readiness | Ability to perform required application operations |
| depends_on | Compose service dependency configuration |
| Restart policy | Container process restart-management configuration |
| Atomic operation | Indivisible logical operation under a concurrency model |
| Lost update | Concurrency anomaly in which an update is overwritten |
| HTTP 502 | Bad Gateway response |
| HTTP 503 | Service Unavailable response |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |

---

# PART VIII — FORMAL WEEK TWO EXAMINATION

# 87. EXAMINATION STRUCTURE

**Total Available Marks: 100**

| Assessment component | Marks |
|---|---:|
| Part A — Theoretical foundations | 20 |
| Part B — Command and configuration interpretation | 15 |
| Part C — Application architecture | 15 |
| Part D — Practical implementation | 25 |
| Part E — Troubleshooting and recovery | 15 |
| Part F — Documentation and technical explanation | 10 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student should demonstrate practical competence and conceptual understanding.

A successful application deployment without the ability to explain its operation does not constitute full mastery.

---

# 88. EXAMINATION PART A — THEORETICAL QUESTIONS

Answer the following questions in formal technical language.

**Question 1.**

Explain why container writable layers are unsuitable as the sole storage mechanism for important database records.

**Question 2.**

Describe how Docker port publishing enables a browser to access a containerized web application.

**Question 3.**

Explain the difference between the loopback interface of a host and that of a container.

**Question 4.**

Distinguish Dockerfile `EXPOSE` from a Compose `ports` mapping.

**Question 5.**

Explain why Compose service-name discovery is preferable to hard-coded container IP addresses.

**Question 6.**

Describe the differences between Docker volumes and bind mounts.

**Question 7.**

Explain why Redis persistence requires both application-level configuration and appropriate Docker storage.

**Question 8.**

Describe the relationship between Docker Compose and Docker Engine.

**Question 9.**

Explain why service startup ordering does not guarantee continuous service availability.

**Question 10.**

Distinguish data persistence from backup and recovery.

---

# 89. EXAMINATION PART B — COMMAND INTERPRETATION

Analyze:

```bash
docker compose up -d --build
```

Explain:

1. The meaning of `up`.
2. The meaning of `-d`.
3. The purpose of `--build`.
4. Which resources may be created or reconciled.

Analyze:

```bash
docker compose exec redis redis-cli GET week2:visits
```

Explain:

5. Which service is selected.
6. Which executable is invoked.
7. Which database operation is performed.

Analyze:

```bash
docker compose down
```

Explain:

8. Which resources are normally removed.
9. Why the named Redis volume remains available.

Analyze:

```bash
docker compose down -v
```

Explain:

10. Why this operation may cause persistent data loss.

---

# 90. EXAMINATION PART C — ARCHITECTURAL ANALYSIS

A three-service application consists of:

- Nginx.
- Flask.
- Redis.

The system uses:

- A frontend network.
- A backend network.
- A named volume.

**Required tasks:**

1. Draw the complete architecture.
2. Identify the published service.
3. Identify the service attached to both networks.
4. Explain why Redis is not on the frontend network.
5. Explain why the named volume is attached to Redis.
6. Identify the application process responsible for HTTP business logic.
7. Explain the request flow for a counter increment.
8. Explain the system's most important failure dependencies.

---

# 91. EXAMINATION PART D — PRACTICAL IMPLEMENTATION

The student must independently demonstrate:

1. A valid Compose project.
2. A custom Flask image.
3. A functioning Nginx reverse proxy.
4. A functioning Redis service.
5. Correct user-defined network attachments.
6. Redis state persistence.
7. An incrementing counter.
8. Separate liveness and readiness endpoints.
9. Successful service startup.
10. Successful application recreation.

Evidence may include:

- Configuration files.
- Screenshots.
- Terminal output.
- Docker inspection results.
- Laboratory observation tables.

---

# 92. EXAMINATION PART E — FAILURE AND RECOVERY

The examiner may introduce one or more faults.

Examples include:

- Redis stopped.
- Incorrect Redis hostname.
- Incorrect backend port.
- Incorrect gateway port.
- Missing named volume.
- Invalid Nginx configuration.
- Incorrect application environment variable.

The student must:

1. Identify the fault.
2. Explain the cause.
3. Select diagnostic commands.
4. Perform an appropriate correction.
5. Demonstrate restored functionality.
6. Explain how the correction affects the application architecture.

---

# 93. EXAMINATION PART F — DOCUMENTATION

The student must produce a concise technical report containing:

1. Project objective.
2. Functional requirements.
3. Nonfunctional requirements.
4. Architecture diagram.
5. Compose service description.
6. Network design explanation.
7. Persistent storage explanation.
8. Test results.
9. Failure and recovery analysis.
10. Conclusion.

The report should distinguish observed results from theoretical expectations.

---

# PART IX — CAPSTONE TECHNICAL REPORT

# 94. REQUIRED REPORT STRUCTURE

**Report Title:**

*Design and Evaluation of a Persistent Three-Service Docker Compose Application.*

**Recommended Length:** 1,500–2,000 words.

The report should contain the following sections.

## Abstract

Summarize the project's purpose, architecture, methods, and results.

## Introduction

Explain the problem of managing a stateful multi-container application.

## System Requirements

Describe the functional and nonfunctional requirements.

## Architecture

Explain Nginx, Flask, Redis, networking, and storage responsibilities.

## Implementation

Describe the principal project files and configuration decisions.

## Testing Methodology

Explain the procedures used to verify networking, persistence, health, and recovery.

## Results

Present the observed laboratory results.

## Discussion

Analyze the limitations, security considerations, and possible improvements.

## Conclusion

Summarize what the application demonstrates about container engineering.

---

# 95. CAPSTONE COMPETENCY CHECKLIST

## Port Publishing

- [ ] I can define a network endpoint.
- [ ] I can distinguish host and container ports.
- [ ] I understand application bind addresses.
- [ ] I can explain the difference between EXPOSE and port publishing.
- [ ] I can restrict host publishing to loopback.

## Runtime Configuration

- [ ] I can define environment variables.
- [ ] I can configure Dockerfile ENV defaults.
- [ ] I can use Compose environment mappings.
- [ ] I can use project `.env` interpolation.
- [ ] I can inspect effective runtime configuration.
- [ ] I understand configuration precedence.

## Persistent Storage

- [ ] I can explain the container writable layer.
- [ ] I can create a named volume.
- [ ] I can attach a volume to Redis.
- [ ] I can explain Redis persistence.
- [ ] I can verify data survival after container replacement.
- [ ] I can explain why a volume is not a backup.
- [ ] I can create a volume archive.
- [ ] I can restore an archive.
- [ ] I can verify recovered Redis data.

## Networking

- [ ] I can define a Docker bridge network.
- [ ] I can create user-defined networks.
- [ ] I can explain embedded DNS.
- [ ] I can use service names for communication.
- [ ] I can inspect network membership.
- [ ] I can explain network segmentation.
- [ ] I can distinguish frontend and backend network access.
- [ ] I can explain why Redis does not require a published host port.

## Docker Compose

- [ ] I can construct a Compose file.
- [ ] I can define services.
- [ ] I can define networks.
- [ ] I can define volumes.
- [ ] I can configure health checks.
- [ ] I can configure dependencies.
- [ ] I can validate the Compose model.
- [ ] I can start and stop an application.
- [ ] I can inspect Compose services.
- [ ] I can retrieve logs.
- [ ] I can execute diagnostic commands.
- [ ] I understand restart and recreation.
- [ ] I understand the dangers of destructive volume cleanup.

## Flask and Redis

- [ ] I can construct a Flask application.
- [ ] I can implement GET and POST routes.
- [ ] I can return JSON responses.
- [ ] I can configure Gunicorn.
- [ ] I can create a Redis client.
- [ ] I can retrieve Redis data.
- [ ] I can increment a counter atomically.
- [ ] I can handle Redis connection failures.
- [ ] I can explain why application state is externalized.

## Nginx

- [ ] I can explain reverse proxying.
- [ ] I can mount an Nginx configuration file.
- [ ] I can configure a backend service hostname.
- [ ] I can explain proxy_pass.
- [ ] I can inspect gateway logs.
- [ ] I can troubleshoot backend connection failures.

## Application Reliability

- [ ] I can distinguish liveness from readiness.
- [ ] I can explain startup dependencies.
- [ ] I can inspect health-check states.
- [ ] I can test controlled dependency failures.
- [ ] I can verify recovery.
- [ ] I understand the limits of restart policies.
- [ ] I understand that local persistent volumes do not guarantee disaster recovery.

## Final Competence

- [ ] I constructed the complete application.
- [ ] I validated its configuration.
- [ ] I verified network separation.
- [ ] I verified the Redis counter.
- [ ] I demonstrated concurrent increments.
- [ ] I tested dependency failure.
- [ ] I restored application connectivity.
- [ ] I recreated the containers.
- [ ] I verified persistent state.
- [ ] I created and restored a backup.
- [ ] I completed the assessment.
- [ ] I prepared the technical report.

---

# 96. WEEK TWO SUMMARY

Week Two expanded Docker study from individual containers to the architecture of complete containerized applications.

Lecture 08 introduced container networking boundaries, port publishing, and environment-based configuration.

Lecture 09 established the distinction between disposable container writable layers and independently managed persistent storage.

Lecture 10 explained bridge networking, container DNS, service discovery, and network isolation.

Lecture 11 introduced Docker Compose as a declarative application management system.

Lecture 12 implemented direct application communication between Flask and Redis.

Lecture 13 developed advanced operational concepts involving health checks, dependencies, restart behavior, configuration precedence, and development workflows.

The present capstone combines those mechanisms into a complete three-service system.

The browser communicates with an Nginx reverse proxy.

Nginx forwards requests to Flask through a frontend Docker network.

Flask implements application logic and communicates with Redis through a backend network.

Redis maintains application state and writes recoverable data into a named Docker volume.

Compose manages the application's service definitions, runtime configuration, networks, volume, startup conditions, and container lifecycles.

The practical exercises demonstrate:

- Application connectivity.
- Service-name discovery.
- Network segmentation.
- Atomic database operations.
- Persistent state.
- Health monitoring.
- Dependency failure.
- Container replacement.
- Backup creation.
- Data recovery.

The most important conclusion is that **reliable containerized applications require the deliberate coordination of execution environments, communication pathways, configuration management, persistent storage, and operational recovery procedures**.

---

# 97. REFERENCES AND RECOMMENDED READING

## Docker Networking

[1] Docker Inc. *Docker Networking Overview.*  
https://docs.docker.com/engine/network/

[2] Docker Inc. *Docker Bridge Network Driver.*  
https://docs.docker.com/engine/network/drivers/bridge/

[3] Docker Inc. *Port Publishing and Mapping.*  
https://docs.docker.com/engine/network/port-publishing/

[4] Docker Inc. *Networking in Docker Compose.*  
https://docs.docker.com/compose/how-tos/networking/

[5] Docker Inc. *Compose Networks Reference.*  
https://docs.docker.com/reference/compose-file/networks/

## Docker Storage

[6] Docker Inc. *Docker Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[7] Docker Inc. *Docker Bind Mounts.*  
https://docs.docker.com/engine/storage/bind-mounts/

[8] Docker Inc. *Compose Volumes Reference.*  
https://docs.docker.com/reference/compose-file/volumes/

[9] Docker Inc. *Docker Volume Command Reference.*  
https://docs.docker.com/reference/cli/docker/volume/

## Docker Compose

[10] Docker Inc. *Docker Compose Overview.*  
https://docs.docker.com/compose/

[11] Docker Inc. *Docker Compose Quickstart.*  
https://docs.docker.com/compose/gettingstarted/

[12] Docker Inc. *Compose File Reference.*  
https://docs.docker.com/reference/compose-file/

[13] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[14] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[15] Docker Inc. *Environment Variable Precedence.*  
https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/

[16] Docker Inc. *Compose Variable Interpolation.*  
https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/

[17] Docker Inc. *Docker Compose Up.*  
https://docs.docker.com/reference/cli/docker/compose/up/

[18] Docker Inc. *Docker Compose Down.*  
https://docs.docker.com/reference/cli/docker/compose/down/

## Application Technology

[19] Flask. *Official Flask Documentation.*  
https://flask.palletsprojects.com/

[20] Flask. *Gunicorn Deployment.*  
https://flask.palletsprojects.com/en/stable/deploying/gunicorn/

[21] Redis. *Redis Documentation.*  
https://redis.io/docs/latest/

[22] Redis. *Redis Persistence.*  
https://redis.io/docs/latest/management/persistence/

[23] Redis. *INCR Command.*  
https://redis.io/docs/latest/commands/incr/

[24] NGINX. *NGINX Reverse Proxy Documentation.*  
https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

---

# 98. FINAL MODULE CONCLUSION

The completion of Lecture 14 represents the conclusion of the course's second major stage.

The student has progressed from the study of individual Docker objects to the engineering of a coordinated multi-container application.

A container is no longer considered only as an isolated process environment.

It is now understood as a component participating in a wider system involving networking, application protocols, configuration, storage, and lifecycle management.

Docker provides the fundamental container execution mechanisms.

Docker networking establishes the communication pathways.

Named volumes provide independent storage lifecycles.

Environment variables separate deployment settings from application artifacts.

Docker Compose expresses these relationships through a reusable application model.

Flask, Nginx, and Redis demonstrate how these mechanisms support distinct application responsibilities.

The resulting architecture separates the client-facing HTTP entry point, application logic, and persistent database state.

The laboratory also demonstrates the importance of failure analysis.

A service may remain running while a dependency is unavailable.

A successful DNS lookup does not guarantee a functioning application.

A named volume does not guarantee that a database has written recoverable files.

A persistent volume is not itself a complete backup strategy.

A valid Compose file does not prove that all services operate correctly.

These distinctions are essential to professional container engineering.

The final week of the course will extend these foundations into image optimization, security, troubleshooting, registries, production deployment, continuous integration, and a complete final application project.

---

**END OF LECTURE 14**

**END OF MODULE 02 — DOCKER NETWORKING, STORAGE, AND MULTI-CONTAINER APPLICATIONS**

**Next Lecture:** Lecture 15 — Advanced Docker Image Engineering: Multi-Stage Builds, BuildKit, Image Optimization, Cache Management, and Reproducible Container Construction.
