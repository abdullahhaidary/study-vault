# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 09 — DOCKER STORAGE AND DATA PERSISTENCE: WRITABLE LAYERS, VOLUMES, BIND MOUNTS, TEMPORARY STORAGE, BACKUP, AND RECOVERY

**Course:** Docker and Containerization Technology  
**Module:** 02 — Networking, Storage, and Multi-Container Applications  
**Lecture:** 09 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 4–5 hours

**Prerequisites:**

- Lecture 01 — Introduction to Docker and Containerization.
- Lecture 02 — Container Lifecycle Management.
- Lecture 03 — Container Filesystems and Runtime Inspection.
- Lecture 04 — Docker Images and Layered Architecture.
- Lecture 05 — Dockerfile Fundamentals.
- Lecture 06 — Advanced Dockerfile Instructions.
- Lecture 07 — Week One Review and Capstone.
- Lecture 08 — Port Publishing and Runtime Environment Configuration.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Explain the role of persistent storage in containerized applications.
2. Distinguish between application execution state and stored application data.
3. Describe the structure and limitations of container writable layers.
4. Explain the relationship between image layers and runtime filesystem changes.
5. Define Docker volumes and identify their principal characteristics.
6. Distinguish named volumes from anonymous volumes.
7. Explain how Docker manages volume lifecycles.
8. Create, list, inspect, and remove Docker volumes.
9. Explain the syntax of `--mount` and `-v`.
10. Describe how Docker mounts storage into a container filesystem.
11. Explain how mounts can obscure existing image content.
12. Describe the initial population behavior of empty Docker volumes.
13. Define bind mounts and explain their relationship to host filesystems.
14. Distinguish bind mounts from Docker-managed volumes.
15. Explain read-only and read-write mount behavior.
16. Describe how host file modifications may become visible inside a bind-mounted container.
17. Define temporary filesystem mounts and explain their uses.
18. Explain how container storage choices influence portability.
19. Identify filesystem ownership and permission problems.
20. Explain the relationship between application-level persistence and Docker-managed storage.
21. Configure a Redis database with persistent data storage.
22. Demonstrate data survival across container stopping, removal, and recreation.
23. Explain Redis snapshot and append-only persistence at an introductory level.
24. Create a consistent archive of a named volume.
25. Restore archived data into a separate Docker volume.
26. Explain why persistent storage is not equivalent to backup.
27. Identify security risks associated with host bind mounts.
28. Explain how volume removal and pruning can cause data loss.
29. Apply appropriate storage-selection principles.
30. Complete a practical laboratory integrating storage, container lifecycles, and application state.

---

# 2. INTRODUCTION TO DATA PERSISTENCE

## 2.1 Background

A Docker container is commonly designed to be replaceable.

An application container may be stopped, removed, and recreated from an image when:

- A new application version is deployed.
- Configuration changes.
- A container becomes unhealthy.
- Infrastructure is replaced.
- A service is restarted after failure.
- A development environment is rebuilt.

However, many applications produce information that must remain available beyond the lifetime of an individual container.

Examples include:

- Database records.
- User-uploaded files.
- Application documents.
- Transactional information.
- Generated reports.
- Stored messages.
- Application configuration.
- Media assets.
- Persistent queues.
- Long-term audit records.

If these resources exist only in a container's writable filesystem layer, removing the container ordinarily removes that data.

This behavior creates a fundamental architectural challenge.

Application containers should be replaceable, but important application data may need to survive.

Docker storage mechanisms address this requirement.

## 2.2 Definition of Persistence

Data persistence is the property by which information remains available beyond the lifetime of the process or execution instance that originally produced it.

**Formal definition:**

Data persistence is the retention of application state in a storage system capable of preserving the required information independently of a particular executing process or container instance.

Persistence must be evaluated according to the type of failure or lifecycle event involved.

For example, a file surviving an application restart does not necessarily mean it will survive container removal, disk failure, or host destruction.

## 2.3 Stateful and Stateless Applications

Applications are frequently classified as stateful or stateless.

### Stateless Applications

A stateless application does not rely on locally retained application state between independent requests or executions.

Examples may include:

- Static content servers.
- Certain HTTP API services.
- Request-processing applications that store their data externally.

A stateless application may be replaced without requiring the preservation of its container-local runtime files.

### Stateful Applications

A stateful application maintains information that influences subsequent operations.

Examples include:

- Databases.
- Message brokers.
- Persistent queues.
- File storage services.
- Applications maintaining durable user records.

A stateful application requires a storage and recovery strategy appropriate to the information it maintains.

## 2.4 Important Qualification

Stateless and stateful are architectural descriptions rather than absolute properties of software products.

A web server may operate statelessly while serving fixed content.

The same web server may become part of a stateful system when it writes uploaded files or stores application-generated information locally.

Similarly, some databases may be configured for temporary in-memory use without disk persistence.

The storage requirements depend on the actual application design.

---

# 3. REVIEW OF CONTAINER FILESYSTEM ARCHITECTURE

## 3.1 Image Filesystem Content

Docker container images contain filesystem layers representing packaged application content.

These layers may include:

- Executables.
- Libraries.
- Configuration files.
- Application resources.
- Runtime dependencies.

Image content is treated as immutable during ordinary container execution.

## 3.2 The Container Writable Layer

When Docker creates a conventional container, it establishes writable filesystem state associated with that particular container.

This layer accommodates changes made during runtime.

Such changes may include:

- Creating files.
- Updating files.
- Removing files.
- Writing temporary application output.
- Creating runtime directories.

## 3.3 Layered Filesystem Model

```text
RUNNING CONTAINER
[ Container Writable Layer ]
[ Image Layer 3 ]
[ Image Layer 2 ]
[ Image Layer 1 ]
```

The application ordinarily observes a unified filesystem hierarchy.

The storage implementation manages how the read-only image content and writable container state are presented.

## 3.4 Container Restart

Stopping and restarting the same container normally preserves its writable layer.

For example:

1. A container starts.
2. An application creates `/tmp/report.txt`.
3. The container stops.
4. The same container restarts.
5. The file remains present unless some other operation removed it.

## 3.5 Container Removal

When the container is removed, its writable layer is ordinarily deleted.

A newly created container from the original image does not inherit files that existed exclusively in the removed container's writable layer.

## 3.6 Fundamental Limitation

**The container writable layer is not a reliable substitute for independently managed persistent application storage.**

Its lifecycle is tied to the individual container object.

This relationship is appropriate for disposable runtime changes but unsuitable for important information that must survive container replacement.

---

# 4. STORAGE DECOUPLING

## 4.1 Definition

Storage decoupling is the architectural separation of application execution resources from the storage used to maintain application data.

In Docker, this is commonly achieved through volumes or bind mounts.

The application executes within a container.

Its important data resides in a storage resource whose lifecycle is not necessarily tied to that container.

## 4.2 Architectural Representation

```text
             DOCKER IMAGE
                  |
                  v
             CONTAINER
                  |
                  |
           Reads and Writes
                  |
                  v
            MOUNTED STORAGE
                  |
                  v
             STORED DATA
```

The container can be replaced while the selected storage resource remains available.

## 4.3 Replacement Model

```text
             CONTAINER A
                  |
                  v
             NAMED VOLUME
                  |
              Stored Data
                  |
                  v
             CONTAINER B
```

Container A may be removed.

Container B can subsequently mount the same named volume.

If the application uses compatible data formats and configurations, it can access the previously stored information.

## 4.4 Benefits of Decoupling

Separating application execution from data storage supports:

1. Container replacement.
2. Application upgrades.
3. Development environment reconstruction.
4. Controlled storage management.
5. Data backup.
6. Recovery procedures.
7. Independent lifecycle management.
8. Improved reproducibility of application deployment.

However, separating storage from a container does not automatically provide replication, high availability, or fault tolerance.

Those capabilities require additional system design.

---

# 5. DOCKER STORAGE MECHANISMS

Docker supports several ways of providing filesystem content to containers.

The principal mechanisms examined in this lecture are:

1. Container writable layers.
2. Docker volumes.
3. Bind mounts.
4. Temporary filesystem mounts.

## 5.1 Comparison

| Storage mechanism | Managed by | Typical purpose | Independent of container writable layer |
|---|---|---|---|
| Writable layer | Docker container lifecycle | Disposable runtime changes | No |
| Named volume | Docker volume subsystem | Persistent application data | Yes |
| Anonymous volume | Docker volume subsystem | Data stored in automatically named volume | Yes |
| Bind mount | Host filesystem and Docker mount configuration | Development files and selected host resources | Yes |
| tmpfs mount | Runtime and operating-system memory facilities | Temporary nonpersistent data | Yes |

## 5.2 Storage Selection Principle

Storage should be selected according to:

