# LINUX: FOUNDATIONS, SYSTEM ADMINISTRATION, AND PROFESSIONAL SERVER ENGINEERING

## MAJOR LECTURE 02 — LINUX USERS, PERMISSIONS, PROCESSES, SYSTEMD, NETWORKING, SSH, STORAGE, FILESYSTEMS, SCHEDULING, AND BACKUP ADMINISTRATION

**Course:** Linux: Foundations to Professional System Administration  
**Lecture:** 02 of 03  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, Practical Laboratory, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 9–12 Hours  
**Recommended Environment:** Ubuntu Server installed in a dedicated virtual machine  
**Prerequisites:** Major Lecture 01 — Linux Fundamentals, Terminal, Bash, and Filesystem

**Major Topics:**

1. Linux Users, Groups, and Administrative Privileges
2. File Ownership, Permissions, ACLs, and Umask
3. Linux Processes, Signals, and Job Control
4. Systemd Services and Journal Logging
5. Linux Networking, TCP/IP, DNS, and Routing
6. SSH and Secure Remote Administration
7. Linux Storage, Partitions, Filesystems, and Mounting
8. LVM and Disk Usage
9. Archives, Compression, and File Transfers
10. Cron and Systemd Timers
11. Backup, Restoration, and Administrative Troubleshooting
12. Complete Linux Server Administration Laboratory

---

# PART I — INTRODUCTION TO LINUX ADMINISTRATION

## 1. PURPOSE OF THE LECTURE

In Major Lecture 01, we studied Linux fundamentals.

We learned what the Linux kernel does, how a terminal interacts with a shell, how files are organized, and how Bash commands can process information.

We also learned how to create directories, inspect files, search logs, use redirection, and construct simple Bash scripts.

These are essential foundations.

However, a Linux system administrator has responsibilities beyond ordinary command-line usage.

Consider a company operating an Ubuntu server.

Several developers require access to the machine.

An application must run continuously.

The application needs permission to read its configuration but should not be allowed to modify unrelated system files.

Other computers must communicate with the server over the network.

The administrator must determine which ports are listening, monitor running processes, manage persistent storage, and preserve important data.

The administrator must also investigate service failures and arrange for scheduled maintenance operations.

These responsibilities introduce several core concepts:

- User identities.
- Groups.
- File permissions.
- Administrative privileges.
- Processes.
- Signals.
- Services.
- Network interfaces.
- IP addresses.
- DNS.
- Routing.
- SSH.
- Disks.
- Filesystems.
- Mount points.
- Scheduled tasks.
- Backups.

This lecture explains how these components operate individually and how they work together in a complete Linux system.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Explain Linux user accounts.
2. Distinguish users from groups.
3. Explain UID and GID values.
4. Explain the root account.
5. Explain the purpose of sudo.
6. Inspect user identities.
7. Understand `/etc/passwd`, `/etc/group`, and `/etc/shadow`.
8. Create and manage users on an authorized system.
9. Explain primary and supplementary groups.
10. Understand Unix file ownership.
11. Interpret rwx permissions.
12. Explain numeric chmod notation.
13. Explain directory permissions.
14. Use chmod and chown appropriately.
15. Explain umask.
16. Understand ACLs.
17. Explain special permission bits.
18. Define a Linux process.
19. Explain PIDs and PPIDs.
20. Inspect running processes.
21. Explain Linux process states.
22. Use process signals.
23. Explain foreground and background jobs.
24. Explain systemd.
25. Understand systemd units.
26. Manage application services.
27. Inspect service logs.
28. Create a user-managed systemd service.
29. Explain network interfaces.
30. Understand IP addressing and CIDR notation.
31. Explain TCP and UDP.
32. Understand ports and listening sockets.
33. Explain routing and gateways.
34. Explain DNS resolution.
35. Diagnose basic connectivity problems.
36. Explain SSH authentication.
37. Connect to an authorized remote system.
38. Explain Linux storage devices.
39. Understand partitions and filesystems.
40. Distinguish disk space from inode availability.
41. Explain mount points.
42. Understand `/etc/fstab`.
43. Explain LVM architecture.
44. Create and inspect compressed archives.
45. Explain rsync and scp.
46. Understand cron schedules.
47. Understand systemd timers.
48. Create and verify backups.
49. Restore files into an independent location.
50. Complete an integrated Linux administration project.

---

# PART II — USERS, GROUPS, AND IDENTITY

## 3. WHAT IS A LINUX USER?

A Linux user is an identity recognized by the operating system.

Users are associated with numeric user identifiers called UIDs.

User identities help the operating system determine which processes and files belong to which accounts and what access those processes should have.

Linux users can represent:

- Human administrators.
- Software developers.
- Application service accounts.
- System services.
- Automated tasks.

A Linux user does not necessarily represent a person.

For example, a web server may operate using a dedicated service account.

---

# 4. WHAT IS A UID?

UID stands for:

**User Identifier.**

A UID is a numeric value associated with a user identity.

Example:

```text
Username: developer
UID: 1000
```

The exact UID depends on the system.

Linux primarily uses numeric identities internally.

Human-readable usernames are mapped to those identities through system account databases.

### Important Principle

A username is a readable label.

A UID is the numeric identity used by the operating system.

---

# 5. WHAT IS A GROUP?

A group is a collection of user identities used to organize access.

For example:

```text
developers
```

may contain several accounts.

A shared group can help authorize access to selected files and directories without granting every user full administrative privileges.

### Example

```text
GROUP: developers

MEMBERS:
  alice
  bob
  carol
```

Groups help administrators manage permissions across multiple accounts.

---

# 6. WHAT IS A GID?

GID stands for:

**Group Identifier.**

Like a UID, a GID is a numeric identity.

Example:

```text
Group: developers
GID: 1005
```

The numeric value is illustrative.

### Important Principle

**UID identifies a user. GID identifies a group.**

---

# 7. PRIMARY AND SUPPLEMENTARY GROUPS

A user has a primary group and may belong to supplementary groups.

Example:

```text
User: alice

Primary group:
  alice

Supplementary groups:
  developers
  docker
```

The primary group commonly determines the initial group ownership of newly created files, subject to directory settings and filesystem behavior.

Supplementary groups provide additional group-based access.

### Important Security Detail

Membership in powerful groups can provide elevated capabilities.

For example, access to the Docker daemon through the conventional Docker group can effectively provide root-level control over the host in many installations.

Group membership must therefore be reviewed carefully.

---

# 8. INSPECTING USER IDENTITY

Display the current username:

```bash
whoami
```

Display detailed identity information:

```bash
id
```

Example output:

```text
uid=1000(student) gid=1000(student) groups=1000(student),27(sudo)
```

The exact output varies by system.

Display group memberships:

```bash
groups
```

Inspect another account when available:

```bash
id USERNAME
```

These commands are fundamental tools for Linux permission troubleshooting.

---

# 9. THE ROOT USER

The root account is the traditional superuser account.

Its UID is:

```text
0
```

Root has extensive administrative privileges.

Root can ordinarily:

- Manage system users.
- Change file ownership.
- Install system software.
- Configure system services.
- Modify protected configuration.
- Perform privileged storage operations.
- Configure network resources.

### Critical Principle

Root privileges are powerful and must be used deliberately.

Ordinary application and development tasks should not automatically run as root.

---

# 10. WHAT IS SUDO?

`sudo` allows an authorized user to execute selected commands with another user's privileges, commonly root.

Example:

```bash
sudo systemctl status ssh
```

Whether the command succeeds depends on the user's sudo permissions and the system configuration.

### Important Distinction

`sudo` is not the same thing as logging in permanently as root.

It provides controlled privilege escalation for individual operations.

### Security Principle

**Use administrative privileges only when necessary.**

---

# 11. THE SUDO GROUP

On Ubuntu, membership in the `sudo` group commonly provides permission to execute administrative commands according to the system's sudo configuration.

Inspect your groups:

```bash
groups
```

Inspect the sudo group:

```bash
getent group sudo
```

### Important Qualification

Other distributions may configure administrative authorization differently.

The presence of a group named `sudo` does not establish a universal Linux rule.

---

# 12. THE /ETC/PASSWD FILE

Linux systems traditionally store local account information in:

```text
/etc/passwd
```

Example entry:

```text
student:x:1000:1000:Linux Student:/home/student:/bin/bash
```

The fields describe information such as:

1. Username.
2. Password placeholder.
3. UID.
4. Primary GID.
5. Comment or descriptive field.
6. Home directory.
7. Login shell.

Modern systems generally do not store ordinary user password hashes directly in `/etc/passwd`.

---

# 13. THE /ETC/SHADOW FILE

`/etc/shadow` stores sensitive local authentication and password-aging information.

It is normally protected from ordinary users.

It may contain password hashes, aging fields, and account-related authentication settings.

### Security Warning

Do not attempt to read, copy, or distribute password hashes as part of ordinary Linux training.

The conceptual distinction is sufficient for this lecture.

---

# 14. THE /ETC/GROUP FILE

The `/etc/group` file contains local group entries.

Example:

```text
developers:x:1005:alice,bob
```

The entry includes:

- Group name.
- Password-related placeholder.
- GID.
- Listed supplementary members.

Primary group memberships are not necessarily repeated in the final membership field.

---

# 15. ACCOUNT DATABASE LOOKUP

The `getent` command queries configured system identity databases.

Example:

```bash
getent passwd
```

To query one account:

```bash
getent passwd "$(whoami)"
```

To query a group:

```bash
getent group sudo
```

### Why This Matters

Linux identity information can come from sources other than local text files.

For example, enterprise systems may use external directory services.

`getent` follows configured Name Service Switch mechanisms.

---

# 16. CREATING A USER

On Ubuntu, an administrator commonly uses:

```bash
sudo adduser USERNAME
```

For example, on an isolated practice VM:

```bash
sudo adduser linux2trainee
```

The command may create an account, a home directory, and associated default configuration.

### Important Distinction

`adduser` is commonly a distribution-provided friendly account-management interface.

`useradd` is a lower-level account-management utility.

Their options and defaults may differ.

---

# 17. CREATING A GROUP

On Ubuntu:

```bash
sudo addgroup linux2team
```

Add a user to the group:

```bash
sudo usermod -aG linux2team linux2trainee
```

The `-aG` combination is important.

`-a` means append.

`-G` identifies supplementary groups.

### Critical Warning

Using `usermod -G` without `-a` can replace the account's existing supplementary group list.

Do not accidentally remove necessary memberships.

---

# 18. GROUP MEMBERSHIP CHANGES

After changing supplementary group membership, existing user sessions may not immediately receive the new group list.

The user may need to start a new login session.

A command such as:

```bash
newgrp GROUP
```

can start a shell with changed group context when authorized.

However, it is not a universal replacement for normal session reauthentication.

---

# 19. PASSWORD MANAGEMENT

A user can change their own password:

```bash
passwd
```

