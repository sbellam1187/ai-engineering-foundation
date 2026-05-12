# CWE-22 — Path Traversal

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/path-injection`, `java/zipslip`, `java/partial-path-traversal` |
| **Query files** | [`CWE-022/TaintedPath.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-022/TaintedPath.ql), [`CWE-022/ZipSlip.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-022/ZipSlip.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `7.5` (High) |
| **OWASP** | A01:2021 Broken Access Control |

---

## What CodeQL Is Detecting

CodeQL tracks user-controlled path components flowing into file system operations.

**Sources:**
- `HttpServletRequest.getParameter()` used in file path construction
- `@RequestParam`, `@PathVariable` values used in paths
- ZIP/archive entry names from `ZipEntry.getName()`
- Multipart file names from `MultipartFile.getOriginalFilename()`

**Sinks flagged:**
- `new File(basePath + tainted)` — string concatenation in file paths
- `Paths.get(tainted)` where tainted includes `..` traversal
- `new FileInputStream(tainted)`
- `Files.readAllBytes(Paths.get(tainted))`
- `ZipEntry` extraction without path validation

**What it does NOT flag:**
- `basePath.resolve(userInput).normalize()` followed by `.startsWith(basePath)` check
- Hard-coded file paths with no user input

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — replacing one traversal pattern misses encoded variants
String safe = userInput.replace("../", "");
new File("/app/uploads/" + safe); // still vulnerable to ....// or %2e%2e

// ❌ FAILS — checking contains("..") is bypassable
if (!userInput.contains("..")) {
    new File("/app/uploads/" + userInput); // ..%2F or URL-encoded bypass
}

// ❌ FAILS — basename extraction with split is fragile
String filename = userInput.split("/")[userInput.split("/").length - 1];
new File("/app/uploads/" + filename); // null bytes, Unicode tricks

// ❌ FAILS — Path.of without normalization and start check
Path p = Path.of("/app/uploads/", userInput);
// p.toString() could be "/app/uploads/../secrets/config"
```

---

## Fix Patterns

### Standard Path Traversal Fix

```java
// ✅ CORRECT — normalize and verify the path stays within base directory
public File safeResolve(String userProvidedPath) throws IOException {
    Path baseDir = Paths.get("/app/uploads").toRealPath();
    Path resolved = baseDir.resolve(userProvidedPath).normalize();

    // Verify the resolved path is still within the base directory
    if (!resolved.startsWith(baseDir)) {
        throw new SecurityException(
            "Path traversal attempt blocked: " + userProvidedPath
        );
    }

    // Optionally verify it exists and is a regular file
    if (!Files.exists(resolved) || !Files.isRegularFile(resolved)) {
        throw new FileNotFoundException("File not found: " + userProvidedPath);
    }

    return resolved.toFile();
}
```

### Spring MVC File Download

```java
@GetMapping("/files/{filename}")
public ResponseEntity<Resource> downloadFile(
        @PathVariable String filename,
        HttpServletRequest request) throws IOException {

    // Resolve and validate path
    Path baseDir = Paths.get(uploadDir).toRealPath();
    Path filePath = baseDir.resolve(filename).normalize();

    if (!filePath.startsWith(baseDir)) {
        return ResponseEntity.badRequest().build();
    }

    Resource resource = new UrlResource(filePath.toUri());
    if (!resource.exists() || !resource.isReadable()) {
        return ResponseEntity.notFound().build();
    }

    String contentType = request.getServletContext()
        .getMimeType(resource.getFile().getAbsolutePath());

    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(
            contentType != null ? contentType : "application/octet-stream"))
        .header(HttpHeaders.CONTENT_DISPOSITION,
            "attachment; filename=\"" + resource.getFilename() + "\"")
        .body(resource);
}
```

### Zip Slip Fix

```java
// ✅ CORRECT — validate every ZipEntry path before extraction
public void safeUnzip(File zipFile, File targetDir) throws IOException {
    Path targetDirPath = targetDir.toPath().toRealPath();

    try (ZipInputStream zis = new ZipInputStream(new FileInputStream(zipFile))) {
        ZipEntry entry;
        while ((entry = zis.getNextEntry()) != null) {
            Path entryPath = targetDirPath.resolve(entry.getName()).normalize();

            // ZipSlip check — ensure entry stays within target directory
            if (!entryPath.startsWith(targetDirPath)) {
                throw new SecurityException(
                    "ZipSlip attack detected: " + entry.getName()
                );
            }

            if (entry.isDirectory()) {
                Files.createDirectories(entryPath);
            } else {
                Files.createDirectories(entryPath.getParent());
                Files.copy(zis, entryPath, StandardCopyOption.REPLACE_EXISTING);
            }

            zis.closeEntry();
        }
    }
}
```

### Multipart File Upload Fix

```java
@PostMapping("/upload")
public ResponseEntity<String> uploadFile(@RequestParam MultipartFile file)
        throws IOException {

    // Never trust the original filename
    String originalName = file.getOriginalFilename();
    if (originalName == null || originalName.isBlank()) {
        return ResponseEntity.badRequest().body("No filename");
    }

    // Generate a safe filename — strip path components, use only the basename
    String safeName = Paths.get(originalName).getFileName().toString();

    // Optionally: generate a UUID filename instead for maximum safety
    String uuidName = UUID.randomUUID() + getExtension(safeName);

    Path targetPath = Paths.get(uploadDir).resolve(uuidName).normalize();
    Path uploadDirPath = Paths.get(uploadDir).toRealPath();

    if (!targetPath.startsWith(uploadDirPath)) {
        return ResponseEntity.badRequest().body("Invalid filename");
    }

    file.transferTo(targetPath);
    return ResponseEntity.ok("Uploaded: " + uuidName);
}

private String getExtension(String filename) {
    int dot = filename.lastIndexOf('.');
    return dot >= 0 ? filename.substring(dot) : "";
}
```

---

## Security Tests

```java
@Test
void shouldBlockPathTraversal() {
    assertThrows(SecurityException.class, () ->
        fileService.safeResolve("../../etc/passwd")
    );
    assertThrows(SecurityException.class, () ->
        fileService.safeResolve("../secrets/application.properties")
    );
    assertThrows(SecurityException.class, () ->
        fileService.safeResolve("%2e%2e%2fetc%2fpasswd")
    );
}

@Test
void shouldAllowValidFilename() throws IOException {
    // Create a test file first
    Path testFile = Paths.get(uploadDir).resolve("test.txt");
    Files.writeString(testFile, "test");

    assertDoesNotThrow(() -> fileService.safeResolve("test.txt"));
}

@Test
void shouldBlockZipSlip() {
    File maliciousZip = createZipWithEntry("../../evil.sh", "malicious content");
    assertThrows(SecurityException.class, () ->
        zipService.safeUnzip(maliciousZip, targetDir)
    );
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL path injection query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-022/TaintedPath.ql |
| CodeQL ZipSlip query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-022/ZipSlip.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-path-injection/ |
| OWASP Path Traversal | https://owasp.org/www-community/attacks/Path_Traversal |
| OWASP File Upload Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| ZipSlip vulnerability research | https://security.snyk.io/research/zip-slip-vulnerability |
| CWE-22 | https://cwe.mitre.org/data/definitions/22.html |
