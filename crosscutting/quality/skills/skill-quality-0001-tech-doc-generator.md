---
id: SKILL-quality-0001-tech-doc-generator
name: tech-doc-generator
title: Technical Documentation Generator
version: 1.0.0
status: active
owner: enterprise-architecture
concern: quality
created: 2026-03-23
lastUpdated: 2026-03-23
description: Generate comprehensive technical documentation for microservices and repositories by analyzing source code. Produces enterprise-grade docs including service overview, architecture diagrams, API reference, business rules, process flows, sequence diagrams, external integrations, resilience patterns, data models, error handling, security, configuration, and deployment notes. All documentation is strictly derived from source code.
trigger_keywords:
  - document
  - docs
  - documentation
  - generate docs
  - write docs
  - technical documentation
  - explain
  - describe
  - architecture overview
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# Technical Documentation Generator

## Skill: Technical Documentation Generator

### Purpose
Generate enterprise-grade technical documentation for microservices and repositories by systematically analyzing
source code. Every statement in the output is traceable to the codebase — nothing is assumed or fabricated.

### Trigger Keywords
`document`, `docs`, `documentation`, `generate docs`, `write docs`, `explain`, `describe`, `architecture overview`

### Scope / What to produce
- Complete documentation suite in `docs/` folder
- Service overview and tech stack analysis
- Architecture diagrams (Mermaid flowcharts)
- API reference tables
- Business rules and domain logic
- Process flows and sequence diagrams
- External integration maps
- Resilience patterns documentation
- Data model ER diagrams
- Error handling and security documentation
- Configuration and deployment guides

### Hard constraints (must follow)
1. **Code-Truth Policy** — Every statement MUST be directly traceable to source code.
2. **NEVER fabricate** features, patterns, integrations, or behaviors not found in code.
3. **NEVER assume** a pattern exists because it is common — verify it in the codebase.
4. **NEVER guess** technology choices, configurations, or business rules.
5. **ALWAYS cite** the source file and relevant code when documenting a behavior.
6. **ALWAYS use `[NEEDS VERIFICATION]`** when code is ambiguous or intent is unclear.
7. **ALWAYS flag dead code** or unused dependencies explicitly rather than documenting them as active.
8. **Skip empty sections** — Do not generate documents for which no relevant code exists.
9. **Validate all Mermaid diagrams** before including them in documentation.

### Input expected from user
- Repository path or reference to the codebase to document
- Scope (full documentation vs. specific sections like API-only, architecture-only)
- Target audience (if different from developers/architects)
- Any specific areas of focus or concern

### Output format
- Generate documentation in `docs/` folder with numbered files
- Use markdown format with metadata headers
- Embed Mermaid diagrams inline
- Include cross-links between related documents
- Build index in `docs/README.md`

---

## How to Activate This Skill

**Auto-trigger (easiest):**

- "Document the authentication flow"
- "Generate documentation for UserService"
- "Explain how this module works"
- "Create technical docs"
- "Write architecture overview for this service"

**Explicit reference:**

- "Use tech-doc-generator skill to document..."
- "Following tech-doc-generator, create docs for..."

## When to Use This Skill

- User asks to **generate**, **create**, or **write** technical documentation for a service or repository
- User asks to **document this microservice** or **document this codebase**
- User asks for an **architecture overview**, **service overview**, or **technical spec** based on code
- User asks to **reverse-engineer documentation** from source code
- User wants to **understand what a service does** and needs formal docs
- User says "generate docs", "write tech docs", "create service documentation", "document this repo"
- User needs documentation for **onboarding developers** or **architecture review**

## ⚠️ CRITICAL: Code-Truth Policy

**EVERY statement in the generated documentation MUST be directly traceable to source code.**

