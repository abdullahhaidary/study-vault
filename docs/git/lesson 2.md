# GIT & GITHUB: FOUNDATIONS AND PROFESSIONAL DEVELOPMENT

## MAJOR LECTURE 02 — GITHUB, REMOTE REPOSITORIES, AUTHENTICATION, PULL REQUESTS, CODE REVIEWS, FORKING, AND TEAM COLLABORATION

**Course:** Git and GitHub: Foundations to Professional Workflows  
**Lecture:** 02 of 03  
**Academic Level:** Undergraduate Computer Science / Software Engineering / DevOps  
**Lecture Type:** Comprehensive Theory, GitHub Collaboration Laboratory, Technical Examination, and Independent Assignment  
**Recommended Study Duration:** 7–10 Hours  
**Prerequisites:** Major Lecture 01 — Git Fundamentals and Local Version Control

**Topics Covered:**

1. Local and Remote Git Repositories
2. GitHub Repository Creation and Management
3. Git Authentication with SSH and HTTPS
4. Fetching, Pulling, Pushing, and Remote Tracking
5. Feature Branches and Pull Requests
6. Code Reviews, Merge Strategies, and Repository Protection
7. Forking, Open-Source Contributions, Issues, Milestones, and GitHub Projects

---

# PART I — INTRODUCTION TO REMOTE COLLABORATION

## 1. PURPOSE OF THE LECTURE

In Major Lecture 01, we learned to use Git on a local computer.

We created repositories, staged changes, made commits, developed features on branches, merged histories, and recovered from mistakes.

All of those operations can happen without an internet connection.

However, most professional software projects involve multiple developers.

One developer may implement an API.

Another may fix bugs.

Another may work on documentation.

A fourth developer may review the changes before they become part of the main application.

These developers require a method for exchanging commits and coordinating work.

Git provides remote repository capabilities.

GitHub adds an online collaboration environment around those capabilities.

The purpose of this lecture is to connect local Git knowledge with professional collaboration.

The central development process will be:

```text
              SOFTWARE REQUIREMENT
                       |
                       v
                  GITHUB ISSUE
                       |
                       v
                 FEATURE BRANCH
                       |
                       v
                  LOCAL COMMITS
                       |
                       v
                    GIT PUSH
                       |
                       v
                   GITHUB PR
                       |
                       v
                   CODE REVIEW
                       |
                       v
                REQUIRED CHECKS
                       |
                       v
                    MERGE
                       |
                       v
                 UPDATED MAIN
                       |
                       v
                    GIT PULL
```

At the end of the lecture, the student should understand how a local Git repository becomes part of a shared software engineering workflow.

---

# 2. LEARNING OBJECTIVES

Upon completing this lecture, the student should be able to:

1. Explain the purpose of remote repositories.
2. Distinguish local and remote Git history.
3. Define a Git remote.
4. Explain the conventional meaning of `origin`.
5. Explain the conventional meaning of `upstream`.
6. Configure remote repository URLs.
7. Distinguish HTTPS and SSH Git transport.
8. Explain authentication and authorization.
9. Generate an SSH key pair.
10. Distinguish public and private SSH keys.
11. Configure an SSH agent.
12. Add an SSH public key to GitHub.
13. Verify SSH connectivity.
14. Explain personal access tokens.
15. Describe Git credential helpers.
16. Explain GitHub CLI authentication.
17. Create a GitHub repository.
18. Explain repository visibility.
19. Configure a README.
20. Select an appropriate license.
21. Configure repository collaborators.
22. Explain repository permission levels.
23. Use `git remote`.
24. Use `git fetch`.
25. Use `git pull`.
26. Use `git push`.
27. Explain remote-tracking branches.
28. Explain upstream branch tracking.
29. Set tracking with `git push -u`.
30. Explain non-fast-forward push rejection.
31. Synchronize local and remote changes.
32. Develop a feature branch.
33. Publish a feature branch.
34. Create a pull request.
35. Distinguish base and head branches.
36. Create draft pull requests.
37. Review code changes on GitHub.
38. Explain review comments and suggestions.
39. Request changes to a pull request.
40. Respond to review feedback.
41. Explain required status checks.
42. Distinguish merge, squash, and rebase merge methods.
43. Explain branch protection.
44. Explain GitHub rulesets.
45. Configure CODEOWNERS.
46. Define a GitHub fork.
47. Distinguish forks from clones.
48. Configure the original repository as an upstream remote.
49. Synchronize a fork.
50. Explain the open-source pull-request workflow.
51. Create GitHub Issues.
52. Use labels and assignees.
53. Explain milestones.
54. Explain GitHub Projects.
55. Use issue and pull-request templates.
56. Recognize common remote Git errors.
57. Complete a professional GitHub collaboration laboratory.

---

# PART II — LOCAL AND REMOTE REPOSITORIES

## 3. WHAT IS A REMOTE REPOSITORY?

A remote repository is a Git repository accessible through a configured location, often a network service.

A remote repository provides a place where developers can exchange commits and branches.

A common example is a Git repository hosted on GitHub.

Consider two developers.

Developer A has a local repository.

Developer B has a different local repository.

Both repositories may connect to one shared GitHub repository.

```text
            DEVELOPER A
           LOCAL REPOSITORY
                 |
                 |
                 v
             GITHUB
          REMOTE REPOSITORY
                 ^
                 |
                 |
            DEVELOPER B
           LOCAL REPOSITORY
```

Each developer can create local commits.

Those commits are not automatically uploaded.

They are transferred through Git operations such as push and fetch.

---

# 4. LOCAL VERSUS REMOTE HISTORY

A local repository contains the commits and references available on your computer.

A remote repository contains the commits and references available on the remote server.

These histories may differ temporarily.

For example:

```plaintext
LOCAL MAIN:

A --- B --- C


GITHUB MAIN:

A --- B
```

The local repository contains commit C.

The remote repository does not yet contain it.

A push may publish commit C to the remote.

Alternatively:

```plaintext
LOCAL MAIN:

A --- B


GITHUB MAIN:

A --- B --- C
```

The remote contains a newer commit.

A fetch can retrieve knowledge of that commit.

The developer can then integrate it locally.

**Important principle:** A local commit does not automatically become a GitHub commit.

---

# 5. WHAT IS A GIT REMOTE?

A Git remote is a named configuration entry identifying another repository location.

Example:

```bash
git remote add origin git@github.com:USERNAME/PROJECT.git
```

This stores a remote named:

```text
origin
```

pointing to the specified GitHub repository.

A remote name is an alias.

It is not itself a branch.

---

# 6. WHAT DOES ORIGIN MEAN?

`origin` is the conventional default name for the repository from which a local repository was cloned.

It is also commonly used when connecting a newly created local repository to GitHub.

Example:

```text
origin
   |
   v
git@github.com:USERNAME/PROJECT.git
```

Git does not require the remote to be called `origin`.

Other names are permitted.

However, `origin` is widely used because it is immediately recognizable to developers.

---

# 7. WHAT DOES UPSTREAM MEAN?

The word upstream can refer to two related but different ideas.

## 7.1 Upstream Remote

When working with a fork, `upstream` commonly names the original repository.

Example:

```text
origin   = YOUR FORK
upstream = ORIGINAL PROJECT
```

## 7.2 Upstream Tracking Branch

A local branch can track a corresponding branch reference.

Example:

```text
local main
    |
    v
origin/main
```

The tracking relationship helps Git determine default locations for selected pull and push operations.

These two meanings should not be confused.

---

# 8. REMOTE REPOSITORY URLS

Git supports several remote URL forms.

For GitHub, the two most common are HTTPS and SSH.

### HTTPS

```text
https://github.com/USERNAME/PROJECT.git
```

### SSH

```text
git@github.com:USERNAME/PROJECT.git
```

Both can access the same repository when properly configured and authorized.

The difference is the transport and authentication mechanism.

---

# 9. VIEWING CONFIGURED REMOTES

Execute:

```bash
git remote
```

For more detail:

```bash
git remote -v
```

Example:

```text
origin  git@github.com:example/project.git (fetch)
origin  git@github.com:example/project.git (push)
```

The repository may have separate fetch and push URLs, but most introductory workflows use the same destination.

---

# 10. ADDING A REMOTE

Execute:

```bash
git remote add origin git@github.com:USERNAME/PROJECT.git
```

Replace the placeholder with the correct repository location.

The command saves the remote configuration.

It does not automatically push local commits.

Verify:

```bash
git remote -v
```

---

# 11. CHANGING A REMOTE URL

Suppose the remote address changes.

Execute:

```bash
git remote set-url origin NEW_URL
```

Example:

```bash
git remote set-url origin https://github.com/USERNAME/PROJECT.git
```

This changes where Git connects for that remote.

It does not rename local branches or rewrite project commits.

---

# 12. RENAMING AND REMOVING REMOTES

Rename:

```bash
git remote rename origin previous-origin
```

Remove:

```bash
git remote remove previous-origin
```

Removing a remote removes its local remote configuration and associated remote-tracking references.

It does not delete the hosted repository on GitHub.

---

# PART III — GITHUB REPOSITORIES

## 13. WHAT IS A GITHUB REPOSITORY?

A GitHub repository hosts a Git project and provides collaboration features.

A GitHub repository may contain:

- Source code.
- Commit history.
- Branches.
- Tags.
- README.
- License.
- Issues.
- Pull requests.
- Code reviews.
- Discussions.
- Project planning information.
- GitHub Actions workflows.

A GitHub repository has an owner and repository name.

Example:

```text
USERNAME/task-manager
```

---

# 14. CREATING A GITHUB REPOSITORY

A typical browser workflow is:

1. Sign in to GitHub.
2. Create a new repository.
3. Enter a repository name.
4. Choose the owner.
5. Choose visibility.
6. Decide whether to add starter files.
7. Create the repository.

For the practical laboratory, use:

```text
github-major-lesson2
```