- Data lifetime.
- Application access requirements.
- Security sensitivity.
- Performance requirements.
- Portability.
- Backup requirements.
- Host compatibility.
- Concurrency requirements.

There is no single storage mechanism that is optimal for every application.

---

# 6. DOCKER VOLUMES

## 6.1 Definition

A Docker volume is a storage resource managed through Docker's volume subsystem.

Volumes can be created independently of containers and mounted into their filesystems.

**Formal definition:**

A Docker volume is a Docker-managed storage object that can be attached to container filesystem locations and whose lifecycle can be managed independently of individual container instances.

## 6.2 Principal Characteristics

Docker volumes commonly provide:

- Persistent storage across container replacement.
- Independent naming and management.
- Separation from container writable layers.
- Reuse by different containers.
- Explicit inspection.
- Compatibility with volume drivers.
- Support for backup and restoration workflows.

## 6.3 Local Volume Driver

Docker commonly uses the `local` volume driver by default.

With the local driver, volume content is ordinarily maintained within the Docker Engine host's storage environment.

On Docker Desktop, the actual storage generally resides in Docker's Linux execution environment rather than being presented directly as an ordinary native Windows or macOS directory.

## 6.4 Volume Architecture

```text
DOCKER ENGINE → CONTAINER A
DOCKER ENGINE → CONTAINER B
CONTAINER A → NAMED VOLUME
CONTAINER B → NAMED VOLUME
NAMED VOLUME → STORED FILESYSTEM
```

Multiple containers may be able to mount the same volume.

However, simultaneous access does not automatically make concurrent writes safe.

Applications must provide appropriate coordination when sharing mutable data.

---

# 7. NAMED VOLUMES

## 7.1 Definition

A named volume is a Docker volume assigned an explicit identifier.

Example:

`lecture09-data`

The identifier can be used in subsequent container creation and volume-management operations.

## 7.2 Creating a Named Volume

General syntax:

```text
docker volume create VOLUME_NAME
```

Example:

```bash
docker volume create lecture09-data
```

Docker creates the volume and returns its name.

## 7.3 Listing Volumes

```bash
docker volume ls
```

This displays the available volumes.

The output commonly includes:

- DRIVER.
- VOLUME NAME.

## 7.4 Inspecting a Volume

```bash
docker volume inspect lecture09-data
```

The output typically includes:

- Volume name.
- Driver.
- Mountpoint.
- Labels.
- Driver options.
- Scope.

## 7.5 Volume Mountpoint

The `Mountpoint` field identifies the underlying location associated with the volume in the Docker Engine environment.

For a conventional Linux Docker Engine using the local driver, the location may resemble:

```text
/var/lib/docker/volumes/lecture09-data/_data
```

This path is illustrative.

Its exact value depends on Docker configuration and the volume driver.

On Docker Desktop, this path generally refers to the internal Linux environment rather than a normal desktop host directory.

Administrators should avoid directly modifying Docker-managed storage directories unless the operation is explicitly supported and properly controlled.

---

# 8. MOUNTING A NAMED VOLUME

## 8.1 The --mount Option

Docker supports the `--mount` option during container creation.

A named volume can be attached using:

```text
--mount type=volume,source=VOLUME_NAME,target=CONTAINER_PATH
```

Example:

```bash
docker run --rm \
  --mount type=volume,source=lecture09-data,target=/data \
  alpine:3.20 ls /data
```

This makes the volume accessible under `/data` in the container.

## 8.2 Source and Target

**Source:** The Docker volume object.

**Target:** The mount location within the container filesystem.

The path used inside the container does not need to resemble the volume's underlying host storage path.

## 8.3 Automatic Volume Creation

If a named volume does not exist, Docker can create it automatically when a suitable mount is requested.

Nevertheless, explicitly creating a named volume is useful for administration and documentation.

## 8.4 Read-Write Behavior

Volumes are ordinarily mounted as read-write unless configured otherwise.

Applications with appropriate permissions can create and modify files inside the mounted storage.

## 8.5 Volume Persistence

Removing the container does not ordinarily remove a named volume.

A replacement container can mount the same named volume by name.

This is the central persistence mechanism demonstrated in the laboratory.

---

# 9. THE -v OPTION

## 9.1 General Syntax

Docker also provides:

`-v`

Its long form is:

`--volume`

For a named volume:

```text
-v VOLUME_NAME:CONTAINER_PATH
```

Example:

```bash
docker run --rm \
  -v lecture09-data:/data \
  alpine:3.20 ls /data
```

This achieves a result similar to the previous `--mount` example.

## 9.2 Read-Only Syntax

```text
-v VOLUME_NAME:CONTAINER_PATH:ro
```

Example:

```bash
docker run --rm \
  -v lecture09-data:/data:ro \
  alpine:3.20 ls /data
```

The `ro` suffix requests read-only access to the mounted data.

## 9.3 --mount Versus -v

| Characteristic | --mount | -v |
|---|---|---|
| Syntax | Explicit key-value fields | Compact colon-separated fields |
| Named volumes | Supported | Supported |
| Bind mounts | Supported | Supported |
| Read-only options | Supported | Supported |
| Source and target clarity | High | More compact |
| Missing bind source behavior | Normally reports an error | May automatically create a directory |

For instructional and administrative clarity, `--mount` is generally preferable when several mount parameters must be expressed explicitly.

---

# 10. ANONYMOUS VOLUMES

## 10.1 Definition

An anonymous volume is a Docker volume created without an explicitly supplied human-readable name.

Docker assigns it a generated identifier.

## 10.2 Example

```bash
docker run --rm \
  --mount type=volume,target=/data \
  alpine:3.20 ls /data
```

The volume has no user-specified name.

## 10.3 Anonymous Volume Characteristics

Anonymous volumes:

1. Are Docker-managed storage resources.
2. Can exist independently of the container writable layer.
3. Receive generated identifiers.
4. May persist after ordinary container removal.
5. Are more difficult to reattach deliberately without recording their identifiers.
6. May be removed automatically under specific lifecycle or cleanup options.

## 10.4 --rm and Anonymous Volumes

When a container is created with `--rm`, Docker ordinarily removes anonymous volumes associated with that container when the container is automatically removed.

Named volumes are not removed merely because the container used `--rm`.

## 10.5 docker rm -v

The command:

```bash
docker rm -v CONTAINER_NAME
```

removes the selected container and eligible anonymous volumes associated with it.

Explicitly named volumes are not removed by this option merely because they were mounted by that container.

## 10.6 Administrative Recommendation

Named volumes are generally more suitable for important persistent application data because they provide stable identifiers for later reattachment and management.

Anonymous volumes may be appropriate for temporary or automatically managed container storage, but their lifecycle must still be understood.

---

# 11. VOLUMES AND EXISTING IMAGE CONTENT

## 11.1 Mounting Over a Directory

When a volume is mounted at a container filesystem location, the mount becomes visible at that path.

Files that would otherwise be visible beneath the mount point may become obscured.

## 11.2 Non-Empty Volumes

If a non-empty volume is mounted over a directory already containing image files, the existing image files are hidden by the mounted volume's contents.

The underlying image content is not necessarily deleted.

It is simply not visible through that mounted path while the mount is active.

## 11.3 Empty Volume Initialization

Docker ordinarily copies pre-existing image files into a newly mounted empty volume when the destination directory already contains content.

This behavior provides a convenient mechanism for initializing certain data volumes.

## 11.4 Example

Suppose an image contains:

```text
/app/default.txt
```

An empty named volume is mounted at:

`/app`

Docker may populate the empty volume with the existing file.

The mounted volume then contains `default.txt`.

## 11.5 Preventing Automatic Copying

Docker supports the `volume-nocopy` option for applicable volume mounts.

Example:

```text
--mount type=volume,source=mydata,target=/app,volume-nocopy
```

This prevents the ordinary initial copying of destination content into an empty volume.

## 11.6 Importance

Volume initialization behavior can influence application startup.

For example, an application may expect configuration files supplied by its image.

Mounting an empty bind mount or an already populated volume over those files can hide them.

Understanding mount behavior is therefore essential for reliable application configuration.

---

# 12. BIND MOUNTS

## 12.1 Definition

A bind mount makes a selected host filesystem path available at a location inside a container.

Unlike a Docker-managed volume, the source path is explicitly selected from the host filesystem environment.

**Formal definition:**

A bind mount is a filesystem mount that maps an existing path from the Docker daemon host environment into a container's filesystem namespace.

## 12.2 Example

Suppose a development project contains:

```text
project/
└── website/
    └── index.html
```

The developer wants Nginx to serve the local website files without rebuilding the image.

A bind mount can provide access to the directory.

## 12.3 Syntax

```text
--mount type=bind,source=HOST_PATH,target=CONTAINER_PATH
```

