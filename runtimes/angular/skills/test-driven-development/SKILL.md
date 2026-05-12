---
name: test-driven-development
description: Test-Driven Development using the Red-Green-Refactor cycle for any language or framework. Use when building or modifying features test-first. Supports Spring Boot (Gradle & Maven), Python (pytest), and other ecosystems. Triggers on requests to build features TDD-style, write tests first, or develop code with proper test coverage.
---

# Test-Driven Development Skill

Develop software using strict Test-Driven Development with the Red-Green-Refactor cycle. This skill is framework-agnostic — ecosystem-specific patterns, annotations, and tooling live in the reference files.

## When to Use

Trigger this skill when:
- Building new features or endpoints test-first
- Writing tests before production code
- Requests mention TDD, Red-Green-Refactor, or "write tests first"
- Adding test coverage as part of a feature implementation
- Refactoring existing code with test safety nets

## Ecosystem Reference Files

After detecting the project ecosystem, **read the corresponding reference file** for framework-specific test patterns, dependencies, and conventions:

| Ecosystem | Detected By | Reference File |
|-----------|-------------|----------------|
| Spring Boot (Gradle) | `build.gradle` or `build.gradle.kts` | `references/spring-boot.md` |
| Spring Boot (Maven) | `pom.xml` | `references/spring-boot.md` |
| Python | `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | `references/python.md` |

> **Only load the reference file for the detected ecosystem.** Do not load all files.

## TDD Workflow

For each feature or change, follow this cycle:

1. **RED** — Write a failing test first
   - Test must compile/parse but fail when run
   - Test defines the expected behavior
   - Commit: `test: add failing test for [feature]`

2. **GREEN** — Write minimal code to pass
   - Implement just enough to make the test pass
   - No extra functionality, no optimization
   - Commit: `feat: implement [feature] to pass test`

3. **REFACTOR** — Improve code quality
   - Clean up duplication, improve naming
   - Tests must stay green
   - Commit: `refactor: clean up [feature] implementation`

## Test Pyramid

Structure tests at three levels. The ecosystem reference file provides specific annotations, tools, and examples for each level.

| Level | Purpose | Speed | Scope |
|-------|---------|-------|-------|
| **Unit** | Test a single function/class in isolation with mocked dependencies | Fast (< 100ms) | Narrow |
| **Integration** | Test interaction between multiple components or with real infrastructure | Moderate | Medium |
| **End-to-End / API** | Test full request-response flow through the running application | Slow | Wide |

> Aim for **many unit tests**, **fewer integration tests**, and **minimal E2E tests**. Each level should add confidence without duplicating coverage from the level below.

## Workflow

```
1. Detect Ecosystem → 2. Load Reference → 3. RED (failing test) → 4. GREEN (minimal impl) → 5. REFACTOR → 6. Repeat
```

### Step 1: Detect Project Ecosystem

Identify the project type by checking for these files in the repository:

| File Present | Ecosystem |
|-------------|-----------|
| `build.gradle` or `build.gradle.kts` | Spring Boot (Gradle) |
| `pom.xml` | Spring Boot (Maven) |
| `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | Python |

### Step 2: Load Reference File

Read the ecosystem-specific reference file listed in the table above. It contains:
- Test layer annotations/decorators and when to use them
- Dependency/package configuration for test libraries
- Complete code examples for each test type
- Naming conventions and directory structure
- Build and test commands

### Steps 3–6: Red-Green-Refactor Cycle

For each layer of the feature (e.g., controller → service → repository, or route → service → data access):

1. **Write a failing test** for the current layer — verify it fails for the right reason
2. **Implement the minimal code** to make the test pass — no more
3. **Refactor** — improve names, extract helpers, remove duplication; tests must stay green
4. **Move to the next layer** and repeat

## Key Principles

- **Never write production code without a failing test**
- **One assertion concept per test** (multiple asserts OK if testing one behavior)
- **Tests are documentation** — names should describe behavior, not implementation
- **Fast feedback** — unit tests < 100ms; use lightweight test slices/fixtures over full application context
- **Isolate tests** — no shared mutable state between tests
- **Follow the ecosystem's conventions** — see the reference file for naming, directory structure, and tooling