1. ❌ **NEVER fabricate** features, patterns, integrations, or behaviors not found in code
2. ❌ **NEVER assume** a pattern exists because it is common — verify it in the codebase
3. ❌ **NEVER guess** technology choices, configurations, or business rules
4. ✅ **ALWAYS cite** the source file and relevant code when documenting a behavior
5. ✅ **ALWAYS use `[NEEDS VERIFICATION]`** when code is ambiguous or intent is unclear
6. ✅ **ALWAYS flag dead code** or unused dependencies explicitly rather than documenting them as active
7. ✅ **ALWAYS read the actual source files** before writing any documentation section

**If you cannot determine something from the code, say so. Do not fill gaps with assumptions.**

## Documentation Output Structure

The skill produces a `docs/` folder with the following files. **Only generate files for which relevant code exists.** If
a section has no backing code (e.g., no resilience patterns found), skip that file and note the omission in the index.

```
docs/
├── README.md                    # Index / table of contents
├── 01-overview.md               # Service overview & tech stack
├── 02-architecture.md           # High-level architecture (Mermaid diagrams)
├── 03-api-reference.md          # REST / GraphQL / gRPC endpoints
├── 04-business-rules.md         # Domain logic & validation rules
├── 05-process-flows.md          # Business process flowcharts (Mermaid)
├── 06-sequence-diagrams.md      # Request path sequence diagrams (Mermaid)
├── 07-external-integrations.md  # DB, queues, APIs, cache, etc.
├── 08-resilience-patterns.md    # Circuit breakers, retries, timeouts
├── 09-data-model.md             # Entity relationships (Mermaid ER diagram)
├── 10-error-handling.md         # Exception hierarchy & error codes
├── 11-security.md               # Auth, authorization, encryption
├── 12-configuration.md          # Env vars, config files, feature flags
└── 13-deployment.md             # Dockerfile, CI/CD, health checks
```

### docs/README.md — Index

- Service name, description, and metadata header
- Table of contents linking all generated doc files
- Quick-start summary (what the service does in 2-3 sentences)
- List of sections omitted and why (e.g., "No resilience patterns detected in codebase")

### docs/01-overview.md — Service Overview

- **Purpose**: What the service does (derived from README, main class, or entry point)
- **Tech Stack**: Language, framework, build tool, runtime (detected from build files)
- **Project Structure**: Directory layout with descriptions of key packages/modules
- **Build & Run**: Commands to build, test, and run locally (from build files, Makefile, scripts)
- **Dependencies**: Key libraries and their purpose (from dependency manifest)

### docs/02-architecture.md — Architecture

- **High-Level Architecture Diagram** (Mermaid flowchart): Service and its external dependencies
- **Component Breakdown**: Internal layers/modules and their responsibilities
- **Design Patterns**: Patterns detected in code (MVC, hexagonal, CQRS, event-driven, etc.)
- **Package/Module Dependency Flow**: How internal components depend on each other

### docs/03-api-reference.md — API Reference

- **Endpoints Table**: Method, path, description, request/response body, status codes
- **Authentication Requirements**: Per-endpoint auth (if annotated/configured)
- **Request/Response Examples**: Derived from DTOs, schemas, or OpenAPI specs in code
- **Pagination, Filtering, Sorting**: If implemented
- **API Versioning**: Strategy and current versions (if present)

### docs/04-business-rules.md — Business Rules

- **Domain Rules**: Validation logic, business constraints, conditional behaviors
- **State Machines**: State transitions if present
- **Calculations & Formulas**: Business computations found in service layer
- **Rule Sources**: File and method references for each rule

### docs/05-process-flows.md — Process Flows

- **Mermaid Flowcharts**: For each major business process/workflow
- **Decision Points**: Conditional branches with conditions from code
- **Happy Path & Error Paths**: Both documented
- **Trigger & Outcome**: What initiates the process and what the end state is

### docs/06-sequence-diagrams.md — Sequence Diagrams

- **Mermaid Sequence Diagrams**: For critical request paths (e.g., create order, process payment)
- **Participants**: All services/components involved including external systems
- **Synchronous vs Asynchronous**: Solid vs dotted lines
- **Error/Fallback Paths**: `alt` blocks for error handling

### docs/07-external-integrations.md — External Integrations

