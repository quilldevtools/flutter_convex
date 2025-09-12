/// Configuration for Convex deployment
class ConvexConfig {
  static String? _deploymentUrl;

  /// Initialize Convex with deployment URL
  /// Call this in main() with your deployment URL
  static void initialize(String deploymentUrl) {
    _deploymentUrl = deploymentUrl;
  }

  /// Get the configured deployment URL
  static String get deploymentUrl {
    if (_deploymentUrl == null || _deploymentUrl!.isEmpty) {
      throw Exception(
        'ConvexConfig not initialized. Call ConvexConfig.initialize("https://your-deployment.convex.cloud") in main()',
      );
    }
    return _deploymentUrl!;
  }

  /// Check if Convex is configured
  static bool get isConfigured => _deploymentUrl != null && _deploymentUrl!.isNotEmpty;
}