If you already created the local repository, create the GitHub repository empty.

Avoid adding a remote README, license, or `.gitignore` during creation when following the exact initial-push exercise.

Otherwise, the local and remote repositories may begin with different commits.

---

# 15. PUBLIC AND PRIVATE REPOSITORIES

## Public Repository

Repository code is generally viewable by anyone.

Public repositories are useful for:

- Open-source projects.
- Public demonstrations.
- Documentation.
- Portfolio projects.

## Private Repository

Repository access is limited to authorized users and applications.

Private repositories are useful for:

- Internal software.
- Confidential project development.
- Restricted collaboration.

## Important Security Qualification

Private repository visibility does not make committed secrets safe.

Credentials should not be committed to either public or private repositories.

---

# 16. THE README FILE

A README introduces a repository to developers and users.

Common contents include:

1. Project title.
2. Project purpose.
3. Requirements.
4. Installation.
5. Usage.
6. Testing.
7. Contribution guidance.

Example:

```markdown
# Python Task Manager

A small application used to practice GitHub collaboration.

## Requirements

Python 3.12 or another compatible Python 3 environment.

## Run

python task_manager.py

## Test

python -m unittest discover -s tests -v
```

A useful README helps another developer understand the project without reading every source file.

---

# 17. LICENSE FILES

A software license establishes legal terms for using, modifying, and distributing the software.

A publicly visible repository is not automatically open source merely because its code can be viewed.

A suitable open-source license must be deliberately selected.

Examples include:

- MIT.
- Apache-2.0.
- GPL-3.0.

The appropriate license depends on the project and its legal requirements.

For training, learn what the licenses mean before adding one.

Do not copy an arbitrary license into a project without considering its terms.

---

# 18. GITHUB REPOSITORY SETTINGS

Repository administrators may configure:

- Default branch.
- Repository visibility.
- Collaborator access.
- Merge options.
- Branch protection.
- Rulesets.
- Issues.
- Discussions.
- Automatic branch deletion.
- Security features.

Settings vary according to repository ownership, organization policy, and GitHub plan.

---

# PART IV — AUTHENTICATION AND AUTHORIZATION

## 19. AUTHENTICATION VERSUS AUTHORIZATION

These concepts are related but different.

**Authentication:** Who are you?

**Authorization:** What are you allowed to do?

For example, GitHub may successfully identify your account.

However, that account might not have permission to push to a particular repository.

Successful login does not guarantee repository write permission.

---

# 20. GIT AUTHOR IDENTITY IS NOT LOGIN

In Major Lecture 01, we configured:

```bash
git config user.name "Developer"
```

and:

```bash
git config user.email "developer@example.com"
```

These values become commit metadata.

They do not authenticate a Git connection to GitHub.

To push to GitHub, the client needs an appropriate authentication method.

Common methods include:

- SSH keys.
- HTTPS with an appropriate credential or token.
- GitHub CLI and its credential integration.

---

# 21. WHAT IS SSH?

SSH stands for Secure Shell.

SSH provides an authenticated encrypted connection mechanism.

GitHub supports SSH-based Git operations.

With SSH, the local machine commonly uses a private key to prove possession of an identity.

The GitHub account stores the corresponding public key.

---

# 22. SSH PUBLIC AND PRIVATE KEYS

An SSH key pair contains:

1. A private key.
2. A public key.

## Private Key

Must remain confidential.

It proves possession of the associated identity.

## Public Key

Can be added to GitHub.

It allows GitHub to verify authentication based on the corresponding private key.

### Conceptual Model

```text
         LOCAL COMPUTER
         PRIVATE SSH KEY
                |
                |
        SSH AUTHENTICATION
                |
                v
              GITHUB
          REGISTERED PUBLIC
               KEY
```

**Important rule:** Never upload your SSH private key to GitHub as though it were the public key.

---

# 23. CHECKING EXISTING SSH KEYS

On a Bash-compatible environment:

```bash
ls -al ~/.ssh
```

You may see names such as:

```text
id_ed25519
id_ed25519.pub
```

Files ending in `.pub` commonly represent public keys.

Before creating a new key, check whether a suitable one already exists.

Avoid overwriting an existing private key.

---

# 24. GENERATING AN SSH KEY

The following example creates a new dedicated key without overwriting the default SSH key filename:

```bash
ssh-keygen \
  -t ed25519 \
  -C "you@example.com" \
  -f ~/.ssh/id_ed25519_github_course
```

Replace the email placeholder if desired.

Choose an appropriate passphrase when prompted.

This produces:

```text
~/.ssh/id_ed25519_github_course
~/.ssh/id_ed25519_github_course.pub
```

The first file is private.

The second is public.

---

# 25. THE SSH AGENT

An SSH agent manages SSH identities and can reduce repeated passphrase entry.

On a suitable Bash environment:

```bash
eval "$(ssh-agent -s)"
```

Add the private key:

```bash
ssh-add ~/.ssh/id_ed25519_github_course
```

Depending on the operating system, SSH agent management may be integrated with the system credential or keychain service.

---

# 26. ADDING THE PUBLIC KEY TO GITHUB

Display the public key:

```bash
cat ~/.ssh/id_ed25519_github_course.pub
```

Copy the displayed public-key text.

In GitHub account settings, navigate to:

```text
Settings
    |
SSH and GPG keys
    |
New SSH key
```

Choose an appropriate title.

Paste the public key.

Save it.

The exact visual navigation may change over time.

The private key remains on your local computer.

---

# 27. SSH CONFIGURATION

If the key has a custom filename, it may be helpful to identify the key explicitly.

Create or carefully edit:

```text
~/.ssh/config
```

Example:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_course
    IdentitiesOnly yes
```

This is suitable for the simple case where the key should be used for `github.com`.

Developers using multiple GitHub accounts may require separate SSH host aliases rather than a single global configuration.

Do not overwrite an existing SSH configuration without reviewing it.

---

# 28. TESTING SSH AUTHENTICATION

Execute:

```bash
ssh -T git@github.com
```

A successful authentication test commonly displays a message indicating that GitHub recognized the user but does not provide shell access.

The test command may exit with status 1 even when authentication succeeds.

## Important Security Detail

The first connection may ask you to verify GitHub's SSH host key.

Compare the displayed fingerprint against GitHub's official published fingerprints before accepting it.

Do not approve an unknown key blindly.

---

# 29. HTTPS AUTHENTICATION

GitHub also supports Git operations over HTTPS.

Example remote:

```text
https://github.com/USERNAME/PROJECT.git
```

For authenticated command-line operations, use an appropriate credential mechanism.

Common approaches include:

- Git Credential Manager.
- GitHub CLI.
- Personal access tokens.

GitHub account passwords are not the normal replacement for an access token in HTTPS Git authentication.

---

# 30. PERSONAL ACCESS TOKENS

A personal access token, abbreviated PAT, authorizes selected operations associated with a GitHub account.

GitHub supports fine-grained tokens and classic tokens.

Fine-grained tokens can often be restricted by:

- Resource owner.
- Repository selection.
- Permission category.
- Expiration.

When suitable, use the minimum permissions needed for the operation.

## Security Practices

- Do not commit tokens.
- Do not print tokens in logs.
- Do not include tokens in remote URLs.
- Avoid storing tokens in plain-text files.
- Revoke compromised tokens.
- Use a credential manager when appropriate.

---

# 31. THE GITHUB CLI

GitHub CLI uses the command:

```text
gh
```

It provides terminal commands for GitHub operations.

Examples:

```bash
gh auth login
```

```bash
gh auth status
```

```bash
gh repo view
```

```bash
gh pr list
```

```bash
gh issue list
```

The GitHub CLI is optional.

Git itself can perform repository synchronization without `gh`.

The browser can handle most GitHub collaboration operations.

---

# 32. GITHUB CLI AUTHENTICATION

When GitHub CLI is installed:

```bash
gh auth login
```

Follow the interactive prompts.

A browser-based authentication flow is commonly available.

Verify:

```bash
gh auth status
```

GitHub CLI can also help configure authentication for Git operations.

## Important Qualification

Credential storage behavior depends on the operating system and available credential store.

Do not assume every environment provides identical secure credential storage.

---

# PART V — FETCH, PULL, AND PUSH

## 33. THE THREE ESSENTIAL REMOTE COMMANDS

The most important remote Git commands are:

```text
FETCH
PULL
PUSH
```

Their responsibilities differ.

### Fetch

Retrieve remote updates into local Git history and remote-tracking references.

### Pull

Fetch and integrate changes into the current branch according to the configured or selected integration method.

### Push

Send local commits and reference updates to a remote repository.

---

# 34. GIT FETCH

Execute:

```bash
git fetch origin
```

This contacts the remote repository and downloads selected objects and reference updates.

For example:

```text
BEFORE FETCH:

local main       A -- B
origin/main      A -- B


REMOTE GITHUB:

main             A -- B -- C
```

After fetching:

```text
local main       A -- B
origin/main      A -- B -- C
```

The local main branch has not automatically moved to C.

This is why fetch is useful for inspecting changes before integrating them.

---

# 35. REMOTE-TRACKING BRANCHES

A remote-tracking branch is a local reference representing Git's last known state of a remote branch.

Example:

```text
origin/main
```

This is not an ordinary local editable branch.

It is a local reference updated through appropriate remote synchronization.

View remote-tracking branches:

```bash
git branch -r
```

View all local and remote-tracking branches:

```bash
git branch -a
```

---

# 36. INSPECTING FETCHED CHANGES

After:

```bash
git fetch origin
```

Compare the local branch with the remote-tracking branch:

```bash
git log --oneline main..origin/main
```

This displays commits reachable from `origin/main` but not from `main`.

To view file differences:

```bash
git diff main..origin/main
```

These commands help determine what changed on GitHub before integrating the remote updates.

---

# 37. GIT PULL

A pull is conceptually:

```text
FETCH
  +
