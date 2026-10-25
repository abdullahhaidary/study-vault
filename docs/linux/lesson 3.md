# LINUX: FOUNDATIONS, SYSTEM ADMINISTRATION, AND PROFESSIONAL SERVER ENGINEERING

## MAJOR LECTURE 03 — ADVANCED BASH, LINUX INTERNALS, SYSTEM SECURITY, SSH HARDENING, FIREWALLS, NGINX, TLS, MONITORING, TROUBLESHOOTING, AUTOMATION, BACKUPS, AND PRODUCTION SERVER ENGINEERING

**Course:** Linux: Foundations to Professional System Administration  
**Lecture:** 03 of 03 — Final Major Lecture  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, Practical Laboratory, Production Capstone, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 10–14 Hours  
**Recommended Environment:** Ubuntu Server in a dedicated virtual machine  
**Prerequisites:** Major Lectures 01 and 02; basic knowledge of Git and Docker is helpful

**Major Topics:**

1. Advanced Bash Scripting
2. Bash Error Handling, Functions, Parameters, and Traps
3. Linux Kernel Internals, Processes, Memory, and System Calls
4. Namespaces, Cgroups, and Containers
5. Server Security and Least Privilege
6. SSH Hardening and Firewall Administration
7. AppArmor, SELinux, and Systemd Sandboxing
8. Linux Application Deployment
9. Nginx Reverse Proxy and TLS
10. Logging, Monitoring, and Performance Analysis
11. System Troubleshooting and Incident Response
12. System Automation and Scheduled Maintenance
13. Backup Strategies and Disaster Recovery
14. Production Deployment and Rollback
15. Complete Linux Production Server Capstone

---

# PART I — INTRODUCTION TO ADVANCED LINUX

## 1. PURPOSE OF THE LECTURE

In Major Lecture 01, we studied Linux fundamentals.

We learned about the Linux kernel, distributions, the filesystem, terminals, Bash, file management, text processing, and package management.

In Major Lecture 02, we moved into Linux administration.

We studied users, groups, permissions, processes, signals, systemd, networking, SSH, storage, scheduled tasks, and backups.

This final lecture examines how those components work together in a production-oriented Linux environment.

A professional Linux server must do more than run an application.

It must:

- Restrict unauthorized access.
- Execute applications with appropriate privileges.
- Protect sensitive information.
- Expose only necessary network services.
- Manage application processes.
- Record useful operational information.
- Detect failures.
- Recover failed services.
- Control resource usage.
- Apply security updates.
- Preserve application data.
- Support safe deployments.
- Recover from operational mistakes.

These requirements form the foundation of reliable Linux operations.

---

# 2. LEARNING OBJECTIVES

Upon completion of this lecture, the student should be able to:

1. Write reusable Bash scripts.
2. Understand positional arguments and parameters.
3. Use conditionals, loops, functions, and arrays.
4. Explain Bash exit statuses.
5. Handle common script failures.
6. Use traps for cleanup.
7. Explain safe quoting and argument passing.
8. Explain process and kernel boundaries.
9. Inspect information through `/proc`.
10. Explain virtual memory.
11. Understand the page cache.
12. Explain the Out-of-Memory killer.
13. Understand Linux system calls.
14. Inspect processes with tracing tools.
15. Explain namespaces and cgroups.
16. Connect Linux resource controls to Docker.
17. Explain the principle of least privilege.
18. Describe secure SSH administration.
19. Inspect and manage UFW firewall rules.
20. Explain AppArmor and SELinux.
21. Apply systemd service hardening.
22. Deploy an application under a non-root account.
23. Configure an Nginx reverse proxy.
24. Explain HTTP and HTTPS.
25. Explain TLS certificates.
26. Describe automated certificate renewal.
27. Inspect systemd and application logs.
28. Diagnose CPU, memory, and disk problems.
29. Diagnose service and network failures.
30. Explain basic incident response.
31. Configure automated application checks.
32. Create scheduled backups.
33. Verify and restore backup data.
34. Explain recovery point and recovery time objectives.
35. Understand production release and rollback procedures.
36. Complete a Linux server engineering capstone.

---

# PART II — ADVANCED BASH SCRIPTING

## 3. WHY BASH SCRIPTING MATTERS

Linux administrators often repeat the same operations.

Examples include:

- Checking disk usage.
- Restarting a service.
- Backing up data.
- Collecting logs.
- Verifying application health.
- Synchronizing files.
- Preparing deployment directories.

Performing every step manually is time-consuming and increases the possibility of mistakes.

Bash scripting allows multiple operations to be organized into a repeatable process.

A well-written script should be understandable, testable, and safe to rerun.

**Important principle:** Automation should make an operation predictable, not merely shorter.

---

# 4. BASIC BASH SCRIPT STRUCTURE

Example:

```bash
#!/usr/bin/env bash

set -euo pipefail

echo "Starting server check"

date

echo "Server check completed"
```

The first line is the shebang.

The second line enables selected error-detection behavior.

The remaining commands perform the work.

Run a script explicitly with:

```bash
bash script.sh
```

Or, after providing execute permission:

```bash
chmod 700 script.sh
./script.sh
```

The script's behavior depends on its interpreter, environment, and permissions.

---

# 5. BASH VARIABLES

A variable stores a value.

Example:

```bash
APP_NAME="linux-capstone"

echo "$APP_NAME"
```

Variables are useful for avoiding repeated hardcoded values.

Example:

```bash
APP_DIR="$HOME/linux-major-lesson3"

LOG_DIR="$APP_DIR/logs"

BACKUP_DIR="$APP_DIR/backups"
```

If a directory changes, updating one variable can update all commands that use it.

### Important Rule

Quote variable expansions when they represent filenames or other values that must remain single arguments.

---

# 6. POSITIONAL PARAMETERS

A Bash script can receive command-line arguments.

Example script:

```bash
#!/usr/bin/env bash

echo "Script name: $0"
echo "First argument: ${1:-none}"
echo "Second argument: ${2:-none}"
```

Run:

```bash
bash arguments.sh apple banana
```

The positional parameters include:

```text
$0  Script invocation name

$1  First argument

$2  Second argument
```

Other useful parameters include:

```text
$#  Number of positional arguments

$@  All positional arguments

$?  Previous command exit status

$$  Current shell process identifier
```

---

# 7. THE DIFFERENCE BETWEEN "$@" AND "$\*"

When forwarding command-line arguments, use:

```bash
"$@"
```

This preserves each positional parameter as a separate argument.

Example:

```bash
#!/usr/bin/env bash

printf 'Argument: <%s>\n' "$@"
```

If one argument contains spaces, quoted `"$@"` preserves that argument boundary.

The quoted `"$*"` form joins positional parameters into one string.

**Memory principle:** `"$@"` preserves argument boundaries.

---

# 8. DEFAULT PARAMETER VALUES

Bash supports parameter expansion with defaults.

Example:

```bash
PORT="${1:-8765}"
```

If the first argument is unset or empty, the value `8765` is used.

Another form:

```bash
NAME="${NAME:-linux-app}"
```

provides a default environment-independent value.

This is useful for configurable scripts.

---

# 9. CONDITIONAL STATEMENTS

Bash supports `if` statements.

Example:

```bash
#!/usr/bin/env bash

if [[ -f "config.txt" ]]; then
    echo "Configuration exists"
else
    echo "Configuration is missing"
fi
```

The `[[ ... ]]` syntax is a Bash conditional construct.

It supports string comparisons, selected pattern matching, and file tests.

---

# 10. COMMON FILE TESTS

| Test      | Meaning                     |
| --------- | --------------------------- |
| `-f FILE` | Existing regular file       |
| `-d PATH` | Existing directory          |
| `-e PATH` | Existing filesystem entry   |
| `-r FILE` | Readable                    |
| `-w FILE` | Writable                    |
| `-x FILE` | Executable/searchable       |
| `-s FILE` | Exists and has nonzero size |

Example:

```bash
if [[ ! -d "$HOME/backups" ]]; then
    mkdir -p "$HOME/backups"
fi
```

### Important Detail

A file test is a point-in-time observation.

Another process may change the filesystem afterward.

Do not assume that checking a file completely prevents race conditions.

---

# 11. STRING COMPARISONS

Example:

```bash
MODE="production"

if [[ "$MODE" == "production" ]]; then
    echo "Production mode"
fi
```

Other operators include:

```text
!=  Not equal
```

And Bash supports additional string and pattern operations.

When exact text matching is desired, avoid unintentionally introducing regular-expression or pattern behavior.

---

# 12. NUMERIC COMPARISONS

Example:

```bash
COUNT=5

if (( COUNT > 3 )); then
    echo "Count exceeds three"
fi
```

Bash arithmetic evaluation works with integers.

It is not a general floating-point calculation engine.

For more sophisticated numerical processing, another language or utility may be preferable.

---

# 13. FOR LOOPS

A `for` loop repeats operations over a collection of values.

Example:

```bash
for name in alice bob carol; do
    printf 'User: %s\n' "$name"
done
```

Loop over specified files:

```bash
for file in *.txt; do
    [[ -e "$file" ]] || continue
    printf 'Found: %s\n' "$file"
done
```

The file-existence check helps avoid treating an unmatched literal glob as a real file under ordinary Bash settings.

---

# 14. WHILE LOOPS

A `while` loop repeats while its condition succeeds.

Example:

```bash
COUNT=1

while (( COUNT <= 5 )); do
    echo "$COUNT"
    (( COUNT += 1 ))
done
```

The loop stops when its condition becomes false.

### Important Principle

Every loop needs a reliable termination condition unless an intentionally persistent process is required.

---

# 15. READING FILES LINE BY LINE

A useful Bash pattern is:

```bash
while IFS= read -r line || [[ -n "$line" ]]; do
    printf 'Line: %s\n' "$line"
done < tasks.txt
```

### Explanation

`IFS=` helps preserve leading and trailing whitespace.

`read -r` prevents ordinary backslash interpretation.

The extra condition allows processing a final line without a trailing newline.

This is useful for line-oriented text files.

It is not suitable for arbitrary binary data.

---

# 16. BASH FUNCTIONS

Functions organize reusable logic.

Example:

```bash
log_message() {
    local message="$1"
    printf '[INFO] %s\n' "$message"
}

log_message "Application started"
```

`local` makes a variable local to the function in Bash.

Functions make scripts more readable and easier to test.

---

# 17. FUNCTION RETURN VALUES

Bash functions return exit statuses.

Example:

```bash
is_ready() {
    [[ -f "$HOME/ready.flag" ]]
}
```

The function succeeds when the file test succeeds.

For text output, a function can print a value:

```bash
get_version() {
    printf '%s\n' "1.0.0"
}

VERSION="$(get_version)"
```

### Important Distinction

A shell function's return status is not the same thing as a general return value in Python.

---

# 18. BASH ARRAYS

Bash supports indexed arrays.

Example:

```bash
SERVICES=("ssh" "nginx" "cron")

for service in "${SERVICES[@]}"; do
    printf 'Service: %s\n' "$service"
done
```

The quoted array expansion preserves elements as separate words.

This is useful for lists of commands, files, or service names.

---

# 19. BASH EXIT STATUSES

Linux commands conventionally return an exit status.

```text
0        Successful result

Nonzero  Failure or command-specific condition
```

A script can terminate with:

```bash
exit 1
```

Or:

```bash
exit 0
```

The meaning of nonzero values depends on the operation.

For example, `grep` commonly returns 1 when it finds no matching lines.

---

# 20. UNDERSTANDING set -euo pipefail

A common Bash configuration is:

```bash
set -euo pipefail
```

### `-e`

Exits under selected unhandled command-failure conditions.

It has exceptions and should not be treated as a complete error-handling mechanism.

### `-u`

Treats many references to unset variables as errors.

### `pipefail`

Makes a pipeline report a nonzero status when an earlier component fails, according to Bash pipeline rules.

### Important Principle

These settings improve failure visibility, but deliberate validation and error handling remain necessary.

---

# 21. ERROR HANDLING

Example:

```bash
if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required" >&2
    exit 1
fi
```

This verifies that a required utility is available.

Another example:

```bash
if ! curl --fail --silent http://127.0.0.1:8765/healthz; then
    echo "Health check failed" >&2
    exit 1
fi
```

### Important Principle

A useful script reports meaningful failures rather than silently continuing.

---

# 22. WHAT IS A TRAP?

A Bash trap specifies commands to execute when selected signals or shell events occur.

Example:

```bash
cleanup() {
    echo "Cleaning temporary files"
}

trap cleanup EXIT
```

The cleanup function runs when the shell exits.

This is useful for:

