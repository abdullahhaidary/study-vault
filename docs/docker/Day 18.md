# DOCKER: FOUNDATIONS AND PRACTICAL APPLICATIONS

## LECTURE 18 — DOCKER REGISTRIES AND IMAGE DISTRIBUTION: IMAGE REFERENCES, DOCKER HUB, AUTHENTICATION, PUSH AND PULL OPERATIONS, DIGEST VERIFICATION, MULTI-PLATFORM DISTRIBUTION, AND SOFTWARE RELEASE MANAGEMENT

**Course:** Docker and Containerization Technology  
**Module:** 03 — Production Engineering, Security, Troubleshooting, and Deployment  
**Lecture:** 18 of 21  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Recommended Study Duration:** 5–7 hours  
**Lecture Type:** Formal Academic Lecture, Image Distribution Laboratory, Release Engineering Assessment, and Independent Study

**Prerequisites:** Lectures 01–17, particularly image layers, image tags, Dockerfiles, BuildKit, Docker security, Docker Compose, and operational diagnostics.

---

# 1. PURPOSE OF THE LECTURE

The construction of a Docker image is only one stage in the software delivery lifecycle.

After an image has been built and tested, it must become available to the environment in which the application will execute.

An application may be developed on one workstation, built in a continuous integration environment, and deployed on several independent servers.

These systems require a reliable mechanism for identifying, storing, transferring, retrieving, and verifying the correct application image.

Docker registries provide the infrastructure supporting this process.

A registry stores container image content and associated metadata so that authorized clients can retrieve and distribute images.

This lecture examines the complete image distribution workflow:

1. Constructing a release artifact.
2. Assigning a repository name.
3. Assigning a version tag.
4. Connecting to a registry.
5. Authenticating where required.
6. Uploading an image.
7. Retrieving the image in another environment.
8. Verifying its content digest.
9. Testing the downloaded artifact.
10. Managing releases and rollback references.

The practical laboratory introduces a local registry that does not require a Docker Hub account.

The student will publish a Python HTTP application into that registry, remove its local image references, retrieve the application from the registry, and verify that the retrieved artifact executes correctly.

An additional optional laboratory introduces Docker Hub publication.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Define a container image registry.
2. Distinguish a registry from a repository.
3. Explain the difference between images and containers.
4. Describe the principal components of an image reference.
5. Identify registry hostname, namespace, repository, tag, and digest.
6. Explain Docker's default registry behavior.
7. Distinguish official images from user-published images.
8. Describe the purpose of Docker Hub.
9. Explain public and private repositories.
10. Define registry authentication.
11. Explain the purpose of `docker login`.
12. Describe Docker credential stores and helpers.
13. Explain the purpose of access tokens.
14. Distinguish authentication from authorization.
15. Describe the principle of least privilege for registry credentials.
16. Explain image tagging.
17. Use `docker image tag`.
18. Explain why tagging does not rebuild an image.
19. Explain the purpose of `docker push`.
20. Describe image layer upload and reuse.
21. Explain the purpose of `docker pull`.
22. Describe the relationship between local image storage and registry storage.
23. Explain why the `latest` tag does not guarantee the newest application release.
24. Describe semantic versioning conventions.
25. Distinguish mutable tags from content digests.
26. Explain content-addressable storage.
27. Describe image manifests and configuration objects.
28. Distinguish image IDs from registry manifest digests.
29. Explain image indexes and multi-platform distribution.
30. Describe Docker's platform selection during image retrieval.
31. Explain why architecture compatibility matters.
32. Use `docker buildx imagetools inspect`.
33. Describe registry TLS requirements.
34. Explain why unauthenticated HTTP registries are unsuitable for production.
35. Construct a local development registry.
36. Configure persistent registry storage.
37. Tag an application image for a local registry.
38. Push and retrieve an image from the registry.
39. Inspect the registry's API.
40. Verify image distribution using an actual digest.
41. Compare multiple application release tags.
42. Demonstrate rollback to a previous image release.
43. Describe registry access-control considerations.
44. Explain image scanning, SBOMs, and provenance.
45. Distinguish `docker save` and `docker load` from registry operations.
46. Describe an appropriate image release process.
47. Diagnose common registry failures.
48. Complete a formal release engineering assessment.

---

# PART I — CONTAINER IMAGE DISTRIBUTION FUNDAMENTALS

# 3. THE SOFTWARE DELIVERY LIFECYCLE

A containerized application passes through several engineering stages before reaching its users.

A simplified model is:

```text
               SOURCE CODE
                    |
                    v
              IMAGE BUILD
                    |
                    v
             AUTOMATED TESTS
                    |
                    v
              RELEASE IMAGE
                    |
                    v
             CONTAINER REGISTRY
                    |
                    v
             DEPLOYMENT SYSTEM
                    |
                    v
              RUNNING SERVICE
```

Each stage has different responsibilities.

The build system creates the artifact.

The test system evaluates its behavior.

The registry distributes the artifact.

The deployment system retrieves and executes the selected artifact.

The important architectural principle is that the same tested image can be distributed to multiple environments without requiring its source code to be rebuilt separately in each environment.

---

# 4. DEFINITION OF A CONTAINER REGISTRY

A container registry is a service that stores and distributes container images and related artifacts.

It provides interfaces for authorized clients to upload and retrieve image content.

A registry may be:

- Public.
- Private.
- Self-hosted.
- Managed by a cloud provider.
- Managed by an organization.
- Used only for development and testing.

Examples of registry systems include:

- Docker Hub.
- Amazon Elastic Container Registry.
- Azure Container Registry.
- Google Artifact Registry.
- GitHub Container Registry.
- Self-hosted OCI-compatible registries.

The existence of a registry does not automatically mean its contents are public.

Visibility and access depend on repository settings and the registry's authorization model.

---

# 5. REGISTRY VERSUS REPOSITORY

These two concepts must be distinguished.

## 5.1 Registry

A registry is the service responsible for storing and distributing image content.

Example:

```text
docker.io
```

## 5.2 Repository

A repository is a logical collection of image versions under a registry-specific name.

Example:

```text
example-user/analytics-api
```

## 5.3 Repository Tags

A repository may contain tags such as:

```text
1.0.0
1.0.1
1.1.0
stable
```

## 5.4 Hierarchical Model

```text
REGISTRY (docker.io) → USER A
REGISTRY (docker.io) → USER B
USER A → API REPO
USER B → WEB REPO
API REPO → 1.0.0
API REPO → 1.1.0
```

A registry contains repositories.

Repositories provide image references through tags and digests.

---

# 6. IMAGE REFERENCES

A Docker image reference commonly follows this general structure:

```text
[REGISTRY[:PORT]/][NAMESPACE/]REPOSITORY[:TAG]
```

Examples:

```text
nginx:alpine
```

```text
docker.io/library/nginx:alpine
```

```text
example-user/analytics-api:1.0.0
```

```text
127.0.0.1:5000/lecture18/api:1.0.0
```

The parts of a reference help Docker identify where to retrieve an image and which version or content to select.

---

# 7. REGISTRY HOSTNAME

Consider:

```text
127.0.0.1:5000/lecture18/api:1.0.0
```

The registry endpoint is:

```text
127.0.0.1:5000
```

The registry stores the requested repository content.

The client communicates with the registry through the configured endpoint.

## Important Networking Qualification

When Docker Engine runs on a remote machine, `127.0.0.1` refers to the loopback environment of that machine.

It does not automatically refer to the computer on which a remote Docker CLI is executed.

This distinction matters when operating a local training registry or a remotely managed Docker daemon.

---

# 8. NAMESPACES AND REPOSITORY NAMES

A namespace is a logical naming scope.

In Docker Hub, a namespace commonly identifies a user account or organization.

For example:

```text
example-user
```

A repository name might be:

```text
lecture18-api
```

The combined Docker Hub reference becomes:

```text
example-user/lecture18-api:1.0.0
```

An account can publish an image only when its credentials and permissions authorize the relevant repository operation.

Naming an image with someone else's namespace does not grant permission to publish there.

---

# 9. IMAGE TAGS

A tag is a human-readable identifier associated with an image repository.

Common tag formats include:

```text
1.0.0
1.0.1
2.0.0
development
staging
stable
```

Tags are convenient because operators can associate an image with a release or deployment channel.

However, tags are not inherently immutable.

A registry may permit an authorized publisher to update a tag so that it identifies different image content.

This behavior is important for release engineering.

---

# 10. THE MEANING OF latest

When a tag is omitted from an ordinary Docker image reference, Docker commonly uses the tag:

```text
latest
```

For example:

```bash
docker pull nginx
```

ordinarily refers to:

```text
nginx:latest
```

However, `latest` is simply a tag name.

It does not automatically mean:

- The most recently built image.
- The newest semantic version.
- The most secure image.
- The most recently published image.
- The image recommended for a particular deployment.

The publisher determines which content the tag identifies.

**Academic conclusion:** The name `latest` should not be treated as a reliable release versioning policy.

---

# 11. SEMANTIC VERSIONING

Semantic Versioning provides a widely used approach to software version identifiers.

A typical version follows:

```text
MAJOR.MINOR.PATCH
```

For example:

```text
2.3.1
```

## 11.1 Major Version

A major version change conventionally indicates an incompatible public API change.

## 11.2 Minor Version

A minor version change conventionally indicates backward-compatible functionality.

## 11.3 Patch Version

A patch version change conventionally indicates a backward-compatible correction.

## 11.4 Important Qualification

A Docker image tag does not automatically enforce Semantic Versioning rules.

Teams must establish and apply their own release policies.

---

# 12. IMAGE TAGGING

The command:

```bash
docker image tag SOURCE_IMAGE TARGET_IMAGE
```

creates an additional image reference.

Example:

```bash
docker image tag lecture18-api:1.0.0 lecture18-api:stable
```