- **Integration Inventory Table**: System, type (DB/queue/API/cache), protocol, connection config
- **Database Connections**: JDBC/connection strings, ORM config, migration tools
- **Message Queues**: Topics/queues, producers, consumers, serialization
- **External API Calls**: HTTP clients, base URLs, endpoints called, auth method
- **Cache**: Provider, cache names/keys, TTL, eviction policies
- **File Storage**: S3/blob/local file system interactions
- **Mermaid Integration Diagram**: Showing all external touchpoints

### docs/08-resilience-patterns.md — Resilience Patterns

- **Circuit Breakers**: Which calls are protected, thresholds, fallback methods
- **Retry Policies**: Max attempts, backoff strategy, retryable exceptions
- **Timeouts**: Connection and read timeouts per integration
- **Bulkheads**: Thread pool isolation or semaphore configs
- **Fallback Strategies**: What happens when a dependency fails
- **Rate Limiting**: If present, limits and strategies
- **Health Checks**: Liveness/readiness probe implementations
- **Configuration Table**: Pattern, target, parameters, source file

### docs/09-data-model.md — Data Model

- **Mermaid ER Diagram**: Entities and relationships
- **Entity Descriptions**: Purpose, key fields, constraints
- **Indexes**: Defined indexes and their purpose
- **Migrations**: Migration tool and current schema version
- **Data Validation**: Field-level constraints (not null, unique, size, pattern)

### docs/10-error-handling.md — Error Handling

- **Exception Hierarchy**: Custom exceptions and their meaning
- **Global Error Handler**: How unhandled exceptions are caught and formatted
- **Error Response Format**: Standard error response structure
- **Error Codes**: Enumerated error codes and descriptions (if present)
- **Logging Strategy**: Log levels, structured logging, correlation IDs

### docs/11-security.md — Security

- **Authentication**: Mechanism (JWT, OAuth2, API key, session-based)
- **Authorization**: Role-based, attribute-based, or policy-based access control
- **Security Filters/Middleware**: Chain of security processing
- **Input Validation & Sanitization**: XSS, SQL injection protections
- **Secrets Management**: How secrets are loaded (env vars, vault, config server)
- **CORS Configuration**: If present
- **Encryption**: At rest and in transit (TLS config, field-level encryption)

### docs/12-configuration.md — Configuration

- **Environment Variables Table**: Name, description, default, required
- **Configuration Files**: Application config files and their purpose
- **Profiles/Environments**: Dev, staging, prod profile differences
- **Feature Flags**: Toggle mechanisms and current flags
- **External Config Sources**: Config server, parameter store, etc.

### docs/13-deployment.md — Deployment

- **Dockerfile Analysis**: Base image, build stages, exposed ports, entry point
- **CI/CD Pipeline**: Build steps, test stages, deployment stages (from pipeline config)
- **Infrastructure Notes**: Kubernetes manifests, Terraform, CloudFormation (if in repo)
- **Health Check Endpoints**: Path, expected response
- **Scaling Configuration**: Replicas, HPA, resource limits
- **Logging & Monitoring**: Log aggregation, metrics endpoints, tracing config

## Workflow

Execute these phases in order. **Read actual source files at every step — do not rely on assumptions.**

### Phase 1: Discovery

Scan the repository to identify language, framework, and project structure.

1. **Read root directory** — List all top-level files and folders
2. **Identify build system** — Look for build files to determine language and framework:

| File                                             | Language / Framework               |
|--------------------------------------------------|------------------------------------|
| `pom.xml`                                        | Java / Maven                       |
| `build.gradle` or `build.gradle.kts`             | Java or Kotlin / Gradle            |
| `package.json`                                   | JavaScript or TypeScript / Node.js |
| `go.mod`                                         | Go                                 |
| `requirements.txt`, `pyproject.toml`, `setup.py` | Python                             |
| `Cargo.toml`                                     | Rust                               |
| `*.csproj`, `*.sln`                              | C# / .NET                          |
| `Gemfile`                                        | Ruby                               |

