# CWE-327/328/338 — Cryptographic Failures

## CodeQL Query Details

| Attribute | Value |
|-----------|-------|
| **Rule IDs** | `java/weak-cryptographic-algorithm`, `java/insecure-randomness` |
| **Query files** | [`CWE-327/BrokenCryptoAlgorithm.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-327/BrokenCryptoAlgorithm.ql), [`CWE-338/InsecureRandomness.ql`](https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-338/InsecureRandomness.ql) |
| **Kind** | `problem` |
| **Precision** | `high` |
| **Security severity** | `7.5` (High) |
| **OWASP** | A02:2021 Cryptographic Failures |

---

## What CodeQL Is Detecting

### CWE-327 — Broken Algorithm
CodeQL flags use of broken or weak cryptographic algorithms by name.

**Flagged algorithms:**
- `MessageDigest.getInstance("MD5")` — broken, collision attacks
- `MessageDigest.getInstance("SHA-1")` — deprecated, collision attacks
- `Cipher.getInstance("DES/...")` — 56-bit key, brute-forceable
- `Cipher.getInstance("RC2/...")` — weak
- `Cipher.getInstance("RC4")` / `Cipher.getInstance("ARCFOUR")` — broken stream cipher
- `Cipher.getInstance("AES/ECB/...")` — ECB mode leaks patterns
- `KeyPairGenerator` with RSA < 2048 bits

### CWE-338 — Insecure Randomness
CodeQL flags use of `java.util.Random` in security-sensitive contexts.

**Flagged:**
- `new Random().nextInt()` used for token generation
- `Math.random()` used for session IDs or security nonces
- `Random` seeded with predictable values

**What it does NOT flag:**
- `SecureRandom` — cryptographically secure
- `UUID.randomUUID()` — uses `SecureRandom` internally
- `Random` used for non-security purposes (shuffling UI elements, test data)

---

## Fix Patterns

### Replace Weak Hashing

```java
// ❌ BAD — MD5 and SHA-1 are broken
MessageDigest md5 = MessageDigest.getInstance("MD5");
MessageDigest sha1 = MessageDigest.getInstance("SHA-1");

// ✅ GOOD — use SHA-256 or stronger for general hashing
MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
byte[] hash = sha256.digest(data.getBytes(StandardCharsets.UTF_8));

// ✅ GOOD — for passwords, NEVER use raw hashing — use BCrypt
// Add Spring Security dependency which includes BCrypt
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12); // cost factor 12
}

// Usage
String encoded = passwordEncoder.encode(rawPassword);
boolean matches = passwordEncoder.matches(rawPassword, encoded);
```

### Replace Weak Cipher

```java
// ❌ BAD — DES, RC4, AES/ECB
Cipher des = Cipher.getInstance("DES/CBC/PKCS5Padding");
Cipher ecb = Cipher.getInstance("AES/ECB/PKCS5Padding"); // ECB leaks patterns

// ✅ GOOD — AES-256 with GCM (authenticated encryption)
public byte[] encrypt(byte[] plaintext, SecretKey key) throws Exception {
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

    // Generate a fresh random IV for every encryption
    byte[] iv = new byte[12]; // 96 bits for GCM
    new SecureRandom().nextBytes(iv);
    GCMParameterSpec paramSpec = new GCMParameterSpec(128, iv); // 128-bit auth tag

    cipher.init(Cipher.ENCRYPT_MODE, key, paramSpec);
    byte[] ciphertext = cipher.doFinal(plaintext);

    // Prepend IV to ciphertext for use during decryption
    byte[] result = new byte[iv.length + ciphertext.length];
    System.arraycopy(iv, 0, result, 0, iv.length);
    System.arraycopy(ciphertext, 0, result, iv.length, ciphertext.length);
    return result;
}

public byte[] decrypt(byte[] ivAndCiphertext, SecretKey key) throws Exception {
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

    byte[] iv = Arrays.copyOfRange(ivAndCiphertext, 0, 12);
    byte[] ciphertext = Arrays.copyOfRange(ivAndCiphertext, 12, ivAndCiphertext.length);

    GCMParameterSpec paramSpec = new GCMParameterSpec(128, iv);
    cipher.init(Cipher.DECRYPT_MODE, key, paramSpec);
    return cipher.doFinal(ciphertext);
}

