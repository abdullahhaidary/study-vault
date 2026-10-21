# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 21 — FINAL GRADUATION CAPSTONE: DESIGNING, BUILDING, SECURING, TESTING, DEPLOYING, AND AUTOMATING A POSTGRESQL-BACKED TASK MANAGEMENT APPLICATION

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 21 of 21 — Final Lecture  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 8–12 hours  
**Lecture Type:** Comprehensive Capstone, System Design, Implementation Laboratory, Failure Analysis, Final Examination, and Graduation Assessment

**Prerequisites:** Completion of Lectures 01–20.

**Capstone System:** Docker Task Manager

**Technology Stack:**

- Docker Engine
- Docker Compose V2
- Python 3.12
- Flask
- Gunicorn
- Psycopg 3
- PostgreSQL 17
- Nginx
- Docker BuildKit
- Git and GitHub
- GitHub Actions
- Docker Hub

---

# PART I — INTRODUCTION TO THE FINAL CAPSTONE

# 1. PURPOSE OF THE FINAL LECTURE

The preceding twenty lectures developed Docker knowledge through a sequence of increasingly complex engineering problems.

The first week established the foundations of containerization.

The second week introduced application networking, storage, and multi-container deployment.

The third week examined production-oriented image construction, security, troubleshooting, registries, reliability, and continuous integration.

The final lecture integrates these areas into one complete engineering exercise.

Rather than learning one Docker feature in isolation, the student will apply multiple technologies simultaneously.

The capstone requires the student to design, construct, operate, diagnose, protect, and distribute a functioning task management system.

The final system must provide:

1. A browser-based interface.
2. A REST API.
3. PostgreSQL persistence.
4. An Nginx reverse proxy.
5. Docker network segmentation.
6. Container health monitoring.
7. Runtime secrets.
8. Resource constraints.
9. Non-root application execution.
10. A read-only application root filesystem.
11. Automated unit tests.
12. End-to-end API tests.
13. GitHub Actions validation.
14. Docker Hub image publication.
15. Backup and restoration.
16. A documented deployment procedure.
17. Failure analysis and recovery.

Completion of this project demonstrates the student's ability to connect Docker concepts to a real software engineering workflow.

---

# 2. FINAL LEARNING OBJECTIVES

Upon completing the capstone, the student should be able to:

1. Design a multi-container application architecture.
2. Explain service responsibilities.
3. Implement a relational data model.
4. Construct a Python REST API.
5. Use parameterized SQL queries.
6. Implement validation and HTTP error handling.
7. Distinguish application and database health.
8. Build a Docker image using multiple stages.
9. Execute automated tests during image construction.
10. Apply non-root application execution.
11. Configure a read-only runtime filesystem.
12. Configure temporary writable storage.
13. Configure Docker Compose service dependencies.
14. Configure health checks.
15. Create separate frontend and database networks.
16. Store database credentials outside the application image.
17. Configure persistent PostgreSQL storage.
18. Explain PostgreSQL initialization behavior.
19. Configure Nginx reverse proxying.
20. Publish only the required host port.
21. Configure container resource limits.
22. Configure bounded logs.
23. Execute end-to-end tests.
24. Diagnose dependency failures.
25. Verify container restart behavior.
26. Verify database persistence.
27. Produce a consistent PostgreSQL backup.
28. Restore a backup to a separate database instance.
29. Implement a CI workflow.
30. Implement a release publication workflow.
31. Explain image tagging and digests.
32. Deploy a published image.
33. Describe release rollback.
34. Identify unresolved production security requirements.
35. Prepare a technical engineering report.

---

# 3. REVIEW OF THE COMPLETE 21-DAY COURSE

| Lecture | Principal subject |
|---|---|
| 01 | Docker architecture and containerization |
| 02 | Container lifecycle |
| 03 | Container inspection and diagnostics |
| 04 | Images, layers, and registries |
| 05 | Dockerfile fundamentals |
| 06 | Advanced Dockerfile construction |
| 07 | Week One capstone |
| 08 | Ports and environment variables |
| 09 | Volumes and persistent storage |
| 10 | Docker networking and DNS |
| 11 | Compose fundamentals |
| 12 | Flask and Redis application |
| 13 | Advanced Compose |
| 14 | Week Two capstone |
| 15 | Multi-stage builds and BuildKit |
| 16 | Docker security |
| 17 | Troubleshooting |
| 18 | Registries and release management |
| 19 | Production operations and recovery |
| 20 | CI/CD with GitHub Actions |
| 21 | Final PostgreSQL-backed application capstone |

The final project builds on every principal category of knowledge developed during the course.

---

# 4. CAPSTONE PROBLEM STATEMENT

A small organization requires a task-management application.

Employees must be able to:

- Add tasks.
- View tasks.
- Mark tasks as completed.
- Mark completed tasks as incomplete.
- Delete tasks.

The organization also requires the application to preserve data when application containers are replaced.

It must be possible to test the application automatically before releasing a new version.

The application must use a private database service, and its internal database port must not be published to the host.

The system must also support structured troubleshooting and data recovery.

The engineering assignment is to implement this application using Docker and the technologies studied in the course.

---

# 5. FUNCTIONAL REQUIREMENTS

The application must provide the following operations.

| Requirement | Description |
|---|---|
| FR-01 | Display a task-management webpage |
| FR-02 | Create a task |
| FR-03 | List tasks |
| FR-04 | Retrieve one task |
| FR-05 | Mark a task complete or incomplete |
| FR-06 | Delete a task |
| FR-07 | Validate task titles |
| FR-08 | Reject invalid request data |
| FR-09 | Preserve tasks in PostgreSQL |
| FR-10 | Return appropriate HTTP status codes |

A task title must contain between 1 and 120 characters after surrounding whitespace is removed.

A task's completion state must be a Boolean value.

Unknown tasks must produce an HTTP 404 response.

---

# 6. NON-FUNCTIONAL REQUIREMENTS

The application must also satisfy engineering requirements concerning how it operates.

| Requirement | Description |
|---|---|
| NFR-01 | Run through Docker Compose |
| NFR-02 | Use separate Nginx, Flask, and PostgreSQL services |
| NFR-03 | Publish only the Nginx host port |
| NFR-04 | Use an internal database network |
| NFR-05 | Use named-volume database persistence |
| NFR-06 | Use a runtime database password file |
| NFR-07 | Run Flask as a non-root process |
| NFR-08 | Use a read-only Flask root filesystem |
| NFR-09 | Configure health checks |
| NFR-10 | Configure restart policies |
| NFR-11 | Configure resource limits |
| NFR-12 | Configure bounded logging |
| NFR-13 | Run automated tests |
| NFR-14 | Support database backup |
| NFR-15 | Support independent restoration |
| NFR-16 | Support automated image publication |

---

# 7. CAPSTONE ARCHITECTURE

The complete system consists of three principal services.

```text
[ USER BROWSER ]
[ 127.0.0.1:8311 ]
[ NGINX REVERSE PROXY :80 ]
[ FRONTEND NETWORK ]
[ FLASK GUNICORN :8000 NON-ROOT USER ]
[ INTERNAL DATA NETWORK ]
[ POSTGRESQL 17 :5432 ]
[ POSTGRES VOLUME PERSISTENT DATA ]
```

Only Nginx is accessible through a published host endpoint.

Flask and PostgreSQL are reached through internal Docker service networking.

---

# 8. WHY THREE SERVICES?

## 8.1 Nginx

Nginx handles incoming HTTP traffic.

It forwards requests to Flask.

A reverse proxy allows application networking and public-facing request handling to be managed separately.

## 8.2 Flask

Flask implements application behavior.

It validates incoming requests and issues database operations.

Gunicorn manages the Python application processes.

## 8.3 PostgreSQL

PostgreSQL stores the authoritative task data.

It provides relational constraints and transactional database operations.

## 8.4 Separation of Responsibilities

The design separates:

- Client-facing traffic management.
- Business logic.
- Persistent relational storage.

This separation improves maintainability and supports independent diagnosis of different failure categories.

---

# 9. REQUEST FLOW

Consider the creation of a new task.

```text
              USER SELECTS "ADD TASK"
                         |
                         v
                  JAVASCRIPT FETCH
                         |
                         v
                  POST /api/tasks
                         |
                         v
                       NGINX
                         |
                         v
                       FLASK
                         |
                         v
                  VALIDATE TITLE
                         |
                         v
                PARAMETERIZED SQL
                         |
                         v
                     POSTGRESQL
                         |
                         v
                 COMMIT TRANSACTION
                         |
                         v
                  HTTP 201 RESPONSE
                         |
                         v
                 UPDATE BROWSER UI
```

The database must confirm the operation before the API reports successful task creation.

---

# 10. FAILURE DOMAINS

The system contains several possible failure points.

A failure might involve:

1. The client.
2. Host port publishing.
3. Nginx.
4. The frontend network.
5. Gunicorn.
6. Flask application logic.
7. The database network.
8. PostgreSQL.
9. The database volume.
10. Docker Engine.
11. The underlying host.

These failures do not all produce the same symptoms.

An important goal of the capstone is learning to distinguish them.

---

# 11. IMPORTANT SECURITY LIMITATIONS

This is a comprehensive instructional application, but it is not ready to be exposed publicly without further work.

The training project deliberately uses:

- Localhost HTTP.
- No account authentication.
- No user-specific authorization.
- No rate limiting.
- A single PostgreSQL host.
- One Docker Engine.
- A locally generated database secret.
- PostgreSQL's bootstrap database role for the application.

A genuine public deployment would require additional protection, including trusted HTTPS, user authentication, authorization, appropriate database roles, a managed secrets strategy, and a stronger operational architecture.

A complete Docker education includes recognizing these boundaries rather than describing every functional system as production-ready.

---

# PART II — DATA MODEL AND API ENGINEERING

# 12. RELATIONAL DATA MODEL

The application uses one relational table.

**Table:** `tasks`

| Column | PostgreSQL type | Purpose |
|---|---|---|
| id | BIGINT identity | Unique task identifier |
| title | VARCHAR(120) | Task description |
| done | BOOLEAN | Completion status |
| created_at | TIMESTAMPTZ | Creation timestamp |

The primary key uniquely identifies each task.

The title column cannot be null.

The database also constrains blank task titles.

The completion state defaults to false.

The timestamp defaults to the current database time.

---

# 13. COMPLETE POSTGRESQL SCHEMA

Create:

`db/init.sql`

```sql
CREATE TABLE IF NOT EXISTS public.tasks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    title VARCHAR(120) NOT NULL
        CHECK (char_length(btrim(title)) > 0),

    done BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tasks_created_at_idx
    ON public.tasks (created_at DESC);
```

## Interpretation

`GENERATED ALWAYS AS IDENTITY` creates automatically generated identifiers.

`PRIMARY KEY` enforces uniqueness and non-nullability.

`CHECK` rejects empty or whitespace-only titles.

`BOOLEAN` represents task completion.