INTEGRATE
```

Depending on the selected configuration, integration may use:

- Merge.
- Rebase.
- Fast-forward-only behavior.

Example:

```bash
git pull origin main
```

However, the exact integration behavior can depend on configuration.

For this introductory collaboration laboratory, a conservative command is:

```bash
git pull --ff-only origin main
```

This refuses to create an automatic merge when a fast-forward is impossible.

---

# 38. WHY FAST-FORWARD-ONLY CAN BE USEFUL

Suppose the local main branch is behind GitHub main.

```plaintext
LOCAL:

A --- B


REMOTE:

A --- B --- C
```

A fast-forward is possible.

Local main can move to C.

Now consider:

```plaintext
LOCAL:

A --- B --- D


REMOTE:

A --- B --- C
```

The histories have diverged.

A fast-forward-only pull refuses to integrate them automatically.

The developer must decide how the histories should be combined.

This helps prevent accidental merge commits during routine synchronization.

---

# 39. GIT PUSH

A push sends selected local reference updates and associated Git objects to a remote.

Example:

```bash
git push origin main
```

This requests that the remote main branch advance according to the pushed history and server rules.

The remote may reject the push if:

- You are not authenticated.
- You lack permission.
- The branch is protected.
- The histories diverged.
- Repository policy rejects the update.

---

# 40. FIRST-TIME BRANCH PUSH

When publishing a new branch:

```bash
git push -u origin feature/tasks
```

The `-u` option establishes an upstream tracking relationship.

Afterward, appropriate Git configurations allow simpler commands such as:

```bash
git push
```

and:

```bash
git pull
```

The exact defaults depend on the repository's upstream and push configuration.

---

# 41. WHAT DOES TRACKING MEAN?

A local branch can track a remote-tracking branch.

Example:

```text
LOCAL:
feature/tasks
      |
      v
REMOTE-TRACKING:
origin/feature/tasks
```

Inspect tracking relationships:

```bash
git branch -vv
```

Set upstream tracking explicitly:

```bash
git branch --set-upstream-to=origin/main main
```

Tracking allows Git to report whether a local branch is ahead or behind its configured upstream reference.

---

# 42. AHEAD AND BEHIND

Suppose the local branch has two commits not yet published.

Git may report:

```text
Your branch is ahead of 'origin/main' by 2 commits.
```

This means the local branch contains commits not reachable from the last fetched `origin/main`.

Alternatively:

```text
Your branch is behind 'origin/main' by 3 commits.
```

This means the remote-tracking reference contains three commits not yet included locally.

A branch can be both ahead and behind when histories have diverged.

---

# 43. PUSH REJECTION: NON-FAST-FORWARD

Imagine:

```plaintext
LOCAL MAIN:

A --- B --- D


GITHUB MAIN:

A --- B --- C
```

If you attempt to push D directly to remote main, GitHub generally rejects the update because it would not be a fast-forward.

The remote already contains commit C.

Publishing D as the new remote tip without integrating C would remove C from the branch's visible history.

The safe response is to retrieve and appropriately integrate remote changes.

---

# 44. SAFE RESPONSE TO A REJECTED PUSH

A typical investigation is:

```bash
git status
```

```bash
git fetch origin
```

```bash
git log --oneline --graph --decorate --all
```

After reviewing the divergence, choose an appropriate integration method.

For a merge-based approach:

```bash
git merge origin/main
```

If conflicts occur, resolve them and complete the merge.

Then push when authorized:

```bash
git push origin main
```

## Important Qualification

If main is protected, direct pushing may remain prohibited even after conflicts are resolved.

A pull request may be required.

---

# 45. FETCH VERSUS PULL VERSUS PUSH

| Operation   | Main effect                                        |
| ----------- | -------------------------------------------------- |
| `git fetch` | Retrieves remote history and reference updates     |
| `git pull`  | Fetches and integrates into the current branch     |
| `git push`  | Publishes local reference updates                  |
| `git clone` | Creates a new local copy of an existing repository |

**Central distinction:** Fetch retrieves; pull integrates; push publishes.

---

# PART VI — GITHUB COLLABORATION

## 46. THE PROFESSIONAL FEATURE BRANCH WORKFLOW

A common collaborative workflow is:

```text
                MAIN BRANCH
                     |
                     v
              CREATE FEATURE
                     |
                     v
                WRITE CODE
                     |
                     v
               MAKE COMMITS
                     |
                     v
               PUSH FEATURE
                     |
                     v
               PULL REQUEST
                     |
                     v
                CODE REVIEW
                     |
                     v
                AUTOMATED TESTS
                     |
                     v
                    MERGE
```

This allows changes to be reviewed before they become part of main.

---

# 47. WHY NOT CHANGE MAIN DIRECTLY?

In a team project, the main branch may represent the latest approved version of the software.

Direct changes can bypass important review and testing procedures.

Feature branches separate incomplete or unreviewed work from main.

Benefits include:

- Easier code review.
- More focused changes.
- Better collaboration.
- Reduced accidental interference.
- Support for automated checks.

A repository may therefore require pull requests before updating main.

---

# 48. FEATURE BRANCH NAMING

Examples:

```text
feature/add-login
feature/task-count
fix/empty-title
docs/update-readme
refactor/database-client
```

A branch name should communicate the purpose of the work.

Names do not need to follow one universal pattern, but consistency helps collaboration.

---

# 49. CREATING AND PUBLISHING A FEATURE

Start from an updated main branch:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

Create the feature branch:

```bash
git switch -c feature/task-count
```

Implement the change.

Stage and commit:

```bash
git add .
```

```bash
git commit -m "Add task count function"
```

Publish:

```bash
git push -u origin feature/task-count
```

The feature branch now exists on GitHub.

---

# PART VII — PULL REQUESTS

## 50. WHAT IS A PULL REQUEST?

A pull request, often abbreviated PR, is a GitHub collaboration feature for proposing and reviewing changes before integrating them into another branch.

A pull request is not itself a Git commit.

It is a collaboration record associated with source and target branches.

It can include:

- Description.
- Commit history.
- File changes.
- Comments.
- Review decisions.
- Status checks.
- Merge controls.

---

# 51. BASE AND HEAD BRANCHES

A pull request compares two branches.

## Base Branch

The destination branch.

Example:

```text
main
```

## Head Branch

The branch containing the proposed changes.

Example:

```text
feature/task-count
```

### Relationship

```text
feature/task-count
       |
       | proposed changes
       v
      main
```

In a fork contribution, the head may belong to a different repository owner.

---

# 52. CREATING A PULL REQUEST

After pushing a feature branch:

1. Open the GitHub repository.
2. Select the Pull requests section.
3. Create a new pull request.
4. Choose the base branch.
5. Choose the head branch.
6. Review the file differences.
7. Enter a meaningful title.
8. Add a useful description.
9. Submit the pull request.

GitHub may also display a convenient comparison option immediately after a new branch is pushed.

---

# 53. A GOOD PULL REQUEST DESCRIPTION

A useful pull request explains:

## Summary

What changed?

## Motivation

Why was the change necessary?

## Testing

How was it verified?

## Related Issue

Which issue or requirement does it address?

Example:

```markdown
## Summary

Adds a function that returns the number of tasks.

## Motivation

The application needs a task count for its user interface.

## Testing

- Ran the Python unit tests
- Verified the output manually

## Related Issue

Fixes #12
```

Replace the issue number with a real issue in the repository.

Appropriate GitHub issue-closing keywords can close referenced issues when qualifying pull requests are merged into the default branch.

---

# 54. DRAFT PULL REQUESTS

A draft pull request indicates work that is not yet ready for final review or merging.

Draft pull requests are useful when:

- A developer wants early feedback.
- A feature is incomplete.
- Architecture review is needed.
- Automated checks should run before the work is ready.

When the work is prepared for formal review, the PR can be marked ready.

---

# 55. GITHUB CLI PULL REQUESTS

When GitHub CLI is installed and authenticated:

```bash
gh pr create \
  --base main \
  --head feature/task-count \
  --title "Add task count" \
  --body "Adds a task counting function and tests."
```

View the PR:

```bash
gh pr view --web
```

List open PRs:

```bash
gh pr list
```

Inspect changes:

```bash
gh pr diff
```

The browser interface remains a valid alternative.

---

# PART VIII — CODE REVIEW

## 56. WHAT IS CODE REVIEW?

Code review is the process of examining proposed changes before accepting them.

Reviewers evaluate qualities such as:

- Correctness.
- Readability.
- Maintainability.
- Security.
- Testing.
- Compatibility.
- Design consistency.

A reviewer should understand both what changed and why.

---

# 57. CODE REVIEW WORKFLOW

```text
DEVELOPER OPENS PR
         |
         v
REVIEWER READS CHANGES
         |
         v
REVIEWER COMMENTS
         |
         v
DEVELOPER REVISES
         |
         v
TESTS RUN AGAIN
         |
         v
REVIEW APPROVED
         |
         v