// Generate a strong AES-256 key
public SecretKey generateKey() throws Exception {
    KeyGenerator keyGen = KeyGenerator.getInstance("AES");
    keyGen.init(256, new SecureRandom());
    return keyGen.generateKey();
}
```

### Replace Insecure Random

```java
// ❌ BAD — java.util.Random is predictable
Random random = new Random();
String token = String.valueOf(random.nextLong()); // predictable

// ❌ BAD — Math.random() is also predictable
String sessionId = Double.toString(Math.random());

// ✅ GOOD — SecureRandom for all security-sensitive values
SecureRandom secureRandom = new SecureRandom();

// Generate a secure token (hex)
byte[] tokenBytes = new byte[32]; // 256 bits
secureRandom.nextBytes(tokenBytes);
String token = HexFormat.of().formatHex(tokenBytes);

// Generate a secure token (Base64 URL-safe)
String base64Token = Base64.getUrlEncoder()
    .withoutPadding()
    .encodeToString(tokenBytes);

// Generate a secure UUID (already uses SecureRandom)
String uuid = UUID.randomUUID().toString();

// Generate a secure numeric OTP
int otp = secureRandom.nextInt(900000) + 100000; // 6-digit OTP
```

### RSA — Minimum Key Size

```java
// ❌ BAD — RSA-1024 is too small
KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
kpg.initialize(1024); // breakable

// ✅ GOOD — RSA-2048 minimum, prefer RSA-4096 or EC
KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
kpg.initialize(2048, new SecureRandom());
KeyPair keyPair = kpg.generateKeyPair();

// ✅ BETTER — use Elliptic Curve (stronger with smaller keys)
KeyPairGenerator ecKpg = KeyPairGenerator.getInstance("EC");
ECGenParameterSpec ecSpec = new ECGenParameterSpec("secp256r1"); // P-256
ecKpg.initialize(ecSpec, new SecureRandom());
KeyPair ecKeyPair = ecKpg.generateKeyPair();
```

### Spring Security — Crypto Module

```java
// ✅ GOOD — Spring Security's crypto module handles key management
import org.springframework.security.crypto.encrypt.Encryptors;
import org.springframework.security.crypto.keygen.KeyGenerators;

// Generate a random salt
String salt = KeyGenerators.string().generateKey();

// AES-256/GCM encryption (Spring wraps it safely)
BytesEncryptor encryptor = Encryptors.stronger(password, salt);
byte[] encrypted = encryptor.encrypt(plaintext);
byte[] decrypted = encryptor.decrypt(encrypted);
```

---

## Security Tests

```java
@Test
void shouldUseSecureRandomForTokens() throws NoSuchAlgorithmException {
    // Verify the token generation uses sufficient entropy
    Set<String> tokens = new HashSet<>();
    for (int i = 0; i < 1000; i++) {
        tokens.add(tokenService.generateToken());
    }
    // All 1000 tokens should be unique
    assertEquals(1000, tokens.size(), "Tokens must be unique — Random would repeat");

    // Tokens should have sufficient length (at least 32 chars)
    assertTrue(tokens.iterator().next().length() >= 32,
        "Token should have at least 256 bits of entropy");
}

@Test
void shouldUseStrongHashAlgorithm() {
    // Verify password hashing uses BCrypt (not MD5/SHA-1)
    String encoded = passwordEncoder.encode("testPassword");
    assertTrue(encoded.startsWith("$2a$") || encoded.startsWith("$2b$"),
        "Should use BCrypt encoding");
    assertFalse(encoded.length() == 32, "MD5 hashes are 32 chars — should not match");
}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL weak crypto query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-327/BrokenCryptoAlgorithm.ql |
| CodeQL insecure randomness query | https://github.com/github/codeql/blob/main/java/ql/src/Security/CWE/CWE-338/InsecureRandomness.ql |
| CodeQL query help | https://codeql.github.com/codeql-query-help/java/java-weak-cryptographic-algorithm/ |
| OWASP Cryptographic Failures | https://owasp.org/Top10/A02_2021-Cryptographic_Failures/ |
| OWASP Cryptographic Storage Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html |
| NIST Approved Algorithms | https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program |
| CWE-327 | https://cwe.mitre.org/data/definitions/327.html |
| CWE-338 | https://cwe.mitre.org/data/definitions/338.html |
