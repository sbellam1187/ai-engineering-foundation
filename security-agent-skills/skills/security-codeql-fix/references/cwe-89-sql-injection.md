# CWE-89 — SQL Injection (+ CWE-90 LDAP Injection)

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/sql-injection`, `java/concatenated-sql-query`, `java/ldap-injection`, `java/mybatis-annotation-sql-injection`, `java/mybatis-xml-sql-injection` |
| **Query files** | [`CWE-089/SqlInjection.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-089/SqlInjection.ql), [`CWE-089/SqlConcatenated.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-089/SqlConcatenated.ql) |
| **Kind** | `path-problem` |
| **Precision** | `high` |
| **Security severity** | `8.8` (High) |
| **OWASP** | A03:2021 Injection |

---

## What CodeQL Is Detecting

CodeQL tracks tainted user input flowing into SQL query construction sinks.

**Sources:**
- `HttpServletRequest.getParameter()`, `getHeader()`, `getPathVariable()`
- `@RequestParam`, `@PathVariable`, `@RequestBody` values
- Any value derived from the above through string operations

**Sinks flagged:**
- `Statement.execute(tainted)` / `executeQuery(tainted)` / `executeUpdate(tainted)`
- `Connection.prepareStatement(tainted)` — where the query string itself is tainted
- `EntityManager.createNativeQuery(tainted)`
- `EntityManager.createQuery(tainted)` — JPQL injection
- `JdbcTemplate.query(tainted, ...)` / `queryForObject(tainted, ...)`
- `@Query` with `nativeQuery=true` and string concatenation
- MyBatis `${}` substitution (vs safe `#{}` parameterized)

**What it does NOT flag:**
- `PreparedStatement` with `?` placeholders and `setString()`/`setInt()`
- Spring Data JPA `@Query` with `:param` named parameters
- `JdbcTemplate.query(fixedString, new Object[]{paramValue})`
- MyBatis `#{}` substitution

---

## Why Naive Fixes Fail

```java
// ❌ FAILS — trimming doesn't break the taint
String q = "SELECT * FROM users WHERE name = '" + userInput.trim() + "'";

// ❌ FAILS — toUpperCase doesn't sanitize SQL injection
String q = "SELECT * FROM " + userInput.toUpperCase();

// ❌ FAILS — checking length is not a sanitizer
if (userInput.length() < 50) {
    jdbc.query("SELECT * FROM users WHERE id = " + userInput, ...);
}

// ❌ FAILS — escaping quotes manually is incomplete and error-prone
String safe = userInput.replace("'", "''");
jdbc.query("SELECT * FROM users WHERE name = '" + safe + "'", ...);
```

---

## Fix Patterns

### Spring Data JPA — Named Parameters (BEST for JPA projects)

```java
// ✅ BEST — Spring Data repository method (auto-parameterized)
List<User> findByEmailContainingIgnoreCase(String email);
Optional<User> findByUsernameAndActive(String username, boolean active);

// ✅ GOOD — @Query with named parameters
@Query("SELECT u FROM User u WHERE u.department = :dept AND u.active = :active")
List<User> findByDeptAndActive(
    @Param("dept") String dept,
    @Param("active") boolean active
);

// ✅ GOOD — native query with named parameters (NOT string concatenation)
@Query(value = "SELECT * FROM users WHERE dept = :dept", nativeQuery = true)
List<User> findByDeptNative(@Param("dept") String dept);
```

### JDBC — PreparedStatement

```java
// ✅ GOOD — PreparedStatement with placeholders
String sql = "SELECT * FROM users WHERE name = ? AND active = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, userInput);
ps.setBoolean(2, true);
ResultSet rs = ps.executeQuery();

// ✅ GOOD — JdbcTemplate with parameter array
String sql = "SELECT * FROM users WHERE name = ? AND dept = ?";
List<User> users = jdbcTemplate.query(
    sql,
    new Object[]{userName, deptName},
    new UserRowMapper()
);

// ✅ GOOD — JdbcTemplate named parameters
String sql = "SELECT * FROM users WHERE name = :name AND dept = :dept";
MapSqlParameterSource params = new MapSqlParameterSource()
    .addValue("name", userName)
    .addValue("dept", deptName);
namedJdbcTemplate.query(sql, params, new UserRowMapper());
```

### MyBatis — Use #{} not ${}

```xml
<!-- ✅ GOOD — #{} is parameterized, safe -->
<select id="findUser" resultType="User">
    SELECT * FROM users WHERE name = #{name} AND dept = #{dept}
</select>

<!-- ❌ BAD — ${} is string substitution, injectable -->
<select id="findUser" resultType="User">
    SELECT * FROM users WHERE name = '${name}'
</select>
```

### Dynamic Queries — Use Criteria API

```java
// ✅ GOOD — JPA Criteria API for dynamic queries
CriteriaBuilder cb = em.getCriteriaBuilder();
CriteriaQuery<User> cq = cb.createQuery(User.class);
Root<User> root = cq.from(User.class);

List<Predicate> predicates = new ArrayList<>();
if (name != null && !name.isBlank()) {
    predicates.add(cb.equal(root.get("name"), name)); // parameterized
}
if (dept != null) {
    predicates.add(cb.equal(root.get("department"), dept)); // parameterized
}

cq.where(predicates.toArray(new Predicate[0]));
return em.createQuery(cq).getResultList();
```

### LDAP Injection Fix

```java
// ✅ GOOD — encode LDAP filter values
import org.springframework.ldap.core.LdapEncoder;

String safeFilter = LdapEncoder.filterEncode(userInput);
String filter = "(uid=" + safeFilter + ")";

// ✅ GOOD — Spring LDAP with named parameters
List<User> users = ldapTemplate.find(
    query().where("uid").is(userInput), // Spring LDAP handles encoding
    User.class
);
```

---

## Security Tests

```java
@Test
void shouldPreventSqlInjection() {
    // Classic SQL injection payload should not alter query semantics
    String maliciousInput = "' OR '1'='1";
    
    // Should return empty or throw, NOT return all users
    List<User> result = userRepository.findByName(maliciousInput);
    assertTrue(result.isEmpty(), "SQL injection payload should not return data");
}

@Test
void shouldHandleSqlMetaCharacters() {
    // These should be treated as literal values, not SQL syntax
    String inputWithQuotes = "O'Brien";
    String inputWithSemicolon = "admin; DROP TABLE users";
    
    // Both should either match literally or return empty — not throw
    assertDoesNotThrow(() -> userRepository.findByName(inputWithQuotes));
    assertDoesNotThrow(() -> userRepository.findByName(inputWithSemicolon));
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL SQL injection query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-089/SqlInjection.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-sql-injection/ |
| OWASP SQL Injection Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html |
| OWASP Query Parameterization | https://cheatsheetseries.owasp.org/cheatsheets/Query_Parameterization_Cheat_Sheet.html |
| Spring Data JPA | https://docs.spring.io/spring-data/jpa/reference/ |
| CWE-89 | https://cwe.mitre.org/data/definitions/89.html |