`TIMESTAMPTZ` stores timestamp values with time-zone-aware semantics.

The index may assist selected operations involving creation time, although its usefulness depends on actual queries and data volume.

---

# 14. DATABASE INITIALIZATION

The PostgreSQL Docker Official Image supports initialization scripts under:

```text
/docker-entrypoint-initdb.d/
```

The Compose project mounts the SQL file at:

```text
/docker-entrypoint-initdb.d/001_schema.sql
```

The initialization process runs for a newly initialized empty database data directory.

**Important:** The script is not a general-purpose schema migration mechanism.

When an existing PostgreSQL volume already contains a database cluster, the initialization scripts are not automatically replayed.

Future schema changes require a controlled database migration procedure.

---

# 15. WHY POSTGRESQL 17?

The capstone uses:

```text
postgres:17-alpine
```

PostgreSQL 17 has a well-defined Docker data path:

```text
/var/lib/postgresql/data
```

The project explicitly mounts a named volume at this path.

Different major versions of the PostgreSQL Official Image can have different recommended storage layouts.

An application should therefore not change its PostgreSQL major version without reviewing both database upgrade requirements and image storage behavior.

---

# 16. REST API DESIGN

The following API will be implemented.

| Method | Endpoint | Operation | Success |
|---|---|---|---|
| GET | `/` | Display webpage | 200 |
| GET | `/health/live` | Application liveness | 200 |
| GET | `/health/ready` | Database readiness | 200 |
| GET | `/api/tasks` | List tasks | 200 |
| GET | `/api/tasks/{id}` | Retrieve one task | 200 |
| POST | `/api/tasks` | Create task | 201 |
| PATCH | `/api/tasks/{id}` | Update completion | 200 |
| DELETE | `/api/tasks/{id}` | Delete task | 204 |

Additional error responses include:

- 400 — Invalid request data.
- 404 — Task not found.
- 503 — Database unavailable.

---

# 17. HTTP STATUS CODE DESIGN

## 17.1 HTTP 200

The request succeeded and the server returned the expected result.

## 17.2 HTTP 201

A new resource was created successfully.

## 17.3 HTTP 204

The request succeeded and no response body is required.

## 17.4 HTTP 400

The client supplied invalid input.

## 17.5 HTTP 404

The requested resource does not exist.

## 17.6 HTTP 503

The application cannot currently perform the requested database operation.

Correct status codes make the API easier to test and troubleshoot.

---

# 18. PARAMETERIZED SQL

User-supplied values must not be concatenated directly into SQL statements.

Incorrect:

```python
query = "SELECT * FROM tasks WHERE id = " + user_input
```

Correct:

```python
cur.execute(
    "SELECT id, title FROM tasks WHERE id = %s",
    (task_id,),
)
```

The Psycopg driver handles the parameter as a separate SQL value.

This helps prevent SQL injection caused by incorrectly assembled query strings.

Parameterized SQL does not replace all security controls, but it is essential for safe database access.

---

# 19. APPLICATION DATA VALIDATION

The application defines two important validation functions.

```python
def validate_title(value):
    if not isinstance(value, str):
        raise ValueError("title must be a string")

    result = value.strip()

    if not result or len(result) > 120:
        raise ValueError(
            "title must contain 1 to 120 characters"
        )

    return result


def validate_done(value):
    if type(value) is not bool:
        raise ValueError("done must be a boolean")

    return value
```

## Title Validation

The title must be a string.

Whitespace around the title is removed.

The resulting value must contain 1–120 characters.

## Boolean Validation

The completion state must be an actual Boolean.

The values `0`, `"true"`, and `null` are not accepted as substitutes.

---

# 20. TRANSACTION HANDLING

Psycopg connection context managers support transaction handling.

For example:

```python
with db_connection() as conn:
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tasks (title) VALUES (%s)",
            ("Study Docker",),
        )
```

Successful completion commits the transaction under the connection context-manager behavior.

An exception can cause the transaction to be rolled back.

The connection is closed when its context is exited.

This supports consistent behavior for individual database operations.

---

# 21. DATABASE CONNECTION FUNCTION

The capstone reads the PostgreSQL password from a mounted secret file.

```python
from pathlib import Path

import psycopg

from psycopg.rows import dict_row


def db_connection():

    password = Path(
        "/run/secrets/db_password"
    ).read_text(encoding="utf-8").strip()

    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("DB_NAME", "taskdb"),
        user=os.getenv("DB_USER", "taskowner"),
        password=password,
        connect_timeout=3,
        row_factory=dict_row,
    )
```

The password is not stored in the application source.

The application reads it at runtime.

## Important Security Qualification

The local Compose secret is file-backed.

It is not equivalent to a fully managed encrypted secrets service.

The permissions on the host source file remain relevant.

---

# PART III — COMPLETE APPLICATION IMPLEMENTATION

# 22. PYTHON DEPENDENCIES

Create:

`web/requirements.txt`

```text
Flask==3.1.3
psycopg[binary]==3.3.6
gunicorn==26.2.0
```

These direct dependency versions were selected for the October 2026 course environment.

The Python project uses:

- Flask for HTTP routing.
- Psycopg 3 for PostgreSQL communication.
- Gunicorn for process management.

A high-assurance release process should also lock or otherwise control transitive dependencies and review security updates.

---

# 23. FLASK APPLICATION STRUCTURE

The complete application resides in:

`web/app.py`

It contains:

1. Flask application initialization.
2. Logging configuration.
3. Validation functions.
4. Database connection setup.
5. Task serialization.
6. Liveness and readiness endpoints.
7. Task listing.
8. Individual task retrieval.
9. Task creation.
10. Task updates.
11. Task deletion.
12. Controlled database error responses.

The source archive accompanying this lecture contains the complete file.

The following sections reproduce the principal application logic.

---

# 24. TASK SERIALIZATION

Database rows must be converted into JSON-compatible objects.

```python
def serialize_task(row):

    return {
        "id": row["id"],
        "title": row["title"],
        "done": row["done"],
        "created_at": row["created_at"].isoformat(),
    }
```

The database timestamp is represented as an ISO 8601 string.

This provides a consistent API representation.

---

# 25. APPLICATION LIVENESS

```python
@app.get("/health/live")
def live():

    return jsonify(status="alive"), 200
```

This endpoint does not require a database query.

Its purpose is to verify that the Flask application can respond.

## Important Distinction

Successful liveness does not guarantee that PostgreSQL is available.

---

# 26. APPLICATION READINESS

```python
@app.get("/health/ready")
def ready():

    try:
        with db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT to_regclass('public.tasks') "
                    "AS table_name"
                )

                if cur.fetchone()["table_name"] is None:
                    return jsonify(
                        status="not_ready"
                    ), 503

        return jsonify(status="ready"), 200

    except (psycopg.Error, OSError, ValueError):

        return jsonify(
            status="not_ready"
        ), 503
```

The readiness check verifies access to PostgreSQL and the existence of the expected table.

The complete source file also records a diagnostic warning when readiness fails.

## Engineering Importance

A database process may be running before the application schema is usable.

Readiness must therefore consider application requirements, not merely process existence.

---

# 27. LISTING TASKS

```python
@app.get("/api/tasks")
def list_tasks():

    try:
        with db_connection() as conn:
            with conn.cursor() as cur:

                cur.execute(
                    "SELECT id, title, done, created_at "
                    "FROM tasks ORDER BY id DESC LIMIT 200"
                )

                rows = cur.fetchall()

        return jsonify(
            tasks=[serialize_task(row) for row in rows]
        ), 200

    except (psycopg.Error, OSError, ValueError):

        return jsonify(
            error="database unavailable"
        ), 503
```

The endpoint returns at most 200 tasks.

For a larger production application, cursor-based pagination or another explicit pagination strategy would be appropriate.

---

# 28. CREATING TASKS

```python
@app.post("/api/tasks")
def create_task():

    payload = request.get_json(silent=True)

    if not isinstance(payload, dict):
        return jsonify(
            error="a JSON object is required"
        ), 400

    try:
        title = validate_title(payload.get("title"))

    except ValueError as exc:
        return jsonify(error=str(exc)), 400

    try:
        with db_connection() as conn:
            with conn.cursor() as cur:

                cur.execute(
                    "INSERT INTO tasks (title) VALUES (%s) "
                    "RETURNING id, title, done, created_at",
                    (title,),
                )

                row = cur.fetchone()

        response = jsonify(
            task=serialize_task(row)
        )

        response.status_code = 201

        response.headers["Location"] = url_for(
            "get_task",
            task_id=row["id"],
        )

        return response

    except (psycopg.Error, OSError, ValueError):

        return jsonify(
            error="database unavailable"
        ), 503
```

## Engineering Analysis

The endpoint:

1. Parses JSON.
2. Validates the title.
3. Opens a database connection.
4. Executes parameterized SQL.
5. Commits the successful operation.
6. Returns HTTP 201.
7. Provides the created task representation.

---

# 29. UPDATING TASKS

```python
@app.patch("/api/tasks/<int:task_id>")
def update_task(task_id):

    payload = request.get_json(silent=True)

    if (
        not isinstance(payload, dict)
        or "done" not in payload
    ):
        return jsonify(
            error="JSON boolean done is required"
        ), 400

    try:
        done = validate_done(payload["done"])

    except ValueError as exc:
        return jsonify(error=str(exc)), 400

    try:
        with db_connection() as conn:
            with conn.cursor() as cur:

                cur.execute(
                    "UPDATE tasks SET done = %s "
                    "WHERE id = %s "
                    "RETURNING id, title, done, created_at",
                    (done, task_id),
                )

                row = cur.fetchone()

        if row is None:
            return jsonify(
                error="task not found"
            ), 404

        return jsonify(
            task=serialize_task(row)
        ), 200

    except (psycopg.Error, OSError, ValueError):

        return jsonify(
            error="database unavailable"
        ), 503
```

The update operation uses a Boolean value rather than arbitrary user-provided text.

The database returns the updated row.

An unknown task produces HTTP 404.

---

# 30. DELETING TASKS

```python
@app.delete("/api/tasks/<int:task_id>")
def delete_task(task_id):

    try:
        with db_connection() as conn:
            with conn.cursor() as cur:

                cur.execute(
                    "DELETE FROM tasks WHERE id = %s",
                    (task_id,),
                )

                deleted = cur.rowcount

        if not deleted:
            return jsonify(
                error="task not found"
            ), 404

        return "", 204

    except (psycopg.Error, OSError, ValueError):

        return jsonify(
            error="database unavailable"
        ), 503
```

The endpoint verifies whether any row was deleted.

Successful deletion returns HTTP 204.

---

# 31. THE HTML FRONTEND

Create:

`web/templates/index.html`

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">

  <meta name="viewport"
        content="width=device-width,initial-scale=1">

  <title>Docker Day 21 — Task Manager</title>

  <link rel="stylesheet" href="/static/style.css">

  <script src="/static/app.js" defer></script>
