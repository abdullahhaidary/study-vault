# LINUX: FOUNDATIONS, SYSTEM ADMINISTRATION, AND PROFESSIONAL SERVER ENGINEERING

## MAJOR LECTURE 01 — LINUX FUNDAMENTALS, TERMINAL, BASH, FILESYSTEM STRUCTURE, FILE OPERATIONS, TEXT PROCESSING, AND PACKAGE MANAGEMENT

**Course:** Linux: Foundations to Professional System Administration  
**Lecture:** 01 of 03  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, Command-Line Laboratory, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 7–10 Hours  
**Recommended Environment:** Ubuntu Linux or Ubuntu Server, preferably in a dedicated practice virtual machine  
**Prerequisites:** Basic computer literacy; prior terminal, Docker, or Git experience is helpful but not required

**Major Topics:**

1. Linux and Operating-System Architecture
2. Linux Distributions and the Kernel
3. Terminal, Shell, and Bash
4. Linux Filesystem Hierarchy
5. Paths and Directory Navigation
6. File and Directory Management
7. Text File Viewing and Editing
8. Searching Files and Processing Text
9. Bash Variables, Expansion, and Quoting
10. Pipes, Redirection, and Command Execution
11. Package Management and Software Repositories
12. Complete Linux Command-Line Capstone

---

# PART I — INTRODUCTION TO LINUX

## 1. PURPOSE OF THE LECTURE

Linux is one of the most important technologies in modern computing.

It is widely used in:

- Web servers.
- Cloud infrastructure.
- Development environments.
- Databases.
- Container platforms.
- Networking equipment.
- Embedded systems.
- High-performance computing.
- Automation.
- Software engineering.

Many applications that developers use every day operate on Linux-based systems.

For example, a developer may write code on a laptop, commit changes using Git, build a Docker image, and deploy the application to a Linux server.

Although these technologies serve different purposes, the underlying operating-system concepts are closely related.

Understanding Linux helps developers understand processes, files, permissions, networking, resource management, scripting, and server operations.

The purpose of this lecture is to establish a strong foundation in Linux before advancing to user administration, services, networking, storage, security, and production operations.

By the end of this lecture, the student should be comfortable navigating Linux from the command line, managing files and directories, reading configuration files, searching information, using Bash, and understanding basic software package management.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Define Linux.
2. Define an operating system.
3. Explain the Linux kernel.
4. Distinguish the kernel from a Linux distribution.
5. Explain user space and kernel space.
6. Explain the purpose of system calls.
7. Identify common Linux distributions.
8. Distinguish Linux from Unix.
9. Explain the role of the terminal.
10. Explain the role of the shell.
11. Define Bash.
12. Interpret a shell command.
13. Understand arguments and options.
14. Navigate absolute and relative paths.
15. Explain the Linux root directory.
16. Identify important Linux filesystem directories.
17. Use `pwd`, `ls`, and `cd`.
18. Create files and directories.
19. Copy, rename, move, and remove files.
20. Explain hard links and symbolic links.
21. Identify hidden files.
22. Read files using `cat`, `less`, `head`, and `tail`.
23. Edit text using Nano or Vim.
24. Search files with `find`.
25. Search content with `grep`.
26. Count and transform text with standard tools.
27. Explain shell variables.
28. Explain environment variables.
29. Explain the `PATH` variable.
30. Use shell quoting correctly.
31. Explain filename expansion and wildcards.
32. Use standard input, output, and error.
33. Redirect output to files.
34. Connect commands using pipes.
35. Explain command exit statuses.
36. Create a simple Bash script.
37. Explain software packages.
38. Distinguish APT and DNF.
39. Explain repositories and dependencies.
40. Find command documentation.
41. Complete a realistic Linux workspace project.

---

# PART II — UNDERSTANDING LINUX

## 3. WHAT IS LINUX?

Strictly speaking, Linux is an operating-system kernel.

However, in everyday conversation, people often use the word Linux to describe complete operating systems built around that kernel.

Examples include Ubuntu, Debian, and Fedora.

A complete Linux operating-system environment typically combines:

- Linux kernel.
- System libraries.
- Command-line utilities.
- Package-management tools.
- System services.
- Shell programs.
- Applications.
- Optional graphical desktop environments.

The Linux kernel is responsible for fundamental interactions between software and hardware.

The surrounding software makes the system usable.

### Simple Model

```text
               APPLICATIONS
                    |
                    v
             SYSTEM UTILITIES
                    |
                    v
               LINUX KERNEL
                    |
                    v
                 HARDWARE
```

### Important Principle

Linux is not merely a collection of terminal commands.

It is an operating-system foundation supporting many kinds of applications and computing environments.

---

# 4. WHAT IS AN OPERATING SYSTEM?

An operating system manages computer resources and provides services to software applications.

Its responsibilities include:

- Managing processes.
- Managing memory.
- Managing filesystems.
- Managing devices.
- Managing networking.
- Coordinating access to hardware.
- Providing security boundaries.
- Supporting application execution.

Consider a Python application.

The Python program does not normally communicate directly with the storage device's hardware controller.

Instead, the program uses operating-system interfaces to request filesystem operations.

The operating system handles those requests through the kernel and supporting software.

### Conceptual Example

```text
PYTHON PROGRAM
      |
      | Requests to read a file
      v
OPERATING-SYSTEM INTERFACE
      |
      v
LINUX KERNEL
      |
      v
STORAGE DEVICE
```

The operating system provides the controlled environment in which application software executes.

---

# 5. THE LINUX KERNEL

The Linux kernel is the central component responsible for managing core system resources.

Important kernel responsibilities include:

1. Process scheduling.
2. Memory management.
3. Filesystem interfaces.
4. Device drivers.
5. Networking.
6. Inter-process communication.
7. Security and access controls.

### Process Scheduling

The kernel decides how runnable processes receive CPU time.

### Memory Management

The kernel manages virtual memory and physical memory resources.

### Filesystems

The kernel implements filesystem interfaces and coordinates storage access.

### Networking

The kernel provides interfaces for network communication and implements much of the networking stack.

### Device Drivers

Drivers allow the operating system to communicate with supported hardware devices.

### Memory Principle

**The kernel manages resources. Applications request services from the kernel.**

---

# 6. USER SPACE AND KERNEL SPACE

Linux separates ordinary application execution from privileged kernel execution.

The two concepts are:

- User space.
- Kernel space.

## User Space

Normal applications execute in user space.

Examples:

- Bash.
- Python.
- Nginx.
- Git.
- Text editors.
- Database processes.

## Kernel Space

The kernel executes privileged operating-system operations.

### Architecture

```text
             USER SPACE
    +--------------------------+
    | Python                   |
    | Bash                     |
    | Git                      |
    | Nginx                    |
    +--------------------------+
                 |
                 | System calls
                 v
             KERNEL SPACE
    +--------------------------+
    | Process management       |
    | Memory management        |
    | Filesystem operations    |
    | Device management        |
    | Networking               |
    +--------------------------+
                 |
                 v
              HARDWARE
```

This separation supports controlled access to system resources.

---

# 7. WHAT ARE SYSTEM CALLS?

A system call is a mechanism through which a user-space program requests a kernel service.

Examples include operations related to:

- Reading files.
- Writing files.
- Creating processes.
- Opening network connections.
- Allocating memory.

A program may use a language runtime or standard library that ultimately invokes the appropriate kernel interface.

### Example

A Python application executes:

```python
with open("notes.txt") as file:
    content = file.read()
```

The Python runtime uses operating-system interfaces to request access to the file.

The kernel coordinates the underlying filesystem operations.

The Python developer does not need to manually implement disk access.

---

# 8. LINUX DISTRIBUTIONS

A Linux distribution combines the kernel with selected software and configuration to form a usable operating-system environment.

Different distributions make different choices regarding:

- Package management.
- Software versions.
- Default tools.
- Installation procedures.
- Release schedules.
- Security policies.
- Support models.
- Desktop environments.

Common distributions include:

| Distribution             | General characteristics                                     |
| ------------------------ | ----------------------------------------------------------- |
| Ubuntu                   | Widely used for desktops, servers, and cloud systems        |
| Debian                   | Community-driven distribution emphasizing reliability       |
| Fedora                   | Community distribution with relatively current technologies |
| Red Hat Enterprise Linux | Enterprise-oriented distribution and support ecosystem      |
| Rocky Linux              | Enterprise Linux-compatible distribution                    |
| AlmaLinux                | Enterprise Linux-compatible distribution                    |
| Arch Linux               | Rolling-release distribution emphasizing user configuration |
| Alpine Linux             | Small distribution often used in container images           |

These distributions all use the Linux kernel, but they do not necessarily include identical commands, package managers, or default configurations.

---

# 9. UBUNTU AND DEBIAN

Ubuntu is based on Debian.

Both commonly use:

```text
.deb
```

software packages.

Their primary package-management ecosystem includes:

- APT.
- dpkg.

Ubuntu is a practical choice for Linux training because it has extensive documentation, broad software availability, and widespread server usage.

For this course, the primary examples assume Ubuntu.

---

# 10. FEDORA AND RED HAT FAMILY

Fedora and related distributions commonly use RPM packages.

Fedora uses DNF for package management.

Some commands and configuration paths differ from Debian-based distributions.

For example:

### Ubuntu

```bash
sudo apt install tree
```

### Fedora

```bash
sudo dnf install tree
```

Both commands aim to install the `tree` utility, but through different package managers.

### Important Principle

Knowing Linux concepts is more important than memorizing only one distribution's package commands.

---

# 11. LINUX VERSUS UNIX

Unix refers to a family and tradition of operating-system designs, including systems conforming to relevant Unix specifications.

Linux is Unix-like.

Linux shares many concepts with Unix systems, including:

- Hierarchical filesystems.
- Process-oriented execution.
- Command-line shells.
- Small composable utilities.
- File permissions.
- Standard streams.

However, Linux is not simply a copy of one historical Unix operating system.

Its kernel and development history are distinct.

---

# PART III — LINUX ARCHITECTURE

## 12. MAIN LINUX COMPONENTS

A practical Linux environment includes several layers.

```text
                 USER
                  |
                  v
               TERMINAL
                  |
                  v
                SHELL
                  |
                  v
         COMMANDS / APPLICATIONS
                  |
                  v
           SYSTEM LIBRARIES
                  |
                  v
              LINUX KERNEL
                  |
                  v
               HARDWARE
```

Not every command must pass through each layer in the same way.