An authorized administrator can change another user's password:

```bash
sudo passwd USERNAME
```

Passwords should be chosen according to organizational security policy.

Do not put passwords directly into shell commands, Git repositories, or scripts.

---

# 20. ACCOUNT LOCKING

On systems supporting the relevant `passwd` options:

```bash
sudo passwd -l USERNAME
```

locks password authentication for the account.

### Important Security Qualification

Locking a password does not necessarily disable all methods of logging into the account.

For example, an account may still have authorized SSH keys.

Disabling an account entirely requires reviewing all applicable authentication and access mechanisms.

---

# PART III — LINUX FILE PERMISSIONS

## 21. WHY FILE PERMISSIONS EXIST

Linux supports multiple users and processes.

The operating system must determine which identities are permitted to access files and directories.

Traditional Unix permissions provide a basic access-control model.

They distinguish three categories:

1. Owner.
2. Group.
3. Others.

Each category can have read, write, and execute permissions.

---

# 22. UNDERSTANDING RWX

The three basic permission letters are:

```text
r = read

w = write

x = execute
```

For a regular file:

**Read:** Read the file's contents.

**Write:** Modify the file's contents.

**Execute:** Execute the file as a program or script where applicable.

### Important Detail

Execute permission does not guarantee that the file is valid executable code.

It only contributes to the operating system's permission decision.

---

# 23. READING PERMISSION STRINGS

Execute:

```bash
ls -l
```

Example:

```text
-rwxr-xr--
```

Break it into sections:

```text
-   rwx   r-x   r--
|    |     |     |
|    |     |     +-- Others
|    |     +-------- Group
|    +-------------- Owner
+------------------- File type
```

### Meaning

Owner:

```text
rwx
```

Read, write, execute.

Group:

```text
r-x
```

Read and execute.

Others:

```text
r--
```

Read only.

---

# 24. THE FIRST PERMISSION CHARACTER

In a traditional long listing:

```text
-
```

usually indicates a regular file.

```text
d
```

indicates a directory.

```text
l
```

indicates a symbolic link.

Additional characters can represent other special filesystem object types.

---

# 25. NUMERIC FILE PERMISSIONS

Linux permissions are often expressed using octal digits.

The basic values are:

```text
Read    = 4

Write   = 2

Execute = 1
```

Combine the values to obtain the desired permissions.

Example:

```text
rwx = 4 + 2 + 1 = 7

r-x = 4 + 0 + 1 = 5

r-- = 4 + 0 + 0 = 4
```

Therefore:

```text
754 = rwxr-xr--
```

---

# 26. COMMON PERMISSION MODES

| Mode | Meaning                                |
| ---- | -------------------------------------- |
| 600  | Owner read/write                       |
| 644  | Owner read/write; others read          |
| 700  | Owner full access only                 |
| 755  | Owner full access; others read/execute |
| 750  | Owner full access; group read/execute  |
| 770  | Owner and group full access            |
| 660  | Owner and group read/write             |
| 400  | Owner read only                        |

The correct permissions depend on the security requirements of the file.

Do not assume that one mode is suitable for every resource.

---

# 27. THE CHMOD COMMAND

`chmod` changes permission bits.

Example:

```bash
chmod 600 private.txt
```

For a shell script:

```bash
chmod 755 script.sh
```

Symbolic notation can also be used:

```bash
chmod u+x script.sh
```

This adds execute permission for the owner.

---

# 28. SYMBOLIC CHMOD NOTATION

Common symbols include:

```text
u = owner

g = group

o = others

a = all
```

Operators:

```text
+ = add

- = remove

= = assign
```

Examples:

```bash
chmod g+w shared.txt
```

```bash
chmod o-r private.txt
```

```bash
chmod u=rwx,g=rx,o= script.sh
```

The final example sets explicit permissions for each category.

---

# 29. DIRECTORY PERMISSIONS

Directory permissions have meanings that differ from ordinary file permissions.

For a directory:

**Read:** List directory entry names.

**Write:** Modify directory entries when other relevant conditions permit it.

**Execute:** Search or traverse the directory.

### Critical Principle

A user can sometimes read a known file inside a directory without being allowed to list all of the directory's entry names, provided search permission and the necessary file permissions exist.

Directory execute permission is therefore extremely important.

---

# 30. FILE DELETION AND DIRECTORY PERMISSIONS

Deleting a file commonly requires suitable permissions on the containing directory.

It does not simply depend on whether the file itself is writable.

Other mechanisms, such as sticky bits and access-control restrictions, can affect deletion.

### Important Distinction

File write permission controls modifying file content.

Directory write and search permissions help control adding and removing directory entries.

---

# 31. FILE OWNERSHIP

Files are associated with a user owner and group owner.

Inspect:

```bash
ls -l FILE
```

To change ownership when authorized:

```bash
sudo chown USERNAME FILE
```

Change user and group ownership:

```bash
sudo chown USERNAME:GROUPNAME FILE
```

### Warning

Do not change ownership of system directories or application data recursively without understanding the consequences.

---

# 32. THE CHGRP COMMAND

`chgrp` changes a file's group ownership when authorized.

Example:

```bash
chgrp developers shared.txt
```

Success depends on permissions and group membership.

Changing ownership is distinct from changing permission bits.

---

# 33. WHAT IS UMASK?

`umask` controls which permission bits are removed from the initial creation mode of new files and directories.

Inspect:

```bash
umask
```

A common value is:

```text
0022
```

For many ordinary file-creation operations:

```text
Initial file mode:      666
Umask:                  022
Typical resulting mode: 644
```

For directories:

```text
Initial directory mode: 777
Umask:                  022
Typical resulting mode: 755
```

### Important Qualification

Umask is a bit mask, not ordinary decimal subtraction.

Applications, ACLs, and filesystem behavior can also affect final permissions.

---

# 34. PRIVATE UMASK

A more restrictive umask is:

```bash
umask 077
```

Typical resulting permissions for ordinary new files:

```text
600
```

And directories:

```text
700
```

This can be useful when creating private application files.

However, changing umask in the current shell affects later file creations until changed again.

---

# 35. ACCESS CONTROL LISTS

Traditional owner/group/other permissions may be insufficient for complex access requirements.

Access Control Lists, or ACLs, provide additional permission entries.

For example, an ACL may grant a selected user access to a file without changing the file's owning group.

Common commands include:

```bash
getfacl FILE
```

and:

```bash
setfacl
```

The tools may require installation.

The filesystem must support the relevant ACL behavior.

---

# 36. ACL MASKS

POSIX ACLs include a mask that can restrict the effective permissions of selected ACL entries.

An ACL entry showing read and write permissions does not always mean those effective permissions are available if the ACL mask is more restrictive.

Inspect the effective ACL output when troubleshooting.

### Important Principle

ACL evaluation can be more detailed than the simple rwx permission string.

---

# 37. SPECIAL PERMISSION BITS

Linux also supports special permission bits.

Three important ones are:

1. Setuid.
2. Setgid.
3. Sticky bit.

### Setuid

On applicable executable files, it can affect the effective user identity during execution.

### Setgid

On executable files, it can affect the effective group identity.

On directories, it can cause newly created entries to inherit the directory's group ownership under applicable filesystem rules.

### Sticky Bit

On directories, it restricts who may remove or rename entries, even when the directory is writable.

---

# 38. THE /TMP DIRECTORY AND STICKY BIT

A shared temporary directory may have permissions resembling:

```text
drwxrwxrwt
```

The final `t` indicates a sticky bit.

This prevents ordinary users from freely deleting other users' files from the shared directory under the normal sticky-directory rules.

### Security Principle

Writable shared directories require deliberate access controls.

---

# PART IV — LINUX PROCESSES

## 39. WHAT IS A PROCESS?

A process is a running instance of a program.

Examples include:

- Python applications.
- Bash shells.
- SSH servers.
- Web servers.
- Database processes.

Linux assigns processes identifiers and maintains execution-related state.

---

# 40. PROCESS IDENTIFIERS

PID means:

**Process ID.**

PPID means:

**Parent Process ID.**

Example:

```text
Bash shell PID: 2000

Python process PID: 2100

Python PPID: 2000
```

The identifiers are illustrative.

The parent-child relationship helps explain how processes are created.

---

# 41. PROCESS CREATION

Linux processes are commonly created through operating-system interfaces involving operations such as fork, clone, and exec.

At a high level:

1. A process requests creation of another execution context.
2. The new process receives appropriate identity and resource context.
3. A program may then be executed in that process.

The details depend on the program and its process-creation mechanism.

---

# 42. VIEWING RUNNING PROCESSES

Use:

```bash
ps
```

For a broader snapshot:

```bash
ps aux
```

Display selected fields:

```bash
ps -eo pid,ppid,user,stat,comm
```

### Important Principle

`ps` reports a snapshot.

It does not continuously update like an interactive process monitor.

---

# 43. THE TOP COMMAND

Use:

```bash
top
```

It provides an interactive display of processes and resource usage.

Common controls include:

```text
q = quit
```

The output commonly includes:

- CPU usage.
- Memory usage.
- Process IDs.
- Process states.
- Command names.

The exact display depends on configuration.

---

# 44. HTOP

`htop` is an optional interactive process monitor.

Execute:

```bash
htop
```

It may provide a more convenient process interface than traditional `top`.

It may need to be installed separately.

### Important Principle

Process monitors help observe resource behavior, but one snapshot does not necessarily explain a performance problem.

---

# 45. PROCESS STATES

Linux processes can be in several states.

Common indicators include:

| State | Meaning               |
| ----- | --------------------- |
| R     | Running or runnable   |
| S     | Interruptible sleep   |
| D     | Uninterruptible sleep |
| T     | Stopped or traced     |
| Z     | Zombie                |

A zombie process has terminated but has not yet been fully reaped by its parent.

A zombie is not an ordinary process actively executing application code.

---

# 46. PROCESS SIGNALS

Signals are mechanisms for notifying processes about events or requesting behavior.

Important examples include:

| Signal  | Common purpose                         |
| ------- | -------------------------------------- |
| SIGINT  | Interrupt, commonly Ctrl+C             |
| SIGTERM | Request termination                    |
| SIGKILL | Force termination                      |
| SIGSTOP | Stop execution                         |
| SIGCONT | Continue a stopped process             |
| SIGHUP  | Hangup; some daemons use it for reload |

### Important Qualification

Signals such as SIGTERM and SIGHUP can be handled by processes.

SIGKILL cannot be caught or ignored by ordinary process signal handlers.

---

# 47. TERMINATING PROCESSES

Request graceful termination:

```bash
kill -TERM PID
```

Or:

```bash
kill -15 PID
```

Force termination when necessary:

```bash
kill -KILL PID
```

### Important Principle

Prefer a graceful termination request when possible.

SIGKILL prevents the target process from performing its normal signal-handling cleanup.

---

# 48. FINDING PROCESSES BY NAME

