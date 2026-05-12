# DotNet Agent – Engineering Constitution

> **SYNC IMPACT REPORT**
> - **Version Change**: Initial publication (1.0.0)
> - **Modified Principles**: 6 core principles established (Code Quality, DI/Async, Testing, API/Versioning, Security, Observability)
> - **Added Sections**: Technology Stack, Development Workflow, Code Review Checklist, CI/CD Requirements
> - **Template Sync**: Constitution now governs all template generation, task validation, and PR enforcement
> - **Status**: ACTIVE – All development MUST comply immediately

---

**Title**: DotNet Agent – Engineering Constitution  
**Version**: 1.0.0  
**Ratified**: 2026-04-14  
**Status**: Active  
**Last Amended**: 2026-04-29

---

## Core Principles (NON-NEGOTIABLE)

### 1. Code Quality and Maintainability

Every line of code MUST meet these requirements:
- **SOLID principles**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **Clean Code**: Descriptive naming, methods ≤20 lines, cyclomatic complexity ≤10, no "WTF comments"
- **DRY principle**: No code duplication; shared logic extracted to utilities or services
- **Documentation**: XML doc comments on all public APIs; architecture decisions in ADRs
- Code MUST pass StyleCop/Roslyn analyzers; formatting enforced via EditorConfig
- Technical debt MUST be tracked in backlog; refactoring is a first-class task, not optional

Example C# implementations of SOLID principles:

**Single Responsibility Principle (SRP)**

```csharp
public class OrderCalculator
{
    public decimal CalculateTotal(IEnumerable<OrderItem> items)
    {
        return items.Sum(item => item.Price * item.Quantity);
    }
}

public class OrderRepository
{
    public Task SaveAsync(Order order)
    {
        return Task.CompletedTask;
    }
}
```

**Open/Closed Principle (OCP)**

```csharp
public interface IDiscountStrategy
{
    decimal Apply(decimal amount);
}

public class NoDiscountStrategy : IDiscountStrategy
{
    public decimal Apply(decimal amount) => amount;
}

public class PercentageDiscountStrategy : IDiscountStrategy
{
    private readonly decimal _percentage;

    public PercentageDiscountStrategy(decimal percentage)
    {
        _percentage = percentage;
    }

    public decimal Apply(decimal amount) => amount - (amount * _percentage);
}

public class PriceCalculator
{
    public decimal Calculate(decimal amount, IDiscountStrategy discountStrategy)
    {
        return discountStrategy.Apply(amount);
    }
}
```

**Liskov Substitution Principle (LSP)**

```csharp
public abstract class NotificationSender
{
    public abstract Task SendAsync(string message);
}

public class EmailSender : NotificationSender
{
    public override Task SendAsync(string message)
    {
        Console.WriteLine($"Email sent: {message}");
        return Task.CompletedTask;
    }
}

public class SmsSender : NotificationSender
{
    public override Task SendAsync(string message)
    {
        Console.WriteLine($"SMS sent: {message}");
        return Task.CompletedTask;
    }
}
```

**Interface Segregation Principle (ISP)**

```csharp
public interface IWorker
{
    Task WorkAsync();
}

public interface IManager
{
    Task ApproveBudgetAsync();
}

public class Developer : IWorker
{
    public Task WorkAsync()
    {
        Console.WriteLine("Writing code");
        return Task.CompletedTask;
    }
}

public class TeamLead : IWorker, IManager
{
    public Task WorkAsync()
    {
        Console.WriteLine("Coordinating work");
        return Task.CompletedTask;
    }

    public Task ApproveBudgetAsync()
    {
        Console.WriteLine("Budget approved");
        return Task.CompletedTask;
    }
}
```

**Dependency Inversion Principle (DIP)**

```csharp
public interface IMessageProvider
{
    Task<string> GetMessageAsync();
}

public class DatabaseMessageProvider : IMessageProvider
{
    public Task<string> GetMessageAsync()
    {
        return Task.FromResult("Message from database");
    }
}

public class MessageProcessor
{
    private readonly IMessageProvider _messageProvider;

    public MessageProcessor(IMessageProvider messageProvider)
    {
        _messageProvider = messageProvider;
    }

    public async Task ProcessAsync()
    {
        var message = await _messageProvider.GetMessageAsync();
        Console.WriteLine($"Processing: {message}");
    }
}
```