</head>

<body>
  <main>
    <h1>Docker Graduation Capstone</h1>

    <p>PostgreSQL-backed task manager</p>

    <form id="task-form">
      <label for="title">New task</label>

      <input
        id="title"
        maxlength="120"
        required
        placeholder="Finish Docker course"
      >

      <button type="submit">Add task</button>
    </form>

    <p id="message" role="status"></p>

    <ul id="tasks"></ul>
  </main>
</body>
</html>
```

The interface uses a form for creating tasks and an unordered list for displaying them.

The JavaScript application supplies the dynamic behavior.

---

# 32. FRONTEND JAVASCRIPT

Create:

`web/static/app.js`

```javascript
const form = document.getElementById('task-form');
const input = document.getElementById('title');
const list = document.getElementById('tasks');
const message = document.getElementById('message');

async function api(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {})
    }
  });

  if (response.status === 204) return null;

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error || 'Request failed');
  }

  return body;
}

async function refresh() {
  try {
    const result = await api('/api/tasks');

    list.replaceChildren();

    for (const task of result.tasks) {
      const item = document.createElement('li');

      const title = document.createElement('span');
      title.textContent = task.title;

      if (task.done) {
        title.classList.add('completed');
      }

      const toggle = document.createElement('button');
      toggle.textContent = task.done ? 'Undo' : 'Complete';

      toggle.addEventListener('click', async () => {
        try {
          await api(`/api/tasks/${task.id}`, {
            method: 'PATCH',
            body: JSON.stringify({
              done: !task.done
            })
          });

          await refresh();

        } catch (error) {
          message.textContent = error.message;
        }
      });

      const remove = document.createElement('button');
      remove.textContent = 'Delete';

      remove.addEventListener('click', async () => {
        try {
          await api(`/api/tasks/${task.id}`, {
            method: 'DELETE'
          });

          await refresh();

        } catch (error) {
          message.textContent = error.message;
        }
      });

      item.append(title, toggle, remove);
      list.append(item);
    }

    message.textContent =
      `${result.tasks.length} task(s) shown`;

  } catch (error) {
    message.textContent = error.message;
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();

  const title = input.value.trim();

  if (!title) return;

  try {
    await api('/api/tasks', {
      method: 'POST',
      body: JSON.stringify({ title })
    });

    input.value = '';
    await refresh();

  } catch (error) {
    message.textContent = error.message;
  }
});

refresh();
```

## Security Observation

The application inserts task titles using:

```javascript
title.textContent = task.title;
```

This treats titles as text rather than HTML markup.

It avoids an important class of unsafe rendering behavior associated with inserting untrusted strings as HTML.

The application still requires authentication and authorization before being exposed to real users.

---

# 33. STYLESHEET

Create:

`web/static/style.css`

```css
body {
    font: 16px/1.5 system-ui, sans-serif;
    background: #eff6ff;
    margin: 0;
    color: #172554;
}

main {
    margin: 48px auto;
    max-width: 780px;
    background: #fff;
    padding: 34px;
    border-radius: 12px;
}

form {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
}

input {
    flex: 1;
    min-width: 200px;
    padding: 11px;
}

button {
    background: #1d4ed8;
    color: white;
    border: none;
    padding: 10px 14px;
    border-radius: 6px;
    cursor: pointer;
}

li {
    padding: 12px 0;
    border-top: 1px solid #e2e8f0;
    display: flex;
    align-items: center;
    gap: 12px;
}

li span {
    flex: 1;
}

.completed {
    color: #64748b;
    text-decoration: line-through;
}
```

The source archive contains the complete stylesheet, including additional layout and state styling.

---

# PART IV — DOCKER IMAGE ENGINEERING

# 34. MULTI-STAGE DOCKERFILE

Create:

`web/Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim AS deps

WORKDIR /work

COPY requirements.txt ./requirements.txt

RUN python -m pip install \
    --no-cache-dir \
    --prefix=/install \
    -r requirements.txt


FROM deps AS test

COPY app.py ./app.py

COPY tests/ ./tests/

COPY templates/ ./templates/

COPY static/ ./static/

RUN PYTHONPATH=/install/lib/python3.12/site-packages \
    python -m unittest discover -s tests -v


FROM python:3.12-slim AS runtime

COPY --from=deps /install/ /usr/local/

WORKDIR /srv/app

COPY --from=test --chown=10001:10001 \
    /work/app.py ./app.py

COPY --from=test --chown=10001:10001 \
    /work/templates/ ./templates/

COPY --from=test --chown=10001:10001 \
    /work/static/ ./static/

USER 10001:10001

EXPOSE 8000

CMD [
  "gunicorn",
  "--bind", "0.0.0.0:8000",
  "--workers", "2",
  "--timeout", "30",
  "--graceful-timeout", "20",
  "--worker-tmp-dir", "/tmp",
  "--access-logfile", "-",
  "--error-logfile", "-",
  "app:app"
]
```

---

# 35. MULTI-STAGE BUILD ANALYSIS

The Dockerfile contains three stages.

## Stage 1 — Dependencies

Installs the selected Python packages under a temporary installation prefix.

## Stage 2 — Testing

Copies source files and executes the unit test suite.

## Stage 3 — Runtime

Copies the installed dependencies and the application files.

The runtime stage depends on the test stage for its application content.

Consequently, successful construction of the final image requires successful completion of the selected test stage.

## Security Features

The runtime process executes as UID 10001.

The final image does not include the application test directory.

Gunicorn writes logs to standard output and standard error.

---

# 36. BUILD CONTEXT

Create:

`web/.dockerignore`

```text
.git
__pycache__/
*.pyc
.env
secrets/
backups/
```

The Docker build context is the `web` directory.

Only the files required for that build should be made available to the builder.

The database password file belongs outside the web image build context.

---

# 37. UNIT TEST SUITE

Create:

`web/tests/test_app.py`

The unit tests focus on logic that can be validated without a running PostgreSQL database.

The suite includes:

1. Title trimming.
2. Empty title rejection.
3. Excessively long title rejection.
4. Non-string title rejection.
5. Boolean validation.
6. Rejection of non-Boolean completion values.
7. Application liveness.
8. Invalid create request.
9. Invalid update request.
10. Homepage availability.

Example:

```python
import unittest

from app import app, validate_title, validate_done


class ValidationTests(unittest.TestCase):

    def test_trim_title(self):
        self.assertEqual(
            validate_title("  study Docker  "),
            "study Docker",
        )

    def test_empty_title(self):
        with self.assertRaises(ValueError):
            validate_title("   ")

    def test_non_string_title(self):
        with self.assertRaises(ValueError):
            validate_title(42)

    def test_boolean(self):
        self.assertTrue(validate_done(True))
        self.assertFalse(validate_done(False))

    def test_non_boolean(self):
        with self.assertRaises(ValueError):
            validate_done("true")


class RouteTests(unittest.TestCase):

    def setUp(self):
        self.client = app.test_client()

    def test_liveness(self):
        response = self.client.get("/health/live")
        self.assertEqual(response.status_code, 200)

    def test_invalid_create(self):
        response = self.client.post(
            "/api/tasks",
            json={"title": "  "},
        )

        self.assertEqual(response.status_code, 400)
```

The complete test file is included in the project archive.

---

# PART V — NGINX, COMPOSE, AND SECRETS

# 38. NGINX REVERSE PROXY

Create:

`gateway.conf`

```nginx
server {
    listen 80;

    server_name _;

    resolver 127.0.0.11 valid=5s ipv6=off;

    set $backend web;

    location = /gateway-health {
        default_type text/plain;
        return 200 "gateway alive\n";
    }

    location / {
        proxy_pass http://$backend:8000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;

        proxy_set_header X-Real-IP $remote_addr;

        proxy_set_header X-Forwarded-For
            $proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 3s;

        proxy_read_timeout 15s;

        add_header X-Content-Type-Options
            "nosniff" always;

        add_header Referrer-Policy
            "no-referrer" always;
    }
}
```

## Dynamic Resolution

The proxy uses Docker's embedded DNS resolver.

This supports resolution of the `web` service name across container replacement.

## Gateway Health

The gateway has a local health endpoint independent of Flask.

Thus, Nginx may remain healthy even when the application becomes unavailable.

---

# 39. COMPLETE COMPOSE PROJECT

Create:

`compose.yaml`

```yaml
name: docker-day21-capstone

x-logging: &bounded-logging
  driver: local
  options:
    max-size: "10m"
    max-file: "3"

services:

  db:
    image: postgres:17-alpine

    environment:
      POSTGRES_DB: taskdb
      POSTGRES_USER: taskowner
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"

    secrets:
      - db_password

    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/001_schema.sql:ro

    networks:
      - data

    healthcheck:
      test:
        - CMD-SHELL
        - 'pg_isready -U "$${POSTGRES_USER}" -d "$${POSTGRES_DB}"'
      interval: 5s
      timeout: 3s
      retries: 12
      start_period: 15s

    restart: unless-stopped
    stop_grace_period: 40s

    mem_limit: 512m
    cpus: 1.0
    pids_limit: 128

    logging: *bounded-logging

  web:
    build:
      context: ./web
      dockerfile: Dockerfile

    image: "${IMAGE_REF:-day21-task-web:local}"

    environment:
      DB_HOST: db
      DB_PORT: "5432"
      DB_NAME: taskdb
      DB_USER: taskowner

    secrets:
      - db_password

    depends_on:
      db:
        condition: service_healthy

    networks:
      - frontend
      - data

    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=2)"
      interval: 10s
      timeout: 4s
      retries: 3
      start_period: 20s

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

    mem_limit: 320m
    cpus: 0.75
    pids_limit: 96

    logging: *bounded-logging

  gateway:
    image: nginx:stable-alpine

    ports:
      - "127.0.0.1:${PUBLIC_PORT:-8311}:80"

    volumes:
      - ./gateway.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      web:
        condition: service_healthy

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

    restart: unless-stopped
    stop_grace_period: 20s

    mem_limit: 128m
    cpus: 0.5

    logging: *bounded-logging

networks:
  frontend:
    driver: bridge

  data:
    driver: bridge
    internal: true

volumes:
  postgres-data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

---

# 40. COMPOSE ARCHITECTURE ANALYSIS

The configuration demonstrates several important ideas.

## Service Isolation

Three services are declared independently.

## Network Separation

Nginx joins the frontend network.

PostgreSQL joins the internal data network.

Flask joins both networks to communicate with each service.

## Health-Dependent Startup

Flask waits for PostgreSQL health during startup.

Nginx waits for Flask readiness.

## Persistence

PostgreSQL stores its data in a named volume.

## Secrets

The database password is supplied through a file-backed Compose secret.

## Hardening

Flask executes as non-root and uses a read-only root filesystem.

## Operations

Resource limits, restart policies, and bounded logging are applied.

---

# 41. DATABASE SECRET CONFIGURATION

The database password is read from:

```text
/run/secrets/db_password
```

The secret source file is:

```text
secrets/db_password.txt
```

The file should be created locally and excluded from source control.

For this isolated training project, a Python command will generate a random demonstration password.

The application uses the mounted file rather than including the password in its Dockerfile.

## Important Limitation

A local Compose file-backed secret is mounted from the host.

The synthetic secret file must be readable by the application's non-root process.

The training procedure uses local demonstration permissions; a real deployment should use carefully managed file ownership, access policy, and preferably an appropriate dedicated secret-management system.

---

# 42. SECRET GENERATION

From the project root in a Bash-compatible terminal:

```bash
mkdir -p secrets backups
```

Generate a random password:

```bash
python3 -c 'from pathlib import Path; import secrets; Path("secrets/db_password.txt").write_text(secrets.token_hex(24) + "\n")'
```

For this isolated local demonstration, ensure that the file is readable by the non-root Flask process:

```bash
chmod 644 secrets/db_password.txt
```

**Warning:** The last setting is a training convenience for file-backed Compose secrets. It is not the recommended permission policy for real production credentials.

Never commit the secret file.

---

# 43. DOCKER COMPOSE STARTUP ORDER

The intended startup order is:

```text
           POSTGRESQL STARTS
                   |
                   v
          POSTGRESQL HEALTHY
                   |
                   v
              FLASK STARTS
                   |
                   v
             FLASK READY
                   |
                   v
              NGINX STARTS
                   |
                   v
               APPLICATION
```

The health checks do not eliminate the need for runtime error handling.

PostgreSQL may fail after the application starts.

Flask must still respond appropriately to later database unavailability.

---

# 44. DOCKER LOGGING

The Compose configuration uses the `local` logging driver.

```yaml
logging:
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
```

This controls the local retention of container logs.

The system remains dependent on the operator to retrieve or monitor the logs.

A public production environment should evaluate centralized collection and alerting.

---

# 45. DOCKER NETWORK SECURITY

The backend network uses:

```yaml
internal: true
```

PostgreSQL has no published host port.

Therefore, ordinary client traffic reaches the application through Nginx rather than connecting directly to the database.

The frontend and backend networks have separate responsibilities.

However, network isolation does not replace database access controls.

---

# 46. DATABASE ROLE LIMITATION

The PostgreSQL image initializes:

```text
POSTGRES_USER=taskowner
```

This bootstrap identity has administrative authority in the initialized PostgreSQL instance.

The training application also uses it for database access to keep the capstone setup understandable.

A real production application should use a dedicated application role with only the required table privileges.

For example, a task-management service generally does not require unrestricted authority to create databases or modify arbitrary roles.

A suitable production design would separate database administration from routine application queries.

---

# PART VI — AUTOMATED VALIDATION AND CI/CD

# 47. END-TO-END TESTING

The final project includes:

`scripts/smoke.py`

It is a Python standard-library acceptance-test program.

The script tests:

1. Application readiness.
2. Liveness.
3. Invalid title rejection.
4. Invalid completion-state rejection.
5. Task creation.
6. Individual task retrieval.
7. Task listing.
8. Task completion.
9. Task deletion.
10. HTTP 404 after deletion.

The test creates a uniquely named temporary task and deletes it before finishing.

---

# 48. END-TO-END TEST IMPLEMENTATION

A simplified representation of the acceptance test is:

```python
import json
from urllib.request import Request, urlopen


BASE = "http://127.0.0.1:8311"


def call(method, path, data=None):

    payload = (
        json.dumps(data).encode("utf-8")
        if data is not None
        else None
    )

    request = Request(
        BASE + path,
        data=payload,
        method=method,
        headers={
            "Content-Type": "application/json"
        },
    )

    with urlopen(request, timeout=5) as response:

        body = response.read()

        return (
            response.status,
            json.loads(body) if body else None,
        )


status, result = call(
    "POST",
    "/api/tasks",
    {"title": "Complete Docker capstone"},
)

assert status == 201

task_id = result["task"]["id"]

status, result = call(
    "PATCH",
    f"/api/tasks/{task_id}",
    {"done": True},
)

assert status == 200
assert result["task"]["done"] is True
```

The full script additionally handles expected HTTP error responses, retries readiness checks, and deletes its test task.

---

# 49. CONTINUOUS INTEGRATION WORKFLOW

Create:

`.github/workflows/ci.yaml`

```yaml
name: Day 21 - Continuous Integration

on:
  pull_request:
    branches: [main]

  push:
    branches: [main]

permissions:
  contents: read

jobs:
  verify:
    runs-on: ubuntu-latest

    timeout-minutes: 25

    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-python@v7
        with:
          python-version: '3.12'

      - name: Verify Python syntax
        run: python -m compileall -q web scripts

      - name: Create synthetic CI database password
        run: |
          mkdir -p secrets

          python -c 'from pathlib import Path; import secrets; Path("secrets/db_password.txt").write_text(secrets.token_hex(24) + "\n")'

          chmod 644 secrets/db_password.txt

      - uses: docker/setup-buildx-action@v4

      - name: Build and test Docker image
        uses: docker/build-push-action@v7
        with:
          context: ./web
          target: test
          push: false
          cache-from: type=gha,scope=day21-ci
          cache-to: type=gha,mode=max,scope=day21-ci

      - name: Start integration environment
        run: |
          docker compose up -d --build --wait --wait-timeout 150

      - name: Run end-to-end acceptance tests
        run: |
          python scripts/smoke.py http://127.0.0.1:8311

      - name: Gather diagnostic logs if tests fail
        if: failure()
        run: |
          docker compose ps -a || true
          docker compose logs --tail 100 || true

      - name: Remove CI environment
        if: always()
        run: |
          docker compose down -v --remove-orphans || true
```

---

# 50. CI WORKFLOW ANALYSIS

The workflow runs on:

- Pull requests targeting main.
- Pushes to main.

It executes on a GitHub-hosted runner.

The CI job:

1. Checks out the source code.
2. Configures Python.
3. Validates Python syntax.
4. Generates a synthetic database password.
5. Configures Docker Buildx.
6. Builds the Docker test stage.
7. Starts PostgreSQL, Flask, and Nginx.
8. Runs the end-to-end API test.
9. Collects logs on failure.
10. Cleans up the temporary CI environment.

The cleanup command includes `-v` because the CI project creates disposable test data.

This differs from production teardown, where deleting persistent volumes would require deliberate authorization.

---

# 51. CI SECURITY MODEL

The pull-request workflow does not require Docker Hub credentials.

The database password is generated specifically for the temporary CI environment.

The application and test database are disposed of when the workflow finishes.

Untrusted contributions are validated without access to registry publication credentials.

This establishes a useful security boundary between code validation and image publication.

---

# 52. RELEASE PUBLICATION WORKFLOW

Create:

`.github/workflows/release.yaml`

```yaml
name: Day 21 - Release Publication

on:
  push:
    tags: ['v*']

permissions:
  contents: read

jobs:
  verify:
    runs-on: ubuntu-latest

    timeout-minutes: 25

    steps:
      - uses: actions/checkout@v7

      - name: Validate release tag
        shell: bash
        run: |
          [[ "$GITHUB_REF_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]

      - uses: actions/setup-python@v7
        with:
          python-version: '3.12'

      - name: Create synthetic CI database password
        run: |
          mkdir -p secrets

          python -c 'from pathlib import Path; import secrets; Path("secrets/db_password.txt").write_text(secrets.token_hex(24) + "\n")'

          chmod 644 secrets/db_password.txt

      - name: Start application for acceptance tests
        run: |
          docker compose up -d --build --wait --wait-timeout 150

      - name: Verify REST API end to end
        run: |
          python scripts/smoke.py http://127.0.0.1:8311

      - name: Diagnostic logs on failure
        if: failure()
        run: docker compose logs --tail 100 || true

      - name: Clean up
        if: always()
        run: docker compose down -v --remove-orphans || true

  publish:
    needs: verify

    runs-on: ubuntu-latest

    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v7

      - uses: docker/setup-buildx-action@v4

      - name: Docker Hub login
        uses: docker/login-action@v4
        with:
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Generate image tags
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ vars.DOCKERHUB_USERNAME }}/day21-taskmanager

          flavor: |
            latest=false

          tags: |
            type=semver,pattern={{version}}
            type=sha,format=long

      - name: Publish verified source build
        id: publish_image
        uses: docker/build-push-action@v7
        with:
          context: ./web
          target: runtime
          platforms: linux/amd64
          push: true

          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

          cache-from: type=gha,scope=day21-release
          cache-to: type=gha,mode=max,scope=day21-release

          sbom: true
          provenance: mode=max

      - name: Record release digest
        env:
          IMAGE_DIGEST: ${{ steps.publish_image.outputs.digest }}
        run: |
          echo "## Docker Day 21 Release" >> "$GITHUB_STEP_SUMMARY"
          echo "Published digest: $IMAGE_DIGEST" >> "$GITHUB_STEP_SUMMARY"
```

---

# 53. RELEASE WORKFLOW ANALYSIS

The release workflow is triggered by versioned Git tags.

It contains two jobs.

## Verify

The first job validates the tag, starts the complete multi-container application, and executes the acceptance test.

## Publish

The second job runs only after the verification dependency succeeds under normal GitHub Actions behavior.

It authenticates to Docker Hub.

It generates version and commit-based image tags.

It publishes the runtime image.

It requests SBOM and provenance attestations.

It records the published digest.

## Important Release Engineering Qualification

The verification job and publication job perform separate image builds from the tagged source.

This verifies that the source and application behavior are acceptable, but it is not strictly the same as building an artifact once, testing that exact image digest, and promoting the identical bytes.

A mature production system may use a build-once-and-promote strategy for stronger artifact identity guarantees.

---

# 54. REGISTRY CONFIGURATION

The GitHub repository requires:

**GitHub Actions variable:**

```text
DOCKERHUB_USERNAME
```

**GitHub Actions secret:**

```text
DOCKERHUB_TOKEN
```

The Docker Hub repository should be named:

```text
day21-taskmanager
```

The variable identifies the authorized namespace.

The secret stores the appropriate publishing token.

The workflow must not contain the actual token value.

---

# 55. RELEASE VERSIONING

A Git tag:

```text
v1.0.0
```

produces an image tag:

```text
1.0.0
```

The workflow also generates a source-revision tag.

An example published image reference is:

```text
YOUR_DOCKER_ID/day21-taskmanager:1.0.0
```

The exact published content can also be selected using its registry digest.

---

# 56. ARTIFACT-BASED DEPLOYMENT

The Compose project supports an image override through:

```yaml
image: "${IMAGE_REF:-day21-task-web:local}"
```

For local development, the default image name is used.

For a published release, an operator may set:

```text
IMAGE_REF=YOUR_DOCKER_ID/day21-taskmanager:1.0.0
```

Then use Compose with options that pull the image and avoid rebuilding from source.