Use:

```bash
pgrep -a python3
```

This displays matching processes and command-line information.

A command such as:

```bash
pkill
```

can signal matching processes.

### Safety Warning

Do not use broad process-name patterns for termination without verifying exactly which processes they may affect.

For laboratory exercises, use the PID of a process you intentionally started.

---

# 49. FOREGROUND PROCESSES

A foreground process occupies the terminal's foreground job position.

Example:

```bash
sleep 30
```

The shell waits for the command.

Pressing Ctrl+C commonly sends SIGINT to the foreground process group.

---

# 50. BACKGROUND PROCESSES

Bash can start a command as a background job.

Example:

```bash
sleep 120 &
```

The shell returns a prompt while the sleep process continues.

Inspect jobs:

```bash
jobs -l
```

The shell may display the job number and PID.

---

# 51. JOB CONTROL

Common Bash job-control commands include:

```bash
jobs
```

```bash
fg
```

```bash
bg
```

A foreground job can often be suspended using Ctrl+Z.

Then it may be resumed in the background or foreground.

### Important Qualification

Job control is primarily an interactive shell feature.

A background job is not automatically a reliable system service.

For long-running applications, an appropriate service manager is usually preferable.

---

# 52. PROCESS PRIORITY

Linux scheduling includes priority and nice values.

Inspect:

```bash
ps -eo pid,ni,comm
```

Start a lower-priority process:

```bash
nice -n 10 COMMAND
```

Adjusting an existing process may involve:

```bash
renice
```

### Important Principle

Nice values influence scheduling priority under applicable policies.

They do not provide the same guarantees as strict CPU resource limits.

---

# 53. RESOURCE INSPECTION

Inspect memory:

```bash
free -h
```

Inspect system uptime and load:

```bash
uptime
```

Inspect virtual memory statistics:

```bash
vmstat 1 3
```

The last command requests repeated statistics when the tool is installed.

### Connection to Docker

Docker containers are processes using the host's Linux kernel.

Their resource usage can be influenced by cgroups.

Understanding Linux process and memory tools helps with container troubleshooting.

---

# PART V — SYSTEMD SERVICE MANAGEMENT

## 54. WHAT IS SYSTEMD?

Systemd is a system and service manager used by many Linux distributions.

It helps manage:

- Services.
- Timers.
- Mounts.
- Targets.
- Sockets.
- Other system units.

Systemd is widely used on modern Ubuntu Server installations.

However, not every Linux environment uses systemd as its service manager.

Minimal containers may not have systemd running as PID 1.

---

# 55. WHAT IS A SERVICE?

A service is a program or managed activity intended to provide ongoing or scheduled functionality.

Examples include:

- SSH server.
- Web server.
- Database.
- Application server.
- Backup task.

A service manager can coordinate startup, stop, restart, and dependency behavior.

---

# 56. WHAT IS A SYSTEMD UNIT?

A systemd unit is a configuration object representing a managed resource or operation.

Examples:

```text
ssh.service
```

```text
myapp.service
```

```text
backup.timer
```

```text
data.mount
```

The suffix identifies the unit type.

---

# 57. SYSTEMCTL

`systemctl` communicates with the systemd manager.

Common commands include:

```bash
systemctl status ssh
```

```bash
systemctl is-active ssh
```

```bash
systemctl is-enabled ssh
```

These inspect different aspects of a service.

### Important Distinction

A service can be active without being enabled to start at boot.

Enabled and active are different states.

---

# 58. STARTING AND STOPPING SERVICES

For an authorized system service:

```bash
sudo systemctl start SERVICE
```

```bash
sudo systemctl stop SERVICE
```

```bash
sudo systemctl restart SERVICE
```

```bash
sudo systemctl reload SERVICE
```

### Important Qualification

Not every service supports reload.

Restart and reload are different operations.

Restart generally involves stopping and starting the managed service.

Reload asks a supported service to reload configuration without necessarily restarting the process.

---

# 59. ENABLING SERVICES

Use:

```bash
sudo systemctl enable SERVICE
```

This configures appropriate startup relationships according to the unit's installation metadata.

Start and enable together:

```bash
sudo systemctl enable --now SERVICE
```

### Important Distinction

`enable` does not necessarily start the service immediately.

`--now` requests the corresponding start operation as well.

---

# 60. SYSTEMD SERVICE UNIT EXAMPLE

A basic system service unit may look like:

```ini
[Unit]
Description=Example Python Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/srv/myapp
ExecStart=/usr/bin/python3 /srv/myapp/server.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

This is a conceptual example.

It requires:

- An existing `appuser`.
- An existing `/srv/myapp` directory.
- An available Python interpreter.
- Correct file permissions.
- A valid application.

### Important Principle

Systemd `ExecStart=` is not automatically interpreted by a shell.

Shell pipelines or redirection require an explicitly invoked shell when appropriate.

---

# 61. DAEMON RELOAD

After changing systemd unit files, the manager may need to reload unit definitions:

```bash
sudo systemctl daemon-reload
```

This does not automatically restart every service whose unit definition changed.

The administrator must decide which services need to be restarted or reloaded.

---

# 62. JOURNALCTL

`journalctl` reads logs from the systemd journal.

Examples:

```bash
journalctl -b
```

```bash
journalctl -u ssh
```

```bash
journalctl -u ssh -n 50
```

```bash
journalctl -u ssh -f
```

### Explanation

`-b` filters the current boot.

`-u` filters a unit.

`-n` limits recent displayed entries.

`-f` follows new entries.

Access depends on journal permissions.

---

# 63. USER-LEVEL SYSTEMD SERVICES

Systemd also supports per-user service managers.

A user unit may live under:

```text
~/.config/systemd/user/
```

Commands use:

```bash
systemctl --user
```

Example:

```bash
systemctl --user list-units
```

### Important Qualification

User services require a suitable running user manager and session environment.

They may not work in minimal containers, some remote shells, or systems without an active user systemd manager.

User services are particularly useful for safe practice without modifying system-level service configuration.

---

# PART VI — LINUX NETWORKING

## 64. WHAT IS A NETWORK INTERFACE?

A network interface provides an endpoint through which the system communicates using a network.

Interfaces may be:

- Physical Ethernet.
- Wireless.
- Loopback.
- Virtual.
- Bridge.
- Container-related interfaces.

Display interfaces:

```bash
ip link
```

Inspect addresses:

```bash
ip addr
```

A concise view:

```bash
ip -br addr
```

---

# 65. WHAT IS AN IP ADDRESS?

An IP address identifies a network interface endpoint within an IP network context.

An IPv4 address looks like:

```text
192.168.1.25
```

An IPv6 address looks like:

```text
2001:db8::25
```

These are examples rather than addresses to configure blindly.

### Important Principle

IP addresses allow networks to identify communication endpoints.

---

# 66. CIDR NOTATION

CIDR notation identifies a network prefix length.

Example:

```text
192.168.1.25/24
```

The `/24` indicates that 24 bits form the network prefix.

In conventional IPv4 subnetting, this is equivalent to:

```text
255.255.255.0
```

The address and prefix describe how the interface participates in its network.

---

# 67. LOOPBACK

The IPv4 loopback address commonly used is:

```text
127.0.0.1
```

It refers to the local network stack.

Example:

```bash
curl http://127.0.0.1:8000
```

The request targets a service on the same network namespace.

### Connection to Docker

Inside a container, `127.0.0.1` refers to that container's network namespace rather than automatically referring to the Docker host or another container.

---

# 68. TCP AND UDP

TCP and UDP are transport-layer protocols.

### TCP

Provides connection-oriented reliable byte-stream delivery under normal operating conditions.

Commonly used by:

- SSH.
- HTTP/HTTPS.
- Database connections.

### UDP

Provides datagram-based communication without TCP's delivery and ordering guarantees.

Commonly used by selected:

- DNS operations.
- Real-time applications.
- Streaming protocols.
- Network discovery mechanisms.

The application protocol determines which transport is used.

---

# 69. PORT NUMBERS

A port identifies a transport-layer communication endpoint.

Examples:

| Port           | Common service |
| -------------- | -------------- |
| 22/TCP         | SSH            |
| 53/UDP and TCP | DNS            |
| 80/TCP         | HTTP           |
| 443/TCP        | HTTPS          |
| 5432/TCP       | PostgreSQL     |
| 6379/TCP       | Redis          |

These are common defaults, not mandatory assignments.

Applications can be configured to use other ports.

---

# 70. LISTENING SOCKETS

A server listens for network connections on selected addresses and ports.

Inspect TCP listening sockets:

```bash
ss -lnt
```

Inspect TCP and UDP listening sockets:

```bash
ss -tuln
```

Display process information where permitted:

```bash
ss -tulnp
```

### Useful Options

```text
-l = listening

-n = numeric addresses and ports

-t = TCP

-u = UDP

-p = process information
```

### Important Principle

A process listening on `127.0.0.1` is not automatically reachable from other machines.

---

# 71. WHAT IS A ROUTE?

A route tells the operating system how to forward outgoing network traffic toward a destination.

Inspect:

```bash
ip route
```

Example:

```text
default via 192.168.1.1 dev enp0s3
```

This indicates a default route through a gateway for traffic matching that route.

The actual interface name and address depend on the system.

---

# 72. DEFAULT GATEWAY

A default gateway provides a route for destinations not covered by more specific routes.

For example, a server may send traffic for an external network through a local router.

### Important Principle

A correct IP address does not guarantee external connectivity if routing is incorrect.

---

# 73. DNS

DNS stands for:

**Domain Name System.**

DNS maps domain names to records such as IP addresses.

Example:

```text
example.com
        |
        v
