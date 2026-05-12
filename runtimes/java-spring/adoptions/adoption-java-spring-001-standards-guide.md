# Java Spring Boot Standards Guide
*Enterprise-Grade Development Standards for Spring Boot Applications*

**Version:** 1.0.0  
**Last Updated:** March 6th, 2026  
**Status:** Ratified

----

## Table of Contents

1. [Code Structure & Design](#1-code-structure--design)
2. [Architectural Patterns](#2-architectural-patterns)
3. [Security Standards](#3-security-standards)
4. [Performance and Resiliency](#4-performance-and-resiliency)
5. [Monitoring & Logging](#5-monitoring--logging)
6. [Testing Standards](#6-testing-standards)
7. [Code Quality & Maintenance](#7-code-quality--maintenance)

---

## 1. Code Structure & Design

### 1.1 Layered Architecture

#### Standard Package Structure

```
com.company.application
├── config/              # Configuration classes (@Configuration)
├── controller/          # REST controllers (@RestController)
├── service/            # Business logic layer (@Service)
│   ├── impl/          # Service implementations
│   └── validator/     # Business validation logic
├── repository/         # Data access layer (@Repository)
├── domain/            # Domain entities (@Entity)
│   └── shared/       # Shared domain models
├── dto/               # Data Transfer Objects
│   ├── request/      # Request DTOs
│   ├── response/     # Response DTOs
│   └── mapper/       # DTO-Entity mappers (MapStruct)
├── exception/         # Custom exceptions
│   └── handler/      # Global exception handlers
├── security/          # Security configurations
├── util/              # Utility classes
├── aspect/            # AOP aspects
├── event/             # Domain events
│   ├── publisher/    # Event publishers
│   └── listener/     # Event listeners
└── Application.java   # Main application class
```

#### Layer Responsibilities

**Controller Layer (@RestController)**
```java
/**
 * Controller responsibilities:
 * - HTTP request/response mapping
 * - Input validation (JSR-303/380)
 * - Request/Response DTO transformation
 * - HTTP status code management
 * - NO business logic
 */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Validated
@Slf4j
public class UserController {
    
    private final UserService userService;
    private final UserMapper userMapper;
    
    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUser(
            @PathVariable @Positive Long id) {
        log.debug("Fetching user with id: {}", id);
        User user = userService.findById(id);
        return ResponseEntity.ok(userMapper.toResponse(user));
    }
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<UserResponse> createUser(
            @RequestBody @Valid CreateUserRequest request) {
        log.info("Creating new user: {}", request.getEmail());
        User user = userService.createUser(request);
        return ResponseEntity
            .created(URI.create("/api/v1/users/" + user.getId()))
            .body(userMapper.toResponse(user));
    }
}
```

**Service Layer (@Service)**
```java
/**
 * Service layer responsibilities:
 * - Business logic implementation
 * - Transaction management
 * - Domain model orchestration
 * - Business validation
 * - Event publishing
 * - Coordination between repositories
 */
@Service
@Transactional(readOnly = true)
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {
    
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final UserValidator userValidator;
    
    @Override
    @Transactional
    public User createUser(CreateUserRequest request) {
        // Business validation
        userValidator.validateCreateRequest(request);
        
        // Check business rules
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new DuplicateUserException("User with email already exists");
        }
        
        // Create domain entity
        User user = User.builder()
            .email(request.getEmail())
            .firstName(request.getFirstName())
            .lastName(request.getLastName())
            .status(UserStatus.ACTIVE)
            .createdAt(Instant.now())
            .build();
        
        // Persist
        User savedUser = userRepository.save(user);
        
        // Publish domain event
        eventPublisher.publishEvent(new UserCreatedEvent(this, savedUser));
        
        log.info("User created successfully: {}", savedUser.getId());
        return savedUser;
    }
    
    @Override
    @Cacheable(value = "users", key = "#id")
    public User findById(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }
}
```

**Repository Layer (@Repository)**
```java
/**
 * Repository responsibilities:
 * - Data access operations
 * - Query methods
 * - Custom query implementations
 * - NO business logic
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long>, 
        UserRepositoryCustom {
    
    Optional<User> findByEmail(String email);
    
    boolean existsByEmail(String email);
    
    List<User> findByStatus(UserStatus status);
    
    @Query("SELECT u FROM User u WHERE u.createdAt >= :date")
    List<User> findRecentUsers(@Param("date") Instant date);
    
    // Native query for complex operations
    @Query(value = """
        SELECT u.* FROM users u
        WHERE u.status = 'ACTIVE'
        AND u.last_login > CURRENT_DATE - INTERVAL '30 days'
        """, nativeQuery = true)
    List<User> findActiveUsersWithRecentLogin();
}
```

### 1.2 Data Transfer Objects (DTOs)

#### DTO Guidelines

**Why Use DTOs?**
- Decouple API contract from domain model
- Control data exposure (security)
- Version API independently from domain
- Optimize network payload
- Enable API evolution without breaking changes

#### Request DTOs

```java
/**
 * Request DTO with validation
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateUserRequest {
    
    @NotBlank(message = "Email is required")
    @Email(message = "Email must be valid")
    @Size(max = 255, message = "Email must not exceed 255 characters")
    private String email;
    
    @NotBlank(message = "First name is required")
    @Size(min = 2, max = 50, message = "First name must be between 2 and 50 characters")
    private String firstName;
    
    @NotBlank(message = "Last name is required")
    @Size(min = 2, max = 50, message = "Last name must be between 2 and 50 characters")
    private String lastName;
    
    @Pattern(regexp = "^\\+?[1-9]\\d{1,14}$", 
             message = "Phone number must be in E.164 format")
    private String phoneNumber;
    
    @Valid
    private AddressRequest address;
}
```

#### Response DTOs

```java
/**
 * Response DTO - immutable and serializable
 */
@Value
@Builder
public class UserResponse {
    
    Long id;
    String email;
    String firstName;
    String lastName;
    String phoneNumber;
    UserStatus status;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", timezone = "UTC")
    Instant createdAt;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", timezone = "UTC")
    Instant updatedAt;
    
    AddressResponse address;
    
    // Exclude sensitive fields using @JsonIgnore
    @JsonIgnore
    String internalNotes;
}
```

#### DTO Mappers (MapStruct)

```java
/**
 * MapStruct mapper for DTO-Entity conversion
 * Compile-time generated, type-safe, performant
 */
@Mapper(componentModel = "spring", 
        unmappedTargetPolicy = ReportingPolicy.WARN,
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface UserMapper {
    
    UserResponse toResponse(User user);
    
    List<UserResponse> toResponseList(List<User> users);
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "status", constant = "ACTIVE")
    User toEntity(CreateUserRequest request);
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    void updateEntity(UpdateUserRequest request, @MappingTarget User user);
}
```

### 1.3 Dependency Injection

#### Constructor-Based Injection (Mandatory)

```java
/**
 * ALWAYS use constructor-based injection for:
 * - Immutability (final fields)
 * - Testability
 * - Circular dependency detection
 * - Clear dependency declaration
 */

// ✅ CORRECT: Constructor injection with Lombok
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final UserValidator userValidator;
}

// ✅ CORRECT: Explicit constructor (without Lombok)
@Service
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
    
    public UserService(UserRepository userRepository, 
                       EmailService emailService) {
        this.userRepository = userRepository;
        this.emailService = emailService;
    }
}

// ❌ WRONG: Field injection
@Service
public class UserService {
    @Autowired  // BAD: Field injection
    private UserRepository userRepository;
    
    @Autowired  // BAD: Harder to test
    private EmailService emailService;
}

// ❌ WRONG: Setter injection
@Service
public class UserService {
    private UserRepository userRepository;
    
    @Autowired  // BAD: Fields are mutable
    public void setUserRepository(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
}
```

### 1.4 Naming Conventions

#### Class Naming Standards

| Component | Suffix | Example | Purpose |
|-----------|--------|---------|---------|
| REST Controller | `Controller` | `UserController` | HTTP endpoints |
| Service Interface | `Service` | `UserService` | Business logic contract |
| Service Implementation | `ServiceImpl` | `UserServiceImpl` | Business logic implementation |
| Repository | `Repository` | `UserRepository` | Data access |
| Domain Entity | (none) | `User`, `Order` | Domain model |
| DTO Request | `Request` | `CreateUserRequest` | API request payload |
| DTO Response | `Response` | `UserResponse` | API response payload |
| Mapper | `Mapper` | `UserMapper` | DTO-Entity conversion |
| Configuration | `Config` or `Configuration` | `DatabaseConfig` | Bean configuration |
| Exception | `Exception` | `UserNotFoundException` | Custom exception |
| Validator | `Validator` | `UserValidator` | Business validation |
| Aspect | `Aspect` | `LoggingAspect` | Cross-cutting concern |
| Event | `Event` | `UserCreatedEvent` | Domain event |
| Listener | `Listener` | `UserEventListener` | Event subscriber |

#### Method Naming Standards

```java
/**
 * Method naming conventions
 */
public interface UserService {
    
    // Query methods: find*, get*, search*, list*, count*, exists*
    User findById(Long id);
    User getUserByEmail(String email);
    List<User> searchByName(String name);
    List<User> listActiveUsers();
    long countActiveUsers();
    boolean existsByEmail(String email);
    
    // Command methods: create*, update*, delete*, save*, remove*
    User createUser(CreateUserRequest request);
    User updateUser(Long id, UpdateUserRequest request);
    void deleteUser(Long id);
    User saveUser(User user);
    
    // Boolean predicates: is*, has*, can*, should*
    boolean isUserActive(Long id);
    boolean hasPermission(Long userId, Permission permission);
    boolean canUserAccess(Long userId, Resource resource);
    
    // Action methods: activate*, deactivate*, send*, process*
    void activateUser(Long id);
    void deactivateUser(Long id);
    void sendWelcomeEmail(User user);
    void processUserRegistration(User user);
}
```

### 1.5 Separate Domain Model (Shared Domain)

```java
/**
 * Shared domain models across services
 * Use in DDD context or microservices architecture
 */

// Shared domain module: common-domain
package com.company.common.domain;

/**
 * Value Object - immutable, no identity
 */
@Value
@Builder
public class Money {
    BigDecimal amount;
    Currency currency;
    
    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }
}

/**
 * Entity - has identity, mutable state
 */
@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, unique = true)
    private String email;
    
    @Embedded
    private PersonName name;  // Value object
    
    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "street", column = @Column(name = "billing_street")),
        @AttributeOverride(name = "city", column = @Column(name = "billing_city"))
    })
    private Address billingAddress;  // Value object
}

/**
 * Aggregate Root - consistency boundary
 */
@Entity
@Table(name = "orders")
public class Order {
    
    @Id
    private OrderId id;  // Value object for identity
    
    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "order_id")
    private List<OrderLine> orderLines = new ArrayList<>();
    
    private OrderStatus status;
    
    // Business method maintaining invariants
    public void addOrderLine(Product product, int quantity) {
        if (this.status != OrderStatus.DRAFT) {
            throw new IllegalStateException("Cannot modify confirmed order");
        }
        
        OrderLine line = new OrderLine(product, quantity);
        this.orderLines.add(line);
    }
}
```

---

## 2. Architectural Patterns

### 2.1 SOLID Principles

#### 2.1.1 Single Responsibility Principle (SRP)

**Definition:** A class should have only one reason to change, meaning it should have only one job or responsibility.

#### ❌ Violation Example

```java
@Service
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    // Responsibility 1: User management
    public User createUser(CreateUserRequest request) {
        User user = new User();
        user.setEmail(request.getEmail());
        user.setFirstName(request.getFirstName());
        return userRepository.save(user);
    }
    
    // Responsibility 2: Email sending
    public void sendWelcomeEmail(User user) {
        String subject = "Welcome " + user.getFirstName();
        String body = "Thank you for registering...";
        // Send email logic
        EmailUtil.send(user.getEmail(), subject, body);
    }
    
    // Responsibility 3: Reporting
    public byte[] generateUserReport(Long userId) {
        User user = userRepository.findById(userId).orElseThrow();
        // Generate PDF report
        PdfGenerator generator = new PdfGenerator();
        return generator.generate(user);
    }
    
    // Responsibility 4: Validation
    public boolean validateEmail(String email) {
        return email.matches("^[A-Za-z0-9+_.-]+@(.+)$");
    }
}
```

#### ✅ Correct Implementation

```java
/**
 * Single Responsibility: User business logic only
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {
    
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final UserValidator userValidator;
    
    @Transactional
    public User createUser(CreateUserRequest request) {
        userValidator.validate(request);
        
        User user = User.builder()
            .email(request.getEmail())
            .firstName(request.getFirstName())
            .lastName(request.getLastName())
            .status(UserStatus.ACTIVE)
            .build();
        
        User savedUser = userRepository.save(user);
        
        // Delegate email sending to EmailService
        emailService.sendWelcomeEmail(savedUser);
        
        log.info("User created: {}", savedUser.getId());
        return savedUser;
    }
}

/**
 * Single Responsibility: Email operations
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {
    
    private final JavaMailSender mailSender;
    private final EmailTemplateEngine templateEngine;
    
    public void sendWelcomeEmail(User user) {
        String subject = "Welcome to Our Platform";
        String body = templateEngine.render("welcome-email", user);
        
        sendEmail(user.getEmail(), subject, body);
        log.info("Welcome email sent to: {}", user.getEmail());
    }
    
    private void sendEmail(String to, String subject, String body) {
        // Email sending implementation
    }
}

/**
 * Single Responsibility: User validation
 */
@Component
public class UserValidator {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@(.+)$");
    
    public void validate(CreateUserRequest request) {
        validateEmail(request.getEmail());
        validateName(request.getFirstName(), "First name");
        validateName(request.getLastName(), "Last name");
    }
    
    private void validateEmail(String email) {
        if (email == null || !EMAIL_PATTERN.matcher(email).matches()) {
            throw new ValidationException("Invalid email format");
        }
    }
    
    private void validateName(String name, String fieldName) {
        if (name == null || name.trim().isEmpty()) {
            throw new ValidationException(fieldName + " is required");
        }
        if (name.length() < 2 || name.length() > 50) {
            throw new ValidationException(fieldName + " must be 2-50 characters");
        }
    }
}

/**
 * Single Responsibility: Report generation
 */
@Service
@RequiredArgsConstructor
public class UserReportService {
    
    private final UserRepository userRepository;
    private final PdfGenerator pdfGenerator;
    
    public byte[] generateUserReport(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException(userId));
        
        return pdfGenerator.generateUserReport(user);
    }
}
```

#### 2.1.2 Open/Closed Principle (OCP)

**Definition:** Software entities should be open for extension but closed for modification.

#### ❌ Violation Example

```java
@Service
public class PaymentProcessor {
    
    public void processPayment(Payment payment) {
        if (payment.getType().equals("CREDIT_CARD")) {
            // Process credit card
            chargeCreditCard(payment);
        } else if (payment.getType().equals("PAYPAL")) {
            // Process PayPal
            chargePayPal(payment);
        } else if (payment.getType().equals("BITCOIN")) {
            // Process Bitcoin - MODIFIED CLASS TO ADD NEW TYPE
            chargeBitcoin(payment);
        }
        // Adding new payment types requires modifying this class
    }
}
```

#### ✅ Correct Implementation (Strategy Pattern)

```java
/**
 * Payment strategy interface (Open for extension)
 */
public interface PaymentStrategy {
    void processPayment(Payment payment);
    String getPaymentType();
}

/**
 * Credit Card implementation
 */
@Service
public class CreditCardPaymentStrategy implements PaymentStrategy {
    
    @Override
    public void processPayment(Payment payment) {
        log.info("Processing credit card payment: {}", payment.getAmount());
        // Credit card processing logic
    }
    
    @Override
    public String getPaymentType() {
        return "CREDIT_CARD";
    }
}

/**
 * PayPal implementation
 */
@Service
public class PayPalPaymentStrategy implements PaymentStrategy {
    
    @Override
    public void processPayment(Payment payment) {
        log.info("Processing PayPal payment: {}", payment.getAmount());
        // PayPal processing logic
    }
    
    @Override
    public String getPaymentType() {
        return "PAYPAL";
    }
}

/**
 * Bitcoin implementation (NEW - no modification to existing code)
 */
@Service
public class BitcoinPaymentStrategy implements PaymentStrategy {
    
    @Override
    public void processPayment(Payment payment) {
        log.info("Processing Bitcoin payment: {}", payment.getAmount());
        // Bitcoin processing logic
    }
    
    @Override
    public String getPaymentType() {
        return "BITCOIN";
    }
}

/**
 * Payment processor (Closed for modification)
 */
@Service
@RequiredArgsConstructor
public class PaymentProcessor {
    
    private final List<PaymentStrategy> paymentStrategies;
    
    public void processPayment(Payment payment) {
        PaymentStrategy strategy = paymentStrategies.stream()
            .filter(s -> s.getPaymentType().equals(payment.getType()))
            .findFirst()
            .orElseThrow(() -> new UnsupportedPaymentTypeException(payment.getType()));
        
        strategy.processPayment(payment);
    }
}
```

#### 2.1.3 Liskov Substitution Principle (LSP)

**Definition:** Objects of a superclass should be replaceable with objects of a subclass without breaking the application.

#### ❌ Violation Example

```java
public class Rectangle {
    protected int width;
    protected int height;
    
    public void setWidth(int width) {
        this.width = width;
    }
    
    public void setHeight(int height) {
        this.height = height;
    }
    
    public int getArea() {
        return width * height;
    }
}

public class Square extends Rectangle {
    @Override
    public void setWidth(int width) {
        this.width = width;
        this.height = width;  // Violates LSP - changes behavior
    }
    
    @Override
    public void setHeight(int height) {
        this.width = height;  // Violates LSP - changes behavior
        this.height = height;
    }
}

// This will fail for Square
public void testRectangle(Rectangle rectangle) {
    rectangle.setWidth(5);
    rectangle.setHeight(4);
    assert rectangle.getArea() == 20;  // Fails for Square!
}
```

#### ✅ Correct Implementation

```java
/**
 * Shape interface - common contract
 */
public interface Shape {
    int getArea();
}

/**
 * Rectangle implementation
 */
public class Rectangle implements Shape {
    private final int width;
    private final int height;
    
    public Rectangle(int width, int height) {
        this.width = width;
        this.height = height;
    }
    
    @Override
    public int getArea() {
        return width * height;
    }
    
    public int getWidth() {
        return width;
    }
    
    public int getHeight() {
        return height;
    }
}

/**
 * Square implementation (separate from Rectangle)
 */
public class Square implements Shape {
    private final int side;
    
    public Square(int side) {
        this.side = side;
    }
    
    @Override
    public int getArea() {
        return side * side;
    }
    
    public int getSide() {
        return side;
    }
}

/**
 * Usage - both can be used interchangeably as Shape
 */
public int calculateTotalArea(List<Shape> shapes) {
    return shapes.stream()
        .mapToInt(Shape::getArea)
        .sum();
}
```

#### Spring Boot LSP Example

```java
/**
 * Base notification service
 */
public interface NotificationService {
    void sendNotification(String recipient, String message);
    boolean isAvailable();
}

/**
 * Email notification
 */
@Service
@RequiredArgsConstructor
public class EmailNotificationService implements NotificationService {
    
    private final JavaMailSender mailSender;
    
    @Override
    public void sendNotification(String recipient, String message) {
        MimeMessage mimeMessage = mailSender.createMimeMessage();
        // Send email
        mailSender.send(mimeMessage);
    }
    
    @Override
    public boolean isAvailable() {
        return true;  // Always available
    }
}

/**
 * SMS notification
 */
@Service
@RequiredArgsConstructor
public class SmsNotificationService implements NotificationService {
    
    private final SmsClient smsClient;
    
    @Override
    public void sendNotification(String recipient, String message) {
        smsClient.sendSms(recipient, message);
    }
    
    @Override
    public boolean isAvailable() {
        return smsClient.isConnected();
    }
}

/**
 * Client code - works with any NotificationService
 */
@Service
@RequiredArgsConstructor
public class UserNotificationService {
    
    private final List<NotificationService> notificationServices;
    
    public void notifyUser(String recipient, String message) {
        notificationServices.stream()
            .filter(NotificationService::isAvailable)
            .forEach(service -> service.sendNotification(recipient, message));
    }
}
```

#### 2.1.4 Interface Segregation Principle (ISP)
**Definition:** Clients should not be forced to depend on interfaces they don't use.

#### ❌ Violation Example

```java
/**
 * Fat interface - forces clients to implement unnecessary methods
 */
public interface Worker {
    void work();
    void eat();
    void sleep();
    void attendMeeting();
    void takeBreak();
}

/**
 * Robot forced to implement irrelevant methods
 */
public class RobotWorker implements Worker {
    @Override
    public void work() {
        // Robot can work
    }
    
    @Override
    public void eat() {
        throw new UnsupportedOperationException("Robots don't eat");
    }
    
    @Override
    public void sleep() {
        throw new UnsupportedOperationException("Robots don't sleep");
    }
    
    @Override
    public void attendMeeting() {
        throw new UnsupportedOperationException("Robots don't attend meetings");
    }
    
    @Override
    public void takeBreak() {
        throw new UnsupportedOperationException("Robots don't take breaks");
    }
}
```

#### ✅ Correct Implementation

```java
/**
 * Segregated interfaces
 */
public interface Workable {
    void work();
}

public interface Eatable {
    void eat();
}

public interface Sleepable {
    void sleep();
}

public interface Attendable {
    void attendMeeting();
}

public interface Breakable {
    void takeBreak();
}

/**
 * Human worker implements relevant interfaces
 */
public class HumanWorker implements Workable, Eatable, Sleepable, Attendable, Breakable {
    
    @Override
    public void work() {
        log.info("Human is working");
    }
    
    @Override
    public void eat() {
        log.info("Human is eating");
    }
    
    @Override
    public void sleep() {
        log.info("Human is sleeping");
    }
    
    @Override
    public void attendMeeting() {
        log.info("Human is attending meeting");
    }
    
    @Override
    public void takeBreak() {
        log.info("Human is taking a break");
    }
}

/**
 * Robot only implements what it needs
 */
public class RobotWorker implements Workable {
    
    @Override
    public void work() {
        log.info("Robot is working");
    }
}
```

#### Spring Boot ISP Example

```java
/**
 * Segregated repository interfaces
 */
public interface ReadableRepository<T, ID> {
    Optional<T> findById(ID id);
    List<T> findAll();
    boolean existsById(ID id);
}

public interface WritableRepository<T, ID> {
    T save(T entity);
    void deleteById(ID id);
}

public interface PageableRepository<T> {
    Page<T> findAll(Pageable pageable);
}

/**
 * Full repository (combines all interfaces)
 */
@Repository
public interface UserRepository extends 
    ReadableRepository<User, Long>,
    WritableRepository<User, Long>,
    PageableRepository<User> {
}

/**
 * Read-only repository for reporting
 */
@Repository
public interface UserReadOnlyRepository extends ReadableRepository<User, Long> {
    // Only read operations - cannot accidentally modify data
}

/**
 * Service using read-only repository
 */
@Service
@RequiredArgsConstructor
public class UserReportService {
    
    // This service can only read, not write
    private final UserReadOnlyRepository userRepository;
    
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
}
```

#### 2.1.5 Dependency Inversion Principle (DIP)

**Definition:** High-level modules should not depend on low-level modules. Both should depend on abstractions.

#### ❌ Violation Example

```java
/**
 * High-level module depends on low-level implementation
 */
@Service
public class OrderService {
    
    // Direct dependency on concrete class
    private MySqlOrderRepository orderRepository = new MySqlOrderRepository();
    private SendGridEmailService emailService = new SendGridEmailService();
    
    public void createOrder(Order order) {
        orderRepository.save(order);  // Tightly coupled to MySQL
        emailService.sendOrderConfirmation(order);  // Tightly coupled to SendGrid
    }
}

/**
 * Low-level module
 */
public class MySqlOrderRepository {
    public void save(Order order) {
        // MySQL specific implementation
    }
}

/**
 * Low-level module
 */
public class SendGridEmailService {
    public void sendOrderConfirmation(Order order) {
        // SendGrid specific implementation
    }
}
```

#### ✅ Correct Implementation

```java
/**
 * Abstraction for data access
 */
public interface OrderRepository {
    Order save(Order order);
    Optional<Order> findById(Long id);
}

/**
 * Abstraction for email service
 */
public interface EmailService {
    void sendOrderConfirmation(Order order);
}

/**
 * High-level module depends on abstractions
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    // Depends on abstractions, not implementations
    private final OrderRepository orderRepository;
    private final EmailService emailService;
    
    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        Order order = Order.builder()
            .customerId(request.getCustomerId())
            .items(request.getItems())
            .status(OrderStatus.PENDING)
            .build();
        
        Order savedOrder = orderRepository.save(order);
        emailService.sendOrderConfirmation(savedOrder);
        
        return savedOrder;
    }
}

/**
 * Low-level module - MySQL implementation
 */
@Repository
public class MySqlOrderRepository implements OrderRepository {
    
    @PersistenceContext
    private EntityManager entityManager;
    
    @Override
    public Order save(Order order) {
        entityManager.persist(order);
        return order;
    }
    
    @Override
    public Optional<Order> findById(Long id) {
        return Optional.ofNullable(entityManager.find(Order.class, id));
    }
}

/**
 * Low-level module - SendGrid implementation
 */
@Service
@RequiredArgsConstructor
public class SendGridEmailService implements EmailService {
    
    private final SendGrid sendGridClient;
    
    @Override
    public void sendOrderConfirmation(Order order) {
        Email from = new Email("orders@company.com");
        Email to = new Email(order.getCustomerEmail());
        String subject = "Order Confirmation #" + order.getId();
        Content content = new Content("text/html", buildEmailContent(order));
        
        Mail mail = new Mail(from, subject, to, content);
        sendGridClient.send(mail);
    }
    
    private String buildEmailContent(Order order) {
        // Build email HTML
        return "";
    }
}

/**
 * Alternative implementation - can swap without changing OrderService
 */
@Service
@Primary  // Use this implementation by default
@RequiredArgsConstructor
public class AwsSesEmailService implements EmailService {
    
    private final AmazonSimpleEmailService sesClient;
    
    @Override
    public void sendOrderConfirmation(Order order) {
        SendEmailRequest request = new SendEmailRequest()
            .withSource("orders@company.com")
            .withDestination(new Destination()
                .withToAddresses(order.getCustomerEmail()))
            .withMessage(new Message()
                .withSubject(new Content("Order Confirmation"))
                .withBody(new Body()
                    .withHtml(new Content(buildEmailContent(order)))));
        
        sesClient.sendEmail(request);
    }
    
    private String buildEmailContent(Order order) {
        return "";
    }
}
```

#### Spring Boot Configuration for DIP

```java
/**
 * Configuration to control which implementation is used
 */
@Configuration
public class AppConfiguration {
    
    @Bean
    @ConditionalOnProperty(name = "email.provider", havingValue = "sendgrid")
    public EmailService sendGridEmailService(SendGrid sendGridClient) {
        return new SendGridEmailService(sendGridClient);
    }
    
    @Bean
    @ConditionalOnProperty(name = "email.provider", havingValue = "aws-ses", matchIfMissing = true)
    public EmailService awsSesEmailService(AmazonSimpleEmailService sesClient) {
        return new AwsSesEmailService(sesClient);
    }
}

/**
 * application.properties
 * email.provider=aws-ses
 */
```

### 2.2 Gang of Four Design Patterns

#### 2.2.1 Creational Patterns

##### 2.2.1.1 Singleton Pattern

**Purpose:** Ensure a class has only one instance and provide a global access point to it.

**Spring Boot Implementation:** Spring beans are singletons by default.

```java
/**
 * Singleton using Spring (Recommended)
 */
@Component
public class ApplicationConfig {
    
    @Value("${app.name}")
    private String applicationName;
    
    @Value("${app.version}")
    private String applicationVersion;
    
    public String getApplicationInfo() {
        return applicationName + " v" + applicationVersion;
    }
}

/**
 * Manual Singleton (use only when Spring is not available)
 */
public class DatabaseConnection {
    
    private static volatile DatabaseConnection instance;
    private final Connection connection;
    
    private DatabaseConnection() {
        // Private constructor prevents instantiation
        this.connection = createConnection();
    }
    
    public static DatabaseConnection getInstance() {
        if (instance == null) {
            synchronized (DatabaseConnection.class) {
                if (instance == null) {
                    instance = new DatabaseConnection();
                }
            }
        }
        return instance;
    }
    
    private Connection createConnection() {
        // Create database connection
        return null;
    }
    
    public Connection getConnection() {
        return connection;
    }
}

/**
 * Usage in Spring
 */
@Service
@RequiredArgsConstructor
public class UserService {
    
    // Spring injects singleton instance
    private final ApplicationConfig config;
    
    public void logInfo() {
        log.info("Application: {}", config.getApplicationInfo());
    }
}
```

##### 2.2.1.2 Factory Pattern

**Purpose:** Define an interface for creating objects, but let subclasses decide which class to instantiate.

```java
/**
 * Product interface
 */
public interface Notification {
    void send(String recipient, String message);
}

/**
 * Concrete products
 */
@Service("emailNotification")
public class EmailNotification implements Notification {
    @Override
    public void send(String recipient, String message) {
        log.info("Sending email to {}: {}", recipient, message);
    }
}

@Service("smsNotification")
public class SmsNotification implements Notification {
    @Override
    public void send(String recipient, String message) {
        log.info("Sending SMS to {}: {}", recipient, message);
    }
}

@Service("pushNotification")
public class PushNotification implements Notification {
    @Override
    public void send(String recipient, String message) {
        log.info("Sending push notification to {}: {}", recipient, message);
    }
}

/**
 * Factory (Spring-based)
 */
@Service
public class NotificationFactory {
    
    private final Map<String, Notification> notificationMap;
    
    @Autowired
    public NotificationFactory(List<Notification> notifications) {
        this.notificationMap = notifications.stream()
            .collect(Collectors.toMap(
                n -> n.getClass().getSimpleName().toLowerCase().replace("notification", ""),
                Function.identity()
            ));
    }
    
    public Notification getNotification(String type) {
        Notification notification = notificationMap.get(type.toLowerCase());
        if (notification == null) {
            throw new IllegalArgumentException("Unknown notification type: " + type);
        }
        return notification;
    }
}

/**
 * Usage
 */
@Service
@RequiredArgsConstructor
public class NotificationService {
    
    private final NotificationFactory notificationFactory;
    
    public void sendNotification(String type, String recipient, String message) {
        Notification notification = notificationFactory.getNotification(type);
        notification.send(recipient, message);
    }
}
```

##### 2.2.1.3 Builder Pattern

**Purpose:** Separate the construction of a complex object from its representation.

```java
/**
 * Domain entity with builder
 */
@Entity
@Table(name = "orders")
@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Order {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private Long customerId;
    
    @Column(nullable = false)
    private String orderNumber;
    
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL)
    @Builder.Default
    private List<OrderItem> items = new ArrayList<>();
    
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private OrderStatus status = OrderStatus.PENDING;
    
    @Column(nullable = false)
    private BigDecimal totalAmount;
    
    @Column(name = "shipping_address")
    private String shippingAddress;
    
    @Column(name = "billing_address")
    private String billingAddress;
    
    @CreationTimestamp
    private Instant createdAt;
    
    @UpdateTimestamp
    private Instant updatedAt;
}

/**
 * Custom builder for complex object creation
 */
public class OrderBuilder {
    
    private Long customerId;
    private List<OrderItem> items = new ArrayList<>();
    private String shippingAddress;
    private String billingAddress;
    private String promoCode;
    
    public OrderBuilder forCustomer(Long customerId) {
        this.customerId = customerId;
        return this;
    }
    
    public OrderBuilder addItem(Long productId, int quantity, BigDecimal price) {
        OrderItem item = new OrderItem();
        item.setProductId(productId);
        item.setQuantity(quantity);
        item.setUnitPrice(price);
        item.setSubtotal(price.multiply(BigDecimal.valueOf(quantity)));
        this.items.add(item);
        return this;
    }
    
    public OrderBuilder withShippingAddress(String address) {
        this.shippingAddress = address;
        return this;
    }
    
    public OrderBuilder withBillingAddress(String address) {
        this.billingAddress = address;
        return this;
    }
    
    public OrderBuilder withPromoCode(String promoCode) {
        this.promoCode = promoCode;
        return this;
    }
    
    public Order build() {
        BigDecimal totalAmount = items.stream()
            .map(OrderItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        // Apply promo code discount
        if (promoCode != null) {
            totalAmount = applyDiscount(totalAmount, promoCode);
        }
        
        String orderNumber = generateOrderNumber();
        
        Order order = Order.builder()
            .customerId(customerId)
            .orderNumber(orderNumber)
            .items(items)
            .totalAmount(totalAmount)
            .shippingAddress(shippingAddress)
            .billingAddress(billingAddress != null ? billingAddress : shippingAddress)
            .status(OrderStatus.PENDING)
            .build();
        
        // Set back-reference for items
        items.forEach(item -> item.setOrder(order));
        
        return order;
    }
    
    private String generateOrderNumber() {
        return "ORD-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }
    
    private BigDecimal applyDiscount(BigDecimal amount, String promoCode) {
        // Apply discount logic
        return amount.multiply(BigDecimal.valueOf(0.9)); // 10% discount
    }
}

/**
 * Usage
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    
    public Order createOrder(CreateOrderRequest request) {
        OrderBuilder orderBuilder = new OrderBuilder()
            .forCustomer(request.getCustomerId())
            .withShippingAddress(request.getShippingAddress())
            .withBillingAddress(request.getBillingAddress());
        
        // Add items
        for (OrderItemRequest itemRequest : request.getItems()) {
            orderBuilder.addItem(
                itemRequest.getProductId(),
                itemRequest.getQuantity(),
                itemRequest.getPrice()
            );
        }
        
        // Apply promo code if provided
        if (request.getPromoCode() != null) {
            orderBuilder.withPromoCode(request.getPromoCode());
        }
        
        Order order = orderBuilder.build();
        return orderRepository.save(order);
    }
}
```

##### 2.2.1.4 Prototype Pattern

**Purpose:** Create new objects by copying an existing object (prototype).

```java
/**
 * Cloneable entity
 */
@Entity
@Table(name = "email_templates")
@Getter
@Setter
@NoArgsConstructor
public class EmailTemplate implements Cloneable {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String name;
    private String subject;
    private String body;
    private String category;
    
    @Override
    public EmailTemplate clone() {
        try {
            EmailTemplate cloned = (EmailTemplate) super.clone();
            cloned.setId(null);  // New entity should not have ID
            cloned.setName(this.name + " (Copy)");
            return cloned;
        } catch (CloneNotSupportedException e) {
            throw new RuntimeException("Failed to clone template", e);
        }
    }
}

/**
 * Prototype registry
 */
@Service
@RequiredArgsConstructor
public class EmailTemplateRegistry {
    
    private final EmailTemplateRepository templateRepository;
    private final Map<String, EmailTemplate> templateCache = new ConcurrentHashMap<>();
    
    @PostConstruct
    public void initialize() {
        // Load commonly used templates into cache
        templateRepository.findByCategoryIn(List.of("welcome", "order-confirmation"))
            .forEach(template -> templateCache.put(template.getName(), template));
    }
    
    public EmailTemplate getTemplate(String name) {
        EmailTemplate prototype = templateCache.get(name);
        if (prototype == null) {
            prototype = templateRepository.findByName(name)
                .orElseThrow(() -> new TemplateNotFoundException(name));
            templateCache.put(name, prototype);
        }
        // Return a clone to avoid modifying the prototype
        return prototype.clone();
    }
    
    public EmailTemplate createFromPrototype(String prototypeName, String newName) {
        EmailTemplate prototype = getTemplate(prototypeName);
        prototype.setName(newName);
        return templateRepository.save(prototype);
    }
}

/**
 * Usage
 */
@Service
@RequiredArgsConstructor
public class EmailService {
    
    private final EmailTemplateRegistry templateRegistry;
    private final JavaMailSender mailSender;
    
    public void sendWelcomeEmail(User user) {
        // Get a copy of the template
        EmailTemplate template = templateRegistry.getTemplate("welcome-email");
        
        // Customize the copy
        String personalizedBody = template.getBody()
            .replace("{{firstName}}", user.getFirstName())
            .replace("{{lastName}}", user.getLastName());
        
        // Send email with customized content
        sendEmail(user.getEmail(), template.getSubject(), personalizedBody);
    }
    
    private void sendEmail(String to, String subject, String body) {
        // Email sending implementation
    }
}
```

#### 2.2.2 Structural Patterns

##### 2.2.2.1 Adapter Pattern

**Purpose:** Convert the interface of a class into another interface clients expect.

```java
/**
 * Target interface (what client expects)
 */
public interface PaymentGateway {
    PaymentResult processPayment(PaymentRequest request);
    PaymentStatus checkStatus(String transactionId);
    void refund(String transactionId, BigDecimal amount);
}

/**
 * Adaptee (existing third-party service - Stripe)
 */
public class StripeClient {
    public StripeChargeResponse charge(StripeChargeRequest request) {
        // Stripe-specific implementation
        return new StripeChargeResponse();
    }
    
    public StripeCharge retrieve(String chargeId) {
        // Retrieve charge from Stripe
        return new StripeCharge();
    }
    
    public StripeRefund createRefund(String chargeId, long amount) {
        // Create refund in Stripe
        return new StripeRefund();
    }
}

/**
 * Adapter for Stripe
 */
@Service
@RequiredArgsConstructor
public class StripePaymentAdapter implements PaymentGateway {
    
    private final StripeClient stripeClient;
    
    @Override
    public PaymentResult processPayment(PaymentRequest request) {
        // Adapt our request to Stripe's format
        StripeChargeRequest stripeRequest = new StripeChargeRequest();
        stripeRequest.setAmount(request.getAmount().multiply(BigDecimal.valueOf(100)).longValue()); // Convert to cents
        stripeRequest.setCurrency(request.getCurrency());
        stripeRequest.setSource(request.getPaymentToken());
        stripeRequest.setDescription(request.getDescription());
        
        try {
            StripeChargeResponse response = stripeClient.charge(stripeRequest);
            
            // Adapt Stripe's response to our format
            return PaymentResult.builder()
                .success(true)
                .transactionId(response.getId())
                .amount(request.getAmount())
                .status(PaymentStatus.COMPLETED)
                .build();
                
        } catch (StripeException e) {
            return PaymentResult.builder()
                .success(false)
                .errorMessage(e.getMessage())
                .status(PaymentStatus.FAILED)
                .build();
        }
    }
    
    @Override
    public PaymentStatus checkStatus(String transactionId) {
        StripeCharge charge = stripeClient.retrieve(transactionId);
        
        // Adapt Stripe status to our enum
        return switch (charge.getStatus()) {
            case "succeeded" -> PaymentStatus.COMPLETED;
            case "pending" -> PaymentStatus.PENDING;
            case "failed" -> PaymentStatus.FAILED;
            default -> PaymentStatus.UNKNOWN;
        };
    }
    
    @Override
    public void refund(String transactionId, BigDecimal amount) {
        long amountInCents = amount.multiply(BigDecimal.valueOf(100)).longValue();
        stripeClient.createRefund(transactionId, amountInCents);
    }
}

/**
 * Adaptee (another third-party service - PayPal)
 */
public class PayPalClient {
    public PayPalPayment createPayment(PayPalPaymentRequest request) {
        return new PayPalPayment();
    }
    
    public PayPalPayment getPayment(String paymentId) {
        return new PayPalPayment();
    }
    
    public PayPalRefund refundPayment(String paymentId, PayPalRefundRequest request) {
        return new PayPalRefund();
    }
}

/**
 * Adapter for PayPal
 */
@Service
@RequiredArgsConstructor
public class PayPalPaymentAdapter implements PaymentGateway {
    
    private final PayPalClient payPalClient;
    
    @Override
    public PaymentResult processPayment(PaymentRequest request) {
        PayPalPaymentRequest payPalRequest = new PayPalPaymentRequest();
        payPalRequest.setAmount(request.getAmount().toString());
        payPalRequest.setCurrency(request.getCurrency());
        payPalRequest.setReturnUrl(request.getReturnUrl());
        payPalRequest.setCancelUrl(request.getCancelUrl());
        
        try {
            PayPalPayment payment = payPalClient.createPayment(payPalRequest);
            
            return PaymentResult.builder()
                .success(payment.getState().equals("approved"))
                .transactionId(payment.getId())
                .amount(request.getAmount())
                .status(mapPayPalStatus(payment.getState()))
                .build();
                
        } catch (PayPalException e) {
            return PaymentResult.builder()
                .success(false)
                .errorMessage(e.getMessage())
                .status(PaymentStatus.FAILED)
                .build();
        }
    }
    
    @Override
    public PaymentStatus checkStatus(String transactionId) {
        PayPalPayment payment = payPalClient.getPayment(transactionId);
        return mapPayPalStatus(payment.getState());
    }
    
    @Override
    public void refund(String transactionId, BigDecimal amount) {
        PayPalRefundRequest request = new PayPalRefundRequest();
        request.setAmount(amount.toString());
        payPalClient.refundPayment(transactionId, request);
    }
    
    private PaymentStatus mapPayPalStatus(String payPalStatus) {
        return switch (payPalStatus) {
            case "approved", "completed" -> PaymentStatus.COMPLETED;
            case "created", "pending" -> PaymentStatus.PENDING;
            case "failed", "cancelled" -> PaymentStatus.FAILED;
            default -> PaymentStatus.UNKNOWN;
        };
    }
}

/**
 * Client service - works with unified interface
 */
@Service
@RequiredArgsConstructor
public class PaymentService {
    
    @Qualifier("stripePaymentAdapter")
    private final PaymentGateway primaryGateway;
    
    @Qualifier("payPalPaymentAdapter")
    private final PaymentGateway fallbackGateway;
    
    public PaymentResult processPayment(PaymentRequest request) {
        try {
            return primaryGateway.processPayment(request);
        } catch (Exception e) {
            log.warn("Primary gateway failed, trying fallback", e);
            return fallbackGateway.processPayment(request);
        }
    }
}
```

##### 2.2.2.2 Decorator Pattern

**Purpose:** Attach additional responsibilities to an object dynamically.

```java
/**
 * Component interface
 */
public interface NotificationService {
    void send(String recipient, String message);
}

/**
 * Concrete component
 */
@Service("basicNotificationService")
public class BasicNotificationService implements NotificationService {
    
    @Override
    public void send(String recipient, String message) {
        log.info("Sending notification to {}: {}", recipient, message);
        // Basic sending logic
    }
}

/**
 * Base decorator
 */
@RequiredArgsConstructor
public abstract class NotificationDecorator implements NotificationService {
    protected final NotificationService wrappedService;
    
    @Override
    public void send(String recipient, String message) {
        wrappedService.send(recipient, message);
    }
}

/**
 * Logging decorator
 */
public class LoggingNotificationDecorator extends NotificationDecorator {
    
    public LoggingNotificationDecorator(NotificationService service) {
        super(service);
    }
    
    @Override
    public void send(String recipient, String message) {
        log.info("=== START Notification ===");
        log.info("Recipient: {}", recipient);
        log.info("Message length: {}", message.length());
        
        long startTime = System.currentTimeMillis();
        super.send(recipient, message);
        long endTime = System.currentTimeMillis();
        
        log.info("Time taken: {}ms", endTime - startTime);
        log.info("=== END Notification ===");
    }
}

/**
 * Encryption decorator
 */
public class EncryptionNotificationDecorator extends NotificationDecorator {
    
    private final EncryptionService encryptionService;
    
    public EncryptionNotificationDecorator(NotificationService service, 
                                          EncryptionService encryptionService) {
        super(service);
        this.encryptionService = encryptionService;
    }
    
    @Override
    public void send(String recipient, String message) {
        String encryptedMessage = encryptionService.encrypt(message);
        log.info("Message encrypted for recipient: {}", recipient);
        super.send(recipient, encryptedMessage);
    }
}

/**
 * Retry decorator
 */
public class RetryNotificationDecorator extends NotificationDecorator {
    
    private final int maxRetries;
    private final long retryDelay;
    
    public RetryNotificationDecorator(NotificationService service) {
        super(service);
        this.maxRetries = 3;
        this.retryDelay = 1000;
    }
    
    @Override
    public void send(String recipient, String message) {
        int attempt = 0;
        
        while (attempt < maxRetries) {
            try {
                super.send(recipient, message);
                return;  // Success, exit
            } catch (Exception e) {
                attempt++;
                if (attempt >= maxRetries) {
                    log.error("Failed to send notification after {} attempts", maxRetries);
                    throw e;
                }
                log.warn("Attempt {} failed, retrying in {}ms", attempt, retryDelay);
                sleep(retryDelay);
            }
        }
    }
    
    private void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}

/**
 * Configuration to build decorated service
 */
@Configuration
public class NotificationConfiguration {
    
    @Bean
    public NotificationService notificationService(
            @Qualifier("basicNotificationService") NotificationService basicService,
            EncryptionService encryptionService) {
        
        // Build decorator chain: Retry -> Encryption -> Logging -> Basic
        NotificationService service = basicService;
        service = new LoggingNotificationDecorator(service);
        service = new EncryptionNotificationDecorator(service, encryptionService);
        service = new RetryNotificationDecorator(service);
        
        return service;
    }
}
```

##### 2.2.2.3 Facade Pattern

**Purpose:** Provide a unified interface to a set of interfaces in a subsystem.

```java
/**
 * Complex subsystems
 */
@Service
@RequiredArgsConstructor
public class InventoryService {
    public boolean checkAvailability(Long productId, int quantity) {
        // Check inventory
        return true;
    }
    
    public void reserve(Long productId, int quantity) {
        // Reserve inventory
    }
    
    public void release(Long productId, int quantity) {
        // Release inventory
    }
}

@Service
@RequiredArgsConstructor
public class PaymentProcessorService {
    public String authorizePayment(Long customerId, BigDecimal amount) {
        // Authorize payment
        return "AUTH-123";
    }
    
    public void capturePayment(String authorizationId) {
        // Capture payment
    }
    
    public void voidPayment(String authorizationId) {
        // Void payment
    }
}

@Service
@RequiredArgsConstructor
public class ShippingService {
    public String createShipment(Order order) {
        // Create shipment
        return "SHIP-123";
    }
    
    public void cancelShipment(String shipmentId) {
        // Cancel shipment
    }
}

@Service
@RequiredArgsConstructor
public class NotificationService {
    public void sendOrderConfirmation(Order order) {
        // Send confirmation
    }
    
    public void sendOrderCancellation(Order order) {
        // Send cancellation
    }
}

/**
 * Facade - Simplified interface for complex order processing
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderFacade {
    
    private final OrderRepository orderRepository;
    private final InventoryService inventoryService;
    private final PaymentProcessorService paymentService;
    private final ShippingService shippingService;
    private final NotificationService notificationService;
    
    /**
     * Single method that coordinates all subsystems
     */
    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        log.info("Starting order placement for customer: {}", request.getCustomerId());
        
        try {
            // Step 1: Check inventory
            for (OrderItemRequest item : request.getItems()) {
                if (!inventoryService.checkAvailability(item.getProductId(), item.getQuantity())) {
                    throw new InsufficientInventoryException(item.getProductId());
                }
            }
            
            // Step 2: Reserve inventory
            for (OrderItemRequest item : request.getItems()) {
                inventoryService.reserve(item.getProductId(), item.getQuantity());
            }
            
            // Step 3: Create order
            Order order = createOrderFromRequest(request);
            order = orderRepository.save(order);
            
            // Step 4: Authorize payment
            String authorizationId = paymentService.authorizePayment(
                request.getCustomerId(), 
                order.getTotalAmount()
            );
            order.setPaymentAuthorizationId(authorizationId);
            
            // Step 5: Capture payment
            paymentService.capturePayment(authorizationId);
            order.setStatus(OrderStatus.PAID);
            
            // Step 6: Create shipment
            String shipmentId = shippingService.createShipment(order);
            order.setShipmentId(shipmentId);
            order.setStatus(OrderStatus.SHIPPED);
            
            // Step 7: Send confirmation
            notificationService.sendOrderConfirmation(order);
            
            orderRepository.save(order);
            log.info("Order placed successfully: {}", order.getId());
            
            return order;
            
        } catch (Exception e) {
            log.error("Failed to place order", e);
            rollbackOrder(request);
            throw new OrderProcessingException("Failed to place order", e);
        }
    }
    
    /**
     * Single method to cancel order
     */
    @Transactional
    public void cancelOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
        
        try {
            // Cancel shipment
            if (order.getShipmentId() != null) {
                shippingService.cancelShipment(order.getShipmentId());
            }
            
            // Refund payment
            if (order.getPaymentAuthorizationId() != null) {
                paymentService.voidPayment(order.getPaymentAuthorizationId());
            }
            
            // Release inventory
            for (OrderItem item : order.getItems()) {
                inventoryService.release(item.getProductId(), item.getQuantity());
            }
            
            // Update order status
            order.setStatus(OrderStatus.CANCELLED);
            orderRepository.save(order);
            
            // Send notification
            notificationService.sendOrderCancellation(order);
            
            log.info("Order cancelled successfully: {}", orderId);
            
        } catch (Exception e) {
            log.error("Failed to cancel order: {}", orderId, e);
            throw new OrderCancellationException("Failed to cancel order", e);
        }
    }
    
    private Order createOrderFromRequest(CreateOrderRequest request) {
        // Order creation logic
        return new Order();
    }
    
    private void rollbackOrder(CreateOrderRequest request) {
        // Rollback logic
        for (OrderItemRequest item : request.getItems()) {
            inventoryService.release(item.getProductId(), item.getQuantity());
        }
    }
}

/**
 * Controller uses facade - simple API
 */
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {
    
    private final OrderFacade orderFacade;
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<Order> placeOrder(@RequestBody @Valid CreateOrderRequest request) {
        // Client only needs to call one method
        Order order = orderFacade.placeOrder(request);
        return ResponseEntity.created(URI.create("/api/v1/orders/" + order.getId()))
            .body(order);
    }
    
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public ResponseEntity<Void> cancelOrder(@PathVariable Long id) {
        orderFacade.cancelOrder(id);
        return ResponseEntity.noContent().build();
    }
}
```

#### 2.2.3 Behavioral Patterns

##### 2.2.3.1 Strategy Pattern

**Purpose:** Define a family of algorithms, encapsulate each one, and make them interchangeable.

```java
/**
 * Strategy interface
 */
public interface PricingStrategy {
    BigDecimal calculatePrice(Order order);
    String getStrategyName();
}

/**
 * Regular pricing strategy
 */
@Service
public class RegularPricingStrategy implements PricingStrategy {
    
    @Override
    public BigDecimal calculatePrice(Order order) {
        return order.getItems().stream()
            .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
    
    @Override
    public String getStrategyName() {
        return "REGULAR";
    }
}

/**
 * Member discount strategy
 */
@Service
public class MemberPricingStrategy implements PricingStrategy {
    
    private static final BigDecimal DISCOUNT_RATE = BigDecimal.valueOf(0.10); // 10%
    
    @Override
    public BigDecimal calculatePrice(Order order) {
        BigDecimal regularPrice = order.getItems().stream()
            .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        BigDecimal discount = regularPrice.multiply(DISCOUNT_RATE);
        return regularPrice.subtract(discount);
    }
    
    @Override
    public String getStrategyName() {
        return "MEMBER";
    }
}

/**
 * VIP pricing strategy
 */
@Service
public class VipPricingStrategy implements PricingStrategy {
    
    private static final BigDecimal DISCOUNT_RATE = BigDecimal.valueOf(0.20); // 20%
    private static final BigDecimal FREE_SHIPPING_THRESHOLD = BigDecimal.valueOf(100);
    
    @Override
    public BigDecimal calculatePrice(Order order) {
        BigDecimal regularPrice = order.getItems().stream()
            .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        // Apply VIP discount
        BigDecimal discount = regularPrice.multiply(DISCOUNT_RATE);
        BigDecimal discountedPrice = regularPrice.subtract(discount);
        
        // Free shipping for orders over threshold
        if (discountedPrice.compareTo(FREE_SHIPPING_THRESHOLD) < 0) {
            discountedPrice = discountedPrice.add(order.getShippingCost());
        }
        
        return discountedPrice;
    }
    
    @Override
    public String getStrategyName() {
        return "VIP";
    }
}

/**
 * Black Friday strategy
 */
@Service
public class BlackFridayPricingStrategy implements PricingStrategy {
    
    private static final BigDecimal DISCOUNT_RATE = BigDecimal.valueOf(0.50); // 50% off
    
    @Override
    public BigDecimal calculatePrice(Order order) {
        BigDecimal regularPrice = order.getItems().stream()
            .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        BigDecimal discount = regularPrice.multiply(DISCOUNT_RATE);
        return regularPrice.subtract(discount);
    }
    
    @Override
    public String getStrategyName() {
        return "BLACK_FRIDAY";
    }
}

/**
 * Context - Order service that uses strategies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderPricingService {
    
    private final List<PricingStrategy> pricingStrategies;
    private final CustomerService customerService;
    
    public BigDecimal calculateOrderPrice(Order order) {
        // Determine which strategy to use
        PricingStrategy strategy = selectStrategy(order);
        
        BigDecimal price = strategy.calculatePrice(order);
        log.info("Calculated price using {} strategy: {}", strategy.getStrategyName(), price);
        
        return price;
    }
    
    private PricingStrategy selectStrategy(Order order) {
        Customer customer = customerService.findById(order.getCustomerId());
        
        // Strategy selection logic
        if (isBlackFridayPeriod()) {
            return getStrategyByName("BLACK_FRIDAY");
        } else if (customer.isVip()) {
            return getStrategyByName("VIP");
        } else if (customer.isMember()) {
            return getStrategyByName("MEMBER");
        } else {
            return getStrategyByName("REGULAR");
        }
    }
    
    private PricingStrategy getStrategyByName(String name) {
        return pricingStrategies.stream()
            .filter(strategy -> strategy.getStrategyName().equals(name))
            .findFirst()
            .orElseThrow(() -> new IllegalStateException("Strategy not found: " + name));
    }
    
    private boolean isBlackFridayPeriod() {
        LocalDate now = LocalDate.now();
        // Check if current date is in Black Friday period
        return now.getMonthValue() == 11 && now.getDayOfMonth() >= 25;
    }
}
```

#### 2.2.3.2 Observer Pattern

**Purpose:** Define a one-to-many dependency between objects so that when one object changes state, all its dependents are notified.

```java
/**
 * Event (Subject state change)
 */
@Getter
public class OrderPlacedEvent extends ApplicationEvent {
    private final Order order;
    private final Instant occurredAt;
    
    public OrderPlacedEvent(Object source, Order order) {
        super(source);
        this.order = order;
        this.occurredAt = Instant.now();
    }
}

/**
 * Observer 1: Inventory management
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class InventoryEventListener {
    
    private final InventoryService inventoryService;
    
    @EventListener
    @Async
    public void handleOrderPlaced(OrderPlacedEvent event) {
        log.info("Updating inventory for order: {}", event.getOrder().getId());
        
        event.getOrder().getItems().forEach(item -> {
            inventoryService.decreaseStock(item.getProductId(), item.getQuantity());
        });
    }
}

/**
 * Observer 2: Email notification
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class EmailEventListener {
    
    private final EmailService emailService;
    private final CustomerService customerService;
    
    @EventListener
    @Async
    public void handleOrderPlaced(OrderPlacedEvent event) {
        log.info("Sending confirmation email for order: {}", event.getOrder().getId());
        
        Customer customer = customerService.findById(event.getOrder().getCustomerId());
        emailService.sendOrderConfirmation(customer.getEmail(), event.getOrder());
    }
}

/**
 * Observer 3: Analytics tracking
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class AnalyticsEventListener {
    
    private final AnalyticsService analyticsService;
    
    @EventListener
    @Async
    public void handleOrderPlaced(OrderPlacedEvent event) {
        log.info("Tracking order for analytics: {}", event.getOrder().getId());
        
        analyticsService.trackOrderPlaced(event.getOrder());
    }
}

/**
 * Observer 4: Loyalty points
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class LoyaltyPointsEventListener {
    
    private final LoyaltyPointsService loyaltyPointsService;
    
    @EventListener
    @Async
    public void handleOrderPlaced(OrderPlacedEvent event) {
        log.info("Awarding loyalty points for order: {}", event.getOrder().getId());
        
        Order order = event.getOrder();
        int points = order.getTotalAmount().intValue() / 10; // 1 point per $10
        loyaltyPointsService.awardPoints(order.getCustomerId(), points);
    }
}

/**
 * Subject (Publisher)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;
    
    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        Order order = createOrder(request);
        order = orderRepository.save(order);
        
        // Notify all observers
        log.info("Publishing order placed event: {}", order.getId());
        eventPublisher.publishEvent(new OrderPlacedEvent(this, order));
        
        return order;
    }
    
    private Order createOrder(CreateOrderRequest request) {
        // Order creation logic
        return new Order();
    }
}
```

#### 2.2.3.3 Template Method Pattern

**Purpose:** Define the skeleton of an algorithm in a method, deferring some steps to subclasses.

```java
/**
 * Abstract template class
 */
public abstract class AbstractDataImporter {
    
    /**
     * Template method - defines the algorithm skeleton
     */
    public final ImportResult importData(InputStream inputStream) {
        log.info("Starting data import using {}", getClass().getSimpleName());
        
        try {
            // Step 1: Validate input
            validateInput(inputStream);
            
            // Step 2: Parse data (implemented by subclass)
            List<String[]> records = parseData(inputStream);
            
            // Step 3: Validate records (implemented by subclass)
            List<String[]> validRecords = validateRecords(records);
            
            // Step 4: Transform data (implemented by subclass)
            List<?> entities = transformRecords(validRecords);
            
            // Step 5: Save to database
            saveToDatabase(entities);
            
            // Step 6: Generate report
            ImportResult result = generateReport(records.size(), validRecords.size());
            
            // Step 7: Cleanup (hook method)
            cleanup();
            
            log.info("Data import completed successfully");
            return result;
            
        } catch (Exception e) {
            log.error("Data import failed", e);
            handleError(e);
            throw new ImportException("Import failed", e);
        }
    }
    
    // Common implementation
    protected void validateInput(InputStream inputStream) {
        if (inputStream == null) {
            throw new IllegalArgumentException("Input stream cannot be null");
        }
    }
    
    // Abstract methods - must be implemented by subclasses
    protected abstract List<String[]> parseData(InputStream inputStream);
    protected abstract List<String[]> validateRecords(List<String[]> records);
    protected abstract List<?> transformRecords(List<String[]> records);
    protected abstract void saveToDatabase(List<?> entities);
    
    // Common implementation
    protected ImportResult generateReport(int totalRecords, int validRecords) {
        return ImportResult.builder()
            .totalRecords(totalRecords)
            .successfulRecords(validRecords)
            .failedRecords(totalRecords - validRecords)
            .importedAt(Instant.now())
            .build();
    }
    
    // Hook methods - optional override
    protected void cleanup() {
        // Default: do nothing
    }
    
    protected void handleError(Exception e) {
        // Default: log error
        log.error("Error during import", e);
    }
}

/**
 * Concrete implementation - CSV Importer
 */
@Component
@RequiredArgsConstructor
public class CsvUserImporter extends AbstractDataImporter {
    
    private final UserRepository userRepository;
    private final UserValidator userValidator;
    
    @Override
    protected List<String[]> parseData(InputStream inputStream) {
        List<String[]> records = new ArrayList<>();
        
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
             CSVReader csvReader = new CSVReader(reader)) {
            
            String[] header = csvReader.readNext(); // Skip header
            String[] record;
            
            while ((record = csvReader.readNext()) != null) {
                records.add(record);
            }
            
        } catch (IOException e) {
            throw new ParseException("Failed to parse CSV", e);
        }
        
        return records;
    }
    
    @Override
    protected List<String[]> validateRecords(List<String[]> records) {
        return records.stream()
            .filter(record -> {
                try {
                    userValidator.validateImportRecord(record);
                    return true;
                } catch (ValidationException e) {
                    log.warn("Invalid record: {}", Arrays.toString(record), e);
                    return false;
                }
            })
            .collect(Collectors.toList());
    }
    
    @Override
    protected List<User> transformRecords(List<String[]> records) {
        return records.stream()
            .map(record -> User.builder()
                .email(record[0])
                .firstName(record[1])
                .lastName(record[2])
                .status(UserStatus.ACTIVE)
                .build())
            .collect(Collectors.toList());
    }
    
    @Override
    protected void saveToDatabase(List<?> entities) {
        @SuppressWarnings("unchecked")
        List<User> users = (List<User>) entities;
        userRepository.saveAll(users);
    }
    
    @Override
    protected void cleanup() {
        // CSV-specific cleanup
        log.info("CSV import cleanup completed");
    }
}

/**
 * Concrete implementation - Excel Importer
 */
@Component
@RequiredArgsConstructor
public class ExcelUserImporter extends AbstractDataImporter {
    
    private final UserRepository userRepository;
    private final UserValidator userValidator;
    private Workbook workbook;
    
    @Override
    protected List<String[]> parseData(InputStream inputStream) {
        List<String[]> records = new ArrayList<>();
        
        try {
            workbook = WorkbookFactory.create(inputStream);
            Sheet sheet = workbook.getSheetAt(0);
            
            // Skip header row
            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row != null) {
                    String[] record = new String[3];
                    record[0] = getCellValue(row.getCell(0)); // Email
                    record[1] = getCellValue(row.getCell(1)); // First name
                    record[2] = getCellValue(row.getCell(2)); // Last name
                    records.add(record);
                }
            }
            
        } catch (IOException e) {
            throw new ParseException("Failed to parse Excel", e);
        }
        
        return records;
    }
    
    @Override
    protected List<String[]> validateRecords(List<String[]> records) {
        return records.stream()
            .filter(record -> {
                try {
                    userValidator.validateImportRecord(record);
                    return true;
                } catch (ValidationException e) {
                    log.warn("Invalid record: {}", Arrays.toString(record), e);
                    return false;
                }
            })
            .collect(Collectors.toList());
    }
    
    @Override
    protected List<User> transformRecords(List<String[]> records) {
        return records.stream()
            .map(record -> User.builder()
                .email(record[0])
                .firstName(record[1])
                .lastName(record[2])
                .status(UserStatus.ACTIVE)
                .build())
            .collect(Collectors.toList());
    }
    
    @Override
    protected void saveToDatabase(List<?> entities) {
        @SuppressWarnings("unchecked")
        List<User> users = (List<User>) entities;
        userRepository.saveAll(users);
    }
    
    @Override
    protected void cleanup() {
        // Close Excel workbook
        if (workbook != null) {
            try {
                workbook.close();
                log.info("Excel workbook closed");
            } catch (IOException e) {
                log.error("Failed to close workbook", e);
            }
        }
    }
    
    private String getCellValue(Cell cell) {
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> "";
        };
    }
    
    @Override
    protected void handleError(Exception e) {
        super.handleError(e);
        // Excel-specific error handling
        cleanup(); // Ensure workbook is closed on error
    }
}
```

#### 2.2.3.4 Chain of Responsibility Pattern

**Purpose:** Pass a request along a chain of handlers. Each handler decides either to process the request or to pass it to the next handler in the chain.

```java
/**
 * Handler interface
 */
public interface ValidationHandler {
    boolean validate(Order order);
    void setNext(ValidationHandler next);
}

/**
 * Abstract base handler
 */
public abstract class AbstractValidationHandler implements ValidationHandler {
    
    protected ValidationHandler next;
    
    @Override
    public void setNext(ValidationHandler next) {
        this.next = next;
    }
    
    @Override
    public boolean validate(Order order) {
        boolean isValid = doValidate(order);
        
        if (isValid && next != null) {
            return next.validate(order);
        }
        
        return isValid;
    }
    
    protected abstract boolean doValidate(Order order);
}

/**
 * Handler 1: Customer validation
 */
@Component
public class CustomerValidationHandler extends AbstractValidationHandler {
    
    @Autowired
    private CustomerService customerService;
    
    @Override
    protected boolean doValidate(Order order) {
        Customer customer = customerService.findById(order.getCustomerId());
        
        if (!customer.isActive()) {
            throw new ValidationException("Customer account is not active");
        }
        
        if (customer.isBlocked()) {
            throw new ValidationException("Customer account is blocked");
        }
        
        log.info("Customer validation passed for order: {}", order.getId());
        return true;
    }
}

/**
 * Handler 2: Inventory validation
 */
@Component
public class InventoryValidationHandler extends AbstractValidationHandler {
    
    @Autowired
    private InventoryService inventoryService;
    
    @Override
    protected boolean doValidate(Order order) {
        for (OrderItem item : order.getItems()) {
            if (!inventoryService.hasStock(item.getProductId(), item.getQuantity())) {
                throw new ValidationException(
                    String.format("Insufficient stock for product %d", item.getProductId())
                );
            }
        }
        
        log.info("Inventory validation passed for order: {}", order.getId());
        return true;
    }
}

/**
 * Handler 3: Payment validation
 */
@Component
public class PaymentValidationHandler extends AbstractValidationHandler {
    
    @Autowired
    private PaymentService paymentService;
    
    @Override
    protected boolean doValidate(Order order) {
        if (order.getPaymentMethod() == null) {
            throw new ValidationException("Payment method is required");
        }
        
        if (!paymentService.isValidPaymentMethod(order.getPaymentMethod())) {
            throw new ValidationException("Invalid payment method");
        }
        
        // Check if customer has sufficient credit
        if (order.getPaymentMethod().equals("CREDIT")) {
            BigDecimal availableCredit = paymentService.getAvailableCredit(order.getCustomerId());
            if (availableCredit.compareTo(order.getTotalAmount()) < 0) {
                throw new ValidationException("Insufficient credit");
            }
        }
        
        log.info("Payment validation passed for order: {}", order.getId());
        return true;
    }
}

/**
 * Handler 4: Shipping validation
 */
@Component
public class ShippingValidationHandler extends AbstractValidationHandler {
    
    @Autowired
    private ShippingService shippingService;
    
    @Override
    protected boolean doValidate(Order order) {
        if (order.getShippingAddress() == null) {
            throw new ValidationException("Shipping address is required");
        }
        
        if (!shippingService.canShipToAddress(order.getShippingAddress())) {
            throw new ValidationException("Cannot ship to the specified address");
        }
        
        log.info("Shipping validation passed for order: {}", order.getId());
        return true;
    }
}

/**
 * Handler 5: Fraud detection
 */
@Component
public class FraudDetectionHandler extends AbstractValidationHandler {
    
    @Autowired
    private FraudDetectionService fraudService;
    
    @Override
    protected boolean doValidate(Order order) {
        FraudCheckResult result = fraudService.checkOrder(order);
        
        if (result.getRiskLevel() == RiskLevel.HIGH) {
            throw new ValidationException("Order flagged for fraud: " + result.getReason());
        }
        
        if (result.getRiskLevel() == RiskLevel.MEDIUM) {
            log.warn("Order has medium fraud risk: {}", order.getId());
            // Could implement additional verification here
        }
        
        log.info("Fraud detection passed for order: {}", order.getId());
        return true;
    }
}

/**
 * Chain configurator
 */
@Configuration
public class ValidationChainConfiguration {
    
    @Bean
    public ValidationHandler orderValidationChain(
            CustomerValidationHandler customerHandler,
            InventoryValidationHandler inventoryHandler,
            PaymentValidationHandler paymentHandler,
            ShippingValidationHandler shippingHandler,
            FraudDetectionHandler fraudHandler) {
        
        // Build the chain: Customer -> Inventory -> Payment -> Shipping -> Fraud
        customerHandler.setNext(inventoryHandler);
        inventoryHandler.setNext(paymentHandler);
        paymentHandler.setNext(shippingHandler);
        shippingHandler.setNext(fraudHandler);
        
        return customerHandler;  // Return the first handler
    }
}

/**
 * Service using the chain
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderValidationService {
    
    private final ValidationHandler validationChain;
    
    public boolean validateOrder(Order order) {
        try {
            return validationChain.validate(order);
        } catch (ValidationException e) {
            log.error("Order validation failed: {}", e.getMessage());
            throw e;
        }
    }
}

/**
 * Order service using validation chain
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final OrderValidationService validationService;
    
    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        Order order = createOrderFromRequest(request);
        
        // Validate using chain of responsibility
        validationService.validateOrder(order);
        
        // If validation passes, save the order
        return orderRepository.save(order);
    }
    
    private Order createOrderFromRequest(CreateOrderRequest request) {
        // Order creation logic
        return new Order();
    }
}
```

### 2.3 API Design Best Practices

#### 2.3.1 RESTful Resource Naming

```java
/**
 * Resource Naming Conventions
 */
public class ResourceNamingRules {
    
    // ✅ Use nouns, not verbs
    // GET    /api/v1/users
    // GET    /api/v1/users/{id}
    // POST   /api/v1/users
    // PUT    /api/v1/users/{id}
    // DELETE /api/v1/users/{id}
    
    // ❌ Don't use verbs in URLs
    // POST   /api/v1/createUser
    // GET    /api/v1/getUser/{id}
    // POST   /api/v1/deleteUser/{id}
    
    // ✅ Use plural nouns for collections
    // GET /api/v1/orders
    // GET /api/v1/products
    
    // ❌ Don't mix singular and plural
    // GET /api/v1/order
    // GET /api/v1/products
    
    // ✅ Use hierarchy for relationships
    // GET /api/v1/users/{userId}/orders
    // GET /api/v1/orders/{orderId}/items
    
    // ✅ Use query parameters for filtering, sorting, pagination
    // GET /api/v1/users?status=active&sort=createdAt,desc&page=0&size=20
    
    // ✅ Use hyphens for multi-word resources (kebab-case)
    // GET /api/v1/order-items
    // GET /api/v1/payment-methods
    
    // ❌ Don't use underscores or camelCase in URLs
    // GET /api/v1/order_items
    // GET /api/v1/paymentMethods
}
```

#### 2.3.2 HTTP Methods and Status Codes

```java
/**
 * Proper HTTP method usage
 */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {
    
    private final UserService userService;
    
    /**
     * GET - Retrieve resource(s)
     * Status: 200 OK (found), 404 NOT FOUND (not found)
     */
    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUser(@PathVariable Long id) {
        return userService.findById(id)
            .map(user -> ResponseEntity.ok(userMapper.toResponse(user)))
            .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * POST - Create new resource
     * Status: 201 CREATED (success), 400 BAD REQUEST (validation error)
     */
    @PostMapping
    public ResponseEntity<UserResponse> createUser(@RequestBody @Valid CreateUserRequest request) {
        User user = userService.createUser(request);
        return ResponseEntity
            .created(URI.create("/api/v1/users/" + user.getId()))
            .body(userMapper.toResponse(user));
    }
    
    /**
     * PUT - Full update of existing resource
     * Status: 200 OK (success), 404 NOT FOUND (not found)
     */
    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> updateUser(
            @PathVariable Long id,
            @RequestBody @Valid UpdateUserRequest request) {
        User user = userService.updateUser(id, request);
        return ResponseEntity.ok(userMapper.toResponse(user));
    }
    
    /**
     * PATCH - Partial update of existing resource
     * Status: 200 OK (success), 404 NOT FOUND (not found)
     */
    @PatchMapping("/{id}")
    public ResponseEntity<UserResponse> patchUser(
            @PathVariable Long id,
            @RequestBody Map<String, Object> updates) {
        User user = userService.partialUpdate(id, updates);
        return ResponseEntity.ok(userMapper.toResponse(user));
    }
    
    /**
     * DELETE - Remove resource
     * Status: 204 NO CONTENT (success), 404 NOT FOUND (not found)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        userService.deleteUser(id);
        return ResponseEntity.noContent().build();
    }
    
    /**
     * GET - List resources with pagination
     * Status: 200 OK
     */
    @GetMapping
    public ResponseEntity<Page<UserResponse>> listUsers(
            @RequestParam(required = false) UserStatus status,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) 
            Pageable pageable) {
        Page<User> users = userService.findAll(status, pageable);
        return ResponseEntity.ok(users.map(userMapper::toResponse));
    }
}
```

#### 2.3.3 API Versioning

```java
/**
 * Option 1: URI versioning (Recommended)
 */
@RestController
@RequestMapping("/api/v1/users")
public class UserV1Controller {
    // Version 1 implementation
}

@RestController
@RequestMapping("/api/v2/users")
public class UserV2Controller {
    // Version 2 implementation with breaking changes
}

/**
 * Option 2: Header versioning
 */
@RestController
@RequestMapping("/api/users")
public class UserController {
    
    @GetMapping(headers = "API-Version=1")
    public ResponseEntity<UserV1Response> getUserV1(@PathVariable Long id) {
        // Version 1 logic
        return ResponseEntity.ok(new UserV1Response());
    }
    
    @GetMapping(headers = "API-Version=2")
    public ResponseEntity<UserV2Response> getUserV2(@PathVariable Long id) {
        // Version 2 logic
        return ResponseEntity.ok(new UserV2Response());
    }
}

/**
 * Option 3: Content negotiation (Accept header)
 */
@RestController
@RequestMapping("/api/users")
public class UserController {
    
    @GetMapping(produces = "application/vnd.company.v1+json")
    public ResponseEntity<UserV1Response> getUserV1(@PathVariable Long id) {
        return ResponseEntity.ok(new UserV1Response());
    }
    
    @GetMapping(produces = "application/vnd.company.v2+json")
    public ResponseEntity<UserV2Response> getUserV2(@PathVariable Long id) {
        return ResponseEntity.ok(new UserV2Response());
    }
}
```

#### 2.3.4 Error Handling

```java
/**
 * Standard error response format
 */
@Getter
@Builder
public class ErrorResponse {
    private Instant timestamp;
    private int status;
    private String error;
    private String message;
    private String path;
    private List<ValidationError> validationErrors;
}

@Getter
@AllArgsConstructor
public class ValidationError {
    private String field;
    private String message;
    private Object rejectedValue;
}

/**
 * Global exception handler
 */
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {
    
    /**
     * Handle validation errors (400 BAD REQUEST)
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleValidationException(
            MethodArgumentNotValidException ex,
            HttpServletRequest request) {
        
        List<ValidationError> validationErrors = ex.getBindingResult()
            .getFieldErrors()
            .stream()
            .map(error -> new ValidationError(
                error.getField(),
                error.getDefaultMessage(),
                error.getRejectedValue()
            ))
            .collect(Collectors.toList());
        
        return ErrorResponse.builder()
            .timestamp(Instant.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error("Validation Failed")
            .message("Request validation failed")
            .path(request.getRequestURI())
            .validationErrors(validationErrors)
            .build();
    }
    
    /**
     * Handle resource not found (404 NOT FOUND)
     */
    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFoundException(
            ResourceNotFoundException ex,
            HttpServletRequest request) {
        
        return ErrorResponse.builder()
            .timestamp(Instant.now())
            .status(HttpStatus.NOT_FOUND.value())
            .error("Not Found")
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .build();
    }
    
    /**
     * Handle business logic errors (422 UNPROCESSABLE ENTITY)
     */
    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.UNPROCESSABLE_ENTITY)
    public ErrorResponse handleBusinessException(
            BusinessException ex,
            HttpServletRequest request) {
        
        return ErrorResponse.builder()
            .timestamp(Instant.now())
            .status(HttpStatus.UNPROCESSABLE_ENTITY.value())
            .error("Business Rule Violation")
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .build();
    }
    
    /**
     * Handle general exceptions (500 INTERNAL SERVER ERROR)
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResponse handleGeneralException(
            Exception ex,
            HttpServletRequest request) {
        
        log.error("Unexpected error occurred", ex);
        
        return ErrorResponse.builder()
            .timestamp(Instant.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error("Internal Server Error")
            .message("An unexpected error occurred")
            .path(request.getRequestURI())
            .build();
    }
}
```

#### 2.3.5 Pagination and Filtering

```java
/**
 * Pagination and filtering best practices
 */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {
    
    private final UserService userService;
    
    /**
     * List with pagination, filtering, and sorting
     */
    @GetMapping
    public ResponseEntity<Page<UserResponse>> listUsers(
            // Filtering
            @RequestParam(required = false) String search,
            @RequestParam(required = false) UserStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) 
            LocalDate createdAfter,
            
            // Pagination and sorting
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) 
            Pageable pageable) {
        
        UserSearchCriteria criteria = UserSearchCriteria.builder()
            .search(search)
            .status(status)
            .createdAfter(createdAfter)
            .build();
        
        Page<User> users = userService.findAll(criteria, pageable);
        Page<UserResponse> response = users.map(userMapper::toResponse);
        
        // Add custom headers
        HttpHeaders headers = new HttpHeaders();
        headers.add("X-Total-Count", String.valueOf(response.getTotalElements()));
        headers.add("X-Total-Pages", String.valueOf(response.getTotalPages()));
        
        return ResponseEntity.ok()
            .headers(headers)
            .body(response);
    }
}

/**
 * Service with specification pattern for dynamic filtering
 */
@Service
@RequiredArgsConstructor
public class UserService {
    
    private final UserRepository userRepository;
    
    public Page<User> findAll(UserSearchCriteria criteria, Pageable pageable) {
        Specification<User> spec = UserSpecifications.withCriteria(criteria);
        return userRepository.findAll(spec, pageable);
    }
}

/**
 * Specification builder for dynamic queries
 */
public class UserSpecifications {
    
    public static Specification<User> withCriteria(UserSearchCriteria criteria) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            
            // Search filter (email or name)
            if (criteria.getSearch() != null) {
                String searchPattern = "%" + criteria.getSearch().toLowerCase() + "%";
                Predicate emailPredicate = cb.like(cb.lower(root.get("email")), searchPattern);
                Predicate firstNamePredicate = cb.like(cb.lower(root.get("firstName")), searchPattern);
                Predicate lastNamePredicate = cb.like(cb.lower(root.get("lastName")), searchPattern);
                predicates.add(cb.or(emailPredicate, firstNamePredicate, lastNamePredicate));
            }
            
            // Status filter
            if (criteria.getStatus() != null) {
                predicates.add(cb.equal(root.get("status"), criteria.getStatus()));
            }
            
            // Date filter
            if (criteria.getCreatedAfter() != null) {
                predicates.add(cb.greaterThanOrEqualTo(
                    root.get("createdAt"), 
                    criteria.getCreatedAfter().atStartOfDay().toInstant(ZoneOffset.UTC)
                ));
            }
            
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}
```

#### 2.3.6 Security Best Practices

##### 2.3.6.1 Authentication & Authorization

**JWT Token-Based Authentication:**

```java
/**
 * Security Configuration
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfiguration {
    
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter) 
            throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .sessionManagement(session -> 
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**", "/api/v1/public/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/v1/orders").hasAnyRole("USER", "ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/v1/orders/**").authenticated()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(new CustomAuthenticationEntryPoint())
                .accessDeniedHandler(new CustomAccessDeniedHandler())
            )
            .build();
    }
    
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(List.of("https://app.example.com"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        configuration.setExposedHeaders(List.of("X-Total-Count", "X-Total-Pages"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", configuration);
        return source;
    }
    
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
    
    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}

/**
 * JWT Authentication Filter
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private final JwtTokenProvider jwtTokenProvider;
    private final UserDetailsService userDetailsService;
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        try {
            String jwt = extractJwtFromRequest(request);
            
            if (jwt != null && jwtTokenProvider.validateToken(jwt)) {
                String username = jwtTokenProvider.getUsernameFromToken(jwt);
                
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                UsernamePasswordAuthenticationToken authentication = 
                    new UsernamePasswordAuthenticationToken(
                        userDetails, 
                        null, 
                        userDetails.getAuthorities()
                    );
                authentication.setDetails(new WebAuthenticationDetailsSource()
                    .buildDetails(request));
                
                SecurityContextHolder.getContext().setAuthentication(authentication);
                log.debug("User {} authenticated successfully", username);
            }
        } catch (Exception e) {
            log.error("Cannot set user authentication", e);
        }
        
        filterChain.doFilter(request, response);
    }
    
    private String extractJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}

/**
 * JWT Token Provider
 */
@Component
@Slf4j
public class JwtTokenProvider {
    
    @Value("${jwt.secret}")
    private String jwtSecret;
    
    @Value("${jwt.expiration:86400000}") // 24 hours default
    private long jwtExpirationMs;
    
    public String generateToken(Authentication authentication) {
        UserDetails userPrincipal = (UserDetails) authentication.getPrincipal();
        
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + jwtExpirationMs);
        
        Map<String, Object> claims = new HashMap<>();
        claims.put("roles", userPrincipal.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .collect(Collectors.toList()));
        
        return Jwts.builder()
            .setSubject(userPrincipal.getUsername())
            .addClaims(claims)
            .setIssuedAt(now)
            .setExpiryDate(expiryDate)
            .signWith(SignatureAlgorithm.HS512, jwtSecret)
            .compact();
    }
    
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parser()
            .setSigningKey(jwtSecret)
            .parseClaimsJws(token)
            .getBody();
        
        return claims.getSubject();
    }
    
    public boolean validateToken(String authToken) {
        try {
            Jwts.parser().setSigningKey(jwtSecret).parseClaimsJws(authToken);
            return true;
        } catch (SignatureException e) {
            log.error("Invalid JWT signature");
        } catch (MalformedJwtException e) {
            log.error("Invalid JWT token");
        } catch (ExpiredJwtException e) {
            log.error("Expired JWT token");
        } catch (UnsupportedJwtException e) {
            log.error("Unsupported JWT token");
        } catch (IllegalArgumentException e) {
            log.error("JWT claims string is empty");
        }
        return false;
    }
}

/**
 * Method-level security with @PreAuthorize
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    
    @PreAuthorize("hasRole('USER')")
    public Order createOrder(CreateOrderRequest request) {
        // Only users with USER role can create orders
        return orderRepository.save(new Order());
    }
    
    @PreAuthorize("hasRole('ADMIN') or @orderSecurityService.isOrderOwner(#orderId, principal.username)")
    public Order getOrder(Long orderId) {
        // Admin or order owner can view order
        return orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
    }
    
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteOrder(Long orderId) {
        // Only admin can delete orders
        orderRepository.deleteById(orderId);
    }
}

/**
 * Custom security expressions
 */
@Service
public class OrderSecurityService {
    
    @Autowired
    private OrderRepository orderRepository;
    
    public boolean isOrderOwner(Long orderId, String username) {
        return orderRepository.findById(orderId)
            .map(order -> order.getCustomer().getUsername().equals(username))
            .orElse(false);
    }
}
```

##### 2.3.6.2 Input Validation & Sanitization

**Bean Validation with Custom Validators:**

```java
/**
 * DTO with validation annotations
 */
@Getter
@Setter
public class CreateUserRequest {
    
    @NotBlank(message = "Email is required")
    @Email(message = "Email must be valid")
    @Size(max = 100, message = "Email must not exceed 100 characters")
    private String email;
    
    @NotBlank(message = "Password is required")
    @Size(min = 8, max = 100, message = "Password must be 8-100 characters")
    @Pattern(
        regexp = "^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=]).*$",
        message = "Password must contain digit, lowercase, uppercase, and special character"
    )
    private String password;
    
    @NotBlank(message = "First name is required")
    @Size(min = 2, max = 50, message = "First name must be 2-50 characters")
    @Pattern(regexp = "^[a-zA-Z\\s'-]+$", message = "First name contains invalid characters")
    private String firstName;
    
    @NotBlank(message = "Last name is required")
    @Size(min = 2, max = 50, message = "Last name must be 2-50 characters")
    @Pattern(regexp = "^[a-zA-Z\\s'-]+$", message = "Last name contains invalid characters")
    private String lastName;
    
    @Past(message = "Birth date must be in the past")
    private LocalDate birthDate;
    
    @ValidPhoneNumber // Custom validator
    private String phoneNumber;
    
    @SafeHtml // Prevents XSS attacks
    private String bio;
}

/**
 * Custom phone number validator
 */
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface ValidPhoneNumber {
    String message() default "Invalid phone number format";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

@Component
public class PhoneNumberValidator implements ConstraintValidator<ValidPhoneNumber, String> {
    
    private static final Pattern PHONE_PATTERN = 
        Pattern.compile("^[+]?[(]?[0-9]{1,4}[)]?[-\\s./0-9]*$");
    
    @Override
    public boolean isValid(String phoneNumber, ConstraintValidatorContext context) {
        if (phoneNumber == null || phoneNumber.isEmpty()) {
            return true; // Use @NotNull for required fields
        }
        
        // Remove common formatting characters
        String cleaned = phoneNumber.replaceAll("[()\\s.-]", "");
        
        // Check length and pattern
        return cleaned.length() >= 10 && cleaned.length() <= 15
            && PHONE_PATTERN.matcher(phoneNumber).matches();
    }
}

/**
 * Input sanitization service
 */
@Service
public class InputSanitizationService {
    
    private final Policy htmlPolicy;
    
    public InputSanitizationService() {
        // Define allowed HTML tags and attributes
        this.htmlPolicy = new HtmlPolicyBuilder()
            .allowElements("p", "br", "strong", "em", "u")
            .allowAttributes("class").onElements("p")
            .toFactory();
    }
    
    /**
     * Sanitize HTML input to prevent XSS
     */
    public String sanitizeHtml(String input) {
        if (input == null) {
            return null;
        }
        return htmlPolicy.sanitize(input);
    }
    
    /**
     * Sanitize SQL-like input (but use parameterized queries instead!)
     */
    public String escapeSqlLikePattern(String input) {
        if (input == null) {
            return null;
        }
        // Escape SQL LIKE special characters
        return input.replace("\\", "\\\\")
            .replace("%", "\\%")
            .replace("_", "\\_");
    }
    
    /**
     * Remove potentially dangerous characters
     */
    public String sanitizeFilename(String filename) {
        if (filename == null) {
            return null;
        }
        // Remove path traversal attempts and dangerous characters
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_")
            .replaceAll("\\.{2,}", ".");
    }
}

/**
 * Controller with validation
 */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Validated
public class UserController {
    
    private final UserService userService;
    private final InputSanitizationService sanitizationService;
    
    @PostMapping
    public ResponseEntity<UserResponse> createUser(
            @RequestBody @Valid CreateUserRequest request) {
        
        // Additional sanitization for user-generated content
        if (request.getBio() != null) {
            String sanitizedBio = sanitizationService.sanitizeHtml(request.getBio());
            request.setBio(sanitizedBio);
        }
        
        User user = userService.createUser(request);
        return ResponseEntity.created(URI.create("/api/v1/users/" + user.getId()))
            .body(toResponse(user));
    }
    
    @GetMapping("/search")
    public ResponseEntity<List<UserResponse>> searchUsers(
            @RequestParam @Size(min = 2, max = 100) String query) {
        
        // Sanitize search query
        String sanitizedQuery = sanitizationService.escapeSqlLikePattern(query);
        
        List<User> users = userService.search(sanitizedQuery);
        return ResponseEntity.ok(users.stream()
            .map(this::toResponse)
            .collect(Collectors.toList()));
    }
}
```

##### 2.3.6.3 SQL Injection Prevention

**Always use parameterized queries:**

```java
/**
 * ✅ CORRECT: Using JPA with named parameters
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    // Named parameters prevent SQL injection
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.status = :status")
    Optional<User> findByEmailAndStatus(
        @Param("email") String email, 
        @Param("status") UserStatus status
    );
    
    // Spring Data JPA method names are safe
    List<User> findByFirstNameContainingIgnoreCase(String firstName);
    
    // JPQL with positional parameters
    @Query("SELECT u FROM User u WHERE u.createdAt > ?1 ORDER BY u.createdAt DESC")
    List<User> findRecentUsers(Instant since);
}

/**
 * ✅ CORRECT: Using JdbcTemplate with parameterized queries
 */
@Repository
@RequiredArgsConstructor
public class UserRepositoryImpl {
    
    private final JdbcTemplate jdbcTemplate;
    
    public List<User> searchUsers(String email, UserStatus status) {
        String sql = """
            SELECT id, email, first_name, last_name, status
            FROM users
            WHERE email LIKE ? AND status = ?
            ORDER BY created_at DESC
            """;
        
        // Question marks are placeholders - JDBC safely escapes values
        return jdbcTemplate.query(
            sql,
            new Object[]{"%" + email + "%", status.name()},
            (rs, rowNum) -> User.builder()
                .id(rs.getLong("id"))
                .email(rs.getString("email"))
                .firstName(rs.getString("first_name"))
                .lastName(rs.getString("last_name"))
                .status(UserStatus.valueOf(rs.getString("status")))
                .build()
        );
    }
    
    public int updateUserStatus(Long userId, UserStatus newStatus) {
        String sql = "UPDATE users SET status = ?, updated_at = ? WHERE id = ?";
        
        return jdbcTemplate.update(
            sql,
            newStatus.name(),
            Instant.now(),
            userId
        );
    }
}

/**
 * ❌ WRONG: String concatenation (vulnerable to SQL injection)
 */
@Repository
public class VulnerableUserRepository {
    
    @PersistenceContext
    private EntityManager entityManager;
    
    // NEVER DO THIS - SQL INJECTION VULNERABILITY!
    public List<User> searchUsersUnsafe(String email) {
        String sql = "SELECT u FROM User u WHERE u.email LIKE '" + email + "'";
        return entityManager.createQuery(sql, User.class).getResultList();
        // If email = "' OR '1'='1", this returns all users!
    }
}

/**
 * ✅ CORRECT: Criteria API for dynamic queries
 */
@Repository
@RequiredArgsConstructor
public class UserSearchRepository {
    
    @PersistenceContext
    private EntityManager entityManager;
    
    public List<User> searchUsers(UserSearchCriteria criteria) {
        CriteriaBuilder cb = entityManager.getCriteriaBuilder();
        CriteriaQuery<User> query = cb.createQuery(User.class);
        Root<User> user = query.from(User.class);
        
        List<Predicate> predicates = new ArrayList<>();
        
        // Safe: Criteria API uses parameterized queries
        if (criteria.getEmail() != null) {
            predicates.add(cb.like(
                cb.lower(user.get("email")),
                "%" + criteria.getEmail().toLowerCase() + "%"
            ));
        }
        
        if (criteria.getStatus() != null) {
            predicates.add(cb.equal(user.get("status"), criteria.getStatus()));
        }
        
        if (criteria.getCreatedAfter() != null) {
            predicates.add(cb.greaterThanOrEqualTo(
                user.get("createdAt"), 
                criteria.getCreatedAfter()
            ));
        }
        
        query.where(cb.and(predicates.toArray(new Predicate[0])));
        query.orderBy(cb.desc(user.get("createdAt")));
        
        return entityManager.createQuery(query).getResultList();
    }
}
```

##### 2.3.6.4 Security Headers

**Add security headers to protect against common attacks:**

```java
/**
 * Security headers configuration
 */
@Configuration
public class SecurityHeadersConfiguration {
    
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .headers(headers -> headers
                // Prevent clickjacking attacks
                .frameOptions(frame -> frame.deny())
                
                // Prevent MIME type sniffing
                .contentTypeOptions(contentType -> contentType.disable())
                
                // Enable XSS protection
                .xssProtection(xss -> xss
                    .headerValue(XXssProtectionHeaderWriter.HeaderValue.ENABLED_MODE_BLOCK)
                )
                
                // Enforce HTTPS
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true)
                    .maxAgeInSeconds(31536000) // 1 year
                )
                
                // Content Security Policy
                .contentSecurityPolicy(csp -> csp
                    .policyDirectives("" +
                        "default-src 'self'; " +
                        "script-src 'self' 'unsafe-inline' https://cdn.example.com; " +
                        "style-src 'self' 'unsafe-inline'; " +
                        "img-src 'self' data: https:; " +
                        "font-src 'self' data:; " +
                        "connect-src 'self' https://api.example.com; " +
                        "frame-ancestors 'none';"
                    )
                )
                
                // Referrer Policy
                .referrerPolicy(referrer -> referrer
                    .policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN)
                )
                
                // Permissions Policy (formerly Feature Policy)
                .permissionsPolicy(permissions -> permissions
                    .policy("" +
                        "camera=(), " +
                        "microphone=(), " +
                        "geolocation=(self), " +
                        "payment=()"
                    )
                )
            )
            .build();
    }
}

/**
 * Custom security headers filter for additional control
 */
@Component
public class CustomSecurityHeadersFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        // Add custom security headers
        response.setHeader("X-Content-Type-Options", "nosniff");
        response.setHeader("X-Frame-Options", "DENY");
        response.setHeader("X-XSS-Protection", "1; mode=block");
        response.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        response.setHeader("Pragma", "no-cache");
        response.setHeader("Expires", "0");
        
        // Remove server information
        response.setHeader("Server", "");
        
        filterChain.doFilter(request, response);
    }
}
```

##### 2.3.6.5 Rate Limiting

**Implement rate limiting to prevent abuse:**

```java
/**
 * Rate limiting with Bucket4j
 */
@Component
public class RateLimitingFilter extends OncePerRequestFilter {
    
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        String clientId = getClientId(request);
        Bucket bucket = resolveBucket(clientId);
        
        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
        } else {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("""
                {
                    "error": "Too Many Requests",
                    "message": "Rate limit exceeded. Please try again later.",
                    "status": 429
                }
                """);
        }
    }
    
    private Bucket resolveBucket(String clientId) {
        return cache.computeIfAbsent(clientId, key -> createNewBucket());
    }
    
    private Bucket createNewBucket() {
        // 100 requests per minute
        Bandwidth limit = Bandwidth.classic(100, Refill.intervally(100, Duration.ofMinutes(1)));
        return Bucket.builder()
            .addLimit(limit)
            .build();
    }
    
    private String getClientId(HttpServletRequest request) {
        // Use API key if present, otherwise use IP address
        String apiKey = request.getHeader("X-API-Key");
        if (apiKey != null) {
            return apiKey;
        }
        return request.getRemoteAddr();
    }
}

/**
 * Method-level rate limiting with annotations
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RateLimit {
    int requests() default 10;
    int perSeconds() default 60;
}

@Aspect
@Component
@Slf4j
public class RateLimitAspect {
    
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();
    
    @Around("@annotation(rateLimit)")
    public Object checkRateLimit(ProceedingJoinPoint joinPoint, RateLimit rateLimit) 
            throws Throwable {
        
        // Get user from security context
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String userId = auth != null ? auth.getName() : "anonymous";
        
        String key = userId + ":" + joinPoint.getSignature().toShortString();
        Bucket bucket = buckets.computeIfAbsent(key, 
            k -> createBucket(rateLimit.requests(), rateLimit.perSeconds()));
        
        if (bucket.tryConsume(1)) {
            return joinPoint.proceed();
        } else {
            throw new RateLimitExceededException(
                "Rate limit exceeded: " + rateLimit.requests() + " requests per " + 
                rateLimit.perSeconds() + " seconds"
            );
        }
    }
    
    private Bucket createBucket(int requests, int perSeconds) {
        Bandwidth limit = Bandwidth.classic(
            requests, 
            Refill.intervally(requests, Duration.ofSeconds(perSeconds))
        );
        return Bucket.builder().addLimit(limit).build();
    }
}

/**
 * Usage in controller
 */
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
    
    @PostMapping
    @RateLimit(requests = 10, perSeconds = 60) // 10 requests per minute
    public ResponseEntity<Order> createOrder(@RequestBody @Valid CreateOrderRequest request) {
        // Implementation
        return ResponseEntity.ok(new Order());
    }
    
    @GetMapping("/{id}")
    @RateLimit(requests = 100, perSeconds = 60) // 100 requests per minute
    public ResponseEntity<Order> getOrder(@PathVariable Long id) {
        // Implementation
        return ResponseEntity.ok(new Order());
    }
}
```

##### 2.3.6.6 Sensitive Data Protection

**Protect sensitive data in logs, responses, and storage:**

```java
/**
 * Mask sensitive fields in JSON responses
 */
@JsonSerialize(using = SensitiveDataSerializer.class)
public @interface SensitiveData {
    MaskType maskType() default MaskType.PARTIAL;
}

public enum MaskType {
    PARTIAL,  // Show first 2 and last 2 characters
    FULL,     // Show nothing (all asterisks)
    EMAIL     // Mask email username
}

public class SensitiveDataSerializer extends JsonSerializer<String> {
    
    @Override
    public void serialize(String value, JsonGenerator gen, SerializerProvider serializers) 
            throws IOException {
        if (value == null) {
            gen.writeNull();
            return;
        }
        
        // Get annotation from current field
        BeanProperty property = (BeanProperty) gen.getCurrentValue();
        SensitiveData annotation = property.getAnnotation(SensitiveData.class);
        
        if (annotation != null) {
            String masked = maskValue(value, annotation.maskType());
            gen.writeString(masked);
        } else {
            gen.writeString(value);
        }
    }
    
    private String maskValue(String value, MaskType maskType) {
        return switch (maskType) {
            case PARTIAL -> maskPartial(value);
            case FULL -> "*".repeat(value.length());
            case EMAIL -> maskEmail(value);
        };
    }
    
    private String maskPartial(String value) {
        if (value.length() <= 4) {
            return "*".repeat(value.length());
        }
        String start = value.substring(0, 2);
        String end = value.substring(value.length() - 2);
        return start + "*".repeat(value.length() - 4) + end;
    }
    
    private String maskEmail(String email) {
        int atIndex = email.indexOf('@');
        if (atIndex <= 0) {
            return maskPartial(email);
        }
        String username = email.substring(0, atIndex);
        String domain = email.substring(atIndex);
        return maskPartial(username) + domain;
    }
}

/**
 * DTO with sensitive data masking
 */
@Getter
@Setter
public class UserResponse {
    
    private Long id;
    
    @SensitiveData(maskType = MaskType.EMAIL)
    private String email;
    
    private String firstName;
    private String lastName;
    
    @SensitiveData(maskType = MaskType.PARTIAL)
    private String phoneNumber;
    
    @SensitiveData(maskType = MaskType.PARTIAL)
    private String ssn;
    
    @JsonIgnore // Never expose in API
    private String password;
    
    @SensitiveData(maskType = MaskType.PARTIAL)
    private String creditCardNumber;
}

/**
 * Encrypt sensitive data at rest
 */
@Entity
@Table(name = "users")
@Getter
@Setter
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String email;
    
    @Convert(converter = EncryptedStringConverter.class)
    private String ssn;
    
    @Convert(converter = EncryptedStringConverter.class)
    private String phoneNumber;
    
    // Password should be hashed, not encrypted
    private String passwordHash;
}

/**
 * JPA Attribute Converter for encryption
 */
@Component
@Converter
public class EncryptedStringConverter implements AttributeConverter<String, String> {
    
    @Autowired
    private EncryptionService encryptionService;
    
    @Override
    public String convertToDatabaseColumn(String attribute) {
        if (attribute == null) {
            return null;
        }
        return encryptionService.encrypt(attribute);
    }
    
    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null) {
            return null;
        }
        return encryptionService.decrypt(dbData);
    }
}

/**
 * Encryption service using AES-256
 */
@Service
public class EncryptionService {
    
    @Value("${encryption.secret-key}")
    private String secretKey;
    
    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 16;
    
    public String encrypt(String plaintext) {
        try {
            byte[] iv = new byte[GCM_IV_LENGTH];
            SecureRandom random = new SecureRandom();
            random.nextBytes(iv);
            
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, iv);
            cipher.init(Cipher.ENCRYPT_MODE, getKey(), parameterSpec);
            
            byte[] cipherText = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            
            // Combine IV and ciphertext
            byte[] combined = new byte[iv.length + cipherText.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(cipherText, 0, combined, iv.length, cipherText.length);
            
            return Base64.getEncoder().encodeToString(combined);
            
        } catch (Exception e) {
            throw new EncryptionException("Encryption failed", e);
        }
    }
    
    public String decrypt(String encrypted) {
        try {
            byte[] decoded = Base64.getDecoder().decode(encrypted);
            
            // Extract IV and ciphertext
            byte[] iv = new byte[GCM_IV_LENGTH];
            System.arraycopy(decoded, 0, iv, 0, iv.length);
            
            byte[] cipherText = new byte[decoded.length - GCM_IV_LENGTH];
            System.arraycopy(decoded, GCM_IV_LENGTH, cipherText, 0, cipherText.length);
            
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH * 8, iv);
            cipher.init(Cipher.DECRYPT_MODE, getKey(), parameterSpec);
            
            byte[] plaintext = cipher.doFinal(cipherText);
            return new String(plaintext, StandardCharsets.UTF_8);
            
        } catch (Exception e) {
            throw new EncryptionException("Decryption failed", e);
        }
    }
    
    private SecretKey getKey() throws NoSuchAlgorithmException {
        byte[] keyBytes = secretKey.getBytes(StandardCharsets.UTF_8);
        MessageDigest sha = MessageDigest.getInstance("SHA-256");
        keyBytes = sha.digest(keyBytes);
        return new SecretKeySpec(keyBytes, "AES");
    }
}

/**
 * Mask sensitive data in logs
 */
@Component
public class SensitiveDataLogger {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}");
    private static final Pattern PHONE_PATTERN = 
        Pattern.compile("\\d{3}[-.]?\\d{3}[-.]?\\d{4}");
    private static final Pattern SSN_PATTERN = 
        Pattern.compile("\\d{3}-\\d{2}-\\d{4}");
    private static final Pattern CREDIT_CARD_PATTERN = 
        Pattern.compile("\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}");
    
    public String maskSensitiveData(String message) {
        if (message == null) {
            return null;
        }
        
        String masked = message;
        masked = EMAIL_PATTERN.matcher(masked).replaceAll("***@***.***");
        masked = PHONE_PATTERN.matcher(masked).replaceAll("***-***-****");
        masked = SSN_PATTERN.matcher(masked).replaceAll("***-**-****");
        masked = CREDIT_CARD_PATTERN.matcher(masked).replaceAll("****-****-****-****");
        
        return masked;
    }
}

/**
 * Logging aspect with sensitive data masking
 */
@Aspect
@Component
@RequiredArgsConstructor
@Slf4j
public class LoggingAspect {
    
    private final SensitiveDataLogger sensitiveDataLogger;
    
    @Around("@annotation(org.springframework.web.bind.annotation.PostMapping) || " +
            "@annotation(org.springframework.web.bind.annotation.PutMapping)")
    public Object logApiCall(ProceedingJoinPoint joinPoint) throws Throwable {
        String methodName = joinPoint.getSignature().toShortString();
        
        // Mask sensitive data in arguments
        Object[] args = joinPoint.getArgs();
        String maskedArgs = Arrays.stream(args)
            .map(arg -> arg != null ? sensitiveDataLogger.maskSensitiveData(arg.toString()) : "null")
            .collect(Collectors.joining(", "));
        
        log.info("API call: {} with args: [{}]", methodName, maskedArgs);
        
        try {
            Object result = joinPoint.proceed();
            log.info("API call completed: {}", methodName);
            return result;
        } catch (Exception e) {
            log.error("API call failed: {}", methodName, e);
            throw e;
        }
    }
}
```

### 2.4 Anti-Patterns to Avoid

#### 2.4.1 God Object / God Class

**Problem:** A class that knows too much or does too much.

##### ❌ Anti-Pattern Example

```java
/**
 * God class - handles everything related to orders
 */
@Service
public class OrderManager {
    
    // Handles all order operations
    public Order createOrder(CreateOrderRequest request) { }
    public void cancelOrder(Long orderId) { }
    public void updateOrder(Long orderId, UpdateOrderRequest request) { }
    
    // Handles payment
    public void processPayment(Long orderId, PaymentDetails payment) { }
    public void refundPayment(Long orderId) { }
    
    // Handles inventory
    public void reserveInventory(Long orderId) { }
    public void releaseInventory(Long orderId) { }
    
    // Handles shipping
    public void createShipment(Long orderId) { }
    public void trackShipment(String shipmentId) { }
    
    // Handles notifications
    public void sendOrderConfirmation(Long orderId) { }
    public void sendShippingNotification(Long orderId) { }
    
    // Handles reports
    public byte[] generateInvoice(Long orderId) { }
    public byte[] generatePackingSlip(Long orderId) { }
    
    // ... hundreds more methods
}
```

##### ✅ Correct Implementation (SRP Applied)

```java
@Service
@RequiredArgsConstructor
public class OrderService {
    public Order createOrder(CreateOrderRequest request) { }
    public void cancelOrder(Long orderId) { }
}

@Service
@RequiredArgsConstructor
public class PaymentService {
    public void processPayment(Long orderId, PaymentDetails payment) { }
    public void refundPayment(Long orderId) { }
}

@Service
@RequiredArgsConstructor
public class InventoryService {
    public void reserveInventory(Long orderId) { }
    public void releaseInventory(Long orderId) { }
}

@Service
@RequiredArgsConstructor
public class ShippingService {
    public void createShipment(Long orderId) { }
    public void trackShipment(String shipmentId) { }
}
```

#### 2.4.2 Anemic Domain Model

**Problem:** Domain objects with getters/setters but no behavior (just data holders).

##### ❌ Anti-Pattern Example

```java
/**
 * Anemic model - no business logic
 */
@Entity
public class Order {
    private Long id;
    private BigDecimal amount;
    private OrderStatus status;
    private List<OrderItem> items;
    
    // Only getters and setters, no behavior
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    // ... more getters/setters
}

/**
 * All business logic in service
 */
@Service
public class OrderService {
    
    public void cancelOrder(Order order) {
        if (order.getStatus() == OrderStatus.SHIPPED) {
            throw new IllegalStateException("Cannot cancel shipped order");
        }
        order.setStatus(OrderStatus.CANCELLED);
        // Refund logic
        // Inventory release logic
    }
}
```

##### ✅ Correct Implementation (Rich Domain Model)

```java
/**
 * Rich domain model with business logic
 */
@Entity
@NoArgsConstructor
public class Order {
    
    @Id
    @GeneratedValue
    private Long id;
    
    private BigDecimal amount;
    
    @Enumerated(EnumType.STRING)
    private OrderStatus status;
    
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL)
    private List<OrderItem> items = new ArrayList<>();
    
    private Instant shippedAt;
    
    /**
     * Business method - encapsulates cancellation logic
     */
    public void cancel() {
        if (status == OrderStatus.SHIPPED) {
            throw new IllegalStateException(
                "Cannot cancel order that has been shipped"
            );
        }
        
        if (status == OrderStatus.CANCELLED) {
            throw new IllegalStateException(
                "Order is already cancelled"
            );
        }
        
        this.status = OrderStatus.CANCELLED;
        publishDomainEvent(new OrderCancelledEvent(this));
    }
    
    /**
     * Business method - encapsulates shipping logic
     */
    public void markAsShipped() {
        if (status != OrderStatus.PAID) {
            throw new IllegalStateException(
                "Can only ship orders that are paid"
            );
        }
        
        this.status = OrderStatus.SHIPPED;
        this.shippedAt = Instant.now();
        publishDomainEvent(new OrderShippedEvent(this));
    }
    
    /**
     * Business method - calculate total
     */
    public BigDecimal calculateTotal() {
        return items.stream()
            .map(OrderItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
    
    /**
     * Business method - validate order
     */
    public boolean isValid() {
        return items != null 
            && !items.isEmpty() 
            && amount != null 
            && amount.compareTo(BigDecimal.ZERO) > 0;
    }
    
    private void publishDomainEvent(DomainEvent event) {
        // Event publishing logic
    }
}

/**
 * Service orchestrates, domain handles logic
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
    
    @Transactional
    public void cancelOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
        
        // Domain object handles its own business rules
        order.cancel();
        
        // Service coordinates with other services
        paymentService.refund(order.getId());
        
        orderRepository.save(order);
    }
}
```

#### 2.4.3 N+1 Query Problem

**Problem:** Executing N additional database queries for N results.

##### ❌ Anti-Pattern Example

```java
@Service
public class OrderService {
    
    @Autowired
    private OrderRepository orderRepository;
    
    public List<OrderDTO> getAllOrders() {
        List<Order> orders = orderRepository.findAll();  // 1 query
        
        return orders.stream()
            .map(order -> {
                // N queries - one for each order!
                Customer customer = customerRepository.findById(order.getCustomerId()).get();
                List<OrderItem> items = orderItemRepository.findByOrderId(order.getId());
                
                return OrderDTO.builder()
                    .orderId(order.getId())
                    .customerName(customer.getName())
                    .itemCount(items.size())
                    .build();
            })
            .collect(Collectors.toList());
    }
}
```

##### ✅ Correct Implementation

```java
/**
 * Use JOIN FETCH to load associations in single query
 */
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    
    @Query("""
        SELECT DISTINCT o FROM Order o
        LEFT JOIN FETCH o.customer
        LEFT JOIN FETCH o.items
        WHERE o.status = :status
        """)
    List<Order> findAllWithCustomerAndItems(@Param("status") OrderStatus status);
    
    // Or use EntityGraph
    @EntityGraph(attributePaths = {"customer", "items"})
    List<Order> findAll();
}

/**
 * Batch loading approach
 */
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    
    public List<OrderDTO> getAllOrders() {
        // Single query with all joins
        List<Order> orders = orderRepository.findAllWithCustomerAndItems(OrderStatus.ACTIVE);
        
        return orders.stream()
            .map(this::toDTO)
            .collect(Collectors.toList());
    }
}
```

#### 2.4.4 Spaghetti Code / Cyclic Dependencies

**Problem:** Tangled, complex code with circular dependencies between classes.

##### ❌ Anti-Pattern Example

```java
@Service
public class UserService {
    @Autowired
    private OrderService orderService;  // Circular dependency!
    
    public User createUser(UserRequest request) {
        User user = new User();
        // ...
        
        // UserService depends on OrderService
        orderService.createWelcomeOrder(user);
        return user;
    }
}

@Service
public class OrderService {
    @Autowired
    private UserService userService;  // Circular dependency!
    
    public Order createOrder(OrderRequest request) {
        // OrderService depends on UserService
        User user = userService.findById(request.getUserId());
        // ...
    }
    
    public void createWelcomeOrder(User user) {
        // ...
    }
}
```

##### ✅ Correct Implementation

```java
/**
 * Option 1: Introduce intermediate service
 */
@Service
@RequiredArgsConstructor
public class UserRegistrationService {
    
    private final UserService userService;
    private final OrderService orderService;
    
    @Transactional
    public User registerUser(UserRequest request) {
        // Orchestrate both services
        User user = userService.createUser(request);
        orderService.createWelcomeOrder(user.getId());
        return user;
    }
}

@Service
public class UserService {
    // No dependency on OrderService
    public User createUser(UserRequest request) {
        return userRepository.save(new User());
    }
}

@Service
public class OrderService {
    // No dependency on UserService
    public Order createWelcomeOrder(Long userId) {
        return orderRepository.save(new Order());
    }
}

/**
 * Option 2: Use events to decouple
 */
@Service
@RequiredArgsConstructor
public class UserService {
    
    private final ApplicationEventPublisher eventPublisher;
    
    @Transactional
    public User createUser(UserRequest request) {
        User user = userRepository.save(new User());
        
        // Publish event instead of direct dependency
        eventPublisher.publishEvent(new UserCreatedEvent(this, user));
        
        return user;
    }
}

@Component
@RequiredArgsConstructor
public class WelcomeOrderListener {
    
    private final OrderService orderService;
    
    @EventListener
    @Async
    public void handleUserCreated(UserCreatedEvent event) {
        orderService.createWelcomeOrder(event.getUser().getId());
    }
}
```

#### 2.4.5 Magic Numbers and Strings

**Problem:** Hard-coded values scattered throughout code without explanation.

##### ❌ Anti-Pattern Example

```java
@Service
public class DiscountService {
    
    public BigDecimal calculateDiscount(Order order) {
        BigDecimal total = order.getTotal();
        
        if (order.getCustomerType().equals("VIP")) {
            return total.multiply(BigDecimal.valueOf(0.25));  // Magic number!
        } else if (order.getCustomerType().equals("MEMBER")) {
            return total.multiply(BigDecimal.valueOf(0.10));  // Magic number!
        } else if (total.compareTo(BigDecimal.valueOf(1000)) > 0) {  // Magic number!
            return total.multiply(BigDecimal.valueOf(0.05));  // Magic number!
        }
        
        return BigDecimal.ZERO;
    }
}
```

##### ✅ Correct Implementation

```java
/**
 * Use constants with meaningful names
 */
public class DiscountConstants {
    public static final BigDecimal VIP_DISCOUNT_RATE = BigDecimal.valueOf(0.25);
    public static final BigDecimal MEMBER_DISCOUNT_RATE = BigDecimal.valueOf(0.10);
    public static final BigDecimal BULK_ORDER_DISCOUNT_RATE = BigDecimal.valueOf(0.05);
    public static final BigDecimal BULK_ORDER_THRESHOLD = BigDecimal.valueOf(1000);
    
    public static final String CUSTOMER_TYPE_VIP = "VIP";
    public static final String CUSTOMER_TYPE_MEMBER = "MEMBER";
}

/**
 * Better: Use enums for customer types
 */
public enum CustomerType {
    REGULAR(BigDecimal.ZERO),
    MEMBER(BigDecimal.valueOf(0.10)),
    VIP(BigDecimal.valueOf(0.25));
    
    private final BigDecimal discountRate;
    
    CustomerType(BigDecimal discountRate) {
        this.discountRate = discountRate;
    }
    
    public BigDecimal getDiscountRate() {
        return discountRate;
    }
}

@Service
public class DiscountService {
    
    public BigDecimal calculateDiscount(Order order) {
        BigDecimal total = order.getTotal();
        CustomerType customerType = order.getCustomerType();
        
        // Use enum discount rate
        BigDecimal discount = total.multiply(customerType.getDiscountRate());
        
        // Bulk order discount
        if (total.compareTo(DiscountConstants.BULK_ORDER_THRESHOLD) > 0) {
            BigDecimal bulkDiscount = total.multiply(DiscountConstants.BULK_ORDER_DISCOUNT_RATE);
            discount = discount.max(bulkDiscount);
        }
        
        return discount;
    }
}
```

#### 2.4.6 Service Layer Bypassing

**Problem:** Controllers directly accessing repositories, bypassing business logic.

##### ❌ Anti-Pattern Example

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
    
    @Autowired
    private OrderRepository orderRepository;  // Direct repository access!
    
    @Autowired
    private CustomerRepository customerRepository;
    
    @PostMapping
    public ResponseEntity<Order> createOrder(@RequestBody CreateOrderRequest request) {
        // Business logic in controller - BAD!
        Customer customer = customerRepository.findById(request.getCustomerId()).get();
        
        if (!customer.isActive()) {
            return ResponseEntity.badRequest().build();
        }
        
        Order order = new Order();
        order.setCustomerId(request.getCustomerId());
        order.setStatus(OrderStatus.PENDING);
        
        // Direct repository call - bypasses any business logic
        Order saved = orderRepository.save(order);
        
        return ResponseEntity.ok(saved);
    }
}
```

##### ✅ Correct Implementation

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {
    
    private final OrderService orderService;  // Use service layer
    
    @PostMapping
    public ResponseEntity<Order> createOrder(@RequestBody @Valid CreateOrderRequest request) {
        // Delegate to service - proper layering
        Order order = orderService.createOrder(request);
        return ResponseEntity.created(URI.create("/api/v1/orders/" + order.getId()))
            .body(order);
    }
}

@Service
@RequiredArgsConstructor
@Transactional
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final CustomerService customerService;
    private final OrderValidator orderValidator;
    
    public Order createOrder(CreateOrderRequest request) {
        // All business logic in service
        Customer customer = customerService.findById(request.getCustomerId());
        orderValidator.validateCustomer(customer);
        orderValidator.validateOrder(request);
        
        Order order = Order.builder()
            .customerId(request.getCustomerId())
            .status(OrderStatus.PENDING)
            .items(request.getItems())
            .build();
        
        return orderRepository.save(order);
    }
}
```

---

#### 2.4.7 Overly Generic Annotations

**Problem:** Not using more specific annotations

- Annotation specificity: Use the most specific possible
- Controllers
  - `@RestController` is preferred over
  - `@Controller` is preferred over
  - `@Component`
- Services
  - `@Service` is preferred over
  - `@Component`
- Repositories
  - `@Repository` is preferred over
  - `@Component`

##### ❌ Anti-Pattern Example

```java
@Controller // Too generic - should be @RestController
@RequestMapping("/api/v1/flights")
public class FlightController {
  // ...
}
```

##### ✅ Correct Implementation

```java
@RestController
@RequestMapping("/api/v1/flights")
public class FlightController {
  // ...
}
```

## 3. Security Standards

### 3.1 Application Security

#### Authentication & Authorization

```java
/**
 * Security Configuration
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
@RequiredArgsConstructor
public class SecurityConfig {
    
    private final JwtAuthenticationFilter jwtAuthFilter;
    private final AuthenticationProvider authenticationProvider;
    
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .authorizeHttpRequests(auth -> auth
                // Public endpoints
                .requestMatchers("/api/v1/auth/**", "/api/v1/public/**").permitAll()
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                
                // Admin endpoints
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                
                // User endpoints
                .requestMatchers("/api/v1/users/**").hasAnyRole("USER", "ADMIN")
                
                // All other requests require authentication
                .anyRequest().authenticated()
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .authenticationProvider(authenticationProvider)
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint((request, response, authException) -> {
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    response.setContentType("application/json");
                    response.getWriter().write(
                        "{\"error\":\"Unauthorized\",\"message\":\"" + 
                        authException.getMessage() + "\"}"
                    );
                })
                .accessDeniedHandler((request, response, accessDeniedException) -> {
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.setContentType("application/json");
                    response.getWriter().write(
                        "{\"error\":\"Forbidden\",\"message\":\"" + 
                        accessDeniedException.getMessage() + "\"}"
                    );
                })
            );
        
        return http.build();
    }
    
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList("https://app.company.com"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setExposedHeaders(Arrays.asList("X-Total-Count", "Authorization"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
```

#### Method-Level Security

```java
@Service
@RequiredArgsConstructor
public class UserService {
    
    /**
     * Check if user has specific role
     */
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(Long id) {
        userRepository.deleteById(id);
    }
    
    /**
     * Check if user has specific authority
     */
    @PreAuthorize("hasAuthority('USER_WRITE')")
    public User createUser(CreateUserRequest request) {
        // Implementation
    }
    
    /**
     * Check if authenticated user is accessing their own resource
     */
    @PreAuthorize("#userId == authentication.principal.id or hasRole('ADMIN')")
    public User updateUser(Long userId, UpdateUserRequest request) {
        // Implementation
    }
    
    /**
     * SpEL expression for complex authorization
     */
    @PreAuthorize("@userSecurityService.canAccessUser(#userId, authentication)")
    public User getUserDetails(Long userId) {
        // Implementation
    }
    
    /**
     * Post-authorization (check after method execution)
     */
    @PostAuthorize("returnObject.userId == authentication.principal.id")
    public Order getOrder(Long orderId) {
        return orderRepository.findById(orderId).orElseThrow();
    }
}
```

### 3.2 Externalized Configuration

```yaml
# application.yml
spring:
  config:
    import: optional:configserver:http://localhost:8888
  cloud:
    config:
      name: user-service
      profile: ${SPRING_PROFILES_ACTIVE:dev}
      uri: ${CONFIG_SERVER_URI}
      username: ${CONFIG_SERVER_USERNAME}
      password: ${CONFIG_SERVER_PASSWORD}
      fail-fast: true
      retry:
        max-attempts: 6
        initial-interval: 1000
        max-interval: 2000

# Vault integration for secrets
  cloud:
    vault:
      uri: ${VAULT_URI:http://localhost:8200}
      token: ${VAULT_TOKEN}
      kv:
        enabled: true
        backend: secret
        profile-separator: '/'
```

```java
/**
 * Configuration Properties
 */
@ConfigurationProperties(prefix = "app")
@Validated
@Data
public class ApplicationProperties {
    
    @NotNull
    private Security security;
    
    @NotNull
    private Database database;
    
    @Valid
    private Kafka kafka;
    
    @Data
    public static class Security {
        @NotBlank
        private String jwtSecret;
        
        @Positive
        private Long jwtExpiration;
        
        @NotEmpty
        private List<String> allowedOrigins;
    }
    
    @Data
    public static class Database {
        @Min(5)
        @Max(50)
        private Integer maxPoolSize;
        
        @Min(2)
        private Integer minIdle;
    }
}

/**
 * Enable configuration properties
 */
@Configuration
@EnableConfigurationProperties(ApplicationProperties.class)
public class AppConfig {
    // Configuration beans
}
```

### 3.3 Sensitive Information Handling (PCI/PII)

```java
/**
 * Entity with sensitive data
 */
@Entity
@Table(name = "payment_cards")
@Data
public class PaymentCard {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    /**
     * PCI DSS: Card number must be encrypted at rest
     * Use JPA attribute converter for transparent encryption
     */
    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "card_number", nullable = false)
    private String cardNumber;
    
    /**
     * PCI DSS: CVV must never be stored
     * Use @Transient to prevent persistence
     */
    @Transient
    private String cvv;
    
    /**
     * Mask PII in logs
     */
    @Override
    public String toString() {
        return "PaymentCard{" +
               "id=" + id +
               ", cardNumber='" + maskCardNumber() + '\'' +
               '}';
    }
    
    private String maskCardNumber() {
        if (cardNumber == null || cardNumber.length() < 4) {
            return "****";
        }
        return "****-****-****-" + cardNumber.substring(cardNumber.length() - 4);
    }
}

/**
 * JPA Converter for encryption
 */
@Converter
@RequiredArgsConstructor
public class EncryptedStringConverter implements AttributeConverter<String, String> {
    
    private final EncryptionService encryptionService;
    
    @Override
    public String convertToDatabaseColumn(String attribute) {
        if (attribute == null) {
            return null;
        }
        return encryptionService.encrypt(attribute);
    }
    
    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null) {
            return null;
        }
        return encryptionService.decrypt(dbData);
    }
}

/**
 * Encryption Service using AES-256
 */
@Service
public class EncryptionService {
    
    @Value("${app.security.encryption.key}")
    private String encryptionKey;
    
    private final String ALGORITHM = "AES/GCM/NoPadding";
    
    public String encrypt(String plainText) {
        try {
            SecretKeySpec keySpec = new SecretKeySpec(
                encryptionKey.getBytes(StandardCharsets.UTF_8), "AES");
            
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            byte[] iv = new byte[12];
            SecureRandom random = new SecureRandom();
            random.nextBytes(iv);
            
            GCMParameterSpec parameterSpec = new GCMParameterSpec(128, iv);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, parameterSpec);
            
            byte[] encryptedBytes = cipher.doFinal(
                plainText.getBytes(StandardCharsets.UTF_8));
            
            byte[] combined = new byte[iv.length + encryptedBytes.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encryptedBytes, 0, combined, iv.length, encryptedBytes.length);
            
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new EncryptionException("Failed to encrypt data", e);
        }
    }
    
    public String decrypt(String encryptedText) {
        try {
            byte[] combined = Base64.getDecoder().decode(encryptedText);
            
            byte[] iv = new byte[12];
            byte[] encryptedBytes = new byte[combined.length - iv.length];
            
            System.arraycopy(combined, 0, iv, 0, iv.length);
            System.arraycopy(combined, iv.length, encryptedBytes, 0, encryptedBytes.length);
            
            SecretKeySpec keySpec = new SecretKeySpec(
                encryptionKey.getBytes(StandardCharsets.UTF_8), "AES");
            
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(128, iv);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, parameterSpec);
            
            byte[] decryptedBytes = cipher.doFinal(encryptedBytes);
            return new String(decryptedBytes, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new EncryptionException("Failed to decrypt data", e);
        }
    }
}

/**
 * Audit logging for PII access
 */
@Aspect
@Component
@Slf4j
public class PIIAccessAuditAspect {
    
    @Around("@annotation(com.company.annotation.PIIAccess)")
    public Object auditPIIAccess(ProceedingJoinPoint joinPoint) throws Throwable {
        String method = joinPoint.getSignature().toShortString();
        String user = SecurityContextHolder.getContext()
            .getAuthentication().getName();
        
        log.info("PII_ACCESS: user={}, method={}, timestamp={}", 
                user, method, Instant.now());
        
        try {
            return joinPoint.proceed();
        } finally {
            log.info("PII_ACCESS_COMPLETE: user={}, method={}", user, method);
        }
    }
}
```

### 3.4 Certificate and Key Management

```java
/**
 * SSL/TLS Configuration
 */
@Configuration
public class SSLConfig {
    
    /**
     * Configure mutual TLS (mTLS) for service-to-service communication
     */
    @Bean
    public RestClient mtlsRestClient() throws Exception {
        // Load client keystore
        KeyStore keyStore = KeyStore.getInstance("PKCS12");
        try (InputStream keyStoreStream = 
                 new FileInputStream("/path/to/client-keystore.p12")) {
            keyStore.load(keyStoreStream, "keystorePassword".toCharArray());
        }
        
        // Load truststore
        KeyStore trustStore = KeyStore.getInstance("JKS");
        try (InputStream trustStoreStream = 
                 new FileInputStream("/path/to/truststore.jks")) {
            trustStore.load(trustStoreStream, "truststorePassword".toCharArray());
        }
        
        SSLContext sslContext = SSLContextBuilder.create()
            .loadKeyMaterial(keyStore, "keyPassword".toCharArray())
            .loadTrustMaterial(trustStore, new TrustSelfSignedStrategy())
            .build();
        
        HttpClient httpClient = HttpClients.custom()
            .setSSLContext(sslContext)
            .setSSLHostnameVerifier(new DefaultHostnameVerifier())
            .build();
        
        HttpComponentsClientHttpRequestFactory factory = 
            new HttpComponentsClientHttpRequestFactory(httpClient);
        factory.setConnectTimeout(5000);
        factory.setConnectionRequestTimeout(5000);
        
        return RestClient.builder()
            .requestFactory(factory)
            .build();
    }
}

/**
 * Vault integration for dynamic secrets
 */
@Service
@RequiredArgsConstructor
public class VaultSecretService {
    
    private final VaultTemplate vaultTemplate;
    
    public String getDatabasePassword() {
        VaultResponse response = vaultTemplate.read("secret/data/database");
        return (String) response.getData().get("password");
    }
    
    public Map<String, Object> getApiCredentials(String serviceName) {
        VaultResponse response = vaultTemplate.read(
            "secret/data/api/" + serviceName);
        return response.getData();
    }
}
```

---

## 4. Performance and Resiliency

### 4.0 Required Guidelines (Normative)

Use the following standards for all production Spring Boot services.

#### 4.0.1 Caching (Embedded and Distributed)

- Use Spring Cache abstraction (`@Cacheable`, `@CachePut`, `@CacheEvict`) as the default integration pattern.
- Use embedded cache (Caffeine) for low-latency, process-local, read-heavy data with acceptable staleness.
- Use distributed cache (Redis) when cache must be shared across instances/pods, or when horizontal scaling requires cache coherence.
- Prefer a two-level approach for critical hot paths: L1 embedded cache + L2 distributed cache.
- Define TTL per cache domain (for example: reference data longer TTL, transactional views shorter TTL).
- Do not cache secrets, tokens, or PII unless encryption, masking, and retention controls are explicitly approved.
- Always define eviction behavior for update/delete workflows to avoid stale reads.
- Instrument cache hit ratio, misses, evictions, and load latency with Micrometer metrics.

#### 4.0.1.1 Redis Cache Configuration Rules

- Use Redis for shared/distributed cache only; avoid using Redis cache as a system of record.
- Configure explicit key prefixes by bounded context (`<app>:<domain>:<entity>:<id>`) to prevent key collisions.
- Configure per-cache TTLs. Do not use unbounded TTL in production.
- Disable caching of null values unless a documented cache-penetration strategy requires it.
- Use stable serialization (`StringRedisSerializer` for keys and JSON serializer for values) and version DTOs to avoid deserialization breaks during rollout.
- Use connection pooling with conservative limits and fail-fast timeout settings.
- For Azure Redis Cache, enforce TLS-only traffic, disable non-TLS access, and use Microsoft Entra authentication or Key Vault-managed access keys.
- Define cache invalidation on write paths (`@CacheEvict`/`@CachePut`) and document eventual consistency expectations.
- Add metrics and alerts for hit ratio drop, command latency, connection pool exhaustion, and memory pressure/evictions.

#### 4.0.1.2 Azure Redis Cache Rules

- Use Azure Private Endpoint (or VNet integration) for production workloads; avoid public network access unless explicitly approved.
- Store Redis credentials only in Azure Key Vault and load them through managed identity-backed secret resolution.
- Prefer Microsoft Entra auth where supported by your Azure Redis tier; otherwise rotate access keys on a defined schedule.
- Set `spring.data.redis.ssl.enabled=true` for all non-local profiles.
- Use zone-redundant/high-availability tiers for critical services and validate failover behavior during resilience tests.
- Monitor Azure Redis signals: server load, connected clients, cache hits/misses, evicted keys, and throttling events.

```yaml
# application.yml - Azure Redis cache baseline
spring:
    cache:
        type: redis
        redis:
            time-to-live: 10m
            cache-null-values: false
            use-key-prefix: true
            key-prefix: "${spring.application.name}:"
    data:
        redis:
            host: ${AZURE_REDIS_HOST}
            port: ${AZURE_REDIS_PORT:6380}
            username: ${AZURE_REDIS_USERNAME:}
            password: ${AZURE_REDIS_PASSWORD:}
            timeout: 2s
            connect-timeout: 2s
            ssl:
                enabled: true
```

#### 4.0.2 API Resilience (Circuit Breaker, Retry, Timeout)

- Protect all outbound network calls with resilience patterns; do not call external dependencies without guardrails.
- Apply timeout first, retry only for transient failures, and use circuit breaker to prevent cascading failures.
- Retry only idempotent operations by default. Non-idempotent retries require explicit business approval and idempotency keys.
- Use exponential backoff with jitter to avoid retry storms.
- Configure fallback behavior per use case: cached response, partial response, queue-for-later, or explicit failure.
- Use bulkhead isolation for high-risk integrations to protect thread and connection pools.
- Classify exceptions into retryable and non-retryable categories; document this in the API client contract.
- Expose resilience metrics through Actuator/Micrometer and alert on open circuit breakers and sustained timeouts.

#### 4.0.3 Multi-threading and Async

- Use `@EnableAsync` and named `ThreadPoolTaskExecutor` beans; do not rely on default common pools for business workloads.
- Define separate executors by workload type (I/O-bound, CPU-bound, notifications, batch).
- Set explicit `corePoolSize`, `maxPoolSize`, `queueCapacity`, and rejection policy.
- Propagate correlation and trace context across async boundaries (MDC + OpenTelemetry context propagation).
- Apply timeouts (`orTimeout`, Resilience4j `TimeLimiter`) to async workflows to prevent thread starvation.
- Avoid blocking calls inside reactive pipelines and avoid unbounded `CompletableFuture` chaining.
- Handle async exceptions centrally and emit structured logs with correlation IDs.
- Verify async behavior with integration tests for timeout, partial failure, and executor saturation scenarios.

### 4.1 Caching Strategies

#### Spring Cache Abstraction

```java
/**
 * Cache Configuration
 */
@Configuration
@EnableCaching
public class CacheConfig {
    
    /**
     * Embedded Cache (Caffeine)
     */
    @Bean
    public CacheManager caffeineCacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager(
            "users", "products", "orders");
        
        cacheManager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(10, TimeUnit.MINUTES)
            .recordStats());
        
        return cacheManager;
    }
    
    /**
     * Distributed Cache (Redis)
     */
    @Bean
    public CacheManager redisCacheManager(RedisConnectionFactory connectionFactory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .disableCachingNullValues()
            .serializeKeysWith(RedisSerializationContext.SerializationPair
                .fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(RedisSerializationContext.SerializationPair
                .fromSerializer(new GenericJackson2JsonRedisSerializer()));
        
        Map<String, RedisCacheConfiguration> cacheConfigurations = new HashMap<>();
        cacheConfigurations.put("users", config.entryTtl(Duration.ofMinutes(30)));
        cacheConfigurations.put("products", config.entryTtl(Duration.ofHours(1)));
        
        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(config)
            .withInitialCacheConfigurations(cacheConfigurations)
            .build();
    }
    
    /**
     * Multi-level cache (L1: Caffeine, L2: Redis)
     */
    @Bean
    @Primary
    public CacheManager multiLevelCacheManager(
            CacheManager caffeineCacheManager,
            CacheManager redisCacheManager) {
        return new CompositeCacheManager(
            caffeineCacheManager, redisCacheManager);
    }
}

/**
 * Cache Usage
 */
@Service
@RequiredArgsConstructor
public class UserService {
    
    /**
     * Cache the result
     */
    @Cacheable(value = "users", key = "#id", unless = "#result == null")
    public User findById(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }
    
    /**
     * Update cache on modification
     */
    @CachePut(value = "users", key = "#result.id")
    public User updateUser(Long id, UpdateUserRequest request) {
        User user = findById(id);
        userMapper.updateEntity(request, user);
        return userRepository.save(user);
    }
    
    /**
     * Evict cache entry
     */
    @CacheEvict(value = "users", key = "#id")
    public void deleteUser(Long id) {
        userRepository.deleteById(id);
    }
    
    /**
     * Evict all entries
     */
    @CacheEvict(value = "users", allEntries = true)
    public void clearUserCache() {
        log.info("User cache cleared");
    }
    
    /**
     * Complex caching with SpEL
     */
    @Cacheable(
        value = "usersByEmail",
        key = "#email.toLowerCase()",
        condition = "#email.length() > 5",
        unless = "#result.status == T(com.company.domain.UserStatus).INACTIVE"
    )
    public User findByEmail(String email) {
        return userRepository.findByEmail(email)
            .orElseThrow(() -> new UserNotFoundException(email));
    }
}
```

### 4.2 API Resilience Patterns

**Purpose:** Build fault-tolerant microservices that can handle failures gracefully and recover automatically.

#### 4.2.1 Circuit Breaker (Resilience4j)

**Problem:** Prevent cascading failures when calling external services that may be slow or unavailable.

**Solution:** Use Resilience4j Circuit Breaker with Spring Boot.

```xml
<!-- pom.xml dependencies -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
    <version>2.1.0</version>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

```yaml
# application.yml - Circuit Breaker Configuration
resilience4j.circuitbreaker:
  instances:
    paymentService:
      registerHealthIndicator: true
      slidingWindowType: COUNT_BASED
      slidingWindowSize: 10
      minimumNumberOfCalls: 5
      permittedNumberOfCallsInHalfOpenState: 3
      automaticTransitionFromOpenToHalfOpenEnabled: true
      waitDurationInOpenState: 10s
      failureRateThreshold: 50
      eventConsumerBufferSize: 10
      recordExceptions:
        - java.io.IOException
        - java.util.concurrent.TimeoutException
      ignoreExceptions:
        - com.company.exception.BusinessException
    
    inventoryService:
      registerHealthIndicator: true
      slidingWindowSize: 20
      minimumNumberOfCalls: 10
      waitDurationInOpenState: 30s
      failureRateThreshold: 60
```

```java
/**
 * Circuit Breaker Configuration
 */
@Configuration
public class CircuitBreakerConfiguration {
    
    @Bean
    public CircuitBreakerRegistry circuitBreakerRegistry() {
        CircuitBreakerConfig config = CircuitBreakerConfig.custom()
            .slidingWindowType(CircuitBreakerConfig.SlidingWindowType.COUNT_BASED)
            .slidingWindowSize(10)
            .minimumNumberOfCalls(5)
            .failureRateThreshold(50)
            .waitDurationInOpenState(Duration.ofSeconds(10))
            .permittedNumberOfCallsInHalfOpenState(3)
            .automaticTransitionFromOpenToHalfOpenEnabled(true)
            .recordExceptions(IOException.class, TimeoutException.class)
            .ignoreExceptions(BusinessException.class)
            .build();
        
        return CircuitBreakerRegistry.of(config);
    }
}

/**
 * Service with Circuit Breaker using annotation
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {
    
    private final PaymentClient paymentClient;
    
    /**
     * Circuit breaker with fallback method
     */
    @CircuitBreaker(name = "paymentService", fallbackMethod = "processPaymentFallback")
    @Retry(name = "paymentService")
    @TimeLimiter(name = "paymentService")
    public CompletableFuture<PaymentResult> processPayment(PaymentRequest request) {
        log.info("Processing payment for order: {}", request.getOrderId());
        
        return CompletableFuture.supplyAsync(() -> {
            PaymentResult result = paymentClient.charge(request);
            log.info("Payment processed successfully: {}", result.getTransactionId());
            return result;
        });
    }
    
    /**
     * Fallback method - called when circuit is open
     */
    private CompletableFuture<PaymentResult> processPaymentFallback(
            PaymentRequest request, 
            Exception ex) {
        
        log.error("Payment service unavailable, using fallback for order: {}", 
            request.getOrderId(), ex);
        
        // Return cached result, queue for later, or return partial result
        return CompletableFuture.completedFuture(
            PaymentResult.builder()
                .success(false)
                .status(PaymentStatus.PENDING)
                .message("Payment temporarily unavailable. Will retry automatically.")
                .build()
        );
    }
}

/**
 * Service with Circuit Breaker using programmatic API
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class InventoryService {
    
    private final InventoryClient inventoryClient;
    private final CircuitBreakerRegistry circuitBreakerRegistry;
    
    public boolean checkStock(Long productId, int quantity) {
        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("inventoryService");
        
        // Decorate the method call with circuit breaker
        Supplier<Boolean> decoratedSupplier = CircuitBreaker
            .decorateSupplier(circuitBreaker, () -> {
                return inventoryClient.checkAvailability(productId, quantity);
            });
        
        try {
            return decoratedSupplier.get();
        } catch (CallNotPermittedException e) {
            // Circuit is open
            log.error("Circuit breaker is OPEN for inventory service");
            return false; // Fail fast
        } catch (Exception e) {
            log.error("Error checking inventory", e);
            throw e;
        }
    }
}

/**
 * Circuit Breaker Event Listener for monitoring
 */
@Component
@Slf4j
public class CircuitBreakerEventListener {
    
    @Autowired
    public void registerEventListener(CircuitBreakerRegistry registry) {
        registry.circuitBreaker("paymentService").getEventPublisher()
            .onStateTransition(event -> {
                log.warn("Circuit Breaker State Transition: {} -> {}", 
                    event.getStateTransition().getFromState(),
                    event.getStateTransition().getToState());
            })
            .onFailureRateExceeded(event -> {
                log.error("Circuit Breaker Failure Rate Exceeded: {}%", 
                    event.getFailureRate());
            })
            .onError(event -> {
                log.error("Circuit Breaker Error: {}", 
                    event.getThrowable().getMessage());
            })
            .onSuccess(event -> {
                log.debug("Circuit Breaker Success: duration={}ms", 
                    event.getElapsedDuration().toMillis());
            });
    }
}
```

#### 4.2.2 Retry Pattern

**Problem:** Temporary failures (network blips, brief service unavailability) should be retried automatically.

**Solution:** Use Resilience4j Retry with exponential backoff.

```yaml
# application.yml - Retry Configuration
resilience4j.retry:
  instances:
    paymentService:
      maxAttempts: 3
      waitDuration: 1s
      enableExponentialBackoff: true
      exponentialBackoffMultiplier: 2
      retryExceptions:
        - java.io.IOException
        - java.util.concurrent.TimeoutException
      ignoreExceptions:
        - com.company.exception.ValidationException
    
    orderService:
      maxAttempts: 5
      waitDuration: 500ms
      enableExponentialBackoff: true
      exponentialBackoffMultiplier: 1.5
      retryExceptions:
        - org.springframework.web.client.HttpServerErrorException
```

```java
/**
 * Service with Retry pattern
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
    
    private final OrderClient orderClient;
    private final RetryRegistry retryRegistry;
    
    /**
     * Retry with annotation
     */
    @Retry(name = "orderService", fallbackMethod = "createOrderFallback")
    public Order createOrder(CreateOrderRequest request) {
        log.info("Attempting to create order: attempt #{}", getCurrentAttempt());
        return orderClient.create(request);
    }
    
    /**
     * Fallback after all retries exhausted
     */
    private Order createOrderFallback(CreateOrderRequest request, Exception ex) {
        log.error("All retry attempts exhausted for order creation", ex);
        throw new OrderCreationFailedException(
            "Unable to create order after multiple attempts", ex);
    }
    
    /**
     * Programmatic retry with custom configuration
     */
    public Order createOrderWithCustomRetry(CreateOrderRequest request) {
        Retry retry = Retry.of("customOrderRetry", RetryConfig.custom()
            .maxAttempts(3)
            .waitDuration(Duration.ofSeconds(1))
            .intervalFunction(IntervalFunction.ofExponentialBackoff(1000, 2))
            .retryOnException(e -> e instanceof IOException)
            .build());
        
        // Decorate the call
        Supplier<Order> retryableSupplier = Retry.decorateSupplier(
            retry,
            () -> orderClient.create(request)
        );
        
        // Add event listeners
        retry.getEventPublisher()
            .onRetry(event -> log.warn("Retry attempt #{} for order creation", 
                event.getNumberOfRetryAttempts()))
            .onSuccess(event -> log.info("Order created successfully after {} attempts", 
                event.getNumberOfRetryAttempts()))
            .onError(event -> log.error("Order creation failed after {} attempts", 
                event.getNumberOfRetryAttempts()));
        
        return retryableSupplier.get();
    }
    
    private int getCurrentAttempt() {
        // Get current retry attempt from context
        return RetryRegistry.ofDefaults()
            .retry("orderService")
            .getMetrics()
            .getNumberOfFailedCallsWithRetryAttempt();
    }
}

/**
 * Conditional Retry - retry based on response
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ShippingService {
    
    private final ShippingClient shippingClient;
    
    public Shipment createShipment(Order order) {
        RetryConfig config = RetryConfig.custom()
            .maxAttempts(3)
            .waitDuration(Duration.ofMillis(500))
            .intervalFunction(IntervalFunction.ofExponentialRandomBackoff())
            .retryOnResult(response -> {
                // Retry if response indicates temporary failure
                if (response instanceof ShipmentResult result) {
                    return result.getStatus() == ShipmentStatus.RATE_LIMITED
                        || result.getStatus() == ShipmentStatus.TEMPORARILY_UNAVAILABLE;
                }
                return false;
            })
            .retryExceptions(IOException.class, TimeoutException.class)
            .build();
        
        Retry retry = Retry.of("shippingService", config);
        
        Supplier<Shipment> retryableCall = Retry.decorateSupplier(
            retry,
            () -> shippingClient.createShipment(order)
        );
        
        return retryableCall.get();
    }
}
```

#### 4.2.3 Timeout Pattern

**Problem:** Prevent threads from waiting indefinitely for slow downstream services.

**Solution:** Set appropriate timeouts at multiple levels.

```yaml
# application.yml - Timeout Configuration
resilience4j.timelimiter:
  instances:
    paymentService:
      timeoutDuration: 3s
      cancelRunningFuture: true
    
    inventoryService:
      timeoutDuration: 2s
      cancelRunningFuture: true

# HTTP client timeout
rest:
  client:
    connect-timeout: 2000
    read-timeout: 5000
```

```java
/**
 * RestClient with timeout configuration
 */
@Configuration
public class RestClientConfiguration {
    
    @Value("${rest.client.connect-timeout:2000}")
    private int connectTimeout;
    
    @Value("${rest.client.read-timeout:5000}")
    private int readTimeout;
    
    @Bean
    public RestClient restClient() {
        HttpComponentsClientHttpRequestFactory factory = 
            new HttpComponentsClientHttpRequestFactory();
        
        factory.setConnectTimeout(connectTimeout);
        factory.setReadTimeout(readTimeout);
        
        // Connection pool settings
        HttpClient httpClient = HttpClientBuilder.create()
            .setMaxConnTotal(100)
            .setMaxConnPerRoute(20)
            .setConnectionTimeToLive(30, TimeUnit.SECONDS)
            .build();
        
        factory.setHttpClient(httpClient);
        
        return RestClient.builder()
            .requestFactory(factory)
            .build();
    }
}

/**
 * WebClient with timeout (Reactive)
 */
@Configuration
public class WebClientConfiguration {
    
    @Bean
    public WebClient webClient() {
        HttpClient httpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(5))
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 2000)
            .doOnConnected(conn -> 
                conn.addHandlerLast(new ReadTimeoutHandler(5, TimeUnit.SECONDS))
                    .addHandlerLast(new WriteTimeoutHandler(5, TimeUnit.SECONDS))
            );
        
        return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .build();
    }
}

/**
 * Service with TimeLimiter
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ExternalApiService {
    
    private final RestClient restClient;
    private final TimeLimiterRegistry timeLimiterRegistry;
    
    /**
     * Using @TimeLimiter annotation
     */
    @TimeLimiter(name = "paymentService", fallbackMethod = "apiCallFallback")
    public CompletableFuture<ApiResponse> callExternalApi(ApiRequest request) {
        return CompletableFuture.supplyAsync(() -> {
            log.info("Calling external API...");
            return restClient.post()
                .uri("https://api.example.com/process")
                .body(request)
                .retrieve()
                .body(ApiResponse.class);
        });
    }
    
    /**
     * Fallback when timeout occurs
     */
    private CompletableFuture<ApiResponse> apiCallFallback(
            ApiRequest request, 
            TimeoutException ex) {
        
        log.error("API call timed out for request: {}", request.getId(), ex);
        
        return CompletableFuture.completedFuture(
            ApiResponse.builder()
                .success(false)
                .message("Request timed out. Please try again.")
                .build()
        );
    }
    
    /**
     * Programmatic timeout control
     */
    public ApiResponse callApiWithTimeout(ApiRequest request, Duration timeout) {
        TimeLimiter timeLimiter = TimeLimiter.of(timeout);
        
        Callable<ApiResponse> callable = () -> {
            return restClient.post()
                .uri("https://api.example.com/process")
                .body(request)
                .retrieve()
                .body(ApiResponse.class);
        };
        
        try {
            return timeLimiter.executeFutureSupplier(
                () -> CompletableFuture.supplyAsync(() -> {
                    try {
                        return callable.call();
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                })
            );
        } catch (TimeoutException e) {
            log.error("API call timed out after {}ms", timeout.toMillis());
            throw new ApiTimeoutException("External API call timed out", e);
        } catch (Exception e) {
            log.error("API call failed", e);
            throw new ApiException("External API call failed", e);
        }
    }
}
```
#### 4.2.4 Bulkhead Pattern

**Problem:** Isolate different parts of the system so failures in one don't exhaust all resources.

**Solution:** Use thread pools or semaphores to limit concurrent executions.

```yaml
# application.yml - Bulkhead Configuration
resilience4j.bulkhead:
  instances:
    paymentService:
      maxConcurrentCalls: 10
      maxWaitDuration: 500ms
    
    reportService:
      maxConcurrentCalls: 5
      maxWaitDuration: 1s

resilience4j.thread-pool-bulkhead:
  instances:
    heavyProcessing:
      maxThreadPoolSize: 4
      coreThreadPoolSize: 2
      queueCapacity: 10
      keepAliveDuration: 20ms
```

```java
/**
 * Semaphore-based Bulkhead (for blocking calls)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentProcessingService {
    
    private final PaymentClient paymentClient;
    
    /**
     * Limit concurrent payment processing to prevent overload
     */
    @Bulkhead(name = "paymentService", fallbackMethod = "processPaymentFallback", 
              type = Bulkhead.Type.SEMAPHORE)
    public PaymentResult processPayment(PaymentRequest request) {
        log.info("Processing payment in bulkhead: {}", request.getOrderId());
        return paymentClient.charge(request);
    }
    
    /**
     * Fallback when bulkhead is full
     */
    private PaymentResult processPaymentFallback(
            PaymentRequest request, 
            BulkheadFullException ex) {
        
        log.warn("Payment service bulkhead is full. Queueing payment for order: {}", 
            request.getOrderId());
        
        // Queue for later processing or return pending status
        return PaymentResult.builder()
            .success(false)
            .status(PaymentStatus.QUEUED)
            .message("Payment queued due to high load. Will be processed shortly.")
            .build();
    }
}

/**
 * Thread Pool Bulkhead (for async operations)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ReportGenerationService {
    
    private final ReportGenerator reportGenerator;
    
    /**
     * Use separate thread pool for CPU-intensive report generation
     */
    @Bulkhead(name = "reportService", type = Bulkhead.Type.THREADPOOL)
    public CompletableFuture<Report> generateReport(ReportRequest request) {
        return CompletableFuture.supplyAsync(() -> {
            log.info("Generating report in dedicated thread pool: {}", 
                Thread.currentThread().getName());
            return reportGenerator.generate(request);
        });
    }
}

