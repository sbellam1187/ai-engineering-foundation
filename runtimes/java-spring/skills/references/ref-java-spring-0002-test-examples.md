# Test Examples & Patterns

> These examples illustrate the enterprise test patterns required by the `java-unit-test-generator` skill.
> They are **generic templates** — consuming projects should adapt class names, packages, and builders
> to their own domain.

---

## Pattern 1 — Service Class with Repository Dependency

Demonstrates: `@ExtendWith(MockitoExtension.class)`, `@InjectMocks` / `@Mock`, happy path,
not-found exception, deep assertions, mock verification.

```java
package com.example.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ItemServiceTest {

    @InjectMocks
    private ItemServiceImpl target;

    @Mock
    private ItemRepository mockRepository;

    // ── happy path ──────────────────────────────────────────────

    @Test
    void shouldReturnItem_whenIdExists() {
        // Arrange
        Item expected = Item.builder().id("ITEM-001").name("Widget").price(9.99).build();
        when(mockRepository.findById("ITEM-001")).thenReturn(Optional.of(expected));

        // Act
        Item result = target.findById("ITEM-001");

        // Assert — deep: validate field values, not just non-null
        assertThat(result.getId()).isEqualTo("ITEM-001");
        assertThat(result.getName()).isEqualTo("Widget");
        assertThat(result.getPrice()).isEqualTo(9.99);
        verify(mockRepository).findById("ITEM-001");
    }

    // ── exception scenario ──────────────────────────────────────

    @Test
    void shouldThrowNotFoundException_whenIdDoesNotExist() {
        // Arrange
        when(mockRepository.findById(anyString())).thenReturn(Optional.empty());

        // Act & Assert
        assertThatThrownBy(() -> target.findById("MISSING"))
                .isInstanceOf(ItemNotFoundException.class)
                .hasMessageContaining("Item not found: MISSING");
        verify(mockRepository).findById("MISSING");
    }

    // ── edge case ───────────────────────────────────────────────

    @Test
    void shouldThrowIllegalArgument_whenIdIsNull() {
        // Act & Assert
        assertThatThrownBy(() -> target.findById(null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("id must not be null");
        verify(mockRepository, never()).findById(anyString());
    }
}
```

**Key take-aways:**
- One `@Mock` per external dependency; real objects for domain types.
- Every `@Test` has explicit `// Arrange`, `// Act`, `// Assert` comments.
- Assertions inspect **field values**, not just `isNotNull()`.
- `verify()` confirms the expected interaction occurred.

---

## Pattern 2 — Validation / Rule Class (no mocking)

Demonstrates: testing a pure-logic class, `@BeforeEach` shared setup,
boundary values, violation message assertions.

```java
package com.example.validation;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class MaxAmountValidatorTest {

    private MaxAmountValidator target;
    private List<ValidationResult> results;

    @BeforeEach
    void setUp() {
        target = new MaxAmountValidator(/* threshold */ 10_000);
        results = new ArrayList<>();
    }

    // ── happy path ──────────────────────────────────────────────

    @Test
    void shouldPass_whenAmountBelowThreshold() {
        // Arrange
        Request request = Request.builder().amount(5_000).build();

        // Act
        target.validate(request, results);

        // Assert
        assertThat(results).isEmpty();
    }

    // ── boundary ────────────────────────────────────────────────

    @Test
    void shouldPass_whenAmountEqualsThreshold() {
        // Arrange
        Request request = Request.builder().amount(10_000).build();

        // Act
        target.validate(request, results);

        // Assert
        assertThat(results).isEmpty();
    }

    // ── violation ───────────────────────────────────────────────

    @Test
    void shouldReportViolation_whenAmountExceedsThreshold() {
        // Arrange
        Request request = Request.builder().amount(10_001).build();

        // Act
        target.validate(request, results);

        // Assert — deep: verify code, severity, and message content
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCode()).isEqualTo("MAX_AMOUNT_EXCEEDED");
        assertThat(results.get(0).getSeverity()).isEqualTo("ERROR");
        assertThat(results.get(0).getMessage()).contains("10001", "exceeds maximum 10000");
    }

    // ── edge case ───────────────────────────────────────────────

    @Test
    void shouldReportViolation_whenAmountIsNegative() {
        // Arrange
        Request request = Request.builder().amount(-1).build();

        // Act
        target.validate(request, results);

        // Assert
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCode()).isEqualTo("INVALID_AMOUNT");
    }
}
```

