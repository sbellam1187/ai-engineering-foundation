---
id: SKILL-java-spring-0002-spring-boot-tdd
name: spring-boot-tdd
title: Spring Boot TDD
version: 1.0.0
status: active
owner: enterprise-architecture
concern: java-spring
created: 2026-03-23
lastUpdated: 2026-03-23
description: Test-Driven Development for Spring Boot applications using the Red-Green-Refactor cycle. Use when building or modifying Spring Boot REST APIs with JPA/Hibernate and Spring Data. Covers unit tests (service/repository with Mockito), integration tests (@SpringBootTest, @DataJpaTest, Testcontainers), and controller tests (@WebMvcTest, MockMvc).
trigger_keywords:
  - test
  - tests
  - TDD
  - test-driven
  - write tests
  - test coverage
  - unit test
  - integration test
  - "@Test"
related:
  laws:
    - LAW-quality-0001-atomic-tdd
  adoptions: []
  skills: []
  plugins: []
---

# Spring Boot TDD Skill

## Skill: Spring Boot TDD

### Purpose
Develop Spring Boot applications using strict Test-Driven Development with the Red-Green-Refactor cycle.
Every feature is built test-first, ensuring high quality and maintainable code.

### Trigger Keywords
`test`, `tests`, `TDD`, `test-driven`, `write tests`, `test coverage`, `unit test`, `integration test`

### Scope / What to produce
- Unit tests for service layer (Mockito)
- Unit tests for repository layer (@DataJpaTest)
- Controller tests (@WebMvcTest, MockMvc)
- Integration tests (@SpringBootTest)
- Database integration tests (Testcontainers)
- Test fixtures and builders

### Hard constraints (must follow)
1. **Never write production code without a failing test** — Red phase must come first.
2. **One assertion concept per test** — Multiple asserts OK if testing one behavior.
3. **Tests are documentation** — Names must describe behavior clearly.
4. **Fast feedback** — Unit tests < 100ms, use test slices when possible.
5. **Isolate tests** — No shared mutable state between tests.
6. **Follow naming conventions** — `should{Expected}_when{Condition}()` for methods.
7. **Mirror package structure** — Test packages mirror main source packages.
8. **Commit at each phase** — Separate commits for RED, GREEN, REFACTOR.

### Input expected from user
- Feature or endpoint to implement
- Domain context and business rules
- Related entities or services involved
- Any specific edge cases to cover

### Output format
- Test class in `src/test/java` mirroring main structure
- Production code in `src/main/java`
- Commit messages following: `test:`, `feat:`, `refactor:` prefixes

---

## How to Activate This Skill

**Auto-trigger (easiest):**
- "Write tests for UserService"
- "Add test coverage for FlightTimeRule"
- "Test this class using TDD"
- "Create unit tests for PaymentProcessor"

**Explicit reference:**
- "Use the spring-boot-tdd skill to implement feature X"
- "Following spring-boot-tdd methodology, write tests for..."

## TDD Workflow

For each feature or change, follow this cycle:

1. **RED** - Write a failing test first
    - Test must compile but fail when run
    - Test defines the expected behavior
    - Commit: `test: add failing test for [feature]`

2. **GREEN** - Write minimal code to pass
    - Implement just enough to make the test pass
    - No extra functionality, no optimization
    - Commit: `feat: implement [feature] to pass test`

3. **REFACTOR** - Improve code quality
    - Clean up duplication, improve naming
    - Tests must stay green
    - Commit: `refactor: clean up [feature] implementation`

## Test Layer Guide

Select the appropriate test type based on what you're testing:

| Layer | Annotation | Use Case |
|-------|------------|----------|
| Unit (Service) | `@ExtendWith(MockitoExtension.class)` | Business logic with mocked dependencies |
| Unit (Repository) | `@DataJpaTest` | JPA queries, custom repository methods |
| Controller | `@WebMvcTest` | REST endpoints, request/response mapping |
| Integration | `@SpringBootTest` | Full context, end-to-end flows |
| Database Integration | `@Testcontainers` + `@SpringBootTest` | Real database behavior |

## Test Examples

See [references/ref-java-spring-0001-test-patterns.md](references/ref-java-spring-0001-test-patterns.md) for complete examples of each test type.