/**
 * Custom Bulkhead Configuration
 */
@Configuration
public class BulkheadConfiguration {
    
    @Bean
    public BulkheadRegistry bulkheadRegistry() {
        BulkheadConfig config = BulkheadConfig.custom()
            .maxConcurrentCalls(10)
            .maxWaitDuration(Duration.ofMillis(500))
            .build();
        
        return BulkheadRegistry.of(config);
    }
    
    @Bean
    public ThreadPoolBulkheadRegistry threadPoolBulkheadRegistry() {
        ThreadPoolBulkheadConfig config = ThreadPoolBulkheadConfig.custom()
            .maxThreadPoolSize(4)
            .coreThreadPoolSize(2)
            .queueCapacity(10)
            .keepAliveDuration(Duration.ofMillis(20))
            .build();
        
        return ThreadPoolBulkheadRegistry.of(config);
    }
}

/**
 * Bulkhead Event Monitoring
 */
@Component
@Slf4j
public class BulkheadEventListener {
    
    @Autowired
    public void registerEventListener(BulkheadRegistry registry) {
        registry.bulkhead("paymentService").getEventPublisher()
            .onCallRejected(event -> 
                log.warn("Bulkhead call rejected: {}", event.getBulkheadName()))
            .onCallPermitted(event -> 
                log.debug("Bulkhead call permitted: {}", event.getBulkheadName()))
            .onCallFinished(event -> 
                log.debug("Bulkhead call finished: {}", event.getBulkheadName()));
    }
}

