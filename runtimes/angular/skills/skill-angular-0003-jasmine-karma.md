---
id: SKILL-angular-0003-jasmine-karma
name: angular-jasmine-karma
title: Angular Unit Tests with Jasmine + Karma
version: 1.0.0
status: active
owner: enterprise-architecture
concern: angular
created: 2026-04-29
lastUpdated: 2026-04-29
description: Authoring guidance for Angular unit tests (`.spec.ts`) using Jasmine and Karma in any Angular application — covers Specify-first workflow, test design, mocking, coverage, and safe edits to existing tests.
trigger_keywords:
  - angular unit test
  - jasmine
  - karma
  - spec.ts
  - testbed
  - createSpyObj
  - fakeAsync
applyTo: "**/*.spec.ts"
related:
  laws:
    - LAW-quality-0001-atomic-tdd
  adoptions: []
  skills:
    - SKILL-angular-0001-html-templates
    - SKILL-angular-0002-typescript
  plugins: []
---

# Angular Unit Tests with Jasmine + Karma Skill

Guidance for authoring and maintaining Angular unit test files (`.spec.ts`) in any Angular application that uses Jasmine and Karma.

## Testing Framework

- The project uses **Jasmine** for test assertions and **Karma** as the test runner.
- Use the project's existing npm scripts (commonly `npm test` for watch mode, `npm run test:ci` for headless single-run, and `npm run test:coverage` for coverage). Defer to the actual scripts defined in the project's `package.json`.
- Do not introduce alternative test frameworks, assertion libraries, or runners (Jest, Vitest, Mocha, Chai, etc.) into a Jasmine/Karma project.

## Specify-First Workflow (Required)

Before writing or modifying any `.spec.ts` test file, produce Specify artifacts first as workspace files under `specs/<feature-name>/`:

1. `specs/<feature-name>/spec.md` — user stories, acceptance scenarios, edge cases, requirements.
2. `specs/<feature-name>/plan.md` — implementation and test strategy, mock strategy, technical context.
3. `specs/<feature-name>/tasks.md` — atomic test tasks grouped by phase with dependencies.
4. Implement or update `.spec.ts` files.

Use the specification as the source of truth for test scenarios. Every major behavior in tests must map to a user story or acceptance scenario from the spec. If a requested test change is not represented in the current spec, update the spec first, then write the tests.

## Unit Test Design

- Keep tests focused: one behavior per `it` block.
- Use a clear **arrange / act / assert** structure where practical.
- Test observable behavior and outputs, not implementation details.
- Keep tests deterministic — avoid relying on wall-clock timing, external state, or execution order.
- Prefer synchronous tests when possible. Use `fakeAsync`/`tick`, `waitForAsync`, or `async`/`await` only when strictly necessary.
- **Do not use `setTimeout`** in tests. When mocking observables with `of()`, emissions are synchronous — `setTimeout` adds unnecessary delays. Use `fakeAsync` + `tick()` only if the component has internal timers; otherwise, remove the timeout wrapper entirely.
- **Do not use `console.log` for assertions.** Logs are a debugging tool, not a verification mechanism. Assert on actual values, spy calls, or DOM state.
- **Avoid magic numbers** in test expectations — use named constants or document the expected value.
- Include both **happy path and failure/error scenarios** for each method or behavior.
- Cover **edge cases**: empty data, `null` / `undefined` inputs, error responses, and missing or incomplete objects.

## What Tests Should Cover

- Public methods and their expected outputs given specific inputs.
- Component behavior in response to user interaction and input changes.
- Service methods, including observable emissions, error handling, and edge cases.
- Guard, resolver, and interceptor logic where applicable.
- Test private methods directly when needed using `(component as any).methodName()` or `(service as any).methodName()` to ensure proper coverage. Prefer testing through the public API where reasonable.
- Do not write tests for trivial getters or framework boilerplate.
- Aim for **>90% coverage on new code**, or whatever threshold the project enforces — defer to the project's coverage configuration if higher.

## Test Setup and Mocking

- Add all necessary imports. Always import actual service classes — do not provide them as string tokens.
- Use `TestBed` for component and service test configuration, following the project's existing setup patterns.
- Create mock services using `const` with `jasmine.createSpyObj<T>()` or `spyOn`. **Do not create hand-written mock classes** unless the project already does so consistently.
- Use `BehaviorSubject` or `Subject` to control mock observable behavior. Group related observable tests together and simulate emissions using `Subject`.
- Use `NO_ERRORS_SCHEMA` (or `CUSTOM_ELEMENTS_SCHEMA`) to ignore unknown child components when testing a component in isolation, only if that matches the existing pattern in the project.
- Reuse existing testing utilities, mock factories, and setup helpers found in the project before creating new ones.
- Do not over-mock: only mock what is necessary to isolate the unit under test.

## Mock Data

- Keep mock data **minimal and reusable**.
- Define a `baseMock` object (e.g., `baseMockRow`, `mockData`) and extend it with the spread operator (`...`) when variations are needed.
- Do not duplicate large object literals across tests — share and extend instead.
- Do not leave unused mock data or variables in the test file.

## Readability and Maintainability

- Use descriptive test names that explain the expected behavior: `it('should return filtered items when a filter is applied')`.
- Group related tests with `describe` blocks per public method or scenario.
- Keep test files focused on the unit they test — avoid unrelated assertions.
- Avoid duplicating large setup blocks; extract shared setup into `beforeEach` when it helps readability.
- Keep tests clean and concise. Do not leave unused code, dead imports, or commented-out blocks.

## Modifying Existing Tests

- When changing production code, update only the tests that are actually impacted by the change.
- Do not rewrite, reorganize, or rename unrelated tests.
- Match the existing test style in the file — do not introduce a new pattern without reason.
- If a test file has an established mock setup, extend it rather than replacing it.
