# CWE-611 — XML External Entity (XXE)

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/xml/xxe`, `java/xml/xxe-local` |
| **Query files** | [`CWE-611/XXE.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-611/XXE.ql), [`CWE-611/XXELocal.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-611/XXELocal.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `9.1` (Critical) |
| **OWASP** | A05:2021 Security Misconfiguration |

---

## What CodeQL Is Detecting

CodeQL detects XML parsers that process user-supplied XML **without disabling external entity resolution**. The parser itself is the vulnerability — if it is configured insecurely, any XML input (even seemingly benign) can be exploited.

**Sources:**
- `HttpServletRequest.getInputStream()` — raw request body
- `HttpServletRequest.getReader()`
- `@RequestBody` receiving XML content
- `MultipartFile.getInputStream()` — uploaded XML files

**Sinks flagged — insecurely configured parsers:**
- `DocumentBuilderFactory.newInstance()` without disabling DTD/external entities
- `SAXParserFactory.newInstance()` without feature flags
- `XMLInputFactory.newInstance()` without disabling external entities
- `TransformerFactory.newInstance()` without access restrictions
- `SchemaFactory.newInstance()` without access restrictions
- `JAXBContext.createUnmarshaller()` with unsafe underlying parser

**What it does NOT flag:**
- Parsers with DTD disabled via `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`
- Parsers with `ACCESS_EXTERNAL_DTD` and `ACCESS_EXTERNAL_SCHEMA` set to `""`

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — checking for DOCTYPE in input string is bypassable
if (!xmlInput.contains("DOCTYPE")) {
    DocumentBuilder db = DocumentBuilderFactory.newInstance().newDocumentBuilder();
    db.parse(new InputSource(new StringReader(xmlInput)));
}
// Bypass: use encoding tricks, split DOCTYPE across chunks

// ❌ FAILS — catching exceptions doesn't prevent the XXE
try {
    db.parse(xmlInput);
} catch (Exception e) {
    log.error("Parse error", e); // XXE may have already fired before exception
}

// ❌ FAILS — just setting namespace-aware doesn't help
factory.setNamespaceAware(true); // unrelated to XXE
```

---

## Fix Patterns

### DocumentBuilderFactory — Full Hardening

```java
// ✅ CORRECT — disable all external entity processing
public DocumentBuilder createSafeDocumentBuilder() throws ParserConfigurationException {
    DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();

    // Primary defense — disallow DOCTYPE declarations entirely
    factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);

    // Defense in depth — disable external general and parameter entities
    factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
    factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);

    // Disable external DTD loading
    factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);

    // Disable XInclude processing
    factory.setXIncludeAware(false);
    factory.setExpandEntityReferences(false);

    // Restrict access (Java 7+)
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");

    return factory.newDocumentBuilder();
}

// Usage
DocumentBuilder safeDb = createSafeDocumentBuilder();
Document doc = safeDb.parse(new InputSource(new StringReader(userXml)));
```

### SAXParserFactory — Full Hardening

```java
// ✅ CORRECT
public SAXParser createSafeSaxParser() throws Exception {
    SAXParserFactory factory = SAXParserFactory.newInstance();

    factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
    factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
    factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
    factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);

    return factory.newSAXParser();
}
```

### XMLInputFactory (StAX) — Full Hardening

```java
// ✅ CORRECT — StAX parser hardening
XMLInputFactory factory = XMLInputFactory.newInstance();
factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
factory.setProperty(XMLInputFactory.IS_REPLACING_ENTITY_REFERENCES, false);

XMLStreamReader reader = factory.createXMLStreamReader(inputStream);
```

### TransformerFactory — Full Hardening

```java
// ✅ CORRECT — used for XSLT transformations
TransformerFactory factory = TransformerFactory.newInstance();
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");

Transformer transformer = factory.newTransformer();
```

### Spring Boot — Jackson XML (Safe by Default)

```java
// ✅ GOOD — if switching from manual XML parsing, use Jackson XML
// Jackson's XML module disables XXE by default
@Bean
public XmlMapper xmlMapper() {
    XmlMapper mapper = new XmlMapper();
    // Already safe — DTD and external entities disabled by default
    return mapper;
}

// Use in controller
@PostMapping(value = "/data", consumes = MediaType.APPLICATION_XML_VALUE)
public ResponseEntity<DataDto> receiveXml(@RequestBody DataDto data) {
    // Jackson handles deserialization safely
    return ResponseEntity.ok(data);
}
```

### Reusable Safe Parser Bean — Spring

```java
// ✅ BEST PRACTICE — create once, inject everywhere
@Configuration
public class XmlParserConfig {

    @Bean
    public DocumentBuilderFactory safeDocumentBuilderFactory()
            throws ParserConfigurationException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        return factory;
    }
}

// Inject and use
@Autowired
private DocumentBuilderFactory safeDocumentBuilderFactory;

public Document parseXml(String xml) throws Exception {
    DocumentBuilder db = safeDocumentBuilderFactory.newDocumentBuilder();
    return db.parse(new InputSource(new StringReader(xml)));
}
```

---

## Security Tests

```java
@Test
void shouldBlockXxeFileRead() {
    String xxePayload = """
        <?xml version="1.0"?>
        <!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
        <data>&xxe;</data>
        """;

    // Should throw or return without /etc/passwd content
    assertThrows(Exception.class, () -> xmlService.parse(xxePayload));
}

@Test
void shouldBlockSsrfViaXxe() {
    String xxePayload = """
        <?xml version="1.0"?>
        <!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]>
        <data>&xxe;</data>
        """;

    assertThrows(Exception.class, () -> xmlService.parse(xxePayload));
}

@Test
void shouldParseValidXml() throws Exception {
    String validXml = "<data><item>hello</item></data>";
    Document doc = xmlService.parse(validXml);
    assertNotNull(doc);
    assertEquals("data", doc.getDocumentElement().getTagName());
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL XXE query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-611/XXE.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-xxe/ |
| OWASP XXE Prevention Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html |
| OWASP XXE attack | https://owasp.org/www-community/vulnerabilities/XML_External_Entity_(XXE)_Processing |
| CWE-611 | https://cwe.mitre.org/data/definitions/611.html |