IP address
```

Without DNS resolution, an application may know a hostname but be unable to determine the corresponding address.

---

# 74. DNS INSPECTION

Query through configured system name resolution:

```bash
getent hosts example.com
```

On systems using systemd-resolved:

```bash
resolvectl status
```

If the `dig` utility is installed:

```bash
dig example.com
```

Short output:

```bash
dig +short example.com
```

### Important Qualification

`dig` performs DNS queries and may not follow every aspect of the application's Name Service Switch lookup behavior.

`getent` is often useful for checking how local applications resolve names.

---

# 75. TESTING NETWORK CONNECTIVITY

A common tool is:

```bash
ping -c 3 1.1.1.1
```

This sends ICMP echo requests.

### Important Qualification

Some networks block ICMP traffic.

A failed ping does not conclusively prove that all network connectivity is unavailable.

For an application protocol, test the actual service where possible.

Example:

```bash
curl -I https://example.com
```

This requests HTTP response headers using HTTPS.

The command requires a suitable network connection.

---

# 76. NETWORK TROUBLESHOOTING ORDER

A useful diagnostic sequence is:

1. Inspect network interfaces.
2. Inspect IP addresses.
3. Inspect routes.
4. Inspect DNS resolution.
5. Inspect listening sockets.
6. Test the intended destination.
7. Inspect local firewall and service configuration if authorized.

Commands:

```bash
ip -br addr
```

```bash
ip route
```

```bash
getent hosts example.com
```

```bash
ss -lnt
```

```bash
curl --verbose http://127.0.0.1:8000
```

### Important Principle

Investigate the exact layer where connectivity fails.

---

# 77. NETWORK CONFIGURATION ON UBUNTU

Modern Ubuntu systems commonly use Netplan for network configuration.

Depending on the environment, Netplan can work with:

- systemd-networkd.
- NetworkManager.

Network configuration often resides under:

```text
/etc/netplan/
```

### Important Warning

Changing addresses, routes, or DNS configuration on a remotely accessed server can disconnect your SSH session.

Do not experiment with live network configuration on an important server.

Use a dedicated VM with console access for such exercises.

---

# PART VII — SSH ADMINISTRATION

## 78. WHAT IS SSH?

SSH stands for:

**Secure Shell.**

SSH supports encrypted remote communication and authentication.

It is widely used for Linux server administration.

A developer can connect to a Linux server from another computer and execute authorized commands.

---

# 79. SSH CLIENT AND SERVER

An SSH connection involves:

```text
SSH CLIENT
    |
    | Encrypted connection
    v
SSH SERVER
```

The SSH server commonly uses:

```text
sshd
```

The client commonly uses:

```bash
ssh
```

The server usually listens on TCP port 22 unless configured otherwise.

---

# 80. CONNECTING THROUGH SSH

Example:

```bash
ssh USERNAME@SERVER_ADDRESS
```

For a custom SSH port:

```bash
ssh -p 2222 USERNAME@SERVER_ADDRESS
```

Replace placeholders with a real server and authorized account.

### Important Security Principle

Connect only to systems you own or are authorized to administer.

Verify the server's SSH host key identity, particularly on first connection.

---

# 81. SSH KEY AUTHENTICATION

SSH can authenticate using public-key cryptography.

A key pair contains:

- Private key.
- Public key.

Generate a dedicated key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_linux_course
```

Choose a suitable passphrase.

The private key must remain confidential.

---

# 82. AUTHORIZED KEYS

A server account may authorize SSH public keys through:

```text
~/.ssh/authorized_keys
```

An authorized administrator can install a public key using:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_linux_course.pub USERNAME@SERVER_ADDRESS
```

This requires an available authenticated method for initial access.

### Important Principle

The public key may be installed on the remote account.

The private key stays on the client machine.

---

# 83. SSH FILE PERMISSIONS

Common secure settings include:

```bash
chmod 700 ~/.ssh
```

```bash
chmod 600 ~/.ssh/authorized_keys
```

For a private key:

```bash
chmod 600 ~/.ssh/id_ed25519_linux_course
```

OpenSSH checks selected ownership and permissions as part of secure authentication behavior.

The exact requirements also depend on the server's configuration.

---

# 84. OPENSSH SERVICE MANAGEMENT

On Ubuntu Server, the service is commonly named:

```text
ssh
```

Inspect:

```bash
systemctl status ssh
```

Inspect recent logs:

```bash
sudo journalctl -u ssh -n 50
```

### Important Warning

Do not disable password login or restart SSH configuration remotely until you have verified working alternative access and a recovery path.

A configuration mistake can lock administrators out.

Advanced SSH hardening belongs to Major Lecture 03.

---

# PART VIII — STORAGE AND FILESYSTEMS

## 85. STORAGE DEVICES

Linux can use various storage devices, including:

- Physical hard disks.
- Solid-state drives.
- Virtual disks.
- Network-attached storage.
- Removable devices.

A storage device can contain partitions.

Partitions can contain filesystems or serve other storage roles.

---

# 86. STORAGE ARCHITECTURE

A simplified traditional disk structure is:

```text
PHYSICAL OR VIRTUAL DISK
           |
           v
       PARTITIONS
           |
           v
       FILESYSTEMS
           |
           v
       MOUNT POINTS
           |
           v
      APPLICATION FILES
```

LVM can introduce additional layers between physical storage and the filesystem.

Not every Linux installation uses every layer.

---

# 87. INSPECTING BLOCK DEVICES

Use:

```bash
lsblk
```

For filesystem information:

```bash
lsblk -f
```

The output may display:

- Disk names.
- Partitions.
- Filesystem types.
- UUIDs.
- Mount points.

### Important Warning

Do not assume a device named `/dev/sdb` or `/dev/nvme1n1` is unused.

Never format a device based solely on a guessed name.

---

# 88. WHAT IS A PARTITION?

A partition is a defined region of a block storage device.

Partitions allow a disk to be divided into separately managed regions.

Partition-table formats include:

- GPT.
- MBR.

GPT is common on modern systems.

### Important Distinction

A partition is not the same thing as a filesystem.

A filesystem may be created within a partition or other block device.

---

# 89. WHAT IS A FILESYSTEM?

A filesystem organizes stored data into files, directories, metadata, and associated structures.

Common Linux filesystem types include:

- ext4.
- XFS.
- Btrfs.

Other types include:

- FAT filesystems.
- exFAT.
- NTFS.

Linux can also access network filesystems.

### Important Principle

Different filesystems have different features and operational characteristics.

---

# 90. WHAT IS MOUNTING?

Mounting makes a filesystem accessible at a location within the Linux directory hierarchy.

Example:

```text
Device filesystem
        |
        v
Mount point
        |
        v
/mnt/data
```

A mounted filesystem becomes accessible through its selected mount point.

---

# 91. INSPECTING MOUNTS

Use:

```bash
findmnt
```

For the filesystem containing your home directory:

```bash
findmnt -T "$HOME"
```

Inspect mounted filesystem types and usage:

```bash
df -hT
```

### Important Principle

A Linux path does not necessarily correspond to a separate disk.

Multiple paths can refer to the same filesystem.

---

# 92. DISK SPACE WITH DF

`df` reports filesystem space usage.

Example:

```bash
df -h
```

It can show:

- Total space.
- Used space.
- Available space.
- Mount point.

### Important Detail

Filesystem-level used space is not necessarily identical to the sum of visible file sizes in a selected directory.

---

# 93. DIRECTORY SIZE WITH DU

`du` examines disk usage associated with selected files and directories.

Example:

```bash
du -sh "$HOME"
```

Inspect top-level directories under a practice workspace:

```bash
du -h --max-depth=1 "$HOME/linux-major-lesson2"
```

### Difference

**df:** Filesystem capacity and free space.

**du:** Disk usage associated with selected paths.

---

# 94. INODES

Filesystems commonly use metadata structures called inodes.

A filesystem can have available disk capacity but run out of allocatable inodes.

Inspect inode usage:

```bash
df -i
```

### Important Principle

"Disk full" conditions can involve different resource limits.

Inspect both space and inode availability when diagnosing filesystem capacity problems.

---

# 95. THE /ETC/FSTAB FILE

The file:

```text
/etc/fstab
```

describes filesystem mount configuration.

An illustrative entry is:

```text
UUID=EXAMPLE-UUID /mnt/data ext4 defaults,nofail 0 2
```

Fields represent:

1. Filesystem source.
2. Mount point.
3. Filesystem type.
4. Mount options.
5. Dump-related field.
6. Filesystem check order.

### Important Warning

This is not a command to paste into a terminal or into a live server configuration without adaptation.

Incorrect `/etc/fstab` entries can cause serious mount or boot problems.

---

# 96. UUIDS

A filesystem UUID is a persistent identifier assigned to a filesystem.

It is often preferable to a potentially changing kernel device name when configuring persistent mounts.

Inspect:

```bash
lsblk -f
```

Where available:

```bash
blkid
```

### Important Principle

Use verified identifiers rather than guessing storage device names.

---

# 97. MOUNT OPTIONS

Mount options influence filesystem behavior.

Examples include:

```text
ro
rw
noexec
nosuid
nodev
nofail
```

### Interpretation

`ro`: Read-only mount.

`rw`: Read-write mount.

`noexec`: Restricts direct execution through the mount.

`nosuid`: Restricts setuid/setgid effects.

`nodev`: Restricts interpretation of device special files.

`nofail`: Allows selected boot behavior when a mount is unavailable.

### Important Qualification

Mount options are useful defense layers but are not complete security boundaries by themselves.

---

# PART IX — LOGICAL VOLUME MANAGEMENT

## 98. WHAT IS LVM?

LVM stands for:

**Logical Volume Manager.**

LVM provides a flexible storage abstraction.

It can combine physical storage resources and allocate logical volumes.

---

# 99. LVM COMPONENTS

Three key LVM concepts are:

1. Physical Volume — PV.
2. Volume Group — VG.
3. Logical Volume — LV.

### Architecture

```text
DISK OR PARTITION
        |
        v
PHYSICAL VOLUME (PV)
        |
        v
VOLUME GROUP (VG)
        |
        v
LOGICAL VOLUME (LV)
        |
        v
FILESYSTEM
        |
        v
MOUNT POINT
```

A volume group can contain multiple physical volumes.

Logical volumes are allocated from the volume group's storage.

---

# 100. LVM INSPECTION

On a system with LVM utilities installed:

```bash
pvs
```

```bash
vgs
```

```bash
lvs
```

More detailed commands include:

```bash
pvdisplay
```

```bash
vgdisplay
```

```bash
lvdisplay
```

### Important Warning

Creating, resizing, or deleting logical volumes changes real storage configuration.

These operations should be performed only in a dedicated practice VM with disposable virtual disks and suitable backups.

---

# 101. EXTENDING STORAGE

An administrator may need to increase available application storage.

A simplified LVM-based extension process can involve:

1. Verify the actual disk and volume layout.
2. Ensure additional storage is available.
3. Extend the appropriate volume group if necessary.
4. Extend the selected logical volume.
5. Grow the filesystem using the correct filesystem-specific method.
6. Verify the resulting capacity.

### Important Qualification

Extending a logical volume is not always the same operation as growing its filesystem.

The correct commands depend on the filesystem and storage layout.

---

# PART X — ARCHIVES AND COMPRESSION

## 102. WHAT IS AN ARCHIVE?

An archive combines files and directories into a single file.

A compressed archive additionally applies a compression mechanism.

Common formats include:

```text
.tar
.tar.gz
.tgz
.zip
```

On Linux, `tar` is widely used for archival operations.

---

# 103. THE TAR COMMAND

Create an uncompressed archive:

```bash
tar -cf project.tar project/
```

Create a gzip-compressed archive:

```bash
tar -czf project.tar.gz project/
```

List archive contents:

```bash
tar -tzf project.tar.gz
```

Extract:

```bash
tar -xzf project.tar.gz
```

### Common Flags

```text
-c = create

-x = extract

-t = list

-z = gzip

-f = archive filename