- Removing temporary files.
- Stopping temporary processes.
- Releasing locks.
- Restoring temporary state.

---

# 23. SAFE TEMPORARY FILES

Avoid predictable temporary filenames when uniqueness and safety matter.

Use:

```bash
TEMP_FILE="$(mktemp)"
```

Then arrange cleanup:

```bash
trap 'rm -f -- "$TEMP_FILE"' EXIT
```

### Important Qualification

A temporary file's location, permissions, and lifecycle must match the use case.

Do not put sensitive temporary data in an inappropriate shared location.

---

# 24. SCRIPT IDEMPOTENCE

An operation is idempotent when repeating it has the same intended effect as performing it once.

Example:

```bash
mkdir -p "$HOME/reports"
```

Running this multiple times ordinarily leaves the required directory in place.

By contrast:

```bash
echo "New entry" >> report.txt
```

adds another line each time.

### Professional Principle

Deployment and administration scripts should be designed to avoid unnecessary repeated side effects.

---

# PART III — LINUX INTERNALS

## 25. USER SPACE AND KERNEL SPACE

Normal Linux applications execute in user space.

The kernel manages privileged operating-system functions.

```text
              USER SPACE
     +------------------------+
     | Bash                   |
     | Python                 |
     | Nginx                  |
     | PostgreSQL             |
     +------------------------+
                  |
              SYSTEM CALLS
                  |
                  v
             KERNEL SPACE
     +------------------------+
     | Process scheduling     |
     | Virtual memory         |
     | Filesystems            |
     | Network stack          |
     | Device management      |
     +------------------------+
                  |
                  v
               HARDWARE
```

This separation is fundamental to operating-system design.

---

# 26. SYSTEM CALLS

A system call requests a service from the kernel.

Important examples include interfaces for:

- Opening files.
- Reading and writing.
- Process creation.
- Network communication.
- Memory management.
- Filesystem metadata.

Many programming-language libraries eventually rely on these interfaces.

A Python application may call:

```python
with open("tasks.txt", "r") as file:
    text = file.read()
```

The Python runtime uses operating-system interfaces to perform the file operations.

---

# 27. THE /PROC FILESYSTEM

`/proc` exposes process and kernel information through a virtual filesystem.

Examples:

```bash
cat /proc/version
```

```bash
cat /proc/meminfo
```

```bash
cat /proc/loadavg
```

```bash
cat /proc/self/status
```

These entries expose system state through kernel-supported interfaces.

They are not ordinary text documents stored in the same way as application data files.

---

# 28. PROCESS INFORMATION IN /PROC

For a running process:

```text
/proc/PID/
```

contains information associated with that process.

Examples include:

```text
/proc/PID/status

/proc/PID/cmdline

/proc/PID/fd/

/proc/PID/maps
```

Access depends on permissions, system configuration, and process state.

### Important Security Warning

Some process metadata can contain sensitive information.

Do not collect or publish process environment values, memory contents, or command lines indiscriminately.

---

# 29. VIRTUAL MEMORY

Linux processes use virtual address spaces.

Virtual memory provides an abstraction between process memory addresses and underlying physical memory.

Benefits include:

- Process address-space separation.
- Memory protection.
- Flexible mapping.
- Shared memory support.
- Demand paging.
- File-backed memory mappings.

A process's virtual memory size is not the same as its current physical memory consumption.

---

# 30. PHYSICAL MEMORY AND PAGE CACHE

Linux uses RAM for application processes and filesystem caching.

The page cache can improve performance by retaining frequently accessed file data in memory.

This is one reason that a Linux system may report substantial memory usage even when applications are not consuming all of it privately.

Inspect:

```bash
free -h
```

### Important Principle

Do not assume that every byte of used memory represents an application memory leak.

---

# 31. PROCESS MEMORY METRICS

Common terms include:

### RSS

Resident Set Size: memory pages associated with a process that are currently resident in RAM.

### VSZ

Virtual memory size associated with a process.

### Swap

Disk-backed storage that may be used by the virtual memory subsystem.

### Important Qualification

Shared memory complicates simple per-process totals.

Adding RSS values across all processes can double-count shared pages.

---

# 32. SWAP

Swap provides storage space that Linux may use for selected memory pages when managing memory pressure.

Inspect:

```bash
swapon --show
```

And:

```bash
free -h
```

Swap can help with some memory-pressure situations.

However, heavy swapping may cause serious performance degradation.

### Important Principle

Swap is not a substitute for sufficient RAM.

---

# 33. THE OUT-OF-MEMORY KILLER

When memory cannot be allocated under relevant conditions, the kernel may terminate selected processes.

This is commonly called an OOM kill.

Symptoms may include:

- Sudden process termination.
- Unexpected service restarts.
- Kernel messages about killed processes.
- A container exiting due to memory limits.

Investigation may involve:

```bash
journalctl -k -b
```

and, when available:

```bash
oomctl
```

### Important Qualification

OOM behavior can involve global memory pressure or limits associated with a particular cgroup.

Not every process termination is an OOM event.

---

# 34. CPU LOAD

Linux load averages describe runnable and certain waiting tasks over different intervals.

Inspect:

```bash
uptime
```

The familiar intervals are approximately:

- 1 minute.
- 5 minutes.
- 15 minutes.

### Important Distinction

Load average is not the same thing as CPU percentage.

High load can reflect CPU demand or selected forms of uninterruptible waiting.

Interpret load in relation to the system's CPU capacity and workload.

---

# 35. I/O WAIT

Applications may spend time waiting for storage operations.

Symptoms can include:

- Slow file access.
- Delayed database responses.
- Elevated disk latency.
- Processes in uninterruptible sleep.

Useful tools include:

```bash
vmstat 1 5
```

If installed:

```bash
iostat -xz 1 3
```

### Important Principle

A slow application is not necessarily CPU-bound.

Storage, networking, locking, and other dependencies can be responsible.

---

# 36. STRACE

`strace` can observe selected system calls and signals made by a process.

Example:

```bash
strace -o trace.log /bin/true
```

Another useful example:

```bash
strace -e trace=openat cat /etc/hostname
```

The exact system calls displayed depend on the operating-system and executable implementation.

### Important Warning

Tracing another process may require appropriate permissions.

Tracing can affect performance and may expose filenames, data, or other sensitive details.

Use it only on authorized processes.

---

# 37. SYSCTL

`sysctl` inspects or changes selected kernel parameters.

Read a parameter:

```bash
sysctl vm.swappiness
```

Another example:

```bash
sysctl net.ipv4.ip_forward
```

### Important Principle

Kernel parameters influence system behavior.

Do not change kernel tunables merely because a tutorial suggests a number.

Production tuning should begin with an observed problem and measurable objectives.

---

# PART IV — NAMESPACES, CGROUPS, AND DOCKER

## 38. WHAT ARE LINUX NAMESPACES?

Namespaces allow processes to have different views of selected operating-system resources.

Important namespace types include:

- PID.
- Network.
- Mount.
- UTS.
- IPC.
- User.
- Cgroup.
- Time.

Namespaces are an important foundation of Linux container isolation.

---

# 39. PID NAMESPACE

A PID namespace gives processes a particular view of process identifiers.

A process may appear as PID 1 inside a container while having a different PID on the host.

### Memory Principle

**PID namespace = my process view.**

---

# 40. NETWORK NAMESPACE

A network namespace provides a separate network environment.

It can include its own:

- Interfaces.
- Addresses.
- Routing table.
- Loopback interface.
- Network sockets.

This explains why `localhost` is relative to a network namespace.

### Memory Principle

**Network namespace = my network world.**

---

# 41. MOUNT NAMESPACE

A mount namespace controls a process's view of filesystem mounts.

Two applications can see different mount arrangements while sharing the same kernel.

### Memory Principle

**Mount namespace = my filesystem mount view.**

---

# 42. USER NAMESPACE

A user namespace allows UID and GID mappings between different user namespace contexts.

A process appearing as root inside one user namespace does not necessarily have unrestricted root privileges on the host.

This is useful in selected container security and rootless execution models.

---

# 43. WHAT ARE CGROUPS?

Cgroups organize processes and control or account for selected system resources.

Important resource categories include:

- CPU.
- Memory.
- Process count.
- I/O.

Modern Linux distributions commonly use cgroup v2.

Inspect the current cgroup association:

```bash
cat /proc/self/cgroup
```

Where available:

```bash
cat /sys/fs/cgroup/cgroup.controllers
```

### Memory Principle

**Namespaces control what processes see. Cgroups control and measure resource usage.**

---

# 44. SYSTEMD AND CGROUPS

Systemd commonly organizes managed services into cgroups.

Useful inspection tools include:

```bash
systemd-cgls
```

```bash
systemd-cgtop
```

A systemd service can also be configured with resource limits.

Example:

```ini
[Service]
MemoryMax=256M
CPUQuota=50%
TasksMax=100
```

These values are illustrative limits, not universal recommendations.

---

# 45. DOCKER CONNECTION

Docker uses Linux features to run applications in isolated environments.

Containers rely on mechanisms including:

- Namespaces.
- Cgroups.
- Filesystem layers and mounts.
- Process credentials and capabilities.
- Network configuration.

Example:

```bash
docker run --memory 256m --cpus 0.5 nginx:alpine
```

Docker configures the container's resource controls through the relevant runtime and kernel mechanisms.

### Important Principle

Docker is not a replacement for Linux knowledge.

Docker builds on Linux operating-system behavior.

---

# PART V — LINUX SERVER SECURITY

## 46. WHAT IS SERVER HARDENING?

Server hardening is the process of reducing unnecessary exposure and restricting the capabilities of the system.

Common activities include:

- Removing unnecessary services.
- Keeping software updated.
- Restricting user privileges.
- Securing SSH.
- Configuring firewalls.
- Protecting files and secrets.
- Applying mandatory access controls.
- Monitoring changes and failures.
- Creating reliable recovery procedures.

### Important Principle

Security is a combination of controls, not one command.

---

# 47. THE PRINCIPLE OF LEAST PRIVILEGE

Least privilege means granting a user or process only the permissions needed to perform its legitimate task.

For example, a Python web application may need to:

- Read its source code.
- Read selected data.
- Write to one application state directory.
- Bind a local network port.
- Write logs through standard output.

It does not normally need:

- Full root privileges.
- Access to every home directory.
- Permission to modify system binaries.
- Permission to administer storage devices.

### Professional Rule

**Give the application only the access required for its work.**

---

# 48. DEDICATED SERVICE ACCOUNTS

Production applications commonly run under dedicated accounts.

Example:

```text
Account: opsdemo

Purpose: Run one application

Login shell: nologin

Administrative privileges: None
```

The account can own the application's writable data directory.

Application source files can remain owned by root and readable by the application.

This reduces the impact of some application compromises.

---

# 49. FILE PERMISSION HARDENING

Common principles include:

- Keep private keys private.
- Avoid world-writable configuration files.
- Restrict writable application paths.
- Separate code from data.
- Use appropriate file ownership.
- Do not use `chmod 777` as a general solution.

Example:

```bash
chmod 600 private-key-file
```

Appropriate file permissions depend on the account that actually needs access.

---

# 50. AUTOMATIC SECURITY UPDATES

Ubuntu supports unattended package updates through `unattended-upgrades`.

Inspect:

```bash
systemctl list-timers | grep apt
```

Check whether the package is installed:

```bash
dpkg-query -W unattended-upgrades
```

Inspect its configuration when applicable:

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
```

### Important Principle

Updates reduce exposure to known vulnerabilities, but they must be compatible with operational and recovery requirements.

Some changes may require service restarts or reboots.

---

# 51. SECURITY UPDATES VERSUS REBOOTS

Installing a new kernel package does not mean the currently running kernel has automatically changed.

Inspect:

```bash
uname -r
```

Ubuntu systems may indicate that a reboot is needed through:

```text
/var/run/reboot-required
```

Check:

```bash
test -e /var/run/reboot-required && echo "Reboot may be required"
```

A production reboot requires operational planning.

---

# PART VI — SSH HARDENING

## 52. WHY SSH SECURITY MATTERS

SSH is a primary administrative entry point for many Linux servers.

A poorly configured SSH service can expose the system to:

- Password guessing.
- Stolen credentials.
- Excessive privileges.
- Unauthorized administrative access.
- Misconfigured authentication.

SSH security involves both authentication and authorization.

---

# 53. SSH PUBLIC-KEY AUTHENTICATION

A client proves possession of a private key associated with an authorized public key.

The private key remains on the client.

The public key is installed on the authorized server account.

A passphrase helps protect the private key when the local key file is exposed.

### Important Principle

**Public key on the server. Private key stays with the client.**

---

# 54. SSH SERVER CONFIGURATION

On Ubuntu, OpenSSH server configuration may involve:

```text
/etc/ssh/sshd_config
```

and:

```text
/etc/ssh/sshd_config.d/
```

Selected security-related directives include:

```text
PermitRootLogin no