/**
 * Programmatic Bulkhead usage
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ImageProcessingService {
    
    private final BulkheadRegistry bulkheadRegistry;
    private final ImageProcessor imageProcessor;
    
    public ProcessedImage processImage(Image image) {
        Bulkhead bulkhead = bulkheadRegistry.bulkhead("imageProcessing");
        
        Supplier<ProcessedImage> decoratedSupplier = Bulkhead.decorateSupplier(
            bulkhead,
            () -> imageProcessor.process(image)
        );
        
        try {
            return decoratedSupplier.get();
        } catch (BulkheadFullException e) {
            log.error("Image processing bulkhead is full");
            throw new ServiceUnavailableException(
                "Image processing service is at capacity. Please retry later.");
        }
    }
}
```

#### 4.2.5 Fallback Pattern

**Problem:** Provide graceful degradation when primary service fails.

**Solution:** Implement fallback mechanisms with cached data, default values, or alternative implementations.

```java
/**
 * Comprehensive Fallback Strategies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {
    
    private final ProductClient productClient;
    private final CacheManager cacheManager;
    private final ProductRepository productRepository;
    
    /**
     * Strategy 1: Return cached data
     */
    @CircuitBreaker(name = "productService", fallbackMethod = "getProductFromCache")
    @Cacheable(value = "products", key = "#productId")
    public Product getProduct(Long productId) {
        return productClient.findById(productId);
    }
    
    private Product getProductFromCache(Long productId, Exception ex) {
        log.warn("Primary service failed, attempting cache lookup for product: {}", 
            productId, ex);
        
        Cache cache = cacheManager.getCache("products");
        if (cache != null) {
            Product cached = cache.get(productId, Product.class);
            if (cached != null) {
                log.info("Returning cached product: {}", productId);
                return cached;
            }
        }
        
        // Last resort: database
        return getProductFromDatabase(productId, ex);
    }
    
    /**
     * Strategy 2: Fallback to database
     */
    private Product getProductFromDatabase(Long productId, Exception ex) {
        log.warn("Cache miss, falling back to database for product: {}", productId);
        
        return productRepository.findById(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));
    }
    
    /**
     * Strategy 3: Return default/degraded data
     */
    @CircuitBreaker(name = "recommendationService", 
                    fallbackMethod = "getDefaultRecommendations")
    public List<Product> getRecommendations(Long userId) {
        return productClient.getPersonalizedRecommendations(userId);
    }
    
    private List<Product> getDefaultRecommendations(Long userId, Exception ex) {
        log.warn("Recommendation service unavailable, returning popular products", ex);
        
        // Return popular/trending products instead of personalized ones
        return productRepository.findTopSellingProducts(PageRequest.of(0, 10));
    }
    
    /**
     * Strategy 4: Partial success (best effort)
     */
    @CircuitBreaker(name = "inventoryService", 
                    fallbackMethod = "getProductsWithPartialInventory")
    public List<ProductWithInventory> getProductsWithInventory(List<Long> productIds) {
        return productClient.getProductsWithInventory(productIds);
    }
    
    private List<ProductWithInventory> getProductsWithPartialInventory(
            List<Long> productIds, 
            Exception ex) {
        
        log.warn("Inventory service unavailable, returning products without inventory", ex);
        
        // Return products without inventory information (degraded service)
        List<Product> products = productRepository.findAllById(productIds);
        
        return products.stream()
            .map(product -> ProductWithInventory.builder()
                .product(product)
                .inventoryAvailable(false)
                .inventoryMessage("Inventory information temporarily unavailable")
                .build())
            .collect(Collectors.toList());
    }
}

