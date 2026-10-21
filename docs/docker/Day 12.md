# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 12 — BUILDING A MULTI-CONTAINER APPLICATION WITH DOCKER COMPOSE: FLASK, REDIS, SERVICE COMMUNICATION, AND PERSISTENT STATE

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 12 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–6 hours

**Prerequisites:**

- Lectures 01–07 — Docker Fundamentals.
- Lecture 08 — Port Publishing and Environment Variables.
- Lecture 09 — Docker Volumes and Data Persistence.
- Lecture 10 — Container Networking and Service Discovery.
- Lecture 11 — Docker Compose Fundamentals.
- Elementary familiarity with Python functions and HTTP requests.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define a multi-container application and explain its architectural significance.
2. Distinguish infrastructure composition from actual application-level integration.
3. Explain the separation of application logic and persistent data storage.
4. Describe the responsibilities of a web application and a data service.
5. Define Flask and explain its role as a Python web application framework.
6. Explain the purpose of a Web Server Gateway Interface.
7. Describe the role of Gunicorn in serving Flask applications.
8. Define Redis and describe its key-value data model.
9. Explain how Python applications communicate with Redis.
10. Describe Redis client libraries and connection configuration.
11. Explain how Docker Compose connects application services.
12. Use service-name DNS discovery in application configuration.
13. Distinguish container-internal ports from host-published ports.
14. Define application state and describe how it can be shared across application processes.
15. Explain the significance of atomic database operations.
16. Distinguish atomic increments from non-atomic read-modify-write sequences.
17. Construct a Python Flask HTTP application.
18. Implement read-only and state-changing HTTP endpoints.
19. Distinguish the intended semantics of GET and POST requests.
20. Connect Flask to Redis using a Python client library.
21. Create a Dockerfile that packages the Flask application.
22. Apply basic dependency-version control and image caching.
23. Configure non-root application execution.
24. Define a two-service application using Docker Compose.
25. Use environment variables to configure inter-service connections.
26. Configure Redis persistent storage through a named volume.
27. Explain Redis append-only persistence.
28. Configure service health checks.
29. Explain the difference between liveness and readiness.
30. Describe health-aware startup dependencies.
31. Explain why dependency ordering does not eliminate runtime failure.
32. Handle temporary Redis connectivity failures.
33. Build and start the application using Docker Compose.
34. Inspect containers, logs, networks, and volumes.
35. Verify database persistence after application recreation.
36. Analyze application behavior during database unavailability.
37. Demonstrate recovery after Redis becomes available again.
38. Evaluate security, reliability, and production limitations.
39. Complete a comprehensive practical laboratory.
40. Prepare a formal technical assessment of the resulting system.

---

# 2. INTRODUCTION TO MULTI-CONTAINER APPLICATIONS

## 2.1 Background

The previous lecture introduced Docker Compose as a declarative mechanism for managing multiple containers.

A Compose application can define several services, each with its own image, runtime configuration, network attachments, and storage requirements.

However, the existence of several services within the same Compose project does not automatically mean that the services cooperate.

For example, an Nginx container and a Redis container may execute successfully on the same Docker network without exchanging any application data.

Actual cooperation requires application logic that implements the relevant communication protocol.

Lecture 12 introduces this additional layer.

The student will construct a Python web application that actively communicates with Redis to maintain a visitor counter.

## 2.2 Definition of a Multi-Container Application

**Formal definition:**

A multi-container application is a software system composed of multiple cooperating containerized components whose combined execution provides the intended application functionality.

Each component may have an independent:

- Image.
- Process lifecycle.
- Network endpoint.
- Runtime configuration.
- Set of dependencies.
- Storage requirements.
- Operational responsibilities.

## 2.3 Example Application

Consider a web application that displays a numeric counter.

The user interacts with a web page.

When the user presses a button, the application increments a value stored in Redis.

The updated value is returned to the browser.

The architecture consists of two cooperating services:

**Web application service:** Implements the HTTP interface and counter operations.

**Redis service:** Stores the counter value.

## 2.4 Architectural Significance

Separating application logic from data storage provides several advantages.

These include:

1. Independent application and data lifecycles.
2. Clear separation of responsibilities.
3. Independent service diagnostics.
4. Reusable application images.
5. Network-based integration.
6. Shared state across application processes.
7. More flexible scaling arrangements.
8. Independent persistent storage management.

However, the separation introduces network dependencies and additional failure scenarios.

These must be managed deliberately.

---

# 3. SERVICE RESPONSIBILITIES

## 3.1 Web Application Service

The web application is responsible for:

- Receiving HTTP requests.
- Interpreting request methods and paths.
- Performing application logic.
- Communicating with Redis.
- Generating HTTP responses.
- Reporting errors.
- Providing health and readiness endpoints.

## 3.2 Redis Service

Redis is responsible for:

- Maintaining key-value data.
- Executing supported database commands.
- Performing atomic operations.
- Serving network clients.
- Maintaining its configured persistence files.
- Recovering data from persistent storage.

## 3.3 Infrastructure Responsibilities

Docker Compose is responsible for configuring and managing:

- Container creation.
- Image selection and construction.
- Network membership.
- Environment variables.
- Named volumes.
- Host port publishing.
- Service startup conditions.
- Container health checks.
- Application lifecycle commands.

## 3.4 Separation of Responsibilities

```text
             DOCKER COMPOSE
                   |
      +------------+------------+
      |                         |
      v                         v
  WEB SERVICE              REDIS SERVICE
      |                         |
      v                         v
 HTTP LOGIC               KEY-VALUE STORAGE
      |                         |
      +------- NETWORK ---------+
                                |
                                v
                           NAMED VOLUME
```

The web application and Redis implement the application behavior.

Docker Compose provides the environment in which they operate.

---

# 4. FUNDAMENTALS OF WEB APPLICATION ARCHITECTURE

## 4.1 Client-Server Model

A client-server system contains components that request services and components that provide those services.

In an HTTP web application:

**Client:** Usually a web browser or HTTP client.

**Server:** An application that accepts HTTP requests and returns HTTP responses.

## 4.2 HTTP Request Structure

An HTTP request contains information such as:

- Method.
- Target path.
- Protocol version.
- Headers.
- Optional request body.

For example:

```http
GET /api/count HTTP/1.1
Host: 127.0.0.1:8222
```

The application interprets the request and produces a response.

## 4.3 HTTP Response Structure

An HTTP response contains:

- Protocol status.
- Response headers.
- Optional response body.

For example:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"count":5}
```

The response body contains a JSON representation of the requested counter value.

## 4.4 HTTP Methods

Two important HTTP methods for this lecture are GET and POST.

**GET** is intended for retrieving a representation of a resource without requesting a state-changing operation.

**POST** submits information or requests processing that may change application state.

## 4.5 Correct Counter Semantics

A counter application should distinguish between:

```text
GET /api/count
```

and:

```text
POST /api/increment
```

The first operation reads the existing counter.

The second operation changes the counter.

This separation avoids unintentionally changing application state every time a browser, proxy, or monitoring system requests the counter endpoint.

---

# 5. INTRODUCTION TO FLASK

## 5.1 Definition

Flask is a lightweight Python web application framework.

It provides mechanisms for:

- Defining HTTP routes.
- Handling requests.
- Creating responses.
- Returning JSON.
- Rendering HTML templates.
- Organizing application logic.
- Integrating with external libraries.

## 5.2 Basic Flask Application

A minimal Flask application may contain:

```python
from flask import Flask

app = Flask(__name__)

@app.get("/")
def home():
    return "Hello from Flask"
```

## 5.3 Application Object

The statement:

```python
app = Flask(__name__)
```

creates a Flask application object.

This object represents the web application and maintains its configuration and routing information.

## 5.4 Route Definitions

The decorator:

```python
@app.get("/")
```

associates an HTTP GET request for the root path with a Python function.

Similarly:

```python
@app.post("/api/increment")
```

associates an HTTP POST request with a function implementing a state-changing operation.

## 5.5 Flask and Docker

Flask is an application framework.

Docker is a containerization platform.

Flask does not require Docker to function.

Docker provides a mechanism for packaging and operating the Flask application in a controlled runtime environment.

---

# 6. WSGI AND APPLICATION SERVERS

## 6.1 Definition of WSGI

The Web Server Gateway Interface, abbreviated WSGI, is a standardized interface between Python web applications and compatible web servers.

Flask implements the WSGI application model.

## 6.2 Development Server

Flask provides a development server intended for development and debugging.

It is useful for local experimentation.

However, it is not the recommended general-purpose production deployment server.

## 6.3 Gunicorn

Gunicorn is a Python WSGI HTTP server.

It can load a Flask application and serve HTTP requests using worker processes.

## 6.4 Application Execution Model

```text
              HTTP CLIENT
                   |
                   v
             GUNICORN SERVER
                   |
          +--------+--------+
          |                 |
          v                 v
       WORKER 1          WORKER 2
          |                 |
          v                 v
       FLASK APP         FLASK APP
          |                 |
          +--------+--------+
                   |
                   v
                  REDIS
```

The diagram is a logical representation.

Worker processes execute application logic and can independently communicate with Redis.

## 6.5 Significance of Multiple Workers

Multiple workers can handle independent requests.

However, each worker has its own process memory.

A global Python variable stored in one worker is not automatically a reliable shared counter across all workers.

A shared external storage system such as Redis provides an appropriate location for the counter value.

## 6.6 Gunicorn Command

An example command is:

```bash
gunicorn --bind 0.0.0.0:8000 --workers 2 app:app
```

The first `app` identifies the Python module.

The second `app` identifies the Flask application object within that module.

The server listens on container TCP port 8000.

---

# 7. INTRODUCTION TO REDIS

## 7.1 Definition

Redis is an in-memory data system that supports several data structures and application operations.

For this lecture, Redis is used as a key-value database.

## 7.2 Key-Value Data Model

A key-value record associates an identifier with a stored value.

Example:

```text
Key:   lecture12:counter
Value: 5
```

The key identifies the counter.

The value represents the current count.

## 7.3 Redis Commands

Common Redis commands include:

| Command | Purpose |
|---|---|
| `PING` | Test server responsiveness |
| `GET` | Retrieve a string value |
| `SET` | Assign a value |
| `INCR` | Increment a numeric value |
| `DECR` | Decrement a numeric value |
| `DEL` | Delete a key |
| `EXISTS` | Check key existence |
| `TYPE` | Inspect a key's data type |

## 7.4 Application Role

The Flask application acts as a Redis client.

Redis acts as the database server.

Communication occurs over TCP using the Redis application protocol.

## 7.5 Network Configuration

The Flask service will use:

```text
REDIS_HOST=redis
REDIS_PORT=6379
```

The hostname `redis` is the Compose service name.

It is resolved through Docker's internal service-discovery mechanism.

---

# 8. THE PYTHON REDIS CLIENT

## 8.1 Purpose

A Redis client library translates application operations into requests understood by the Redis server.

The Python Redis library is commonly called redis-py.

## 8.2 Basic Client Construction

```python
import redis