Example:

```text
--mount type=bind,source=/home/student/website,target=/usr/share/nginx/html
```

The source must refer to an appropriate existing host path.

## 12.4 Bind Mount Architecture

```text
          HOST FILESYSTEM
                 |
                 v
          /project/website
                 |
                 | Bind Mount
                 v
         NGINX CONTAINER
                 |
                 v
      /usr/share/nginx/html
                 |
                 v
             NGINX
                 |
                 v
           WEB BROWSER
```

The directory content is shared through the mount.

The container does not require an independent copy of every file in its writable layer.

## 12.5 Development Uses

Bind mounts are useful for:

- Editing source code on the host.
- Development web servers.
- Sharing local configuration files.
- Accessing selected host resources.
- Transferring generated files.
- Local development workflows.

## 12.6 Portability Limitations

Bind mounts depend on host filesystem paths.

A path valid on one development computer may not exist on another.

This can reduce deployment portability.

For example, a project depending on:

`/home/student/projects/application`

will not automatically work on every host without adjusting the mount configuration.

---

# 13. BIND MOUNTS VERSUS NAMED VOLUMES

| Characteristic | Named volume | Bind mount |
|---|---|---|
| Source management | Docker-managed | Explicit host path |
| Typical use | Persistent application data | Development files and host integration |
| Stable Docker identifier | Yes | Not as a Docker volume |
| Direct host editing | Less convenient | Usually straightforward |
| Host path dependency | Generally lower | Higher |
| Sharing between containers | Supported | Supported |
| Backup required | Yes, when data is important | Yes, when data is important |
| Read-only mounting | Supported | Supported |
| Portability | Often better | Often host-dependent |
| Permission concerns | Yes | Yes |

## 13.1 Decision Principle

Use a named volume when Docker-managed persistent storage is appropriate.

Use a bind mount when the application must access specific files or directories controlled through the host filesystem.

This distinction is a design recommendation rather than an absolute technical restriction.

---

# 14. READ-ONLY AND READ-WRITE MOUNTS

## 14.1 Read-Write Mounts

A read-write mount allows a container process with suitable permissions to modify mounted content.

For bind mounts, these changes can affect the corresponding host files.

This makes read-write bind mounts useful but potentially dangerous.

## 14.2 Read-Only Mounts

A read-only mount allows reading but prevents ordinary writes through that mount.

Example:

```text
--mount type=bind,source=/project/site,target=/usr/share/nginx/html,readonly
```

The container can read the mounted website content.

It cannot normally modify those files through the read-only mount.

## 14.3 Security Significance

Read-only mounts are useful for:

- Application configuration.
- Static website resources.
- Public certificates.
- Reference datasets.
- Files that should not be modified by the application.

However, read-only mounting is not a complete security boundary by itself.

The overall security of a container still depends on privileges, available capabilities, other mounts, and Docker daemon access.

---

# 15. MISSING BIND MOUNT SOURCES

## 15.1 --mount Behavior

By default, Docker's bind-mount form using `--mount` normally fails if the specified source path does not exist.

This behavior helps administrators identify incorrect paths.

## 15.2 -v Behavior

The `-v` syntax may automatically create a missing host directory.

The automatically created object is a directory, not an arbitrary requested file.

## 15.3 Practical Consequences

Consider an application expecting a specific configuration file.

If the administrator accidentally specifies a nonexistent source path through `-v`, Docker may create a directory instead.

The container can then fail because the mounted resource is not the expected file.

## 15.4 Recommended Practice

For critical configurations:

1. Verify source path existence.
2. Verify source type.
3. Confirm ownership and permissions.
4. Use explicit mount syntax.
5. Inspect the resulting container mounts.

---

# 16. TEMPORARY FILESYSTEM MOUNTS

## 16.1 Definition

A tmpfs mount provides temporary filesystem storage using Linux memory-backed filesystem facilities.

Its contents are not intended for durable persistence.

## 16.2 Example

```bash
docker run --rm \
  --mount type=tmpfs,target=/temporary \
  alpine:3.20 sh -c 'echo temporary > /temporary/test.txt && cat /temporary/test.txt'
```

The example requires a Linux container environment supporting tmpfs mounts.

## 16.3 Characteristics

A tmpfs mount:

- Exists as a runtime mount.
- Provides temporary filesystem storage.
- Is not a named Docker volume.
- Is not designed to preserve application data after the container stops.
- Can consume memory resources.
- May be subject to memory limits.

## 16.4 tmpfs and Memory

Tmpfs is memory-backed storage, but its exact physical memory and swap behavior depends on operating-system configuration.

It should not automatically be interpreted as cryptographically protected memory.

## 16.5 Common Uses

Tmpfs mounts can be useful for:

- Temporary processing files.
- Short-lived application state.
- Runtime scratch data.
- Selected sensitive temporary material.

They are unsuitable for durable database storage.

---

# 17. FILESYSTEM PERMISSIONS AND OWNERSHIP

## 17.1 Fundamental Principle

A mounted filesystem does not eliminate the operating system's access-control requirements.

Applications must still possess appropriate permissions for the files they access.

## 17.2 User Identifiers

Linux filesystem ownership is associated with numeric user and group identifiers.

A process executing as UID 10001 may not be permitted to write to a directory owned by UID 0.

This remains relevant inside containers.

## 17.3 Named Volume Permissions

A named volume mounted into a container may contain files owned by a particular user.

If the application runs with an incompatible identity, write operations may fail.

## 17.4 Bind Mount Permissions

Bind-mounted files retain filesystem ownership and permission characteristics associated with the host environment and applicable mount translation mechanisms.

A container's process identity may therefore lack access to certain host files.

## 17.5 Docker Desktop Considerations

Docker Desktop uses filesystem-sharing mechanisms between desktop host operating systems and the Linux environment used by Docker.

Permission behavior can differ from native Linux bind mounts.

The effective permissions depend on the desktop platform, configuration, and filesystem-sharing implementation.

## 17.6 Safe Administrative Practice

Before changing ownership or permissions:

1. Identify the application process identity.
2. Inspect the mounted directory.
3. Determine the required operations.
4. Apply the minimum necessary permissions.
5. Avoid indiscriminate use of permission mode `777`.

Granting universal read, write, and execute permissions is not an appropriate general solution to filesystem permission failures.

---

# 18. STORAGE PERFORMANCE CONSIDERATIONS

## 18.1 Filesystem I/O

Applications perform filesystem input/output operations such as:

- Reading files.
- Creating files.
- Writing data.
- Updating records.
- Synchronizing storage.
- Deleting content.

The performance of these operations can depend on the selected storage mechanism.

## 18.2 Container Writable Layers

Writable-layer operations may involve additional overlay or snapshotter behavior.

For write-intensive applications, this can introduce considerations absent from certain direct-mounted storage paths.

## 18.3 Named Volumes

Docker-managed volumes are commonly appropriate for persistent application data and databases.

Their performance depends on:

- Filesystem.
- Volume driver.
- Physical storage device.
- Container environment.
- I/O workload.

## 18.4 Bind Mounts

Bind-mount performance may vary by host operating system.

For example, source-code bind mounts on Docker Desktop may involve cross-environment filesystem access.

This can behave differently from native Linux filesystem access.

## 18.5 Engineering Principle

Storage performance should be evaluated using relevant workloads and measurements.

No storage mechanism should be assumed to provide the best performance for every application.

---

# 19. DATABASE PERSISTENCE

## 19.1 Database State

A database stores application information according to a structured data model.

Database systems may maintain state in:

- Memory.
- Transaction logs.
- Data files.
- Snapshot files.
- Index files.
- Other storage structures.

A containerized database may execute correctly while still lacking a durable persistence configuration.

## 19.2 Two Separate Requirements

Persistent database operation generally requires both:

**Application-level persistence**

The database must write the required state into durable files.

**Docker storage persistence**

The filesystem location containing those files must survive the replacement of the database container.

These requirements are distinct.

## 19.3 Important Example

A database configured to store data only in memory will not automatically become durable merely because a Docker volume is mounted.

The application must actually write recoverable data to that mounted location.

Similarly, a database configured to write persistent files may still lose those files when the container is removed if they exist only in the container writable layer.

## 19.4 Correct Model

```text
          DATABASE APPLICATION
                  |
                  v
       DATABASE PERSISTENCE LOGIC
                  |
                  v
          DATA FILES / LOGS
                  |
                  v
             NAMED VOLUME
                  |
                  v
          RECOVERABLE STORAGE
```

The database persistence strategy and Docker storage configuration must work together.

---

# 20. REDIS AS A STORAGE CASE STUDY

## 20.1 Definition

Redis is an in-memory data system commonly used for:

- Caching.
- Key-value storage.
- Queues.
- Counters.
- Session-related data.
- Messaging.
- Supporting application state.

Redis can also write data to disk through supported persistence mechanisms.

## 20.2 Redis Storage Model

Redis maintains operational data in memory.

Depending on configuration, it can generate persistent data files.

Two important mechanisms are:

1. RDB snapshots.
2. Append-only files.

## 20.3 RDB Persistence

RDB persistence creates point-in-time snapshots of a Redis dataset.

These snapshots allow Redis to recover a stored dataset from a previous save point.

The interval and triggering behavior influence potential data loss.

## 20.4 Append-Only File Persistence

Append-only file persistence, abbreviated AOF, records data-changing operations in a form that can be replayed during recovery.

This supports reconstruction of the dataset.

Modern Redis versions use a multi-part AOF mechanism.

## 20.5 Durability Limitations

AOF persistence does not automatically guarantee that every acknowledged write survives every possible failure.

Durability depends on the configured synchronization policy and storage behavior.

For example, an every-second synchronization policy introduces a possible interval of data loss during sudden failure.

## 20.6 Laboratory Configuration

The practical laboratory will use:

```text
appendonly yes
```

and:

```text
dir /data
```

The `/data` path will be backed by a named Docker volume.

The laboratory will also execute an explicit Redis snapshot command to demonstrate application-level persistence.

---

# 21. THE DOCKER VOLUME COMMAND FAMILY

Docker provides dedicated commands for volume management.

| Command | Function |
|---|---|
| `docker volume create` | Create a volume |
| `docker volume ls` | List volumes |
| `docker volume inspect` | Examine volume metadata |
| `docker volume rm` | Remove selected volumes |
| `docker volume prune` | Remove eligible unused local volumes |
| `docker inspect CONTAINER` | Examine mounted storage |
| `docker system df -v` | Examine Docker storage usage |

## 21.1 Volume Creation

```bash
docker volume create lecture09-data
```

## 21.2 Volume Inspection

```bash
docker volume inspect lecture09-data
```

## 21.3 Volume Listing

```bash
docker volume ls
```

## 21.4 Volume Removal

```bash
docker volume rm lecture09-data
```

A volume in use by an existing container ordinarily cannot be removed through the normal volume-removal operation.

## 21.5 Volume Pruning

```bash
docker volume prune
```

On current Docker Engine versions, this normally removes unused anonymous local volumes.

The option:

```bash
docker volume prune --all
```

also makes unused named volumes eligible for removal.

**Critical warning:**

An unused volume is not necessarily an unimportant volume.

A volume containing valuable data may be considered unused simply because no existing container currently references it.

Broad volume pruning must therefore be approached with care.

---

# 22. INSPECTING CONTAINER MOUNTS

## 22.1 Docker Inspect

Mounted storage can be examined using:

```bash
docker inspect CONTAINER_NAME
```

The `Mounts` section contains information about attached storage resources.

## 22.2 Formatted Output

```bash
docker inspect --format '{{json .Mounts}}' CONTAINER_NAME
```

This requests the mount information in JSON form.

## 22.3 Important Mount Fields

| Field | Meaning |
|---|---|
| Type | Mount mechanism, such as volume or bind |
| Name | Docker volume name, when applicable |
| Source | Underlying storage source |
| Destination | Container filesystem mount point |
| Driver | Storage driver, when applicable |
| RW | Whether the mount is writable |
| Propagation | Applicable mount propagation information |

## 22.4 Interpretation

Consider an illustrative mount:

```text
Type:        volume
Name:        lecture09-data
Destination: /data
RW:          true
```

This indicates that the selected named volume is mounted into the container at `/data` with read-write access.

The mount is distinct from the container's ordinary writable layer.

---

# 23. DATA BACKUP AND RECOVERY

## 23.1 Definition of Backup

A backup is an independently maintained copy of information that can be used to restore data after loss, corruption, or other failures.

A backup may include:

- Application data.
- Database snapshots.
- Filesystem archives.
- Configuration files.
- Recovery metadata.

## 23.2 Persistence Versus Backup

Persistence and backup are different concepts.

**Persistence:** Allows the application to retain information across designated lifecycle events.

**Backup:** Maintains recoverable copies of information that can be restored when the primary data is unavailable or damaged.

## 23.3 Example

A Redis database stores files in a named Docker volume.

Removing the Redis container does not automatically remove the named volume.

However, deleting the volume can remove the only available copy of the database files.

If a separate valid backup exists, recovery may still be possible.

## 23.4 Backup Consistency

A filesystem archive is not automatically a consistent database backup.

If a database is modifying several related files during archiving, the resulting archive may capture an inconsistent combination of states.

Possible approaches include:

1. Stopping the database before filesystem backup.
2. Using database-specific backup tools.
3. Creating an application-consistent snapshot.
4. Coordinating writes during backup.
5. Using storage-system snapshot mechanisms with appropriate consistency procedures.

## 23.5 Recovery Objectives

Production backup planning may use two important measures.

**Recovery Point Objective (RPO):**

The maximum acceptable amount of data loss, expressed in time.

**Recovery Time Objective (RTO):**

The target time required to restore an acceptable level of service after a failure.

These objectives guide the selection of backup frequency, persistence mechanisms, and recovery infrastructure.

## 23.6 Important Principle

A backup strategy is incomplete until restoration has been tested.

The existence of an archive does not guarantee that the application can successfully recover from it.

---

# PART II — PRACTICAL LABORATORY 09

# 24. LABORATORY OVERVIEW

## 24.1 Laboratory Title

**Docker Persistent Storage Laboratory: Writable Layers, Named Volumes, Bind Mounts, Redis Persistence, and Data Recovery**

## 24.2 Laboratory Objective

The laboratory will demonstrate:

1. Temporary container filesystem changes.
2. Persistence across ordinary container restart.
3. Data loss after removal and recreation without external storage.
4. Named volume creation.
5. Volume inspection.
6. Redis database persistence.
7. Data recovery following container replacement.
8. Bind-mounted website content.
9. Read-only mount behavior.
10. Anonymous volume behavior.
11. Temporary filesystem mounts.
12. Volume backup.
13. Volume restoration.
14. Controlled resource cleanup.

## 24.3 Requirements

- Docker Engine or Docker Desktop.
- Docker CLI.
- Internet access for obtaining required images.
- A terminal.
- A text editor.
- A web browser.
- A writable working directory.

Required container images:

- `alpine:3.20`
- `nginx:alpine`
- `redis:7-alpine`

The Redis laboratory is intended for local training.

It does not publish the Redis database port to the host.

---

# 25. EXPERIMENT 1 — VERIFY THE DOCKER ENVIRONMENT

Execute:

```bash
docker version
```

Then:

```bash
docker volume ls
```

**Objective:**

Confirm that Docker is functioning and examine the volumes already present.

**Required observations:**

1. Record the Docker version.
2. Record the number of available local volumes.
3. Identify whether any previously created named volumes are present.
4. Explain why unrelated volumes should not be deleted during the laboratory.

---

# 26. EXPERIMENT 2 — CREATE A TEMPORARY CONTAINER FILE

Start an Alpine container:

```bash
docker run -d \
  --name lecture09-layer \
  alpine:3.20 sleep 3600
```

Create a file inside the running container:

```bash
docker exec lecture09-layer sh -c 'printf "Container writable layer\n" > /tmp/storage-note.txt'
```

Read the file:

```bash
docker exec lecture09-layer cat /tmp/storage-note.txt
```

**Expected result:**

```text
Container writable layer
```

**Objective:**

Demonstrate filesystem modification within a conventional container writable layer.

---

# 27. EXPERIMENT 3 — VERIFY RESTART PERSISTENCE

Stop the container:

```bash
docker stop lecture09-layer
```

Start the same container:

```bash
docker start lecture09-layer
```

Read the file again:

```bash
docker exec lecture09-layer cat /tmp/storage-note.txt
```

**Expected result:**

The file remains present.

**Required analysis:**

Explain why the writable layer survives the ordinary stop-and-start operation.

---

# 28. EXPERIMENT 4 — VERIFY DATA LOSS AFTER RECREATION

Stop:

```bash
docker stop lecture09-layer
```

Remove:

```bash
docker rm lecture09-layer
```

Recreate:

```bash
docker run -d \
  --name lecture09-layer \
  alpine:3.20 sleep 3600
```

Check whether the file exists:

```bash
docker exec lecture09-layer sh -c 'if [ -e /tmp/storage-note.txt ]; then echo PRESENT; else echo ABSENT; fi'
```

**Expected result:**

```text
ABSENT
```

**Technical interpretation:**

The new container does not contain the previous container's writable-layer modifications.

Cleanup:

```bash
docker stop lecture09-layer
```

```bash
docker rm lecture09-layer
```

