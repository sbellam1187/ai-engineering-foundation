# CWE-502 — Unsafe Deserialization

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule ID** | `java/unsafe-deserialization` |
| **Query file** | [`CWE-502/UnsafeDeserialization.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-502/UnsafeDeserialization.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `9.8` (Critical) |
| **OWASP** | A08:2021 Software and Data Integrity Failures |

---

## What CodeQL Is Detecting

CodeQL tracks untrusted data flowing into Java deserialization sinks — where arbitrary object graphs can be reconstructed from bytes, enabling remote code execution via gadget chains.

**Sources:**
- `HttpServletRequest.getInputStream()`
- `HttpServletRequest.getParameter()` — Base64-encoded serialized objects
- `@RequestBody byte[]`
- Data from message queues, sockets, or file uploads

**Sinks flagged:**
- `new ObjectInputStream(taintedInput).readObject()` — Java native serialization
- `XMLDecoder.readObject()` — XML-based Java serialization (equally dangerous)
- Certain Kryo, XStream usages without class filtering

**What it does NOT flag:**
- `ObjectInputStream` with a proper `ObjectInputFilter` that allowlists classes
- Jackson `ObjectMapper` with typed JSON (safe by default for known types)
- Protobuf / Avro deserialization (not Java native serialization)

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — catching exceptions doesn't prevent RCE
// The gadget chain executes during readObject() before you can catch it safely
try {
    Object obj = ois.readObject();
} catch (ClassNotFoundException e) {
    log.error("Unknown class", e); // too late — code already ran
}

// ❌ FAILS — checking the stream length doesn't prevent malicious payloads
if (inputStream.available() < 10000) {
    Object obj = new ObjectInputStream(inputStream).readObject();
}

// ❌ FAILS — instanceof check after readObject() is too late
Object obj = ois.readObject();
if (!(obj instanceof SafeClass)) { // gadget chain already executed
    throw new SecurityException("wrong type");
}
```

---

## Fix Patterns

### Java 9+ ObjectInputFilter — Allowlist Classes

```java
// ✅ CORRECT — filter runs BEFORE class instantiation
public Object safeDeserialize(InputStream input) throws Exception {
    ObjectInputStream ois = new ObjectInputStream(input);

    // Set filter before reading — allowlist only your known safe classes
    ois.setObjectInputFilter(info -> {
        if (info.serialClass() == null) {
            // Primitive or array without a class — check depth and size limits
            if (info.depth() > 5) return ObjectInputFilter.Status.REJECTED;
            if (info.references() > 100) return ObjectInputFilter.Status.REJECTED;
            return ObjectInputFilter.Status.UNDECIDED;
        }

        String className = info.serialClass().getName();

        // Allowlist — only permit your own model classes
        if (className.startsWith("com.aa.ecm.model.") ||
            className.startsWith("com.aa.ct.loyalty.model.") ||
            className.equals("java.lang.String") ||
            className.equals("java.util.ArrayList") ||
            className.equals("java.util.HashMap")) {
            return ObjectInputFilter.Status.ALLOWED;
        }

        // Block everything else — gadget chains use commons-collections,
        // spring-core, groovy, etc.
        log.warn("Deserialization blocked for class: {}", className);
        return ObjectInputFilter.Status.REJECTED;
    });

    return ois.readObject();
}
```

### Replace Native Serialization with Jackson JSON

```java
// ✅ BEST — replace ObjectInputStream entirely with Jackson
// Jackson does not use Java's serialization mechanism

@Bean
public ObjectMapper objectMapper() {
    ObjectMapper mapper = new ObjectMapper();
    // Do NOT enable default typing with NON_FINAL — that enables polymorph attacks
    // mapper.enableDefaultTyping(...) // NEVER do this
    return mapper;
}

// Serialize
String json = objectMapper.writeValueAsString(myObject);

// Deserialize — typed, safe
MyDto dto = objectMapper.readValue(json, MyDto.class);

// For polymorphic types — use explicit @JsonTypeInfo with known subtypes only
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = ConcreteA.class, name = "typeA"),
    @JsonSubTypes.Type(value = ConcreteB.class, name = "typeB")
})
public abstract class BaseDto { }
```

### Replace XMLDecoder

```java
// ❌ BAD — XMLDecoder is as dangerous as ObjectInputStream
XMLDecoder decoder = new XMLDecoder(inputStream);
Object obj = decoder.readObject(); // RCE via gadgets

// ✅ GOOD — use JAXB with a safe parser instead
JAXBContext ctx = JAXBContext.newInstance(MyDto.class);
Unmarshaller u = ctx.createUnmarshaller();
// Wire in a safe SAX parser (see CWE-611 for XXE hardening)
SAXParserFactory spf = SAXParserFactory.newInstance();
spf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
XMLReader xmlReader = spf.newSAXParser().getXMLReader();
SAXSource source = new SAXSource(xmlReader, new InputSource(inputStream));
MyDto result = (MyDto) u.unmarshal(source);
```

### Global JVM Filter (Defense in Depth)

Set in `application.properties` or JVM startup args — blocks dangerous gadget chain classes JVM-wide:

```properties
# application.properties — Java serialization filter
jdk.serialFilter=com.aa.**;java.lang.*;java.util.*;!*
```

Or as a JVM argument:
```bash
-Djdk.serialFilter="com.aa.**;java.lang.*;java.util.*;!*"
```

---

## Security Tests

```java
@Test
void shouldBlockGadgetChainDeserialization() throws Exception {
    // Attempt to deserialize a class not in the allowlist
    byte[] maliciousPayload = serializeObject(new org.apache.commons.collections4
        .functors.InvokerTransformer("exec", null, null));

    assertThrows(InvalidClassException.class, () ->
        deserializationService.safeDeserialize(
            new ByteArrayInputStream(maliciousPayload))
    );
}

@Test
void shouldAllowKnownSafeClass() throws Exception {
    MyDto original = new MyDto("test", 42);
    byte[] serialized = serializeObject(original);

    Object result = deserializationService.safeDeserialize(
        new ByteArrayInputStream(serialized));

    assertInstanceOf(MyDto.class, result);
    assertEquals("test", ((MyDto) result).getName());
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL deserialization query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-502/UnsafeDeserialization.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-unsafe-deserialization/ |
| OWASP Deserialization Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html |
| Java ObjectInputFilter docs | https://docs.oracle.com/en/java/docs/api/java.base/java/io/ObjectInputFilter.html |
| ysoserial gadget chain repo | https://github.com/frohoff/ysoserial |
| CWE-502 | https://cwe.mitre.org/data/definitions/502.html |