This separates local application development from deployment of a previously published artifact.

---

# PART VII — FINAL PRACTICAL LABORATORY

# 57. LABORATORY OVERVIEW

The final laboratory contains 32 structured experiments.

The experiments are divided into:

1. Environment preparation.
2. Application deployment.
3. REST API testing.
4. Database inspection.
5. Security verification.
6. Persistence testing.
7. Controlled failure analysis.
8. Backup and restoration.
9. CI/CD.
10. Final acceptance.

**Recommended laboratory duration:** 4–6 hours, excluding independent report preparation.

**Safety requirements:**

- Use the supplied isolated Compose project.
- Do not expose the training application publicly.
- Do not place real credentials in the repository.
- Do not remove unrelated Docker volumes.
- Do not use `docker compose down -v` against data that must be retained.
- Preserve evidence before destructive operations.

---

# 58. EXPERIMENT 1 — VERIFY THE DEVELOPMENT ENVIRONMENT

Execute:

```bash
docker version
```

```bash
docker compose version
```

```bash
docker buildx version
```

```bash
git --version
```

```bash
python3 --version
```

**Objective:** Confirm the required development tools.

**Required observations:** Record the installed versions.

---

# 59. EXPERIMENT 2 — PREPARE THE PROJECT

Extract the supplied project archive.

Enter the directory containing `compose.yaml`.

Verify:

```bash
ls
```

Inspect the project structure.

**Objective:** Identify the application, database, gateway, scripts, and workflow directories.

**Expected result:** All required source files exist.

---

# 60. EXPERIMENT 3 — CREATE THE DATABASE SECRET

Execute the secret-generation commands from Section 42.

Confirm that:

```text
secrets/db_password.txt
```

exists.

Do not print its contents.

**Objective:** Prepare local runtime configuration without hardcoding a password into the image.

---

# 61. EXPERIMENT 4 — VALIDATE THE COMPOSE MODEL

Execute:

```bash
docker compose config -q
```

Then:

```bash
docker compose config
```

**Objective:** Validate the application architecture.

**Required observations:**

1. Three services.
2. Two networks.
3. One named volume.
4. One secret.
5. Health checks.
6. Restart policies.
7. Resource limits.
8. Published gateway port.

---

# 62. EXPERIMENT 5 — BUILD THE APPLICATION IMAGE

Execute:

```bash
docker compose build web
```

**Objective:** Build the multi-stage Flask image.

**Expected result:** The Dockerfile test stage completes and the runtime image is produced.

**Required analysis:** Explain which dependencies are installed during the build and which files enter the final image.

---

# 63. EXPERIMENT 6 — START THE COMPLETE APPLICATION

Execute:

```bash
docker compose up -d
```

For supported Compose versions, the following also waits for configured services to become ready:

```bash
docker compose up -d --wait --wait-timeout 150
```

**Objective:** Start PostgreSQL, Flask, and Nginx.

**Expected result:** The services start and eventually report healthy states.

---

# 64. EXPERIMENT 7 — VERIFY SERVICE STATES

Execute:

```bash
docker compose ps
```

Then:

```bash
docker compose ps -a
```

**Objective:** Inspect lifecycle and health status.

**Required analysis:** Explain the difference between a running process and a healthy service.

---

# 65. EXPERIMENT 8 — OPEN THE WEB APPLICATION

Open:

```text
http://127.0.0.1:8311
```

**Objective:** Verify that the browser reaches the application through Nginx.

**Expected result:** The Docker Graduation Capstone page appears.

**Required analysis:** Trace the request through Nginx and Flask.

---

# 66. EXPERIMENT 9 — CREATE TASKS THROUGH THE BROWSER

Add three tasks.

Suggested examples:

```text
Review Docker networking
Practice PostgreSQL backups
Complete Docker final examination
```

**Objective:** Test the application user interface.

**Expected result:** The tasks appear in the list.

**Required analysis:** Explain why the task data is stored in PostgreSQL rather than in the browser or Flask process.

---

# 67. EXPERIMENT 10 — TEST THE REST API

Execute:

```bash
curl -i http://127.0.0.1:8311/health/live
```

Then:

```bash
curl -i http://127.0.0.1:8311/health/ready
```

Then:

```bash
curl http://127.0.0.1:8311/api/tasks
```

**Objective:** Verify liveness, readiness, and task retrieval.

---

# 68. EXPERIMENT 11 — CREATE A TASK USING CURL

Execute:

```bash
curl -i \
  -X POST \
  http://127.0.0.1:8311/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Docker capstone API task"}'
```

**Expected result:** HTTP 201.

Record the returned task ID.

**Objective:** Verify database-backed task creation.

---

# 69. EXPERIMENT 12 — UPDATE A TASK

Use the task ID returned in the previous experiment.

For example, if the ID is 4:

```bash
curl -i \
  -X PATCH \
  http://127.0.0.1:8311/api/tasks/4 \
  -H "Content-Type: application/json" \
  -d '{"done":true}'
```

Replace 4 with the actual task ID.

**Expected result:** HTTP 200 and `done: true`.

**Objective:** Verify parameterized database updates.

---

# 70. EXPERIMENT 13 — DELETE A TASK

Use the actual task ID:

```bash
curl -i \
  -X DELETE \
  http://127.0.0.1:8311/api/tasks/4
```

**Expected result:** HTTP 204.

Now retrieve the deleted task.

**Expected result:** HTTP 404.

**Objective:** Verify deletion semantics.

---

# 71. EXPERIMENT 14 — TEST INVALID INPUT

Attempt an empty task title:

```bash
curl -i \
  -X POST \
  http://127.0.0.1:8311/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"   "}'
```

**Expected result:** HTTP 400.

Attempt an invalid completion value:

```bash
curl -i \
  -X PATCH \
  http://127.0.0.1:8311/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"done":"yes"}'
```

**Expected result:** HTTP 400.

**Objective:** Verify input validation independently of database state.

---

# 72. EXPERIMENT 15 — RUN THE COMPLETE ACCEPTANCE TEST

Execute:

```bash
python3 scripts/smoke.py http://127.0.0.1:8311
```

**Objective:** Execute the end-to-end acceptance suite.

**Expected result:** The script reports successful liveness, readiness, validation, create, list, retrieve, update, and delete operations.

**Required analysis:** Explain why this test is stronger than checking only the homepage.

---

# 73. EXPERIMENT 16 — INSPECT POSTGRESQL

Execute:

```bash
docker compose exec db \
  psql -U taskowner -d taskdb \
  -c 'SELECT id, title, done, created_at FROM tasks ORDER BY id;'
```

**Objective:** Inspect the authoritative database records.

**Required analysis:** Compare the SQL results with the browser's task list.

---

# 74. EXPERIMENT 17 — INSPECT THE DATABASE SCHEMA

Execute:

```bash
docker compose exec db \
  psql -U taskowner -d taskdb \
  -c '\d+ public.tasks'
```

**Objective:** Inspect table columns, constraints, and indexes.

**Required analysis:** Explain the database-level controls that protect data integrity.

---

# 75. EXPERIMENT 18 — VERIFY NETWORK SEGMENTATION

Execute:

```bash
docker network inspect docker-day21-capstone_frontend
```

Then:

```bash
docker network inspect docker-day21-capstone_data
```

**Expected membership:**

| Network | Services |
|---|---|
| frontend | gateway, web |
| data | web, db |

**Objective:** Verify separation of the client-facing and database networks.

---

# 76. EXPERIMENT 19 — VERIFY THAT POSTGRESQL HAS NO PUBLISHED HOST PORT

Execute:

```bash
docker compose ps
```

Inspect the published ports.

**Expected result:** Only the gateway publishes a host port.

**Objective:** Verify that PostgreSQL is not directly published to the host.

**Required analysis:** Explain how Flask can access the database even though PostgreSQL has no published port.

---

# 77. EXPERIMENT 20 — VERIFY NON-ROOT APPLICATION EXECUTION

Execute:

```bash
docker compose exec web id
```

**Expected result:** UID and GID 10001.

**Objective:** Verify the application process identity.

**Required analysis:** Explain the difference between a non-root container process and rootless Docker Engine.

---

# 78. EXPERIMENT 21 — VERIFY FILESYSTEM HARDENING

Attempt a root-filesystem write:

```bash
docker compose exec web sh -c 'touch /should-fail'
```

**Expected result:** The write fails.

Now test the designated temporary directory:

```bash
docker compose exec web sh -c 'touch /tmp/temporary-test && echo "tmpfs works"'
```

**Expected result:** The temporary write succeeds.

**Objective:** Verify read-only root filesystem behavior.

---

# 79. EXPERIMENT 22 — INSPECT RESOURCE LIMITS

Execute:

```bash
docker stats --no-stream
```

Inspect the web container:

```bash
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{.HostConfig.Memory}}'
```

Then:

```bash
docker inspect \
  "$(docker compose ps -q web)" \
  --format '{{.HostConfig.PidsLimit}}'
```

**Objective:** Verify resource constraints.

**Required analysis:** Explain why resource limits must reflect actual workload requirements.

---

# 80. EXPERIMENT 23 — TEST DATABASE FAILURE

Stop PostgreSQL:

```bash
docker compose stop db
```

Test liveness:

```bash
curl -i http://127.0.0.1:8311/health/live
```

Test readiness:

```bash
curl -i http://127.0.0.1:8311/health/ready
```

**Expected result:** Flask may remain alive while database readiness returns HTTP 503.

**Objective:** Distinguish process availability from application readiness.

---

# 81. EXPERIMENT 24 — DIAGNOSE AND RECOVER FROM DATABASE FAILURE

Inspect:

```bash
docker compose ps -a
```

```bash
docker compose logs --tail 40 web
```

```bash
docker compose logs --tail 40 db
```

Restart PostgreSQL:

```bash
docker compose start db
```

Verify readiness.

**Objective:** Recover without deleting or recreating the database volume.

**Required analysis:** Explain why a restart policy cannot automatically repair every dependency problem.

---

# 82. EXPERIMENT 25 — VERIFY DATA PERSISTENCE

Record the current task count:

```bash
docker compose exec db \
  psql -U taskowner -d taskdb \
  -c 'SELECT COUNT(*) FROM tasks;'
```

Remove the application containers without deleting volumes:

```bash
docker compose down
```

Restart:

```bash
docker compose up -d
```

Repeat the database count.

**Expected result:** The existing tasks remain available.

**Objective:** Verify PostgreSQL named-volume persistence.

---

# 83. EXPERIMENT 26 — CREATE A CONSISTENT DATABASE BACKUP

Create a backup directory:

```bash
mkdir -p backups
```

Execute:

```bash
docker compose exec -T db \
  pg_dump -U taskowner -d taskdb -Fc \
  > backups/taskdb.dump
```

**Objective:** Create a consistent logical PostgreSQL backup.

**Important:** PostgreSQL `pg_dump` uses a consistent database snapshot and can run while normal database activity continues.