---

# 29. EXPERIMENT 5 — CREATE A NAMED VOLUME

Execute:

```bash
docker volume create lecture09-redis-data
```

Verify:

```bash
docker volume ls
```

Inspect:

```bash
docker volume inspect lecture09-redis-data
```

**Objective:**

Create and examine a Docker-managed persistent storage object.

**Required observations:**

1. Record the volume name.
2. Identify the volume driver.
3. Identify the mountpoint shown by Docker.
4. Explain why the reported mountpoint should not be treated as a universally portable host path.

---

# 30. EXPERIMENT 6 — START REDIS WITH PERSISTENT STORAGE

Execute:

```bash
docker run -d \
  --name lecture09-redis \
  --mount type=volume,source=lecture09-redis-data,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes --dir /data
```

**Objective:**

Create a Redis container using a named volume for its persistent files.

**Technical interpretation:**

The container executes Redis.

Redis is configured to use append-only persistence.

Its configured data directory is `/data`.

Docker mounts the named volume at that directory.

**Expected result:**

The Redis container starts successfully.

Verify:

```bash
docker ps
```

---

# 31. EXPERIMENT 7 — WRITE DATA INTO REDIS

Execute:

```bash
docker exec lecture09-redis redis-cli SET course:lesson "Docker Lecture 09"
```

Expected response:

```text
OK
```

Now:

```bash
docker exec lecture09-redis redis-cli GET course:lesson
```

Expected response:

```text
Docker Lecture 09
```

Add a numeric value:

```bash
docker exec lecture09-redis redis-cli SET course:counter 10
```

Increment it:

```bash
docker exec lecture09-redis redis-cli INCR course:counter
```

Expected result:

```text
11
```

**Objective:**

Demonstrate state changes within a database application.

**Required analysis:**

Explain why the Redis key-value data initially exists within the Redis application rather than being a conventional text file created directly by Docker.

---

# 32. EXPERIMENT 8 — CREATE A REDIS SNAPSHOT

Execute:

```bash
docker exec lecture09-redis redis-cli SAVE
```

**Expected result:**

```text
OK
```

The `SAVE` command requests a synchronous Redis snapshot.

Inspect the data directory:

```bash
docker exec lecture09-redis ls -la /data
```

**Expected observation:**

The data directory contains Redis persistence-related files.

These may include:

- An RDB snapshot.
- An append-only persistence directory and files.

The exact file structure depends on the Redis version and its persistence configuration.

**Required analysis:**

Explain the difference between Redis application-level persistence and the Docker named volume that stores the resulting files.

---

# 33. EXPERIMENT 9 — INSPECT THE REDIS MOUNT

Execute:

```bash
docker inspect --format '{{json .Mounts}}' lecture09-redis
```

**Objective:**

Verify that the correct storage resource is attached.

**Required observations:**

Identify:

1. Mount type.
2. Volume name.
3. Container destination.
4. Read-write status.
5. Storage driver, if reported.

**Expected configuration:**

```text
Type: volume
Name: lecture09-redis-data
Destination: /data
```

---

# 34. EXPERIMENT 10 — TEST CONTAINER REPLACEMENT

Stop Redis:

```bash
docker stop lecture09-redis
```

Remove the container:

```bash
docker rm lecture09-redis
```

Verify that the volume still exists:

```bash
docker volume inspect lecture09-redis-data
```

Now create a replacement container:

```bash
docker run -d \
  --name lecture09-redis \
  --mount type=volume,source=lecture09-redis-data,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes --dir /data
```

Retrieve the original data:

```bash
docker exec lecture09-redis redis-cli GET course:lesson
```

Expected response:

```text
Docker Lecture 09
```

Retrieve the counter:

```bash
docker exec lecture09-redis redis-cli GET course:counter
```

Expected response:

```text
11
```

**Technical interpretation:**

The original Redis container was removed.

The named volume remained available.

The replacement Redis container mounted the same volume and loaded the persisted database state.

**Required analysis:**

Explain why the database state survived the replacement of the container.

---

# 35. EXPERIMENT 11 — CREATE A BIND-MOUNTED WEBSITE

Create a local project directory:

`docker-lecture09`

Inside it, create:

```text
docker-lecture09/
└── website/
    └── index.html
```

Insert the following into `website/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Docker Lecture 09</title>
</head>
<body>
    <h1>Docker Bind Mount Laboratory</h1>
    <p>Website Version 1</p>
</body>
</html>
```

**Objective:**

Prepare host-managed application content that will be shared with an Nginx container.

---

# 36. EXPERIMENT 12 — RUN NGINX WITH A BIND MOUNT

Open a terminal in the `docker-lecture09` project directory.

For a Bash-compatible shell on Linux or macOS:

```bash
docker run -d \
  --name lecture09-site \
  --mount "type=bind,source=$(pwd)/website,target=/usr/share/nginx/html,readonly" \
  -p 127.0.0.1:8199:80 \
  nginx:alpine
```

For PowerShell on Windows with Docker Desktop using Linux containers:

```powershell
docker run -d --name lecture09-site --mount "type=bind,source=$((Resolve-Path ./website).Path),target=/usr/share/nginx/html,readonly" -p 127.0.0.1:8199:80 nginx:alpine
```

**Objective:**

Mount the local website directory into the Nginx container.

Open:

http://127.0.0.1:8199

**Expected result:**

The website displays:

**Website Version 1**

**Technical interpretation:**

Nginx reads the HTML file through the bind mount.

The HTML content remains under the control of the host project directory.

---

# 37. EXPERIMENT 13 — MODIFY THE HOST FILE

Open the local file:

`website/index.html`

Change:

```html
<p>Website Version 1</p>
```

To:

```html
<p>Website Version 2</p>
```

Save the file.

Refresh:

http://127.0.0.1:8199

**Expected result:**

The webpage now displays:

**Website Version 2**

**Objective:**

Demonstrate that changes to the host-managed file become visible through the bind mount without rebuilding the image.

**Required analysis:**

Explain how this behavior differs from copying the HTML file into an image during Dockerfile construction.

---

# 38. EXPERIMENT 14 — VERIFY READ-ONLY MOUNT BEHAVIOR

Inspect the mounts:

```bash
docker inspect --format '{{json .Mounts}}' lecture09-site
```

Identify the bind mount.

Verify that its `RW` field indicates read-only behavior.

Now attempt a write operation from inside the container:

```bash
docker exec lecture09-site sh -c 'echo "Container modification" > /usr/share/nginx/html/index.html'
```

**Expected result:**

The operation fails because the target is mounted read-only.

**Objective:**

Demonstrate that the container is allowed to read the website files without being granted normal write access through that mount.

**Required analysis:**

Explain why this is useful for static application resources.

---

# 39. EXPERIMENT 15 — STOP AND REMOVE THE NGINX CONTAINER

Execute:

```bash
docker stop lecture09-site
```

Then:

```bash
docker rm lecture09-site
```

Inspect the local project directory.

**Expected result:**

The file `website/index.html` remains available on the host.

**Technical interpretation:**

The bind-mounted host directory was not part of the container's writable layer.

Removing the container does not automatically delete the original host directory.

---

# 40. EXPERIMENT 16 — EXAMINE AN ANONYMOUS VOLUME

Execute:

```bash
docker create \
  --name lecture09-anonymous \
  --mount type=volume,target=/example-data \
  alpine:3.20
```

Inspect:

```bash
docker inspect --format '{{json .Mounts}}' lecture09-anonymous
```

**Objective:**

Identify the generated Docker volume associated with a container created without a supplied volume name.

**Expected result:**

The mount information includes a volume with a generated identifier.

Record that identifier.

Remove the container:

```bash
docker rm -v lecture09-anonymous
```

**Expected result:**

Docker removes the container and the eligible anonymous volume created for it.

**Required analysis:**

Explain why an explicitly named volume provides more convenient reattachment and lifecycle management.

---

# 41. EXPERIMENT 17 — INVESTIGATE TMPFS STORAGE

Execute:

```bash
docker run --rm \
  --mount type=tmpfs,target=/temporary \
  alpine:3.20 \
  sh -c 'printf "Temporary data\n" > /temporary/example.txt; cat /temporary/example.txt'
```

**Objective:**

Demonstrate storage through a temporary filesystem mount.

**Expected output:**

```text
Temporary data
```

The container exits and is automatically removed.

The tmpfs contents are not retained as a named persistent storage resource.

**Required analysis:**

Explain why tmpfs is inappropriate for important database records that must survive container replacement.

---

# PART IV — VOLUME BACKUP AND RESTORATION

# 42. BACKUP EXPERIMENT OVERVIEW

The following experiments demonstrate a controlled backup and recovery procedure using Docker-managed volumes.

