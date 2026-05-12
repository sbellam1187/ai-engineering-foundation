## What’s in this repo?

The repository contains several types of engineering specifications and accelerators:

- **Principles** — enduring engineering truths that guide decision‑making  
- **POVs (Points of View)** — opinionated stances on how we build and operate systems  
- **Laws** — non‑negotiable, enterprise‑wide constraints (MUST / SHALL)  
- **ADRs** — Architecture Decision Records explaining decisions and tradeoffs  
- **Adoptions** — implementation playbooks that make laws and POVs easy to adopt and hard to bypass  
- **Skills** — reusable, task‑oriented agent instructions that encode *how* to perform engineering work consistently  
- **Agents** — opinionated compositions of skills that perform a defined engineering role or responsibility  
- **Workflows** — orchestrated, multi‑step sequences that coordinate agents, skills, and plugins across the SDLC  
- **Plugins** — executable or integrative extensions (tools, MCP servers, APIs, actions) that allow agents and workflows to act on real systems  

---

## Practice Guides

- **`practice-guides/`** — step‑by‑step guidance and examples for applying specs, skills, agents, workflows, and plugins in day‑to‑day engineering

---

## Repository Structure

This repository is organized by **taxonomy roots**, then by **concern**, then by **artifact type**.  
The taxonomy is defined in `registry.yaml` (machine‑readable) and described in `taxonomy.md` (human‑readable).

### Top‑level roots

- `enterprise/` — enterprise‑wide standards and architecture concerns  
- `domains/` — business domain–aligned engineering specs (DDD‑oriented)  
- `platforms/` — shared platform capabilities (e.g., AI, cloud)  
- `runtimes/` — application runtime frameworks (e.g., `java-spring`, `dotnet`)  
- `crosscutting/` — concerns that apply across everything (security, quality, resiliency, devops)  

### Example layout

```
enterprise/
  architecture/
    principles/
    laws/
    adrs/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/

domains/
  customer/
    principles/
    povs/
    laws/
    adrs/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/

  flight/
    principles/
    povs/
    laws/
    adrs/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/

platforms/
  ai/
    principles/
    povs/
    laws/
    adrs/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/

runtimes/
  java-spring/
    laws/
    adrs/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/

crosscutting/
  security/
    laws/
    adoptions/
    skills/
    agents/
    workflows/
    plugins/
```

---

## Skills

**Skills** encode *how engineering work is performed* in a reusable, agent‑friendly way.

They typically:

- implement one or more **adoptions**
- assume compliance with relevant **laws**
- are invoked by humans, agents, workflows, or pipelines
- are composable building blocks

Examples include architecture blueprint generation, repo scaffolding, ADR creation, security review, API conformance checks.

---

## Agents

**Agents** represent **opinionated engineering roles** composed of one or more skills.

Agents:

- bundle related **skills** into a coherent responsibility
- enforce enterprise **laws** and **POVs** by default
- can be reused across repos, teams, and platforms
- may be interactive (human‑in‑the‑loop) or autonomous

Examples include:

- `architecture-review-agent`
- `security-remediation-agent`
- `repo-scaffolding-agent`
- `api-governance-agent`

Agents focus on *who* is performing the work and *what responsibility they own*, not just the individual steps.

---

## Workflows

**Workflows** orchestrate **agents, skills, and plugins** into **repeatable SDLC flows**.

Workflows:

- define multi‑step sequences (e.g., design → build → validate → release)
- coordinate multiple agents and skills
- integrate with CI/CD, GitHub, or platform pipelines
- enable end‑to‑end automation with clear guardrails

Examples include:

- new‑service onboarding workflow  
- PR security and compliance sweep workflow  
- architecture decision capture workflow  
- production readiness verification workflow  

Workflows turn enterprise intent into **executable engineering behavior at scale**.

---

## Plugins

**Plugins** provide the execution layer for skills, agents, and workflows.

They may be:

- MCP servers  
- CLI tools  
- GitHub Actions  
- API integrations  
- policy or validation engines  

Plugins are versioned, documented, and explicitly linked to the skills, agents, or workflows they enable.

---

## Naming Conventions (Filenames & IDs)

Strict naming conventions ensure specs, skills, agents, workflows, and plugins are sortable, traceable, and automatable.

### Filenames

- `principle-<concern>-####-short-title.md`
- `pov-<concern>-####-short-title.md`
- `adr-<concern>-####-short-title.md`
- `law-<concern>-###-short-title.md`
- `adoption-<concern>-###-short-title.md`
- `skill-<concern>-####-short-title.md`
- `agent-<concern>-####-short-title.md`
- `workflow-<concern>-####-short-title.md`
- `plugin-<concern>-####-short-title.md`

### IDs (YAML frontmatter)

- `PRINCIPLE-…`
- `POV-…`
- `ADR-…`
- `LAW-…`
- `ADOPTION-…`
- `SKILL-…`
- `AGENT-…`
- `WORKFLOW-…`
- `PLUGIN-…`

Numbering starts at **0001 per concern and artifact type**.

---

## Templates (`_templates/`)

All new artifacts should start from templates:

- `_templates/principle.md`
- `_templates/pov.md`
- `_templates/law.md`
- `_templates/adr.md`
- `_templates/adoption.md`
- `_templates/skill.md`
- `_templates/agent.md`
- `_templates/workflow.md`
- `_templates/plugin.md`

Templates include required frontmatter fields and standard sections to keep artifacts consistent and automation‑ready.

---

## Relationships: Laws ↔ Adoptions ↔ Skills ↔ Agents ↔ Workflows ↔ Plugins ↔ ADRs

Artifacts are explicitly linked using `related:` in YAML frontmatter:

- **Laws** reference ADRs, adoptions, skills, agents, workflows, and plugins that enforce them  
- **ADRs** reference the laws they satisfy and workflows they influence  
- **Adoptions** reference the skills and agents that operationalize them  
- **Skills** reference the adoptions they implement  
- **Agents** reference the skills they compose  
- **Workflows** reference the agents and plugins they orchestrate  
- **Plugins** reference the skills, agents, or workflows they enable  

This enables **full traceability from enterprise intent to executable behavior**.

---

## Final Notes

This repository is meant to **evolve**—from guidance, to contracts, to **agent‑orchestrated execution**.

Enterprise intent flows through **architecture**, **domains**, and **platforms**, and is ultimately realized through **skills, agents, workflows, and plugins**—turning standards into **repeatable, automated engineering outcomes**.
