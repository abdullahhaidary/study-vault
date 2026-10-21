# GIT & GITHUB: FOUNDATIONS AND PROFESSIONAL DEVELOPMENT

## MAJOR LECTURE 01 — COMPLETE GIT FUNDAMENTALS AND LOCAL VERSION CONTROL

**Course:** Git and GitHub: Foundations to Professional Workflows  
**Lecture:** 01 of 03  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, Practical Laboratory, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 6–8 Hours  
**Prerequisites:** Basic command-line familiarity

**Topics Covered:**

1. Git, GitHub, and Version Control
2. Git Installation and Configuration
3. Repositories, Working Directory, Staging Area, and Commits
4. File Tracking, Differences, and History Inspection
5. Branches, HEAD, and Branch Navigation
6. Merging, Fast-Forward Merges, and Conflict Resolution
7. Undoing Mistakes, Resetting, Reverting, and Recovering Work

---

# PART I — INTRODUCTION TO VERSION CONTROL

## 1. PURPOSE OF THE LECTURE

Software development involves constant change.

A programmer writes code, discovers problems, fixes bugs, implements features, and improves existing functionality.

During development, it is essential to maintain a reliable record of these changes.

Without version control, developers often create multiple copies of a project:

```text
my-project/
my-project-new/
my-project-final/
my-project-final-2/
my-project-final-really-final/
```

This approach creates several difficulties.

It becomes difficult to identify which version is correct, determine what changed, recover deleted work, or combine changes from different developers.

Git solves these problems through a distributed version control system.

It records project history, supports isolated development branches, and provides tools for inspecting, combining, and recovering changes.

This lecture establishes the conceptual and practical foundations required to use Git correctly.

Unlike the next major lecture, which focuses on remote repositories and GitHub collaboration, this lecture primarily examines Git operations performed on a local computer.

By the end, the student will construct a Git repository, record changes, create and merge branches, resolve conflicts, and recover from selected mistakes.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Define version control.
2. Explain the purpose of Git.
3. Distinguish Git from GitHub.
4. Define a repository.
5. Explain distributed version control.
6. Distinguish local and remote repositories.
7. Install and verify Git.
8. Configure an author name and email.
9. Explain Git configuration scopes.
10. Create a repository using `git init`.
11. Copy a repository using `git clone`.
12. Explain the `.git` directory.
13. Distinguish tracked and untracked files.
14. Explain the working directory.
15. Explain the staging area.
16. Define a commit.
17. Describe the Git file lifecycle.
18. Stage files using `git add`.
19. Create commits using `git commit`.
20. Write meaningful commit messages.
21. Configure `.gitignore`.
22. Inspect repository status.
23. Compare file changes.
24. Inspect staged changes.
25. Examine commit history.
26. Inspect specific commits.
27. Identify changes using `git blame`.
28. Define branches.
29. Explain HEAD.
30. Create and switch branches.
31. Explain fast-forward merging.
32. Explain three-way merging.
33. Merge independent development branches.
34. Identify merge conflicts.
35. Resolve merge conflicts manually.
36. Abort an incomplete merge.
37. Restore modified files.
38. Unstage staged changes.
39. Explain `git reset`.
40. Distinguish soft, mixed, and hard resets.
41. Explain `git revert`.
42. Amend a local commit.
43. Recover historical references using `git reflog`.
44. Recognize detached HEAD.
45. Complete a practical local Git development workflow.

---

# PART II — WHAT IS VERSION CONTROL?

## 3. DEFINITION OF VERSION CONTROL

Version control is a system for recording and managing changes to files over time.

In software engineering, version control primarily manages source code and project-related files.

A version control system allows developers to:

- Preserve earlier project states.
- Compare different versions.
- Identify when changes occurred.
- Determine who recorded changes.
- Recover previously committed content.
- Develop features independently.
- Combine contributions from multiple developers.

Consider a Python application.

### Version 1

```python
print("Hello")
```

### Version 2

```python
print("Hello, Docker")
```

### Version 3

```python
name = input("Enter your name: ")
print(f"Hello, {name}")
```

Without version control, a developer may overwrite earlier versions.

With Git, the developer can record all three versions as commits.

Git makes it possible to examine how the application evolved.

---

# 4. WHY VERSION CONTROL MATTERS

Version control addresses several important software engineering requirements.

## 4.1 Historical Traceability

Developers can identify changes made over time.

## 4.2 Error Recovery

Earlier committed versions can be inspected or restored.

## 4.3 Parallel Development

Different features can be developed independently.

## 4.4 Collaboration

Developers can exchange and integrate changes.

## 4.5 Accountability

Commits record author information and associated timestamps.

## 4.6 Release Management

Specific commits can be associated with software releases.

Version control therefore provides more than backup functionality.

It establishes a structured history of software development.

---

# 5. CENTRALIZED AND DISTRIBUTED VERSION CONTROL

Version control systems can use different architectures.

## 5.1 Centralized Version Control

A centralized system commonly relies on a primary central repository.

Developers retrieve files and submit changes to that system.

The central server holds the authoritative history.

## 5.2 Distributed Version Control

Git is a distributed version control system.

A normal Git clone contains local repository history.

Developers can create commits, examine history, and manage branches without continuously communicating with a server.

Remote synchronization happens when needed.

### Architecture

```text
REMOTE REPOSITORY → DEVELOPER A
REMOTE REPOSITORY → DEVELOPER B
DEVELOPER A → LOCAL GIT REPOSITORY
DEVELOPER B → LOCAL GIT REPOSITORY
LOCAL GIT REPOSITORY → LOCAL WORK
```

Both developers can create local commits.

They later exchange changes through a remote repository.

**Important distinction:** Git can function locally without GitHub or internet access.

---

# PART III — GIT VERSUS GITHUB

## 6. WHAT IS GIT?

Git is a distributed version control system.

It runs on the developer's computer and manages repository history.

Git provides commands such as:

```bash
git init
git add
git commit
git log
git branch
git merge
```

These operations can be performed entirely offline.

Git is the underlying version control technology.

---

# 7. WHAT IS GITHUB?

GitHub is an online platform for hosting Git repositories and supporting software collaboration.

GitHub provides capabilities including:

- Remote repository hosting.
- Pull requests.
- Code reviews.
- Issues.
- Project management.
- Releases.
- Repository access controls.
- GitHub Actions automation.

GitHub uses Git, but Git and GitHub are not the same thing.

### Comparison

| Git                                | GitHub                                         |
| ---------------------------------- | ---------------------------------------------- |
| Version control software           | Repository hosting and collaboration platform  |
| Runs locally                       | Primarily a network service                    |
| Manages commits and branches       | Hosts repositories and collaboration workflows |
| Can work offline                   | Online features require service connectivity   |
| Uses commands such as `git commit` | Supports pull requests, reviews, and Actions   |

### Simple Relationship

```text
             GIT
      VERSION CONTROL TOOL
               |
               v
            GITHUB
      REPOSITORY HOSTING
      AND COLLABORATION
```

Other platforms can also host Git repositories.

GitHub is not required for Git to function.

---

# 8. WHAT IS A REPOSITORY?

A Git repository is a collection of project files together with Git's stored version-control information.

A repository can contain:

- Source code.
- Documentation.
- Configuration files.
- Tests.
- Commit history.
- Branch references.
- Tags.
- Git configuration.

Example project:

```text
task-manager/
├── app.py
├── README.md
├── requirements.txt
├── tests/
└── .git/
```

The `.git` directory stores the Git repository's internal data.

The other files are part of the working project.

---

# 9. THE .GIT DIRECTORY

When Git initializes an ordinary repository, it creates a hidden directory named:

```text
.git
```

This directory contains repository metadata and version-control objects.

Common internal components include:

```text
.git/
├── HEAD
├── config
├── objects/
├── refs/
├── hooks/
└── index
```

## HEAD

Identifies the current checked-out commit or, commonly, the current branch reference.

## config

Stores repository-specific Git configuration.

## objects

Stores Git objects representing content and history.

## refs

Stores references such as branches and tags.

## hooks

Contains locations for Git hook scripts and example hooks.

## index

Stores the staging area representation.

**Important:** The `.git` directory should not be manually modified during ordinary Git usage.

Deleting `.git` removes the directory's local Git repository metadata and history.

The remaining project files may still exist, but the directory is no longer the same initialized repository.

---

# PART IV — INSTALLING AND CONFIGURING GIT

## 10. INSTALLING GIT

Git is available for Linux, Windows, and macOS.

### Ubuntu and Debian

```bash
sudo apt update
sudo apt install git
```

### Fedora

```bash
sudo dnf install git
```

### Windows

Git for Windows can be installed from:

https://git-scm.com/downloads/win

Git Bash provides a Bash-like shell environment suitable for the exercises in this lecture.

### macOS

Git may already be available through Apple developer tools.

Another installation approach is:

```bash
brew install git
```

when Homebrew is installed.

---

# 11. VERIFYING GIT

Execute:

```bash
git --version
```

Example output:

```text
git version 2.x.x
```

The exact version depends on the installed environment.

The command confirms that Git is available.

---

# 12. GIT CONFIGURATION

Git stores configuration values controlling its behavior.

Common configuration settings include:

- Author name.
- Author email.
- Default initial branch.
- Default editor.
- Merge and output preferences.

Git supports different configuration scopes.

---

# 13. CONFIGURATION SCOPES

## System Configuration

Applies to the system installation, subject to permissions and more specific overrides.

Example:

```bash
git config --system --list
```

## Global Configuration

Applies to the current user's Git environment.

Example:

```bash
git config --global --list
```

## Local Configuration

Applies to one repository.

Example:

```bash
git config --local --list
```

Local repository configuration generally overrides corresponding global values.

### Conceptual Priority

```text
SYSTEM CONFIGURATION
         |
         v
GLOBAL CONFIGURATION
         |
         v
LOCAL REPOSITORY CONFIGURATION
```

More specific applicable configuration can override less specific configuration.

Other Git configuration mechanisms also exist, but these are the essential scopes for this lesson.

---

# 14. CONFIGURING AN AUTHOR IDENTITY

For normal personal use:

```bash
git config --global user.name "Your Name"
```

```bash
git config --global user.email "you@example.com"
```

Replace these placeholders with your preferred Git author identity.

Check the values:

```bash
git config --global user.name
```

```bash
git config --global user.email
```

The email stored in a commit identifies its author.

This is different from authenticating to GitHub.

An author name and email do not establish permission to push to a remote repository.

---

# 15. DEFAULT BRANCH CONFIGURATION

Modern Git versions support selecting an initial branch.

For example:

```bash
git config --global init.defaultBranch main
```

This configures the branch name commonly used when new repositories are initialized.

A particular repository can also be initialized explicitly using:

```bash
git init -b main
```

This lecture uses `main` as its primary branch.

---

# PART V — CREATING AND CLONING REPOSITORIES

## 16. CREATING A LOCAL REPOSITORY

Create a project directory:

```bash
mkdir my-project
```

Enter it:

```bash
cd my-project
```

Initialize Git:

```bash
git init -b main
```

Git creates the repository metadata.

The directory becomes a Git repository.

Initially, it may have no commits.

---

# 17. CHECKING REPOSITORY STATUS

Execute:

```bash
git status
```

Git reports information such as:

- Current branch.
- Untracked files.
- Modified files.
- Staged files.
- Whether changes are ready to commit.

A newly initialized repository may report that no commits exist.

The exact output depends on the working directory.

---

# 18. CLONING AN EXISTING REPOSITORY

The command:

```bash
git clone REPOSITORY_LOCATION
```

copies an existing Git repository into a local directory.

A repository location can be:

- A local filesystem path.
- An HTTPS repository URL.
- An SSH repository URL.

Example of local cloning:

```bash
git clone ../existing-project copied-project
```

Example of remote cloning:

```bash
git clone https://github.com/OWNER/REPOSITORY.git
```

The remote example requires an actual accessible repository.

### Difference

`git init` initializes a new repository.

`git clone` copies an existing repository, including available history and references.

Remote authentication and synchronization will be studied in Major Lecture 02.

---

# PART VI — THE THREE MAIN AREAS OF GIT

## 19. THE MOST IMPORTANT GIT CONCEPT

To understand Git correctly, you must distinguish three areas:

1. Working directory.
2. Staging area.
3. Repository history.

These areas form the foundation of everyday Git operations.

### Architecture

```text
             WORKING DIRECTORY
               YOUR FILES
                    |
                 git add
                    |
                    v
               STAGING AREA
               NEXT SNAPSHOT
                    |
                git commit
                    |
                    v
             LOCAL REPOSITORY
              COMMIT HISTORY
```

A developer changes files in the working directory.

Selected changes are staged.

Git records the staged snapshot when a commit is created.

---

# 20. WORKING DIRECTORY

The working directory is the filesystem location where project files are available for editing.

For example:

```text
project/
├── app.py
├── README.md
└── config.txt
```

You can:

- Modify files.
- Create files.
- Delete files.
- Rename files.

Git can identify differences between the working directory and the relevant recorded or staged state.

The working directory contains the actual files used by editors and development tools.

---

# 21. STAGING AREA

The staging area is also called the index.

It records the content selected for the next commit.

Example:

```bash
git add app.py
```

This updates the staging area with the current content of `app.py`.

The command does not create a commit.

It prepares content for a future commit.

### Important Detail

Staging records file content at the time of staging.

If you modify a file after staging it, those newer modifications are not automatically added to the staged snapshot.

You must stage the updated content again if you want the next commit to include it.

---

# 22. LOCAL REPOSITORY HISTORY

The local repository stores committed project history.

A commit represents a recorded project snapshot with metadata and relationships to previous commits.

Create a commit:

```bash
git commit -m "Add initial application"
```

Git creates a new commit object and updates the current branch reference.

The message describes the recorded change.

---

# 23. TRACKED AND UNTRACKED FILES

A file may be tracked or untracked.

## Untracked

Git has not yet included the file in the repository's tracked state or staging index.

Example:

```text
new-file.txt
```

## Tracked

Git knows about the file through the repository or staging state.

A tracked file may be:

- Unmodified.
- Modified.
- Staged for commit.
- Deleted from the working directory.

### Typical Lifecycle

