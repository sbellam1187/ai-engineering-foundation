---
id: REF-java-spring-0001-test-patterns
title: Test Patterns Reference
version: 1.0.0
status: active
owner: enterprise-architecture
concern: java-spring
created: 2026-03-23
lastUpdated: 2026-03-23
description: Complete code examples for each Spring Boot test layer including unit tests, repository tests, controller tests, and integration tests with Testcontainers.
related:
  skills:
    - SKILL-java-spring-0002-spring-boot-tdd
---

# Test Patterns Reference

Complete examples for each Spring Boot test layer.

## Unit Test - Service Layer

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

## Unit Test - Repository Layer

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

## Controller Test - WebMvcTest

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

## Integration Test - SpringBootTest

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

## Integration Test - Testcontainers

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
