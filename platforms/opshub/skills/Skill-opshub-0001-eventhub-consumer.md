# Skill: Consuming Messages from Azure Event Hubs using Spring Boot and Kafka

## Purpose

This skill is meant to be reused by any team that needs to consume messages from Azure Event Hubs. It provides a complete set of instructions — configuration, classes, authentication, and runtime setup — so that a new consumer application can be created from scratch without guessing at the wiring. Follow the steps in order and adjust names to fit your project.

---

## What the consumer does

- Connects to an Azure Event Hub namespace using the Kafka protocol with SSL and OAuth token-based authentication.
- Reads messages as raw byte arrays from one or more topics.
- Logs each message payload and its headers.
- If authentication fails temporarily (for example during a geo-replication failover), the consumer retries every 10 seconds instead of shutting down.
- Offsets are committed in batches after processing, so no messages are lost silently.

---

## Prerequisites

- Java 21 or higher.
- Maven as the build tool.
- An Azure Event Hub namespace and the topic name(s) to read from. To find available namespaces and topics, refer to [OpsHub's Cloud Event Offerings in Azure](https://wiki.aa.com/bin/view/Operations%20Technology/Ops%20Hub%20Product/Team%20-%20Platform/Cloud%20Event%20Offerings%20in%20Azure/).
- Request the schema for your topic from the OpsHub team.
- An Azure Service Principal with read access to the Event Hub. To set this up:
  1. Create a Service Principal (SP) at https://developer.aa.com/infrastructure/service-principal if hosting to kpass.
  2. Gain access to the Event Hub using the `objectId` from the Azure SP overview page. Request the OpsHub team to provide access.
  3. Get the `tenant-id` from App Registrations in Entra ID in the Azure portal.
  4. Use the `clientId` (Application ID) and `clientSecret` received during SP creation in your application configuration. These map to the `azure.client-id` and `azure.client-secret` environment variables.

---

## Dependencies

Add the following libraries to your Maven project under a Spring Boot 3.5.x parent:

- **spring-kafka** — provides the Kafka consumer and listener framework that connects to Event Hubs. Exclude `lz4-java` from this dependency to avoid conflicts.
- **msal4j** (group: `com.microsoft.azure`, artifact: `msal4j`) — Microsoft's authentication library for Java. The OAuth callback handler uses this to get tokens from Azure AD with the service principal credentials.
- **spring-boot-starter-web** — starts an embedded web server, useful for health check endpoints. Exclude `spring-boot-starter-logging` from this dependency because the project uses Log4j2 instead.
- **spring-boot-starter-log4j2** — provides Log4j2 as the logging framework.
- **spring-boot-starter-actuator** — exposes health and readiness endpoints so orchestrators like Kubernetes can monitor the app.
- **lombok** (optional) — provides the `@Slf4j` annotation for logging. You can skip this and declare the logger manually if you prefer.
- **avro** (group: `org.apache.avro`, artifact: `avro`, version: `1.12.0`) — Apache Avro library. Used to deserialize raw Avro byte arrays into a `GenericRecord` using `GenericDatumReader` and `BinaryDecoder`. You need the `.avsc` schema file for the topic placed under `src/main/resources/avroschema/`. Request the schema for your topic from the OpsHub team.

---

## Configuration files

Create two files under `src/main/resources/`.

### application.yml

This is the main Spring Boot configuration file. Replace `sample` with your domain name and `SampleConsumer` with your app name throughout. All `${}` values are placeholders that get filled from environment variables at runtime.

The file has a mix of flat dot-notation keys and nested YAML blocks. Flat keys sit on their own line as `key: value`. Nested blocks group related properties under a shared parent. Here is what goes in the file, in order from top to bottom:

**Application name** comes first. It is a flat dot-notation key: `spring.application.name` set to your app name. It sits on its own line and is not part of any nested block.

**Spring block** comes next. It groups together the Spring Boot settings under a `spring:` parent. Under `spring:`, there are three groups:

The first group is `main:` which holds `banner-mode` set to `'off'` and `allow-bean-definition-overriding` set to `true`.

The second group is `autoconfigure:` which holds `exclude` set to `org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration`. This stops Spring from auto-configuring Kafka because the consumer config class does it manually.

The third group is `kafka:` which holds `consumer:`, and inside `consumer:` is `topic` set to `${inputTopicNames}`.

**Listener block** comes after the spring block. It is a separate block at the root of the file, not inside spring. The parent is your domain name (e.g. `sample:`). Inside it is `listener:`, and inside listener are three properties: `concurrency` set to `${inputTopicConcurrency}` which controls how many threads listen in parallel, `clientid` set to `${inputTopicClientIDPrefix}` which is a prefix for identifying this consumer in logs and on the broker, and `groupid` set to `${inputTopicGroupID}` which is the Kafka consumer group this app belongs to.

**Server block** comes next. The parent is `server:` at the root. Inside it is `port` set to `8080` and `servlet:`, and inside `servlet:` is `context-path` set to your app path (e.g. `/SampleConsumer`).

**Azure credentials** come last. These are three flat dot-notation keys, each on its own line: `az.client-id` set to `${azure.client-id}`, `az.client-secret` set to `${azure.client-secret}`, and `az.tenant-id` set to `${azure.tenant-id}`. They must stay as flat keys and not be grouped under a nested `az:` block.

### Event Hub consumer properties file

A separate `.properties` file that holds every Kafka-level setting for connecting to the Event Hub. Name it something meaningful for your project (e.g. `eventhub.properties`). The consumer config class loads this file explicitly.

Choose a key prefix that makes sense for your project (e.g. `kafka.input.`) and use it consistently for all properties below.

**Connection and security — these tell Kafka how to reach and authenticate with the Event Hub:**
- `<prefix>bootstrap-servers` — the Event Hub namespace with port, set to `${input_namespace}`.
- `<prefix>security.protocol` — set to `SASL_SSL`.
- `<prefix>security.sasl.mechanism` — set to `OAUTHBEARER`.
- `<prefix>security.sasl.jaas.config` — set to `org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;`.
- `<prefix>security.sasl.login.callback.handler.class` — the fully qualified class name of the OAuth callback handler you create (described below).

**Request tuning — these control timeouts and batching behavior:**
- `<prefix>max.request.size` — largest message size in bytes the consumer will accept (e.g. `900000`).
- `<prefix>request.timeout.ms` — how long to wait for a broker response before timing out (e.g. `60000`).
- `<prefix>linger.ms` — how long to wait before sending a batch (e.g. `500`).
- `<prefix>delivery.timeout.ms` — total time allowed for a message to be acknowledged (e.g. `181500`).
- `<prefix>metadata.max.age.ms` — how often to refresh broker metadata (e.g. `180000`).
- `<prefix>connections.max.idle.ms` — how long an idle connection stays open before being closed (e.g. `60000`).

**Polling — these control how many messages are fetched at a time:**
- `kafka.input.max.poll.records` — how many messages to fetch per poll (e.g. `20`).
- `kafka.input.max.poll.interval.ms` — if the consumer takes longer than this between polls, the broker considers it dead (e.g. `660000`).

---

## Classes to create

You need five classes total.

### 1. OAuthBearerTokenImpl

A small helper class that wraps an OAuth token so Kafka can use it. The callback handler (described next) creates an instance of this class every time it acquires a new token.

- It implements the `OAuthBearerToken` interface from the Kafka library (`org.apache.kafka.common.security.oauthbearer.OAuthBearerToken`).
- Its constructor takes two arguments: the token as a string and the expiry time as a `java.util.Date`.
- It stores the token string in a field. It converts the expiry date to milliseconds by calling `getTime()` on the date and stores that too.
- `value()` returns the stored token string.
- `lifetimeMs()` returns the stored expiry time in epoch milliseconds.
- `scope()`, `principalName()`, and `startTimeMs()` all return `null` — they are not used for Event Hub authentication.

### 2. OAuth Callback Handler

This class is how Kafka gets a valid OAuth token to authenticate with the Event Hub. Kafka creates and calls this class on its own — it is not managed by Spring.

- It implements `AuthenticateCallbackHandler` from the Kafka library (`org.apache.kafka.common.security.auth.AuthenticateCallbackHandler`).
- It uses the MSAL4J library to talk to Azure AD and get a token.

**What it stores:**
- An authority URL, starting as `"https://login.microsoftonline.com/"`. The tenant ID gets appended to it during setup.
- A cached MSAL client (`ConfidentialClientApplication`). This is created once on first use and reused for every token request after that.
- Token request parameters (`ClientCredentialParameters`) that hold the scope.
- The service principal credentials: tenant ID, app ID, and app secret.

**How it sets up (the `configure` method):**
- Kafka passes in the consumer properties map.
- It reads the bootstrap server from the map using the key `ProducerConfig.BOOTSTRAP_SERVERS_CONFIG`, strips any square brackets, prepends `https://`, and extracts the host to build the token scope automatically (e.g. `https://mynamespace.servicebus.windows.net/.default`). You do not need to hardcode the scope anywhere.
- It builds the token request parameters with that scope using `ClientCredentialParameters.builder(Collections.singleton(sbUri + "/.default")).build()`.
- It reads the service principal credentials from the map using the keys `sp.tenant.id`, `sp.client.id`, and `sp.client.secret`.
- It appends the tenant ID to the authority URL.

**How it handles token requests (the `handle` method):**
- Kafka calls this with one or more callbacks.
- If the callback is an `OAuthBearerTokenCallback`, it calls a helper method to get a token and sets it on the callback.
- For any other callback type, it throws `UnsupportedCallbackException`.

**How it acquires the token (a helper method, e.g. `getOAuthBearerToken`):**
- Inside a `synchronized` block, it checks if the MSAL client has been created yet. If not, it creates one using `ConfidentialClientApplication.builder()` with the app ID, a credential built from the app secret via `ClientCredentialFactory.createFromSecret()`, and the authority URL. The synchronized block ensures this only happens once even if multiple threads call it.
- It calls `aadClient.acquireToken(aadParameters).get()` to get the authentication result.
- It creates and returns a new `OAuthBearerTokenImpl` using the access token string and expiry date from the result.

**The `close` method** is empty — there is nothing to clean up.

### 3. Kafka Consumer Configuration

A Spring configuration class that wires up everything Kafka needs to connect to the Event Hub and start consuming.

**How it loads properties:**
- It is annotated with `@PropertySource` pointing to the Event Hub properties file created earlier.
- It uses `@Value` annotations to inject every property: connection settings, security settings, request tuning, polling limits, and the three Azure credentials from `application.yml`.

**What beans it creates:**

First, a bean that returns all consumer properties as a `Map<String, Object>`. This map contains:
- The service principal credentials under custom keys `sp.tenant.id`, `sp.client.id`, and `sp.client.secret`. These are how the callback handler receives the credentials — Kafka passes this entire map to the handler's `configure` method.
- All the Kafka connection and security settings (bootstrap servers, security protocol, SASL mechanism, JAAS config, callback handler class name).
- All request tuning and polling settings.
- Auto offset reset set to `earliest` — when the consumer group has no saved offset, it starts reading from the beginning.
- Auto commit disabled — offsets are committed manually in batches.
- Partition assignment set to round-robin so partitions are distributed evenly across consumers.
- Both key and value deserializers set to `ByteArrayDeserializer` — messages arrive as raw bytes with no schema interpretation.

Second, a consumer factory bean that wraps the properties map above in a `DefaultKafkaConsumerFactory`.

Third, a listener container factory bean with a specific name (e.g. `inputAvroConsumerKafkaConnectionFactory`). This is what the message listener references to know how to connect. It creates a `ConcurrentKafkaListenerContainerFactory`, sets the consumer factory on it, and configures:
- Acknowledgement mode to `BATCH` — Spring commits offsets after each batch of messages is processed.
- Auth exception retry interval to 10 seconds — if authentication fails (e.g. during a geo-failover), the consumer waits 10 seconds and retries instead of shutting down permanently.

Fourth, a static `PropertySourcesPlaceholderConfigurer` bean. This is required so that `@Value` placeholders from the external properties file resolve correctly.

### 4. Message Listener

This is the class that actually receives messages, converts them from Avro bytes to a readable format using standard Apache Avro classes, and logs them.

- It is a Spring component (annotated with `@Component`).
- It has a method annotated with `@KafkaListener` that tells Spring Kafka what to listen to. The annotation specifies:
  - The topic name, read from `spring.kafka.consumer.topic` in `application.yml`.
  - The container factory bean name from the config class above.
  - The client ID prefix, consumer group ID, and concurrency, read from the listener section in `application.yml`.

**Schema loading:**

The class needs the Avro schema to deserialize messages. Load the `.avsc` schema file once and keep it as a field so it is not re-parsed on every message. Use `Schema.Parser` to parse the schema from the classpath resource (e.g. `new Schema.Parser().parse(getClass().getResourceAsStream("/avroschema/sample.avsc"))`). You can do this in the constructor, a `@PostConstruct` method, or a lazy-init field.

**How it processes each message:**

When a message arrives, the method receives it as a `ConsumerRecord<Object, Object>`.

Inside a try block:
- It casts the message value to `byte[]`.
- It creates a `GenericDatumReader<GenericRecord>` using the loaded schema.
- It creates a `BinaryDecoder` by calling `DecoderFactory.get().binaryDecoder(byteArray, null)`.
- It calls `datumReader.read(null, decoder)` which returns a `GenericRecord` — this is the deserialized message.
- It calls `toString()` on the `GenericRecord` to get a human-readable JSON-like string of the entire message.
- It logs this string along with the topic name, partition number, offset, and timestamp so you can see the full decoded message content in the logs.

If anything goes wrong, the catch block logs the error with the topic, partition, offset, timestamp, and the exception message so you can trace exactly which message failed.

Finally, it logs the total execution time in milliseconds from the start of processing to the end.

### 5. Application Entry Point

The main class that starts the Spring Boot application.

- It must have these four annotations:
  - `@SpringBootApplication` — standard Spring Boot startup.
  - `@EnableWebMvc` — turns on the web layer for health check endpoints.
  - `@EnableKafka` — tells Spring to look for `@KafkaListener` methods and start them.
  - `@EnableAutoConfiguration` — lets Spring auto-configure other beans. This works alongside the manual Kafka config because the Kafka auto-configuration is excluded in `application.yml`.
- Its `main` method calls `SpringApplication.run` and can store the returned application context if other parts of the app need to access it (e.g. a static utility class).

---


## Project layout

```
src/main/
├── java/com/example/consumer/
│   ├── ConsumerApplication.java
│   ├── auth/
│   │   ├── OAuthBearerTokenImpl.java
│   │   └── ServicePrincipalCallbackHandler.java
│   ├── config/
│   │   └── KafkaConsumerConfig.java
│   └── listener/
│       └── EventHubMessageConsumer.java
└── resources/
    ├── application.yml
    └── eventhub.properties
```

---

## Environment variables needed at runtime

| Variable | What it is | Example |
|----------|-----------|---------|
| `input_namespace` | Event Hub namespace with port | `mynamespace.servicebus.windows.net:9093` |
| `inputTopicNames` | Topic (Event Hub) name to consume | `my-events-topic` |
| `inputTopicGroupID` | Kafka consumer group ID | `my-consumer-group` |
| `inputTopicClientIDPrefix` | Prefix for the consumer client ID | `my-consumer` |
| `inputTopicConcurrency` | Number of concurrent listener threads | `1` |
| `azure.client-id` | Service principal application ID | _(from Azure portal)_ |
| `azure.client-secret` | Service principal secret | _(from Azure portal)_ |
| `azure.tenant-id` | Azure AD tenant ID | _(from Azure portal)_ |

---

## Test Cases (required and fast)

Always generate tests along with the skill, but keep the default set small so generation stays fast.

Generate this small smoke set by default:

- One test for `OAuthBearerTokenImpl` to verify token value and expiry mapping.
- One test for the listener happy path to verify Avro bytes become a `GenericRecord` and `record.toString()` is logged.

Add broader tests only when specifically requested. These are optional and slower:

- Callback handler error paths and unsupported callback handling.
- Kafka config bean wiring and `@SpringBootTest` context-load tests.
- Listener failure cases like invalid bytes or null payloads.

Use JUnit 5 and Mockito through `spring-boot-starter-test` (scope `test`) for this default smoke set.

---


## How to reuse this in a new project

1. Create a new Spring Boot Maven project.
2. Add the dependencies listed above to your `pom.xml`.
3. Create `application.yml` under `src/main/resources/` following the structure described above. Pay special attention to which keys are top-level flat keys and which are nested blocks.
4. Create the Event Hub consumer properties file under `src/main/resources/` with all the connection, security, tuning, and polling keys listed above.
5. Create the five Java classes described above. Adjust package names to fit your project.
6. Update the callback handler class path in the properties file to match the package where you placed it.
7. Set the environment variables listed above and run the application.