PubkeyAuthentication yes

PasswordAuthentication no
```

### Critical Warning

Do not disable password authentication until a separate, working, authorized key-based login has been verified.

Keep console recovery access and an existing administrative session available when making remote SSH changes.

These directives may also interact with included files, match blocks, and other authentication settings.

---

# 55. VALIDATING SSH CONFIGURATION

Check syntax before reloading:

```bash
sudo /usr/sbin/sshd -t
```

Inspect effective configuration where appropriate:

```bash
sudo /usr/sbin/sshd -T
```

Reload after verifying the intended configuration:

```bash
sudo systemctl reload ssh
```

### Important Principle

A configuration file's contents and the service's effective configuration are not always identical.

---

# 56. SSH HARDENING CHECKLIST

A reasonable administrative review includes:

1. Authorized accounts.
2. Public-key authentication.
3. Root-login policy.
4. Password-authentication policy.
5. SSH host key identity.
6. File ownership and permissions.
7. SSH logs.
8. Firewall restrictions.
9. Account offboarding.
10. Recovery access.

SSH hardening should not be performed blindly on an inaccessible remote machine.

---

# PART VII — FIREWALL ADMINISTRATION

## 57. WHAT IS A FIREWALL?

A firewall filters network traffic according to configured rules.

It can restrict which traffic is allowed to enter or leave a system.

Linux provides kernel packet-filtering mechanisms.

Ubuntu commonly uses UFW as an administrative frontend.

---

# 58. UFW

UFW stands for:

**Uncomplicated Firewall.**

Inspect status:

```bash
sudo ufw status verbose
```

Inspect existing numbered rules:

```bash
sudo ufw status numbered
```

List application profiles:

```bash
sudo ufw app list
```

These inspection commands do not enable or reset the firewall.

---

# 59. FIREWALL RULES

Examples:

Allow SSH on the standard port:

```bash
sudo ufw allow 22/tcp
```

Allow HTTP:

```bash
sudo ufw allow 80/tcp
```

Allow HTTPS:

```bash
sudo ufw allow 443/tcp
```

These are examples, not instructions to expose every port on every machine.

Open only the services needed for the environment.

---

# 60. ENABLING UFW SAFELY

On a dedicated server with console access, the general sequence is:

1. Identify the active SSH port.
2. Review existing firewall and cloud security rules.
3. Add the necessary SSH allow rule.
4. Verify that management access will remain possible.
5. Enable UFW.
6. Test SSH from a separate session.
7. Confirm the intended service ports.

A common command is:

```bash
sudo ufw enable
```

### Critical Warning

Enabling or reconfiguring a firewall can interrupt remote access.

Never assume the SSH server is using port 22.

Do not enable UFW on an important remote server without a tested recovery plan.

---

# 61. LOCAL FIREWALL VERSUS CLOUD FIREWALL

A cloud server may have multiple network control layers.

```text
INTERNET
    |
    v
CLOUD FIREWALL
    |
    v
LINUX HOST FIREWALL
    |
    v
APPLICATION LISTENER
```

Allowing a port in UFW does not necessarily open that port in the cloud provider's firewall.

Likewise, a cloud firewall rule does not replace correct host-level configuration.

---

# 62. FIREWALLS AND DOCKER

Docker may configure host networking and packet-filtering rules for published container ports.

As a result, Docker-published port exposure may not behave exactly as an administrator expects from ordinary UFW input rules.

### Important Principle

Inspect actual container bindings, Docker firewall integration, and external network controls.

Do not assume UFW alone controls every Docker-published port.

---

# PART VIII — APPARMOR, SELINUX, AND SANDBOXING

## 63. DISCRETIONARY ACCESS CONTROL

Traditional Linux file permissions are a form of discretionary access control, or DAC.

The filesystem owner and privileged administrators can influence access permissions according to the system's model.

Examples include:

```bash
chmod
```

```bash
chown
```

And ACL tools.

DAC is an important security layer, but additional restrictions may be needed.

---

# 64. MANDATORY ACCESS CONTROL

Mandatory access control, or MAC, can apply security restrictions independently of ordinary file ownership permissions.

Two important Linux security systems are:

- AppArmor.
- SELinux.

They provide different policy models.

Both are designed to constrain application behavior.

---

# 65. APPARMOR

AppArmor uses profiles to control permitted application behavior.

Ubuntu commonly includes AppArmor.

Inspect:

```bash
sudo aa-status
```

Profiles may be operating in:

- Enforce mode.
- Complain mode.

### Enforce Mode

Policy violations are blocked according to the active rules.

### Complain Mode

Many policy violations are logged instead of blocked, helping policy development and investigation.

### Important Principle

AppArmor augments ordinary permissions.

It does not remove the need for correct application design and least privilege.

---

# 66. SELINUX

SELinux provides mandatory access controls based on security policies and labels.

It is commonly associated with several enterprise Linux environments.

Useful inspection commands, where SELinux is installed, include:

```bash
getenforce
```

```bash
sestatus
```

A permission problem may arise from SELinux policy even when ordinary Unix permissions appear correct.

Do not disable SELinux merely to avoid investigating a policy denial.

---

# 67. SYSTEMD SANDBOXING

Systemd supports several options for reducing service privileges.

Examples include:

```ini
NoNewPrivileges=yes

PrivateTmp=yes

ProtectSystem=strict

ProtectHome=yes
```

These options provide different kinds of restrictions.

### Important Qualification

Some sandboxing features require kernel capabilities and system-manager privileges.

They may not work identically in unprivileged user units or restricted containers.

---

# 68. PROTECTSYSTEM

Example:

```ini
ProtectSystem=strict
```

This makes much of the filesystem hierarchy read-only from the service's perspective, subject to documented exceptions.

A service that needs writable state must receive appropriately scoped access.

Example:

```ini
StateDirectory=opsdemo
```

Systemd can manage the service's state directory and make it writable under the relevant protection settings.

---

# 69. RESOURCE LIMITS IN SYSTEMD

Example:

```ini
MemoryMax=256M

CPUQuota=50%

TasksMax=100
```

These can help limit service resource consumption.

### Important Qualification

Limits are workload-specific.

Setting a memory limit too low may cause legitimate service failures.

Resource controls do not replace application monitoring or capacity planning.

---

# PART IX — PRODUCTION APPLICATION ARCHITECTURE

## 70. BASIC WEB APPLICATION ARCHITECTURE

A common Linux web-server architecture is:

```text
CLIENT
   |
   v
NGINX
   |
   v
APPLICATION PROCESS
   |
   v
APPLICATION DATA
```

Nginx handles incoming HTTP requests and forwards selected requests to the application.

Systemd manages the application process.

Linux permissions restrict application access to the system.

---

# 71. WHAT IS A REVERSE PROXY?

A reverse proxy accepts requests from clients and forwards them to backend servers.

For example:

```text
CLIENT
   |
   | HTTP request
   v
NGINX :8080
   |
   | Proxy request
   v
PYTHON :8765
```

The client communicates with Nginx.

Nginx communicates with the backend application.

---

# 72. WHY USE NGINX?

Nginx can provide:

- Reverse proxying.
- TLS termination.
- HTTP request routing.
- Static content delivery.
- Connection management.
- Selected buffering and caching features.
- Load balancing configurations.

Using a reverse proxy can separate public web-server responsibilities from application logic.

---

# 73. LOCALHOST BINDING

A backend application can listen on:

```text
127.0.0.1:8765
```

This makes it reachable through the host's loopback network interface.

It is not directly bound to every external network interface.

### Important Principle

Bind internal services only to the interfaces they genuinely need.

---

# 74. NGINX PROXY CONFIGURATION

A basic reverse-proxy location can look like:

```nginx
location / {
    proxy_pass http://127.0.0.1:8765;

    proxy_set_header Host $host;

    proxy_set_header X-Real-IP $remote_addr;

    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header X-Forwarded-Proto $scheme;
}
```

This forwards matching requests to the local backend application.

### Important Qualification

An application must not blindly trust forwarded client-address or scheme headers from untrusted clients.

Proxy trust should be configured deliberately.

---

# PART X — HTTP, HTTPS, AND TLS

## 75. HTTP

HTTP is an application-layer protocol used for web communication.

A client makes a request.

A server returns a response.

Example request:

```text
GET /healthz HTTP/1.1
```

Example successful status:

```text
200 OK
```

Other important status codes include:

| Code | General meaning         |
| ---- | ----------------------- |
| 200  | Successful request      |
| 301  | Permanent redirect      |
| 400  | Bad request             |
| 401  | Authentication required |
| 403  | Forbidden               |
| 404  | Not found               |
| 500  | Server-side error       |
| 502  | Bad gateway             |
| 503  | Service unavailable     |
| 504  | Gateway timeout         |

---

# 76. HTTPS

HTTPS is HTTP carried over TLS.

TLS provides mechanisms for:

- Encrypting communication.
- Protecting communication integrity.
- Authenticating the server's identity through certificate validation.

TLS configuration requires certificates and appropriate server settings.

---

# 77. TLS TERMINATION

A reverse proxy can terminate TLS.

Example:

```text
CLIENT
   |
   | HTTPS
   v
NGINX :443
   |
   | HTTP over local loopback
   v
PYTHON :8765
```

This can be appropriate when Nginx and the backend reside on the same trusted host.

For traffic across less-trusted networks, additional protection may be required between proxy and backend.

---

# 78. CERTIFICATES

A TLS certificate associates identifying information with a public key under a certificate authority's trust framework.

The client validates the certificate according to its trust configuration.

A certificate must correspond to the domain or identity used for the connection.

### Important Principle

A valid certificate does not mean the application is free from vulnerabilities.

It primarily supports authenticated encrypted communication.

---

# 79. CERTBOT

Certbot is software that can automate obtaining and renewing suitable publicly trusted certificates.

A common Nginx integration command is:

```bash
sudo certbot --nginx -d YOUR_REAL_DOMAIN
```

This requires:

- An installed and supported Certbot configuration.
- A real domain.
- Correct DNS.
- Suitable network reachability.
- Appropriate server authorization.

### Important Qualification

Do not attempt public certificate issuance for an arbitrary local hostname or placeholder domain.

For the local laboratory, use HTTP restricted to loopback.

---

# 80. CERTIFICATE RENEWAL

Certificates expire.

Automated renewal must be verified.

Where Certbot is configured appropriately:

```bash
sudo certbot renew --dry-run
```

This tests the renewal configuration.

### Important Principle

A working HTTPS connection today does not guarantee it will continue working after certificate expiration.

---

# PART XI — LOGGING AND MONITORING

## 81. WHAT IS MONITORING?

Monitoring collects information about system and application behavior.

Important categories include:

- Availability.
- CPU usage.
- Memory usage.
- Disk space.
- Disk I/O.
- Network connectivity.
- Application errors.
- Request latency.
- Backup status.
- Security events.

Monitoring helps detect problems before or during service disruption.

---

# 82. METRICS, LOGS, AND TRACES

These are different observability concepts.

### Metrics

Numerical measurements over time.

Examples:

```text
CPU usage

Memory usage

HTTP requests per second
```

### Logs

Recorded events.

Examples:

```text
Application started

Request failed

