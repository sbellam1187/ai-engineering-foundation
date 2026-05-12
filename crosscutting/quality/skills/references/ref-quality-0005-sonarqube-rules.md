# SonarQube Rule Categories & Fix Patterns

Detailed rule categories, ecosystem-specific patterns, and fix examples for the SonarQube Code Quality Review Skill.

## 1. 🔴 Bugs (Reliability)

| Pattern | What to Look For | Fix |
|---------|-----------------|-----|
| Null dereference | Unchecked `Optional.get()`, nullable returns | `isPresent()` / `orElse()` |
| Equality misuse | `==` instead of `.equals()` for objects | `Objects.equals()` |
| Resource leak | Streams, connections not closed | `try-with-resources` |
| Unchecked cast | `(Type) object` without `instanceof` | Add `instanceof` check |
| hashCode/equals | Override one without the other | Override both |
| Off-by-one | `<` vs `<=` in loop bounds | Verify boundaries |
| Concurrency issues | Shared mutable state | Thread-safe collections, `final` |
| Ignored return value | `String.replace()` discarded | Use the returned value |

### Java / Spring Boot
| Pattern | Rule | Fix |
|---------|------|-----|
| `@Autowired` on mutable field | squid:S3306 | Constructor injection |
| Missing `@Transactional` rollback | — | `rollbackFor = Exception.class` |
| `SimpleDateFormat` shared | squid:S5164 | Use `DateTimeFormatter` |
| `Optional` as parameter | squid:S3553 | Overloaded methods |

### .NET
| Pattern | Rule | Fix |
|---------|------|-----|
| `IDisposable` not disposed | CA2000 | `using` statement |
| `async void` methods | VSTHRD100 | Return `Task` |
| String interpolation in logs | CA2254 | Structured templates |

### Node.js / TypeScript
| Pattern | Rule | Fix |
|---------|------|-----|
| Unhandled promise | no-floating-promises | `.catch()` or `try/catch` |
| `==` instead of `===` | eqeqeq | Strict equality |

### Python
| Pattern | Rule | Fix |
|---------|------|-----|
| Mutable default argument | W0102 | `None` default |
| Bare `except:` | W0702 | Specific exceptions |

## 2. 🟠 Vulnerabilities (Security)

| Pattern | OWASP | CWE | Fix |
|---------|-------|-----|-----|
| SQL injection | A03 | CWE-89 | Parameterised queries |
| Command injection | A03 | CWE-78 | Safe APIs, no shell |
| XSS | A03 | CWE-79 | Encode output |
| Path traversal | A01 | CWE-22 | Canonicalise paths |
| Hardcoded credentials | A02 | CWE-798 | Key Vault / env vars |
| Insecure random | A02 | CWE-330 | `SecureRandom` |
| Log injection | A09 | CWE-117 | Parameterised logging |
| Insecure deserialization | A08 | CWE-502 | Allow-lists |
| SSRF | A10 | CWE-918 | URL allow-list |
| Weak crypto | A02 | CWE-327 | AES-256, SHA-256+ |
| Missing auth | A01 | CWE-862 | `@PreAuthorize` / `[Authorize]` |

## 3. 🔶 Security Hotspots

| Category | Trigger | Review Question |
|----------|---------|-----------------|
| Cryptography | Encryption/hashing APIs | Strong algorithm? Keys managed? |
| Authentication | Custom auth logic | Mechanism secure? |
| CORS | Cross-origin config | Allow-list restrictive? `*` avoided? |
| Regex | Complex patterns | ReDoS vulnerable? |
| Cookies | Set/read cookies | `Secure`, `HttpOnly`, `SameSite` set? |

## 4. 🟡 Code Smells

### Cognitive Complexity (threshold: 15 per method)

| Construct | Increment | Extra per Nesting |
|-----------|-----------|-------------------|
| `if`, `else if`, `else` | +1 | +1 |
| `for`, `while` | +1 | +1 |
| `catch` | +1 | +1 |
| `switch` | +1 | +1 |
| `&&`, `\|\|` | +1 | — |

**Reduction techniques**: Guard clauses, extract methods, Stream API, strategy/map dispatch, Optional chaining.

### Other Smells

| Pattern | Threshold | Fix |
|---------|-----------|-----|
| Method too long | > 60 lines | Extract helpers |
| Too many parameters | > 7 | Parameter object |
| Duplicate code | ≥ 3 lines × 2 places | Shared method |
| Dead code | Unused private methods | Remove |
| Magic numbers | Literals in logic | Named constants |
| Deep nesting | > 3 levels | Guard clauses |
| God class | > 500 lines | Split by SRP |

## 5. 🔵 Coverage Gaps

| Pattern | Fix |
|---------|-----|
| Untested public methods | Unit test happy + error path |
| Missing branch coverage | Test each branch |
| Exception paths untested | Trigger the exception |
| Edge cases | Null, empty, boundary tests |

## 6. Static Analysis Compliance

### Java — PMD & Checkstyle
| Rule | Fix |
|------|-----|
| LooseCoupling | Use interface types (`List`, `Map`) |
| CloseResource | `try-with-resources` |
| Star imports | Import specific classes |
| Catching Throwable | Catch specific types |

### .NET — Roslyn
| Rule | Fix |
|------|-----|
| CA1062 | `ArgumentNullException.ThrowIfNull()` |
| CA1822 | Add `static` modifier |

### Node.js — ESLint
| Rule | Fix |
|------|-----|
| no-unused-vars | Remove or `_` prefix |
| no-explicit-any | Proper type |
| prefer-const | Change to `const` |

### Python — Pylint/Bandit
| Rule | Fix |
|------|-----|
| R0913 | Dataclass or `**kwargs` |
| B608 | Parameterised query |

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Large methods with high complexity | Extract helpers, guard clauses |
| Deep `instanceof` chains | Pattern matching, sealed interfaces |
| Interface types not used in signatures | Declare as `List`, `Map`, `Set` |
| Thread-unsafe shared state | Local vars, `ConcurrentHashMap` |
| Catch-and-ignore | Log at minimum |
| String concatenation in loops | `StringBuilder`, `Collectors.joining()` |
| Boolean method parameters | Enum or separate methods |

## SQALE Technical Debt Estimates

| Smell Type | Remediation |
|-----------|-------------|
| Cognitive complexity > 15 | 15–30 min/method |
| Duplicate block | 10–20 min/block |
| God class | 2–4 hours |
| Dead code | 5 min/occurrence |
| Magic number | 5 min/occurrence |
