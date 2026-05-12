---
id: SKILL-ai-0001-standard-prompt-generation
name: standard-prompt-generation
title: Standard Prompt Generation
version: 1.0.0
status: active
owner: enterprise-architecture
concern: ai
created: 2026-03-24
lastUpdated: 2026-03-24
description: Enterprise-level standardized prompt templates for common development tasks across all technology stacks. Technology-agnostic templates that work with Java, Python, .NET, Node.js, React, Angular, and more. Contains templates for code review, testing, documentation, architecture, debugging, refactoring, security scanning, performance analysis, and API design.
trigger_keywords:
  - template
  - prompt
  - standard
  - review template
  - test template
  - documentation template
  - prompt template
  - standard prompt
  - code review
  - architecture review
related:
  laws: []
  adoptions:
    - ADOPTION-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle
  skills: []
  plugins: []
---

# Enterprise Standard Prompts Library

## Skill: Standard Prompt Generation

### Purpose
Provide enterprise-level, technology-agnostic prompt templates for common development tasks.
These templates ensure consistency across all teams regardless of their technology stack
(Java, Python, .NET, Node.js, Go, React, Angular, etc.).

### Trigger Keywords
`template`, `prompt`, `standard`, `review`, `test template`, `documentation template`, `architecture`

### Scope / What to produce
- Code review prompt templates (any language)
- Testing prompt templates (TDD, unit, integration, E2E)
- Documentation prompt templates
- Architecture review templates
- Debugging/troubleshooting templates
- Refactoring templates
- Security assessment templates
- Performance analysis templates
- API design templates
- Database design templates
- DevOps/CI-CD templates

### Hard constraints (must follow)
1. **Technology-agnostic** — Templates must work across all tech stacks.
2. **Self-contained** — Include all context needed for execution.
3. **Include checklists** — Every template has verification items.
4. **Use consistent structure** — Context, Requirements, Constraints, Output format.
5. **No hardcoding** — Use `[placeholder]` for project-specific values.
6. **Enterprise-aligned** — Follow AA engineering laws and standards.

### Input expected from user
- Task type (review, test, document, debug, refactor, etc.)
- Technology stack (optional - templates adapt)
- Target scope (file, module, service, system)
- Any specific concerns or focus areas

### Output format
- Markdown formatted prompt template
- Ready for copy/paste or agent consumption
- Bracketed placeholders for customization

---

## Quick Reference