Authentication rejected
```

### Traces

Information describing the path of a request through one or more services.

### Important Principle

Metrics show trends.

Logs describe events.

Traces help explain request execution paths.

---

# 83. JOURNALCTL

On systemd systems:

```bash
journalctl -b
```

shows messages from the current boot.

For a service:

```bash
journalctl -u opsdemo.service
```

Recent messages:

```bash
journalctl -u opsdemo.service -n 50
```

Follow new messages:

```bash
journalctl -u opsdemo.service -f
```

These commands are essential for diagnosing service failures.

---

# 84. KERNEL LOGS

Inspect kernel messages:

```bash
journalctl -k -b
```

Search for selected memory-related messages:

```bash
journalctl -k -b | grep -i "out of memory"
```

### Important Qualification

The absence of a matching message in one log view does not prove that no memory-related event occurred.

Logging configuration, retention, and permissions influence available evidence.

---

# 85. CPU MONITORING

Useful commands:

```bash
top
```

```bash
ps aux --sort=-%cpu
```

```bash
uptime
```

These help identify processes consuming CPU resources.

### Important Principle

High CPU usage is not automatically a malfunction.

A compute-intensive application may legitimately use the available CPU capacity.

---

# 86. MEMORY MONITORING

Useful commands:

```bash
free -h
```

```bash
ps aux --sort=-%mem
```

```bash
cat /proc/meminfo
```

Investigate the relationship between:

- Used memory.
- Available memory.
- Page cache.
- Swap.
- Individual process usage.

---

# 87. STORAGE MONITORING

Useful commands:

```bash
df -h
```

```bash
df -i
```

```bash
du -sh /var/log
```

Where installed:

```bash
iostat -xz 1 3
```

### Important Principle

Storage monitoring should consider space, inodes, performance, and data integrity.

---

# 88. NETWORK MONITORING

Useful commands:

```bash
ip -br addr
```

```bash
ip route
```

```bash
ss -lnt
```

```bash
curl --verbose http://127.0.0.1:8765/healthz
```

For DNS:

```bash
getent hosts example.com
```

These commands investigate different layers of connectivity.

---

# PART XII — PRODUCTION TROUBLESHOOTING

## 89. A STRUCTURED TROUBLESHOOTING METHOD

A reliable troubleshooting procedure is:

1. Identify the exact symptom.
2. Determine the affected component.
3. Check recent changes.
4. Inspect service status.
5. Inspect logs.
6. Check system resources.
7. Test dependencies.
8. Apply the smallest appropriate correction.
9. Verify the result.
10. Record the cause and resolution.

### Important Principle

Do not restart random services or delete files merely because the system behaves unexpectedly.

---

# 90. APPLICATION NOT RESPONDING

Possible causes:

- Application process stopped.
- Incorrect listening port.
- Application startup exception.
- Insufficient permissions.
- Memory exhaustion.
- Missing application data.
- Failed dependency.

Investigation:

```bash
systemctl status opsdemo.service
```

```bash
journalctl -u opsdemo.service -n 50
```

```bash
ss -lnt
```

```bash
curl --fail http://127.0.0.1:8765/healthz
```

---

# 91. NGINX 502 BAD GATEWAY

An Nginx 502 response can occur when the proxy cannot obtain a valid response from the backend.

Possible causes:

- Backend not running.
- Incorrect upstream address.
- Backend refusing connections.
- Backend closing connections unexpectedly.
- Proxy/backend protocol mismatch.

Investigate:

```bash
sudo nginx -t
```

```bash
sudo journalctl -u nginx -n 50
```

```bash
sudo journalctl -u opsdemo.service -n 50
```

```bash
curl --fail http://127.0.0.1:8765/healthz
```

### Important Principle

A 502 error does not automatically mean Nginx itself is broken.

The backend or communication path may be responsible.

---

# 92. NGINX 504 GATEWAY TIMEOUT

A 504 response can indicate that an upstream operation exceeded a relevant timeout.

Possible causes:

- Slow application operation.
- Slow database query.
- Blocked dependency.
- Network delay.
- Insufficient worker capacity.

Do not simply increase timeouts without investigating the underlying latency.

---

# 93. PERMISSION DENIED

Investigate:

```bash
id
```

```bash
ls -ld /opt/opsdemo
```

```bash
ls -l /opt/opsdemo
```

```bash
ls -ld /var/lib/opsdemo
```

If AppArmor is enabled, inspect relevant security denials.

### Important Principle

The correct response is to identify the required permission, not to grant world-wide access.

---

# 94. DISK FULL

Investigate:

```bash
df -h
```

```bash
df -i
```

```bash
sudo du -sh /var/log
```

```bash
sudo du -sh /var/backups
```

Possible causes include:

- Growing logs.
- Backup accumulation.
- Temporary files.
- Database growth.
- Inode exhaustion.

### Important Principle

Before deleting anything, understand whether it is required for normal operation or recovery.

---

# 95. HIGH MEMORY USAGE

Investigate:

```bash
free -h
```

```bash
ps aux --sort=-%mem
```

```bash
journalctl -k -b
```

Consider:

- Application memory demand.
- Page cache.
- Memory leaks.
- Cgroup limits.
- Swap activity.
- OOM events.

A memory limit should be set based on observed workload requirements.

---

# 96. DNS PROBLEMS

A DNS problem may appear as:

```text
Name or service not known
```

or a related resolver error.

Investigate:

```bash
getent hosts example.com
```

```bash
ip route
```

Where appropriate:

```bash
resolvectl status
```

Distinguish DNS failure from a successful resolution followed by a TCP connection failure.

---

# 97. SSH CONNECTION FAILURE

Possible causes include:

- Wrong hostname.
- Wrong port.
- Missing route.
- Firewall restriction.
- SSH service stopped.
- Incorrect private key.
- Authentication failure.
- Account restrictions.

Investigate from the client:

```bash
ssh -v USERNAME@SERVER_ADDRESS
```

Investigate on the server through authorized console access:

```bash
systemctl status ssh
```

```bash
sudo journalctl -u ssh -n 50
```

### Important Principle

Authentication failures and connectivity failures occur at different stages.

---

# PART XIII — INCIDENT RESPONSE

## 98. WHAT IS AN INCIDENT?

An incident is an event affecting the security, availability, integrity, or normal operation of a system.

Examples include:

- Unauthorized access.
- Service outage.
- Data corruption.
- Unexpected privilege changes.
- Storage failure.
- Credential exposure.

A consistent response process reduces the risk of making the situation worse.

---

# 99. BASIC INCIDENT RESPONSE PROCESS

A simplified workflow is:

```text
DETECTION
    |
    v
TRIAGE
    |
    v
CONTAINMENT
    |
    v
INVESTIGATION
    |
    v
RECOVERY
    |
    v
POST-INCIDENT REVIEW
```

### Important Principle

Preserve relevant evidence before making unnecessary destructive changes.

Follow organizational policy for serious security incidents.

---

# 100. POST-INCIDENT ANALYSIS

A useful incident report records:

- What happened.
- When it happened.
- What was affected.
- How the problem was detected.
- The immediate cause, when established.
- Contributing factors.
- Recovery actions.
- Preventive improvements.

### Professional Principle

A successful recovery should improve the system's future reliability.

---

# PART XIV — BACKUP AND RECOVERY ENGINEERING

## 101. BACKUP OBJECTIVES

A backup strategy should define:

- What data is protected.
- How frequently it is copied.
- Where copies are stored.
- How long copies are retained.
- Who can access them.
- How they are restored.
- How restoration is tested.

A scheduled command is only one part of backup engineering.

---

# 102. RPO AND RTO

### Recovery Point Objective

RPO describes the acceptable amount of data loss in time.

Example:

```text
RPO = 1 hour
```

### Recovery Time Objective

RTO describes the desired recovery time.

Example:

```text
RTO = 4 hours
```

These are planning objectives, not guarantees.

A backup schedule must be designed and tested against the application's actual requirements.

---

# 103. THE 3-2-1 BACKUP PRINCIPLE

A familiar backup guideline is:

- Three copies of important data.
- Two different storage media or independent storage systems.
- One copy offsite.

Modern recovery planning may additionally require immutable or offline backups and verified restoration.

### Important Principle

A backup stored only on the same server may be lost when the server or its storage fails.

---

# 104. BACKUP INTEGRITY

A checksum can detect selected unintended changes to backup content.

Example:

```bash
sha256sum backup.tar.gz
```

Write a checksum file:

```bash
sha256sum backup.tar.gz > backup.tar.gz.sha256
```

Verify:

```bash
sha256sum -c backup.tar.gz.sha256
```

### Important Security Qualification

A checksum stored beside the backup can detect accidental corruption.

It is not sufficient by itself to prove authenticity if an attacker can modify both the backup and checksum.

---

# 105. RESTORATION TESTING

A safe restoration exercise should:

1. Select a specific backup.
2. Inspect its contents.
3. Verify integrity.
4. Extract to a separate directory.
5. Compare restored content.
6. Test application behavior using restored data.
7. Record the result.

### Critical Principle

**A backup is valuable only when it can be recovered correctly.**

---

# PART XV — PRODUCTION DEPLOYMENT ENGINEERING

## 106. A RELIABLE DEPLOYMENT

A production deployment should have:

- A known source revision.
- Tested application files.
- Verified dependencies.
- Correct permissions.
- Controlled configuration.
- Health checks.
- A rollback path.
- Logging.
- Backup verification.
- Operational documentation.

---

# 107. DEPLOYMENT VERSUS RELEASE

A release identifies an approved software version or artifact.

A deployment places selected software into an execution environment.

For example:

```text
GIT TAG v1.0.0
      |
      v
RELEASE ARTIFACT
      |
      v
LINUX SERVER DEPLOYMENT
      |
      v
APPLICATION PROCESS
```

A release can exist without being deployed.

A deployment can fail even when the artifact was built successfully.

---

# 108. ROLLBACK

Rollback restores a previous approved state after a problematic deployment.

A rollback strategy may involve:

- Restoring an earlier application artifact.
- Reverting configuration.
- Selecting a previous container image digest.
- Repointing a versioned release directory.
- Restoring compatible data when appropriate.

### Critical Qualification

Application rollback and database rollback are not necessarily the same operation.

Data migrations may make reverting application code more complicated.

---

# PART XVI — COMPLETE FINAL CAPSTONE

## 109. PROJECT TITLE

**Secure Linux Application Server: Bash Automation, Dedicated Service Accounts, Systemd Hardening, Nginx Reverse Proxy, Health Monitoring, Scheduled Backups, and Recovery**

This capstone combines the main concepts from all three Linux lectures.

The project will use:

- Ubuntu Server.
- Python 3.
- Bash.
- Systemd.
- Nginx.
- UFW inspection.
- Journal logging.
- A dedicated application account.
- File permissions.
- Automated backups.
- Independent restoration.

### Important Note

The application is intentionally a small read-only training service.

It does not provide user authentication or database-backed application functionality.

The focus is Linux operations and server administration.

---

# 110. CAPSTONE ARCHITECTURE

```text
                 LOCAL CLIENT
                       |
                       v
                  NGINX :8080
                       |
                       v
                 HTTP PROXY
                       |
                       v
               PYTHON :8765
                       |
                       v
              TASK DATA FILE
                       |
                       v
                /var/lib/opsdemo
                       |
                       v
                BACKUP SCRIPT
                       |
                       v
              /var/backups/opsdemo
```

Systemd manages:

```text
opsdemo.service

opsdemo-backup.service

opsdemo-backup.timer
```

The application itself runs without root privileges.

The administrative installation steps require elevated permissions on the dedicated practice VM.

---

# 111. CAPSTONE REQUIREMENTS

Use:

- A dedicated Ubuntu Server VM.
- An administrator account with sudo access.
- Python 3 installed.
- Bash installed.
- Systemd running as the service manager.
- Nginx installed for the reverse-proxy exercises.
- Curl installed for HTTP checks.
- Sufficient available disk space.
- A VM snapshot or other recovery option before modifying system services.

### Important Safety Rule

Do not run the privileged deployment exercises on an important production server without adapting and reviewing each command.

---

# 112. INITIAL PROJECT STRUCTURE

Create:

```text
linux-major-lesson3/
├── app.py
├── tests/
│   └── test_app.py
├── data/
│   └── tasks.txt
├── scripts/
│   ├── check.sh
│   └── backup.sh
└── backups/
```

Later, system-level files will be installed under:

```text
/opt/opsdemo/

/var/lib/opsdemo/

/var/backups/opsdemo/

/etc/systemd/system/

/etc/nginx/sites-available/
```

---

# 113. APPLICATION SOURCE

Create:

`app.py`

```python
import json
import os

from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


DATA_FILE = Path(
    os.environ.get(
        "DATA_FILE",
        str(Path(__file__).resolve().parent / "data" / "tasks.txt"),
    )
)

APP_RELEASE = os.environ.get("APP_RELEASE", "development")


def read_tasks(path):
    content = Path(path).read_text(encoding="utf-8")

    return [
        line.strip()
        for line in content.splitlines()
        if line.strip()
    ]


def task_summary(path):
    tasks = read_tasks(path)

    return {
        "tasks": tasks,
        "count": len(tasks),
    }


class Handler(BaseHTTPRequestHandler):

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")

        self.send_response(status)

        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )

        self.send_header(
            "Content-Length",
            str(len(body)),
        )

        self.end_headers()

        self.wfile.write(body)

    def do_GET(self):
        path = urlsplit(self.path).path

        if path == "/healthz":
            self.send_json(
                200,
                {"status": "alive"},
            )
            return

        if path == "/readyz":
            try:
                read_tasks(DATA_FILE)

            except (OSError, UnicodeError):
                self.send_json(
                    503,
                    {"status": "not_ready"},
                )
                return

            self.send_json(
                200,
                {"status": "ready"},
            )
            return

        if path == "/api/tasks":
            try:
                result = task_summary(DATA_FILE)

            except (OSError, UnicodeError):
                self.send_json(
                    503,
                    {"error": "Task data unavailable"},
                )
                return

            self.send_json(200, result)
            return

        if path == "/api/info":
            self.send_json(
                200,
                {
                    "application": "opsdemo",
                    "release": APP_RELEASE,
                },
            )
            return

        self.send_json(
            404,
            {"error": "Not found"},
        )


