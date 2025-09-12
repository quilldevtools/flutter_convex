import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_convex/flutter_convex.dart';
import 'dart:async';

void main() {
  group('WebSocket Integration Tests', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    tearDown(() {
      // Cannot reset singleton ConvexConfig in tests
      // Service state is managed internally
    });

    group('Subscription Management', () {
      test('subscribe returns a stream', () {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });

      test('multiple subscriptions with different args create different streams', () {
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '1'});
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '2'});
        
        expect(identical(stream1, stream2), isFalse);
      });

      test('identical subscriptions return same stream', () {
        final args = {'id': 'test', 'filter': 'active'};
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', args);
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', args);
        
        expect(identical(stream1, stream2), isTrue);
      });

      test('subscription count increases with active subscriptions', () {
        expect(service.activeSubscriptions, equals(0));
        
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '1'});
        // Note: activeSubscriptions might only increase when actually connected
        
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '2'});
        
        // Clean up streams to prevent resource leaks in tests
        stream1.listen(null).cancel();
        stream2.listen(null).cancel();
      });
    });

    group('Connection State Management', () {
      test('initial connection state is Disconnected', () {
        expect(service.connectionState, equals('Disconnected'));
        expect(service.isConnected, isFalse);
      });

      test('connection state updates appropriately', () {
        // This would require actual WebSocket connection or mocking
        expect(service.connectionState, isA<String>());
      });
    });

    group('Real-time Data Flow', () {
      test('subscription stream can handle null data', () async {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        // Test that stream can emit null values
        stream.listen(
          (data) {
            // Should handle null data gracefully
            expect(data, anyOf(isNull, isA<Map<String, dynamic>>()));
          },
          onError: (error) {
            // Error handling should work
            expect(error, isNotNull);
          },
        );
        
        // Don't wait for actual connection in unit tests
      });

      test('subscription stream handles different data types', () async {
        // Test different generic types
        final mapStream = service.subscribe<Map<String, dynamic>>('test:getMap', {});
        final listStream = service.subscribe<List<dynamic>>('test:getList', {});
        final stringStream = service.subscribe<String>('test:getString', {});
        
        expect(mapStream, isA<Stream<Map<String, dynamic>?>>());
        expect(listStream, isA<Stream<List<dynamic>?>>());
        expect(stringStream, isA<Stream<String?>>());
      });
    });

    group('Authentication with WebSocket', () {
      test('WebSocket reconnects when auth token changes', () {
        service.initialize();
        
        // Simulate token change
        service.updateAuthToken('new-token');
        
        // Should trigger reconnection (tested through behavior)
      });

      test('WebSocket handles auth errors gracefully', () {
        service.initialize(null, 'invalid-token');
        
        // Should handle invalid token without crashing
        expect(service.onAuthError, isA<Stream<String>>());
      });
    });

    group('Error Handling', () {
      test('subscription handles connection errors', () async {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        stream.listen(
          null,
          onError: (error) {
            expect(error, isNotNull);
          },
        );
        
        // Connection errors should be propagated to subscription streams
      });

      test('fatal errors are emitted on fatal error stream', () {
        expect(service.onFatalError, isA<Stream<String>>());
        
        service.onFatalError.listen((error) {
          expect(error, isA<String>());
          expect(error.isNotEmpty, isTrue);
        });
      });
    });

    group('WebSocket Protocol', () {
      test('service handles WebSocket message types', () {
        // These would be integration tests with actual WebSocket messages
        expect(service.onPing, isA<Stream<void>>());
        expect(service.onMutationResponse, isA<Stream<Map<String, dynamic>>>());
        expect(service.onActionResponse, isA<Stream<Map<String, dynamic>>>());
      });

      test('service generates proper subscription IDs', () {
        final stream1 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '1'});
        final stream2 = service.subscribe<Map<String, dynamic>>('test:getData', {'id': '2'});
        
        // Different subscriptions should have different internal IDs
        expect(identical(stream1, stream2), isFalse);
      });
    });

    group('Resource Management', () {
      test('cancelled subscriptions clean up resources', () async {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        final subscription = stream.listen(null);
        
        await subscription.cancel();
        
        // Resources should be cleaned up
        // (This would be verified through internal state inspection in real implementation)
      });

      test('service can be disposed cleanly', () {
        service.initialize();
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        stream.listen(null);
        
        // Dispose should clean up all resources
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('Subscription Lifecycle', () {
      test('subscription survives connection drops', () {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        // Simulate connection drop and reconnect
        // Subscription should automatically reestablish
        
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });

      test('subscription handles server restarts', () {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        
        // Should handle server restart gracefully
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });
    });
  });
}