/**
 * Fallback Chain - multiple fallback levels
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PricingService {
    
    private final PricingClient pricingClient;
    private final PricingCache pricingCache;
    private final PricingRepository pricingRepository;
    
    @CircuitBreaker(name = "pricingService", fallbackMethod = "getPriceFromCache")
    public BigDecimal getPrice(Long productId) {
        log.debug("Fetching price from primary service");
        return pricingClient.getCurrentPrice(productId);
    }
    
    // Fallback Level 1: Cache
    private BigDecimal getPriceFromCache(Long productId, Exception ex) {
        log.warn("Price service unavailable, checking cache");
        
        BigDecimal cachedPrice = pricingCache.get(productId);
        if (cachedPrice != null) {
            return cachedPrice;
        }
        
        // Continue to next fallback
        return getPriceFromDatabase(productId, ex);
    }
    
    // Fallback Level 2: Database
    private BigDecimal getPriceFromDatabase(Long productId, Exception ex) {
        log.warn("Cache miss, checking database");
        
        return pricingRepository.findLatestPrice(productId)
            .map(PriceHistory::getPrice)
            .orElseGet(() -> getDefaultPrice(productId, ex));
    }
    
    // Fallback Level 3: Default/Static value
    private BigDecimal getDefaultPrice(Long productId, Exception ex) {
        log.error("All price sources unavailable, returning default price");
        
        // Return a conservative default price
        return BigDecimal.valueOf(99.99);
    }
}

/**
 * Async Fallback with CompletableFuture
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {
    
    private final EmailService emailService;
    private final SmsService smsService;
    private final PushNotificationService pushService;
    
    /**
     * Try email, fallback to SMS, then push notification
     */
    public CompletableFuture<Boolean> notifyUser(User user, String message) {
        return sendEmail(user, message)
            .exceptionally(emailEx -> {
                log.warn("Email failed, trying SMS", emailEx);
                return sendSms(user, message).join();
            })
            .exceptionally(smsEx -> {
                log.warn("SMS failed, trying push notification", smsEx);
                return sendPushNotification(user, message).join();
            })
            .exceptionally(pushEx -> {
                log.error("All notification methods failed", pushEx);
                return false;
            });
    }
    
    private CompletableFuture<Boolean> sendEmail(User user, String message) {
        return CompletableFuture.supplyAsync(() -> 
            emailService.send(user.getEmail(), message));
    }
    
    private CompletableFuture<Boolean> sendSms(User user, String message) {
        return CompletableFuture.supplyAsync(() -> 
            smsService.send(user.getPhone(), message));
    }
    
    private CompletableFuture<Boolean> sendPushNotification(User user, String message) {
        return CompletableFuture.supplyAsync(() -> 
            pushService.send(user.getDeviceId(), message));
    }
}
```

#### 4.2.6 Combined Resiliency Pattern

**Best Practice:** Combine multiple patterns for robust fault tolerance.

```java
/**
 * Comprehensive resiliency with all patterns combined
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ResilientOrderService {
    
    private final OrderClient orderClient;
    private final OrderCache orderCache;
    
    /**
     * Stack multiple resilience patterns:
     * 1. Bulkhead - Isolate order service calls
     * 2. CircuitBreaker - Fail fast when service is down
     * 3. Retry - Retry transient failures
     * 4. TimeLimiter - Don't wait forever
     * 5. Fallback - Graceful degradation
     */
    @Bulkhead(name = "orderService", type = Bulkhead.Type.SEMAPHORE)
    @CircuitBreaker(name = "orderService", fallbackMethod = "getOrderFallback")
    @Retry(name = "orderService")
    @TimeLimiter(name = "orderService")
    @RateLimiter(name = "orderService")
    public CompletableFuture<Order> getOrder(Long orderId) {
        return CompletableFuture.supplyAsync(() -> {
            log.info("Fetching order: {}", orderId);
            return orderClient.findById(orderId);
        });
    }
    
    /**
     * Multi-level fallback strategy
     */
    private CompletableFuture<Order> getOrderFallback(Long orderId, Exception ex) {
        log.warn("Primary order service failed, trying fallback strategies", ex);
        
        // Try cache first
        Order cached = orderCache.get(orderId);
        if (cached != null) {
            log.info("Returning cached order: {}", orderId);
            return CompletableFuture.completedFuture(cached);
        }
        
        // Return partial order data
        log.warn("No cached data, returning limited order information");
        return CompletableFuture.completedFuture(
            Order.builder()
                .id(orderId)
                .status(OrderStatus.DATA_UNAVAILABLE)
                .message("Order details temporarily unavailable. Please try again later.")
                .build()
        );
    }
}

