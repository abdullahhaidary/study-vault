# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 04 — DOCKER IMAGES AND IMAGE REGISTRIES: ARCHITECTURE, LAYERS, TAGS, DIGESTS, DISTRIBUTION, AND DOCKER HUB

**Course:** Docker and Containerization Technology  
**Module:** 01 — Fundamental Concepts  
**Lecture:** 04 of 21  
**Academic Level:** Introductory Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 3–4 hours  
**Prerequisites:**

- Lecture 01 — Introduction to Docker and Containerization Technology.
- Lecture 02 — Docker Container Lifecycle and Runtime Operations.
- Lecture 03 — Container Inspection, Filesystem Exploration, and Runtime Diagnostics.
- Basic familiarity with Linux filesystems and command-line interfaces.

---

# 1. LEARNING OBJECTIVES

Upon successful completion of this lecture, the student should be able to:

1. Define a Docker image and explain its function in containerization.
2. Explain the differences between an image, a container, and a Dockerfile.
3. Describe the internal architecture of container images.
4. Explain the principles of layered image filesystems.
5. Describe image immutability and its implications for software deployment.
6. Explain how image layers contribute to storage efficiency.
7. Identify the principal components of an OCI-compatible container image.
8. Distinguish between image manifests, image configurations, and image layers.
9. Interpret Docker image names and registry references.
10. Explain the purpose of image repositories and tags.
11. Distinguish mutable image tags from content-addressable image digests.
12. Describe image identifiers and their relationship to image configuration.
13. Explain Docker image distribution through container registries.
14. Describe the responsibilities of Docker Hub.
15. Distinguish between public and private image repositories.
16. Explain the image pull and push operations.
17. Download and inspect container images using Docker CLI commands.
18. Examine image history and filesystem layers.
19. Create additional image tags.
20. Identify important considerations in image selection, versioning, portability, and security.
21. Explain multi-platform image support at a conceptual level.
22. Remove image references and manage local image storage safely.
23. Complete an image administration laboratory.
24. Evaluate the suitability of images for software development and deployment.

---

# 2. INTRODUCTION TO DOCKER IMAGES

## 2.1 Definition of a Docker Image

A Docker image is a standardized, immutable software package containing the filesystem content and execution configuration required to create a container.

Container images provide the files and metadata necessary for a container runtime to establish an application execution environment.

The filesystem content may include:

- Application executables.
- Programming language runtimes.
- Shared system libraries.
- Framework dependencies.
- Application source code or compiled artifacts.
- Configuration files.
- Static application resources.
- Supporting executables and utilities.

In addition to filesystem contents, an image includes configuration metadata that influences container execution.

This metadata may specify:

- Default executable commands.
- Process arguments.
- Environment variables.
- Working directory.
- Default user.
- Entrypoint configuration.
- Declared application ports.
- Declared volume locations.

**Formal definition:**

A Docker image is an immutable, content-addressable collection of filesystem layers and associated configuration metadata that defines the initial filesystem and execution parameters used to instantiate a container.

The term _content-addressable_ means that important image components can be identified by cryptographic hashes derived from their contents.

## 2.2 Images as Deployment Artifacts

In software engineering, an artifact is a product generated or assembled during a development or build process.

Examples include:

- Executable binaries.
- Compiled libraries.
- Software packages.
- Installation archives.
- Container images.

A Docker image is a deployment artifact because it can be constructed, tested, transferred, and used to instantiate application environments.

This creates a distinction between software development and software execution.

During development, a team produces an image containing the required application environment.

During deployment, the image is distributed to a compatible target system.

At runtime, the target system creates one or more containers from the image.

The workflow can be represented as:

```text
APPLICATION SOURCE CODE
          |
          v
    BUILD PROCESS
          |
          v
     DOCKER IMAGE
          |
          v
     IMAGE REGISTRY
          |
          v
   DEPLOYMENT SYSTEM
          |
          v
   RUNNING CONTAINER
```

This workflow supports the principle of producing a deployable artifact once and reusing that artifact across compatible environments.

## 2.3 Images Versus Containers

Docker images and containers are related but distinct objects.

An image represents packaged application content and default execution configuration.

A container represents an execution instance created from an image.

An image does not require an active process.

A container executes processes within an isolated runtime environment when started.

| Characteristic                        | Docker Image            | Docker Container                           |
| ------------------------------------- | ----------------------- | ------------------------------------------ |
| Primary function                      | Application packaging   | Application execution                      |
| Contains filesystem content           | Yes                     | Uses image filesystem plus runtime changes |
| Contains execution metadata           | Yes                     | Uses image and container configuration     |
| Has a running state                   | No                      | Yes                                        |
| Executes processes                    | No                      | Yes, when running                          |
| Ordinary filesystem modifications     | Immutable image content | Writable container state                   |
| Can create multiple instances         | Yes                     | Represents an individual instance          |
| Can be distributed through a registry | Yes                     | Not directly as a running instance         |
| Exists without execution              | Yes                     | Yes, if created or stopped                 |

## 2.4 Images Versus Dockerfiles

A Dockerfile is a text file containing instructions that define how an image should be built.

A Docker image is the resulting packaged artifact.

A container is a runtime instance created from that image.

The relationship is:

```text
     DOCKERFILE
  Build instructions
          |
          | docker build
          v
      DOCKER IMAGE
   Filesystem + Config
          |
          | docker run
          v
      CONTAINER
    Running process
```

Although Dockerfiles are commonly used to create images, image construction is not conceptually limited to Dockerfiles.

Other tools can produce compatible container images.

The detailed Dockerfile instruction system will be examined in Lecture 05.

---

# 3. THE INTERNAL ARCHITECTURE OF A DOCKER IMAGE

## 3.1 Overview

A Docker image is not simply a compressed folder containing application files.

Modern container images use a structured representation containing filesystem layers, configuration objects, manifests, and content identifiers.

The Open Container Initiative (OCI) defines specifications supporting interoperable container image formats.

At a conceptual level, an OCI-compatible image includes:

1. An image manifest.
2. An image configuration object.
3. One or more filesystem layer descriptors and their referenced content.
4. Optionally, an image index that references multiple image manifests.

These components work together to describe the packaged filesystem and execution environment.

## 3.2 Image Manifest

An image manifest is a structured document that describes the components of a container image.

It contains references to the image's configuration object and filesystem layers.

Each referenced object is represented through a descriptor containing information such as:

- Content digest.
- Content size.
- Media type.

The manifest does not ordinarily contain the application filesystem directly.

Instead, it identifies the objects from which the image is assembled.

**Formal definition:**

An image manifest is a metadata document describing the content-addressed configuration object and ordered filesystem layers associated with a container image.

A simplified conceptual manifest may be represented as:

```json
{
  "schemaVersion": 2,
  "config": {
    "digest": "sha256:CONFIG_HASH"
  },
  "layers": [
    {
      "digest": "sha256:LAYER_1_HASH"
    },
    {
      "digest": "sha256:LAYER_2_HASH"
    }
  ]
}
```

This is a conceptual illustration, not a complete valid OCI manifest. Actual manifests require additional descriptor fields and valid digest values.

## 3.3 Image Configuration

The image configuration is a structured object containing execution settings and information about the image filesystem.

It may contain:

- Default command.
- Entrypoint.
- Environment variables.
- Working directory.
- User identity.
- Exposed port declarations.
- Volume declarations.
- Filesystem layer DiffIDs.
- Image history metadata.

The configuration object influences how a container runtime initializes a container.

However, the runtime can accept additional settings that override some image defaults.

For example, an image may define a default command, while a user may supply an alternative command through `docker run`.

## 3.4 Filesystem Layers

Filesystem layers represent ordered changes to an image filesystem.

Each layer can introduce operations such as:

1. Adding files.
2. Modifying existing files.
3. Marking files for deletion.
4. Creating directories.
5. Changing filesystem metadata.

The layers are combined to produce the final filesystem view used by a container.

The image's filesystem therefore results from applying an ordered sequence of changes rather than necessarily storing each complete filesystem version independently.

## 3.5 Image Architecture Diagram

```text
IMAGE REFERENCE (nginx:alpine) → IMAGE MANIFEST
IMAGE MANIFEST → IMAGE CONFIG
IMAGE MANIFEST → LAYER DESCRIPTORS
LAYER DESCRIPTORS → Layer 1
LAYER DESCRIPTORS → Layer 2
LAYER DESCRIPTORS → Layer 3
IMAGE CONFIG → Runtime Settings
Layers 1, 2, 3 → Root Filesystem
Runtime Settings → CONTAINER
Root Filesystem → CONTAINER
```

This representation separates image configuration from filesystem content.

Both are necessary to describe a runnable application image.

---

# 4. DOCKER IMAGE LAYERS

## 4.1 Definition of an Image Layer

An image layer is a filesystem changeset representing modifications applied relative to preceding filesystem content.