3. **Read dependency manifest** — Parse the build file to identify:
    - Framework (Spring Boot, Express, NestJS, FastAPI, Gin, .NET, Rails, etc.)
    - Key libraries (ORM, HTTP client, messaging, caching, resilience, security)
4. **Map project structure** — Identify source directories, test directories, config directories, scripts
5. **Read README** — Extract stated purpose, setup instructions, any existing documentation
6. **Read configuration files** — `application.yml`, `application.properties`, `.env`, `config/`, etc.

### Phase 2: Framework Detection

Use detected build files and dependencies to select the appropriate scanning strategy.

#### Java / Spring Boot

- **Entry point**: Class annotated with `@SpringBootApplication`
- **Controllers**: `@RestController`, `@Controller`, `@RequestMapping`
- **Services**: `@Service`, `@Component`
- **Repositories**: `@Repository`, `JpaRepository`, `CrudRepository`
- **Entities**: `@Entity`, `@Table`, `@Document`
- **Config**: `@Configuration`, `@ConfigurationProperties`, `@Value`
- **Security**: `SecurityFilterChain`, `@EnableWebSecurity`, `@PreAuthorize`
- **Resilience**: `@CircuitBreaker`, `@Retry`, `@Bulkhead`, `@RateLimiter`, `@TimeLimiter`
- **Messaging**: `@KafkaListener`, `@RabbitListener`, `@JmsListener`, `KafkaTemplate`, `RabbitTemplate`
- **Caching**: `@Cacheable`, `@CacheEvict`, `@CachePut`, `RedisCacheManager`
- **HTTP Clients**: `@FeignClient`, `RestTemplate`, `WebClient`, `RestClient`
- **Scheduling**: `@Scheduled`, `@EnableScheduling`

#### JavaScript / TypeScript (Node.js)

- **Entry point**: `index.ts`, `main.ts`, `app.ts`, `server.ts`
- **Routes/Controllers**: Express `router.get()`, NestJS `@Controller()`, Fastify route definitions
- **Services**: NestJS `@Injectable()`, class-based services
- **Database**: Sequelize models, TypeORM entities, Mongoose schemas, Prisma schema
- **Config**: `dotenv`, `config` module, NestJS `@ConfigService`
- **Security**: Passport.js strategies, `express-jwt`, middleware auth
- **Resilience**: `opossum` (circuit breaker), `async-retry`, custom retry logic
- **Messaging**: `kafkajs`, `amqplib`, `bull`/`bullmq` (queue)
- **Caching**: `ioredis`, `cache-manager`, `node-cache`
- **HTTP Clients**: `axios`, `node-fetch`, `got`

#### Python

- **Entry point**: `main.py`, `app.py`, `manage.py`
- **Routes**: FastAPI `@app.get()`, Flask `@app.route()`, Django `urls.py`
- **Models**: SQLAlchemy models, Django models, Pydantic schemas
- **Config**: `pydantic.BaseSettings`, `python-dotenv`, `settings.py`
- **Security**: `fastapi.security`, Django auth, Flask-Login
- **Resilience**: `tenacity` (retry), `pybreaker` (circuit breaker)
- **Messaging**: `confluent-kafka`, `pika` (RabbitMQ), `celery`
- **Caching**: `redis-py`, `cachetools`, Django cache framework
- **HTTP Clients**: `httpx`, `requests`, `aiohttp`

#### Go

- **Entry point**: `main.go`, `cmd/` directory
- **Routes**: `chi`, `gin`, `echo`, `gorilla/mux` route definitions
- **Database**: `database/sql`, `gorm`, `sqlx`, `pgx`
- **Config**: `viper`, `envconfig`, `os.Getenv`
- **Security**: JWT middleware, OAuth2 handlers
- **Resilience**: `sony/gobreaker`, `avast/retry-go`, custom middleware
- **Messaging**: `segmentio/kafka-go`, `streadway/amqp`
- **Caching**: `go-redis`, `groupcache`, `ristretto`
- **HTTP Clients**: `net/http`, `resty`

#### C# / .NET

