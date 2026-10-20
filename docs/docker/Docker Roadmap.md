# Complete Docker Learning Roadmap — 3 Weeks (21 Days)

If I were your Docker teacher, I would design a 21-day, hands-on course that takes you from an absolute beginner to someone who can confidently use Docker for real development projects.

We wouldn't just watch tutorials or memorize commands. Every day, you'd learn the concepts, practice commands, solve problems, and build something.

| Duration | Daily study | Level |
| --- | --- | --- |
| 21 days | 1.5–2 hours | Beginner → Practical |

**Your learning journey**

| Week | Focus |
| --- | --- |
| Week 1 | Fundamentals |
| Week 2 | Real applications |
| Week 3 | Professional workflows |

## Before starting: What you need

You do not need to know Kubernetes, cloud computing, or DevOps to begin.

You should have:

- A computer running Windows, Linux, or macOS.
- Basic terminal knowledge, such as `cd`, `ls`, and `mkdir`.
- A code editor such as VS Code.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Windows/macOS, or Docker Engine on Linux.
- A GitHub account and a Docker Hub account (useful later).
- Basic understanding of Python, Node.js, or any programming language is helpful but not essential for the first week.

**Study method:** 20–30 minutes of theory, 60–75 minutes of practice, and 15 minutes of review each day.

# Week 1 — Docker Fundamentals

Days 1–7

**Main goal:** Understand Docker, manage containers, work with images, and write your first Dockerfile.

## Day 1 — Introduction to Docker

**Topics to learn**

1. What is Docker?
2. Why was Docker created?
3. Problems Docker solves.
4. What is containerization?
5. Containers vs virtual machines.
6. What is Docker Engine?
7. What is Docker Desktop?
8. Docker architecture: client, daemon, images, and containers.
9. Real-world Docker use cases.

**Practice**

Install Docker and execute:

```bash
docker --version
docker compose version
docker info
docker run --rm hello-world
```

**Homework:** Explain the difference between a container and a virtual machine in your own words.

**Daily result:** You understand what Docker is and can run your first container.

## Day 2 — Docker Containers

**Topics to learn**

1. What is a container?
2. Container lifecycle: created, running, stopped, removed.
3. Foreground vs background containers.
4. Interactive mode and detached mode.
5. Container naming.
6. Port publishing basics.
7. Starting, stopping, and removing containers.

**Commands**

```bash
docker run
docker ps
docker ps -a
docker stop
docker start
docker restart
docker rm
docker logs
```

**Hands-on assignment**

Run an Nginx web server:

```bash
docker run -d \
  --name my-nginx \
  -p 8080:80 \
  nginx:alpine
```

Open `http://localhost:8080` in your browser.

Then stop and start the container yourself.

**Daily result:** You can create, manage, and remove Docker containers.

## Day 3 — Working Inside Containers

**Topics to learn**

1. How to enter a running container.
2. Container filesystems.
3. Running terminal commands inside containers.
4. Inspecting container information.
5. Copying files between the host and a container.
6. Understanding process isolation.
7. Basic troubleshooting.

**Commands**

```bash
docker exec
docker inspect
docker cp
docker top
docker logs
```

**Hands-on assignment**

Enter your running Nginx container:

```bash
docker exec -it my-nginx sh
```

Inside the container, explore its folders, look at environment variables, and find the Nginx HTML directory.

**Daily result:** You can investigate what is happening inside a running container.

## Day 4 — Docker Images and Docker Hub

**Topics to learn**

1. What is a Docker image?
2. Image vs container.
3. Image layers.
4. Image tags and versions.
5. Image IDs and digests.
6. What is Docker Hub?
7. Public vs private repositories.
8. Pulling, inspecting, and removing images.

**Commands**

```bash
docker images
docker pull nginx:alpine
docker image inspect nginx:alpine
docker history nginx:alpine
docker rmi
docker tag
```

**Hands-on assignment:** Download Nginx, Redis, and Alpine images. Compare their sizes and inspect their metadata.

**Daily result:** You understand where images come from, how they are versioned, and how Docker uses them.

## Day 5 — Writing Your First Dockerfile

This is one of the most important days.