The backup is performed after the Redis database is stopped.

This avoids copying application files while Redis continues modifying them.

The archive will initially be stored in a second Docker volume.

**Important limitation:** A backup volume located on the same Docker host is not an adequate off-host disaster-recovery strategy.

The exercise demonstrates backup mechanics, not complete production disaster recovery.

---

# 43. EXPERIMENT 18 — PREPARE THE REDIS DATA FOR BACKUP

Execute:

```bash
docker exec lecture09-redis redis-cli SAVE
```

Expected response:

```text
OK
```

Stop Redis:

```bash
docker stop lecture09-redis
```

Remove the stopped container:

```bash
docker rm lecture09-redis
```

The named volume remains available.

**Objective:**

Establish a stable filesystem state for backup.

**Required analysis:**

Explain why the database is stopped before the filesystem archive is created.

---

# 44. EXPERIMENT 19 — CREATE A BACKUP VOLUME

Execute:

```bash
docker volume create lecture09-backup
```

Inspect:

```bash
docker volume inspect lecture09-backup
```

**Objective:**

Create a separate Docker-managed storage resource for the archive.

---

# 45. EXPERIMENT 20 — CREATE A FILESYSTEM ARCHIVE

Execute:

```bash
docker run --rm \
  --mount type=volume,source=lecture09-redis-data,target=/source,readonly \
  --mount type=volume,source=lecture09-backup,target=/backup \
  alpine:3.20 \
  sh -c 'tar -cf /backup/redis-backup.tar -C /source .'
```

**Objective:**

Copy the contents of the Redis data volume into a tar archive stored in the backup volume.

## Technical Explanation

The command creates a temporary Alpine container.

The original Redis volume is mounted read-only at:

`/source`

The backup volume is mounted at:

`/backup`

The `tar` utility creates:

`/backup/redis-backup.tar`

The archive contains the files found inside the source volume.

The temporary container is removed after execution.

## Expected Result

The archive is created successfully.

---

# 46. EXPERIMENT 21 — VERIFY THE BACKUP

Execute:

```bash
docker run --rm \
  --mount type=volume,source=lecture09-backup,target=/backup,readonly \
  alpine:3.20 \
  tar -tf /backup/redis-backup.tar
```

**Objective:**

List the contents of the backup archive.

**Expected result:**

The output identifies Redis persistence-related files and directories.

**Required analysis:**

Explain why verifying that an archive exists is useful but does not independently establish that a database can be successfully recovered.

---

# 47. EXPERIMENT 22 — RESTORE INTO A NEW VOLUME

Create the destination volume:

```bash
docker volume create lecture09-redis-restored
```

Restore the archive:

```bash
docker run --rm \
  --mount type=volume,source=lecture09-backup,target=/backup,readonly \
  --mount type=volume,source=lecture09-redis-restored,target=/restore \
  alpine:3.20 \
  sh -c 'tar -xf /backup/redis-backup.tar -C /restore'
```

**Objective:**

Reconstruct the Redis data files in an independent volume.

**Expected result:**

The archive is extracted successfully.

**Required analysis:**

Explain why restoring into a separate volume preserves the original volume for comparison.

---

# 48. EXPERIMENT 23 — VERIFY DATABASE RECOVERY

Start a Redis container using the restored volume:

```bash
docker run -d \
  --name lecture09-redis-restored \
  --mount type=volume,source=lecture09-redis-restored,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes --dir /data
```

Retrieve the original value:

```bash
docker exec lecture09-redis-restored redis-cli GET course:lesson
```

**Expected result:**

```text
Docker Lecture 09
```

Retrieve the counter:

```bash
docker exec lecture09-redis-restored redis-cli GET course:counter
```

**Expected result:**

```text
11
```

**Objective:**

Demonstrate that the archived data can be restored and loaded by a new Redis container.

**Technical interpretation:**

The recovered database uses:

1. A new container.
2. A new named volume.
3. Restored persistence files.
4. The same compatible Redis application configuration.

This provides practical evidence that the archive contains recoverable application state.

---

# 49. EXPERIMENT 24 — INSPECT THE STORAGE OBJECTS

Execute:

```bash
docker volume ls
```

At this stage, the laboratory should include:

- `lecture09-redis-data`
- `lecture09-backup`
- `lecture09-redis-restored`

Inspect each volume individually.

```bash
docker volume inspect lecture09-redis-data
```

```bash
docker volume inspect lecture09-backup
```

```bash
docker volume inspect lecture09-redis-restored
```

**Required analysis:**

Explain the purpose of each volume and describe its relationship to the database's recovery process.

---

# 50. EXPERIMENT 25 — CONTROLLED CLEANUP

Stop the restored Redis container:

```bash
docker stop lecture09-redis-restored
```

Remove it:

```bash
docker rm lecture09-redis-restored
```

Verify:

```bash
docker ps -a
```

Inspect the remaining volumes:

```bash
docker volume ls
```

The three named laboratory volumes may be retained for future study.

If the laboratory data is no longer required and the student has deliberately decided to discard it, remove the volumes individually:

```bash
docker volume rm lecture09-redis-data
```

```bash
docker volume rm lecture09-backup
```

```bash
docker volume rm lecture09-redis-restored
```

**Critical warning:**

Removing these volumes deletes the associated stored laboratory data.

Do not execute the removal commands if the data must be preserved.

Do not use broad volume pruning to complete this laboratory.

---

# 51. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Operation | Observed result |
|---|---|---|
| 1 | Docker environment inspection | |
| 2 | Container writable-layer file creation | |
| 3 | Restart persistence | |
| 4 | Removal and recreation | |
| 5 | Named volume creation | |
| 6 | Redis persistent container startup | |
| 7 | Redis data operations | |
| 8 | Redis snapshot creation | |
| 9 | Volume mount inspection | |
| 10 | Redis container replacement | |
| 11 | Host website creation | |
| 12 | Nginx bind mount | |
| 13 | Live host-file modification | |
| 14 | Read-only mount verification | |
| 15 | Bind-mounted container removal | |
| 16 | Anonymous volume examination | |
| 17 | tmpfs mount investigation | |
| 18 | Backup preparation | |
| 19 | Backup volume creation | |
| 20 | Archive creation | |
| 21 | Backup archive verification | |
| 22 | Restoration into a new volume | |
| 23 | Redis recovery verification | |
| 24 | Storage object inspection | |
| 25 | Controlled cleanup | |

## Laboratory Conclusion

Prepare a technical conclusion of approximately 250–350 words explaining:

1. The difference between container writable layers and Docker volumes.
2. Why named volumes can survive container removal.
3. How bind mounts expose host-managed files to containers.
4. Why read-only mounts may improve storage safety.
5. Why database-level persistence is necessary in addition to Docker storage.
6. Why a persistent volume is not equivalent to a backup.
7. How the Redis data was recovered from an archive.

---

# PART V — ADVANCED STORAGE CONCEPTS

# 52. VOLUME SHARING BETWEEN CONTAINERS

## 52.1 General Principle

Several containers may mount the same named volume.

This can provide shared access to a filesystem location.

However, safe concurrent access depends on application behavior.

## 52.2 Read-Only Consumers

A common pattern involves one process preparing data and another process reading it.

The reading container can mount the volume in read-only mode.

This can reduce the risk of unwanted modifications.

## 52.3 Concurrent Writers

Multiple containers writing to the same storage location may require:

- File locking.
- Application-level coordination.
- Transaction management.
- Consistency mechanisms.
- Specialized shared-storage systems.

## 52.4 Database Caution

It is generally unsafe to start two independent database server processes against the same ordinary database data directory unless the database explicitly supports that arrangement.

Sharing a volume does not automatically establish database clustering.

---

# 53. VOLUME DRIVERS

## 53.1 Definition

A volume driver is a component responsible for provisioning and managing storage resources made available through Docker's volume interface.

## 53.2 Local Driver

The default local driver commonly provides storage associated with the Docker Engine host.

It is suitable for many development and single-host applications.

## 53.3 Alternative Drivers

Additional volume drivers and supported storage integrations may provide access to:

- Network storage.
- Cloud storage.
- Shared storage resources.
- Specialized storage platforms.

## 53.4 Portability Qualification

A Docker volume name does not automatically identify the same physical data on every Docker host.

A local volume named `application-data` on one machine is ordinarily distinct from a local volume with the same name on another machine.

Migrating application data therefore requires an appropriate backup, restoration, replication, or shared-storage strategy.

---

# 54. DATA PROTECTION AND SECURITY

## 54.1 Filesystem Access

Containers with appropriate access to a mounted storage resource can read or modify its files according to effective permissions.

Mount configuration must therefore be treated as a security-sensitive operation.

## 54.2 Bind Mount Risks

A read-write bind mount can expose selected host files to modification by a container process.