- **Entry point**: `Program.cs`, `Startup.cs`
- **Controllers**: `[ApiController]`, `ControllerBase`, `[HttpGet]`
- **Services**: DI-registered services, `IHostedService`
- **Database**: Entity Framework `DbContext`, `DbSet`, Dapper
- **Config**: `appsettings.json`, `IConfiguration`, `IOptions<T>`
- **Security**: `[Authorize]`, Identity, JWT Bearer, policy-based auth
- **Resilience**: Polly (`IAsyncPolicy`, `PolicyWrap`, `CircuitBreakerAsync`)
- **Messaging**: MassTransit, NServiceBus, `IConsumer<T>`
- **Caching**: `IDistributedCache`, `IMemoryCache`, StackExchange.Redis
- **HTTP Clients**: `IHttpClientFactory`, `HttpClient`, Refit

### Phase 3: Code Analysis

Systematically scan through the codebase layer by layer. **Read actual files — do not guess.**

1. **Entry point & bootstrap** — Read the main class/file to understand how the app starts, what modules/beans are
   registered
2. **Controllers / Routes** — Scan all route definitions to build the API reference:
    - HTTP method, path, parameters, request/response types
    - Authentication/authorization annotations
    - Validation constraints on request bodies
3. **Service layer** — Read service classes to extract:
    - Business logic and rules
    - Orchestration flows (which methods call which external systems)
    - Transaction boundaries
    - Decision trees and conditional logic
4. **Repository / Data access layer** — Identify:
    - Entities / models and their relationships
    - Custom queries
    - Database type (relational, document, graph, key-value)
5. **External clients** — Find all outbound HTTP calls, message producers, cache interactions:
    - Base URLs, endpoints, headers
    - Serialization/deserialization
    - Error handling per client
6. **Resilience configuration** — Search for:
    - Circuit breaker declarations (thresholds, fallback methods)
    - Retry policies (max attempts, backoff, retryable exceptions)
    - Timeout settings
    - Bulkhead / thread pool configurations
7. **Security configuration** — Read security config files:
    - Auth filter chains
    - Protected endpoints and roles
    - CORS rules
    - Token validation
8. **Error handling** — Find global exception handlers, custom exceptions, error response structures
9. **Configuration** — Parse all config files for environment variables, external URLs, feature flags
10. **Deployment artifacts** — Read Dockerfile, CI/CD pipeline files, Kubernetes manifests, infra-as-code

### Phase 4: Diagram Generation

Generate Mermaid diagrams for visual documentation. Follow these rules:

- **Use `mermaid-diagram-validator`** to validate every diagram before including it
- **Use `mermaid-diagram-preview`** to verify rendering
- **Max 15 nodes per diagram** — split complex diagrams into multiple focused ones
- **Use consistent naming** — PascalCase for components, lowercase for labels
- **Label all arrows** — include protocol, method, or data type
- **Use subgraphs** for logical boundaries (layers, domains, external systems)

#### Required Diagrams

| Document                    | Diagram Type      | Content                                          |
|-----------------------------|-------------------|--------------------------------------------------|
| 02-architecture.md          | `flowchart TD`    | Service components and external dependencies     |
| 05-process-flows.md         | `flowchart TD`    | Business process flowcharts with decision points |
| 06-sequence-diagrams.md     | `sequenceDiagram` | Request path interactions between components     |
| 07-external-integrations.md | `flowchart LR`    | Integration map showing all external touchpoints |
| 09-data-model.md            | `erDiagram`       | Entity relationships and cardinality             |

#### Diagram Syntax Reference

See [references/ref-quality-0002-mermaid-guide.md](references/ref-quality-0002-mermaid-guide.md) for complete syntax and patterns.

### Phase 5: Document Assembly

Write each documentation file following the templates in [references/ref-quality-0001-doc-template.md](references/ref-quality-0001-doc-template.md).