The `-Fc` option selects PostgreSQL's custom archive format.

This is not equivalent to copying raw database files while PostgreSQL is writing them.

---

# 84. EXPERIMENT 27 — INSPECT THE BACKUP

List the backup file:

```bash
ls -lh backups/taskdb.dump
```

Inspect its archive contents through PostgreSQL tools:

```bash
cat backups/taskdb.dump | \
  docker compose exec -T db pg_restore --list
```

**Objective:** Confirm that a readable PostgreSQL archive was created.

**Required analysis:** Explain why archive inspection is useful but insufficient to prove complete recovery.

---

# 85. EXPERIMENT 28 — CREATE AN INDEPENDENT RESTORATION DATABASE

Create a new Docker volume:

```bash
docker volume create day21-restore-data
```

Start a separate PostgreSQL instance:

```bash
docker run -d \
  --name day21-restore-check \
  --network none \
  --env POSTGRES_DB=taskdb \
  --env POSTGRES_USER=taskowner \
  --env POSTGRES_PASSWORD_FILE=/run/secrets/db_password \
  --mount type=volume,source=day21-restore-data,target=/var/lib/postgresql/data \
  --mount type=bind,source="$(pwd)/secrets/db_password.txt",target=/run/secrets/db_password,readonly \
  postgres:17-alpine
```

**Objective:** Initialize a separate recovery environment.

**Important Detail:** The recovery instance uses an independent volume.

It does not overwrite the original application data.

The `--network none` configuration keeps this training recovery container disconnected from Docker networks.

---

# 86. EXPERIMENT 29 — RESTORE THE BACKUP

Verify that the recovery database has started.

Execute:

```bash
docker exec day21-restore-check \
  pg_isready -U taskowner -d taskdb
```

When ready, restore the dump:

```bash
docker exec -i day21-restore-check \
  pg_restore \
  -U taskowner \
  -d taskdb \
  --no-owner \
  --no-privileges \
  < backups/taskdb.dump
```

**Objective:** Reconstruct the task database in the independent recovery environment.

**Expected result:** The SQL schema and backed-up task records are restored.

---

# 87. EXPERIMENT 30 — VERIFY RECOVERED DATA

Execute:

```bash
docker exec day21-restore-check \
  psql -U taskowner -d taskdb \
  -c 'SELECT id, title, done FROM tasks ORDER BY id;'
```

Compare the recovered rows with the original task records.

**Objective:** Verify actual database recovery.

**Required conclusion:** The restored database contains the expected task data.

This provides stronger evidence than the mere existence of a backup archive.

---

# 88. EXPERIMENT 31 — VERIFY THE CI/CD PROJECT

Initialize or inspect the Git repository.

Push the project to an authorized GitHub repository.

Confirm that the workflow files exist under:

```text
.github/workflows/
```

Verify that the CI workflow runs for the intended branch or pull request.

If Docker Hub publishing is desired:

1. Configure the repository variable `DOCKERHUB_USERNAME`.
2. Configure the secret `DOCKERHUB_TOKEN`.
3. Create the authorized `day21-taskmanager` repository.
4. Tag an approved commit using a version such as `v1.0.0`.
5. Push the tag.
6. Verify release workflow execution.
7. Record the actual published image digest.

**Objective:** Complete the software delivery lifecycle.

---

# 89. EXPERIMENT 32 — FINAL VERIFICATION AND CONTROLLED CLEANUP

Inspect:

```bash
docker compose ps
```

```bash
docker compose logs --tail 30
```

```bash
docker volume ls
```

```bash
docker network ls
```

Verify the task-management API one final time.

Stop and remove the recovery container:

```bash
docker stop day21-restore-check
```

```bash
docker rm day21-restore-check
```

Stop the main application without deleting the original volume:

```bash
docker compose down
```

The original PostgreSQL volume, the recovery volume, and the backup file remain unless deliberately removed.

**Optional destructive cleanup:**

Only after confirming that the data is no longer required:

```bash
docker volume rm day21-restore-data
```

To remove the original application volume, first verify that no container is using it and that independent backups are retained.

**Critical warning:** Do not execute broad pruning or volume-removal operations against unrelated Docker workloads.

---

# PART VIII — PRODUCTION ENGINEERING ASSESSMENT

# 90. FUNCTIONAL ACCEPTANCE MATRIX

| Test | Expected result |
|---|---|
| Webpage | HTTP 200 |
| Liveness | HTTP 200 |
| Readiness with database available | HTTP 200 |
| Create valid task | HTTP 201 |
| Create empty task | HTTP 400 |
| List tasks | HTTP 200 |
| Retrieve existing task | HTTP 200 |
| Retrieve unknown task | HTTP 404 |
| Update valid task | HTTP 200 |
| Update with non-Boolean value | HTTP 400 |
| Delete existing task | HTTP 204 |
| Retrieve deleted task | HTTP 404 |
| Stop database | Application readiness becomes unavailable |
| Restart database | Application readiness recovers |
| Recreate application containers | Database data remains |
| Restore logical backup | Expected rows are recovered |

The student should record actual responses rather than assuming that a command succeeded.

---

# 91. SECURITY ACCEPTANCE MATRIX

| Security requirement | Evidence |
|---|---|
| Flask runs as non-root | `docker compose exec web id` |
| Flask root filesystem is read-only | Failed write outside allowed mounts |
| Temporary storage works | Successful `/tmp` write |
| Linux capabilities reduced | Docker inspection |
| No-new-privileges configured | Docker inspection |
| Database not published | Compose port listing |
| Database network is internal | Network inspection |
| Password not in image source | Dockerfile and source review |
| Compose secret granted only to relevant services | Compose configuration |
| Bounded logging | Logging-driver inspection |
| Resource limits configured | Container inspection |
| No real secrets committed | Repository review |

## Important Limitation

These checks provide evidence about specific controls.

They do not prove the absence of vulnerabilities or guarantee complete application security.

---

# 92. OPERATIONAL ACCEPTANCE MATRIX

| Requirement | Verification |
|---|---|
| Container startup | Compose service status |
| Health monitoring | Docker health inspection |
| Restart policy | Runtime configuration |
| Application logs | Compose logs |
| Persistent storage | Container recreation test |
| Consistent backup | Successful pg_dump |
| Backup archive validation | pg_restore list |
| Recovery procedure | Independent database restore |
| REST API functionality | Smoke test |
| Automated source validation | GitHub Actions CI |
| Automated release publication | GitHub Actions release job |
| Registry digest tracking | Release job summary |

---

# 93. WHY THIS IS NOT YET A PUBLIC PRODUCTION SYSTEM

The final application demonstrates many production engineering principles.

However, several requirements remain outside the implemented training scope.

These include:

1. User authentication.
2. Per-user task ownership and authorization.
3. HTTPS with a trusted certificate.
4. Cross-site request forgery defenses if cookie-based authentication is introduced.
5. Rate limiting.
6. Dedicated least-privilege database roles.
7. Automated schema migrations.
8. Connection pooling appropriate to expected load.
9. Centralized metrics and alerting.
10. Off-site backups.
11. Database replication.
12. Multi-host high availability.
13. Scheduled vulnerability scanning.
14. Fully pinned transitive dependencies.
15. Approved image digests.
16. Formal release approval.
17. Operational incident escalation.
18. Disaster recovery testing on replacement infrastructure.

Recognizing these requirements is part of professional engineering competence.

---

# PART IX — FINAL TROUBLESHOOTING EXAMINATION

# 94. FAILURE SCENARIO 1 — DATABASE UNAVAILABLE

**Symptom:** The homepage loads, but the task list cannot be retrieved.

**Possible causes:**

- PostgreSQL stopped.
- Wrong database hostname.
- Incorrect database credentials.
- Database schema unavailable.
- Network attachment failure.

**Required diagnostic sequence:**

1. Inspect Compose service status.
2. Retrieve Flask logs.
3. Inspect PostgreSQL health.
4. Verify effective database configuration.
5. Verify network membership.
6. Verify database connectivity.
7. Correct the identified cause.
8. Repeat the readiness and API tests.

---

# 95. FAILURE SCENARIO 2 — HTTP 502

**Symptom:** Nginx returns HTTP 502.

**Possible causes:**

- Flask is stopped.
- Gunicorn failed.
- Incorrect upstream port.
- Incorrect service hostname.
- Frontend network problem.

**Required investigation:**

```bash
docker compose ps
```

```bash
docker compose logs gateway
```

```bash
docker compose logs web
```

Explain why an Nginx error does not necessarily mean Nginx itself is the failing component.

---

# 96. FAILURE SCENARIO 3 — APPLICATION CONTAINER EXITS

**Symptom:** The Flask container exits shortly after startup.

**Possible causes:**

- Missing dependency.
- Incorrect Gunicorn command.
- Invalid application import.
- Permission error.
- Resource failure.

**Required evidence:**

- Exit code.
- Logs.
- Dockerfile command.
- Configured resource limits.
- Runtime identity.

The investigation should distinguish process failure from a failing health check.

---

# 97. FAILURE SCENARIO 4 — PERMISSION DENIED

**Symptom:** The application cannot write a temporary file.

**Possible causes:**

- Read-only root filesystem.
- Missing tmpfs mount.
- Wrong target directory.
- Incorrect user permissions.

**Required analysis:**

Explain why granting privileged mode is not the appropriate default solution.

Determine the minimum required writable directory.

---

# 98. FAILURE SCENARIO 5 — MISSING DATABASE TABLE

**Symptom:** PostgreSQL is running, but the application reports database readiness failure.

**Possible cause:** The `tasks` table does not exist.

**Required investigation:**

Inspect:

```bash
docker compose exec db \
  psql -U taskowner -d taskdb \
  -c '\dt'
```

Determine whether the database volume was newly initialized or already contained an existing cluster.

**Important Principle:** Initialization scripts are not a replacement for schema migrations.

---

# 99. FAILURE SCENARIO 6 — APPARENT DATA LOSS

**Symptom:** A recreated application displays no tasks.

**Possible causes:**

- Wrong database.
- Wrong PostgreSQL volume.
- Different Compose project name.
- Schema reset.
- Actual data deletion.

**Required analysis:**

Verify the database and volume identities before attempting restoration.

Do not delete the original data while diagnosing apparent data loss.

---

# 100. FAILURE SCENARIO 7 — BACKUP RESTORE ERROR

**Symptom:** `pg_restore` reports errors.

**Possible causes:**

- Archive corruption.
- Incorrect database version.
- Existing destination objects.
- Insufficient database permissions.
- Missing extension.
- Incompatible schema.

**Required procedure:**

1. Inspect the archive.
2. Inspect the destination database.
3. Verify PostgreSQL versions.
4. Review error messages.
5. Correct the destination configuration.
6. Repeat restoration safely.
7. Verify recovered data.

---

# 101. FAILURE SCENARIO 8 — CI WORKFLOW FAILURE

**Symptom:** GitHub Actions reports failure.