```text
UNTRACKED FILE
      |
    git add
      |
      v
STAGED NEW FILE
      |
   git commit
      |
      v
TRACKED FILE
      |
  edit file
      |
      v
MODIFIED FILE
      |
    git add
      |
      v
STAGED MODIFICATION
      |
   git commit
      |
      v
UPDATED HISTORY
```

---

# PART VII — STAGING AND COMMITTING

## 24. THE git add COMMAND

`git add` stages content.

Examples:

Stage one file:

```bash
git add README.md
```

Stage selected files:

```bash
git add app.py README.md
```

Stage changes under the current directory:

```bash
git add .
```

Stage changes across the entire current repository:

```bash
git add -A
```

Interactive staging is also available:

```bash
git add -p
```

### Important Principle

`git add` does not automatically create a permanent historical snapshot.

That happens when a commit is created.

---

# 25. THE git commit COMMAND

A commit records the staged snapshot.

Example:

```bash
git commit -m "Add task creation endpoint"
```

A commit includes metadata such as:

- Author.
- Committer.
- Commit message.
- Timestamp information.
- Tree representing the snapshot.
- Parent commit relationships.

Each commit has an identifier derived from the repository's object format.

A displayed abbreviated identifier might resemble:

```text
f82ac91
```

The actual value is determined by Git.

---

# 26. COMMIT MESSAGES

A good commit message should describe the purpose of the change.

### Weak Examples

```text
update
fix
changes
stuff
```

### Better Examples

```text
Initialize task manager repository
Add task listing function
Fix empty task title validation
Document branch workflow
```

A meaningful commit message helps future developers understand the project history.

### Recommended Pattern

```text
Action + specific change
```

Example:

```text
Add validation for empty task titles
```

---

# 27. COMMIT FREQUENCY

Commits should represent meaningful units of work.

A single commit might contain:

- One new feature.
- One bug fix.
- One documentation improvement.
- One focused refactoring.

Avoid grouping unrelated work into the same commit when it can reasonably be separated.

A good commit should be understandable and reviewable.

---

# 28. STAGING VERSUS COMMITTING

Consider:

```bash
git add app.py
```

The file content is prepared for the next commit.

Now execute:

```bash
git commit -m "Update application"
```

The staged snapshot is recorded in repository history.

### Important Distinction

`git add` chooses what goes into the next commit.

`git commit` records that choice in history.

---

# PART VIII — IGNORING FILES

## 29. THE .gitignore FILE

A `.gitignore` file defines patterns for untracked files that Git should ordinarily ignore.

Examples include:

- Temporary files.
- Build outputs.
- Local environment files.
- Generated caches.
- Editor-specific files.

Example:

```gitignore
__pycache__/
*.pyc
*.log
.env
.venv/
```

### Explanation

`__pycache__/` ignores Python cache directories.

`*.pyc` ignores compiled Python bytecode.

`*.log` ignores matching log files.

`.env` ignores a local environment file.

`.venv/` ignores a local Python virtual environment directory.

---

# 30. IMPORTANT .gitignore LIMITATION

`.gitignore` does not automatically stop tracking files that Git already tracks.

If a file is already committed, adding it to `.gitignore` is not sufficient to remove it from version control.

To remove a tracked file from the index while keeping its working copy:

```bash
git rm --cached FILE
```

The change must then be committed.

**Security Warning:** If a secret was previously committed, removing the file from the latest commit does not necessarily erase the secret from historical commits.

An exposed credential should be revoked or rotated, and repository history may require additional remediation.

---

# PART IX — INSPECTING CHANGES

## 31. git status

This is one of the most frequently used Git commands.

```bash
git status
```

It reports the current repository state.

A shorter representation is:

```bash
git status --short
```

Example output:

```text
 M app.py
?? notes.txt
```

### Interpretation

` M app.py` means the tracked file has unstaged working-directory modifications.

`?? notes.txt` means the file is untracked.

Other indicators represent staged modifications, additions, deletions, or conflicts.

---

# 32. git diff

The basic command:

```bash
git diff
```

shows unstaged working-directory changes relative to the index.

### Example

Original:

```python
print("Hello")
```

Modified:

```python
print("Hello, Git")
```

Git can display which lines were removed and added.

---

# 33. git diff --staged

Execute:

```bash
git diff --staged
```

This shows staged changes relative to the current commit.

The equivalent option:

```bash
git diff --cached
```

is also available.

### Comparison

| Command             | Comparison                              |
| ------------------- | --------------------------------------- |
| `git diff`          | Working directory versus index          |
| `git diff --staged` | Index versus current commit             |
| `git diff HEAD`     | Working directory versus current commit |

These comparisons are central to understanding the three Git areas.

---

# 34. CHECKING PATCH QUALITY

Execute:

```bash
git diff --check
```

Git checks selected whitespace problems in the diff.

This is useful before creating a commit.

It is not a full code-quality or syntax validator.

---

# PART X — INSPECTING PROJECT HISTORY

## 35. git log

The `git log` command displays commit history.

```bash
git log
```

A compact view:

```bash
git log --oneline
```

Example:

```text
b13f41e Add task listing
f6c8142 Initialize repository
```

The identifiers are illustrative.

---

# 36. GRAPHICAL HISTORY

Execute:

```bash
git log --oneline --graph --decorate --all
```

This shows:

- Commit history.
- Branch relationships.
- Tags and branch labels.
- Visible merge structure.

Example:

```text
*   e51d423 Merge feature/show-count
|\
| * a17c4bd Add task count display
* | b44f817 Update project documentation
|/
* 8c3d210 Initialize repository
```

The exact structure depends on the repository's history.

---

# 37. git show

Use `git show` to inspect a particular commit.

```bash
git show HEAD
```

Or inspect a specific commit ID:

```bash
git show COMMIT_ID
```

The output may include:

- Commit metadata.
- Commit message.
- File differences.

---

# 38. git blame

The `git blame` command annotates lines with information about commits associated with those lines.

Example:

```bash
git blame app.py
```

It helps investigate the recorded history of individual lines.

### Important Qualification

`git blame` does not establish who is personally responsible for a bug.

It records line attribution based on repository history.

Later refactoring, copied code, and other operations can affect what it shows.

---

# PART XI — BRANCHING

## 39. WHAT IS A BRANCH?

A Git branch is a movable reference to a commit.

Branches allow different lines of development to progress independently.

Example:

```plaintext
                A ---- B ---- C
                       \
                        D ---- E
```

The upper history may represent `main`.

The lower history may represent `feature/tasks`.

Both histories share earlier commits.

---

# 40. WHY BRANCHES ARE USEFUL

Branches allow a developer to:

- Develop a feature independently.
- Fix a bug without disrupting other work.
- Experiment with changes.
- Separate release preparation.
- Review work before integration.

Branches are generally lightweight references, not complete duplicated copies of every repository file.

---

# 41. THE MAIN BRANCH

Many repositories use:

```text
main
```

as their primary development branch.

The branch name is conventional.

Git does not require the name to be `main`.

Other branch names are possible.

---

# 42. CREATING A BRANCH

Execute:

```bash
git branch feature/tasks
```

This creates a new branch reference.

It does not automatically switch to that branch.

Switch using:

```bash
git switch feature/tasks
```

Or create and switch in one operation:

```bash
git switch -c feature/tasks
```

---