**Key takeaways:**
- No `@Mock` needed — the class under test has no external dependencies.
- Boundary value (`== threshold`) tested explicitly.
- Assertions drill into `getCode()`, `getSeverity()`, `getMessage()` — never just `isNotNull()`.

---

## Pattern 3 — Collection / Aggregation Logic

Demonstrates: empty-collection edge case, filtering logic, `@InjectMocks` with builder-created domain objects.

```java
package com.example.aggregation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ScoreAggregatorTest {

    @InjectMocks
    private ScoreAggregator target;

    // ── happy path ──────────────────────────────────────────────

    @Test
    void shouldSumActiveScores_whenMultipleEntriesProvided() {
        // Arrange
        List<ScoreEntry> entries = List.of(
                ScoreEntry.builder().value(80).active(true).build(),
                ScoreEntry.builder().value(60).active(true).build(),
                ScoreEntry.builder().value(40).active(false).build()  // excluded
        );

        // Act
        int total = target.sumActiveScores(entries);

        // Assert
        assertThat(total).isEqualTo(140);
    }

    // ── edge case: empty collection ─────────────────────────────

    @Test
    void shouldReturnZero_whenListIsEmpty() {
        // Arrange
        List<ScoreEntry> entries = new ArrayList<>();

        // Act
        int total = target.sumActiveScores(entries);

        // Assert
        assertThat(total).isEqualTo(0);
    }

    // ── edge case: all inactive ─────────────────────────────────

    @Test
    void shouldReturnZero_whenAllEntriesAreInactive() {
        // Arrange
        List<ScoreEntry> entries = List.of(
                ScoreEntry.builder().value(50).active(false).build()
        );

        // Act
        int total = target.sumActiveScores(entries);

        // Assert
        assertThat(total).isEqualTo(0);
    }

    // ── null guard ──────────────────────────────────────────────

    @Test
    void shouldThrowException_whenListIsNull() {
        // Act & Assert
        assertThatThrownBy(() -> target.sumActiveScores(null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("entries must not be null");
    }
}
```

**Key takeaways:**
- Domain objects built with the builder pattern (no mocking).
- Empty-collection and all-filtered-out edge cases are covered.
- Null-input guard tested explicitly.

---

## Pattern 4 — Mock Verification (interaction testing)

Demonstrates: `verify()` variants — `times()`, `never()`, `any()`, argument captors.

```java
package com.example.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class NotificationDispatcherTest {

    @InjectMocks
    private NotificationDispatcher target;

    @Mock
    private EmailClient mockEmailClient;

    @Mock
    private AuditLogger mockAuditLogger;

    @Captor
    private ArgumentCaptor<EmailMessage> emailCaptor;

    @Test
    void shouldSendEmailAndLogAudit_whenRecipientIsValid() {
        // Arrange
        when(mockEmailClient.send(any(EmailMessage.class))).thenReturn(true);

        // Act
        target.dispatch("user@example.com", "Hello");

        // Assert — verify interactions
        verify(mockEmailClient, times(1)).send(emailCaptor.capture());
        verify(mockAuditLogger).log(eq("EMAIL_SENT"), eq("user@example.com"));

        // Assert — deep-check captured argument
        EmailMessage sent = emailCaptor.getValue();
        assertThat(sent.getRecipient()).isEqualTo("user@example.com");
        assertThat(sent.getBody()).isEqualTo("Hello");
    }

    @Test
    void shouldNotSendEmail_whenRecipientIsBlank() {
        // Act
        target.dispatch("", "Hello");

        // Assert
        verify(mockEmailClient, never()).send(any(EmailMessage.class));
        verify(mockAuditLogger).log(eq("EMAIL_SKIPPED"), eq("blank recipient"));
    }
}
```

**Key takeaways:**
- `ArgumentCaptor` used to inspect the exact object passed to the mock.
- `never()` verifies a method was **not** called.
- Audit/logging side-effects verified alongside business logic.

---

## Anti-Patterns (❌ DO NOT)

```java
// ❌ Shallow assertion — proves nothing about content
assertThat(result).isNotNull();

// ❌ Fully qualified class name instead of import
org.junit.jupiter.api.Assertions.assertEquals(expected, actual);

// ❌ Missing AAR comments — impossible to skim
@Test void test1() { service.process(input); assertTrue(output.isValid()); }

// ❌ Mocking a domain object instead of using a real instance / builder
@Mock private Order mockOrder;

// ❌ Star import
import static org.mockito.Mockito.*;
```