If a sensitive host directory is mounted into an untrusted container, the container may be able to access or alter important host data.

## 54.3 Docker Socket Risk

Mounting the Docker Engine socket into a container can grant extensive control over the Docker environment.

It should not be treated as an ordinary harmless file-sharing operation.

## 54.4 Read-Only Root Filesystems

Docker supports configurations that make the container root filesystem read-only.

Writable volumes or temporary filesystems can then be mounted only where application writes are required.

This can reduce unnecessary filesystem modification opportunities.

## 54.5 Confidential Data

Persistent volumes may contain:

- Password databases.
- Personal information.
- Database credentials.
- Application tokens.
- Private documents.

Such data requires appropriate access control, backup protection, and retention policies.

Persistent storage is not automatically encrypted merely because Docker manages it.

---

# 55. COMMON STORAGE ERRORS

## Error 1 — Data Disappears After Container Recreation

**Possible cause:**

The application stored important files only in the container writable layer.

**Correction:**

Configure persistent storage at the application's actual data directory.

## Error 2 — Volume Exists but Data Is Missing

**Possible causes:**

- Incorrect mount destination.
- Application stores data elsewhere.
- Different volume name used.
- Application persistence disabled.
- Data files not flushed.
- Data format or version incompatibility.

**Correction:**

Inspect the container mounts and verify the application's actual storage configuration.

## Error 3 — Bind Mount Hides Application Files

**Possible cause:**

A host directory is mounted over a directory containing image-supplied files.

**Correction:**

Verify the source directory and intended mount destination.

## Error 4 — Permission Denied

**Possible cause:**

The application process lacks the required ownership or permissions.

**Correction:**

Inspect effective user identity and filesystem permissions.

Apply the minimum required access changes.

## Error 5 — Bind Source Does Not Exist

**Possible cause:**

The source path is incorrect or unavailable.

**Correction:**

Create or correct the intended host path before starting the container.

## Error 6 — Read-Only Filesystem Error

**Possible cause:**

The application attempts to write to a read-only mount.

**Correction:**

Determine whether the application genuinely requires write access.

If not, correct its behavior or write location.

## Error 7 — Volume Cannot Be Removed

**Possible cause:**

The volume remains referenced by an existing container.

**Correction:**

Inspect dependent containers and determine whether their removal is appropriate.

## Error 8 — Backup Cannot Restore the Database

**Possible causes:**

- Archive corruption.
- Inconsistent backup.
- Missing files.
- Incorrect restoration directory.
- Incorrect file ownership.
- Database version incompatibility.

**Correction:**

Validate the backup, storage layout, permissions, and recovery procedure.

---

# 56. COMMON CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1

**A running container's filesystem is automatically permanent.**

Incorrect.

Container writable-layer data is ordinarily deleted when the container is removed.

## Misunderstanding 2

**Stopping a container deletes all its files.**

Incorrect.

The existing container's writable layer normally remains available after stopping.

## Misunderstanding 3

**Removing a container automatically removes named volumes.**

Incorrect.

Named volumes ordinarily remain available after removal of the container.

## Misunderstanding 4

**A Docker volume is identical to a directory inside the image.**

Incorrect.

A volume is a separately managed storage resource mounted into the container.

## Misunderstanding 5

**Bind mounts and named volumes are interchangeable in every respect.**

Incorrect.

They differ in management, portability, source selection, and filesystem integration.

## Misunderstanding 6

**A read-only mount makes the entire container read-only.**

Incorrect.

Read-only configuration applies to the selected mount, not automatically to every filesystem location.

## Misunderstanding 7

**A Docker volume guarantees that a database will preserve its data.**

Incorrect.

The database must use an appropriate persistence mechanism and write to the mounted storage location.

## Misunderstanding 8

**All Docker volumes are automatically backed up.**

Incorrect.

Volumes require an appropriate backup strategy.

## Misunderstanding 9

**A volume is always stored directly in the desktop host's normal filesystem.**

Incorrect.

Docker Desktop commonly stores Docker-managed volume data inside its Linux execution environment.

## Misunderstanding 10

**A named volume exists automatically on every Docker host.**

Incorrect.

Volume identity and physical storage are associated with the configured Docker environment.

## Misunderstanding 11

**Two database containers can safely write to the same data directory merely because they use a shared volume.**

Incorrect.

Application-level concurrency and storage consistency requirements must be satisfied.

## Misunderstanding 12

**Volume pruning is always safe when Docker reports a volume as unused.**

Incorrect.

An unused volume may still contain important data.

## Misunderstanding 13

**tmpfs provides durable storage.**

Incorrect.

Tmpfs is intended for temporary, nonpersistent storage.

## Misunderstanding 14

**Creating a backup archive proves that recovery will succeed.**

Incorrect.

A recovery procedure must be tested.

---

# PART VI — ACADEMIC ASSESSMENT

# 57. PART A — FORMAL DEFINITIONS

Provide technically precise definitions for:

1. Data persistence.
2. Stateful application.
3. Stateless application.
4. Container writable layer.
5. Named volume.
6. Anonymous volume.
7. Bind mount.
8. Mount point.
9. Read-only mount.
10. tmpfs.
11. Volume driver.
12. Application-level persistence.
13. Filesystem backup.
14. Recovery Point Objective.
15. Recovery Time Objective.

---

# 58. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why application data stored exclusively in a container writable layer is at risk during container replacement.

**Question 2.**

Describe the differences between named and anonymous Docker volumes.

**Question 3.**

Explain how Docker volumes decouple data storage from container execution.

**Question 4.**

Distinguish between a volume mount and a bind mount.

**Question 5.**

Explain how a bind mount can make local source-code modifications visible inside a running container.

**Question 6.**

Describe why mounted storage can obscure files provided by the original image.

**Question 7.**

Explain the default behavior when an empty volume is mounted over a directory containing image files.

**Question 8.**

Describe the purpose of `volume-nocopy`.

**Question 9.**

Explain why filesystem ownership remains important when using Docker volumes.

**Question 10.**

Explain why a database may lose its data even when a volume is mounted.

**Question 11.**

Distinguish Redis RDB persistence from append-only file persistence.

**Question 12.**

Explain why volume persistence is not equivalent to backup.

**Question 13.**

Describe why a consistent database backup may require stopping writes or using database-specific facilities.

**Question 14.**

Explain the security implications of mounting a sensitive host directory read-write into a container.

**Question 15.**

Describe how volume pruning can create an unintended data-loss event.

---

# 59. PART C — COMMAND INTERPRETATION

Consider:

```bash
docker volume create application-data
```

Answer:

1. What object is created?
2. Does the command create a container?
3. Can the volume exist without a container?
4. Which command can inspect it?

Consider:

```bash
docker run -d \
  --name database \
  --mount type=volume,source=application-data,target=/data \
  IMAGE
```

Answer:

5. What does `type=volume` specify?
6. What does `source=application-data` identify?
7. What does `target=/data` identify?
8. Does the command automatically guarantee database-level persistence?
9. What happens to the named volume after ordinary container removal?

Consider:

```bash
docker run --rm \
  --mount type=bind,source=/project/site,target=/usr/share/nginx/html,readonly \
  nginx:alpine
```

Answer:

10. What filesystem source is shared?
11. Where is it mounted?
12. Can the container ordinarily modify the mounted files?
13. Does this operation copy the source into a new Docker image?
14. What happens to the original host files after the container is removed?

---

# 60. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Lost Database Records

An organization runs a database inside a Docker container.

The database writes its files into a directory inside the container writable layer.

The container is replaced during a software deployment.

The database records disappear.

Analyze the cause.

Propose a storage architecture that separates database files from the container lifecycle.

## Case Study 2 — Development Website

A developer repeatedly modifies HTML and CSS files.

The developer rebuilds the Docker image after every modification.

Evaluate whether a bind mount may improve this development workflow.

Discuss the advantages and limitations.

## Case Study 3 — Incorrect Mount Destination

A database writes to:

`/var/lib/application/data`

An administrator mounts a named volume at:

`/data`

The application continues writing to its original directory.

After container replacement, the data is lost.

Explain the failure.

Describe how to determine and correct the proper storage location.

## Case Study 4 — Permission Failure

A container runs under UID 10001.

The mounted data directory is not writable by that identity.

The application exits with a permission error.

Investigate the possible causes.

Recommend a solution based on least privilege and filesystem ownership.

## Case Study 5 — Backup Corruption

A database is actively modifying several files while an administrator creates a filesystem archive.

The archive is successfully created but the restored database cannot start.

Explain how an inconsistent backup may arise.

Recommend safer backup procedures.

## Case Study 6 — Unused Volume Removal

A database container is stopped and removed for maintenance.

Its named volume remains on the Docker host.

