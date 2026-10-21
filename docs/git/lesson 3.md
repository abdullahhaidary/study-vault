# GIT & GITHUB: FOUNDATIONS AND PROFESSIONAL DEVELOPMENT

## MAJOR LECTURE 03 — ADVANCED GIT, HISTORY MANAGEMENT, DEBUGGING, SOFTWARE RELEASES, GITHUB ACTIONS, CI/CD SECURITY, AND PROFESSIONAL DEVELOPMENT WORKFLOWS

**Course:** Git and GitHub: Foundations to Professional Workflows  
**Lecture:** 03 of 03 — Final Major Lecture  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, Practical Laboratory, Professional Capstone, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 8–12 Hours  
**Prerequisites:** Major Lectures 01 and 02; basic Docker knowledge is recommended for the final project.

**Principal Topics:**

1. Merge Versus Rebase
2. Interactive Rebase and Commit History Editing
3. Stash and Temporary Work Management
4. Cherry-Pick and Selective Commit Integration
5. Reflog and Advanced Recovery
6. Git Bisect and Historical Debugging
7. Git Worktrees
8. Git Hooks and Repository Attributes
9. Git LFS and Submodules
10. Git Tags, Releases, and Semantic Versioning
11. GitHub Actions and Continuous Integration
12. Continuous Delivery and Deployment
13. Workflow Security, Secrets, Permissions, and OIDC
14. Artifacts, Caching, and Dependency Updates
15. Docker Image Publication and Release Traceability
16. Complete Professional GitHub Development Capstone

---

# PART I — INTRODUCTION

## 1. PURPOSE OF THE FINAL LECTURE

The first major lecture established the foundations of Git.

We learned how repositories work, how commits record project history, how branches represent different development paths, and how Git can recover selected changes.

The second major lecture connected Git to GitHub.

We learned how developers use remote repositories, SSH authentication, pull requests, reviews, forks, issues, and repository rules to collaborate.

The final lecture examines the advanced techniques used by professional software engineering teams.

Consider the following situation.

A team has been developing a Python application for several weeks.

One developer has five unfinished commits on a feature branch.

Another developer has discovered an important security bug.

A third developer needs to identify exactly which historical commit introduced a regression.

Meanwhile, the team is preparing version 1.0.0 of the application.

Before publishing the release, automated tests must succeed.

A Docker image must be constructed.

The release must be traceable to an exact source revision.

These activities require more than basic `git add`, `git commit`, and `git push`.

They require a structured understanding of history manipulation, recovery, automation, and release engineering.

The purpose of this lecture is to develop those abilities.

---

# 2. LEARNING OBJECTIVES

Upon completion, the student should be able to:

1. Explain Git commit ancestry.
2. Distinguish merge and rebase.
3. Perform a safe local rebase.
4. Resolve rebase conflicts.
5. Abort or continue a rebase.
6. Explain rewritten commit identifiers.
7. Perform interactive rebase.
8. Squash related commits.
9. Edit commit messages.
10. Explain fixup commits.
11. Identify risks of rewriting shared history.
12. Use Git stash.
13. Save tracked and untracked work temporarily.
14. Inspect and restore stashes.
15. Apply selected commits using cherry-pick.
16. Handle cherry-pick conflicts.
17. Use reflog for recovery.
18. Understand detached HEAD recovery.
19. Find regressions with Git bisect.
20. Use multiple working directories with worktrees.
21. Explain Git hooks.
22. Configure local hooks.
23. Explain `.gitattributes`.
24. Explain Git LFS.
25. Explain Git submodules.
26. Distinguish annotated and lightweight tags.
27. Explain Semantic Versioning.
28. Create versioned Git releases.
29. Explain GitHub Actions architecture.
30. Configure workflow triggers.
31. Distinguish workflows, jobs, steps, and runners.
32. Use job dependencies.
33. Restrict GitHub Actions permissions.
34. Handle secrets appropriately.
35. Explain the security of pull-request workflows.
36. Understand GitHub environments.
37. Explain OIDC.
38. Use workflow artifacts.
39. Explain pipeline caching.
40. Configure Dependabot.
41. Build Docker images in CI.
42. Run automated application tests.
43. Perform container smoke tests.
44. Publish versioned Docker images.
45. Explain SBOM and provenance attestations.
46. Inspect published image digests.
47. Distinguish release publication from deployment.
48. Complete an end-to-end professional development workflow.

---

# PART II — ADVANCED GIT HISTORY

## 3. UNDERSTANDING COMMIT HISTORY

Git records commits in a directed graph.

Each ordinary commit identifies its parent commit.

A merge commit can have multiple parents.

Consider:

```plaintext
A --- B --- C --- D

```

Here:

- A is an earlier commit.
- B follows A.
- C follows B.
- D follows C.

A branch reference such as `main` can point to D.

When you create another commit on main, the branch reference advances.

Git does not store a branch as a completely separate project folder.

A branch is primarily a movable reference to a commit.

This principle is essential for understanding rebase and advanced recovery.

---

# 4. MERGE VERSUS REBASE

Git provides two important ways to integrate work from branches.

They are:

1. Merge.
2. Rebase.

Both can incorporate development changes.

However, they produce different historical structures.

---

# 5. HOW MERGE WORKS

Suppose two branches diverge.

```plaintext
           A --- B --- C   main
                \
                 D --- E   feature

```

A merge can combine these histories:

```plaintext
           A --- B --- C ------- M   main
                \               /
                 D ----------- E     feature

```

M is a merge commit.

The original feature commits remain part of the history.

The merge records the relationship between the two development paths.

### Example

```bash
git switch main

git merge feature
```

The feature branch is merged into the currently checked-out main branch.

---

# 6. HOW REBASE WORKS

Rebase changes the base of a series of commits by replaying their changes onto another commit.

Original history:

```plaintext
           A --- B --- C   main
                \
                 D --- E   feature

```

After rebasing feature onto main:

```plaintext
           A --- B --- C --- D' --- E'   feature

```

The original changes from D and E have been replayed as new commits D' and E'.

The resulting history is linear.

### Command

```bash
git switch feature

git rebase main
```

### Important Detail

Rebase normally creates new commit identities for replayed commits.

D' is not the same Git commit object as D.

Even if the resulting file content is equivalent, the commit history has been rewritten.

---

# 7. MERGE VERSUS REBASE COMPARISON

| Merge                                        | Rebase                                          |
| -------------------------------------------- | ----------------------------------------------- |
| Combines existing histories                  | Replays commits onto a new base                 |
| Usually preserves existing commit identities | Normally rewrites replayed commit identities    |
| Can create merge commits                     | Can produce a linear history                    |
| Makes branch integration visible             | Can simplify historical presentation            |
| Often suitable for shared history            | Often suitable for local feature-branch cleanup |

Neither method is universally superior.

The correct choice depends on team policy and whether other developers already depend on the existing history.

---

# 8. THE MOST IMPORTANT REBASE RULE

Do not casually rewrite commits that other developers are already using.

If a shared feature branch has been pulled by several teammates, rebasing and force-pushing it may disrupt their work.

For an unpublished personal feature branch, rewriting history is usually less problematic.

**Professional rule: Prefer cleaning private local history before publication. Coordinate any rewrite of shared history.**

---

# 9. PERFORMING A REBASE

Suppose the local main branch has been updated.

```bash
git fetch origin
```

Switch to your feature branch:

```bash
git switch feature/task-count
```

Rebase onto the updated remote-tracking main:

```bash
git rebase origin/main
```

Git attempts to replay the feature commits onto the current `origin/main`.

If all changes apply cleanly, rebase completes.

If the changes conflict, Git pauses.

---

# 10. REBASE CONFLICTS

A rebase conflict can occur when a replayed change cannot be applied cleanly.

The correct general procedure is:

1. Inspect the conflict.
2. Understand both versions.
3. Edit the affected files.
4. Remove conflict markers.
5. Stage the resolved files.
6. Continue the rebase.
7. Run relevant tests.

Commands:

```bash
git status
```

After editing:

```bash
git add FILE
```

Continue:

```bash
git rebase --continue
```

Abort when appropriate:

```bash
git rebase --abort
```

The abort command attempts to return the branch to its pre-rebase state.

---

# 11. REBASE VERSUS MERGE CONFLICT HANDLING

In a merge, Git integrates histories and may create a merge commit.

In a rebase, Git replays individual commits.

Therefore, a long rebase may pause on more than one commit.

You might resolve one conflict, continue, and encounter another.

This behavior is normal.

**Important:** Complete the rebase and run tests before treating the history as correct.

---

# PART III — INTERACTIVE REBASE

## 12. WHAT IS INTERACTIVE REBASE?

Interactive rebase allows developers to edit a sequence of commits.

It can be used to:

- Reorder commits.
- Rename commit messages.
- Combine commits.
- Remove selected commits.
- Pause to edit a commit.
- Produce a clearer local development history.

It is particularly useful before publishing a feature branch.

---

# 13. STARTING INTERACTIVE REBASE

To edit the most recent three commits:

```bash
git rebase -i HEAD~3
```

Git opens an editor with a list resembling:

```text
pick a111111 Add initial feature
pick b222222 Fix small bug
pick c333333 Improve documentation
```

These commit identifiers are illustrative.

The developer changes the instructions and saves the file.

Git then executes the selected history transformation.

---

# 14. INTERACTIVE REBASE COMMANDS

| Instruction | Purpose                                                         |
| ----------- | --------------------------------------------------------------- |
| `pick`      | Keep commit                                                     |
| `reword`    | Change commit message                                           |
| `edit`      | Stop for commit modification                                    |
| `squash`    | Combine with previous commit and edit message                   |
| `fixup`     | Combine with previous commit, normally discarding fixup message |
| `drop`      | Remove commit from rewritten sequence                           |
| `exec`      | Execute a shell command during rebase                           |

These instructions are placed in the interactive rebase todo file.

They are not separate commands that must be typed into the terminal.

---

# 15. SQUASHING COMMITS

Imagine:

```text
Commit A — Add login
Commit B — Fix login typo
Commit C — Fix another login mistake
```

Before publication, you may want one focused commit.

Interactive rebase:

```text
pick a111111 Add login
squash b222222 Fix login typo
squash c333333 Fix another login mistake
```

After completion, the rewritten branch contains one combined commit for those changes.