**Topics to learn**

1. What is a Dockerfile?
2. Dockerfile syntax.
3. Build context.
4. Base images.
5. `FROM`, `COPY`, and `WORKDIR`.
6. `RUN` vs `CMD`.
7. Building an image.
8. Running your custom image.

**Hands-on assignment**

Create this project structure:

```
my-first-docker-app/
├── Dockerfile
└── index.html
```

Your Dockerfile:

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

Build and run it:

```bash
docker build -t my-website:v1 .
docker run -d -p 8081:80 my-website:v1
```

Visit `http://localhost:8081`.

**Daily result:** You've built and run your first custom Docker image.

## Day 6 — Dockerfile Deep Dive

**Topics to learn**

1. `FROM`
2. `RUN`
3. `COPY`
4. `ADD`
5. `WORKDIR`
6. `CMD`
7. `ENTRYPOINT`
8. `ENV`
9. `ARG`
10. `EXPOSE`
11. `USER`
12. `.dockerignore`
13. Docker build cache.
14. How Dockerfile instruction ordering affects rebuilds.

**Hands-on assignment:** Create a Dockerfile for a simple Python or Node.js application. Rebuild it after making code changes and observe which steps use the cache.

**Daily result:** You can read and write useful Dockerfiles rather than just copying them.

## Day 7 — Week 1 Review + Mini Project

**Mini Project 1: Dockerized Personal Website**

Build a simple HTML/CSS website that runs entirely inside Docker.

- [ ] Create a small website with an HTML page
- [ ] Write a Dockerfile
- [ ] Build and tag a custom image
- [ ] Run the website on port 8080
- [ ] Enter the container and inspect its files
- [ ] Inspect logs and stop/restart the container
- [ ] Remove the container and rebuild it from scratch

At the end of Week 1, you should be able to answer:

- What is the difference between an image and a container?
- Why do we need a Dockerfile?
- What happens when we run `docker build`?
- How do we expose a container's port?
- How do we inspect and troubleshoot a container?

If you can answer those questions and complete the project without following a tutorial step by step, you're ready for Week 2.

# Week 2 — Docker Networking, Storage, and Docker Compose

Days 8–14 | Intermediate foundations

**Main goal:** Learn how Docker containers communicate, store data, and work together as a complete application.

## Day 8 — Docker Ports and Environment Variables

**Topics to learn**

1. How port mapping works.
2. Host ports vs container ports.
3. TCP and UDP basics.
4. `EXPOSE` vs `-p`.
5. Container environment variables.
6. The `-e` option.
7. Using `--env-file`.
8. Why `localhost` inside a container is different from `localhost` on your computer.

**Commands**

```bash
docker run -p 8080:80 nginx:alpine

docker run -e APP_ENV=development alpine env

docker port my-nginx
```

**Hands-on assignment:** Run two separate Nginx containers on ports `8080` and `8081`. Inspect their port mappings and experiment with environment variables.

**Daily result:** You understand how applications running inside containers communicate with the outside world.

## Day 9 — Docker Volumes and Persistent Storage

**Topics to learn**

1. Why container data can disappear.
2. Container writable layers.
3. What is a Docker volume?
4. Named volumes.
5. Anonymous volumes.
6. Bind mounts.
7. Named volumes vs bind mounts.
8. Data persistence.
9. Volume inspection and cleanup.
10. Basics of backing up persistent data.

**Commands**

```bash
docker volume ls
docker volume create my-data
docker volume inspect my-data
docker volume rm my-data
```

**Hands-on assignment:** Run a Redis container with a named volume and persistence enabled. Save a key, remove the container, recreate it using the same volume, and check that the key is still available.

> **Important:** Removing a container is not the same as deleting its volume. Avoid destructive cleanup commands until you understand which data they remove.

**Daily result:** You can preserve important application data across container replacements.

## Day 10 — Docker Networking

**Topics to learn**

1. Docker networking architecture.
2. Bridge networking.
3. Host networking.
4. None networking.
5. Default vs user-defined bridge networks.
6. Internal container DNS.
7. Container-to-container communication.
8. Connecting containers to networks.
9. Inspecting networks.
10. Network isolation.