## Dependencies

Ensure `pom.xml` or `build.gradle` includes:

```xml
<!-- pom.xml -->
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId> <!-- or mysql, etc. -->
        <scope>test</scope>
    </dependency>
</dependencies>
```

## Naming Conventions

- Test classes: `{ClassName}Test.java` (unit) or `{ClassName}IT.java` (integration)
- Test methods: `should{ExpectedBehavior}_when{Condition}()`
- Package structure mirrors main source: `src/test/java` mirrors `src/main/java`

## Workflow Example

**Task**: Add endpoint `GET /api/users/{id}` returning user by ID

**Cycle 1 - Controller Test (RED → GREEN → REFACTOR)**
1. Write failing `@WebMvcTest` for endpoint → RED
2. Create controller method returning stub → GREEN
3. Clean up → REFACTOR

**Cycle 2 - Service Test (RED → GREEN → REFACTOR)**
1. Write failing unit test for `UserService.findById()` → RED
2. Implement service method → GREEN
3. Extract constants, improve naming → REFACTOR

**Cycle 3 - Repository Test (RED → GREEN → REFACTOR)**
1. Write `@DataJpaTest` for custom query if needed → RED
2. Implement repository method → GREEN
3. Optimize query → REFACTOR

**Cycle 4 - Integration Test**
1. Write `@SpringBootTest` verifying full flow → should pass if cycles 1-3 done correctly

## Key Principles

- **Never write production code without a failing test**
- **One assertion concept per test** (multiple asserts OK if testing one behavior)
- **Tests are documentation** - names should describe behavior
- **Fast feedback** - unit tests < 100ms, integration tests use slices when possible
- **Isolate tests** - no shared mutable state between tests

---

## Reference Files

| File                                                                             | Purpose                                          |
|----------------------------------------------------------------------------------|--------------------------------------------------|
| [references/ref-java-spring-0001-test-patterns.md](references/ref-java-spring-0001-test-patterns.md) | Complete test examples for each Spring Boot layer |

---

## Standard Prompt (copy/paste)

You are the **Spring Boot TDD skill**.  
Develop features using strict Test-Driven Development with Red-Green-Refactor cycle.  
Follow constraints in this skill:
- Never write production code without a failing test
- One assertion concept per test
- Follow naming convention: `should{Expected}_when{Condition}()`
- Commit separately at each phase (RED, GREEN, REFACTOR)
Output test files in `src/test/java` mirroring main package structure.

---

## Checklist

After completing a TDD cycle, verify:
- [ ] Test was written BEFORE production code (Red phase)
- [ ] Test failed initially for the right reason
- [ ] Minimal code written to pass test (Green phase)
- [ ] Code refactored without breaking tests (Refactor phase)
- [ ] Test method follows `should{Expected}_when{Condition}()` naming
- [ ] Test class follows `{ClassName}Test.java` or `{ClassName}IT.java` naming
- [ ] Package structure mirrors main source
- [ ] Separate commits for each TDD phase
- [ ] No shared mutable state between tests
- [ ] Unit tests execute in < 100ms

---

## Variants

### Variant A — Unit Tests Only (Service Layer)
If user only wants service layer unit tests:
- Use `@ExtendWith(MockitoExtension.class)`
- Mock all dependencies with `@Mock`
- Focus on business logic and edge cases
- Skip controller and integration tests

### Variant B — Controller Tests Only (API Layer)
If user only wants REST endpoint tests:
- Use `@WebMvcTest(ControllerClass.class)`
- Mock services with `@MockBean`
- Test request/response mapping, validation, error handling
- Use `MockMvc` for HTTP assertions

### Variant C — Integration Tests (Full Stack)
If user wants end-to-end integration tests:
- Use `@SpringBootTest` with full context
- Use `@Testcontainers` for real database
- Test complete request flow from controller to database
- Verify transactional behavior

### Variant D — Repository Tests Only (Data Layer)
If user only wants JPA repository tests:
- Use `@DataJpaTest` for JPA slice
- Use `TestEntityManager` for setup
- Test custom queries and derived query methods
- Verify entity mappings and constraints