### Benefit

The resulting history communicates the completed logical feature rather than every intermediate correction.

---

# 16. FIXUP COMMITS

A fixup commit represents a change intended to be combined with another commit.

Create a fixup commit targeting an earlier commit:

```bash
git commit --fixup=COMMIT_ID
```

Then use:

```bash
git rebase -i --autosquash BASE_COMMIT
```

Git can rearrange the fixup commit next to its target during interactive rebase.

### Why This Matters

Fixup commits provide a convenient way to keep local corrections organized until history is cleaned.

---

# 17. REWORDING A COMMIT

Interactive rebase can change an earlier commit message.

Example:

```text
reword a111111 Add login
pick b222222 Add login tests
```

Git pauses to allow a new commit message.

The rewritten commit receives a new identity.

Any later replayed commits may also receive new identities.

---

# 18. REWRITING HISTORY SAFELY

Before performing interactive rebase:

1. Confirm the correct branch.
2. Inspect the log.
3. Ensure the working tree is clean.
4. Identify whether the commits were shared.
5. Create a temporary backup branch if the operation is complex.

Example:

```bash
git branch backup-before-rebase
```

Then inspect:

```bash
git log --oneline --graph --decorate -10
```

After rebasing, compare the result against the original requirements and run tests.

---

# PART IV — STASH

## 19. WHAT IS GIT STASH?

Git stash temporarily stores selected working-directory and index changes.

It is useful when you need to change tasks without immediately creating a commit.

Example situation:

You are halfway through implementing a feature.

An urgent bug needs attention.

You do not want to commit incomplete work merely to switch tasks.

Git stash provides a temporary storage mechanism.

---

# 20. CREATING A STASH

Execute:

```bash
git stash push -m "Unfinished task feature"
```

This saves eligible tracked working changes and staged changes.

To also include untracked files:

```bash
git stash push -u -m "Unfinished feature with new files"
```

The `-u` option includes untracked files.

Ignored files are not included by this option.

---

# 21. INSPECTING STASHES

List entries:

```bash
git stash list
```

Example:

```text
stash@{0}: On feature/tasks: Unfinished task feature
```

Show a summary:

```bash
git stash show stash@{0}
```

Show a patch:

```bash
git stash show -p stash@{0}
```

---

# 22. APPLYING AND POPPING A STASH

Apply without removing the stash entry:

```bash
git stash apply stash@{0}
```

Apply and remove the stash entry after successful application:

```bash
git stash pop
```

### Important Qualification

Stash application can produce conflicts.

A failed pop does not necessarily remove the stash entry.

Inspect status and resolve conflicts before continuing.

---

# 23. REMOVING STASHES

Remove a selected stash:

```bash
git stash drop stash@{0}
```

Remove all stashes:

```bash
git stash clear
```

### Warning

Removing stash entries can make saved work difficult or impossible to recover.

Do not use `stash clear` casually.

### Memory Principle

**Stash = temporary shelf for unfinished changes.**

---

# PART V — CHERRY-PICK

## 24. WHAT IS CHERRY-PICK?

Cherry-pick applies the change introduced by a selected commit onto the current branch.

It is useful when only one specific commit is needed from another development line.

Suppose:

```plaintext
main:

A --- B


feature:

A --- C --- D

```

You want the change from D but do not want to merge all the feature work.

Cherry-pick allows selective integration.

---

# 25. CHERRY-PICK EXAMPLE

First identify the desired commit:

```bash
git log --oneline feature
```

Switch to the target branch:

```bash
git switch main
```

Apply the selected commit:

```bash
git cherry-pick COMMIT_ID
```

Git attempts to apply that commit's change as a new commit on main.

The resulting commit usually has a different identity from the original.

---

# 26. CHERRY-PICK USE CASES

Cherry-pick is useful for:

- Applying a small bug fix to a release branch.
- Transferring a selected improvement.
- Reusing one approved commit without merging unrelated work.
- Backporting selected changes.

### Important Limitation

Cherry-picking the same logical change onto multiple branches can complicate future merging if its relationships are not understood.

---

# 27. CHERRY-PICK CONFLICTS

When cherry-pick cannot apply automatically, Git pauses.

Inspect:

```bash
git status
```

Resolve conflicts.

Stage:

```bash
git add FILE
```

Continue:

```bash
git cherry-pick --continue
```

Abort:

```bash
git cherry-pick --abort
```

### Memory Principle

**Cherry-pick = copy one commit's change onto another branch.**

---

# PART VI — REFLOG AND ADVANCED RECOVERY

## 28. GIT REFLOG

Reflog records local movements of references such as HEAD and branches.

Example:

```bash
git reflog
```

It may contain entries associated with:

- Commits.
- Resets.
- Rebases.
- Branch switches.
- Amended commits.

Reflog is particularly useful when a developer has moved a branch reference and can no longer find a previous commit through ordinary history.

---

# 29. RECOVERING A COMMIT

Suppose a reset moved main away from a valuable commit.

Inspect:

```bash
git reflog
```

Locate the old commit ID.

Create a branch pointing to that commit:

```bash
git branch recovered-feature COMMIT_ID
```

Now the commit is reachable through the new branch.

### Important Limitation

Reflog entries expire and Git may eventually clean up unreachable objects.

Reflog is a recovery tool, not a permanent backup.

---

# 30. DETACHED HEAD RECOVERY

If you checked out a historical commit directly, HEAD may be detached.

Inspect:

```bash
git status
```

If you created valuable commits while detached, preserve the current commit by creating a branch:

```bash
git switch -c recovered-experiment
```

This gives the work a named reference.

### Memory Principle

**A Git commit is easier to preserve when a branch or tag points to it.**

---

# 31. FORCE PUSH AND FORCE-WITH-LEASE

Rebasing a published feature branch changes its commit history.

Updating the corresponding remote branch may require a non-fast-forward push.

Git offers:

```bash
git push --force-with-lease
```

This is generally safer than unconditional `--force` because it checks an expected remote reference state before overwriting it.

However, `--force-with-lease` is not risk-free.

It can still rewrite shared history.

It must not be treated as permission to ignore team policy or protected-branch restrictions.

---

# PART VII — GIT BISECT

## 32. WHAT IS GIT BISECT?

Git bisect helps identify which commit introduced a regression.

It performs a binary search through commit history.

Suppose an application worked correctly ten commits ago.

Now it fails.

You do not know which commit caused the problem.

Without bisect, you might inspect each commit manually.

With bisect, Git selects commits to test, progressively narrowing the range.

---

# 33. BISECT CONCEPT

Imagine eight commits:

```text
A -- B -- C -- D -- E -- F -- G -- H
```

A is known to be good.

H is known to be bad.

Git bisect chooses a commit between them.

You test it and report whether it is good or bad.

Git then selects another candidate.

Eventually, it identifies the first commit associated with the regression in the tested history.

### Memory Principle

**Bisect = binary search for the bad commit.**

---

# 34. MANUAL BISECT

Start:

```bash
git bisect start
```

Mark the current commit bad:

```bash
git bisect bad
```

Mark a known older commit good:

```bash
git bisect good GOOD_COMMIT_ID
```

Git checks out a candidate commit.

Test the application.

Then report:

```bash
git bisect good
```

or:

```bash
git bisect bad
```

Repeat until Git identifies the first bad commit.

Finish:

```bash
git bisect reset
```

This restores the position recorded when bisect began.

---

# 35. AUTOMATED BISECT

If a test command returns:

- Exit code 0 for good behavior.
- Exit code 1 for the observed failure.

Git bisect can execute it automatically.

Example:

```bash
git bisect run python3 -m unittest
```

The command must reliably distinguish good and bad revisions.

### Important Qualification

A failing test caused by missing dependencies or incompatible historical setup may not prove the intended regression.

The test must be valid across the revisions being examined.

---

# PART VIII — GIT WORKTREES

## 36. WHAT IS A GIT WORKTREE?

A Git worktree allows multiple working directories to share the same repository's Git object storage.

This is useful when you want to work on more than one branch without repeatedly switching one working directory.

Example:

```text
project/
    main branch

project-hotfix/
    hotfix branch
```

Both worktrees are associated with the same Git repository.

---

# 37. CREATING A WORKTREE

From a repository:

```bash
git worktree add ../project-hotfix -b hotfix/login main
```

This creates:

- A new branch named `hotfix/login`.
- A separate working directory at `../project-hotfix`.

List worktrees:

```bash
git worktree list
```

When finished, and after preserving any important changes:

```bash
git worktree remove ../project-hotfix
```

### Important Detail

Git normally prevents checking out the same branch simultaneously in multiple linked worktrees.

### Memory Principle

**Worktree = multiple workspaces, shared repository history.**

---

# PART IX — GIT HOOKS

## 38. WHAT ARE GIT HOOKS?

Git hooks are scripts that execute in response to selected Git events.

Examples include:

- Pre-commit.
- Commit message preparation or validation.
- Pre-push.
- Post-commit.

Hooks can automate local checks such as:

- Formatting.
- Linting.
- Unit tests.
- Commit message validation.

---

# 39. PRE-COMMIT HOOK

A pre-commit hook runs before a normal commit is finalized.

Example:

```sh
#!/bin/sh

python3 -m unittest discover -s tests -v
```

If the script exits unsuccessfully, the commit may be blocked.

### Important Security Detail

Ordinary repository-local hooks under `.git/hooks` are not transferred automatically when someone clones a repository.

Developers must deliberately configure local hooks or an approved hook-management tool.

---

# 40. VERSIONED HOOK DIRECTORIES

A repository can store hook scripts in a versioned directory:

```text
.githooks/
```

Then configure:

```bash
git config --local core.hooksPath .githooks
```

This tells Git to use the selected hooks directory for that local repository.

### Limitations

Hooks are not a substitute for CI.

They can be disabled, bypassed, or absent from a contributor's environment.

Required server-side or CI checks should enforce important project policies.

---

# PART X — GIT ATTRIBUTES

## 41. WHAT IS .GITATTRIBUTES?

The `.gitattributes` file controls selected Git behavior for matching paths.

It can describe:

- Text normalization.
- Line-ending handling.
- Binary file treatment.
- Merge and diff behavior.
- Filters used by supporting tools.

Example:

```gitattributes
* text=auto

*.sh text eol=lf

*.png binary

*.jpg binary
```

---

# 42. LINE ENDINGS

Different operating systems commonly use different line-ending conventions.

Linux and macOS typically use LF.

Windows commonly uses CRLF.

Git can normalize line endings when configured appropriately.

For shell scripts:

```gitattributes
*.sh text eol=lf
```

can help maintain expected LF endings in the working tree.

### Memory Principle

**.gitignore controls selected untracked files; .gitattributes controls how Git treats selected paths.**

---

# PART XI — GIT LFS

## 43. WHAT IS GIT LFS?

Git LFS stands for Git Large File Storage.

It is an extension for managing large files through a pointer-based approach.

Examples include:

- Large media assets.
- Design files.
- Some binary datasets.
- Large model assets.

Instead of storing full large-file content through ordinary Git object handling for each tracked LFS version, Git stores pointer files and manages the actual content through LFS storage.

---

# 44. USING GIT LFS

Git LFS must be installed separately where necessary.

Initialize LFS integration:

```bash
git lfs install
```

Track a selected file pattern:

```bash
git lfs track "*.psd"
```

Inspect:

```bash
cat .gitattributes
```

Stage the generated attributes file:

```bash
git add .gitattributes
```

Then add and commit actual LFS-managed files as appropriate.

### Important Qualification

Git LFS does not make storage unlimited.

Hosting providers may impose storage and bandwidth quotas or charges.

---

# PART XII — GIT SUBMODULES

## 45. WHAT IS A SUBMODULE?

A Git submodule allows one Git repository to include a reference to a specific commit from another repository.

Example:

```text
main-project/
├── app.py
└── vendor/
    └── library/
```

The `library` directory may be a separately managed repository included as a submodule.

The parent repository records which submodule commit it expects.

---

# 46. ADDING A SUBMODULE

Example:

```bash
git submodule add REPOSITORY_URL vendor/library
```

This updates the parent repository's submodule configuration and records the selected submodule commit.

Clone with submodules:

```bash
git clone --recurse-submodules REPOSITORY_URL
```

Initialize or update submodules in an existing clone:

```bash
git submodule update --init --recursive
```

---

# 47. SUBMODULE TRADEOFFS

Benefits:

- Separate dependency repository history.
- Explicit submodule revision tracking.
- Support for independently developed components.

Challenges:

- More complex cloning.
- More complicated updates.
- Additional authentication or access requirements.
- Possible confusion about detached HEAD states within submodules.

### Memory Principle

**Submodule = one repository references a commit in another repository.**

---

# PART XIII — GIT TAGS

## 48. WHAT IS A GIT TAG?

A Git tag is a reference commonly used to identify a significant point in repository history.

Typical uses include:

- Software releases.
- Stable versions.
- Important project milestones.

Example:

```text
v1.0.0
```

A version tag helps developers identify which source revision corresponds to a release.

---

# 49. LIGHTWEIGHT TAGS

Create a lightweight tag:

```bash
git tag v1.0.0
```

A lightweight tag is primarily a named reference to an object, usually a commit.

It does not create the additional annotation metadata associated with an annotated tag.

---

# 50. ANNOTATED TAGS

Create an annotated tag:

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
```

An annotated tag creates a tag object that can contain:

- Tag name.
- Target object.
- Tagger information.
- Message.

Annotated tags are generally useful for formal releases.

---

# 51. LISTING AND INSPECTING TAGS

List:

```bash
git tag
```

Inspect:

```bash
git show v1.0.0
```

Push one tag:

```bash
git push origin v1.0.0
```

### Important Distinction

Creating a local tag does not automatically publish it to GitHub.

The tag must be pushed.

---

# 52. SIGNED TAGS

Git supports cryptographically signed tags when suitable signing keys and configuration are available.

Example:

```bash
git tag -s v1.0.0 -m "Signed release 1.0.0"
```

Verification:

```bash
git verify-tag v1.0.0
```

Signature verification depends on suitable trust and key configuration.

A signature provides evidence about the signing identity and integrity of the signed object; it does not prove that the software contains no vulnerabilities.

---

# PART XIV — SEMANTIC VERSIONING

## 53. WHAT IS SEMANTIC VERSIONING?

Semantic Versioning provides a structured naming system for software releases.

The familiar form is:

```text
MAJOR.MINOR.PATCH
```

Example:

```text
2.4.1
```

### MAJOR

Typically increases when incompatible public API changes are introduced.

### MINOR

Typically increases for backward-compatible functionality.

### PATCH

Typically increases for backward-compatible bug fixes.

These meanings depend on a defined public API and proper adoption of the Semantic Versioning specification.

---

# 54. SEMANTIC VERSION EXAMPLES

| Version change | Typical meaning         |
| -------------- | ----------------------- |
| 1.0.0 → 1.0.1  | Compatible bug fix      |
| 1.0.0 → 1.1.0  | Compatible new feature  |
| 1.0.0 → 2.0.0  | Incompatible API change |

Prerelease identifiers are also possible.

Example:

```text
v2.0.0-beta.1
```

The training release workflow later in this lecture uses a simpler restricted format:

```text
vMAJOR.MINOR.PATCH
```

---

# PART XV — GITHUB RELEASES

## 55. GIT TAG VERSUS GITHUB RELEASE

A Git tag is part of Git's reference system.

A GitHub Release is a GitHub-hosted publication record associated with a tag.

A GitHub Release can contain:

- Release title.
- Release notes.
- Version tag.
- Attached assets.
- Release metadata.

### Key Distinction

**Git tag identifies a source revision. GitHub Release communicates and distributes a software release.**

---

# 56. CREATING A GITHUB RELEASE

After creating and pushing an approved version tag:

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
```

```bash
git push origin v1.0.0
```

You can create a GitHub Release through the repository's Releases interface.

Alternatively, with GitHub CLI:

```bash
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Initial stable release."
```

The command requires suitable authentication and permission.

---

# PART XVI — INTRODUCTION TO CI/CD

## 57. WHAT IS CI/CD?

CI/CD refers to engineering practices that automate selected software validation and delivery activities.

The three important concepts are:

1. Continuous Integration.
2. Continuous Delivery.
3. Continuous Deployment.

They are related but not identical.

---

# 58. CONTINUOUS INTEGRATION

Continuous Integration validates source code changes through repeatable automated checks.

Typical activities include:

- Syntax verification.
- Unit tests.
- Integration tests.
- Static analysis.
- Application builds.

### Example

A developer opens a pull request.

GitHub Actions automatically runs the project's Python tests.

If a required test fails, the PR should not be treated as successfully validated.

---

# 59. CONTINUOUS DELIVERY

Continuous Delivery means maintaining software in a condition suitable for controlled release.

A release may still require manual approval.

For example, a pipeline may:

1. Test source code.
2. Build an artifact.
3. Publish a release candidate.
4. Record its identity.

An authorized person then decides when to deploy it.

---

# 60. CONTINUOUS DEPLOYMENT

Continuous Deployment extends the process so that qualifying changes are deployed automatically after the required controls succeed.

This can reduce manual release work.

However, automatic deployment requires suitable safeguards, including environment permissions, rollback procedures, and operational verification.

### Comparison

| Practice              | Primary purpose                       |
| --------------------- | ------------------------------------- |
| CI                    | Validate changes                      |
| Continuous Delivery   | Prepare verified releases             |
| Continuous Deployment | Automatically deploy eligible changes |

---

# PART XVII — GITHUB ACTIONS ARCHITECTURE

## 61. WHAT IS GITHUB ACTIONS?

GitHub Actions is an automation platform integrated with GitHub repositories.

Workflow files are stored in:

```text
.github/workflows/
```

They use YAML syntax.

GitHub Actions can automate:

- Tests.
- Application builds.
- Docker image publication.
- Release preparation.
- Deployment.
- Documentation generation.
- Security checks.

---

# 62. MAIN COMPONENTS

A GitHub Actions workflow contains several important concepts.

### Workflow

A configured automation process.

### Event

The event that triggers the workflow.

### Job

A group of steps executed on a selected runner.

### Step

An individual command or reusable action.

### Action

A reusable automation component.

### Runner

The execution environment that performs the job.

---

# 63. WORKFLOW STRUCTURE

Example:

```yaml
name: Python CI

on:
  push:
    branches: [main]

  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  tests:
    runs-on: ubuntu-latest

    steps:
      - name: Check out source
        uses: actions/checkout@v7

      - name: Set up Python
        uses: actions/setup-python@v7
        with:
          python-version: "3.12"

      - name: Run tests
        run: python -m unittest discover -s tests -v
```

This workflow runs for relevant pushes and pull requests.

It retrieves the source code, configures Python, and executes the test suite.

---

# 64. WORKFLOW EVENTS

Common triggers include:

```yaml
on:
  push:
```

```yaml
on:
  pull_request:
```

```yaml
on:
  workflow_dispatch:
```

```yaml
on:
  schedule:
```

```yaml
on:
  release:
```

Each event has different semantics and security implications.

A workflow should use the event appropriate to its purpose.

---

# 65. JOB DEPENDENCIES

Suppose a release must pass tests before publication.

Example:

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest

    steps:
      - run: echo "Verify release"

  publish:
    needs: verify
    runs-on: ubuntu-latest

    steps:
      - run: echo "Publish release"
```

The `publish` job depends on `verify`.

Under normal GitHub Actions dependency behavior, the publishing job does not proceed when its required verification job fails.

---

# 66. GITHUB-HOSTED AND SELF-HOSTED RUNNERS

### GitHub-Hosted Runner

GitHub provides the execution environment.

### Self-Hosted Runner

An organization manages its own runner.

Self-hosted runners can provide custom software, hardware, or network access.

However, they create additional security and maintenance responsibilities.

Untrusted pull-request code must not be allowed to compromise persistent privileged runner environments.

---

# PART XVIII — CI/CD SECURITY

## 67. THE GITHUB TOKEN

GitHub Actions can provide a token called `GITHUB_TOKEN`.

It allows selected operations against GitHub APIs and repository resources.

The available permissions depend on:

- Repository settings.
- Organization policy.
- Triggering event.
- Workflow configuration.
- Job-level permissions.

A workflow should explicitly request only the permissions it needs.

---

# 68. LEAST-PRIVILEGE PERMISSIONS

Example:

```yaml
permissions:
  contents: read