client = redis.Redis(
    host="redis",
    port=6379,
    decode_responses=True
)
```

This creates a client object configured to communicate with Redis.

## 8.3 Connection Establishment

Constructing a Redis client object does not necessarily establish an immediate network connection.

A connection is commonly established when an operation is executed.

For example:

```python
client.ping()
```

tests whether Redis responds successfully.

## 8.4 Reading Data

```python
value = client.get("lecture12:counter")
```

The operation retrieves the current value associated with the key.

## 8.5 Writing Data

```python
client.set("lecture12:counter", 10)
```

This operation assigns the value 10.

## 8.6 Atomic Increment

```python
new_value = client.incr("lecture12:counter")
```

Redis performs the increment operation on the server.

The resulting value is returned to the client.

This operation is especially useful when multiple application workers may attempt to update the counter concurrently.

---

# 9. ATOMICITY AND CONCURRENT APPLICATION STATE

## 9.1 Definition

An atomic operation is an operation that is performed as an indivisible logical action with respect to the relevant concurrency model.

For Redis `INCR`, competing increments are processed without the lost-update problem associated with a naive read-modify-write sequence.

## 9.2 Non-Atomic Counter Example

Consider two application workers.

Both execute:

1. Read the current count.
2. Add one.
3. Write the new count.

Suppose the initial value is:

```text
10
```

Worker A reads 10.

Worker B also reads 10.

Worker A writes 11.

Worker B writes 11.

Two increment requests occurred, but the final value is only 11.

One increment has effectively been lost.

## 9.3 Incorrect Algorithm

```python
current = int(client.get("counter") or 0)

client.set("counter", current + 1)
```

The read and write are separate operations.

Another client may modify the value between them.

## 9.4 Correct Atomic Operation

```python
new_value = client.incr("counter")
```

Redis performs the increment as a single database command.

## 9.5 Architectural Importance

A shared external data store combined with appropriate atomic operations allows multiple application processes to operate on common state more reliably.

This is an important foundation for concurrent and distributed applications.

## 9.6 Qualification

Atomicity applies to the specific operation and its guarantees.

It does not automatically make an entire multi-step business transaction atomic.

Operations involving several records or services may require more sophisticated consistency mechanisms.

---

# 10. STATELESS APPLICATION PROCESSES AND SHARED STATE

## 10.1 Process-Local State

A Python process can store information in ordinary variables.

Example:

```python
counter = 0
```

However, this variable belongs to the memory environment of the Python process.

Separate Gunicorn workers may maintain independent copies.

## 10.2 Container Replacement

A variable stored only in process memory disappears when the process terminates.

Therefore, process-local variables are not an appropriate sole storage mechanism for a durable application counter.

## 10.3 External State

The application will store the counter in Redis.

```text
          FLASK WORKER 1
                 |
                 v
               REDIS
                 ^
                 |
          FLASK WORKER 2
```

Both workers communicate with the same Redis server.

## 10.4 Benefits

Externalized state supports:

- Multiple application processes.
- Container replacement.
- Shared application state.
- Independent data lifecycle.
- Simplified application image construction.

However, Redis becomes a dependency whose availability must be considered.

---

# 11. THE COMPLETE APPLICATION REQUEST FLOW

## 11.1 Increment Request

When a user presses the increment button, the browser sends:

```http
POST /api/increment HTTP/1.1
```

The request reaches Gunicorn.

Gunicorn dispatches the request to a Flask application worker.

The Flask handler executes a Redis `INCR` command.

Redis updates the counter.

The new value is returned to Flask.

Flask returns a JSON response.

The browser updates its displayed count.

## 11.2 Architecture Diagram

```text
                    WEB BROWSER
                         |
                         | POST /api/increment
                         v
                  HOST PORT 8222
                         |
                         v
                 WEB CONTAINER
                         |
                         v
                   GUNICORN
                         |
                         v
                 FLASK ROUTE
                         |
                         | Redis INCR
                         v
                  COMPOSE NETWORK
                         |
                         v
                 REDIS CONTAINER
                         |
                         v
                 COUNTER UPDATED
                         |
                         | New count
                         v
                    FLASK API
                         |
                         | JSON response
                         v
                    WEB BROWSER
```

## 11.3 Persistence Path

Separately, Redis writes recoverable data to its configured storage directory.

```text
             REDIS PROCESS
                   |
                   v
            PERSISTENCE FILES
                   |
                   v
                 /data
                   |
                   v
          DOCKER NAMED VOLUME
```

The complete application therefore contains both a communication pathway and a persistence pathway.

---

# 12. INTRODUCTION TO REST-ORIENTED HTTP DESIGN

## 12.1 Resource Representation

A web API provides access to resources through HTTP interfaces.

For this application, the counter is represented as a resource.

## 12.2 Read Endpoint

```text
GET /api/count
```

Returns the current counter value.

## 12.3 Mutation Endpoint

```text
POST /api/increment
```

Increments the counter.

## 12.4 Health Endpoints

```text
GET /health
```

Checks basic web-application responsiveness.

```text
GET /ready
```

Checks whether the application can communicate with Redis.

## 12.5 Endpoint Summary

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | Display HTML interface |
| GET | `/api/count` | Retrieve current value |
| POST | `/api/increment` | Increment stored counter |
| GET | `/health` | Basic process liveness |
| GET | `/ready` | Dependency readiness |

## 12.6 HTTP Status Codes

Important responses include:

**200 OK:** The request succeeded.

**404 Not Found:** The requested resource or path does not exist.

**405 Method Not Allowed:** The requested path does not support the selected HTTP method.

**503 Service Unavailable:** The application cannot currently provide the requested operation because a required service is unavailable.

---

# 13. JSON IN APPLICATION COMMUNICATION

## 13.1 Definition

JavaScript Object Notation, abbreviated JSON, is a text-based data interchange format.

It represents information using structured values such as objects, arrays, strings, numbers, and Boolean values.

## 13.2 Example Counter Response

```json
{
  "count": 12
}
```

## 13.3 Application Use

The Flask application returns JSON responses through its API.

The browser interprets these responses using JavaScript.

## 13.4 Advantages

JSON is:

- Human-readable.
- Widely supported.
- Suitable for structured responses.
- Easily consumed by browser applications.
- Independent of the implementation language.

## 13.5 Important Qualification

JSON defines a representation format.

It does not provide transport, authentication, encryption, or application correctness on its own.

---

# 14. SERVICE DISCOVERY IN THE APPLICATION

## 14.1 Compose Network

The application will define a user-defined bridge network named:

```text
backend
```

Both the Flask and Redis services will join this network.

## 14.2 Internal DNS

The Flask application will connect using:

```text
redis:6379
```

The hostname `redis` corresponds to the Compose service name.

## 14.3 Why localhost Is Incorrect

If Flask uses:

```text
127.0.0.1:6379
```

it ordinarily attempts to connect to a Redis server inside the Flask container's own network namespace.

Redis executes in another container.

Therefore, Flask must use a destination address reachable through the shared Docker network.

## 14.4 Why Host Port Publishing Is Unnecessary

Redis will not be published to the Docker host.

The Flask service uses Redis's internal port.

This is sufficient for the intended application communication.

---

# 15. ENVIRONMENT-BASED SERVICE CONFIGURATION

## 15.1 Application Parameters

The Flask application will read:

```text
APP_NAME
REDIS_HOST
REDIS_PORT
REDIS_COUNTER_KEY
```

## 15.2 Example

```text
APP_NAME=Docker Compose Counter Laboratory
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_COUNTER_KEY=lecture12:counter
```

## 15.3 Purpose

Environment variables separate application configuration from the source code.

The same image can be used with different service names, keys, or deployment settings.

## 15.4 Compose Interpolation

The Compose `.env` file will supply the host port and application display name.

For example:

```text
WEB_PORT=8222
APP_NAME=Docker Compose Counter Laboratory
```

These values can be referenced in the Compose file through interpolation expressions.

## 15.5 Scope

The project `.env` file is not automatically imported into the container environment.

The Compose service must explicitly pass the required variables.

---

# 16. REDIS PERSISTENCE

## 16.1 Purpose

The counter must survive the removal and recreation of the Redis container.

This requires application persistence and Docker-managed storage.

## 16.2 Redis Append-Only File

Redis supports append-only file persistence, abbreviated AOF.

When enabled, Redis records data-changing operations in persistence files.

These records can be replayed when Redis starts.

## 16.3 Configuration

The laboratory uses:

```text
appendonly yes
```

and:

```text
appendfsync everysec
```

## 16.4 Meaning of everysec

The `everysec` setting requests periodic synchronization of append-only data to storage.

It provides a balance between performance and durability.

However, a sudden failure may still result in the loss of recently acknowledged writes.

The configuration must not be interpreted as a guarantee of zero data loss.

## 16.5 Named Volume

The Redis data directory will be:

```text
/data
```

Compose will mount a named volume at this location.

The volume will remain available after ordinary `docker compose down` operations.

---

# 17. LIVENESS AND READINESS

## 17.1 Liveness

Liveness describes whether an application process remains capable of responding to a basic internal check.

A liveness endpoint may return a successful response even when a dependency is unavailable.

## 17.2 Readiness

Readiness describes whether an application can perform the operations expected of it.

For a counter application, Redis connectivity is necessary for the primary counter functionality.

A readiness endpoint can verify that dependency.

## 17.3 Comparison

| Characteristic | Liveness | Readiness |
|---|---|---|
| Principal question | Is the application process responsive? | Can the application perform required work? |
| Redis dependency required in this laboratory | No | Yes |
| Example endpoint | `/health` | `/ready` |
| Expected result when Redis is unavailable | May remain successful | Should report failure |
| Operational use | Process diagnostics | Service readiness diagnostics |

## 17.4 Important Limitation

These distinctions are application-design conventions.

The application author determines what the endpoints actually test.

An endpoint named `/health` is not automatically a correct liveness check merely because of its name.

---

# 18. HEALTH-AWARE DEPENDENCY MANAGEMENT

## 18.1 Dependency Ordering

Compose supports:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

This indicates that the web service depends on Redis meeting the configured healthy condition during startup.

## 18.2 Redis Health Check

A simple Redis health check may execute:

```text
redis-cli ping
```

The expected response is:

```text
PONG
```

## 18.3 Startup Sequence

```text
         COMPOSE UP
             |
             v
       REDIS CONTAINER
             |
             v
       REDIS HEALTHCHECK
             |
             v
          HEALTHY
             |
             v
        WEB CONTAINER
             |
             v
       FLASK APPLICATION