### 2. Async, Dependency Injection, and Middleware Internals

Constructor-only Dependency Injection is MANDATORY:
- All dependencies resolved via constructor parameters; NO service locator pattern
- Lifetimes MUST be explicit and correct: `Scoped` for business logic, `Transient` for stateless utilities, `Singleton` for expensive operations only
- Async/await MUST be used throughout the stack; synchronous blocking calls FORBIDDEN
- No `.Result`, `.Wait()`, or `GetAwaiter().GetResult()` except in Program.cs configuration
- Middleware ordering CRITICAL: authentication → authorization → exception handling → logging
- DI containers validated at startup via IValidateOptions and manual checks in Program.cs

Example of required constructor-based dependency injection pattern:

```csharp
private readonly IYourDataProvider _dataProvider;
private readonly IYourServiceProvider _serviceProvider;
private readonly IYourApiProvider _apiProvider;
private readonly IApplicationSettingsBusinessProvider _settingsProvider;
private readonly ILogger<YourBusinessProvider> _log;

/// <summary>
/// Constructor receives all dependencies from DI container
/// Each dependency is immutable (readonly)
/// </summary>
public YourBusinessProvider(
    IYourDataProvider dataProvider,
    IYourServiceProvider serviceProvider,
    IYourApiProvider apiProvider,
    IApplicationSettingsBusinessProvider settingsProvider,
    ILogger<YourBusinessProvider> log)
{
    _dataProvider = dataProvider;
    _serviceProvider = serviceProvider;
    _apiProvider = apiProvider;
    _settingsProvider = settingsProvider;
    _log = log;
}
```

### 3. Test-First Development and Coverage

Red-Green-Refactor cycle is NON-NEGOTIABLE:
- Unit tests MUST reach ≥80% code coverage (SonarQube verified)
- Integration tests MUST reach ≥20% coverage (focus: data layer, external APIs, inter-service contracts)
- Every feature implements: unit tests → feature tests → live tests (in that order, written first)
- Mocks/stubs used for external dependencies; integration tests use real database/containerized services
- Test failure MUST halt CI/CD; no merge to `Development/*` or `main/*` without green tests
- Flaky tests immediately marked `[Ignore]` and escalated; root cause analysis required before re-enable

### 4. API Contract, Versioning, and UX Consistency

REST API contracts are IMMUTABLE boundaries:
- All endpoints versioned: `/api/v1/*`, `/api/v2/*` (breaking changes require new version)
- DTOs are immutable at API boundary; no direct domain model exposure
- Request/response envelopes standardized: `{ data: T, metadata: {}, errors: [] }`
- No "magic" field names; versioning via URL path, NOT headers or query strings
- Deprecation timeline: new version released → old version deprecated → 6-month grace period → old version removed
- API documentation (OpenAPI/Swagger) auto-generated from code; documentation MUST stay synchronized with implementation

### 5. Security and Authentication

Security-first architecture enforced:
- **Ingress validation**: ALL user input validated at controller boundary; whitelist rules, reject invalid early
- **Secrets**: NO hardcoded credentials; all secrets loaded from environment variables or Azure Key Vault
- **HTTPS only**: TLS 1.2+ mandatory in production; certificate pinning for critical services
- **JWT tokens**: Validated on every request; expiration enforced; refresh tokens rotate
- **RBAC**: Role-based authorization via claims; policy-based authorization in middleware
- **SQL injection prevention**: Parameterized queries ONLY; no string concatenation for SQL
- **Audit logging**: All mutations (create, update, delete) logged with user ID, timestamp, before/after state
- **CORS**: Explicit whitelist only; no wildcard origins in production

### 6. Performance, Diagnostics, and Observability

Observability is built-in, not retrofitted:
- **Structured logging**: Every log entry includes trace ID, user ID, component name, severity; JSON format for aggregation
- **Centralized exception handling**: Middleware catches all exceptions, logs with context, returns standardized error response
- **Trace IDs**: Generated at request ingress; propagated across all service calls (logging, monitoring, tracing)
- **Health/Readiness endpoints**: `/health` (liveness) and `/ready` (readiness) for Kubernetes; depend on all critical services
- **Metrics**: Request latency, error rates, business KPIs pushed to Application Insights; SLA thresholds defined
- **Diagnostics**: Correlation IDs in responses; request/response timing logged; slow query detection (>500ms)
- **Caching**: Strategic caching with cache invalidation policy; no cache stampedes
- **Database indexing**: Query plans analyzed; N+1 queries forbidden; pagination enforced (max 1000 records)