1. **Apply metadata header** to every document (service name, date, version)
2. **Write content** strictly from Phase 3 analysis — cite source files
3. **Embed validated Mermaid diagrams** from Phase 4
4. **Cross-link** between documents (e.g., API reference links to sequence diagrams)
5. **Build the index** (`docs/README.md`) with links to all generated files
6. **Omit empty sections** — if no relevant code exists for a document, do not generate it; list it as omitted in the
   index

### Phase 6: Cross-Reference & Verification

Final quality pass before delivering documentation.

1. **Source traceability** — Verify every documented feature, rule, or pattern has a source file reference
2. **Diagram validation** — Confirm all Mermaid diagrams pass `mermaid-diagram-validator`
3. **Link integrity** — Ensure all cross-document links resolve correctly
4. **Completeness check** — Verify all detected components are documented
5. **Ambiguity tagging** — Add `[NEEDS VERIFICATION]` tags where code intent is unclear
6. **Dead code flagging** — Mark any unused endpoints, deprecated methods, or unreachable code paths

## Enterprise Documentation Standards

### Metadata Header

Every document file must start with this metadata block:

```markdown
# [Document Title]

| Field         | Value                               |
| ------------- | ----------------------------------- |
| **Service**   | [service-name]                      |
| **Generated** | [YYYY-MM-DD]                        |
| **Source**    | [repository-url]                    |
| **Branch**    | [branch-name]                       |
| **Status**    | Auto-generated — review recommended |
```

### Formatting Rules

- **Headings**: Use `##` for major sections, `###` for subsections, `####` for details
- **Tables**: Use for structured data (endpoints, env vars, error codes, config)
- **Code blocks**: Use fenced code blocks with language tags (`java, `typescript, etc.)
- **File references**: Always include relative file path when citing source code:
  `(see src/service/OrderService.java:45)`