Layers are ordered, and their combined changes establish the resulting image filesystem.

For example, a simplified application image might contain:

**Layer 1:** Base Linux user-space files.

**Layer 2:** Additional system libraries.

**Layer 3:** Programming language dependencies.

**Layer 4:** Application files.

When assembled, these layers provide the filesystem required for application execution.

This example is conceptual. The number and organization of layers depend on how the image was built.

## 4.2 Layered Filesystem Representation

```text
+----------------------------------+
| Layer 4 — Application Files      |
+----------------------------------+
| Layer 3 — Application Libraries  |
+----------------------------------+
| Layer 2 — Runtime Dependencies   |
+----------------------------------+
| Layer 1 — Base Filesystem        |
+----------------------------------+
             |
             v
     FINAL IMAGE FILESYSTEM
```

The ordering of layers is significant.

Later filesystem changes can add to or modify the content established by earlier layers.

## 4.3 Image Immutability

Docker images are immutable in the sense that an existing image's content-addressed objects are not modified in place through ordinary image-management operations.

If a developer wants to change application content, a new image is generally produced.

The existing image content remains unchanged.

For example, consider an image containing an application configuration file.

Changing that configuration in the application's source repository does not modify the already constructed image.

A new build is normally required to incorporate the updated configuration into a new image.

**Important distinction:**

Image immutability does not mean that an image tag can never be changed.

An image's content-addressed objects are immutable, while named tag references may be reassigned to different image content.

## 4.4 Layer Reuse

Image layers can be shared by multiple images.

Consider two applications that use the same underlying runtime environment.

```text
SHARED BASE LAYERS → APP A LAYERS
SHARED BASE LAYERS → APP B LAYERS
APP A LAYERS → IMAGE A
APP B LAYERS → IMAGE B
```

When identical layers are already available, Docker can reuse the associated content rather than storing separate copies of the same layer for each image.

This improves storage efficiency.

It can also reduce unnecessary data transfer when downloading images with shared content.

## 4.5 Layer Deduplication

Deduplication refers to avoiding unnecessary duplicate storage of identical data.

Docker image storage can reuse content-addressed layer objects.

When several images reference the same layer content, the storage system does not necessarily need to maintain an independent full copy for every image.

The resulting storage savings depend on:

- Shared layer content.
- Image format.
- Storage backend.
- Compression.
- Snapshotter implementation.
- Local image-store configuration.

Layer reuse should not be interpreted as a guarantee that all files shared by different images are deduplicated at every possible storage level.

## 4.6 Layers and Container Writable State

When a container starts from an image, Docker normally establishes a writable filesystem state for that container.

The original image content remains unchanged.

```text
RUNNING CONTAINER
[ Container Writable Layer ]
[ Image Layer 4 ]
[ Image Layer 3 ]
[ Image Layer 2 ]
[ Image Layer 1 ]
```

Ordinary application writes affect the container's writable layer or mounted storage.

They do not modify the original source image.

This principle was introduced in Lecture 03 and is fundamental to understanding image reuse.

## 4.7 Filesystem Layers Versus History Entries

An image's build history and its filesystem layers are related but are not necessarily identical collections.

Some image construction operations modify the filesystem and produce filesystem changesets.

Other operations modify image metadata without producing a filesystem layer.

Consequently, the number of history records displayed by `docker history` may differ from the number of filesystem layers reported in the image configuration.

This distinction becomes particularly important when studying Dockerfile instructions.

---

# 5. CONTENT-ADDRESSABLE STORAGE AND CRYPTOGRAPHIC DIGESTS

## 5.1 Content-Addressable Storage

Traditional file systems commonly identify files through filenames and directory paths.

Content-addressable systems instead identify stored objects using values derived from their content.

Container image distribution uses cryptographic digests to identify and verify image-related objects.

A digest changes when the underlying hashed content changes.

This allows software to refer to specific data objects independently of mutable human-readable names.

## 5.2 SHA-256

SHA-256 is a cryptographic hash function that produces a 256-bit digest.

Its output is commonly represented using 64 hexadecimal characters.

In container image references, a digest is often written using the format:

`sha256:<64-hexadecimal-character-value>`

Example format:

```text
sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

The repeated hexadecimal characters in this example are illustrative and do not identify a specific Docker image.

## 5.3 Image Digests

An image may be referenced through a digest rather than through a conventional tag.

Conceptually:

```text
nginx@sha256:<digest>
```

A digest reference identifies specific registry content.

Depending on the reference, the digest may identify an image manifest or a multi-platform image index.

The precise object being referenced is important when analyzing multi-platform images.

## 5.4 Image IDs

Docker also maintains image identifiers.

For OCI-compatible image representations, the image ID commonly corresponds to the digest of the image configuration object.

This is distinct from the digest of the image manifest.

The distinction matters because:

- A configuration object describes runtime settings and filesystem DiffIDs.
- A manifest references the configuration and distributable layer objects.
- A multi-platform index references one or more platform-specific manifests.

These different objects can have different cryptographic digests.

Therefore, an image ID and a repository digest should not automatically be treated as interchangeable identifiers.

## 5.5 Layer Digests and DiffIDs

OCI image formats distinguish between digests used for distributed layer content and digests used to identify uncompressed filesystem changesets.

A layer descriptor in a manifest generally identifies the distributed layer blob through a content digest.

The image configuration contains ordered filesystem layer identifiers commonly called **DiffIDs**.

A DiffID represents the digest of an uncompressed layer changeset.

Because compression changes the bytes being hashed, the digest of a compressed layer blob and the DiffID of its uncompressed content are generally different.

This distinction is important when comparing registry objects with filesystem layer information returned by Docker inspection commands.

## 5.6 Integrity Versus Authenticity

Cryptographic digests help establish content integrity.

Integrity means that content corresponds to the expected hash value.

However, integrity is not identical to authenticity.

A digest alone does not establish that an image originated from a trustworthy publisher.

For example, malicious content can also possess a valid cryptographic digest.

Publisher authenticity may require additional mechanisms such as verified registry identity, digital signatures, provenance information, and organizational trust policies.

This distinction is fundamental to software supply-chain security.

---

# 6. DOCKER IMAGE NAMES AND REFERENCES

## 6.1 Image Reference Structure

Docker uses structured image references to identify repositories and selected image versions.

A common format is:

```text
[REGISTRY_HOST[:PORT]/][NAMESPACE/]REPOSITORY[:TAG]
```

Images may also be referenced by digest.

For example:

```text
REGISTRY/NAMESPACE/REPOSITORY@sha256:DIGEST
```

Each component serves a specific purpose.

## 6.2 Registry Host

The registry host identifies the service responsible for storing or distributing the image.

Examples include:

- Docker Hub.
- A private enterprise registry.
- A cloud-provider registry.
- A self-hosted registry.

When a registry host is omitted from an ordinary Docker image reference, Docker generally defaults to Docker Hub.

The standard Docker Hub registry hostname is:

`docker.io`

## 6.3 Namespace

A namespace identifies a user, organization, or reserved repository grouping within the registry.

For example:

```text
exampleuser/my-application
```

Here:

`exampleuser` represents the namespace.

`my-application` represents the repository.

For Docker Official Images, the reserved namespace `library` is commonly used.

## 6.4 Repository

A repository is a named collection of related image references maintained within a registry.

For example:

```text
nginx
```

is an image repository name.

A repository may contain several image tags.

## 6.5 Tag

A tag is a human-readable reference associated with image content.

Tags are commonly used to distinguish:

- Application releases.
- Runtime versions.
- Operating-system variants.
- Development environments.
- Release channels.

Examples include:

```text
nginx:alpine
python:3.12
redis:7-alpine
```

The exact meaning of a tag is established by the image publisher.

A tag should not automatically be interpreted as a universally standardized version declaration.

## 6.6 Image Reference Examples

| Image reference                    | Interpretation                                   |
| ---------------------------------- | ------------------------------------------------ |
| `nginx`                            | Docker Hub Nginx repository, default tag         |
| `nginx:alpine`                     | Nginx repository, Alpine variant tag             |
| `python:3.12`                      | Python repository, selected tag                  |
| `redis:7-alpine`                   | Redis repository, selected tag                   |
| `exampleuser/web:v1`               | User namespace and application tag               |
| `registry.example.com/team/api:v2` | Explicit registry, namespace, repository, tag    |
| `alpine@sha256:<digest>`           | Alpine reference to content identified by digest |

These examples illustrate the syntax and do not guarantee that every named tag remains available indefinitely.

---

# 7. DOCKER IMAGE TAGGING

## 7.1 Definition of Tagging

Tagging is the operation of associating an image with an additional repository and tag reference.

Docker provides:

`docker tag`

Its equivalent image-management form is:

`docker image tag`

The general syntax is:

```text
docker tag SOURCE_IMAGE TARGET_IMAGE
```

## 7.2 Creating an Additional Tag

Example:

```bash
docker tag nginx:alpine my-nginx:study
```

This operation creates a local reference named:

`my-nginx:study`

The new reference points to the image content associated with `nginx:alpine` at the time of tagging.

It does not rebuild the image.

It also does not automatically duplicate every underlying image layer.

## 7.3 Multiple Tags for One Image

An image may have several references.

For example:

```text
nginx:alpine
       |
       v
    IMAGE ID
       ^
       |