-v = verbose
```

---

# 104. ARCHIVE EXTRACTION SAFETY

Archives may contain pathnames or other metadata affecting extraction behavior.

Do not extract an untrusted archive directly into sensitive directories.

For the laboratory, create archives from your own practice data and restore them into a separate empty directory.

### Important Principle

Inspect what an archive contains before extracting it.

---

# 105. GZIP

`gzip` compresses data.

Example:

```bash
gzip file.txt
```

This normally replaces the source with a compressed file named:

```text
file.txt.gz
```

Decompress:

```bash
gunzip file.txt.gz
```

To preserve the original file while compressing its output:

```bash
gzip -c file.txt > file.txt.gz
```

---

# 106. ARCHIVE VERSUS BACKUP

An archive is a packaging format.

A backup is a deliberately maintained recovery copy.

A reliable backup strategy also considers:

- Storage location.
- Independence from the original data.
- Backup frequency.
- Retention.
- Integrity verification.
- Restoration testing.
- Recovery objectives.

### Important Principle

Creating a `.tar.gz` file does not automatically establish an adequate disaster-recovery system.

---

# PART XI — FILE TRANSFER

## 107. WHAT IS SCP?

SCP provides secure file copying over SSH-based transport.

Example:

```bash
scp local.txt USERNAME@SERVER_ADDRESS:/home/USERNAME/
```

To copy from a remote server:

```bash
scp USERNAME@SERVER_ADDRESS:/home/USERNAME/report.txt .
```

The user requires suitable authorization.

Modern OpenSSH versions commonly use SFTP as the default underlying protocol for the `scp` command.

---

# 108. WHAT IS RSYNC?

`rsync` synchronizes files and directories.

It is useful for:

- Local directory synchronization.
- Remote file transfer.
- Backup workflows.
- Efficient copying of changed data.

Example:

```bash
rsync -av source/ destination/
```

### Important Principle

The source path's trailing slash affects what is copied.

---

# 109. RSYNC TRAILING SLASHES

Compare:

```bash
rsync -av source/ destination/
```

with:

```bash
rsync -av source destination/
```

The first copies the contents of `source` into the destination.

The second commonly creates or updates a `source` directory within the destination.

Understanding this difference prevents many synchronization mistakes.

---

# 110. RSYNC DRY RUN

Before copying important data, inspect the proposed operation:

```bash
rsync -avn source/ destination/
```

The `-n` option requests a dry run.

For deletion-capable synchronization, use extra caution.

A command such as:

```text
rsync --delete
```

can remove files from the destination that are absent from the source.

Do not use deletion options without reviewing the intended source and destination.

---

# PART XII — SCHEDULING

## 111. WHY SCHEDULE TASKS?

Many administrative operations should happen repeatedly.

Examples include:

- Backup creation.
- Log processing.
- Temporary-file cleanup.
- Report generation.
- Data synchronization.
- Scheduled maintenance.

Linux provides several scheduling mechanisms.

Two important ones are:

1. Cron.
2. Systemd timers.

---

# 112. WHAT IS CRON?

Cron is a time-based job scheduler commonly available on Unix-like systems.

Users can define recurring commands through crontab entries.

Open a user's crontab:

```bash
crontab -e
```

List scheduled jobs:

```bash
crontab -l
```

The scheduling daemon must be available and running for jobs to execute.

---

# 113. CRON EXPRESSION FORMAT

A traditional user crontab line has five scheduling fields followed by the command.

```text
MINUTE HOUR DAY MONTH WEEKDAY COMMAND
```

Example:

```text
17 2 * * * /usr/bin/bash /home/student/backup.sh
```

This requests execution at 02:17 according to the cron implementation's time configuration.

### Important Principle

Cron timing depends on the scheduler's environment, timezone, and daemon behavior.

---

# 114. CRON EXAMPLES

| Expression     | Intended schedule                   |
| -------------- | ----------------------------------- |
| `0 * * * *`    | Every hour at minute zero           |
| `0 3 * * *`    | Daily at 03:00                      |
| `30 6 * * 1`   | Monday at 06:30                     |
| `*/15 * * * *` | Every 15 minutes                    |
| `0 0 1 * *`    | First day of each month at midnight |

The commands are evaluated according to the system's cron configuration.

---

# 115. CRON ENVIRONMENT

Cron jobs may execute with a more limited environment than an interactive login shell.

For reliability:

- Use explicit executable paths.
- Use absolute file paths.
- Set required variables deliberately.
- Redirect useful output to logs.
- Test the script manually first.

### Important Principle

A script working interactively does not guarantee it will work unchanged under cron.

---

# 116. SYSTEMD TIMERS

Systemd timers schedule activation of other systemd units.

A timer can use:

- Calendar expressions.
- Time elapsed since system boot.
- Time elapsed since another event.

Example:

```ini
[Timer]
OnCalendar=daily
Persistent=true
```

The timer normally activates a related service unit.

---

# 117. SYSTEMD TIMER VERSUS CRON

| Cron                                          | Systemd timer                                       |
| --------------------------------------------- | --------------------------------------------------- |
| Crontab-based scheduling                      | Unit-based scheduling                               |
| Simple traditional syntax                     | Integrated with systemd services                    |
| Typically managed by a cron daemon            | Managed by systemd                                  |
| Output needs deliberate handling              | Integrates with the journal                         |
| Missed-run behavior depends on implementation | `Persistent=true` can catch up missed calendar runs |

### Important Detail

`Persistent=true` does not mean every missed event is replayed separately.

For calendar timers, it supports an appropriate catch-up activation when the timer becomes active again.

---

# 118. SYSTEMD TIMER INSPECTION

List timers:

```bash
systemctl list-timers
```

For user timers:

```bash
systemctl --user list-timers
```

Inspect timer state:

```bash
systemctl --user status TIMER_NAME
```

### Important Principle

A timer's existence does not prove its associated task succeeded.

Inspect the activated service and its logs.

---

# PART XIII — BACKUP AND RECOVERY

## 119. WHAT IS A BACKUP?

A backup is a recoverable copy of selected data maintained separately from the original working data.

Backups protect against risks such as:

- Accidental deletion.
- Corruption.
- Failed changes.
- Storage loss.
- Ransomware and other attacks.
- Operational mistakes.

Backup requirements depend on the value of the data and the service's recovery objectives.

---

# 120. BACKUP TYPES

Common approaches include:

### Full Backup

Copies the entire selected dataset.

### Incremental Backup

Copies changes since an earlier backup according to the backup tool's method.

### Differential Backup

Copies changes since a reference full backup according to the tool's method.

### Logical Database Backup

Exports database contents through database-aware mechanisms.

### Filesystem Snapshot

Captures a storage-state reference using supported filesystem or storage capabilities.

Different backup mechanisms provide different consistency and recovery properties.

---

# 121. BACKUP VERIFICATION

A reliable backup procedure should answer:

1. Was the backup created successfully?
2. Does the archive or backup pass available integrity checks?
3. Can it be restored?
4. Does the restored content match expectations?
5. Is the recovery procedure documented?
6. Is the backup accessible when the original system is unavailable?

### Important Principle

**A backup should be tested through restoration, not merely through file existence.**

---

# 122. RPO AND RTO

RPO means:

**Recovery Point Objective.**

It expresses an acceptable data-loss window.

RTO means:

**Recovery Time Objective.**

It expresses a target recovery duration.

Example:

```text
RPO: 1 hour

RTO: 4 hours
```

These are requirements for designing a recovery process.

They are not automatically achieved by scheduling a backup.

---

# PART XIV — COMPLETE PRACTICAL LABORATORY

## 123. LABORATORY TITLE

**Linux Server Administration: User Identity, Permissions, Process Management, Systemd, Local Networking, File Transfers, Archives, and Scheduled Backups**

### Purpose

The student will construct a small Linux application environment and administer it using the concepts covered in this lecture.

### Practice Workspace

```text
~/linux-major-lesson2
```

### Safety Rules

1. Perform ordinary exercises as a non-root user.
2. Use a dedicated Linux VM for privileged account-management exercises.
3. Do not alter existing system users.
4. Do not modify live network routes or interfaces.
5. Do not format disks or change partition tables.
6. Do not alter `/etc/fstab` on an important machine.
7. Do not modify SSH server authentication settings without console recovery access.
8. Do not delete any directory outside the dedicated practice workspace.
9. Use a high, loopback-only application port to avoid exposing the training service.
10. Verify backup contents before restoring them.

---

# 124. EXPERIMENT 1 — IDENTIFY THE CURRENT USER

Execute:

```bash
whoami
```

```bash
id
```

```bash
groups
```

### Objective

Identify the current user's username, UID, primary GID, and supplementary groups.

---

# 125. EXPERIMENT 2 — INSPECT ACCOUNT DATABASES

Execute:

```bash
getent passwd "$(whoami)"
```

```bash
getent group "$(id -gn)"
```

Inspect public account metadata:

```bash
head -n 5 /etc/passwd
```

### Objective

Understand account and group lookup.

Do not inspect password hashes.

---

# 126. EXPERIMENT 3 — CREATE THE PRACTICE WORKSPACE

Execute in Bash:

```bash
mkdir -p "$HOME/linux-major-lesson2"/{app,data,logs,scripts,backups,restore,units,transfers}
```

Enter:

```bash
cd "$HOME/linux-major-lesson2"
```

Verify:

```bash
pwd
```

```bash
ls -la
```

### Objective

Create a dedicated workspace for Linux administration exercises.

---

# 127. EXPERIMENT 4 — CREATE TEST DATA

Execute:

```bash
cat > data/tasks.txt <<'EOF'
Learn Linux permissions
Practice process management
Study systemd
Inspect network services
Create verified backups
EOF
```

Create another file:

```bash
printf 'ADMIN_MODE=training\n' > data/settings.conf
```

Inspect:

```bash
ls -l data
```

### Objective

Create project files for permission, service, and backup exercises.

---

# 128. EXPERIMENT 5 — PRACTICE FILE PERMISSIONS

Execute:

```bash
chmod 600 data/settings.conf
```

```bash
chmod 644 data/tasks.txt
```

Inspect:

```bash
ls -l data
```

### Objective

Distinguish private configuration permissions from ordinary readable data-file permissions.

---

# 129. EXPERIMENT 6 — PRACTICE SYMBOLIC PERMISSIONS

Remove read access for others:

```bash
chmod o-r data/tasks.txt
```

Inspect:

```bash
ls -l data/tasks.txt
```

Restore the original training mode:

```bash
chmod 644 data/tasks.txt
```

### Objective

Understand symbolic chmod operations.

---

# 130. EXPERIMENT 7 — PRACTICE DIRECTORY PERMISSIONS

Create:

```bash
mkdir -p data/private
```

Set:

```bash
chmod 700 data/private
```

Inspect:

```bash
ls -ld data/private
```

### Objective

Recognize the meaning of private directory permissions.

---

# 131. EXPERIMENT 8 — PRACTICE UMASK

Save the current umask:

```bash
OLD_UMASK="$(umask)"
```

Set a restrictive mask:

```bash
umask 077
```

Create a file:

```bash
touch data/private/secret-example.txt
```

Inspect:

```bash
ls -l data/private/secret-example.txt
```

Restore the previous mask:

```bash
umask "$OLD_UMASK"
```

### Objective

Observe how umask affects new file permissions.

---

# 132. EXPERIMENT 9 — INSPECT ACL TOOLS

Check whether ACL tools exist:

```bash
command -v getfacl
```

```bash
command -v setfacl
```

If available:

```bash
getfacl data/tasks.txt
```

### Objective

Inspect the ACL representation of a file.

Installing tools is optional.

---

# 133. EXPERIMENT 10 — OPTIONAL USER ADMINISTRATION

**Dedicated practice VM with administrator authorization only.**

Create a disposable training user:

```bash
sudo adduser linux2trainee
```

Create a training group:

```bash
sudo addgroup linux2team
```

Add the user to the group:

```bash
sudo usermod -aG linux2team linux2trainee
```

Inspect:

```bash
id linux2trainee
```

### Objective

Practice account and group administration.

### Important Note

This experiment changes the actual system account database.

Skip it unless the VM is intended for disposable administrative training.

---

# 134. EXPERIMENT 11 — INSPECT SYSTEM PROCESSES

Execute:

```bash
ps -eo pid,ppid,user,stat,comm
```

Then:

```bash
top
```

Exit `top` using:

```text
q
```

### Objective

Identify running processes, ownership, and process states.

---

# 135. EXPERIMENT 12 — START A BACKGROUND PROCESS

Execute:

```bash
sleep 120 &
```

Save its PID immediately:

```bash
SLEEP_PID=$!
```

Inspect:

```bash
jobs -l
```

```bash
ps -p "$SLEEP_PID" -o pid,ppid,stat,comm
```

### Objective

Understand foreground/background execution and process IDs.

---

# 136. EXPERIMENT 13 — SEND SIGTERM

Terminate the process created in the previous experiment:

```bash
kill -TERM "$SLEEP_PID"
```

Wait for it to finish:

```bash
wait "$SLEEP_PID" 2>/dev/null || true
```

### Objective

Demonstrate graceful termination request using the exact PID of a disposable process.

---

# 137. EXPERIMENT 14 — INSPECT RESOURCE USAGE

Execute:

```bash
free -h
```

```bash
uptime
```

```bash
df -h
```

```bash
df -i
```

### Objective

Inspect memory, system load, filesystem capacity, and inode usage.

---

# 138. EXPERIMENT 15 — CREATE A LOCAL HTTP APPLICATION

Create:

```text
app/server.py
```

Insert:

```python
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json


