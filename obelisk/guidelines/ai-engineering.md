These are **project-specific execution invariants** for code quality, architecture, security, and research boundaries.

They MUST be **respected during Planning**, and are **strictly enforced during Implementation and Review**.

This file contains **constraints, not workflow**.  
Phase-specific procedures are defined in the Implementation and Review prompts.


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
    _(Do NOT write tests unless explicitly required by the plan)_

---

### Structure & Architecture

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