Both references can initially identify the same local image.

## 12.1 Tagging Does Not Rebuild

Assigning another tag does not recompile the application or create a new set of application files.

## 12.2 Important Distinction

A new tag does not automatically mean new image content.

Several tags can refer to identical content.

---

# 13. LOCAL IMAGE STORE

Docker Engine maintains local image content and references.

A local image may be used to create containers without retrieving it from a remote registry when suitable content is already available.

Useful commands include:

```bash
docker image ls
```

```bash
docker image inspect IMAGE
```

```bash
docker history IMAGE
```

## 13.1 Local Availability

Local availability does not necessarily imply that the image has been published to a registry.

## 13.2 Registry Availability

Registry availability does not necessarily imply that the image is already present in the local Docker Engine image store.

These are distinct locations and lifecycles.

---

# 14. CONTENT-ADDRESSABLE STORAGE

Container images use content-addressed identifiers for important image objects.

A content digest is derived from the corresponding content.

The commonly used digest format is:

```text
sha256:<digest-value>
```

## 14.1 General Principle

If the relevant content changes, its content digest ordinarily changes.

## 14.2 Benefit

Content digests support precise identification and integrity verification.

## 14.3 Limitation

A digest proves a relationship to specific content.

It does not establish that the content is safe, authorized, or trustworthy.

---

# 15. IMAGE IDS AND REGISTRY DIGESTS

Several identifiers appear in Docker operations.

They should not be treated as interchangeable.

## 15.1 Local Image ID

The local image ID commonly identifies an image configuration object.

Example:

```text
sha256:<image-configuration-digest>
```

## 15.2 Registry Manifest Digest

A registry digest may identify a manifest or image index.

Example:

```text
repository@sha256:<manifest-digest>
```

## 15.3 Why They Differ

The image configuration and registry manifest are different objects.

Their content digests are therefore not necessarily equal.

## 15.4 Practical Importance

When deploying an image by digest, use the correct registry-resolvable manifest or index digest.

Do not assume that the local image ID is the correct digest for a registry pull.

---

# 16. IMAGE MANIFESTS

An image manifest describes image-related content stored in a registry.

A single-platform image manifest commonly references:

1. The image configuration object.
2. Filesystem layer descriptors.
3. Content digests.
4. Media types.
5. Object sizes.

A simplified representation is:

```text
IMAGE MANIFEST → CONFIGURATION
IMAGE MANIFEST → LAYERS
CONFIGURATION → IMAGE METADATA
LAYERS → FILESYSTEM
```

The manifest allows a client to determine which content objects are needed to retrieve the image.

---

# 17. IMAGE LAYERS DURING DISTRIBUTION

Docker image filesystems commonly consist of multiple layers.

Registries distribute layer content as part of image retrieval and publication.

When pushing an image, the client can avoid uploading certain blobs that the registry already possesses and can reuse.

When pulling an image, the client can reuse suitable locally available content.

This reduces unnecessary data transfer.

## Important Qualification

The exact transfer behavior depends on registry content, manifests, local storage, compression formats, and implementation details.

A second push of an unchanged image may involve much less transfer than the initial push.

---

# 18. IMAGE INDEXES

An image index associates a logical image reference with multiple image manifests.

A common use is multi-platform distribution.

Example:

```text
IMAGE INDEX → linux/amd64
IMAGE INDEX → linux/arm64
linux/amd64 → MANIFEST A
linux/arm64 → MANIFEST B
MANIFEST A → IMAGE FILES
MANIFEST B → IMAGE FILES
```

A compatible registry can store an image index and its associated platform-specific manifests.

---

# 19. MULTI-PLATFORM IMAGE SELECTION

An image may support multiple target platforms.

Examples:

```text
linux/amd64
linux/arm64
linux/arm/v7
```

When an image reference resolves to a multi-platform image index, Docker ordinarily selects an appropriate platform variant for the target environment.

## 19.1 Platform Mismatch

If the requested image does not provide a compatible variant, Docker may report a platform-related error.

## 19.2 Emulation

Some environments support executing non-native architecture binaries through emulation.

However, emulation is not universally available and may introduce performance or compatibility limitations.

## 19.3 Deployment Principle

An image must be compatible with the target operating system and CPU architecture, or the environment must provide a suitable compatibility mechanism.

---

# PART II — REGISTRY SERVICES AND DOCKER HUB

# 20. DOCKER HUB

Docker Hub is a hosted registry and repository management service.

It supports workflows such as:

- Publishing images.
- Retrieving images.
- Managing repositories.
- Managing repository visibility.
- Collaborating within organizations.
- Accessing Docker Official Images.
- Managing registry authentication.

Docker Hub commonly uses the registry domain:

```text
docker.io
```

A reference omitting an explicit registry commonly defaults to Docker Hub.

---

# 21. OFFICIAL IMAGES

Docker Official Images are curated images published through the official-image program.

Examples include:

```text
nginx
```

```text
redis
```

```text
python
```

```text
postgres
```

For example:

```bash
docker pull python:3.12-slim
```

retrieves the selected image reference.

## Important Qualification

Official-image status does not eliminate the need for:

- Version selection.
- Vulnerability evaluation.
- Updates.
- Application compatibility testing.
- Digest and provenance controls where appropriate.

---

# 22. PUBLIC REPOSITORIES

A public repository makes its published image content available for retrieval under the registry's applicable terms and access rules.

Public repositories are useful for:

- Open-source software.
- Public demonstrations.
- General-purpose base images.
- Community distribution.

## Security Implication

Publishing an image publicly may disclose its filesystem contents and embedded metadata.

Private credentials and sensitive organization information must not be included.

---

# 23. PRIVATE REPOSITORIES

A private repository restricts access to authorized accounts or identities.

Private repositories may be used for:

- Proprietary applications.
- Internal services.
- Private organization releases.
- Confidential software distribution.

However, repository privacy does not compensate for insecure image contents.

A private image can still contain vulnerable software or improperly embedded credentials.

---

# 24. AUTHENTICATION

Authentication establishes the identity of a client.

Docker provides:

```bash
docker login
```

for registry authentication.

For Docker Hub, the command may use a browser-based device authorization process.

An explicit username can select a username-based authentication flow.

Example:

```bash
docker login --username YOUR_DOCKER_ID
```

The user supplies the appropriate credential through the supported interactive workflow.

The password or token must not be inserted directly into a public command example.

---

# 25. AUTHENTICATION VERSUS AUTHORIZATION

## 25.1 Authentication

Authentication asks:

**Who is the client?**

## 25.2 Authorization

Authorization asks:

**Which operations may that identity perform?**

A user may be authenticated successfully but lack permission to:

- Push to a particular repository.
- Modify a protected tag.
- Read a private repository.
- Delete an image.
- Manage repository settings.

## 25.3 Diagnostic Significance

An authentication failure and an authorization failure require different corrections.

---

# 26. PERSONAL ACCESS TOKENS

A personal access token, abbreviated PAT, is a credential that can be used in place of an account password in supported authentication workflows.

Depending on the account and service capabilities, tokens may support selected permissions and expiration settings.

## Recommended Practices

- Use the minimum required permissions.
- Use appropriate expiration periods.
- Store tokens in a credential manager.
- Do not commit tokens to source repositories.
- Rotate compromised tokens.
- Revoke tokens that are no longer needed.

For organization automation, appropriately scoped organization or service credentials may be preferable to credentials tied to an individual person.

---

# 27. CREDENTIAL STORAGE

Docker CLI authentication information may be stored through credential helpers or a configured credential store.

Examples include integration with native operating-system credential management facilities.

## 27.1 Security Benefit

A credential helper reduces the need to store reusable secrets directly in a plain configuration file.

## 27.2 Configuration File

Docker client settings commonly reside under:

```text
~/.docker/config.json
```

on Unix-like systems.

## 27.3 Important Qualification

Without a suitable credential store, Docker may store credentials in a less secure representation within the client configuration.

Base64 encoding is not encryption.

---

# 28. NONINTERACTIVE AUTHENTICATION

Automated pipelines may require noninteractive registry authentication.

Docker supports reading a credential from standard input:

```bash
docker login --username USERNAME --password-stdin
```

The credential should be supplied by a secure secret-management facility.

## Important Security Principle

Do not write actual credentials directly into shell command lines.

Command-line arguments, shell history, process inspection, and logs may expose sensitive information.

The appropriate implementation will be explored further in Lecture 20.

---

# 29. DOCKER LOGOUT

Docker provides:

```bash
docker logout
```

for removing locally stored authentication information for the selected registry.

## Important Qualification

Logging out does not delete images already published to the registry.

It also does not revoke an access token at the registry provider.

Token revocation must be performed through the provider's credential management controls.

---

# PART III — IMAGE PUBLICATION AND RETRIEVAL

# 30. THE docker push COMMAND

`docker push` publishes a local image reference to a registry.

General syntax:

```bash
docker push REGISTRY/REPOSITORY:TAG
```

Example:

```bash
docker push 127.0.0.1:5000/lecture18/api:1.0.0
```

The Docker Engine must be able to reach the registry.

The client must have the required authorization where applicable.

The image must also have a reference identifying the intended registry and repository.

---

# 31. THE docker pull COMMAND

`docker pull` retrieves image content from a registry.

Example:

```bash
docker pull 127.0.0.1:5000/lecture18/api:1.0.0
```

Docker resolves the image reference and obtains the required manifest and content objects.

## Important Distinction

Pulling an image does not automatically start a container.

The image becomes available for subsequent container creation.

---

# 32. THE docker run COMMAND

Once an image is available locally or retrievable from a registry, Docker can create a container from it.

Example:

```bash
docker run --rm 127.0.0.1:5000/lecture18/api:1.0.0
```

A real application may require additional runtime configuration.

For this lecture, the application will publish an HTTP port.