```

A validation workflow usually does not need general repository write access.

A workflow publishing to GitHub Container Registry may require:

```yaml
permissions:
  contents: read
  packages: write
```

The correct configuration depends on the registry, repository, and workflow.

### Security Principle

**Grant automation only the authority it needs.**

---

# 69. GITHUB ACTIONS SECRETS

GitHub provides mechanisms for configuring secret values.

Examples include:

- Docker Hub token.
- Cloud deployment credentials.
- Third-party API credentials.

Reference:

```yaml
${{ secrets.DOCKERHUB_TOKEN }}
```

Do not write the actual token into workflow YAML.

Secrets are not generally supplied to ordinary untrusted fork pull-request workflows.

That restriction protects privileged resources from untrusted contributions.

---

# 70. PULL REQUEST SECURITY

A pull-request workflow may execute code from an external contributor.

That code should be treated as potentially untrusted.

The `pull_request_target` event requires special care because it can operate with base-repository privileges.

Executing untrusted pull-request source code in a privileged workflow while secrets or powerful tokens are available can create a serious security vulnerability.

The final project uses separate workflows for:

1. Unprivileged code validation.
2. Authorized release publication.

---

# 71. GITHUB ENVIRONMENTS

GitHub environments can support controlled deployment processes.

Depending on the repository and plan, controls may include:

- Required reviewers.
- Environment-specific secrets.
- Deployment restrictions.
- Waiting periods.

An environment can separate automatic CI from production deployment authorization.

### Important Qualification

An environment name alone does not guarantee that approval or protection rules are configured.

---

# 72. OPENID CONNECT

OpenID Connect, or OIDC, supports federated identity.

An appropriately configured GitHub Actions workflow can obtain short-lived credentials for supported external services.

This can reduce reliance on long-lived stored access tokens.

### Important Detail

OIDC requires a trust relationship configured on the destination provider.

Simply adding `id-token: write` to a workflow does not automatically authorize access to a cloud environment.

---

# 73. ACTION PINNING

GitHub Actions may reference reusable actions by version tags:

```yaml
uses: actions/checkout@v7
```

For a higher-assurance environment, the action may be pinned to a reviewed full commit SHA.

This provides more explicit control over the executed action implementation.

Pinned actions still require maintenance and updates when security fixes are released.

---

# PART XIX — WORKFLOW ARTIFACTS AND CACHING

## 74. WHAT IS A WORKFLOW ARTIFACT?

A workflow artifact is a file or collection of files stored as output from a workflow run.

Examples include:

- Test reports.
- Build outputs.
- Documentation.
- Logs.
- Generated packages.

Artifacts help preserve results after an individual job finishes.

They are different from Git commits and container registry images.

---

# 75. ARTIFACT UPLOAD EXAMPLE

An artifact can be uploaded using an appropriate official action.

Example:

```yaml
- name: Upload test report
  uses: actions/upload-artifact@v4
  with:
    name: python-test-report
    path: reports/
    if-no-files-found: error
```

This requires the workflow to have created the `reports/` directory and relevant files beforehand.

Artifacts are subject to the platform's retention and access policies.

---

# 76. WHAT IS WORKFLOW CACHING?

Caching stores reusable computation or dependency data to improve future workflow performance.

Examples:

- Python dependency downloads.
- BuildKit cache layers.
- Package-manager caches.
- Compiler cache data.

Caching may significantly reduce build times.

However, a correct build must be able to succeed without a warm cache.

---

# 77. ARTIFACT VERSUS CACHE

| Artifact                                  | Cache                                           |
| ----------------------------------------- | ----------------------------------------------- |
| Preserves a workflow result               | Accelerates repeated work                       |
| Used for reports or outputs               | Used for reusable build or dependency data      |
| Often consumed or downloaded deliberately | Usually consumed automatically by matching keys |
| Supports traceability                     | Supports performance                            |

A cache should not be treated as a trusted release artifact.

---

# PART XX — DEPENDABOT

## 78. WHAT IS DEPENDABOT?

Dependabot helps identify and propose updates for supported dependencies.

It can create pull requests for dependency version updates.

Supported ecosystems include GitHub Actions and Docker.

A project can configure version updates using:

```text
.github/dependabot.yml
```

---

# 79. DEPENDABOT CONFIGURATION

Example:

```yaml
version: 2

updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Explanation

The first entry checks GitHub Actions dependencies.

The second checks Dockerfile base-image dependencies.

Dependabot can open update pull requests.

The team should still review and test those updates.

---

# PART XXI — PROFESSIONAL RELEASE ARCHITECTURE

## 80. COMPLETE RELEASE PIPELINE

```text
                  GITHUB ISSUE
                       |
                       v
                  FEATURE BRANCH
                       |
                       v
                 SOURCE CHANGES
                       |
                       v
                   UNIT TESTS
                       |
                       v
                 PULL REQUEST
                       |
                       v
                 REVIEW + CI
                       |
                       v
                 MERGE TO MAIN
                       |
                       v
                 RELEASE TAG
                       |
                       v
                 RELEASE TESTS
                       |
                       v
                DOCKER IMAGE BUILD
                       |
                       v
                  DOCKER HUB
                       |
                       v
                PUBLISHED DIGEST
                       |
                       v
              CONTROLLED DEPLOYMENT
```

This architecture connects all three major Git and GitHub lectures.

---

# PART XXII — FINAL PROFESSIONAL PROJECT

## 81. PROJECT TITLE

**Professional GitHub Release Pipeline: Python Task Manager, Automated Testing, Docker Image Construction, Versioned Releases, and Docker Hub Publication**

The project builds on the Python task-manager theme from Major Lecture 02.

It adds:

- An HTTP service.
- Docker image construction.
- Automated tests.
- Container smoke testing.
- GitHub Actions CI.
- Release verification.
- Docker Hub publication.
- Versioned Git tags.
- Image digest recording.
- Dependabot configuration.

The project is intentionally small enough to understand completely.

The goal is to master the development workflow rather than introduce a complex application framework.

---

# 82. PROJECT DIRECTORY STRUCTURE

Create:

```text
github-major-lesson3/
├── task_manager.py
├── server.py
├── Dockerfile
├── .dockerignore
├── .gitignore
├── .gitattributes
├── README.md
├── tests/
│   └── test_app.py
├── scripts/
│   └── smoke.sh
└── .github/
    ├── dependabot.yml
    └── workflows/
        ├── ci.yml
        └── release.yml
```

The following sections provide the main source files.

---

# 83. TASK MANAGER MODULE

Create:

`task_manager.py`

```python
def add_task(tasks, title):

    if not isinstance(title, str):
        raise ValueError("Task title must be a string")

    cleaned = title.strip()

    if not cleaned:
        raise ValueError("Task title cannot be empty")

    if len(cleaned) > 120:
        raise ValueError("Task title is too long")

    return [*tasks, cleaned]


def count_tasks(tasks):
    return len(tasks)


def format_tasks(tasks):

    return "\n".join(
        f"- {task}"
        for task in tasks
    )
```

This module represents the core application logic.

It is separate from the HTTP server so that its behavior can be tested independently.

---

# 84. COMPLETE HTTP APPLICATION

Create:

`server.py`

```python
import json
import os

from http.server import (
    BaseHTTPRequestHandler,
    ThreadingHTTPServer,
)

from urllib.parse import urlsplit

from task_manager import count_tasks


EXAMPLE_TASKS = [
    "Learn Git",
    "Learn GitHub",
]


class Handler(BaseHTTPRequestHandler):

    def respond_json(self, status, data):

        body = json.dumps(
            data,
            sort_keys=True,
        ).encode("utf-8")

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

            self.respond_json(
                200,
                {"status": "ok"},
            )

            return


        if path == "/api/tasks":

            self.respond_json(
                200,
                {
                    "tasks": EXAMPLE_TASKS,
                    "count": count_tasks(EXAMPLE_TASKS),
                },
            )

            return


        if path == "/api/info":

            self.respond_json(
                200,
                {
                    "application": "git3-task-manager",
                    "version": os.getenv(
                        "APP_VERSION",
                        "development",
                    ),
                    "revision": os.getenv(
                        "VCS_REF",
                        "unknown",
                    ),
                },
            )

            return


        self.respond_json(
            404,
            {"error": "Not found"},
        )


def main():

    server = ThreadingHTTPServer(
        ("0.0.0.0", 8000),
        Handler,
    )

    print(
        "GitHub professional capstone is running",
        flush=True,
    )

    server.serve_forever()


if __name__ == "__main__":
    main()
```

The application provides three main endpoints.

| Endpoint     | Purpose                      |
| ------------ | ---------------------------- |
| `/healthz`   | Basic service health         |
| `/api/tasks` | Example task data            |
| `/api/info`  | Release version and revision |

The task list is intentionally static in this exercise.

The purpose is to test a complete source-to-release pipeline, not to implement persistent task storage again.

---

# 85. AUTOMATED TEST SUITE

Create:

`tests/test_app.py`

```python
import json
import threading
import unittest

from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import urlopen

from task_manager import (
    add_task,
    count_tasks,
    format_tasks,
)

from server import Handler


class TaskManagerTests(unittest.TestCase):

    def test_add_task(self):

        result = add_task(
            [],
            "Learn Git",
        )

        self.assertEqual(
            result,
            ["Learn Git"],
        )


    def test_trim_task(self):

        result = add_task(
            [],
            "  Learn GitHub  ",
        )

        self.assertEqual(
            result,
            ["Learn GitHub"],
        )


    def test_empty_title(self):

        with self.assertRaises(ValueError):
            add_task([], "  ")


    def test_non_string_title(self):

        with self.assertRaises(ValueError):
            add_task([], 123)


    def test_count_tasks(self):

        self.assertEqual(
            count_tasks(["A", "B"]),
            2,
        )


    def test_format_tasks(self):

        self.assertEqual(
            format_tasks(["A", "B"]),
            "- A\n- B",
        )


class HttpTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):

        cls.server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            Handler,
        )

        cls.port = cls.server.server_port

        cls.thread = threading.Thread(
            target=cls.server.serve_forever,
            daemon=True,
        )

        cls.thread.start()


    @classmethod
    def tearDownClass(cls):

        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)


    def request(self, path):

        return urlopen(
            f"http://127.0.0.1:{self.port}{path}",
            timeout=3,
        )


    def test_health(self):

        with self.request("/healthz") as response:

            data = json.load(response)

            self.assertEqual(
                response.status,
                200,
            )

            self.assertEqual(
                data["status"],
                "ok",
            )


    def test_task_api(self):

        with self.request("/api/tasks") as response:

            data = json.load(response)

            self.assertEqual(
                data["count"],
                2,
            )

            self.assertEqual(
                len(data["tasks"]),
                2,
            )


    def test_info_api(self):

        with self.request("/api/info") as response:

            data = json.load(response)

            self.assertEqual(
                data["application"],
                "git3-task-manager",
            )


    def test_unknown_path(self):

        with self.assertRaises(HTTPError) as result:

            self.request("/does-not-exist")

        self.assertEqual(
            result.exception.code,
            404,
        )


if __name__ == "__main__":
    unittest.main()
```