This diagram represents the general relationship between user applications and operating-system services.

---

# 13. THE TERMINAL

A terminal is an interface through which a user interacts with command-line programs.

A modern graphical terminal application provides a text-based interaction environment.

Examples include:

- GNOME Terminal.
- Konsole.
- Xfce Terminal.
- Other terminal emulators.
- Terminal access through SSH.

The terminal displays input and output and provides a way to interact with a shell.

### Important Distinction

A terminal is not the same thing as Bash.

The terminal provides the interface.

Bash interprets shell commands.

---

# 14. THE SHELL

A shell is a program that interprets commands and controls their execution.

The shell can:

- Launch programs.
- Process arguments.
- Expand variables.
- Connect commands.
- Redirect input and output.
- Execute scripts.
- Control selected command execution behavior.

Examples include:

- Bash.
- Zsh.
- Fish.
- Dash.

This course focuses on Bash.

---

# 15. WHAT IS BASH?

Bash stands for:

**Bourne Again Shell.**

Bash is both:

1. An interactive command interpreter.
2. A scripting language.

For example:

```bash
echo "Hello Linux"
```

Bash interprets the command and executes the appropriate operation.

A Bash script stores commands in a file so they can be executed repeatedly.

### Important Principle

The shell is the command interpreter, not the operating-system kernel.

---

# 16. CHECKING THE CURRENT SHELL

To inspect your configured login shell:

```bash
echo "$SHELL"
```

Example output:

```text
/bin/bash
```

This environment variable usually identifies the configured login shell.

To inspect the running Bash version when using Bash:

```bash
bash --version
```

To inspect the current shell process, depending on the environment:

```bash
ps -p $$ -o comm=
```

The results can differ in containers and specialized terminal environments.

---

# 17. THE COMMAND PROMPT

A shell prompt might look like:

```text
student@ubuntu:~$
```

Possible elements include:

```text
student    username
ubuntu     hostname
~          home directory
$          ordinary user prompt indicator
```

A prompt ending in `#` often indicates a root shell in common configurations.

However, prompt appearance is customizable.

Do not determine actual permissions solely from the prompt symbol.

---

# PART IV — UNDERSTANDING LINUX COMMANDS

## 18. COMMAND STRUCTURE

A Linux command often follows this general pattern:

```text
COMMAND [OPTIONS] [ARGUMENTS]
```

Example:

```bash
ls -l /home
```

### Command

```text
ls
```

Lists directory entries.

### Option

```text
-l
```

Requests a long listing format.

### Argument

```text
/home
```

Identifies the directory to inspect.

---

# 19. OPTIONS AND ARGUMENTS

Options modify command behavior.

Example:

```bash
ls -a
```

The `-a` option displays entries that would otherwise be hidden.

A long option may look like:

```bash
ls --all
```

Some commands accept combined short options:

```bash
ls -la
```

This requests both long format and inclusion of hidden entries.

### Important Detail

Not every command follows identical option conventions.

Consult the command's documentation.

---

# 20. COMMAND CASE SENSITIVITY

Linux filesystems and commands commonly treat uppercase and lowercase letters as different.

For example:

```text
Report.txt
report.txt
```

are ordinarily different filenames on standard Linux filesystems.

Likewise:

```text
ls
```

and:

```text
LS
```

are not generally the same command.

### Memory Principle

**On Linux, letter case usually matters.**

---

# 21. BUILT-IN AND EXTERNAL COMMANDS

Some commands are built into the shell.

Others are external executable programs.

For example:

```bash
type cd
```

typically identifies `cd` as a shell builtin.

```bash
type ls
```

may identify an executable, alias, or shell function depending on configuration.

### Why cd Is Usually Built In

Changing the current directory must affect the shell process itself.

An unrelated child process cannot simply change its parent's current directory.

### Useful Commands

```bash
type cd
type ls
command -v ls
```

---

# PART V — THE LINUX FILESYSTEM

## 22. THE ROOT DIRECTORY

Linux uses a hierarchical filesystem structure.

The top of the directory hierarchy is:

```text
/
```

This is called the root directory.

It is not the same as the root user's home directory.

### Root Directory

```text
/
```

### Root User's Home Directory

```text
/root
```

### Normal User's Home Directory

Commonly:

```text
/home/username
```

These are different filesystem locations.

---

# 23. THE LINUX FILESYSTEM TREE

A typical Linux filesystem contains directories such as:

```text
/
├── bin/
├── boot/
├── dev/
├── etc/
├── home/
│   └── student/
├── lib/
├── media/
├── mnt/
├── opt/
├── proc/
├── root/
├── run/
├── sbin/
├── srv/
├── sys/
├── tmp/
├── usr/
│   ├── bin/
│   ├── lib/
│   ├── local/
│   └── share/
└── var/
    ├── cache/
    ├── lib/
    └── log/
```

Not every Linux distribution exposes precisely the same directory layout.

For example, many modern systems use a merged `/usr` layout in which paths such as `/bin` are symbolic links into `/usr`.

---

# 24. IMPORTANT FILESYSTEM DIRECTORIES

| Directory    | Main purpose                                      |
| ------------ | ------------------------------------------------- |
| `/`          | Top of filesystem hierarchy                       |
| `/home`      | Normal user home directories                      |
| `/root`      | Root user's home directory                        |
| `/etc`       | Host-specific system configuration                |
| `/usr`       | Much installed software and shared resources      |
| `/usr/bin`   | Many user commands                                |
| `/usr/local` | Locally installed software hierarchy              |
| `/var`       | Variable system and application data              |
| `/var/log`   | Log files                                         |
| `/var/lib`   | Persistent application and service state          |
| `/tmp`       | Temporary files                                   |
| `/var/tmp`   | Temporary files commonly retained longer          |
| `/proc`      | Process and kernel information interface          |
| `/sys`       | Kernel device and subsystem information interface |
| `/dev`       | Device-related filesystem entries                 |
| `/boot`      | Boot-related files                                |
| `/run`       | Runtime state                                     |
| `/opt`       | Add-on software                                   |
| `/mnt`       | Temporary manual mount locations                  |
| `/media`     | Common locations for removable media mounts       |
| `/srv`       | Data associated with services                     |

These locations are described by Linux conventions and the Filesystem Hierarchy Standard.

---

# 25. THE /HOME DIRECTORY

Normal users commonly have home directories under:

```text
/home
```

Example:

```text
/home/student
```

A user can store:

- Documents.
- Source code.
- Personal configuration.
- Downloads.
- Scripts.
- Practice projects.

The environment variable:

```bash
echo "$HOME"
```

normally identifies the current user's home directory.

### Practical Principle

Perform ordinary learning exercises inside your home directory, not in sensitive system locations.

---

# 26. THE /ETC DIRECTORY

The `/etc` directory contains host-specific system configuration.

Examples may include:

```text
/etc/passwd
/etc/hostname
/etc/hosts
/etc/ssh/
/etc/apt/
```

Some files are readable by ordinary users.

Others require elevated permissions.

### Important Warning

Do not modify system configuration files merely to practice file operations.

Use safe copies in your own practice workspace.

---

# 27. THE /VAR DIRECTORY

The `/var` hierarchy contains variable system and application data.

Examples:

```text
/var/log
/var/lib
/var/cache
```

### /var/log

Contains log-related data.

### /var/lib

Contains persistent state used by selected system services and applications.

### /var/cache

Contains cache data.

### Important Principle

`/var` is associated with data that changes during ordinary system operation.

---

# 28. THE /USR DIRECTORY

The `/usr` hierarchy contains much of the installed system software.

Examples:

```text
/usr/bin
/usr/lib
/usr/share
/usr/local
```

### /usr/bin

Contains many executable commands.

### /usr/lib

Contains libraries and supporting files.

### /usr/share

Contains architecture-independent shared resources.

### /usr/local

Provides a hierarchy for locally installed software.

Do not confuse `/usr` with an individual user's home directory.

---

# 29. THE /TMP DIRECTORY

`/tmp` is used for temporary files.

Its contents may be removed through system cleanup policies.

The exact cleanup behavior depends on the system.

### Important Principle

Do not store the only copy of valuable data in `/tmp`.

For temporary work that needs greater persistence across reboots, `/var/tmp` may be appropriate according to system policy.

---

# 30. THE /PROC DIRECTORY

`/proc` is a virtual filesystem providing interfaces to process and kernel information.

Examples:

```bash
cat /proc/version
```

```bash
cat /proc/meminfo
```

The displayed information is generated through the kernel interface rather than simply representing ordinary files stored on a disk.

### Connection to Docker

Linux containers may have their own process namespace and corresponding view of parts of `/proc`.

This helps explain why process listings inside a container differ from those on the host.

---

# 31. THE /DEV DIRECTORY

`/dev` contains device-related special filesystem entries.

Examples:

```text
/dev/null
/dev/zero
/dev/random
```

### /dev/null

Discards data written to it.

For example:

```bash
printf 'discard this\n' > /dev/null
```

### Important Principle

Not every filesystem entry behaves like an ordinary regular file.

Some represent devices or kernel interfaces.

---

# PART VI — PATHS AND NAVIGATION

## 32. ABSOLUTE PATHS

An absolute path begins at the root directory.

Example:

```text
/home/student/projects/app.py
```

It identifies a location independently of the shell's current working directory.

### Memory Principle

**Absolute path = starts with `/`.**

---

# 33. RELATIVE PATHS

A relative path is interpreted relative to the current working directory.

Example:

```text
projects/app.py
```

If the current directory is:

```text
/home/student
```

the relative path refers to:

```text
/home/student/projects/app.py
```

### Memory Principle

**Relative path = starts from where you currently are.**

---

# 34. SPECIAL PATH SYMBOLS

Several symbols are especially important.

| Symbol | Meaning                                  |
| ------ | ---------------------------------------- |
| `/`    | Root directory                           |
| `.`    | Current directory                        |
| `..`   | Parent directory                         |
| `~`    | Home directory in common shell expansion |
| `-`    | Previous directory when used with `cd -` |

Examples:

```bash
cd .
```

```bash
cd ..
```

```bash
cd ~
```

```bash
cd -
```

---

# 35. THE pwd COMMAND

`pwd` stands for:

**Print Working Directory.**

Execute:

```bash
pwd
```

Example output:

```text
/home/student
```

The command reports the current directory.

This is one of the most important commands when navigating Linux.

---

# 36. THE ls COMMAND

`ls` lists directory entries.

Examples:

```bash
ls
```

```bash
ls -l
```

```bash
ls -a
```

```bash
ls -la
```

```bash
ls -lh
```

### Common Options

| Option | Meaning                                    |
| ------ | ------------------------------------------ |
| `-l`   | Long listing                               |
| `-a`   | Include hidden entries                     |
| `-h`   | Human-readable sizes with suitable formats |
| `-t`   | Sort by modification time                  |
| `-R`   | Recursively list subdirectories            |

### Important Detail

`ls -R` can produce very large output when used on large directory trees.

---

# 37. HIDDEN FILES

A filename beginning with a dot is commonly treated as hidden by ordinary directory listings.

Examples:

```text
.bashrc
.profile
.gitconfig
```

Display hidden entries:

```bash
ls -a
```

### Important Principle

Hidden files are not automatically protected or secret.

A leading dot mainly affects ordinary listing behavior.

---

# 38. THE cd COMMAND

`cd` stands for:

**Change Directory.**

Examples:

```bash
cd /home
```

```bash
cd ..
```

```bash
cd "$HOME"
```

```bash
cd -
```

The `cd` command changes the shell's current working directory.

### Useful Habit

After changing directories, use:

```bash
pwd
```

to confirm your location.

---

# 39. THE TREE COMMAND

The optional `tree` utility displays directory structure hierarchically.

Example:

```bash
tree .
```

If `tree` is not installed, it may need to be installed through the appropriate package manager.

Another option is:

```bash
find . -print
```

The commands do not present identical formats, but both can help inspect a directory tree.

---

# PART VII — CREATING AND MANAGING FILES

## 40. CREATING DIRECTORIES

Use:

```bash
mkdir projects
```

Create nested directories:

```bash
mkdir -p projects/python/tests
```

The `-p` option allows parent directories to be created as necessary.

It also avoids reporting an error merely because an existing directory already exists.

---

# 41. CREATING EMPTY FILES

Use:

```bash
touch notes.txt
```

If the file does not exist, this ordinarily creates an empty file.

If it exists, `touch` normally updates selected timestamps.

### Important Principle

`touch` does not necessarily leave an existing file unchanged in metadata.

---

# 42. COPYING FILES

Use:

```bash
cp notes.txt notes-backup.txt
```

This creates or replaces a destination file according to command behavior and available permissions.

For directories, GNU `cp` supports:

```bash
cp -r source-directory destination-directory
```

### Safety Habit

Before copying to an important destination, inspect its contents.

GNU `cp -i` can request confirmation before overwriting:

```bash
cp -i source.txt destination.txt
```

---

# 43. MOVING AND RENAMING FILES

Use:

```bash
mv old-name.txt new-name.txt
```

This renames a file within the relevant filesystem environment.

Move a file into a directory:

```bash
mv report.txt archive/
```

### Important Principle

`mv` may overwrite an existing destination depending on options and circumstances.

For interactive confirmation:

```bash
mv -i source.txt destination.txt
```

---

# 44. REMOVING FILES

Use:

```bash
rm unwanted.txt
```

For an empty directory:

```bash
rmdir empty-directory
```

### Critical Warning

Unlike a graphical recycle bin, ordinary `rm` operations do not normally provide a simple trash-based recovery workflow.

Be especially careful with recursive removal:

```text
rm -r DIRECTORY
```

And avoid executing destructive removal commands against unknown paths.

For this lecture, use ordinary test files in a dedicated practice workspace.

---

# 45. THE LINK CONCEPT

Linux filesystems support different kinds of links.

Two common types are:

1. Hard links.
2. Symbolic links.

---

# 46. HARD LINKS

A hard link is another directory entry referring to the same underlying file object on a filesystem.

Example:

```bash
ln original.txt another-name.txt
```

Both names refer to the same underlying regular-file content.

A change written through either name is visible through the other.

Hard links have filesystem restrictions and are not generally used to link ordinary directories.

---

# 47. SYMBOLIC LINKS

A symbolic link stores a path referring to another filesystem location.

Example:

```bash
ln -s original.txt shortcut.txt
```

A symbolic link can point to a file or directory.

The target may be missing, in which case the link can be dangling.

### Comparison

| Hard link                                                         | Symbolic link                       |
| ----------------------------------------------------------------- | ----------------------------------- |
| Another name for the same file object                             | Stores a path to a target           |
| Ordinarily within the same filesystem                             | Can cross filesystem boundaries     |
| Usually for regular files                                         | Can refer to files or directories   |
| Removing one name need not remove content while other links exist | Can become dangling if target moves |

---

# 48. INSPECTING FILE TYPES

Use:

```bash
file notes.txt
```

This attempts to classify the file.

Use:

```bash
ls -l
```

to see long-format entries.

The first character in a traditional long listing indicates a file type.

For example:

```text
-
```

commonly indicates a regular file.

```text
d
```

indicates a directory.

```text
l
```

indicates a symbolic link.

Detailed ownership and permission management will be covered in Major Lecture 02.

---

# PART VIII — READING AND EDITING TEXT

## 49. THE cat COMMAND

`cat` can display file contents.

Example:

```bash
cat notes.txt
```

It can also concatenate content from multiple files.

Example:

```bash
cat first.txt second.txt
```

### Important Detail

`cat` is convenient for small files.

For long files, a pager such as `less` is often easier to use.

---

# 50. THE less COMMAND

Use:

```bash
less notes.txt
```

`less` provides interactive navigation through text.

Common controls include:

| Key     | Action            |
| ------- | ----------------- |
| Space   | Page forward      |
| `b`     | Page backward     |
| `/word` | Search forward    |
| `n`     | Next search match |
| `q`     | Quit              |

The exact interaction depends on the pager configuration.

---

# 51. THE head COMMAND

Use:

```bash
head notes.txt
```

This ordinarily shows the first ten lines.

Show five lines:

```bash
head -n 5 notes.txt
```

This is useful for quickly inspecting the beginning of a file.

---

# 52. THE tail COMMAND

Use:

```bash
tail notes.txt
```

This ordinarily shows the last ten lines.

Show five:

```bash
tail -n 5 notes.txt
```

Follow appended output:

```bash
tail -f application.log
```

This is particularly useful for observing log files that continue to receive new lines.

Stop interactive following with Ctrl+C.

---

# 53. THE NANO EDITOR

Nano is a terminal-based text editor.

Open a file:

```bash
nano notes.txt
```

Common shortcuts include:

| Shortcut | Action           |
| -------- | ---------------- |
| Ctrl+O   | Write file       |
| Enter    | Confirm filename |
| Ctrl+X   | Exit             |
| Ctrl+W   | Search           |
| Ctrl+K   | Cut line         |
| Ctrl+U   | Paste line       |

Nano is convenient for beginners.

It may need to be installed on minimal Linux environments.

---

# 54. THE VIM EDITOR

Vim is a modal text editor.

This means different modes interpret keys differently.

### Normal Mode

Used for navigation and commands.

### Insert Mode

Used for inserting text.

### Command-Line Mode

Used for selected editor commands.

Open:

```bash
vim notes.txt
```

Enter insert mode:

```text
i
```

Return to normal mode:

```text
Esc
```

Save and quit:

```text
:wq
```

Quit without saving:

```text
:q!
```

### Important Principle

Vim's modes must be understood before editing confidently.

The editor may not be installed in every minimal Linux environment.

---

# 55. NANO VERSUS VIM

| Nano                              | Vim                                                |
| --------------------------------- | -------------------------------------------------- |
| Straightforward editing interface | Modal editing model                                |
| Easy to learn initially           | Greater investment in commands and modes           |
| Useful for quick edits            | Powerful for complex editing                       |
| Common in beginner tutorials      | Widely used in server and development environments |

Both can be useful.

A Linux engineer should be able to work with at least one terminal editor.

---

# PART IX — SEARCHING FILES

## 56. THE find COMMAND

`find` searches a directory hierarchy.

Example:

```bash
find . -name "*.txt"
```

This searches for matching filenames under the current directory.

The wildcard pattern is quoted so the shell passes it to `find` rather than expanding it before `find` runs.

---

# 57. COMMON FIND EXPRESSIONS

Search regular files:

```bash
find . -type f
```

Search directories:

```bash
find . -type d
```

Search filenames:

```bash
find . -name "*.py"
```

Case-insensitive filename search:

```bash
find . -iname "*.TXT"
```

Limit search depth using GNU `find`:

```bash
find . -maxdepth 2 -type f
```

Search results depend on filesystem permissions and actual directory contents.

---

# 58. SEARCHING FILE CONTENT WITH GREP

`grep` searches text using patterns.

Example:

```bash
grep "ERROR" application.log
```

Display matching lines with line numbers:

```bash
grep -n "ERROR" application.log
```

Ignore case:

```bash
grep -i "error" application.log
```

Search recursively:

```bash
grep -R "ERROR" logs/
```

---

# 59. FIXED STRINGS VERSUS REGULAR EXPRESSIONS

By default, `grep` treats its pattern according to regular-expression rules.

For a literal text search:

```bash
grep -F "ERROR" application.log
```

The `-F` option treats the pattern as a fixed string.

### Why This Matters

Characters such as:

```text
.
*
[
]
```

can have special meanings in regular expressions.

Use fixed-string searching when you want those characters treated literally.

---

# 60. GREP EXIT STATUS

A successful match ordinarily produces exit status:

```text
0
```

No matching line ordinarily produces:

```text
1
```

Other errors normally produce a different nonzero status.

This matters when writing shell scripts.

A command returning 1 does not always mean the operating system or application is broken.

It may simply mean that no matching line was found.

---

# PART X — TEXT PROCESSING

## 61. THE wc COMMAND

`wc` counts selected text properties.

Examples:

```bash
wc -l notes.txt
```

Counts lines.

```bash
wc -w notes.txt
```

Counts words.

```bash
wc -c notes.txt
```

Counts bytes.

The results depend on the file's actual content.

---

# 62. THE sort COMMAND

`sort` arranges lines.

Example:

```bash
sort names.txt
```

Numerical sorting:

```bash
sort -n numbers.txt
```

Reverse sorting:

```bash
sort -r names.txt
```

Sorting rules can depend on locale.

For reproducible byte-oriented ordering in appropriate situations:

```bash
LC_ALL=C sort names.txt
```

---

# 63. THE uniq COMMAND

`uniq` works with adjacent repeated lines.

Example:

```bash
uniq names.txt
```

Count adjacent duplicates:

```bash
uniq -c names.txt
```