MERGE
```

In some projects, several review cycles may be required.

---

# 58. REVIEW DECISIONS

GitHub supports review outcomes including:

- Comment.
- Approve.
- Request changes.

## Comment

Provides feedback without approving or formally requesting changes.

## Approve

Indicates acceptance of the proposed change.

## Request Changes

Indicates that changes are required before the review is considered satisfactory.

The effect on merge eligibility depends on repository rules.

---

# 59. REVIEW COMMENTS

Reviewers can comment on specific lines.

Example:

```text
This function should reject empty task titles.
```

The developer should:

1. Understand the feedback.
2. Apply an appropriate correction.
3. Test the change.
4. Commit the correction.
5. Push the feature branch.
6. Respond to the review.

New commits pushed to the head branch normally update its open pull request.

---

# 60. REVIEW SUGGESTIONS

GitHub supports suggestions associated with code review comments.

A reviewer may propose a small replacement for selected lines.

The contributor may apply the suggestion when appropriate.

However, suggested code must still be evaluated and tested.

A suggestion is not inherently correct merely because it comes from a reviewer.

---

# 61. APPROVING YOUR OWN PR

A developer cannot ordinarily satisfy a required independent review by approving their own pull request.

If repository rules require approval from another authorized reviewer, a second eligible reviewer must participate.

For a personal solo repository, it is possible to practice:

- Opening a PR.
- Inspecting changes.
- Leaving comments.
- Updating commits.
- Merging when permitted.

But a solo demonstration does not substitute for a genuine independent code review.

---

# 62. AUTOMATED STATUS CHECKS

A pull request can display results from automated validation systems.

Examples include:

- Python unit tests.
- Docker builds.
- Linting.
- Security checks.
- Integration tests.

These checks may be produced by GitHub Actions or external systems.

A repository rule can require selected checks to succeed before merging.

The check names must match the actual reported status contexts or jobs.

---

# 63. REVIEW VERSUS AUTOMATED TESTING

Code review and automated testing provide different forms of assurance.

| Code review                          | Automated testing                     |
| ------------------------------------ | ------------------------------------- |
| Human evaluation                     | Programmatic validation               |
| Evaluates design and maintainability | Executes defined tests                |
| Can identify conceptual mistakes     | Detects configured failure conditions |
| Requires reviewer judgment           | Produces repeatable results           |

Neither replaces the other completely.

Professional workflows often use both.

---

# PART IX — MERGE STRATEGIES ON GITHUB

## 64. MERGING A PULL REQUEST

After required conditions are satisfied, an authorized contributor can merge the pull request.

GitHub supports several merge strategies.

The three principal strategies are:

1. Merge commit.
2. Squash and merge.
3. Rebase and merge.

The repository's settings determine which strategies are available.

---

# 65. MERGE COMMIT

A merge commit preserves the commits from the feature branch and records an explicit merge point.

Example:

```plaintext
       A --- B --- C
              \     \
               D --- M
```

The exact graph depends on the branches and history.

## Benefits

- Preserves individual feature commits.
- Retains an explicit merge relationship.
- Shows how histories were integrated.

## Tradeoff

The history may contain more merge commits.

---

# 66. SQUASH AND MERGE

Squash and merge combines the pull request's selected changes into one new commit on the base branch.

Example:

Feature branch:

```plaintext
A --- B --- C --- D
```

After squash merging:

```plaintext
A --- S
```

Here, S represents one commit recording the combined feature changes.

The intermediate feature commits are not retained as separate commits in the base branch history.

## Benefits

- Cleaner main-branch history.
- One commit per logical pull request.
- Convenient for small feature branches.

## Important Detail

The squash commit has a new identity.

The feature branch's original commits are not the same commit objects as the resulting squash commit.

---

# 67. REBASE AND MERGE

Rebase and merge replays the feature commits onto the base branch without creating an additional merge commit.

Example:

```plaintext
A --- B --- C --- D
```

The result has a linear history.

GitHub's implementation produces new commit identities for the replayed commits.

## Benefits

- Linear history.
- Separate feature commits can remain visible.

## Tradeoff

Commit history is rewritten.

The development team must understand the implications for local feature branches.

Advanced rebase behavior will be studied in Major Lecture 03.

---

# 68. MERGE STRATEGY COMPARISON

| Strategy         | Preserves separate feature commits on main | Creates merge commit |
| ---------------- | ------------------------------------------ | -------------------- |
| Merge commit     | Yes                                        | Yes                  |
| Squash and merge | No                                         | No                   |
| Rebase and merge | Yes, as rewritten commits                  | No                   |

A team should choose merge strategies according to its history and review policies.

---

# 69. CLEANING UP AFTER MERGING

After merging a feature PR:

1. Update local main.
2. Confirm the merged changes.
3. Remove the obsolete feature branch if safe.
4. Continue work from current main.

Example:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

If the feature was squash merged, Git may not recognize the original feature commits as merged into main.

Therefore, do not blindly force-delete a feature branch.

Verify that the intended work is present and that no unique changes need to be preserved.

---

# PART X — PROTECTED BRANCHES AND RULESETS

## 70. WHY PROTECT MAIN?

A primary branch may contain code intended for deployment or release.

Uncontrolled changes can introduce defects or bypass reviews.

Repository protection can require:

- Pull requests.
- Approvals.
- Passing status checks.
- Signed commits.
- Linear history.
- Restrictions on force pushes.
- Restrictions on deletion.

The exact controls depend on the selected configuration and plan.

---

# 71. BRANCH PROTECTION RULES

A branch protection rule applies selected conditions to matching branches.

For example, main may require:

1. Changes through pull requests.
2. One approving review.
3. Passing Python tests.
4. No force pushes.

Some repositories also apply the rules to administrators.

When rules are configured, contributors must satisfy them before changing protected branches.

---

# 72. GITHUB RULESETS

Rulesets provide another system for controlling changes to selected branches and tags.

Rulesets can express requirements such as:

- Required pull requests.
- Required status checks.
- Signed commits.
- Restricted updates.
- Restricted deletions.
- Linear history.

Multiple rulesets can apply to the same branch.

This differs from the traditional single-applicable-rule model of branch protection.

---

# 73. CONFIGURING A RULESET

For an eligible repository with suitable administration permissions:

1. Open repository Settings.
2. Open Rulesets.
3. Create a branch ruleset.
4. Choose the default branch as the target.
5. Enable the intended requirements.
6. Configure authorized bypass behavior if needed.
7. Save and activate the ruleset.

Example policy:

```text
Target: main

Require pull request: Yes

Require status checks: Yes

Required test check: tests

Block force pushes: Yes

Block deletion: Yes
```

Only select `tests` as a required check after the workflow has produced that check successfully and its exact name is available.

## Availability Qualification

Ruleset and protection capabilities vary with repository visibility, ownership, and GitHub plan.

If a selected control is not available, do not assume it is enabled.

---

# 74. WHAT IS CODEOWNERS?

A CODEOWNERS file identifies GitHub users or teams responsible for selected files.

It can automatically request appropriate reviews when a pull request changes matching files.

Common supported locations include:

```text
.github/CODEOWNERS
```

```text
CODEOWNERS
```

```text
docs/CODEOWNERS
```

GitHub searches supported locations in a defined order.

---

# 75. CODEOWNERS EXAMPLE

Create:

```text
.github/CODEOWNERS
```

Example:

```text
# Default code owner
* @ACTUAL_GITHUB_USERNAME

# Application code
*.py @ACTUAL_GITHUB_USERNAME

# GitHub workflow configuration
.github/workflows/ @ACTUAL_GITHUB_USERNAME
```

Replace the placeholder with an actual authorized GitHub user.

A code owner must have the required repository access.

For an organization, visible teams with suitable access can also be assigned.

---

# 76. CODEOWNERS AND REQUIRED APPROVALS

CODEOWNERS can request reviewers.

An applicable repository protection setting can additionally require approval from a code owner.

These are separate functions.

The presence of CODEOWNERS does not automatically guarantee that approval is mandatory.

A reviewer cannot satisfy an independent approval requirement by simply reviewing their own contribution.

---

# PART XI — FORKS AND OPEN-SOURCE CONTRIBUTIONS

## 77. WHAT IS A FORK?

A fork is a GitHub repository created from another GitHub repository through GitHub's fork mechanism.

It is commonly associated with a different repository owner or namespace.

Example:

```text
ORIGINAL OWNER
   |
   v
original/project
   |
   v
YOUR FORK
   |
   v
your-account/project
```

Forks are particularly useful when contributors do not have write access to the original repository.

---

# 78. FORK VERSUS CLONE

These terms are not interchangeable.

| Fork                                           | Clone                                        |
| ---------------------------------------------- | -------------------------------------------- |
| GitHub-side repository relationship            | Local Git copy operation                     |
| Creates a repository under an authorized owner | Creates a repository on your computer        |
| Supports cross-repository PR workflows         | Provides local development files and history |
| Usually performed through GitHub               | Performed with `git clone`                   |

A common contribution workflow is:

1. Fork the upstream project on GitHub.
2. Clone your fork locally.
3. Create a feature branch.
4. Implement a change.
5. Push to your fork.
6. Open a pull request to the original project.

---

# 79. ORIGIN AND UPSTREAM IN A FORK

Suppose:

```text
ORIGINAL:

https://github.com/ORIGINAL_OWNER/project.git
```

Your fork:

```text
https://github.com/YOUR_USERNAME/project.git
```

After cloning your fork:

```bash
git clone git@github.com:YOUR_USERNAME/project.git
```

The default remote `origin` points to your fork.

Add the original repository:

```bash
git remote add upstream \
  https://github.com/ORIGINAL_OWNER/project.git
```

Now:

```text
origin   = your fork
upstream = original project
```

---

# 80. SYNCHRONIZING A FORK

Fetch the original project:

```bash
git fetch upstream
```

Switch to your fork's local main branch:

```bash
git switch main
```

When a fast-forward is possible:

```bash
git merge --ff-only upstream/main
```

Publish the updated main branch to your fork:

```bash
git push origin main
```

## Important Qualification

If your local main has diverged from the original repository, the fast-forward command fails.

That requires deliberate reconciliation rather than blindly forcing an update.

---

# 81. CONTRIBUTING TO AN OPEN-SOURCE PROJECT

A respectful contribution workflow includes:

1. Read the README.
2. Read CONTRIBUTING.md if present.
3. Review the project's license.
4. Check existing issues and pull requests.
5. Understand contribution requirements.
6. Fork when necessary.
7. Create a focused feature branch.
8. Implement a useful change.
9. Run the relevant tests.
10. Open a meaningful pull request.
11. Respond to maintainer feedback.

Do not open unnecessary test pull requests against unrelated public projects.

Use your own practice repository or an explicitly designated training repository for exercises.

---

# PART XII — ISSUES, LABELS, AND PROJECT MANAGEMENT

## 82. WHAT IS A GITHUB ISSUE?

A GitHub Issue is a work-tracking item.

It can represent:

- Bug report.
- Feature request.
- Documentation improvement.
- Maintenance task.
- Design discussion requiring concrete follow-up.

An issue can include:

- Title.
- Description.
- Comments.
- Assignees.
- Labels.
- Milestones.
- Project associations.
- Relationships to other issues.

---

# 83. ISSUE EXAMPLE

Title:

```text
Add a function to count tasks
```

Description:

```markdown
## Problem