The tests verify application functions and HTTP behavior.

The HTTP tests use an automatically selected local port, reducing the possibility of conflicts with an existing application.

---

# 86. MULTI-STAGE DOCKERFILE

Create:

`Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim AS test

WORKDIR /app

COPY task_manager.py server.py ./

COPY tests/ ./tests/

RUN python -m unittest discover -s tests -v


FROM python:3.12-slim AS runtime

ARG APP_VERSION=development

ARG VCS_REF=unknown

ENV APP_VERSION=${APP_VERSION} \
    VCS_REF=${VCS_REF} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY --from=test --chown=10001:10001 \
    /app/task_manager.py /app/server.py ./

USER 10001:10001

EXPOSE 8000

CMD ["python", "-B", "server.py"]
```

### Dockerfile Analysis

The test stage executes the application tests.

The runtime stage copies application source from the completed test stage.

The runtime image executes as a non-root user.

Release metadata is supplied through non-sensitive build arguments.

The final image does not need external Python application packages.

---

# 87. .DOCKERIGNORE

Create:

`.dockerignore`

```text
.git
.github
tests/
__pycache__/
*.pyc
.env
reports/
```

The test suite remains available to the Dockerfile only if it is included in the build context.

Therefore, for this project, remove the `tests/` exclusion from the actual `.dockerignore` file.

The correct final `.dockerignore` is:

```text
.git
.github
__pycache__/
*.pyc
.env
reports/
```

### Important Principle

A file cannot be copied by the Dockerfile if it was excluded from the build context.

---

# 88. .GITIGNORE

Create:

`.gitignore`

```gitignore
__pycache__/
*.pyc
.env
.venv/
reports/
*.log
```

This keeps temporary local files out of repository history.

---

# 89. .GITATTRIBUTES

Create:

`.gitattributes`

```gitattributes
* text=auto

*.sh text eol=lf

*.py text eol=lf

*.png binary
```

This establishes basic text and line-ending behavior.

---

# 90. CONTAINER SMOKE TEST SCRIPT

Create:

`scripts/smoke.sh`

```bash
#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:-git3-api:local}"
PORT="${2:-8400}"

NAME="git3-smoke-$$"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

docker run -d \
    --name "$NAME" \
    -p "127.0.0.1:${PORT}:8000" \
    "$IMAGE"

ready=0

for attempt in {1..20}; do

    if curl --fail --silent \
        "http://127.0.0.1:${PORT}/healthz" \
        >/dev/null; then

        ready=1
        break
    fi

    sleep 1
done

if [ "$ready" -ne 1 ]; then

    docker logs "$NAME"
    exit 1
fi

curl --fail --show-error \
    "http://127.0.0.1:${PORT}/api/tasks"

echo
echo "Container smoke test passed"
```

Make it executable on Unix-like systems:

```bash
chmod +x scripts/smoke.sh
```

The script:

1. Starts the container.
2. Waits for the HTTP health endpoint.
3. Tests the task API.
4. Fails when the application is unavailable.
5. Removes the temporary container.

---

# PART XXIII — CONTINUOUS INTEGRATION WORKFLOW

## 91. CI WORKFLOW

Create:

`.github/workflows/ci.yml`

```yaml
name: GitHub Major Lecture 3 - CI

on:
  pull_request:
    branches:
      - main

  push:
    branches:
      - main

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    name: Test and Build

    runs-on: ubuntu-latest

    timeout-minutes: 20

    steps:
      - name: Check out repository
        uses: actions/checkout@v7

      - name: Set up Python
        uses: actions/setup-python@v7
        with:
          python-version: "3.12"

      - name: Verify Python syntax
        run: |
          python -m compileall -q \
            task_manager.py \
            server.py \
            tests/

      - name: Run automated tests
        run: |
          python -m unittest discover -s tests -v

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Build Docker runtime image
        uses: docker/build-push-action@v7
        with:
          context: .
          target: runtime
          load: true
          push: false
          tags: git3-api:ci

      - name: Verify running container
        run: |
          bash scripts/smoke.sh git3-api:ci 8400
```

---

# 92. CI WORKFLOW ANALYSIS

The workflow runs when:

- A pull request targets main.
- Code is pushed to main.

The job performs:

1. Repository checkout.
2. Python setup.
3. Syntax validation.
4. Unit and HTTP tests.
5. Buildx setup.
6. Docker image construction.
7. Container smoke testing.

The Dockerfile itself also executes the tests as part of the image construction dependency.

### Security Boundary

The workflow does not require a Docker Hub token.

It does not publish an image.

Untrusted pull-request changes should not receive unnecessary registry credentials.

---

# PART XXIV — RELEASE PUBLICATION WORKFLOW

## 93. RELEASE WORKFLOW

Create:

`.github/workflows/release.yml`

```yaml
name: GitHub Major Lecture 3 - Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: read

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  verify:
    name: Verify Release

    runs-on: ubuntu-latest

    timeout-minutes: 20

    steps:
      - name: Check out tagged source
        uses: actions/checkout@v7

      - name: Validate release version
        shell: bash
        run: |
          set -euo pipefail

          if [[ ! "$GITHUB_REF_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Expected a tag such as v1.0.0"
            exit 1
          fi

      - name: Set up Python
        uses: actions/setup-python@v7
        with:
          python-version: "3.12"

      - name: Run release tests
        run: |
          python -m unittest discover -s tests -v

      - name: Build release verification image
        run: |
          docker build -t git3-api:verify .

      - name: Smoke test release
        run: |
          bash scripts/smoke.sh git3-api:verify 8400

  publish:
    name: Publish Docker Image

    needs: verify

    runs-on: ubuntu-latest

    timeout-minutes: 30

    steps:
      - name: Check out tagged source
        uses: actions/checkout@v7

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Log in to Docker Hub
        uses: docker/login-action@v4
        with:
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Generate image tags
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ vars.DOCKERHUB_USERNAME }}/git3-task-manager
          flavor: |
            latest=false
          tags: |
            type=semver,pattern={{version}}
            type=sha,format=long

      - name: Build and publish image
        id: image
        uses: docker/build-push-action@v7
        with:
          context: .
          target: runtime
          platforms: linux/amd64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            APP_VERSION=${{ steps.meta.outputs.version }}
            VCS_REF=${{ github.sha }}
          sbom: true
          provenance: mode=max

      - name: Record image digest
        env:
          DIGEST: ${{ steps.image.outputs.digest }}
          VERSION: ${{ steps.meta.outputs.version }}
        run: |
          echo "## Published Docker Release" >> "$GITHUB_STEP_SUMMARY"
          echo "" >> "$GITHUB_STEP_SUMMARY"
          echo "Version: $VERSION" >> "$GITHUB_STEP_SUMMARY"
          echo "Digest: $DIGEST" >> "$GITHUB_STEP_SUMMARY"
```

---

# 94. RELEASE WORKFLOW ANALYSIS

The workflow is triggered by versioned Git tags.

The verification job:

- Validates the tag format.
- Executes Python tests.
- Builds a Docker image.
- Runs the image in a container.
- Performs an HTTP smoke test.

The publication job runs only after verification succeeds under normal dependency behavior.

It authenticates to Docker Hub.

It creates image references based on the release version and source commit.

It publishes the image.

It requests SBOM and provenance metadata.

It records the published digest.

### Important Qualification

This example builds one image for verification and another image for publication.

It provides a clear educational quality gate, but it does not guarantee byte-identical artifacts between the two jobs.

A stricter release process can build once, validate the exact resulting artifact, and promote that artifact without rebuilding.

---

# 95. DOCKER HUB REQUIREMENTS

Create a Docker Hub repository named:

```text
git3-task-manager
```

Configure the following GitHub repository variable:

```text
DOCKERHUB_USERNAME
```

Configure the following GitHub repository secret:

```text
DOCKERHUB_TOKEN
```

The token must have the appropriate publication permissions.

Never include its value in source code or workflow YAML.

---

# 96. IMAGE TAGS

A Git tag:

```text
v1.0.0
```

produces a version-oriented image tag:

```text
1.0.0
```

The workflow also creates a source-revision-oriented image tag.

The exact image digest is recorded after publication.

Example image reference:

```text
YOUR_DOCKER_ID/git3-task-manager:1.0.0
```

Use your actual authorized Docker Hub namespace.

---

# 97. SBOM AND PROVENANCE

The release workflow requests:

```yaml
sbom: true
provenance: mode=max
```

### SBOM

Describes software components associated with the image.

### Provenance

Describes relevant information about the image build.

### Security Warning

Build arguments must not contain sensitive credentials.

Build provenance may expose build argument values.

Attestations provide useful supply-chain information, but they do not guarantee that the software is secure.

---

# 98. DEPLOYMENT BY IMAGE DIGEST

After publication, inspect:

```bash
docker buildx imagetools inspect \
  YOUR_DOCKER_ID/git3-task-manager:1.0.0
```

An exact published artifact can be selected using:

```text
YOUR_DOCKER_ID/git3-task-manager@sha256:ACTUAL_DIGEST
```

Replace the placeholder with the actual published digest.

### Benefit

Digest references identify specific registry content.

### Important Distinction

Publishing the image does not automatically deploy it.

A separate authorized deployment operation must select and run the artifact.

---

# PART XXV — FINAL PRACTICAL LABORATORY

## 99. LABORATORY OBJECTIVE