### Important Principle

`uniq` does not automatically search for duplicates throughout an arbitrarily ordered file.

To group equal lines before counting:

```bash
sort names.txt | uniq -c
```

---

# 64. THE cut COMMAND

`cut` extracts selected portions of lines.

For a simple colon-delimited file:

```bash
cut -d ':' -f 1 file.txt
```

### Explanation

`-d ':'` sets the field delimiter.

`-f 1` selects the first field.

Example input:

```text
alice:developer
bob:designer
```

Output:

```text
alice
bob
```

`cut` is useful for simple delimited text.

It is not a full general-purpose CSV parser.

---

# 65. THE sed COMMAND

`sed` is a stream editor.

It can filter and transform text.

Example:

```bash
sed 's/error/ERROR/g' notes.txt
```

This replaces occurrences of the lowercase text `error` with uppercase `ERROR` in the output.

The original file is not modified by this command.

Display selected lines:

```bash
sed -n '1,5p' notes.txt
```

This prints lines 1 through 5.

### Important Distinction

Printing transformed text is different from modifying the original file in place.

---

# 66. THE awk COMMAND

`awk` is a text-processing language especially useful for structured records and fields.

Example:

```bash
awk '{print $1}' notes.txt
```

This prints the first whitespace-separated field of each input record.

Example file:

```text
alice developer
bob designer
```

Output:

```text
alice
bob
```

Custom delimiters are possible:

```bash
awk -F, '{print $2}' tasks.csv
```

This example assumes simple comma-delimited data without quoting or embedded commas.

For complex CSV, use a proper CSV-aware parser.

---

# 67. TOOL COMPOSITION

A major Linux philosophy is combining small tools.

Instead of requiring one large program to perform every operation, Linux shells allow commands to work together.

For example:

```bash
grep "ERROR" application.log | wc -l
```

This:

1. Selects lines containing `ERROR`.
2. Counts the resulting lines.

### Important Principle

Each command does one focused operation, while the pipeline combines them into a larger operation.

---

# PART XI — BASH FUNDAMENTALS

## 68. WHAT IS A SHELL VARIABLE?

A shell variable stores a value in the shell's execution environment.

Example:

```bash
NAME="Linux Student"
```

Read it:

```bash
echo "$NAME"
```

Output:

```text
Linux Student
```

### Important Syntax Rule

In a normal Bash variable assignment, do not place spaces around `=`.

Correct:

```bash
NAME="Linux"
```

Incorrect:

```text
NAME = "Linux"
```

---

# 69. VARIABLE EXPANSION

Bash expands variable references.

Example:

```bash
PROJECT="task-manager"
```

```bash
printf 'Project: %s\n' "$PROJECT"
```

Output:

```text
Project: task-manager
```

Braces can make boundaries explicit:

```bash
printf '%s\n' "${PROJECT}-backup"
```

Output:

```text
task-manager-backup
```

---

# 70. SHELL VARIABLES VERSUS ENVIRONMENT VARIABLES

A shell variable exists in the shell's state.

An exported environment variable is normally passed to child processes.

Example:

```bash
APP_MODE="development"
```

Export:

```bash
export APP_MODE
```

A child program may now read the variable from its environment.

Alternatively:

```bash
export APP_MODE="development"
```

### Important Connection to Docker

Docker's `-e` option and Compose `environment` configuration provide environment variables to container processes.

These are related to the same operating-system concepts.

---

# 71. THE PATH VARIABLE

`PATH` is an environment variable containing directories that the shell searches for commands.

Inspect:

```bash
printf '%s\n' "$PATH"
```

Its contents may resemble:

```text
/usr/local/bin:/usr/bin:/bin
```

The individual paths are separated by colons.

### How Command Lookup Works

When you enter:

```bash
python3
```

Bash searches suitable locations according to its command lookup rules.

`PATH` is important when resolving external executables.

---

# 72. CHECKING COMMAND LOCATIONS

Use:

```bash
command -v python3
```

Or:

```bash
type python3
```

These commands help determine how a command name is resolved.

### Important Security Habit

Avoid adding untrusted directories to the beginning of `PATH`.

Doing so can cause unintended executable files to be selected.

---

# 73. BASH QUOTING

Bash uses quoting to control how text is interpreted.

Three common forms are:

1. Unquoted text.
2. Single quotes.
3. Double quotes.

### Unquoted

```bash
echo $NAME
```

May be affected by word splitting and filename expansion.

### Single Quotes

```bash
echo '$NAME'
```

Prints the literal text:

```text
$NAME
```

### Double Quotes

```bash
echo "$NAME"
```

Expands the variable while preserving the result as an appropriately quoted argument.

---

# 74. WHY QUOTING MATTERS

Suppose:

```bash
FILE="my report.txt"
```

Correct:

```bash
cat "$FILE"
```

Without quotation:

```bash
cat $FILE
```

Bash may split the value into separate arguments:

```text
my
report.txt
```

The command may then fail or operate on unintended files.

### Important Rule

**Quote variable expansions unless you deliberately need another behavior.**

---

# 75. WILDCARDS AND GLOBS

The shell can expand filename patterns.

Examples:

```text
*
```

Matches filename sequences according to shell globbing rules.

```text
?
```

Matches one character in an appropriate filename pattern.

```text
[abc]
```

Matches a character from the specified set.

Example:

```bash
ls *.txt
```

Bash may expand `*.txt` into matching filenames before running `ls`.

### Important Distinction

A shell glob is not the same thing as a general regular expression.

---

# 76. TILDE EXPANSION

The tilde symbol commonly represents a user's home directory.

Example:

```bash
cd ~
```

This takes the shell to the current user's home directory.

However:

```bash
echo "~"
```

prints the literal tilde because the quotes prevent ordinary tilde expansion.

---

# 77. COMMAND SUBSTITUTION

Command substitution inserts the output of a command.

Example:

```bash
TODAY="$(date +%Y-%m-%d)"
```

Then:

```bash
printf 'Today: %s\n' "$TODAY"
```

The shell runs `date` and stores its output in the variable.

### Syntax

```text
$(COMMAND)
```

Command substitution is widely used in Bash scripts.

---

# 78. ARITHMETIC EXPANSION

Bash supports integer arithmetic expansion.

Example:

```bash
COUNT=5
```

```bash
NEXT=$((COUNT + 1))
```

```bash
echo "$NEXT"
```

Output:

```text
6
```

### Syntax

```text
$((EXPRESSION))
```

This is useful for counters and basic integer calculations.

---

# PART XII — STANDARD STREAMS AND REDIRECTION

## 79. STANDARD INPUT, OUTPUT, AND ERROR

Linux processes commonly use three standard streams.

| Stream          | File descriptor | Purpose                     |
| --------------- | --------------: | --------------------------- |
| Standard input  |               0 | Input                       |
| Standard output |               1 | Normal output               |
| Standard error  |               2 | Error and diagnostic output |

These streams allow programs to interact with terminals, files, and other programs.

---

# 80. OUTPUT REDIRECTION

The `>` operator redirects standard output.

Example:

```bash
echo "Hello Linux" > message.txt
```

This writes output into the file.

### Important Warning

The target file may be created or truncated.

If the file already contains important data, `>` can overwrite that content.

---

# 81. APPENDING OUTPUT

The `>>` operator appends standard output.

Example:

```bash
echo "Second line" >> message.txt
```

This adds content to the end of the file.

### Difference

```text
>    create or overwrite output
>>   append output
```

---

# 82. INPUT REDIRECTION

The `<` operator redirects standard input.

Example:

```bash
wc -l < message.txt
```

This lets `wc` read from the file through standard input.

A useful distinction is that the output does not need to include the input filename.

---

# 83. REDIRECTING ERRORS

Use:

```bash
ls does-not-exist 2> errors.txt
```

The error output is written to `errors.txt`.

This demonstrates file descriptor 2.

### Redirect Both Streams

In Bash:

```bash
command > combined.log 2>&1
```

This redirects standard output to the file and then makes standard error use the same destination.

### Important Detail

The order of redirection operators matters.

---

# 84. PIPES

The pipe operator is:

```text
|
```

It connects the standard output of one command to the standard input of another.

Example:

```bash
cat notes.txt | grep "Linux"
```

A shorter form is often:

```bash
grep "Linux" notes.txt
```

Pipes are especially powerful when multiple transformations are required.

Example:

```bash
sort names.txt | uniq -c | sort -nr
```

This sorts data, counts adjacent repeated values, and sorts the resulting counts numerically in descending order.

---

# 85. COMMAND EXIT STATUS

Programs report execution results using exit statuses.

Conventionally:

```text
0       success
nonzero other result or failure condition
```

Check the previous command's exit status:

```bash
echo "$?"
```

### Important Qualification

The interpretation of nonzero codes is command-specific.

For example, `grep` returns 1 when no match is found.

That can be an expected result.

---

# 86. CONDITIONAL COMMAND OPERATORS

Bash supports:

```text
&&
```

Run the next command only if the previous command succeeds.

Example:

```bash
mkdir -p reports && echo "Directory ready"
```

And:

```text
||
```

Run the next command if the previous command fails.

Example:

```bash
grep "ERROR" application.log || echo "No matching lines or another grep failure"
```

The message must not assume all failures mean no matches, because errors such as unreadable files can also cause failure.

---

# PART XIII — INTRODUCTION TO BASH SCRIPTS

## 87. WHAT IS A BASH SCRIPT?

A Bash script is a text file containing commands intended to be interpreted by Bash.

Example:

```bash
#!/usr/bin/env bash

echo "Starting application"

date

echo "Finished"
```

Save as:

```text
hello.sh
```

Run:

```bash
bash hello.sh
```

The `.sh` extension is conventional, not mandatory.

---

# 88. THE SHEBANG

The first line:

```bash
#!/usr/bin/env bash
```

is called a shebang.

When the file is executed directly on a compatible system, it helps identify which interpreter should execute the script.

Running:

```bash
bash script.sh
```

explicitly selects Bash and does not require the file to be executable.

Direct execution normally requires suitable execute permission.

Detailed permissions will be covered in Major Lecture 02.

---

# 89. SCRIPT VARIABLES

Example:

```bash
#!/usr/bin/env bash

PROJECT="Linux Course"

printf 'Welcome to %s\n' "$PROJECT"
```

Variables make scripts easier to configure and reuse.

---

# 90. BASIC SCRIPT SAFETY

A common Bash script setting is:

```bash
set -euo pipefail
```