**Commands**

```bash
docker network ls
docker network create app-network
docker network inspect app-network
docker network connect
docker network disconnect
docker network rm
```

**Hands-on assignment:** Create a custom bridge network. Start a Redis container attached to that network, then connect to it from another container using its name rather than its IP address.

**Daily result:** You understand container networking and service discovery.

## Day 11 — Introduction to Docker Compose

**Topics to learn**

1. What is Docker Compose?
2. Why Compose is useful.
3. Single-container vs multi-container applications.
4. YAML fundamentals.
5. The `compose.yaml` file.
6. Services.
7. Images and builds.
8. Ports.
9. Networks.
10. Volumes.
11. Environment variables.
12. Running and stopping a Compose project.

**Example**

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"

  redis:
    image: redis:alpine
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```

**Commands**

```bash
docker compose up -d
docker compose ps
docker compose logs
docker compose stop
docker compose down
```

**Hands-on assignment:** Create the Compose file above and start both services with a single command.

**Daily result:** You can define and manage multiple containers using one configuration file.

## Day 12 — Building a Multi-Container Application

**Topics to learn**

1. Application architecture in Docker.
2. Application container vs database container.
3. Service naming.
4. Internal communication.
5. Connection configuration.
6. Persistent application data.
7. Managing several services as one project.
8. Container dependencies.

**Hands-on assignment: Python + Redis**

Create a small Flask application that records how many times a webpage has been visited. Redis stores the visit counter.

**Your application architecture**

```text
Browser → Flask Container, web application (localhost:8000)
Flask Container → Redis Container, stores counter data
Redis Container → Persistent Volume
```

You can follow Docker's official [Compose Quickstart](https://docs.docker.com/compose/gettingstarted/) for this assignment.

**Daily result:** You can run an application with multiple connected services.

## Day 13 — Advanced Docker Compose Features

**Topics to learn**

1. `depends_on`.
2. Health checks.
3. Service readiness.
4. Restart policies.
5. `.env` files.
6. Compose variable interpolation.
7. Development bind mounts.
8. Compose Watch.
9. Multiple Compose files.
10. Debugging services through Compose.

**Commands**

```bash
docker compose config
docker compose up --build -d
docker compose logs -f
docker compose exec web sh
docker compose down
```

**Hands-on assignment:** Extend yesterday's Flask + Redis project. Add a Redis health check, service dependencies, a named volume, and live development support.

**Daily result:** You can configure a more reliable and developer-friendly Compose environment.

## Day 14 — Week 2 Review + Project

**Mini Project 2: Multi-Container Web Application**

Create a complete application with a web service and a data service.

**Project requirements**

- [ ] Create a working Python Flask application.
- [ ] Create an application Dockerfile.
- [ ] Configure Redis as a separate service.
- [ ] Create a `compose.yaml` file.
- [ ] Configure container networking.
- [ ] Add a named volume for Redis.
- [ ] Pass environment variables to the application.
- [ ] Start the whole application with one command.
- [ ] Inspect logs and solve at least one intentionally introduced error.
- [ ] Recreate the containers and verify that persistent data survives.

Your target command:

```bash
docker compose up -d --build
```

After that, the whole application should be running.

By the end of Week 2, you should understand Docker Compose, persistent storage, and communication between services.

# Week 3 — Advanced Docker, Best Practices, and Real-World Usage

Days 15–21 | Practical professional workflows

**Main goal:** Build efficient and secure images, troubleshoot Docker problems, publish images, and complete a project that demonstrates your skills.

## Day 15 — Docker Image Optimization

**Topics to learn**

1. Docker image size.
2. Image layers.
3. Build caching.
4. Layer ordering.
5. Multi-stage builds.
6. Choosing a base image.
7. `.dockerignore` best practices.
8. Avoiding unnecessary files.
9. BuildKit fundamentals.
10. Comparing build performance.

**Commands**

```bash
docker image ls
docker history my-website:v1
docker build -t my-app:optimized .
docker image inspect my-app:optimized
```

**Hands-on assignment:** Build one normal Docker image and one optimized version of the same application. Compare their sizes and rebuild times.

**Daily result:** You can write more efficient Dockerfiles using techniques such as multi-stage builds.

## Day 16 — Docker Security Best Practices

**Topics to learn**

1. Why container security matters.
2. Running processes as a non-root user.
3. Understanding the `USER` instruction.
4. Safe base image selection.
5. Image vulnerability scanning.
6. Handling environment variables securely.
7. Secrets vs build arguments.
8. Build-time secrets.
9. Minimizing container privileges.
10. Keeping dependencies updated.
11. Understanding image provenance.
12. Avoiding credentials inside images.

**Hands-on assignment:** Take an existing Dockerfile, configure a non-root user, remove unnecessary dependencies, and inspect its security posture.

Optional: explore Docker Scout for image vulnerability analysis.

**Daily result:** You understand important security practices and can improve a container image's security.

## Day 17 — Docker Debugging and Troubleshooting

**Topics to learn**

1. Containers exiting unexpectedly.
2. Reading logs.
3. Diagnosing application startup failures.
4. Port conflicts.
5. Networking failures.
6. File permission errors.
7. Volume mounting issues.
8. Inspecting container metadata.
9. CPU and memory monitoring.
10. Container events.
11. Troubleshooting unhealthy services.
12. Understanding exit codes.

**Commands**

```bash
docker logs --tail 50 my-nginx
docker inspect my-nginx
docker stats
docker events
docker compose ps
docker compose logs -f
```

**Hands-on assignment:** Intentionally break your application in three ways: use an incorrect port, misconfigure a Redis hostname, and introduce an invalid startup command. Diagnose and fix each error.

**Daily result:** You have a repeatable process for troubleshooting Docker problems.

## Day 18 — Docker Hub and Image Registries

**Topics to learn**

1. What is an image registry?
2. Docker Hub.
3. Public and private repositories.
4. Logging in to a registry.
5. Image naming conventions.
6. Semantic version tags.
7. Image digests.
8. Pushing and pulling images.
9. Image distribution.
10. Basic release management.

**Commands**

```bash
docker login