my-nginx:study
```

Both names may refer to the same local image identifier.

This demonstrates that an image name is not the same concept as the image's underlying identity.

## 7.4 Mutable Tags

Image tags are generally mutable references.

A publisher may update a tag so that it points to newer content.

For example, an image repository may initially associate the tag `1.0` with one image.

Later, the publisher may associate the same tag with updated image content.

The tag string remains unchanged, but the referenced content changes.

This behavior may be undesirable when exact reproducibility is required.

## 7.5 The Latest Tag

When an ordinary image reference omits a tag, Docker typically uses the tag:

`latest`

For example:

```bash
docker pull nginx
```

normally refers to:

```text
nginx:latest
```

The tag `latest` is not a special mechanism that analyzes every image version and selects the chronologically newest software release.

It is a conventional tag name controlled by the repository publisher.

Therefore, `latest` should not be interpreted as a universal guarantee of the newest, most stable, or most secure application release.

## 7.6 Versioning Strategies

Different environments may benefit from different image reference strategies.

**Development environment:**

A moving tag may be convenient for evaluating updated software.

**Testing environment:**

A specific version tag can improve consistency.

**Production environment:**

Digest-based references can provide stronger guarantees that deployments use the intended image content.

However, pinning an image to a digest does not automatically provide security updates.

A maintenance process is required to review, validate, and adopt updated images.

---

# 8. TAGS VERSUS DIGESTS

## 8.1 Fundamental Difference

A tag is a human-readable reference that can change.

A digest identifies content by its cryptographic hash.

| Characteristic               | Image Tag                | Image Digest                  |
| ---------------------------- | ------------------------ | ----------------------------- |
| Identification               | Human-readable name      | Content-derived hash          |
| Mutability                   | Generally mutable        | Bound to hashed content       |
| Ease of use                  | High                     | Lower                         |
| Exact content identification | Not guaranteed over time | Yes, for referenced object    |
| Common purpose               | Version selection        | Reproducibility and integrity |
| Example                      | `nginx:alpine`           | `nginx@sha256:<digest>`       |

## 8.2 Why Digest Pinning Matters

Consider two deployment systems.

System A downloads an image using:

```text
example/api:production
```

System B downloads the same reference several days later.

If the publisher has updated the `production` tag, the two systems may receive different image content.

By contrast, a digest reference selects a specific content-addressed object.

This reduces ambiguity in image selection.

## 8.3 Limitations of Digest Pinning

Digest pinning identifies specific content.

It does not establish that the content is secure, updated, or suitable for a particular environment.

It also does not eliminate differences caused by external configuration, runtime settings, networking, mounted data, or hardware.

For a multi-platform image, pinning an image-index digest may still allow the runtime to select different platform-specific manifests on different compatible machines.

Therefore, exact reproducibility may also require control over the selected operating system and processor architecture.

---

# 9. IMAGE REGISTRIES

## 9.1 Definition of a Container Registry

A container registry is a service that stores and distributes container images and associated metadata.

A registry enables images to be transferred between separate systems.

For example, a developer may build an image locally and upload it to a registry.

A deployment server can subsequently retrieve the image.

**Formal definition:**

A container registry is a storage and distribution service implementing interfaces through which clients can upload, retrieve, and manage content-addressed container image manifests, configurations, and layer objects.

## 9.2 Registry Responsibilities

A container registry may provide:

1. Image storage.
2. Image retrieval.
3. Repository organization.
4. Tag management.
5. Authentication.
6. Authorization.
7. Access control.
8. Image metadata.
9. Content distribution.
10. Repository management.

Additional capabilities depend on the particular registry service.

## 9.3 Public Registries

A public registry or public repository allows image content to be retrieved by users according to the service's access policies.

Public registries are useful for distributing open-source software and publicly available application images.

Examples include Docker Hub and other container registries operated by software vendors or cloud providers.

Public availability does not guarantee that an image is trustworthy.

## 9.4 Private Registries and Repositories

Private repositories restrict access to authorized users or systems.

They are commonly used for:

- Proprietary applications.
- Internal development images.
- Enterprise software.
- Controlled deployment artifacts.
- Organization-specific infrastructure.

Private registry access generally requires authentication and authorization.

## 9.5 Registry Architecture

```text
       DEVELOPMENT COMPUTER
                |
                |
        Build or Pull Image
                |
                v
          LOCAL IMAGE STORE
                |
                | docker push
                v
         CONTAINER REGISTRY
                |
                | docker pull
                v
         DEPLOYMENT SERVER
                |
                v
          LOCAL IMAGE STORE
                |
                | docker run
                v
          RUNNING CONTAINER