def main():
    host = "127.0.0.1"
    port = int(os.environ.get("PORT", "8765"))

    server = ThreadingHTTPServer(
        (host, port),
        Handler,
    )

    print(
        f"opsdemo listening at {host}:{port}",
        flush=True,
    )

    server.serve_forever()


if __name__ == "__main__":
    main()
```

### Application Features

The application exposes:

```text
GET /healthz

GET /readyz

GET /api/tasks

GET /api/info
```

`/healthz` reports that the process is responding.

`/readyz` checks whether the task data is readable.

`/api/tasks` returns the stored task list.

`/api/info` returns application metadata.

### Important Principle

Liveness and readiness checks answer different questions.

A process may be running while its required data or dependencies are unavailable.

---

# 114. TEST SUITE

Create:

`tests/test_app.py`

```python
import tempfile
import unittest

from pathlib import Path

from app import read_tasks, task_summary


class TaskDataTests(unittest.TestCase):

    def test_read_tasks(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tasks.txt"

            path.write_text(
                "Learn Linux\nPractice Bash\n",
                encoding="utf-8",
            )

            self.assertEqual(
                read_tasks(path),
                ["Learn Linux", "Practice Bash"],
            )

    def test_ignore_blank_lines(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tasks.txt"

            path.write_text(
                "Task A\n\nTask B\n",
                encoding="utf-8",
            )

            self.assertEqual(
                read_tasks(path),
                ["Task A", "Task B"],
            )

    def test_task_count(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tasks.txt"

            path.write_text(
                "A\nB\nC\n",
                encoding="utf-8",
            )

            self.assertEqual(
                task_summary(path)["count"],
                3,
            )

    def test_missing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing.txt"

            with self.assertRaises(FileNotFoundError):
                read_tasks(path)


if __name__ == "__main__":
    unittest.main()
```

These tests exercise the data-processing logic independently of a running HTTP server.

---

# 115. HEALTH CHECK SCRIPT

Create:

`scripts/check.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

URL="${1:-http://127.0.0.1:8765/readyz}"

if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "$URL" >/dev/null; then

    printf 'Health check passed: %s\n' "$URL"

else
    printf 'Health check failed: %s\n' "$URL" >&2
    exit 1
fi
```

This script performs an HTTP readiness check.

It returns a nonzero exit status when the check fails.

---

# 116. BACKUP SCRIPT

Create:

`scripts/backup.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

umask 077

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

SOURCE_DIR="${SOURCE_DIR:-$ROOT/data}"

BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    printf 'Source directory missing: %s\n' "$SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

exec 9>"$BACKUP_DIR/.backup.lock"

if ! flock -n 9; then
    echo "Another backup appears to be running" >&2
    exit 1
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

ARCHIVE="$BACKUP_DIR/data-$STAMP-$$.tar.gz"

TEMP_ARCHIVE="$(
    mktemp --tmpdir="$BACKUP_DIR" ".backup-XXXXXXXX.tar.gz"
)"

cleanup() {
    rm -f -- "$TEMP_ARCHIVE"
}

trap cleanup EXIT

tar -czf "$TEMP_ARCHIVE" \
    -C "$(dirname -- "$SOURCE_DIR")" \
    "$(basename -- "$SOURCE_DIR")"

tar -tzf "$TEMP_ARCHIVE" >/dev/null

mv -- "$TEMP_ARCHIVE" "$ARCHIVE"

sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

printf 'Backup created: %s\n' "$ARCHIVE"
printf 'Checksum created: %s\n' "$ARCHIVE.sha256"
```

### Backup Script Features

- Restrictive umask.
- Configurable source and destination.
- Source-directory validation.
- Locking to prevent concurrent runs.
- Temporary archive creation.
- Archive readability verification.
- SHA-256 checksum.
- Automatic temporary-file cleanup.

### Important Qualification

This is a file-level training backup script.

It does not implement a complete offsite backup strategy, retention policy, encryption system, or database-consistent snapshot mechanism.

---

# PART XVII — CAPSTONE LABORATORY

## 117. EXPERIMENT 1 — VERIFY THE ENVIRONMENT

Execute:

```bash
uname -a
```

```bash
cat /etc/os-release
```

```bash
python3 --version
```

```bash
systemctl --version
```

```bash
command -v curl
```

### Objective

Verify the Linux distribution, Python runtime, systemd, and available tooling.

---

# 118. EXPERIMENT 2 — CREATE THE LOCAL WORKSPACE

Execute:

```bash
mkdir -p "$HOME/linux-major-lesson3"/{data,tests,scripts,backups}
```

Enter:

```bash
cd "$HOME/linux-major-lesson3"
```

Create the files from Sections 113–116.

### Objective

Establish the local project.

---

# 119. EXPERIMENT 3 — CREATE TASK DATA

Execute:

```bash
cat > data/tasks.txt <<'EOF'
Learn advanced Bash
Understand Linux internals
Secure SSH
Configure Nginx
Monitor application health
Test backups
EOF
```

### Objective

Provide application data for the laboratory.

---

# 120. EXPERIMENT 4 — RUN THE TEST SUITE

Execute:

```bash
python3 -m unittest discover -s tests -v
```

### Objective

Verify the task data-processing logic.

All four included tests should pass when the project has been created correctly.

---

# 121. EXPERIMENT 5 — RUN THE APPLICATION LOCALLY

Execute:

```bash
python3 app.py
```

Leave the server running in that terminal.

From another terminal:

```bash
curl --fail http://127.0.0.1:8765/healthz
```

```bash
curl --fail http://127.0.0.1:8765/readyz
```

```bash
curl --fail http://127.0.0.1:8765/api/tasks
```

### Objective

Verify liveness, readiness, and application data.

Stop the server using Ctrl+C when finished.

---

# 122. EXPERIMENT 6 — INSPECT THE PROCESS

While the application is running:

```bash
pgrep -af "python3 app.py"
```

Inspect the listening port:

```bash
ss -lnt
```

Look for:

```text
127.0.0.1:8765
```

### Objective

Connect the running application process with its listening TCP socket.

---

# 123. EXPERIMENT 7 — EXPLORE /PROC

Execute:

```bash
cat /proc/self/status
```

```bash
cat /proc/meminfo
```

```bash
cat /proc/loadavg
```

### Objective

Inspect kernel-provided process and system information.

---

# 124. EXPERIMENT 8 — INSPECT CGROUPS

Execute:

```bash
cat /proc/self/cgroup
```

If available:

```bash
systemd-cgls
```

And:

```bash
systemd-cgtop
```

### Objective

Understand how the system organizes processes into control groups.

---

# 125. EXPERIMENT 9 — PRACTICE BASH PARAMETERS

Create:

`scripts/arguments.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

printf 'Argument count: %s\n' "$#"

for argument in "$@"; do
    printf 'Argument: %s\n' "$argument"
done
```

Execute:

```bash
bash scripts/arguments.sh "hello world" second third
```

### Objective

Demonstrate positional arguments and quoted `"$@"`.

---

# 126. EXPERIMENT 10 — PRACTICE TRAPS

Create:

`scripts/temporary.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

TEMP_FILE="$(mktemp)"

cleanup() {
    rm -f -- "$TEMP_FILE"
    echo "Temporary file cleaned"
}

trap cleanup EXIT

printf 'Temporary data\n' > "$TEMP_FILE"

cat "$TEMP_FILE"
```

Run:

```bash
bash scripts/temporary.sh
```

### Objective

Demonstrate safe temporary-file cleanup.

---

# 127. EXPERIMENT 11 — RUN A LOCAL BACKUP

Execute:

```bash
bash scripts/backup.sh
```

Inspect:

```bash
ls -lah backups
```

### Objective

Create an archive and corresponding checksum.

---

# 128. EXPERIMENT 12 — VERIFY AND RESTORE LOCALLY

Inspect the backup directory:

```bash
ls -1 backups/*.tar.gz
```

Select the created archive:

```bash
ARCHIVE="$(find backups -maxdepth 1 -name '*.tar.gz' -type f | sort | tail -n 1)"
```

Verify:

```bash
sha256sum -c "$ARCHIVE.sha256"
```

Create a restoration directory:

```bash
mkdir -p restore-test
```

Extract:

```bash
tar -xzf "$ARCHIVE" -C restore-test
```

Compare:

```bash
diff data/tasks.txt restore-test/data/tasks.txt
```

### Objective

Verify archive integrity and restored content.

The checksum file generated by this script records the archive path; run the verification from the same project location unless adjusting the stored path.

---

# 129. EXPERIMENT 13 — INSPECT THE FIREWALL

Execute:

```bash
sudo ufw status verbose
```

```bash
sudo ufw app list
```

### Objective

Inspect host firewall state without changing the rules.

### Important Note

Do not enable or reset the firewall in this exercise.

---

# 130. EXPERIMENT 14 — INSPECT SECURITY CONTROLS

Execute:

```bash
sudo aa-status
```

If installed:

```bash
getenforce
```

Inspect current permissions:

```bash
ls -la
```

### Objective

Identify available mandatory access controls and filesystem permissions.

---

# 131. EXPERIMENT 15 — CREATE THE SERVICE ACCOUNT

**Dedicated VM and administrator privileges required.**

Create a system account:

```bash
sudo useradd \
  --system \
  --user-group \
  --home-dir /nonexistent \
  --shell /usr/sbin/nologin \
  opsdemo
```

Inspect:

```bash
id opsdemo
```

### Objective

Create a dedicated non-root application identity.

### Important Qualification

If the account already exists, inspect it rather than blindly recreating it.

This example assumes an isolated training VM without an existing account named `opsdemo`.

---

# 132. EXPERIMENT 16 — INSTALL APPLICATION CODE

Stop the manually running training application first.

Create the deployment directory:

```bash
sudo install -d \
  -o root \
  -g root \
  -m 0755 \
  /opt/opsdemo
```

Install the application:

```bash
sudo install \
  -o root \
  -g root \
  -m 0644 \
  app.py \
  /opt/opsdemo/app.py
```

### Objective

Separate application source code from writable application state.

The service account can read the application code but cannot ordinarily modify the root-owned deployment file.

---

# 133. EXPERIMENT 17 — PREPARE PERSISTENT DATA

Create a state directory:

```bash
sudo install -d \
  -o opsdemo \
  -g opsdemo \
  -m 0750 \
  /var/lib/opsdemo
```

Install the task data:

```bash
sudo install \
  -o opsdemo \
  -g opsdemo \
  -m 0640 \
  data/tasks.txt \
  /var/lib/opsdemo/tasks.txt
```

Inspect:

```bash
sudo ls -l /var/lib/opsdemo
```

### Objective

Give the application account controlled access to its data.

---

# 134. EXPERIMENT 18 — CREATE A HARDENED SYSTEMD SERVICE

Create:

```text
/etc/systemd/system/opsdemo.service
```

Use an authorized editor:

```bash
sudo nano /etc/systemd/system/opsdemo.service
```

Insert:

```ini
[Unit]
Description=Linux Major Lecture 3 Application
After=network.target

[Service]
Type=simple

User=opsdemo
Group=opsdemo

WorkingDirectory=/opt/opsdemo

Environment=DATA_FILE=/var/lib/opsdemo/tasks.txt
Environment=APP_RELEASE=1.0.0
Environment=PORT=8765

ExecStart=/usr/bin/python3 -B /opt/opsdemo/app.py

Restart=on-failure
RestartSec=3

UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes

ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

RestrictSUIDSGID=yes
LockPersonality=yes

CapabilityBoundingSet=
AmbientCapabilities=

StateDirectory=opsdemo
StateDirectoryMode=0750

MemoryMax=256M
TasksMax=100

[Install]
WantedBy=multi-user.target
```

### Explanation

`User` and `Group` select the application identity.

`ExecStart` defines the process to run.

`Restart=on-failure` provides selected automatic recovery behavior.

`ProtectSystem=strict` limits filesystem writes.

`StateDirectory` manages the intended writable application state location.

`NoNewPrivileges` restricts privilege escalation.

`CapabilityBoundingSet=` removes the service's capability bounding set.

`MemoryMax` defines a memory-control limit.

### Important Qualification

This is a training configuration for a small application.

Service hardening must be tested with the actual workload, systemd version, and runtime environment.

---

# 135. EXPERIMENT 19 — START THE SYSTEMD SERVICE

Reload unit definitions:

```bash
sudo systemctl daemon-reload
```

Check the unit file:

```bash
sudo systemd-analyze verify /etc/systemd/system/opsdemo.service
```

Start:

```bash
sudo systemctl start opsdemo.service
```

Inspect:

```bash
systemctl status opsdemo.service
```

Verify:

```bash
curl --fail http://127.0.0.1:8765/readyz
```

### Objective

Run the application as a systemd-managed non-root service.

---

# 136. EXPERIMENT 20 — ENABLE AUTOMATIC STARTUP

Execute:

```bash
sudo systemctl enable opsdemo.service
```

Inspect:

```bash
systemctl is-enabled opsdemo.service
```

### Objective

Configure the service to start through the system's normal boot target relationships.

This does not require rebooting the training machine immediately.

---

# 137. EXPERIMENT 21 — INSPECT SERVICE SECURITY

Inspect the process:

```bash
systemctl show opsdemo.service -p User -p Group -p MainPID
```

Check the unit's hardening assessment:

```bash
sudo systemd-analyze security opsdemo.service
```

### Objective

Inspect the configured service identity and security-related settings.

### Important Qualification

The systemd security score is a diagnostic indicator, not proof that a service is secure.

---

# 138. EXPERIMENT 22 — INSPECT SERVICE LOGS

Execute:

```bash
sudo journalctl -u opsdemo.service -n 50
```

Follow logs:

```bash
sudo journalctl -u opsdemo.service -f
```

From another terminal, request:

```bash
curl --fail http://127.0.0.1:8765/api/tasks
```

### Objective

Observe request-related application output in the service journal.

---

# 139. EXPERIMENT 23 — INSTALL NGINX

**Dedicated VM and administrator privileges required.**

On Ubuntu:

```bash
sudo apt update
```

```bash
sudo apt install nginx
```

Inspect:

```bash
systemctl status nginx
```

### Objective

Install and inspect the reverse-proxy service.

### Important Note

Package installation changes the system.

Perform this on the dedicated practice VM.

---

# 140. EXPERIMENT 24 — CONFIGURE LOCAL NGINX REVERSE PROXY

Create:

```text
/etc/nginx/sites-available/opsdemo-lab
```

Example:

```nginx
server {
    listen 127.0.0.1:8080;

    server_name localhost;

    access_log /var/log/nginx/opsdemo-access.log;
    error_log /var/log/nginx/opsdemo-error.log;

    location / {
        proxy_pass http://127.0.0.1:8765;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
}
```

Save the configuration.

Enable it:

```bash
sudo ln -s \
  /etc/nginx/sites-available/opsdemo-lab \
  /etc/nginx/sites-enabled/opsdemo-lab
```

Check syntax:

```bash
sudo nginx -t
```

Reload:

```bash
sudo systemctl reload nginx
```

### Objective

Create a reverse proxy that listens only on the local interface.

### Important Qualification

Do not recreate the symbolic link if it already exists.

Review any existing Nginx virtual hosts before modifying an important server.

---

# 141. EXPERIMENT 25 — TEST THE REVERSE PROXY

Execute:

```bash
curl --fail http://127.0.0.1:8080/healthz
```

```bash
curl --fail http://127.0.0.1:8080/readyz
```

```bash
curl --fail http://127.0.0.1:8080/api/tasks
```

### Objective

Verify the complete request path:

```text
CURL
  |
  v
NGINX :8080
  |
  v
PYTHON :8765
  |
  v
DATA FILE
```

---

# 142. EXPERIMENT 26 — OBSERVE BACKEND FAILURE

On the dedicated VM:

```bash
sudo systemctl stop opsdemo.service
```

Now request:

```bash
curl -i http://127.0.0.1:8080/healthz
```

The proxy may return a 502 response when it cannot connect to the stopped backend.

Inspect:

```bash
sudo journalctl -u nginx -n 30
```

Restore the backend:

```bash
sudo systemctl start opsdemo.service
```

Verify:

```bash
curl --fail http://127.0.0.1:8080/readyz
```

### Objective

Understand the connection between backend availability and reverse-proxy errors.

---

# 143. EXPERIMENT 27 — TEST SERVICE RESTART BEHAVIOR

Inspect the main PID:

```bash
systemctl show opsdemo.service -p MainPID
```

Request a service restart:

```bash
sudo systemctl restart opsdemo.service
```

Inspect:

```bash
systemctl status opsdemo.service
```

Verify:

```bash
curl --fail http://127.0.0.1:8765/readyz
```

### Objective

Confirm that systemd can stop and start the application cleanly.

---

# 144. EXPERIMENT 28 — INSPECT MEMORY AND CPU USAGE

Execute:

```bash
free -h
```

```bash
ps aux --sort=-%mem | head
```

```bash
ps aux --sort=-%cpu | head
```

```bash
systemd-cgtop
```

### Objective

Observe resource usage associated with the Linux environment and running services.

---

# 145. EXPERIMENT 29 — INSTALL THE BACKUP SCRIPT

**Dedicated VM and administrator privileges required.**

Install the backup script:

```bash
sudo install \
  -o root \
  -g root \
  -m 0750 \
  scripts/backup.sh \
  /usr/local/sbin/opsdemo-backup
```

Create the destination:

```bash
sudo install -d \
  -o root \
  -g root \
  -m 0700 \
  /var/backups/opsdemo
```

### Objective

Prepare an administrator-controlled backup operation.

The backup script will read application state and write root-restricted archives.

---

# 146. EXPERIMENT 30 — CREATE A SYSTEMD BACKUP SERVICE

Create:

```text
/etc/systemd/system/opsdemo-backup.service
```

Content:

```ini
[Unit]
Description=Backup Linux Opsdemo Application Data

[Service]
Type=oneshot

Environment=SOURCE_DIR=/var/lib/opsdemo
Environment=BACKUP_DIR=/var/backups/opsdemo

ExecStart=/usr/local/sbin/opsdemo-backup

UMask=0077
NoNewPrivileges=yes

PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

ReadWritePaths=/var/backups/opsdemo
ReadOnlyPaths=/var/lib/opsdemo
```

### Objective

Define a privileged backup task with restricted filesystem access.

### Important Security Qualification

The backup process runs with root privileges in this example because it is a system-level recovery operation.

The service is deliberately separate from the non-root web application.

---

# 147. EXPERIMENT 31 — CREATE A BACKUP TIMER

Create:

```text
/etc/systemd/system/opsdemo-backup.timer
```

Content:

```ini
[Unit]
Description=Schedule Linux Opsdemo Backup

[Timer]
OnCalendar=*-*-* 02:15:00
Persistent=true
RandomizedDelaySec=15m
Unit=opsdemo-backup.service

[Install]
WantedBy=timers.target
```

Reload:

```bash
sudo systemctl daemon-reload
```

Enable and start the timer:

```bash
sudo systemctl enable --now opsdemo-backup.timer
```

Inspect:

```bash
systemctl list-timers --all
```

### Objective

Schedule automatic backup execution.

### Important Qualification

A daily schedule is only an example.

The correct frequency depends on data-loss requirements and available recovery infrastructure.

---

# 148. EXPERIMENT 32 — RUN A BACKUP MANUALLY

Execute:

```bash
sudo systemctl start opsdemo-backup.service
```

Inspect logs:

```bash
sudo journalctl -u opsdemo-backup.service -n 50
```

List backups:

```bash
sudo ls -lah /var/backups/opsdemo
```

### Objective

Verify that the backup task works before relying on its schedule.

---

# 149. EXPERIMENT 33 — RESTORE TO AN INDEPENDENT LOCATION

Create a separate temporary restoration directory:

```bash
sudo install -d \
  -o root \
  -g root \
  -m 0700 \
  /var/tmp/opsdemo-restore-test
```

Choose an actual backup archive filename displayed in the preceding exercise.

For illustration:

```text
/var/backups/opsdemo/data-YYYYMMDDTHHMMSSZ-PID.tar.gz
```

Verify its checksum:

```bash
sudo sha256sum -c \
  /var/backups/opsdemo/ACTUAL_ARCHIVE_NAME.tar.gz.sha256
```

Inspect archive contents:

```bash
sudo tar -tzf \
  /var/backups/opsdemo/ACTUAL_ARCHIVE_NAME.tar.gz
```

Extract to the separate directory:

```bash
sudo tar -xzf \
  /var/backups/opsdemo/ACTUAL_ARCHIVE_NAME.tar.gz \
  -C /var/tmp/opsdemo-restore-test
```

Compare:

```bash
sudo diff \
  /var/lib/opsdemo/tasks.txt \
  /var/tmp/opsdemo-restore-test/opsdemo/tasks.txt
```

### Objective

Prove that the backup contains recoverable application data.

### Important Qualification

Replace the archive placeholder with its actual filename.

The backup script stores the source directory under the archive's top-level name, which is `opsdemo` for the deployed state directory.

Do not restore directly over the live data during this verification exercise.

---

# 150. EXPERIMENT 34 — TEST THE READINESS CHECK

Temporarily rename the application data file in the dedicated VM:

```bash
sudo mv \
  /var/lib/opsdemo/tasks.txt \
  /var/lib/opsdemo/tasks.txt.training-hidden
```

Request:

```bash
curl -i http://127.0.0.1:8765/readyz
```

The application should return a readiness failure.

Restore the file immediately:

```bash
sudo mv \
  /var/lib/opsdemo/tasks.txt.training-hidden \
  /var/lib/opsdemo/tasks.txt
```

Verify:

```bash
curl --fail http://127.0.0.1:8765/readyz
```

### Objective

Demonstrate that an application can be running but not ready.

### Safety Note

This intentionally creates a temporary failure.

Perform it only in the disposable practice environment.

---

# 151. EXPERIMENT 35 — FINAL SYSTEM INSPECTION

Execute:

```bash
systemctl status opsdemo.service
```

```bash
systemctl status nginx
```

```bash
systemctl status opsdemo-backup.timer
```

```bash
ss -lnt
```

```bash
df -h
```

```bash
free -h
```

```bash
curl --fail http://127.0.0.1:8080/readyz
```

```bash
sudo ls -lah /var/backups/opsdemo
```

### Objective

Verify the complete application and operational environment.

---

# PART XVIII — OPTIONAL PUBLIC SERVER EXTENSION

## 152. PUBLIC DEPLOYMENT REQUIREMENTS

The local laboratory intentionally binds Nginx to:

```text
127.0.0.1:8080
```

A genuine public deployment is different.

It requires:

- An authorized public server.
- A real domain name.
- Appropriate DNS.
- Correct public IP routing.
- Host and cloud firewall rules.
- Controlled SSH access.
- Nginx listening on the intended public interfaces.
- Valid TLS configuration.
- Monitoring and incident response.
- Verified backup arrangements.

Do not expose the training application publicly without completing the necessary security and operational review.

---

# 153. PUBLIC NGINX CONFIGURATION

For an authorized public deployment, an Nginx server block may initially resemble:

```nginx
server {
    listen 80;

    server_name YOUR_REAL_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8765;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Replace the placeholder with a real, controlled domain.

This example describes only the reverse-proxy portion.

Production deployment also requires TLS, access-control decisions, appropriate headers, and application security review.

---

# 154. OPTIONAL TLS CONFIGURATION

On a correctly configured public server with Certbot installed:

```bash
sudo certbot --nginx -d YOUR_REAL_DOMAIN
```

The application must be reachable under an appropriate public domain and must satisfy the certificate authority's validation requirements.

After issuance, inspect HTTPS behavior.

Verify renewal:

```bash
sudo certbot renew --dry-run
```

### Important Principle

A local-only exercise does not need a public TLS certificate.

Use actual domain validation only when deploying to an authorized, properly configured public server.

---

# 155. OPTIONAL FIREWALL REVIEW

Before enabling a firewall on a remote server:

1. Verify the actual SSH port.
2. Ensure authorized remote management remains possible.
3. Review cloud security-group rules.
4. Allow required public application ports.
5. Preserve console recovery access.
6. Test connectivity after applying changes.

Typical public web ports are:

```text
80/tcp

443/tcp
```

The backend application's port should remain restricted to loopback for this architecture.

### Important Security Principle

**Expose the reverse proxy, not the private application listener.**

---

# PART XIX — DEPLOYMENT AND ROLLBACK

## 156. VERSIONED RELEASE DIRECTORIES

A production system may store separate application versions.

Example:

```text
/opt/opsdemo/
├── releases/
│   ├── v1.0.0/
│   └── v1.1.0/
└── current -> releases/v1.1.0
```

The active service can use the `current` symbolic link.

A deployment changes the active release after validation.

This makes it easier to restore a previous application version.

---

# 157. SAFE DEPLOYMENT SEQUENCE

A controlled deployment might follow:

1. Build or obtain an approved artifact.
2. Verify its source identity.
3. Ensure backup requirements are satisfied.
4. Install into a new version directory.
5. Set correct permissions.
6. Test configuration.
7. Update the active release reference.
8. Restart or reload the service as appropriate.
9. Verify readiness.
10. Verify proxy access.
11. Monitor logs.
12. Roll back if required.

### Important Principle

Do not treat a successful file copy as proof that deployment succeeded.

---

# 158. ROLLBACK VERIFICATION

A rollback procedure must be tested before it is urgently needed.

Questions include:

- Is the previous artifact available?
- Is its configuration still valid?
- Are its dependencies available?
- Can it read the current data format?
- Can the service be restarted?
- Can the reverse proxy reach it?
- Are backup and restore procedures available?

### Important Qualification

Some schema or data changes are not automatically reversible.

Application rollback planning must account for data compatibility.

---

# PART XX — COMMON PRODUCTION MISTAKES

## 159. RUNNING EVERYTHING AS ROOT

Incorrect approach:

Run the application with unlimited administrative privileges.

Preferred approach:

Use a dedicated account with only necessary filesystem and process permissions.

---

# 160. EXPOSING INTERNAL PORTS

Incorrect approach:

Bind every backend service to all network interfaces.

Preferred approach:

Bind private services to loopback or a deliberately restricted internal network.

---

# 161. DISABLING SSH PASSWORD AUTHENTICATION TOO EARLY

Incorrect approach:

Disable passwords before verifying key-based access.

Preferred approach:

Verify a separate authorized login and recovery mechanism first.

---

# 162. ENABLING FIREWALLS WITHOUT MANAGEMENT RULES

Incorrect approach:

Enable a restrictive firewall on a remote machine without ensuring SSH remains accessible.

Preferred approach:

Plan authorized management access, verify the necessary rules, and retain console recovery.

---

# 163. USING CHMOD 777 TO FIX ERRORS

Incorrect approach:

Give all users read, write, and execute permissions whenever an application reports "permission denied."

Preferred approach:

Determine the service identity and grant only the required access.

---

# 164. IGNORING SERVICE LOGS

Incorrect approach:

Repeatedly restart a failing service without inspecting why it stopped.

Preferred approach:

Inspect unit status, journal entries, dependencies, permissions, and application logs.

---

# 165. ASSUMING A BACKUP IS VALID WITHOUT RESTORING IT

Incorrect approach:

Consider an archive sufficient merely because the backup command exited successfully.

Preferred approach:

Verify integrity and periodically restore to a separate location.

---

# 166. RESTARTING PRODUCTION SERVICES WITHOUT A PLAN

Incorrect approach:

Modify configuration and restart immediately.

Preferred approach:

Validate configuration, determine service impact, preserve previous known-good state, and verify operation afterward.

---

# PART XXI — MASTER COMMAND REFERENCE

## 167. ADVANCED BASH

| Command or syntax         | Purpose                                    |
| ------------------------- | ------------------------------------------ |
| `"$@"`                    | Preserve positional argument boundaries    |
| `${1:-default}`           | Default parameter value                    |
| `[[ -f FILE ]]`           | Test regular file                          |
| `(( EXPRESSION ))`        | Integer arithmetic evaluation              |
| `for ...; do ...; done`   | Loop                                       |
| `while ...; do ...; done` | Conditional loop                           |
| `local`                   | Function-local variable                    |
| `trap ... EXIT`           | Exit cleanup                               |
| `mktemp`                  | Unique temporary file or directory         |
| `set -euo pipefail`       | Selected Bash error-detection behaviors    |
| `flock`                   | Advisory locking utility                   |
| `shellcheck`              | Optional shell-script static-analysis tool |

---

# 168. LINUX INTERNALS

| Command                 | Purpose                                         |
| ----------------------- | ----------------------------------------------- |
| `cat /proc/meminfo`     | Kernel memory information                       |
| `cat /proc/self/status` | Current process information                     |
| `free -h`               | Memory summary                                  |
| `uptime`                | System uptime and load                          |
| `vmstat`                | Virtual memory statistics                       |
| `iostat`                | Optional I/O statistics                         |
| `strace`                | Trace selected system calls                     |
| `sysctl`                | Inspect/change supported kernel parameters      |
| `lsns`                  | List namespace information                      |
| `systemd-cgls`          | Inspect cgroup hierarchy                        |
| `systemd-cgtop`         | Inspect cgroup resource usage                   |
| `oomctl`                | Inspect OOM-related information where available |

---

# 169. SECURITY

| Command                    | Purpose                                  |
| -------------------------- | ---------------------------------------- |
| `id`                       | Inspect identity                         |
| `chmod`                    | Permission bits                          |
| `chown`                    | File ownership                           |
| `sudo`                     | Authorized privilege escalation          |
| `sshd -t`                  | SSH server configuration syntax check    |
| `sshd -T`                  | Effective SSH configuration output       |
| `ufw status`               | Firewall state                           |
| `ufw status numbered`      | Firewall rules                           |
| `aa-status`                | AppArmor status                          |
| `getenforce`               | SELinux enforcement mode where installed |
| `systemd-analyze security` | Unit hardening assessment                |

---

# 170. NGINX AND APPLICATIONS

| Command                  | Purpose                                |
| ------------------------ | -------------------------------------- |
| `nginx -t`               | Validate Nginx configuration           |
| `systemctl status nginx` | Inspect Nginx                          |
| `systemctl reload nginx` | Reload Nginx configuration             |
| `curl -i URL`            | Inspect HTTP response                  |
| `curl --fail URL`        | Treat HTTP error responses as failures |
| `ss -lnt`                | Inspect TCP listeners                  |
| `journalctl -u UNIT`     | Inspect service logs                   |
| `systemctl restart UNIT` | Restart managed unit                   |
| `systemctl show UNIT`    | Inspect selected service properties    |

---

# 171. BACKUP AND RECOVERY

| Command                     | Purpose                       |
| --------------------------- | ----------------------------- |
| `tar -czf`                  | Create compressed archive     |
| `tar -tzf`                  | Inspect archive entries       |
| `tar -xzf`                  | Extract archive               |
| `sha256sum`                 | Calculate checksum            |
| `sha256sum -c`              | Verify recorded checksums     |
| `rsync -avn`                | Preview synchronization       |
| `rsync -av`                 | Synchronize files             |
| `diff`                      | Compare text files            |
| `systemctl list-timers`     | Inspect scheduled timers      |
| `journalctl -u BACKUP_UNIT` | Inspect backup execution      |
| `df -h`                     | Available filesystem capacity |
| `df -i`                     | Available inodes              |

---

# PART XXII — FORMAL ACADEMIC EXAMINATION

## 172. PART A — DEFINITIONS

Define the following terms:

1. Bash function.
2. Positional parameter.
3. Exit status.
4. Shell trap.
5. Idempotence.
6. Kernel space.
7. User space.
8. System call.
9. Virtual memory.
10. Page cache.
11. RSS.
12. Swap.
13. OOM killer.
14. CPU load average.
15. I/O wait.
16. Namespace.
17. Cgroup.
18. PID namespace.
19. Network namespace.
20. Rootless execution.
21. Least privilege.
22. Server hardening.
23. SSH public key.
24. Firewall.
25. UFW.
26. Mandatory access control.
27. AppArmor.
28. SELinux.
29. Systemd sandboxing.
30. Reverse proxy.
31. TLS.
32. Certificate.
33. Monitoring.
34. Metric.
35. Log.
36. Trace.
37. Health check.
38. Readiness check.
39. Incident response.
40. Recovery Point Objective.
41. Recovery Time Objective.
42. Backup integrity.
43. Release.
44. Deployment.
45. Rollback.

---

# 173. PART B — SHORT-ANSWER QUESTIONS

**Question 1.** Explain why quoting variables matters in Bash scripts.

**Question 2.** Explain how `trap` helps protect temporary resources.

**Question 3.** Describe the limitations of `set -e`.

**Question 4.** Explain why idempotent scripts are useful in operations.

**Question 5.** Describe the relationship between Linux applications and kernel system calls.

**Question 6.** Explain the difference between virtual memory and physical memory.

**Question 7.** Explain why high memory usage does not always indicate a memory leak.

**Question 8.** Describe the purpose of the OOM killer.

**Question 9.** Distinguish namespaces from cgroups.

**Question 10.** Explain how Docker depends on Linux kernel features.

**Question 11.** Explain the principle of least privilege.

**Question 12.** Why should server applications normally avoid root privileges?

**Question 13.** Explain the role of UFW and external cloud firewalls.

**Question 14.** Describe the relationship between AppArmor and ordinary filesystem permissions.

**Question 15.** Explain the purpose of `ProtectSystem=strict`.

**Question 16.** Describe the role of Nginx as a reverse proxy.

**Question 17.** Explain the difference between HTTP and HTTPS.

**Question 18.** Why must certificate renewal be verified?

**Question 19.** Distinguish liveness and readiness checks.

**Question 20.** Explain how journalctl supports troubleshooting.

**Question 21.** Describe a structured response to an Nginx 502 error.

**Question 22.** Explain why service failure does not always mean the service manager is broken.

**Question 23.** Why should backup copies be stored independently from the production server?

**Question 24.** Explain the difference between RPO and RTO.

**Question 25.** Explain why a release and deployment are not the same thing.

---

# 174. PART C — COMMAND INTERPRETATION

Explain:

```bash
set -euo pipefail
```

Explain:

```bash
trap cleanup EXIT
```

Explain:

```bash
cat /proc/self/cgroup
```

Explain:

```bash
sysctl vm.swappiness
```

Explain:

```bash
sudo ufw status verbose
```

Explain:

```bash
sudo /usr/sbin/sshd -t
```

Explain:

```bash
sudo systemd-analyze security opsdemo.service
```

Explain:

```bash
sudo nginx -t
```

Explain:

```bash
curl --fail http://127.0.0.1:8765/readyz
```

Explain:

```bash
sudo journalctl -u opsdemo.service -n 50
```

Explain:

```bash
sha256sum -c backup.tar.gz.sha256
```

Explain:

```bash
sudo systemctl start opsdemo-backup.service
```

---

# 175. PART D — CASE STUDIES

## Case Study 1 — SSH Lockout

An administrator disables password login and can no longer connect.

Describe what should have been verified before changing the configuration and how authorized console recovery may help.

## Case Study 2 — Application Memory Exhaustion

A service repeatedly restarts after reaching its memory limit.

Explain how cgroups, systemd resource limits, logs, and application behavior should be investigated.

## Case Study 3 — Nginx 502 Error

Clients receive HTTP 502 responses.

Explain how to determine whether the backend is running and whether Nginx can reach it.

## Case Study 4 — Application Not Ready

The application's process is running, but its required data file is missing.

Explain why a liveness endpoint may succeed while a readiness endpoint fails.

## Case Study 5 — Security Policy Denial

A process has apparently correct Unix permissions but cannot read a file.

Explain how AppArmor or SELinux could contribute.

## Case Study 6 — Failed Backup

The timer shows that the backup task ran, but the archive is not usable.

Explain the difference between scheduling success, backup completion, archive integrity, and verified restoration.

## Case Study 7 — Failed Deployment

A newly installed application version fails its readiness check.

Describe a controlled rollback procedure.

## Case Study 8 — Public Exposure

A backend application intended for internal use is accidentally reachable from the internet.

Explain how bind addresses, reverse-proxy configuration, host firewalls, and cloud firewalls affect exposure.

---

# PART XXIII — FINAL PRACTICAL EXAMINATION

## 176. ASSESSMENT RUBRIC

| Assessment category                       |   Marks |
| ----------------------------------------- | ------: |
| Advanced Bash scripting                   |      15 |
| Linux internals and resource management   |      10 |
| Security, SSH, and firewall understanding |      15 |
| Systemd service hardening                 |      10 |
| Nginx and HTTP/TLS architecture           |      10 |
| Monitoring and troubleshooting            |      15 |
| Backup and restoration                    |      10 |
| Production deployment and rollback        |      10 |
| Final capstone documentation              |       5 |
| **Total**                                 | **100** |

**Suggested passing standard:** 80/100.

The student should demonstrate conceptual understanding, correct command execution, and safe administrative decision-making.

---

# PART XXIV — INDEPENDENT ACADEMIC ASSIGNMENT

## 177. ASSIGNMENT TITLE

**Secure Linux Server Engineering: Automation, Kernel Internals, Application Deployment, Monitoring, and Disaster Recovery**

Prepare a technical report of approximately 2,500–3,500 words covering:

1. Advanced Bash scripting.
2. Script safety.
3. Error handling.
4. Traps and cleanup.
5. Idempotent automation.
6. Linux kernel architecture.
7. System calls.
8. Virtual memory.
9. Memory pressure.
10. OOM behavior.
11. Namespaces.
12. Cgroups.
13. Linux containers.
14. Server hardening.
15. Least privilege.
16. SSH security.
17. UFW firewall management.
18. AppArmor.
19. SELinux.
20. Systemd sandboxing.
21. Application deployment.
22. Nginx reverse proxy.
23. HTTP and HTTPS.
24. TLS certificates.
25. Certificate renewal.
26. Monitoring.
27. Log investigation.
28. Performance analysis.
29. Troubleshooting procedures.
30. Incident response.
31. Backup integrity.
32. Backup scheduling.
33. Restoration testing.
34. Production deployment.
35. Rollback planning.

Include:

- A Linux kernel architecture diagram.
- A namespace and cgroup comparison diagram.
- A production server network diagram.
- A systemd service architecture.
- An Nginx reverse-proxy configuration.
- A backup-and-recovery workflow.
- The actual Bash scripts.
- Relevant application and systemd logs.
- A successful restore verification.
- A technical security assessment.

---

# PART XXV — COMPLETE LINUX COURSE REVIEW

## 178. MAJOR LECTURE 01 — FUNDAMENTALS

Covered:

- Linux architecture.
- Kernel and distributions.
- Terminal and shell.
- Filesystem hierarchy.
- Files and directories.
- Text processing.
- Bash fundamentals.
- Pipes and redirection.
- Package management.
- Command-line automation.

**Central principle:** Understand and use Linux confidently.

---

# 179. MAJOR LECTURE 02 — SYSTEM ADMINISTRATION

Covered:

- Users and groups.
- UIDs and GIDs.
- Root and sudo.
- File permissions.
- ACLs and umask.
- Processes and signals.
- Systemd.
- Networking.
- DNS and SSH.
- Storage and filesystems.
- Archives and transfers.
- Cron and systemd timers.
- Backups.

**Central principle:** Understand and administer the resources of a Linux system.

---

# 180. MAJOR LECTURE 03 — PRODUCTION ENGINEERING

Covered:

- Advanced Bash.
- Error handling.
- Linux internals.
- Memory and CPU behavior.
- Namespaces and cgroups.
- Server hardening.
- SSH security.
- Firewalls.
- AppArmor and SELinux.
- Systemd sandboxing.
- Nginx.
- TLS.
- Monitoring.
- Troubleshooting.
- Incident response.
- Automated backups.
- Recovery.
- Production deployment and rollback.

**Central principle:** Operate Linux services securely, reliably, and recoverably.

---

# PART XXVI — TEN GOLDEN LINUX PRINCIPLES

## 181. PRINCIPLE 1 — UNDERSTAND THE KERNEL

Applications depend on kernel services for processes, memory, filesystems, and networking.

---

## 182. PRINCIPLE 2 — UNDERSTAND YOUR FILESYSTEM

Know where configuration, application code, runtime state, and logs belong.

---

## 183. PRINCIPLE 3 — USE THE TERMINAL DELIBERATELY

Understand command arguments, quoting, paths, streams, and exit statuses before automating operations.

---

## 184. PRINCIPLE 4 — APPLY LEAST PRIVILEGE

Run applications under appropriately restricted identities.

Avoid unnecessary root access.

---

## 185. PRINCIPLE 5 — MANAGE PROCESSES AS SERVICES

Use appropriate service supervision rather than relying on unmanaged background terminal jobs.

---

## 186. PRINCIPLE 6 — CONTROL NETWORK EXPOSURE

Expose only the intended service interfaces and ports.

Use firewalls and correctly configured bind addresses.

---

## 187. PRINCIPLE 7 — OBSERVE BEFORE CHANGING

Inspect status, logs, processes, network connections, and resources before taking corrective action.

---

## 188. PRINCIPLE 8 — AUTOMATE WITH SAFETY

Write scripts that validate inputs, detect errors, clean temporary resources, and avoid unnecessary repeated side effects.

---

## 189. PRINCIPLE 9 — PLAN FOR FAILURE

Services can stop, disks can fill, configurations can break, and deployments can fail.

Monitoring and recovery procedures are essential.

---

## 190. PRINCIPLE 10 — VERIFY BACKUPS AND DEPLOYMENTS

A backup must be restorable.

A deployment must pass operational verification.

Successful command execution alone does not establish system reliability.

---

# PART XXVII — PROFESSIONAL COMPETENCY CHECKLIST

## 191. FUNDAMENTALS

- [ ] I understand the Linux kernel.
- [ ] I can navigate the filesystem.
- [ ] I can manage files safely.
- [ ] I can inspect and edit configuration files.
- [ ] I understand Bash variables and quoting.
- [ ] I can combine commands using pipelines.
- [ ] I understand Linux package management.

## 192. ADMINISTRATION

- [ ] I understand users and groups.
- [ ] I can interpret permission bits.
- [ ] I understand sudo and root.
- [ ] I can inspect processes.
- [ ] I understand signals.
- [ ] I can manage systemd services.
- [ ] I can inspect journal logs.
- [ ] I understand IP addresses and ports.
- [ ] I can troubleshoot DNS.
- [ ] I understand SSH authentication.
- [ ] I can inspect disks and filesystems.
- [ ] I understand backup scheduling.

## 193. ADVANCED LINUX

- [ ] I can write Bash functions and loops.
- [ ] I understand traps and error handling.
- [ ] I understand virtual memory.
- [ ] I understand the OOM killer.
- [ ] I can inspect `/proc`.
- [ ] I understand namespaces.
- [ ] I understand cgroups.
- [ ] I understand least privilege.
- [ ] I can explain SSH hardening.
- [ ] I can inspect firewall rules.
- [ ] I understand AppArmor and SELinux.
- [ ] I can configure a hardened systemd service.
- [ ] I can configure Nginx as a reverse proxy.
- [ ] I understand TLS certificates.
- [ ] I can inspect system performance.
- [ ] I can troubleshoot a failing service.
- [ ] I can run an automated backup.
- [ ] I can verify backup integrity.
- [ ] I can restore application data.
- [ ] I understand rollback requirements.

---

# PART XXVIII — REFERENCES

## Linux Kernel and Internals

[1] The Linux Kernel Project. _Linux Kernel Documentation._  
https://docs.kernel.org/

[2] Linux Kernel Documentation. _Control Group v2._  
https://docs.kernel.org/admin-guide/cgroup-v2.html

[3] Linux man-pages Project. _Linux Manual Pages._  
https://man7.org/linux/man-pages/

[4] Linux man-pages Project. _Namespaces._  
https://man7.org/linux/man-pages/man7/namespaces.7.html

[5] Linux man-pages Project. _proc._  
https://man7.org/linux/man-pages/man5/proc.5.html

## Bash Scripting

[6] GNU Project. _Bash Reference Manual._  
https://www.gnu.org/software/bash/manual/

[7] GNU Project. _Bash Conditional Constructs._  
https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html

[8] GNU Project. _Bash Shell Parameters._  
https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html

[9] GNU Project. _Bash Traps._  
https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html

## Ubuntu Server Security

[10] Ubuntu. _Ubuntu Server Documentation._  
https://ubuntu.com/server/docs/

[11] Ubuntu. _Security Suggestions._  
https://ubuntu.com/server/docs/explanation/security/security_suggestions/

[12] Ubuntu. _OpenSSH Server._  
https://ubuntu.com/server/docs/how-to/security/openssh-server/

[13] Ubuntu. _Firewall._  
https://ubuntu.com/server/docs/firewalls/

[14] Ubuntu. _AppArmor._  
https://ubuntu.com/server/docs/how-to/security/apparmor/

[15] Ubuntu. _Automatic Updates._  
https://ubuntu.com/server/docs/how-to/software/automatic-updates/

## Systemd

[16] Systemd Project. _systemd.service._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html

[17] Systemd Project. _systemd.exec._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html

[18] Systemd Project. _systemd.resource-control._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html

[19] Systemd Project. _systemd.timer._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html

[20] Systemd Project. _journalctl._  
https://www.freedesktop.org/software/systemd/man/latest/journalctl.html

[21] Systemd Project. _systemd-analyze._  
https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html

## Nginx and TLS

[22] Nginx. _Official Documentation._  
https://nginx.org/en/docs/

[23] Nginx. _Reverse Proxy Administration Guide._  
https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

[24] Certbot. _Official Installation and Configuration Instructions._  
https://certbot.eff.org/instructions

[25] Let's Encrypt. _Documentation._  
https://letsencrypt.org/docs/

## Monitoring and Operations

[26] Linux man-pages Project. _signal._  
https://man7.org/linux/man-pages/man7/signal.7.html

[27] Linux man-pages Project. _sysctl._  
https://man7.org/linux/man-pages/man8/sysctl.8.html

[28] GNU Project. _GNU Tar Manual._  
https://www.gnu.org/software/tar/manual/

[29] Rsync Project. _Rsync Documentation._  
https://rsync.samba.org/

---

# PART XXIX — FINAL COURSE CONCLUSION

## 194. CONCLUSION OF MAJOR LECTURE 03

This lecture completes the study of Linux foundations, system administration, and production-oriented server engineering.

The student has examined advanced Bash scripting, including functions, parameters, loops, conditionals, traps, and error handling.

The lecture has explained the relationship between user-space applications and the Linux kernel.

It has introduced virtual memory, process resource usage, the page cache, system calls, namespaces, cgroups, and the mechanisms underlying container operation.

Security has been examined through least privilege, dedicated service accounts, SSH configuration, firewall rules, file permissions, mandatory access controls, and systemd sandboxing.

Application deployment has been studied using systemd and Nginx.

The lecture has described HTTP communication, reverse proxying, TLS, certificates, and certificate-renewal requirements.

Monitoring and troubleshooting have been presented as structured processes involving service status, logs, process information, resource metrics, and network diagnostics.

Backup engineering has been examined through independent copies, integrity checks, restoration testing, recovery objectives, and scheduled operations.

The final capstone demonstrates how these concepts work together.

A small application is created and tested.

The application is deployed under a dedicated non-root account.

Systemd supervises the process and applies selected restrictions.

Nginx provides a local reverse proxy.

Health and readiness endpoints support operational verification.

Journal logging provides evidence of application behavior.

A scheduled backup service protects the application's state.

Restoration is tested independently from the live application.

These exercises demonstrate that production engineering requires more than installing software and starting a process.

A reliable Linux system must be secured, observed, maintained, and recoverable.

---

# 195. COMPLETION OF THE THREE-LECTURE LINUX COURSE

**Course Title:** Linux: Foundations to Professional System Administration

**Major Lecture 01:** Linux Fundamentals, Terminal, Bash, and Filesystem.

**Major Lecture 02:** Users, Permissions, Processes, Systemd, Networking, SSH, Storage, and Administration.

**Major Lecture 03:** Advanced Bash, Linux Internals, Security, Nginx, Monitoring, Automation, and Production Engineering.

**Total Major Lectures:** 3.

**Final Practical Project:** Secure Linux application server with non-root execution, systemd supervision, Nginx reverse proxy, health checks, scheduled backups, and verified restoration.

**Final Assessment:** 100 Marks.

**Completion Standard:** Demonstrated understanding of the lecture concepts and successful execution of the appropriate laboratory exercises.

---

# 196. FINAL CLOSING STATEMENT

Linux is one of the central foundations of modern software infrastructure.

It provides the operating-system services required by applications, development tools, container platforms, databases, and web servers.

A professional Linux engineer must understand not only how to execute commands but also why the system behaves as it does.

The engineer must be able to identify resource problems, apply appropriate permissions, manage services, control network exposure, protect administrative access, investigate failures, and recover important data.

These responsibilities require sound technical judgment and repeatable procedures.

The three major lectures have provided a structured path through those responsibilities.

Major Lecture 01 established command-line and filesystem competence.

Major Lecture 02 introduced system administration and resource management.

Major Lecture 03 integrated the concepts into secure and recoverable application operations.

Together, these lectures establish a comprehensive foundation for further study in Docker, Kubernetes, cloud infrastructure, infrastructure automation, and Site Reliability Engineering.

**END OF MAJOR LECTURE 03**

**END OF THE COMPLETE LINUX COURSE**

**THREE OF THREE MAJOR LECTURES COVERED.**