The application does not report the number of tasks.

## Proposed Solution

Add a function that returns the current task count.

## Acceptance Criteria

- Returns 0 for an empty task list
- Returns the correct count for a populated list
- Has automated unit tests
```

This makes the expected behavior explicit before development begins.

---

# 84. ISSUES VERSUS PULL REQUESTS

An Issue describes something to investigate or accomplish.

A Pull Request proposes concrete code changes.

Example:

```text
ISSUE:
Task count is missing.
      |
      v
FEATURE BRANCH:
Implement task count.
      |
      v
PULL REQUEST:
Review the implementation.
      |
      v
MERGE:
Deliver the change.
```

An issue does not necessarily require a pull request.

However, connecting related work can improve traceability.

---

# 85. LABELS

Labels categorize work.

Examples:

```text
bug
enhancement
documentation
help wanted
good first issue
priority-high
```

Labels can help developers filter tasks and understand their purpose.

A label is not the same as an assignee or milestone.

---

# 86. ASSIGNEES

An assignee identifies who is responsible for selected work.

For example:

```text
Issue: Add task count

Assignee: Developer A
```

Assigning an issue does not create a Git branch automatically.

It is a project coordination mechanism.

---

# 87. MILESTONES

A milestone groups issues or pull requests around a shared goal.

Examples:

```text
Version 1.0
October maintenance release
Task manager MVP
```

A milestone can help track progress toward a release or project objective.

---

# 88. GITHUB PROJECTS

GitHub Projects supports planning and tracking work across issues and pull requests.

A project can use views such as:

- Table.
- Board.
- Roadmap.

A basic board might have columns:

```text
TODO | IN PROGRESS | IN REVIEW | DONE
```

This provides a convenient overview of team activity.

GitHub Projects is a planning interface.

It does not replace Git's commit history or pull-request review process.

---

# 89. ISSUE TEMPLATES

Issue templates guide contributors when reporting problems.

Example:

```text
.github/ISSUE_TEMPLATE/bug_report.md
```

Content:

```markdown
---
name: Bug Report
about: Report a reproducible problem
---

## Description

Describe the problem.

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

Describe what should happen.

## Actual Behavior

Describe what happened.

## Environment

Include relevant software versions.
```

A template encourages more complete problem reports.

---

# 90. PULL REQUEST TEMPLATES

Create:

```text
.github/PULL_REQUEST_TEMPLATE.md
```

Example:

```markdown
## Summary

Describe the changes.

## Reason

Explain why the changes are necessary.

## Testing

- [ ] Unit tests passed
- [ ] Relevant functionality verified
- [ ] No secrets added

## Related Issue

Closes #
```

The developer replaces the issue placeholder when applicable.

The template improves consistency across contributions.

---

# 91. GITHUB DISCUSSIONS

GitHub Discussions can provide a place for conversations that are not necessarily ready to become concrete tasks.

Examples include:

- Community questions.
- Feature ideas.
- Design exploration.
- Announcements.
- General support discussions.

A discussion can eventually lead to an Issue or Pull Request.

Availability depends on repository configuration.

---

# PART XIII — COMPLETE PRACTICAL LABORATORY

## 92. LABORATORY TITLE

**GitHub Team Collaboration: Remote Repository Creation, Authentication, Feature Branches, Pull Requests, Simulated Teammate Conflicts, and Repository Protection**

The laboratory uses a small Python task-management project.

The purpose is to demonstrate a realistic GitHub workflow from a local repository through reviewed integration.

### Requirements

- Git installed.
- Python 3 installed.
- An authenticated GitHub account.
- A Bash-compatible terminal.
- An empty practice GitHub repository.
- GitHub CLI optionally installed.

### Important Constraint

Use a dedicated practice repository.

Do not experiment with force pushes, history changes, or intentionally conflicting commits in a repository containing valuable team work.

---

# 93. LABORATORY DIRECTORY STRUCTURE

The initial project will have:

```text
github-major-lesson2/
├── task_manager.py
├── README.md
├── .gitignore
├── tests/
│   └── test_tasks.py
└── .github/
    └── workflows/
        └── tests.yml
```

Additional files will be added during the laboratory.

---

# 94. APPLICATION SOURCE FILE

Create:

```text
task_manager.py
```

Insert:

```python
def add_task(tasks, title):

    cleaned = title.strip()

    if not cleaned:
        raise ValueError("A task title is required")

    return [*tasks, cleaned]


def format_tasks(tasks):

    return "\n".join(
        f"- {task}"
        for task in tasks
    )


def main():

    tasks = []

    tasks = add_task(
        tasks,
        "Learn GitHub",
    )

    tasks = add_task(
        tasks,
        "Practice pull requests",
    )

    print(format_tasks(tasks))


if __name__ == "__main__":
    main()
```

The application uses only Python's standard library.

It allows tasks to be added to an in-memory list and displayed.

Persistence is not the focus of this GitHub collaboration lesson.

---

# 95. UNIT TEST FILE

Create:

```text
tests/test_tasks.py
```

Insert:

```python
import unittest

from task_manager import (
    add_task,
    format_tasks,
)


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


    def test_trim_title(self):

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

            add_task(
                [],
                "   ",
            )


    def test_format_tasks(self):

        result = format_tasks(
            ["Git", "GitHub"]
        )

        self.assertEqual(
            result,
            "- Git\n- GitHub",
        )


if __name__ == "__main__":
    unittest.main()
```

---

# 96. GITHUB ACTIONS VALIDATION FILE

Create:

```text
.github/workflows/tests.yml
```

Insert:

```yaml
name: Python Tests

on:
  push:
    branches:
      - main

  pull_request:
    branches:
      - main

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

      - name: Run Python tests
        run: |
          python -m unittest discover -s tests -v
```

This is intentionally a small workflow.

The primary lesson is GitHub collaboration.

Advanced Actions configuration will be covered in Major Lecture 03.

The job is named:

```text
tests
```

This name may be used as an example status check when configuring eligible repository protection rules after the check has run successfully.

---

# 97. README FILE

Create:

```text
README.md
```

Insert:

```markdown
# GitHub Collaboration Laboratory

This is a small Python task-management project used to learn
professional Git and GitHub collaboration workflows.

## Requirements

Python 3.

## Run

python3 task_manager.py

## Test

python3 -m unittest discover -s tests -v

## Collaboration

Create a feature branch, make a focused change,
open a pull request, and review the change before merging.
```

---

# 98. GITIGNORE FILE

Create:

```text
.gitignore
```

Insert:

```gitignore
__pycache__/
*.pyc
.env
.venv/
*.log
```

This excludes selected local environment and generated files from ordinary tracking.

---

# 99. EXPERIMENT 1 — VERIFY TOOLS

Execute:

```bash
git --version
```

```bash
python3 --version
```

Optional:

```bash
gh --version
```

**Objective:** Confirm Git, Python, and optionally GitHub CLI availability.

---

# 100. EXPERIMENT 2 — CREATE THE PROJECT

For a Bash-compatible terminal:

```bash
mkdir -p github-major-lesson2/tests
```

```bash
mkdir -p github-major-lesson2/.github/workflows
```

```bash
cd github-major-lesson2
```

Create the source files from Sections 94–98.

**Objective:** Establish the project structure.

---

# 101. EXPERIMENT 3 — RUN LOCAL TESTS

Execute:

```bash
python3 -m unittest discover -s tests -v
```

Run the application:

```bash
python3 task_manager.py
```

**Objective:** Verify that the initial source is functional.

**Expected result:** All four defined unit tests pass.

---

# 102. EXPERIMENT 4 — INITIALIZE THE REPOSITORY

Execute:

```bash
git init -b main
```

Verify your author identity:

```bash
git config user.name
```

```bash
git config user.email
```

Configure it if necessary.

For actual GitHub attribution, use the GitHub-associated author identity or an appropriate GitHub-provided no-reply email.

**Objective:** Create the initial local repository.

---

# 103. EXPERIMENT 5 — CREATE THE INITIAL COMMIT

Execute:

```bash
git add .
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "Initialize GitHub collaboration laboratory"
```

Verify:

```bash
git log --oneline
```

**Objective:** Establish a tracked project history.

---

# 104. EXPERIMENT 6 — CREATE THE GITHUB REMOTE

On GitHub, create a new repository:

```text
github-major-lesson2
```

Do not add starter commits when following this exact exercise.

Choose appropriate public or private visibility.

**Objective:** Prepare the online repository.

---

# 105. EXPERIMENT 7 — CONFIGURE AUTHENTICATION

Use either the SSH method or HTTPS method described previously.

For SSH:

1. Verify or generate a suitable SSH key.
2. Add its public key to GitHub.
3. Configure the SSH agent if necessary.
4. Verify the connection.

Test:

```bash
ssh -T git@github.com
```

**Objective:** Establish authenticated Git transport.

---

# 106. EXPERIMENT 8 — ADD THE ORIGIN REMOTE

For SSH:

```bash
git remote add origin \
  git@github.com:YOUR_USERNAME/github-major-lesson2.git