**Possible causes:**

- Failed unit test.
- Dockerfile build failure.
- PostgreSQL initialization failure.
- Health-check timeout.
- Incorrect secret-file setup.
- API acceptance-test failure.

**Required analysis:**

Identify the first meaningful failing step.

Read the available logs.

Distinguish an application defect from a runner or configuration problem.

---

# 102. FAILURE SCENARIO 9 — REGISTRY PUBLICATION DENIED

**Symptom:** The release verification job passes, but Docker Hub rejects the push.

**Possible causes:**

- Invalid token.
- Missing repository permission.
- Incorrect namespace.
- Missing GitHub secret.
- Incorrect repository name.

**Required analysis:**

Explain why source validation success does not automatically authorize registry publication.

---

# 103. FAILURE SCENARIO 10 — DEPLOYED IMAGE DIFFERS FROM APPROVED RELEASE

**Symptom:** A running application reports an unexpected version.

**Possible causes:**

- Wrong image tag.
- Mutable tag updated.
- Local cached image.
- Wrong Compose environment value.
- Incorrect deployment command.

**Required investigation:**

Compare:

1. Intended release version.
2. Registry digest.
3. Effective Compose configuration.
4. Running container image identifier.
5. Application release metadata.

---

# PART X — FINAL ACADEMIC EXAMINATION

# 104. PART A — FOUNDATIONAL THEORY

Answer the following questions.

1. Define containerization.
2. Explain the difference between containers and virtual machines.
3. Describe Linux namespaces.
4. Explain the purpose of cgroups.
5. Define a Docker image.
6. Define a Docker container.
7. Explain image layers.
8. Describe the Dockerfile build context.
9. Explain `.dockerignore`.
10. Define a multi-stage build.
11. Explain BuildKit.
12. Describe Docker image caching.
13. Explain why container process exit codes matter.
14. Define a Docker network.
15. Explain Docker service-name resolution.

---

# 105. PART B — APPLICATION AND DATA ENGINEERING

Answer the following questions.

1. Why does the application use PostgreSQL?
2. What is a primary key?
3. What does the Boolean `done` column represent?
4. Why are task IDs generated by the database?
5. Why are parameterized SQL queries important?
6. What is a database transaction?
7. Why does the application validate titles?
8. Why does the API return HTTP 201 for task creation?
9. Why does deletion return HTTP 204?
10. Why does an unknown task return HTTP 404?
11. What does HTTP 503 indicate?
12. Why is the database placed on an internal Docker network?
13. Why is PostgreSQL data stored in a volume?
14. What are PostgreSQL initialization scripts?
15. Why are schema migrations necessary after initial deployment?

---

# 106. PART C — SECURITY AND OPERATIONS

Answer the following questions.

1. Explain the principle of least privilege.
2. Why does Flask run as UID 10001?
3. What does `cap_drop: ALL` request?
4. What does no-new-privileges restrict?
5. Why is the root filesystem read-only?
6. Why is `/tmp` writable?
7. What is a Compose secret?
8. Why must credentials not be embedded in an image?
9. What is the purpose of a health check?
10. Distinguish liveness from readiness.
11. Why do restart policies not provide complete high availability?
12. Why are resource limits important?
13. What is bounded logging?
14. Why is a named volume not a backup?
15. Why must database restoration be tested?

---

# 107. PART D — CI/CD AND RELEASE ENGINEERING

Answer the following questions.

1. Define Continuous Integration.
2. Define Continuous Delivery.
3. Define Continuous Deployment.
4. What is a GitHub Actions workflow?
5. What is a runner?
6. What is a quality gate?
7. Why are pull-request workflows less privileged?
8. Why does the release workflow contain separate verification and publication jobs?
9. What is Docker Buildx?
10. What is the purpose of a build cache?
11. What is a Docker image tag?
12. What is an image digest?
13. Why should published digests be recorded?
14. What is build provenance?
15. Why is application rollback different from database recovery?

---

# 108. PART E — DESIGN QUESTION

**Examination Question:**

Design an architecture for a task-management application expected to support a large number of concurrent users.

Your answer must address:

- Client traffic.
- Reverse proxying.
- Application replicas.
- Database availability.
- Persistent storage.
- Authentication.
- Transport encryption.
- Database backups.
- Metrics and alerting.
- Deployment strategy.
- Rollback.
- Failure domains.

Produce an architectural diagram and explain the responsibilities of each major component.

Discuss which requirements cannot be satisfied by simply running three containers on one Docker host.

---

# 109. PART F — PRACTICAL FAILURE ANALYSIS

You are given the following incident:

```text
12:00 — Task manager is operating correctly.

12:05 — PostgreSQL becomes unavailable.

12:06 — Flask remains running.

12:06 — Readiness check fails.

12:07 — New task creation returns HTTP 503.

12:10 — PostgreSQL is restarted.

12:11 — Readiness succeeds.

12:12 — Task creation succeeds.
```

Answer:

1. Which component originally failed?
2. Why did Flask remain running?
3. Why did the readiness check fail?
4. What is the meaning of HTTP 503?
5. Why did a Flask restart not necessarily need to occur?
6. Which logs should be inspected?
7. Which Docker events might be relevant?
8. Which persistent storage conditions should be verified?
9. How should recovery be documented?
10. What preventive operational improvements would you recommend?

---

# PART XI — FINAL CAPSTONE ASSESSMENT

# 110. FINAL 100-MARK RUBRIC

| Assessment category | Marks |
|---|---:|
| Docker architecture and system design | 10 |
| Flask REST API functionality | 15 |
| PostgreSQL schema and persistence | 10 |
| Dockerfile and image engineering | 10 |
| Docker Compose networking and orchestration | 10 |
| Security and runtime hardening | 10 |
| Unit and end-to-end tests | 10 |
| Backup and recovery verification | 10 |
| GitHub Actions and release automation | 10 |
| Documentation and technical explanation | 5 |
| **Total** | **100** |

## Suggested Academic Classification

| Score | Classification |
|---|---|
| 90–100 | Excellent |
| 80–89 | Very Good |
| 70–79 | Good |
| 60–69 | Satisfactory |
| Below 60 | Further work required |

These classifications are proposed for this course and are not an official institutional grading standard.

---

# 111. MINIMUM PASSING REQUIREMENTS

Regardless of the numerical grade, a successful final capstone should demonstrate:

1. The application starts through Compose.
2. PostgreSQL is persistent.
3. The REST API operates correctly.
4. Nginx forwards requests successfully.
5. The database is not published directly.
6. The application runs non-root.
7. Unit tests pass.
8. End-to-end tests pass.
9. The database backup can be restored.
10. The student can explain the system architecture.

The backup requirement is especially important.

A backup that has never been restored does not provide sufficient evidence of recoverability.

---

# 112. FINAL PROJECT REPORT

Prepare a formal academic report of approximately 2,000–3,000 words entitled:

**“Engineering a Secure, Persistent, and Automated Multi-Container Task Management Application with Docker, Flask, PostgreSQL, and GitHub Actions.”**

The report must include:

1. Executive summary.
2. Problem statement.
3. Functional requirements.
4. Non-functional requirements.
5. System architecture.
6. Service responsibilities.
7. Database design.
8. REST API specification.
9. Dockerfile design.
10. Docker Compose architecture.
11. Network segmentation.
12. Secret management.
13. Security hardening.
14. Health checks.
15. Resource limits.
16. Logging.
17. Automated testing.
18. Controlled failure experiments.
19. Persistent storage verification.
20. Backup and restoration.
21. CI/CD workflow architecture.
22. Release publication.
23. Limitations.
24. Future improvements.
25. Technical conclusion.

The report must contain at least three architectural or process diagrams and a record of actual laboratory verification results.

---

# 113. PROFESSIONAL CODE REVIEW QUESTIONS

A reviewer should ask:

**Is input validated?**

Task titles and completion states must satisfy the API contract.

**Are SQL statements parameterized?**

User-provided data must not be inserted directly into query strings.

**Are database operations transactional?**

Successful mutations must be committed correctly.

**Are errors handled?**

Temporary database unavailability should produce controlled responses.

**Are sensitive values exposed?**

Secrets must not be embedded in source code or image layers.

**Is the application running as root?**

The Flask runtime uses a non-root identity.

**Are unnecessary host ports published?**

Only Nginx has a published localhost endpoint.

**Is persistent storage actually used?**

PostgreSQL writes to the named volume.

**Can the system be recovered?**

The backup must be independently restored and checked.

**Is the release traceable?**

The CI/CD process records Git and image artifact information.

---

# 114. FINAL ENGINEERING COMPETENCY CHECKLIST

## Docker Fundamentals

- [ ] I understand Docker architecture.
- [ ] I can build images.
- [ ] I can run containers.
- [ ] I can inspect containers.
- [ ] I can read container logs.
- [ ] I can troubleshoot process failures.

## Image Engineering

- [ ] I can write Dockerfiles.
- [ ] I understand image layers.
- [ ] I can use `.dockerignore`.
- [ ] I understand multi-stage builds.
- [ ] I can use BuildKit.
- [ ] I can distinguish test and runtime stages.

## Networking

- [ ] I can configure Docker bridge networks.
- [ ] I understand service DNS.
- [ ] I can use a reverse proxy.
- [ ] I understand host port publishing.
- [ ] I can isolate a database network.

## Persistent Storage

- [ ] I understand named volumes.
- [ ] I can inspect volumes.
- [ ] I can configure PostgreSQL persistence.
- [ ] I understand database initialization.
- [ ] I can create a logical backup.
- [ ] I can restore a backup.
- [ ] I can verify recovered records.

## Security

- [ ] I can configure non-root execution.
- [ ] I can configure a read-only filesystem.
- [ ] I can configure tmpfs.
- [ ] I can remove unnecessary capabilities.
- [ ] I understand no-new-privileges.
- [ ] I can configure a Compose secret.
- [ ] I understand database least privilege.
- [ ] I can identify missing authentication requirements.

## Reliability

- [ ] I can configure health checks.
- [ ] I understand service readiness.
- [ ] I understand restart policies.
- [ ] I can set resource limits.
- [ ] I can inspect resource usage.
- [ ] I can diagnose a failed dependency.

## Application Engineering

- [ ] I can design a REST API.
- [ ] I understand relational data modeling.
- [ ] I can implement parameterized SQL.
- [ ] I can validate application input.
- [ ] I can test API status codes.
- [ ] I can distinguish unit and integration tests.

## CI/CD

- [ ] I can create a GitHub Actions workflow.
- [ ] I can configure automated tests.
- [ ] I can build Docker images in CI.
- [ ] I can run integration tests.
- [ ] I can explain release verification.
- [ ] I can authenticate to Docker Hub securely.
- [ ] I can publish an image.
- [ ] I can inspect an image digest.
- [ ] I can explain deployment rollback.

## Final Capstone