ROOT = Path(__file__).resolve().parent.parent
TASK_FILE = ROOT / "data" / "tasks.txt"


class Handler(BaseHTTPRequestHandler):

    def send_json(self, status, payload):
        content = json.dumps(payload).encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):

        if self.path == "/healthz":
            self.send_json(200, {"status": "ok"})
            return

        if self.path == "/tasks":
            tasks = TASK_FILE.read_text(
                encoding="utf-8"
            ).splitlines()

            self.send_json(
                200,
                {
                    "tasks": tasks,
                    "count": len(tasks),
                },
            )
            return

        self.send_json(404, {"error": "Not found"})


if __name__ == "__main__":

    server = ThreadingHTTPServer(
        ("127.0.0.1", 8462),
        Handler,
    )

    print(
        "Linux administration lab listening on 127.0.0.1:8462",
        flush=True,
    )

    server.serve_forever()
```

### Objective

Create a small HTTP service for process, networking, systemd, and journal exercises.

The server listens only on the loopback interface.

It is intended for local training, not public production deployment.

---

# 139. EXPERIMENT 16 — RUN THE APPLICATION MANUALLY

From the project directory:

```bash
python3 app/server.py &
```

Save the process ID:

```bash
SERVER_PID=$!
```

Verify health:

```bash
curl --fail http://127.0.0.1:8462/healthz
```

Verify task data:

```bash
curl --fail http://127.0.0.1:8462/tasks
```

Stop the process:

```bash
kill -TERM "$SERVER_PID"
```

```bash
wait "$SERVER_PID" 2>/dev/null || true
```

### Objective

Start, inspect, and stop a simple application process.

---

# 140. EXPERIMENT 17 — INSPECT LISTENING SOCKETS

While the application is running, execute from another terminal:

```bash
ss -lnt
```

Look for:

```text
127.0.0.1:8462
```

### Objective

Connect process execution with TCP listening sockets.

If you already stopped the application, repeat the manual start operation before inspecting.

---

# 141. EXPERIMENT 18 — INSPECT NETWORK INTERFACES

Execute:

```bash
ip -br addr
```

```bash
ip route
```

```bash
ip addr show lo
```

### Objective

Identify local interfaces, IP addresses, routes, and loopback.

These commands are inspection-only.

---

# 142. EXPERIMENT 19 — CHECK DNS AND CONNECTIVITY

Execute:

```bash
getent hosts example.com
```

If internet access is available:

```bash
curl -I --max-time 10 https://example.com
```

If installed:

```bash
dig +short example.com
```

### Objective

Distinguish name resolution from application-level connectivity.

A failure may reflect an intentionally disconnected practice VM.

---

# 143. EXPERIMENT 20 — INSPECT SYSTEMD

On a systemd-based Ubuntu installation:

```bash
systemctl --version
```

Inspect the SSH service if available:

```bash
systemctl status ssh
```

Inspect active services:

```bash
systemctl list-units --type=service --state=running
```

### Objective

Understand basic systemd service inspection.

---

# 144. EXPERIMENT 21 — CREATE A USER SERVICE UNIT

Create:

```bash
mkdir -p "$HOME/.config/systemd/user"
```

Create:

```text
~/.config/systemd/user/linux2-app.service
```

Content:

```ini
[Unit]
Description=Linux Major Lecture 2 Practice Application

[Service]
Type=simple
WorkingDirectory=%h/linux-major-lesson2
ExecStart=/usr/bin/python3 %h/linux-major-lesson2/app/server.py
Restart=on-failure
RestartSec=2
NoNewPrivileges=yes

[Install]
WantedBy=default.target
```

### Objective

Define a user-managed application service.

### Important Qualification

This experiment requires an active systemd user manager.

If `systemctl --user` is unavailable, continue with the manual application process from Experiment 16.

---

# 145. EXPERIMENT 22 — START THE USER SERVICE

Reload user unit definitions:

```bash
systemctl --user daemon-reload
```

Start the service:

```bash
systemctl --user start linux2-app.service
```

Inspect:

```bash
systemctl --user status linux2-app.service
```

Verify:

```bash
curl --fail http://127.0.0.1:8462/healthz
```

### Objective

Manage a running application through systemd.

Do not run the manual copy of the server on the same port simultaneously.

---

# 146. EXPERIMENT 23 — INSPECT USER SERVICE LOGS

Execute:

```bash
journalctl --user -u linux2-app.service -n 30
```

Follow logs:

```bash
journalctl --user -u linux2-app.service -f
```

Use Ctrl+C to stop following.

### Objective

Inspect application output through the systemd journal.

---

# 147. EXPERIMENT 24 — INSPECT STORAGE

Execute:

```bash
lsblk -f
```

```bash
findmnt -T "$HOME"
```

```bash
df -hT "$HOME"
```

```bash
du -sh "$HOME/linux-major-lesson2"
```

### Objective

Connect physical or virtual storage, filesystems, mount points, and directory usage.

---

# 148. EXPERIMENT 25 — INSPECT FSTAB SAFELY

Execute:

```bash
cat /etc/fstab
```

If permitted and available:

```bash
findmnt --verify
```

### Objective

Understand persistent mount configuration.

Do not edit `/etc/fstab` in this exercise.

---

# 149. EXPERIMENT 26 — CREATE A COMPRESSED BACKUP

Return to the project directory:

```bash
cd "$HOME/linux-major-lesson2"
```

Create an archive:

```bash
tar -czf backups/data-manual.tar.gz -C "$HOME/linux-major-lesson2" data
```

Inspect:

```bash
tar -tzf backups/data-manual.tar.gz
```

### Objective

Create and inspect a compressed archive of project data.

---

# 150. EXPERIMENT 27 — RESTORE THE BACKUP

Create a separate restoration directory:

```bash
mkdir -p restore/manual-test
```

Extract your own archive:

```bash
tar -xzf backups/data-manual.tar.gz -C restore/manual-test
```

Verify:

```bash
cat restore/manual-test/data/tasks.txt
```

Compare:

```bash
diff data/tasks.txt restore/manual-test/data/tasks.txt
```

### Objective

Demonstrate restoration into an independent path.

A successful `diff` normally produces no output and exits with status 0.

---

# 151. EXPERIMENT 28 — PRACTICE RSYNC

Create a destination:

```bash
mkdir -p transfers/data-copy
```

Preview:

```bash
rsync -avn data/ transfers/data-copy/
```

Perform the synchronization:

```bash
rsync -av data/ transfers/data-copy/
```

Verify:

```bash
diff data/tasks.txt transfers/data-copy/tasks.txt
```

### Objective

Understand safe file synchronization and source-path trailing slash behavior.

Rsync may need to be installed separately.

---

# 152. EXPERIMENT 29 — CREATE AN AUTOMATED BACKUP SCRIPT

Create:

```text
scripts/backup.sh
```

Content:

```bash
#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/linux-major-lesson2"

BACKUP_DIR="$ROOT/backups"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

ARCHIVE="$BACKUP_DIR/data-$STAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

tar -czf "$ARCHIVE" -C "$ROOT" data

tar -tzf "$ARCHIVE" >/dev/null

printf 'Backup created: %s\n' "$ARCHIVE"
```

Make it executable:

```bash
chmod 700 scripts/backup.sh
```

Run:

```bash
bash scripts/backup.sh
```

### Objective

Automate backup creation and basic archive verification.

### Important Qualification

This verifies that the archive is readable.

It is not a substitute for a separate restoration test or an off-host backup.

---

# 153. EXPERIMENT 30 — CREATE A SYSTEMD BACKUP SERVICE

Create:

```text
~/.config/systemd/user/linux2-backup.service
```

Content:

```ini
[Unit]
Description=Linux Major Lecture 2 Data Backup

[Service]
Type=oneshot
ExecStart=/usr/bin/bash %h/linux-major-lesson2/scripts/backup.sh
```

### Objective

Define a one-time backup operation managed by systemd.

The service is intended to perform the script and exit.

---

# 154. EXPERIMENT 31 — CREATE A SYSTEMD TIMER

Create:

```text
~/.config/systemd/user/linux2-backup.timer
```

Content:

```ini
[Unit]
Description=Schedule Linux Major Lecture 2 Backup