```

Replace the placeholder with your actual GitHub username.

Inspect:

```bash
git remote -v
```

**Objective:** Connect the local project to its GitHub repository.

---

# 107. EXPERIMENT 9 — PUBLISH MAIN

Execute:

```bash
git push -u origin main
```

Open the repository on GitHub.

**Expected result:** The source files and initial commit are visible.

**Objective:** Perform the first publication of the local repository history.

---

# 108. EXPERIMENT 10 — INSPECT REMOTE TRACKING

Execute:

```bash
git branch -vv
```

Then:

```bash
git branch -r
```

Then:

```bash
git status
```

**Objective:** Examine the relationship between local main and `origin/main`.

---

# 109. EXPERIMENT 11 — CREATE A GITHUB ISSUE

Open the repository's Issues section.

Create an issue titled:

```text
Add a task count function
```

Use the following description:

```markdown
## Requirement

Add a function that returns the number of tasks.

## Acceptance Criteria

- Empty list returns 0
- Two tasks return 2
- Existing behavior remains unchanged
- Unit tests pass
```

Record the issue number.

**Objective:** Create a traceable development requirement.

---

# 110. EXPERIMENT 12 — CREATE A FEATURE BRANCH

Ensure the local main branch is current:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

Create a feature branch:

```bash
git switch -c feature/task-count
```

**Objective:** Develop without directly changing main.

---

# 111. EXPERIMENT 13 — IMPLEMENT THE FEATURE

Append a function to `task_manager.py`:

```bash
cat >> task_manager.py <<'PY'


def count_tasks(tasks):
    return len(tasks)
PY
```

Create:

```text
tests/test_count.py
```

Insert:

```python
import unittest

from task_manager import count_tasks


class CountTests(unittest.TestCase):

    def test_empty_count(self):

        self.assertEqual(
            count_tasks([]),
            0,
        )


    def test_two_tasks(self):

        self.assertEqual(
            count_tasks(["Git", "GitHub"]),
            2,
        )


if __name__ == "__main__":
    unittest.main()
```

Run the complete test suite.

**Expected result:** Six tests pass.

---

# 112. EXPERIMENT 14 — COMMIT THE FEATURE

Execute:

```bash
git status
```

```bash
git diff
```

Stage:

```bash
git add task_manager.py tests/test_count.py
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "Add task counting function and tests"
```

**Objective:** Create a focused feature commit.

---

# 113. EXPERIMENT 15 — PUSH THE FEATURE BRANCH

Execute:

```bash
git push -u origin feature/task-count
```

Verify:

```bash
git branch -vv
```

Open GitHub.

**Expected result:** The feature branch is available on the remote.

---

# 114. EXPERIMENT 16 — OPEN A PULL REQUEST

On GitHub:

1. Open Pull requests.
2. Create a new pull request.
3. Select main as the base.
4. Select `feature/task-count` as the head.
5. Review the code difference.
6. Submit the PR.

Suggested title:

```text
Add task counting function
```

Suggested description:

```markdown
## Summary

Adds a function that returns the number of tasks.

## Tests

- Empty list returns zero
- Populated list returns the expected count
- All unit tests pass

## Related Issue

Fixes #ISSUE_NUMBER
```

Replace the placeholder with the actual issue number.

**Objective:** Propose a code change through GitHub's review workflow.

---

# 115. EXPERIMENT 17 — VERIFY AUTOMATED CHECKS

Open the pull request.

Inspect its Checks section.

Locate the Python Tests workflow.

**Expected result:** The test job passes.

**Objective:** Verify automatic validation of the proposed change.

---

# 116. EXPERIMENT 18 — PERFORM A SELF-REVIEW

Open the pull request's Files changed section.

Inspect:

- Added function.
- New tests.
- Commit messages.
- Scope of changes.

Add a discussion comment or a non-approval review comment.

**Objective:** Practice reviewing the proposed changes.

**Important Qualification:** This is a learning exercise and does not count as independent approval if the repository requires an eligible outside reviewer.

---

# 117. EXPERIMENT 19 — RESPOND TO REVIEW FEEDBACK

Improve the function by adding a short docstring.

Edit the function:

```python
def count_tasks(tasks):
    """Return the number of tasks in a collection."""
    return len(tasks)
```

Run tests again.

Commit:

```bash
git add task_manager.py
```

```bash
git commit -m "Document task count behavior"
```

Push:

```bash
git push origin feature/task-count
```

**Objective:** Demonstrate that additional feature-branch commits update the open pull request.

---

# 118. EXPERIMENT 20 — MERGE THE PULL REQUEST

When the configured checks and review conditions permit merging:

1. Inspect the final changes.
2. Confirm checks passed.
3. Choose an available merge method.
4. Merge the PR.
5. Record the merge result.

For the laboratory, squash and merge is a useful demonstration.

**Objective:** Integrate reviewed feature changes into main.

---

# 119. EXPERIMENT 21 — UPDATE LOCAL MAIN

Execute:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

Run:

```bash
python3 -m unittest discover -s tests -v
```

Inspect:

```bash
git log --oneline --graph --decorate --all
```

**Objective:** Synchronize the local repository with the merged changes.

---

# 120. EXPERIMENT 22 — CLEAN UP THE FEATURE BRANCH

Verify the feature is present on main:

```bash
python3 -c 'from task_manager import count_tasks; print(count_tasks(["A", "B"]))'
```

Expected:

```text
2
```

If the PR was squash merged, the original feature commits may not be considered ancestors of main.

After verifying that no unique work remains:

```bash
git branch -D feature/task-count
```

Remove the remote feature branch through GitHub if it has not already been deleted.

**Objective:** Clean up a completed feature safely.

---

# 121. EXPERIMENT 23 — SIMULATE A SECOND DEVELOPER

Move to the parent directory:

```bash
cd ..
```

Clone the repository into a second local directory:

```bash
git clone \
  git@github.com:YOUR_USERNAME/github-major-lesson2.git \
  github-major-lesson2-teammate