The laboratory consists of 30 experiments.

Its purpose is to demonstrate advanced Git history management, debugging, and a complete GitHub release workflow.

Perform the history-rewriting exercises only in a dedicated training repository.

Do not practice destructive Git commands on valuable team branches.

---

# 100. EXPERIMENT 1 — VERIFY THE ENVIRONMENT

Execute:

```bash
git --version
```

```bash
python3 --version
```

```bash
docker version
```

```bash
docker buildx version
```

**Objective:** Verify the required development environment.

---

# 101. EXPERIMENT 2 — CREATE THE CAPSTONE REPOSITORY

Create:

```bash
mkdir -p github-major-lesson3/tests
mkdir -p github-major-lesson3/scripts
mkdir -p github-major-lesson3/.github/workflows
```

Enter:

```bash
cd github-major-lesson3
```

Create the project files described earlier.

**Objective:** Establish the final application and automation project.

---

# 102. EXPERIMENT 3 — RUN TESTS LOCALLY

Execute:

```bash
python3 -m unittest discover -s tests -v
```

**Objective:** Verify the application logic and HTTP endpoints.

**Expected result:** All included tests pass.

---

# 103. EXPERIMENT 4 — BUILD THE DOCKER IMAGE

Execute:

```bash
docker build -t git3-api:local .
```

**Objective:** Build the tested runtime image.

**Expected result:** The Dockerfile test stage succeeds and the image is constructed.

---

# 104. EXPERIMENT 5 — SMOKE TEST THE CONTAINER

Execute:

```bash
bash scripts/smoke.sh git3-api:local 8400
```

**Objective:** Verify that the application starts and responds over HTTP.

**Expected result:** The script reports a successful smoke test.

---

# 105. EXPERIMENT 6 — INITIALIZE GIT

Execute:

```bash
git init -b main
```

Configure an appropriate local author identity if needed.

Stage:

```bash
git add .
```

Commit:

```bash
git commit -m "Initialize professional GitHub capstone"
```

**Objective:** Establish the initial source history.

---

# 106. EXPERIMENT 7 — CREATE A REBASE DEMONSTRATION BRANCH

Execute:

```bash
git switch -c feature/rebase-demo
```

Create:

```bash
printf 'Advanced Git\n' > ADVANCED.md
```

Commit:

```bash
git add ADVANCED.md
git commit -m "Add advanced Git notes"
```

Append:

```bash
printf 'Rebase keeps feature history organized.\n' >> ADVANCED.md
```

Commit:

```bash
git add ADVANCED.md
git commit -m "Explain rebasing"
```

**Objective:** Create two feature commits suitable for rebasing.

---

# 107. EXPERIMENT 8 — DIVERGE MAIN

Switch to main:

```bash
git switch main
```

Add:

```bash
printf 'Project maintenance guide\n' > MAINTENANCE.md
```

Commit:

```bash
git add MAINTENANCE.md
git commit -m "Add maintenance guide"
```

**Objective:** Create a different development path.

---

# 108. EXPERIMENT 9 — REBASE THE FEATURE

Switch:

```bash
git switch feature/rebase-demo
```

Rebase:

```bash
git rebase main
```

Inspect:

```bash
git log --oneline --graph --decorate --all
```

**Objective:** Observe the replayed feature commits.

**Expected result:** The feature commits appear after the latest main commit in a linear history.

---

# 109. EXPERIMENT 10 — INTERACTIVE REBASE

Create a backup reference:

```bash
git branch backup-rebase-demo
```

Start:

```bash
git rebase -i HEAD~2
```

In the editor, keep the first commit as `pick` and change the second to `squash`.

Save the file.

Choose a meaningful combined commit message.

Inspect:

```bash
git log --oneline --graph --decorate --all
```

**Objective:** Combine two related local feature commits.

---

# 110. EXPERIMENT 11 — INTEGRATE THE CLEAN FEATURE

Switch to main:

```bash
git switch main
```

Merge:

```bash
git merge --ff-only feature/rebase-demo
```

Verify:

```bash
git log --oneline
```

**Objective:** Advance main to the cleaned feature history.

---

# 111. EXPERIMENT 12 — PRACTICE STASH

Make an unfinished change:

```bash
printf '\nUnfinished note\n' >> README.md
```

If README.md does not exist yet, create it first:

```bash
printf '# Professional GitHub Capstone\n' > README.md
```

Now stash:

```bash
git stash push -u -m "Temporary documentation work"
```

Inspect:

```bash
git stash list
```

Restore:

```bash
git stash pop
```

**Objective:** Temporarily preserve unfinished changes.

Before the next experiment, either commit the intended content or discard it deliberately so the working tree is clean.

---

# 112. EXPERIMENT 13 — CHERRY-PICK A FIX

Create a branch:

```bash
git switch -c hotfix/example
```

Create:

```bash
printf 'Example bug fix\n' > BUGFIX.md
```

Commit:

```bash
git add BUGFIX.md
git commit -m "Add example bug fix"
```

Record the commit:

```bash
git log -1 --oneline
```

Switch to main:

```bash
git switch main
```

Cherry-pick using the actual recorded commit ID:

```bash
git cherry-pick COMMIT_ID
```

**Objective:** Apply one selected change without merging an entire branch.

---

# 113. EXPERIMENT 14 — INSPECT REFLOG

Execute:

```bash
git reflog
```

Locate entries for:

- Branch switches.
- Rebase.
- Cherry-pick.
- Commits.

**Objective:** Understand local reference history.

---

# 114. EXPERIMENT 15 — CREATE A WORKTREE

Execute:

```bash
git worktree add ../git3-hotfix-worktree -b worktree/hotfix main
```

Inspect:

```bash
git worktree list
```

Enter the new directory:

```bash
cd ../git3-hotfix-worktree
```

Inspect the branch:

```bash
git branch --show-current
```

Return to the original directory:

```bash
cd ../github-major-lesson3
```

Remove the worktree when no uncommitted changes need preserving:

```bash
git worktree remove ../git3-hotfix-worktree
```

**Objective:** Demonstrate multiple working directories associated with the same repository.

---

# 115. EXPERIMENT 16 — SET UP A LOCAL HOOK

Create:

```bash
mkdir -p .githooks
```

Create `.githooks/pre-commit`:

```sh
#!/bin/sh

python3 -m unittest discover -s tests -v
```

Make it executable:

```bash
chmod +x .githooks/pre-commit
```

Configure:

```bash
git config --local core.hooksPath .githooks
```

**Objective:** Run tests automatically before normal local commits.

The hook is local policy and does not replace GitHub Actions.

---

# 116. EXPERIMENT 17 — INSPECT GIT ATTRIBUTES

Execute:

```bash
cat .gitattributes
```

Then inspect Git's attributes for a selected shell script:

```bash
git check-attr -a -- scripts/smoke.sh
```

**Objective:** Understand repository-controlled file behavior.

---

# 117. EXPERIMENT 18 — EXPLORE GIT LFS

If Git LFS is installed:

```bash
git lfs version
```

```bash
git lfs install
```

Inspect:

```bash
git lfs help track
```

**Objective:** Understand how large files can be tracked through an extension rather than ordinary Git object storage.

Do not add large test files unnecessarily.

---

# 118. EXPERIMENT 19 — EXPLORE SUBMODULES

Inspect:

```bash
git help submodule
```

Study:

```bash
git submodule update --init --recursive
```

**Objective:** Understand how one repository can reference a specific commit from another.

For hands-on submodule practice, use a repository you own or a trusted project with appropriate permissions.

---

# 119. EXPERIMENT 20 — CREATE A GITHUB REPOSITORY

Create a GitHub repository named:

```text
github-major-lesson3
```

Use appropriate visibility.

For the exact push commands below, create it without conflicting starter commits.

Connect:

```bash
git remote add origin \
  git@github.com:YOUR_USERNAME/github-major-lesson3.git
```

Replace the placeholder.

**Objective:** Prepare the remote repository.

---

# 120. EXPERIMENT 21 — PUBLISH MAIN

Ensure your working tree is clean and intended project files are committed.

Execute:

```bash
git switch main
```

```bash
git push -u origin main
```

**Objective:** Publish the initial application and workflow configuration.

---

# 121. EXPERIMENT 22 — CREATE A FEATURE PULL REQUEST

Create a new branch:

```bash
git switch -c feature/readme-improvement
```

Modify the README with a meaningful improvement.

Commit:

```bash
git add README.md
git commit -m "Improve installation documentation"
```

Push:

```bash
git push -u origin feature/readme-improvement
```

Open a pull request on GitHub.

**Objective:** Practice the professional collaboration workflow.

---

# 122. EXPERIMENT 23 — VERIFY AUTOMATED CI

Open the pull request.

Inspect the workflow:

```text
GitHub Major Lecture 3 - CI
```

Verify:

1. Python syntax.
2. Automated tests.
3. Docker image build.
4. Container smoke test.

**Objective:** Confirm automated validation of proposed changes.

---

# 123. EXPERIMENT 24 — MERGE THE APPROVED FEATURE

Review the PR changes.

When all configured requirements are satisfied, merge the PR.

Update local main:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

**Objective:** Complete the reviewed integration.

---

# 124. EXPERIMENT 25 — CREATE A RELEASE TAG

Confirm that the intended release commit has passed the relevant validation.

Create:

```bash
git tag -a v1.0.0 -m "Initial professional GitHub release"
```

Inspect:

```bash
git show v1.0.0
```

Push:

```bash
git push origin v1.0.0
```

**Objective:** Trigger the release publication workflow.

---

# 125. EXPERIMENT 26 — CONFIGURE DOCKER HUB

Configure:

```text
DOCKERHUB_USERNAME
```

as a GitHub Actions variable.

Configure:

```text
DOCKERHUB_TOKEN
```

as a GitHub Actions secret.

Create the authorized Docker Hub repository:

```text
git3-task-manager
```

**Objective:** Prepare authenticated registry publication.

Do not place the token directly in YAML.

---

# 126. EXPERIMENT 27 — VERIFY RELEASE PUBLICATION

If the tag was pushed before registry credentials were configured, initiate an appropriate new release run only after correcting configuration; avoid casually deleting or moving a published tag.

Inspect the release workflow.

Verify:

- Tag validation.
- Python tests.
- Docker build.
- Container smoke test.
- Registry authentication.
- Image publication.
- Published digest.