An administrator performs aggressive volume pruning.

The database data is deleted.

Analyze the operational failure.

Recommend procedures that reduce the risk of accidental deletion.

---

# 61. PRACTICAL ASSESSMENT

The practical assessment evaluates the student's ability to manage application data independently of container lifecycles.

**Total available marks: 100**

| Assessment category | Marks |
|---|---:|
| Theoretical storage knowledge | 15 |
| Volume management | 15 |
| Writable-layer analysis | 10 |
| Redis persistence configuration | 20 |
| Bind mount implementation | 15 |
| Backup and restoration | 15 |
| Technical documentation and analysis | 10 |
| **Total** | **100** |

**Recommended passing score:** 80/100.

The assessment requires both successful execution and a technically accurate explanation of the observed behavior.

---

# 62. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Persistent Data Management in Docker Container Environments

Prepare an academic report of approximately 1,100–1,600 words addressing:

**“Persistent Storage Architecture in Docker: Container Writable Layers, Volumes, Bind Mounts, and Database Recovery.”**

The report must contain:

1. An introduction to application state and persistence.
2. An explanation of container writable layers.
3. A description of Docker-managed volumes.
4. A comparison of named and anonymous volumes.
5. An explanation of bind mounts.
6. A comparison of volumes and bind mounts.
7. An analysis of read-only and read-write storage.
8. A discussion of tmpfs.
9. An explanation of storage permissions.
10. An examination of Redis persistence.
11. A discussion of persistent storage across container replacement.
12. An explanation of volume backup and restoration.
13. A security assessment.
14. An analysis of the laboratory results.
15. A conclusion discussing storage decoupling in containerized systems.

The report should contain at least one storage architecture diagram and appropriate command examples.

---

# 63. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 10, verify that you can independently complete the following tasks.

## Foundational Storage Concepts

- [ ] Define data persistence.
- [ ] Distinguish stateful and stateless applications.
- [ ] Explain container writable layers.
- [ ] Describe data loss after container removal.
- [ ] Explain storage decoupling.

## Docker Volumes

- [ ] Define a Docker volume.
- [ ] Create a named volume.
- [ ] List Docker volumes.
- [ ] Inspect volume metadata.
- [ ] Mount a named volume.
- [ ] Explain anonymous volumes.
- [ ] Distinguish `--mount` and `-v`.
- [ ] Explain volume initialization behavior.
- [ ] Explain `volume-nocopy`.
- [ ] Remove a named volume deliberately.
- [ ] Explain the risks of volume pruning.

## Bind Mounts

- [ ] Define a bind mount.
- [ ] Mount a host directory into a container.
- [ ] Explain source and target paths.
- [ ] Modify host files and observe changes inside a container.
- [ ] Configure a read-only bind mount.
- [ ] Explain host portability limitations.
- [ ] Identify permission-related problems.

## Temporary Storage

- [ ] Define tmpfs.
- [ ] Create a temporary filesystem mount.
- [ ] Explain why tmpfs is not persistent.
- [ ] Distinguish temporary storage from named volumes.

## Application Persistence

- [ ] Start Redis with a named volume.
- [ ] Configure Redis persistence.
- [ ] Create Redis key-value records.
- [ ] Generate an RDB snapshot.
- [ ] Stop and remove the Redis container.
- [ ] Create a replacement Redis container.
- [ ] Verify recovery of existing records.
- [ ] Explain the relationship between Redis persistence and Docker storage.

## Backup and Recovery

- [ ] Create a volume backup archive.
- [ ] Inspect archive contents.
- [ ] Restore into a separate named volume.
- [ ] Start an application using restored data.
- [ ] Verify application-level recovery.
- [ ] Explain the difference between persistence and backup.
- [ ] Explain why off-host backups are necessary for broader disaster recovery.

**Completion standard:**

The student must demonstrate the ability to retain, inspect, back up, and restore application data independently of individual container instances.

The student should also be capable of explaining why the selected storage architecture is appropriate for the application's requirements.

---

# 64. LECTURE SUMMARY

Docker provides several mechanisms for managing application filesystem state.

The container writable layer stores runtime filesystem changes associated with an individual container.

This storage is ordinarily preserved when that container is stopped and restarted.

However, it is normally removed when the container itself is deleted.

Docker volumes provide storage resources whose lifecycle can be managed independently of container instances.

Named volumes offer stable identifiers that make persistent application data easier to reattach and administer.

Anonymous volumes are also Docker-managed storage resources but do not possess user-assigned names.

Bind mounts provide access to explicitly selected host filesystem paths.

They are particularly useful in development environments where source files must remain directly editable on the host.

Read-only mount options can restrict ordinary modification of selected resources.

Temporary filesystem mounts provide nonpersistent storage suited to transient application data.

Persistent database operation requires both an appropriate application persistence mechanism and a storage configuration that retains the resulting files.

The Redis laboratory demonstrates this relationship.

Redis writes recoverable application data to files stored on a named Docker volume.

A replacement Redis container can then mount the same volume and recover the original database state.

The backup laboratory demonstrates how volume data can be archived, restored into a separate volume, and verified through application execution.

A fundamental conclusion is that **persistent storage, data backup, and disaster recovery are related but distinct responsibilities that must be addressed through deliberate system architecture and operational procedures.**

---

# 65. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. *Docker Volumes.*  
https://docs.docker.com/engine/storage/volumes/

[2] Docker Inc. *Docker Bind Mounts.*  
https://docs.docker.com/engine/storage/bind-mounts/

[3] Docker Inc. *Docker tmpfs Mounts.*  
https://docs.docker.com/engine/storage/tmpfs/

[4] Docker Inc. *Docker Volume Command Reference.*  
https://docs.docker.com/reference/cli/docker/volume/

[5] Docker Inc. *Docker Volume Create.*  
https://docs.docker.com/reference/cli/docker/volume/create/

[6] Docker Inc. *Docker Volume Inspect.*  
https://docs.docker.com/reference/cli/docker/volume/inspect/

[7] Docker Inc. *Docker Volume Remove.*  
https://docs.docker.com/reference/cli/docker/volume/rm/

[8] Docker Inc. *Docker Volume Prune.*  
https://docs.docker.com/reference/cli/docker/volume/prune/

[9] Docker Inc. *Docker Container Run.*  
https://docs.docker.com/reference/cli/docker/container/run/

[10] Docker Inc. *Docker Container Inspect.*  
https://docs.docker.com/reference/cli/docker/container/inspect/

[11] Docker Inc. *Prune Unused Docker Objects.*  
https://docs.docker.com/engine/manage-resources/pruning/

[12] Redis. *Redis Persistence.*  
https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

[13] Docker Inc. *Docker Storage Overview.*  
https://docs.docker.com/engine/storage/

[14] Docker Inc. *Docker Compose Volumes.*  
https://docs.docker.com/reference/compose-file/volumes/

## Recommended Reading Sequence

Begin with references [1] and [2] to establish the technical distinctions between Docker-managed volumes and host bind mounts.

Continue with reference [3] to understand temporary filesystem storage.

References [4] through [11] provide command-level details for volume administration and safe resource cleanup.

Reference [12] explains Redis application-level persistence.

References [13] and [14] provide broader storage context and prepare students for storage configuration in multi-container Docker Compose applications.

---

# 66. FINAL LECTURE CONCLUSION

Persistent data management is an essential responsibility in containerized software engineering.

Containers are frequently designed to be replaceable execution environments.

This design provides operational flexibility, but it creates the need to manage important application state independently of the container writable layer.

Docker volumes and bind mounts provide mechanisms for establishing that separation.

Named volumes offer Docker-managed storage that can survive container removal and be attached to replacement containers.

Bind mounts provide direct integration with selected host filesystem paths.

Temporary filesystem mounts offer nonpersistent storage for appropriate transient workloads.

These mechanisms differ in lifecycle, portability, security, and operational management.

Their correct use requires understanding application behavior as well as Docker configuration.

The Redis laboratory demonstrates that application-level data persistence and Docker-managed storage must operate together.

A volume alone does not guarantee durable database state.

The application must write recoverable information to the mounted filesystem.

The subsequent backup-and-restoration exercises establish another essential distinction.

The persistence of a named volume does not guarantee recovery from deletion, corruption, or host failure.

A valid backup strategy must preserve suitable copies of application data and demonstrate that restoration can succeed.

The concepts developed in this lecture provide the foundation for constructing reliable stateful container systems.

They are also prerequisites for multi-container application architectures in which services communicate through Docker networks while retaining important data in independently managed storage resources.

---

**END OF LECTURE 09**

**Next Lecture:** Lecture 10 — Docker Networking Architecture: Bridge Networks, Network Isolation, Container DNS, Service Discovery, and Inter-Container Communication.
