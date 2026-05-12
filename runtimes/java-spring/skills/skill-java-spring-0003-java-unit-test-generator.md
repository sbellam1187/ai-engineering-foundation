---
name: java-unit-test-generator
description: Generate comprehensive JUnit 5 + Mockito unit tests for Java classes following project standards. Automatically analyzes source code to create tests covering happy paths, edge cases, exception handling, and boundary conditions. Uses project builders, follows AAR pattern, and produces deep assertions. Triggers on keywords like "generate tests", "create unit tests", "write tests for", "test coverage", "JUnit", "Mockito".
trigger_keywords: generate tests, create tests, write tests, unit test, junit, mockito, test coverage, add tests, test this
---

# Java Unit Test Generator (JUnit 5 + Mockito)

Generate comprehensive, production-ready JUnit 5 unit tests with Mockito mocking that follow all project standards.

## Purpose

Generate unit tests for the **changed methods** of a given Java class — not the entire class. Scope is determined by the PR diff. Only when the entire file is brand-new (100% added lines) should all methods be tested.

## Inputs

- **Source class**: Java class to generate tests for (file path or class name)
- **Methods** (optional): Specific methods to test — when invoked from `@junit-writer`,
  this is the list of new/modified methods from the PR diff. Default: changed methods only (NOT "all").
- **Mode** (optional): `create` (default — new test class) or `augment` (add tests to an
  already-existing test file). See **Delta Mode** below.
  Both modes use the same scoping rule: only changed methods get new tests.

## Outputs

- **Create mode**: complete new test class at `src/test/java/<mirror-package>/[ClassName]Test.java`
- **Augment mode**: in-place edit of the existing test file — appends `@Test` methods only for the
  specified methods. Existing tests, fields, mocks, and `@BeforeEach` are preserved.
- **Format**: JUnit 5 + Mockito + AssertJ, following AAR pattern
- **Constraint**: All assertions must be deep (validate content, not just existence)

## Steps

### Step 0: Locate Any Existing Test File (Mode Selection)

Before writing anything, determine whether a test file for the source class already exists. Check in this order:

1. **Standard mirror**: `src/test/java/<pkg>/<Class>Test.java`
2. **Common variants** in the same mirror package: `<Class>Tests.java`, `<Class>IT.java`, `<Class>UnitTest.java`, `<Class>Spec.java`
3. **Import-based fallback** (catches non-standard names): `grep -rl --include='*.java' -F "import <fully.qualified.Class>;" src/test/java`

- If any check returns a hit → **mode = augment** (use Delta Mode procedure below)
- Otherwise → **mode = create** (proceed with Steps 1–3 to generate a new test class)

> Creating a parallel `<Class>Test.java` when an existing test file is present is forbidden — it produces duplicate, drifting test suites.

### Step 1: Read and Analyze Source Class

1. Read the source file being tested
2. Run `git diff origin/${PR_BASE_REF:-master}...HEAD -- <source-file>` to identify which methods were added or modified
3. Focus analysis on the **changed methods only** — understand their signatures, dependencies, business logic, and return values
4. If the entire file is new (100% added lines), all methods are considered "changed"

### Step 2: Identify Test Scenarios

For each **changed method** (not every method in the class), identify scenarios across these categories:
- **Happy Path**: Normal successful execution
- **Edge Cases**: Empty collections, null inputs, boundary values, single vs multiple items
- **Exception Scenarios**: Invalid input, missing data, business rule violations
- **Business Logic**: Rule triggering, calculation accuracy, state transitions

### Step 3: Generate Test Class (changed methods only)

**Test file location**: `src/test/java/<mirror-package>/[ClassName]Test.java`

Generate `@Test` methods **only for the changed methods identified in Step 1** — not for every method in the class.

```java
@ExtendWith(MockitoExtension.class)
class ExampleClassTest {

    @InjectMocks
    private ExampleClass target;

    @Mock
    private DependencyService mockDependency;

    @BeforeEach
    void setUp() {
        // Common setup if needed
    }

    @Test
    void shouldSucceed_whenValidCondition() {
        // Arrange
        // Act
        // Assert - DEEP assertions
    }
}
```

## Delta Mode — Augmenting an Existing Test File

Use this procedure when Step 0 found an existing test file (any naming). The goal is to add tests **only for the new/modified methods** without disturbing existing tests.

### Step D1: Identify Changed Methods

```bash
git diff "origin/${PR_BASE_REF:-master}...HEAD" -- <source-file>
```

From the diff, capture every method signature on a `+` line that looks like a Java method declaration (`public`, `protected`, `private`, `static`, `<T>`, etc.). These are the only methods that need new `@Test`s.

**If no new method signatures are found but the file IS in the PR diff**, the change is an **Internal Behavior Change** — see Step D3-B below.

### Step D2: Read the Existing Test File

Note:
- Package, class name, and `@ExtendWith(...)` annotation
- All `@InjectMocks`, `@Mock`, and helper fields
- Existing `@BeforeEach` setup
- Existing imports
- Helper / fixture methods you can reuse

### Step D3: Update Impacted Existing Tests

Before adding new tests, check whether the PR changes break any existing `@Test` methods in the file. Common causes:
- Method signature changed (parameters added/removed/retyped)
- Return type changed
- Business logic changed (different expected output)
- Dependencies changed (new `@Mock` needed, or mock setup needs adjustment)

