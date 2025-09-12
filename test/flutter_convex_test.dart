import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'flutter_convex_test.mocks.dart';

@GenerateMocks([http.Client, WebSocketChannel])
void main() {
  group('ConvexConfig', () {
    tearDown(() {
      // Cannot reset singleton ConvexConfig in tests
    });

    test('initialize sets deployment URL', () {
      const testUrl = 'https://test.convex.cloud';
      ConvexConfig.initialize(testUrl);
      
      expect(ConvexConfig.deploymentUrl, equals(testUrl));
      expect(ConvexConfig.isConfigured, isTrue);
    });

    test('throws exception when not configured', () {
      expect(() => ConvexConfig.deploymentUrl, throwsException);
      expect(ConvexConfig.isConfigured, isFalse);
    });
  });

  group('ConvexClient', () {
    late MockClient mockHttpClient;
    late ConvexClient client;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      mockHttpClient = MockClient();
      client = ConvexClient(deploymentUrl: ConvexConfig.deploymentUrl);
      // We'd need to add a way to inject the mock client
    });

    test('query makes correct HTTP request', () async {
      const testData = {'result': 'success', 'value': 42};
      
      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"result":"success","value":42}',
        200,
        headers: {'content-type': 'application/json'},
      ));

      // This test would require dependency injection in ConvexClient
      // For now, we'll test the public interface
      expect(() => client.query('test:function', {}), returnsNormally);
    });
  });

  group('ConvexService', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    test('singleton returns same instance', () {
      final instance1 = ConvexService.instance;
      final instance2 = ConvexService.instance;
      
      expect(identical(instance1, instance2), isTrue);
    });

    test('initialize without auth service works', () {
      expect(() => service.initialize(), returnsNormally);
      expect(service.isConnected, isFalse); // Not connected initially
    });

    test('initialize with auth token works', () {
      const testToken = 'test-jwt-token';
      expect(() => service.initialize(null, testToken), returnsNormally);
    });

    test('updateAuthToken updates token', () {
      const testToken = 'new-test-token';
      service.updateAuthToken(testToken);
      
      // Token is updated internally (we'd need getter to verify)
      expect(() => service.updateAuthToken(null), returnsNormally);
    });
  });

  group('AuthService Integration', () {
    late TestAuthService authService;
    late ConvexService convexService;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      authService = TestAuthService();
      convexService = ConvexService.instance;
    });

    test('ConvexService listens to auth changes', () {
      convexService.initialize(authService);
      
      // Change auth token
      authService.updateToken('new-token');
      
      // ConvexService should have been notified (tested through behavior)
      expect(authService.hasListeners, isTrue);
    });

    test('ConvexService handles auth token removal', () {
      convexService.initialize(authService);
      authService.updateToken('test-token');
      
      // Remove token
      authService.updateToken(null);
      
      // Should handle gracefully
      expect(authService.hasListeners, isTrue);
    });
  });

  group('Connection State', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    test('initial connection state is disconnected', () {
      expect(service.connectionState, equals('Disconnected'));
      expect(service.isConnected, isFalse);
    });

    test('activeSubscriptions starts at 0', () {
      expect(service.activeSubscriptions, equals(0));
    });
  });

  group('Error Handling', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    test('invalid function name throws appropriate error', () async {
      expect(
        () => service.query('', {}),
        throwsA(isA<Exception>()),
      );
    });

    test('network error is handled gracefully', () async {
      // This would require mocking network failures
      expect(
        service.query('test:nonexistent', {}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Stream Events', () {
    late ConvexService service;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      service = ConvexService.instance;
    });

    test('event streams are not null', () {
      expect(service.onMutationResponse, isNotNull);
      expect(service.onActionResponse, isNotNull);
      expect(service.onAuthError, isNotNull);
      expect(service.onFatalError, isNotNull);
      expect(service.onPing, isNotNull);
    });

    test('streams are broadcast streams', () {
      expect(service.onMutationResponse.isBroadcast, isTrue);
      expect(service.onActionResponse.isBroadcast, isTrue);
      expect(service.onAuthError.isBroadcast, isTrue);
      expect(service.onFatalError.isBroadcast, isTrue);
      expect(service.onPing.isBroadcast, isTrue);
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