### `-e`

Requests that Bash exit under selected command-failure conditions.

It is not a universal exception mechanism, and some contexts are exempt.

### `-u`

Treats many uses of unset variables as errors.

### `pipefail`

Causes a pipeline's status to reflect a failed command in the pipeline rather than simply the final command, according to Bash's pipeline rules.

### Important Principle

These options help detect problems, but scripts still require deliberate error handling and testing.

---

# PART XIV — PACKAGE MANAGEMENT

## 91. WHAT IS A SOFTWARE PACKAGE?

A software package contains files and metadata used to install and manage software.

Packages may contain:

- Executable programs.
- Libraries.
- Configuration files.
- Documentation.
- Metadata.
- Dependency declarations.

Package management systems help install, update, and remove software consistently.

---

# 92. WHAT IS A PACKAGE REPOSITORY?

A package repository is a source of software packages and associated metadata.

A distribution's package manager can retrieve information from configured repositories.

The package manager then determines which package files and dependencies are needed.

### Architecture

```text
              USER COMMAND
                   |
                   v
              PACKAGE MANAGER
                   |
                   v
           CONFIGURED REPOSITORIES
                   |
                   v
              PACKAGE DOWNLOAD
                   |
                   v
             DEPENDENCY HANDLING
                   |
                   v
                INSTALLATION
```

---

# 93. WHAT IS A DEPENDENCY?

A dependency is another software component required by a package.

For example, an application may require a shared library.

The package manager uses package metadata to identify the necessary components.

### Important Distinction

System package dependencies are different from Python virtual environment dependencies, although they can interact.

A Python package installed through `pip` does not automatically become a distribution-managed package.

---

# 94. APT ON UBUNTU AND DEBIAN

APT is a package-management system used by Debian-based Linux distributions.

Common commands include:

```bash
sudo apt update
```

```bash
sudo apt install PACKAGE
```

```bash
apt search PACKAGE
```

```bash
apt show PACKAGE
```

```bash
sudo apt remove PACKAGE
```

The commands require an appropriately configured APT environment.

---

# 95. APT UPDATE VERSUS UPGRADE

This is a particularly important distinction.

### Update

```bash
sudo apt update
```

Refreshes the local index of available packages from configured repositories.

It does not itself install all available package upgrades.

### Upgrade

```bash
sudo apt upgrade
```

Requests upgrades of installed packages according to APT's policies and dependency rules.

### Memory Principle

**Update = refresh package information.**

**Upgrade = install suitable newer package versions.**

---

# 96. INSTALLING SOFTWARE WITH APT

Example:

```bash
sudo apt install tree
```

This installs `tree` and necessary dependencies when available.

Search first:

```bash
apt search tree
```

Inspect package information:

```bash
apt show tree
```

### Important Warning

Use `sudo` only when an operation requires elevated permissions.

Do not run package installation or removal commands without understanding the requested changes.

---

# 97. APT-GET AND DPKG

APT has related tools.

### apt-get

Often preferred for scripting and automated operations where a more stable command-line interface is desirable.

Example:

```bash
sudo apt-get update
```

### dpkg

A lower-level Debian package-management tool.

Example:

```bash
dpkg -l
```

APT handles repository access and dependency resolution on top of the Debian package-management ecosystem.

---

# 98. DNF ON FEDORA

Fedora commonly uses DNF.

Examples:

```bash
sudo dnf install tree
```

```bash
dnf search tree
```

```bash
dnf info tree
```

```bash
sudo dnf upgrade
```

### Important Principle

The package manager must match the Linux distribution.

Do not assume APT is available on Fedora or DNF on Ubuntu.

---

# 99. SOFTWARE UPDATE SAFETY

On a dedicated practice Linux machine, package installation and updates can be useful exercises.

On a production server, updates may affect:

- Libraries.
- Kernel packages.
- Applications.
- Services.
- Runtime dependencies.

Some updates may require service restarts or system reboot.

Production updates should therefore follow the organization's maintenance and verification process.

This lecture focuses on understanding the package-management commands rather than performing uncontrolled system-wide upgrades.

---

# PART XV — BUILT-IN DOCUMENTATION

## 100. THE man COMMAND

`man` displays manual pages.

Example:

```bash
man ls
```

Other examples:

```bash
man cp
```

```bash
man find
```

```bash
man bash
```

Manual pages provide details about:

- Command usage.
- Options.
- Arguments.
- Behavior.
- Relevant files.
- Exit statuses.

The manual-page software and pages may not be installed on minimal systems.

---

# 101. THE --help OPTION

Many commands provide help text.

Example:

```bash
ls --help
```

```bash
grep --help
```

```bash
find --help
```

The output commonly lists supported options.

Not all commands implement the same help conventions.

---

# 102. THE help BUILTIN

Bash provides help for its built-in commands.

Example:

```bash
help cd
```

```bash
help export
```

```bash
help printf
```

### Important Distinction

`help` provides information about Bash builtins.

`man` can provide broader manual documentation.

---

# 103. THE type COMMAND

Use:

```bash
type cd
```

```bash
type printf
```

```bash
type grep
```

This identifies how Bash resolves a command name.

It can reveal:

- Shell builtins.
- Executable programs.
- Aliases.
- Functions.

This is useful when a command behaves differently from expectations.

---

# PART XVI — COMPLETE PRACTICAL LABORATORY

## 104. LABORATORY TITLE

**Linux Command-Line Engineering: Building, Searching, Processing, and Reporting on a Safe Local Project Workspace**

This laboratory is designed to integrate the theoretical concepts from the lecture.

All file-creation exercises use a dedicated directory under the current user's home directory.

**Practice directory:**

```text
~/linux-major-lesson1
```

### Safety Rules

1. Execute the exercises as an ordinary user.
2. Use Bash for the shell examples.
3. Do not use `sudo` for routine file operations.
4. Do not change real system configuration.
5. Do not run recursive deletion commands on unknown locations.
6. Review destination paths before moving or overwriting files.
7. Package installation is optional and should be performed only on an authorized practice system.

---

# 105. EXPERIMENT 1 — IDENTIFY THE OPERATING SYSTEM

Execute:

```bash
uname -s
```

Then:

```bash
uname -r
```

Inspect the distribution information:

```bash
cat /etc/os-release
```

### Objective

Distinguish the kernel identity from the Linux distribution information.

### Expected Understanding

`uname` reports kernel-related information.

`/etc/os-release` contains operating-system identification information.

---

# 106. EXPERIMENT 2 — IDENTIFY YOUR ENVIRONMENT

Execute:

```bash
whoami
```

```bash
echo "$HOME"
```

```bash
echo "$SHELL"
```

```bash
pwd
```

### Objective

Identify the current user, home directory, configured shell, and current working directory.

---

# 107. EXPERIMENT 3 — INSPECT THE FILESYSTEM ROOT

Execute:

```bash
ls /
```

Then:

```bash
ls -ld /etc /home /usr /var /tmp
```

### Objective

Identify major Linux filesystem directories.

### Expected Understanding

The root directory contains the beginning of the filesystem hierarchy.

---

# 108. EXPERIMENT 4 — CREATE A PRACTICE WORKSPACE

Execute:

```bash
mkdir -p "$HOME/linux-major-lesson1"
```

Navigate:

```bash
cd "$HOME/linux-major-lesson1"
```

Verify:

```bash
pwd
```

### Objective

Create a safe directory for the laboratory.

---

# 109. EXPERIMENT 5 — CREATE THE PROJECT STRUCTURE

Execute:

```bash
mkdir -p documents
mkdir -p logs
mkdir -p archive
mkdir -p scripts
mkdir -p output
```

Inspect:

```bash
ls -la
```

### Expected Structure

```text
linux-major-lesson1/
├── archive/
├── documents/
├── logs/
├── output/
└── scripts/
```

---

# 110. EXPERIMENT 6 — CREATE FILES

Execute:

```bash
touch documents/notes.txt
```

```bash
touch documents/tasks.txt
```

Inspect:

```bash
ls -l documents
```

### Objective

Understand basic file creation and listing.

---

# 111. EXPERIMENT 7 — WRITE TEXT INTO A FILE

Execute:

```bash
printf 'Linux fundamentals\n' > documents/notes.txt
```

Append:

```bash
printf 'Terminal navigation\n' >> documents/notes.txt
```

Append again:

```bash
printf 'Bash scripting\n' >> documents/notes.txt
```

Read:

```bash
cat documents/notes.txt
```

### Expected Output

```text
Linux fundamentals
Terminal navigation
Bash scripting
```

### Objective

Practice standard-output redirection.

---

# 112. EXPERIMENT 8 — CREATE A TASK LIST

Execute:

```bash
cat > documents/tasks.txt <<'EOF'
Learn Linux
Practice Bash
Learn Git
Practice Docker
Learn Linux
Practice Bash
EOF
```

Inspect:

```bash
cat documents/tasks.txt
```

### Objective

Use a here-document to create a multi-line text file.

The `<<'EOF'` form prevents shell expansion inside this particular here-document.

---

# 113. EXPERIMENT 9 — COPY A FILE

Execute:

```bash
cp documents/notes.txt archive/notes-copy.txt
```

Inspect:

```bash
cat archive/notes-copy.txt
```

### Objective

Create a separate copy of a regular file.

---

# 114. EXPERIMENT 10 — RENAME A FILE

Execute:

```bash
mv archive/notes-copy.txt archive/notes-backup.txt
```

Inspect:

```bash
ls -l archive
```

### Objective

Rename an existing file.

---

# 115. EXPERIMENT 11 — CREATE A SYMBOLIC LINK

Execute:

```bash
ln -s ../documents/notes.txt archive/notes-link.txt
```

Inspect:

```bash
ls -l archive
```

Read the link target through the link:

```bash
cat archive/notes-link.txt
```

### Objective

Understand the relationship between a symbolic link and its target.

### Important Detail

The link target is interpreted relative to the symbolic link's location when the stored target path is relative.

---

# 116. EXPERIMENT 12 — CREATE A HARD LINK

Execute:

```bash
ln documents/notes.txt documents/notes-hardlink.txt
```

Inspect:

```bash
ls -li documents/notes.txt documents/notes-hardlink.txt
```

### Objective

Observe that two hard-linked names refer to the same underlying filesystem object.

The inode number is commonly the same on filesystems exposing traditional inode information.

---

# 117. EXPERIMENT 13 — EXPLORE HIDDEN FILES

Create:

```bash
touch .training-config
```

Execute:

```bash
ls
```

Then:

```bash
ls -a
```

### Objective

Understand how dot-prefixed filenames behave in ordinary directory listings.

---

# 118. EXPERIMENT 14 — READ FILES WITH HEAD AND TAIL

Execute:

```bash
head -n 2 documents/tasks.txt
```

Then:

```bash
tail -n 2 documents/tasks.txt
```

### Objective

Retrieve selected portions of a text file.

---

# 119. EXPERIMENT 15 — USE A TERMINAL EDITOR

Open:

```bash
nano documents/notes.txt
```

Add a line describing what you have learned.

Save and exit.

If Nano is unavailable, use Vim or another authorized text editor.

Verify:

```bash
cat documents/notes.txt
```

### Objective

Edit a text file interactively.

---

# 120. EXPERIMENT 16 — CREATE A LOG FILE

Execute:

```bash
cat > logs/application.log <<'EOF'
2026-10-21 INFO Application started
2026-10-21 INFO Configuration loaded
2026-10-21 ERROR Database connection failed
2026-10-21 WARNING Retrying database connection
2026-10-21 INFO Database connected
2026-10-21 ERROR Invalid task request
2026-10-21 INFO Application ready
EOF
```

### Objective

Create realistic structured text for search and processing.

The dates are fixed example data for the exercise.

---

# 121. EXPERIMENT 17 — SEARCH LOGS WITH GREP

Execute:

```bash
grep "ERROR" logs/application.log
```

Display line numbers:

```bash
grep -n "ERROR" logs/application.log
```

Case-insensitive search:

```bash
grep -i "warning" logs/application.log
```

### Objective

Identify relevant application events.

---

# 122. EXPERIMENT 18 — COUNT ERRORS

Execute:

```bash
grep -c "ERROR" logs/application.log
```

### Expected Result

```text
2
```

Compare with:

```bash
grep "ERROR" logs/application.log | wc -l
```

### Objective

Understand two methods of counting matching lines.

---

# 123. EXPERIMENT 19 — COUNT TASKS

Execute:

```bash
wc -l documents/tasks.txt
```

Then:

```bash
wc -w documents/tasks.txt
```

### Objective

Count lines and words.

The line count is expected to be six.

---

# 124. EXPERIMENT 20 — SORT AND COUNT REPEATED TASKS

Execute:

```bash
sort documents/tasks.txt
```

Then:

```bash
sort documents/tasks.txt | uniq -c
```

### Objective

Group equal lines and count repetitions.

### Expected Understanding

`sort` brings equal lines together.

`uniq -c` counts adjacent repetitions.

---

# 125. EXPERIMENT 21 — SEARCH FILENAMES

Execute:

```bash
find . -type f -name "*.txt"
```

Then:

```bash
find . -maxdepth 2 -type f
```

### Objective

Search by filename, type, and location.

---

# 126. EXPERIMENT 22 — PRACTICE SPACES AND QUOTING

Create a filename containing a space:

```bash
touch "documents/my report.txt"
```

Inspect:

```bash
ls -l documents
```

Read its content safely:

```bash
printf 'Linux report\n' > "documents/my report.txt"
```

```bash
cat "documents/my report.txt"
```

### Objective

Understand why shell quoting is essential when filenames contain spaces.

---

# 127. EXPERIMENT 23 — PRACTICE VARIABLES

Execute:

```bash
PROJECT="linux-major-lesson1"
```

Then:

```bash
printf 'Current project: %s\n' "$PROJECT"
```

Create a filename variable:

```bash
REPORT_FILE="output/variable-report.txt"
```

Write:

```bash
printf 'Project=%s\n' "$PROJECT" > "$REPORT_FILE"
```

Inspect:

```bash
cat "$REPORT_FILE"
```

### Objective

Store and safely expand shell variables.

---

# 128. EXPERIMENT 24 — INSPECT PATH AND COMMAND LOCATION

Execute:

```bash
printf '%s\n' "$PATH"
```

Then:

```bash
command -v bash
```

```bash
type cd
```

```bash
type ls
```

### Objective

Distinguish built-in commands from executable programs and inspect command lookup.

---

# 129. EXPERIMENT 25 — USE PIPES

Execute:

```bash
cat logs/application.log | grep "INFO"
```

Then:

```bash
grep "INFO" logs/application.log | wc -l
```

### Expected Result

```text
4
```

### Objective

Connect commands using standard streams.

---

# 130. EXPERIMENT 26 — REDIRECT ERROR OUTPUT

Execute:

```bash
ls file-that-does-not-exist 2> output/errors.txt
```

The command is expected to report a missing file through the redirected error stream and return a nonzero status.

Inspect:

```bash
cat output/errors.txt
```

### Objective

Understand standard error redirection.

---

# 131. EXPERIMENT 27 — PRACTICE CUT

Create:

```bash
cat > documents/team.txt <<'EOF'
alice:developer
bob:designer
carol:administrator
EOF
```

Extract names:

```bash
cut -d ':' -f 1 documents/team.txt
```

Extract roles:

```bash
cut -d ':' -f 2 documents/team.txt
```

### Objective

Process simple delimited text.

---

# 132. EXPERIMENT 28 — PRACTICE SED

Execute:

```bash
sed 's/Linux/LINUX/g' documents/tasks.txt
```

Then:

```bash
sed -n '1,3p' documents/tasks.txt
```

### Objective

Perform text substitution and selected-line printing.

### Important Detail

These commands display results without changing the original file.

---

# 133. EXPERIMENT 29 — PRACTICE AWK

Use the log file.

Execute:

```bash
awk '{print $2}' logs/application.log
```

This prints the log level field.

Count by level:

```bash
awk '{count[$2]++} END {for (level in count) print level, count[level]}' logs/application.log
```

### Objective

Analyze structured lines using fields and counters.

The order of the final output may vary.

---

# 134. EXPERIMENT 30 — CREATE A BASH REPORT SCRIPT

Create:

```text
scripts/daily-report.sh
```

Insert the following complete script:

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

LOG_FILE="$PROJECT_DIR/logs/application.log"

TASK_FILE="$PROJECT_DIR/documents/tasks.txt"

OUTPUT_DIR="$PROJECT_DIR/output"

REPORT_FILE="$OUTPUT_DIR/daily-report.txt"

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$LOG_FILE" ]]; then
    printf 'Missing log file: %s\n' "$LOG_FILE" >&2
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    printf 'Missing task file: %s\n' "$TASK_FILE" >&2
    exit 1
fi

ERROR_COUNT="$(
    grep -c ' ERROR ' "$LOG_FILE" || true
)"

TASK_COUNT="$(
    wc -l < "$TASK_FILE"
)"

{
    printf 'LINUX DAILY REPORT\n'
    printf '==================\n'
    printf 'Generated: %s\n' "$(date)"
    printf 'Hostname: %s\n' "$(hostname)"
    printf 'Project: %s\n' "$PROJECT_DIR"
    printf 'Task lines: %s\n' "$TASK_COUNT"
    printf 'Error lines: %s\n' "$ERROR_COUNT"
    printf '\nTask list:\n'
    cat "$TASK_FILE"
} > "$REPORT_FILE"

printf 'Report generated: %s\n' "$REPORT_FILE"
```

### Objective

Combine:

- Shebang.
- Variables.
- Quoting.
- Directory navigation.
- Command substitution.
- Conditionals.
- Exit statuses.
- Redirection.
- Text processing.
- File creation.

### Important Qualification

The `grep ... || true` expression treats all `grep` failures as nonfatal.

This is acceptable for demonstrating a short local report, but a robust production script should distinguish "no matches" from genuine read errors.

Advanced Bash error handling will be covered in Major Lecture 03.

---

# 135. EXPERIMENT 31 — EXECUTE THE REPORT SCRIPT

Execute:

```bash
bash scripts/daily-report.sh
```

Inspect:

```bash
cat output/daily-report.txt
```

### Expected Result

The report displays:

- Generation date.
- Hostname.
- Project directory.
- Task line count.
- Error line count.
- Task list.

### Objective

Verify that Bash can automate multiple Linux commands.

---

# 136. EXPERIMENT 32 — INSPECT AVAILABLE SOFTWARE

On Ubuntu or Debian:

```bash
apt search tree
```

```bash
apt show tree
```

On Fedora:

```bash
dnf search tree
```

```bash
dnf info tree
```

### Objective

Understand software discovery without making unnecessary system changes.

---

# 137. EXPERIMENT 33 — READ COMMAND DOCUMENTATION

Execute:

```bash
ls --help
```

```bash
help cd
```

```bash
type grep
```

If manual pages are installed:

```bash
man find
```

### Objective

Develop the habit of consulting documentation rather than guessing command options.

---

# 138. EXPERIMENT 34 — FINAL WORKSPACE INSPECTION

From the project directory:

```bash
pwd
```

```bash
find . -maxdepth 3 -print
```

```bash
ls -la
```

```bash
cat output/daily-report.txt
```

### Objective

Verify that the workspace and report were created correctly.

---

# 139. EXPECTED FINAL PROJECT STRUCTURE

The workspace should resemble:

```text
linux-major-lesson1/
├── .training-config
├── archive/
│   ├── notes-backup.txt
│   └── notes-link.txt
├── documents/
│   ├── my report.txt
│   ├── notes.txt
│   ├── notes-hardlink.txt
│   ├── tasks.txt
│   └── team.txt
├── logs/
│   └── application.log
├── output/
│   ├── daily-report.txt
│   ├── errors.txt
│   └── variable-report.txt
└── scripts/
    └── daily-report.sh