/**
 * Monitoring and Metrics for Resiliency
 */
@Component
@Slf4j
public class ResilienceMetricsExporter {
    
    @Autowired
    public void exportMetrics(
            CircuitBreakerRegistry circuitBreakerRegistry,
            RetryRegistry retryRegistry,
            BulkheadRegistry bulkheadRegistry,
            TimeLimiterRegistry timeLimiterRegistry) {
        
        // Circuit Breaker Metrics
        circuitBreakerRegistry.circuitBreaker("orderService")
            .getEventPublisher()
            .onStateTransition(event -> {
                log.info("CircuitBreaker[{}] state: {} -> {}", 
                    "orderService",
                    event.getStateTransition().getFromState(),
                    event.getStateTransition().getToState());
            });
        
        // Retry Metrics
        retryRegistry.retry("orderService")
            .getEventPublisher()
            .onRetry(event -> {
                log.info("Retry[{}] attempt: #{}", 
                    "orderService",
                    event.getNumberOfRetryAttempts());
            });
        
        // Bulkhead Metrics
        bulkheadRegistry.bulkhead("orderService")
            .getEventPublisher()
            .onCallRejected(event -> {
                log.warn("Bulkhead[{}] call rejected - at capacity", "orderService");
            });
    }
}

/**
 * Health Indicator for Circuit Breakers
 */
