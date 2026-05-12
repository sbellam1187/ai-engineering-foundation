# Spring Boot TDD Reference

Test patterns, dependencies, and conventions for TDD in Spring Boot applications (Gradle & Maven).

## Test Layer Guide

Select the appropriate test type based on what you're testing:

| Layer | Annotation | Use Case |
|-------|------------|----------|
| Unit (Service) | `@ExtendWith(MockitoExtension.class)` | Business logic with mocked dependencies |
| Unit (Repository) | `@DataJpaTest` | JPA queries, custom repository methods |
| Controller | `@WebMvcTest` | REST endpoints, request/response mapping |
| Integration | `@SpringBootTest` | Full application context, end-to-end flows |
| Database Integration | `@Testcontainers` + `@SpringBootTest` | Real database behavior with containers |

## Dependencies

### Gradle

```groovy
// build.gradle
dependencies {
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.testcontainers:junit-jupiter'
    testImplementation 'org.testcontainers:postgresql' // or mysql, etc.
}
```

### Maven

```xml
<!-- pom.xml -->
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId> <!-- or mysql, etc. -->
        <scope>test</scope>
    </dependency>
</dependencies>
```

## Naming Conventions

- Test classes: `{ClassName}Test.java` (unit) or `{ClassName}IT.java` (integration)
- Test methods: `should{ExpectedBehavior}_when{Condition}()`
- Package structure mirrors main source: `src/test/java` mirrors `src/main/java`

## Build & Test Commands

### Gradle

```bash
./gradlew test                  # Run unit tests
./gradlew integrationTest       # Run integration tests (if task exists)
./gradlew test --tests "com.example.UserServiceTest"  # Run specific test class
./gradlew jacocoTestReport      # Generate coverage report (if configured)
```

### Maven

```bash
./mvnw test                     # Run unit tests (Surefire)
./mvnw verify                   # Run unit + integration tests (Failsafe)
./mvnw test -Dtest=UserServiceTest  # Run specific test class
./mvnw jacoco:report            # Generate coverage report (if configured)
```

## Workflow Example

**Task**: Add endpoint `GET /api/users/{id}` returning user by ID

**Cycle 1 — Controller Test (RED → GREEN → REFACTOR)**
1. Write failing `@WebMvcTest` for endpoint → RED
2. Create controller method returning stub → GREEN
3. Clean up → REFACTOR

**Cycle 2 — Service Test (RED → GREEN → REFACTOR)**
1. Write failing unit test for `UserService.findById()` → RED
2. Implement service method → GREEN
3. Extract constants, improve naming → REFACTOR

**Cycle 3 — Repository Test (RED → GREEN → REFACTOR)**
1. Write `@DataJpaTest` for custom query if needed → RED
2. Implement repository method → GREEN
3. Optimize query → REFACTOR

**Cycle 4 — Integration Test**
1. Write `@SpringBootTest` verifying full flow → should pass if cycles 1–3 done correctly

---

## Test Patterns

Complete examples for each Spring Boot test layer.

### Unit Test — Service Layer

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Test
    void shouldReturnUser_whenUserExists() {
        // Arrange
        var user = new User(1L, "john@example.com", "John Doe");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        // Act
        var result = userService.findById(1L);

        // Assert
        assertThat(result).isPresent();
        assertThat(result.get().getEmail()).isEqualTo("john@example.com");
        verify(userRepository).findById(1L);
    }

    @Test
    void shouldThrowException_whenUserNotFound() {
        // Arrange
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        // Act & Assert
        assertThatThrownBy(() -> userService.getById(99L))
            .isInstanceOf(UserNotFoundException.class)
            .hasMessageContaining("99");
    }
}
```

### Unit Test — Repository Layer

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = Replace.NONE)
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void shouldFindUserByEmail_whenEmailExists() {
        // Arrange
        var user = new User(null, "test@example.com", "Test User");
        entityManager.persistAndFlush(user);

        // Act
        var result = userRepository.findByEmail("test@example.com");

        // Assert
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Test User");
    }

    @Test
    void shouldReturnActiveUsers_whenStatusIsActive() {
        // Arrange
        entityManager.persistAndFlush(new User(null, "active@test.com", "Active", Status.ACTIVE));
        entityManager.persistAndFlush(new User(null, "inactive@test.com", "Inactive", Status.INACTIVE));

        // Act
        var result = userRepository.findByStatus(Status.ACTIVE);

        // Assert
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getEmail()).isEqualTo("active@test.com");
    }
}
```