[Timer]
OnCalendar=daily
Persistent=true
Unit=linux2-backup.service

[Install]
WantedBy=timers.target
```

Reload:

```bash
systemctl --user daemon-reload
```

Enable the timer:

```bash
systemctl --user enable --now linux2-backup.timer
```

Inspect:

```bash
systemctl --user list-timers
```

### Objective

Schedule a systemd-managed backup.

The timer operates only while its relevant systemd user-manager environment is available, subject to user-session and lingering configuration.

---

# 155. EXPERIMENT 32 — RUN THE BACKUP SERVICE MANUALLY

Execute:

```bash
systemctl --user start linux2-backup.service
```

Inspect:

```bash
journalctl --user -u linux2-backup.service -n 30
```

List archives:

```bash
ls -lh "$HOME/linux-major-lesson2/backups"
```

### Objective

Verify the actual backup task independently of waiting for the timer's next scheduled activation.

---

# 156. EXPERIMENT 33 — EXPLORE CRON

Check whether cron tools exist:

```bash
command -v crontab
```

If available:

```bash
crontab -l
```

Examine the following example without installing it:

```text
17 2 * * * /usr/bin/bash /home/USERNAME/linux-major-lesson2/scripts/backup.sh
```

Replace the placeholder only if deliberately configuring a real scheduled job.

### Objective

Understand the five-field cron schedule format.

Do not configure both cron and systemd timer execution for the same training backup unless you explicitly want both schedulers to run it.

---

# 157. EXPERIMENT 34 — VERIFY THE COMPLETE ENVIRONMENT

Inspect the workspace:

```bash
find "$HOME/linux-major-lesson2" -maxdepth 3 -type f -print
```

Inspect application data:

```bash
cat "$HOME/linux-major-lesson2/data/tasks.txt"
```

Inspect backup files:

```bash
ls -lh "$HOME/linux-major-lesson2/backups"
```

Inspect the service if available:

```bash
systemctl --user status linux2-app.service
```

Inspect the timer if available:

```bash
systemctl --user status linux2-backup.timer
```

### Objective

Verify the integrated administrative training environment.

---

# 158. EXPECTED PROJECT STRUCTURE

The project should resemble:

```text
linux-major-lesson2/
├── app/
│   └── server.py
├── data/
│   ├── tasks.txt
│   ├── settings.conf
│   └── private/
│       └── secret-example.txt
├── logs/
├── scripts/
│   └── backup.sh
├── backups/
│   ├── data-manual.tar.gz
│   └── data-TIMESTAMP.tar.gz
├── restore/
│   └── manual-test/
│       └── data/
│           ├── tasks.txt
│           └── settings.conf
├── transfers/
│   └── data-copy/
└── units/
```

The systemd user units are stored separately under:

```text
~/.config/systemd/user/
```

---

# PART XV — ADMINISTRATIVE TROUBLESHOOTING

## 159. PERMISSION DENIED

Possible causes:

- Incorrect ownership.
- Missing file read permission.
- Missing directory search permission.
- ACL restrictions.
- Read-only filesystem.
- Security policy restrictions.

Initial commands:

```bash
id
```

```bash
ls -ld DIRECTORY
```

```bash
ls -l FILE
```

If available:

```bash
getfacl FILE
```

### Important Principle

Do not immediately use `chmod 777` as a shortcut.

Identify the required access and grant only what is necessary.

---

# 160. SERVICE WILL NOT START

Possible causes:

- Invalid unit configuration.
- Missing executable.
- Wrong working directory.
- Missing permissions.
- Application crash.
- Port conflict.
- Missing dependency.

Investigation:

```bash
systemctl --user status linux2-app.service
```

```bash
journalctl --user -u linux2-app.service -n 50
```

```bash
ss -lnt
```

### Important Principle

A service-manager failure can originate from the application's process, configuration, permissions, or environment.

---

# 161. APPLICATION PORT IS UNAVAILABLE

Suppose the application is expected on port 8462.

Inspect:

```bash
ss -lnt
```

Test:

```bash
curl --verbose http://127.0.0.1:8462/healthz
```

Possible causes:

- Process not running.
- Wrong port.
- Wrong bind address.
- Application startup error.
- Local filtering.
- Client connecting from a different network namespace.

---

# 162. DNS RESOLUTION FAILURE

Inspect:

```bash
getent hosts example.com
```

```bash
ip route
```

If supported:

```bash
resolvectl status
```

### Important Principle

Differentiate hostname resolution failure from a connection failure to an already resolved IP address.

---

# 163. DISK SPACE PROBLEM

Inspect:

```bash
df -h
```

```bash
df -i
```

```bash
du -sh "$HOME/linux-major-lesson2"
```

Possible causes:

- Filesystem capacity exhausted.
- Inodes exhausted.
- Application logs growing.
- Backup files accumulating.
- Temporary files not cleaned up.

Do not remove unknown data until its ownership and operational purpose have been established.

---

# 164. BACKUP FAILURE

Investigate:

1. Backup destination exists.
2. Required permissions are available.
3. Source paths are correct.
4. Enough disk space exists.
5. Archive creation succeeded.
6. Archive is readable.
7. Restoration succeeds.
8. The scheduler ran the intended command.

### Important Principle

Troubleshoot the entire backup chain, not only the scheduler.

---

# PART XVI — MASTER COMMAND REFERENCE

## 165. USERS AND GROUPS

| Command                       | Purpose                                         |
| ----------------------------- | ----------------------------------------------- |
| `whoami`                      | Current username                                |
| `id`                          | User and group identity                         |
| `groups`                      | Group membership                                |
| `getent passwd USER`          | User database lookup                            |
| `getent group GROUP`          | Group database lookup                           |
| `sudo adduser USER`           | Create user on supported systems                |
| `sudo addgroup GROUP`         | Create group on supported systems               |
| `sudo usermod -aG GROUP USER` | Append supplementary group                      |
| `passwd`                      | Change password                                 |
| `sudo passwd USER`            | Change selected user's password when authorized |
| `sudo`                        | Execute an authorized privileged command        |

---

# 166. PERMISSIONS AND OWNERSHIP

| Command   | Purpose                                 |
| --------- | --------------------------------------- |
| `ls -l`   | Inspect permissions and ownership       |
| `chmod`   | Change permission bits                  |
| `chown`   | Change ownership                        |
| `chgrp`   | Change group ownership                  |
| `umask`   | Inspect/change creation permission mask |
| `getfacl` | Inspect ACL                             |
| `setfacl` | Modify ACL                              |

---

# 167. PROCESSES

| Command          | Purpose                         |
| ---------------- | ------------------------------- |
| `ps aux`         | Inspect processes               |
| `ps -eo ...`     | Display selected process fields |
| `top`            | Interactive monitoring          |
| `htop`           | Optional interactive monitoring |
| `pgrep`          | Find matching processes         |
| `kill -TERM PID` | Request termination             |
| `kill -KILL PID` | Force termination               |
| `jobs -l`        | List shell jobs                 |
| `fg`             | Foreground selected job         |
| `bg`             | Background selected stopped job |
| `nice`           | Start with selected nice value  |
| `renice`         | Change nice value               |
| `free -h`        | Memory usage                    |
| `uptime`         | Uptime and load                 |
| `vmstat`         | Virtual memory statistics       |

---

# 168. SYSTEMD

| Command                       | Purpose                      |
| ----------------------------- | ---------------------------- |
| `systemctl status UNIT`       | Inspect unit                 |
| `systemctl start UNIT`        | Start unit                   |
| `systemctl stop UNIT`         | Stop unit                    |
| `systemctl restart UNIT`      | Restart unit                 |
| `systemctl enable UNIT`       | Configure startup activation |
| `systemctl enable --now UNIT` | Enable and start             |
| `systemctl daemon-reload`     | Reload unit definitions      |
| `systemctl --user`            | Manage user units            |
| `journalctl -u UNIT`          | Unit logs                    |
| `journalctl -f`               | Follow journal               |
| `systemctl list-timers`       | Inspect system timers        |

---

# 169. NETWORKING

| Command             | Purpose                                       |
| ------------------- | --------------------------------------------- |
| `ip addr`           | IP addresses                                  |
| `ip -br addr`       | Concise address view                          |
| `ip link`           | Network interfaces                            |
| `ip route`          | Routes                                        |
| `ss -lnt`           | TCP listeners                                 |
| `ss -tulnp`         | Listening sockets with available process info |
| `getent hosts NAME` | Hostname lookup                               |
| `resolvectl status` | Resolver status where supported               |
| `dig NAME`          | DNS query                                     |
| `ping -c 3 ADDRESS` | ICMP probe                                    |
| `curl URL`          | Application-level HTTP request                |
| `ssh USER@HOST`     | SSH connection                                |

---

# 170. STORAGE AND BACKUPS

| Command       | Purpose                 |
| ------------- | ----------------------- |
| `lsblk -f`    | Devices and filesystems |
| `df -h`       | Filesystem capacity     |
| `df -i`       | Inode usage             |
| `du -sh PATH` | Path disk usage         |
| `findmnt`     | Mount information       |
| `blkid`       | Block-device identity   |
| `pvs`         | LVM physical volumes    |
| `vgs`         | LVM volume groups       |
| `lvs`         | LVM logical volumes     |
| `tar -czf`    | Create gzip archive     |
| `tar -tzf`    | Inspect gzip archive    |
| `tar -xzf`    | Extract gzip archive    |
| `gzip`        | Compress                |
| `rsync -av`   | Synchronize             |
| `rsync -avn`  | Preview synchronization |
| `scp`         | Secure file copy        |

---

# 171. SCHEDULING

| Command                        | Purpose                |
| ------------------------------ | ---------------------- |
| `crontab -l`                   | List user cron entries |
| `crontab -e`                   | Edit user cron entries |
| `systemctl list-timers`        | List systemd timers    |
| `systemctl --user list-timers` | List user timers       |
| `systemctl --user start UNIT`  | Start user unit        |
| `journalctl --user -u UNIT`    | Inspect user unit logs |

---

# PART XVII — FORMAL ACADEMIC EXAMINATION

## 172. PART A — DEFINITIONS

Define:

1. Linux user.
2. UID.
3. Group.
4. GID.
5. Primary group.
6. Supplementary group.
7. Root.
8. Sudo.
9. File ownership.
10. Read permission.
11. Write permission.
12. Execute permission.
13. Umask.
14. ACL.
15. Setuid.
16. Setgid.
17. Sticky bit.
18. Process.
19. PID.
20. PPID.
21. Signal.
22. Zombie process.
23. Foreground job.
24. Background job.
25. Systemd.
26. Service unit.
27. Timer unit.
28. Journal.
29. Network interface.
30. IP address.
31. CIDR.
32. TCP.
33. UDP.
34. Port.
35. Route.
36. Default gateway.
37. DNS.
38. SSH.
39. Filesystem.
40. Partition.
41. Mount point.
42. UUID.
43. LVM.
44. Archive.
45. Backup.
46. Cron.
47. RPO.
48. RTO.

---

# 173. PART B — SHORT-ANSWER QUESTIONS

**Question 1.** Explain the difference between a username and UID.

**Question 2.** Explain the difference between a primary group and supplementary groups.

**Question 3.** Why should ordinary application processes not automatically run as root?

**Question 4.** Explain the difference between chmod and chown.

**Question 5.** Interpret permission mode 750.

**Question 6.** Explain why directory execute permission matters.

**Question 7.** Explain how umask affects new file permissions.

**Question 8.** Describe the purpose of an ACL.

**Question 9.** Explain the relationship between a process and its PID.

**Question 10.** Distinguish SIGTERM from SIGKILL.

**Question 11.** Explain why background jobs are not equivalent to reliable managed services.

**Question 12.** Explain the difference between systemctl start and enable.

**Question 13.** Describe the purpose of the systemd journal.

**Question 14.** Explain how an IP address and port identify a service endpoint.

**Question 15.** Explain the difference between DNS and routing.

**Question 16.** Why does a failed ping not conclusively prove network unavailability?

**Question 17.** Explain the purpose of SSH public and private keys.

**Question 18.** Describe the difference between a partition and a filesystem.

**Question 19.** Explain the difference between df and du.

**Question 20.** Explain the PV, VG, and LV relationship in LVM.

**Question 21.** Explain the difference between tar and gzip.

**Question 22.** Explain why the rsync trailing slash matters.

**Question 23.** Compare cron and systemd timers.

**Question 24.** Explain why a backup needs restoration testing.

---

# 174. PART C — COMMAND INTERPRETATION

Explain:

```bash
id
```

Explain:

```bash
chmod 640 settings.conf
```

Explain:

```bash
sudo chown appuser:appgroup app.conf
```

Explain:

```bash
umask 077
```

Explain:

```bash
ps -eo pid,ppid,user,stat,comm
```

Explain:

```bash
kill -TERM 1234
```

Explain:

```bash
systemctl status ssh
```

Explain:

```bash
journalctl -u ssh -n 50
```

Explain:

```bash
ss -lnt
```

Explain:

```bash
ip route
```

Explain:

```bash
findmnt -T /home
```

Explain:

```bash
df -i
```

Explain:

```bash
tar -tzf backup.tar.gz
```

Explain:

```bash
rsync -avn data/ backup/
```

---

# 175. PART D — CASE STUDIES

## Case Study 1 — Permission Denied

A Python application cannot read a configuration file.

The administrator discovers that the file is owned by root and has mode 600.

Explain why a non-root process may be denied access and propose a least-privilege correction.

## Case Study 2 — Service Failure

A systemd-managed application fails immediately after startup.

Explain how to investigate status, logs, executable paths, permissions, and dependencies.

## Case Study 3 — Port Conflict

An application reports that its port is already in use.

Describe how to identify the listener and decide whether the service or application configuration should change.

## Case Study 4 — DNS Failure

A server can reach a known IP address but cannot resolve hostnames.

Describe the likely diagnostic area and relevant commands.

## Case Study 5 — Storage Failure

An application reports insufficient space despite apparently available disk capacity.

Explain how inode exhaustion or another filesystem condition might contribute.

## Case Study 6 — Unverified Backup

A backup job reports success, but the archive has never been restored.

Explain the remaining operational risks.

---

# 176. PRACTICAL EXAMINATION — 100 MARKS

| Category                  |   Marks |
| ------------------------- | ------: |
| Users and groups          |      10 |
| Permissions and ownership |      15 |
| Processes and signals     |      10 |
| Systemd services and logs |      15 |
| Networking and SSH        |      15 |
| Storage and filesystems   |      10 |
| Archives and transfers    |      10 |
| Scheduling and backup     |      10 |
| Laboratory documentation  |       5 |
| **Total**                 | **100** |

**Suggested passing standard:** 80/100.

A successful student should demonstrate conceptual understanding and safe execution of the relevant administrative procedures.

---

# PART XVIII — INDEPENDENT ACADEMIC ASSIGNMENT

## 177. ASSIGNMENT TITLE

**Linux System Administration: Identity Management, Permissions, Process Supervision, Network Services, Storage, and Automated Backup**

Prepare a technical report of approximately 2,000–2,500 words covering:

1. Linux users and groups.
2. User and group identifiers.
3. Root and sudo.
4. Account databases.
5. File ownership.
6. Permission bits.
7. Directory access.
8. ACLs.
9. Umask.
10. Linux processes.
11. Process states.
12. Signals.
13. Resource monitoring.
14. Systemd services.
15. Journal logging.
16. Network interfaces.
17. IP addressing.
18. Routing.
19. DNS.
20. TCP and UDP.
21. SSH authentication.
22. Storage devices.
23. Partitions.
24. Filesystems.
25. Mount points.
26. LVM.
27. Archives and compression.
28. Rsync and SCP.
29. Cron.
30. Systemd timers.
31. Backup verification.
32. Restoration and recovery.

Include:

- A Linux user/group access diagram.
- An rwx permission diagram.
- A process/service architecture diagram.
- A TCP/IP network diagram.
- A disk-to-filesystem architecture diagram.
- A backup-and-recovery workflow.
- Command-output evidence from the laboratory.
- A short risk assessment.

---

# PART XIX — THE COMPLETE LECTURE IN TEN PRINCIPLES

## 178. PRINCIPLE 1 — IDENTITY

A Linux user is an operating-system identity associated with a UID.

Groups organize shared access through GIDs.

---

# 179. PRINCIPLE 2 — PRIVILEGES

Root has extensive administrative authority.

Use sudo only for operations that genuinely require elevated permissions.

---

# 180. PRINCIPLE 3 — PERMISSIONS

Traditional Linux permissions distinguish owner, group, and others.

Read, write, and execute rights depend on both file and directory access requirements.

---

# 181. PRINCIPLE 4 — PROCESSES

Applications run as processes.

Processes have PIDs, states, resource usage, and signal-handling behavior.

---

# 182. PRINCIPLE 5 — SERVICES

A systemd service provides a managed execution environment for an application.

A running application and an enabled service are not the same thing.

---

# 183. PRINCIPLE 6 — NETWORKING

IP addresses identify endpoints in an IP network context.

Ports identify transport endpoints.

Routes determine how traffic moves toward destinations.

DNS helps map names to addresses.

---

# 184. PRINCIPLE 7 — SSH

SSH provides authenticated encrypted remote communication.

Private keys must be protected, and server identity should be verified.

---

# 185. PRINCIPLE 8 — STORAGE

Disks, partitions, filesystems, logical volumes, and mount points are distinct concepts.

Always identify actual devices and data before changing storage configuration.

---

# 186. PRINCIPLE 9 — SCHEDULING

Cron and systemd timers can automate recurring operations.

A scheduled task must be monitored and verified, not merely configured.

---

# 187. PRINCIPLE 10 — RECOVERY

Persistent data requires a recovery strategy.

A backup must be independently restorable and its restored content verified.

---

# PART XX — REFERENCES

## Official Ubuntu Server Documentation

[1] Ubuntu. _Ubuntu Server Documentation._  
https://ubuntu.com/server/docs/

[2] Ubuntu. _User Management._  
https://ubuntu.com/server/docs/how-to/security/user-management/

[3] Ubuntu. _OpenSSH Server._  
https://ubuntu.com/server/docs/how-to/security/openssh-server/

[4] Ubuntu. _Configuring Networks._  
https://ubuntu.com/server/docs/explanation/networking/configuring-networks/

[5] Ubuntu. _Managing Logical Volumes._  
https://ubuntu.com/server/docs/how-to/storage/manage-logical-volumes/

## Linux Manual Pages

[6] Linux man-pages Project. _Linux Manual Pages._  
https://man7.org/linux/man-pages/

[7] Linux man-pages Project. _chmod._  
https://man7.org/linux/man-pages/man1/chmod.1.html

[8] Linux man-pages Project. _kill._  
https://man7.org/linux/man-pages/man1/kill.1.html

[9] Linux man-pages Project. _mount._  
https://man7.org/linux/man-pages/man8/mount.8.html

[10] Linux man-pages Project. _fstab._  
https://man7.org/linux/man-pages/man5/fstab.5.html

[11] Linux man-pages Project. _crontab._  
https://man7.org/linux/man-pages/man5/crontab.5.html

## Systemd Documentation

[12] Systemd Project. _systemd.service._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html

[13] Systemd Project. _systemd.timer._  
https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html

[14] Systemd Project. _systemctl._  
https://www.freedesktop.org/software/systemd/man/latest/systemctl.html

[15] Systemd Project. _journalctl._  
https://www.freedesktop.org/software/systemd/man/latest/journalctl.html

## Linux Administration and Utilities

[16] GNU Project. _Coreutils Manual._  
https://www.gnu.org/software/coreutils/manual/

[17] OpenSSH Project. _OpenSSH._  
https://www.openssh.com/

[18] Samba Project. _Rsync Documentation._  
https://rsync.samba.org/

[19] GNU Project. _GNU Tar Manual._  
https://www.gnu.org/software/tar/manual/

[20] The Linux Kernel Project. _Kernel Documentation._  
https://docs.kernel.org/

---

# PART XXI — FINAL CONCLUSION

## 188. LECTURE CONCLUSION

This lecture establishes the principal concepts and tools required for Linux system administration.

Linux uses user identities and groups to organize ownership and access.

Root and sudo provide mechanisms for privileged system operations.

Traditional permissions, ACLs, umask, and special permission bits determine how users and processes interact with filesystem resources.

Processes are running instances of programs.

Administrators use process inspection, signals, resource statistics, and job-control concepts to understand their behavior.

Systemd provides a framework for managing services, timers, and related system resources.

Journal logging enables investigation of service execution and failures.

Linux networking depends on interfaces, addresses, routing, DNS, transport protocols, and ports.

SSH provides secure remote administration and file-transfer capabilities.

Storage administration requires understanding the difference between devices, partitions, filesystems, logical volumes, and mount points.

Archives and file-synchronization tools support data movement and recovery procedures.

Cron and systemd timers enable recurring administrative operations.

Backups preserve recoverable copies of important data, but their effectiveness must be established through verification and restoration.

The practical laboratory combines these concepts through a small Linux service, controlled permissions, process inspection, loopback networking, systemd management, archive creation, scheduled backups, and independent restoration.

A student who understands this lecture should be able to administer basic Linux resources, diagnose common failures, and operate a small application environment safely.

These abilities prepare the student for advanced Linux server engineering.

**END OF MAJOR LECTURE 02**

**Next: Major Lecture 03 — Advanced Bash, Linux Internals, SSH Hardening, Firewalls, Security, Nginx, Monitoring, Troubleshooting, Production Automation, and Final Linux Server Capstone.**