The relevant image reference identifies what to run.

Runtime flags determine how the container executes.

---

# 33. IMAGE DISTRIBUTION WORKFLOW

```text
               DEVELOPER
                   |
                   v
             DOCKER BUILD
                   |
                   v
              LOCAL IMAGE
                   |
                   v
              DOCKER TAG
                   |
                   v
              DOCKER PUSH
                   |
                   v
                 REGISTRY
                   |
                   v
              DOCKER PULL
                   |
                   v
             DEPLOYMENT HOST
                   |
                   v
              DOCKER RUN
                   |
                   v
              APPLICATION
```

This workflow is the principal subject of the practical laboratory.

---

# 34. DIGEST-BASED IMAGE REFERENCES

An image can be selected by a repository and digest.

General syntax:

```text
REGISTRY/REPOSITORY@sha256:<actual-digest>
```

For example:

```text
127.0.0.1:5000/lecture18/api@sha256:<actual-digest>
```

The placeholder must be replaced by the actual registry digest.

## 34.1 Benefits

Digest-based selection provides a precise content reference.

## 34.2 Tradeoff

The identifier is less human-readable than a semantic version tag.

A release management system can therefore record both:

- Human-readable release version.
- Exact content digest.

---

# 35. TAGS VERSUS DIGESTS

| Property | Tag | Digest |
|---|---|---|
| Human-readable | Usually yes | Less convenient |
| Identifies a release concept | Often | Through external metadata |
| Can point to changed content | Usually yes | Content identifier is fixed |
| Suitable for release communication | Yes | Yes, with metadata |
| Suitable for exact artifact pinning | Less reliable alone | Yes |
| Automatically proves the image is secure | No | No |

## Engineering Principle

Use meaningful version tags for release management and record exact digests when strict deployment reproducibility is required.

---

# 36. RELEASE IMMUTABILITY

A release process should preserve the relationship between an approved software version and its image content.

For example:

```text
Release 1.0.0
     |
     v
Approved Registry Digest
     |
     v
Deployment Environment
```

Overwriting an existing release tag with different content can create ambiguity.

A deployment configured to use the same tag may retrieve different image content at different times.

A disciplined release process should define whether and how tags may be updated.

---

# 37. IMAGE PROMOTION

Image promotion moves an approved artifact through logical deployment stages.

Example:

```text
BUILD
  |
  v
TEST
  |
  v
STAGING
  |
  v
PRODUCTION
```

## 37.1 Rebuilding at Every Stage

Rebuilding separately in every environment may produce different artifacts.

## 37.2 Promoting an Existing Artifact

Promoting the same tested image digest reduces the possibility of unintentionally changing the software between stages.

## 37.3 Important Qualification

Environment-specific settings may still differ at runtime.

Promoting the same image does not mean every environment has identical databases, networks, secrets, or operational configuration.

---

# 38. ROLLBACK

Rollback is the process of returning a deployment to a previously approved application version.

For example:

```text
Current Release: 1.0.1

Previous Release: 1.0.0
```

The deployment may be changed back to the previous image reference.

## Important Limitations

Application rollback may not restore:

- Database schema.
- Persistent data.
- External service state.
- Changed secrets.
- Infrastructure configuration.

Application release rollback and database recovery are different operations.

---

# PART IV — REGISTRY SECURITY AND OPERATIONS

# 39. REGISTRY TLS

A production registry should use appropriately configured HTTPS transport.

TLS provides important protection for communication between registry clients and the registry server.

Depending on the authentication model, it helps protect:

- Credentials in transit.
- Image transport.
- Server identity.
- Integrity of transferred data.

## Important Qualification

TLS does not establish that every image in the registry is trustworthy.

Artifact provenance and software vulnerability assessment remain separate responsibilities.

---

# 40. UNENCRYPTED HTTP REGISTRIES

An unauthenticated HTTP registry may be acceptable for an isolated local training exercise.

It is not an appropriate default architecture for Internet-facing production distribution.

Potential risks include:

- Traffic interception.
- Unauthorized registry access.
- Modification or substitution attempts.
- Exposure of transferred content.
- Lack of transport authentication.

The laboratory will bind its registry service only to the local host loopback endpoint.

---

# 41. LOCAL REGISTRY CONSIDERATIONS

For a local registry, the Docker Engine must be able to reach the registry endpoint.

Docker commonly permits local loopback registry testing.

If a particular Engine configuration rejects an HTTP registry, the administrator must inspect its registry trust and insecure-registry settings.

**Do not weaken the Docker daemon's registry security configuration broadly merely to make a classroom experiment work.**

The training registry will not be exposed to external network interfaces.

---

# 42. REGISTRY PERSISTENCE

A registry stores image manifests and blobs in its configured storage backend.

If the registry stores content only inside a disposable container writable layer, removing that container may remove its stored artifacts.

A named volume can provide a storage lifecycle independent of the registry container.

For the laboratory, the registry data directory will be:

```text
/var/lib/registry
```

It will be backed by a named Docker volume.

---

# 43. REGISTRY AUTHORIZATION

Production registries should implement an appropriate authentication and authorization strategy.

Possible controls include:

- User authentication.
- Organization membership.
- Repository permissions.
- Push permissions.
- Pull permissions.
- Protected tags.
- Auditing.
- Credential rotation.

A registry should not expose write permissions to all clients without careful evaluation.

---

# 44. IMAGE SCANNING

Image vulnerability scanning attempts to identify known vulnerabilities in the image's detected software components.

It can support release approval.

However:

- Unknown vulnerabilities may remain.
- Application-specific defects may not be detected.
- Some detected vulnerabilities may not be exploitable.
- Some software components may not be fully identified.

Image scanning is a security input rather than a complete guarantee.

---

# 45. SBOM AND PROVENANCE

## 45.1 SBOM

A Software Bill of Materials identifies software components associated with an artifact.

## 45.2 Provenance

Build provenance records information about how an artifact was constructed.

## 45.3 Registry Distribution

Modern OCI-compatible registries can participate in workflows that distribute additional metadata and attestations.

## 45.4 Operational Importance

A mature release process can associate an image with:

- Version.
- Source revision.
- Build system.
- Test results.
- Image digest.
- Vulnerability assessment.
- Software component inventory.

This information supports traceability.

---

# 46. REGISTRY RETENTION

A registry may accumulate many historical image versions.

Organizations often define retention policies controlling which artifacts should remain available.

Important considerations include:

- Release rollback requirements.
- Compliance requirements.
- Storage cost.
- Historical traceability.
- Incident investigation.
- Protected production releases.

Deleting an old image merely because it is not the newest can remove an artifact still required for rollback or audit.

---

# 47. REGISTRY GARBAGE COLLECTION

Registries may use garbage-collection procedures to remove storage that is no longer referenced by retained image content.

Deleting a repository tag does not always immediately reclaim all underlying blob storage.

The exact behavior depends on the registry implementation and storage backend.

Garbage collection is an administrative operation.

It must be performed according to the registry's supported procedures to avoid storage inconsistency or unintended data loss.

---

# 48. REGISTRY QUOTAS AND RATE LIMITS

Registry services may impose limits on:

- Image pulls.
- Storage consumption.
- Repository counts.
- Network transfer.
- API requests.
- Organization usage.

These limits vary between providers and account configurations.

A failed pull is not always caused by an invalid image reference.

Rate limits and authorization settings may also be relevant.

---

# PART V — COMPLETE IMAGE RELEASE LABORATORY

# 49. PROJECT TITLE

**Docker Image Release Engineering: Build, Test, Tag, Publish, Retrieve, Verify, and Roll Back a Python HTTP Application**

## 49.1 Laboratory Objective

The student will construct a Python HTTP application and publish it through a local Docker registry.

The system will demonstrate:

1. Image construction.
2. Automated application testing.
3. Version metadata.
4. Non-root execution.
5. Registry deployment.
6. Image tagging.
7. Image pushing.
8. Image pulling.
9. Registry API inspection.
10. Content digest verification.
11. Versioned release distribution.
12. Rollback.
13. Offline image archive export and import.
14. Optional Docker Hub publication.

---

# 50. REQUIRED SOFTWARE

The required environment includes:

- Docker Engine or Docker Desktop.
- Docker Compose V2.
- Docker Buildx.
- Terminal.
- Text editor.
- HTTP client or browser.
- Internet access to retrieve initial base images.

No Docker Hub publishing account is required for the principal local registry laboratory.

The optional Docker Hub exercises require an account and suitable repository permissions.

---

# 51. LABORATORY ARCHITECTURE

```text
                   DEVELOPMENT
                        |
                        v
                   DOCKER BUILD
                        |
                        v
                LOCAL APPLICATION IMAGE
                        |
                        v
                    DOCKER TAG
                        |
                        v
                    DOCKER PUSH
                        |
                        v
              LOCAL REGISTRY SERVICE
                127.0.0.1:5000
                        |
                        v
                  REGISTRY VOLUME
                        |
                        |
                    DOCKER PULL
                        |
                        v
                 DEPLOYED CONTAINER
                        |
                        v
                127.0.0.1:8280
```

The local registry uses persistent Docker-managed storage.

The deployed application runs from an image retrieved from that registry.

---

# 52. PROJECT DIRECTORY STRUCTURE

Create:

```text
docker-lecture18/
├── Dockerfile
├── app.py
├── tests/
│   └── test_app.py
├── compose.registry.yaml
├── .dockerignore
├── .gitignore
└── artifacts/
```

## File Responsibilities

`Dockerfile`: Defines application build, test, and runtime stages.

`app.py`: Implements the HTTP application.

`tests/test_app.py`: Verifies selected application behavior.

`compose.registry.yaml`: Defines the local registry.

`.dockerignore`: Excludes unnecessary image build inputs.

`.gitignore`: Excludes local artifacts and other unnecessary repository content.

