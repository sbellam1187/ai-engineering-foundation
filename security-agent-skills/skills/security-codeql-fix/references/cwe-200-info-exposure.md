# CWE-200/209/532 — Information Exposure

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/stack-trace-exposure`, `java/sensitive-log`, `java/sensitive-query-parameter` |
| **Query files** | [`CWE-209/StackTraceExposure.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-209/StackTraceExposure.ql), [`CWE-532/SensitiveLog.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-532/SensitiveLog.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `5.3` (Medium) |
| **OWASP** | A01:2021 Broken Access Control, A09:2021 Security Logging Failures |

---

## What CodeQL Is Detecting

### CWE-209 — Stack Trace in HTTP Response
CodeQL tracks exception objects flowing into HTTP response output — exposing internal package names, class names, file paths, and line numbers to attackers.

**Sources:** Exception objects from `catch` blocks
**Sinks:** `response.getWriter().print(exception)`, `e.printStackTrace(response.getWriter())`, returning `e.getMessage()` or `e.toString()` in response body

### CWE-532 — Sensitive Data in Logs
CodeQL tracks sensitive fields (passwords, tokens, SSN, credit cards) flowing into logging calls.

**Sources:** Fields named `password`, `secret`, `token`, `ssn`, `creditCard`, `cvv`, etc.
**Sinks:** `log.info(...)`, `log.debug(...)`, `log.error(...)`, `System.out.println(...)`

---

## Fix Patterns

### CWE-209 — Global Exception Handler

```java
// ✅ CORRECT — @RestControllerAdvice catches all unhandled exceptions
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    // Generic catch-all — never expose stack trace to client
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneral(
            Exception ex, HttpServletRequest request) {

        // Log full details server-side only
        String correlationId = MDC.get("correlationId");
        log.error("Unhandled exception [correlationId={}] for {} {}",
            correlationId, request.getMethod(), request.getRequestURI(), ex);

        // Return generic message to client — no stack trace, no class names
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(new ErrorResponse(
                "An unexpected error occurred. Please contact support.",
                correlationId
            ));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleBadRequest(IllegalArgumentException ex) {
        log.warn("Bad request: {}", ex.getMessage()); // message only, no stack
        return ResponseEntity.badRequest()
            .body(new ErrorResponse("Invalid request parameters", null));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex) {
        log.warn("Access denied: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(new ErrorResponse("Access denied", null));
    }
}

// Simple error response DTO — no exception details
public record ErrorResponse(String message, String correlationId) {}
```

### Spring Boot application.properties

```properties
# ✅ Disable Spring Boot's default error details in responses
server.error.include-message=never
server.error.include-stacktrace=never
server.error.include-exception=false
server.error.include-binding-errors=never
```

### CWE-532 — Mask Sensitive Fields in Logs

```java
// ✅ GOOD — never log raw sensitive values
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    public void authenticate(String username, String password) {
        // ✅ Log the username (not sensitive in this context)
        // ❌ NEVER log the password
        log.info("Authentication attempt for user: {}", username);

        // Do NOT do:
        // log.debug("Auth: user={} password={}", username, password); // BAD
        // log.info("Token: {}", authToken); // BAD
    }

    // ✅ GOOD — mask sensitive fields for debugging
    private String mask(String value) {
        if (value == null || value.length() < 4) return "****";
        return value.substring(0, 2) + "****" + value.substring(value.length() - 2);
    }

    public void processPayment(String creditCard, String cvv) {
        // ✅ Only log masked version
        log.info("Processing payment for card ending: {}", mask(creditCard));
        // ❌ NEVER: log.info("Card: {} CVV: {}", creditCard, cvv);
    }
}
```

### Logback — Mask Sensitive Fields at Framework Level

```xml
<!-- logback-spring.xml — mask sensitive fields globally -->
<configuration>
    <conversionRule conversionWord="maskedMsg"
        converterClass="com.aa.logging.MaskingConverter"/>

    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{ISO8601} [%thread] %-5level %logger{36} - %maskedMsg%n</pattern>
        </encoder>
    </appender>
</configuration>
```

```java
// MaskingConverter.java
public class MaskingConverter extends ClassicConverter {
    private static final Pattern SENSITIVE_PATTERN = Pattern.compile(
        "(password|secret|token|ssn|creditcard|cvv|authorization)\\s*[=:]\\s*\\S+",
        Pattern.CASE_INSENSITIVE
    );

    @Override
    public String convert(ILoggingEvent event) {
        String message = event.getFormattedMessage();
        return SENSITIVE_PATTERN.matcher(message).replaceAll("$1=****");
    }
}
```

### Never printStackTrace to Response

```java
// ❌ BAD — exposes full stack trace including internal class names
} catch (Exception e) {
    e.printStackTrace(response.getWriter()); // direct exposure
    response.getWriter().println(e.getMessage()); // exposes internal message
    return "Error: " + e.toString(); // exposes class name + message
}

// ✅ GOOD — log server-side, return generic message
} catch (Exception e) {
    log.error("Processing failed for request {}", requestId, e); // full detail in log
    return ResponseEntity.internalServerError()
        .body(new ErrorResponse("Processing failed. Reference: " + requestId, requestId));
}
```

---

## Security Tests

```java
@Test
void shouldNotExposeStackTraceInResponse() throws Exception {
    // Trigger an internal error
    mockMvc.perform(get("/endpoint-that-throws"))
        .andExpect(status().isInternalServerError())
        .andExpect(jsonPath("$.message").value("An unexpected error occurred. Please contact support."))
        .andExpect(content().string(not(containsString("at com.aa."))))    // no stack frames
        .andExpect(content().string(not(containsString("Exception"))))      // no exception class
        .andExpect(content().string(not(containsString("NullPointerException"))));
}

@Test
void shouldNotLogSensitiveData(LogCaptor logCaptor) {
    service.authenticate("user123", "MySecretPassword123!");

    // Verify password never appears in any log line
    assertThat(logCaptor.getInfoLogs())
        .noneMatch(log -> log.contains("MySecretPassword123!"));
    assertThat(logCaptor.getDebugLogs())
        .noneMatch(log -> log.contains("MySecretPassword123!"));
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL stack trace query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-209/StackTraceExposure.ql |
| CodeQL sensitive log query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-532/SensitiveLog.ql |
| OWASP Error Handling Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html |
| OWASP Logging Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| CWE-209 | https://cwe.mitre.org/data/definitions/209.html |
| CWE-532 | https://cwe.mitre.org/data/definitions/532.html |
