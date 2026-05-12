# Code Review Standards Reference

Standards and checklists used by the Code Reviewer Agent. Organized by review category.

## Supported Technology Stacks

| Category | Technologies |
|----------|--------------|
| **Languages** | Java, Python, JavaScript/TypeScript, C#/.NET, Go, Ruby |
| **Frameworks** | Spring Boot, FastAPI, Express, ASP.NET, Django, Rails, React, Angular |
| **Testing** | JUnit, pytest, Jest, xUnit, Mocha |
| **Build Tools** | Maven, Gradle, npm, pip, dotnet |

## 1. Code Organization

- **Correct directory/package structure** for the framework
- **Separation of concerns** — Controllers, services, repositories
- **Consistent file naming** — Matches class/module name
- **No circular dependencies**

## 2. Naming Conventions

| Element | Convention | Examples |
|---------|------------|----------|
| Classes | PascalCase, descriptive | `UserService`, `OrderProcessor` |
| Methods | camelCase (Java/JS) or snake_case (Python) | `processOrder`, `validate_input` |
| Variables | Descriptive, matches value | `timeoutSeconds`, `isValid` |
| Constants | SCREAMING_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| Test Methods | Describes scenario | `should_return_user_when_valid_id` |

## 3. Code Quality Rules

Check for violations:

- ❌ Unused imports/variables
- ❌ Methods exceeding reasonable length (50-100 lines)
- ❌ Too many parameters (>5-7)
- ❌ Deep nesting (>3-4 levels)
- ❌ Code duplication
- ❌ Magic numbers/strings
- ❌ Hardcoded credentials or URLs
- ❌ Print statements in production code
- ❌ Catching generic exceptions without handling
- ❌ Empty catch blocks
- ❌ Commented-out code

## 4. Best Practices

- ✅ Single Responsibility Principle
- ✅ DRY (Don't Repeat Yourself)
- ✅ Proper error handling with meaningful messages
- ✅ Logging at appropriate levels
- ✅ Input validation
- ✅ Null safety / Optional usage
- ✅ Immutability where appropriate
- ✅ Dependency injection over hardcoded dependencies
- ✅ Configuration externalization

## 5. Testing Requirements

- ✅ Unit tests for new/changed logic
- ✅ Integration tests for API changes
- ✅ Tests cover success and error paths
- ✅ Edge cases covered
- ✅ Test names describe the scenario
- ✅ Assertions verify actual behavior (not just no exception)
- ✅ Mocks used appropriately

## 6. Security Checks

- ❌ Hardcoded secrets or credentials
- ❌ SQL injection risks
- ❌ XSS vulnerabilities
- ❌ Missing input validation
- ❌ Sensitive data in logs
- ❌ Missing authentication/authorization