docker tag my-website:v1 \
  YOUR_USERNAME/my-website:v1

docker push YOUR_USERNAME/my-website:v1

docker pull YOUR_USERNAME/my-website:v1
```

Replace `YOUR_USERNAME` with your own Docker Hub username.

**Hands-on assignment:** Build an application image, push it to your Docker Hub repository, remove your local copy, and pull it again.

**Daily result:** You know how to share and distribute containerized applications.

## Day 19 — Docker in Production Environments

**Topics to learn**

1. Development vs production.
2. Container restart policies.
3. CPU and memory limits.
4. Health checks.
5. Persistent storage strategies.
6. Backup and restoration concepts.
7. Container logging.
8. Monitoring and observability.
9. Secrets and configuration.
10. Exposing services safely.
11. Reverse proxies and HTTPS concepts.
12. Image version pinning and updates.
13. Avoiding data loss during deployment.

**Hands-on assignment:** Configure resource limits, a restart policy, and a health check for your application. Practice restarting services while preserving important data.

**Daily result:** You understand the main operational considerations involved in running containerized applications.

> **Note:** Learning these practices does not automatically make an application production-ready. Production deployments also require server security, backups, monitoring, TLS, and recovery planning.

## Day 20 — Docker with CI/CD and GitHub Actions

**Topics to learn**

1. What is CI/CD?
2. Why Docker is useful in automation.
3. CI vs CD.
4. GitHub Actions fundamentals.
5. Automated Docker builds.
6. Running tests before publishing.
7. Image tagging in pipelines.
8. Docker registry authentication.
9. Publishing images automatically.
10. Introduction to deployment pipelines.

**Hands-on assignment:** Create a GitHub repository for your application and configure a GitHub Actions workflow that builds its Docker image automatically when you push changes.

For an extra challenge, configure publishing to Docker Hub using securely stored credentials.

Official learning reference: [Docker with GitHub Actions](https://docs.docker.com/build/ci/github-actions/).

**Daily result:** You understand how Docker fits into automated software delivery.

## Day 21 — Final Docker Capstone Project

**Final Project: Dockerized Task Manager**

Your end-of-course practical assessment.

Build a small task management application, or use an existing starter app so you can concentrate on Docker.

**Suggested project architecture**

```text
User's Browser → Nginx (optional reverse proxy)
Nginx → Flask / Node.js (application backend)
Flask / Node.js → PostgreSQL (database)
PostgreSQL → Docker Volume
```

**Project deliverables**

- [ ] Application source code or a documented starter application.
- [ ] Well-structured Dockerfile.
- [ ] `.dockerignore`.
- [ ] `compose.yaml`.
- [ ] Environment configuration and `.env.example`.
- [ ] Separate database and application services.
- [ ] Working Docker networking.
- [ ] Persistent database storage.
- [ ] Health checks and appropriate restart policies.
- [ ] Application logs that can be inspected.
- [ ] An image published to Docker Hub.
- [ ] A GitHub repository with setup instructions.
- [ ] A successful rebuild and restart from scratch.

You can start building this capstone during Days 17–20 and reserve Day 21 for final integration and testing. Nginx and CI publishing are stretch goals if you're new to programming.

## Docker commands you should know by the end of 3 weeks

Use this as your quick-reference sheet.

| Category | Essential commands |
| --- | --- |
| Information | `docker version`, `docker info` |
| Containers | `run`, `ps`, `stop`, `start`, `restart`, `rm` |
| Inspection | `logs`, `exec`, `inspect`, `stats`, `top` |
| Images | `images`, `pull`, `build`, `tag`, `push`, `rmi` |
| Networks | `network ls`, `network create`, `network inspect`, `network rm` |
| Volumes | `volume ls`, `volume create`, `volume inspect`, `volume rm` |
| Compose | `compose up`, `down`, `ps`, `logs`, `exec`, `config` |
| Cleanup | `container prune`, `image prune`, `system df` |

These commands are prefixed with `docker`, so `images` means `docker images`.

## Recommended free learning resources

1. [Docker Official Get Started](https://docs.docker.com/get-started/) — the best primary reference for core concepts, installation, Dockerfiles, and container management.
2. [Play with Docker](https://labs.play-with-docker.com/) — a browser-based practice environment for experimenting with Docker commands, subject to service availability.
3. [Official Getting Started Lab](https://docs.docker.com/guides/lab-container-getting-started/) — practice containers, Dockerfiles, image building, and running your own apps with guided exercises.

## How I would test your learning

At the end of the three weeks, I would assess you on these five areas. **Target score: 80+ out of 100.**

| Area | What you should be able to do | Score |
| --- | --- | --- |
| Container management | Run, inspect, stop and troubleshoot containers | __ / 20 |
| Dockerfiles and images | Build and optimize custom application images | __ / 20 |
| Networks and volumes | Connect services and preserve data | __ / 20 |
| Docker Compose | Run and configure a multi-container application | __ / 20 |
| Final project | Document, test and publish your project | __ / 20 |

Give yourself 0, 5, 10, 15, or 20 points per area according to how independently you can complete it.

## What to learn after these three weeks

Once you've mastered Docker fundamentals, the next topics I'd recommend are:

1. **Linux:** Processes, permissions, networking, services, and shell scripting.
2. **Docker deeper concepts:** Buildx, multi-platform images, advanced Compose, registries, and rootless Docker.
3. **CI/CD:** GitHub Actions, automated testing, and image release pipelines.
4. **Cloud deployment:** Deploying containers to a VPS, AWS, Azure, or Google Cloud.
5. **Kubernetes:** Pods, Deployments, Services, ConfigMaps, Secrets, and persistent volumes.
6. **Monitoring:** Prometheus, Grafana, logging, and observability.

## My teaching rule for your 21 days

Don't move from one day to the next just because you finished watching a video. Move on when you can explain the concept and do the assignment yourself.

Aim for 70% hands-on practice and 30% theory. Keep a notebook of Docker commands, error messages, and how you solved them.

After three weeks, you won't know everything about Docker, but you should be able to containerize an application, connect it to other services, preserve its data, troubleshoot common failures, and share its image.

That's the practical foundation I'd want every beginner to have before moving on to Kubernetes or more advanced DevOps work.
