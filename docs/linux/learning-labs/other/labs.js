const LABS = [
  {
    "id": "X001",
    "topic": "File permissions",
    "title": "Make a token owner-only",
    "scenario": "A copied service token is readable and writable by everyone. Restrict access to its owner and inspect the result.",
    "solution": [
      "chmod 600 /srv/app/secret.env",
      "ls -l /srv/app/secret.env"
    ],
    "goals": [
      {
        "label": "Token mode is 600",
        "rule": [
          "mode",
          "/srv/app/secret.env",
          "600"
        ]
      },
      {
        "label": "Inspect the protected token metadata",
        "rule": [
          "seen",
          "ls:/srv/app/secret.env"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X002",
    "topic": "File permissions",
    "title": "Publish a read-only notice",
    "scenario": "A notice should be readable by all users but writable only by its owner. Remove its executable bit.",
    "solution": [
      "chmod 644 /srv/app/notice.txt",
      "ls -l /srv/app/notice.txt"
    ],
    "goals": [
      {
        "label": "Notice uses 644",
        "rule": [
          "mode",
          "/srv/app/notice.txt",
          "644"
        ]
      },
      {
        "label": "Inspect notice metadata",
        "rule": [
          "seen",
          "ls:/srv/app/notice.txt"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/notice.txt": {
          "data": "Maintenance at 18:00\n",
          "mode": "777",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X003",
    "topic": "File permissions",
    "title": "Share a group configuration",
    "scenario": "Deployment staff need read access to a configuration. Others should have none.",
    "solution": [
      "chgrp deploy /srv/app/config.ini",
      "chmod 640 /srv/app/config.ini",
      "ls -l /srv/app/config.ini"
    ],
    "goals": [
      {
        "label": "Configuration belongs to deploy",
        "rule": [
          "group",
          "/srv/app/config.ini",
          "deploy"
        ]
      },
      {
        "label": "Only owner can write; group can read",
        "rule": [
          "mode",
          "/srv/app/config.ini",
          "640"
        ]
      },
      {
        "label": "Inspect configuration metadata",
        "rule": [
          "seen",
          "ls:/srv/app/config.ini"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X004",
    "topic": "File permissions",
    "title": "Make a private executable helper",
    "scenario": "A helper contains internal paths. Let its owner execute it while blocking all other access.",
    "solution": [
      "chmod 700 /lab/args.sh",
      "ls -l /lab/args.sh"
    ],
    "goals": [
      {
        "label": "Helper mode is 700",
        "rule": [
          "mode",
          "/lab/args.sh",
          "700"
        ]
      },
      {
        "label": "Inspect helper metadata",
        "rule": [
          "seen",
          "ls:/lab/args.sh"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X005",
    "topic": "Directory permissions",
    "title": "Protect a home workspace",
    "scenario": "The student workspace has inherited a public mode. Permit only the student to traverse it.",
    "solution": [
      "chown student:student /home/student",
      "chmod 700 /home/student",
      "ls -l /home/student"
    ],
    "goals": [
      {
        "label": "Workspace belongs to student",
        "rule": [
          "owner",
          "/home/student",
          "student"
        ]
      },
      {
        "label": "Private directory mode is 700",
        "rule": [
          "mode",
          "/home/student",
          "700"
        ]
      },
      {
        "label": "Inspect the directory",
        "rule": [
          "seen",
          "ls:/home/student"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X006",
    "topic": "Directory permissions",
    "title": "Create a group-inheriting release area",
    "scenario": "New release files should inherit the deploy group. Configure a shared directory with setgid.",
    "solution": [
      "chgrp deploy /srv/releases",
      "chmod 2770 /srv/releases",
      "ls -l /srv/releases"
    ],
    "goals": [
      {
        "label": "Release group is deploy",
        "rule": [
          "group",
          "/srv/releases",
          "deploy"
        ]
      },
      {
        "label": "Setgid and group access are set",
        "rule": [
          "mode",
          "/srv/releases",
          "2770"
        ]
      },
      {
        "label": "Inspect release directory",
        "rule": [
          "seen",
          "ls:/srv/releases"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X007",
    "topic": "Directory permissions",
    "title": "Protect a shared scratch directory",
    "scenario": "Everyone may create files in scratch, but the directory needs the sticky bit to constrain removal of other users’ entries.",
    "solution": [
      "mkdir /srv/scratch",
      "chmod 1777 /srv/scratch",
      "ls -l /srv/scratch"
    ],
    "goals": [
      {
        "label": "Scratch directory exists",
        "rule": [
          "dir",
          "/srv/scratch"
        ]
      },
      {
        "label": "Sticky directory mode is 1777",
        "rule": [
          "mode",
          "/srv/scratch",
          "1777"
        ]
      },
      {
        "label": "Inspect scratch metadata",
        "rule": [
          "seen",
          "ls:/srv/scratch"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "The mode sets policy here; this simulator does not emulate deletion authorization. On Linux the sticky bit restricts who may remove entries.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X008",
    "topic": "Directory permissions",
    "title": "Give a team traversal without listing",
    "scenario": "A handoff directory should allow owner access and group traversal, but no group directory listing.",
    "solution": [
      "chgrp deploy /srv/handoff",
      "chmod 710 /srv/handoff",
      "ls -l /srv/handoff"
    ],
    "goals": [
      {
        "label": "Handoff group is deploy",
        "rule": [
          "group",
          "/srv/handoff",
          "deploy"
        ]
      },
      {
        "label": "Group receives x without r",
        "rule": [
          "mode",
          "/srv/handoff",
          "710"
        ]
      },
      {
        "label": "Inspect handoff metadata",
        "rule": [
          "seen",
          "ls:/srv/handoff"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/handoff": {
          "data": "",
          "mode": "777",
          "owner": "root",
          "group": "root",
          "dir": true
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X009",
    "topic": "Ownership",
    "title": "Return data to the service account",
    "scenario": "A root-run repair left task data under root ownership. Restore the service identity without widening access.",
    "solution": [
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "chmod 640 /srv/app/tasks.txt",
      "ls -l /srv/app/tasks.txt"
    ],
    "goals": [
      {
        "label": "Service owns task data",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Service group owns task data",
        "rule": [
          "group",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Mode remains constrained",
        "rule": [
          "mode",
          "/srv/app/tasks.txt",
          "640"
        ]
      },
      {
        "label": "Inspect task metadata",
        "rule": [
          "seen",
          "ls:/srv/app/tasks.txt"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/tasks.txt": {
          "data": "Inspect logs\nTest restore\n",
          "mode": "600",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X010",
    "topic": "Ownership",
    "title": "Transfer a developer handoff file",
    "scenario": "Sara is taking responsibility for a handoff note. Transfer its ownership while retaining team read access.",
    "solution": [
      "chown sara:deploy /srv/app/handoff.txt",
      "chmod 640 /srv/app/handoff.txt",
      "ls -l /srv/app/handoff.txt"
    ],
    "goals": [
      {
        "label": "Sara owns the note",
        "rule": [
          "owner",
          "/srv/app/handoff.txt",
          "sara"
        ]
      },
      {
        "label": "Deploy group can read",
        "rule": [
          "group",
          "/srv/app/handoff.txt",
          "deploy"
        ]
      },
      {
        "label": "Note mode is 640",
        "rule": [
          "mode",
          "/srv/app/handoff.txt",
          "640"
        ]
      },
      {
        "label": "Inspect note metadata",
        "rule": [
          "seen",
          "ls:/srv/app/handoff.txt"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/handoff.txt": {
          "data": "Handoff\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X011",
    "topic": "Ownership",
    "title": "Repair an SSH directory tree",
    "scenario": "Sara’s public key tree is owned by root. Correct the tree and secure both directory and key file.",
    "solution": [
      "chown -R sara:sara /home/sara/.ssh",
      "chmod 700 /home/sara/.ssh",
      "chmod 600 /home/sara/.ssh/authorized_keys",
      "ls -l /home/sara/.ssh"
    ],
    "goals": [
      {
        "label": "Directory owner corrected",
        "rule": [
          "owner",
          "/home/sara/.ssh",
          "sara"
        ]
      },
      {
        "label": "Key owner corrected",
        "rule": [
          "owner",
          "/home/sara/.ssh/authorized_keys",
          "sara"
        ]
      },
      {
        "label": "Directory protected",
        "rule": [
          "mode",
          "/home/sara/.ssh",
          "700"
        ]
      },
      {
        "label": "Public-key file protected",
        "rule": [
          "mode",
          "/home/sara/.ssh/authorized_keys",
          "600"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X012",
    "topic": "Ownership",
    "title": "Separate executable code from writable data",
    "scenario": "The service should read deployed code but not own it. Give code to root and the data file to opsdemo.",
    "solution": [
      "chown root:root /srv/app/config.ini",
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "chmod 644 /srv/app/config.ini",
      "ls -l /srv/app/tasks.txt"
    ],
    "goals": [
      {
        "label": "Code configuration owned by root",
        "rule": [
          "owner",
          "/srv/app/config.ini",
          "root"
        ]
      },
      {
        "label": "Data owned by service",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Code mode is 644",
        "rule": [
          "mode",
          "/srv/app/config.ini",
          "644"
        ]
      },
      {
        "label": "Inspect separated data ownership",
        "rule": [
          "seen",
          "ls:/srv/app/tasks.txt"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/config.ini": {
          "data": "port=8765\n",
          "mode": "666",
          "owner": "opsdemo",
          "group": "opsdemo",
          "dir": false
        },
        "/srv/app/tasks.txt": {
          "data": "Inspect logs\nTest restore\n",
          "mode": "640",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X013",
    "topic": "User accounts",
    "title": "Onboard an auditor with a home",
    "scenario": "Create a distinct audit account rather than sharing the administrator’s account.",
    "solution": [
      "getent passwd",
      "useradd -m auditor",
      "id auditor"
    ],
    "goals": [
      {
        "label": "Inspect existing accounts",
        "rule": [
          "seen",
          "accounts"
        ]
      },
      {
        "label": "Auditor exists",
        "rule": [
          "user",
          "auditor"
        ]
      },
      {
        "label": "Auditor has a home",
        "rule": [
          "home",
          "auditor"
        ]
      },
      {
        "label": "Inspect new account",
        "rule": [
          "seen",
          "id:auditor"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X014",
    "topic": "User accounts",
    "title": "Create a noninteractive worker identity",
    "scenario": "A batch worker needs an identity and no home directory. This ticket models identity creation only; a real service account also needs an appropriate login shell policy.",
    "solution": [
      "useradd batch",
      "id batch"
    ],
    "goals": [
      {
        "label": "Batch identity exists",
        "rule": [
          "user",
          "batch"
        ]
      },
      {
        "label": "Inspect worker identity",
        "rule": [
          "seen",
          "id:batch"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "useradd without -m does not create a home in this training model. It does not by itself disable interactive login on a real machine.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X015",
    "topic": "User accounts",
    "title": "Create a group before the account handoff",
    "scenario": "Prepare a reporting group, create Rami’s individual account, and grant the reporting membership.",
    "solution": [
      "groupadd reporting",
      "useradd -m rami",
      "usermod -aG reporting rami",
      "id rami"
    ],
    "goals": [
      {
        "label": "Reporting group exists",
        "rule": [
          "groupExists",
          "reporting"
        ]
      },
      {
        "label": "Rami has a home",
        "rule": [
          "home",
          "rami"
        ]
      },
      {
        "label": "Rami joins reporting",
        "rule": [
          "member",
          "rami",
          "reporting"
        ]
      },
      {
        "label": "Inspect Rami identity",
        "rule": [
          "seen",
          "id:rami"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X016",
    "topic": "User accounts",
    "title": "Give two operators individual identities",
    "scenario": "Two operators need separate homes and membership in the same existing deployment team.",
    "solution": [
      "useradd -m lina",
      "useradd -m omar",
      "usermod -aG deploy lina",
      "usermod -aG deploy omar",
      "getent group"
    ],
    "goals": [
      {
        "label": "Lina has a home",
        "rule": [
          "home",
          "lina"
        ]
      },
      {
        "label": "Omar has a home",
        "rule": [
          "home",
          "omar"
        ]
      },
      {
        "label": "Lina joins deploy",
        "rule": [
          "member",
          "lina",
          "deploy"
        ]
      },
      {
        "label": "Omar joins deploy",
        "rule": [
          "member",
          "omar",
          "deploy"
        ]
      },
      {
        "label": "Inspect group database",
        "rule": [
          "seen",
          "groups"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X017",
    "topic": "Group memberships",
    "title": "Add monitoring without removing deployment",
    "scenario": "Sara already belongs to deploy. Add monitoring while preserving her existing team access.",
    "solution": [
      "groupadd monitoring",
      "usermod -aG monitoring sara",
      "id sara"
    ],
    "goals": [
      {
        "label": "Preserve deploy membership",
        "rule": [
          "member",
          "sara",
          "deploy"
        ]
      },
      {
        "label": "Add monitoring membership",
        "rule": [
          "member",
          "sara",
          "monitoring"
        ]
      },
      {
        "label": "Inspect final memberships",
        "rule": [
          "seen",
          "id:sara"
        ]
      }
    ],
    "seed": {
      "users": {
        "sara": {
          "home": "/home/sara",
          "groups": [
            "sara",
            "deploy"
          ]
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X018",
    "topic": "Group memberships",
    "title": "Remove obsolete deployment access",
    "scenario": "An operator has moved to reporting. Remove only the deploy membership.",
    "solution": [
      "gpasswd -d sara deploy",
      "id sara"
    ],
    "goals": [
      {
        "label": "Deploy membership removed",
        "rule": [
          "notMember",
          "sara",
          "deploy"
        ]
      },
      {
        "label": "Primary group retained",
        "rule": [
          "member",
          "sara",
          "sara"
        ]
      },
      {
        "label": "Inspect resulting identity",
        "rule": [
          "seen",
          "id:sara"
        ]
      }
    ],
    "seed": {
      "users": {
        "sara": {
          "home": "/home/sara",
          "groups": [
            "sara",
            "deploy"
          ]
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X019",
    "topic": "Group memberships",
    "title": "Create an incident-response team",
    "scenario": "Create a responders group and add Sara and the student without replacing their existing groups.",
    "solution": [
      "groupadd responders",
      "usermod -aG responders sara",
      "usermod -aG responders student",
      "getent group"
    ],
    "goals": [
      {
        "label": "Response group exists",
        "rule": [
          "groupExists",
          "responders"
        ]
      },
      {
        "label": "Sara is a responder",
        "rule": [
          "member",
          "sara",
          "responders"
        ]
      },
      {
        "label": "Student is a responder",
        "rule": [
          "member",
          "student",
          "responders"
        ]
      },
      {
        "label": "Inspect team database",
        "rule": [
          "seen",
          "groups"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X020",
    "topic": "Group memberships",
    "title": "Keep service and human identities separate",
    "scenario": "The service needs read membership in a logs group. Add it without giving the student that membership.",
    "solution": [
      "groupadd logs",
      "usermod -aG logs opsdemo",
      "id opsdemo",
      "id student"
    ],
    "goals": [
      {
        "label": "Service joins logs",
        "rule": [
          "member",
          "opsdemo",
          "logs"
        ]
      },
      {
        "label": "Student is not added to logs",
        "rule": [
          "notMember",
          "student",
          "logs"
        ]
      },
      {
        "label": "Inspect service identity",
        "rule": [
          "seen",
          "id:opsdemo"
        ]
      },
      {
        "label": "Inspect human identity",
        "rule": [
          "seen",
          "id:student"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X021",
    "topic": "Umask and creation",
    "title": "Default to private artifacts",
    "scenario": "A secret-generation session must create owner-only files and private directories.",
    "solution": [
      "umask 077",
      "mkdir /srv/generated",
      "touch /srv/generated/result.txt",
      "ls -l /srv/generated"
    ],
    "goals": [
      {
        "label": "New directory receives expected mode",
        "rule": [
          "mode",
          "/srv/generated",
          "700"
        ]
      },
      {
        "label": "New ordinary file receives expected mode",
        "rule": [
          "mode",
          "/srv/generated/result.txt",
          "600"
        ]
      },
      {
        "label": "Inspect created entries",
        "rule": [
          "seen",
          "ls:/srv/generated"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Umask removes requested permission bits. Ordinary files begin at 666, directories at 777; it does not grant execute permission to ordinary files.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X022",
    "topic": "Umask and creation",
    "title": "Default to team-readable artifacts",
    "scenario": "A reporting session needs files readable by its group but no access for others.",
    "solution": [
      "umask 027",
      "mkdir /srv/generated",
      "touch /srv/generated/result.txt",
      "ls -l /srv/generated"
    ],
    "goals": [
      {
        "label": "New directory receives expected mode",
        "rule": [
          "mode",
          "/srv/generated",
          "750"
        ]
      },
      {
        "label": "New ordinary file receives expected mode",
        "rule": [
          "mode",
          "/srv/generated/result.txt",
          "640"
        ]
      },
      {
        "label": "Inspect created entries",
        "rule": [
          "seen",
          "ls:/srv/generated"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Umask removes requested permission bits. Ordinary files begin at 666, directories at 777; it does not grant execute permission to ordinary files.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X023",
    "topic": "Umask and creation",
    "title": "Default to public-readable artifacts",
    "scenario": "A documentation build should create readable files without making them executable.",
    "solution": [
      "umask 022",
      "mkdir /srv/generated",
      "touch /srv/generated/result.txt",
      "ls -l /srv/generated"
    ],
    "goals": [
      {
        "label": "New directory receives expected mode",
        "rule": [
          "mode",
          "/srv/generated",
          "755"
        ]
      },
      {
        "label": "New ordinary file receives expected mode",
        "rule": [
          "mode",
          "/srv/generated/result.txt",
          "644"
        ]
      },
      {
        "label": "Inspect created entries",
        "rule": [
          "seen",
          "ls:/srv/generated"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Umask removes requested permission bits. Ordinary files begin at 666, directories at 777; it does not grant execute permission to ordinary files.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X024",
    "topic": "Umask and creation",
    "title": "Default to collaborative artifacts",
    "scenario": "A shared development session needs group-writable files and directories.",
    "solution": [
      "umask 002",
      "mkdir /srv/generated",
      "touch /srv/generated/result.txt",
      "ls -l /srv/generated"
    ],
    "goals": [
      {
        "label": "New directory receives expected mode",
        "rule": [
          "mode",
          "/srv/generated",
          "775"
        ]
      },
      {
        "label": "New ordinary file receives expected mode",
        "rule": [
          "mode",
          "/srv/generated/result.txt",
          "664"
        ]
      },
      {
        "label": "Inspect created entries",
        "rule": [
          "seen",
          "ls:/srv/generated"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Umask removes requested permission bits. Ordinary files begin at 666, directories at 777; it does not grant execute permission to ordinary files.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X025",
    "topic": "Named-user ACLs",
    "title": "Let an auditor read one configuration",
    "scenario": "Grant Sara read-only ACL access without changing the file’s owning group.",
    "solution": [
      "setfacl -m u:sara:r-- /srv/app/config.ini",
      "getfacl /srv/app/config.ini"
    ],
    "goals": [
      {
        "label": "Sara has named read permission",
        "rule": [
          "acl",
          "/srv/app/config.ini",
          "sara",
          "r--"
        ]
      },
      {
        "label": "Inspect stored ACL",
        "rule": [
          "seen",
          "acl:/srv/app/config.ini"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X026",
    "topic": "Named-user ACLs",
    "title": "Grant directory traversal to a collaborator",
    "scenario": "Sara needs to list and traverse release files without writing into the release directory.",
    "solution": [
      "setfacl -m u:sara:r-x /srv/releases",
      "getfacl /srv/releases"
    ],
    "goals": [
      {
        "label": "Sara receives r-x on the directory",
        "rule": [
          "acl",
          "/srv/releases",
          "sara",
          "r-x"
        ]
      },
      {
        "label": "Inspect release ACL",
        "rule": [
          "seen",
          "acl:/srv/releases"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X027",
    "topic": "Named-user ACLs",
    "title": "Grant service read access to a report",
    "scenario": "Keep root ownership while adding a named ACL for the service identity.",
    "solution": [
      "setfacl -m u:opsdemo:r-- /srv/app/report.txt",
      "getfacl /srv/app/report.txt",
      "ls -l /srv/app/report.txt"
    ],
    "goals": [
      {
        "label": "Service gets named read access",
        "rule": [
          "acl",
          "/srv/app/report.txt",
          "opsdemo",
          "r--"
        ]
      },
      {
        "label": "Root remains owner",
        "rule": [
          "owner",
          "/srv/app/report.txt",
          "root"
        ]
      },
      {
        "label": "Inspect report ACL",
        "rule": [
          "seen",
          "acl:/srv/app/report.txt"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/report.txt": {
          "data": "Daily report\n",
          "mode": "600",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X028",
    "topic": "Named-user ACLs",
    "title": "Revoke a temporary named ACL grant",
    "scenario": "A temporary maintenance window has ended. Set Sara’s named entry to no access and inspect it.",
    "solution": [
      "setfacl -m u:sara:--- /srv/app/config.ini",
      "getfacl /srv/app/config.ini"
    ],
    "goals": [
      {
        "label": "Named grant has no permissions",
        "rule": [
          "acl",
          "/srv/app/config.ini",
          "sara",
          "---"
        ]
      },
      {
        "label": "Inspect revoked grant",
        "rule": [
          "seen",
          "acl:/srv/app/config.ini"
        ]
      }
    ],
    "seed": {
      "acls": {
        "/srv/app/config.ini": {
          "sara": "rw-"
        }
      }
    },
    "edits": {},
    "hint": "The simulator models named user entries with an automatically widened mask. Real getfacl also shows effective rights and ACL masks. A named --- entry is different from deleting the entry.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X029",
    "topic": "Process signals",
    "title": "Gracefully stop a background report",
    "scenario": "Identify the report process before sending a catchable termination request.",
    "solution": [
      "pgrep report",
      "kill -TERM 5000",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Locate report PID",
        "rule": [
          "seen",
          "pgrep:report"
        ]
      },
      {
        "label": "Report has exited",
        "rule": [
          "procGone",
          "5000"
        ]
      },
      {
        "label": "SIGTERM used",
        "rule": [
          "signal",
          "5000",
          "TERM"
        ]
      },
      {
        "label": "Inspect remaining processes",
        "rule": [
          "seen",
          "processes"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X030",
    "topic": "Process signals",
    "title": "Escalate an unresponsive worker",
    "scenario": "The ticket records that a previous graceful request timed out. Identify the worker and use the forced signal authorized for this simulation.",
    "solution": [
      "pgrep worker",
      "kill -KILL 4242",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Locate worker",
        "rule": [
          "seen",
          "pgrep:worker"
        ]
      },
      {
        "label": "Worker removed",
        "rule": [
          "procGone",
          "4242"
        ]
      },
      {
        "label": "Forced signal used",
        "rule": [
          "signal",
          "4242",
          "KILL"
        ]
      },
      {
        "label": "Inspect survivors",
        "rule": [
          "seen",
          "processes"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "SIGKILL cannot be caught and prevents process cleanup. This scenario explicitly assumes a prior failed graceful stop.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X031",
    "topic": "Process signals",
    "title": "Stop one worker without killing another",
    "scenario": "Two separate jobs are running. Stop the report while preserving the worker for unrelated requests.",
    "solution": [
      "ps -ef",
      "kill -TERM 5000",
      "pgrep worker"
    ],
    "goals": [
      {
        "label": "Report stopped",
        "rule": [
          "procGone",
          "5000"
        ]
      },
      {
        "label": "Worker still running",
        "rule": [
          "procExists",
          "4242"
        ]
      },
      {
        "label": "Inspect worker survivor",
        "rule": [
          "seen",
          "pgrep:worker"
        ]
      },
      {
        "label": "Inspect process list",
        "rule": [
          "seen",
          "processes"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X032",
    "topic": "Process signals",
    "title": "Drain two retired jobs",
    "scenario": "Both training background jobs belong to a retired batch. Inspect and gracefully terminate each PID.",
    "solution": [
      "ps -ef",
      "kill -TERM 4242",
      "kill -TERM 5000"
    ],
    "goals": [
      {
        "label": "Inspect initial processes",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Worker stopped",
        "rule": [
          "procGone",
          "4242"
        ]
      },
      {
        "label": "Report stopped",
        "rule": [
          "procGone",
          "5000"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X033",
    "topic": "Scheduling priority",
    "title": "Deprioritize a CPU-heavy report",
    "scenario": "A nonurgent report competes with interactive work. Lower its scheduling priority without killing it.",
    "solution": [
      "ps -ef",
      "renice -n 10 -p 5000",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Inspect process evidence",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Selected process has the intended nice value",
        "rule": [
          "nice",
          "5000",
          10
        ]
      }
    ],
    "seed": {
      "processes": {
        "5000": {
          "name": "report",
          "nice": 0
        }
      }
    },
    "edits": {},
    "hint": "A larger nice value means lower scheduling priority; nice is not a CPU quota. Lowering the numerical nice value can require additional privilege on real Linux.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X034",
    "topic": "Scheduling priority",
    "title": "Keep a background worker polite",
    "scenario": "A maintenance worker may continue but should have the lowest normal nice priority.",
    "solution": [
      "ps -ef",
      "renice -n 19 -p 4242",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Inspect process evidence",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Selected process has the intended nice value",
        "rule": [
          "nice",
          "4242",
          19
        ]
      }
    ],
    "seed": {
      "processes": {
        "4242": {
          "name": "worker",
          "nice": 0
        }
      }
    },
    "edits": {},
    "hint": "A larger nice value means lower scheduling priority; nice is not a CPU quota. Lowering the numerical nice value can require additional privilege on real Linux.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X035",
    "topic": "Scheduling priority",
    "title": "Use a moderate batch priority",
    "scenario": "A reporting job needs a modest priority reduction rather than the maximum adjustment.",
    "solution": [
      "ps -ef",
      "renice -n 5 -p 5000",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Inspect process evidence",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Selected process has the intended nice value",
        "rule": [
          "nice",
          "5000",
          5
        ]
      }
    ],
    "seed": {
      "processes": {
        "5000": {
          "name": "report",
          "nice": 0
        }
      }
    },
    "edits": {},
    "hint": "A larger nice value means lower scheduling priority; nice is not a CPU quota. Lowering the numerical nice value can require additional privilege on real Linux.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X036",
    "topic": "Scheduling priority",
    "title": "Return a simulated worker to normal priority",
    "scenario": "A worker inherited nice 15. In this authorized simulation restore its normal priority.",
    "solution": [
      "ps -ef",
      "renice -n 0 -p 4242",
      "ps -ef"
    ],
    "goals": [
      {
        "label": "Inspect process evidence",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Selected process has the intended nice value",
        "rule": [
          "nice",
          "4242",
          0
        ]
      }
    ],
    "seed": {
      "processes": {
        "4242": {
          "name": "worker",
          "nice": 15
        }
      }
    },
    "edits": {},
    "hint": "A larger nice value means lower scheduling priority; nice is not a CPU quota. Lowering the numerical nice value can require additional privilege on real Linux.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X037",
    "topic": "Service lifecycle",
    "title": "Start a disabled application for this session",
    "scenario": "The application is stopped. Bring it up while leaving its boot policy disabled.",
    "solution": [
      "systemctl status opsdemo",
      "systemctl start opsdemo",
      "curl http://127.0.0.1:8765/healthz"
    ],
    "goals": [
      {
        "label": "Inspect app state",
        "rule": [
          "seen",
          "status:opsdemo"
        ]
      },
      {
        "label": "Application active",
        "rule": [
          "service",
          "opsdemo",
          "active",
          true
        ]
      },
      {
        "label": "Boot activation stays disabled",
        "rule": [
          "service",
          "opsdemo",
          "enabled",
          false
        ]
      },
      {
        "label": "Verify liveness",
        "rule": [
          "seen",
          "health"
        ]
      }
    ],
    "seed": {
      "services": {
        "opsdemo": {
          "active": false,
          "enabled": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X038",
    "topic": "Service lifecycle",
    "title": "Persist application startup across boots",
    "scenario": "The application is running manually. Configure startup and verify the enabled state.",
    "solution": [
      "systemctl enable opsdemo",
      "systemctl status opsdemo"
    ],
    "goals": [
      {
        "label": "Startup enabled",
        "rule": [
          "service",
          "opsdemo",
          "enabled",
          true
        ]
      },
      {
        "label": "Inspect enabled service",
        "rule": [
          "seen",
          "status:opsdemo"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X039",
    "topic": "Service lifecycle",
    "title": "Disable future startup without stopping now",
    "scenario": "A service must finish current work but should not return automatically after the next reboot.",
    "solution": [
      "systemctl disable opsdemo",
      "systemctl status opsdemo"
    ],
    "goals": [
      {
        "label": "Boot activation disabled",
        "rule": [
          "service",
          "opsdemo",
          "enabled",
          false
        ]
      },
      {
        "label": "Current process stays active",
        "rule": [
          "service",
          "opsdemo",
          "active",
          true
        ]
      },
      {
        "label": "Inspect service state",
        "rule": [
          "seen",
          "status:opsdemo"
        ]
      }
    ],
    "seed": {
      "services": {
        "opsdemo": {
          "active": true,
          "enabled": true
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X040",
    "topic": "Service lifecycle",
    "title": "Stop an application for maintenance",
    "scenario": "Perform a planned stop while preserving its enabled boot policy for the next startup.",
    "solution": [
      "systemctl stop opsdemo",
      "systemctl status opsdemo"
    ],
    "goals": [
      {
        "label": "Application inactive",
        "rule": [
          "service",
          "opsdemo",
          "active",
          false
        ]
      },
      {
        "label": "Boot policy preserved",
        "rule": [
          "service",
          "opsdemo",
          "enabled",
          true
        ]
      },
      {
        "label": "Inspect stopped state",
        "rule": [
          "seen",
          "status:opsdemo"
        ]
      }
    ],
    "seed": {
      "services": {
        "opsdemo": {
          "active": true,
          "enabled": true
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X041",
    "topic": "Log investigation",
    "title": "Collect a backend incident bundle",
    "scenario": "An application is slow. Gather process, memory and service journal evidence before changing it.",
    "solution": [
      "journalctl -u opsdemo",
      "ps -ef",
      "free -h"
    ],
    "goals": [
      {
        "label": "Inspect service events",
        "rule": [
          "seen",
          "journal:opsdemo"
        ]
      },
      {
        "label": "Inspect process list",
        "rule": [
          "seen",
          "processes"
        ]
      },
      {
        "label": "Inspect host memory",
        "rule": [
          "seen",
          "memory"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X042",
    "topic": "Log investigation",
    "title": "Separate kernel and service failures",
    "scenario": "A service disappeared. Compare kernel evidence with service events and resource limits.",
    "solution": [
      "journalctl -k",
      "journalctl -u opsdemo",
      "systemctl show opsdemo"
    ],
    "goals": [
      {
        "label": "Inspect kernel evidence",
        "rule": [
          "seen",
          "kernelLog"
        ]
      },
      {
        "label": "Inspect application events",
        "rule": [
          "seen",
          "journal:opsdemo"
        ]
      },
      {
        "label": "Inspect configured limit",
        "rule": [
          "seen",
          "limits"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X043",
    "topic": "Log investigation",
    "title": "Trace a reverse-proxy connection failure",
    "scenario": "The frontend has an upstream connection error. Inspect its journal and the actual TCP listeners.",
    "solution": [
      "journalctl -u nginx",
      "ss -lntp",
      "systemctl status opsdemo"
    ],
    "goals": [
      {
        "label": "Inspect proxy error",
        "rule": [
          "seen",
          "journal:nginx"
        ]
      },
      {
        "label": "Inspect sockets",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Inspect backend state",
        "rule": [
          "seen",
          "status:opsdemo"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X044",
    "topic": "Log investigation",
    "title": "Verify a oneshot job from its journal",
    "scenario": "The backup service is inactive. Run it and distinguish a successful completed oneshot from a failed daemon.",
    "solution": [
      "systemctl start backup",
      "systemctl status backup",
      "journalctl -u backup"
    ],
    "goals": [
      {
        "label": "Backup ran successfully",
        "rule": [
          "seen",
          "backupRan"
        ]
      },
      {
        "label": "Inspect inactive oneshot state",
        "rule": [
          "seen",
          "status:backup.service"
        ]
      },
      {
        "label": "Inspect completion journal",
        "rule": [
          "seen",
          "journal:backup"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X045",
    "topic": "Connectivity and DNS",
    "title": "Restore a dropped interface",
    "scenario": "The default route and resolver exist, but eth0 is down. Inspect link state and bring the interface back.",
    "solution": [
      "ip addr",
      "ip link set eth0 up",
      "getent hosts app.example.test"
    ],
    "goals": [
      {
        "label": "Inspect interface address state",
        "rule": [
          "seen",
          "addresses"
        ]
      },
      {
        "label": "Interface is up",
        "rule": [
          "value",
          "link",
          true
        ]
      },
      {
        "label": "Resolve service name",
        "rule": [
          "seen",
          "resolved"
        ]
      }
    ],
    "seed": {
      "link": false,
      "dns": "1.1.1.1"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X046",
    "topic": "Connectivity and DNS",
    "title": "Repair a missing resolver",
    "scenario": "The host has an address and route but lacks a DNS resolver. Apply the training resolver and test a name.",
    "solution": [
      "ip route",
      "resolvectl status",
      "resolvectl dns eth0 1.1.1.1",
      "getent hosts app.example.test"
    ],
    "goals": [
      {
        "label": "Inspect routing",
        "rule": [
          "seen",
          "routes"
        ]
      },
      {
        "label": "Inspect DNS configuration",
        "rule": [
          "seen",
          "resolver"
        ]
      },
      {
        "label": "Configure resolver",
        "rule": [
          "value",
          "dns",
          "1.1.1.1"
        ]
      },
      {
        "label": "Verify name resolution",
        "rule": [
          "seen",
          "resolved"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X047",
    "topic": "Connectivity and DNS",
    "title": "Record a complete network baseline",
    "scenario": "Capture interface, route, resolver and socket state on a working training host.",
    "solution": [
      "ip addr",
      "ip route",
      "resolvectl status",
      "ss -lntp"
    ],
    "goals": [
      {
        "label": "Record addressing",
        "rule": [
          "seen",
          "addresses"
        ]
      },
      {
        "label": "Record routing",
        "rule": [
          "seen",
          "routes"
        ]
      },
      {
        "label": "Record resolver",
        "rule": [
          "seen",
          "resolver"
        ]
      },
      {
        "label": "Record listeners",
        "rule": [
          "seen",
          "sockets"
        ]
      }
    ],
    "seed": {
      "dns": "1.1.1.1"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X048",
    "topic": "Connectivity and DNS",
    "title": "Verify application traffic after DNS repair",
    "scenario": "A name lookup fails even though the backend is running. Repair DNS and prove an application request by name.",
    "solution": [
      "resolvectl dns eth0 1.1.1.1",
      "getent hosts app.example.test",
      "curl http://app.example.test:8765/healthz"
    ],
    "goals": [
      {
        "label": "Resolve the name",
        "rule": [
          "seen",
          "resolved"
        ]
      },
      {
        "label": "Backend answers by name",
        "rule": [
          "seen",
          "health"
        ]
      },
      {
        "label": "Resolver is configured",
        "rule": [
          "value",
          "dns",
          "1.1.1.1"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X049",
    "topic": "Listeners and endpoints",
    "title": "Locate the private backend listener",
    "scenario": "Verify that the application listens on loopback and can serve a direct health request.",
    "solution": [
      "ss -lntp",
      "curl http://127.0.0.1:8765/healthz"
    ],
    "goals": [
      {
        "label": "Inspect listening addresses",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Probe direct backend",
        "rule": [
          "seen",
          "health"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X050",
    "topic": "Listeners and endpoints",
    "title": "Restore a missing backend listener",
    "scenario": "Nginx exists but its backend is stopped. Start the missing service and verify its direct endpoint.",
    "solution": [
      "ss -lntp",
      "systemctl start opsdemo",
      "curl http://127.0.0.1:8765/healthz"
    ],
    "goals": [
      {
        "label": "Inspect sockets before repair",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Backend active",
        "rule": [
          "service",
          "opsdemo",
          "active",
          true
        ]
      },
      {
        "label": "Direct endpoint healthy",
        "rule": [
          "seen",
          "health"
        ]
      }
    ],
    "seed": {
      "services": {
        "opsdemo": {
          "active": false,
          "enabled": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X051",
    "topic": "Listeners and endpoints",
    "title": "Compare the backend and proxy endpoints",
    "scenario": "Both layers should answer. Capture socket state and verify the direct and proxied liveness paths.",
    "solution": [
      "ss -lntp",
      "curl http://127.0.0.1:8765/healthz",
      "curl http://127.0.0.1:8080/healthz"
    ],
    "goals": [
      {
        "label": "Inspect listeners",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Direct probe succeeds",
        "rule": [
          "seen",
          "health"
        ]
      },
      {
        "label": "Proxy probe succeeds",
        "rule": [
          "seen",
          "proxyHealth"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/nginx/app.conf": {
          "data": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X052",
    "topic": "Listeners and endpoints",
    "title": "Inspect the release served by the process",
    "scenario": "The running release may differ from the filesystem pointer. Inspect both plus the listener.",
    "solution": [
      "readlink /opt/opsdemo/current",
      "ss -lntp",
      "curl http://127.0.0.1:8765/api/info"
    ],
    "goals": [
      {
        "label": "Inspect release pointer",
        "rule": [
          "seen",
          "releasePointer"
        ]
      },
      {
        "label": "Inspect listener",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Observe running v2 release",
        "rule": [
          "all",
          [
            "seen",
            "version"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X053",
    "topic": "SSH hardening",
    "title": "Disable direct root SSH login",
    "scenario": "Individual keys already work. Remove direct root login and inspect the effective policy.",
    "solution": [
      "ssh -o PreferredAuthentications=publickey sara@server.test",
      "edit /etc/ssh/sshd_config",
      "sshd -t",
      "systemctl reload ssh",
      "sshd -T"
    ],
    "goals": [
      {
        "label": "Test independent public-key connection",
        "rule": [
          "seen",
          "keyLogin"
        ]
      },
      {
        "label": "Validate saved policy",
        "rule": [
          "seen",
          "sshValidated"
        ]
      },
      {
        "label": "Inspect effective policy",
        "rule": [
          "seen",
          "effectiveSSH"
        ]
      },
      {
        "label": "Selected SSH setting is disabled",
        "rule": [
          "ssh",
          "PermitRootLogin",
          "no"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/ssh/sshd_config": "PubkeyAuthentication yes\nPermitRootLogin no\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\n"
    },
    "hint": "Keep recovery access and an existing session on real hosts. The lab models one SSH config file on port 22, without drop-ins, PAM or Match blocks.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X054",
    "topic": "SSH hardening",
    "title": "Remove SSH password authentication",
    "scenario": "A second key session is available. Disable password authentication without changing the working key method.",
    "solution": [
      "ssh -o PreferredAuthentications=publickey sara@server.test",
      "edit /etc/ssh/sshd_config",
      "sshd -t",
      "systemctl reload ssh",
      "sshd -T"
    ],
    "goals": [
      {
        "label": "Test independent public-key connection",
        "rule": [
          "seen",
          "keyLogin"
        ]
      },
      {
        "label": "Validate saved policy",
        "rule": [
          "seen",
          "sshValidated"
        ]
      },
      {
        "label": "Inspect effective policy",
        "rule": [
          "seen",
          "effectiveSSH"
        ]
      },
      {
        "label": "Selected SSH setting is disabled",
        "rule": [
          "ssh",
          "PasswordAuthentication",
          "no"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/ssh/sshd_config": "PubkeyAuthentication yes\nPermitRootLogin yes\nPasswordAuthentication no\nKbdInteractiveAuthentication yes\n"
    },
    "hint": "Keep recovery access and an existing session on real hosts. The lab models one SSH config file on port 22, without drop-ins, PAM or Match blocks.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X055",
    "topic": "SSH hardening",
    "title": "Remove keyboard-interactive login",
    "scenario": "The key path is verified. Disable keyboard-interactive authentication for this single-file training policy.",
    "solution": [
      "ssh -o PreferredAuthentications=publickey sara@server.test",
      "edit /etc/ssh/sshd_config",
      "sshd -t",
      "systemctl reload ssh",
      "sshd -T"
    ],
    "goals": [
      {
        "label": "Test independent public-key connection",
        "rule": [
          "seen",
          "keyLogin"
        ]
      },
      {
        "label": "Validate saved policy",
        "rule": [
          "seen",
          "sshValidated"
        ]
      },
      {
        "label": "Inspect effective policy",
        "rule": [
          "seen",
          "effectiveSSH"
        ]
      },
      {
        "label": "Selected SSH setting is disabled",
        "rule": [
          "ssh",
          "KbdInteractiveAuthentication",
          "no"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/ssh/sshd_config": "PubkeyAuthentication yes\nPermitRootLogin yes\nPasswordAuthentication yes\nKbdInteractiveAuthentication no\n"
    },
    "hint": "Keep recovery access and an existing session on real hosts. The lab models one SSH config file on port 22, without drop-ins, PAM or Match blocks.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X056",
    "topic": "SSH hardening",
    "title": "Complete a key-only SSH policy",
    "scenario": "Replace all permissive root and password settings after verifying the independent key connection.",
    "solution": [
      "ssh -o PreferredAuthentications=publickey sara@server.test",
      "edit /etc/ssh/sshd_config",
      "sshd -t",
      "systemctl reload ssh",
      "sshd -T"
    ],
    "goals": [
      {
        "label": "Test independent public-key connection",
        "rule": [
          "seen",
          "keyLogin"
        ]
      },
      {
        "label": "Validate saved policy",
        "rule": [
          "seen",
          "sshValidated"
        ]
      },
      {
        "label": "Inspect effective policy",
        "rule": [
          "seen",
          "effectiveSSH"
        ]
      },
      {
        "label": "All insecure authentication paths disabled",
        "rule": [
          "all",
          [
            "ssh",
            "PermitRootLogin",
            "no"
          ],
          [
            "ssh",
            "PasswordAuthentication",
            "no"
          ],
          [
            "ssh",
            "KbdInteractiveAuthentication",
            "no"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/ssh/sshd_config": "PubkeyAuthentication yes\nPermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n"
    },
    "hint": "Keep recovery access and an existing session on real hosts. The lab models one SSH config file on port 22, without drop-ins, PAM or Match blocks.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X057",
    "topic": "Inbound firewall",
    "title": "Enable SSH-only inbound access",
    "scenario": "Protect a management host using default-deny inbound policy and a single SSH exception.",
    "solution": [
      "ufw allow 22/tcp",
      "ufw default deny incoming",
      "ufw enable",
      "ufw status verbose"
    ],
    "goals": [
      {
        "label": "SSH allowed",
        "rule": [
          "allow",
          "22"
        ]
      },
      {
        "label": "Incoming policy denies by default",
        "rule": [
          "value",
          "policy",
          "deny"
        ]
      },
      {
        "label": "Firewall active",
        "rule": [
          "value",
          "firewall",
          true
        ]
      },
      {
        "label": "Inspect resulting rules",
        "rule": [
          "seen",
          "firewall"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X058",
    "topic": "Inbound firewall",
    "title": "Expose HTTPS while retaining management",
    "scenario": "Add public HTTPS to an existing SSH management policy.",
    "solution": [
      "ufw allow 443/tcp",
      "ufw status verbose"
    ],
    "goals": [
      {
        "label": "HTTPS allowed",
        "rule": [
          "allow",
          "443"
        ]
      },
      {
        "label": "SSH remains allowed",
        "rule": [
          "allow",
          "22"
        ]
      },
      {
        "label": "Inspect rule state",
        "rule": [
          "seen",
          "firewall"
        ]
      }
    ],
    "seed": {
      "rules": [
        "22"
      ],
      "firewall": true,
      "policy": "deny"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X059",
    "topic": "Inbound firewall",
    "title": "Close an accidentally exposed backend",
    "scenario": "An application’s loopback backend also has an unnecessary host firewall exception. Remove it while retaining SSH and HTTPS.",
    "solution": [
      "ufw delete allow 8765/tcp",
      "ufw status verbose"
    ],
    "goals": [
      {
        "label": "Backend exception removed",
        "rule": [
          "blockedPort",
          "8765"
        ]
      },
      {
        "label": "Keep SSH rule",
        "rule": [
          "allow",
          "22"
        ]
      },
      {
        "label": "Keep HTTPS rule",
        "rule": [
          "allow",
          "443"
        ]
      },
      {
        "label": "Inspect revised policy",
        "rule": [
          "seen",
          "firewall"
        ]
      }
    ],
    "seed": {
      "rules": [
        "22",
        "443",
        "8765"
      ],
      "firewall": true,
      "policy": "deny"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X060",
    "topic": "Inbound firewall",
    "title": "Migrate a public HTTP exception to HTTPS",
    "scenario": "A frontend no longer serves public port 80. Replace its rule with HTTPS while preserving management.",
    "solution": [
      "ufw allow 443/tcp",
      "ufw delete allow 80/tcp",
      "ufw status verbose"
    ],
    "goals": [
      {
        "label": "HTTPS allowed",
        "rule": [
          "allow",
          "443"
        ]
      },
      {
        "label": "HTTP exception removed",
        "rule": [
          "blockedPort",
          "80"
        ]
      },
      {
        "label": "SSH preserved",
        "rule": [
          "allow",
          "22"
        ]
      },
      {
        "label": "Inspect final policy",
        "rule": [
          "seen",
          "firewall"
        ]
      }
    ],
    "seed": {
      "rules": [
        "22",
        "80"
      ],
      "firewall": true,
      "policy": "deny"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X061",
    "topic": "Storage triage",
    "title": "Distinguish block capacity from inode pressure",
    "scenario": "A server refuses small new files. Gather both byte and inode capacity before recommending a fix.",
    "solution": [
      "df -h",
      "df -i"
    ],
    "goals": [
      {
        "label": "Inspect byte capacity",
        "rule": [
          "seen",
          "capacity"
        ]
      },
      {
        "label": "Inspect inode capacity",
        "rule": [
          "seen",
          "inodes"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X062",
    "topic": "Storage triage",
    "title": "Map a device to its mounted filesystem",
    "scenario": "A ticket identifies /data but not its underlying device. Inspect block devices and the mount table.",
    "solution": [
      "lsblk",
      "findmnt",
      "cat /etc/fstab"
    ],
    "goals": [
      {
        "label": "Inspect devices",
        "rule": [
          "seen",
          "devices"
        ]
      },
      {
        "label": "Inspect active mount",
        "rule": [
          "seen",
          "mounts"
        ]
      },
      {
        "label": "Inspect persistent mount definition",
        "rule": [
          "seen",
          "cat:/etc/fstab"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X063",
    "topic": "Storage triage",
    "title": "Investigate log-directory growth",
    "scenario": "Filesystem usage is increasing. Compare filesystem capacity with the log directory’s own size.",
    "solution": [
      "df -h",
      "du -sh /var/log",
      "ls -l /var/log"
    ],
    "goals": [
      {
        "label": "Inspect filesystem capacity",
        "rule": [
          "seen",
          "capacity"
        ]
      },
      {
        "label": "Measure log directory",
        "rule": [
          "seen",
          "logSize"
        ]
      },
      {
        "label": "Inspect log entries",
        "rule": [
          "seen",
          "ls:/var/log"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X064",
    "topic": "Storage triage",
    "title": "Audit a persistent mount safely",
    "scenario": "Review the active mount, fstab identity and block-device layout without writing disk metadata.",
    "solution": [
      "findmnt",
      "cat /etc/fstab",
      "lsblk",
      "df -i"
    ],
    "goals": [
      {
        "label": "Read active mount",
        "rule": [
          "seen",
          "mounts"
        ]
      },
      {
        "label": "Read fstab",
        "rule": [
          "seen",
          "cat:/etc/fstab"
        ]
      },
      {
        "label": "Inspect device mapping",
        "rule": [
          "seen",
          "devices"
        ]
      },
      {
        "label": "Inspect inode headroom",
        "rule": [
          "seen",
          "inodes"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X065",
    "topic": "LVM growth",
    "title": "Grow a volume and ext4 together by 2 GiB",
    "scenario": "The 10 GiB data volume has enough free extents. Grow both layers to 12 GiB and verify filesystem capacity.",
    "solution": [
      "vgs",
      "lvextend -r -L +2G /dev/vg0/data",
      "df -h"
    ],
    "goals": [
      {
        "label": "Inspect free extents",
        "rule": [
          "seen",
          "vgs"
        ]
      },
      {
        "label": "LV is 12 GiB",
        "rule": [
          "value",
          "lv",
          12
        ]
      },
      {
        "label": "Filesystem is 12 GiB",
        "rule": [
          "value",
          "filesystem",
          12
        ]
      },
      {
        "label": "Verify capacity",
        "rule": [
          "seen",
          "capacity"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X066",
    "topic": "LVM growth",
    "title": "Grow a volume and filesystem separately",
    "scenario": "The change procedure separates block-volume growth from ext4 growth. Perform both steps explicitly.",
    "solution": [
      "lvs",
      "lvextend -L +2G /dev/vg0/data",
      "resize2fs /dev/vg0/data",
      "df -h"
    ],
    "goals": [
      {
        "label": "Inspect initial LV",
        "rule": [
          "seen",
          "lvs"
        ]
      },
      {
        "label": "LV grows to 12 GiB",
        "rule": [
          "value",
          "lv",
          12
        ]
      },
      {
        "label": "Filesystem catches up",
        "rule": [
          "value",
          "filesystem",
          12
        ]
      },
      {
        "label": "Inspect final capacity",
        "rule": [
          "seen",
          "capacity"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X067",
    "topic": "LVM growth",
    "title": "Allocate a larger 4 GiB increment",
    "scenario": "A planned import needs 4 GiB more room. Verify the VG and grow the supported ext4 volume to 14 GiB.",
    "solution": [
      "pvs",
      "vgs",
      "lvextend -r -L +4G /dev/vg0/data",
      "df -h"
    ],
    "goals": [
      {
        "label": "Inspect physical volume",
        "rule": [
          "seen",
          "pvs"
        ]
      },
      {
        "label": "Inspect free space",
        "rule": [
          "seen",
          "vgs"
        ]
      },
      {
        "label": "LV is 14 GiB",
        "rule": [
          "value",
          "lv",
          14
        ]
      },
      {
        "label": "Filesystem is 14 GiB",
        "rule": [
          "value",
          "filesystem",
          14
        ]
      },
      {
        "label": "Inspect result",
        "rule": [
          "seen",
          "capacity"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X068",
    "topic": "LVM growth",
    "title": "Repair a filesystem left behind after LV growth",
    "scenario": "The block volume is already 14 GiB, but its filesystem still reports 10 GiB. Grow only the filesystem.",
    "solution": [
      "lvs",
      "df -h",
      "resize2fs /dev/vg0/data",
      "df -h"
    ],
    "goals": [
      {
        "label": "Inspect logical volume",
        "rule": [
          "seen",
          "lvs"
        ]
      },
      {
        "label": "Keep existing LV size",
        "rule": [
          "value",
          "lv",
          14
        ]
      },
      {
        "label": "Filesystem grows to match",
        "rule": [
          "value",
          "filesystem",
          14
        ]
      },
      {
        "label": "Inspect filesystem report",
        "rule": [
          "seen",
          "capacity"
        ]
      }
    ],
    "seed": {
      "lv": 14,
      "filesystem": 10
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X069",
    "topic": "Archives",
    "title": "Archive one configuration file",
    "scenario": "Create a compressed training archive of the configuration, then inspect its member list.",
    "solution": [
      "tar -czf /backup/config.tar.gz /srv/app/config.ini",
      "tar -tzf /backup/config.tar.gz"
    ],
    "goals": [
      {
        "label": "Configuration archive exists",
        "rule": [
          "archive",
          "/backup/config.tar.gz"
        ]
      },
      {
        "label": "Inspect archive members",
        "rule": [
          "seen",
          "archive:/backup/config.tar.gz"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X070",
    "topic": "Archives",
    "title": "Archive the application directory contents",
    "scenario": "Capture the application directory, inspect it, and restore its contents independently.",
    "solution": [
      "tar -czf /backup/app.tar.gz /srv/app",
      "tar -tzf /backup/app.tar.gz",
      "tar -xzf /backup/app.tar.gz -C /restore",
      "diff /srv/app/config.ini /restore/config.ini"
    ],
    "goals": [
      {
        "label": "Application archive exists",
        "rule": [
          "archive",
          "/backup/app.tar.gz"
        ]
      },
      {
        "label": "Inspect members",
        "rule": [
          "seen",
          "archive:/backup/app.tar.gz"
        ]
      },
      {
        "label": "Restore configuration matches",
        "rule": [
          "equal",
          "/srv/app/config.ini",
          "/restore/config.ini"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "For portability this training archiver stores the selected directory’s contents at the archive root. Inspect tar -tzf before restoring; real tar layout depends on source paths and -C.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X071",
    "topic": "Archives",
    "title": "Restore a known-good task snapshot",
    "scenario": "The trusted archive contains tasks.txt. Restore it without overwriting the live copy and compare contents.",
    "solution": [
      "tar -tzf /backup/known-good.tar.gz",
      "tar -xzf /backup/known-good.tar.gz -C /restore",
      "diff /srv/app/tasks.txt /restore/tasks.txt"
    ],
    "goals": [
      {
        "label": "Inspect trusted archive",
        "rule": [
          "seen",
          "archive:/backup/known-good.tar.gz"
        ]
      },
      {
        "label": "Recovered data matches live data",
        "rule": [
          "equal",
          "/srv/app/tasks.txt",
          "/restore/tasks.txt"
        ]
      },
      {
        "label": "Compare recovered contents",
        "rule": [
          "seen",
          "equal:/srv/app/tasks.txt:/restore/tasks.txt"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X072",
    "topic": "Archives",
    "title": "Make a backup before editing configuration",
    "scenario": "Capture the original configuration, edit the live port, then prove the archive still contains the original.",
    "solution": [
      "tar -czf /backup/before.tar.gz /srv/app/config.ini",
      "edit /srv/app/config.ini",
      "tar -xzf /backup/before.tar.gz -C /restore"
    ],
    "goals": [
      {
        "label": "Archive created",
        "rule": [
          "archive",
          "/backup/before.tar.gz"
        ]
      },
      {
        "label": "Live config uses new port",
        "rule": [
          "data",
          "/srv/app/config.ini",
          "port=9000\n"
        ]
      },
      {
        "label": "Restored old config preserved",
        "rule": [
          "data",
          "/restore/config.ini",
          "port=8765\n"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/srv/app/config.ini": "port=9000\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X073",
    "topic": "File synchronization",
    "title": "Preview an application mirror",
    "scenario": "The change request authorizes inspection only. Preview a contents copy without creating destination files.",
    "solution": [
      "rsync -an /srv/app/ /srv/mirror/",
      "ls -l /srv/mirror"
    ],
    "goals": [
      {
        "label": "Run dry-run preview",
        "rule": [
          "seen",
          "rsyncPreview"
        ]
      },
      {
        "label": "Destination configuration is still absent",
        "rule": [
          "absent",
          "/srv/mirror/config.ini"
        ]
      },
      {
        "label": "Inspect destination",
        "rule": [
          "seen",
          "ls:/srv/mirror"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X074",
    "topic": "File synchronization",
    "title": "Mirror contents after a dry run",
    "scenario": "Inspect the planned change, copy application contents, and compare the mirrored configuration.",
    "solution": [
      "rsync -an /srv/app/ /srv/mirror/",
      "rsync -a /srv/app/ /srv/mirror/",
      "diff /srv/app/config.ini /srv/mirror/config.ini"
    ],
    "goals": [
      {
        "label": "Preview first",
        "rule": [
          "seen",
          "rsyncPreview"
        ]
      },
      {
        "label": "Mirrored configuration matches",
        "rule": [
          "equal",
          "/srv/app/config.ini",
          "/srv/mirror/config.ini"
        ]
      },
      {
        "label": "Compare copy",
        "rule": [
          "seen",
          "equal:/srv/app/config.ini:/srv/mirror/config.ini"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X075",
    "topic": "File synchronization",
    "title": "Preserve the source directory name",
    "scenario": "The destination needs an app subdirectory rather than flattened contents. Copy without a trailing source slash.",
    "solution": [
      "rsync -an /srv/app /srv/mirror/",
      "rsync -a /srv/app /srv/mirror/",
      "diff /srv/app/config.ini /srv/mirror/app/config.ini"
    ],
    "goals": [
      {
        "label": "Preview directory layout",
        "rule": [
          "seen",
          "rsyncPreview"
        ]
      },
      {
        "label": "Nested app configuration matches",
        "rule": [
          "equal",
          "/srv/app/config.ini",
          "/srv/mirror/app/config.ini"
        ]
      },
      {
        "label": "Nested directory exists",
        "rule": [
          "dir",
          "/srv/mirror/app"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X076",
    "topic": "File synchronization",
    "title": "Refresh a stale mirror without deleting extras",
    "scenario": "The mirror has an outdated configuration and an unrelated keep file. Refresh the source contents while retaining that extra file.",
    "solution": [
      "rsync -an /srv/app/ /srv/mirror/",
      "rsync -a /srv/app/ /srv/mirror/",
      "diff /srv/app/config.ini /srv/mirror/config.ini"
    ],
    "goals": [
      {
        "label": "Preview refresh",
        "rule": [
          "seen",
          "rsyncPreview"
        ]
      },
      {
        "label": "Configuration refreshed",
        "rule": [
          "equal",
          "/srv/app/config.ini",
          "/srv/mirror/config.ini"
        ]
      },
      {
        "label": "Unrelated destination file retained",
        "rule": [
          "data",
          "/srv/mirror/keep.txt",
          "Keep me\n"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/mirror/config.ini": {
          "data": "port=old\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        },
        "/srv/mirror/keep.txt": {
          "data": "Keep me\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X077",
    "topic": "Task scheduling",
    "title": "Enable a dormant backup timer",
    "scenario": "The timer exists but is disabled and inactive. Activate it for this boot and future boots.",
    "solution": [
      "systemctl cat backup.timer",
      "systemctl enable --now backup.timer",
      "systemctl list-timers"
    ],
    "goals": [
      {
        "label": "Inspect timer definition",
        "rule": [
          "seen",
          "unit:backup.timer"
        ]
      },
      {
        "label": "Timer enabled",
        "rule": [
          "service",
          "backup.timer",
          "enabled",
          true
        ]
      },
      {
        "label": "Timer active",
        "rule": [
          "service",
          "backup.timer",
          "active",
          true
        ]
      },
      {
        "label": "Inspect schedule",
        "rule": [
          "seen",
          "timers"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X078",
    "topic": "Task scheduling",
    "title": "Catch missed daily backup activations",
    "scenario": "Update a calendar timer to catch missed activations, reload definitions, and schedule it.",
    "solution": [
      "edit /etc/systemd/system/backup.timer",
      "systemctl daemon-reload",
      "systemctl enable --now backup.timer",
      "systemctl list-timers"
    ],
    "goals": [
      {
        "label": "Persistent calendar setting saved",
        "rule": [
          "config",
          "/etc/systemd/system/backup.timer",
          "Persistent",
          "true"
        ]
      },
      {
        "label": "Reload definitions",
        "rule": [
          "seen",
          "daemon-reload"
        ]
      },
      {
        "label": "Timer enabled",
        "rule": [
          "service",
          "backup.timer",
          "enabled",
          true
        ]
      },
      {
        "label": "Timer active",
        "rule": [
          "service",
          "backup.timer",
          "active",
          true
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/backup.timer": "[Timer]\nOnCalendar=*-*-* 02:00:00\nPersistent=true\n[Install]\nWantedBy=timers.target\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X079",
    "topic": "Task scheduling",
    "title": "Correct a daily cron expression",
    "scenario": "A training crontab runs every minute. Change it to daily at 03:15 using an absolute script path.",
    "solution": [
      "crontab -l",
      "edit /lab/crontab",
      "crontab -l"
    ],
    "goals": [
      {
        "label": "Inspect cron entries",
        "rule": [
          "seen",
          "cron"
        ]
      },
      {
        "label": "Daily 03:15 entry stored",
        "rule": [
          "data",
          "/lab/crontab",
          "15 3 * * * /usr/local/bin/backup\n"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/lab/crontab": {
          "data": "* * * * * backup\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/lab/crontab": "15 3 * * * /usr/local/bin/backup\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X080",
    "topic": "Task scheduling",
    "title": "Test the job before scheduling",
    "scenario": "Prove the backup oneshot succeeds before activating its associated recurring timer.",
    "solution": [
      "systemctl start backup",
      "journalctl -u backup",
      "systemctl enable --now backup.timer",
      "systemctl list-timers"
    ],
    "goals": [
      {
        "label": "Manual backup succeeded",
        "rule": [
          "seen",
          "backupRan"
        ]
      },
      {
        "label": "Read completion journal",
        "rule": [
          "seen",
          "journal:backup"
        ]
      },
      {
        "label": "Schedule activated",
        "rule": [
          "service",
          "backup.timer",
          "active",
          true
        ]
      },
      {
        "label": "Inspect scheduled timers",
        "rule": [
          "seen",
          "timers"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X081",
    "topic": "Recovery verification",
    "title": "Validate a trusted checksum before restoration",
    "scenario": "A recovery run should record checksum evidence and inspect members before extraction.",
    "solution": [
      "sha256sum -c /backup/known-good.sha256",
      "tar -tzf /backup/known-good.tar.gz",
      "tar -xzf /backup/known-good.tar.gz -C /restore"
    ],
    "goals": [
      {
        "label": "Checksum fixture verified",
        "rule": [
          "seen",
          "checksum"
        ]
      },
      {
        "label": "Archive members inspected",
        "rule": [
          "seen",
          "archive:/backup/known-good.tar.gz"
        ]
      },
      {
        "label": "Task snapshot restored",
        "rule": [
          "data",
          "/restore/tasks.txt",
          "Inspect logs\nTest restore\n"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X082",
    "topic": "Recovery verification",
    "title": "Recover deleted task data",
    "scenario": "The live tasks file was removed. Restore the snapshot into a separate directory and copy back the recovered file.",
    "solution": [
      "tar -xzf /backup/known-good.tar.gz -C /restore",
      "cp /restore/tasks.txt /srv/app/tasks.txt",
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "chmod 640 /srv/app/tasks.txt"
    ],
    "goals": [
      {
        "label": "Restore snapshot separately",
        "rule": [
          "data",
          "/restore/tasks.txt",
          "Inspect logs\nTest restore\n"
        ]
      },
      {
        "label": "Live task contents recovered",
        "rule": [
          "data",
          "/srv/app/tasks.txt",
          "Inspect logs\nTest restore\n"
        ]
      },
      {
        "label": "Service owns recovered file",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Recovered mode is constrained",
        "rule": [
          "mode",
          "/srv/app/tasks.txt",
          "640"
        ]
      }
    ],
    "seed": {
      "missing": [
        "/srv/app/tasks.txt"
      ]
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X083",
    "topic": "Recovery verification",
    "title": "Recover contents without weakening metadata",
    "scenario": "The live file has been replaced by bad data. Restore original contents and explicitly reestablish service group ownership.",
    "solution": [
      "sha256sum -c /backup/known-good.sha256",
      "tar -xzf /backup/known-good.tar.gz -C /restore",
      "cp /restore/tasks.txt /srv/app/tasks.txt",
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "diff /srv/app/tasks.txt /restore/tasks.txt"
    ],
    "goals": [
      {
        "label": "Checksum verified",
        "rule": [
          "seen",
          "checksum"
        ]
      },
      {
        "label": "Live content repaired",
        "rule": [
          "equal",
          "/srv/app/tasks.txt",
          "/restore/tasks.txt"
        ]
      },
      {
        "label": "Service owns data",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Service group owns data",
        "rule": [
          "group",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/tasks.txt": {
          "data": "bad data\n",
          "mode": "666",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X084",
    "topic": "Recovery verification",
    "title": "Create and rehearse a fresh backup",
    "scenario": "Generate a current backup through the oneshot job, restore that new archive, and compare it.",
    "solution": [
      "systemctl start backup",
      "tar -tzf /backup/latest.tar.gz",
      "tar -xzf /backup/latest.tar.gz -C /restore",
      "diff /srv/app/tasks.txt /restore/tasks.txt"
    ],
    "goals": [
      {
        "label": "New backup ran",
        "rule": [
          "seen",
          "backupRan"
        ]
      },
      {
        "label": "New archive inspected",
        "rule": [
          "seen",
          "archive:/backup/latest.tar.gz"
        ]
      },
      {
        "label": "Restored fresh data matches",
        "rule": [
          "equal",
          "/srv/app/tasks.txt",
          "/restore/tasks.txt"
        ]
      },
      {
        "label": "Comparison recorded",
        "rule": [
          "seen",
          "equal:/srv/app/tasks.txt:/restore/tasks.txt"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 2",
    "scriptPatterns": null
  },
  {
    "id": "X085",
    "topic": "Bash argument boundaries",
    "title": "Preserve a spaced release label",
    "scenario": "The helper expects two labels. The first contains spaces and must remain one argument.",
    "solution": [
      "cat /lab/args.sh",
      "bash /lab/args.sh \"candidate build 7\" stable"
    ],
    "goals": [
      {
        "label": "Inspect the fixed argument helper",
        "rule": [
          "seen",
          "cat:/lab/args.sh"
        ]
      },
      {
        "label": "Arguments arrive with exact boundaries",
        "rule": [
          "args",
          [
            "candidate build 7",
            "stable"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "This fixed helper shows argument boundaries. The browser is not a complete Bash interpreter; unsupported expansion is rejected.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X086",
    "topic": "Bash argument boundaries",
    "title": "Pass an explicit empty argument",
    "scenario": "The deployment helper distinguishes an omitted option from an explicitly empty value.",
    "solution": [
      "cat /lab/args.sh",
      "bash /lab/args.sh \"\" production"
    ],
    "goals": [
      {
        "label": "Inspect the fixed argument helper",
        "rule": [
          "seen",
          "cat:/lab/args.sh"
        ]
      },
      {
        "label": "Arguments arrive with exact boundaries",
        "rule": [
          "args",
          [
            "",
            "production"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "This fixed helper shows argument boundaries. The browser is not a complete Bash interpreter; unsupported expansion is rejected.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X087",
    "topic": "Bash argument boundaries",
    "title": "Keep wildcard text literal",
    "scenario": "A pattern is data for a later tool. Pass a literal asterisk rather than expanding filenames.",
    "solution": [
      "cat /lab/args.sh",
      "bash /lab/args.sh \"*.log\" archive"
    ],
    "goals": [
      {
        "label": "Inspect the fixed argument helper",
        "rule": [
          "seen",
          "cat:/lab/args.sh"
        ]
      },
      {
        "label": "Arguments arrive with exact boundaries",
        "rule": [
          "args",
          [
            "*.log",
            "archive"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "This fixed helper shows argument boundaries. The browser is not a complete Bash interpreter; unsupported expansion is rejected.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X088",
    "topic": "Bash argument boundaries",
    "title": "Keep an equals-sign option intact",
    "scenario": "Pass a label assignment containing spaces as one argument and preserve a second option.",
    "solution": [
      "cat /lab/args.sh",
      "bash /lab/args.sh \"label=nightly build\" --dry-run"
    ],
    "goals": [
      {
        "label": "Inspect the fixed argument helper",
        "rule": [
          "seen",
          "cat:/lab/args.sh"
        ]
      },
      {
        "label": "Arguments arrive with exact boundaries",
        "rule": [
          "args",
          [
            "label=nightly build",
            "--dry-run"
          ]
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "This fixed helper shows argument boundaries. The browser is not a complete Bash interpreter; unsupported expansion is rejected.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X089",
    "topic": "Bash safety review",
    "title": "Quote forwarded arguments",
    "scenario": "A helper forwards parameters to another program. Preserve each caller argument rather than splitting words.",
    "solution": [
      "cat /lab/check.sh",
      "edit /lab/check.sh",
      "lab check-script /lab/check.sh"
    ],
    "goals": [
      {
        "label": "Inspect original script",
        "rule": [
          "seen",
          "cat:/lab/check.sh"
        ]
      },
      {
        "label": "Pattern review: Quote forwarded arguments",
        "rule": [
          "seen",
          "script:/lab/check.sh"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/lab/check.sh": {
          "data": "#!/usr/bin/env bash\nworker $@\n",
          "mode": "755",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/lab/check.sh": "#!/usr/bin/env bash\nworker \"$@\"\n"
    },
    "hint": "Edit the actual training file. lab check-script checks the stated patterns only; it does not execute the script or prove complete Bash correctness.",
    "level": "Lecture 3",
    "scriptPatterns": [
      "\"$@\""
    ]
  },
  {
    "id": "X090",
    "topic": "Bash safety review",
    "title": "Make temporary cleanup explicit",
    "scenario": "A temporary report must be removed on normal exit. Install an EXIT cleanup trap and quote the path.",
    "solution": [
      "cat /lab/check.sh",
      "edit /lab/check.sh",
      "lab check-script /lab/check.sh"
    ],
    "goals": [
      {
        "label": "Inspect original script",
        "rule": [
          "seen",
          "cat:/lab/check.sh"
        ]
      },
      {
        "label": "Pattern review: Make temporary cleanup explicit",
        "rule": [
          "seen",
          "script:/lab/check.sh"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/lab/check.sh": {
          "data": "#!/usr/bin/env bash\ntmp=/tmp/report\n",
          "mode": "755",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/lab/check.sh": "#!/usr/bin/env bash\nset -euo pipefail\ntmp=$(mktemp)\ntrap 'rm -f -- \"$tmp\"' EXIT\n"
    },
    "hint": "Edit the actual training file. lab check-script checks the stated patterns only; it does not execute the script or prove complete Bash correctness.",
    "level": "Lecture 3",
    "scriptPatterns": [
      "mktemp",
      "trap",
      "EXIT",
      "\"$tmp\""
    ]
  },
  {
    "id": "X091",
    "topic": "Bash safety review",
    "title": "Handle an expected probe failure",
    "scenario": "An automation job should explicitly handle a failed readiness probe instead of assuming set -e covers every context.",
    "solution": [
      "cat /lab/check.sh",
      "edit /lab/check.sh",
      "lab check-script /lab/check.sh"
    ],
    "goals": [
      {
        "label": "Inspect original script",
        "rule": [
          "seen",
          "cat:/lab/check.sh"
        ]
      },
      {
        "label": "Pattern review: Handle an expected probe failure",
        "rule": [
          "seen",
          "script:/lab/check.sh"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/lab/check.sh": {
          "data": "#!/usr/bin/env bash\ncurl http://127.0.0.1:8765/readyz\n",
          "mode": "755",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/lab/check.sh": "#!/usr/bin/env bash\nset -euo pipefail\nif ! curl --fail http://127.0.0.1:8765/readyz; then\n    printf \"%s\\n\" \"not ready\" >&2\n    exit 1\nfi\n"
    },
    "hint": "Edit the actual training file. lab check-script checks the stated patterns only; it does not execute the script or prove complete Bash correctness.",
    "level": "Lecture 3",
    "scriptPatterns": [
      "if ! curl --fail",
      "exit 1",
      "fi"
    ]
  },
  {
    "id": "X092",
    "topic": "Bash safety review",
    "title": "Make directory setup safe to rerun",
    "scenario": "A preparation script fails on its second run because the directory already exists. Use idempotent creation and quote its target.",
    "solution": [
      "cat /lab/check.sh",
      "edit /lab/check.sh",
      "lab check-script /lab/check.sh"
    ],
    "goals": [
      {
        "label": "Inspect original script",
        "rule": [
          "seen",
          "cat:/lab/check.sh"
        ]
      },
      {
        "label": "Pattern review: Make directory setup safe to rerun",
        "rule": [
          "seen",
          "script:/lab/check.sh"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/lab/check.sh": {
          "data": "#!/usr/bin/env bash\nmkdir $target\n",
          "mode": "755",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/lab/check.sh": "#!/usr/bin/env bash\ntarget=${1:-./reports}\nmkdir -p -- \"$target\"\n"
    },
    "hint": "Edit the actual training file. lab check-script checks the stated patterns only; it does not execute the script or prove complete Bash correctness.",
    "level": "Lecture 3",
    "scriptPatterns": [
      "mkdir -p -- \"$target\"",
      "${1:-./reports}"
    ]
  },
  {
    "id": "X093",
    "topic": "Kernel and memory",
    "title": "Compare resident and virtual process memory",
    "scenario": "Read the kernel-exposed process status and compare it with host memory information.",
    "solution": [
      "cat /proc/4242/status",
      "cat /proc/meminfo",
      "free -h"
    ],
    "goals": [
      {
        "label": "Inspect process virtual/resident values",
        "rule": [
          "seen",
          "cat:/proc/4242/status"
        ]
      },
      {
        "label": "Inspect kernel memory report",
        "rule": [
          "seen",
          "cat:/proc/meminfo"
        ]
      },
      {
        "label": "Inspect human-readable memory",
        "rule": [
          "seen",
          "memory"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X094",
    "topic": "Kernel and memory",
    "title": "Check whether cache means pressure",
    "scenario": "The host shows little free RAM. Compare available memory and a short activity sample before declaring exhaustion.",
    "solution": [
      "free -h",
      "vmstat 1 3",
      "cat /proc/meminfo"
    ],
    "goals": [
      {
        "label": "Inspect available memory",
        "rule": [
          "seen",
          "memory"
        ]
      },
      {
        "label": "Sample runtime activity",
        "rule": [
          "seen",
          "vmstat"
        ]
      },
      {
        "label": "Read kernel cache information",
        "rule": [
          "seen",
          "cat:/proc/meminfo"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X095",
    "topic": "Kernel and memory",
    "title": "Locate service cgroup membership",
    "scenario": "A Python process belongs to a systemd unit. Read its kernel membership and compare it with service resource settings.",
    "solution": [
      "cat /proc/4242/cgroup",
      "systemctl show opsdemo"
    ],
    "goals": [
      {
        "label": "Read process cgroup",
        "rule": [
          "seen",
          "cat:/proc/4242/cgroup"
        ]
      },
      {
        "label": "Read systemd limit evidence",
        "rule": [
          "seen",
          "limits"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X096",
    "topic": "Kernel and memory",
    "title": "Assemble OOM evidence before mitigation",
    "scenario": "A process disappeared after a memory event. Read kernel logs, current host memory and the configured service budget.",
    "solution": [
      "journalctl -k",
      "free -h",
      "systemctl show opsdemo",
      "cat /proc/meminfo"
    ],
    "goals": [
      {
        "label": "Inspect OOM event",
        "rule": [
          "seen",
          "kernelLog"
        ]
      },
      {
        "label": "Inspect host headroom",
        "rule": [
          "seen",
          "memory"
        ]
      },
      {
        "label": "Inspect service memory limit",
        "rule": [
          "seen",
          "limits"
        ]
      },
      {
        "label": "Read live kernel memory",
        "rule": [
          "seen",
          "cat:/proc/meminfo"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X097",
    "topic": "Namespaces and resource limits",
    "title": "Separate namespace visibility from memory limits",
    "scenario": "Inspect namespace membership and cgroups rather than assuming a container has its own kernel.",
    "solution": [
      "lsns",
      "cat /proc/4242/cgroup",
      "systemctl show opsdemo"
    ],
    "goals": [
      {
        "label": "Inspect namespace inventory",
        "rule": [
          "seen",
          "namespaces"
        ]
      },
      {
        "label": "Read cgroup membership",
        "rule": [
          "seen",
          "cat:/proc/4242/cgroup"
        ]
      },
      {
        "label": "Inspect resource settings",
        "rule": [
          "seen",
          "limits"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X098",
    "topic": "Namespaces and resource limits",
    "title": "Increase a deliberately undersized service budget",
    "scenario": "A demo process cannot start under its 8 MiB limit. Collect evidence and apply the authorized 256 MiB training budget.",
    "solution": [
      "journalctl -k",
      "systemctl show opsdemo",
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "curl http://127.0.0.1:8765/healthz"
    ],
    "goals": [
      {
        "label": "Inspect failure evidence",
        "rule": [
          "seen",
          "kernelLog"
        ]
      },
      {
        "label": "Inspect old limit",
        "rule": [
          "seen",
          "limits"
        ]
      },
      {
        "label": "256 MiB active in restarted unit",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "MemoryMax",
          "256M"
        ]
      },
      {
        "label": "Verify live process",
        "rule": [
          "seen",
          "health"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/systemd/system/opsdemo.service": {
          "data": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=8M\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      },
      "services": {
        "opsdemo": {
          "active": false,
          "enabled": false
        }
      }
    },
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=256M\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X099",
    "topic": "Namespaces and resource limits",
    "title": "Reload definitions without assuming restart",
    "scenario": "Update the unit’s memory budget. Prove activation by reloading definitions and restarting, not merely saving a file.",
    "solution": [
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "systemctl show opsdemo"
    ],
    "goals": [
      {
        "label": "New memory budget saved",
        "rule": [
          "config",
          "/etc/systemd/system/opsdemo.service",
          "MemoryMax",
          "512M"
        ]
      },
      {
        "label": "New memory budget active",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "MemoryMax",
          "512M"
        ]
      },
      {
        "label": "Inspect limit report",
        "rule": [
          "seen",
          "limits"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=512M\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X100",
    "topic": "Namespaces and resource limits",
    "title": "Review host isolation and mandatory controls",
    "scenario": "Gather namespace and AppArmor evidence plus the current unit’s sandbox review.",
    "solution": [
      "lsns",
      "aa-status",
      "systemd-analyze security opsdemo"
    ],
    "goals": [
      {
        "label": "Inspect namespace membership",
        "rule": [
          "seen",
          "namespaces"
        ]
      },
      {
        "label": "Inspect AppArmor status",
        "rule": [
          "seen",
          "apparmor"
        ]
      },
      {
        "label": "Review systemd controls",
        "rule": [
          "seen",
          "sandboxReview"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X101",
    "topic": "Service sandboxing",
    "title": "Run the application under its own identity",
    "scenario": "Replace a root service identity with the dedicated opsdemo user.",
    "solution": [
      "systemctl cat opsdemo",
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "systemd-analyze security opsdemo"
    ],
    "goals": [
      {
        "label": "Selected sandbox setting active",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "User",
          "opsdemo"
        ]
      },
      {
        "label": "Inspect sandbox controls",
        "rule": [
          "seen",
          "sandboxReview"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=256M\n"
    },
    "hint": "Save the provided complete unit, reload definitions and restart. Sandbox settings depend on workload and installed systemd support; this lab models the displayed directives.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X102",
    "topic": "Service sandboxing",
    "title": "Prevent privilege gains in the service",
    "scenario": "Enable the service control that restricts gaining new privileges through execution.",
    "solution": [
      "systemctl cat opsdemo",
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "systemd-analyze security opsdemo"
    ],
    "goals": [
      {
        "label": "Selected sandbox setting active",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "NoNewPrivileges",
          "yes"
        ]
      },
      {
        "label": "Inspect sandbox controls",
        "rule": [
          "seen",
          "sandboxReview"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=256M\n"
    },
    "hint": "Save the provided complete unit, reload definitions and restart. Sandbox settings depend on workload and installed systemd support; this lab models the displayed directives.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X103",
    "topic": "Service sandboxing",
    "title": "Give the service a private temporary view",
    "scenario": "Separate service temporary storage from the ordinary shared temporary namespace.",
    "solution": [
      "systemctl cat opsdemo",
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "systemd-analyze security opsdemo"
    ],
    "goals": [
      {
        "label": "Selected sandbox setting active",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "PrivateTmp",
          "yes"
        ]
      },
      {
        "label": "Inspect sandbox controls",
        "rule": [
          "seen",
          "sandboxReview"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=256M\n"
    },
    "hint": "Save the provided complete unit, reload definitions and restart. Sandbox settings depend on workload and installed systemd support; this lab models the displayed directives.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X104",
    "topic": "Service sandboxing",
    "title": "Protect system paths with a writable exception",
    "scenario": "Make the system hierarchy read-only while keeping the application data directory writable.",
    "solution": [
      "systemctl cat opsdemo",
      "edit /etc/systemd/system/opsdemo.service",
      "systemctl daemon-reload",
      "systemctl restart opsdemo",
      "systemd-analyze security opsdemo"
    ],
    "goals": [
      {
        "label": "Selected sandbox setting active",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "ProtectSystem",
          "strict"
        ]
      },
      {
        "label": "Inspect sandbox controls",
        "rule": [
          "seen",
          "sandboxReview"
        ]
      },
      {
        "label": "Writable data exception retained",
        "rule": [
          "activeConfig",
          "/etc/systemd/system/opsdemo.service",
          "ReadWritePaths",
          "/var/lib/opsdemo"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/systemd/system/opsdemo.service": "[Service]\nUser=opsdemo\nExecStart=/usr/bin/python3 /opt/opsdemo/current/app.py\nRestart=on-failure\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/opsdemo\nMemoryMax=256M\n"
    },
    "hint": "Save the provided complete unit, reload definitions and restart. Sandbox settings depend on workload and installed systemd support; this lab models the displayed directives.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X105",
    "topic": "Nginx reverse proxy",
    "title": "Repair an upstream port mismatch",
    "scenario": "The backend listens on 8765 but Nginx targets 9999. Repair the saved configuration and activate it.",
    "solution": [
      "journalctl -u nginx",
      "ss -lntp",
      "edit /etc/nginx/app.conf",
      "nginx -t",
      "systemctl reload nginx",
      "curl http://127.0.0.1:8080/readyz"
    ],
    "goals": [
      {
        "label": "Inspect proxy journal",
        "rule": [
          "seen",
          "journal:nginx"
        ]
      },
      {
        "label": "Inspect actual sockets",
        "rule": [
          "seen",
          "sockets"
        ]
      },
      {
        "label": "Correct upstream is active",
        "rule": [
          "activeContains",
          "/etc/nginx/app.conf",
          "127.0.0.1:8765;"
        ]
      },
      {
        "label": "Proxied readiness succeeds",
        "rule": [
          "seen",
          "proxyReady"
        ]
      }
    ],
    "seed": {},
    "edits": {
      "/etc/nginx/app.conf": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n"
    },
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X106",
    "topic": "Nginx reverse proxy",
    "title": "Validate a saved proxy before activation",
    "scenario": "The service file is correct on disk but the running proxy still uses the previous port. Validate and reload it.",
    "solution": [
      "nginx -t",
      "systemctl reload nginx",
      "curl http://127.0.0.1:8080/healthz"
    ],
    "goals": [
      {
        "label": "Validate saved configuration",
        "rule": [
          "seen",
          "nginxValidated"
        ]
      },
      {
        "label": "Proxy serves liveness",
        "rule": [
          "seen",
          "proxyHealth"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/nginx/app.conf": {
          "data": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X107",
    "topic": "Nginx reverse proxy",
    "title": "Add client address forwarding",
    "scenario": "The proxy works but its configuration omits the explicit client-address header. Add it, validate, and reload.",
    "solution": [
      "edit /etc/nginx/app.conf",
      "nginx -t",
      "systemctl reload nginx",
      "curl http://127.0.0.1:8080/api/tasks"
    ],
    "goals": [
      {
        "label": "Client address header active",
        "rule": [
          "activeContains",
          "/etc/nginx/app.conf",
          "proxy_set_header X-Real-IP $remote_addr;"
        ]
      },
      {
        "label": "Tasks served through proxy",
        "rule": [
          "seen",
          "tasks"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/nginx/app.conf": {
          "data": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n }\n}\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {
      "/etc/nginx/app.conf": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n"
    },
    "hint": "The lab checks the active directive. On real services, configure trusted proxy boundaries; do not blindly trust forwarded headers from arbitrary clients.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X108",
    "topic": "Nginx reverse proxy",
    "title": "Recover an offline frontend",
    "scenario": "The application works and the proxy file is already correct, but Nginx is stopped. Validate and start just the frontend.",
    "solution": [
      "curl http://127.0.0.1:8765/healthz",
      "nginx -t",
      "systemctl start nginx",
      "curl http://127.0.0.1:8080/readyz"
    ],
    "goals": [
      {
        "label": "Direct backend healthy",
        "rule": [
          "seen",
          "health"
        ]
      },
      {
        "label": "Frontend active",
        "rule": [
          "service",
          "nginx",
          "active",
          true
        ]
      },
      {
        "label": "Proxied readiness healthy",
        "rule": [
          "seen",
          "proxyReady"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/nginx/app.conf": {
          "data": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      },
      "services": {
        "nginx": {
          "active": false,
          "enabled": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X109",
    "topic": "Liveness and readiness",
    "title": "Restore data ownership after a manual edit",
    "scenario": "The app is alive but root-owned data mode 600 blocks the service. Repair ownership and preserve private group-readable access.",
    "solution": [
      "curl http://127.0.0.1:8765/healthz",
      "curl http://127.0.0.1:8765/readyz",
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "chmod 640 /srv/app/tasks.txt",
      "curl http://127.0.0.1:8765/readyz"
    ],
    "goals": [
      {
        "label": "Liveness observed",
        "rule": [
          "seen",
          "health"
        ]
      },
      {
        "label": "Readiness failure observed",
        "rule": [
          "seen",
          "notReady"
        ]
      },
      {
        "label": "Service owns data",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Readiness recovers",
        "rule": [
          "seen",
          "ready"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/tasks.txt": {
          "data": "Inspect logs\nTest restore\n",
          "mode": "600",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X110",
    "topic": "Liveness and readiness",
    "title": "Remove public access without losing readiness",
    "scenario": "The task file works only because everyone can read it. Give ownership to the service and reduce the mode to 600.",
    "solution": [
      "chown opsdemo:opsdemo /srv/app/tasks.txt",
      "chmod 600 /srv/app/tasks.txt",
      "curl http://127.0.0.1:8765/readyz",
      "curl http://127.0.0.1:8765/api/tasks"
    ],
    "goals": [
      {
        "label": "Service owns data",
        "rule": [
          "owner",
          "/srv/app/tasks.txt",
          "opsdemo"
        ]
      },
      {
        "label": "Data is owner-only",
        "rule": [
          "mode",
          "/srv/app/tasks.txt",
          "600"
        ]
      },
      {
        "label": "Readiness succeeds",
        "rule": [
          "seen",
          "ready"
        ]
      },
      {
        "label": "Tasks remain available",
        "rule": [
          "seen",
          "tasks"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/srv/app/tasks.txt": {
          "data": "Inspect logs\nTest restore\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X111",
    "topic": "Liveness and readiness",
    "title": "Verify the real API after a readiness check",
    "scenario": "A health endpoint alone is insufficient acceptance evidence. Probe liveness, readiness and actual task data.",
    "solution": [
      "curl http://127.0.0.1:8765/healthz",
      "curl http://127.0.0.1:8765/readyz",
      "curl http://127.0.0.1:8765/api/tasks"
    ],
    "goals": [
      {
        "label": "Liveness probe succeeds",
        "rule": [
          "seen",
          "health"
        ]
      },
      {
        "label": "Readiness probe succeeds",
        "rule": [
          "seen",
          "ready"
        ]
      },
      {
        "label": "Real API serves task data",
        "rule": [
          "seen",
          "tasks"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X112",
    "topic": "Liveness and readiness",
    "title": "Verify every layer after proxy recovery",
    "scenario": "The frontend is configured correctly. Prove direct readiness, proxied readiness and the real proxied task endpoint.",
    "solution": [
      "curl http://127.0.0.1:8765/readyz",
      "curl http://127.0.0.1:8080/readyz",
      "curl http://127.0.0.1:8080/api/tasks"
    ],
    "goals": [
      {
        "label": "Backend ready",
        "rule": [
          "seen",
          "ready"
        ]
      },
      {
        "label": "Proxy ready",
        "rule": [
          "seen",
          "proxyReady"
        ]
      },
      {
        "label": "Task API served",
        "rule": [
          "seen",
          "tasks"
        ]
      }
    ],
    "seed": {
      "fs": {
        "/etc/nginx/app.conf": {
          "data": "server {\n listen 8080;\n location / {\n  proxy_pass http://127.0.0.1:8765;\n  proxy_set_header Host $host;\n  proxy_set_header X-Real-IP $remote_addr;\n }\n}\n",
          "mode": "644",
          "owner": "root",
          "group": "root",
          "dir": false
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X113",
    "topic": "TLS renewal operations",
    "title": "Inventory certificates before a rehearsal",
    "scenario": "Record certificate coverage and run the staged renewal rehearsal without changing live expiry.",
    "solution": [
      "certbot certificates",
      "certbot renew --dry-run"
    ],
    "goals": [
      {
        "label": "Inspect training certificate inventory",
        "rule": [
          "seen",
          "certificates"
        ]
      },
      {
        "label": "Renewal rehearsal passes",
        "rule": [
          "seen",
          "renewal"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X114",
    "topic": "TLS renewal operations",
    "title": "Schedule future certificate renewals",
    "scenario": "The certificate timer exists but is disabled. Enable and activate it, then inspect scheduling.",
    "solution": [
      "systemctl enable --now certbot.timer",
      "systemctl list-timers"
    ],
    "goals": [
      {
        "label": "Certificate timer enabled",
        "rule": [
          "service",
          "certbot.timer",
          "enabled",
          true
        ]
      },
      {
        "label": "Certificate timer active",
        "rule": [
          "service",
          "certbot.timer",
          "active",
          true
        ]
      },
      {
        "label": "Inspect scheduled timers",
        "rule": [
          "seen",
          "timers"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X115",
    "topic": "TLS renewal operations",
    "title": "Rehearse and schedule in one change",
    "scenario": "A newly administered server needs both renewal evidence and an active recurring job.",
    "solution": [
      "certbot certificates",
      "certbot renew --dry-run",
      "systemctl enable --now certbot.timer",
      "systemctl list-timers"
    ],
    "goals": [
      {
        "label": "Certificate inventory inspected",
        "rule": [
          "seen",
          "certificates"
        ]
      },
      {
        "label": "Rehearsal succeeds",
        "rule": [
          "seen",
          "renewal"
        ]
      },
      {
        "label": "Recurring job active",
        "rule": [
          "service",
          "certbot.timer",
          "active",
          true
        ]
      },
      {
        "label": "Recurring job enabled",
        "rule": [
          "service",
          "certbot.timer",
          "enabled",
          true
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X116",
    "topic": "TLS renewal operations",
    "title": "Review exposure alongside renewal automation",
    "scenario": "An existing HTTPS host needs an operations review covering its allowed port, certificate and scheduled renewals.",
    "solution": [
      "ufw status verbose",
      "certbot certificates",
      "systemctl status certbot.timer",
      "certbot renew --dry-run"
    ],
    "goals": [
      {
        "label": "Inspect network exposure",
        "rule": [
          "seen",
          "firewall"
        ]
      },
      {
        "label": "Inspect certificate",
        "rule": [
          "seen",
          "certificates"
        ]
      },
      {
        "label": "Inspect renewal timer",
        "rule": [
          "seen",
          "status:certbot.timer"
        ]
      },
      {
        "label": "Verify renewal rehearsal",
        "rule": [
          "seen",
          "renewal"
        ]
      }
    ],
    "seed": {
      "rules": [
        "22",
        "443"
      ],
      "firewall": true,
      "policy": "deny",
      "services": {
        "certbot.timer": {
          "active": true,
          "enabled": true
        }
      }
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X117",
    "topic": "Release engineering",
    "title": "Roll back the running process to v1",
    "scenario": "The known-good v1 remains available. Switch the release pointer, restart, and verify the version actually served.",
    "solution": [
      "readlink /opt/opsdemo/current",
      "ln -sfn /opt/opsdemo/releases/v1 /opt/opsdemo/current",
      "systemctl restart opsdemo",
      "curl http://127.0.0.1:8765/api/info"
    ],
    "goals": [
      {
        "label": "Inspect existing pointer",
        "rule": [
          "seen",
          "releasePointer"
        ]
      },
      {
        "label": "Pointer selects v1",
        "rule": [
          "value",
          "release",
          "v1"
        ]
      },
      {
        "label": "Process runs v1",
        "rule": [
          "value",
          "runningRelease",
          "v1"
        ]
      },
      {
        "label": "Inspect served version",
        "rule": [
          "seen",
          "version"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X118",
    "topic": "Release engineering",
    "title": "Promote v2 from a working v1",
    "scenario": "A tested v2 is ready. Change the pointer, restart, and prove both readiness and the running release.",
    "solution": [
      "ln -sfn /opt/opsdemo/releases/v2 /opt/opsdemo/current",
      "systemctl restart opsdemo",
      "curl http://127.0.0.1:8765/readyz",
      "curl http://127.0.0.1:8765/api/info"
    ],
    "goals": [
      {
        "label": "Pointer selects v2",
        "rule": [
          "value",
          "release",
          "v2"
        ]
      },
      {
        "label": "Process runs v2",
        "rule": [
          "value",
          "runningRelease",
          "v2"
        ]
      },
      {
        "label": "Readiness succeeds",
        "rule": [
          "seen",
          "ready"
        ]
      },
      {
        "label": "Version inspected",
        "rule": [
          "seen",
          "version"
        ]
      }
    ],
    "seed": {
      "release": "v1",
      "runningRelease": "v1"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X119",
    "topic": "Release engineering",
    "title": "Preserve a recovery point before rollback",
    "scenario": "Create a current data snapshot before switching the code to v1, then verify readiness.",
    "solution": [
      "systemctl start backup",
      "ln -sfn /opt/opsdemo/releases/v1 /opt/opsdemo/current",
      "systemctl restart opsdemo",
      "curl http://127.0.0.1:8765/readyz"
    ],
    "goals": [
      {
        "label": "Recovery point created",
        "rule": [
          "archive",
          "/backup/latest.tar.gz"
        ]
      },
      {
        "label": "Process runs v1",
        "rule": [
          "value",
          "runningRelease",
          "v1"
        ]
      },
      {
        "label": "Readiness verified",
        "rule": [
          "seen",
          "ready"
        ]
      }
    ],
    "seed": {},
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  },
  {
    "id": "X120",
    "topic": "Release engineering",
    "title": "Recover from a failed release and schedule backup",
    "scenario": "The current process reports an unhealthy broken release. Recover v1, prove readiness, and activate periodic protection.",
    "solution": [
      "curl http://127.0.0.1:8765/readyz",
      "ln -sfn /opt/opsdemo/releases/v1 /opt/opsdemo/current",
      "systemctl restart opsdemo",
      "curl http://127.0.0.1:8765/readyz",
      "systemctl enable --now backup.timer"
    ],
    "goals": [
      {
        "label": "Observe failed readiness",
        "rule": [
          "seen",
          "notReady"
        ]
      },
      {
        "label": "Known-good process runs",
        "rule": [
          "value",
          "runningRelease",
          "v1"
        ]
      },
      {
        "label": "Readiness recovered",
        "rule": [
          "seen",
          "ready"
        ]
      },
      {
        "label": "Backup timer enabled",
        "rule": [
          "service",
          "backup.timer",
          "enabled",
          true
        ]
      },
      {
        "label": "Backup timer active",
        "rule": [
          "service",
          "backup.timer",
          "active",
          true
        ]
      }
    ],
    "seed": {
      "release": "broken",
      "runningRelease": "broken"
    },
    "edits": {},
    "hint": "Inspect the evidence first. Each command changes only this ticket’s virtual server. Open the solution if you need supported syntax.",
    "level": "Lecture 3",
    "scriptPatterns": null
  }
];