`artifacts/`: Stores local image archives and laboratory evidence.

---

# 53. COMPLETE PYTHON APPLICATION

Create:

`app.py`

Insert:

```python
import html
import json
import os

from http.server import (
    BaseHTTPRequestHandler,
    ThreadingHTTPServer,
)


def release_information():

    return {
        "service": "lecture18-api",
        "version": os.getenv(
            "APP_VERSION",
            "development",
        ),
        "revision": os.getenv(
            "VCS_REF",
            "unknown",
        ),
    }


class ApplicationHandler(BaseHTTPRequestHandler):

    def send_response_body(
        self,
        status,
        body,
        content_type,
    ):

        self.send_response(status)

        self.send_header(
            "Content-Type",
            content_type,
        )

        self.send_header(
            "Content-Length",
            str(len(body)),
        )

        self.end_headers()

        self.wfile.write(body)


    def do_GET(self):

        if self.path == "/healthz":

            self.send_response_body(
                200,
                b"ok\n",
                "text/plain; charset=utf-8",
            )

            return


        if self.path == "/api/info":

            data = release_information()

            body = json.dumps(
                data,
                sort_keys=True,
            ).encode("utf-8")

            self.send_response_body(
                200,
                body,
                "application/json",
            )

            return


        if self.path == "/":

            info = release_information()

            version = html.escape(
                info["version"]
            )

            revision = html.escape(
                info["revision"]
            )

            page = f"""<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">
    <title>Docker Lecture 18</title>
</head>

<body style="font-family:Arial;padding:40px;">

    <h1>Docker Lecture 18</h1>

    <h2>Image Distribution Laboratory</h2>

    <p>Application Version: {version}</p>

    <p>Source Revision: {revision}</p>

    <p>
        This application was packaged into a
        Docker image and distributed through
        a container registry.
    </p>

    <p>
        API endpoint: /api/info
    </p>

</body>
</html>
"""

            self.send_response_body(
                200,
                page.encode("utf-8"),
                "text/html; charset=utf-8",
            )

            return


        body = json.dumps({
            "error": "Not found",
        }).encode("utf-8")

        self.send_response_body(
            404,
            body,
            "application/json",
        )


def main():

    server = ThreadingHTTPServer(
        ("0.0.0.0", 8000),
        ApplicationHandler,
    )

    print(
        "Docker Lecture 18 HTTP service started",
        flush=True,
    )

    server.serve_forever()


if __name__ == "__main__":

    main()
```

---

# 54. APPLICATION ANALYSIS

The application uses Python's standard library.

It requires no third-party Python packages.

The endpoints are:

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | Display the release interface |
| GET | `/healthz` | Basic health check |
| GET | `/api/info` | Display non-sensitive release information |

## 54.1 Release Metadata

The application reads:

```text
APP_VERSION
VCS_REF
```

from its environment.

## 54.2 HTTP Port

The server listens on:

```text
0.0.0.0:8000
```

## 54.3 Portability

The application can execute from any compatible environment containing the expected Python runtime.

Docker provides a packaged environment for distribution.

---

# 55. AUTOMATED TESTS

Create:

`tests/test_app.py`

Insert:

```python
import unittest

from app import release_information


class ReleaseInformationTests(unittest.TestCase):

    def test_service_name(self):

        information = release_information()

        self.assertEqual(
            information["service"],
            "lecture18-api",
        )


    def test_version_field_exists(self):

        information = release_information()

        self.assertIn(
            "version",
            information,
        )


    def test_revision_field_exists(self):

        information = release_information()

        self.assertIn(
            "revision",
            information,
        )


if __name__ == "__main__":

    unittest.main()
```

## 55.1 Purpose

The tests verify the release metadata interface.

## 55.2 Limitation

These tests do not replace complete integration testing.

The laboratory will separately verify actual HTTP functionality after creating a container.

---

# 56. COMPLETE MULTI-STAGE DOCKERFILE

Create:

`Dockerfile`

Insert:

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim AS test

WORKDIR /app

COPY app.py ./app.py

COPY tests/ ./tests/

RUN python -m unittest discover -s tests -v


FROM python:3.12-slim AS runtime

ARG APP_VERSION=1.0.0

ARG VCS_REF=manual-lab

LABEL org.opencontainers.image.title="Docker Lecture 18 API" \
      org.opencontainers.image.description="Registry Distribution Laboratory"

ENV APP_VERSION=${APP_VERSION} \
    VCS_REF=${VCS_REF} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=test --chown=10001:10001 /app/app.py ./app.py

USER 10001:10001

EXPOSE 8000

CMD ["python", "-B", "app.py"]
```

---

# 57. DOCKERFILE ANALYSIS

## 57.1 Test Stage

The first stage executes automated tests.

If the tests fail, the image build fails.

## 57.2 Runtime Stage

The second stage defines the deployable image.

It contains the required Python runtime and application source.

The test files are not copied into the runtime stage.

## 57.3 Build Arguments

The build receives release metadata through:

```dockerfile
ARG APP_VERSION=1.0.0
```

and:

```dockerfile
ARG VCS_REF=manual-lab
```

These values are non-sensitive.

## 57.4 Runtime Environment

The application reads the configured version and revision from its environment.

## 57.5 Non-Root Execution

The runtime image uses numeric UID and GID 10001.

## 57.6 Important Security Principle

Build arguments and environment variables must not contain actual registry passwords or other sensitive credentials.

---

# 58. DOCKERIGNORE CONFIGURATION

Create:

`.dockerignore`

Insert:

```dockerignore
.git
.gitignore
.env
artifacts/
__pycache__/
*.pyc
*.log
*.tmp
```

Create:

`.gitignore`

Insert:

```text
artifacts/
.env
__pycache__/
*.pyc
```

The build context remains focused on source files, tests, and Dockerfile instructions.

---

# 59. COMPLETE LOCAL REGISTRY CONFIGURATION

Create:

`compose.registry.yaml`

Insert:

```yaml
name: lecture18-registry

services:

  registry:
    image: registry:3

    ports:
      - "127.0.0.1:5000:5000"

    environment:
      OTEL_TRACES_EXPORTER: "none"

    volumes:
      - registry-data:/var/lib/registry

    restart: unless-stopped


volumes:

  registry-data:
```

## 59.1 Registry Image

The service uses a Distribution Registry image.

## 59.2 Local Port

The registry is published only through host loopback port 5000.

## 59.3 Persistence

The named volume stores registry content independently of the registry container writable layer.

## 59.4 OpenTelemetry Configuration

The training configuration disables unnecessary trace exporting for the local exercise.

## 59.5 Security Warning

The registry is unauthenticated and uses HTTP.

It is suitable only for an isolated local exercise.

It must not be exposed as an Internet-facing production registry.

---

# PART VI — LOCAL REGISTRY PRACTICAL LABORATORY

# 60. EXPERIMENT 1 — VERIFY DOCKER AVAILABILITY

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
docker buildx version
```

**Objective:** Confirm Docker, Compose, and Buildx availability.

**Required observations:** Record installed versions and the active Docker context.

---

# 61. EXPERIMENT 2 — CREATE THE PROJECT

For a Unix-like shell:

```bash
mkdir -p docker-lecture18/tests
mkdir -p docker-lecture18/artifacts
cd docker-lecture18
```

Create all project files from Sections 53–59.

**Objective:** Establish the reproducible release laboratory.

**Expected result:** The complete project structure exists.

---

# 62. EXPERIMENT 3 — VALIDATE THE REGISTRY CONFIGURATION

Execute:

```bash
docker compose -f compose.registry.yaml config -q
```

Then:

```bash
docker compose -f compose.registry.yaml config
```

**Objective:** Verify the registry service definition.

**Required observations:**

1. Project name.
2. Registry image.
3. Published host endpoint.
4. Named volume.
5. Runtime environment.

---

# 63. EXPERIMENT 4 — START THE LOCAL REGISTRY

Execute:

```bash
docker compose -f compose.registry.yaml up -d
```

Verify:

```bash
docker compose -f compose.registry.yaml ps
```

**Objective:** Start the local registry service.

**Expected result:** The registry container is running.

---

# 64. EXPERIMENT 5 — VERIFY THE REGISTRY API

Execute:

```bash
curl -i http://127.0.0.1:5000/v2/
```

**Objective:** Verify that the registry API responds.

**Expected result:** HTTP 200 from the unauthenticated local registry.

This endpoint is part of the registry API protocol.

**Required analysis:** Explain why an API response is more useful than merely observing that the container is running.

---

# 65. EXPERIMENT 6 — BUILD THE APPLICATION IMAGE

Execute:

```bash
docker build \
  --progress=plain \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg VCS_REF=lecture18-initial \
  -t lecture18-api:1.0.0 \
  .
```

**Objective:** Construct the first release image.

**Expected behavior:** Docker executes the test stage and constructs the runtime image.

**Required analysis:** Explain why a successful build is evidence that the configured tests passed, but not proof of all application functionality.

---

# 66. EXPERIMENT 7 — INSPECT THE RELEASE IMAGE

Execute:

```bash
docker image inspect lecture18-api:1.0.0
```

Then:

```bash
docker image ls lecture18-api
```

**Objective:** Inspect the image before publication.

**Required observations:**

- Image ID.
- Image size.
- User identity.
- Exposed port.
- Runtime command.
- Version environment variable.

---

# 67. EXPERIMENT 8 — RUN THE LOCAL RELEASE

Execute:

```bash
docker run -d \
  --name lecture18-local-check \
  -p 127.0.0.1:8280:8000 \
  lecture18-api:1.0.0
```

Open:

http://127.0.0.1:8280

**Objective:** Verify application execution before publication.

**Expected result:** The browser displays version 1.0.0.

---

# 68. EXPERIMENT 9 — TEST THE APPLICATION API

Execute:

```bash
curl -i http://127.0.0.1:8280/healthz
```

Then:

```bash
curl http://127.0.0.1:8280/api/info
```

**Expected result:** The application returns a successful health response and JSON release metadata.

For example:

```json
{
  "revision": "lecture18-initial",
  "service": "lecture18-api",
  "version": "1.0.0"
}
```

**Objective:** Establish a verified pre-publication baseline.

---

# 69. EXPERIMENT 10 — STOP THE LOCAL VERIFICATION CONTAINER

Execute:

```bash
docker stop lecture18-local-check
```

Then:

```bash
docker rm lecture18-local-check
```

**Objective:** Remove the temporary application container without deleting its image.

**Required analysis:** Distinguish a container's lifecycle from the image used to construct it.

---

# 70. EXPERIMENT 11 — TAG THE IMAGE FOR THE REGISTRY

Execute:

```bash
docker image tag \
  lecture18-api:1.0.0 \
  127.0.0.1:5000/lecture18/api:1.0.0
```

Inspect:

```bash
docker image ls
```

**Objective:** Assign a registry-qualified image reference.

**Expected result:** The local image now has an additional tag identifying the local registry.

**Required analysis:** Explain why Docker did not need to rebuild the application.

---

# 71. EXPERIMENT 12 — PUSH THE IMAGE

Execute:

```bash
docker push 127.0.0.1:5000/lecture18/api:1.0.0
```

**Objective:** Publish the image to the local registry.

**Expected result:** Docker reports successful publication and displays a registry digest.

Record that digest.

**Required analysis:** Explain why publication involves image manifests and layer content rather than running application processes.

---

# 72. EXPERIMENT 13 — INSPECT REGISTRY CATALOG

Execute:

```bash
curl http://127.0.0.1:5000/v2/_catalog
```

**Objective:** Inspect the local registry's repository catalog.

**Expected result:** A response containing a repository identifier such as:

```json
{
  "repositories": [
    "lecture18/api"
  ]
}
```

The precise output formatting may differ.

**Important qualification:** Managed production registries may restrict or disable catalog enumeration.

---

# 73. EXPERIMENT 14 — INSPECT REPOSITORY TAGS

Execute:

```bash
curl http://127.0.0.1:5000/v2/lecture18/api/tags/list
```

**Objective:** Identify published tags for the application repository.

**Expected result:** The response includes:

```text
1.0.0
```

**Required analysis:** Explain why the repository name and its tag are different elements of the image reference.

---

# 74. EXPERIMENT 15 — INSPECT THE PUBLISHED MANIFEST

Execute:

```bash
docker buildx imagetools inspect \
  127.0.0.1:5000/lecture18/api:1.0.0
```

**Objective:** Inspect registry-side image metadata.

**Required observations:**

1. Registry reference.
2. Manifest digest.
3. Media type.
4. Platform information.

**Required analysis:** Explain why a registry manifest digest differs conceptually from a local image ID.

---

# 75. EXPERIMENT 16 — REMOVE LOCAL IMAGE REFERENCES

Before this experiment, verify that the image was pushed successfully.

Remove the local registry-qualified tag:

```bash
docker image rm \
  127.0.0.1:5000/lecture18/api:1.0.0
```

Remove the original local tag:

```bash
docker image rm lecture18-api:1.0.0
```

**Objective:** Demonstrate that the registry contains an independently stored published artifact.

**Important qualification:** Docker may retain shared layers or build-cache content locally even after the tags are removed.

The experiment tests registry retrieval, not complete erasure of every local content blob.

---

# 76. EXPERIMENT 17 — PULL THE PUBLISHED IMAGE

Execute:

```bash
docker pull 127.0.0.1:5000/lecture18/api:1.0.0
```

**Objective:** Retrieve the release from the registry.

**Expected result:** Docker resolves the registry reference and makes the image available locally.

Verify:

```bash
docker image ls
```

**Required analysis:** Explain why the image can be retrieved even though its original local tag was removed.

---

# 77. EXPERIMENT 18 — RUN THE PULLED IMAGE

Execute:

```bash
docker run -d \
  --name lecture18-pulled \
  -p 127.0.0.1:8281:8000 \
  127.0.0.1:5000/lecture18/api:1.0.0
```

Open:

http://127.0.0.1:8281

Verify:

```bash
curl http://127.0.0.1:8281/api/info
```

**Objective:** Demonstrate successful execution of the distributed release artifact.

**Expected result:** The application reports version 1.0.0.

---

# 78. EXPERIMENT 19 — INSPECT REPOSITORY DIGESTS

Execute:

```bash
docker image inspect \
  127.0.0.1:5000/lecture18/api:1.0.0 \
  --format '{{json .RepoDigests}}'
```

**Objective:** Inspect registry-associated digest references.

**Expected result:** The available reference information includes a registry digest after the published image has been pulled.

**Required analysis:** Explain why the digest is associated with the registry-distributed artifact rather than serving as a human-readable release label.

---

# 79. EXPERIMENT 20 — PULL BY DIGEST

From the previous registry inspection output, record the actual manifest digest.

For a Unix-like shell, assign the value:

```bash
DIGEST='sha256:REPLACE_WITH_ACTUAL_DIGEST'
```

Then execute:

```bash
docker pull \
  "127.0.0.1:5000/lecture18/api@${DIGEST}"
```

**Objective:** Retrieve an exact registry artifact.

**Important requirement:** Replace the placeholder with the real digest reported by the registry.

**Required analysis:** Explain why this reference is more precise than an independently mutable tag.

---

# 80. EXPERIMENT 21 — BUILD A SECOND RELEASE

Execute:

```bash
docker build \
  --progress=plain \
  --build-arg APP_VERSION=1.0.1 \
  --build-arg VCS_REF=lecture18-update \
  -t lecture18-api:1.0.1 \
  .
```

**Objective:** Construct a new release image with different metadata.

**Expected result:** Version 1.0.1 becomes available locally.

**Required analysis:** Explain why both images can be retained as separate release artifacts.

---

# 81. EXPERIMENT 22 — TAG AND PUSH THE SECOND RELEASE

Tag:

```bash
docker image tag \
  lecture18-api:1.0.1 \
  127.0.0.1:5000/lecture18/api:1.0.1
```

Push:

```bash
docker push 127.0.0.1:5000/lecture18/api:1.0.1
```

**Objective:** Publish the second version.

**Expected result:** Both version tags are available in the registry.

Inspect:

```bash
curl http://127.0.0.1:5000/v2/lecture18/api/tags/list
```

---

# 82. EXPERIMENT 23 — COMPARE RELEASE REFERENCES

Execute:

```bash
docker buildx imagetools inspect \
  127.0.0.1:5000/lecture18/api:1.0.0
```

Then:

```bash
docker buildx imagetools inspect \
  127.0.0.1:5000/lecture18/api:1.0.1
```

**Objective:** Compare two published release artifacts.

**Expected result:** The versions normally have different content digests because their release metadata differs.

**Required analysis:** Explain why the registry can retain both versions simultaneously.

---

# 83. EXPERIMENT 24 — DEPLOY THE SECOND RELEASE

Remove the first application container:

```bash
docker stop lecture18-pulled
```

```bash
docker rm lecture18-pulled
```

Run the second version:

```bash
docker run -d \
  --name lecture18-current \
  -p 127.0.0.1:8281:8000 \
  127.0.0.1:5000/lecture18/api:1.0.1
```

Verify:

```bash
curl http://127.0.0.1:8281/api/info
```

**Expected result:** Version 1.0.1 is active.

**Objective:** Demonstrate release replacement.

---

# 84. EXPERIMENT 25 — ROLL BACK TO VERSION 1.0.0

Stop the second release:

```bash
docker stop lecture18-current
```

Remove its container:

```bash
docker rm lecture18-current
```

Run the earlier release:

```bash
docker run -d \
  --name lecture18-rollback \
  -p 127.0.0.1:8281:8000 \
  127.0.0.1:5000/lecture18/api:1.0.0
```

Verify:

```bash
curl http://127.0.0.1:8281/api/info
```

**Expected result:** The application reports version 1.0.0.

**Objective:** Demonstrate image-based application rollback.

**Required analysis:** Explain why this exercise does not include database rollback or zero-downtime deployment.

---

# 85. EXPERIMENT 26 — VERIFY REGISTRY PERSISTENCE

Stop the application rollback container:

```bash
docker stop lecture18-rollback
```

```bash
docker rm lecture18-rollback
```

Remove the registry service without deleting its named volume:

```bash
docker compose -f compose.registry.yaml down
```

Inspect:

```bash
docker volume inspect lecture18-registry_registry-data
```

Restart:

```bash
docker compose -f compose.registry.yaml up -d
```

Verify published tags:

```bash
curl http://127.0.0.1:5000/v2/lecture18/api/tags/list
```

**Objective:** Demonstrate persistent registry storage.

**Expected result:** Previously published image references remain available.

---

# 86. EXPERIMENT 27 — EXPORT AN IMAGE ARCHIVE

Create an offline image archive:

```bash
docker image save \
  -o artifacts/lecture18-api-1.0.1.tar \
  127.0.0.1:5000/lecture18/api:1.0.1
```

**Objective:** Export image content into a portable archive.

Verify the file exists.

**Required analysis:** Explain how archive-based transfer differs from registry publication.

---

# 87. EXPERIMENT 28 — RESTORE AN IMAGE ARCHIVE

First ensure no container is using the selected version.

Remove the local tag:

```bash
docker image rm \
  127.0.0.1:5000/lecture18/api:1.0.1
```

Now load:

```bash
docker image load \
  -i artifacts/lecture18-api-1.0.1.tar
```

Verify:

```bash
docker image ls
```

**Objective:** Restore an image from an archive without performing another registry pull.