```

The registry distributes image content.

It does not ordinarily execute the application represented by the image.

Container execution occurs within a compatible container runtime environment.

---

# 10. DOCKER HUB

## 10.1 Definition

Docker Hub is a hosted container image registry and repository-management service operated by Docker.

It enables users and organizations to publish, store, discover, and retrieve container images.

Docker Hub is one of the most widely used sources of publicly available container images.

## 10.2 Principal Features

Docker Hub supports capabilities including:

- Public image repositories.
- Private image repositories.
- Repository namespaces.
- Image tags.
- Image discovery.
- Authentication.
- Access control.
- Image distribution.
- Publisher information.
- Repository documentation.

Some functionality and usage limits depend on the applicable service plan.

## 10.3 Docker Official Images

Docker Official Images are a curated collection of repositories published through Docker's official image program.

Examples include commonly used software such as:

- Alpine Linux.
- Nginx.
- Python.
- Redis.
- PostgreSQL.
- Node.js.

Official Images are maintained through a defined review and publication process.

They provide useful starting points for development and learning.

However, official status does not guarantee the absence of vulnerabilities or remove the need for maintenance.

## 10.4 Verified Publisher Images

Docker Hub also identifies certain publisher repositories through verification programs.

A Verified Publisher designation indicates that Docker has verified the associated publisher under the relevant program.

It should not be interpreted as an absolute guarantee that every published image is secure or appropriate for all applications.

## 10.5 Selecting an Image from Docker Hub

Before using an image, administrators should consider:

1. Publisher identity.
2. Repository documentation.
3. Supported image tags.
4. Software version.
5. Platform compatibility.
6. Maintenance activity.
7. Known vulnerabilities.
8. Image size.
9. Configuration requirements.
10. Licensing and distribution conditions.

Popularity and download counts may be useful contextual information but are not sufficient evidence of image security.

---

# 11. DOWNLOADING DOCKER IMAGES

## 11.1 The Docker Pull Command

Docker provides:

`docker pull`

Its equivalent form is:

`docker image pull`

The general syntax is:

```text
docker pull [OPTIONS] NAME[:TAG|@DIGEST]
```

The purpose of the command is to retrieve a container image from a registry.

## 11.2 Example

```bash
docker pull nginx:alpine
```

This requests the image associated with the `alpine` tag in the Nginx repository.

Docker communicates with the registry and retrieves the image content required for the selected platform.

If relevant content already exists locally, Docker may reuse it.

## 11.3 The Image Pull Process

The general sequence is:

1. The user issues a pull request.
2. Docker resolves the image reference.
3. Docker communicates with the registry.
4. The registry provides the relevant manifest or image index.
5. Docker determines the appropriate image content for the requested platform.
6. Required configuration and layer objects are identified.
7. Missing content is downloaded.
8. Integrity checks are performed using content digests.
9. The image becomes available in the local image store.

The precise internal implementation may differ according to Docker Engine version and image-store configuration.

## 11.4 Pulling by Digest

An image may also be pulled using a valid digest reference.

Example syntax:

```text
docker pull nginx@sha256:<valid-digest>
```

The placeholder must be replaced with a real digest obtained from a trusted source or registry operation.

Digest-based retrieval provides exact identification of the referenced content-addressed object.

## 11.5 Image Download Caching

Docker does not necessarily download all image content every time a pull command is executed.

If required blobs are already present locally, they may be reused.

This reduces unnecessary data transfer and can accelerate repeated image retrieval.

However, a tag-based pull may still contact the registry to resolve the current tag target.

A moving tag may now refer to different content.

---

# 12. LISTING AND EXAMINING LOCAL IMAGES

## 12.1 Local Image Storage

Docker Engine maintains a local store of available image content and references.

The store may contain:

- Images downloaded from registries.
- Images created locally.
- Several tags associated with the same image.
- Content shared among multiple images.

The internal representation depends on the image-store implementation.

## 12.2 The Docker Images Command

Docker provides:

`docker images`

Its equivalent form is:

`docker image ls`

Example:

```bash
docker image ls
```

The command displays locally available images.

Typical columns include:

- REPOSITORY.
- TAG.
- IMAGE ID.
- CREATED.
- SIZE.

Output may differ between Docker versions and storage configurations.

## 12.3 Understanding Image Listings

**REPOSITORY**

The repository name associated with the image reference.

**TAG**

The human-readable tag assigned to the image.

**IMAGE ID**

A shortened representation of the image identifier.

**CREATED**

The creation time recorded in the image metadata.

**SIZE**

The image size reported by Docker.

The exact meaning of reported size may depend on the command, image-store backend, and display format.

## 12.4 Image Size Interpretation

A displayed image size should not automatically be interpreted as the amount of additional physical storage consumed by that image.

Several images may share layers.

Consequently, adding the displayed sizes of all images can overestimate actual unique storage consumption.

Docker provides additional storage accounting through commands such as:

```bash
docker system df
```

More detailed information can be requested using:

```bash
docker system df -v
```

These commands assist in distinguishing overall image references from the storage resources associated with Docker objects.

---

# 13. INSPECTING IMAGE METADATA

## 13.1 The Docker Image Inspect Command

Docker provides:

`docker image inspect`

This command retrieves detailed metadata about one or more images.

Example:

```bash
docker image inspect nginx:alpine
```

The output is typically represented using JSON.

## 13.2 Image Metadata Categories

Image inspection may provide information about:

- Image identifier.
- Repository tags.
- Repository digests.
- Creation timestamp.
- Operating-system type.
- Processor architecture.
- Image configuration.
- Default command.
- Entrypoint.
- Working directory.
- Environment variables.
- Filesystem layer identifiers.
- Image size.

## 13.3 Inspecting the Image Identifier

```bash
docker image inspect --format '{{.Id}}' nginx:alpine
```

This retrieves the image ID.

The returned value commonly uses a SHA-256 identifier.

## 13.4 Inspecting Platform Information

```bash
docker image inspect --format '{{.Os}}/{{.Architecture}}' nginx:alpine
```

This displays the operating-system and architecture values for the inspected image variant.

An illustrative result is:

```text
linux/amd64
```

The actual result depends on the selected platform.

## 13.5 Inspecting Image Configuration

```bash
docker image inspect --format '{{json .Config.Cmd}}' nginx:alpine
```

This retrieves the default command configuration.

Another example:

```bash
docker image inspect --format '{{json .Config.Entrypoint}}' nginx:alpine
```

This retrieves entrypoint configuration.

The precise values depend on the image.

## 13.6 Inspecting Layer Identifiers

```bash
docker image inspect --format '{{json .RootFS.Layers}}' nginx:alpine
```

This displays the recorded filesystem layer DiffIDs associated with the inspected image configuration.

These should not automatically be confused with compressed layer digests listed in a registry manifest.

## 13.7 Inspecting Repository Digests

```bash
docker image inspect --format '{{json .RepoDigests}}' nginx:alpine
```

This requests repository digest references associated with the local image record.

Locally built images or certain locally tagged references may not contain repository digest information.

The presence and representation of digest references depend on the image source and storage circumstances.

---

# 14. INSPECTING IMAGE HISTORY

## 14.1 The Docker History Command

Docker provides:

`docker history`

Its equivalent form is:

`docker image history`

Example:

```bash
docker history nginx:alpine
```

The command displays image history information.

## 14.2 Image History Metadata

The output may include:

- Creation information.
- Layer or history identifiers.
- Build commands.
- Size information.
- Comments.

History records provide information about how an image was constructed.

They do not necessarily reproduce the original Dockerfile in its exact source form.

## 14.3 Untruncated Output

Docker supports:

```bash
docker history --no-trunc nginx:alpine
```

This displays history information without the command's ordinary truncation of long values.

The resulting output may be substantial.

## 14.4 Practical Uses

Image history inspection can support:

1. Investigation of image construction.
2. Identification of unexpectedly large layers.
3. Comparison of image variants.
4. Understanding build operations.
5. Analysis of optimization opportunities.

However, image history alone is not a complete software security assessment.

It does not establish the trustworthiness of dependencies or guarantee that the image is free from vulnerabilities.

---

# 15. MULTI-PLATFORM CONTAINER IMAGES

## 15.1 Platform Compatibility

Container images may contain compiled executables and libraries that depend on a particular processor architecture.

Common architecture identifiers include:

- `amd64`
- `arm64`

Operating-system compatibility is also significant.

For example:

`linux/amd64`

identifies a Linux image variant intended for the AMD64 architecture.

`linux/arm64`

identifies a Linux image variant intended for the ARM64 architecture.

## 15.2 The Multi-Platform Image Problem

A software publisher may want to distribute an application that runs on multiple hardware architectures.

Providing entirely unrelated image names for every architecture complicates distribution.

Multi-platform images address this problem by allowing one image reference to identify a collection of platform-specific image manifests.

## 15.3 Image Indexes

The OCI image index is a structured document that references other image manifests.

A simplified architecture is:

```text
APPLICATION:1.0 → IMAGE INDEX
IMAGE INDEX → linux/amd64 Manifest
IMAGE INDEX → linux/arm64 Manifest
linux/amd64 Manifest → Config + Layers
linux/arm64 Manifest → Config + Layers
```

When a compatible runtime retrieves the image, it can select the variant corresponding to the requested operating system and architecture.

## 15.4 Multi-Platform Image Selection

For a multi-platform image, Docker generally selects an appropriate platform variant according to the execution environment and any explicitly requested platform settings.

An administrator may request a platform through options such as:

```text
--platform linux/amd64
```

For example:

```bash
docker pull --platform linux/amd64 nginx:alpine
```

The ability to retrieve and execute a selected platform variant depends on the registry content, image-store support, runtime architecture, and any available emulation mechanisms.

Downloading an image variant for a particular architecture does not automatically mean that it can execute natively on every host.

## 15.5 Multi-Platform Compatibility Limitations

Container portability remains subject to technical constraints.

An image containing AMD64 machine instructions cannot generally execute natively on an ARM64 processor.

Emulation may provide compatibility in some environments, but it introduces additional requirements and can affect performance.

Similarly, Linux containers require access to compatible Linux kernel facilities.

Therefore, image portability is conditional on the platform requirements of the packaged software.

---

# 16. DISTRIBUTING IMAGES THROUGH REGISTRIES

## 16.1 The Docker Push Command

The command:

`docker push`

uploads an image to a container registry.

Its equivalent form is:

`docker image push`

General syntax:

```text
docker push NAME[:TAG]
```

The image reference determines the target repository and tag.

## 16.2 Authentication

Registries may require authentication before allowing image uploads or access to private repositories.

Docker provides:

```bash
docker login
```

This establishes authentication using a supported login mechanism.

Credentials should be handled using appropriate secure storage and access policies.

Authentication proves or establishes the identity used to access the registry.

Authorization determines whether that identity is permitted to perform an operation.

These are related but distinct concepts.

## 16.3 Repository Naming

To publish an image to a Docker Hub repository belonging to a user, the local image generally needs an appropriate repository reference.

Example:

```bash
docker tag my-application:1.0 USERNAME/my-application:1.0
```

The placeholder `USERNAME` represents the Docker Hub account namespace.

The tag operation associates the existing local image with a reference suitable for the target repository.

## 16.4 Uploading the Image

Once the registry repository and access permissions are configured, the image may be uploaded.

Example:

```bash
docker push USERNAME/my-application:1.0
```

Docker transfers the required image content and publishes the relevant repository reference.

Content already present in the registry may not need to be uploaded again.

## 16.5 Image Distribution Workflow

```text
         DEVELOPER
             |
             | docker build
             v
         LOCAL IMAGE
             |
             | docker tag
             v
     REGISTRY IMAGE NAME
             |
             | docker push
             v
         DOCKER HUB
             |
             | docker pull
             v
       ANOTHER COMPUTER
             |
             | docker run
             v
       RUNNING CONTAINER
```

This workflow is fundamental to software deployment pipelines.

Image construction will be studied in the following lecture.

---

# 17. IMAGE REMOVAL AND LOCAL STORAGE MANAGEMENT

## 17.1 The Docker Image Remove Command

Docker provides:

`docker image rm`

An equivalent shorthand is:

`docker rmi`

The command removes image references and, when appropriate, associated local image content.

Example:

```bash
docker image rm my-image:study
```

## 17.2 Removing a Tag

When several image tags refer to the same image, removing one tag ordinarily removes only that reference.

Other references may continue pointing to the underlying image.

For example:

```text
nginx:alpine ------+
                   |
                   v
                IMAGE ID
                   ^
                   |