---

## Project Architecture

### Layered Architecture (Clean/Onion Architecture)

```
Project Root/
├── Solution File (.sln)
├── Configuration Files (YAML, Docker Compose, Dockerfile)
├── README & Documentation
│
├── API Layer/
│   ├── Project File
│   ├── Entry Point (Program.cs, Startup.cs)
│   ├── Configuration (appsettings.json)
│   ├── Controllers/
│   └── Common/
│
├── Business Logic Layer/
│   ├── Project File
│   ├── Business Providers/
│   ├── Enums/
│   ├── Interfaces/
│   ├── Utilities/
│   └── Extensions/
│
├── Data Access Layer/
│   ├── Project File
│   ├── Data Providers/
│   ├── Data Adapters/
│   ├── DTOs/
│   ├── Factories/
│   ├── Mappers/
│   ├── Interfaces/
│   └── Exceptions/
│
├── Models/Domain Objects Layer/
│   ├── Project File
│   ├── Models/
│   ├── Requests/
│   ├── Responses/
│   ├── External Integrations (CCS)/
│   └── Enums/
│
├── Services Layer/
│   ├── Project File
│   ├── API Providers/
│   ├── Service Providers/
│   ├── DTOs/
│   ├── Mappers/
│   ├── Factories/
│   ├── Interfaces/
│   └── Extensions/
│
├── Tests/
│   ├── Project File
│   ├── Configuration Files (appsettings variants)
│   ├── Test Helpers/
│   ├── Business Tests/
│   ├── Controller Tests/
│   ├── Feature Tests/
│   ├── Live Tests/
│   └── Models/
│
└── Kubernetes/
    └── Deployment Manifests/
```

### Layer Responsibilities

- **API Layer**: HTTP endpoints, request/response handling, controller actions, input validation
- **Business Logic Layer**: Core business rules, workflows, domain logic, calculations
- **Data Access Layer**: Database communication, ORM interactions, query execution
- **Model Layer**: Shared domain objects, DTOs, value objects, enums
- **Service Layer**: External API integrations, third-party service providers, data transformation
- **Tests**: Unit, integration, feature, and live testing across all layers
- **Kubernetes**: Container orchestration, deployment manifests, health checks

### API Layer – Controller Pattern

All controllers MUST follow this pattern:

```csharp
[ApiController]
[Route("api/[controller]")]
public class YourController : BaseController
{
    private readonly IYourBusinessProvider _provider;
    private readonly ILogger<YourController> _log;

    /// <summary>
    /// Creates the controller and resolves the Provider used to process the request
    /// </summary>
    public YourController(IYourBusinessProvider provider, ILogger<YourController> log)
    {
        _provider = provider;
        _log = log;
    }

    /// <summary>
    /// Operation description and purpose
    /// </summary>
    /// <param name="request">Request parameters and business data</param>
    [HttpPost]
    [Route("Operation")]
    [SwaggerResponse((int)HttpStatusCode.OK, "Successful response", typeof(YourResponse))]
    [SwaggerResponse((int)HttpStatusCode.BadRequest, "Invalid request")]
    public async Task<IActionResult> Operation([FromBody] YourRequest request)
    {
        YourResponse response = new YourResponse();
        string logTitle = "YourController.Operation()";

        try
        {
            if (request != null)
            {
                _log.LogInformation(logTitle + " - WebApi request: {0}", LogSanitizer.SerializeSafely(request));
            }

            response = await _provider.ProcessOperation(request);
        }
        catch (Exception ex)
        {
            string message = ex.BuildExceptionMessage();
            _log.LogError(logTitle + " - Error: {0}", message);
        }
        finally
        {
            _log.LogInformation(logTitle + " - WebApi response: {0}", LogSanitizer.SerializeSafely(response));
        }

        return BuildActionResult(response);
    }
}
```