For each impacted test:
- **Update it in place** — fix assertions, adjust mock stubs, update expected values
- Keep the same test method name and intent — do NOT delete and recreate
- Do NOT change tests that are not impacted by the PR changes

### Step D3-B: Internal Behavior Changes (No New Method Signatures)

When the PR diff shows changes **inside an existing method body** but no new or renamed method signatures, this is an **Internal Behavior Change**. Common examples:

| Change Type | Example | Required Test Action |
|-------------|---------|---------------------|
| **Modified error/violation message** | `"ILLGL REST"` → `"ILLEGAL REST PERIOD"` | Update `assertThat(...).contains("...")` in every existing test that asserts on the old message text |
| **New condition/branch in existing method** | Added `if (isInternational) { ... }` | Add **new `@Test` methods** covering the new branch (true and false paths). Also verify existing tests still cover the original path correctly |
| **Changed constant/threshold** | `MIN_REST = 600` → `MIN_REST = 660` | Update expected values in existing tests that depend on the old constant |
| **Changed return value logic** | Modified calculation formula | Update assertions in existing tests to match new expected output |
| **Added a call to a new dependency** | Added `validator.validate(...)` call | Add `@Mock` for the new dependency if needed, update `@BeforeEach` setup, and add tests for the new validation path |

**Procedure for internal behavior changes:**

1. Run `git diff` and carefully read every `+` and `-` line — even though no method signature changed, the **content** DID change
2. Identify every existing `@Test` method that exercises the changed code path — look for assertions on the old values (old message strings, old thresholds, old expected results)
3. **Update those existing tests in place** — change expected values, assertion strings, mock setups to match the new behavior
4. **Add new `@Test` methods** if the change introduced a new code path (e.g., a new `if` branch, a new validation, a new edge case) — cover both the new path and ensure the original path is still tested
5. If the issue's Changed Methods column says `_(see PR diff)_`, this is the signal to use this procedure

> **Key insight**: A file can require test updates even if zero new method signatures were added. Changed messages, conditions, constants, and logic are all **testable behavioral changes** that must be reflected in the test suite.

### Step D4: Add `@Test` Methods Only for the Changed Methods

For each new/modified method **that does not already have a passing test**, append `@Test` methods covering happy path / edge cases / exceptions, following the same conventions as the rest of the file:

- **Reuse** existing fields, mocks, `@BeforeEach`, helpers — do NOT redeclare them
- **Match style** — naming pattern, AAR comments, builder usage, assertion library — use whatever the existing file uses, even if it differs slightly from the project default
- **Add imports** only if you reference a type not already imported
- Place each new `@Test` near related existing tests when reasonable; otherwise append at the bottom (above the closing brace)

### Step D5: Forbidden Edits in Delta Mode

- ❌ Do NOT **delete** any existing test method — update impacted tests, but never remove them
- ❌ Do NOT change `@ExtendWith` on existing files
- ❌ Do NOT reformat unrelated lines
- ❌ Do NOT create a parallel `<Class>Test.java` next to the existing file
- ❌ Do NOT rewrite tests that are NOT impacted by the PR changes

### Step D6: Verify

```bash
mvn clean compile -DskipTests
mvn -Dtest=<ExistingTestClassName> test
mvn test
```

The full suite must pass — both updated existing tests and new tests must be green.

## Standards & Constraints

### Test Method Naming
Use `should[ExpectedBehavior]_when[Condition]()` pattern.

### Arrange-Act-Assert (AAR) Pattern
Every test MUST have clear `// Arrange`, `// Act`, `// Assert` comments.

### Deep Assertions — MANDATORY
- ❌ AVOID: `assertThat(response).isNotNull();`
- ✅ USE: `assertThat(response.getEmployeeId()).isEqualTo("EMP001");`
- Validate primitive fields, collection contents, nested objects, business logic results

### Mocking Strategy
- **Mock ONLY**: External service clients, database connections, complex dependencies, configuration properties
- **Use REAL objects for**: Domain objects, value objects, request/response objects, collections
- Use project builders when available (e.g., test data builders defined in the consuming project's `src/test/java` tree)

### Import Standards
- ✅ ALWAYS use import statements — NEVER fully qualified class names
- Use static imports for assertions: `import static org.assertj.core.api.Assertions.assertThat;`

### Verification Patterns
```java
verify(mockService).findEmployee("EMP001");
verify(mockService, times(1)).save(any(Employee.class));
verify(mockService, never()).delete(anyString());
```

## Quality Checklist

- [ ] **No duplicate test files** — if any test for the source class existed, it was augmented in place
- [ ] **Augment mode**: every changed method has at least one new `@Test`; impacted existing tests were updated (not deleted)
- [ ] **No existing tests were deleted** — impacted tests are updated in place, unimpacted tests are untouched
- [ ] Test class in correct mirror package (Create mode only)
- [ ] All imports explicit (no fully qualified names)
- [ ] `@ExtendWith(MockitoExtension.class)` or `@ExtendWith(SpringExtension.class)`
- [ ] `should[Expected]_when[Condition]` naming
- [ ] AAR pattern with comments
- [ ] Deep assertions validate content
- [ ] Project builders used for domain objects
- [ ] Only external dependencies mocked
- [ ] Happy paths, edge cases, and exceptions covered
- [ ] Helper methods extracted for repeated object creation

## References

- [references/ref-java-spring-0002-test-examples.md](references/ref-java-spring-0002-test-examples.md) — Complete test examples for service classes, validation classes, aggregation logic, and interaction testing
