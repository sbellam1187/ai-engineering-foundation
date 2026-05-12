---
id: SKILL-angular-0002-typescript
name: angular-typescript
title: Angular TypeScript Authoring
version: 1.0.0
status: active
owner: enterprise-architecture
concern: angular
created: 2026-04-29
lastUpdated: 2026-04-29
description: Authoring guidance for Angular TypeScript code (components, services, helpers, models) in any Angular application — covers conventions, RxJS/signals, change detection, file organization, and safe edits to existing code.
trigger_keywords:
  - angular typescript
  - angular component
  - angular service
  - rxjs
  - signals
  - inject
  - standalone component
  - onpush
applyTo: "**/*.ts"
related:
  laws: []
  adoptions: []
  skills:
    - SKILL-angular-0001-html-templates
  plugins: []
---

# Angular TypeScript Authoring Skill

Guidance for Angular TypeScript code — components, services, helpers, models, and other UI logic — in any Angular application.

## TypeScript Coding Expectations

- Use `readonly` where properties should not be reassigned after initialization.
- Avoid type assertions (`as`) unless there is no cleaner alternative.
- Keep union and intersection types simple and readable.
- Prefer **pure functions** without side effects for data transformations and calculations. Manage state through return values instead of mutating class properties when possible.
- Favor immutability: avoid mutating input parameters and shared objects.
- Avoid `any`. Prefer `unknown` plus narrowing when the type is genuinely unknown.

## Angular Code Conventions

- **For new code**, prefer modern Angular patterns: standalone components, the `inject()` function, and signals where the project supports them.
- **When editing existing code**, follow the patterns already present in the file (e.g., `@NgModule`, constructor injection). Modernize only the code you are actively changing, not the surrounding code.
- Use `@Injectable({ providedIn: 'root' })` for singleton services unless the project uses a different scoping convention.
- Use `BehaviorSubject` / `Subject` (or signals) for component and service state management, following existing patterns in the codebase.
- Use RxJS operators idiomatically: `map`, `switchMap`, `catchError`, `takeUntil`, `takeUntilDestroyed`, etc.
- Unsubscribe from observables properly to avoid memory leaks:
  - **Prefer the `async` pipe** when the data is only needed in the template — Angular handles unsubscription automatically and it works well with `OnPush`.
  - Use **`takeUntilDestroyed()`** (Angular 16+) or **`takeUntil`** with a `destroy$` Subject when the value is needed in the component class and there are multiple subscriptions.
  - Use **explicit `unsubscribe()`** for isolated, single subscriptions or in services where the lifetime is managed manually.
- When using `OnPush` change detection, ensure all data displayed in the template is immutable or flows through observables/signals. Verify that `trackBy` (or `track` in `@for`) is set on all list iterations to avoid rendering issues.

## Readability and Maintainability

- **Avoid magic numbers and magic strings.** Extract literals into well-named constants or enums.
- Prefer native JavaScript/TypeScript array and object methods (`find`, `map`, `filter`, `forEach`, `some`, `every`, `Object.entries`) over utility-library equivalents. Keep utility libraries (Lodash, Ramda, etc.) only where they add clear value (e.g., `debounce`, `throttle`, `cloneDeep`, `merge`, deep `get`/`set`).
- Keep functions small and focused on one responsibility.

## Visibility and Method Design

- If a method is not intended to be used outside its service or component, mark it `private` and add an explicit return type.
- If a service method is part of the public API, add an explicit return type and a brief JSDoc comment clarifying its purpose for external consumers.
- Do not use `console.log` / `console.error` for production error handling. Use the project's logging or notification service (e.g., a centralized logger, toast/alert/notification service, or error-reporting client). If none exists, surface errors through the appropriate Angular error handler rather than the console.

## File Organization

- Extract pure helper functions (no side effects, no Angular dependencies) into a `[component-name].helpers.ts` file alongside the component.
- Extract interfaces, types, and enums into a `[component-name].models.ts` file alongside the component, unless they belong in a shared `models/` or `types/` directory.
- When writing new code, group and order class members by responsibility (e.g., inputs/outputs, signals/state, lifecycle hooks, public API, event handlers, private helpers). Do not reorder existing members unless the task explicitly involves refactoring.

## State and Logic

- Keep business logic in services, not in components, when it involves data transformation, API calls, or shared state.
- Keep component classes focused on view logic: binding, user interaction, and delegation to services.
- Do not duplicate logic that already exists in a service or utility — reuse it.
- Treat state as immutable: produce new objects/arrays rather than mutating existing ones, especially with `OnPush` and signals.

## Existing Code Safety

- When editing existing files, preserve the surrounding patterns (DI style, RxJS vs. signals, module vs. standalone) unless the task is an explicit migration.
- Avoid drive-by refactors. Limit changes to the scope of the task.
- Do not remove or rename public APIs, selectors, or exported symbols without confirming there are no external consumers.
