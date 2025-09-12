import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Low-level HTTP client for Convex API operations
/// 
/// Provides direct access to Convex HTTP endpoints for queries, mutations, and actions.
/// For most use cases, consider using [ConvexService] instead which provides
/// additional features like real-time subscriptions and connection management.
class ConvexClient {
  final String deploymentUrl;
  final String? authToken;

  ConvexClient({required this.deploymentUrl, this.authToken});

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  /// Execute a Convex query function
  Future<T?> query<T>(String functionName, Map<String, dynamic> args) async {
    try {
      final url = Uri.parse('$deploymentUrl/api/query');
      final requestBody = {
        'path': functionName,
        'args': args,
        'format': 'json',
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if response has status field
        if (responseData is Map && responseData.containsKey('status')) {
          if (responseData['status'] == 'success') {
            return responseData['value'] as T?;
          } else {
            return null;
          }
        } else {
          // Direct response value
          return responseData as T?;
        }
      } else {
        debugPrint('Convex query failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Convex query error: $e');
      return null;
    }
  }

  /// Execute a Convex action function
  Future<T?> action<T>(String functionName, Map<String, dynamic> args) async {
    try {
      final url = Uri.parse('$deploymentUrl/api/action');
      final requestBody = {
        'path': functionName,
        'args': args,
        'format': 'json',
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if response has status field
        if (responseData is Map && responseData.containsKey('status')) {
          if (responseData['status'] == 'success') {
            return responseData['value'] as T?;
          } else {
            return null;
          }
        } else {
          // Direct response value
          return responseData as T?;
        }
      } else {
        debugPrint('Convex action failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Convex action error: $e');
      return null;
    }
  }

  /// Execute a Convex mutation function
  Future<T?> mutation<T>(String functionName, Map<String, dynamic> args) async {
    try {
      final url = Uri.parse('$deploymentUrl/api/mutation');
      final requestBody = {
        'path': functionName,
        'args': args,
        'format': 'json',
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if response has status field
        if (responseData is Map && responseData.containsKey('status')) {
          if (responseData['status'] == 'success') {
            return responseData['value'] as T?;
          } else {
            return null;
          }
        } else {
          // Direct response value
          return responseData as T?;
        }
      } else {
        debugPrint(
          'Convex mutation failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Convex mutation error: $e');
      return null;
    }
  }

  /// Alternative function calling format: /api/run/{functionIdentifier}
  Future<T?> runFunction<T>(
    String functionPath,
    Map<String, dynamic> args, {
    String format = 'json',
  }) async {
    try {
      // Convert path from 'module:function' to 'module/function'
      final functionIdentifier = functionPath.replaceAll(':', '/');
      final url = Uri.parse('$deploymentUrl/api/run/$functionIdentifier');
      final requestBody = {'args': args, 'format': format};

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData is Map && responseData.containsKey('status')) {
          if (responseData['status'] == 'success') {
            return responseData['value'] as T?;
          } else {
            return null;
          }
        } else {
          return responseData as T?;
        }
      } else {
        debugPrint(
          'Convex run function failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Convex run function error: $e');
      return null;
    }
  }
}