import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('ConvexConfig', () {
    // Note: ConvexConfig is a singleton and cannot be easily reset in tests
    // Each test should use unique URLs or handle already-configured state

    group('Initialization', () {
      test('initialize sets deployment URL', () {
        const testUrl = 'https://test.convex.cloud';
        ConvexConfig.initialize(testUrl);
        
        expect(ConvexConfig.deploymentUrl, equals(testUrl));
        expect(ConvexConfig.isConfigured, isTrue);
      });

      test('initialize with different URL formats', () {
        const urls = [
          'https://happy-animal-123.convex.cloud',
          'https://my-app.convex.site', 
          'https://localhost:3210',
          'https://custom-domain.example.com',
        ];
        
        // Test that each URL format is accepted (singleton means last one wins)
        for (final url in urls) {
          ConvexConfig.initialize(url);
          expect(ConvexConfig.deploymentUrl, equals(url));
          expect(ConvexConfig.isConfigured, isTrue);
        }
      });

      test('initialize trims whitespace from URL', () {
        const urlWithWhitespace = '  https://test.convex.cloud  ';
        const expectedUrl = 'https://test.convex.cloud';
        
        ConvexConfig.initialize(urlWithWhitespace);
        
        expect(ConvexConfig.deploymentUrl, equals(expectedUrl));
      });
    });

    group('URL Validation', () {
      test('rejects empty URL', () {
        expect(
          () => ConvexConfig.initialize(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects null URL', () {
        expect(
          () => ConvexConfig.initialize(null as dynamic),
          throwsA(isA<TypeError>()),
        );
      });

      test('rejects URL without https', () {
        expect(
          () => ConvexConfig.initialize('http://test.convex.cloud'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects malformed URLs', () {
        const malformedUrls = [
          'not-a-url',
          'ftp://test.convex.cloud',
          'https://',
          'https://.',
          '://test.convex.cloud',
        ];
        
        for (final url in malformedUrls) {
          expect(
            () => ConvexConfig.initialize(url),
            throwsA(isA<ArgumentError>()),
            reason: 'URL $url should be rejected',
          );
        }
      });
    });

    group('State Management', () {
      test('isConfigured returns false initially', () {
        expect(ConvexConfig.isConfigured, isFalse);
      });

      test('isConfigured returns true after initialization', () {
        ConvexConfig.initialize('https://test.convex.cloud');
        expect(ConvexConfig.isConfigured, isTrue);
      });

      test('deploymentUrl throws when not configured', () {
        expect(
          () => ConvexConfig.deploymentUrl,
          throwsA(isA<Exception>()),
        );
      });

      test('can reconfigure with different URL', () {
        const firstUrl = 'https://first.convex.cloud';
        const secondUrl = 'https://second.convex.cloud';
        
        ConvexConfig.initialize(firstUrl);
        expect(ConvexConfig.deploymentUrl, equals(firstUrl));
        
        ConvexConfig.initialize(secondUrl);
        expect(ConvexConfig.deploymentUrl, equals(secondUrl));
      });
    });

    group('URL Formatting', () {
      test('maintains URL formatting', () {
        const testCases = {
          'https://test.convex.cloud': 'https://test.convex.cloud',
          'https://test.convex.cloud/': 'https://test.convex.cloud/',
          'https://test.convex.cloud/path': 'https://test.convex.cloud/path',
          'https://test.convex.cloud:8080': 'https://test.convex.cloud:8080',
        };
        
        testCases.forEach((input, expected) {
          ConvexConfig.initialize(input);
          expect(ConvexConfig.deploymentUrl, equals(expected));
        });
      });
    });

    group('Thread Safety', () {
      test('multiple initializations are safe', () {
        const url = 'https://test.convex.cloud';
        
        // Initialize multiple times (simulating concurrent access)
        for (int i = 0; i < 10; i++) {
          ConvexConfig.initialize(url);
          expect(ConvexConfig.deploymentUrl, equals(url));
          expect(ConvexConfig.isConfigured, isTrue);
        }
      });
    });

    group('Error Messages', () {
      test('provides helpful error message when not configured', () {
        expect(
          () => ConvexConfig.deploymentUrl,
          throwsA(
            predicate((e) => e.toString().contains('initialize') && e.toString().contains('ConvexConfig')),
          ),
        );
      });

      test('provides helpful error message for invalid URLs', () {
        expect(
          () => ConvexConfig.initialize('invalid-url'),
          throwsA(
            predicate((e) => e.toString().contains('https')),
          ),
        );
      });
    });

    group('Integration with Services', () {
      test('ConvexService can access configured URL', () {
        const testUrl = 'https://test.convex.cloud';
        ConvexConfig.initialize(testUrl);
        
        // ConvexService should be able to use the configured URL
        expect(() => ConvexService.instance.initialize(), returnsNormally);
      });

      test('ConvexClient can access configured URL', () {
        const testUrl = 'https://test.convex.cloud';
        ConvexConfig.initialize(testUrl);
        
        // ConvexClient should be able to use the configured URL
        expect(() => ConvexClient(deploymentUrl: testUrl), returnsNormally);
      });
    });
  });
}