my-nginx:study ----+
```

Removing `my-nginx:study` does not necessarily remove the image content because `nginx:alpine` may still reference it.

## 17.3 Image Usage Conflicts

Docker may prevent image removal when the image is associated with existing containers or otherwise required by the local image store.

An administrator should determine whether the image is still needed before attempting removal.

Forced image removal options exist, but they should not be used without understanding their consequences.

## 17.4 Dangling Images

A dangling image is generally an image object that has no ordinary repository tag reference and is no longer represented through a tagged image reference in the usual way.

Dangling image content can arise during image rebuilding, retagging, or image-management operations.

Dangling images should not automatically be assumed to be useless in every operational context.

## 17.5 The Docker Image Prune Command

Docker provides:

```bash
docker image prune
```

By default, this operation removes dangling images eligible for pruning.

The broader command:

```bash
docker image prune -a
```

can remove unused images more aggressively, including tagged images that are not associated with existing containers.

**Administrative warning:**

Pruning operations can remove useful locally cached image content.

On shared or production systems, image cleanup should be performed only after examining which resources will be affected.

## 17.6 Local Removal Versus Registry Deletion

Removing an image from a local Docker Engine does not delete its corresponding image from Docker Hub or another registry.

Local image management and remote repository management are separate operations.

This distinction is particularly important in deployment environments where an image may be stored in many different locations.

---

# 18. IMAGE ARCHIVING AND OFFLINE TRANSFER

## 18.1 Image Archives

Docker supports exporting image content into an archive suitable for later loading.

This can be useful when:

- Transferring images between isolated environments.
- Maintaining offline development resources.
- Preserving image copies.
- Moving images without direct registry access.

## 18.2 The Docker Image Save Command

Example:

```bash
docker image save -o nginx-image.tar nginx:alpine
```

This saves the selected locally available image content to an archive.

The resulting file contains image data required for later loading, subject to the platform variants and content available locally.

## 18.3 The Docker Image Load Command

Example:

```bash
docker image load -i nginx-image.tar
```

This loads the archived image into the Docker image store.

The operation differs from `docker pull`, which retrieves image content from a registry.

## 18.4 Image Save Versus Container Export

Docker image archiving should not be confused with exporting a container filesystem.

`docker image save` preserves image-related content and metadata for loading as an image.

`docker container export` exports a container's filesystem view without preserving the complete original image metadata and history in the same manner.

These operations serve different purposes.

For normal image distribution, registries or image save/load workflows are generally preferable to treating a container filesystem export as an equivalent image backup.

---

# 19. IMAGE SECURITY AND SOFTWARE SUPPLY-CHAIN CONSIDERATIONS

## 19.1 Software Supply Chain

A software supply chain consists of the components, tools, processes, dependencies, and distribution mechanisms involved in producing and delivering software.

Container images are important software supply-chain artifacts because they may include numerous third-party packages and binaries.

The security of an application image therefore depends partly on the integrity and trustworthiness of its components.

## 19.2 Untrusted Images

Images from untrusted or unknown sources may contain:

- Vulnerable software.
- Malicious executable programs.
- Insecure configuration.
- Unauthorized background processes.
- Embedded credentials.
- Unnecessary privileged utilities.

Executing an image can expose the host or connected systems to risk, particularly when excessive container permissions are granted.

## 19.3 Image Selection Principles

Administrators should:

1. Prefer documented and appropriately maintained images.
2. Verify publisher identity.
3. Review image variants and version tags.
4. Consider known software vulnerabilities.
5. Avoid unnecessary packages.
6. Use appropriate runtime privileges.
7. Review image updates.
8. Prefer reproducible version-selection strategies.
9. Apply organizational approval policies where appropriate.
10. Avoid embedding sensitive credentials into image content.

## 19.4 Image Scanning

Image scanning tools examine image contents and software-package metadata to identify known security vulnerabilities and other risks.

Scanning results depend on:

- Vulnerability databases.
- Available package metadata.
- Scanner capabilities.
- Analysis time.
- Software ecosystem.

A successful scan cannot establish that an image is completely secure.

Conversely, a reported vulnerability must be evaluated in the context of the application's actual use and exposure.

## 19.5 Image Signing and Provenance

Digital signatures and provenance records can provide evidence about image authenticity, origin, and construction.

Modern container supply-chain systems may use technologies such as Sigstore or Notation.

These mechanisms complement digest-based integrity checking.

A digest identifies content.

A signature can provide cryptographic evidence linking content to a signing identity.

Provenance can provide structured evidence about how an artifact was produced.

## 19.6 Security and Image Immutability

Immutable image content can improve traceability.

However, immutability does not make an image automatically secure.

An immutable image can still contain vulnerable or malicious software.

Security requires a continuing process of assessment, updates, testing, and controlled deployment.

---

# 20. IMPORTANT DOCKER IMAGE COMMANDS

The following commands constitute the principal image-management vocabulary of this lecture.

| Command                | Purpose                                             |
| ---------------------- | --------------------------------------------------- |
| `docker images`        | List locally available images                       |
| `docker image ls`      | List images using image subcommand                  |
| `docker pull`          | Download an image from a registry                   |
| `docker image inspect` | Examine image metadata                              |
| `docker history`       | Display image construction history                  |
| `docker tag`           | Create an image tag reference                       |
| `docker rmi`           | Remove an image reference or eligible local content |
| `docker image prune`   | Remove eligible unused image content                |
| `docker login`         | Authenticate with a registry                        |
| `docker logout`        | End a registry login session                        |
| `docker push`          | Upload an image to a registry                       |
| `docker image save`    | Save images to an archive                           |
| `docker image load`    | Load images from an archive                         |
| `docker system df`     | Examine Docker storage usage                        |
| `docker image build`   | Build an image from a build specification           |

## 20.1 Important Command Options

| Option       | Command context        | Purpose                              |
| ------------ | ---------------------- | ------------------------------------ |
| `--digests`  | `docker image ls`      | Display available digest information |
| `--format`   | `docker image inspect` | Select and format metadata           |
| `--no-trunc` | `docker history`       | Avoid truncated history output       |
| `--platform` | `docker pull`          | Request an image platform            |
| `-a`         | `docker image prune`   | Broaden unused-image pruning         |
| `-o`         | `docker image save`    | Select output archive                |
| `-i`         | `docker image load`    | Select input archive                 |

---

# 21. PRACTICAL LABORATORY 04 — IMAGE ACQUISITION, INSPECTION, TAGGING, AND DISTRIBUTION

## 21.1 Laboratory Title

**Investigation of Docker Image Structure, Identifiers, Tags, History, and Registry Operations**

## 21.2 Laboratory Objective

The purpose of this laboratory is to examine Docker image management operations and establish a practical understanding of image architecture and distribution.

The exercises will demonstrate:

1. Image retrieval.
2. Local image listing.
3. Image metadata inspection.
4. Image history examination.
5. Layer identification.
6. Image tagging.
7. Image identity comparison.
8. Image-based container execution.
9. Image archiving.
10. Image loading.
11. Registry reference structure.
12. Controlled image cleanup.

## 21.3 Laboratory Requirements

The laboratory requires:

- A functional Docker installation.
- Docker CLI access.
- Internet connectivity for downloading images.
- Sufficient local disk space.
- A writable working directory.
- Optional Docker Hub account for registry publication exercises.

The principal images used are:

`alpine:3.20`

`nginx:alpine`

`redis:7-alpine`

Image tags identify requested releases or variants. Actual image sizes and digests may vary with architecture and registry updates.

Commands should be executed from the host terminal unless otherwise indicated.

---

## EXPERIMENT 1 — VERIFY DOCKER AVAILABILITY

Execute:

```bash
docker version
```

**Purpose:**

To verify access to the Docker client and Docker Engine.

**Expected result:**

Version information for the client and connected server is displayed.

**Required observation:**

Record the Docker client and server versions.

---

## EXPERIMENT 2 — DOWNLOAD THREE IMAGES

Execute:

```bash
docker pull alpine:3.20
```

Next:

```bash
docker pull nginx:alpine
```

Finally:

```bash
docker pull redis:7-alpine
```

**Purpose:**

To retrieve three container images intended for different application purposes.

**Expected result:**

Docker obtains the required image content from the registry or reuses content already available locally.

**Required observations:**

1. Identify the requested repository names.
2. Identify their tags.
3. Determine whether image content was downloaded.
4. Record any digest information reported.
5. Explain the difference between pulling an image and running a container.

---

## EXPERIMENT 3 — LIST LOCAL IMAGES

Execute:

```bash
docker image ls
```

**Purpose:**

To examine available local image references.

**Expected result:**

The three requested images appear in the local image listing.

Record:

| Repository | Tag | Image ID | Reported size |
| ---------- | --- | -------- | ------------- |
| Alpine     |     |          |               |
| Nginx      |     |          |               |
| Redis      |     |          |               |

**Analysis question:**

Why do images containing different application environments generally report different sizes?

---

## EXPERIMENT 4 — EXAMINE IMAGE DIGEST INFORMATION

Execute:

```bash
docker image ls --digests
```

**Purpose:**

To display digest information where available.

**Required observations:**

1. Identify a repository digest associated with an image.
2. Compare its format with the displayed image identifier.
3. Explain why the image ID and registry digest may differ.
4. Identify the purpose of content-addressable image references.

**Technical note:**

Some local image references may display no repository digest information.

This does not necessarily mean that the corresponding image content is invalid.

---

## EXPERIMENT 5 — INSPECT IMAGE METADATA

Execute:

```bash
docker image inspect alpine:3.20
```

**Purpose:**

To retrieve structured information about the Alpine image.

Now execute:

```bash
docker image inspect --format '{{.Id}}' alpine:3.20
```

Then:

```bash
docker image inspect --format '{{.Os}}/{{.Architecture}}' alpine:3.20
```

Finally:

```bash
docker image inspect --format '{{json .Config.Cmd}}' alpine:3.20
```

**Required observations:**

Record:

- Image identifier.
- Operating system.
- Architecture.
- Default command configuration.

**Analysis question:**

Why does an image contain execution configuration even though it is not a running container?

---

## EXPERIMENT 6 — EXAMINE IMAGE LAYERS

Execute:

```bash
docker image inspect --format '{{json .RootFS.Layers}}' nginx:alpine
```

**Purpose:**

To examine the filesystem layer DiffIDs recorded in the image configuration.

**Expected result:**

Docker displays an array of layer identifiers.

**Required observations:**

1. Record the number of listed filesystem layers.
2. Identify their digest format.
3. Explain why layer order matters.
4. Explain why filesystem layer identifiers may differ from compressed registry layer digests.

---

## EXPERIMENT 7 — EXAMINE IMAGE HISTORY

Execute:

```bash
docker history nginx:alpine
```

Then:

```bash
docker history --no-trunc nginx:alpine
```

**Purpose:**

To inspect image build history information.

**Required observations:**

1. Identify selected construction operations.
2. Examine the reported size information.
3. Determine whether all history records correspond to filesystem-changing operations.
4. Explain why image history can assist with image optimization.

**Analysis question:**

Why is the number of image history records not necessarily identical to the number of filesystem layers?

---

## EXPERIMENT 8 — CREATE A NEW IMAGE TAG

Execute:

```bash
docker tag alpine:3.20 lecture04-alpine:study
```

**Purpose:**

To create a second local reference to the Alpine image.

Verify:

```bash
docker image ls
```

**Expected result:**

Both the original `alpine:3.20` reference and the `lecture04-alpine:study` reference are present.

**Analysis question:**

Did Docker create an entirely new image filesystem by performing the tagging operation?

---

## EXPERIMENT 9 — COMPARE IMAGE IDENTIFIERS

Execute:

```bash
docker image inspect --format '{{.Id}}' alpine:3.20
```

Then:

```bash
docker image inspect --format '{{.Id}}' lecture04-alpine:study
```

**Purpose:**

To establish whether two image references identify the same image content.

**Expected result:**

The identifiers should match.

**Technical interpretation:**

The two references identify the same local image object.

Creating an additional tag does not require constructing a new image.

---

## EXPERIMENT 10 — EXECUTE A CONTAINER FROM THE TAGGED IMAGE

Execute:

```bash
docker run --rm lecture04-alpine:study cat /etc/os-release
```

**Purpose:**

To demonstrate that the newly created image tag can be used to instantiate a container.

**Expected result:**

The command prints operating-system distribution information from inside the temporary container.

The container is automatically removed after execution.

**Analysis question:**

Explain the sequence of operations connecting the image tag, image content, and container execution.

---

## EXPERIMENT 11 — ARCHIVE THE IMAGE

Execute:

```bash
docker image save -o lecture04-alpine.tar lecture04-alpine:study
```

**Purpose:**

To export image content to a local archive.

**Expected result:**

An archive named `lecture04-alpine.tar` is created in the current working directory.

**Required observations:**

1. Confirm the archive exists.
2. Record its approximate size.
3. Explain the purpose of image archiving.
4. Explain how image archiving differs from exporting a container filesystem.

---

## EXPERIMENT 12 — REMOVE THE LABORATORY TAG

Execute:

```bash
docker image rm lecture04-alpine:study
```

**Purpose:**

To remove the additional image tag created for this laboratory.

Verify:

```bash
docker image ls
```

**Expected result:**

The `lecture04-alpine:study` reference is no longer present.

The original `alpine:3.20` reference should remain.

**Technical interpretation:**

Only the additional reference was removed.

The underlying image content remains available through the original reference.

---

## EXPERIMENT 13 — LOAD THE ARCHIVED IMAGE

Execute:

```bash
docker image load -i lecture04-alpine.tar
```

**Purpose:**

To load previously archived image content and references into the Docker image store.

Verify:

```bash
docker image ls
```

**Expected result:**

The saved image reference is restored.

**Analysis question:**

Explain why an image can be transferred through an archive without requiring a registry pull during the loading operation.

---

## EXPERIMENT 14 — EXAMINE IMAGE STORAGE CONSUMPTION

Execute:

```bash
docker system df
```

Then:

```bash
docker system df -v
```

**Purpose:**

To examine Docker's reported storage usage.

**Required observations:**

1. Record reported image storage consumption.
2. Identify available image-related statistics.
3. Explain why adding all displayed image sizes may overestimate physical disk consumption.
4. Explain how shared layers affect storage accounting.

---

## EXPERIMENT 15 — INVESTIGATE DOCKER HUB

Open the following website:

https://hub.docker.com/

Locate the repositories corresponding to:

- Nginx.
- Alpine.
- Redis.

**Required observations:**

For each repository, record:

1. Repository name.
2. Publisher information.
3. Available image tags.
4. Supported architecture information, if provided.
5. Relevant usage documentation.
6. Any visible official or publisher-verification designation.

**Analysis question:**

Why should repository documentation and publisher identity be examined before an image is deployed?

---

## EXPERIMENT 16 — OPTIONAL REGISTRY PUBLICATION

This experiment is optional and requires a Docker Hub account and permission to publish to the selected repository.

Create an appropriate repository in your Docker Hub namespace if required.

Authenticate:

```bash
docker login
```

Tag the local image:

```bash
docker tag alpine:3.20 YOUR_USERNAME/lecture04-alpine:1.0
```

Replace `YOUR_USERNAME` with your Docker Hub namespace.

Publish the image:

```bash
docker push YOUR_USERNAME/lecture04-alpine:1.0
```

**Purpose:**

To demonstrate image publication through a container registry.

**Expected result:**

Docker transfers the image content required by the target registry.

If successful, the image reference becomes available in the configured Docker Hub repository, subject to its visibility and access settings.

**Security and publication note:**

Use a controlled educational repository. Do not publish proprietary source code, sensitive files, credentials, or materials for which you lack distribution rights.

**Analysis question:**

Explain the difference between image tagging, image authentication, and image publication.

---

## EXPERIMENT 17 — FINAL LABORATORY CLEANUP

Remove the local laboratory tag:

```bash
docker image rm lecture04-alpine:study
```

If the optional publication experiment was completed, the additional local user-namespace tag can also be removed when no longer needed.

Do not remove images or containers belonging to unrelated applications.

The archive `lecture04-alpine.tar` can be retained for future reference or deleted using the host operating system's file-management tools.

**Important:**

Do not execute broad pruning commands solely to complete this laboratory.

The objective is to understand controlled image management rather than indiscriminate resource deletion.

---

# 22. LABORATORY OBSERVATION RECORD

Complete the following table.

| Experiment | Principal objective             | Observed result |
| ---------- | ------------------------------- | --------------- |
| 1          | Docker verification             |                 |
| 2          | Image downloads                 |                 |
| 3          | Local image listing             |                 |
| 4          | Digest examination              |                 |
| 5          | Metadata inspection             |                 |
| 6          | Filesystem layer analysis       |                 |
| 7          | Image history analysis          |                 |
| 8          | Additional image tagging        |                 |
| 9          | Image ID comparison             |                 |
| 10         | Image-based container execution |                 |
| 11         | Image archiving                 |                 |
| 12         | Image reference removal         |                 |
| 13         | Image loading                   |                 |
| 14         | Storage examination             |                 |
| 15         | Docker Hub investigation        |                 |
| 16         | Optional image publication      |                 |
| 17         | Controlled cleanup              |                 |

## Laboratory Conclusion

Prepare a written conclusion of approximately 200–300 words addressing:

1. The architectural components of Docker images.
2. The distinction between image references and image identity.
3. The importance of layered filesystems.
4. The use of tags and digests.
5. The role of registries in image distribution.
6. The relationship between image storage and container execution.
7. The significance of controlled image versioning and management.

---

# 23. COMMON ERRORS AND TROUBLESHOOTING

## 23.1 Image Not Found

**Problem:**

Docker cannot locate the requested image reference.

**Possible causes:**

- Incorrect repository name.
- Incorrect tag.
- Unavailable registry.
- Restricted repository access.
- Typographical errors.

**Corrective procedure:**

Verify the repository and tag through the registry documentation.

Confirm network connectivity and authentication when required.

## 23.2 Image Pull Access Denied

**Problem:**

The registry refuses to provide the requested image.

**Possible causes:**

- Private repository.
- Incorrect authentication.
- Missing repository permission.
- Incorrect image name.
- Registry access policy.

**Corrective procedure:**

Verify image availability, repository ownership, and authorization.

## 23.3 Image Push Access Denied

**Problem:**

An image cannot be published to the selected registry namespace.

**Possible causes:**

- Missing authentication.
- Incorrect namespace.
- Insufficient permissions.
- Repository configuration problems.

**Corrective procedure:**

Verify the authenticated account, repository ownership, and publication permissions.

## 23.4 Image Removal Conflict

**Problem:**

Docker refuses to remove an image.

**Possible cause:**

Existing containers or other references still depend on the image.

**Corrective procedure:**

Inspect image references and existing containers before deciding whether cleanup is appropriate.

Do not automatically use forced removal.

## 23.5 Unsupported Platform

**Problem:**

Docker cannot locate or execute a compatible platform variant.

**Possible causes:**

- Missing platform-specific manifest.
- Processor architecture mismatch.
- Unsupported operating-system combination.
- Missing emulation support.

**Corrective procedure:**

Inspect the available image platforms and compare them with the target execution environment.

## 23.6 Missing Digest Information

**Problem:**

A locally tagged or locally built image does not display an expected repository digest.

**Explanation:**

Repository digest metadata may not be available for every local image reference.

Image identifiers and local tags can exist without the same registry-associated digest information.

This behavior should not automatically be interpreted as corruption.

---

# 24. COMMON CONCEPTUAL MISUNDERSTANDINGS

## Misunderstanding 1: A Docker image is a running application.

Incorrect.

An image is a packaged artifact. A running container executes an application.

## Misunderstanding 2: An image is only a compressed directory.

Incomplete.

Modern images contain structured manifests, configuration information, and filesystem layers.

## Misunderstanding 3: Every image layer contains a complete operating system.

Incorrect.

Layers represent filesystem changesets. Their combination establishes the image filesystem.

## Misunderstanding 4: Every Dockerfile instruction creates a filesystem layer.

Incorrect.

Some instructions modify image metadata without producing a filesystem-changing layer.

## Misunderstanding 5: Creating a new image tag duplicates the entire image.

Incorrect.

Tagging associates an additional reference with existing image content.

## Misunderstanding 6: A tag identifies immutable content.

Incorrect.

Tags can generally be reassigned to new content.

## Misunderstanding 7: The latest tag always represents the newest software release.

Incorrect.

The `latest` tag is a publisher-controlled reference.

## Misunderstanding 8: Image IDs and registry digests always match.

Incorrect.

They may identify different OCI objects.

## Misunderstanding 9: A digest guarantees that an image is secure.

Incorrect.

A digest establishes content identity and supports integrity verification, not publisher trustworthiness or vulnerability-free operation.

## Misunderstanding 10: Docker Hub runs every image stored in its repositories.

Incorrect.

Docker Hub primarily stores and distributes image content.

Execution occurs in a compatible runtime environment.

## Misunderstanding 11: Public images are automatically trustworthy.

Incorrect.

Public accessibility is not evidence of security or authenticity.

## Misunderstanding 12: Removing a local image deletes it from the registry.

Incorrect.

Local image removal and remote repository deletion are separate operations.

## Misunderstanding 13: All images of the same name work on every processor architecture.

Incorrect.

Images and their executable components must be compatible with the target platform, or appropriate compatibility mechanisms must be available.

## Misunderstanding 14: The sum of image-list sizes equals actual unique disk usage.

Incorrect.

Image content may be shared between multiple references and images.

## Misunderstanding 15: Image immutability eliminates the need for application updates.

Incorrect.

Image maintenance requires producing and adopting updated content as software dependencies and security requirements change.

---

# 25. IMPORTANT TERMINOLOGY

| Term                        | Academic definition                                                      |
| --------------------------- | ------------------------------------------------------------------------ |
| Docker image                | Immutable packaged filesystem and execution configuration                |
| Image layer                 | Ordered filesystem changeset within an image                             |
| Image manifest              | Document referencing image configuration and layers                      |
| Image configuration         | Object defining runtime settings and filesystem metadata                 |
| Image index                 | Document referencing multiple image manifests                            |
| OCI                         | Open Container Initiative                                                |
| Image ID                    | Content-derived identifier commonly based on image configuration         |
| Digest                      | Cryptographic hash identifying content                                   |
| DiffID                      | Digest of an uncompressed layer changeset                                |
| SHA-256                     | Cryptographic hashing algorithm producing a 256-bit digest               |
| Repository                  | Named collection of image references                                     |
| Image tag                   | Human-readable reference associated with image content                   |
| Registry                    | Service for storing and distributing container images                    |
| Docker Hub                  | Docker-operated hosted image registry service                            |
| Docker Official Image       | Curated repository published through Docker's Official Images program    |
| Image pull                  | Download of an image from a registry                                     |
| Image push                  | Upload of an image to a registry                                         |
| Image tagging               | Assignment of an additional image reference                              |
| Image inspection            | Examination of image metadata                                            |
| Image history               | Metadata describing image construction operations                        |
| Image immutability          | Property that image content is not modified in place                     |
| Content-addressable storage | Storage model using content-derived identifiers                          |
| Layer deduplication         | Reuse of identical layer content                                         |
| Base image                  | Image used as the starting point for another image                       |
| Multi-platform image        | Image reference supporting multiple platform-specific variants           |
| Authentication              | Process of establishing identity                                         |
| Authorization               | Determination of permitted operations                                    |
| Image archive               | File containing image content suitable for loading                       |
| Software supply chain       | Processes and components involved in producing and distributing software |
| Image provenance            | Evidence describing image origin and production                          |
| Image scanning              | Analysis of image contents for vulnerabilities or other risks            |

---

# 26. ACADEMIC ASSESSMENT

## Part A — Formal Definitions

Provide technically precise definitions for:

1. Docker image.
2. Image manifest.
3. Image configuration.
4. Filesystem layer.
5. Image immutability.
6. Content-addressable storage.
7. Image digest.
8. Image ID.
9. Image repository.
10. Image tag.
11. Container registry.
12. Docker Hub.
13. Image index.
14. Multi-platform image.
15. Software supply chain.

## Part B — Short-Answer Questions

**Question 1.**

Explain the fundamental differences between a Docker image, a Docker container, and a Dockerfile.

**Question 2.**

Describe why modern container images are structured into filesystem layers.

**Question 3.**

Explain how layer reuse contributes to storage efficiency.

**Question 4.**

Describe the responsibilities of an image manifest.

**Question 5.**

Explain the distinction between image configuration and image filesystem content.

**Question 6.**

Describe the relationship between an image identifier and the image configuration object.

**Question 7.**

Explain why an image tag may identify different content at different times.

**Question 8.**

Describe why digest-based references improve deployment reproducibility.

**Question 9.**

Explain why digest identification does not guarantee publisher authenticity.

**Question 10.**

Describe the functions of Docker Hub in image distribution.

**Question 11.**

Explain the difference between public and private image repositories.

**Question 12.**

Describe the principal operations performed during an image pull.

**Question 13.**

Explain the difference between `docker tag` and `docker push`.

**Question 14.**

Describe why image history records and filesystem layers may have different counts.

**Question 15.**

Explain how multi-platform image references support different processor architectures.

---

# 27. COMMAND INTERPRETATION ASSESSMENT

Analyze the following command:

```bash
docker pull nginx:alpine
```

Answer:

1. Which operation is performed?
2. What is the repository?
3. What is the tag?
4. Which registry is normally selected?
5. Does the command start a container?
6. Can locally available image content be reused?

Analyze:

```bash
docker tag nginx:alpine exampleuser/nginx-study:v1
```

Answer:

7. What is the source reference?
8. What is the target reference?
9. Does the command construct a new filesystem?
10. Is the image automatically uploaded?
11. What additional command would publish the image?

Analyze:

```bash
docker image inspect --format '{{.Id}}' nginx:alpine
```

Answer:

12. What metadata field is requested?
13. Why is the identifier useful?
14. Is this identifier necessarily identical to the registry manifest digest?

Finally, analyze:

```bash
docker image rm exampleuser/nginx-study:v1
```

Answer:

15. What operation is requested?
16. Does this command necessarily delete all underlying image content?
17. Does it delete the corresponding image from Docker Hub?

---

# 28. ANALYTICAL AND CASE-STUDY QUESTIONS

## Case Study 1 — Mutable Image Tags

An organization deploys its production application using the reference:

`company/application:production`

Two servers retrieve this reference on different dates.

The application behaves differently on the two servers.

Investigate how mutable tags may contribute to this situation.

Discuss the advantages and limitations of adopting digest-based image references.

## Case Study 2 — Image Storage Efficiency

A development workstation contains ten application images.

Eight of these images share a common base image.

Explain how layered image storage may reduce redundant disk consumption.

Discuss why the displayed size of individual images cannot simply be added to calculate unique storage consumption.

## Case Study 3 — Image Security

A developer discovers an unofficial public image that claims to contain an optimized version of a popular database.

The repository documentation is incomplete, and the publisher's identity cannot be established confidently.

Evaluate the risks of using the image.

Recommend a technically justified image-selection process.

## Case Study 4 — Multi-Platform Deployment

An organization develops an application on an AMD64 workstation.

The application must also execute on ARM64-based systems.

Explain the problems that may arise when transferring a single architecture-specific image.

Discuss the role of multi-platform image indexes and compatible executable builds.

## Case Study 5 — Image Distribution

A developer creates a local image and successfully executes it.

Another developer attempts to retrieve the image using `docker pull`, but the image is unavailable.

Explain why local image creation does not automatically make the image accessible through a registry.

Describe the necessary tagging, authentication, authorization, and publication operations.

---

# 29. INDEPENDENT STUDY ASSIGNMENT

**Assignment Title:** Docker Image Architecture and Distribution

Prepare an academic report of approximately 800–1,200 words addressing:

**“Docker Container Images: Layered Architecture, Content Identification, Versioning, and Registry-Based Distribution.”**

The report must contain:

1. An introduction defining Docker images.
2. A comparison of images, containers, and Dockerfiles.
3. A technical explanation of image manifests and configuration objects.
4. A description of layered image filesystems.
5. An explanation of image immutability.
6. A discussion of image identifiers, tags, and digests.
7. An examination of Docker Hub and container registries.
8. An explanation of image pull and push operations.
9. A discussion of multi-platform images.
10. An assessment of image security and software supply-chain risks.
11. A conclusion discussing why standardized container images are important to modern software engineering.

The report should contain at least one architectural diagram and several command examples.

---

# 30. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 05, the student should be able to complete the following tasks independently.

- [ ] Define a Docker image accurately.
- [ ] Distinguish images from containers.
- [ ] Explain the purpose of image manifests.
- [ ] Describe image configuration metadata.
- [ ] Explain the layered filesystem model.
- [ ] Explain image immutability.
- [ ] Describe layer reuse and deduplication.
- [ ] Explain content-addressable storage.
- [ ] Distinguish image IDs from registry digests.
- [ ] Explain tags and tag mutability.
- [ ] Describe the purpose of the `latest` tag.
- [ ] Interpret standard image reference syntax.
- [ ] Identify a registry, namespace, repository, and tag.
- [ ] Pull an image from a registry.
- [ ] List locally available images.
- [ ] Inspect image metadata.
- [ ] Examine image history.
- [ ] Identify filesystem layer DiffIDs.
- [ ] Create an additional image tag.
- [ ] Verify that two tags identify the same image.
- [ ] Execute a container using a locally tagged image.
- [ ] Save an image to an archive.
- [ ] Load an image from an archive.
- [ ] Examine local image storage usage.
- [ ] Explain the image push workflow.
- [ ] Explain multi-platform image selection.
- [ ] Remove a laboratory image tag safely.
- [ ] Describe basic image trust and security considerations.

**Completion standard:**

The student must demonstrate an understanding of both the image-management commands and the architectural principles that explain their operation.

Successful command execution without conceptual understanding is not sufficient.

---

# 31. LECTURE SUMMARY

Docker images provide the standardized packaging mechanism used to instantiate containerized applications.

An image consists of structured filesystem content and execution metadata rather than an active application process.

Modern OCI-compatible image formats include manifests, configuration objects, filesystem layers, and optional image indexes.

Filesystem layers represent ordered changesets that collectively establish the image filesystem.

Layer reuse supports efficient storage and distribution, while image immutability promotes reproducible application packaging.

Docker images use several forms of identification.

Image tags provide convenient human-readable references, but they are generally mutable.

Cryptographic digests support exact identification of content-addressed objects.

Image identifiers and registry digests must be distinguished because they may reference different objects within the image representation.

Container registries, including Docker Hub, enable the storage and distribution of images across development and deployment environments.

The commands `docker pull`, `docker push`, `docker tag`, `docker image inspect`, and `docker history` provide essential image-management functionality.

Additional commands support local image listing, archiving, loading, removal, and storage inspection.

Multi-platform image indexes allow a single image reference to identify different operating-system and architecture-specific variants.

Image selection must nevertheless account for platform compatibility, publisher trustworthiness, dependency maintenance, and security requirements.

A fundamental conclusion of this lecture is that **Docker images represent reproducible deployment artifacts whose content, metadata, identification, and distribution can be managed independently of their runtime container instances**.

Understanding this distinction is necessary before learning to construct custom images through Dockerfiles.

---

# 32. REFERENCES AND RECOMMENDED READING

## Primary Reference Material

[1] Docker Inc. _What Is an Image?_  
https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/

[2] Docker Inc. _Docker Image Command Reference._  
https://docs.docker.com/reference/cli/docker/image/

[3] Docker Inc. _Docker Image Pull._  
https://docs.docker.com/reference/cli/docker/image/pull/

[4] Docker Inc. _Docker Image List._  
https://docs.docker.com/reference/cli/docker/image/ls/

[5] Docker Inc. _Docker Image Inspect._  
https://docs.docker.com/reference/cli/docker/image/inspect/

[6] Docker Inc. _Docker Image History._  
https://docs.docker.com/reference/cli/docker/image/history/

[7] Docker Inc. _Docker Image Tag._  
https://docs.docker.com/reference/cli/docker/image/tag/

[8] Docker Inc. _Docker Image Push._  
https://docs.docker.com/reference/cli/docker/image/push/

[9] Docker Inc. _Docker Image Remove._  
https://docs.docker.com/reference/cli/docker/image/rm/

[10] Docker Inc. _Docker Image Prune._  
https://docs.docker.com/reference/cli/docker/image/prune/

[11] Docker Inc. _Multi-Platform Builds._  
https://docs.docker.com/build/building/multi-platform/

[12] Docker Inc. _Docker Hub Documentation._  
https://docs.docker.com/docker-hub/

[13] Docker Inc. _Trusted Content on Docker Hub._  
https://docs.docker.com/docker-hub/image-library/trusted-content/

[14] Open Container Initiative. _OCI Image Format Specification._  
https://specs.opencontainers.org/image-spec/

[15] Open Container Initiative. _OCI Image Manifest Specification._  
https://specs.opencontainers.org/image-spec/manifest/

[16] Open Container Initiative. _OCI Image Configuration Specification._  
https://specs.opencontainers.org/image-spec/config/

[17] Docker Inc. _Docker Image Save._  
https://docs.docker.com/reference/cli/docker/image/save/

[18] Docker Inc. _Docker Image Load._  
https://docs.docker.com/reference/cli/docker/image/load/

## Recommended Reading Sequence

Begin with references [1] and [2] to establish the central concepts of image packaging and management.

Study references [3] through [10] to understand the operational commands.

Proceed to references [14], [15], and [16] for a more rigorous understanding of container image structure and content identification.

Reference [11] provides background on platform compatibility and image indexes.

References [12] and [13] examine image registries, distribution, and source trust.

References [17] and [18] explain archive-based image transfer.

---

# 33. FINAL LECTURE CONCLUSION

Docker image technology forms the foundation of the container-based software deployment model.

Images separate the construction and distribution of application environments from the execution of those environments.

This separation enables software teams to produce standardized application artifacts and distribute them through compatible registry infrastructure.

The layered image model provides mechanisms for content reuse and efficient filesystem construction.

The OCI image architecture establishes a structured representation of image manifests, configuration, and filesystem content.

Cryptographic digests provide content-based identification, while repository tags provide convenient naming and version-selection mechanisms.

Understanding the distinction between these forms of identification is essential for reproducible deployment practices.

Docker Hub and other registries provide the infrastructure through which images can be published and retrieved.

The Docker command-line interface provides mechanisms for acquiring images, inspecting their metadata, examining their construction history, creating references, managing local storage, and publishing artifacts.

A technically competent Docker administrator must therefore understand both the internal structure of images and the operational procedures through which images are managed.

A further conclusion concerns security.

Standardized packaging does not automatically establish the trustworthiness of software.

Image provenance, source verification, maintenance, vulnerability assessment, and controlled access remain necessary throughout the software delivery lifecycle.

The concepts developed in this lecture provide the theoretical foundation for creating custom container images using Dockerfiles.

---

**END OF LECTURE 04**

**Next Lecture:** Lecture 05 — Dockerfile Fundamentals: Image Construction, Build Contexts, Dockerfile Instructions, and Building Custom Docker Images.
