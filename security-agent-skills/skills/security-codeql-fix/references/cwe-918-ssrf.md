# CWE-918 — Server-Side Request Forgery (SSRF)

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule ID** | `java/request-forgery` |
| **Query file** | [`java/ql/src/Security/CWE/CWE-918/RequestForgery.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-918/RequestForgery.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Severity** | `error` |
| **Security severity** | `9.1` (Critical) |
| **OWASP** | A10:2021 Server-Side Request Forgery |
| **Query suites** | `java-code-scanning.qls`, `java-security-extended.qls` |

---

## What CodeQL Is Detecting

CodeQL performs **inter-procedural taint tracking** from HTTP request sources to URL-construction sinks.

**Sources CodeQL tracks:**
- `HttpServletRequest.getParameter()`
- `HttpServletRequest.getHeader()`
- `HttpServletRequest.getPathVariable()` / `@PathVariable` bindings
- `HttpServletRequest.getRequestURI()`
- `@RequestParam`, `@RequestBody`, `@RequestHeader` annotated parameters
- Spring `ServerRequest` reactive equivalents

**Sinks CodeQL flags:**
- `RestTemplate.getForObject(url, ...)` where `url` contains tainted data
- `RestTemplate.postForEntity(url, ...)` 
- `RestTemplate.exchange(url, ...)`
- `new URL(taintedString)` + `.openConnection()`
- `HttpClient.send(HttpRequest.newBuilder().uri(URI.create(tainted)))`
- `new URI(taintedString)` used in HTTP calls
- `WebClient.get().uri(taintedString)`

**What it does NOT flag:**
- URI template variables (`restTemplate.getForObject(template, Class, Map.of("key", value))`) — Spring handles these safely
- Hardcoded URLs with only validated path segments appended

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — renaming the variable doesn't break the taint
String safeUrl = userInput; // still tainted
restTemplate.getForObject(safeUrl, String.class);

// ❌ FAILS — logging doesn't sanitize
log.info("Calling: {}", userInput);
restTemplate.getForObject(userInput, String.class);

// ❌ FAILS — moving to a helper method doesn't break inter-procedural taint
private String callService(String url) {
    return restTemplate.getForObject(url, String.class); // CodeQL still sees taint
}
callService(userInput);

// ❌ FAILS — string length check is not a sanitizer for SSRF
if (userInput.length() < 200) {
    restTemplate.getForObject(userInput, String.class);
}
```

---

## Fix Scenarios

### Scenario A: Only a path/query parameter is user-controlled (PREFERRED)

When the **base URL is from server config** and only a path segment (ID, key) is user-provided — use Spring URI template variables. Spring URL-encodes the value and treats it as data only — it **cannot alter host, scheme, or URL structure**.

```java
// ✅ BEST — Spring URI template variables, framework-native, minimal
// URL in config: https://api.example.com/disputes/{dispute_id}/evidence
String urlTemplate = config.get("submit_evidence_url"); // from application.properties

// Defense-in-depth: validate the ID format
if (!disputeId.matches("[a-zA-Z0-9_-]+")) {
    throw new IllegalArgumentException("Invalid ID format: " + disputeId);
}

// Spring treats the map values as URI variables — cannot change host or scheme
ResponseEntity<Response> response = restTemplate.postForEntity(
    urlTemplate,
    requestEntity,
    Response.class,
    Map.of("dispute_id", disputeId)  // Spring encodes this safely
);
```

**Why this breaks the CodeQL taint:** The tainted value goes into `Map.of()`, not directly into the URL string. Spring's URI template engine is a recognized sanitizer in CodeQL's model.

### Scenario B: Full URL is user-controlled

When the entire URL comes from user input (webhook callbacks, proxy requests):

```java
// ✅ GOOD — validate and allowlist before making the request
public ResponseEntity<String> proxyRequest(String userUrl) {
    URI uri;
    try {
        uri = new URI(userUrl);
    } catch (URISyntaxException e) {
        throw new IllegalArgumentException("Invalid URL", e);
    }

    String host = uri.getHost();
    if (host == null) {
        throw new SecurityException("URL has no host");
    }

    // Block internal/private IP ranges
    try {
        InetAddress addr = InetAddress.getByName(host);
        if (addr.isLoopbackAddress() ||
            addr.isSiteLocalAddress() ||
            addr.isLinkLocalAddress() ||
            addr.isAnyLocalAddress()) {
            throw new SecurityException("Access to internal addresses blocked: " + host);
        }
    } catch (UnknownHostException e) {
        throw new SecurityException("Cannot resolve host: " + host);
    }

    // Enforce allowlist
    Set<String> allowedHosts = Set.of("api.partner.com", "cdn.partner.com");
    if (!allowedHosts.contains(host.toLowerCase())) {
        throw new SecurityException("Host not permitted: " + host);
    }

    // Enforce scheme
    if (!"https".equals(uri.getScheme())) {
        throw new SecurityException("Only HTTPS is permitted");
    }

    return restTemplate.getForEntity(uri, String.class);
}
```

### Scenario C: URL built from config + user-provided query param only

```java
// ✅ GOOD — hardcode the base, user controls only query value
String baseUrl = "https://api.example.com/search";
UriComponentsBuilder builder = UriComponentsBuilder
    .fromHttpUrl(baseUrl)
    .queryParam("q", UriUtils.encode(userQuery, StandardCharsets.UTF_8));

URI safeUri = builder.build(true).toUri();
restTemplate.getForObject(safeUri, String.class);
```

---

## Security Tests to Add

```java
@Test
void shouldRejectInternalUrlSsrf() {
    assertThrows(SecurityException.class, () ->
        service.proxyRequest("http://localhost/internal")
    );
    assertThrows(SecurityException.class, () ->
        service.proxyRequest("http://169.254.169.254/metadata") // AWS metadata
    );
    assertThrows(SecurityException.class, () ->
        service.proxyRequest("http://10.0.0.1/admin")
    );
}

@Test
void shouldRejectNonAllowlistedHost() {
    assertThrows(SecurityException.class, () ->
        service.proxyRequest("http://evil.com/steal-data")
    );
}

@Test
void shouldAllowValidRequest() {
    // Use WireMock or MockRestServiceServer to mock the partner API
    assertDoesNotThrow(() ->
        service.proxyRequest("https://api.partner.com/data")
    );
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL query source | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-918/RequestForgery.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-request-forgery/ |
| OWASP SSRF Prevention Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html |
| CWE-918 | https://cwe.mitre.org/data/definitions/918.html |
| Spring UriComponentsBuilder | https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/util/UriComponentsBuilder.html |
