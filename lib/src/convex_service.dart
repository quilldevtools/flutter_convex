import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import 'convex_client.dart';
import 'convex_config.dart';

/// Connection state for real-time WebSocket connection
enum ConvexConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Subscription state for tracking active subscriptions
class ConvexSubscription<T> {
  final String functionName;
  final Map<String, dynamic> args;
  final StreamController<T?> controller;
  final String subscriptionId;

  ConvexSubscription({
    required this.functionName,
    required this.args,
    required this.controller,
    required this.subscriptionId,
  });

  void dispose() {
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

/// 🚀 CORE SERVICE FOR ALL CONVEX OPERATIONS
///
/// Provides both real-time subscriptions (WebSocket) and HTTP operations
/// for optimal performance and user experience.
///
/// ✅ Real-time subscriptions for live data updates
/// ✅ HTTP requests for one-time operations (mutations, actions)
/// ✅ Automatic connection management and reconnection
/// ✅ Optimistic updates support
/// ✅ Stream-based event system
///
/// Usage:
/// ```dart
/// // Initialize in main()
/// ConvexConfig.initialize('https://your-deployment.convex.cloud');
/// ConvexService.instance.initialize(authToken: 'your-token');
///
/// // Real-time data (WebSocket)
/// ConvexService.instance.subscribe<Map<String, dynamic>>('myFunction', {'id': 'example'})
///   .listen((data) => setState(() => _data = data));
///
/// // One-time operations (HTTP)
/// await ConvexService.instance.mutation('myMutation', {'data': 'value'});
/// await ConvexService.instance.action('myAction', {'param': 'value'});
/// ```
class ConvexService extends ChangeNotifier {
  static ConvexService? _instance;
  static ConvexService get instance {
    _instance ??= ConvexService._internal();
    return _instance!;
  }

  ConvexService._internal();

  // HTTP client for one-time operations
  ConvexClient? _httpClient;
  String? _authToken;
  ChangeNotifier? _authService;

  // WebSocket connection for real-time subscriptions
  WebSocketChannel? _wsChannel;
  ConvexConnectionState _connectionState = ConvexConnectionState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Subscription management
  final Map<String, ConvexSubscription> _subscriptions = {};
  int _subscriptionIdCounter = 0;
  
  // Convex protocol state
  String? _sessionId;
  int _connectionCount = 0;
  int _querySetVersion = 0;
  int _identityVersion = 0;
  final Map<int, String> _queryIdToSubscriptionId = {};
  int _nextQueryId = 1;
  
  // Stream controllers for different event types
  final _mutationResponseController = StreamController<Map<String, dynamic>>.broadcast();
  final _actionResponseController = StreamController<Map<String, dynamic>>.broadcast();
  final _authErrorController = StreamController<String>.broadcast();
  final _fatalErrorController = StreamController<String>.broadcast();
  final _pingController = StreamController<void>.broadcast();

  /// Current connection state
  ConvexConnectionState get connectionState => _connectionState;
  
  /// Stream of mutation responses from the server
  Stream<Map<String, dynamic>> get onMutationResponse => _mutationResponseController.stream;
  
  /// Stream of action responses from the server  
  Stream<Map<String, dynamic>> get onActionResponse => _actionResponseController.stream;
  
  /// Stream of authentication errors
  Stream<String> get onAuthError => _authErrorController.stream;
  
  /// Stream of fatal errors that require reconnection
  Stream<String> get onFatalError => _fatalErrorController.stream;
  
  /// Stream of ping events from the server
  Stream<void> get onPing => _pingController.stream;

  /// Initialize with optional auth token or auth service
  /// 
  /// For simple token-based auth:
  /// ```dart
  /// ConvexService.instance.initialize(authToken: 'your-token');
  /// ```
  /// 
  /// For AuthService integration (reactive updates):
  /// ```dart
  /// ConvexService.instance.initialize(authService);
  /// ```
  void initialize([ChangeNotifier? authService, String? authToken]) {
    if (authService != null) {
      _authService = authService;
      _authService!.addListener(_onAuthChanged);
      _updateTokenFromAuthService();
    } else {
      _authToken = authToken;
    }
    _updateHttpClient();
  }

  void _onAuthChanged() {
    _updateTokenFromAuthService();
    _updateHttpClient();
    
    // Reconnect WebSocket with new auth token if connected
    if (_connectionState == ConvexConnectionState.connected) {
      _reconnectWebSocket();
    }
  }

  void _updateTokenFromAuthService() {
    if (_authService != null) {
      // Try to get token from common AuthService patterns
      try {
        // Try accessing 'token' property via reflection-like approach
        final dynamic service = _authService;
        if (service.runtimeType.toString().contains('AuthService')) {
          _authToken = service.token as String?;
        }
      } catch (e) {
        // If reflection fails, token will remain null
        debugPrint('Could not get token from auth service: $e');
      }
    }
  }

  /// Update auth token and reconnect if needed
  void updateAuthToken(String? newToken) {
    if (_authToken != newToken) {
      _authToken = newToken;
      _updateHttpClient();
      
      // Reconnect WebSocket with new auth token if connected
      if (_connectionState == ConvexConnectionState.connected) {
        _reconnectWebSocket();
      }
    }
  }

  void _updateHttpClient() {
    _httpClient = ConvexClient(
      deploymentUrl: ConvexConfig.deploymentUrl,
      authToken: _authToken,
    );
  }

  ConvexClient get _client {
    if (_httpClient == null) {
      throw Exception(
        'ConvexService not initialized. Call ConvexService.instance.initialize() in main()',
      );
    }
    return _httpClient!;
  }

  // ========================================================================
  // HTTP OPERATIONS (One-time operations)
  // ========================================================================

  /// Execute a Convex query (one-time fetch)
  /// Use this for initial data loading or one-time data fetches
  Future<T?> query<T>(String functionName, Map<String, dynamic> args) async {
    try {
      return await _client.query<T>(functionName, args);
    } catch (e) {
      debugPrint('ConvexService query error: $e');
      rethrow;
    }
  }

  /// Execute a Convex mutation (write operation)
  /// Use this for creating, updating, or deleting data
  Future<T?> mutation<T>(String functionName, Map<String, dynamic> args) async {
    try {
      return await _client.mutation<T>(functionName, args);
    } catch (e) {
      debugPrint('ConvexService mutation error: $e');
      rethrow;
    }
  }

  /// Execute a Convex action (server-side operation)
  /// Use this for external API calls, sending emails, etc.
  Future<T?> action<T>(String functionName, Map<String, dynamic> args) async {
    try {
      return await _client.action<T>(functionName, args);
    } catch (e) {
      debugPrint('ConvexService action error: $e');
      rethrow;
    }
  }

  // ========================================================================
  // WEBSOCKET OPERATIONS (Real-time subscriptions)
  // ========================================================================

  /// Subscribe to real-time updates from a Convex query
  /// Use this for data you want to keep up-to-date automatically
  Stream<T?> subscribe<T>(String functionName, Map<String, dynamic> args) {
    // Create subscription ID
    final subscriptionId = 'sub_${_subscriptionIdCounter++}';

    // Create stream controller
    final controller = StreamController<T?>.broadcast();

    // Create subscription
    final subscription = ConvexSubscription<T>(
      functionName: functionName,
      args: args,
      controller: controller as StreamController<T?>,
      subscriptionId: subscriptionId,
    );

    _subscriptions[subscriptionId] = subscription;

    // Ensure WebSocket connection
    _ensureWebSocketConnection();

    // Send subscription request when connected
    _sendSubscriptionRequest(subscription);

    // Return stream that auto-unsubscribes when no listeners
    return controller.stream.asBroadcastStream(
      onCancel: (sub) {
        _unsubscribe(subscriptionId);
      },
    );
  }

  void _ensureWebSocketConnection() {
    if (_connectionState == ConvexConnectionState.disconnected) {
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (_connectionState == ConvexConnectionState.connecting ||
        _connectionState == ConvexConnectionState.connected) {
      return;
    }

    _setConnectionState(ConvexConnectionState.connecting);

    try {
      // Use actual Convex WebSocket protocol endpoint
      final wsUrl = ConvexConfig.deploymentUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://') + '/api/1.27.0/sync';
      
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );

      // Generate proper UUID format session ID (Convex expects UUID format)
      _sessionId = _generateSessionId();
      _connectionCount++;
      
      // Send initial Connect message
      _sendConnectMessage();
      
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _handleWebSocketError(e);
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;
      
      switch (type) {
        case 'Transition':
          _handleTransition(data);
          break;
        case 'MutationResponse':
          _handleMutationResponse(data);
          break;
        case 'ActionResponse':
          _handleActionResponse(data);
          break;
        case 'AuthError':
          _handleAuthError(data);
          break;
        case 'FatalError':
          _handleFatalError(data);
          break;
        case 'Ping':
          _handlePing(data);
          break;
        default:
          debugPrint('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _handleTransition(Map<String, dynamic> data) {
    final modifications = data['modifications'] as List<dynamic>? ?? [];
    
    for (final mod in modifications) {
      final modMap = mod as Map<String, dynamic>;
      final modType = modMap['type'] as String?;
      final queryId = modMap['queryId'] as int?;
      
      if (queryId == null) continue;
      
      final subscriptionId = _queryIdToSubscriptionId[queryId];
      if (subscriptionId == null || !_subscriptions.containsKey(subscriptionId)) {
        continue;
      }
      
      final subscription = _subscriptions[subscriptionId]!;
      
      switch (modType) {
        case 'QueryUpdated':
          final value = modMap['value'];
          subscription.controller.add(value);
          break;
        case 'QueryFailed':
          final errorMessage = modMap['errorMessage'] as String? ?? 'Query failed';
          debugPrint('Convex query failed: $errorMessage');
          subscription.controller.addError(Exception(errorMessage));
          break;
        case 'QueryRemoved':
          break;
      }
    }
    
    // Update version numbers
    final endVersion = data['endVersion'] as Map<String, dynamic>?;
    if (endVersion != null) {
      _querySetVersion = endVersion['querySet'] as int? ?? _querySetVersion;
      _identityVersion = endVersion['identity'] as int? ?? _identityVersion;
    }
  }
  
  void _handleMutationResponse(Map<String, dynamic> data) {
    _mutationResponseController.add(data);
  }
  
  void _handleActionResponse(Map<String, dynamic> data) {
    _actionResponseController.add(data);
  }
  
  void _handleAuthError(Map<String, dynamic> data) {
    final error = data['error'] as String? ?? 'Authentication error';
    debugPrint('Convex auth error: $error');
    _setConnectionState(ConvexConnectionState.error);
    _authErrorController.add(error);
  }
  
  void _handleFatalError(Map<String, dynamic> data) {
    final error = data['error'] as String? ?? 'Fatal error';
    debugPrint('Convex fatal error: $error');
    _setConnectionState(ConvexConnectionState.error);
    _fatalErrorController.add(error);
  }
  
  void _handlePing(Map<String, dynamic> data) {
    _pingController.add(null);
  }

  void _handleWebSocketError(dynamic error) {
    debugPrint('Convex WebSocket error: $error');
    _setConnectionState(ConvexConnectionState.error);
    _scheduleReconnect();
  }

  void _handleWebSocketClosed() {
    _setConnectionState(ConvexConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Convex: Max reconnection attempts reached');
      return;
    }

    if (_subscriptions.isEmpty) {
      // No active subscriptions, don't reconnect
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: (2 * _reconnectAttempts).clamp(1, 30));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _setConnectionState(ConvexConnectionState.reconnecting);
      _connectWebSocket();
    });
  }

  void _reconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _setConnectionState(ConvexConnectionState.disconnected);
    _connectWebSocket();
  }

  void _sendConnectMessage() {
    if (_wsChannel == null || _sessionId == null) return;
    
    final connectMessage = {
      'type': 'Connect',
      'sessionId': _sessionId!,
      'connectionCount': _connectionCount,
      'lastCloseReason': null,
      'clientTs': DateTime.now().millisecondsSinceEpoch,
    };
    
    _wsChannel!.sink.add(jsonEncode(connectMessage));
    
    // After connect, send auth if available
    Timer(const Duration(milliseconds: 100), () {
      _sendAuthMessage();
    });
  }
  
  void _sendAuthMessage() {
    if (_wsChannel == null) return;
    
    final authMessage = {
      'type': 'Authenticate',
      'tokenType': _authToken != null ? 'User' : 'None',
      'baseVersion': _identityVersion,
    };
    
    if (_authToken != null) {
      authMessage['value'] = _authToken!;
    }
    
    _wsChannel!.sink.add(jsonEncode(authMessage));
    
    // Set connected state after auth
    Timer(const Duration(milliseconds: 200), () {
      if (_connectionState == ConvexConnectionState.connecting) {
        _setConnectionState(ConvexConnectionState.connected);
        _reconnectAttempts = 0;
        _resubscribeAll();
      }
    });
  }

  void _sendSubscriptionRequest(ConvexSubscription subscription) {
    if (_wsChannel != null &&
        _connectionState == ConvexConnectionState.connected) {
      
      final queryId = _nextQueryId++;
      _queryIdToSubscriptionId[queryId] = subscription.subscriptionId;
      
      // Send ModifyQuerySet message to add the query
      final addQuery = {
        'type': 'Add',
        'queryId': queryId,
        'udfPath': subscription.functionName,
        'args': [subscription.args], // Convex expects args as an array
      };
      
      final modifyMessage = {
        'type': 'ModifyQuerySet',
        'baseVersion': _querySetVersion,
        'newVersion': _querySetVersion + 1,
        'modifications': [addQuery],
      };
      
      _querySetVersion++;
      
      _wsChannel!.sink.add(jsonEncode(modifyMessage));
    }
  }

  void _resubscribeAll() {
    for (final subscription in _subscriptions.values) {
      _sendSubscriptionRequest(subscription);
    }
  }

  void _unsubscribe(String subscriptionId) {
    final subscription = _subscriptions.remove(subscriptionId);
    if (subscription != null) {
      // Find the query ID for this subscription
      int? queryIdToRemove;
      _queryIdToSubscriptionId.forEach((queryId, subId) {
        if (subId == subscriptionId) {
          queryIdToRemove = queryId;
        }
      });
      
      // Send unsubscribe message
      if (queryIdToRemove != null && 
          _wsChannel != null &&
          _connectionState == ConvexConnectionState.connected) {
        
        final removeQuery = {
          'type': 'Remove',
          'queryId': queryIdToRemove!,
        };
        
        final modifyMessage = {
          'type': 'ModifyQuerySet',
          'baseVersion': _querySetVersion,
          'newVersion': _querySetVersion + 1,
          'modifications': [removeQuery],
        };
        
        _querySetVersion++;
        
        _wsChannel!.sink.add(jsonEncode(modifyMessage));
        
        _queryIdToSubscriptionId.remove(queryIdToRemove!);
      }

      subscription.dispose();
    }

    // Close WebSocket if no active subscriptions
    if (_subscriptions.isEmpty) {
      _wsChannel?.sink.close();
      _wsChannel = null;
      _setConnectionState(ConvexConnectionState.disconnected);
      _queryIdToSubscriptionId.clear();
      _nextQueryId = 1;
    }
  }

  void _setConnectionState(ConvexConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      notifyListeners();
    }
  }

  /// Generate a proper UUID v4 session ID
  String _generateSessionId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  /// Check if WebSocket is connected and ready for subscriptions
  bool get isConnected => _connectionState == ConvexConnectionState.connected;

  /// Get number of active subscriptions
  int get activeSubscriptions => _subscriptions.length;

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();

    // Dispose all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.dispose();
    }
    _subscriptions.clear();
    
    // Close all stream controllers
    _mutationResponseController.close();
    _actionResponseController.close();
    _authErrorController.close();
    _fatalErrorController.close();
    _pingController.close();

    super.dispose();
  }
}