**Important distinction:** `docker save` and `docker load` operate on image archives. They are not interchangeable with `docker export` and `docker import`, which concern container filesystem exports and do not preserve the same image structure and metadata.

---

# 88. EXPERIMENT 29 — FINAL RELEASE VERIFICATION

Inspect the local registry:

```bash
curl http://127.0.0.1:5000/v2/_catalog
```

Inspect tags:

```bash
curl http://127.0.0.1:5000/v2/lecture18/api/tags/list
```

Inspect a release manifest:

```bash
docker buildx imagetools inspect \
  127.0.0.1:5000/lecture18/api:1.0.1
```

**Objective:** Verify that the registry still contains the intended release artifacts.

**Required conclusion:** The local registry contains both published versions, and the application image can be retrieved and executed.

---

# 89. EXPERIMENT 30 — CONTROLLED REGISTRY CLEANUP

Stop the registry service:

```bash
docker compose -f compose.registry.yaml down
```

The registry storage volume remains available.

Verify:

```bash
docker volume ls
```

**Optional destructive cleanup:**

Only after verifying that the published laboratory images are no longer required, remove the specific registry volume:

```bash
docker volume rm lecture18-registry_registry-data
```

**Critical warning:** Removing this volume deletes the registry's stored image content.

The operation must not be executed when the published artifacts must be retained.

The local image archive in `artifacts/` is a separate resource.

---

# PART VII — OPTIONAL DOCKER HUB PUBLICATION LABORATORY

# 90. PREREQUISITES FOR DOCKER HUB PUBLICATION

The following exercises are optional.

They require:

1. A Docker Hub account.
2. Suitable repository permissions.
3. Access to the Docker Hub website.
4. Docker CLI authentication.
5. An image selected for publication.

The local registry laboratory is complete without these additional activities.

---

# 91. OPTIONAL EXPERIMENT A — CREATE A REPOSITORY

Sign in to Docker Hub.

Create a repository named:

```text
lecture18-api
```

Choose a namespace under the account or organization for which you have appropriate permissions.

Select public or private visibility according to your intended use.

## Security Consideration

Do not publish confidential application images into a public repository.

The instructional application contains no real credentials and is intended for educational distribution.

---

# 92. OPTIONAL EXPERIMENT B — AUTHENTICATE

Execute:

```bash
docker login
```

Follow the available authentication process.

If the environment requires username-based authentication:

```bash
docker login --username YOUR_DOCKER_ID
```

Supply the authorized credential interactively.

Do not place an actual token into the lecture notes or a public command.

---

# 93. OPTIONAL EXPERIMENT C — TAG FOR DOCKER HUB

Replace `YOUR_DOCKER_ID` with your actual Docker Hub namespace.

Execute:

```bash
docker image tag \
  lecture18-api:1.0.1 \
  YOUR_DOCKER_ID/lecture18-api:1.0.1
```

If the local source tag is unavailable, first reassign a local tag to the version retrieved from the local registry or rebuild the intended release.

## Objective

Associate the image with the correct Docker Hub repository.

---

# 94. OPTIONAL EXPERIMENT D — PUSH TO DOCKER HUB

Execute:

```bash
docker push YOUR_DOCKER_ID/lecture18-api:1.0.1
```

## Objective

Publish the application into the authorized repository.

## Expected Result

The image appears in the repository after successful publication.

## Important Qualification

Publication may fail because of incorrect credentials, missing permissions, repository settings, connectivity, or registry limits.

A successful local image build does not guarantee permission to push to a particular Docker Hub namespace.

---

# 95. OPTIONAL EXPERIMENT E — VERIFY REMOTE RETRIEVAL

Inspect the published image through Docker Hub.

Then execute:

```bash
docker pull YOUR_DOCKER_ID/lecture18-api:1.0.1
```

## Objective

Demonstrate retrieval from an external registry rather than the local laboratory registry.

The application can then be tested through an appropriately published container port.

---

# 96. OPTIONAL EXPERIMENT F — LOG OUT

After completing the publication exercise, consider ending the Docker Hub authentication session on a shared or temporary training machine.

Execute:

```bash
docker logout
```

## Important Qualification

Logging out may affect other workflows that rely on the same local Docker client credentials.

The command does not remove published images or revoke the access token at the provider.

---

# PART VIII — ADVANCED REGISTRY ENGINEERING

# 97. MULTI-PLATFORM PUBLICATION

Docker Buildx can construct images for multiple platforms when the build environment supports the required targets.

Example:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag YOUR_DOCKER_ID/lecture18-api:1.0.1 \
  --push \
  .
```

This command is illustrative and requires an authorized registry destination.

## 97.1 Output

The registry may receive an image index referencing multiple platform-specific image manifests.

## 97.2 Platform Compatibility

The builder must support the target platforms through native execution, emulation, or suitable cross-compilation.

## 97.3 Practical Significance

The same logical image tag can serve different processor architectures.

## 97.4 Limitation

Not every application or dependency supports every target platform.

Multi-platform support must be verified through appropriate testing.

---

# 98. MANIFEST INSPECTION

Docker Buildx provides:

```bash
docker buildx imagetools inspect IMAGE
```

This command inspects image information in a registry.

It can reveal:

- Manifest or image index media type.
- Registry digest.
- Platform variants.
- Referenced manifests.
- Additional metadata.

## Important Distinction

The presence of a multi-platform index does not prove that every application variant has passed functional tests.

Each supported platform may require its own validation.

---

# 99. BUILDKIT DIRECT REGISTRY EXPORT

Buildx can build and push in one operation.

Example:

```bash
docker buildx build \
  --tag YOUR_DOCKER_ID/lecture18-api:1.0.1 \
  --push \
  .
```

## 99.1 Engineering Benefit

The build output can be sent directly to a registry.

This can be useful in continuous integration systems.

## 99.2 Local Image Store

Some Buildx builder configurations do not automatically load the resulting image into the local Docker Engine image store.

This behavior must be distinguished from a failed build.

## 99.3 Next Lecture Connection

Lecture 20 will examine how a CI/CD pipeline performs authentication, building, testing, and registry publication automatically.

---

# 100. REGISTRY AND DEPLOYMENT SECURITY

A professional image release process should consider:

1. Registry TLS.
2. Account authentication.
3. Repository authorization.
4. Token permissions.
5. Token rotation.
6. Image vulnerability scanning.
7. Software component inventories.
8. Build provenance.
9. Image digest tracking.
10. Approved release references.
11. Audit records.
12. Controlled rollback.

The registry is not merely a file storage service.

It is part of the software supply chain.

---

# 101. RELEASE METADATA

A release record may contain:

| Field | Example |
|---|---|
| Application | Lecture 18 API |
| Release version | 1.0.1 |
| Registry | Docker Hub or local registry |
| Repository | lecture18-api |
| Source revision | lecture18-update |
| Manifest digest | Actual SHA-256 digest |
| Supported platform | linux/amd64 |
| Build status | Passed |
| Test status | Passed |
| Publication status | Verified |
| Deployment status | Verified |

## Important Principle

The release record should contain actual values observed from the build and registry.

Do not fabricate a digest or claim that an artifact was published without successful publication evidence.

---

# 102. RELEASE PROMOTION STRATEGY

A mature release process may establish separate environments:

```text
                  SOURCE CODE
                       |
                       v
                  BUILD IMAGE
                       |
                       v
                 AUTOMATED TEST
                       |
                       v
                 PUBLISH IMAGE
                       |
                       v
                STAGING VALIDATION
                       |
                       v
               PRODUCTION APPROVAL
                       |
                       v
                PRODUCTION DEPLOY
