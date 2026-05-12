---
id: SKILL-java-spring-0001-junit-mockito
name: junit-mockito
title: JUnit + Mockito Test Generator
version: 1.0.0
status: active
owner: enterprise-architecture
concern: java-spring
created: 2026-03-23
lastUpdated: 2026-03-23
description: Generate unit tests only for existing Java code using JUnit 5 and Mockito. Prefer deterministic, isolated tests with clear arrange/act/assert structure.
trigger_keywords:
  - unit test
  - junit
  - mockito
  - test generator
  - generate test
related:
  laws:
    - LAW-quality-0001-atomic-tdd
  adoptions: []
  skills: []
  plugins: []
---

# JUnit + Mockito Test Generator Skill

## Skill: Java Unit Test Generator (JUnit 5 + Mockito)

### Purpose
Generate **unit tests only** for existing Java code. Do not modify production code unless explicitly asked.
Prefer deterministic, isolated tests with clear arrange/act/assert structure.

### Scope / What to produce
- JUnit 5 tests (`org.junit.jupiter.*`)
- Mockito for mocks (`org.mockito.*`)
- Use `@ExtendWith(MockitoExtension.class)` for pure unit tests
- Use `@TempDir` when filesystem is needed
- Use `assertThrows` for exceptions
- Use `ArgumentCaptor` when validating passed arguments
- Cover success, failure, edge cases, and boundary values

### Hard constraints (must follow)
1. **Do not change production code.** Only create or edit test files under:
   - `src/test/java/...`
2. **No external integration** unless explicitly requested:
   - No Spring context (`@SpringBootTest`) unless asked
   - No network calls
   - No database connections
3. **Deterministic tests**:
   - No reliance on current time unless injected/controlled
   - No random values unless seeded
4. **Readable structure**:
   - Use `// Arrange`, `// Act`, `// Assert` comments
   - Prefer descriptive test names: `methodName_condition_expectedOutcome`

### Input expected from user
- Target class name and package
- Source code (or file reference)
- Any domain rules / invariants
- Any known edge cases or bugs to guard against

### Output format
- Create a test class named `{ClassName}Test`
- Place in matching package under `src/test/java`
- Include a short comment at top: what is covered and what is intentionally not covered

---

## Standard Prompt (copy/paste)
You are the **Java Unit Test Generator skill**.  
Generate **JUnit 5 + Mockito unit tests only** for the selected class.  
Follow constraints in this skills.md:
- Do not modify production code
- Tests must be deterministic and isolated
- Cover success + failure + edge cases
Output only the test file content and where to place it.

### Checklist
- [ ] Happy path test(s)
- [ ] Null / empty input test(s) (if applicable)
- [ ] Boundary value test(s) (if applicable)
- [ ] Exception test(s)
- [ ] Interaction verification with mocks (`verify`)
- [ ] Captured arguments validated (if important)

---

## Variants

### Variant A — Controller tests (MockMvc)
If the selected file is a Spring MVC controller:
- Use `@WebMvcTest(ControllerClass.class)`
- Mock dependencies with `@MockBean`
- Use `MockMvc` for request/response assertions
- Do not start full app context unless explicitly asked

### Variant B — Service tests (pure unit)
If the selected file is a service:
- Prefer pure unit tests with Mockito
- No Spring annotations
- Mock collaborators