# 43. LISTING BRANCHES

Execute:

```bash
git branch
```

Example:

```text
* main
  feature/tasks
```

The asterisk identifies the current branch.

For additional information:

```bash
git branch -v
```

---

# 44. SWITCHING BRANCHES

Execute:

```bash
git switch main
```

Git updates the checked-out branch and adjusts working files as needed.

### Important Qualification

If local uncommitted changes would be overwritten by a branch switch, Git may refuse the operation.

The developer should commit, stash, or deliberately resolve those changes before switching.

---

# 45. WHAT IS HEAD?

`HEAD` represents the currently checked-out position in repository history.

In normal branch-based work, HEAD is a symbolic reference to the current branch.

Example:

```text
HEAD
 |
 v
main
 |
 v
Commit C
```

If you create a new commit on main, main advances.

HEAD continues to refer to main.

### View HEAD

```bash
git symbolic-ref --short HEAD
```

This ordinarily prints the current branch name when HEAD is attached to a branch.

---

# 46. DETACHED HEAD

A detached HEAD occurs when HEAD directly identifies a commit rather than a branch reference.

For example:

```bash
git switch --detach COMMIT_ID
```

This allows inspection or experimentation at a specific historical commit.

New commits made while detached may become difficult to find after moving away unless a branch or another reference is created.

To preserve work:

```bash
git switch -c saved-experiment
```

### Key Lesson

A branch is a named movable reference.

Detached HEAD means the checked-out commit is not being followed through an ordinary current branch reference.

---

# 47. DELETING AND RENAMING BRANCHES

Delete a safely merged branch:

```bash
git branch -d feature/tasks
```

Force deletion:

```bash
git branch -D feature/tasks
```

### Warning

`-D` skips the ordinary merged-work safety check.

Do not use it casually when the branch may contain unique work.

Rename a branch:

```bash
git branch -m old-name new-name
```

---

# PART XII — MERGING

## 48. WHAT IS MERGING?

Merging combines development histories.

Suppose two branches contain useful changes.

The objective is to integrate them into a selected target branch.

Example:

```text
                   MAIN
                A --- B
                 \
                  C --- D
                   FEATURE
```

A merge incorporates the feature branch's changes into the current branch's history.

---

# 49. FAST-FORWARD MERGE

A fast-forward merge is possible when the target branch has not diverged from the source branch.

Example:

Before:

```text
main
 |
 v
 A --- B --- C
             ^
             |
           feature
```

After:

```plaintext
A --- B --- C
            ^
            |
       main, feature
```

Git can simply move the target branch reference forward.

Example:

```bash
git switch main
```

```bash
git merge --ff-only feature
```

The `--ff-only` option permits the merge only when a fast-forward is possible.

---

# 50. THREE-WAY MERGE

A three-way merge becomes relevant when branches have diverged.

Example:

```text
A → B (main)
A → C (feature)
```

Git identifies a common ancestor and combines the differing development histories.

A successful merge may produce:

```text
          A
         / \
        B   C
         \ /
          M
          |
         MAIN
```

`M` is a merge commit.

A merge commit can have more than one parent.

---

# 51. MERGE DIRECTION

The usual command:

```bash
git merge feature/tasks
```

merges `feature/tasks` into the **currently checked-out branch**.

If you intend to merge into main:

```bash
git switch main
```

Then:

```bash
git merge feature/tasks
```

### Important Principle

The current branch is the merge destination.

Always check your branch before merging.

---

# PART XIII — MERGE CONFLICTS

## 52. WHAT IS A MERGE CONFLICT?

A merge conflict occurs when Git cannot automatically combine changes safely.

For example, two branches modify the same line differently.

### Main Branch

```text
Theme: purple
```

### Feature Branch

```text
Theme: green
```

Git may not be able to determine which value is correct.

It pauses the merge for human resolution.

---

# 53. CONFLICT MARKERS

A conflicted file may contain:

```text
<<<<<<< HEAD
Theme: purple
=======
Theme: green
>>>>>>> feature/theme
```

### Interpretation

The first section represents one side of the conflict.

The second section represents the other side.

The markers identify the conflicting region.

### Important Detail

Conflict markers are not intended to remain in the completed source file.

The developer must resolve the content.

---

# 54. RESOLVING THE CONFLICT

The developer decides the correct final content.

Example:

```text
Theme: green and purple
```

Then stage the resolved file:

```bash
git add settings.txt
```

Complete the merge:

```bash
git commit -m "Resolve theme configuration conflict"
```

### General Procedure

1. Inspect conflicting files.
2. Understand both changes.
3. Decide the correct result.
4. Remove conflict markers.
5. Save the resolved files.
6. Stage them.
7. Complete the merge.
8. Test the application.

---

# 55. ABORTING A MERGE

If a merge is in progress and should not be completed:

```bash
git merge --abort
```

Git attempts to return to the pre-merge state.

### Important Qualification

A merge abort is not guaranteed to restore every unrelated local modification exactly as expected in all situations.

Keeping the working directory clean before a complicated merge reduces risk.

---

# PART XIV — UNDOING AND RECOVERING WORK

## 56. WHY GIT RECOVERY REQUIRES CARE

Git provides several ways to undo changes.

However, these commands do not all perform the same operation.

A developer must first identify where the unwanted change exists:

- Working directory.
- Staging area.
- Local commit history.
- Shared commit history.

Choosing the wrong operation can destroy uncommitted work or rewrite history unexpectedly.

---

# 57. git restore — DISCARDING WORKING CHANGES

Suppose `README.md` is tracked.

You modify it but have not staged the modifications.

Execute:

```bash
git restore README.md
```

This restores the working file from the index by default.

### Warning

Unstaged modifications in that file may be lost.

Use:

```bash
git diff README.md
```

first if you are uncertain.

---

# 58. git restore --staged — UNSTAGING

Suppose you accidentally stage a file.

Execute:

```bash
git restore --staged README.md
```

This updates the staging area to remove the selected staged changes relative to HEAD.

The modified working file remains.

### Difference

```text
git restore FILE
```

Restores working-tree content from the index.

```text
git restore --staged FILE
```

Resets the staged version to HEAD while keeping working-directory changes.

---

# 59. RESTORING FROM AN OLDER COMMIT

To recover a file's historical content into the working directory:

```bash
git restore --source=HEAD~1 -- README.md
```

This selects the file content from the parent of HEAD.

The result is placed in the working directory.

Review it before staging or committing.

---

# 60. git commit --amend

The amend option replaces the latest commit with an updated commit.

Example:

```bash
git commit --amend -m "Improve documentation"
```

The resulting commit receives a new identifier.

### Appropriate Use

Correcting a recent local commit that has not been shared.

### Important Warning

Amending a commit that others already depend on rewrites history and can complicate collaboration.

---

# 61. git reset

`git reset` can move the current branch or HEAD to another commit and can also update the index and working tree depending on its mode.

The three most important modes are:

```text
--soft
--mixed
--hard
```

---

# 62. SOFT RESET

Example:

```bash
git reset --soft HEAD~1
```

This moves the current branch back one commit.

The staging area and working directory remain unchanged.

The changes from the former latest commit ordinarily remain staged.

### Main Idea

**Soft reset = move history reference, keep staged content.**

