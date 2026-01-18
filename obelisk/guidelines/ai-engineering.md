These rules govern how AI behaves during **IMPLEMENTATION and REVIEW** phases.  
They apply across sessions and models.

This file controls **execution behavior only**.  
Discovery, task formulation, and planning are **out of scope**.

For project-specific technical knowledge, see:  
`/obelisk/state/tech-memory.md`

---

## Authority Order (MANDATORY)

1. `/obelisk/state/*.domain.md` — Immutable business rules
2. `/obelisk/temp-state/task.md` — Frozen task intent (if present)
3. `/obelisk/temp-state/plan.md` — Approved execution plan (if present)
4. `/obelisk/state/tech-memory.md` — Non-authoritative technical memory
5. This file — Execution constraints

If a higher authority conflicts with a lower one:

- **STOP**
- Report the conflict
- Do NOT proceed

---

## Execution Discipline

- Execute the plan **literally and in order**
- Do NOT reinterpret, redesign, or extend scope
- Make the **smallest change** that satisfies the plan
- Modify **only** files listed in the plan
- Do NOT modify contracts, tasks, plans, or tech memory

Surface issues only via:

- Implementation Notes (informational)
- STOP conditions (blocking)

---

## Code Guidelines

### Core Principles

- Simple over clever
- Junior-readable naming and flow
- Single responsibility (≈20–30 lines per function)
- Prefer early returns; avoid deep nesting
- Fail fast; no silent failures
- Preserve valid comments
- Write test-ready code  
    _(do NOT write tests unless the plan explicitly requires it)_

---

### Structure & Architecture (Constraints)

- Follow existing patterns only
- Abstract only where already established
- Organize by feature, not layers
- Use dependency injection; avoid hard-coded dependencies
- Design with i18n in mind (EN/AR, LTR/RTL)

Do NOT introduce new patterns or architectural changes unless explicitly required by the task or plan.

---

## Security & Dependencies

You MUST NOT:

- Introduce security vulnerabilities
- Hard-code secrets
- Add dependencies unless required by the plan

You MUST:

- Sanitize inputs
- Flag security risks explicitly
- Use environment variables for credentials
- Verify dependency compatibility

---

## External Research

Web search or documentation lookup:

- Allowed **ONLY if explicitly required by the plan**
- Search only for the specific information the plan demands
- Do NOT search for alternatives or optimizations

If research is needed but not planned:

- **STOP**
- Record a blocker
- Do NOT proceed

---

## Change Workflow

### Before Execution

- Read **all files listed** in the plan's _Files to Modify_
- Read relevant code paths
- Understand current behavior
- Confirm the plan fully specifies the change

### During Execution

- Avoid unnecessary edits
- Do NOT remove valid code or comments
- Do NOT reorder, merge, or skip plan steps

### After Execution

- Write Implementation Notes **only if needed**
- Do NOT update framework state or context files

---

## STOP / Blocker Protocol

If you encounter:

- Ambiguity
- Missing information
- Contradiction
- Impossible instruction
- Plan error

Then:

1. **STOP immediately**
2. Record the issue in Implementation Notes
3. Do NOT guess or apply workarounds
4. Do NOT modify any files further

---

## Implementation Notes Format

When writing `/obelisk/temp-state/implementation-notes.md`:


## [Step Number or File Name]

**Observation:** What was observed  
**Impact:** Why it matters  
**Type:** Blocker / Risk / Question


Rules:

- Notes are factual only
- No solutions or alternatives
- Notes do NOT change authority

---

## Scope Reminder

This file:

- Does NOT define tasks
- Does NOT define plans
- Does NOT justify design decisions
- Does NOT override contracts or frozen intent

It exists solely to ensure **predictable, safe, mechanical execution**.