**Objective:** Demonstrate controlled release engineering.

---

# 127. EXPERIMENT 28 — RETRIEVE THE RELEASE

Execute with the actual Docker Hub namespace:

```bash
docker pull YOUR_DOCKER_ID/git3-task-manager:1.0.0
```

Inspect:

```bash
docker buildx imagetools inspect \
  YOUR_DOCKER_ID/git3-task-manager:1.0.0
```

**Objective:** Retrieve and inspect the published artifact.

---

# 128. EXPERIMENT 29 — VERIFY THE PUBLISHED IMAGE

Run:

```bash
bash scripts/smoke.sh \
  YOUR_DOCKER_ID/git3-task-manager:1.0.0 \
  8400
```

**Objective:** Verify that the published image starts and responds correctly.

The image must be available locally or retrievable from the configured registry.

---

# 129. EXPERIMENT 30 — FINAL RELEASE TRACEABILITY

Record:

1. Git repository URL.
2. Approved pull request.
3. Source commit SHA.
4. Release tag.
5. CI workflow result.
6. Release workflow result.
7. Docker image tag.
8. Docker image digest.
9. Runtime smoke-test result.

**Objective:** Establish a complete chain connecting source code to a released application artifact.

---

# PART XXVI — COMMON ADVANCED GIT MISTAKES

## 130. REBASING SHARED HISTORY

**Mistake:** Rebasing published commits without considering teammates.

**Problem:** Commit identities change and collaborators may have based work on the original history.

**Correct approach:** Use rebase primarily for suitable private development history or coordinate the rewrite.

---

# 131. CONFUSING REBASE AND MERGE

**Mistake:** Assuming rebase and merge produce identical histories.

**Correct understanding:**

Merge combines histories.

Rebase replays changes onto a different base.

Both can result in equivalent working-tree content while producing different commit graphs.

---

# 132. USING STASH AS LONG-TERM STORAGE

**Mistake:** Keeping important changes in unnamed stashes for months.

**Correct approach:** Use a meaningful commit or branch for valuable long-term work.

Stash is best treated as a short-term convenience.

---

# 133. USING CHERRY-PICK WITHOUT UNDERSTANDING THE TARGET

**Mistake:** Cherry-picking a commit onto the wrong branch.

**Correct approach:**

Check the current branch:

```bash
git branch --show-current
```

Inspect the source commit.

Then cherry-pick deliberately.

---

# 134. FORGETTING TO RESET BISECT

**Mistake:** Leaving the repository at a bisect-selected historical commit.

**Correct approach:**

```bash
git bisect reset
```

when the investigation is complete.

---

# 135. PUTTING SECRETS IN GITHUB ACTIONS YAML

**Mistake:** Hardcoding tokens into workflow files.

**Correct approach:** Use appropriate GitHub secrets, provider identity federation, and minimal permissions.

---

# 136. USING PRIVILEGED TOKENS IN UNTRUSTED PULL REQUEST TESTS

**Mistake:** Executing untrusted code with powerful publishing or deployment credentials.

**Correct approach:** Separate unprivileged validation from authorized release and deployment actions.

---

# 137. ASSUMING A SUCCESSFUL BUILD IS A DEPLOYMENT

**Mistake:** Thinking that `docker push` updates an already running production application.

**Correct approach:** Treat artifact publication and deployment as separate operations.

---

# PART XXVII — FINAL TECHNICAL REFERENCE

## 138. ADVANCED GIT COMMANDS

| Command                   | Purpose                                     |
| ------------------------- | ------------------------------------------- |
| `git rebase main`         | Replay current branch commits onto main     |
| `git rebase -i HEAD~3`    | Edit recent commit history                  |
| `git rebase --continue`   | Continue paused rebase                      |
| `git rebase --abort`      | Abort rebase                                |
| `git commit --fixup=ID`   | Create fixup commit                         |
| `git stash push -u`       | Temporarily save tracked and untracked work |
| `git stash list`          | List stashes                                |
| `git stash apply`         | Apply stash without removing it             |
| `git stash pop`           | Apply and normally remove stash             |
| `git cherry-pick ID`      | Apply selected commit change                |
| `git cherry-pick --abort` | Abort cherry-pick                           |
| `git reflog`              | Inspect local reference history             |
| `git bisect start`        | Begin regression search                     |
| `git bisect good`         | Mark tested commit good                     |
| `git bisect bad`          | Mark tested commit bad                      |
| `git bisect run`          | Execute automated regression test           |
| `git bisect reset`        | Finish bisect                               |
| `git worktree add`        | Add linked working directory                |
| `git worktree list`       | List worktrees                              |
| `git tag -a`              | Create annotated tag                        |
| `git verify-tag`          | Verify signed tag                           |
| `git lfs track`           | Configure LFS tracking                      |
| `git submodule update`    | Initialize/update submodules                |

---

# PART XXVIII — FORMAL FINAL EXAMINATION

## 139. PART A — DEFINITIONS

Define precisely:

1. Rebase.
2. Merge.
3. Interactive rebase.
4. Squash.
5. Fixup.
6. Cherry-pick.
7. Git stash.
8. Reflog.
9. Detached HEAD.
10. Git bisect.
11. Worktree.
12. Git hook.
13. `.gitattributes`.
14. Git LFS.
15. Git submodule.
16. Lightweight tag.
17. Annotated tag.
18. Signed tag.
19. Semantic Versioning.
20. GitHub Release.
21. Continuous Integration.
22. Continuous Delivery.
23. Continuous Deployment.
24. GitHub Actions workflow.
25. Runner.
26. Job.
27. Step.
28. Quality gate.
29. Workflow artifact.
30. Build cache.
31. GitHub secret.
32. GitHub environment.
33. OIDC.
34. Dependabot.
35. SBOM.
36. Build provenance.
37. Image digest.

---

# 140. PART B — SHORT-ANSWER QUESTIONS

**Question 1.** Explain the difference between merge and rebase.

**Question 2.** Why does rebase normally create new commit identities?

**Question 3.** Why should developers avoid casually rebasing shared history?

**Question 4.** Explain the purpose of interactive rebase.

**Question 5.** Distinguish squash from fixup.

**Question 6.** Explain when Git stash is useful.

**Question 7.** Explain the purpose of cherry-pick.

**Question 8.** Describe how reflog can help recover a lost commit reference.

**Question 9.** Explain how Git bisect identifies a regression.

**Question 10.** Describe the purpose of Git worktrees.

**Question 11.** Explain the limitations of local Git hooks.

**Question 12.** Distinguish `.gitignore` from `.gitattributes`.

**Question 13.** Explain the role of Git LFS.

**Question 14.** Explain how a submodule references another repository.

**Question 15.** Distinguish lightweight and annotated tags.

**Question 16.** Explain the purpose of Semantic Versioning.

**Question 17.** Distinguish Git tags from GitHub Releases.

**Question 18.** Explain the differences between CI, Continuous Delivery, and Continuous Deployment.

**Question 19.** Describe a GitHub Actions quality gate.

**Question 20.** Explain why untrusted pull-request workflows should not receive release credentials.

**Question 21.** Distinguish workflow artifacts from caches.

**Question 22.** Explain how Dependabot assists maintenance.

**Question 23.** Explain the role of Docker Metadata Action.

**Question 24.** Why should a release record include the published image digest?

**Question 25.** Why does successful publication not guarantee successful production deployment?

---

# 141. PART C — ANALYTICAL CASE STUDIES

### Case Study 1 — Shared History Rewrite

A developer rebases a feature branch already used by three teammates.

Explain the risks and propose a coordination strategy.

### Case Study 2 — Incomplete Work

A developer must pause an incomplete change to investigate an urgent bug.

Explain how stash or a temporary commit could help.

### Case Study 3 — Security Fix Backport

A security fix exists in one branch but must also be applied to an older release branch.

Explain how cherry-pick could be used and what validation is necessary.

### Case Study 4 — Regression Investigation

The latest application version fails, but a much older version works.

Describe a systematic bisect investigation.

### Case Study 5 — Workflow Secret Exposure

A contributor modifies a PR test script to print environment variables.

Explain why privileged credentials must not be exposed to untrusted PR execution.

### Case Study 6 — Failed Release Publication

The release verification job passes, but Docker Hub rejects publication.

Explain how to distinguish source quality from registry authorization.

### Case Study 7 — Wrong Production Artifact

A deployed environment contains a different image from the one intended.

Explain how Git commit SHAs, image tags, and digests help investigate the problem.

---

# PART XXIX — FINAL PRACTICAL EXAMINATION

## 142. ASSESSMENT RUBRIC

**Total: 100 Marks**

| Assessment category                          |   Marks |
| -------------------------------------------- | ------: |
| Advanced Git history and rebase              |      15 |
| Stash, cherry-pick, and recovery             |      10 |
| Bisect and worktrees                         |      10 |
| Hooks, attributes, LFS, and submodules       |      10 |
| Tags, releases, and Semantic Versioning      |      10 |
| GitHub Actions Continuous Integration        |      15 |
| CI/CD security and dependency management     |      10 |
| Docker image release publication             |      10 |
| Final project verification and documentation |      10 |
| **Total**                                    | **100** |

**Suggested passing standard:** 80/100.

The student should demonstrate the ability to explain the tools, execute the relevant operations, identify their risks, and integrate them into a coherent professional workflow.

---

# PART XXX — FINAL ACADEMIC ASSIGNMENT

## 143. ASSIGNMENT TITLE

**Advanced Distributed Version Control and Automated Software Release Engineering Using Git, GitHub Actions, and Docker**

Prepare a formal technical report of approximately 2,000–3,000 words.

The report must cover:

1. Advanced commit graph management.
2. Merge versus rebase.
3. Interactive rebase.
4. Squash and fixup.
5. Cherry-pick.
6. Stash.
7. Reflog recovery.
8. Git bisect.
9. Git worktrees.
10. Git hooks.
11. `.gitattributes`.
12. Git LFS.
13. Git submodules.
14. Git tags.
15. Semantic Versioning.
16. GitHub Releases.
17. GitHub Actions architecture.
18. Workflow triggers.
19. Jobs and dependencies.
20. Automated testing.
21. Docker image construction.
22. Container smoke tests.
23. Workflow permissions.
24. Secrets and OIDC.
25. Artifacts and caching.
26. Dependabot.
27. Registry publication.
28. Image digests.
29. Release verification.
30. Deployment limitations and future improvements.