```

The approved release should be traceable to its source revision and image digest.

Environment-specific configuration is supplied separately from the application image where appropriate.

---

# PART IX — TROUBLESHOOTING IMAGE DISTRIBUTION

# 103. ERROR: REPOSITORY DOES NOT EXIST

A pull may fail because:

- The repository name is incorrect.
- The registry hostname is incorrect.
- The repository has not been created.
- The repository is private.
- The client lacks required access.

## Investigation

1. Verify the complete image reference.
2. Verify the intended registry.
3. Verify repository existence.
4. Verify the repository's visibility.
5. Verify authentication and permissions.

---

# 104. ERROR: ACCESS DENIED

An image push may fail because:

- The client is not authenticated.
- The credentials are invalid.
- The token lacks write permission.
- The namespace belongs to another account.
- Organization policy prevents publication.

## Corrective Principle

Verify authorization rather than repeatedly changing the image tag without understanding the permission boundary.

---

# 105. ERROR: MANIFEST UNKNOWN

A registry may report that a requested manifest is unknown.

Possible causes include:

- Incorrect tag.
- Missing image version.
- Deleted registry artifact.
- Incorrect digest.
- Wrong repository.
- Incomplete or failed publication.

## Investigation

Inspect available repository tags and known release digests.

For the local training registry:

```bash
curl http://127.0.0.1:5000/v2/lecture18/api/tags/list
```

---

# 106. ERROR: CONNECTION REFUSED

A client may be unable to connect to the registry endpoint.

Possible causes include:

- Registry container not running.
- Wrong port.
- Incorrect host address.
- Port mapping missing.
- Docker daemon accessing another machine's loopback address.

## Investigation

```bash
docker compose -f compose.registry.yaml ps
```

```bash
docker compose -f compose.registry.yaml logs registry
```

```bash
curl -i http://127.0.0.1:5000/v2/
```

---

# 107. ERROR: TLS OR CERTIFICATE FAILURE

A registry client may reject a connection because:

- The registry certificate is not trusted.
- The certificate hostname is incorrect.
- The certificate has expired.
- The server provides HTTP where HTTPS is expected.
- The client lacks the required trust configuration.

## Corrective Principle

Use appropriately configured TLS and trusted certificates.

Do not disable TLS verification for production simply to avoid correcting certificate problems.

---

# 108. ERROR: WRONG PLATFORM

A pull or run operation may fail because the requested image does not include an appropriate platform variant.

## Investigation

Use:

```bash
docker buildx imagetools inspect IMAGE
```

Identify available platforms.

## Corrective Principle

Build and publish the required platform variant or use a suitable compatible execution environment.

---

# 109. ERROR: IMAGE NOT FOUND LOCALLY AFTER BUILDX

A Buildx build may finish successfully without loading the resulting image into Docker Engine's local image store.

## Corrective Action

For a suitable single-platform local build:

```bash
docker buildx build --load -t application:local .
```

For registry publication:

```bash
docker buildx build --push -t REGISTRY/REPOSITORY:TAG .
```

The correct operation depends on the intended output.

---

# 110. ERROR: REGISTRY DATA DISAPPEARS

A local registry container is removed and recreated.

Previously published images are unavailable.

Possible causes include:

- Missing named volume.
- Wrong volume name.
- Wrong storage mount.
- Different Compose project.
- Deleted registry storage.
- Incorrect registry configuration.

## Corrective Principle

Inspect both the registry's storage configuration and Docker volume lifecycle.

---

# PART X — COMMON CONCEPTUAL MISUNDERSTANDINGS

# 111. FREQUENT ERRORS

**Misunderstanding 1:** A Docker image is the same as a running container.

Incorrect. An image is a deployable artifact; a container is a runtime instance.

**Misunderstanding 2:** Tagging always creates a new image.

Incorrect. Tagging can create another reference to existing image content.

**Misunderstanding 3:** The `latest` tag automatically identifies the newest release.

Incorrect. It is an ordinary tag.

**Misunderstanding 4:** A repository is the same thing as a registry.

Incorrect. A registry can contain multiple repositories.

**Misunderstanding 5:** Pushing an image starts the application.

Incorrect. Pushing publishes the artifact.

**Misunderstanding 6:** Pulling an image starts a container.

Incorrect. Pulling retrieves the image.

**Misunderstanding 7:** The local image ID must equal the registry manifest digest.

Incorrect. They commonly identify different content objects.

**Misunderstanding 8:** A digest proves that an image is secure.

Incorrect. It identifies specific content.

**Misunderstanding 9:** A private repository guarantees an image contains no secrets.

Incorrect. Image content must still be reviewed.

**Misunderstanding 10:** Successful registry authentication guarantees push permission.

Incorrect. Authorization is separate.

**Misunderstanding 11:** Docker Hub is the only container registry.

Incorrect. Many compatible registries exist.

**Misunderstanding 12:** Every registry must support public catalog enumeration.

Incorrect. Production registries may restrict it.

**Misunderstanding 13:** A local HTTP registry is appropriate for Internet-facing production.

Incorrect. Production distribution requires appropriate transport security and access controls.

**Misunderstanding 14:** Removing local image tags deletes published registry images.

Incorrect. Local and registry storage have independent lifecycles.

**Misunderstanding 15:** Application rollback automatically restores database state.

Incorrect. Persistent data and application images are managed separately.

---

# PART XI — ACADEMIC GLOSSARY

# 112. TECHNICAL TERMINOLOGY

| Term | Definition |
|---|---|
| Container registry | Service for storing and distributing container images |
| Repository | Logical collection of image references |
| Namespace | Naming scope associated with a user or organization |
| Image reference | Structured identifier for selecting an image |
| Registry hostname | Network identifier of the registry service |
| Tag | Human-readable image reference label |
| Digest | Content-derived identifier |
| Image ID | Local identifier associated with image configuration content |
| Manifest | Metadata describing image configuration and layers |
| Image index | Metadata referencing multiple image manifests |
| OCI | Open Container Initiative |
| Docker Hub | Hosted container registry and repository service |
| Official Image | Image distributed through the Docker Official Images program |
| Public repository | Repository accessible under public retrieval rules |
| Private repository | Repository restricted by authorization |
| Authentication | Process of establishing client identity |
| Authorization | Determination of allowed operations |
| Access token | Credential used for supported authenticated access |
| Credential helper | Program supporting secure credential storage |
| Push | Upload of image content to a registry |
| Pull | Retrieval of image content from a registry |
| Image tagging | Assignment of an additional image reference |
| Semantic Versioning | Version identification scheme using major, minor, and patch components |
| Immutable release | Release whose approved artifact identity remains fixed |
| Release promotion | Movement of an approved artifact through deployment stages |
| Rollback | Return to a previous application version |
| TLS | Transport Layer Security |
| Registry API | Interface for registry content and metadata operations |
| Multi-platform image | Image distribution supporting multiple target platforms |
| Architecture | Processor instruction-set target such as amd64 or arm64 |
| Buildx | Docker extended BuildKit interface |
| Registry exporter | Build output mechanism publishing directly to a registry |
| SBOM | Software Bill of Materials |
| Provenance | Information describing how an artifact was constructed |
| Vulnerability scan | Assessment for identified known software vulnerabilities |
| Retention policy | Rules determining how long artifacts are preserved |
| Garbage collection | Reclamation of unreferenced storage |
| Docker save | Export of Docker image content to an archive |
| Docker load | Import of image content from an archive |
| Software supply chain | Processes and components involved in producing and delivering software |

---

# PART XII — FORMAL ACADEMIC ASSESSMENT

# 113. PART A — TECHNICAL DEFINITIONS

Define precisely:

1. Container registry.
2. Repository.
3. Namespace.
4. Image reference.
5. Image tag.
6. Content digest.
7. Image manifest.
8. Image index.
9. Registry authentication.
10. Registry authorization.
11. Software release.
12. Release immutability.
13. Image promotion.
14. Rollback.
15. Multi-platform distribution.

---

# 114. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain the purpose of a container registry.

**Question 2.**

Distinguish a registry from a repository.

**Question 3.**

Describe the components of a fully qualified Docker image reference.

**Question 4.**

Explain why the `latest` tag should not be treated as a reliable version identifier.

**Question 5.**

Describe what happens when `docker image tag` is executed.

**Question 6.**

Explain the responsibilities of `docker push`.

**Question 7.**

Explain the responsibilities of `docker pull`.

**Question 8.**

Distinguish authentication from authorization.

**Question 9.**

Describe the security benefits of appropriate registry credential management.

**Question 10.**

Explain the difference between a local image ID and a registry manifest digest.

**Question 11.**

Describe the purpose of a multi-platform image index.

**Question 12.**

Explain why registry TLS is important.

**Question 13.**

Describe why image digest pinning improves deployment reproducibility.

**Question 14.**

Explain why image rollback does not automatically restore application data.

**Question 15.**

Compare registry-based image distribution with `docker save` and `docker load`.

---

# 115. PART C — IMAGE REFERENCE ANALYSIS

Consider:

```text
127.0.0.1:5000/lecture18/api:1.0.0
```

Answer:

1. What is the registry hostname?
2. What is the registry port?
3. What is the repository name?
4. What is the tag?
5. Which command uploads this image?
6. Which command retrieves it?

Consider:

```text
example-user/lecture18-api:1.0.1
```

Answer:

7. Which registry is used by default?
8. What does the namespace identify?
9. What permissions are needed to push?

Consider:

```text
repository@sha256:<actual-digest>
```

Answer:

10. What does the digest identify?
11. Why is this reference more precise than a mutable tag?
12. Does digest pinning prove that the software is vulnerability-free?

---

# 116. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Unauthorized Push

A developer builds an image successfully but receives access denied when pushing it.

Analyze possible authorization and naming problems.

Recommend a diagnostic procedure.

## Case Study 2 — Mutable Release Tag

An organization publishes release 1.0.0.

Later, it overwrites the same tag with different content.

Two deployment hosts pull the same tag at different times.

Explain why they may receive different artifacts.

Recommend a release policy.

## Case Study 3 — Registry TLS Failure

A client cannot connect to an internal registry because the TLS certificate is untrusted.

Explain the security purpose of certificate verification.

Recommend an appropriate correction.

## Case Study 4 — Platform Mismatch

An image is built for `linux/amd64`.

A deployment target requires `linux/arm64`.

Explain why a compatibility problem may occur.

Describe how multi-platform images can address it.

## Case Study 5 — Registry Data Loss

A developer runs a registry container without persistent storage.

The container is removed.

Its images disappear.

Explain the cause and recommend a storage configuration.

## Case Study 6 — Application Rollback

An application is rolled back from image 1.0.1 to 1.0.0.

However, the database schema has changed.

Explain why the image rollback may be insufficient.

Discuss the need for coordinated migration and recovery procedures.

---

# 117. PRACTICAL EXAMINATION

**Total Available Marks: 100**

| Assessment category | Marks |
|---|---:|
| Registry and image reference theory | 15 |
| Image construction and testing | 15 |
| Local registry deployment | 15 |
| Tagging, push, and pull | 20 |
| Digest verification and manifest inspection | 15 |
| Release versioning and rollback | 10 |
| Security and troubleshooting | 5 |
| Technical documentation | 5 |
| **Total** | **100** |

**Recommended passing standard:** 80/100.

The student must demonstrate that an image was successfully published, retrieved, and executed.

A successful local build alone is not sufficient evidence of image distribution competence.

---

# 118. INDEPENDENT ACADEMIC ASSIGNMENT

**Assignment Title:** Docker Registry Architecture and Container Image Release Engineering

Prepare a technical report of approximately 1,500–2,000 words addressing:

**“Container Image Distribution and Release Management: Registries, Repository Naming, Authentication, Image Manifests, Content Digests, and Controlled Deployment.”**

The report must include:

1. Introduction to image distribution.
2. Registry architecture.
3. Repository and namespace concepts.
4. Docker image reference structure.
5. Tagging and semantic versioning.
6. Docker Hub publication workflow.
7. Authentication and authorization.
8. Credential security.
9. Push and pull operations.
10. Image layer distribution.
11. Image manifests.
12. Image indexes.
13. Content digests.
14. Multi-platform images.
15. Local registry implementation.
16. Registry persistence.
17. Image release validation.
18. Rollback procedures.
19. Registry security.
20. Laboratory results.
21. Technical conclusion.

The report should contain:

- An image distribution architecture diagram.
- A registry hierarchy diagram.
- A table comparing tags and digests.
- A record of both published release versions.
- The actual manifest digests obtained during the laboratory.
- The observed results of retrieval and rollback.

---

# 119. PRACTICAL COMPETENCY CHECKLIST

Before proceeding to Lecture 19, verify the following.

## Registry Fundamentals

- [ ] I can define a container registry.
- [ ] I can distinguish registry and repository.
- [ ] I understand namespaces.
- [ ] I can interpret complete image references.
- [ ] I understand Docker's default registry behavior.

## Image Versioning

- [ ] I can assign image tags.
- [ ] I understand semantic version identifiers.
- [ ] I understand that tags may be mutable.
- [ ] I can distinguish tags from digests.
- [ ] I understand why `latest` is not a reliable release identifier.

## Authentication

- [ ] I can explain registry authentication.
- [ ] I can explain registry authorization.
- [ ] I understand Docker credential storage.
- [ ] I understand access-token security.
- [ ] I know why credentials should not be hardcoded.

## Image Distribution

- [ ] I can use `docker push`.
- [ ] I can use `docker pull`.
- [ ] I understand image layer reuse.
- [ ] I can explain registry manifests.
- [ ] I can inspect an image digest.
- [ ] I can retrieve an image by digest.
- [ ] I can inspect image platforms.

## Local Registry

- [ ] I can define a registry service using Compose.
- [ ] I can publish the registry on loopback.
- [ ] I can configure a registry named volume.
- [ ] I can test the registry API.
- [ ] I can inspect repository tags.
- [ ] I understand why the local HTTP configuration is not production-ready.

## Release Management

- [ ] I can construct version 1.0.0.
- [ ] I can construct version 1.0.1.
- [ ] I can publish both versions.
- [ ] I can retrieve both versions.
- [ ] I can compare manifest digests.
- [ ] I can deploy a selected release.
- [ ] I can roll back to an earlier release.
- [ ] I understand the limitations of application-only rollback.

## Image Archives

- [ ] I can export an image with `docker save`.
- [ ] I can import an image with `docker load`.
- [ ] I can distinguish archive transfer from registry publication.
- [ ] I understand that image archives do not replace a complete release management system.

## Practical Laboratory

- [ ] I created the complete project.
- [ ] I built the application image.
- [ ] I executed the automated tests.
- [ ] I tested the local application.
- [ ] I deployed the local registry.
- [ ] I validated its API.
- [ ] I tagged the image for the registry.
- [ ] I pushed release 1.0.0.
- [ ] I inspected the registry catalog.
- [ ] I inspected available tags.
- [ ] I inspected the published manifest.
- [ ] I removed local image references.
- [ ] I pulled the image again.
- [ ] I ran the retrieved image.
- [ ] I recorded the registry digest.
- [ ] I built release 1.0.1.
- [ ] I published release 1.0.1.
- [ ] I deployed the second release.
- [ ] I demonstrated rollback.
- [ ] I verified registry persistence.
- [ ] I exported and restored an image archive.
- [ ] I completed the academic assessment.
- [ ] I prepared the technical report.

**Completion standard:**

The student should be able to construct, version, publish, retrieve, inspect, and redeploy Docker images through a registry while maintaining appropriate controls over release identity and distribution security.

---

# 120. LECTURE SUMMARY

Lecture 18 introduces container registries as the distribution infrastructure for Docker images.

A container image is a deployable artifact.

A registry stores and distributes that artifact.

Repositories organize image references.

Namespaces identify logical ownership scopes.

Tags provide human-readable version references.

Content digests identify specific image content.

These concepts are related but not interchangeable.

`docker image tag` assigns an additional reference to an image.

`docker push` publishes image content to a registry.

`docker pull` retrieves the selected image from a registry.

Neither command automatically starts an application container.

Docker Hub provides a hosted registry service, while self-hosted registries allow organizations to operate their own distribution infrastructure.

Authentication establishes the identity of a client.

Authorization determines which repositories and operations that identity may access.

Registry credentials must be protected through appropriate storage and privilege controls.

Image manifests and indexes describe the content and platform variants associated with distributed images.

Digest-based references provide precise artifact selection.

Semantic version tags support human-readable release management.

A disciplined release process records both the approved release version and the associated digest.

The laboratory demonstrates these principles through a local Distribution Registry.

The student builds and tests an HTTP application, publishes version 1.0.0, retrieves the image, verifies its execution, publishes version 1.0.1, and rolls back to the earlier release.

The experiments also demonstrate registry persistence and archive-based image transfer.

**The central principle of this lecture is that container image distribution must preserve artifact identity, control publication permissions, support reproducible retrieval, and provide a traceable relationship between tested releases and deployed software.**

---

# 121. REFERENCES AND RECOMMENDED READING

## Docker Image References and Operations

[1] Docker Inc. *Docker Image Tag.*  
https://docs.docker.com/reference/cli/docker/image/tag/

[2] Docker Inc. *Docker Image Push.*  
https://docs.docker.com/reference/cli/docker/image/push/

[3] Docker Inc. *Docker Image Pull.*  
https://docs.docker.com/reference/cli/docker/image/pull/

[4] Docker Inc. *Docker Image List.*  
https://docs.docker.com/reference/cli/docker/image/ls/

[5] Docker Inc. *Docker Image Inspect.*  
https://docs.docker.com/reference/cli/docker/image/inspect/

## Docker Hub

[6] Docker Inc. *Docker Hub Documentation.*  
https://docs.docker.com/docker-hub/

[7] Docker Inc. *Create a Repository.*  
https://docs.docker.com/docker-hub/repos/create/

[8] Docker Inc. *Push Images to a Repository.*  
https://docs.docker.com/docker-hub/repos/manage/hub-images/push/

[9] Docker Inc. *Docker Login.*  
https://docs.docker.com/reference/cli/docker/login/

[10] Docker Inc. *Personal Access Tokens.*  
https://docs.docker.com/security/access-tokens/personal-access-tokens/

## Registries and Image Manifests

[11] CNCF Distribution. *Deploy a Registry Server.*  
https://distribution.github.io/distribution/about/deploying/

[12] CNCF Distribution. *Test an Insecure Registry.*  
https://distribution.github.io/distribution/about/insecure/

[13] Docker Inc. *Image and Registry Exporters.*  
https://docs.docker.com/build/exporters/image-registry/

[14] Docker Inc. *Buildx Imagetools Inspect.*  
https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/

[15] Docker Inc. *Multi-Platform Builds.*  
https://docs.docker.com/build/building/multi-platform/

## Archive Transfer

[16] Docker Inc. *Docker Image Save.*  
https://docs.docker.com/reference/cli/docker/image/save/

[17] Docker Inc. *Docker Image Load.*  
https://docs.docker.com/reference/cli/docker/image/load/

## Software Supply Chain

[18] Docker Inc. *Docker Scout.*  
https://docs.docker.com/scout/

[19] Docker Inc. *Build Attestations.*  
https://docs.docker.com/build/metadata/attestations/

[20] Open Container Initiative. *Image Specification.*  
https://github.com/opencontainers/image-spec

[21] Semantic Versioning. *Semantic Versioning Specification.*  
https://semver.org/

## Recommended Reading Sequence

Begin with references [1] through [5] to understand local image references and distribution commands.

Continue with references [6] through [10] to study Docker Hub authentication and repository management.

References [11] and [12] describe local registry deployment and associated security limitations.

References [13] through [15] explain modern image publication, registry manifests, and multi-platform images.

References [16] and [17] provide the alternative archive-based image transfer workflow.

Finally, review references [18] through [21] to connect image distribution with software supply-chain assurance and formal release versioning.

---

# 122. FINAL LECTURE CONCLUSION

The ability to create a Docker image does not complete the application delivery process.

Images must also be identified, stored, transferred, retrieved, and verified.

Container registries provide the distribution infrastructure supporting these activities.

Docker Hub offers a hosted registry service, while organizations may also use cloud-managed or self-hosted registries.

Repositories group related image artifacts.

Namespaces establish logical naming scopes.

Tags provide human-readable version references.

Digests provide content-based artifact identities.

The distinction between tags and digests is especially important.

An image tag may be reassigned to different content.

A content digest identifies a specific object.

Consequently, professional release systems should preserve the relationship between an approved human-readable release and the exact image artifact used for deployment.

Registry authentication and authorization protect image publication and retrieval.

TLS protects registry communication.

Credential management limits the exposure of account secrets.

Image scanning, software bills of materials, and provenance provide additional information about software integrity and supply-chain risk.

The practical laboratory demonstrates the complete release workflow.

The student constructs a tested Python application, publishes an image to a local registry, retrieves that image, and executes it.

A second version is published and deployed.

The application is then rolled back to its earlier release.

These operations demonstrate that application images can be distributed and selected independently of their original build environment.

The laboratory also distinguishes registry storage from local Docker image storage and archive-based transfers.

However, an image release does not contain the complete operational state of a distributed application.

Databases, volumes, secrets, infrastructure configuration, and network dependencies may require independent lifecycle management.

These considerations lead directly to production deployment engineering.

Lecture 19 will examine health monitoring, restart behavior, resource management, persistent data backups, TLS, production configuration, and operational readiness.

---

**END OF LECTURE 18**

**Next Lecture:** Lecture 19 — Docker in Production: Deployment Architecture, Health Monitoring, Restart Policies, Resource Limits, Persistent Data Protection, TLS, Observability, and Operational Readiness.
