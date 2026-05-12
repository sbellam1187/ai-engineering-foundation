# CWE-79 — Cross-Site Scripting (XSS)

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule ID** | `java/xss` |
| **Query file** | [`java/ql/src/Security/CWE/CWE-079/XSS.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-079/XSS.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `6.1` (Medium) |
| **OWASP** | A03:2021 Injection |

---

## What CodeQL Is Detecting

CodeQL tracks user-controlled input flowing directly into HTTP response output without encoding.

**Sources:**
- `HttpServletRequest.getParameter()`, `getHeader()`, `getQueryString()`
- `@RequestParam`, `@PathVariable`, `@RequestHeader` values
- Data read from cookies via `request.getCookies()`

**Sinks flagged:**
- `HttpServletResponse.getWriter().print(tainted)` / `println(tainted)`
- `HttpServletResponse.getOutputStream().write(tainted)`
- `response.getWriter().write(tainted)`
- Servlet `PrintWriter` with tainted content
- JSP `out.print(tainted)` without encoding

**What it does NOT flag:**
- `Encode.forHtml(userInput)` — OWASP Java Encoder (recognized sanitizer)
- `HtmlUtils.htmlEscape(userInput)` — Spring's HTML escaper (recognized)
- Thymeleaf `th:text` — auto-escaping (recognized)
- JSON responses with `@ResponseBody` returning typed objects (not raw strings)

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — replacing only < and > misses many XSS vectors
String safe = userInput.replace("<", "&lt;").replace(">", "&gt;");
writer.print(safe); // still vulnerable to attribute injection, JS events

// ❌ FAILS — toLowerCase doesn't sanitize
writer.print(userInput.toLowerCase());

// ❌ FAILS — checking for "script" keyword is bypassable
if (!userInput.contains("script")) {
    writer.print(userInput);
}

// ❌ FAILS — Base64 encoding is not HTML encoding
writer.print(Base64.encode(userInput)); // decoded in browser context
```

---

## Fix Patterns

### Servlet — OWASP Java Encoder

```java
import org.owasp.encoder.Encode;

// ✅ GOOD — HTML context (body, attribute values)
response.getWriter().print(Encode.forHtml(userInput));

// ✅ GOOD — HTML attribute context
response.getWriter().print("<input value=\"" + Encode.forHtmlAttribute(userInput) + "\">");

// ✅ GOOD — JavaScript context (inside <script> blocks)
response.getWriter().print("var name = '" + Encode.forJavaScript(userInput) + "';");

// ✅ GOOD — URL parameter context
response.getWriter().print("<a href=\"/search?q=" + Encode.forUriComponent(userInput) + "\">");
```

Add OWASP Java Encoder to `build.gradle`:
```groovy
implementation 'org.owasp.encoder:encoder:1.2.3'
```

### Spring MVC — Return typed objects not raw strings

```java
// ✅ BEST — return typed Java object, Spring serializes to JSON safely
@GetMapping("/user/{id}")
@ResponseBody
public UserDto getUser(@PathVariable String id) {
    return userService.findById(id); // UserDto fields are escaped by Jackson
}

// ❌ BAD — returning raw HTML string with user data embedded
@GetMapping("/greet")
@ResponseBody
public String greet(@RequestParam String name) {
    return "<h1>Hello " + name + "</h1>"; // XSS
}

// ✅ GOOD — if you must return HTML, encode first
@GetMapping("/greet")
@ResponseBody
public String greet(@RequestParam String name) {
    return "<h1>Hello " + Encode.forHtml(name) + "</h1>";
}
```

### Spring MVC — Use Spring's HtmlUtils

```java
import org.springframework.web.util.HtmlUtils;

// ✅ GOOD — Spring's built-in HTML escaper (recognized by CodeQL)
String safe = HtmlUtils.htmlEscape(userInput);
response.getWriter().print(safe);
```

### Thymeleaf Templates

```html
<!-- ✅ GOOD — th:text auto-escapes HTML entities -->
<p th:text="${userInput}">safe</p>
<input th:value="${userInput}" type="text">

<!-- ❌ BAD — th:utext does NOT escape, use only for trusted content -->
<p th:utext="${userInput}">UNSAFE</p>
```

### Content-Type and Security Headers

```java
// ✅ GOOD — set correct content type
response.setContentType("application/json; charset=UTF-8");

// ✅ GOOD — add security headers in Spring Security config
@Bean
SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.headers(headers -> headers
        .contentSecurityPolicy(csp -> csp
            .policyDirectives("default-src 'self'; script-src 'self'")
        )
        .xssProtection(xss -> xss.headerValue(XXssProtectionHeaderWriter.HeaderValue.ENABLED_MODE_BLOCK))
        .contentTypeOptions(Customizer.withDefaults())
    );
    return http.build();
}
```

---

## Security Tests

```java
@Test
void shouldEncodeHtmlInResponse() throws Exception {
    String xssPayload = "<script>alert('xss')</script>";
    
    mockMvc.perform(get("/greet").param("name", xssPayload))
        .andExpect(status().isOk())
        .andExpect(content().string(not(containsString("<script>"))))
        .andExpect(content().string(containsString("&lt;script&gt;")));
}

@Test
void shouldHandleXssInPathVariable() throws Exception {
    String xssPayload = "<img src=x onerror=alert(1)>";
    
    mockMvc.perform(get("/user/" + URLEncoder.encode(xssPayload, UTF_8)))
        .andExpect(status().isOk())
        .andExpect(content().string(not(containsString("<img"))));
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL XSS query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-079/XSS.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-xss/ |
| OWASP XSS Prevention Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html |
| OWASP Java Encoder | https://owasp.org/www-project-java-encoder/ |
| CWE-79 | https://cwe.mitre.org/data/definitions/79.html |