The report must include:

- A Git commit graph.
- A merge-versus-rebase comparison diagram.
- A bisect investigation example.
- A CI/CD architecture diagram.
- A complete workflow configuration.
- A published release reference.
- The actual image digest.
- A technical security assessment.

---

# PART XXXI — PROFESSIONAL COMPETENCY CHECKLIST

## 144. ADVANCED GIT

- [ ] I understand Git commit ancestry.
- [ ] I can explain merge versus rebase.
- [ ] I can rebase an unpublished feature branch.
- [ ] I can resolve rebase conflicts.
- [ ] I can use interactive rebase.
- [ ] I understand squash and fixup.
- [ ] I understand the risks of shared-history rewriting.
- [ ] I can stash unfinished changes.
- [ ] I can inspect and restore a stash.
- [ ] I can cherry-pick a commit.
- [ ] I can use reflog for recovery.
- [ ] I can perform a bisect investigation.
- [ ] I can create and remove worktrees.

## 145. PROFESSIONAL REPOSITORY TOOLS

- [ ] I understand Git hooks.
- [ ] I can configure a local pre-commit hook.
- [ ] I understand `.gitattributes`.
- [ ] I know when Git LFS may be useful.
- [ ] I understand submodule references.
- [ ] I can create annotated tags.
- [ ] I understand signed tags.
- [ ] I understand Semantic Versioning.
- [ ] I can create a GitHub Release.

## 146. CI/CD

- [ ] I can explain CI.
- [ ] I can explain Continuous Delivery.
- [ ] I can explain Continuous Deployment.
- [ ] I can create a GitHub Actions workflow.
- [ ] I understand runners and jobs.
- [ ] I can define job dependencies.
- [ ] I can execute automated tests.
- [ ] I can build a Docker image in CI.
- [ ] I can run a container smoke test.
- [ ] I understand workflow artifacts.
- [ ] I understand caching.
- [ ] I can configure Dependabot.
- [ ] I understand workflow permissions.
- [ ] I know how to protect secrets.
- [ ] I understand OIDC conceptually.

## 147. RELEASE ENGINEERING

- [ ] I can create a release tag.
- [ ] I can trigger a release workflow.
- [ ] I can configure Docker Hub authentication.
- [ ] I can generate image tags.
- [ ] I can publish a Docker image.
- [ ] I can record the image digest.
- [ ] I understand SBOMs.
- [ ] I understand provenance.
- [ ] I can distinguish publication from deployment.
- [ ] I understand why artifact identity matters.
- [ ] I completed the final project.

---

# PART XXXII — COMPLETE THREE-LECTURE COURSE REVIEW

## 148. MAJOR LECTURE 01

**Git Fundamentals and Local Version Control**

Covered:

- Version control.
- Git architecture.
- Local repositories.
- Working directory.
- Staging area.
- Commits.
- History inspection.
- Branches.
- Merge conflicts.
- Restore.
- Reset.
- Revert.
- Reflog.

**Central principle:** Understand and control local source history.

---

# 149. MAJOR LECTURE 02

**GitHub and Team Collaboration**

Covered:

- Remote repositories.
- GitHub authentication.
- SSH keys.
- HTTPS access.
- Fetch.
- Pull.
- Push.
- Remote tracking.
- Feature branches.
- Pull requests.
- Code reviews.
- Merge strategies.
- Protected branches.
- Rulesets.
- CODEOWNERS.
- Forks.
- Issues.
- Projects.

**Central principle:** Share and integrate source history through controlled collaboration.

---

# 150. MAJOR LECTURE 03

**Advanced Git and Professional Automation**

Covered:

- Rebase.
- Interactive rebase.
- Squash.
- Fixup.
- Stash.
- Cherry-pick.
- Reflog.
- Bisect.
- Worktrees.
- Hooks.
- Attributes.
- LFS.
- Submodules.
- Tags.
- Releases.
- CI/CD.
- GitHub Actions.
- Secrets.
- Dependency management.
- Docker image publication.

**Central principle:** Maintain reliable development history and automate software release engineering.

---

# PART XXXIII — FIVE GOLDEN PRINCIPLES

## 151. THE MOST IMPORTANT LESSONS

**Principle 1 — Understand history before changing it.**

Git history is a graph of commits, and operations such as rebase, reset, cherry-pick, and merge modify the relationship between changes and references.

**Principle 2 — Rewrite private history carefully and protect shared history.**

A clean commit history is useful, but collaboration becomes difficult when published history changes unexpectedly.

**Principle 3 — Debug through evidence.**

Reflog helps investigate reference movement.

Bisect helps identify regressions.

Tests help distinguish intended behavior from defects.

**Principle 4 — Separate validation from privileged publication.**

Untrusted code should not receive unnecessary registry or deployment credentials.

**Principle 5 — Make releases traceable.**

A professional release should connect the source revision, validation result, release tag, published artifact, and image digest.

---

# PART XXXIV — REFERENCES

## Git Fundamentals and Advanced History

[1] Git Project. _Git Reference Documentation._  
https://git-scm.com/docs

[2] Chacon, Scott, and Ben Straub. _Pro Git, Second Edition._  
https://git-scm.com/book/en/v2

[3] Git Project. _Rebasing._  
https://git-scm.com/book/en/v2/Git-Branching-Rebasing

[4] Git Project. _Rewriting History._  
https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History

[5] Git Project. _git-stash._  
https://git-scm.com/docs/git-stash

[6] Git Project. _git-cherry-pick._  
https://git-scm.com/docs/git-cherry-pick

[7] Git Project. _git-reflog._  
https://git-scm.com/docs/git-reflog

[8] Git Project. _git-bisect._  
https://git-scm.com/docs/git-bisect

[9] Git Project. _git-worktree._  
https://git-scm.com/docs/git-worktree

[10] Git Project. _gitattributes._  
https://git-scm.com/docs/gitattributes

[11] Git Project. _git-submodule._  
https://git-scm.com/docs/git-submodule

## Git LFS and Releases

[12] Git LFS Project. _Official Website._  
https://git-lfs.com/

[13] Semantic Versioning. _Specification._  
https://semver.org/

[14] GitHub. _Managing Releases in a Repository._  
https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

## GitHub Actions and Security

[15] GitHub. _GitHub Actions Documentation._  
https://docs.github.com/en/actions

[16] GitHub. _Workflow Syntax._  
https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax

[17] GitHub. _Secure Use of GitHub Actions._  
https://docs.github.com/en/actions/reference/security/secure-use

[18] GitHub. _Using Secrets in GitHub Actions._  
https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets

[19] GitHub. _Dependabot Version Updates._  
https://docs.github.com/en/code-security/concepts/supply-chain-security/dependabot-version-updates

[20] GitHub CLI. _Official Manual._  
https://cli.github.com/manual/

## Docker Release Automation

[21] Docker Inc. _GitHub Actions for Docker Builds._  
https://docs.docker.com/build/ci/github-actions/

[22] Docker Inc. _SBOM and Provenance with GitHub Actions._  
https://docs.docker.com/build/ci/github-actions/attestations/

[23] Docker. _Build Push Action._  
https://github.com/docker/build-push-action

[24] Docker. _Metadata Action._  
https://github.com/docker/metadata-action

[25] Docker. _Login Action._  
https://github.com/docker/login-action

[26] Docker. _Setup Buildx Action._  
https://github.com/docker/setup-buildx-action

---

# PART XXXV — FINAL COURSE CONCLUSION

## 152. CONCLUSION OF MAJOR LECTURE 03

This lecture completes the transition from basic Git commands to advanced source-control and automated release engineering.

The student has studied the structure of Git history and the differences between merge and rebase.

Interactive rebase provides methods for organizing local commits.

Stash supports temporary work preservation.

Cherry-pick allows selected changes to be applied across branches.

Reflog supports investigation of local reference movements.

Git bisect provides a systematic approach to identifying regressions.

Worktrees allow multiple linked working directories.

Git hooks support selected local automation.

Repository attributes manage file-specific behavior.

Git LFS and submodules address specialized repository management requirements.

Git tags identify significant source revisions.

Semantic Versioning provides a structured approach to release naming.

GitHub Releases provide a public or restricted distribution and communication mechanism around those versions.

GitHub Actions automates software validation, building, and publication.

Workflow permissions and secrets establish important security boundaries.

Dependabot supports dependency maintenance.

Docker integrates naturally with automated delivery through Buildx, registry authentication, image metadata, and artifact publication.

The final practical project combines these capabilities into a structured release workflow.

The result is an understanding of not only how developers change software, but also how teams evaluate those changes and turn them into traceable release artifacts.

---

# 153. COMPLETION OF THE THREE-LECTURE COURSE

**Course Title:** Git and GitHub: Foundations to Professional Workflows

**Major Lecture 01:** Git Fundamentals and Local Version Control.

**Major Lecture 02:** GitHub, Remote Repositories, and Team Collaboration.

**Major Lecture 03:** Advanced Git, GitHub Actions, CI/CD, and Professional Release Engineering.

**Total Major Lectures:** 3.

**Final Practical Project:** Python Task Manager with Automated Testing, Docker Image Construction, GitHub Actions, and Docker Hub Publication.

**Final Assessment:** 100 Marks.

**Completion Standard:** Demonstrate conceptual understanding and successfully complete the required practical exercises.

---

# 154. FINAL CLOSING STATEMENT

Git and GitHub are not merely tools for saving code.

Together, they form an important part of modern software engineering.

Git provides a reliable model for source history.

GitHub supports collaboration, code review, project organization, and automation.

Advanced Git techniques allow developers to manage complicated histories and investigate failures.

CI/CD systems connect source changes to repeatable validation and software release processes.

The professional developer must understand the relationship between these activities.

A reliable workflow begins with a clear requirement, develops the change on an appropriate branch, records meaningful commits, executes tests, receives suitable review, and produces a traceable release.

The central goal of this course has been to develop the knowledge required to participate confidently in that process.

**END OF MAJOR LECTURE 03**

**END OF THE COMPLETE GIT & GITHUB COURSE**

**Three of Three Major Lectures Completed.**