@Component
public class CircuitBreakerHealthIndicator implements HealthIndicator {
    
    @Autowired
    private CircuitBreakerRegistry circuitBreakerRegistry;
    
    @Override
    public Health health() {
        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("orderService");
        
        CircuitBreaker.State state = circuitBreaker.getState();
        Metrics metrics = circuitBreaker.getMetrics();
        
        Health.Builder builder = switch (state) {
            case CLOSED, HALF_OPEN -> Health.up();
            case OPEN, FORCED_OPEN -> Health.down();
            case DISABLED -> Health.unknown();
        };
        
        return builder
            .withDetail("state", state)
            .withDetail("failureRate", metrics.getFailureRate() + "%")
            .withDetail("slowCallRate", metrics.getSlowCallRate() + "%")
            .withDetail("bufferedCalls", metrics.getNumberOfBufferedCalls())
            .withDetail("failedCalls", metrics.getNumberOfFailedCalls())
            .withDetail("successfulCalls", metrics.getNumberOfSuccessfulCalls())
            .build();
    }
}
```

```yaml
# Complete Resiliency Configuration Example
resilience4j:
  circuitbreaker:
    configs:
      default:
        slidingWindowSize: 100
        minimumNumberOfCalls: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 10
        automaticTransitionFromOpenToHalfOpenEnabled: true
    instances:
      orderService:
        baseConfig: default
        slidingWindowSize: 50
        failureRateThreshold: 40
  
  retry:
    configs:
      default:
        maxAttempts: 3
        waitDuration: 1s
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2
    instances:
      orderService:
        baseConfig: default
        maxAttempts: 5
  
  bulkhead:
    configs:
      default:
        maxConcurrentCalls: 10
        maxWaitDuration: 500ms
    instances:
      orderService:
        baseConfig: default
        maxConcurrentCalls: 20
  
  timelimiter:
    configs:
      default:
        timeoutDuration: 5s
        cancelRunningFuture: true
    instances:
      orderService:
        baseConfig: default
        timeoutDuration: 3s
  
  ratelimiter:
    configs:
      default:
        limitForPeriod: 100
        limitRefreshPeriod: 1s
        timeoutDuration: 0s
    instances:
      orderService:
        baseConfig: default
        limitForPeriod: 50

# Actuator endpoints for monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,circuitbreakers,ratelimiters,retries,bulkheads,timelimiters
  endpoint:
    health:
      show-details: always
  health:
    circuitbreakers:
      enabled: true
```

### 4.3 Asynchronous Processing

#### Async Configuration

```java
/**
 * Async Configuration
 */
@Configuration
@EnableAsync
public class AsyncConfig {
    
    @Bean(name = "taskExecutor")
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(60);
        executor.initialize();
        return executor;
    }
    
    @Bean(name = "emailExecutor")
    public Executor emailExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("email-");
        executor.initialize();
        return executor;
    }
    
    /**
     * Async exception handler
     */
    @Bean
    public AsyncUncaughtExceptionHandler asyncExceptionHandler() {
        return (throwable, method, params) -> {
            log.error("Async method {} threw exception: {}",
                     method.getName(), throwable.getMessage(), throwable);
        };
    }
}

