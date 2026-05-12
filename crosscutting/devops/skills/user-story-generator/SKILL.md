---
name: user-story-generator
description: Generate well-structured Azure DevOps user stories from feature descriptions, requirements, or PRDs. Produces story content (title, description, acceptance criteria, notes) following AA field templates and INVEST principles. Pushing to ADO is handled by the calling agent.
---

# User Story Generator Skill

## Purpose

Generate well-structured user story content (title, description, acceptance criteria, notes) from feature descriptions, requirements, or PRDs following AA ADO field templates and INVEST principles.

## Inputs

- Feature description, requirement, or PRD text
- Affected microservices (if known)
- Persona and business value
- Team name and Work Type (for ADO field population)

## Outputs

One or more user stories, each containing:
- **Title**: `[Domain] - [Action] - [Context]`
- **Description** (HTML): User story statement + Technical Context
- **Acceptance Criteria** (HTML): Given/When/Then scenarios (min 2 happy + 1 error)
- **Notes** (HTML): Implementation notes, risks, open questions
- **ADO field values**: Area Path, Story Points (0), Priority, Work Type

## Steps

1. Parse input → extract persona, business value, domain keywords, API/service references
2. Decompose into sprint-sized stories following INVEST principles
3. Generate story content per field templates below
4. Populate ADO field values

## Standards & Constraints

### Title Format
`[Domain] - [Action] - [Context]`  
Example: `Rewards - Reinstate AAdvantage Miles for Cancelled AAVacation Bookings`

### Description Field (`System.Description`) — HTML
User story statement + Technical Context ONLY. No ACs, no Notes.
```html
<p><strong>As a</strong> [persona],<br>
<strong>I want</strong> [action],<br>
<strong>So that</strong> [measurable business value].</p>
<h3>Technical Context</h3>
<ul>
  <li><strong>Affected Services:</strong> [names]</li>
  <li><strong>Dependencies:</strong> [upstream/downstream]</li>
  <li><strong>API Changes:</strong> [endpoint, request/response shape]</li>
</ul>
```

### Acceptance Criteria Field (`Microsoft.VSTS.Common.AcceptanceCriteria`) — HTML
All Given/When/Then scenarios here. NEVER in Description.  
Minimum: 2 happy path, 1-2 error/edge, 1 boundary/security.

### Notes Field (`AAIT.Notes`) — HTML
Implementation notes, risks, open questions ONLY. NEVER in Description.

### ADO Field Reference

| Field | Reference Name | Required |
|---|---|---|
| Title | `System.Title` | Yes |
| Description | `System.Description` | Yes |
| Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` | Yes |
| Notes | `AAIT.Notes` | No |
| Area Path | `System.AreaPath` | Yes |
| Story Points | `Microsoft.VSTS.Scheduling.StoryPoints` | Yes — set `0` |
| Priority | `Microsoft.VSTS.Common.Priority` | No — default `2` |
| Work Type | `AAIT.WorkType` | Yes |

### Work Type Values

| Value | Use when |
|---|---|
| `0. SOW / Business` | New feature, business-requested capability |
| `1. Tech Debt` | Refactoring, migration, dependency upgrades |
| `2. Innovation` | Exploratory, proof of concept |
| `3. Incident Response` | Hotfix, production issue remediation |
| `4. Software / UX` | UI/UX change, design system update |

### Decomposition Rules
- Split by persona, API endpoint, service boundary, or independent deliverable
- Max 6 ACs per story; max 2-3 services per story
- Tech debt/migration: persona = "As the development team"
- Significant unknowns: suggest a Spike story first

## Quality Checklist
- [ ] Title: `[Domain] - [Action] - [Context]`
- [ ] Description: As a / I want / So that + Technical Context only
- [ ] ACs in `AcceptanceCriteria` field (not Description); min 2 happy path + 1 error
- [ ] Notes in `AAIT.Notes` field (not Description)
- [ ] `AAIT.WorkType` set to correct value
- [ ] `StoryPoints` = `0`
- [ ] Story passes INVEST

## References

ADO push logic (team selection, confirmation, MCP invocation) is the responsibility of the calling agent, not this skill.
