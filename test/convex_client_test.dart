import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('ConvexClient', () {
    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
    });

    test('can be instantiated with deployment URL', () {
      const deploymentUrl = 'https://client-test.convex.cloud';
      
      expect(() => ConvexClient(deploymentUrl: deploymentUrl), returnsNormally);
    });

    test('can be instantiated with auth token', () {
      const deploymentUrl = 'https://client-test.convex.cloud';
      const authToken = 'test-auth-token';
      
      expect(() => ConvexClient(
        deploymentUrl: deploymentUrl,
        authToken: authToken,
      ), returnsNormally);
    });

    test('can be instantiated with both URL and token', () {
      const deploymentUrl = 'https://authenticated-client.convex.cloud';
      const authToken = 'Bearer jwt-token-here';
      
      final client = ConvexClient(
        deploymentUrl: deploymentUrl,
        authToken: authToken,
      );
      
      expect(client, isNotNull);
      expect(client, isA<ConvexClient>());
    });

    test('accepts different deployment URL formats', () {
      const testUrls = [
        'https://happy-animal-123.convex.cloud',
        'https://my-app.convex.site',
        'https://localhost:3000',
        'https://custom-domain.example.com',
      ];
      
      for (final url in testUrls) {
        expect(() => ConvexClient(deploymentUrl: url), returnsNormally);
      }
    });

    test('handles various auth token formats', () {
      const deploymentUrl = 'https://auth-test.convex.cloud';
      const testTokens = [
        'simple-token',
        'Bearer jwt.token.here',
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.test.signature',
      ];
      
      for (final token in testTokens) {
        expect(() => ConvexClient(
          deploymentUrl: deploymentUrl,
          authToken: token,
        ), returnsNormally);
      }
    });
  });
}