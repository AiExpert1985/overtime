## Obelisk Framework — Overview

Obelisk is a framework for **human–AI collaboration** designed to make AI-assisted development **safe, repeatable, and recoverable** over long-running projects.

It is built on a simple observation:

> **AI does not fail because it is weak — it fails because long-term use is unmanaged.**

Obelisk does not try to eliminate bugs.  
It exists to **prevent silent damage**, enable clean recovery, and keep work verifiable across:

- long time gaps
- model switches
- session resets
- refactors

---

## Core Idea

AI becomes unreliable when **truth, intent, and execution are mixed**.

Obelisk enforces strict separation between:

- **Truth** — what must never change
- **Intent** — what we want to do
- **Execution** — how it is done

Only written files are authoritative.  
Chat history has no authority.

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
    Task materials are archived and temporary state is cleaned.  
    Approval means _matches intent_, not _bug-free_.


Tasks and plans are **disposable by design**.

---

## Authority Layers (Conceptual)

Obelisk separates authority to prevent drift:

1. **Contracts** — versioned business constraints (frozen during execution)
2. **Task** — frozen human-approved intent
3. **Plan** — mechanical execution steps (temporary)
4. **Execution** — code and tests (disposable)

Higher layers constrain lower ones.  
Lower layers must never redefine higher ones.

**Note:** Contracts are frozen during task execution but can be updated during Discovery Phases when requirements genuinely change.

---

### Contract Evolution

While contracts are treated as immutable during task execution, they **can be 
updated during Discovery Phases** when business requirements genuinely change.

**Contract updates:**
- Require explicit human approval
- Occur only during Project Discovery or Task Discovery
- Are tracked via version control (Git)
- Cannot be modified by tasks, plans, or AI execution

This ensures contracts evolve deliberately, not through drift.

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

## Scope of This File

This README:

- explains **what Obelisk is**
- provides **orientation for humans and models**

It does **not**:

- define project-specific rules
- override contracts, tasks, or plans
- participate in authority resolution

Correctness is enforced by contracts, frozen tasks, plans, and execution rules — not by this document.