```

## 18.4 Runtime Qualification

A dependency becoming unavailable later does not automatically guarantee that Compose will stop or restart dependent services.

Applications must still handle dependency failures after startup.

## 18.5 Restart Policies

Docker restart policies operate on container process lifecycle events.

A container becoming unhealthy does not, by itself, guarantee an automatic restart.

Health monitoring and failure remediation are separate concerns.

---

# 19. FAILURE HANDLING

## 19.1 Network Failure

Redis may be unavailable because of:

- Container stopping.
- Network disconnection.
- Incorrect hostname.
- Wrong port.
- Redis process failure.
- DNS resolution failure.
- Resource exhaustion.

## 19.2 Application Behavior

The Flask application should not necessarily terminate whenever an individual Redis request fails.

Instead, it can return a controlled error response.

For example:

```json
{
  "error": "Redis is temporarily unavailable"
}
```

with HTTP status:

```text
503 Service Unavailable
```

## 19.3 Recovery

When Redis becomes available again, subsequent requests can succeed.

This avoids requiring a complete web application rebuild or replacement for every transient dependency failure.

## 19.4 Limitations

Handling errors at the HTTP request level is only one aspect of resilience.

Production systems may require:

- Connection retry policies.
- Timeouts.
- Circuit breakers.
- Backoff mechanisms.
- Queueing.
- Monitoring.
- Alerting.
- High-availability storage.

These topics will receive greater attention during Week 3.

---

# 20. SECURITY CONSIDERATIONS

## 20.1 Non-Root Web Execution

The Flask application will execute using a non-root user identifier.

This reduces unnecessary filesystem privileges.

## 20.2 Localhost Port Publishing

The web application will be published through the Docker host's IPv4 loopback address.

Example:

```text
127.0.0.1:8222:8000
```

This is appropriate for local development and academic experiments.

## 20.3 Internal Redis Service

Redis will be available on the Compose network but will not have a host-published port.

This reduces unnecessary external exposure.

## 20.4 Redis Authentication

The demonstration uses a Redis instance without an application password.

It is intended for a private, local training environment.

An untrusted container attached to the same network could access the Redis service.

Production configurations require appropriate authentication, authorization, network restrictions, and credential management.

## 20.5 State-Changing API

The increment endpoint is intentionally unauthenticated to simplify the laboratory.

It must not be treated as a secure public API.

Production designs should consider:

- Authentication.
- Authorization.
- Request limits.
- CSRF protection where applicable.
- Input validation.
- Monitoring.
- Abuse prevention.

---

# PART II — PRACTICAL PROJECT DESIGN

# 21. LABORATORY PROJECT

## 21.1 Title

**Flask-and-Redis Visitor Counter: A Stateful Multi-Container Application Managed with Docker Compose**

## 21.2 Project Objective

The objective is to construct a complete application in which:

1. A browser displays an HTML interface.
2. The browser requests the stored counter.
3. Flask receives the HTTP request.
4. Flask communicates with Redis.
5. Redis retrieves or modifies the counter.
6. Flask returns JSON.
7. Browser JavaScript updates the displayed value.
8. Redis persists its state in a named Docker volume.

## 21.3 Required Functionality

The application must:

- Display a counter.
- Retrieve the current counter without modifying it.
- Increment the counter through a POST request.
- Display controlled error messages if Redis is unavailable.
- Expose separate liveness and readiness endpoints.
- Persist counter data across container replacement.
- Use Compose DNS-based service discovery.
- Run the Flask application without root privileges.
- Use a WSGI server rather than Flask's development server.
- Restrict host access to the local development endpoint.

## 21.4 Required Software

- Docker Engine or Docker Desktop.
- Docker Compose V2.
- Text editor.
- Terminal.
- Web browser.
- Internet access for initial dependencies and images.

---

# 22. COMPLETE SYSTEM ARCHITECTURE

```text
                   USER
                    |
                    v
                WEB BROWSER
                    |
               HTTP REQUEST
                    |
                    v
          127.0.0.1:8222
                    |
                    v
             DOCKER HOST
                    |
              PORT MAPPING
                    |
                    v
        +------------------------+
        |       WEB SERVICE      |
        |                        |
        |      GUNICORN          |
        |          |             |
        |          v             |
        |      FLASK APP         |
        |                        |
        |   GET /api/count       |
        |   POST /api/increment  |
        |   GET /health          |
        |   GET /ready           |
        +------------------------+
                    |
                    |
             backend NETWORK
                    |
                redis:6379
                    |
                    v
        +------------------------+
        |      REDIS SERVICE     |
        |                        |
        |    KEY-VALUE STORE     |
        |                        |
        | lecture12:counter      |
        +------------------------+
                    |
                    v
                  /data
                    |
                    v
           DOCKER NAMED VOLUME
                    |
                    v
             PERSISTENT FILES
```

The application has two distinct state lifecycles.

The web application process can be replaced without changing the counter data.

The Redis container can also be replaced while its named volume remains available.

---

# 23. PROJECT DIRECTORY STRUCTURE

Create:

```text
docker-lecture12/
├── compose.yaml
├── Dockerfile
├── requirements.txt
├── app.py
├── .dockerignore
├── .env
└── laboratory-notes.md
```

**File responsibilities:**

`compose.yaml`: Defines the multi-service application.

`Dockerfile`: Packages the Flask application.

`requirements.txt`: Declares Python dependencies.

`app.py`: Implements Flask routes and Redis communication.

`.dockerignore`: Excludes unnecessary files from the image build context.

`.env`: Supplies Compose interpolation values.

`laboratory-notes.md`: Records experimental observations.

---

# 24. PYTHON DEPENDENCIES

Create:

```text
requirements.txt
```

Insert:

```text
Flask==3.1.3
redis==6.2.0
gunicorn==26.2.0
```

## 24.1 Explanation

**Flask**

Implements the HTTP application.

**redis**

Provides the Python Redis client.

**gunicorn**

Provides the WSGI HTTP server.

## 24.2 Version Management

Specific versions are declared to improve consistency during laboratory reproduction.

However, pinning only the direct dependencies does not necessarily pin all transitive dependencies.

Fully controlled builds may require a dependency lockfile, hashes, image digest pinning, and additional reproducibility measures.

For production use, dependency versions should be periodically reviewed for compatibility and security updates.

---

# 25. COMPLETE FLASK APPLICATION SOURCE

Create:

```text
app.py
```

Insert the following complete Python application:

```python
import os

import redis
from flask import Flask, jsonify, render_template_string
from redis.exceptions import RedisError


app = Flask(__name__)


APP_NAME = os.getenv(
    "APP_NAME",
    "Docker Compose Counter"
)

REDIS_HOST = os.getenv(
    "REDIS_HOST",
    "redis"
)

REDIS_PORT = int(
    os.getenv("REDIS_PORT", "6379")
)

COUNTER_KEY = os.getenv(
    "REDIS_COUNTER_KEY",
    "lecture12:counter"
)


redis_client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=0,
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

    <title>Docker Compose Counter</title>

    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            background: #f1f5f9;
            color: #0f172a;
            padding: 40px;
        }

        main {
            max-width: 650px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 14px;
            text-align: center;
        }

        h1 {
            color: #2563eb;
        }

        #count {
            font-size: 64px;
            font-weight: bold;
            margin: 30px 0;
        }

        button {
            background: #2563eb;
            color: white;
            border: none;
            padding: 15px 25px;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
        }

        button:hover {
            background: #1d4ed8;
        }

        #message {
            margin-top: 24px;
            color: #475569;
        }
    </style>
</head>

<body>

    <main>

        <h1>{{ app_name }}</h1>

        <h2>Docker Lecture 12</h2>

        <p>
            Flask and Redis Multi-Container Application
        </p>

        <p>Persistent Counter Value</p>

        <div id="count">...</div>

        <button id="increment">
            Increment Counter
        </button>

        <p id="message"></p>

    </main>

    <script>

        const countElement =
            document.getElementById("count");

        const messageElement =
            document.getElementById("message");

        const incrementButton =
            document.getElementById("increment");


        async function loadCount() {

            try {

                const response = await fetch(
                    "/api/count",
                    { cache: "no-store" }
                );

                if (!response.ok) {
                    throw new Error(
                        "Counter service unavailable"
                    );
                }

                const data = await response.json();

                countElement.textContent =
                    String(data.count);

                messageElement.textContent =
                    "Counter loaded successfully";

            } catch (error) {

                countElement.textContent = "--";

                messageElement.textContent =
                    error.message;
            }
        }


        async function incrementCount() {

            incrementButton.disabled = true;

            try {

                const response = await fetch(
                    "/api/increment",
                    {
                        method: "POST"
                    }
                );

                if (!response.ok) {
                    throw new Error(
                        "Unable to increment counter"
                    );
                }

                const data = await response.json();

                countElement.textContent =
                    String(data.count);

                messageElement.textContent =
                    "Counter incremented successfully";

            } catch (error) {

                messageElement.textContent =
                    error.message;

            } finally {

                incrementButton.disabled = false;
            }
        }


        incrementButton.addEventListener(
            "click",
            incrementCount
        );

        loadCount();

    </script>