| Category | Template | Use Case |
|----------|----------|----------|
| **Quality** | [Code Review](#code-review-template) | PR review, code quality check |
| **Quality** | [Architecture Review](#architecture-review-template) | Design review, system analysis |
| **Testing** | [Test Generation](#test-generation-template) | Write tests (TDD, unit, integration) |
| **Testing** | [Test Coverage Analysis](#test-coverage-analysis-template) | Identify testing gaps |
| **Documentation** | [Technical Documentation](#technical-documentation-template) | Generate docs from code |
| **Documentation** | [API Documentation](#api-documentation-template) | Document APIs (REST, GraphQL, gRPC) |
| **Development** | [Feature Implementation](#feature-implementation-template) | Build new features |
| **Development** | [Bug Investigation](#bug-investigation-template) | Debug and fix issues |
| **Development** | [Refactoring](#refactoring-template) | Improve code quality |
| **Security** | [Security Assessment](#security-assessment-template) | Vulnerability scanning |
| **Performance** | [Performance Analysis](#performance-analysis-template) | Identify bottlenecks |
| **DevOps** | [CI/CD Pipeline](#cicd-pipeline-template) | Pipeline configuration |
| **Data** | [Database Design](#database-design-template) | Schema design, migrations |

---

## Code Review Template

**Use when**: PR review, code quality assessment, peer review

**Works with**: All languages and frameworks

```markdown
## CODE REVIEW REQUEST

### Context
- **Repository**: [repo-name]
- **Branch/PR**: [branch or PR link]
- **Files**: [file paths or "entire PR"]
- **Technology**: [language/framework - e.g., Java/Spring, Python/FastAPI, Node/Express, .NET/C#, React, Angular]
- **Change Type**: [new feature / bug fix / refactor / configuration]

### Review Focus Areas

#### 1. Code Quality
- [ ] Follows project coding standards and style guide
- [ ] Clear, descriptive naming (variables, functions, classes)
- [ ] No code duplication (DRY principle)
- [ ] Functions/methods have single responsibility
- [ ] Appropriate comments for complex logic
- [ ] No commented-out code or debug statements

#### 2. Logic & Correctness
- [ ] Business logic is correct and complete
- [ ] Edge cases are handled
- [ ] Error handling is appropriate
- [ ] No potential null/undefined issues
- [ ] Input validation is present
- [ ] State management is correct

#### 3. Testing
- [ ] Unit tests exist for new/changed code
- [ ] Tests cover happy path and edge cases
- [ ] Test names describe the scenario
- [ ] No flaky or environment-dependent tests
- [ ] Integration tests where appropriate

#### 4. Security
- [ ] No hardcoded secrets or credentials
- [ ] Input is sanitized/validated
- [ ] No SQL injection or XSS vulnerabilities
- [ ] Proper authentication/authorization checks
- [ ] Sensitive data is not logged

#### 5. Performance
- [ ] No obvious performance issues (N+1 queries, memory leaks)
- [ ] Appropriate caching where needed
- [ ] Efficient algorithms and data structures
- [ ] Database queries are optimized

#### 6. Maintainability
- [ ] Code is easy to understand
- [ ] Dependencies are appropriate and up-to-date
- [ ] Configuration is externalized
- [ ] Follows SOLID principles

### Output Format

| Category | Severity | File:Line | Issue | Suggestion |
|----------|----------|-----------|-------|------------|
| [quality/logic/test/security/performance] | [CRITICAL/MAJOR/MINOR/INFO] | | | |

### Summary
- **Approve**: Ready to merge
- **Request Changes**: Must fix before merge
- **Comment**: Optional improvements
```

---

## Architecture Review Template

**Use when**: Design review, system analysis, technical decision review

**Works with**: Any system architecture

```markdown
## ARCHITECTURE REVIEW REQUEST

### Context
- **System/Service**: [name]
- **Type**: [microservice / monolith / serverless / frontend / data pipeline]
- **Technology Stack**: [list technologies]
- **Review Scope**: [entire system / specific component / integration]

### Architecture Principles Check

#### 1. Design Principles
- [ ] Single Responsibility - each component has one purpose
- [ ] Loose Coupling - minimal dependencies between components
- [ ] High Cohesion - related functionality is grouped together
- [ ] Separation of Concerns - clear boundaries between layers
- [ ] Don't Repeat Yourself (DRY)

#### 2. Scalability
- [ ] Horizontally scalable components
- [ ] Stateless where possible
- [ ] Appropriate caching strategy
- [ ] Database scaling approach defined
- [ ] Load balancing considerations

#### 3. Reliability
- [ ] Fault tolerance mechanisms (retry, circuit breaker)
- [ ] Graceful degradation
- [ ] Health checks and monitoring
- [ ] Disaster recovery plan
- [ ] Data backup strategy

#### 4. Security
- [ ] Authentication mechanism defined
- [ ] Authorization model implemented
- [ ] Data encryption (at rest and in transit)
- [ ] Secrets management approach
- [ ] Network security (firewalls, VPCs)

#### 5. Maintainability
- [ ] Clear documentation
- [ ] Consistent patterns across codebase
- [ ] Logging and observability
- [ ] Configuration management
- [ ] Dependency management

#### 6. Integration
- [ ] API contracts defined
- [ ] Backward compatibility considered
- [ ] Async communication where appropriate
- [ ] Error handling for external dependencies

### Diagram Request
Generate or review:
- [ ] System context diagram (C4 Level 1)
- [ ] Container diagram (C4 Level 2)
- [ ] Component diagram (C4 Level 3)
- [ ] Sequence diagrams for key flows
- [ ] Data flow diagram

### Output Format
1. Architecture strengths
2. Areas of concern (with severity)
3. Recommendations for improvement
4. Technical debt identified
```

---

## Test Generation Template

**Use when**: Writing tests, TDD development, improving test coverage

**Works with**: All languages and test frameworks

```markdown
## TEST GENERATION REQUEST

### Context
- **Target**: [class/function/module/API endpoint]
- **Language**: [Java/Python/JavaScript/TypeScript/C#/Go/etc.]
- **Test Framework**: [JUnit/pytest/Jest/Mocha/xUnit/etc.]
- **Test Type**: [unit / integration / E2E / contract]

### TDD Approach (if applicable)

1. **RED** - Write failing test first
   - Test describes expected behavior
   - Test fails for the right reason

2. **GREEN** - Write minimal code to pass
   - Only implement what's needed
   - No premature optimization

3. **REFACTOR** - Improve code quality
   - Remove duplication
   - Keep tests green

### Test Scenarios to Cover

#### Happy Path
- [ ] Normal/expected input produces correct output
- [ ] All success scenarios

#### Edge Cases
- [ ] Empty input (null, empty string, empty list)
- [ ] Boundary values (min, max, zero)
- [ ] Special characters
- [ ] Large inputs

#### Error Cases
- [ ] Invalid input handling
- [ ] Exception/error scenarios
- [ ] Timeout handling
- [ ] Network failure (for integrations)

#### State Transitions (if applicable)
- [ ] Initial state
- [ ] State changes
- [ ] Final state validation

### Test Naming Convention
Pattern: `should_[ExpectedBehavior]_when_[Condition]`

Examples:
- `should_return_user_when_valid_id_provided`
- `should_throw_exception_when_input_is_null`
- `should_return_empty_list_when_no_results_found`

### Test Structure
```
// Arrange - Set up test data and mocks
// Act - Execute the code under test
// Assert - Verify the results
```

### Output Format
1. Test class/file with all test cases
2. Mock/stub setup if needed
3. Test data fixtures
4. Comments explaining each test scenario
```

---

## Test Coverage Analysis Template

**Use when**: Identifying gaps in test coverage

```markdown
## TEST COVERAGE ANALYSIS REQUEST

### Context
- **Scope**: [file / module / service / entire codebase]
- **Current Coverage**: [percentage if known]
- **Target Coverage**: [desired percentage]

### Analysis Checklist

#### Code Coverage
- [ ] Statement coverage
- [ ] Branch coverage
- [ ] Function/method coverage
- [ ] Line coverage

#### Scenario Coverage
- [ ] Happy paths tested
- [ ] Error paths tested
- [ ] Edge cases tested
- [ ] Boundary conditions tested

#### Integration Points
- [ ] API endpoints tested
- [ ] Database operations tested
- [ ] External service calls tested
- [ ] Message queue interactions tested

### Output Format
1. Coverage report summary
2. Untested code paths identified
3. Prioritized list of tests to add
4. Risk assessment for untested code
```

---

## Technical Documentation Template

**Use when**: Generating or improving technical documentation

**Works with**: Any codebase

```markdown
## TECHNICAL DOCUMENTATION REQUEST

### Context
- **Scope**: [file / module / service / system]
- **Audience**: [developers / architects / operations / all]
- **Documentation Type**: [README / API docs / architecture docs / runbook]

### Documentation Sections

#### 1. Overview
- [ ] Purpose and description
- [ ] Key features
- [ ] Technology stack
- [ ] Prerequisites

#### 2. Architecture
- [ ] High-level architecture diagram
- [ ] Component descriptions
- [ ] Data flow
- [ ] Integration points

#### 3. Getting Started
- [ ] Installation steps
- [ ] Configuration
- [ ] Running locally
- [ ] Running tests

#### 4. API Reference (if applicable)
- [ ] Endpoints list
- [ ] Request/response formats
- [ ] Authentication
- [ ] Error codes

#### 5. Configuration
- [ ] Environment variables
- [ ] Configuration files
- [ ] Feature flags

#### 6. Deployment
- [ ] Deployment process
- [ ] Environment-specific notes
- [ ] Rollback procedures

#### 7. Operations
- [ ] Monitoring and alerting
- [ ] Logging
- [ ] Troubleshooting guide
- [ ] Common issues and solutions

### Output Format
- Markdown documentation
- Mermaid diagrams where applicable
- Code examples
- Links to related documentation
```

---

## API Documentation Template

**Use when**: Documenting REST, GraphQL, or gRPC APIs

```markdown
## API DOCUMENTATION REQUEST

### Context
- **API Type**: [REST / GraphQL / gRPC / WebSocket]
- **Service**: [service name]
- **Version**: [API version]
- **Base URL**: [base URL or endpoint]

### Documentation Scope

#### Endpoints/Operations
For each endpoint document:
- [ ] HTTP method and path (REST) / Query/Mutation (GraphQL) / RPC method (gRPC)
- [ ] Description and purpose
- [ ] Authentication requirements
- [ ] Request parameters (path, query, headers, body)
- [ ] Request body schema with examples
- [ ] Response schema with examples
- [ ] Error responses
- [ ] Rate limiting

#### Authentication
- [ ] Auth mechanism (OAuth2, API Key, JWT, etc.)
- [ ] How to obtain credentials
- [ ] Token refresh process
- [ ] Required headers/parameters

#### Common Patterns
- [ ] Pagination
- [ ] Filtering and sorting
- [ ] Error response format
- [ ] Versioning strategy

### Output Format
- OpenAPI/Swagger spec (REST)
- GraphQL schema with descriptions
- Protobuf definitions (gRPC)
- Example requests and responses
```

---

## Feature Implementation Template

**Use when**: Building new features

**Works with**: Any technology stack

```markdown
## FEATURE IMPLEMENTATION REQUEST

### Feature Definition
- **Name**: [feature name]
- **User Story**: As a [role], I want [action] so that [benefit]
- **Technology Stack**: [languages/frameworks involved]

### Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Implementation Plan

#### 1. Design
- [ ] Review requirements
- [ ] Identify affected components
- [ ] Design API contracts (if applicable)
- [ ] Plan database changes (if applicable)
- [ ] Document technical approach

#### 2. Test First (TDD)
- [ ] Write failing tests for acceptance criteria
- [ ] Write unit tests for components
- [ ] Write integration tests

#### 3. Implementation
- [ ] Implement in small, testable increments
- [ ] Follow coding standards
- [ ] Keep commits atomic and well-described

#### 4. Quality Checks
- [ ] All tests passing
- [ ] Code review completed
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] Performance acceptable

### Checklist
- [ ] Feature meets acceptance criteria
- [ ] Tests cover happy path and edge cases
- [ ] Error handling implemented
- [ ] Logging added
- [ ] Configuration externalized
- [ ] Backward compatible (if applicable)
- [ ] Documentation updated
```

---

## Bug Investigation Template

**Use when**: Debugging, troubleshooting, fixing issues

```markdown
## BUG INVESTIGATION REQUEST

### Bug Report
- **Summary**: [one-line description]
- **Severity**: [critical / high / medium / low]
- **Environment**: [dev / test / staging / production]
- **Reported By**: [source]
- **Date**: [when discovered]

### Symptoms
- **Expected Behavior**: [what should happen]
- **Actual Behavior**: [what is happening]
- **Error Messages**: [any error messages or stack traces]
- **Frequency**: [always / intermittent / specific conditions]

### Reproduction Steps
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Investigation Checklist

#### 1. Gather Information
- [ ] Collect logs from affected timeframe
- [ ] Check monitoring/metrics
- [ ] Review recent deployments
- [ ] Identify affected users/requests

#### 2. Isolate the Problem
- [ ] Reproduce in lower environment
- [ ] Identify minimum reproduction case
- [ ] Determine root cause vs. symptom

#### 3. Root Cause Analysis
- [ ] Identify the faulty code/configuration
- [ ] Understand why it failed
- [ ] Check for related issues

#### 4. Fix and Verify
- [ ] Write failing test that reproduces bug
- [ ] Implement fix
- [ ] Verify test passes
- [ ] Test in multiple scenarios
- [ ] Check for regression

### Output Format
1. **Root Cause**: [explanation]
2. **Fix**: [code changes]
3. **Test**: [test that prevents regression]
4. **Prevention**: [how to prevent similar issues]
```

---

## Refactoring Template

**Use when**: Improving code quality, reducing technical debt

```markdown
## REFACTORING REQUEST

### Context
- **Target**: [file / class / module / service]
- **Technology**: [language/framework]
- **Reason**: [why refactoring is needed]

### Refactoring Goals
- [ ] Reduce complexity (cyclomatic complexity)
- [ ] Improve readability
- [ ] Remove duplication
- [ ] Improve testability
- [ ] Apply design patterns
- [ ] Improve performance
- [ ] Update deprecated code

### Refactoring Techniques to Consider
- [ ] Extract method/function
- [ ] Extract class/module
- [ ] Rename for clarity
- [ ] Replace conditionals with polymorphism
- [ ] Introduce design pattern
- [ ] Simplify complex expressions
- [ ] Remove dead code

### Safety Checklist
- [ ] Tests exist before refactoring
- [ ] Each change is small and incremental
- [ ] Tests pass after each change
- [ ] Behavior is preserved
- [ ] No new functionality added

### Output Format
1. Refactored code
2. Summary of changes made
3. Before/after comparison
4. Any remaining technical debt
```

---

## Security Assessment Template

**Use when**: Security review, vulnerability assessment, compliance check

```markdown
## SECURITY ASSESSMENT REQUEST

### Context
- **Scope**: [application / service / infrastructure / entire system]
- **Technology Stack**: [list technologies]
- **Compliance Requirements**: [PCI-DSS / HIPAA / SOC2 / GDPR / internal]

### Security Checklist

#### 1. Authentication & Authorization
- [ ] Strong authentication mechanism
- [ ] Proper session management
- [ ] Role-based access control (RBAC)
- [ ] Principle of least privilege
- [ ] Multi-factor authentication (where required)

#### 2. Data Protection
- [ ] Encryption at rest
- [ ] Encryption in transit (TLS)
- [ ] Sensitive data handling (PII, PCI)
- [ ] Data masking in logs
- [ ] Proper data retention/deletion

#### 3. Input Validation
- [ ] All inputs validated and sanitized
- [ ] Protection against injection attacks (SQL, XSS, etc.)
- [ ] File upload validation
- [ ] API input validation

#### 4. Secrets Management
- [ ] No hardcoded credentials
- [ ] Secrets in secure vault
- [ ] Secrets rotation capability
- [ ] Limited access to secrets

#### 5. Dependencies
- [ ] No known vulnerable dependencies (CVEs)
- [ ] Dependencies are up-to-date
- [ ] Dependency sources are trusted
- [ ] License compliance

#### 6. Infrastructure
- [ ] Network segmentation
- [ ] Firewall rules
- [ ] Security groups configured
- [ ] Container security (if applicable)

#### 7. Logging & Monitoring
- [ ] Security events logged
- [ ] Audit trail maintained
- [ ] Alerting for suspicious activity
- [ ] No sensitive data in logs

### Output Format

| Severity | Vulnerability | Location | OWASP Category | Remediation |
|----------|--------------|----------|----------------|-------------|
| [CRITICAL/HIGH/MEDIUM/LOW] | | | | |

### Summary
1. Critical findings (fix immediately)
2. High findings (fix before release)
3. Medium findings (plan to fix)
4. Low findings (fix when convenient)
```

---

## Performance Analysis Template

**Use when**: Performance review, optimization, bottleneck identification

```markdown
## PERFORMANCE ANALYSIS REQUEST

### Context
- **Target**: [application / service / API / database / specific operation]
- **Technology**: [language/framework/database]
- **Current Performance**: [response times, throughput, etc.]
- **Target Performance**: [SLAs, goals]

### Performance Areas

#### 1. Response Time
- [ ] Average response time
- [ ] P95/P99 latency
- [ ] Time to first byte
- [ ] Slow operations identified

#### 2. Throughput
- [ ] Requests per second
- [ ] Concurrent users supported
- [ ] Peak load handling

#### 3. Resource Utilization
- [ ] CPU usage
- [ ] Memory usage
- [ ] Disk I/O
- [ ] Network I/O

#### 4. Database Performance
- [ ] Query execution times
- [ ] N+1 query issues
- [ ] Index usage
- [ ] Connection pool sizing

#### 5. Caching
- [ ] Cache hit rates
- [ ] Cache effectiveness
- [ ] Cache invalidation strategy

#### 6. Code-Level
- [ ] Algorithm efficiency
- [ ] Memory allocations
- [ ] Blocking operations
- [ ] Async/parallel opportunities

### Output Format
1. Performance profile/baseline
2. Bottlenecks identified
3. Optimization recommendations (prioritized)
4. Expected improvement from each optimization
```

---

## CI/CD Pipeline Template

**Use when**: Setting up or reviewing build and deployment pipelines

```markdown
## CI/CD PIPELINE REQUEST

### Context
- **Repository**: [repo URL]
- **Technology**: [language/framework]
- **CI/CD Platform**: [GitHub Actions / GitLab CI / Jenkins / Azure DevOps / etc.]
- **Deployment Target**: [Kubernetes / AWS / Azure / GCP / on-prem]

### Pipeline Stages

#### 1. Build
- [ ] Dependency installation
- [ ] Compilation (if applicable)
- [ ] Artifact creation

#### 2. Test
- [ ] Unit tests
- [ ] Integration tests
- [ ] Code coverage check
- [ ] Static code analysis

#### 3. Security
- [ ] Dependency vulnerability scan
- [ ] SAST (Static Application Security Testing)
- [ ] Secret detection
- [ ] Container image scan (if applicable)

#### 4. Quality Gates
- [ ] Coverage threshold
- [ ] Code quality threshold
- [ ] No critical vulnerabilities
- [ ] All tests passing

#### 5. Deploy
- [ ] Environment-specific configuration
- [ ] Blue-green or canary deployment
- [ ] Health checks
- [ ] Rollback capability

#### 6. Post-Deploy
- [ ] Smoke tests
- [ ] Monitoring verification
- [ ] Notification/alerts

### Output Format
1. Pipeline configuration file
2. Required secrets/variables
3. Environment setup
4. Troubleshooting guide
```

---

## Database Design Template

**Use when**: Designing schemas, planning migrations, data modeling

```markdown
## DATABASE DESIGN REQUEST

### Context
- **Database Type**: [PostgreSQL / MySQL / MongoDB / DynamoDB / etc.]
- **Use Case**: [OLTP / OLAP / mixed]
- **Scale**: [expected data volume, read/write patterns]

### Design Considerations

#### 1. Schema Design
- [ ] Entities and relationships defined
- [ ] Normalization level appropriate
- [ ] Primary keys defined
- [ ] Foreign keys and constraints
- [ ] Data types optimized

#### 2. Indexing Strategy
- [ ] Primary key indexes
- [ ] Foreign key indexes
- [ ] Query-based indexes
- [ ] Composite indexes where needed
- [ ] Index maintenance plan

#### 3. Performance
- [ ] Query patterns analyzed
- [ ] Partitioning strategy (if needed)
- [ ] Read replicas (if needed)
- [ ] Connection pooling

#### 4. Data Integrity
- [ ] Constraints defined
- [ ] Triggers (if needed)
- [ ] Validation rules
- [ ] Referential integrity

#### 5. Migration Plan
- [ ] Backward compatible changes
- [ ] Data migration scripts
- [ ] Rollback scripts
- [ ] Zero-downtime deployment

### Output Format
1. ER diagram
2. DDL scripts
3. Migration scripts
4. Index recommendations
5. Query optimization notes
```

---

## Usage

### For Developers
1. Find the template for your task
2. Copy and fill in the `[placeholder]` sections
3. Use directly or with AI agents

### For AI Agents
Templates are automatically selected based on user intent:
- "Review this code" → Code Review Template
- "Write tests for" → Test Generation Template
- "Document this" → Technical Documentation Template
- "Why is this slow" → Performance Analysis Template

### Extending Templates
Add new templates following the pattern:
1. Clear title with use case
2. Context section with placeholders
3. Checklist for completeness
4. Output format specification

---

## Standard Prompt (copy/paste)

You are the **Standard Prompt Generation skill**.  
Provide enterprise-level, technology-agnostic prompt templates for development tasks.  
Follow these constraints:
- Templates must work across all technology stacks
- Include checklists for completeness
- Use `[placeholder]` for project-specific values
- Structure: Context, Requirements, Checklist, Output Format
Output markdown formatted template ready for immediate use.

---

## Checklist

When using templates, verify:
- [ ] Appropriate template selected for the task
- [ ] All placeholders filled with project-specific values
- [ ] Technology stack specified (if relevant)
- [ ] Scope is clear and bounded
- [ ] Output format matches needs
- [ ] Checklist items are addressed

---

## Variants

### Variant A — Quick Template
Return minimal template with essential sections only for quick tasks.

### Variant B — Comprehensive Template
Return full template with all sections for thorough analysis.

### Variant C — Technology-Specific
Adapt generic template with technology-specific guidance (e.g., Java patterns, Python idioms).

### Variant D — Compliance-Focused
Add compliance and audit requirements to template (PCI-DSS, HIPAA, SOC2).