```

### Final Result

The student has constructed a small file-processing environment using Linux terminal commands.

The final Bash script processes project information and generates a report.

The project demonstrates how individual Linux commands can be combined into a simple automation workflow.

---

# PART XVII — COMMON LINUX MISTAKES

## 140. CONFUSING THE TERMINAL AND THE SHELL

Incorrect:

"The terminal and Bash are exactly the same program."

Correct:

The terminal provides the interaction interface.

Bash interprets and executes shell commands.

---

# 141. CONFUSING / AND /ROOT

Incorrect:

"`/root` is the top of the Linux filesystem."

Correct:

`/` is the filesystem root.

`/root` is conventionally the root user's home directory.

---

# 142. RUNNING COMMANDS FROM THE WRONG DIRECTORY

Incorrect:

Assuming relative paths work regardless of the current location.

Correct:

Use:

```bash
pwd
```

before file operations.

Use absolute paths when the current directory should not matter.

---

# 143. FORGETTING QUOTES

Incorrect:

```bash
cat $FILE
```

when the variable contains a path with spaces.

Better:

```bash
cat "$FILE"
```

Quoted expansions help preserve argument boundaries.

---

# 144. CONFUSING > AND >>

Incorrect:

Using `>` when the intention is to preserve existing content.

Correct:

`>` normally creates or truncates the output file.

`>>` appends.

---

# 145. CONFUSING FIND AND GREP

Incorrect:

Assuming both commands serve exactly the same purpose.

Correct:

`find` searches directory entries according to conditions.

`grep` searches text content according to patterns.

They can be combined when appropriate.

---

# 146. USING RM WITHOUT INSPECTING PATHS

Incorrect:

Deleting unknown directories recursively.

Correct:

Inspect:

```bash
pwd
```

```bash
ls -la TARGET
```

Confirm that the selected files are disposable before removal.

---

# 147. CONFUSING APT UPDATE AND UPGRADE

Incorrect:

"`apt update` installs all updated software."

Correct:

`apt update` refreshes available package information.

`apt upgrade` requests suitable upgrades to installed software.

---

# 148. THINKING EVERY LINUX DISTRIBUTION IS IDENTICAL

Incorrect:

Assuming every distribution uses APT.

Correct:

Package managers and default configurations can differ.

Learn the operating-system concepts and adapt commands to the distribution.

---

# PART XVIII — MASTER COMMAND REFERENCE

## 149. SYSTEM IDENTIFICATION

| Command               | Purpose                     |
| --------------------- | --------------------------- |
| `uname -s`            | Kernel name                 |
| `uname -r`            | Kernel release              |
| `cat /etc/os-release` | Distribution identification |
| `whoami`              | Current username            |
| `pwd`                 | Current directory           |
| `echo "$HOME"`        | Home directory              |
| `echo "$SHELL"`       | Configured login shell      |

---

# 150. DIRECTORY NAVIGATION

| Command          | Purpose                                    |
| ---------------- | ------------------------------------------ |
| `ls`             | List directory entries                     |
| `ls -la`         | Detailed listing including hidden entries  |
| `cd DIRECTORY`   | Change directory                           |
| `cd ..`          | Parent directory                           |
| `cd ~`           | Home directory                             |
| `cd -`           | Previous directory                         |
| `pwd`            | Display current path                       |
| `find . -type f` | Find regular files under current directory |

---

# 151. FILE MANAGEMENT

| Command             | Purpose                                |
| ------------------- | -------------------------------------- |
| `mkdir DIR`         | Create directory                       |
| `mkdir -p PATH`     | Create parent directories as necessary |
| `touch FILE`        | Create/update file timestamp           |
| `cp SOURCE DEST`    | Copy                                   |
| `mv SOURCE DEST`    | Move or rename                         |
| `rm FILE`           | Remove file                            |
| `rmdir DIR`         | Remove empty directory                 |
| `ln SOURCE LINK`    | Create hard link                       |
| `ln -s TARGET LINK` | Create symbolic link                   |
| `file FILE`         | Identify file type                     |

---

# 152. TEXT INSPECTION

| Command        | Purpose                  |
| -------------- | ------------------------ |
| `cat FILE`     | Display/concatenate text |
| `less FILE`    | Read interactively       |
| `head FILE`    | First lines              |
| `tail FILE`    | Last lines               |
| `tail -f FILE` | Follow appended output   |
| `nano FILE`    | Edit text                |
| `vim FILE`     | Modal text editor        |

---

# 153. SEARCH AND PROCESSING

| Command   | Purpose                      |
| --------- | ---------------------------- |
| `find`    | Search filesystem hierarchy  |
| `grep`    | Search text patterns         |
| `grep -F` | Fixed-string search          |
| `grep -n` | Show line numbers            |
| `grep -i` | Ignore case                  |
| `wc -l`   | Count lines                  |
| `sort`    | Sort lines                   |
| `uniq -c` | Count adjacent repetitions   |
| `cut`     | Extract fields or characters |
| `sed`     | Stream transformations       |
| `awk`     | Field-oriented processing    |

---

# 154. BASH AND STREAMS

| Syntax            | Meaning                          |
| ----------------- | -------------------------------- | -------- | ------------------------------ |
| `VAR=value`       | Shell variable assignment        |
| `export VAR`      | Export variable to environment   |
| `"$VAR"`          | Quoted expansion                 |
| `'literal'`       | Literal single-quoted string     |
| `$(command)`      | Command substitution             |
| `$((expression))` | Arithmetic expansion             |
| `*`               | Shell filename wildcard          |
| `>`               | Redirect stdout, truncate/create |
| `>>`              | Append stdout                    |
| `<`               | Redirect stdin                   |
| `2>`              | Redirect stderr                  |
| `                 | `                                | Pipeline |
| `&&`              | Run next command after success   |
| `                 |                                  | `        | Run next command after failure |
| `$?`              | Previous command exit status     |

---

# 155. PACKAGE MANAGEMENT AND HELP

| Command                    | Purpose                                  |
| -------------------------- | ---------------------------------------- |
| `apt search PACKAGE`       | Search available packages on APT systems |
| `apt show PACKAGE`         | Display package information              |
| `sudo apt update`          | Refresh APT package index                |
| `sudo apt install PACKAGE` | Install package                          |
| `sudo apt upgrade`         | Request package upgrades                 |
| `dnf search PACKAGE`       | Search packages on DNF systems           |
| `sudo dnf install PACKAGE` | Install package                          |
| `man COMMAND`              | Read manual page                         |
| `COMMAND --help`           | Display supported help text              |
| `help cd`                  | Bash builtin help                        |
| `type COMMAND`             | Explain command resolution               |
| `command -v NAME`          | Locate command through shell lookup      |

---

# PART XIX — FORMAL ACADEMIC EXAMINATION

## 156. PART A — DEFINITIONS

Define the following terms:

1. Linux.
2. Operating system.
3. Kernel.
4. User space.
5. Kernel space.
6. System call.
7. Linux distribution.
8. Terminal.
9. Shell.
10. Bash.
11. Root directory.
12. Absolute path.
13. Relative path.
14. Home directory.
15. Hidden file.
16. Symbolic link.
17. Hard link.
18. Standard input.
19. Standard output.
20. Standard error.
21. Environment variable.
22. PATH.
23. Shell expansion.
24. Pipe.
25. Redirection.
26. Software package.
27. Package repository.
28. Dependency.
29. APT.
30. DNF.

---

# 157. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain the difference between the Linux kernel and a Linux distribution.

**Question 2.**

Describe the relationship between applications and the Linux kernel.

**Question 3.**

Explain the difference between user space and kernel space.

**Question 4.**

Distinguish a terminal from a shell.

**Question 5.**

Explain the purpose of Bash.

**Question 6.**

Describe the Linux filesystem hierarchy.

**Question 7.**

Explain the difference between `/` and `/root`.

**Question 8.**

Distinguish absolute and relative paths.

**Question 9.**

Explain the differences between `cp`, `mv`, and `rm`.

**Question 10.**

Distinguish hard links and symbolic links.

**Question 11.**

Explain why shell quoting is important.

**Question 12.**

Distinguish standard output from standard error.

**Question 13.**

Explain the difference between `>` and `>>`.

**Question 14.**

Explain how a Bash pipeline works.

**Question 15.**

Describe the difference between `find` and `grep`.

**Question 16.**

Explain the role of `sort` before `uniq -c`.

**Question 17.**

Explain what `PATH` does.

**Question 18.**

Describe the relationship between APT and software repositories.

**Question 19.**

Explain the difference between `apt update` and `apt upgrade`.

**Question 20.**

Explain why commands should be tested in a dedicated practice workspace.

---

# 158. PART C — COMMAND INTERPRETATION

Explain what the following command does:

```bash
ls -la /home
```

Explain:

```bash
find . -name "*.py"
```

Explain:

```bash
grep -n "ERROR" application.log
```

Explain:

```bash
sort names.txt | uniq -c
```

Explain:

```bash
echo "Hello" > output.txt
```

Explain:

```bash
echo "World" >> output.txt
```

Explain:

```bash
wc -l < tasks.txt
```

Explain:

```bash
command -v python3
```

Explain:

```bash
sudo apt update
```

Explain:

```bash
bash scripts/daily-report.sh
```

---

# 159. PART D — PRACTICAL SCENARIOS

## Scenario 1 — Wrong Directory

A student cannot find a file using a relative path.

Explain how to investigate the current working directory and identify the correct file location.

## Scenario 2 — Accidental Overwrite

A student uses `>` instead of `>>`.

Explain why the original content was replaced and how the risk can be reduced.

## Scenario 3 — Filename With Spaces

A script cannot read a file named:

```text
monthly report.txt
```

Explain the quoting problem and provide a correct command.

## Scenario 4 — Searching Logs

An application log contains thousands of lines.

Explain how to display only lines containing `ERROR`, count them, and inspect their line numbers.

## Scenario 5 — Repeated Data

A file contains repeated names in arbitrary order.

Explain how to count duplicate names.

## Scenario 6 — Missing Command

A Linux system reports:

```text
command not found
```

Explain how to determine whether the command is installed and whether its executable location is available through `PATH`.

## Scenario 7 — Package Confusion

A student runs `apt update` but the application version remains unchanged.

Explain the difference between updating the package index and installing package upgrades.

---

# 160. PRACTICAL EXAMINATION — 100 MARKS

| Assessment category                  |   Marks |
| ------------------------------------ | ------: |
| Linux architecture and distributions |      10 |
| Filesystem hierarchy and paths       |      15 |
| Terminal navigation                  |      10 |
| File and directory operations        |      15 |
| Text inspection and editing          |      10 |
| Searching and text processing        |      15 |
| Bash variables, quoting, and streams |      15 |
| Package management and documentation |       5 |
| Final report automation project      |       5 |
| **Total**                            | **100** |

**Suggested passing standard:** 80/100.

The student should demonstrate both conceptual understanding and successful command execution.

---

# PART XX — INDEPENDENT ACADEMIC ASSIGNMENT

## 161. ASSIGNMENT TITLE

**Understanding Linux Architecture, Filesystem Organization, Command-Line Processing, and Basic Bash Automation**

Prepare a technical report of approximately 1,500–2,200 words.

The report should include:

1. Introduction to Linux.
2. Linux kernel architecture.
3. User space and kernel space.
4. Linux distributions.
5. Terminal and shell architecture.
6. Bash fundamentals.
7. Filesystem Hierarchy Standard.
8. Important Linux directories.
9. Absolute and relative paths.
10. File and directory operations.
11. Symbolic and hard links.
12. Text viewing and editing.
13. File searching.
14. Text-processing utilities.
15. Bash variables.
16. Environment variables.
17. Shell quoting.
18. Wildcard expansion.
19. Redirection.
20. Pipelines.
21. Exit statuses.
22. Package-management architecture.
23. APT and DNF.
24. Final workspace laboratory.
25. Technical conclusion.

Include at least:

- One Linux architecture diagram.
- One filesystem hierarchy diagram.
- One terminal-to-kernel explanation.
- One pipeline diagram.
- The Bash report script.
- Actual command-output evidence.

---

# PART XXI — COMMON TECHNICAL TERMINOLOGY

## 162. GLOSSARY

| Term                 | Meaning                                                            |
| -------------------- | ------------------------------------------------------------------ |
| Linux                | Operating-system kernel                                            |
| Distribution         | Usable operating system built around Linux and supporting software |
| Kernel               | Core resource-management component                                 |
| User space           | Ordinary application execution environment                         |
| Kernel space         | Privileged kernel execution environment                            |
| System call          | Program request for a kernel service                               |
| Terminal             | Interface for command-line interaction                             |
| Shell                | Command interpreter                                                |
| Bash                 | Bourne Again Shell                                                 |
| Command              | Operation requested through the shell                              |
| Option               | Modifies command behavior                                          |
| Argument             | Value supplied to a command                                        |
| Root directory       | Top of filesystem hierarchy                                        |
| Absolute path        | Path beginning at `/`                                              |
| Relative path        | Path interpreted from current directory                            |
| Working directory    | Current directory of a process                                     |
| Home directory       | User's conventional personal directory                             |
| Hidden file          | Filename commonly beginning with `.`                               |
| Hard link            | Additional directory entry for same file object                    |
| Symbolic link        | Path-based reference to another location                           |
| Standard input       | Input stream, descriptor 0                                         |
| Standard output      | Normal output stream, descriptor 1                                 |
| Standard error       | Diagnostic stream, descriptor 2                                    |
| Variable             | Named value in shell state                                         |
| Environment variable | Variable supplied to child process environment                     |
| PATH                 | Executable search-path variable                                    |
| Glob                 | Filename-matching shell pattern                                    |
| Pipe                 | Connection from command output to another command input            |
| Redirection          | Change of standard-stream destination or source                    |
| Exit status          | Command execution result code                                      |
| APT                  | Debian-based package-management tool                               |
| DNF                  | RPM-based package manager used by Fedora                           |
| Dependency           | Software component required by another                             |
| Repository           | Source of software packages and metadata                           |

---

# PART XXII — THE COMPLETE LESSON IN FIVE CORE CONCEPTS

## 163. CORE CONCEPT 1 — LINUX ARCHITECTURE

Linux uses a kernel that manages system resources.

Applications execute in user space and request services through operating-system interfaces.

### Remember

**Application → System Interface → Kernel → Hardware.**

---

# 164. CORE CONCEPT 2 — FILESYSTEM

Linux organizes files using a hierarchical filesystem rooted at `/`.

Different directories have conventional responsibilities.

### Remember

**`/` = root of everything.**

**`/home` = ordinary user files.**

**`/etc` = system configuration.**

**`/usr` = installed software and shared resources.**

**`/var` = variable data.**

**`/tmp` = temporary files.**

---

# 165. CORE CONCEPT 3 — TERMINAL COMMANDS

The shell interprets commands.

Individual utilities perform filesystem and text-processing operations.

### Remember

**pwd = where am I?**

**ls = what is here?**

**cd = move somewhere.**

**cp = copy.**

**mv = move or rename.**

**rm = remove.**

**cat = read text.**

**find = find file paths.**

**grep = search inside text.**

---

# 166. CORE CONCEPT 4 — BASH COMPOSITION

Bash combines commands, variables, and streams.

### Remember

**Variable = store a value.**

**Quotes = preserve intended text boundaries.**

**Pipe = connect commands.**

**`>` = write output.**

**`>>` = append output.**

**Script = repeat an organized sequence of commands.**

---

# 167. CORE CONCEPT 5 — PACKAGE MANAGEMENT

Linux distributions use package-management systems to install and maintain software.

### Remember

**Repository = software source.**

**Package = installable software and metadata.**

**Dependency = software needed by another package.**

**APT = Debian/Ubuntu ecosystem.**

**DNF = Fedora ecosystem.**

---

# PART XXIII — PROFESSIONAL CONNECTIONS

## 168. LINUX AND DOCKER

Docker containers use Linux operating-system features.

Understanding Linux helps explain:

- Process behavior.
- Kernel interfaces.
- File paths.
- Environment variables.
- Shell commands.
- Networking.
- Filesystem mounts.
- System resources.

For example, the Docker command:

```bash
docker exec -it CONTAINER sh
```

starts a shell process inside the container environment when the image provides `sh`.

The shell commands used inside the container are fundamentally related to the Linux commands studied in this lecture.

---

# 169. LINUX AND GIT

Git is frequently used through Linux terminals.

Git operations depend on:

- Files and directories.
- Working directories.
- Shell arguments.
- Environment variables.
- SSH configuration.
- Filesystem permissions.

For example:

```bash
git status
```

operates relative to the current repository context.

Knowing how to use `pwd`, `cd`, and the shell helps avoid operating in the wrong repository.

---

# 170. LINUX AND DEVOPS

Linux is a major foundation of DevOps infrastructure.

Common responsibilities include:

- Running application services.
- Configuring servers.
- Managing processes.
- Securing users and files.
- Troubleshooting networking.
- Monitoring resources.
- Writing deployment scripts.
- Automating backups.

These activities build directly on the filesystem and command-line knowledge covered in this lecture.

---

# PART XXIV — REFERENCES

## Linux Architecture

[1] The Linux Kernel Project. _Linux Kernel Documentation._  
https://docs.kernel.org/

[2] Linux Foundation. _Linux Foundation Training._  
https://training.linuxfoundation.org/

[3] GNU Project. _GNU Operating System._  
https://www.gnu.org/

## Filesystem Hierarchy

[4] Filesystem Hierarchy Standard. _Official Specification._  
https://specifications.freedesktop.org/fhs/latest/

[5] Filesystem Hierarchy Standard. _Root Filesystem Requirements._  
https://specifications.freedesktop.org/fhs/latest/rootRequirements.html

[6] Filesystem Hierarchy Standard. _The /usr Hierarchy._  
https://specifications.freedesktop.org/fhs/latest/usrHierarchy.html

[7] Filesystem Hierarchy Standard. _The /var Hierarchy._  
https://specifications.freedesktop.org/fhs/latest/varHierarchy.html

## Bash and Command-Line Tools

[8] GNU Project. _Bash Reference Manual._  
https://www.gnu.org/software/bash/manual/

[9] GNU Project. _Coreutils Manual._  
https://www.gnu.org/software/coreutils/manual/

[10] GNU Project. _GNU Grep Manual._  
https://www.gnu.org/software/grep/manual/

[11] GNU Project. _GNU Findutils Manual._  
https://www.gnu.org/software/findutils/manual/

[12] GNU Project. _GNU Sed Manual._  
https://www.gnu.org/software/sed/manual/

[13] GNU Project. _GNU Awk Manual._  
https://www.gnu.org/software/gawk/manual/

## Distributions and Package Management

[14] Ubuntu. _Ubuntu Server Documentation._  
https://ubuntu.com/server/docs

[15] Ubuntu. _Install and Manage Packages._  
https://ubuntu.com/server/docs/how-to/software/package-management/

[16] Debian Project. _Debian Documentation._  
https://www.debian.org/doc/

[17] Fedora Project. _Fedora Documentation._  
https://docs.fedoraproject.org/

[18] DNF. _Documentation._  
https://dnf.readthedocs.io/

## Reference Materials

[19] Linux Manual Pages Project.  
https://man7.org/linux/man-pages/

[20] GNU Project. _Bash Manual — Shell Expansions._  
https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html

[21] GNU Project. _Bash Manual — Redirections._  
https://www.gnu.org/software/bash/manual/html_node/Redirections.html

---

# PART XXV — FINAL COURSE PROGRESS

## 171. CURRENT PROGRESS

**Course:** Linux: Foundations to Professional System Administration

**Completed:** Major Lecture 01 of 03.

### Major Lecture 01 — Completed

Linux fundamentals, operating-system architecture, filesystem hierarchy, terminal navigation, file operations, text processing, Bash fundamentals, and package management.

### Major Lecture 02 — Next

Linux system administration, users, groups, file permissions, processes, signals, systemd, networking, SSH, storage, filesystems, scheduling, and backups.

### Major Lecture 03 — Final

Advanced Bash, Linux internals, security, firewall administration, production services, monitoring, troubleshooting, automation, recovery, and final Linux server capstone.

---

# 172. FINAL CONCLUSION

Linux provides an essential foundation for understanding modern software infrastructure.

Its kernel manages the resources required by applications and system services.

Linux distributions combine the kernel with utilities, libraries, package managers, and other software to create complete computing environments.

The terminal provides a text-based interface through which users interact with a shell.

Bash interprets commands, expands variables, controls input and output, and executes scripts.

The Linux filesystem organizes files and directories into a hierarchy rooted at `/`.

Important filesystem locations have conventional responsibilities relating to configuration, applications, user data, logs, and temporary storage.

Basic commands allow developers to navigate directories, inspect files, create project structures, and manage data.

Text-processing tools such as grep, find, sort, uniq, cut, sed, and awk support effective inspection and transformation of information.

Standard streams and redirection make it possible to combine small utilities into powerful command pipelines.

Shell variables and quoting provide the basis for reliable scripting.

Package managers simplify the installation and maintenance of software and its dependencies.

The final practical laboratory demonstrates how these concepts work together in a small reporting system.

A student who understands this lecture should be able to navigate Linux confidently, interpret filesystem paths, inspect application data, search text, combine commands, and construct basic Bash automation.

These skills provide the foundation for Linux administration and professional server engineering.

**END OF MAJOR LECTURE 01**

**Next: Major Lecture 02 — Linux Users, Permissions, Processes, Systemd, Networking, SSH, Storage, Filesystems, Scheduling, and Administration.**