```

Enter the new clone:

```bash
cd github-major-lesson2-teammate
```

Set a distinct local commit author for simulation:

```bash
git config user.name "Simulated Teammate"
```

```bash
git config user.email "teammate@example.invalid"
```

**Objective:** Simulate another developer's local repository.

**Important Qualification:** Both clones may still authenticate as your actual GitHub account. Changing the local commit author does not create a second GitHub identity.

---

# 122. EXPERIMENT 24 — PREPARE A SHARED FILE

Return to the original clone:

```bash
cd ../github-major-lesson2
```

Create:

```bash
printf 'color=blue\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Add shared color setting"
```

Push:

```bash
git push origin main
```

Now update the second clone:

```bash
cd ../github-major-lesson2-teammate
```

```bash
git pull --ff-only origin main
```

**Objective:** Establish identical starting content in both clones.

This exercise assumes main does not yet have protection that prohibits direct pushes.

---

# 123. EXPERIMENT 25 — CREATE A REMOTE CHANGE

In the second clone:

```bash
printf 'color=green\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Use green shared color"
```

Push:

```bash
git push origin main
```

**Objective:** Simulate another developer publishing a new commit.

---

# 124. EXPERIMENT 26 — CREATE A CONFLICTING LOCAL CHANGE

Return to the original clone:

```bash
cd ../github-major-lesson2
```

Modify the same line:

```bash
printf 'color=purple\n' > settings.txt
```

Commit:

```bash
git add settings.txt
```

```bash
git commit -m "Use purple shared color"
```

Now attempt:

```bash
git push origin main
```

**Expected result:** Git rejects the non-fast-forward update because the remote contains the second clone's new commit.

**Objective:** Demonstrate remote history divergence.

---

# 125. EXPERIMENT 27 — FETCH AND INSPECT THE DIVERGENCE

Execute:

```bash
git fetch origin
```

Inspect:

```bash
git log --oneline --graph --decorate --all
```

Compare:

```bash
git diff main..origin/main
```

**Objective:** Examine remote changes before integration.

The local main branch and `origin/main` contain diverged histories.

---

# 126. EXPERIMENT 28 — MERGE THE REMOTE CHANGE

Execute:

```bash
git merge origin/main
```

**Expected result:** Git reports a conflict in `settings.txt`.

Inspect:

```bash
git status
```

Open the file and examine the conflict markers.

**Objective:** Experience a conflict caused by simultaneous development in two local clones.

---

# 127. EXPERIMENT 29 — RESOLVE AND PUBLISH

Resolve the file with an agreed training value:

```bash
printf 'color=purple-and-green\n' > settings.txt
```

Stage:

```bash
git add settings.txt
```

Complete:

```bash
git commit -m "Resolve shared color configuration conflict"
```

Push:

```bash
git push origin main
```

**Expected result:** The integrated history is published, assuming no repository rule prevents direct pushing.

**Objective:** Resolve a remote collaboration conflict without discarding either side's history.

---

# 128. EXPERIMENT 30 — SYNCHRONIZE THE SECOND CLONE

Enter the teammate clone:

```bash
cd ../github-major-lesson2-teammate
```

Execute:

```bash
git fetch origin
```

Then:

```bash
git pull --ff-only origin main
```

Inspect:

```bash
cat settings.txt
```

Expected:

```text
color=purple-and-green
```

**Objective:** Confirm both clones converge on the updated shared history.

---

# 129. EXPERIMENT 31 — ADD A PULL REQUEST TEMPLATE

In the original clone, return to main:

```bash
cd ../github-major-lesson2
```

Create a new documentation branch:

```bash
git switch -c docs/pr-template
```

Create:

```text
.github/PULL_REQUEST_TEMPLATE.md
```

Use the template from Section 90.

Commit:

```bash
git add .github/PULL_REQUEST_TEMPLATE.md
```

```bash
git commit -m "Add pull request template"
```

Push:

```bash
git push -u origin docs/pr-template
```

Create and merge a pull request.

**Objective:** Introduce reusable contribution documentation.

---

# 130. EXPERIMENT 32 — CONFIGURE CODEOWNERS

Update local main after the template PR is merged:

```bash
git switch main
```

```bash
git pull --ff-only origin main
```

Create a new branch:

```bash
git switch -c docs/codeowners
```

Create:

```text
.github/CODEOWNERS
```

Add a valid ownership rule using your actual GitHub username.

Example:

```text
* @YOUR_GITHUB_USERNAME
```

Commit and push.

Open a PR.

**Objective:** Demonstrate automatic code-owner assignment.

**Important Qualification:** Code ownership does not permit a PR author to satisfy a required independent approval merely by owning the changed files.

---

# 131. EXPERIMENT 33 — INSPECT REPOSITORY PROTECTION

After completing the direct-push and conflict exercises, inspect the repository's branch protection or ruleset settings.

For an eligible repository:

1. Create a rule targeting main.
2. Require a pull request before merging.
3. Require the previously successful Python test check.
4. Block force pushes.
5. Block branch deletion.
6. Configure approval requirements only when eligible reviewers are available.

**Objective:** Understand how repository rules enforce collaboration policy.

For a solo exercise, do not activate a mandatory second-person approval requirement unless another eligible reviewer is available.

---

# 132. EXPERIMENT 34 — EXPLORE GITHUB ISSUES AND MILESTONES

Create a second issue:

```text
Improve task manager documentation
```

Apply a documentation label.

Create a milestone such as:

```text
Collaboration Practice v1
```

Associate the issue with that milestone.

**Objective:** Practice structured work tracking.

---

# 133. EXPERIMENT 35 — EXPLORE GITHUB PROJECTS

Create a personal or organization GitHub Project, if available to your account.

Add the laboratory issues.

Configure a board view with states such as:

```text
Todo
In Progress
In Review
Done
```

Move the issues through the stages.

**Objective:** Understand the relationship between issue tracking and project planning.

---

# 134. EXPERIMENT 36 — PRACTICE FORK WORKFLOW

Choose an appropriate public repository that permits contributions or a repository specifically intended for Git practice.

Fork it through GitHub.

Clone your fork locally.

Inspect:

```bash
git remote -v
```

Add the original repository as upstream:

```bash
git remote add upstream ORIGINAL_REPOSITORY_URL
```

Fetch:

```bash
git fetch upstream
```

Inspect:

```bash
git branch -r
```

**Objective:** Distinguish personal fork history from the original project's repository.

Do not submit a meaningless practice pull request to an unrelated real project.

---

# 135. EXPERIMENT 37 — FINAL COLLABORATION VERIFICATION

In the main laboratory repository, verify:

```bash
git status
```

```bash
git remote -v
```

```bash
git branch -vv
```

```bash
git log --oneline --graph --decorate --all
```

Confirm through GitHub that:

1. Main contains the approved changes.
2. The task-count PR was merged.
3. The tests ran.
4. The associated issue was updated.
5. The template is present.
6. Code ownership is configured as intended.
7. Relevant repository rules are visible.
8. No credential was committed.

**Objective:** Complete a full GitHub collaboration cycle.

---

# PART XIV — TROUBLESHOOTING REMOTE GIT

## 136. ERROR: PERMISSION DENIED (PUBLICKEY)

Possible causes include:

- No SSH key available.
- Incorrect private key selected.
- Public key not registered with GitHub.
- SSH agent not configured.
- Repository permissions missing.
- Incorrect remote hostname.

Investigation:

```bash
ssh -T git@github.com
```

```bash
git remote -v
```

Check SSH configuration and registered public keys.

Do not share private SSH keys to troubleshoot authentication.

---

# 137. ERROR: REPOSITORY NOT FOUND

Possible causes:

- Incorrect repository URL.
- Repository renamed or deleted.
- Private repository access missing.
- Incorrect authenticated account.
- Repository ownership mismatch.

Investigation:

```bash
git remote -v
```

Verify the repository URL and authenticated identity.

For private repositories, confirm that the account is authorized.

---

# 138. ERROR: AUTHENTICATION FAILED

For HTTPS operations, possible causes include:

- Expired token.
- Revoked token.
- Insufficient token permissions.
- Wrong credential stored.
- Organization authorization requirement.
- Incorrect remote URL.

Use an appropriate credential manager.

Do not insert the token into a script or remote URL.

---

# 139. ERROR: NON-FAST-FORWARD

Symptom:

```text
Updates were rejected because the remote contains work
that you do not have locally.
```

A safe investigation:

```bash
git fetch origin
```

```bash
git log --oneline --graph --decorate --all
```

Then select merge or another appropriate integration method.

Do not use force push merely to make the error disappear.

---

# 140. ERROR: NO UPSTREAM BRANCH

A newly created local branch may not track a remote branch.

Example correction:

```bash
git push -u origin feature/name
```

This publishes the feature branch and sets the upstream relationship.

Use the actual local branch name.

---

# 141. ERROR: PULL REQUIRES INTEGRATION STRATEGY

When branches have diverged, Git may require an explicit selection of how to reconcile them.

Options include:

- Merge.
- Rebase.
- Fast-forward-only.

Example conservative request:

```bash
git pull --ff-only origin main
```

If this fails due to divergence, examine the histories and choose the correct reconciliation strategy.

Do not assume that a failed fast-forward pull means the repository is corrupted.

---

# 142. ERROR: PROTECTED BRANCH

A push may be rejected because the branch requires:

- Pull requests.
- Required reviews.
- Successful checks.
- Signed commits.
- Other repository rules.

The proper response is to satisfy the configured policy.

Do not treat repository protections as errors that must be bypassed.

---

# 143. ERROR: PULL REQUEST HAS MERGE CONFLICTS

A PR may no longer merge cleanly because its base branch has changed.

A common merge-based resolution is:

```bash
git fetch origin
```

```bash
git switch feature/name
```

```bash
git merge origin/main
```

Resolve conflicts and run tests.

Then:

```bash
git push origin feature/name
```

The PR updates with the new feature-branch commits.

The exact procedure may vary when contributing from a fork or when the repository requires rebase-based history.

---

# PART XV — IMPORTANT CONCEPTUAL DISTINCTIONS

## 144. GIT REMOTE COMPARISON TABLE

| Concept A         | Concept B              | Key distinction                                           |
| ----------------- | ---------------------- | --------------------------------------------------------- |
| Git               | GitHub                 | Version control versus hosting platform                   |
| Local repository  | Remote repository      | Local history versus remotely available history           |
| origin            | upstream               | Conventional names for different repository relationships |
| Fetch             | Pull                   | Retrieve versus retrieve and integrate                    |
| Pull              | Push                   | Retrieve/integrate versus publish                         |
| Local branch      | Remote-tracking branch | Editable branch versus local view of remote state         |
| Commit            | Pull request           | Git history object versus GitHub review workflow          |
| Issue             | Pull request           | Work requirement versus proposed code change              |
| Fork              | Clone                  | GitHub-side copy relationship versus local copy           |
| Review            | Test                   | Human assessment versus automated validation              |
| Merge commit      | Squash merge           | Preserve separate commits versus combine into one         |
| Branch protection | CODEOWNERS             | Enforced branch rules versus reviewer ownership mapping   |
| Authentication    | Authorization          | Identity verification versus allowed actions              |

---

# PART XVI — FORMAL ACADEMIC EXAMINATION

## 145. PART A — DEFINITIONS

Define:

1. Remote repository.
2. Local repository.
3. Git remote.
4. Origin.
5. Upstream remote.
6. Upstream tracking branch.
7. Remote-tracking branch.
8. Git fetch.
9. Git pull.
10. Git push.
11. Non-fast-forward rejection.
12. Authentication.
13. Authorization.
14. SSH key pair.
15. Personal access token.
16. GitHub CLI.
17. Feature branch.
18. Pull request.
19. Base branch.
20. Head branch.
21. Draft pull request.
22. Code review.
23. Status check.
24. Branch protection.
25. Ruleset.
26. CODEOWNERS.
27. Fork.
28. Issue.
29. Milestone.
30. GitHub Project.

---

# 146. PART B — SHORT-ANSWER QUESTIONS

**Question 1.**

Explain why a local Git commit does not automatically appear on GitHub.

**Question 2.**

Describe the difference between SSH and HTTPS repository access.

**Question 3.**

Explain the difference between authentication and authorization.

**Question 4.**

Describe the purpose of the SSH public and private keys.

**Question 5.**

Explain why `git fetch` is safer for inspection than automatically integrating remote changes.

**Question 6.**

Describe the difference between `git fetch` and `git pull`.

**Question 7.**

Explain the function of `git push -u`.

**Question 8.**

Why may Git reject a non-fast-forward push?

**Question 9.**

Explain how feature branches support professional collaboration.

**Question 10.**

Distinguish a Git commit from a GitHub pull request.

**Question 11.**

Explain the roles of base and head branches.

**Question 12.**

Describe the three principal pull-request merge strategies.

**Question 13.**

Explain why required status checks are useful.

**Question 14.**

Describe how CODEOWNERS supports code review.

**Question 15.**

Explain the relationship between a fork, origin, and upstream.

---

# 147. PART C — COMMAND INTERPRETATION

Consider:

```bash
git remote add origin REPOSITORY_URL
```

Explain the result.

Consider:

```bash
git fetch origin
```

Explain which repository references may change.

Consider:

```bash
git pull --ff-only origin main
```

Explain why the command may fail.

Consider:

```bash
git push -u origin feature/tasks
```

Explain the effect of `-u`.

Consider:

```bash
git branch -vv
```

Explain the tracking information displayed.

Consider:

```bash
git merge origin/main
```

Explain the role of the remote-tracking reference.

---

# 148. PART D — ANALYTICAL CASE STUDIES

## Case Study 1 — Wrong Remote URL

A developer pushes to the wrong repository URL.

Explain how to inspect and correct the remote configuration.

## Case Study 2 — Missing SSH Key

GitHub rejects SSH authentication.

Explain the steps required to diagnose the key configuration.

## Case Study 3 — Diverged Main

Two developers independently commit to main.

One developer's push is rejected.

Explain why this occurred and how to reconcile the histories safely.

## Case Study 4 — Missing Required Review

A pull request passes all tests, but the Merge option remains blocked.

Explain why repository protection may require additional review.

## Case Study 5 — Squash Merge Cleanup

A contributor squash merges a feature PR.

Git reports that the original local feature branch is not fully merged.

Explain why this can occur and how to verify safe cleanup.

## Case Study 6 — Fork Contribution

A contributor has no write permission to an original public repository.

Explain how forking and cross-repository pull requests permit contribution.

---

# 149. PRACTICAL EXAMINATION — 100 MARKS

| Assessment category                           |   Marks |
| --------------------------------------------- | ------: |
| Remote repository theory                      |      10 |
| GitHub repository creation and configuration  |      10 |
| SSH/HTTPS authentication                      |      15 |
| Fetch, pull, push, and tracking               |      15 |
| Feature branches and pull requests            |      15 |
| Code review and merge strategies              |      10 |
| Repository protection and CODEOWNERS          |      10 |
| Forking and open-source contribution workflow |      10 |
| Documentation and technical explanation       |       5 |
| **Total**                                     | **100** |

**Suggested passing standard:** 80/100.

The student should demonstrate both correct command usage and accurate understanding of GitHub collaboration policies.

---

# PART XVII — INDEPENDENT ACADEMIC ASSIGNMENT

## 150. ASSIGNMENT TITLE

**Distributed Software Collaboration Using Git, GitHub, SSH Authentication, Pull Requests, and Repository Governance**

Prepare a technical report of approximately 1,600–2,200 words addressing:

1. Introduction to remote Git collaboration.
2. Local and remote repositories.
3. Git remotes.
4. Origin and upstream.
5. GitHub repository creation.
6. Repository visibility.
7. Authentication and authorization.
8. SSH authentication.
9. Personal access tokens.
10. Remote-tracking branches.
11. Fetch, pull, and push.
12. Non-fast-forward rejection.
13. Feature branch workflows.
14. Pull requests.
15. Code reviews.
16. Merge strategies.
17. Required checks.
18. Protected branches.
19. Repository rulesets.
20. CODEOWNERS.
21. Forking.
22. Open-source contributions.
23. Issues and milestones.
24. GitHub Projects.
25. Technical conclusion.

Include:

- A local-to-remote architecture diagram.
- A feature branch workflow diagram.
- A pull-request review diagram.
- A remote-history divergence diagram.
- Screenshots or recorded evidence of the practical exercises.
- A short discussion of repository security.

---

# PART XVIII — GLOSSARY

## 151. TECHNICAL TERMINOLOGY

| Term                       | Definition                                                    |
| -------------------------- | ------------------------------------------------------------- |
| Remote repository          | Git repository accessible through another configured location |
| Origin                     | Common conventional name for primary remote                   |
| Upstream remote            | Common name for an original project associated with a fork    |
| Upstream tracking          | Relationship between local branch and tracked branch          |
| Remote-tracking branch     | Local reference representing last known remote branch state   |
| Fetch                      | Retrieve remote history and references                        |
| Pull                       | Fetch and integrate changes                                   |
| Push                       | Send local reference updates to a remote                      |
| Fast-forward               | Advance a reference without diverged-history merge            |
| Non-fast-forward rejection | Refusal to overwrite remote history with incompatible update  |
| Authentication             | Verification of identity                                      |
| Authorization              | Determination of permitted operations                         |
| SSH                        | Secure Shell                                                  |
| Private key                | Confidential authentication credential                        |
| Public key                 | Shareable key used for public-key verification                |
| PAT                        | Personal Access Token                                         |
| Credential helper          | Tool for storing or retrieving Git credentials                |
| GitHub CLI                 | Command-line interface for GitHub operations                  |
| Pull request               | GitHub proposal and review record for changes                 |
| Base branch                | Destination of a proposed change                              |
| Head branch                | Source of proposed changes                                    |
| Draft PR                   | Pull request not ready for final review                       |
| Code review                | Examination of proposed changes                               |
| Status check               | Automated or external validation result                       |
| Branch protection          | Rules restricting changes to selected branches                |
| Ruleset                    | Repository governance configuration for targeted references   |
| CODEOWNERS                 | File mapping paths to responsible users or teams              |
| Fork                       | GitHub repository created from another GitHub repository      |
| Issue                      | Work-tracking item                                            |
| Label                      | Category applied to tracked work                              |
| Assignee                   | User responsible for tracked work                             |
| Milestone                  | Group of issues or PRs related to a goal                      |
| GitHub Project             | Planning and tracking workspace                               |

---

# PART XIX — THE MOST IMPORTANT COMMANDS TO REMEMBER

## 152. REMOTE GIT COMMAND REFERENCE

```bash
git remote -v

