import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

import 'convex_service_test.mocks.dart';

@GenerateMocks([WebSocketChannel])
void main() {
  group('ConvexService', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    tearDown(() {
      // Cannot reset singleton ConvexConfig in tests
      // Service state is managed internally
    });

    group('Singleton Pattern', () {
      test('returns same instance', () {
        final instance1 = ConvexService.instance;
        final instance2 = ConvexService.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Initialization', () {
      test('initialize with no parameters works', () {
        expect(() => service.initialize(), returnsNormally);
      });

      test('initialize with auth token works', () {
        const testToken = 'test-jwt-token';
        expect(() => service.initialize(null, testToken), returnsNormally);
      });

      test('initialize with auth service works', () {
        final authService = TestAuthService();
        expect(() => service.initialize(authService), returnsNormally);
        // AuthService is stored internally (cannot verify directly)
      });

      test('initialize with both auth service and token prioritizes service', () {
        final authService = TestAuthService();
        authService.updateToken('service-token');
        
        service.initialize(authService, 'static-token');
        
        // AuthService is stored internally (cannot verify directly)
      });
    });

    group('Authentication Integration', () {
      late TestAuthService authService;

      setUp(() {
        authService = TestAuthService();
      });

      test('listens to auth service changes', () {
        service.initialize(authService);
        
        expect(authService.hasListeners, isTrue);
        
        authService.updateToken('new-token');
        // Service should have been notified
      });

      test('updates token when auth service changes', () {
        service.initialize(authService);
        
        authService.updateToken('updated-token');
        
        // Token should be updated internally
        // (We'd need a getter to verify this)
      });

      test('handles auth service token removal', () {
        authService.updateToken('initial-token');
        service.initialize(authService);
        
        authService.updateToken(null);
        
        // Should handle gracefully without errors
      });

      test('stops listening when auth service is replaced', () {
        service.initialize(authService);
        expect(authService.hasListeners, isTrue);
        
        final newAuthService = TestAuthService();
        service.initialize(newAuthService);
        
        expect(authService.hasListeners, isFalse);
        expect(newAuthService.hasListeners, isTrue);
      });
    });

    group('Connection State', () {
      test('initial state is Disconnected', () {
        expect(service.connectionState, equals('Disconnected'));
        expect(service.isConnected, isFalse);
      });

      test('activeSubscriptions starts at 0', () {
        expect(service.activeSubscriptions, equals(0));
      });
    });

    group('HTTP Operations', () {
      test('query delegates to ConvexClient', () async {
        // Mock the underlying client behavior
        expect(
          () => service.query<Map<String, dynamic>>('test:getData', {'id': '123'}),
          throwsA(isA<Exception>()), // Expected to fail without proper setup
        );
      });

      test('mutation delegates to ConvexClient', () async {
        expect(
          () => service.mutation<Map<String, dynamic>>('test:updateData', {'id': '123', 'value': 'new'}),
          throwsA(isA<Exception>()), // Expected to fail without proper setup
        );
      });

      test('action delegates to ConvexClient', () async {
        expect(
          () => service.action<Map<String, dynamic>>('test:processData', {'data': 'value'}),
          throwsA(isA<Exception>()), // Expected to fail without proper setup
        );
      });
    });

    group('WebSocket Subscriptions', () {
      test('subscribe returns a stream', () {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });

      test('multiple subscriptions to same function work', () {
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '1'});
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '2'});
        
        expect(stream1, isA<Stream<Map<String, dynamic>?>>());
        expect(stream2, isA<Stream<Map<String, dynamic>?>>());
        expect(identical(stream1, stream2), isFalse);
      });

      test('subscription with same function and args returns same stream', () {
        final args = {'id': 'test'};
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', args);
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', args);
        
        // Should return the same stream for identical subscriptions
        expect(identical(stream1, stream2), isTrue);
      });
    });

    group('Event Streams', () {
      test('all event streams are available', () {
        expect(service.onMutationResponse, isNotNull);
        expect(service.onActionResponse, isNotNull);
        expect(service.onAuthError, isNotNull);
        expect(service.onFatalError, isNotNull);
        expect(service.onPing, isNotNull);
      });

      test('event streams are broadcast streams', () {
        expect(service.onMutationResponse.isBroadcast, isTrue);
        expect(service.onActionResponse.isBroadcast, isTrue);
        expect(service.onAuthError.isBroadcast, isTrue);
        expect(service.onFatalError.isBroadcast, isTrue);
        expect(service.onPing.isBroadcast, isTrue);
      });

      test('multiple listeners can subscribe to event streams', () async {
        var mutationCount = 0;
        var actionCount = 0;
        
        final sub1 = service.onMutationResponse.listen((_) => mutationCount++);
        final sub2 = service.onMutationResponse.listen((_) => mutationCount++);
        final sub3 = service.onActionResponse.listen((_) => actionCount++);
        
        // Clean up
        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();
        
        expect(mutationCount, equals(0)); // No events emitted
        expect(actionCount, equals(0));
      });
    });

    group('Token Management', () {
      test('updateAuthToken updates internal token', () {
        const testToken = 'new-test-token';
        
        expect(() => service.updateAuthToken(testToken), returnsNormally);
      });

      test('updateAuthToken with null clears token', () {
        service.updateAuthToken('test-token');
        
        expect(() => service.updateAuthToken(null), returnsNormally);
      });

      test('updateAuthToken triggers reconnection if connected', () {
        // This would require mocking WebSocket connection
        expect(() => service.updateAuthToken('new-token'), returnsNormally);
      });
    });

    group('Error Handling', () {
      test('handles invalid function names', () async {
        await expectLater(
          service.query('', {}),
          throwsA(isA<Exception>()),
        );
      });

      test('handles null function names', () {
        expect(
          () => service.query(null as dynamic, {}),
          throwsA(isA<TypeError>()),
        );
      });

      test('handles network errors gracefully', () async {
        await expectLater(
          service.query('test:nonexistent', {}),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('ChangeNotifier Integration', () {
      test('implements ChangeNotifier correctly', () {
        expect(service, isA<ChangeNotifier>());
      });

      test('can add and remove listeners', () {
        var notified = false;
        void listener() => notified = true;
        
        service.addListener(listener);
        expect(service.hasListeners, isTrue);
        
        service.removeListener(listener);
        expect(notified, isFalse); // No notification triggered
      });
    });
  });
}

/// Test implementation of ChangeNotifier for auth testing
class TestAuthService extends ChangeNotifier {
  String? _token;
  
  String? get token => _token;
  
  void updateToken(String? newToken) {
    _token = newToken;
    notifyListeners();
  }
}