/**
 * Async service methods
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {
    
    /**
     * Fire-and-forget async method
     */
    @Async("emailExecutor")
    public void sendWelcomeEmail(User user) {
        log.info("Sending welcome email to: {}", user.getEmail());
        // Send email
        log.info("Welcome email sent to: {}", user.getEmail());
    }
    
    /**
     * Async method with CompletableFuture return
     */
    @Async("taskExecutor")
    public CompletableFuture<EmailResult> sendVerificationEmail(User user) {
        log.info("Sending verification email to: {}", user.getEmail());
        
        try {
            // Send email
            EmailResult result = emailClient.send(user.getEmail(), "Verification", "...");
            return CompletableFuture.completedFuture(result);
        } catch (Exception e) {
            log.error("Failed to send verification email", e);
            return CompletableFuture.failedFuture(e);
        }
    }
    
    /**
     * Parallel async operations
     */
    public CompletableFuture<UserNotificationResult> sendAllNotifications(User user) {
        CompletableFuture<EmailResult> emailFuture = sendVerificationEmail(user);
        CompletableFuture<SmsResult> smsFuture = sendVerificationSms(user);
        CompletableFuture<PushResult> pushFuture = sendPushNotification(user);
        
        return CompletableFuture.allOf(emailFuture, smsFuture, pushFuture)
            .thenApply(v -> UserNotificationResult.builder()
                .emailResult(emailFuture.join())
                .smsResult(smsFuture.join())
                .pushResult(pushFuture.join())
                .build());
    }
}
```

#### CompletableFuture Best Practices

```java
@Service
@RequiredArgsConstructor
public class OrderProcessingService {
    
    /**
     * Sequential async processing
     */
    public CompletableFuture<Order> processOrder(CreateOrderRequest request) {
        return validateOrder(request)
            .thenCompose(this::createOrder)
            .thenCompose(this::processPayment)
            .thenCompose(this::sendConfirmation)
            .exceptionally(ex -> {
                log.error("Order processing failed", ex);
                return handleOrderFailure(ex);
            });
    }
    
    /**
     * Parallel async processing
     */
    public CompletableFuture<OrderSummary> getOrderSummary(Long orderId) {
        CompletableFuture<Order> orderFuture = getOrder(orderId);
        CompletableFuture<List<OrderLine>> linesFuture = getOrderLines(orderId);
        CompletableFuture<Payment> paymentFuture = getPaymentInfo(orderId);
        CompletableFuture<Shipment> shipmentFuture = getShipmentInfo(orderId);
        
        return CompletableFuture.allOf(
                orderFuture, linesFuture, paymentFuture, shipmentFuture)
            .thenApply(v -> OrderSummary.builder()
                .order(orderFuture.join())
                .orderLines(linesFuture.join())
                .payment(paymentFuture.join())
                .shipment(shipmentFuture.join())
                .build())
            .orTimeout(10, TimeUnit.SECONDS)
            .handle((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to get order summary", ex);
                    throw new OrderProcessingException("Failed to get order summary", ex);
                }
                return result;
            });
    }
    
    /**
     * Async with timeout and fallback
     */
    public CompletableFuture<PriceQuote> getPriceQuote(String product) {
        return CompletableFuture.supplyAsync(() -> externalPricingService.getQuote(product))
            .orTimeout(3, TimeUnit.SECONDS)
            .exceptionally(ex -> {
                log.warn("Price quote timeout, using fallback");
                return getDefaultPriceQuote(product);
            });
    }
}
```

---

## 5. Monitoring & Logging

### 5.0 Required Guidelines (Normative)

#### 5.0.1 Actuator and Resource-Specific Health Checks

- Enable liveness and readiness probes for containerized deployments.
- Publish resource-specific health indicators for database, cache, message broker, external APIs, and storage.
- Health responses must include actionable diagnostics (latency, dependency state, last successful check).
- Separate internal detailed health information from public endpoints using role-based access.
- Include resilience state in health where appropriate (for example, circuit breaker state for critical downstreams).

#### 5.0.2 Application Capability Logging

- Log capability-level business events, not only technical events (for example: `order.created`, `payment.authorized`, `quote.expired`).
- Define a stable event taxonomy with `eventName`, `capability`, `outcome`, `reasonCode`, and `businessKey` fields.
- Emit lifecycle logs for each capability operation: `started`, `succeeded`, `failed`, and `compensated` when applicable.
- Keep payloads privacy-safe: redact or hash sensitive attributes; never log secrets.
- Correlate capability logs to traces and metrics using `traceId`, `spanId`, and `correlationId`.
- Route capability logs to analytics/observability backends with retention policies aligned to audit requirements.

#### 5.0.3 Logging, OpenTelemetry, Distributed Tracing, and Metrics

- Use structured JSON logging as the default log format in non-local environments.
- Standardize log fields: timestamp, severity, service, environment, version, correlation ID, trace ID, span ID, and message.
- Adopt OpenTelemetry auto-instrumentation first; use manual spans only for key business boundaries.
- Capture RED metrics (Rate, Errors, Duration) for APIs and USE metrics (Utilization, Saturation, Errors) for resources.
- Publish Micrometer metrics to Prometheus (or enterprise equivalent) and define SLO-driven alerts.
- Sample traces intelligently (tail or head sampling) to control telemetry cost while preserving incident fidelity.
- Ensure every production incident can be triaged using the three pillars together: logs, metrics, traces.

### 5.1 Spring Boot Actuator

#### Actuator Configuration

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus,env,loggers
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      show-components: when-authorized
      probes:
        enabled: true
    metrics:
      enabled: true
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${spring.profiles.active}
  health:
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true

# Info endpoint
info:
  app:
    name: ${spring.application.name}
    version: @project.version@
    description: @project.description@
    java-version: @java.version@
```

#### Custom Health Indicators

```java
/**
 * Custom health indicator for external service
 */
@Component
public class ExternalApiHealthIndicator implements HealthIndicator {
    
    private final RestClient restClient;
    private final String apiUrl;
    
    public ExternalApiHealthIndicator(
            RestClient restClient,
            @Value("${app.external-api.url}") String apiUrl) {
        this.restClient = restClient;
        this.apiUrl = apiUrl;
    }
    
    @Override
    public Health health() {
        try {
            long start = System.currentTimeMillis();
            ResponseEntity<Void> response = restClient.get()
                .uri(apiUrl + "/health")
                .retrieve()
                .toBodilessEntity();
            long duration = System.currentTimeMillis() - start;
            
            if (response.getStatusCode().is2xxSuccessful()) {
                return Health.up()
                    .withDetail("url", apiUrl)
                    .withDetail("responseTime", duration + "ms")
                    .withDetail("status", response.getStatusCode())
                    .build();
            } else {
                return Health.down()
                    .withDetail("url", apiUrl)
                    .withDetail("status", response.getStatusCode())
                    .withDetail("reason", "Non-2xx response")
                    .build();
            }
        } catch (Exception e) {
            return Health.down()
                .withDetail("url", apiUrl)
                .withDetail("error", e.getMessage())
                .withException(e)
                .build();
        }
    }
}

/**
 * Resource-specific health indicator
 */
@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    
    private final DataSource dataSource;
    
    public DatabaseHealthIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }
    
    @Override
    public Health health() {
        try (Connection connection = dataSource.getConnection()) {
            if (connection.isValid(1)) {
                DatabaseMetaData metaData = connection.getMetaData();
                return Health.up()
                    .withDetail("database", metaData.getDatabaseProductName())
                    .withDetail("version", metaData.getDatabaseProductVersion())
                    .withDetail("validationQuery", "connection.isValid(1)")
                    .build();
            } else {
                return Health.down()
                    .withDetail("error", "Connection validation failed")
                    .build();
            }
        } catch (SQLException e) {
            return Health.down()
                .withDetail("error", e.getMessage())
                .withException(e)
                .build();
        }
    }
}
```

### 5.2 Structured Logging

#### Logback Configuration

```xml
<!-- logback-spring.xml -->
<configuration>
    
    <!-- Console appender with JSON format -->
    <appender name="CONSOLE_JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <customFields>
                {
                    "application": "${spring.application.name}",
                    "environment": "${spring.profiles.active}"
                }
            </customFields>
            <fieldNames>
                <timestamp>timestamp</timestamp>
                <message>message</message>
                <logger>logger</logger>
                <thread>thread</thread>
                <level>level</level>
                <levelValue>[ignore]</levelValue>
            </fieldNames>
            <throwableConverter class="net.logstash.logback.stacktrace.ShortenedThrowableConverter">
                <maxDepthPerThrowable>30</maxDepthPerThrowable>
                <maxLength>2048</maxLength>
                <shortenedClassNameLength>20</shortenedClassNameLength>
                <rootCauseFirst>true</rootCauseFirst>
            </throwableConverter>
        </encoder>
    </appender>
    
    <!-- File appender -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/application.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/application-%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <timeBasedFileNamingAndTriggeringPolicy 
                class="ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP">
                <maxFileSize>100MB</maxFileSize>
            </timeBasedFileNamingAndTriggeringPolicy>
            <maxHistory>30</maxHistory>
            <totalSizeCap>10GB</totalSizeCap>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
    </appender>
    
    <!-- Async appender for better performance -->
    <appender name="ASYNC" class="ch.qos.logback.classic.AsyncAppender">
        <queueSize>512</queueSize>
        <discardingThreshold>0</discardingThreshold>
        <appender-ref ref="FILE"/>
    </appender>
    
    <!-- Logger levels -->
    <logger name="com.company.application" level="DEBUG"/>
    <logger name="org.springframework.web" level="INFO"/>
    <logger name="org.hibernate.SQL" level="DEBUG"/>
    <logger name="org.hibernate.type.descriptor.sql.BasicBinder" level="TRACE"/>
    
    <root level="INFO">
        <appender-ref ref="CONSOLE_JSON"/>
        <appender-ref ref="ASYNC"/>
    </root>
    
</configuration>
```

#### Apache Log4j2 JSON Configuration

```xml
<!-- log4j2-spring.xml - Apache JSON logging baseline -->
<Configuration status="WARN">
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <JsonTemplateLayout eventTemplateUri="classpath:EcsLayout.json"/>
        </Console>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="Console"/>
        </Root>
    </Loggers>
</Configuration>
```

#### Structured Logging in Code

```java
/**
 * Structured logging with MDC (Mapped Diagnostic Context)
 */
@RestController
@RequiredArgsConstructor
@Slf4j
public class UserController {
    
    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUser(@PathVariable Long id) {
        // Add context to all logs in this request
        MDC.put("userId", String.valueOf(id));
        MDC.put("operation", "getUser");
        
        try {
            log.info("Fetching user");
            User user = userService.findById(id);
            log.info("User found successfully");
            return ResponseEntity.ok(userMapper.toResponse(user));
        } catch (UserNotFoundException e) {
            log.warn("User not found");
            throw e;
        } finally {
            MDC.clear();
        }
    }
}

/**
 * MDC Filter for request tracking
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MDCFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        try {
            // Generate or extract correlation ID
            String correlationId = request.getHeader("X-Correlation-ID");
            if (correlationId == null) {
                correlationId = UUID.randomUUID().toString();
            }
            
            // Add to MDC for all logs in this request
            MDC.put("correlationId", correlationId);
            MDC.put("requestUri", request.getRequestURI());
            MDC.put("requestMethod", request.getMethod());
            MDC.put("remoteAddr", request.getRemoteAddr());
            
            // Add correlation ID to response header
            response.setHeader("X-Correlation-ID", correlationId);
            
            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}

/**
 * Structured logging with markers
 */
@Service
@Slf4j
public class PaymentService {
    
    private static final Marker SECURITY_MARKER = MarkerFactory.getMarker("SECURITY");
    private static final Marker PAYMENT_MARKER = MarkerFactory.getMarker("PAYMENT");
    
    public void processPayment(Payment payment) {
        log.info(PAYMENT_MARKER, 
                "Processing payment: amount={}, currency={}",
                payment.getAmount(), payment.getCurrency());
        
        if (isFraudulent(payment)) {
            log.warn(SECURITY_MARKER,
                    "Fraudulent payment detected: paymentId={}, amount={}",
                    payment.getId(), payment.getAmount());
            throw new FraudException("Fraudulent payment detected");
        }
        
        // Process payment
    }
}
```

### 5.3 OpenTelemetry and Distributed Tracing

```java
/**
 * OpenTelemetry Configuration
 */
@Configuration
public class OpenTelemetryConfig {
    
    @Bean
    public OpenTelemetry openTelemetry() {
        Resource resource = Resource.getDefault()
            .merge(Resource.create(Attributes.of(
                ResourceAttributes.SERVICE_NAME, "user-service",
                ResourceAttributes.SERVICE_VERSION, "1.0.0"
            )));
        
        SdkTracerProvider sdkTracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(BatchSpanProcessor.builder(
                OtlpGrpcSpanExporter.builder()
                    .setEndpoint("http://localhost:4317")
                    .build()
            ).build())
            .setResource(resource)
            .build();
        
        SdkMeterProvider sdkMeterProvider = SdkMeterProvider.builder()
            .registerMetricReader(PeriodicMetricReader.builder(
                OtlpGrpcMetricExporter.builder()
                    .setEndpoint("http://localhost:4317")
                    .build()
            ).setInterval(Duration.ofSeconds(60)).build())
            .setResource(resource)
            .build();
        
        return OpenTelemetrySdk.builder()
            .setTracerProvider(sdkTracerProvider)
            .setMeterProvider(sdkMeterProvider)
            .setPropagators(ContextPropagators.create(
                B3Propagator.injectingSingleHeader()))
            .buildAndRegisterGlobal();
    }
}

/**
 * Custom spans and metrics
 */
@Service
@RequiredArgsConstructor
public class UserService {
    
    private final Tracer tracer;
    private final Meter meter;
    private final LongCounter userCreatedCounter;
    private final LongHistogram userProcessingTime;
    
    @PostConstruct
    public void init() {
        userCreatedCounter = meter
            .counterBuilder("users.created")
            .setDescription("Number of users created")
            .build();
        
        userProcessingTime = meter
            .histogramBuilder("users.processing.time")
            .setDescription("User processing time in milliseconds")
            .ofLongs()
            .build();
    }
    
    public User createUser(CreateUserRequest request) {
        Span span = tracer.spanBuilder("createUser")
            .setAttribute("user.email", request.getEmail())
            .startSpan();
        
        long startTime = System.currentTimeMillis();
        
        try (Scope scope = span.makeCurrent()) {
            // Validate
            Span validationSpan = tracer.spanBuilder("validateUser")
                .startSpan();
            try {
                validateUser(request);
            } finally {
                validationSpan.end();
            }
            
            // Create user
            User user = userRepository.save(createUserEntity(request));
            
            // Record metrics
            userCreatedCounter.add(1);
            userProcessingTime.record(System.currentTimeMillis() - startTime);
            
            span.setAttribute("user.id", user.getId());
            span.setStatus(StatusCode.OK);
            
            return user;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
}
```

### 5.4 Application Metrics

```java
/**
 * Micrometer metrics
 */
@Service
@RequiredArgsConstructor
public class MetricsService {
    
    private final MeterRegistry meterRegistry;
    
    /**
     * Counter - monotonically increasing value
     */
    public void recordUserCreated() {
        meterRegistry.counter("users.created",
                "type", "registration",
                "status", "success")
            .increment();
    }
    
    /**
     * Gauge - current value that can go up or down
     */
    public void registerActiveUsersGauge(UserRepository userRepository) {
        Gauge.builder("users.active", userRepository, repo -> repo.countByStatus(UserStatus.ACTIVE))
            .description("Number of active users")
            .register(meterRegistry);
    }
    
    /**
     * Timer - measure duration and rate
     */
    public void recordOperationTime(String operation, Runnable task) {
        Timer timer = meterRegistry.timer("operation.duration",
                "operation", operation);
        timer.record(task);
    }
    
    /**
     * Distribution summary - statistical distribution of values
     */
    public void recordOrderAmount(BigDecimal amount) {
        meterRegistry.summary("order.amount",
                "currency", "USD")
            .record(amount.doubleValue());
    }
    
    /**
     * Long task timer - measure duration of long-running tasks
     */
    public void processLongRunningTask() {
        LongTaskTimer timer = meterRegistry.more().longTaskTimer("batch.processing");
        LongTaskTimer.Sample sample = timer.start();
        
        try {
            // Long running task
        } finally {
            sample.stop();
        }
    }
}

/**
 * Custom metrics with aspects
 */
@Aspect
@Component
@RequiredArgsConstructor
public class MetricsAspect {
    
    private final MeterRegistry meterRegistry;
    
    @Around("@annotation(timed)")
    public Object timeMethod(ProceedingJoinPoint pjp, Timed timed) throws Throwable {
        String methodName = pjp.getSignature().toShortString();
        
        return Timer.builder(timed.value())
            .description("Execution time of " + methodName)
            .tag("class", pjp.getTarget().getClass().getSimpleName())
            .tag("method", pjp.getSignature().getName())
            .register(meterRegistry)
            .recordCallable(() -> {
                try {
                    return pjp.proceed();
                } catch (Throwable e) {
                    throw new RuntimeException(e);
                }
            });
    }
    
    @AfterReturning("@annotation(counted)")
    public void countMethod(JoinPoint jp, Counted counted) {
        meterRegistry.counter(counted.value(),
                "class", jp.getTarget().getClass().getSimpleName(),
                "method", jp.getSignature().getName())
            .increment();
    }
}
```

---

## 6. Testing Standards

### 6.0 Test Coverage Requirements (NON-NEGOTIABLE)

#### Coverage Gates

**Current Baselines** (NON-NEGOTIABLE, build-enforced):
> Define project-specific baseline values here and enforce them via JaCoCo build rules. Baselines are established from the current codebase and must never be permitted to drop.

**New/Modified Code Gate** (NON-NEGOTIABLE):

- ≥ 90% line coverage on new/modified code
- ≥ 90% branch coverage when new/modified logic includes conditionals
- ≥ 90% instruction coverage for new/modified public methods

**Zero Tolerance**:

- Baseline coverage drops trigger immediate build failure
- New/modified code below the ≥ 90% gate blocks PR approval
- No exceptions without architecture board approval

---

### 6.1 Test Pyramid

```
                    /\
                   /  \
                  / E2E \ (Few)        End-to-End (5%) - Full system tests
                 /______\
                /        \
               /Integration\ (Some)    Integration (15%) - Component interaction
              /____________\
             /              \
            /  Unit Tests    \ (Many)  Unit Tests (80%) - Individual units
           /__________________\
```

### 6.2 Unit Testing

**Goal:** Test individual components in isolation.

```java
/**
 * Unit test for service class
 */
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    
    @Mock
    private UserRepository userRepository;
    
    @Mock
    private EmailService emailService;
    
    @Mock
    private ApplicationEventPublisher eventPublisher;
    
    @InjectMocks
    private UserService userService;
    
    @Test
    @DisplayName("Should create user successfully")
    void shouldCreateUserSuccessfully() {
        // Given
        CreateUserRequest request = CreateUserRequest.builder()
            .email("test@example.com")
            .firstName("John")
            .lastName("Doe")
            .build();
        
        User savedUser = User.builder()
            .id(1L)
            .email(request.getEmail())
            .firstName(request.getFirstName())
            .lastName(request.getLastName())
            .status(UserStatus.ACTIVE)
            .build();
        
        when(userRepository.existsByEmail(request.getEmail())).thenReturn(false);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);
        
        // When
        User result = userService.createUser(request);
        
        // Then
        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals("test@example.com", result.getEmail());
        assertEquals(UserStatus.ACTIVE, result.getStatus());
        
        verify(userRepository).existsByEmail(request.getEmail());
        verify(userRepository).save(any(User.class));
        verify(eventPublisher).publishEvent(any(UserCreatedEvent.class));
        verify(emailService).sendWelcomeEmail(savedUser);
    }
    
    @Test
    @DisplayName("Should throw exception when email already exists")
    void shouldThrowExceptionWhenEmailExists() {
        // Given
        CreateUserRequest request = CreateUserRequest.builder()
            .email("existing@example.com")
            .firstName("John")
            .lastName("Doe")
            .build();
        
        when(userRepository.existsByEmail(request.getEmail())).thenReturn(true);
        
        // When & Then
        assertThrows(DuplicateEmailException.class, () -> {
            userService.createUser(request);
        });
        
        verify(userRepository).existsByEmail(request.getEmail());
        verify(userRepository, never()).save(any(User.class));
        verify(emailService, never()).sendWelcomeEmail(any(User.class));
    }
    
    @Test
    @DisplayName("Should find user by ID")
    void shouldFindUserById() {
        // Given
        Long userId = 1L;
        User user = User.builder()
            .id(userId)
            .email("test@example.com")
            .build();
        
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        
        // When
        User result = userService.findById(userId);
        
        // Then
        assertNotNull(result);
        assertEquals(userId, result.getId());
        verify(userRepository).findById(userId);
    }
    
    @Test
    @DisplayName("Should throw exception when user not found")
    void shouldThrowExceptionWhenUserNotFound() {
        // Given
        Long userId = 999L;
        when(userRepository.findById(userId)).thenReturn(Optional.empty());
        
        // When & Then
        assertThrows(UserNotFoundException.class, () -> {
            userService.findById(userId);
        });
        
        verify(userRepository).findById(userId);
    }
}
```

### 6.3 Integration Testing

**Goal:** Test integration between components with real dependencies.

```java
/**
 * Integration test with test containers
 */
@SpringBootTest
@Testcontainers
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:tc:postgresql:15:///testdb",
    "spring.jpa.hibernate.ddl-auto=create-drop"
})
class UserServiceIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");
    
    @Autowired
    private UserService userService;
    
    @Autowired
    private UserRepository userRepository;
    
    @MockBean
    private EmailService emailService;  // Mock external service
    
    @MockBean
    private ApplicationEventPublisher eventPublisher;
    
    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }
    
    @Test
    @DisplayName("Should create user and persist to database")
    void shouldCreateUserAndPersist() {
        // Given
        CreateUserRequest request = CreateUserRequest.builder()
            .email("integration@test.com")
            .firstName("Integration")
            .lastName("Test")
            .build();
        
        // When
        User createdUser = userService.createUser(request);
        
        // Then
        assertNotNull(createdUser.getId());
        
        // Verify persisted in database
        User foundUser = userRepository.findById(createdUser.getId()).orElseThrow();
        assertEquals("integration@test.com", foundUser.getEmail());
        assertEquals("Integration", foundUser.getFirstName());
        assertEquals("Test", foundUser.getLastName());
        assertEquals(UserStatus.ACTIVE, foundUser.getStatus());
        assertNotNull(foundUser.getCreatedAt());
    }
    
    @Test
    @DisplayName("Should enforce unique email constraint")
    void shouldEnforceUniqueEmailConstraint() {
        // Given - create first user
        CreateUserRequest request1 = CreateUserRequest.builder()
            .email("unique@test.com")
            .firstName("First")
            .lastName("User")
            .build();
        userService.createUser(request1);
        
        // When - try to create second user with same email
        CreateUserRequest request2 = CreateUserRequest.builder()
            .email("unique@test.com")
            .firstName("Second")
            .lastName("User")
            .build();
        
        // Then
        assertThrows(DuplicateEmailException.class, () -> {
            userService.createUser(request2);
        });
    }
    
    @Test
    @DisplayName("Should handle transaction rollback on error")
    @Transactional
    void shouldRollbackOnError() {
        // Given
        CreateUserRequest request = CreateUserRequest.builder()
            .email("rollback@test.com")
            .firstName("Rollback")
            .lastName("Test")
            .build();
        
        // Mock email service to throw exception
        doThrow(new RuntimeException("Email service unavailable"))
            .when(emailService).sendWelcomeEmail(any(User.class));
        
        // When & Then
        assertThrows(RuntimeException.class, () -> {
            userService.createUser(request);
        });
        
        // Verify user was not persisted due to rollback
        assertFalse(userRepository.findByEmail("rollback@test.com").isPresent());
    }
}
```

### 6.4 Contract Testing (Consumer-Driven Contracts)

**Goal:** Verify API contracts between microservices.

```java
/**
 * Provider side - REST controller test with Spring Cloud Contract
 */
@WebMvcTest(UserController.class)
@AutoConfigureRestDocs
@AutoConfigureMockMvc
public class UserContractTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @MockBean
    private UserService userService;
    
    @Test
    public void shouldReturnUserWhenGetUserById() throws Exception {
        // Given
        User user = User.builder()
            .id(1L)
            .email("test@example.com")
            .firstName("John")
            .lastName("Doe")
            .status(UserStatus.ACTIVE)
            .build();
        
        when(userService.findById(1L)).thenReturn(user);
        
        // When & Then
        mockMvc.perform(get("/api/v1/users/1")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("test@example.com"))
            .andExpect(jsonPath("$.firstName").value("John"))
            .andExpect(jsonPath("$.lastName").value("Doe"))
            .andExpect(jsonPath("$.status").value("ACTIVE"))
            .andDo(document("get-user-by-id"));
    }
}
```

### 6.5 End-to-End Testing

**Goal:** Test complete user workflows across multiple services.

```java
/**
 * E2E test for order flow
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureWebTestClient
@Testcontainers
class OrderE2ETest {
    
    @LocalServerPort
    private int port;
    
    @Autowired
    private WebTestClient webTestClient;
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @BeforeEach
    void setUp() {
        webTestClient = webTestClient.mutate()
            .baseUrl("http://localhost:" + port)
            .build();
    }
    
    @Test
    @DisplayName("Complete order flow: create user -> create order -> pay -> ship")
    void completeOrderFlow() {
        // Step 1: Create user
        CreateUserRequest userRequest = CreateUserRequest.builder()
            .email("e2e@test.com")
            .firstName("E2E")
            .lastName("Test")
            .build();
        
        EntityExchangeResult<UserResponse> userResponse = webTestClient.post()
            .uri("/api/v1/users")
            .bodyValue(userRequest)
            .exchange()
            .expectStatus().isCreated()
            .expectBody(UserResponse.class)
            .returnResult();
        
        Long userId = userResponse.getResponseBody().getId();
        
        // Step 2: Create order
        CreateOrderRequest orderRequest = CreateOrderRequest.builder()
            .customerId(userId)
            .items(List.of(
                OrderItemRequest.builder()
                    .productId(1L)
                    .quantity(2)
                    .price(BigDecimal.valueOf(50.00))
                    .build()
            ))
            .shippingAddress("123 Test St")
            .build();
        
        EntityExchangeResult<OrderResponse> orderResponse = webTestClient.post()
            .uri("/api/v1/orders")
            .bodyValue(orderRequest)
            .exchange()
            .expectStatus().isCreated()
            .expectBody(OrderResponse.class)
            .returnResult();
        
        Long orderId = orderResponse.getResponseBody().getId();
        assertEquals(OrderStatus.PENDING, orderResponse.getResponseBody().getStatus());
        
        // Step 3: Process payment
        PaymentRequest paymentRequest = PaymentRequest.builder()
            .orderId(orderId)
            .paymentMethod("CREDIT_CARD")
            .amount(BigDecimal.valueOf(100.00))
            .build();
        
        webTestClient.post()
            .uri("/api/v1/payments")
            .bodyValue(paymentRequest)
            .exchange()
            .expectStatus().isOk();
        
        // Step 4: Verify order status updated to PAID
        EntityExchangeResult<OrderResponse> updatedOrder = webTestClient.get()
            .uri("/api/v1/orders/{orderId}", orderId)
            .exchange()
            .expectStatus().isOk()
            .expectBody(OrderResponse.class)
            .returnResult();
        
        assertEquals(OrderStatus.PAID, updatedOrder.getResponseBody().getStatus());
        
        // Step 5: Ship order
        webTestClient.post()
            .uri("/api/v1/orders/{orderId}/ship", orderId)
            .exchange()
            .expectStatus().is2xxSuccessful();
        
        // Step 6: Verify order status updated to SHIPPED
        EntityExchangeResult<OrderResponse> shippedOrder = webTestClient.get()
            .uri("/api/v1/orders/{orderId}", orderId)
            .exchange()
            .expectStatus().isOk()
            .expectBody(OrderResponse.class)
            .returnResult();
        
        assertEquals(OrderStatus.SHIPPED, shippedOrder.getResponseBody().getStatus());
        assertNotNull(shippedOrder.getResponseBody().getShipmentId());
    }
}
```