---

# 63. MIXED RESET

Example:

```bash
git reset --mixed HEAD~1
```

This moves the current branch back and resets the index.

Working files are generally preserved.

Changes from the removed commit may become unstaged working-directory changes.

`--mixed` is the default reset mode when no mode is specified.

### Main Idea

**Mixed reset = move history reference, update staging, keep working files.**

---

# 64. HARD RESET

Example:

```bash
git reset --hard HEAD~1
```

This moves the current branch back and resets both the index and tracked working-tree content.

### Critical Warning

This operation can destroy uncommitted changes.

It can also make commits unreachable through the ordinary branch history.

Do not run hard reset on valuable work unless you understand exactly which content and history will be affected.

### Main Idea

**Hard reset = move history reference and replace tracked working content.**

---

# 65. RESET COMPARISON

| Command         | Move branch/HEAD | Reset staging | Reset tracked working content |
| --------------- | ---------------- | ------------- | ----------------------------- |
| `reset --soft`  | Yes              | No            | No                            |
| `reset --mixed` | Yes              | Yes           | No                            |
| `reset --hard`  | Yes              | Yes           | Yes                           |

This table is among the most important Git recovery references.

---

# 66. git revert

`git revert` creates a new commit that applies the inverse of a selected earlier commit's changes, when Git can perform the operation.

Example:

```bash
git revert HEAD
```

Unlike reset, revert ordinarily preserves the existing historical sequence and adds a new commit.

### Example

Original history:

```plaintext
A --- B --- C
```

After reverting C:

```plaintext
A --- B --- C --- R
```

`R` reverses the selected changes.

### Important Principle

Revert is generally preferable to rewriting already shared history when an existing commit must be undone.

---

# 67. RESET VERSUS REVERT

| Reset                                         | Revert                                        |
| --------------------------------------------- | --------------------------------------------- |
| Can move branch history backward              | Adds a new undoing commit                     |
| May rewrite visible history                   | Preserves previous commits                    |
| Useful for selected local recovery operations | Useful for undoing shared changes             |
| Hard mode can discard work                    | May produce conflicts that require resolution |

---

# 68. git reflog

Git reflogs record local updates to references such as HEAD and branches.

Execute:

```bash
git reflog
```

Example output may resemble:

```text
f13c890 HEAD@{0}: commit: Add documentation
a74ef21 HEAD@{1}: reset: moving to HEAD~1
b921c04 HEAD@{2}: commit: Add task counter
```

The commit IDs and positions depend on the local repository.

### Why It Matters

Reflog entries may help locate commits that are no longer visible through the current branch's ordinary history.

Example recovery:

```bash
git branch recovered-work COMMIT_ID
```

This creates a branch pointing to the selected existing commit.

### Limitation

Reflogs are local and subject to expiration and object cleanup.

They are not permanent backups.

---

# PART XV — PRACTICAL LABORATORY

## 69. LABORATORY TITLE

**Complete Git Fundamentals Laboratory: Building, Tracking, Branching, Merging, and Recovering a Small Python Task Project**

The laboratory is designed for a Bash-compatible terminal.

It uses:

- Git.
- Python 3.
- Plain-text files.
- A local Git repository.

No GitHub account is required.

All repository history remains local.

---

# 70. LABORATORY OBJECTIVES

The student will:

1. Create a Git repository.
2. Configure its author identity.
3. Create source files.
4. Track and commit changes.
5. Compare staged and unstaged content.
6. Ignore local files.
7. Inspect commit history.
8. Create feature branches.
9. Make independent changes.
10. Perform three-way merges.
11. Perform fast-forward merges.
12. Produce a deliberate merge conflict.
13. Resolve the conflict.
14. Restore uncommitted changes.
15. Unstage changes.
16. Amend a local commit.
17. Experiment with soft reset.
18. Revert a commit.
19. Inspect reflogs.
20. Clone the completed repository locally.

---

# 71. EXPERIMENT 1 — VERIFY GIT

Execute:

```bash
git --version
```

**Objective:** Confirm that Git is installed.

Record the version.

---

# 72. EXPERIMENT 2 — INSPECT GIT CONFIGURATION

Execute:

```bash
git config --list --show-origin
```

**Objective:** Identify configured values and their sources.

Record the active author identity if present.

---

# 73. EXPERIMENT 3 — CREATE THE PROJECT

Execute:

```bash
mkdir git-major-lesson1
```

```bash
cd git-major-lesson1
```

**Objective:** Create a clean laboratory directory.

---

# 74. EXPERIMENT 4 — INITIALIZE GIT

Execute:

```bash
git init -b main
```

Set an identity for this practice repository:

```bash
git config --local user.name "Git Student"
```

```bash
git config --local user.email "student@example.invalid"
```

These values are illustrative local training metadata, not login credentials.

**Objective:** Initialize a local repository without changing the user's global author configuration.

---

# 75. EXPERIMENT 5 — CREATE THE INITIAL SOURCE FILES

Create `README.md`:

```bash
cat > README.md <<'EOF'
# Git Task Manager

A small project used to learn Git fundamentals.
EOF
```

Create `tasks.py`:

```bash
cat > tasks.py <<'PY'
def main():
    print("Git practice task manager")


if __name__ == "__main__":
    main()
PY
```

Create `.gitignore`:

```bash
cat > .gitignore <<'EOF'
.env
*.log
__pycache__/
*.pyc
EOF
```

**Objective:** Establish a small software project.

---

# 76. EXPERIMENT 6 — INSPECT UNTRACKED FILES

Execute:

```bash
git status
```

Then:

```bash
git status --short
```

**Expected result:** Git identifies the newly created files as untracked.

**Objective:** Understand how Git identifies new files.

---

# 77. EXPERIMENT 7 — STAGE THE PROJECT

Execute:

```bash
git add README.md tasks.py .gitignore
```

Inspect:

```bash
git status
```

**Expected result:** The files are staged for the first commit.

**Objective:** Understand the staging area.

---

# 78. EXPERIMENT 8 — INSPECT STAGED CONTENT

Execute:

```bash
git diff --staged
```

**Objective:** Inspect the selected snapshot before committing.

**Expected result:** Git displays the content added to the repository.

---

# 79. EXPERIMENT 9 — CREATE THE FIRST COMMIT

Execute:

```bash
git commit -m "Initialize Git task manager"
```

Inspect:

```bash
git log --oneline
```

**Objective:** Record the project's initial state.

**Expected result:** A first commit appears in history.

---

# 80. EXPERIMENT 10 — MODIFY THE APPLICATION

Replace `tasks.py`:

```bash
cat > tasks.py <<'PY'
def tasks():
    return [
        "Learn Git",
        "Practice branching",
    ]


def main():
    for task in tasks():
        print(f"- {task}")


if __name__ == "__main__":
    main()
PY
```

Run:

```bash
python3 tasks.py
```

**Expected result:**

```text
- Learn Git
- Practice branching
```

Inspect:

```bash
git diff
```

**Objective:** Compare working-directory changes with the staged state.

---

# 81. EXPERIMENT 11 — OBSERVE STAGED SNAPSHOTS

Stage the change:

```bash
git add tasks.py
```

Now append a harmless comment:

```bash
printf '\n# End of task list\n' >> tasks.py
```