git remote add origin REPOSITORY_URL

git remote set-url origin NEW_URL

git fetch origin

git branch -r

git branch -a

git branch -vv

git pull --ff-only origin main

git push origin main

git push -u origin feature/name

git switch -c feature/name

git merge origin/main

git log --oneline --graph --decorate --all
```

Optional GitHub CLI commands:

```bash
gh auth login

gh auth status

gh repo view

gh issue list

gh issue create

gh pr create

gh pr list

gh pr view --web

gh pr diff

gh pr checks
```

---

# PART XX — FINAL LECTURE SUMMARY

## 153. CENTRAL CONCEPTS

Git manages repository history.

GitHub provides remote hosting and collaboration features.

A remote repository stores history and references that can be exchanged with local repositories.

The `origin` remote commonly identifies the primary hosted repository.

When working with forks, `upstream` commonly identifies the original project.

SSH and HTTPS provide methods for connecting Git clients to GitHub.

Authentication verifies identity.

Authorization determines which repository operations are permitted.

Fetch retrieves remote history without automatically integrating it into the current branch.

Pull fetches and integrates changes according to the selected method.

Push publishes local commits and reference updates.

Remote-tracking branches represent Git's local knowledge of remote branch states.

Feature branches separate proposed work from the main development branch.

Pull requests provide structured review and integration.

Code reviews allow contributors to examine correctness, security, and maintainability.

Automated checks provide repeatable validation.

Merge commits, squash merges, and rebase merges produce different commit-history structures.

Branch protection rules and rulesets help enforce repository policy.

CODEOWNERS assigns responsibility for selected files and can support required review.

Forks allow developers to propose changes to repositories where they do not have direct write permission.

Issues organize bugs and work requirements.

Milestones group related work.

GitHub Projects supports planning and tracking.

These capabilities establish the foundations of professional GitHub collaboration.

---

# 154. FIVE PRINCIPLES TO REMEMBER

**Principle 1:** Git is local version control; GitHub is remote hosting and collaboration.

**Principle 2:** Fetch retrieves, pull integrates, and push publishes.

**Principle 3:** Feature branches and pull requests allow changes to be reviewed before integration.

**Principle 4:** Authentication proves identity, while authorization controls permissions.

**Principle 5:** Professional collaboration requires more than commits: clear issues, focused PRs, reviews, tests, protected branches, and documented decisions.

---

# PART XXI — REFERENCES

## Official Git and GitHub Documentation

[1] Git Project. _Git Documentation._  
https://git-scm.com/docs

[2] Chacon, Scott, and Ben Straub. _Pro Git, Second Edition._  
https://git-scm.com/book/en/v2

[3] GitHub. _About Authentication to GitHub._  
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github

[4] GitHub. _Generating a New SSH Key and Adding It to the SSH Agent._  
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

[5] GitHub. _Testing Your SSH Connection._  
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection

[6] GitHub. _Managing Personal Access Tokens._  
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

[7] GitHub. _Pull Requests Documentation._  
https://docs.github.com/en/pull-requests

[8] GitHub. _Pull Request Merges._  
https://docs.github.com/en/pull-requests/reference/pull-request-merges

[9] GitHub. _About Protected Branches._  
https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches

[10] GitHub. _Managing Rulesets._  
https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets

[11] GitHub. _About Code Owners._  
https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners

[12] GitHub. _Work with Forks._  
https://docs.github.com/en/pull-requests/how-tos/work-with-forks

[13] GitHub. _Creating an Issue._  
https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue

[14] GitHub. _GitHub Projects Quickstart._  
https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/quickstart-for-projects

[15] GitHub CLI. _CLI Manual._  
https://cli.github.com/manual/

---

# 155. FINAL CONCLUSION

This lecture extends the local Git foundations established in Major Lecture 01 into remote software collaboration.

The student has examined the difference between local and remote repository history, Git remote configuration, SSH and HTTPS authentication, branch tracking, fetching, pulling, and pushing.

The lecture demonstrates why remote Git operations must preserve existing history and why concurrent development can produce non-fast-forward rejections or merge conflicts.

GitHub collaboration introduces additional processes around Git history.

Feature branches allow changes to be developed independently.

Pull requests provide structured proposals for integrating changes.

Code reviews and automated status checks help evaluate correctness and quality before merge.

Different merge methods produce different historical structures.

Protected branches, repository rulesets, and CODEOWNERS support organizational governance.

Forks provide a method for proposing changes to projects where contributors do not possess direct write access.

Issues, labels, milestones, and GitHub Projects extend the development workflow into task planning and coordination.

The practical laboratory combines these concepts into an end-to-end GitHub collaboration process.

The student creates a repository, authenticates, publishes code, implements a feature, opens a pull request, inspects automated checks, merges changes, simulates concurrent development, resolves conflicts, and explores repository governance.

These are foundational skills for professional software engineering teams.

The next lecture will examine advanced Git operations and automated development workflows.

It will include rebase, interactive history editing, cherry-pick, stash, bisect, advanced recovery, Git tags and releases, GitHub Actions, secrets, caching, artifact management, Git LFS, worktrees, submodules, hooks, and a final professional CI/CD project.

**END OF MAJOR LECTURE 02**

**Next:** Major Lecture 03 — Advanced Git, GitHub Actions, CI/CD, Release Engineering, and Professional Development Workflows.
