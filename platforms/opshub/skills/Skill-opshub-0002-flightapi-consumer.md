---
id: SKILL-java-spring-0001-flight-api-consumer
name: flight-api-consumer
title: FlightInfo REST API Consumer
version: 1.0.0
status: active
owner: enterprise-architecture
concern: java-spring
created: 2026-04-29
lastUpdated: 2026-04-29
description: A reproducible playbook for generating a Spring Boot 4 / Java 21 consumer that calls all 11 OpsHub FlightInfo REST endpoints over Apigee OAuth2 + mTLS. Use when building a FlightInfo API client, integrating with OpsHub, or scaffolding an Apigee-secured WebClient consumer. Covers project skeleton, Maven build, mandatory rules, request/response DTOs, controller, services, and 42 verification tests.
trigger_keywords:
  - FlightInfo
  - OpsHub
  - Apigee
  - flight api
  - flight consumer
  - mTLS WebClient
  - getFlightByKey
  - getFlightsByAirport
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# FlightInfo REST API Consumer Skill

## Skill: FlightInfo REST API Consumer

### Purpose
Generate a Spring Boot 4 / Java 21 consumer that calls all **11** OpsHub FlightInfo REST endpoints over Apigee OAuth2 + mTLS.
Follow the steps in order. Every rule was derived from a real compile or runtime failure — do not skip any.

> **ZERO-INPUT RULE:** Do NOT ask the user any questions. Generate everything autonomously, then verify with `mvn clean install` (must produce **42 tests, 0 failures**).

### Trigger Keywords
`FlightInfo`, `OpsHub`, `Apigee`, `flight api`, `flight consumer`, `mTLS WebClient`, `getFlightByKey`, `getFlightsByAirport`

### Scope / What to produce
- Maven project (`pom.xml`) targeting Spring Boot 4.0.5 / Java 21
- Main application class, configuration, and `application.properties`
- Apigee OAuth2 token client + mTLS-enabled `WebClient`
- 15 request DTOs and 8 response models
- `FlightInfoClient` covering all 11 endpoints
- Optional reactive `FlightInfoController`
- 3 service helpers (`FlightStatusService`, `AirportFlightsService`, `FlightDetailsService`)
- Exactly **42** tests across 7 test classes