Inspect unstaged changes:

```bash
git diff
```

Inspect staged changes:

```bash
git diff --staged
```

**Objective:** Prove that editing a file after staging does not automatically update its staged content.

Stage the latest version:

```bash
git add tasks.py
```

Commit:

```bash
git commit -m "Add example task listing"
```

---

# 82. EXPERIMENT 12 — TEST .gitignore

Create a local configuration file:

```bash
printf 'DEMO_ONLY=true\n' > .env
```

Create a log file:

```bash
printf 'Example log\n' > app.log
```

Execute:

```bash
git status --short
```

Verify the ignore rule:

```bash
git check-ignore -v .env
```

**Expected result:** Git recognizes `.env` as ignored.

**Objective:** Understand ignored untracked files.

Do not use real credentials in this experiment.

---

# 83. EXPERIMENT 13 — INSPECT HISTORY

Execute:

```bash
git log --oneline
```

Then:

```bash
git show HEAD
```

Then:

```bash
git blame tasks.py
```

**Objective:** Inspect the most recent commit and the recorded history of individual lines.

---

# 84. EXPERIMENT 14 — CREATE A FEATURE BRANCH

Execute:

```bash
git switch -c feature/show-count
```

Verify:

```bash
git branch
```

**Expected result:** The current branch is `feature/show-count`.

**Objective:** Begin independent feature development.

---

# 85. EXPERIMENT 15 — DEVELOP THE FEATURE

Replace `tasks.py` with:

```bash
cat > tasks.py <<'PY'
def tasks():
    return [
        "Learn Git",
        "Practice branching",
    ]


def main():
    for task in tasks():
        print(f"- {task}")

    print(f"Total tasks: {len(tasks())}")


if __name__ == "__main__":
    main()
PY
```

Run:

```bash
python3 tasks.py
```

Commit:

```bash
git add tasks.py
```

```bash
git commit -m "Add task count display"
```

**Objective:** Create a feature commit on an independent branch.

---

# 86. EXPERIMENT 16 — CHANGE MAIN INDEPENDENTLY

Switch to main:

```bash
git switch main
```

Append documentation:

```bash
cat >> README.md <<'EOF'

## Purpose

This project demonstrates Git commits, branches, and merges.
EOF
```

Commit:

```bash
git add README.md
```

```bash
git commit -m "Document project purpose"
```

**Objective:** Create independent changes on the two branches.

---

# 87. EXPERIMENT 17 — PERFORM A THREE-WAY MERGE

Confirm the current branch:

```bash
git branch --show-current
```

Merge:

```bash
git merge feature/show-count
```

**Expected result:** Git combines the independent changes.

Because main and the feature branch have diverged, Git generally creates a merge commit in this example.

Inspect:

```bash
git log --oneline --graph --decorate --all
```

Run:

```bash
python3 tasks.py
```

**Objective:** Integrate two lines of development.

---

# 88. EXPERIMENT 18 — DELETE THE MERGED BRANCH

Execute:

```bash
git branch -d feature/show-count
```

**Objective:** Remove an unnecessary branch reference after integration.

The merged commits remain reachable through main.

---

# 89. EXPERIMENT 19 — DEMONSTRATE A FAST-FORWARD MERGE

Create a new branch:

```bash
git switch -c feature/about
```

Create a file:

```bash
printf 'This project is a Git training laboratory.\n' > ABOUT.md
```

Commit:

```bash
git add ABOUT.md
```

```bash
git commit -m "Add project description"
```

Switch to main:

```bash
git switch main
```

Merge:

```bash
git merge --ff-only feature/about
```

Delete the feature branch:

```bash
git branch -d feature/about
```

**Objective:** Observe a merge that moves the main branch reference forward without needing a merge commit.

---

# 90. EXPERIMENT 20 — PREPARE A MERGE CONFLICT

Create a settings file:

```bash
printf 'Theme: blue\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Add theme setting"
```

Create a feature branch:

```bash
git switch -c feature/theme
```

Change the theme:

```bash
printf 'Theme: green\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Change theme to green"
```

**Objective:** Establish one side of a future conflict.

---

# 91. EXPERIMENT 21 — CREATE THE OTHER CONFLICTING CHANGE

Switch to main:

```bash
git switch main
```

Change the same line:

```bash
printf 'Theme: purple\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Change theme to purple"
```

**Objective:** Create a conflicting change in a separate branch.

---

# 92. EXPERIMENT 22 — TRIGGER THE MERGE CONFLICT

Execute:

```bash
git merge feature/theme
```

**Expected result:** The merge reports a content conflict.

Inspect:

```bash
git status
```

Open:

```text
settings.txt
```

The file should contain conflict markers representing the two versions.

**Objective:** Observe Git's behavior when automatic merging is impossible.

---

# 93. EXPERIMENT 23 — RESOLVE THE CONFLICT

Replace the file with an explicitly chosen result:

```bash
printf 'Theme: green and purple\n' > settings.txt
```

Stage:

```bash
git add settings.txt
```

Complete the merge:

```bash
git commit -m "Resolve conflicting theme changes"
```

Delete the merged branch:

```bash
git branch -d feature/theme
```

Inspect history:

```bash
git log --oneline --graph --decorate --all
```

**Objective:** Complete conflict resolution safely.

---

# 94. EXPERIMENT 24 — RESTORE AN UNSTAGED CHANGE

Append an unwanted line:

```bash
printf '\nUnwanted documentation line\n' >> README.md
```

Inspect:

```bash
git diff README.md
```

Restore:

```bash
git restore README.md
```

Verify:

```bash
git status --short
```

**Objective:** Discard a selected unstaged modification.

---

# 95. EXPERIMENT 25 — UNSTAGE A CHANGE

Append:

```bash
printf '\nTemporary documentation note\n' >> README.md
```

Stage:

```bash
git add README.md
```

Unstage:

```bash
git restore --staged README.md
```

Inspect:

```bash
git status
```

The working-directory modification remains.

Discard it for this demonstration:

```bash
git restore README.md
```

**Objective:** Distinguish removing staged content from discarding a working-directory change.

---

# 96. EXPERIMENT 26 — AMEND A LOCAL COMMIT

Create:

```bash
printf 'Git recovery techniques\n' > recovery.md
```

Commit:

```bash
git add recovery.md
```

```bash
git commit -m "Add recovery notes"
```

Now correct the commit message:

```bash
git commit --amend -m "Document Git recovery techniques"
```

Inspect:

```bash
git log -1 --oneline
```

**Objective:** Learn how a local commit can be replaced with an amended commit.

Do not perform this operation casually on shared history.

---

# 97. EXPERIMENT 27 — SOFT RESET

Record the current latest commit:

```bash
git log -1 --oneline
```

Execute:

```bash
git reset --soft HEAD~1
```

Inspect:

```bash
git status
```

The changes from the former commit remain staged.

Recreate the commit:

```bash
git commit -m "Document Git recovery and history"
```

**Objective:** Understand the distinction between moving a branch reference and retaining staged content.

---

# 98. EXPERIMENT 28 — REVERT A COMMIT

Create an intentional bad documentation change:

```bash
printf '\nIncorrect temporary instruction\n' >> README.md
```

Commit:

```bash
git add README.md
```