- [ ] I built the task manager.
- [ ] I started all services.
- [ ] I created tasks.
- [ ] I updated tasks.
- [ ] I deleted tasks.
- [ ] I inspected the PostgreSQL database.
- [ ] I tested invalid input.
- [ ] I verified network isolation.
- [ ] I verified non-root execution.
- [ ] I verified filesystem restrictions.
- [ ] I inspected resource limits.
- [ ] I demonstrated database failure.
- [ ] I restored database availability.
- [ ] I verified persistent storage.
- [ ] I created a consistent backup.
- [ ] I restored the backup into a separate volume.
- [ ] I verified recovered data.
- [ ] I reviewed the CI/CD workflows.
- [ ] I completed the final examination.
- [ ] I prepared the academic capstone report.

---

# PART XII — EXTENSION PROJECTS

# 115. EXTENSION A — USER AUTHENTICATION

Introduce user accounts.

Store password hashes using an appropriate contemporary password-hashing library.

Implement login and logout.

Require authentication before creating or modifying tasks.

Ensure each task belongs to a specific authorized user.

Do not store raw user passwords in PostgreSQL.

---

# 116. EXTENSION B — ROLE-BASED ACCESS CONTROL

Introduce roles such as:

- Administrator.
- Standard user.
- Read-only user.

Define permissions for:

- Task creation.
- Task modification.
- Task deletion.
- Administrative operations.

Test authorization failures.

Distinguish authentication from authorization.

---

# 117. EXTENSION C — DATABASE MIGRATIONS

Add a database migration system.

A migration should track schema versions and apply changes through a controlled process.

Possible operations include:

- Adding columns.
- Creating indexes.
- Adding constraints.
- Migrating data.
- Managing backward compatibility.

The migration workflow should be coordinated with application releases.

---

# 118. EXTENSION D — HTTPS DEPLOYMENT

Adapt the Nginx configuration from Lecture 19.

Use an appropriate certificate.

Redirect HTTP to HTTPS.

Evaluate transport encryption between services if required by the deployment threat model.

Apply suitable browser security headers.

Do not publicly expose the current unauthenticated HTTP training application.

---

# 119. EXTENSION E — OBSERVABILITY

Introduce:

- Application metrics.
- Request latency measurements.
- Error counters.
- Structured logging.
- Centralized log collection.
- Distributed tracing.
- Alerting rules.

Measure the service's behavior under normal load and during selected failures.

---

# 120. EXTENSION F — HIGH AVAILABILITY

Investigate:

- Multiple application replicas.
- Reverse proxy load balancing.
- Database replication.
- Failover.
- External persistent storage.
- Multi-host deployment.
- Recovery objectives.

Explain which responsibilities require additional infrastructure beyond a single Docker Engine.

---

# 121. EXTENSION G — SECURE CI/CD

Improve the release workflow through:

- Full action SHA pinning.
- Dependency locking.
- Image vulnerability scanning.
- Protected release tags.
- Registry credential scoping.
- Approved deployment environments.
- Artifact identity verification.
- Build-once-and-promote workflows.

Develop an explicit release approval policy.

---

# PART XIII — CONCLUSION OF THE FINAL LECTURE

# 122. WHAT THE CAPSTONE DEMONSTRATES

The final project demonstrates that Docker is more than a tool for starting isolated processes.

Docker provides a framework for packaging and operating software components.

A complete application requires coordination between:

- Code.
- Images.
- Containers.
- Networks.
- Persistent storage.
- Runtime configuration.
- Security controls.
- Health monitoring.
- Tests.
- Release artifacts.
- Operational procedures.

The task manager combines these responsibilities into one engineering system.

The browser communicates with Nginx.

Nginx forwards HTTP requests to Flask.

Flask validates requests and executes parameterized SQL through Psycopg.

PostgreSQL manages relational data stored in a Docker named volume.

Compose defines how the services are created, connected, monitored, and operated.

GitHub Actions validates source changes and supports release publication.

PostgreSQL backup utilities provide consistent logical exports.

Independent restoration provides evidence that the database can be recovered.

Each component has a defined responsibility.

Understanding these responsibilities is the central goal of the capstone.

---

# 123. WHAT REMAINS AFTER GRADUATION

Completion of a twenty-one-day Docker course is an important foundation, but Docker engineering continues well beyond introductory and intermediate practice.

Further professional study may include:

1. Advanced Linux internals.
2. Container runtime security.
3. OCI image and runtime specifications.
4. Kubernetes.
5. Helm.
6. Infrastructure as Code.
7. Terraform.
8. Cloud networking.
9. Distributed databases.
10. Advanced PostgreSQL administration.
11. Monitoring and incident response.
12. Software supply-chain security.
13. Enterprise CI/CD systems.
14. Platform engineering.
15. Site Reliability Engineering.

These subjects build naturally on the techniques established in the course.

---

# 124. FINAL REFERENCES

## Docker Architecture and Compose

[1] Docker Inc. *Docker Documentation.*  
https://docs.docker.com/

[2] Docker Inc. *Docker Compose Documentation.*  
https://docs.docker.com/compose/

[3] Docker Inc. *Control Startup and Shutdown Order in Compose.*  
https://docs.docker.com/compose/how-tos/startup-order/

[4] Docker Inc. *Compose Services Reference.*  
https://docs.docker.com/reference/compose-file/services/

[5] Docker Inc. *Use Compose in Production.*  
https://docs.docker.com/compose/how-tos/production/

## Docker Security and Storage

[6] Docker Inc. *Manage Secrets in Compose.*  
https://docs.docker.com/compose/how-tos/use-secrets/

[7] Docker Inc. *Docker Engine Security.*  
https://docs.docker.com/engine/security/

[8] Docker Inc. *Docker Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[9] Docker Inc. *Multi-Stage Builds.*  
https://docs.docker.com/build/building/multi-stage/

[10] Docker Inc. *Docker BuildKit.*  
https://docs.docker.com/build/buildkit/

## PostgreSQL

[11] PostgreSQL Global Development Group. *PostgreSQL Documentation.*  
https://www.postgresql.org/docs/

[12] PostgreSQL. *pg_dump.*  
https://www.postgresql.org/docs/current/app-pgdump.html

[13] PostgreSQL. *pg_restore.*  
https://www.postgresql.org/docs/current/app-pgrestore.html

[14] Docker Hub. *PostgreSQL Official Image.*  
https://hub.docker.com/_/postgres

## Python Application Development

[15] Pallets Projects. *Flask Documentation.*  
https://flask.palletsprojects.com/

[16] Psycopg Project. *Psycopg 3 Documentation.*  
https://www.psycopg.org/psycopg3/docs/

[17] Gunicorn. *Documentation.*  
https://gunicorn.org/

[18] Python Software Foundation. *Python Documentation.*  
https://docs.python.org/3/

## CI/CD and Distribution

[19] GitHub. *GitHub Actions Documentation.*  
https://docs.github.com/en/actions

[20] Docker Inc. *Docker Build GitHub Actions.*  
https://docs.docker.com/build/ci/github-actions/

[21] Docker. *Docker Build Push Action.*  
https://github.com/docker/build-push-action

[22] Docker. *Docker Metadata Action.*  
https://github.com/docker/metadata-action

[23] Docker Inc. *Docker Hub Documentation.*  
https://docs.docker.com/docker-hub/

## Further Engineering Study

[24] Open Container Initiative. *OCI Specifications.*  
https://opencontainers.org/

[25] OpenTelemetry. *Documentation.*  
https://opentelemetry.io/docs/

[26] Google. *Site Reliability Engineering.*  
https://sre.google/books/

---

# 125. FINAL COURSE CONCLUSION

Over the course of twenty-one lectures, the student has progressed from fundamental containerization concepts to the construction and operational evaluation of a complete multi-container application.

The course began by examining the relationship between processes, Linux namespaces, cgroups, Docker Engine, and container isolation.

It continued with the Docker container lifecycle and the commands required to create, inspect, operate, and troubleshoot containers.

Image construction introduced Dockerfiles, filesystem layers, build contexts, registries, and reproducible packaging.

Networking and storage extended these foundations into multi-container software systems.

Docker Compose provided declarative application configuration, internal service discovery, startup dependencies, and persistent volumes.

Production engineering introduced multi-stage image construction, BuildKit caching, non-root execution, Linux capability restrictions, container security profiles, secrets, resource limits, and operational diagnostics.

Registry engineering established a controlled method for publishing and retrieving image artifacts.

Production operations introduced reliability, health monitoring, logging, TLS, backup procedures, and recovery planning.

CI/CD connected these disciplines to repeatable automated software delivery.

The final capstone integrates these concepts through a PostgreSQL-backed task-management application.

The completed system separates request handling, application logic, and persistent data.

It provides a defined REST interface and a browser-based frontend.

Its runtime configuration includes internal networking, persistent storage, health checks, non-root execution, a read-only application filesystem, and bounded resource usage.

The project includes automated tests and GitHub Actions workflows.

Most importantly, the laboratory requires the student to create a logical database backup and demonstrate independent restoration.

This emphasizes an essential lesson of professional systems engineering:

**A software system is not fully understood merely because it can be started. It must also be explainable, testable, secure within its intended threat model, observable, maintainable, and recoverable.**

The successful completion of this capstone demonstrates substantial foundational knowledge of Docker and the engineering practices used to operate containerized applications.

Further expertise will come through repeated implementation, experimentation, failure analysis, source-code review, and the operation of increasingly complex real systems.

---

# 126. COURSE COMPLETION RECORD

**Course Title:** Docker: Foundations and Practical Applications

**Total Lectures:** 21

**Modules Completed:**

- Module 01 — Docker Fundamentals.
- Module 02 — Multi-Container Application Engineering.
- Module 03 — Production Engineering, Security, CI/CD, and Deployment.

**Final Capstone:** PostgreSQL-Backed Docker Task Manager.

**Final Assessment:** 100 Marks.

**Required Evidence of Completion:**

1. Functional application.
2. Valid Compose configuration.
3. Successful unit tests.
4. Successful end-to-end tests.
5. Verified database persistence.
6. Verified independent backup restoration.
7. Security and operational inspection.
8. CI/CD workflow review.
9. Final technical report.
10. Final examination.

**Academic Completion Standard:** Successful demonstration of the stated technical competencies and completion of the final assessment.

---

# 127. CLOSING STATEMENT

You have reached the end of the complete twenty-one-day Docker course.

The objective of this program has been to develop more than command familiarity.

It has been to establish a disciplined understanding of how containerized systems are designed, built, tested, secured, distributed, operated, diagnosed, and recovered.

The final practical project provides an integrated demonstration of those skills.

A successful student should now be able to take a small software application, design its container architecture, construct suitable images, configure networking and persistent storage, automate testing and publication, investigate failures, and document the operational requirements necessary for responsible deployment.

**This concludes Docker: Foundations and Practical Applications — Lectures 01 through 21.**

**END OF LECTURE 21**

**END OF THE COMPLETE COURSE**
