---
id: SKILL-angular-0001-html-templates
name: angular-html-templates
title: Angular HTML Template Authoring
version: 1.0.0
status: active
owner: enterprise-architecture
concern: angular
created: 2026-04-29
lastUpdated: 2026-04-29
description: Authoring guidance for Angular HTML templates in any Angular application — covers template clarity, control-flow syntax, binding, accessibility, and safe edits to existing templates.
trigger_keywords:
  - angular template
  - angular html
  - ngIf
  - ngFor
  - control flow
  - angular accessibility
  - angular ui framework
applyTo: "**/*.component.html"
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# Angular HTML Template Authoring Skill

Guidance for authoring and editing Angular HTML templates in any Angular application.

## Template Clarity

- Keep templates readable and consistent with the existing project style.
- Prefer semantic HTML elements (`<button>`, `<nav>`, `<section>`, `<table>`) over generic `<div>` and `<span>` when they convey meaning.
- **Prefer the project's existing UI/CSS framework components** (e.g., Angular Material, PrimeNG, Nebular, NG-ZORRO, Bootstrap, Tailwind UI, or an in-house design system) over custom `<div>` + manual styles when a suitable component or utility class exists. This reduces custom CSS and ensures visual consistency.
- Do not introduce a new UI framework into a template — match whatever the project already uses. If the project has no UI framework, stick to plain semantic HTML and the project's stylesheet conventions.
- Avoid deeply nested markup. If a section becomes hard to follow, consider whether it should be a child component.
- Use consistent indentation and attribute ordering as found in nearby templates.

## Binding and Template Logic

- **For new code**, use the built-in control flow syntax: `@if`, `@else`, `@for`, `@switch`, `@empty` instead of `*ngIf`, `*ngFor`, `*ngSwitch`. Do not migrate existing templates unless explicitly requested.
- Use Angular binding syntax clearly: `[property]`, `(event)`, `[(ngModel)]`.
- Keep template expressions simple. Move complex logic (calculations, multi-step conditions, data transformations) to the component class or a pure pipe.
- Avoid calling methods in template expressions that perform expensive work — prefer precomputed properties, signals, or pipes.
- Use `track` in `@for` loops (or `trackBy` in legacy `*ngFor`) when iterating over lists. When the component uses `OnPush` change detection or signals, `track` is essential — without it, the view may not update correctly when list items change.
- Prefer the `async` pipe (or signal reads) over manual subscription handling in components when consuming observables in templates.

## Readability

- Use multi-line attribute formatting for elements with many attributes.
- Group related attributes together (structural directives, bindings, event handlers, static attributes).
- Use clear and descriptive template reference variables (`#filterInput`, `#dialogRef`).

## Accessibility and Semantic HTML

- Use native HTML elements for their intended purpose (`<button>` for actions, `<a>` for navigation).
- Include `aria-label` or visible labels for interactive elements that lack descriptive text.
- Ensure form inputs have associated labels (explicit `<label for="">` or `aria-label`).
- Do not suppress focus indicators without providing an alternative.
- Provide meaningful `alt` text on `<img>` elements (or `alt=""` for purely decorative images).
- Follow existing project accessibility patterns — these are baseline expectations, not a license to rewrite working markup.

## Styling Rules

- **Do not use inline styles** (`style="..."`) in HTML templates. All styles belong in the component's stylesheet (`.css`, `.scss`, `.less`, etc.).
- Apply classes via `[class.foo]`, `[ngClass]`, or static `class` attributes rather than inline `style` bindings.
- For project-specific stylesheet conventions (preprocessor, units, scoping, naming), defer to the project's styling guide or sibling style instructions.

## Existing Code Safety

- When editing an existing template, preserve the current structure unless the change clearly improves readability or fixes a bug.
- Avoid unnecessary DOM changes that could affect CSS selectors, component styling, or test queries (`data-testid`, `data-test`, automation hooks).
- Do not rewrite templates to modernize style unless explicitly requested.
- Match the patterns already present in the file or feature area.