```bash
git commit -m "Add incorrect temporary instruction"
```

Now revert:

```bash
git revert --no-edit HEAD
```

Inspect:

```bash
git log --oneline -3
```

**Expected result:** A new commit reverses the earlier change.

**Objective:** Demonstrate history-preserving undo.

---

# 99. EXPERIMENT 29 — INSPECT REFLOG

Execute:

```bash
git reflog
```

Identify entries related to:

- Commit creation.
- Amending a commit.
- Soft reset.
- Branch switching.

**Objective:** Understand how local reference history can support recovery.

The exact entries and identifiers depend on the repository.

---

# 100. EXPERIMENT 30 — CLONE THE REPOSITORY LOCALLY

First ensure the working directory is clean:

```bash
git status
```

From inside the laboratory repository, clone to a sibling directory:

```bash
git clone . ../git-major-lesson1-copy
```

Inspect the copied repository:

```bash
cd ../git-major-lesson1-copy
```

```bash
git log --oneline --graph --decorate --all
```

**Objective:** Verify that a clone contains repository history, not merely the current source files.

The ignored `.env` and log files are not included in ordinary tracked repository history.

---

# 101. FINAL LABORATORY STATE

At the end of the laboratory, the student should have experience with:

- Initialization.
- Configuration.
- Tracking.
- Staging.
- Committing.
- Ignoring files.
- Differences.
- Commit history.
- Branches.
- Fast-forward merges.
- Three-way merges.
- Merge conflicts.
- Restoration.
- Unstaging.
- Amend.
- Reset.
- Revert.
- Reflog.
- Local cloning.

All of these operations can be practiced without GitHub.

---

# PART XVI — THE MOST IMPORTANT GIT COMMANDS

## 102. COMMAND SUMMARY

| Command                     | Main purpose                            |
| --------------------------- | --------------------------------------- |
| `git init -b main`          | Initialize repository                   |
| `git clone LOCATION`        | Clone existing repository               |
| `git status`                | Inspect repository state                |
| `git add FILE`              | Stage content                           |
| `git add -A`                | Stage repository changes                |
| `git commit -m "MESSAGE"`   | Record staged snapshot                  |
| `git log`                   | View commit history                     |
| `git log --oneline`         | Compact history                         |
| `git diff`                  | Inspect unstaged changes                |
| `git diff --staged`         | Inspect staged changes                  |
| `git show HEAD`             | Inspect current commit                  |
| `git blame FILE`            | Annotate line history                   |
| `git branch`                | List or manage branches                 |
| `git switch BRANCH`         | Switch branches                         |
| `git switch -c BRANCH`      | Create and switch                       |
| `git merge BRANCH`          | Merge into current branch               |
| `git merge --abort`         | Attempt to abort merge                  |
| `git restore FILE`          | Restore working content                 |
| `git restore --staged FILE` | Unstage content                         |
| `git reset --soft COMMIT`   | Move reference while preserving staging |
| `git reset --mixed COMMIT`  | Move reference and reset index          |
| `git reset --hard COMMIT`   | Move reference and reset tracked files  |
| `git revert COMMIT`         | Create undoing commit                   |
| `git commit --amend`        | Replace latest commit                   |
| `git reflog`                | Inspect local reference updates         |

---

# PART XVII — COMMON GIT MISTAKES

## 103. CONFUSING GIT AND GITHUB

Incorrect:

"Git cannot work without internet."

Correct:

Git performs most local version-control operations without internet access.

GitHub is a remote collaboration service.

---

# 104. CONFUSING STAGING AND COMMITTING

Incorrect:

"`git add` permanently saves a new project version."

Correct:

`git add` updates the staging area.

`git commit` records the staged snapshot.

---

# 105. COMMITTING EVERYTHING WITHOUT REVIEW

Incorrect:

```bash
git add .
git commit -m "update"
```

without checking the selected changes.

Better:

```bash
git status
git diff
git add app.py
git diff --staged
git commit -m "Fix application validation"
```

The goal is to understand what is being recorded.

---

# 106. MISUNDERSTANDING .gitignore

Incorrect:

"Adding a secret filename to `.gitignore` removes it from every historical commit."

Correct:

`.gitignore` primarily controls the treatment of untracked files.

Previously committed secrets require separate remediation.

---

# 107. MERGING INTO THE WRONG BRANCH

Incorrect:

Assuming `git merge feature` always merges into main.

Correct:

It merges into the currently checked-out branch.

Always verify:

```bash
git branch --show-current
```

---

# 108. USING HARD RESET WITHOUT UNDERSTANDING THE CONSEQUENCES

Incorrect:

Running `git reset --hard` whenever something looks wrong.

Correct:

First identify whether the change is:

- Unstaged.
- Staged.
- Committed locally.
- Already shared.

Choose the appropriate recovery command.

---

# 109. REWRITING SHARED HISTORY CARELESSLY

Incorrect:

Amending or resetting shared commits without considering other developers.

Correct:

Prefer history-preserving operations such as revert when the work is already shared, unless a deliberate coordinated history rewrite is required.

---

# PART XVIII — FORMAL ACADEMIC EXAMINATION

## 110. PART A — DEFINITIONS

Define:

1. Version control.
2. Distributed version control.
3. Git.
4. GitHub.
5. Repository.
6. Working directory.
7. Staging area.
8. Commit.
9. Tracked file.
10. Untracked file.
11. Branch.
12. HEAD.
13. Detached HEAD.
14. Fast-forward merge.
15. Merge commit.
16. Merge conflict.
17. Git reset.
18. Git revert.
19. Git restore.
20. Reflog.

---

# 111. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain the difference between Git and GitHub.

**Question 2.**

Describe the three primary Git areas.

**Question 3.**

Explain the lifecycle of a newly created file from untracked to committed.

**Question 4.**

Distinguish `git init` from `git clone`.

**Question 5.**

Explain why meaningful commit messages are important.

**Question 6.**

Distinguish `git diff` from `git diff --staged`.

**Question 7.**

Explain why branches are useful.

**Question 8.**

Describe HEAD and its relationship to the current branch.

**Question 9.**

Distinguish fast-forward merging from three-way merging.

**Question 10.**

Describe the procedure for resolving a merge conflict.

**Question 11.**

Explain the difference between restore, reset, and revert.

**Question 12.**

Explain why reflog is useful for local recovery.

---

# 112. PART C — CONFIGURATION INTERPRETATION

Consider:

```bash
git add app.py
```

Explain which Git area changes.

Consider:

```bash
git commit -m "Add feature"
```

Explain how repository history changes.

Consider:

```bash
git restore --staged app.py
```

Explain what happens to the staged content and the working file.

Consider:

```bash
git reset --soft HEAD~1
```

Explain what happens to the current branch and staging area.

Consider:

```bash
git revert HEAD
```

Explain why this operation differs from reset.

---

# 113. PART D — CASE STUDIES

## Case Study 1 — Accidental Modification

A developer modifies `settings.py` and wants to discard the unstaged change.

Select an appropriate Git command and explain its effect.

## Case Study 2 — Accidental Staging

A developer stages the wrong file.

The developer wants to unstage it without losing the working-directory modification.

Select an appropriate command.

## Case Study 3 — Incorrect Latest Commit Message