- **Cross-links**: Use relative markdown links between documents: `[See Sequence Diagrams](06-sequence-diagrams.md)`
- **Mermaid diagrams**: Embed inline in fenced ```mermaid blocks — do NOT link to external files
- **Lists**: Bullet lists for unordered items, numbered lists for ordered steps
- **Annotations**:
    - `[NEEDS VERIFICATION]` — ambiguous code, unclear intent
    - `[DEPRECATED]` — detected deprecated code still present
    - `[DEAD CODE]` — unreachable or unused code paths
    - `[TODO]` — incomplete implementations found in source

### Writing Style

- **Audience**: Developers and architects — assume technical proficiency
- **Tone**: Factual, concise, direct — no marketing language
- **Tense**: Present tense ("The service processes orders" not "The service will process orders")
- **Voice**: Active voice preferred ("The controller validates input" not "Input is validated by the controller")
- **Specificity**: Name exact classes, methods, files — avoid vague references

## Best Practices

### ✅ DO

- **Read source files thoroughly** before writing any section
- **Cite source files** with path and line numbers for every documented behavior
- **Use `[NEEDS VERIFICATION]`** when intent is ambiguous rather than guessing
- **Validate all Mermaid diagrams** with `mermaid-diagram-validator` before including
- **Split complex diagrams** into multiple focused ones (max ~15 nodes each)
- **Cross-link documents** so readers can navigate between related sections
- **Document what IS in the code**, including inconsistencies or issues found
- **Flag dead code and deprecated features** explicitly
- **Include both happy path and error paths** in flows and sequences
- **Keep tables concise** — use them for structured reference data

### ❌ DON'T

- **Don't fabricate** features, patterns, or integrations not present in code
- **Don't assume** standard patterns exist — verify each one in source
- **Don't document aspirational architecture** — document actual implementation
- **Don't include credentials or secrets** found in code — flag them as security issues instead
- **Don't generate empty documents** — skip sections with no backing code
- **Don't over-document trivial code** — focus on business-critical paths and non-obvious behavior
- **Don't present unvalidated Mermaid diagrams** — always validate first
- **Don't mix multiple concerns in one diagram** — keep each diagram focused on one aspect
- **Don't paraphrase code comments as documentation** without verifying the code matches the comment

## Quick Examples

**User says:** "Generate technical documentation for this microservice"

→ Execute full workflow:

1. Discover repo structure, language, framework
2. Scan all layers (controllers → services → repositories → config)
3. Generate all applicable doc files in `docs/`
4. Include architecture diagram, API reference, sequence diagrams, integration map
5. Tag ambiguous areas with `[NEEDS VERIFICATION]`

**User says:** "Document the API endpoints in this service"

→ Focus on `docs/03-api-reference.md`:

1. Scan all controller/route files
2. Extract method, path, params, request/response types, auth requirements
3. Build endpoint reference table
4. Include request/response examples from DTOs/schemas

**User says:** "Create architecture docs with diagrams for this repo"

→ Focus on `docs/02-architecture.md` + `docs/06-sequence-diagrams.md` + `docs/07-external-integrations.md`:

1. Analyze component structure and external dependencies
2. Generate high-level architecture (Mermaid flowchart)
3. Generate sequence diagrams for key request paths
4. Map all external integrations (DB, queues, APIs, cache)

**User says:** "What external systems does this service talk to?"

→ Focus on `docs/07-external-integrations.md` + `docs/08-resilience-patterns.md`:

1. Find all HTTP clients, DB connections, queue producers/consumers, cache clients
2. Build integration inventory table
3. Document resilience patterns protecting each integration
4. Generate integration map diagram (Mermaid)

## Reference Files

| File                                                                     | Purpose                                                     |
|--------------------------------------------------------------------------|-------------------------------------------------------------|
| [references/ref-quality-0001-doc-template.md](references/ref-quality-0001-doc-template.md) | Markdown templates for each documentation file              |
| [references/ref-quality-0002-mermaid-guide.md](references/ref-quality-0002-mermaid-guide.md) | Mermaid syntax reference for diagrams used in documentation |

---

## Standard Prompt (copy/paste)

You are the **Technical Documentation Generator skill**.  
Generate comprehensive technical documentation for the specified repository by analyzing source code.  
Follow constraints in this skill:
- Every statement must be traceable to source code (Code-Truth Policy)
- Never fabricate features, patterns, or integrations not found in code
- Use `[NEEDS VERIFICATION]` when code is ambiguous
- Skip sections with no backing code
- Validate all Mermaid diagrams before including
Output documentation in `docs/` folder with numbered markdown files.

---

## Checklist

After generating documentation, verify:
- [ ] All documented behaviors are traceable to source files with path references
- [ ] No fabricated features, patterns, or integrations
- [ ] All Mermaid diagrams validated and render correctly
- [ ] Cross-document links resolve correctly
- [ ] `docs/README.md` index lists all generated files
- [ ] Empty sections are omitted (not generated with placeholder content)
- [ ] Ambiguous code marked with `[NEEDS VERIFICATION]`
- [ ] Dead code and deprecated features flagged explicitly
- [ ] Metadata header present in every document file
- [ ] No credentials or secrets included (flagged as security issues instead)

---

## Variants

### Variant A — API Documentation Only
If user only wants API documentation:
- Focus on `docs/03-api-reference.md`
- Scan all controller/route files only
- Include request/response examples from DTOs/schemas
- Skip architecture, process flows, and other sections

### Variant B — Architecture Overview Only
If user wants high-level architecture documentation:
- Focus on `docs/01-overview.md`, `docs/02-architecture.md`, `docs/07-external-integrations.md`
- Generate architecture diagrams with external dependencies
- Skip detailed API reference, business rules, and config sections

### Variant C — Security & Compliance Audit
If user needs security-focused documentation:
- Focus on `docs/11-security.md`, `docs/10-error-handling.md`
- Document authentication, authorization, input validation
- Flag any credentials/secrets found in code as security issues
- Include CORS, encryption, and secrets management details

### Variant D — Integration Documentation
If user wants to understand external dependencies:
- Focus on `docs/07-external-integrations.md`, `docs/08-resilience-patterns.md`
- Map all DB, queue, API, cache connections
- Document resilience patterns protecting each integration
- Generate integration map diagram