### 6.6 Comprehensive Deep Testing (NON-NEGOTIABLE)

**Philosophy**: Tests must validate complete behavior, not just existence. Surface-level testing is insufficient — every test must prove the full outcome.

#### Shallow vs. Deep Assertions

❌ **AVOID — Shallow assertions (UNACCEPTABLE)**:

```java
@Test
void testGetEntity() {
    Entity entity = repository.findById(1L);
    assertThat(entity).isNotNull();  // Only checks existence!
}
```

✅ **REQUIRED — Comprehensive validation**:

```java
@Test
@DisplayName("Should retrieve complete entity with all relationships populated")
void shouldRetrieveCompleteEntityWithAllRelationshipsPopulated() {
    // Arrange
    Long entityId = 1L;

    // Act
    Optional<Entity> result = repository.findById(entityId);

    // Assert - Validate existence
    assertThat(result).isPresent();

    // Assert - Validate all properties
    Entity entity = result.get();
    assertThat(entity.getId()).isEqualTo(entityId);
    assertThat(entity.getName()).isNotBlank();
    assertThat(entity.getCreatedDate()).isNotNull();
    assertThat(entity.getCreatedDate()).isBefore(LocalDateTime.now());

    // Assert - Validate relationships
    assertThat(entity.getRelatedEntities()).isNotNull();
    assertThat(entity.getRelatedEntities()).hasSize(3);
    assertThat(entity.getRelatedEntities().get(0).getId()).isNotNull();

    // Assert - Validate business rules
    assertThat(entity.isActive()).isTrue();
    assertThat(entity.calculateStatus()).isEqualTo(Status.VALID);
}
```

#### Validation Checklist for Every Test

- [ ] Object existence validated
- [ ] All properties validated (not just IDs)
- [ ] Collections validated (size AND contents)
- [ ] Relationships validated (both directions if bidirectional)
- [ ] Business logic outcomes validated
- [ ] Edge cases and boundaries tested
- [ ] Exception scenarios validated (type, message, cause)

### 6.7 Real Objects Over Mocks

**Philosophy**: Favor real objects to ensure actual behavior is tested. Mocks should be reserved for components that cannot reasonably be instantiated in a test environment.

#### Mock Only

- External database connections (use Testcontainers instead)
- External services and APIs
- Complex framework components
- Time/date providers (for deterministic tests)

#### Prefer Real Objects For

- JPA entities
- DTOs and projections
- Value objects
- Collections and data structures
- Domain objects

❌ **AVOID — Over-mocking domain objects**:

```java
@Mock
private User mockUser;

@Test
void testSomething() {
    when(mockUser.getName()).thenReturn("Test");
    when(mockUser.getEmail()).thenReturn("test@example.com");
    // ... excessive mocking of plain domain state
}
```

✅ **PREFERRED — Real domain objects**:

```java
@Test
void testSomething() {
    User user = User.builder()
            .name("Test")
            .email("test@example.com")
            .roles(List.of("USER", "ADMIN"))
            .createdDate(LocalDateTime.now())
            .build();

    // Test with real object
}
```

### 6.8 Repository Testing Excellence (NON-NEGOTIABLE)

**Philosophy**: JPA repositories are a core concern. They must be tested against a real database — never an in-memory substitute.

#### Repository Testing Standards

- **Always use Testcontainers** with the target database engine (e.g., MSSQL, PostgreSQL)
- **Never use H2** or other in-memory databases for repository tests
- Test all custom queries (JPQL and native SQL)
- Test all projections and DTO mappings
- Verify cascade operations
- Test transaction boundaries
- Validate constraint violations
- Test query correctness with realistic data volumes

#### Example — Comprehensive Repository Integration Test

```java
@SpringBootTest(classes = TestApplication.class)
@Testcontainers
@Transactional
@DisplayName("UserRepository Integration Tests")
class UserRepositoryIT extends BaseIntegrationTest {

    // Singleton container lifecycle managed by BaseIntegrationTest / TestcontainersInitializer

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private PermissionRepository permissionRepository;

    private User testUser;

    @BeforeEach
    void setUpTestData() {
        testUser = TestDataBuilders.createUser("12345678", "John", "Doe");
        testUser = userRepository.save(testUser);
    }

    @Test
    @DisplayName("Should save new user with all required fields")
    void shouldSaveNewUserWithAllRequiredFields() {
        // Arrange
        User newUser = TestDataBuilders.createUser("87654321", "Jane", "Smith");
        newUser.setEmail("jane.smith@example.com");

        // Act
        User savedUser = userRepository.save(newUser);

        // Assert - Deep validation using custom assertions
        UserAssertions.assertThat(savedUser)
                .hasValidEmployeeNumber()
                .hasValidEmail()
                .hasCompleteProfile()
                .isActive();
    }

    @Test
    @DisplayName("Should find active roles and permissions by employee number with complete projection")
    void shouldFindActiveRolesPermissionsByEmployeeNumberWithCompleteProjection() {
        // Arrange - Create role, permission, and assign to user
        Role role = roleRepository.save(TestDataBuilders.createRole("Admin", 100));
        Permission permission = permissionRepository.save(
                TestDataBuilders.createPermission("VIEW_BIDS", "BID_MANAGEMENT"));

        RolePermission rolePermission = TestDataBuilders.createRolePermission(role, permission);
        rolePermissionRepository.save(rolePermission);

        UserRole userRole = TestDataBuilders.createUserRole(testUser, role);
        userRoleRepository.save(userRole);

        // Act
        List<UserRolePermissionProjection> projections =
                userRepository.findActiveRolesPermissionsByEmployeeNumber("12345678");

        // Assert - Validate all projection fields
        assertThat(projections).isNotEmpty();
        UserRolePermissionProjection projection = projections.get(0);
        assertThat(projection.getEmployeeNumber()).isEqualTo("12345678");
        assertThat(projection.getFirstName()).isEqualTo("John");
        assertThat(projection.getRoleName()).isEqualTo("Admin");
        assertThat(projection.getPermissionKey()).isEqualTo("VIEW_BIDS");
        // Validate all remaining projection fields...
    }
}
```

### 6.9 Entity and JPA Testing Standards (NON-NEGOTIABLE)

**Philosophy**: Entities are the foundation of data persistence. They must be correctly designed and thoroughly tested against real persistence behavior.

#### Entity Design Standards

- Use `@Entity` and `@Table` with explicit names
- Always declare `@Id` with an explicit generation strategy
- Use `@Column` with constraints (`nullable`, `length`, `unique`)
- Implement `equals()` and `hashCode()` based on business keys, not surrogate IDs
- Use `@Version` for optimistic locking on mutable entities
- Specify `cascade` and `fetch` types explicitly on every relationship
- Document relationships with inline comments
- Use `@CreationTimestamp` / `@UpdateTimestamp` for audit timestamps

#### Entity Testing Standards

- Test persistence (save) and retrieval (findById) round-trips
- Test all relationship types: one-to-one, one-to-many, many-to-many
- Test cascade operations (persist, merge, remove)
- Test lazy-loading behavior and N+1 avoidance
- Test constraint violations (null, length, unique)
- Verify `equals()` / `hashCode()` consistency across transient, persistent, and detached states
- Test entity lifecycle callbacks (`@PrePersist`, `@PreUpdate`, etc.)

### 6.10 Performance Testing

```java
/**
 * Performance test using JMH
 */
@State(Scope.Benchmark)
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@Warmup(iterations = 2, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(1)
public class UserServicePerformanceTest {
    
    private UserService userService;
    private UserRepository userRepository;
    
    @Setup
    public void setup() {
        // Initialize with in-memory database
        userRepository = mock(UserRepository.class);
        userService = new UserService(userRepository, mock(EmailService.class));
        
        // Pre-populate with test data
        when(userRepository.findById(anyLong())).thenReturn(
            Optional.of(User.builder().id(1L).email("test@example.com").build())
        );
    }
    
    @Benchmark
    public User testFindUserById() {
        return userService.findById(1L);
    }
    
    @Benchmark
    public User testCreateUser() {
        CreateUserRequest request = CreateUserRequest.builder()
            .email("benchmark@test.com")
            .firstName("Benchmark")
            .lastName("Test")
            .build();
        
        when(userRepository.save(any(User.class))).thenReturn(
            User.builder().id(1L).email(request.getEmail()).build()
        );
        
        return userService.createUser(request);
    }
}
```

### 6.11 Test Infrastructure Components

**Philosophy**: Shared test infrastructure reduces duplication and enforces consistent test setup patterns across all integration tests.

#### Base Integration Test Class: `BaseIntegrationTest` (abstract)

- Uses `@SpringBootTest` with `TestApplication` (not `@DataJpaTest` — required for Spring Boot 3.x+)
- Testcontainers singleton with `reuse = true` for fast suite execution
- `@Transactional` applied at class level for automatic rollback after each test
- `TestcontainersInitializer` manages dynamic property injection (datasource URL, credentials)
- Container startup: ~10 seconds once per suite; individual test execution: < 100 ms

#### Test Data Builders: `TestDataBuilders` utility class

- Factory methods for all JPA entities in the module
- Composite key builders (e.g., `UserRoleId`, `RolePermissionId`)
- Relationship helpers with correct `@MapsId` support
- Handles entity associations correctly (e.g., Role → Permission, User → Role)
- Populates audit fields (`updatedBy`, `updatedDt`) with sensible defaults

#### Custom Assertions: Fluent deep-validation classes

- Per-entity assertion classes (e.g., `UserAssertions`, `RoleAssertions`, `PermissionAssertions`)
- Validate all fields and relationships in a single fluent chain
- Preferred over ad-hoc `assertThat` chains for frequently-tested aggregates

```java
// Example — fluent custom assertion usage
UserAssertions.assertThat(savedUser)
        .hasValidEmployeeNumber()
        .hasValidEmail()
        .hasCompleteProfile()
        .isActive();
```

#### Configuration

- `application.yml` — `hibernate.ddl-auto: create-drop`, `default_schema` set to match the target environment
- `schema-init.sql` — creates the target schema before Hibernate generates tables
- Native SQL queries must use the fully-qualified schema prefix matching production

### 6.12 Test Class Documentation Standards (NON-NEGOTIABLE)

**Philosophy**: Test class Javadoc comments must be concise. Comprehensive documentation belongs in `@DisplayName` annotations and inline comments — not in class-level Javadoc blocks.

❌ **AVOID — Verbose class-level Javadoc**:

```java
/**
 * Integration tests for {@link UserRepository}.
 *
 * <p>Tests all CRUD operations, custom queries, and projections with deep validation
 * following constitution requirements. Uses Testcontainers MSSQL for realistic testing.
 *
 * <p><strong>Test Coverage</strong>:
 * <ul>
 *   <li>CRUD operations (Create, Read, Update, Delete)</li>
 *   <li>Custom query: findAllByEmployeeNumberIn</li>
 *   <li>Custom delete: deleteByEmployeeNumberIn</li>
 *   <li>Complex projection: findActiveRolesPermissionsByEmployeeNumber</li>
 *   <li>Edge cases and validation</li>
 * </ul>
 *
 * @see UserRepository
 * @see BaseIntegrationTest
 */
@DisplayName("UserRepository Integration Tests")
class UserRepositoryIntegrationTest extends BaseIntegrationTest {
    // Test methods...
}
```

✅ **REQUIRED — Concise class-level Javadoc**:

```java
/**
 * Integration tests for {@link UserRepository}.
 */
@DisplayName("UserRepository Integration Tests")
class UserRepositoryIT extends BaseIntegrationTest {
    // Test methods...
}
```

**Requirements**:

- Class Javadoc: single line referencing the component under test only
- Use `@DisplayName` with BDD-style names for every test method (e.g., `"Should find user by email when employee number is valid"`)
- Include inline comments for complex setup or non-obvious assertions
- Do **not** maintain a coverage list in Javadoc — the test methods themselves are the specification
- Reduces maintenance burden when coverage changes

### 6.13 Test Class Organization

**Philosophy**: Group related test cases using `@Nested` classes to improve readability and provide clear structure within large test classes.

```java
@SpringBootTest(classes = TestApplication.class)
@Testcontainers
@Transactional
@DisplayName("UserRepository Integration Tests")
class UserRepositoryIT extends BaseIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private PermissionRepository permissionRepository;

    private User testUser;

    @BeforeEach
    void setUpTestData() {
        testUser = TestDataBuilders.createUser("12345678", "John", "Doe");
        testUser = userRepository.save(testUser);
    }

    @Nested
    @DisplayName("Find Operations")
    class FindOperations {

        @Test
        @DisplayName("Should find user by employee number")
        void shouldFindUserByEmployeeNumber() { /* ... */ }

        @Test
        @DisplayName("Should return empty when user not found")
        void shouldReturnEmptyWhenUserNotFound() { /* ... */ }
    }

    @Nested
    @DisplayName("Save Operations")
    class SaveOperations {

        @Test
        @DisplayName("Should persist new user with all required fields")
        void shouldPersistNewUserWithAllRequiredFields() { /* ... */ }

        @Test
        @DisplayName("Should update existing user fields")
        void shouldUpdateExistingUserFields() { /* ... */ }
    }

    @Nested
    @DisplayName("Delete Operations")
    class DeleteOperations {

        @Test
        @DisplayName("Should delete user by employee number")
        void shouldDeleteUserByEmployeeNumber() { /* ... */ }

        @Test
        @DisplayName("Should cascade delete related entities")
        void shouldCascadeDeleteRelatedEntities() { /* ... */ }
    }

    @Nested
    @DisplayName("Custom Query Operations")
    class CustomQueryOperations {

        @Test
        @DisplayName("Should find all users by employee numbers in list")
        void shouldFindAllUsersByEmployeeNumbersInList() { /* ... */ }

        @Test
        @DisplayName("Should find active roles permissions with complete projection")
        void shouldFindActiveRolesPermissionsWithCompleteProjection() { /* ... */ }
    }
}
```

### 6.14 Custom Query and Projection Testing

**Philosophy**: Custom JPQL and native SQL queries are high-risk code. Every query must be tested against a real database with data that exercises both the happy path and exclusion logic.

#### Custom Query Testing

```java
@Test
@DisplayName("Should find all users by employee numbers in list")
void shouldFindAllUsersByEmployeeNumbersInList() {
    // Arrange
    User user2 = TestDataBuilders.createUser("11111111", "Alice", "Johnson");
    User user3 = TestDataBuilders.createUser("22222222", "Bob", "Williams");
    userRepository.saveAll(List.of(user2, user3));

    // Act
    List<User> result = userRepository.findAllByEmployeeNumberIn(
            List.of("12345678", "11111111", "99999999") // 99999999 does not exist
    );

    // Assert — validate size AND contents; confirm non-matching records excluded
    assertThat(result).hasSize(2);
    assertThat(result)
            .extracting(User::getEmployeeNumber)
            .containsExactlyInAnyOrder("12345678", "11111111")
            .doesNotContain("99999999");
}
```

#### Relationship Loading and Join Fetch Testing

```java
@Test
@DisplayName("Should find active roles permissions with complete projection and correct ordering")
void shouldFindActiveRolesPermissionsWithCompleteProjection() {
    // Arrange — build complete relationship chain
    Role adminRole = roleRepository.save(TestDataBuilders.createRole("Admin", 100));
    Role managerRole = roleRepository.save(TestDataBuilders.createRole("Manager", 50));

    Permission permission = permissionRepository.save(
            TestDataBuilders.createPermission("VIEW_BIDS", "BID_MANAGEMENT"));

    // Use entity-based builders (not ID-based) for @MapsId relationships
    rolePermissionRepository.save(TestDataBuilders.createRolePermission(adminRole, permission));
    rolePermissionRepository.save(TestDataBuilders.createRolePermission(managerRole, permission));

    userRoleRepository.save(TestDataBuilders.createUserRole(testUser, adminRole));
    userRoleRepository.save(TestDataBuilders.createUserRole(testUser, managerRole));

    // Act
    List<UserRolePermissionProjection> projections =
            userRepository.findActiveRolesPermissionsByEmployeeNumber("12345678");

    // Assert — validate content and ordering
    assertThat(projections).hasSize(2);
    assertThat(projections)
            .extracting(UserRolePermissionProjection::getRoleName)
            .containsExactlyInAnyOrder("Admin", "Manager");
    // Verify ordering by role rank descending
    assertThat(projections.get(0).getRoleRank())
            .isGreaterThan(projections.get(1).getRoleRank());
}
```

#### Constraint Violation Testing

```java
@Test
@DisplayName("Should throw DataIntegrityViolationException on duplicate email")
void shouldThrowExceptionOnDuplicateEmail() {
    // Arrange
    String duplicateEmail = "duplicate@example.com";
    userRepository.save(TestDataBuilders.createUser("11110000", "First", "User")
            .toBuilder().email(duplicateEmail).build());

    User user2 = TestDataBuilders.createUser("22220000", "Second", "User")
            .toBuilder().email(duplicateEmail).build();

    // Act & Assert
    assertThatThrownBy(() -> userRepository.saveAndFlush(user2))
            .isInstanceOf(DataIntegrityViolationException.class)
            .hasMessageContainingIgnoringCase("unique");
}

@Test
@DisplayName("Should throw DataIntegrityViolationException when saving user with null email")
void shouldThrowExceptionWhenSavingUserWithNullEmail() {
    // Arrange
    User user = TestDataBuilders.createUser("33330000", "No", "Email")
            .toBuilder().email(null).build(); // violates @Column(nullable = false)

    // Act & Assert
    assertThatThrownBy(() -> userRepository.saveAndFlush(user))
            .isInstanceOf(DataIntegrityViolationException.class);
}
```

#### Projection Deep Validation (All Fields)

```java
@Test
@DisplayName("Should return projection with all fields populated")
void shouldReturnProjectionWithAllFieldsPopulated() {
    // Arrange — full relationship chain
    Role role = roleRepository.save(TestDataBuilders.createRole("Admin", 100));
    Permission permission = permissionRepository.save(
            TestDataBuilders.createPermission("VIEW_BIDS", "BID_MANAGEMENT"));
    rolePermissionRepository.save(TestDataBuilders.createRolePermission(role, permission));
    userRoleRepository.save(TestDataBuilders.createUserRole(testUser, role));

    // Act
    List<UserRolePermissionProjection> projections =
            userRepository.findActiveRolesPermissionsByEmployeeNumber("12345678");

    // Assert — validate EVERY projection field (no shallow assertions)
    assertThat(projections).isNotEmpty();
    UserRolePermissionProjection p = projections.get(0);

    // User fields
    assertThat(p.getEmployeeNumber()).isEqualTo("12345678");
    assertThat(p.getFirstName()).isEqualTo("John");
    assertThat(p.getLastName()).isEqualTo("Doe");
    assertThat(p.getEmail()).isNotBlank();
    assertThat(p.getActiveInd()).isTrue();

    // Role fields
    assertThat(p.getRoleId()).isEqualTo(role.getId());
    assertThat(p.getRoleName()).isEqualTo("Admin");
    assertThat(p.getRoleDescription()).isNotBlank();
    assertThat(p.getRoleRank()).isEqualTo(100);

    // Permission fields
    assertThat(p.getPermissionId()).isEqualTo(permission.getId());
    assertThat(p.getPermissionKey()).isEqualTo("VIEW_BIDS");
    assertThat(p.getPermissionName()).isNotBlank();
    assertThat(p.getPermissionCategory()).isEqualTo("BID_MANAGEMENT");
    assertThat(p.getPermissionActiveInd()).isTrue();

    // Audit fields
    assertThat(p.getUserUpdatedBy()).isNotBlank();
    assertThat(p.getUserUpdatedDt()).isNotNull();
    assertThat(p.getRoleUpdatedDt()).isNotNull();
}
```

---

## 7. Code Quality & Maintenance

### 7.1 SonarLint and Static Analysis

```xml
<!-- pom.xml: SonarQube configuration -->
<properties>
    <sonar.organization>company</sonar.organization>
    <sonar.host.url>https://sonarcloud.io</sonar.host.url>
    <sonar.java.coveragePlugin>jacoco</sonar.java.coveragePlugin>
    <sonar.coverage.jacoco.xmlReportPaths>
        ${project.build.directory}/site/jacoco/jacoco.xml
    </sonar.coverage.jacoco.xmlReportPaths>
    <sonar.exclusions>
        **/dto/**,
        **/config/**,
        **/Application.java
    </sonar.exclusions>
</properties>

<build>
    <plugins>
        <!-- JaCoCo for code coverage -->
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.11</version>
            <executions>
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>test</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
                <execution>
                    <id>jacoco-check</id>
                    <goals>
                        <goal>check</goal>
                    </goals>
                    <configuration>
                        <rules>
                            <rule>
                                <element>PACKAGE</element>
                                <limits>
                                    <limit>
                                        <counter>LINE</counter>
                                        <value>COVEREDRATIO</value>
                                        <minimum>0.80</minimum>
                                    </limit>
                                </limits>
                            </rule>
                        </rules>
                    </configuration>
                </execution>
            </executions>
        </plugin>
        
        <!-- SpotBugs for bug detection -->
        <plugin>
            <groupId>com.github.spotbugs</groupId>
            <artifactId>spotbugs-maven-plugin</artifactId>
            <version>4.8.2</version>
            <configuration>
                <effort>Max</effort>
                <threshold>Low</threshold>
                <xmlOutput>true</xmlOutput>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        
        <!-- Checkstyle for code style -->
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-checkstyle-plugin</artifactId>
            <version>3.3.1</version>
            <dependencies>
                <dependency>
                    <groupId>com.puppycrawl.tools</groupId>
                    <artifactId>checkstyle</artifactId>
                    <version>10.12.7</version>
                </dependency>
            </dependencies>
            <configuration>
                <configLocation>google_checks.xml</configLocation>
                <consoleOutput>true</consoleOutput>
                <failsOnError>true</failsOnError>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        
        <!-- PMD for code analysis -->
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-pmd-plugin</artifactId>
            <version>3.21.2</version>
            <configuration>
                <rulesets>
                    <ruleset>/rulesets/java/quickstart.xml</ruleset>
                </rulesets>
                <printFailingErrors>true</printFailingErrors>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

### 7.2 Dependency Management

```xml
<!-- pom.xml: Dependency Management -->
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.2</version>
        <relativePath/>
    </parent>
    
    <groupId>com.company</groupId>
    <artifactId>user-service</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <name>User Service</name>
    <description>User management microservice</description>
    
    <properties>
        <java.version>17</java.version>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        
        <!-- Dependency versions -->
        <mapstruct.version>1.5.5.Final</mapstruct.version>
        <lombok.version>1.18.30</lombok.version>
        <springdoc.version>2.3.0</springdoc.version>
        <testcontainers.version>1.19.3</testcontainers.version>
        <resilience4j.version>2.2.0</resilience4j.version>
    </properties>
    
    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-cache</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        
        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        
        <!-- Caching -->
        <dependency>
            <groupId>com.github.ben-manes.caffeine</groupId>
            <artifactId>caffeine</artifactId>
        </dependency>
        
        <!-- Redis -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        
        <!-- MapStruct -->
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
            <version>${mapstruct.version}</version>
        </dependency>
        
        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>${lombok.version}</version>
            <scope>provided</scope>
        </dependency>
        
        <!-- OpenAPI/Swagger -->
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
            <version>${springdoc.version}</version>
        </dependency>
        
        <!-- Resilience4j -->
        <dependency>
            <groupId>io.github.resilience4j</groupId>
            <artifactId>resilience4j-spring-boot3</artifactId>
            <version>${resilience4j.version}</version>
        </dependency>
        
        <!-- Metrics -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        
        <!-- Testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>testcontainers</artifactId>
            <version>${testcontainers.version}</version>
            <scope>test</scope>
        </dependency>
        
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>postgresql</artifactId>
            <version>${testcontainers.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
            
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>${mapstruct.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>${lombok.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok-mapstruct-binding</artifactId>
                            <version>0.2.0</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            
            <!-- OWASP Dependency Check -->
            <plugin>
                <groupId>org.owasp</groupId>
                <artifactId>dependency-check-maven</artifactId>
                <version>9.0.9</version>
                <configuration>
                    <failBuildOnCVSS>7</failBuildOnCVSS>
                    <skipProvidedScope>true</skipProvidedScope>
                    <skipRuntimeScope>false</skipRuntimeScope>
                </configuration>
                <executions>
                    <execution>
                        <goals>
                            <goal>check</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            
            <!-- Maven Versions Plugin -->
            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>versions-maven-plugin</artifactId>
                <version>2.16.2</version>
                <configuration>
                    <generateBackupPoms>false</generateBackupPoms>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### 7.3 Version Management Scripts

```bash
#!/bin/bash
# check-dependencies.sh

echo "Checking for outdated dependencies..."
mvn versions:display-dependency-updates

echo ""
echo "Checking for plugin updates..."
mvn versions:display-plugin-updates

echo ""
echo "Running OWASP dependency check..."
mvn dependency-check:check

echo ""
echo "Generating dependency tree..."
mvn dependency:tree -Dverbose > dependency-tree.txt
echo "Dependency tree saved to dependency-tree.txt"
```

```bash
#!/bin/bash
# update-dependencies.sh

echo "Updating dependencies to latest versions..."

# Update dependencies
mvn versions:use-latest-releases \
    -Dmaven.version.rules=file://maven-version-rules.xml

# Update Spring Boot version
mvn versions:update-parent

# Update plugins
mvn versions:use-latest-versions -DallowSnapshots=false

echo "Dependencies updated. Please review changes and test thoroughly."
```

---

## Governance

This standards guide is the authoritative reference for all Java Spring Boot development within the organization. All code must comply with these standards unless explicitly approved by the Architecture Review Board.

### Compliance
- All pull requests must pass automated quality gates (SonarQube, tests, security scans)
- Code reviews must verify adherence to these standards
- Exceptions require documented justification and approval

### Amendments
- Standards are reviewed quarterly
- Proposed changes must be submitted to the Architecture Review Board
- Major changes require team consensus and migration plan

### Continuous Improvement
- Teams are encouraged to suggest improvements
- New patterns and practices should be documented and shared
- Regular training sessions on standards compliance

**Version**: 1.0.0  
**Ratified**: February 19, 2026  
**Last Amended**: February 19, 2026  
**Next Review**: May 19, 2026

---

## Additional Resources

- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Spring Framework Documentation](https://docs.spring.io/spring-framework/reference/)
- [Baeldung Spring Tutorials](https://www.baeldung.com/spring-tutorial)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- [Effective Java by Joshua Bloch](https://www.oreilly.com/library/view/effective-java/9780134686097/)
- [Clean Architecture by Robert C. Martin](https://www.oreilly.com/library/view/clean-architecture-a/9780134494166/)

---

*This guide is a living document and will be updated as new best practices emerge and technologies evolve.*
