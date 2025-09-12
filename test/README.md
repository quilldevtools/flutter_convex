# Flutter Convex Package Tests

This directory contains comprehensive tests for the flutter_convex package, ensuring reliability and correctness across all major functionality.

## Test Files

### Unit Tests (Individual class testing)
- **`convex_config_test.dart`** - ConvexConfig unit tests 
- **`convex_client_test.dart`** - ConvexClient unit tests 
- **`convex_service_test.dart`** - ConvexService unit tests 

### Integration Tests (End-to-end workflows)
- **`integration_test.dart`** - Complete integration scenarios 

## Key Features Tested

### Authentication Patterns
- No authentication (public access)
- Static token authentication 
- AuthService integration (reactive)
- Manual token management
- Authentication lifecycle management

### Real-time Functionality
- WebSocket subscriptions
- Stream-based event architecture
- Multiple subscription management
- Connection state monitoring

### HTTP Operations
- Query operations
- Mutation operations
- Action operations
- Error handling

### Configuration Management
- Deployment URL configuration
- Singleton pattern enforcement
- Thread-safe operations

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/convex_config_test.dart
flutter test test/convex_client_test.dart
flutter test test/convex_service_test.dart
flutter test test/integration_test.dart

# Run only unit tests (fast, no network calls)
flutter test test/convex_config_test.dart test/convex_client_test.dart test/convex_service_test.dart

# Run only integration tests
flutter test test/integration_test.dart
```

## Test Architecture

### Unit Tests (Class-specific testing)
- **No network dependencies**: Tests run without making HTTP/WebSocket calls
- **Fast execution**: Perfect for CI/CD pipelines
- **Isolated testing**: Each class tested independently
- **Comprehensive coverage**: All public methods and properties tested
- **Mock implementations**: Custom test utilities to avoid external dependencies

### Integration Tests (End-to-end testing)
- **Complete workflows**: Full authentication lifecycle scenarios
- **Service interaction**: How all services work together as a system
- **Real-world patterns**: Common usage patterns developers will use
- **Performance validation**: System behavior under various conditions

### Design Principles
- Test public APIs only (no private member access)
- Handle singleton patterns appropriately  
- Work with actual implementation behavior
- Provide comprehensive coverage without brittle assumptions
- Focus on functionality over implementation details

This dual approach ensures both fast, reliable unit testing and thorough integration validation.