**Requirements:**
- Inherit from `BaseController` for consistent response handling
- Use constructor-only dependency injection
- Decorate with `[ApiController]` and `[Route("api/[controller]")]`
- Apply `[HttpPost]`, `[HttpGet]`, etc. attributes with specific `[Route]` values
- Include `[SwaggerResponse]` for all response types (success and error cases)
- Wrap logic in try-catch-finally with structured logging
- Validate input before calling business provider
- Return via `BuildActionResult(response)` helper method
- Log request, response, and errors with trace context

### Service Layer – Provider Pattern

All service providers SHOULD follow this pattern:

```csharp
public class YourServiceProvider : IYourServiceProvider
{
    private readonly IServiceCallFactory _serviceCallFactory;
    private readonly IYourResponseMapper _responseMapper;
    private readonly ILogger<YourServiceProvider> _log;

    /// <summary>
    /// Creates the service provider and resolves integration dependencies.
    /// </summary>
    public YourServiceProvider(
        IServiceCallFactory serviceCallFactory,
        IYourResponseMapper responseMapper,
        ILogger<YourServiceProvider> log)
    {
        _serviceCallFactory = serviceCallFactory;
        _responseMapper = responseMapper;
        _log = log;
    }

    /// <summary>
    /// Calls an external service and maps the result into the internal response model.
    /// </summary>
    public async Task<YourResponse> GetDataAsync(YourRequest request)
    {
        string logTitle = "YourServiceProvider.GetDataAsync()";

        try
        {
            _log.LogInformation(logTitle + " - Service request: {0}", JsonSerializer.Serialize(request));

            var client = _serviceCallFactory.GetYourApiClient();
            var externalResponse = await client.GetDataAsync(JsonSerializer.Serialize(request));
            var mappedResponse = _responseMapper.Map(externalResponse);

            _log.LogInformation(logTitle + " - Service call completed");
            return mappedResponse;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, logTitle + " - Service call failed");
            throw;
        }
    }
}
```

**Requirements:**
- Implement a service interface such as `IYourServiceProvider`
- Use constructor-only dependency injection for factories, mappers, and logging
- Keep service-layer logic focused on external integrations and data transformation
- Use async methods for outbound calls
- Log service requests, completions, and failures with context
- Map external responses into internal models before returning
- Rethrow exceptions after logging so upstream layers can handle them consistently

---

## Technology Stack (FIXED)

These technology choices are NON-NEGOTIABLE and immutable:

- **Language**: C# (latest stable minor version)
- **Runtime**: .NET Core 8+ (LTS releases preferred)
- **Dependency Injection**: Microsoft.Extensions.DependencyInjection (built-in, constructor-only)
- **Configuration**: Microsoft.Extensions.Configuration (environment-based)
- **Logging**: Serilog with Application Insights sink; structured JSON format
- **Database**: SQL Server (via Entity Framework Core 8+); migrations via EF Code-First
- **Testing**: xUnit for unit tests, Moq for mocking, FluentAssertions for assertions
- **API Documentation**: Swashbuckle for OpenAPI/Swagger generation
- **Security**: System.IdentityModel.Tokens.Jwt for JWT validation
- **Container**: Docker (Dockerfile in root); docker-compose for local development
- **Orchestration**: Kubernetes (manifests in `/k8s/*`)
- **Monitoring**: Application Insights for metrics, logs, traces; ILogger for structured logging
- **Build**: .NET CLI (`dotnet build`, `dotnet test`, `dotnet publish`)

---

## Development Workflow

### Branch Naming Convention (MANDATORY)

All branches MUST follow these patterns:

- **Main branch**: `main` (production-ready, signed commits only)
- **Feature branches**: `Development/feature/descriptive-name` (development staging area)
- **Bugfix branches**: `Development/bugfix/issue-id-descriptive-name`
- **Hotfix branches**: `main/hotfix/issue-id-descriptive-name` (production fixes only)
- **Experiment branches**: `Development/experiment/descriptive-name` (temporary, auto-delete after 2 weeks)

Branch names MUST:
- Use lowercase with hyphens (kebab-case)
- Include issue/ticket ID when applicable
- Be deleted after PR merge
- Never contain slashes deeper than 3 levels

### Commit Message Format (Conventional Commits)

All commits MUST follow Conventional Commits standard:

```
type(scope): subject

body

footer
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `chore`, `perf`, `ci`  
**Scope**: component/module name (optional)  
**Subject**: imperative, present tense, lowercase, no period, ≤50 chars  
**Body**: detailed explanation if needed; wrap at 72 chars  
**Footer**: `Closes #123`, `BREAKING CHANGE:` if applicable  

Example:
```
feat(auth): implement JWT refresh token rotation

Add automatic refresh token rotation on every token validation.
Tokens expire after 15 minutes; refresh tokens valid for 7 days.

Closes #456
```

### Pull Request Requirements (NON-NEGOTIABLE)

Every PR MUST include:

1. **Constitution Impact Statement**: 
   - Which principles affected? (Code Quality, DI, Testing, API, Security, Observability)
   - Any deviations? List with justification

2. **Test Evidence**:
   - Unit test coverage % (SonarQube report link)
   - New tests added: list them
   - Manual testing checklist completed

3. **Documentation Updates**:
   - README.md updated if user-facing change
   - API docs (Swagger) regenerated
   - ADR created for architectural decisions
   - Breaking changes documented in CHANGELOG.md

4. **Code Review Checklist** (reviewer enforces):
   - [ ] Follows SOLID principles
   - [ ] No service locator pattern; DI only
   - [ ] Async/await used correctly; no `.Result` or `.Wait()`
   - [ ] Tests pass (unit ≥80%, integration ≥20%)
   - [ ] No hardcoded secrets
   - [ ] SQL injection prevention verified
   - [ ] Logging includes trace ID, context
   - [ ] API versioning applied if contract changed
   - [ ] Performance implications reviewed (no N+1 queries)
   - [ ] Security review complete

5. **Approval Requirements**:
   - Minimum 2 code reviews (1 architect, 1 peer)
   - All comments resolved
   - CI/CD pipeline GREEN (all checks pass)
   - Constitution compliance verified

**Non-compliant PRs are AUTOMATICALLY BLOCKED** by CI/CD; no exceptions without security escalation.

---

## Code Review Checklist

Reviewers MUST verify every item before approval:

### Architecture & Design
- [ ] Layered architecture maintained (API → Business → Data → Models)
- [ ] No circular dependencies between layers
- [ ] DTO-to-domain mapping applied at boundaries
- [ ] Constructor-only DI used; no service locators
- [ ] SOLID principles followed (SRP, OCP, LSP, ISP, DIP)

### Async & Performance
- [ ] All I/O operations are `async` (database, HTTP, file)
- [ ] No `.Result`, `.Wait()`, or `GetAwaiter().GetResult()`
- [ ] DI lifetimes correct: Scoped for business logic, Transient for utilities
- [ ] No N+1 queries; include statements used for related data
- [ ] Pagination implemented (max 1000 records per request)
- [ ] Caching strategy documented if applicable

### Testing
- [ ] Unit tests ≥80% code coverage
- [ ] Integration tests ≥20% coverage
- [ ] Tests use AAA pattern (Arrange, Act, Assert)
- [ ] Mocks/stubs for external dependencies
- [ ] Test names describe expected behavior
- [ ] No flaky or skipped tests without justification

### Security
- [ ] ALL user input validated at controller boundary (whitelist)
- [ ] No hardcoded credentials; secrets from env vars/Key Vault only
- [ ] SQL injection prevention: parameterized queries only
- [ ] JWT tokens validated on every request
- [ ] RBAC/ABAC authorization applied where needed
- [ ] HTTPS enforced; no plain HTTP in production
- [ ] Audit logging for all mutations (create, update, delete)
- [ ] CORS whitelist explicit; no wildcards

### Logging & Observability
- [ ] Structured logging with trace ID, user ID, component name
- [ ] Exception handling centralized; context included in logs
- [ ] Health/readiness endpoints return correct status
- [ ] Metrics (latency, error rate) tracked
- [ ] Slow queries (>500ms) logged with context
- [ ] Diagnostic correlation IDs in response headers

### Code Quality
- [ ] StyleCop/Roslyn analyzer warnings resolved (no suppressions without justification)
- [ ] No code duplication; shared logic extracted
- [ ] Methods ≤20 lines; cyclomatic complexity ≤10
- [ ] Descriptive naming: classes, methods, variables self-documenting
- [ ] XML doc comments on all public APIs
- [ ] No "magic strings/numbers"; use constants or enums

