The task discovery discussion is complete and confirmed.

Your job is to:
1. **Freeze the task** — Extract and stabilize intent
2. **Create an execution plan** — Define mechanical implementation steps

This phase produces TWO files:
- `/obelisk/temp-state/task.md` — frozen intent (what + why)
- `/obelisk/temp-state/plan.md` — execution approach (how)

---

## Mandatory Reading (Load Once)

Read these files in order:
1. `/obelisk/state/contracts/*.domain.md`
2. `/obelisk/state/tech-memory.md`
3. `/obelisk/guidelines/ai-engineering.md`

If any required file is missing:
- STOP
- OUTPUT: **"TASK DEFINITION BLOCKED — Missing file: path"**
- Do NOT proceed

---

## Phase 1: Task Freeze

### Contract Update Check (If Needed)

If the task discovery discussion revealed:
- A new business invariant not captured in existing contracts
- A rule that must apply beyond this task

Then you MAY update contracts before freezing the task.

Rules:
- Update ONLY if the human explicitly agreed this is invariant-level
- Capture exactly as discussed (no interpretation)
- If uncertain, record in Open Questions instead

---

### Extraction Rules (MANDATORY)

**You MUST:**
- Use ONLY the content of the current discussion
- Produce exactly ONE task
- Extract what IS clear
- Record unresolved items in **Open Questions**

**You MUST NOT:**
- Invent, refine, or reinterpret intent
- Add implementation or design details
- Ask questions

---

### Task Requirements

The task must:
- Be unambiguous (or explicitly flag ambiguity)
- Define clear scope boundaries
- Specify observable success criteria
- Be stable for planning

---

### Task Output

Write the task to: `/obelisk/temp-state/task.md`

**Format:**

```markdown
# Task: [One-line name]

## Goal
[What must be achieved and why]

## Scope

### Included
- [In scope]

### Excluded
- [Explicitly out of scope]

## Constraints
- [Technical or business constraints]
- [Contracts that must be preserved]
- [Areas that must NOT change]

## Success Criteria
- [Observable completion signals]

## Open Questions (if any)
- [Unresolved ambiguities]
- [Contract updates pending decision]
````

---

## Phase 2: Planning

### Planning Rules (MANDATORY)

**You MUST:**

- Follow the frozen task exactly
- Preserve all contracts
- Respect all task constraints
- Define clear file and boundary scope
- Make the plan executable without interpretation

**You MUST NOT:**

- Change, reinterpret, or extend the task
- Invent requirements or features
- Redesign architecture
- Propose alternatives or options
- Write code
- Make unstated assumptions
- Ask questions

---

### Blocking Conditions

If ANY of the following are true, STOP immediately:

**Task Issues:**

- Required information is missing or unclear
- Task contains ambiguity not explicitly acknowledged in `task.md`
- Task is contradictory
- Task is impossible given current constraints

**Contract Conflicts:**

- Task requires violating a contract
- Task requires modifying a contract

**Coverage Failures:**

- Cannot satisfy all success criteria
- Cannot respect all task constraints

**If blocked:**

- OUTPUT: **"PLANNING BLOCKED — [specific reason]"**
- Do NOT create plan.md
- Leave task.md intact (frozen intent is preserved)

---

### Open Questions Handling

If `task.md` contains an **Open Questions** section:

- Treat it as **archival context only**
- Do NOT ask for clarification
- Do NOT let it block planning
- Proceed only if the task itself is otherwise complete and consistent

---

### Coverage Check (Before Writing Plan)

Verify:

- ✓ All success criteria can be satisfied
- ✓ All task constraints can be respected
- ✓ All contracts will be preserved
- ✓ Scope matches the task exactly

If any check fails → Invoke **Blocking Conditions** above

---

### Plan Output

Write **exactly ONE** plan to: `/obelisk/temp-state/plan.md`

**Format:**

```markdown
# Plan: [Task name from task.md]

## Goal
[Copied verbatim from task.md]

## Requirements Coverage
- [Success criterion 1] → Step [X]
- [Success criterion 2] → Steps [Y, Z]

## Scope

### Files to Modify
- `/path/file.ext` — [what changes]

### Files to Create
- `/path/new-file.ext` — [purpose]

### Files Explicitly Excluded
- `/path/protected.ext` — [why excluded]

## Execution Steps

1. [Concrete step]
   - Input: [before state]
   - Action: [exact change]
   - Output: [after state]

2. ...

## Acceptance Criteria
[Copied from task.md]

## Must NOT Change
- [Contracts]
- [Protected files / behavior]

## Assumptions (Explicitly Accepted in Task)
[List only assumptions explicitly stated or implied in `task.md`.
Do NOT introduce new assumptions.]
```

---

## Final Output

After completing both phases, OUTPUT one of:

### Success:

**"TASK DEFINED"**

**Files created:**

- `/obelisk/temp-state/task.md`
- `/obelisk/temp-state/plan.md`

**Next:** Review both files, then proceed to Implementation.

---

### Partial Success (Planning Blocked):

**"TASK FROZEN — PLANNING BLOCKED"**

**Status:**

- ✓ Task frozen at `/obelisk/temp-state/task.md`
- ✗ Planning failed: [specific reason]

**Action Required:**

- Review frozen task
- Address blocking issue
- Re-run Task Definition OR manually run Planning phase

---

### Complete Failure:

**"TASK DEFINITION BLOCKED — [reason]"**

**No files created.**