A developer notices a typo in the latest local unpublished commit message.

Explain how to correct it.

## Case Study 4 — Shared Bug

A bug was introduced in a commit that other developers have already retrieved.

Explain why revert may be safer than rewriting history.

## Case Study 5 — Merge Conflict

Two branches changed the same configuration line.

Describe the steps required to produce a correct merged result.

## Case Study 6 — Lost Local Commit Reference

A developer uses reset and can no longer see an earlier commit in ordinary history.

Explain how reflog might assist recovery.

---

# 114. PRACTICAL EXAMINATION — 100 MARKS

| Assessment category                       |   Marks |
| ----------------------------------------- | ------: |
| Git and version control theory            |      10 |
| Git configuration and repository creation |      10 |
| Staging and committing                    |      15 |
| Status, diff, log, show, blame            |      15 |
| Branch creation and navigation            |      10 |
| Fast-forward and three-way merging        |      10 |
| Merge conflict resolution                 |      10 |
| Restore, reset, revert, amend, reflog     |      15 |
| Laboratory documentation                  |       5 |
| **Total**                                 | **100** |

**Suggested passing standard:** 80/100.

A successful student must demonstrate correct understanding of staged content, commit history, branches, merging, and safe recovery.

---

# PART XIX — INDEPENDENT ACADEMIC ASSIGNMENT

## 115. ASSIGNMENT TITLE

**Understanding Distributed Version Control and Local Git Repository Management**

Prepare an academic technical report of approximately 1,500–2,000 words covering:

1. The purpose of version control.
2. Centralized and distributed version control.
3. Git and GitHub.
4. Local repository architecture.
5. The `.git` directory.
6. Git configuration.
7. Working directory.
8. Staging area.
9. Commits.
10. Tracked and untracked files.
11. `.gitignore`.
12. Commit inspection.
13. Branch architecture.
14. HEAD.
15. Fast-forward merging.
16. Three-way merging.
17. Merge conflicts.
18. Restoration and unstaging.
19. Reset modes.
20. Revert and reflog.
21. Technical conclusion.

Include actual command output from the practical laboratory.

---

# PART XX — GLOSSARY

## 116. TECHNICAL TERMINOLOGY

| Term            | Definition                                               |
| --------------- | -------------------------------------------------------- |
| Version control | Management of changes over time                          |
| Git             | Distributed version control system                       |
| GitHub          | Git hosting and software collaboration platform          |
| Repository      | Collection of Git-managed content and history            |
| Working tree    | Checked-out working files                                |
| Index           | Staging area                                             |
| Commit          | Recorded repository snapshot with metadata               |
| Commit ID       | Identifier of a commit object                            |
| Tracked file    | File known through index or repository state             |
| Untracked file  | File not tracked in current repository/index             |
| Staged change   | Content selected for the next commit                     |
| HEAD            | Current checked-out repository position                  |
| Branch          | Movable reference to a commit                            |
| Merge           | Integration of development histories                     |
| Fast-forward    | Branch reference moves forward without a merge commit    |
| Three-way merge | Integration using a common ancestor and two histories    |
| Merge conflict  | Change Git cannot automatically combine                  |
| Restore         | Restore file content to a selected source state          |
| Reset           | Move references and optionally update index/working tree |
| Revert          | Create a commit reversing selected changes               |
| Amend           | Replace the latest commit with an updated commit         |
| Reflog          | Local record of reference movements                      |
| Detached HEAD   | HEAD points directly to a commit                         |
| Clone           | Copy an existing Git repository                          |
| .gitignore      | Patterns for ignoring selected untracked files           |

---

# PART XXI — FINAL LECTURE SUMMARY

## 117. CENTRAL CONCEPTS

Git is a distributed version control system.

It records project history and supports independent development.

GitHub is a remote hosting and collaboration platform built around Git repositories.

A Git repository contains project history and metadata.

The working directory contains editable project files.

The staging area selects content for the next commit.

Commits record snapshots of the project.

Branches provide movable references to commits and allow development histories to diverge.

HEAD identifies the current checked-out position.

Fast-forward merges advance a branch reference when histories have not diverged.

Three-way merges combine diverged development histories.

Merge conflicts require deliberate resolution when Git cannot combine selected changes automatically.

Restore manages selected working-tree or staged content.

Reset changes references and may update the index and working tree depending on its mode.

Revert creates a new commit that reverses selected historical changes.

Reflog records local reference movements and may assist recovery.

Together, these concepts establish the foundation of effective Git usage.

---

# 118. THE FIVE PRINCIPLES TO REMEMBER

**Principle 1:** Git is version control; GitHub is a platform that hosts and organizes Git collaboration.

**Principle 2:** Working directory → staging area → commit history is the central everyday Git workflow.

**Principle 3:** A branch is a movable reference to a commit, not a completely separate project copy.

**Principle 4:** Merging combines development histories, and conflicting changes require explicit resolution.

**Principle 5:** Choose recovery commands according to whether work is unstaged, staged, locally committed, or already shared.

---

# 119. REFERENCES

[1] Git Project. _Git Reference Documentation._  
https://git-scm.com/docs

[2] Chacon, Scott, and Ben Straub. _Pro Git, Second Edition._  
https://git-scm.com/book/en/v2

[3] Git Project. _Getting Started._  
https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control

[4] Git Project. _Git Basics — Recording Changes to the Repository._  
https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository

[5] Git Project. _Git Branching — Branches in a Nutshell._  
https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell

[6] Git Project. _Basic Branching and Merging._  
https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging

[7] Git Project. _Reset Demystified._  
https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified

[8] Git Project. _git-restore Documentation._  
https://git-scm.com/docs/git-restore

[9] Git Project. _git-reset Documentation._  
https://git-scm.com/docs/git-reset

[10] Git Project. _git-revert Documentation._  
https://git-scm.com/docs/git-revert

[11] Git Project. _git-reflog Documentation._  
https://git-scm.com/docs/git-reflog

[12] GitHub. _GitHub Documentation._  
https://docs.github.com/

---

# 120. FINAL CONCLUSION

This lecture establishes the theoretical and practical foundations of Git.

The student has examined the purpose of version control, distributed repository architecture, Git configuration, repository initialization, staging, committing, history inspection, branching, merging, and recovery.

The practical laboratory demonstrates how a small software project develops over time.

It begins with an initial snapshot.

Subsequent commits record meaningful source changes.

Feature branches allow independent development.

Fast-forward and three-way merges demonstrate how Git integrates different development histories.

A deliberate conflict illustrates the need for human judgment when overlapping changes cannot be combined automatically.

Recovery exercises demonstrate the differences between restoring files, unstaging changes, amending commits, resetting local history, reverting commits, and examining reflogs.

These skills provide the foundation for collaborative work.

The next major lecture will connect the local repository to GitHub and examine authentication, remote repositories, fetching, pulling, pushing, feature branches, pull requests, reviews, forks, and professional team collaboration.

A developer who understands the concepts presented in this lecture can reliably record, inspect, organize, and recover local project history.

**END OF MAJOR LECTURE 01**

**Next:** Major Lecture 02 — GitHub, Remote Repositories, SSH Authentication, Pull Requests, Code Reviews, Forking, and Team Collaboration.
