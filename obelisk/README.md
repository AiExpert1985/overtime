## Obelisk Framework — Overview

Obelisk is a framework for **human–AI collaboration** designed to make AI-assisted development **safe, repeatable, and recoverable** over long-running projects.

It is built on a simple observation:

> **AI does not fail because it is weak — it fails because long-term use is unmanaged.**

Obelisk prevents silent damage and enables clean recovery by separating **truth**, **intent**, and **execution**, and assigning them explicit authority.

**Written files have the highest authority.**  
Chat history is non-authoritative and informational only.

Authority is enforced through layered artifacts:

1. **Contracts** — versioned business constraints
2. **Task** — frozen, human-approved intent
3. **Plan** — mechanical execution steps (temporary)
4. **Execution** — code and tests (disposable)

Higher layers constrain lower ones; lower layers must never redefine higher ones.

### Contract Evolution

Contracts are immutable during task execution.  
They may evolve **only during Discovery Phases**, with explicit human approval and version control.

This ensures contracts change deliberately, not through drift.

---

## Core Properties

- Files are the source of truth
- Sessions are stateless
- Intent is stabilized before execution
- Models are interchangeable
- History lives in git, not prompts
- **Recovery matters more than perfection**  
    Misses are acceptable; corruption is not
---

## Execution Model (High Level)

Each task runs in an isolated, stateless cycle:

1. **Task Discovery**  
    Intent, scope, constraints, and risks are clarified through bounded discussion.  
    No files are created.

2. **Task Definition**  
    A single task is **frozen** (what + why) and a **mechanical execution plan** is produced (how).  
    This stabilizes intent and approach before any code is written.

3. **Implementation**  
    Code is written strictly according to the approved plan.  
    Observations and risks are recorded separately without altering intent.

4. **Review & Archive**  
	Execution is validated against the plan, and the plan against the task.  
	Task materials are archived to preserve intent, plan, execution notes, and review outcome; temporary state is cleaned.  
	Approval means _matches intent_, not _bug-free_.


Tasks and plans are **disposable by design**.

---

## Scope of This File

This README:

- explains **what Obelisk is**
- provides **orientation for humans and models**

It does **not**:

- define project-specific rules
- override contracts, tasks, or plans
- participate in authority resolution

Correctness is enforced by contracts, frozen tasks, plans, and execution rules — not by this document.