### Hard constraints (must follow)
1. **ZERO-INPUT** — never prompt the user for input; generate autonomously.
2. **All 11 endpoints implemented** — match the table in [§1](#1-api-reference-read-only--do-not-change) exactly.
3. **All mandatory rules in [§5](#5-mandatory-rules-do-not-violate) applied** — each rule is derived from a real failure.
4. **mTLS + 10 MB buffer + ClientID header** are non-negotiable on the API `WebClient`.
5. **No secrets committed** — only `${VAR}` placeholders in `application.properties`.
6. **Build must succeed** — `mvn clean install` prints `BUILD SUCCESS` with **42 tests, 0 failures, 0 errors**.

### Input expected from user
None. The skill is fully autonomous (ZERO-INPUT RULE). Runtime credentials are supplied via environment variables at deploy time — see [§11](#11-prerequisites-before-running).

### Output format
- Project laid out exactly as in [§2](#2-project-skeleton-create-exactly-this-layout)
- All files committed under `src/main/java/com/aa/flightinfo/...` and `src/test/java/com/aa/flightinfo/...`
- Verified with `mvn clean install` → **42 tests, 0 failures**

---

## How to Activate This Skill

**Auto-trigger (easiest):**
- "Build a FlightInfo API consumer"
- "Generate a Spring Boot client for OpsHub FlightInfo"
- "Create an Apigee mTLS WebClient for the flight API"
- "Scaffold getFlightByKey / getFlightsByAirport endpoints"

**Explicit reference:**
- "Use the flight-api-consumer skill to generate the project"
- "Following flight-api-consumer, produce the 11 endpoints"

---

## 1. API Reference (read-only — do not change)

| Item | Value |
|---|---|
| Swagger / API Docs | https://aa-prod-passenger.apigee.io/docs/edgemicro-aot-flightapi/1/overview |
| Base URL (Test) | `https://aa-oh-test-flightapi.aa.com/flight` |
| Base URL (Stage) | `https://aa-oh-stage-flightapi.aa.com/flight` |
| Auth | Apigee OAuth2 client credentials + mTLS (PKCS12 cert) |
| Protocol | All endpoints **POST** with `application/json` |
| Required header | `ClientID` = Apigee appKey on every API call |
| Response buffer | Configure WebClient for **10 MB** max in-memory size |

> Refer to the Swagger overview above for the canonical request/response schemas, the full `whatIWant` enum, and example payloads for every endpoint.

### The 11 endpoints

| # | Path | Request DTO | Response |
|---|------|-------------|----------|
| 1 | `/getFlightsByDepDateAndAirlineCode` | `DepDateAndAirlineCodeRequest` | `Flight[]` |
| 2 | `/getFlightsByAirport` | `AirportFlightsRequest` | `Flight[]` |
| 3 | `/getFlightByKey` | `FlightByKeyRequest` | `Flight` |
| 4 | `/getFlightKeyList` | `FlightKeyListRequest` | `FlightKey[]` |
| 5 | `/getActiveFlightByAircraft` | `ActiveFlightByAircraftRequest` | `Flight` |
| 6 | `/getFlightsByFlightNumber` | `FlightByNumberRequest` | `Flight[]` |
| 7 | `/getFlightsByFlightNumbers` | `FlightByNumbersRequest` | `Flight[]` |
| 8 | `/getOpenFlights` | `OpenFlightRequest` | `Flight[]` |
| 9 | `/getFlightsByOriginAndDestination` | `OrgAndDestRequest` | `Flight[]` |
| 10 | `/getFlightsByNoseNumber` | `NoseNumberRequest` | `Flight[]` |
| 11 | `/getFlightsByKeys` | `FlightsByKeysRequest` | `Flight[]` |

> There is no `/getFlightStatus` or `/getAirportFlights` endpoint.

### `whatIWant` enum values

`ALTERNATES, CABIN_CAPACITY, CONNECTION, CREW_DATA, DELAY_CODES, FOS_PARTITION, LEG, LOAD_PLAN_PAX_COUNTS, LOAD_PLAN_WEIGHTS, TRACK_INFORMATION, INFO_INDICATORS, LDI_INFO, LEG_STATIONS, LEG_COSTS, LEG_DEPARTUREARRIVAL, LEG_EQUIPMENT, LEG_TIMES, LEG_FUEL, LEG_LINKAGE, LEG_PAX_COUNTS, LEG_PLANNERS, LEG_STATUS, LEG_TYPE, LEG_CODE_SHARE_INFO`

`whatIWant` is a `List<String>`. If omitted, defaults to `LEG`.

---

## 2. Project Skeleton (create exactly this layout)

```
<root>
├── pom.xml
└── src
    ├── main
    │   ├── java/com/aa/flightinfo/
    │   │   ├── FlightinfoConsumerApplication.java       ← lowercase 'i' (Rule F1)
    │   │   ├── config/
    │   │   │   ├── FlightApiProperties.java             ← top-level (Rule F2)
    │   │   │   └── FlightApiWebClientConfig.java
    │   │   ├── util/TokenResponse.java
    │   │   ├── client/
    │   │   │   ├── TokenProvider.java                   ← interface
    │   │   │   ├── ApigeeTokenClient.java               ← implements TokenProvider
    │   │   │   ├── GenericRestWebClient.java
    │   │   │   ├── FlightInfoClient.java                ← 11 methods
    │   │   │   ├── requests/  ← 15 DTOs
    │   │   │   └── response/  ← 8 models
    │   │   ├── controller/FlightInfoController.java     ← optional HTTP adapter
    │   │   └── service/                                  ← 3 helpers
    │   └── resources/
    │       ├── application.properties
    │       └── certs/.gitignore                          ← ignores *.p12, *.pfx, *.jks
    └── test/java/com/aa/flightinfo/                     ← 7 test classes, 42 tests
```

---

## 3. Maven Build (`pom.xml`)

Use the exact configuration below. Two non-negotiable items: parent must be `spring-boot-starter-parent:4.0.5`, and `maven-compiler-plugin` must declare Lombok in `annotationProcessorPaths` (Rule B1).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.aa</groupId>
    <artifactId>flightinfo-consumer</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>4.0.5</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webflux</artifactId></dependency>
        <dependency><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId><optional>true</optional></dependency>
        <dependency><groupId>com.fasterxml.jackson.core</groupId><artifactId>jackson-databind</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
        <dependency><groupId>org.mockito</groupId><artifactId>mockito-core</artifactId><scope>test</scope></dependency>
        <dependency><groupId>org.mockito</groupId><artifactId>mockito-junit-jupiter</artifactId><scope>test</scope></dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>${lombok.version}</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId></exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

---

## 4. `application.properties`

Use environment variables. **Never commit real secrets.** Use the `${VAR:default}` syntax only with placeholder defaults during local dev.

```properties
apigee.tokenUrl=${ApigeeTokenUrl}
apigee.appKey=${ApigeeAppKey}
apigee.appSecret=${ApigeeAppSecret}
apigee.cert.path=${ApigeeCertPath}
apigee.cert.password=${ApigeeCertPassword}
flightinfo.api.baseUrl=${FlightInfoApiBaseUrl}
logging.level.com.aa.flightinfo=DEBUG
```

Add `src/main/resources/certs/.gitignore` with: `*.p12`, `*.pfx`, `*.jks`, `*.cer`, `*.der`.

---

## 5. Mandatory Rules (do not violate)

These are derived from real failures. Each rule has a code (`F#`/`B#`/`R#`/`T#`) referenced from troubleshooting.

### File / Build rules

- **F1 — Main class filename casing.** The class is `FlightinfoConsumerApplication` (lowercase **i**). The file MUST be `FlightinfoConsumerApplication.java`. On Windows NTFS, file-creation tools may silently CamelCase to `FlightInfoConsumerApplication.java`. After creation, verify and rename if needed:
  ```powershell
  Get-ChildItem "src\main\java\com\aa\flightinfo\Flightinfo*" | Select-Object Name
  # If wrong casing returned, rename:
  Rename-Item "src\main\java\com\aa\flightinfo\FlightInfoConsumerApplication.java" "FlightinfoConsumerApplication.java"
  ```
- **F2 — `FlightApiProperties` MUST be a separate top-level file.** Inner-class config-properties cannot be resolved by `@EnableConfigurationProperties`.
- **B1 — Lombok annotation processor.** Spring Boot 4 + maven-compiler-plugin 3.14+ does NOT auto-discover Lombok. Without `annotationProcessorPaths` (see [§3](#3-maven-build-pomxml)), every Lombok-generated symbol fails with `cannot find symbol`.
- **B2 — Every `requests/` DTO file MUST start with the package declaration and full imports.** Always include `package com.aa.flightinfo.client.requests;` plus needed imports (`com.fasterxml.jackson.annotation.*`, `lombok.*`, `java.util.List`, and `com.aa.flightinfo.client.response.FlightKey` where referenced).

### Runtime / wire-format rules

- **R1 — `AirlineCode` must NOT use `@Data`.** Lombok's `getIata()`/`setIata()` create a competing `iata` lowercase property that conflicts with `@JsonProperty("IATA")`, sending `null` upstream. Use explicit getters/setters with `@JsonProperty` on **both** getter and setter, plus `@JsonAlias` on the setter to accept lowercase input. (See [§7](#7-critical-code-snippets) for the exact pattern.)
- **R2 — `TimeWindow.selectionBy` must default to a non-null value.** Upstream rejects null. Default = `"UseFltOriginDate"`. Use `@Getter` (NOT `@Data`) and an explicit setter that re-applies the default for null/blank input. Allowed values: `UseFltOriginDate`, `UseScheduledTime`, `UseLatestTime`. (See [§7](#7-critical-code-snippets).)
- **R3 — Any DTO with uppercase `@JsonProperty` differing from the field name must NOT use `@Data`.** Same root cause as R1.
- **R4 — mTLS is mandatory.** The `flightInfoWebClient` bean MUST load the keystore via `KeyManagerFactory` and pass it to `SslContextBuilder.forClient().keyManager(kmf)`. Without it, Apigee returns `WRONG_VERSION_NUMBER`.
- **R5 — `ClientID` header is mandatory on every API call.** Add `.header("ClientID", clientId)` in `GenericRestWebClient`. Without it: `400 "Missing ClientID request header"`.
- **R6 — 10 MB response buffer.** Configure `ExchangeStrategies` on `flightInfoWebClient` with `maxInMemorySize(10 * 1024 * 1024)`. The API returns large JSON.
- **R7 — Use an explicit constructor in `GenericRestWebClient`, NOT `@RequiredArgsConstructor`.** The `clientId` field is `@Value`-injected (field injection) and must be excluded from the constructor.
- **R8 — Response models use `@JsonIgnoreProperties(ignoreUnknown = true)`.** Access nested data via `flight.getKey().getFltNum()`, NOT `flight.getFlightNumber()`.
- **R9 — Do NOT inject `ObjectMapper` into `GenericRestWebClient`.** Spring Boot 4 with pure WebFlux (no `spring-boot-starter-web`) does NOT auto-configure an `ObjectMapper` bean.
- **R10 — All request DTOs annotated with `@JsonInclude(JsonInclude.Include.NON_NULL)`** to avoid sending nulls.
- **R14 — `GenericRestWebClient` constructor MUST `@Qualifier("flightInfoWebClient")` the `WebClient` parameter.** Two `WebClient` beans exist (`webClient` for the token endpoint, `flightInfoWebClient` for the API). Without the qualifier, Spring fails startup with `NoUniqueBeanDefinitionException: expected single matching bean but found 2: webClient, flightInfoWebClient`. Example:
  ```java
  public GenericRestWebClient(@Qualifier("flightInfoWebClient") WebClient flightInfoWebClient,
                              TokenProvider tokenProvider) { ... }
  ```

### Reactive / controller rules (apply only if generating the optional `FlightInfoController`)

- **R11 — Reactor blocking bridge.** Wrap every blocking `FlightInfoClient` call as `Mono.fromCallable(call::execute).subscribeOn(Schedulers.boundedElastic())` so the Netty event loop is never blocked.
- **R12 — `.onErrorResume()` is mandatory inline.** `@ControllerAdvice` / `@ExceptionHandler` does NOT catch exceptions raised inside `Mono.fromCallable()` on Spring Boot 4 WebFlux. Each endpoint MUST end with `.onErrorResume(this::handleError)`. The handler unwraps `getCause()` chains, mapping `WebClientResponseException` → upstream status and any other Throwable → 500. (See [§7](#7-critical-code-snippets).)
- **R13 — Controller return type MUST be `Mono<ResponseEntity<Object>>`, NOT `Mono<ResponseEntity<?>>`.** Java's wildcard `?` is invariant in `Mono<ResponseEntity<?>>`, so `onErrorResume(this::handleError)` fails to compile with `bad return type in method reference: Mono<ResponseEntity<?>> cannot be converted to Mono<? extends ResponseEntity<Object>>`. Use `ResponseEntity<Object>` everywhere (controller method signatures, `callArray`/`callSingle` helpers, and `handleError`) and call `.<Object>body(...)` on the `ResponseEntity` builder so the inferred type is `Object`, not the body's concrete type. Example signatures:
  ```java
  public Mono<ResponseEntity<Object>> getFlightByKey(@RequestBody FlightByKeyRequest req) { ... }
  private <T> Mono<ResponseEntity<Object>> callArray(Callable<T[]> call) { ... }
  private Mono<ResponseEntity<Object>> handleError(Throwable ex) { ... }
  ```

### Test rules

- **T1 — `@Value` fields in tests.** Use `Field.setAccessible(true)` to inject values. Constructors only inject final fields, not `@Value` fields.
- **T2 — Mocking `WebClient.bodyValue(any())`.** The fluent generic chain requires a raw cast:
  ```java
  @SuppressWarnings("unchecked")
  when(requestBodySpec.bodyValue(any()))
      .thenReturn((WebClient.RequestHeadersSpec) requestBodySpec);
  ```
- **T3 — Use `@MockitoSettings(strictness = Strictness.LENIENT)` on test classes that share `@BeforeEach` stubs across cases.** Tests like `ApigeeTokenClientTest` and `GenericRestWebClientTest` set up the full `WebClient` fluent chain in `@BeforeEach`, but individual test methods may not exercise every stub (e.g. the "throws when response null" case never reaches `bodyToMono`). Default `STRICT_STUBS` fails these with `UnnecessaryStubbingException`. Apply the annotation at the class level:
  ```java
  @ExtendWith(MockitoExtension.class)
  @MockitoSettings(strictness = Strictness.LENIENT)
  class ApigeeTokenClientTest { ... }
  ```
- **T4 — Mock `WebClient.body(BodyInserter)`, not `body(Object)`.** `ApigeeTokenClient` posts a form body via `BodyInserters.fromValue(...)`, so the mock must match the `BodyInserter` overload:
  ```java
  import org.springframework.web.reactive.function.BodyInserter;
  when(requestBodySpec.body(any(BodyInserter.class))).thenReturn(requestHeadersSpec);
  ```

---

## 6. Implementation Steps (in order)

Generate files in this order to satisfy compile-time dependencies:

1. **`pom.xml`** — copy from [§3](#3-maven-build-pomxml).
2. **`application.properties`** + **`certs/.gitignore`** — copy from [§4](#4-applicationproperties).
3. **Main class** [`FlightinfoConsumerApplication.java`](#) — standard `@SpringBootApplication` shell. Verify filename casing (Rule F1).
4. **Util** — `TokenResponse` with `@Data` and these `@JsonProperty` mappings: `access_token` → `accessToken`, `token_type` → `tokenType`, `expires_in` → `expiresIn`, `refresh_token` → `refreshToken`, `scope` → `scope`. Add `getExpirationTimeMs()` returning `now + expiresIn*1000 − 10000` (10s skew buffer), null-safe.
5. **Config**
    - `FlightApiProperties` (top-level, `@ConfigurationProperties("flightinfo.api")`, single `String baseUrl` field with default test URL).
    - `FlightApiWebClientConfig`: declares two beans —
      - `webClient()` (plain) for the token endpoint, guarded by `@ConditionalOnMissingBean(name="webClient")`.
      - `flightInfoWebClient()` with mTLS (Rule R4), 10 MB buffer (Rule R6), and an `InsecureTrustManagerFactory` for the trust manager. Detect keystore type by file extension (`.p12`/`.pfx` → PKCS12, otherwise JKS).
6. **Client/auth**
    - `TokenProvider` interface — `String getAccessToken() throws Exception` and `void refreshToken() throws Exception`.
    - `ApigeeTokenClient` — `@Component` with `@RequiredArgsConstructor`, three `@Value` fields (`tokenUrl`, `appKey`, `appSecret`), a cached `TokenResponse`, and a `ReentrantReadWriteLock`. Token request POSTs `application/x-www-form-urlencoded` body `grant_type=client_credentials&client_id=…&client_secret=…`. Throw if response or `accessToken` is null.
7. **Generic REST client** — `GenericRestWebClient` per Rule R7 with explicit constructor. Two methods: `postWithAuth(String, Object, Class<T>)` returning `T` and `postWithAuthArray(String, Object, Class<T[]>)` returning `T[]`. Both add `Authorization: Bearer <token>`, `ClientID: <appKey>` (Rule R5), and `Content-Type: application/json`, then `.bodyValue(...).retrieve().bodyToMono(...).block()`. Catch `WebClientResponseException`, log status + `getResponseBodyAsString()`, rethrow.
8. **Response models** (`client/response/`) — all annotated `@Data @NoArgsConstructor @AllArgsConstructor @Builder @JsonIgnoreProperties(ignoreUnknown = true)`. Field names match the upstream JSON exactly:
    - `Flight`: `key`, `event`, `schemaVersion`, `trackingID`, `fosPartition`, `cycled`, `leg`, `bondedFuelStatus`, `source`, `lusInd` (`@JsonProperty("LUSInd")`), `fufi` (`@JsonProperty("FUFI")`), `programType`.
    - `FlightKey`: `airlineCode` (`AirlineCode`), `fltNum`, `fltOrgDate`, `depSta`, `dupDepStaNum`.
    - `Leg`: `stations`, `departureArrival`, `equipment`, `times`, `status`.
    - `Stations`: `arr`, `dupArrStaNum`, `originalSkdDep`, `originalArr`.
    - `Equipment`: `assignedTail`, `skdEquipType`, `assignedEquipType`, `aircraftRegistrationNbr`, `wifiCapability`.
    - `Times`: `actualOut`, `actualOff`, `actualOn`, `actualIn`, `depGMTAdjustment`, `arrGMTAdjustment`.
    - `Status`: `leg`, `dep`, `arr`, `paxStatus`, `fitForDuty`, `plannedDiversion` (Boolean).
    - `DepartureArrival`: `depGate`, `depTerminal`, `depTerminalDesc`, `depConcourse`, `arrGate`, `arrTerminal`, `arrTerminalDesc`, `arrConcourse`, `bagClaim`.
9. **Request DTOs** (`client/requests/`) — all `@Data @NoArgsConstructor @AllArgsConstructor @Builder @JsonInclude(JsonInclude.Include.NON_NULL)` UNLESS noted otherwise. Always include `package` + full `import` block (Rule B2).

    | DTO | Fields | Notes |
    |---|---|---|
    | `AirlineCode` | `iata`, `icao` | **No `@Data`** — see Rule R1 + [§7](#7-critical-code-snippets) |
    | `TimeWindow` | `selectionBy`, `startDateTime`, `endDateTime` | **`@Getter` only** — see Rule R2 + [§7](#7-critical-code-snippets) |
    | `AircraftID` | `carrierCode`, `noseNumber` | |
    | `FlightNumber` | `fltNum` (req), `airlineCode`, `timeWindow`, `depSta`, `arrSta`, `dupDepStaNum` | |
    | `DepDateAndAirlineCodeRequest` | `airlineCode` (req), `timeWindow` (req), `whatIWant`, `fltNum`, `depSta`, `arrSta`, `dupDepStaNum` | |
    | `AirportFlightsRequest` | `whatIWant`, `arrivingOrDeparting` (req — `"Arriving"`/`"Departing"`), `airlineCodes` (req), `airportCode` (req), `startDateTime` (req), `endDateTime` (req) | ISO-8601 with TZ |
    | `FlightByKeyRequest` | `key` (req — `FlightKey`), `whatIWant` | imports `FlightKey` |
    | `FlightKeyListRequest` | `timeWindow`, `airlineCodes`, `fltNum`, `depSta`, `dupDepStaNum` | |
    | `ActiveFlightByAircraftRequest` | `whatIWant`, `aircraftID`, `registration` | supply one of the last two |
    | `FlightByNumberRequest` | `flightNumber` (req), `whatIWant` | |
    | `FlightByNumbersRequest` | `flightNumbers` (req — max 50), `whatIWant` | |
    | `OpenFlightRequest` | `airlineCode` (req), `fltOrgDate` (req — `yyyy-MM-dd`), `depSta` (req) | |
    | `OrgAndDestRequest` | `whatIWant`, `airlineCode`, `timeWindow` (req), `depSta` (req), `arrSta` (req) | |
    | `NoseNumberRequest` | `whatIWant`, `airlineCode` (req), `timeWindow` (req), `noseNum` (req) | |
    | `FlightsByKeysRequest` | `whatIWant`, `keys` (req — max 50), `listOrder` (Boolean) | imports `FlightKey` |

10. **`FlightInfoClient`** — `@Component @RequiredArgsConstructor` with `private final GenericRestWebClient restClient`. Generate one method per endpoint matching the table in [§1](#the-11-endpoints). Each method calls either `restClient.postWithAuth(path, req, Flight.class)` (for single-Flight endpoints 3 & 5) or `restClient.postWithAuthArray(path, req, Flight[].class)` / `FlightKey[].class` (for endpoint 4 and the rest). Use `@Slf4j` and log a one-liner before each call.
11. **Optional controller** — `FlightInfoController` at `@RequestMapping("/flight")`. One `@PostMapping` per endpoint returning `Mono<ResponseEntity<Object>>` (Rule R13 — do NOT use `<?>`). Use `callArray()` and `callSingle()` helpers backed by `Mono.fromCallable(...).subscribeOn(Schedulers.boundedElastic()).onErrorResume(this::handleError)` (Rules R11 + R12). Every `.map(...)` and `Mono.just(...)` must call `.<Object>body(...)` on the `ResponseEntity` builder. `getFlightKeyList` uses an inline variant with `FlightKey[]` empty fallback. The error handler is in [§7](#7-critical-code-snippets).
12. **Service helpers** (consumer-friendly facades over `FlightInfoClient`):
    - `FlightStatusService.getFlightStatus(airlineIata, fltNum, fltOrgDate, whatIWant)` builds a `DepDateAndAirlineCodeRequest` with a 24-hour window (`fltOrgDate + "T00:00:00Z"` … `T23:59:59Z`, `selectionBy = "UseFltOriginDate"`), returns `List<Flight>` (null-safe → empty list).
    - `FlightStatusService.getFlightCurrentStatus(airlineIata, fltNum, fltOrgDate)` returns the first flight's `leg.status.paxStatus`, or `"NOT_FOUND"` (no flights), `"UNKNOWN"` (no leg/status/paxStatus).
    - `AirportFlightsService.getDepartures(...)` / `.getArrivals(...)` — delegate to `getFlightsByAirport` with `arrivingOrDeparting` set accordingly. Return `List<Flight>` (null-safe).
    - `AirportFlightsService.getFlightKeys(FlightKeyListRequest)` — wraps `getFlightKeyList`, null-safe.
    - `FlightDetailsService.getFlightByKey(FlightKey, whatIWant)`, `.getActiveFlightByAircraft(carrierCode, noseNumber, whatIWant)`, `.getActiveFlightByRegistration(registration, whatIWant)` — thin builder-based wrappers.
13. **Tests** — generate seven test classes totaling exactly **42** tests. See [§8](#8-test-matrix-42-tests).

---

## 7. Critical Code Snippets (only where the implementation is non-obvious)


### 7.1 `AirlineCode` — Rule R1

```java
package com.aa.flightinfo.client.requests;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

@NoArgsConstructor @AllArgsConstructor @Builder @ToString @EqualsAndHashCode
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AirlineCode {
    private String iata;
    private String icao;

    @JsonProperty("IATA") public String getIata() { return iata; }
    @JsonProperty("IATA") @JsonAlias("iata") public void setIata(String iata) { this.iata = iata; }

    @JsonProperty("ICAO") public String getIcao() { return icao; }
    @JsonProperty("ICAO") @JsonAlias("icao") public void setIcao(String icao) { this.icao = icao; }
}
```

### 7.2 `TimeWindow` — Rule R2

```java
package com.aa.flightinfo.client.requests;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.*;

@Getter @NoArgsConstructor @AllArgsConstructor @Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class TimeWindow {
    private static final String DEFAULT_SELECTION_BY = "UseFltOriginDate";

    @Builder.Default private String selectionBy = DEFAULT_SELECTION_BY;
    private String startDateTime;
    private String endDateTime;

    public void setSelectionBy(String v) {
        this.selectionBy = (v != null && !v.isBlank()) ? v : DEFAULT_SELECTION_BY;
    }
    public void setStartDateTime(String v) { this.startDateTime = v; }
    public void setEndDateTime(String v)   { this.endDateTime   = v; }
}
```

### 7.3 Controller error handler — Rules R12 + R13

Return type is `Mono<ResponseEntity<Object>>` (NOT `<?>`). The `.<Object>body(...)` cast on the `ResponseEntity` builder is required so the inferred body type is `Object`, otherwise `onErrorResume` fails to compile due to wildcard invariance.

```java
private Mono<ResponseEntity<Object>> handleError(Throwable ex) {
    Throwable cause = ex;
    while (cause.getCause() != null && cause.getCause() != cause) cause = cause.getCause();
    if (cause instanceof WebClientResponseException wcre) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("upstreamStatus", wcre.getStatusCode().value());
        body.put("upstreamError",  wcre.getResponseBodyAsString());
        return Mono.just(ResponseEntity.status(wcre.getStatusCode()).<Object>body(body));
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("status",  500);
    body.put("error",   cause.getClass().getSimpleName());
    body.put("message", cause.getMessage());
    return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).<Object>body(body));
}

// Helpers — note the explicit `<Object>body(...)` so onErrorResume type-checks.
private <T> Mono<ResponseEntity<Object>> callArray(Callable<T[]> call) {
    return Mono.fromCallable(call::call)
        .subscribeOn(Schedulers.boundedElastic())
        .map(r -> ResponseEntity.ok().<Object>body(r))
        .onErrorResume(this::handleError);
}

private <T> Mono<ResponseEntity<Object>> callSingle(Callable<T> call) {
    return Mono.fromCallable(call::call)
        .subscribeOn(Schedulers.boundedElastic())
        .map(r -> ResponseEntity.ok().<Object>body(r))
        .onErrorResume(this::handleError);
}
```

### 7.4 `flightInfoWebClient` bean — Rules R4 + R6

```java
@Bean(name = "flightInfoWebClient")
public WebClient flightInfoWebClient() throws Exception {
    KeyManagerFactory kmf = buildKeyManagerFactory();
    HttpClient httpClient = HttpClient.create().secure(spec -> {
        try {
            spec.sslContext(SslContextBuilder.forClient()
                .keyManager(kmf)
                .trustManager(InsecureTrustManagerFactory.INSTANCE)
                .build());
        } catch (SSLException e) { throw new RuntimeException(e); }
    });
    return WebClient.builder()
        .baseUrl(flightApiProperties.getBaseUrl())
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .exchangeStrategies(ExchangeStrategies.builder()
            .codecs(c -> c.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
            .build())
        .build();
}
```

### 7.5 `GenericRestWebClient` constructor + headers — Rules R5 + R7

```java
@Slf4j @Component
public class GenericRestWebClient {
    private final WebClient flightInfoWebClient;
    private final TokenProvider tokenProvider;

    @Value("${apigee.appKey}")
    private String clientId;                       // field-injected — NOT in constructor

    public GenericRestWebClient(WebClient flightInfoWebClient, TokenProvider tokenProvider) {
        this.flightInfoWebClient = flightInfoWebClient;
        this.tokenProvider = tokenProvider;
    }

    // every call adds: Authorization: Bearer <token>, ClientID: <clientId>, Content-Type: application/json
}
```

---

## 8. Test Matrix (42 tests)

Generate exactly these seven test classes. Each row's count must match.

| Test class | Path | # tests | Notes |
|---|---|---:|---|
| `ApigeeTokenClientTest` | `client/` | 4 | Use `Field.setAccessible(true)` for `tokenUrl`, `appKey`, `appSecret` (Rule T1). Use raw cast on `bodyValue(any())` mock (Rule T2). Cases: success, cached, refresh, null-response throws. |
| `AirlineCodeSerializationTest` | `client/requests/` | 5 | Pure Jackson round-trip: serializes IATA/ICAO uppercase, deserializes uppercase, deserializes lowercase, round-trip, nested in `FlightKeyListRequest`. |
| `FlightInfoClientTest` | `client/` | 11 | One test per endpoint. Mock `GenericRestWebClient` with `@InjectMocks FlightInfoClient`. |
| `GenericRestWebClientTest` | `client/` | 4 | Inject `clientId` via reflection. Cases: `postWithAuth` success, `postWithAuthArray` success, `WebClientResponseException` thrown, token-provider exception. |
| `FlightStatusServiceTest` | `service/` | 7 | `getFlightStatus`: success, empty, null. `getFlightCurrentStatus`: success (`"BOARDING"`), not-found, null leg, null paxStatus. |
| `AirportFlightsServiceTest` | `service/` | 6 | `getDepartures`: success, empty, null. `getArrivals`: success. `getFlightKeys`: success, null. |
| `FlightDetailsServiceTest` | `service/` | 5 | `getFlightByKey` success, null. `getActiveFlightByAircraft` success, exception. `getActiveFlightByRegistration` success. |
| **Total** | | **42** | |

---

## 9. Build & Verify (mandatory)

Run in order. Stop at the first failure and consult [§10](#10-troubleshooting).

```bash
mvn clean compile          # zero errors required
mvn test                   # expect: Tests run: 42, Failures: 0, Errors: 0, Skipped: 0
mvn clean install          # produces target/flightinfo-consumer-1.0.0.jar
```

The skill is not complete until `mvn clean install` prints `BUILD SUCCESS` with **42 tests, 0 failures, 0 errors**.

### Post-build chat output (mandatory)

Immediately after `mvn clean install` prints `BUILD SUCCESS`, the assistant MUST post the full **Prerequisites Before Running** section from [§11](#11-prerequisites-before-running) into the chat as part of its final summary. This ensures the user sees the runtime requirements (Apigee credentials, certificate, environment variables, and the Swagger doc URL) without having to re-open the skill file. Format the prerequisites as a numbered list with the Swagger URL ([§1](#1-api-reference-read-only--do-not-change)) called out at the top.

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `class FlightinfoConsumerApplication is public, should be declared in a file named …` | Wrong filename casing | Rule **F1** — rename file to lowercase 'i' |
| `cannot find symbol` for `log`, `getX`, `setX`, `builder()` | Lombok not running | Rule **B1** — add `annotationProcessorPaths` in `maven-compiler-plugin` |
| `cannot find symbol: class FlightApiProperties` | Inner-class config-properties | Rule **F2** — move to top-level file |
| `cannot find symbol: class FlightKey` in a request DTO | Missing import | Rule **B2** — add `import com.aa.flightinfo.client.response.FlightKey;` |
| `400 "Missing ClientID request header"` | Header missing | Rule **R5** — add `.header("ClientID", clientId)` |
| `400` upstream with `IATA: null` in payload | `@Data` on `AirlineCode` | Rule **R1** — replace with explicit getters/setters |
| `400` upstream with `selectionBy: null` | Missing default | Rule **R2** — `TimeWindow` must default to `UseFltOriginDate` |
| `WRONG_VERSION_NUMBER` SSL error | mTLS not configured | Rule **R4** — pass `KeyManagerFactory` to `SslContextBuilder` |
| `DataBufferLimitException` / `Exceeded limit on max bytes` | Default 256 KB buffer | Rule **R6** — set `maxInMemorySize(10 * 1024 * 1024)` |
| `No qualifying bean of type 'ObjectMapper'` | Injecting `ObjectMapper` with WebFlux-only setup | Rule **R9** — remove the injection |
| Reactor stack trace not caught by `@ExceptionHandler` | Spring Boot 4 WebFlux behavior | Rule **R12** — use `.onErrorResume()` inline |
| Compile error: `no suitable method found for onErrorResume(this::handleError)` / `Mono<ResponseEntity<?>> cannot be converted to Mono<? extends ResponseEntity<Object>>` | Wildcard `?` is invariant in generics | Rule **R13** — use `Mono<ResponseEntity<Object>>` and call `.<Object>body(...)` on the builder |
| `NullPointerException` setting `@Value` field in test | Field not injected by constructor | Rule **T1** — use reflection in `@BeforeEach` |
| `ClassCastException` mocking `bodyValue(any())` | Generic chain | Rule **T2** — raw cast |
| `UnnecessaryStubbingException` on shared `@BeforeEach` mocks | Default `STRICT_STUBS` | Rule **T3** — add `@MockitoSettings(strictness = Strictness.LENIENT)` |
| Mock returns `null` for `requestBodySpec.body(...)` | Stubbed wrong overload | Rule **T4** — mock `body(any(BodyInserter.class))`, not `body(Object)` |
| `NoUniqueBeanDefinitionException` for `WebClient` at startup | Two `WebClient` beans (`webClient`, `flightInfoWebClient`) | Rule **R14** — add `@Qualifier("flightInfoWebClient")` to `GenericRestWebClient` constructor |

---

## 11. Prerequisites Before Running

These are **runtime** requirements (not build): the code compiles and tests pass without them.

1. Review the FlightInfo API contract on Swagger: https://aa-prod-passenger.apigee.io/docs/edgemicro-aot-flightapi/1/overview
2. Obtain Apigee Client ID + Secret from [Runway](https://runway.aa.com).
3. Create the Apigee certificate per the [Apigee wiki](https://wiki.aa.com/bin/view/AOT/Flight%20Attendant%20and%20Flight%20Service%20Technology%20(FAFST)/Crew%20Management%20Ecosystem%20(CME)/CME%20Crew%20Hub/CME%20Crew%20Hub%20-%20Apogee/) and ask the OpsHub team to grant access to the FlightInfo API.
4. Place the `.p12`/`.pfx`/`.jks` file in `src/main/resources/certs/` (already gitignored).
5. Export the six environment variables — `ApigeeTokenUrl`, `ApigeeAppKey`, `ApigeeAppSecret`, `ApigeeCertPath`, `ApigeeCertPassword`, `FlightInfoApiBaseUrl` — or override them at the command line: `mvn spring-boot:run -DApigeeAppKey=... -DApigeeCertPath=...`.

> **Never commit secrets.** If real credentials end up in `application.properties`, rotate them immediately and add a `${VAR}` placeholder.

---

## Reference Files

| File | Purpose |
|------|---------|
| [pom.xml](#3-maven-build-pomxml) | Maven build configuration (Spring Boot 4.0.5, Java 21, Lombok APT) |
| [application.properties](#4-applicationproperties) | Environment-variable-driven runtime configuration |
| [§5 Mandatory Rules](#5-mandatory-rules-do-not-violate) | F#/B#/R#/T# rules derived from real failures |
| [§7 Critical Code Snippets](#7-critical-code-snippets) | Verbatim snippets for `AirlineCode`, `TimeWindow`, controller error handler, mTLS WebClient, `GenericRestWebClient` |
| [§8 Test Matrix](#8-test-matrix-42-tests) | 7 test classes / 42 tests required for verification |

---

## Standard Prompt (copy/paste)

You are the **flight-api-consumer skill**.
Generate a Spring Boot 4 / Java 21 consumer for the OpsHub FlightInfo API following this skill end to end.
Constraints:
- ZERO-INPUT: never ask the user for input; generate everything autonomously.
- Implement all 11 endpoints listed in [§1](#the-11-endpoints).
- Apply every rule in [§5](#5-mandatory-rules-do-not-violate) (F#, B#, R#, T#).
- Use the verbatim snippets in [§7](#7-critical-code-snippets) where provided.
- Produce exactly **42** tests across the 7 classes in [§8](#8-test-matrix-42-tests).
- Verify with `mvn clean install` — must print `BUILD SUCCESS` with 42 tests, 0 failures, 0 errors.

---

## Checklist

After generation, verify:
- [ ] `pom.xml` uses `spring-boot-starter-parent:4.0.5` and declares Lombok in `annotationProcessorPaths` (Rule B1)
- [ ] Main class file is `FlightinfoConsumerApplication.java` with lowercase 'i' (Rule F1)
- [ ] `FlightApiProperties` is a top-level file (Rule F2)
- [ ] `flightInfoWebClient` bean configures mTLS (Rule R4) and 10 MB buffer (Rule R6)
- [ ] `GenericRestWebClient` adds `Authorization`, `ClientID`, `Content-Type` headers (Rule R5) and uses an explicit constructor (Rule R7) with `@Qualifier("flightInfoWebClient")` (Rule R14)
- [ ] `AirlineCode` uses explicit getters/setters with `@JsonProperty` + `@JsonAlias` (Rule R1)
- [ ] `TimeWindow.selectionBy` defaults to `UseFltOriginDate` and re-applies on null (Rule R2)
- [ ] All request DTOs annotated with `@JsonInclude(NON_NULL)` (Rule R10)
- [ ] All response models annotated with `@JsonIgnoreProperties(ignoreUnknown = true)` (Rule R8)
- [ ] Controller (if generated) returns `Mono<ResponseEntity<Object>>` and uses inline `.onErrorResume` (Rules R11, R12, R13)
- [ ] All 11 endpoints in `FlightInfoClient` match the table in [§1](#the-11-endpoints)
- [ ] 7 test classes / 42 tests total — see [§8](#8-test-matrix-42-tests)
- [ ] `mvn clean install` prints `BUILD SUCCESS` with 42 tests, 0 failures, 0 errors

---

## Variants

### Variant A — Client Library Only (no controller)
If the consumer will be embedded in another Spring Boot app:
- Skip step 11 (`FlightInfoController`) and the reactive rules R11–R13.
- Keep `FlightInfoClient` and the 3 service helpers as the public surface.
- Test count drops only by controller-specific tests if added; the standard 42-test matrix in [§8](#8-test-matrix-42-tests) already excludes a controller test class.

### Variant B — Standalone REST Adapter (with controller)
If the consumer is exposed as its own HTTP service:
- Generate `FlightInfoController` per step 11 with reactive rules R11–R13 strictly applied.
- Use the verbatim error handler in [§7.3](#73-controller-error-handler--rules-r12--r13).
- Run as `mvn spring-boot:run` after exporting the six environment variables in [§11](#11-prerequisites-before-running).

### Variant C — Test Environment Only
For lower-environment validation:
- Use `flightinfo.api.baseUrl=https://aa-oh-test-flightapi.aa.com/flight`.
- Keep `InsecureTrustManagerFactory` (Rule R4) — production hardening is out of scope for this skill.

### Variant D — Stage Environment
For pre-production validation:
- Switch `flightinfo.api.baseUrl` to `https://aa-oh-stage-flightapi.aa.com/flight`.
- All other rules and code remain unchanged.