</body>
</html>
"""


@app.get("/")
def home():

    return render_template_string(
        PAGE,
        app_name=APP_NAME
    )


@app.get("/health")
def health():

    return jsonify(
        status="alive",
        service="web"
    ), 200


@app.get("/ready")
def ready():

    try:

        redis_client.ping()

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

        value = redis_client.get(COUNTER_KEY)

        count = int(value) if value is not None else 0

        return jsonify(
            count=count
        ), 200

    except RedisError:

        return jsonify(
            error="Redis is temporarily unavailable"
        ), 503

    except (ValueError, TypeError):

        return jsonify(
            error="Stored counter value is invalid"
        ), 500


@app.post("/api/increment")
def increment_count():

    try:

        count = redis_client.incr(COUNTER_KEY)

        return jsonify(
            count=count,
            result="incremented"
        ), 200

    except RedisError:

        return jsonify(
            error="Redis is temporarily unavailable"
        ), 503
```

---

# 26. APPLICATION CODE ANALYSIS

## 26.1 Application Initialization

```python
app = Flask(__name__)
```

Creates the Flask application.

The application object is loaded by Gunicorn.

## 26.2 Runtime Configuration

```python
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
```

Retrieves the Redis hostname from the process environment.

The default value is the Compose service name.

## 26.3 Redis Client

```python
redis_client = redis.Redis(...)
```

Constructs the Redis client object.

Timeout options prevent certain connection operations from waiting indefinitely.

## 26.4 HTML Rendering

```python
render_template_string(PAGE, app_name=APP_NAME)
```

Generates the HTML interface.

Flask uses Jinja template functionality to substitute the application name.

## 26.5 Liveness

```python
@app.get("/health")
```

Defines the basic liveness endpoint.

It does not require Redis access.

## 26.6 Readiness

```python
@app.get("/ready")
```

Defines a dependency readiness endpoint.

It attempts to communicate with Redis.

## 26.7 Counter Retrieval

```python
redis_client.get(COUNTER_KEY)
```

Retrieves the stored counter.

If the key does not exist, the endpoint returns zero.

## 26.8 Counter Increment

```python
redis_client.incr(COUNTER_KEY)
```

Performs an atomic counter increment.

## 26.9 Error Handling

```python
except RedisError:
```

Catches Redis client exceptions.

The application returns HTTP 503 for temporary Redis unavailability.

## 26.10 Browser Interaction

Browser JavaScript uses `fetch` to issue HTTP requests.

The increment button sends a POST request.

The returned JSON determines the number displayed on the page.

## 26.11 Separation of Concerns

The browser does not connect directly to Redis.

It communicates with Flask.

Flask applies the application logic and interacts with Redis.

This separation is an important architectural property.

---

# 27. DOCKERFILE CONSTRUCTION

Create:

```text
Dockerfile
```

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL org.opencontainers.image.title="Docker Lecture 12" \
      org.opencontainers.image.description="Flask and Redis Counter Application"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=10001:10001 app.py ./app.py

USER 10001:10001

EXPOSE 8000

CMD [
  "gunicorn",
  "--bind", "0.0.0.0:8000",
  "--workers", "2",
  "--access-logfile", "-",
  "--error-logfile", "-",
  "app:app"
]
```

**Important Dockerfile syntax requirement:** JSON-array exec-form instructions must be valid JSON and should be placed on a single line unless the Dockerfile syntax explicitly supports appropriate continuation formatting.

For maximum compatibility, replace the final multiline `CMD` shown above with this single-line instruction:

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
```

The single-line instruction is the authoritative version for this laboratory.

## 27.1 Dockerfile Analysis

**FROM**

Selects the Python runtime image.

**LABEL**

Adds descriptive image metadata.

**ENV**

Configures Python runtime behavior.

**WORKDIR**

Establishes the application working directory.

**COPY requirements.txt**

Introduces the dependency manifest before application source code.

**RUN pip install**

Installs the required Python packages.

**COPY app.py**

Adds the Flask application to the image.

**USER**

Configures non-root execution.

**EXPOSE**

Declares the intended container TCP port.

**CMD**

Configures Gunicorn as the primary application server command.

## 27.2 Build Cache Optimization

The dependency manifest is copied before the application source.

If only `app.py` changes, Docker may reuse the previously completed dependency installation.

This can reduce build time.

## 27.3 Runtime Process

Gunicorn starts the Flask application using:

```text
app:app
```

Two worker processes handle HTTP requests.

The workers use Redis as shared external state.

---

# 28. DOCKERIGNORE CONFIGURATION

Create:

```text
.dockerignore
```

Insert:

```dockerignore
.git
.gitignore
.env
*.log
*.tmp
*.pyc
__pycache__/
.venv/
venv/
laboratory-notes.md
```

## 28.1 Purpose

The `.dockerignore` file excludes unnecessary content from the image build context.

## 28.2 Security

The `.env` file is excluded because it is intended for Compose configuration rather than inclusion in the built application image.

This precaution does not replace proper secrets management.

---

# 29. COMPOSE INTERPOLATION FILE

Create:

```text
.env
```

Insert:

```text
WEB_PORT=8222
APP_NAME=Docker Compose Counter Laboratory
```

## 29.1 WEB_PORT

Controls the published host port used by the web service.

## 29.2 APP_NAME

Controls the application name presented in the web interface.

## 29.3 Security Note

The file contains only non-sensitive configuration.

Do not place real database passwords or other sensitive credentials into instructional configuration files.

---

# 30. COMPLETE COMPOSE CONFIGURATION

Create:

```text
compose.yaml
```

Insert:

```yaml
name: lecture12-counter

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
      retries: 8
      start_period: 5s

    restart: unless-stopped


  web:
    build:
      context: .
      dockerfile: Dockerfile

    image: lecture12-web:v1

    ports:
      - "127.0.0.1:${WEB_PORT:-8222}:8000"

    environment:
      APP_NAME: "${APP_NAME:-Docker Compose Counter}"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      REDIS_COUNTER_KEY: lecture12:counter

    depends_on:
      redis:
        condition: service_healthy

    networks:
      - backend

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/ready', timeout=2)"
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 15s

    restart: unless-stopped


networks:
  backend:
    driver: bridge


volumes:
  redis-data:
```

---

# 31. COMPOSE CONFIGURATION ANALYSIS

## 31.1 Project Name

```yaml
name: lecture12-counter
```

Establishes the application project identity.

## 31.2 Redis Service

```yaml
redis:
  image: redis:7-alpine
```

Defines the database service.

## 31.3 Redis Startup Configuration

The command enables append-only persistence.

Redis stores its persistent files in `/data`.

## 31.4 Redis Volume

```yaml
volumes:
  - redis-data:/data
```

Attaches the Docker-managed named volume.

## 31.5 Redis Network

```yaml
networks:
  - backend
```

Connects Redis to the internal application network.

## 31.6 Redis Health Check

The health check executes `redis-cli ping` periodically.

A successful result indicates that Redis is responding to the configured test.

## 31.7 Web Build

```yaml
build:
  context: .
  dockerfile: Dockerfile
```

Instructs Compose how to construct the Flask application image.

## 31.8 Web Port Publishing

```yaml
ports:
  - "127.0.0.1:${WEB_PORT:-8222}:8000"
```

Publishes container port 8000 through the selected host port.

## 31.9 Web Environment

The service configuration supplies the Redis hostname, port, counter key, and application title.

## 31.10 Dependency Condition

```yaml
depends_on:
  redis:
    condition: service_healthy
```

Requires Redis to satisfy its health check before the web service starts during the applicable Compose startup operation.

## 31.11 Web Readiness Health Check

The web health check requests:

```text
http://127.0.0.1:8000/ready
```

inside the web container.

The readiness endpoint checks Redis connectivity.

## 31.12 Restart Policy

```yaml
restart: unless-stopped
```

Configures container restart behavior for qualifying process exits.

It does not automatically restart a running container merely because its health status changes to unhealthy.

---

# PART III — PRACTICAL LABORATORY 12

# 32. EXPERIMENT 1 — VERIFY THE ENVIRONMENT

Execute:

```bash
docker version
```

Then:

```bash
docker compose version
```

**Objective:**

Confirm Docker and Compose availability.

**Required observations:**

1. Docker Engine version.
2. Docker Compose version.
3. Docker daemon availability.
4. Operating-system environment.

---

# 33. EXPERIMENT 2 — CREATE THE PROJECT

Create the directory:

```bash
mkdir docker-lecture12
```

Enter it:

```bash
cd docker-lecture12
```

Create the required files according to Sections 23–30.

**Objective:**

Establish the complete application source and configuration.

**Required result:**

The directory contains:

- `app.py`
- `requirements.txt`
- `Dockerfile`
- `compose.yaml`
- `.dockerignore`
- `.env`

---

# 34. EXPERIMENT 3 — VALIDATE THE COMPOSE MODEL

Execute:

```bash
docker compose config -q
```

**Objective:**

Validate the configuration syntax and Compose model.

**Expected result:**

The command completes successfully.

Now execute:

```bash
docker compose config
```

**Required observations:**

Identify the resolved:

1. Web host port.
2. Redis service configuration.
3. Application environment variables.
4. Network definition.
5. Named volume.
6. Dependency condition.
7. Health checks.

---

# 35. EXPERIMENT 4 — BUILD THE WEB IMAGE

Execute:

```bash
docker compose build web
```

**Objective:**

Construct the custom Flask application image.

**Expected build operations:**

1. Resolve the Python base image.
2. Set the working directory.
3. Copy the dependency manifest.
4. Install Python dependencies.
5. Copy the application source.
6. Configure the execution identity.
7. Record the Gunicorn command.
8. Export the image.

Verify:

```bash
docker image ls lecture12-web
```

**Required analysis:**

Explain why the Redis service is not built from the application's Dockerfile.

---

# 36. EXPERIMENT 5 — START THE COMPLETE APPLICATION

Execute:

```bash
docker compose up -d
```

**Objective:**

Create and start the two-service application.

**Expected behavior:**

Compose:

1. Creates the backend network.
2. Creates the Redis named volume.
3. Starts Redis.
4. Evaluates Redis health.
5. Starts the web service when its dependency condition is satisfied.
6. Configures the web port mapping.
7. Starts the Flask application through Gunicorn.

Verify:

```bash
docker compose ps
```

**Expected result:**

Both services are running.

Their health status should become healthy after the configured checks succeed.

---

# 37. EXPERIMENT 6 — ACCESS THE USER INTERFACE

Open:

http://127.0.0.1:8222

**Objective:**

Verify that the Flask application is reachable through the published host port.

**Expected result:**

The page displays:

**Docker Compose Counter Laboratory**

and a counter value.

If the Redis counter key does not yet exist, the displayed value should initially be:

```text
0
```

**Required analysis:**

Explain the complete communication path from the browser to Flask.

---

# 38. EXPERIMENT 7 — RETRIEVE THE COUNTER THROUGH HTTP

Open:

http://127.0.0.1:8222/api/count

**Expected response:**

```json
{
  "count": 0
}
```

If the counter has already been incremented, the returned value will reflect its current stored state.

**Objective:**

Investigate a read-only API operation.

**Required analysis:**

Explain why a GET request to this endpoint should not change the counter.

---

# 39. EXPERIMENT 8 — INCREMENT THE COUNTER

Return to:

http://127.0.0.1:8222

Press:

**Increment Counter**

**Expected result:**

The displayed number increases by one.

Press the button several times.

**Objective:**

Verify the complete browser-to-Flask-to-Redis communication path.

**Required analysis:**

Identify:

1. The browser HTTP method.
2. The Flask route.
3. The Redis command.
4. The stored key.
5. The response representation.

---

# 40. EXPERIMENT 9 — TEST THE API DIRECTLY

Using a terminal with `curl` available, execute:

```bash
curl -i -X POST http://127.0.0.1:8222/api/increment
```

**Objective:**

Test the state-changing API independently of the web interface.

**Expected result:**

HTTP status:

```text
200 OK
```

The response body contains the updated count.

For example:

```json
{
  "count": 5,
  "result": "incremented"
}
```

The exact count depends on previous operations.

**Required analysis:**

Explain why the HTTP client is not required to be a browser.

---

# 41. EXPERIMENT 10 — INSPECT REDIS DATA DIRECTLY

Execute:

```bash
docker compose exec redis redis-cli GET lecture12:counter
```

**Objective:**

Verify that Redis stores the counter value.

**Expected result:**

The command displays the current numeric value.

Now execute:

```bash
docker compose exec redis redis-cli TYPE lecture12:counter
```

**Expected result:**

```text
string
```

**Required analysis:**

Explain why the counter value is stored in Redis rather than in the Flask container's writable filesystem.

---

# 42. EXPERIMENT 11 — MODIFY THE COUNTER OUTSIDE FLASK

Execute:

```bash
docker compose exec redis redis-cli INCR lecture12:counter
```

**Objective:**

Modify shared state directly through the database.

Now refresh the web page.

**Expected result:**

The page displays the newly incremented value.

**Technical interpretation:**

Flask does not maintain the authoritative counter value in its own process memory.

It reads the current value from Redis.

---

# 43. EXPERIMENT 12 — VERIFY CONTAINER DNS RESOLUTION

Execute:

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('redis'))"
```

**Objective:**

Demonstrate service-name resolution from the Flask container.

**Expected result:**

Docker resolves the service name `redis` to an IP address associated with the Redis container's network endpoint.

The exact address depends on Docker networking configuration.

**Required analysis:**

Explain why this hostname remains useful even if the Redis container is recreated with a different IP address.

---

# 44. EXPERIMENT 13 — VERIFY PYTHON-TO-REDIS CONNECTIVITY

Execute:

```bash
docker compose exec web python -c "import redis; client=redis.Redis(host='redis', port=6379); print(client.ping())"
```

**Objective:**

Test Redis connectivity directly from inside the Flask image.

**Expected result:**

```text
True
```

**Required analysis:**

Explain how this test differs from invoking Redis CLI inside the Redis container.

---

# 45. EXPERIMENT 14 — INSPECT NETWORK CONFIGURATION

Execute:

```bash
docker network ls
```

Identify the Compose-managed backend network.

Its ordinary name is:

```text
lecture12-counter_backend
```

Inspect:

```bash
docker network inspect lecture12-counter_backend
```

**Objective:**

Examine the shared container network.

**Required observations:**

1. Network driver.
2. Network subnet.
3. Gateway.
4. Web container attachment.
5. Redis container attachment.

**Required analysis:**

Explain why both services can communicate without publishing Redis port 6379 to the host.

---

# 46. EXPERIMENT 15 — VERIFY REDIS IS NOT HOST-PUBLISHED

Execute:

```bash
docker compose ps
```

**Objective:**

Examine the exposed and published ports of both services.

**Expected observations:**

The web service has a host port mapping.

The Redis service does not have a host-published port.

Redis still listens on TCP port 6379 within its container networking environment.

**Required analysis:**

Explain why container network access and host port publishing are separate mechanisms.

---

# 47. EXPERIMENT 16 — VERIFY LIVENESS

Open:

http://127.0.0.1:8222/health

**Expected response:**

```json
{
  "service": "web",
  "status": "alive"
}
```

**Objective:**

Verify the basic application liveness endpoint.

**Required analysis:**

Explain why a successful response does not necessarily establish that Redis is available.

---

# 48. EXPERIMENT 17 — VERIFY READINESS

Open:

http://127.0.0.1:8222/ready

**Expected response:**

```json
{
  "redis": "available",
  "status": "ready"
}
```

**Objective:**

Verify the application's ability to communicate with its Redis dependency.

**Required analysis:**

Compare the meaning of `/health` and `/ready`.

---

# 49. EXPERIMENT 18 — INSPECT COMPOSE HEALTH STATUS

Execute:

```bash
docker compose ps
```

Then:

```bash
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q web)"
```

The second command uses Unix-style command substitution.

For terminals that do not support this syntax, retrieve the container identifier using:

```bash
docker compose ps -q web
```

Then substitute that identifier into `docker inspect`.

**Objective:**

Examine the web container's recorded health-check results.

**Required analysis:**

Explain how the health-check command determines whether the web container is healthy.

---

# 50. EXPERIMENT 19 — INSPECT APPLICATION LOGS

Execute:

```bash
docker compose logs web
```

Then:

```bash
docker compose logs redis
```

**Objective:**

Examine the output generated by the two application services.

**Expected observations:**

The web logs contain Gunicorn startup information and HTTP request records.

The Redis logs contain database startup and persistence information.

**Required analysis:**

Explain why service-specific logs are useful when diagnosing a multi-container application.

---

# 51. EXPERIMENT 20 — TEST REDIS UNAVAILABILITY

Stop Redis:

```bash
docker compose stop redis
```

Do not stop the web service.

**Objective:**

Introduce a controlled dependency failure.

Now open:

http://127.0.0.1:8222/health

**Expected result:**

The basic liveness endpoint may continue returning HTTP 200.

Next, open:

http://127.0.0.1:8222/ready

**Expected result:**

The readiness endpoint returns HTTP 503.

The response indicates that Redis is unavailable.

Finally, open:

http://127.0.0.1:8222/api/count

**Expected result:**

The counter endpoint returns a controlled service-unavailable error.

**Required analysis:**

1. Why does Gunicorn remain running?
2. Why can liveness remain successful?
3. Why does readiness fail?
4. Why does `depends_on` not automatically terminate the web service?
5. What does this experiment demonstrate about runtime dependencies?

---

# 52. EXPERIMENT 21 — INSPECT HEALTH AFTER REDIS FAILURE

After sufficient time for health-check retries, execute:

```bash
docker compose ps
```

**Objective:**

Observe the web service's health classification after the dependency failure.

**Expected result:**

The web container may become unhealthy because its configured readiness check fails.

Its principal Gunicorn process can remain running.

**Required analysis:**

Explain why the unhealthy state does not automatically imply that Docker must remove or restart the container.

---

# 53. EXPERIMENT 22 — RESTORE REDIS CONNECTIVITY

Execute:

```bash
docker compose start redis
```

Verify Redis operation:

```bash
docker compose exec redis redis-cli PING
```

Expected response:

```text
PONG
```

Now open:

http://127.0.0.1:8222/ready

**Expected result:**

The readiness endpoint returns HTTP 200 after Redis becomes available.

Open:

http://127.0.0.1:8222/api/count

The stored count should be accessible again.

**Objective:**

Demonstrate application recovery without rebuilding the web image.

**Required analysis:**

Explain how the Redis client establishes a new usable connection after the dependency becomes available.

---

# 54. EXPERIMENT 23 — EXAMINE REDIS PERSISTENCE

Execute:

```bash
docker compose exec redis redis-cli CONFIG GET appendonly
```

**Expected result:**

The setting is enabled.

Then:

```bash
docker compose exec redis redis-cli CONFIG GET dir
```

**Expected result:**

Redis uses `/data`.

Inspect the directory:

```bash
docker compose exec redis ls -la /data
```

**Objective:**

Examine the database's persistence configuration and filesystem.

**Required analysis:**

Explain the relationship between the Redis AOF mechanism and the Docker named volume.

---

# 55. EXPERIMENT 24 — VERIFY VOLUME CONFIGURATION

Execute:

```bash
docker volume ls
```

Identify:

```text
lecture12-counter_redis-data
```

Inspect:

```bash
docker volume inspect lecture12-counter_redis-data
```

**Objective:**

Verify that Docker maintains the Redis storage independently of its container writable layer.

**Required observations:**

1. Volume name.
2. Volume driver.
3. Mountpoint.
4. Associated project information.

---

# 56. EXPERIMENT 25 — TEST ATOMIC INCREMENTS

First, retrieve the current count:

```bash
curl http://127.0.0.1:8222/api/count
```

Record the result.

Now execute 20 concurrent HTTP requests from within the web container:

```bash
docker compose exec web python -c "from concurrent.futures import ThreadPoolExecutor; import urllib.request; request=lambda _: urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8000/api/increment', method='POST'), timeout=5).read(); list(ThreadPoolExecutor(max_workers=5).map(request, range(20))); print('20 increments completed')"
```

**Objective:**

Demonstrate multiple concurrent attempts to modify the shared counter.

Retrieve the final count:

```bash
curl http://127.0.0.1:8222/api/count
```

**Expected result:**

If all 20 requests completed successfully and no other increments occurred, the final counter is exactly 20 greater than the initial value.

**Technical interpretation:**

Each request executes Redis `INCR`.

The atomic operation prevents the lost-update behavior associated with separate read-and-write operations.

**Required analysis:**

Explain why this behavior is important when Gunicorn uses multiple worker processes.

---

# 57. EXPERIMENT 26 — VERIFY DATA SURVIVAL AFTER APPLICATION REMOVAL

Request an explicit Redis snapshot:

```bash
docker compose exec redis redis-cli SAVE
```

Now remove the Compose application:

```bash
docker compose down
```

**Objective:**

Remove the service containers and project network while retaining the named Redis volume.

Verify:

```bash
docker volume inspect lecture12-counter_redis-data
```

**Expected result:**

The volume remains available.

Now recreate the application:

```bash
docker compose up -d
```

Open:

http://127.0.0.1:8222/api/count

**Expected result:**

The previously stored counter value remains available.

**Required analysis:**

Explain why the data survived even though the Redis container was removed and recreated.

---

# 58. EXPERIMENT 27 — MODIFY APPLICATION SOURCE CODE

Open:

```text
app.py
```

Find the HTML heading:

```html
<h2>Docker Lecture 12</h2>
```

Change it to:

```html
<h2>Docker Lecture 12 — Updated Application</h2>
```

Save the file.

Execute:

```bash
docker compose up -d --build
```

**Objective:**

Rebuild and redeploy the updated Flask application.

Open:

http://127.0.0.1:8222

**Expected result:**

The updated heading appears.

The Redis counter retains its value.

**Required analysis:**

Explain why rebuilding the web image does not require deleting the Redis data volume.

---

# 59. EXPERIMENT 28 — MODIFY RUNTIME CONFIGURATION

Open:

```text
.env
```

Change:

```text
APP_NAME=Docker Compose Counter Laboratory
```

to:

```text
APP_NAME=Advanced Compose Counter
```

Save the file.

Validate:

```bash
docker compose config
```

Apply the configuration:

```bash
docker compose up -d
```

**Objective:**

Change the application's display name without modifying the Flask source code.

Open:

http://127.0.0.1:8222

**Expected result:**

The application title changes.

**Required analysis:**

Explain how Compose interpolation, container environment configuration, and application code interact.

---

# 60. EXPERIMENT 29 — EXAMINE IMAGE AND CONTAINER INDEPENDENCE

Execute:

```bash
docker image inspect lecture12-web:v1
```

Then:

```bash
docker compose ps
```

Then:

```bash
docker compose exec web id
```

**Objective:**

Distinguish:

1. Image metadata.
2. Container runtime state.
3. Process execution identity.
4. Application configuration.
5. Persistent database state.

**Required analysis:**

Explain why modifying Redis data does not require modification of the Flask image.

---

# 61. EXPERIMENT 30 — CONTROLLED CLEANUP

Stop and remove the Compose application while retaining persistent data:

```bash
docker compose down
```

Verify the volume:

```bash
docker volume ls
```

The Redis data volume remains available.

**Optional destructive cleanup:**

If the laboratory data is no longer required, use the appropriate volume removal procedure deliberately.

For example, after ensuring no container references the volume:

```bash
docker volume rm lecture12-counter_redis-data
```

**Critical warning:**

Removing the named volume deletes the stored Redis data.

Do not execute volume-removal commands if the counter data must be retained.

---

# 62. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation | Observed result |
|---|---|---|
| 1 | Docker environment verification | |
| 2 | Project creation | |
| 3 | Compose validation | |
| 4 | Web image build | |
| 5 | Application startup | |
| 6 | User-interface access | |
| 7 | Counter retrieval | |
| 8 | Browser-based increment | |
| 9 | Direct HTTP API request | |
| 10 | Redis data inspection | |
| 11 | Direct Redis modification | |
| 12 | Container DNS resolution | |
| 13 | Python-to-Redis connectivity | |
| 14 | Network inspection | |
| 15 | Redis port publishing examination | |
| 16 | Liveness verification | |
| 17 | Readiness verification | |
| 18 | Health status inspection | |
| 19 | Service log inspection | |
| 20 | Controlled Redis failure | |
| 21 | Health classification during failure | |
| 22 | Redis recovery | |
| 23 | Persistence configuration | |
| 24 | Named volume inspection | |
| 25 | Concurrent increment test | |
| 26 | Data survival after recreation | |
| 27 | Application image rebuild | |
| 28 | Runtime configuration update | |
| 29 | Image and container independence | |
| 30 | Controlled cleanup | |

## Laboratory Conclusion

Prepare a conclusion of approximately 300–450 words addressing:

1. How Flask communicates with Redis.
2. Why Compose service names are used instead of static container IP addresses.
3. Why the counter is stored in Redis rather than process memory.
4. How Redis `INCR` supports concurrent requests.
5. How named volumes preserve data after container replacement.
6. How readiness differs from liveness.
7. Why the web container can remain running when Redis fails.
8. Why application rebuilding does not require deleting database state.
9. What additional controls would be necessary for production deployment.

---

# PART IV — COMPREHENSIVE TROUBLESHOOTING

# 63. ERROR CATEGORY: FLASK CANNOT RESOLVE REDIS

## Symptoms

The application returns HTTP 503.

Redis operations fail with name-resolution errors.

## Possible Causes

- Incorrect `REDIS_HOST`.
- Services attached to different networks.
- Redis service name misspelled.
- Incorrect Compose project configuration.
- Network endpoint not available.

## Investigation

Execute:

```bash
docker compose config
```

Inspect the network:

```bash
docker network inspect lecture12-counter_backend
```

Test DNS from the web container:

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('redis'))"
```

## Corrective Principle

Ensure both services share the intended Docker network and use the correct service hostname.

---

# 64. ERROR CATEGORY: REDIS CONNECTION REFUSED

## Symptoms

The hostname resolves but the connection cannot be established.

## Possible Causes

- Redis process not running.
- Redis not yet ready.
- Wrong destination port.
- Incorrect listening configuration.
- Network restrictions.

## Investigation

```bash
docker compose ps
```

```bash
docker compose logs redis
```

```bash
docker compose exec redis redis-cli PING
```

## Corrective Principle

Successful DNS resolution and successful application connectivity are separate requirements.

---

# 65. ERROR CATEGORY: WEB CONTAINER EXITS

## Symptoms

The web service repeatedly starts and exits.

## Possible Causes

- Missing Python dependency.
- Invalid Python syntax.
- Incorrect Gunicorn application reference.
- Invalid environment configuration.
- Incorrect Dockerfile command.
- Insufficient filesystem access.

## Investigation

```bash
docker compose logs web
```

Inspect the image and Compose configuration.

## Corrective Principle

Resolve the application or image error rather than relying exclusively on restart policies.

---

# 66. ERROR CATEGORY: COUNTER DOES NOT INCREMENT

## Symptoms

The page loads, but pressing the button does not change the displayed value.

## Possible Causes

- Browser JavaScript error.
- Wrong API path.
- Incorrect HTTP method.
- Redis unavailable.
- Flask route failure.
- Invalid Redis counter value.

## Investigation

1. Examine browser developer tools.
2. Check the network request.
3. Inspect HTTP response status.
4. Read Flask logs.
5. Query the Redis key directly.

## Corrective Principle

Trace the operation across each application boundary.

---

# 67. ERROR CATEGORY: COUNTER DATA DISAPPEARS

## Possible Causes

- Redis volume removed.
- Different Compose project name.
- Different named volume.
- Persistence disabled.
- Wrong Redis data directory.
- Redis storage failure.
- Counter key deleted.

## Investigation

```bash
docker volume ls
```

```bash
docker compose exec redis redis-cli CONFIG GET dir
```

```bash
docker compose exec redis redis-cli CONFIG GET appendonly
```

## Corrective Principle

Verify both application-level persistence and Docker storage configuration.

---

# 68. ERROR CATEGORY: SERVICE REMAINS UNHEALTHY

## Symptoms

The web application process is running but Docker reports unhealthy status.

## Possible Causes

- Redis unavailable.
- Readiness endpoint returning HTTP 503.
- Health-check command failure.
- Incorrect internal port.
- Timeout too short.
- Missing health-check executable.

## Investigation

Inspect:

```bash
docker compose ps
```

Then examine the recorded health-check output using Docker inspection.

## Corrective Principle

An unhealthy state reflects the result of the configured test.

It does not automatically indicate that the web process has terminated.

---

# 69. ERROR CATEGORY: WRONG HOST PORT

## Symptoms

The browser cannot reach the web application.

## Possible Causes

- Incorrect `.env` value.
- Host port already occupied.
- Wrong port mapping.
- Application not listening on port 8000.
- Docker Engine unavailable.

## Investigation

```bash
docker compose config
```

```bash
docker compose ps
```

## Corrective Principle

Distinguish the published host port from the application listening port inside the container.

---

# 70. ERROR CATEGORY: CONFIGURATION NOT APPLIED

## Symptoms

Changes to `.env` or the Compose file do not appear in the running application.

## Explanation

Existing container configuration may require recreation.

## Recommended Operation

```bash
docker compose up -d
```

If the source code or image build inputs changed:

```bash
docker compose up -d --build
```

## Important Principle

Rebuilding an image and recreating a container are related but distinct operations.

---

# PART V — ARCHITECTURAL ANALYSIS

# 71. COMPARISON WITH A SINGLE-CONTAINER APPLICATION

| Characteristic | Single-container design | Flask-and-Redis design |
|---|---|---|
| Application components | One combined execution environment | Separate web and database services |
| Data location | May be local to application | External Redis service |
| Network dependency | Potentially minimal | Required between services |
| State sharing | Process or container dependent | Shared Redis state |
| Application replacement | May affect local state | Web process can be replaced independently |
| Persistent storage | Must be designed explicitly | Redis named volume |
| Operational complexity | Lower | Higher |
| Service separation | Limited | Explicit |

## 71.1 Benefits

The multi-container design provides improved separation between application logic and database state.

## 71.2 Costs

The design also introduces:

- Network dependencies.
- Additional configuration.
- More service lifecycle operations.
- More complicated failure analysis.

## 71.3 Engineering Principle

Service separation should be justified by application requirements rather than adopted automatically in every situation.

---

# 72. APPLICATION AND DATABASE LIFECYCLE SEPARATION

The system contains three important resource categories.

**Application image:** Packages Flask and its dependencies.

**Application containers:** Execute Flask and Redis processes.

**Named volume:** Retains Redis persistence files.

These resources have different lifecycles.

```text
         APPLICATION SOURCE
                 |
                 v
            WEB IMAGE
                 |
                 v
           WEB CONTAINER
                 |
                 |
             REDIS NETWORK
                 |
                 v
          REDIS CONTAINER
                 |
                 v
            NAMED VOLUME
```

Removing the web container does not automatically remove the Redis volume.

Removing the Redis container does not automatically delete the named volume.

However, removing the volume can destroy the stored data.

---

# 73. ATOMIC OPERATIONS AND SCALABILITY

## 73.1 Multiple Application Workers

Gunicorn can run several workers.

Each worker can receive independent requests.

## 73.2 Shared Counter State

All workers communicate with the same Redis instance.

The counter value is therefore not tied to an individual Python worker.

## 73.3 Atomic Increment

Redis `INCR` supports safe counter increments under concurrent client requests.

## 73.4 Limitations

The use of Redis does not automatically guarantee:

- Unlimited scalability.
- High availability.
- Zero data loss.
- Automatic failover.
- Database replication.
- Transactional consistency across unrelated services.

These require additional design decisions.

---

# 74. RELIABILITY AND FAILURE DOMAINS

## 74.1 Definition

A failure domain is a collection of components that may be affected by a particular failure event.

## 74.2 Web Failure

If Gunicorn terminates, the web application becomes unavailable.

Redis and its stored data may remain intact.

## 74.3 Redis Failure

If Redis becomes unavailable, the web application process can remain running.

However, operations requiring Redis cannot complete successfully.

## 74.4 Host Failure

If the Docker host becomes unavailable, both services may be affected.

A named local volume does not automatically protect the system against complete host failure.

## 74.5 Operational Conclusion

Separating services creates more explicit failure boundaries, but it does not automatically provide fault tolerance or high availability.

---

# 75. PRODUCTION DESIGN LIMITATIONS

The laboratory demonstrates several useful engineering practices.

However, it is not a complete production deployment.

Additional requirements would include:

1. Authentication and authorization.
2. Appropriate request limits.
3. TLS and secure ingress.
4. Redis authentication and protected credentials.
5. Backup and recovery procedures.
6. Monitoring and alerting.
7. Resource limits.
8. Dependency updates.
9. Container image security scanning.
10. Appropriate log retention.
11. Health-check policy design.
12. High-availability requirements.
13. Network access restrictions.
14. Application error observability.
15. Controlled deployment and rollback procedures.

These subjects will be developed during the later lectures.

---

# PART VI — COMMON CONCEPTUAL MISUNDERSTANDINGS

# 76. FREQUENT ERRORS

## Misunderstanding 1

**Two containers in the same Compose project automatically exchange application data.**

Incorrect.

Application communication requires implemented protocols and application logic.

## Misunderstanding 2

**Flask and Gunicorn are the same component.**

Incorrect.

Flask is the web application framework.

Gunicorn is a WSGI server that can run Flask applications.

## Misunderstanding 3

**The browser communicates directly with Redis.**

Incorrect in this architecture.

The browser communicates with Flask.

Flask communicates with Redis.

## Misunderstanding 4

**The Redis hostname must be a fixed IP address.**

Incorrect.

Docker's service-name discovery allows the application to use the logical hostname `redis`.

## Misunderstanding 5

**Redis requires a published host port for Flask connectivity.**

Incorrect.

Both services communicate through the Compose network.

## Misunderstanding 6

**An ordinary Python global variable provides reliable shared state across all Gunicorn workers.**

Incorrect.

Separate worker processes do not automatically share mutable Python memory.

## Misunderstanding 7

**A GET request is the preferred mechanism for modifying a counter.**

Incorrect.

A state-changing POST operation is more appropriate.

## Misunderstanding 8

**A Redis GET followed by SET is always equivalent to INCR.**

Incorrect.

Separate operations can introduce lost-update races.

## Misunderstanding 9

**A running web container guarantees Redis is available.**

Incorrect.

Application dependencies can fail independently.

## Misunderstanding 10

**A successful liveness check guarantees complete application readiness.**

Incorrect.

Liveness and readiness evaluate different conditions.

## Misunderstanding 11

**depends_on prevents Redis from failing after startup.**

Incorrect.

Dependency conditions do not eliminate runtime failures.

## Misunderstanding 12

**An unhealthy container is always restarted automatically.**

Incorrect.

Health status does not inherently trigger restart-policy recovery.

## Misunderstanding 13

**A Docker volume guarantees zero database data loss.**

Incorrect.

Application persistence settings and underlying storage behavior still matter.

## Misunderstanding 14

**Rebuilding Flask requires deleting the Redis database.**

Incorrect.

The application image and database volume have independent lifecycles.

## Misunderstanding 15

**A valid Compose file guarantees a correct application.**

Incorrect.

Application code, dependencies, network connectivity, and storage must also function correctly.

---

# PART VII — IMPORTANT TECHNICAL TERMINOLOGY

# 77. ACADEMIC GLOSSARY

| Term | Academic definition |
|---|---|
| Multi-container application | System composed of cooperating containerized components |
| Service integration | Application-level communication among separate services |
| Flask | Python web application framework |
| Gunicorn | Python WSGI HTTP server |
| WSGI | Standard interface between Python web applications and compatible servers |
| HTTP | Application protocol for web communication |
| HTTP method | Operation type associated with an HTTP request |
| GET | HTTP method intended to retrieve resource representations |
| POST | HTTP method used to submit processing requests |
| API | Application Programming Interface |
| REST | Architectural style emphasizing resource-oriented interfaces |
| JSON | Structured text data interchange format |
| Redis | In-memory data system supporting key-value and other structures |
| redis-py | Python client library for Redis |
| Key-value store | Data model associating keys with stored values |
| Counter | Numeric state changed through defined operations |
| Atomic operation | Operation performed as an indivisible logical action |
| Lost update | Concurrency anomaly where one update overwrites another |
| Shared state | Information accessed by multiple application processes |
| Process-local state | Information maintained within one process's memory |
| Service discovery | Identification of service network endpoints |
| Embedded DNS | Docker name-resolution mechanism |
| Application port | Port on which an application accepts network requests |
| Environment variable | Named value supplied to an application process |
| Build context | Filesystem input available to the image builder |
| Non-root execution | Running a process without root user identity |
| AOF | Redis append-only persistence mechanism |
| Named volume | Docker-managed persistent storage resource |
| Liveness | Basic responsiveness of an application process |
| Readiness | Ability of an application to perform required operations |
| Health check | Runtime test used to evaluate application condition |
| depends_on | Compose dependency and startup-order configuration |
| HTTP 503 | Service Unavailable status response |
| Connection timeout | Limit on the duration of a network operation |
| Error handling | Controlled response to expected failure conditions |
| Failure domain | Components affected by a particular failure |
| Persistence | Retention of application state beyond a process lifecycle |
| Application deployment | Process of making software available for execution |

---

# PART VIII — FORMAL ACADEMIC ASSESSMENT

# 78. PART A — FORMAL DEFINITIONS

Provide technically precise definitions for:

1. Multi-container application.
2. Service integration.
3. Flask.
4. Gunicorn.
5. WSGI.
6. Redis.
7. Key-value storage.
8. Atomic increment.
9. Shared application state.
10. Service discovery.
11. Application readiness.
12. Application liveness.
13. Append-only persistence.
14. Failure domain.
15. Dependency recovery.

---

# 79. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why a Compose project containing several running services does not necessarily constitute an integrated application.

**Question 2.**

Describe the relationship between Flask, Gunicorn, and Docker.

**Question 3.**

Explain the responsibilities of Redis in the counter application.

**Question 4.**

Describe why the browser communicates with Flask rather than directly with Redis.

**Question 5.**

Explain why the Redis service hostname is used instead of a hard-coded IP address.

**Question 6.**

Describe why Redis port 6379 does not need to be published on the Docker host.

**Question 7.**

Explain how the Flask application retrieves its Redis connection parameters.

**Question 8.**

Compare GET and POST in the context of the counter API.

**Question 9.**

Explain why the `INCR` command is preferable to a naive GET-and-SET sequence.

**Question 10.**

Describe why a Python global variable is insufficient as the sole shared counter storage when Gunicorn uses multiple worker processes.

**Question 11.**

Explain how Redis persistence and Docker named volumes work together.

**Question 12.**

Distinguish application liveness from application readiness.

**Question 13.**

Explain the purpose of `condition: service_healthy`.

**Question 14.**

Describe why the Flask application can remain running when Redis becomes unavailable.

**Question 15.**

Explain how application rebuilding can occur without deleting persistent Redis data.

---

# 80. PART C — CODE INTERPRETATION

Consider:

```python
client = redis.Redis(
    host="redis",
    port=6379,
    decode_responses=True
)
```

Answer:

1. What object is created?
2. What does the hostname `redis` represent?
3. Which port is used?
4. What does `decode_responses=True` accomplish?
5. Does client construction necessarily prove Redis connectivity?

Consider:

```python
value = client.get("lecture12:counter")
```

Answer:

6. Which operation is performed?
7. Does this operation modify the counter?
8. What result may be returned when the key is absent?

Consider:

```python
value = client.incr("lecture12:counter")
```

Answer:

9. Which operation is performed?
10. Why is this operation useful under concurrent requests?

Consider:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

Answer:

11. What dependency is declared?
12. What condition must be satisfied during startup?
13. Does the condition guarantee that Redis will never fail later?

Consider:

```yaml
volumes:
  - redis-data:/data
```

Answer:

14. What is the storage source?
15. What is the destination inside the container?

---

# 81. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Lost Counter Updates

A developer implements a counter using separate GET and SET operations.

Two requests execute concurrently.

Both read the same initial value and write the same incremented value.

Analyze the concurrency problem.

Explain how Redis `INCR` provides a better solution.

## Case Study 2 — Dependency Failure

The Redis container stops.

Gunicorn continues executing.

The web page is accessible, but counter operations return HTTP 503.

Analyze why the application behaves this way.

Explain the distinction between process liveness and functional readiness.

## Case Study 3 — Incorrect Hostname

A Flask developer configures:

```text
REDIS_HOST=localhost
```

Redis executes in another Compose container.

The connection fails.

Explain the cause.

Recommend the correct configuration.

## Case Study 4 — Missing Database Persistence

A Redis container stores values in memory.

No suitable persistence mechanism is configured.

The container is removed and recreated.

The data disappears.

Explain why a container restart and database recovery are different problems.

Recommend a complete persistence configuration.

## Case Study 5 — Image Rebuild

The Flask source code changes.

The developer rebuilds the web image.

Redis data remains available.

Explain which resources changed and which did not.

Discuss the architectural importance of independent lifecycles.

## Case Study 6 — Incomplete Security

A developer publishes Redis port 6379 to all host interfaces without authentication.

Evaluate the security risks.

Recommend safer networking and authentication practices.

---

# 82. PRACTICAL ASSESSMENT

**Total available marks: 100**

| Assessment category | Marks |
|---|---:|
| Application architecture and theory | 15 |
| Flask API implementation | 20 |
| Redis integration and atomic operations | 15 |
| Dockerfile construction | 10 |
| Compose networking and configuration | 15 |
| Persistence and failure recovery | 15 |
| Technical documentation | 10 |
| **Total** | **100** |

**Recommended passing score:** 80/100.

The student should demonstrate both a correctly functioning application and the ability to explain why each architectural component is necessary.

---

# 83. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Stateful Multi-Container Application Construction with Flask, Redis, and Docker Compose

Prepare an academic report of approximately 1,200–1,800 words addressing:

**“Application-Level Integration in Docker Compose: HTTP Service Architecture, Redis Communication, Shared State, Persistence, and Dependency Management.”**

The report must include:

1. Introduction to multi-container application design.
2. Explanation of service responsibility separation.
3. Description of Flask.
4. Description of Gunicorn and WSGI.
5. Explanation of Redis.
6. Analysis of the application request flow.
7. Explanation of Compose service-name discovery.
8. Discussion of environment-based connection configuration.
9. Analysis of atomic counter operations.
10. Comparison of process-local state and external state.
11. Explanation of Redis persistence.
12. Discussion of named Docker volumes.
13. Examination of health checks.
14. Comparison of liveness and readiness.
15. Analysis of controlled dependency failures.
16. Security evaluation.
17. Description of laboratory results.
18. Technical conclusion.

The report should contain at least two architectural diagrams and selected application-code examples.

---

# 84. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 13, verify the following.

## Application Architecture

- [ ] I can define a multi-container application.
- [ ] I can explain service integration.
- [ ] I can describe the browser-to-Flask-to-Redis communication path.
- [ ] I understand the separation of application logic and data storage.

## Flask and HTTP

- [ ] I can create a Flask application.
- [ ] I can define GET routes.
- [ ] I can define POST routes.
- [ ] I can return JSON responses.
- [ ] I can distinguish read-only and state-changing operations.
- [ ] I can explain HTTP status codes used by the application.

## Redis

- [ ] I can create a Python Redis client.
- [ ] I can connect using a Compose service hostname.
- [ ] I can use GET and SET.
- [ ] I can use INCR.
- [ ] I understand atomic increment operations.
- [ ] I can explain why Redis stores shared application state.

## Dockerfile

- [ ] I can create the Flask Dockerfile.
- [ ] I can install Python dependencies.
- [ ] I can explain dependency-layer caching.
- [ ] I can configure non-root execution.
- [ ] I can explain the Gunicorn startup command.

## Docker Compose

- [ ] I can define both services.
- [ ] I can configure the internal network.
- [ ] I can configure a named Redis volume.
- [ ] I can publish only the web port.
- [ ] I can supply runtime environment variables.
- [ ] I can use project `.env` interpolation.
- [ ] I can define `depends_on`.
- [ ] I can configure health checks.

## Persistence

- [ ] I can configure Redis AOF persistence.
- [ ] I can inspect the Redis data directory.
- [ ] I can verify the Docker named volume.
- [ ] I can remove and recreate the application.
- [ ] I can demonstrate counter-data survival.

## Reliability

- [ ] I can explain application liveness.
- [ ] I can explain application readiness.
- [ ] I can diagnose Redis unavailability.
- [ ] I can interpret HTTP 503 errors.
- [ ] I can restore Redis service operation.
- [ ] I can demonstrate recovery without rebuilding Flask.

## Practical Laboratory

- [ ] I created all required files.
- [ ] I validated the Compose model.
- [ ] I built the application image.
- [ ] I started both services.
- [ ] I used the browser interface.
- [ ] I tested the API directly.
- [ ] I verified the Redis counter.
- [ ] I inspected DNS resolution.
- [ ] I inspected networks and volumes.
- [ ] I tested concurrent increment operations.
- [ ] I tested dependency failure and recovery.
- [ ] I verified data persistence after recreation.
- [ ] I rebuilt the web application.
- [ ] I completed the laboratory report.

**Completion standard:**

The student should be able to construct and explain an integrated two-service application in which a web service accesses shared state through a Docker network and retains that state through an independently managed persistent storage resource.

---

# 85. LECTURE SUMMARY

Lecture 12 introduces application-level integration within Docker Compose.

The preceding lecture established how Compose can configure and operate multiple services as one application.

The present lecture demonstrates how those services can perform useful work through explicit application communication.

Flask provides the HTTP application framework.

Gunicorn provides the WSGI server used to execute Flask.

Redis provides shared key-value storage.

Docker Compose configures the required images, containers, network, environment variables, health checks, and named volume.

The browser communicates with Flask using HTTP.

Flask communicates with Redis using the Redis protocol over TCP.

The application stores its visitor counter externally rather than relying on process-local Python variables.

Redis `INCR` provides an atomic increment operation suitable for concurrent client requests.

The Redis persistence mechanism writes recoverable database state to files stored within a Docker named volume.

The application can therefore be recreated without automatically losing its counter value.

Liveness and readiness endpoints provide different diagnostic perspectives.

A web process can remain responsive even when Redis is unavailable.

A readiness check can report that the application cannot currently perform its required counter operations.

Controlled failure experiments demonstrate that startup ordering does not eliminate runtime dependency failures.

The application must manage those failures through appropriate error handling and recovery behavior.

**The central principle of this lecture is that a functioning multi-container application requires both infrastructure composition and explicit application-level cooperation, supported by reliable communication, shared state, persistent storage, and meaningful failure handling.**

---

# 86. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. *Docker Compose Quickstart — Flask and Redis.*  
https://docs.docker.com/compose/gettingstarted/

[2] Docker Inc. *Docker Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[3] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[4] Docker Inc. *Compose Networking.*  
https://docs.docker.com/compose/how-tos/networking/

[5] Docker Inc. *Compose Volumes.*  
https://docs.docker.com/reference/compose-file/volumes/

[6] Docker Inc. *Compose Build Specification.*  
https://docs.docker.com/reference/compose-file/build/

[7] Docker Inc. *Dockerfile Reference.*  
https://docs.docker.com/reference/dockerfile/

[8] Flask. *Flask Documentation.*  
https://flask.palletsprojects.com/

[9] Flask. *Deploying with Gunicorn.*  
https://flask.palletsprojects.com/en/stable/deploying/gunicorn/

[10] Redis. *Redis Documentation.*  
https://redis.io/docs/latest/

[11] Redis. *Redis Persistence.*  
https://redis.io/docs/latest/management/persistence/

[12] Redis. *Redis INCR Command.*  
https://redis.io/docs/latest/commands/incr/

[13] Redis. *Redis GET Command.*  
https://redis.io/docs/latest/commands/get/

[14] Python. *Python Documentation.*  
https://docs.python.org/3/

[15] Python Package Index. *Flask.*  
https://pypi.org/project/Flask/

[16] Python Package Index. *redis.*  
https://pypi.org/project/redis/

[17] Python Package Index. *gunicorn.*  
https://pypi.org/project/gunicorn/

## Recommended Reading Sequence

Begin with reference [1] to review the official Docker Flask-and-Redis application example.

Continue with references [2] through [7] to study Compose dependency ordering, networking, volumes, and image construction.

References [8] and [9] provide the foundations of Flask and Gunicorn deployment.

References [10] through [13] explain Redis behavior, persistence, and counter operations.

The remaining references provide supporting Python and dependency-management information.

---

# 87. FINAL LECTURE CONCLUSION

Multi-container application engineering involves more than starting several containers.

A functioning application requires explicitly designed communication relationships, shared-state management, storage persistence, runtime configuration, and error handling.

Docker Compose provides a declarative mechanism for configuring the application infrastructure.

Flask and Redis provide the application-level functionality.

The Flask service exposes HTTP endpoints through Gunicorn.

The Redis service stores the authoritative counter value.

Communication between the two services occurs through a Docker-managed bridge network using the logical hostname `redis`.

This removes the need to encode changing container IP addresses directly into the application.

The use of Redis also separates the counter state from the memory of individual Python worker processes.

Atomic Redis operations provide reliable increments under concurrent access.

The named volume provides a storage lifecycle independent of the Redis container.

Consequently, the database container can be removed and recreated while retaining recoverable counter data.

The failure and recovery experiments demonstrate another fundamental architectural property.

Application processes and their dependencies have independent lifecycles.

A web process can remain running while Redis is unavailable.

Correct application behavior therefore requires meaningful readiness checks, controlled error responses, and the ability to recover from temporary dependency failures.

These principles form the technical foundation for more sophisticated service management.

The next lecture will extend this knowledge through advanced Compose configuration, startup conditions, restart behavior, environment management, and development workflows.

---

**END OF LECTURE 12**

**Next Lecture:** Lecture 13 — Advanced Docker Compose: Health Checks, Service Dependencies, Restart Policies, Environment Precedence, Multiple Compose Files, and Development Workflows.