### API Contract
- [ ] Endpoint versioned: `/api/v1/*` format
- [ ] Request/response envelope consistent
- [ ] DTOs immutable at API boundary
- [ ] OpenAPI/Swagger docs auto-generated and accurate
- [ ] Breaking changes documented; deprecation timeline included

### Documentation
- [ ] README.md updated if user-facing
- [ ] CHANGELOG.md updated (if released)
- [ ] ADR created for architectural decisions
- [ ] API documentation (Swagger) accurate
- [ ] Code comments explain "why", not "what"

---

## CI/CD Requirements

### Build Pipeline (MANDATORY)

Every commit triggers:

1. **Restore**: `dotnet restore` – verify all NuGet dependencies available
2. **Build**: `dotnet build --configuration Release` – compilation succeeds, no warnings
3. **Unit Tests**: `dotnet test --filter "Category!=Integration"` – 100% MUST pass
4. **Code Analysis**: SonarQube scan – coverage ≥80% unit, ≥20% integration
5. **Security Scan**: Dependency audit (OWASP), secret scanning (no keys exposed)
6. **Artifact**: `dotnet publish` – generate release artifact

### Deployment Pipeline (MANDATORY)

On `Development/*` merge:
1. Deploy to QA environment (Docker container)
2. Run smoke tests (health endpoint, critical workflows)
3. Run integration tests against QA database
4. Generate deployment report (version, changes, risks)

On `main` merge:
1. Deploy to staging (mirror production)
2. Run full integration test suite
3. Run performance regression tests
4. Manual approval gate (security/architect sign-off)
5. Deploy to production (blue-green deployment)
6. Post-deployment validation (health checks, critical endpoints)
7. Rollback capability on-demand for 30 minutes

### Quality Gates (BLOCKING)

PR is blocked if ANY gate fails:
- Build fails
- Tests fail (unit or integration)
- Code coverage drops below thresholds
- SonarQube detects security vulnerabilities (Critical/Blocker)
- Dependency audit finds unpatched vulnerabilities
- StyleCop violations unresolved

---

## Governance

### Amendment Process (REQUIRED for changes)

Any change to this constitution MUST follow this process:

1. **Rationale Document**: Why is the change needed? Link to issue/ADR
2. **Proposed Text**: Exact wording of change; highlight what's added/removed
3. **Implementation Plan**: How will existing code be migrated? Timeline?
4. **Rollback Plan**: How to revert if amendment causes issues?
5. **Approval**: Architecture review board approval required
6. **Version Bump**: Semantic versioning (MAJOR.MINOR.PATCH)
7. **Migration PR**: Update all affected code; PR MUST reference amendment

### Escalation Path

| Issue | Owner | Timeline | Escalation |
|-------|-------|----------|-----------|
| Constitution violation (minor) | Team Lead | 1 sprint | Architecture review |
| Constitution violation (critical) | Engineering Manager | Immediate | Security/Compliance review |
| Test coverage drop | Team Lead | Next sprint | Block PR until resolved |
| Performance regression | Tech Lead | Urgent (24h) | Engineering Manager |
| Security vulnerability | Security Team | Immediate (4h) | Executive escalation |
| Flaky test | QA Lead | 48 hours | Automate or remove test |

### Compliance Verification

- **Frequency**: Every PR + weekly audit
- **Responsibility**: Code reviewers + automated checks
- **Tool**: CI/CD pipeline enforces constitution automatically
- **Report**: Constitution compliance dashboard (SonarQube)
- **Audit Trail**: Git history + PR records serve as evidence

### Non-Compliance Consequences

1. **First violation**: Warning + coaching
2. **Second violation**: Mandatory architecture review + refactoring sprint
3. **Third violation**: Code review authority revoked until remediation
4. **Critical violations** (security, SQL injection): Immediate remediation required; escalate to management

---

## References

- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Clean Code by Robert C. Martin](https://www.oreilly.com/library/view/clean-code-a/9780136083238/)
- [Async/Await Best Practices in C#](https://docs.microsoft.com/en-us/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [OpenAPI/Swagger Specification](https://swagger.io/specification/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Entity Framework Core Documentation](https://learn.microsoft.com/en-us/ef/core/)
- [xUnit Testing Documentation](https://xunit.net/)
