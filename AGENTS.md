# Agent Instructions for AA Engineering Laws

This repository contains the American Airlines Engineering Laws - a governance framework for software development across AA engineering teams.

## Repository Purpose

The AA Engineering Laws define:
- **Laws**: Mandatory engineering standards (ENG-*) organized by article (10 articles, 55+ laws)
- **Avatars**: Technology-specific implementations (12 technology stacks)
- **Practice Guides**: Hands-on exercises for each law
- **Tools**: Constitution-lint for compliance validation
- **Exception Documentation**: Contextual rules that aren't universal laws

## Working with This Repository

### For AI Agents

1. **Read laws selectively** using `laws/index.yaml` to identify needed articles
2. **Follow Atomic TDD** (ENG-4.1) - this is NON-NEGOTIABLE
3. **Apply avatar guidance** for stack-specific implementations
4. **Check exception documentation** for context-dependent rules
5. **Validate changes** using the constitution-lint tool

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `laws/` | Engineering laws organized by article |
| `laws/index.yaml` | Registry for selective law loading |
| `avatars/` | Technology-specific implementations (12 stacks) |
| `practice-guides/` | Hands-on exercises and templates |
| `docs/standards-exceptions.md` | Exception-prone rules (not laws) |
| `tools/constitution-lint/` | Compliance validation tool |
| `openspec/` | Specification-driven change proposals |

### Law Structure

Each law article file contains:
- **YAML frontmatter**: Law IDs, titles, non-negotiable flags
- **Markdown content**: Detailed guidance, examples, rationale

Example selective loading:
```yaml
# To load only testing laws
- laws/engineering/testing.md  # ENG-4.1 to ENG-4.9
```

### Non-Negotiable Laws

These laws MUST always be followed:
- **ENG-4.1**: Atomic TDD Law
- **ENG-6.1**: Security by Design Law  
- **ENG-6.4**: Data Protection Law
- **ENG-6.7**: Audit Trail Law
- **ENG-6.12**: Database Isolation Law

### Available Avatars

| Avatar | Stack | Specializes |
|--------|-------|-------------|
| `java-spring` | Java 21 + Spring Boot 3.x | TDD, DDD, Quality |
| `python-fastapi` | Python 3.11 + FastAPI | TDD, Complexity |
| `nodejs-typescript` | Node.js + TypeScript | TDD, Immutability |
| `dotnet-core` | .NET 8+ | TDD, Records |
| `react-frontend` | React 18+ | Testing, Components |
| `angular-frontend` | Angular 17+ | Testing, Forms |
| `postgresql` | PostgreSQL 15+ | Data Protection, Isolation |
| `mongodb` | MongoDB 7+ | Data Protection, Recovery |
| `kubernetes` | Kubernetes 1.28+ | GitOps, Network Segmentation |
| `github-actions` | GitHub Actions | CI/CD, Vulnerability Mgmt |
| `opentelemetry` | OTel SDK | Observability, Telemetry |
| `kafka` | Apache Kafka 3.x | Event Streaming, Idempotency |

### Avatar Format

Each avatar contains:
- `manifest.yaml`: Stack configuration, specialized laws
- `guidance.md`: Stack-specific implementation guidance
- `examples/`: Code examples for key laws

### Making Changes

1. Create an OpenSpec proposal in `openspec/changes/<feature-name>/`
2. Write tests first (TDD per ENG-4.1)
3. Run `aa-engineering-lint .` before committing
4. Update relevant practice guides if laws change

## Constitutional Compliance

All changes must comply with:
- **ENG-4.1**: Atomic TDD (NON-NEGOTIABLE)
- **ENG-4.2**: Test Pyramid structure
- **ENG-1.2**: AGENTS.md file presence

## Tools

### Constitution Lint

```bash
# Install
cd tools/constitution-lint && pip install -e .

# Run validation
aa-engineering-lint .

# JSON output for CI/CD
aa-engineering-lint . --format json
```
