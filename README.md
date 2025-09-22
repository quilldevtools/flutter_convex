# flutter_convex

A Flutter package for Convex integration with real-time subscriptions and optimistic updates.

![Avid-Convex demo](https://github.com/user-attachments/assets/03a9cf81-ad3c-417e-9288-20ce5e10566e)

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
  
  // Initialize the service (see Authentication section for options)
  ConvexService.instance.initialize();
  
  runApp(MyApp());
}
```

## Authentication

The package supports multiple authentication patterns:

### 1. No Authentication (Public Access)

```dart
// For public/anonymous access to Convex functions
ConvexConfig.initialize('https://your-deployment.convex.cloud');
ConvexService.instance.initialize();

// Use without authentication
final data = await ConvexService.instance.query('public:getData', {});
```

### 2. Static Token Authentication

```dart
// For simple token-based authentication
ConvexService.instance.initialize(null, 'your-jwt-token');

// Use with token
final data = await ConvexService.instance.query('protected:getData', {});
```

### 3. AuthService Integration (Reactive)

```dart
// For apps with AuthService (ChangeNotifier pattern)
// Automatically syncs token changes and reconnects WebSocket
ConvexService.instance.initialize(authService);

// Token updates automatically when authService.token changes
```

#### Example AuthService Implementation

```dart
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  // Required: ConvexService looks for this property
  String? get token => _token;
  
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners(); // ConvexService will be notified
    
    try {
      // Your auth logic here (Clerk, Auth0, Firebase, etc.)
      final response = await yourAuthProvider.signIn(email, password);
      
      _token = response.token;  // ConvexService automatically picks this up
      _user = response.user;
      _isLoading = false;
      
      notifyListeners(); // ConvexService reconnects with new token
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _token = null;  // ConvexService automatically updates
    _user = null;
    notifyListeners(); // ConvexService removes auth and reconnects
  }

  Future<void> refreshToken() async {
    if (_token != null) {
      final newToken = await yourAuthProvider.refreshToken(_token!);
      _token = newToken;
      notifyListeners(); // ConvexService gets new token automatically
    }
  }
}
```

#### Integration with ConvexService

```dart
void main() {
  ConvexConfig.initialize('https://your-deployment.convex.cloud');
  
  final authService = AuthService();
  ConvexService.instance.initialize(authService);
  
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({required this.authService});

  Widget build(BuildContext context) {
    return MaterialApp(
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          if (authService.isAuthenticated) {
            return HomePage(); // ConvexService automatically has auth
          } else {
            return LoginPage(authService: authService);
          }
        },
      ),
    );
  }
}
```

#### AuthService Requirements

For AuthService integration to work, your AuthService must:

1. **Extend ChangeNotifier** - So ConvexService can listen to changes
2. **Have a `token` getter** - ConvexService looks for `authService.token`
3. **Call `notifyListeners()`** - When token changes (login/logout/refresh)

```dart
// Minimum required interface:
class YourAuthService extends ChangeNotifier {
  String? get token => _yourToken;  // Required property
  
  void updateToken(String? newToken) {
    _yourToken = newToken;
    notifyListeners();  // Required - notifies ConvexService
  }
}
```

### 4. Manual Token Management

```dart
// Start without authentication
ConvexService.instance.initialize();

// Add token later
ConvexService.instance.updateAuthToken('new-token');

// Remove token
ConvexService.instance.updateAuthToken(null);
```

### 5. Complete Auth Example

```dart
void main() {
  ConvexConfig.initialize('https://your-deployment.convex.cloud');
  
  // Option A: No auth
  ConvexService.instance.initialize();
  
  // Option B: Static token  
  ConvexService.instance.initialize(null, 'jwt-token');
  
  // Option C: AuthService integration
  final authService = MyAuthService();
  ConvexService.instance.initialize(authService);
  
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

- `initialize([ChangeNotifier? authService, String? authToken])` - Initialize with AuthService or token
  - No params: No authentication
  - First param: AuthService integration (reactive)
  - Second param: Static token authentication
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