### Controller Test — WebMvcTest

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldReturnUser_whenGetUserById() throws Exception {
        // Arrange
        var user = new UserDto(1L, "john@example.com", "John Doe");
        when(userService.findById(1L)).thenReturn(Optional.of(user));

        // Act & Assert
        mockMvc.perform(get("/api/users/{id}", 1L))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("john@example.com"))
            .andExpect(jsonPath("$.name").value("John Doe"));
    }

    @Test
    void shouldReturn404_whenUserNotFound() throws Exception {
        // Arrange
        when(userService.findById(99L)).thenReturn(Optional.empty());

        // Act & Assert
        mockMvc.perform(get("/api/users/{id}", 99L))
            .andExpect(status().isNotFound());
    }

    @Test
    void shouldCreateUser_whenValidRequest() throws Exception {
        // Arrange
        var request = new CreateUserRequest("new@example.com", "New User");
        var created = new UserDto(1L, "new@example.com", "New User");
        when(userService.create(any())).thenReturn(created);

        // Act & Assert
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1L));
    }

    @Test
    void shouldReturn400_whenInvalidRequest() throws Exception {
        // Arrange
        var request = new CreateUserRequest("", ""); // Invalid: empty fields

        // Act & Assert
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest());
    }
}
```

### Integration Test — SpringBootTest

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class UserIntegrationIT {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    void shouldCreateAndRetrieveUser() {
        // Arrange
        var request = new CreateUserRequest("integration@test.com", "Integration User");

        // Act - Create
        var createResponse = restTemplate.postForEntity(
            "/api/users", request, UserDto.class);

        // Assert - Create
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody()).isNotNull();
        var userId = createResponse.getBody().getId();

        // Act - Retrieve
        var getResponse = restTemplate.getForEntity(
            "/api/users/{id}", UserDto.class, userId);

        // Assert - Retrieve
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().getEmail()).isEqualTo("integration@test.com");
    }
}
```

### Integration Test — Testcontainers

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("testcontainers")
class UserTestcontainersIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldPersistUserToRealDatabase() {
        // Arrange
        var user = new User(null, "testcontainer@test.com", "TC User");

        // Act
        var saved = userRepository.save(user);

        // Assert
        assertThat(saved.getId()).isNotNull();
        var found = userRepository.findById(saved.getId());
        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("testcontainer@test.com");
    }

    @Test
    void shouldHandleConcurrentUpdates() {
        // Arrange
        var user = userRepository.save(new User(null, "concurrent@test.com", "User"));

        // Act & Assert - Test optimistic locking
        var user1 = userRepository.findById(user.getId()).orElseThrow();
        var user2 = userRepository.findById(user.getId()).orElseThrow();

        user1.setName("Updated by 1");
        userRepository.save(user1);

        user2.setName("Updated by 2");
        assertThatThrownBy(() -> userRepository.save(user2))
            .isInstanceOf(OptimisticLockingFailureException.class);
    }
}
```

## AssertJ Cheat Sheet

```java
// Object assertions
assertThat(user).isNotNull();
assertThat(user.getName()).isEqualTo("John");
assertThat(user).isEqualToComparingFieldByField(expectedUser);

// Collection assertions
assertThat(users).hasSize(3);
assertThat(users).isEmpty();
assertThat(users).contains(user1, user2);
assertThat(users).extracting(User::getEmail).containsExactly("a@test.com", "b@test.com");

// Exception assertions
assertThatThrownBy(() -> service.delete(999L))
    .isInstanceOf(NotFoundException.class)
    .hasMessageContaining("not found");

assertThatCode(() -> service.validate(validInput)).doesNotThrowAnyException();

// Optional assertions
assertThat(result).isPresent();
assertThat(result).isEmpty();
assertThat(result).hasValueSatisfying(u -> assertThat(u.getName()).startsWith("John"));
```

## Mockito Cheat Sheet

```java
// Stubbing
when(repository.findById(1L)).thenReturn(Optional.of(user));
when(repository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
doThrow(new RuntimeException()).when(service).delete(999L);

// Verification
verify(repository).save(any(User.class));
verify(repository, times(2)).findById(anyLong());
verify(repository, never()).delete(any());
verifyNoMoreInteractions(repository);

// Argument captors
@Captor ArgumentCaptor<User> userCaptor;

verify(repository).save(userCaptor.capture());
assertThat(userCaptor.getValue().getEmail()).isEqualTo("captured@test.com");
```

## Test Configuration

### application-test.yml

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
```

### application-testcontainers.yml

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
```
