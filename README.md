# flutter_convex

A Flutter package for Convex integration with real-time subscriptions and optimistic updates.

## Features

- ✅ **Real-time subscriptions** - Live data updates via WebSocket
- ✅ **HTTP operations** - Queries, mutations, and actions
- ✅ **Automatic reconnection** - Handles network issues gracefully
- ✅ **Stream-based events** - Listen to server responses and errors
- ✅ **Cross-platform** - Works on web, mobile, and desktop
- ✅ **Optimistic updates** - Perfect for responsive UIs

## Getting started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_convex: ^0.1.0
```

## Usage

### Basic Setup

```dart
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  // Initialize Convex configuration
  ConvexConfig.initialize('https://your-deployment.convex.cloud');
  
  // Initialize the service
  ConvexService.instance.initialize(authToken: 'your-auth-token');
  
  runApp(MyApp());
}
```

### Real-time Subscriptions

```dart
// Subscribe to real-time data updates
final subscription = ConvexService.instance
  .subscribe<Map<String, dynamic>>('myModule:getMyData', {'id': 'example'})
  .listen((data) {
    print('Data updated: $data');
    // Update your UI here
  });

// Don't forget to cancel when done
subscription.cancel();
```

### HTTP Operations

```dart
// Query for one-time data fetch
final result = await ConvexService.instance.query<Map<String, dynamic>>(
  'myModule:getMyData', 
  {'id': 'example'}
);

// Mutation for data updates
await ConvexService.instance.mutation('myModule:updateMyData', {
  'id': 'example',
  'newValue': 'updated'
});

// Action for server-side operations
await ConvexService.instance.action('myModule:processMyAction', {
  'data': 'value'
});
```

### Advanced: Event Streams

```dart
// Listen to server events (optional - for advanced use cases)
ConvexService.instance.onMutationResponse.listen((response) {
  print('Mutation completed: $response');
});

ConvexService.instance.onAuthError.listen((error) {
  print('Authentication error: $error');
  // Handle re-authentication
});

ConvexService.instance.onFatalError.listen((error) {
  print('Fatal error: $error');
  // Handle critical errors
});
```

### Connection State Monitoring

```dart
// Monitor connection state
ConvexService.instance.addListener(() {
  final state = ConvexService.instance.connectionState;
  print('Connection state: $state');
});

// Check if connected
if (ConvexService.instance.isConnected) {
  print('WebSocket is connected!');
}
```

## API Reference

### ConvexService

The main service class that provides both HTTP and WebSocket functionality.

#### Methods

- `initialize({String? authToken})` - Initialize the service with optional auth token
- `updateAuthToken(String? token)` - Update auth token and reconnect if needed
- `query<T>(String functionName, Map<String, dynamic> args)` - Execute a query
- `mutation<T>(String functionName, Map<String, dynamic> args)` - Execute a mutation
- `action<T>(String functionName, Map<String, dynamic> args)` - Execute an action
- `subscribe<T>(String functionName, Map<String, dynamic> args)` - Subscribe to real-time updates

#### Properties

- `connectionState` - Current WebSocket connection state
- `isConnected` - Whether WebSocket is connected
- `activeSubscriptions` - Number of active subscriptions
- `onMutationResponse` - Stream of mutation responses
- `onActionResponse` - Stream of action responses
- `onAuthError` - Stream of authentication errors
- `onFatalError` - Stream of fatal errors
- `onPing` - Stream of ping events

### ConvexClient

Low-level HTTP client for direct API access.

#### Methods

- `query<T>(String functionName, Map<String, dynamic> args)` - HTTP query
- `mutation<T>(String functionName, Map<String, dynamic> args)` - HTTP mutation
- `action<T>(String functionName, Map<String, dynamic> args)` - HTTP action
- `runFunction<T>(String functionPath, Map<String, dynamic> args)` - Alternative API format

### ConvexConfig

Configuration helper for deployment URL management.

#### Methods

- `initialize(String deploymentUrl)` - Set the deployment URL
- `deploymentUrl` - Get the configured URL
- `isConfigured` - Check if configured

## Requirements

- Flutter 3.3.0+
- Dart 3.7.0+

## License

MIT License - see LICENSE file for details.
