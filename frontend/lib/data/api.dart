import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'session.dart';

/// Where the Go backend lives. Override per build:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// What a successful sign-in or refresh hands back.
class AuthTokens {
  final String email;
  final String token;
  final String refreshToken;
  final int expiresIn; // seconds until the access token dies

  const AuthTokens({
    required this.email,
    required this.token,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> r) => AuthTokens(
        email: r['email'] as String,
        token: r['token'] as String,
        refreshToken: r['refreshToken'] as String,
        expiresIn: (r['expiresIn'] as num).toInt(),
      );
}

/// Thin client over the Go API. ponytail: plain http + dartjson, no codegen
/// and no repository layer — there is one caller per endpoint.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _timeout = Duration(seconds: 5);
  static const _uploadTimeout = Duration(seconds: 60);

  Uri _url(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  Future<List<dynamic>> _getList(String path, [Map<String, String>? q]) async {
    final res = await http.get(_url(path, q)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('${res.statusCode} on $path');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// Catalog straight from Postgres.
  Future<List<Product>> products({String? tab, String? query}) async {
    final q = <String, String>{
      if (tab != null && tab != 'All') 'tab': tab,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final rows = await _getList('/api/products', q.isEmpty ? null : q);
    return rows.map((r) => _product(r as Map<String, dynamic>)).toList();
  }

  Future<List<Shop>> shops() async {
    final rows = await _getList('/api/shops');
    return rows
        .map((r) => Shop(
              name: r['name'] as String,
              tagline: r['tagline'] as String? ?? '',
              imageUrl: r['imageUrl'] as String? ?? '',
              tab: r['tab'] as String? ?? 'All',
            ))
        .toList();
  }

  /// Everything one shop sells, priced at that shop.
  Future<List<Product>> shopProducts(String shop) async {
    final rows = await _getList('/api/shops/${Uri.encodeComponent(shop)}/products');
    return rows.map((r) => _product(r as Map<String, dynamic>)).toList();
  }

  Future<bool> isServiceable(String city) async {
    final res = await http
        .get(_url('/api/locations/check', {'city': city}))
        .timeout(_timeout);
    if (res.statusCode != 200) return false;
    return (jsonDecode(res.body) as Map<String, dynamic>)['serviceable'] == true;
  }

  // ---- Sign in ----------------------------------------------------------

  /// Asks the backend to email a six-digit code. Throws with the server's
  /// reason (bad address, or a resend too soon after the last one).
  Future<void> requestLoginCode(String email) async {
    final res = await http
        .post(_url('/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}))
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
  }

  /// Trades the code for a token pair.
  Future<AuthTokens> verifyLoginCode(String email, String code) async {
    final res = await http
        .post(_url('/api/login/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'code': code}))
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Trades a refresh token for a fresh pair. The backend rotates the refresh
  /// token too, so whatever comes back replaces both.
  Future<AuthTokens> refreshSession(String refreshToken) async {
    final res = await http
        .post(_url('/api/login/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}))
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// The API puts a human-readable sentence in `error`; show that rather than
  /// a status code.
  String _reason(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String;
    } catch (_) {
      return 'Something went wrong (${res.statusCode})';
    }
  }

  // ---- Notifications ----------------------------------------------------

  /// The VAPID public key the browser needs to subscribe. Empty when the
  /// backend has no keys, which is how push stays optional.
  Future<String> pushPublicKey() async {
    final res = await http.get(_url('/api/push/key')).timeout(_timeout);
    if (res.statusCode != 200) return '';
    return (jsonDecode(res.body) as Map<String, dynamic>)['publicKey'] as String;
  }

  /// Files this browser under the signed-in address, so orders can reach it.
  Future<void> subscribeToPush(Map<String, dynamic> subscription) async {
    final res = await http
        .post(_url('/api/push/subscribe'),
            headers: {...await _authHeader(), 'Content-Type': 'application/json'},
            body: jsonEncode(subscription))
        .timeout(_timeout);
    if (res.statusCode != 204) throw http.ClientException(_reason(res));
  }

  /// Asks the backend to push a test notification to this browser.
  Future<void> sendTestPush() async {
    final res = await http
        .post(_url('/api/push/test'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
  }

  // ---- Seller ----------------------------------------------------------
  //
  // The seller header stands in for a session; the backend reads it the same
  // way whether it comes from here or a curl.
  /// Every seller call is private, so it carries a live token or does not go
  /// at all — a clearer failure than a 401 from the server.
  Future<Map<String, String>> _authHeader() async {
    final token = await Session.instance.freshToken();
    if (token == null) {
      throw http.ClientException('sign in to manage your store');
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Opens the store and uploads its logo in one request, so there is no
  /// window where the store exists without its picture. Returns the Cloudinary
  /// URL, or '' when no photo was attached.
  Future<String> createStore({
    required String name,
    required String location,
    required String city,
    required List<String> categories,
    Uint8List? photo,
  }) async {
    final body = await _send('/api/seller/store', {
      'name': name,
      'location': location,
      'city': city,
      'categories': categories,
    }, photo == null ? const [] : [photo]);
    return body['photoUrl'] as String? ?? '';
  }

  /// Adds the stock line and its photos in one request. Returns the id the
  /// backend assigned and the URLs it stored.
  Future<({String id, List<String> imageUrls})> addItem({
    required String title,
    required String description,
    required String category,
    required double price,
    required int stock,
    List<Uint8List> photos = const [],
  }) async {
    final body = await _send('/api/seller/items', {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
    }, photos);
    return (
      id: body['id'] as String,
      imageUrls: (body['imageUrls'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  /// Extra photos for an item that already exists — the edit screen's path.
  Future<List<String>> addItemPhotos(String itemId, List<Uint8List> photos) async {
    final body = await _send('/api/seller/items/$itemId/photos', const {}, photos);
    return (body['imageUrls'] as List<dynamic>).cast<String>();
  }

  /// One shape for every seller write: JSON when there is nothing to upload,
  /// multipart when there is. The backend accepts both, so the app never has
  /// to sequence two calls and reconcile a half-done result.
  Future<Map<String, dynamic>> _send(
      String path, Map<String, Object?> fields, List<Uint8List> photos) async {
    final auth = await _authHeader();
    final http.Response res;
    if (photos.isEmpty) {
      res = await http
          .post(_url(path),
              headers: {...auth, 'Content-Type': 'application/json'},
              body: jsonEncode(fields))
          .timeout(_timeout);
    } else {
      final req = http.MultipartRequest('POST', _url(path))
        ..headers.addAll(auth);
      // MultipartRequest.fields is a Map, so a repeated key is impossible —
      // list values go as one comma-separated field and the backend splits it.
      fields.forEach((k, v) =>
          req.fields[k] = v is List ? v.join(',') : '$v');
      for (var i = 0; i < photos.length; i++) {
        req.files.add(http.MultipartFile.fromBytes('file', photos[i],
            filename: 'photo_${i + 1}.jpg'));
      }
      res = await http.Response.fromStream(
          await req.send().timeout(_uploadTimeout));
    }
    if (res.statusCode != 201) {
      throw http.ClientException(_reason(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Product _product(Map<String, dynamic> r) => Product(
        id: r['id'] as String,
        name: r['name'] as String,
        category: r['category'] as String? ?? '',
        tab: r['tab'] as String? ?? 'All',
        price: (r['price'] as num).toDouble(),
        imageUrl: r['imageUrl'] as String? ?? '',
        store: r['store'] as String? ?? '',
        description: r['description'] as String? ?? '',
        offers: [
          for (final o in (r['offers'] as List<dynamic>? ?? const []))
            ShopOffer(o['store'] as String, (o['price'] as num).toDouble()),
        ],
      );
}

/// Logs why a call fell back, so a silent offline mode is never a mystery.
void logApiFailure(String what, Object error) {
  debugPrint('API $what failed, using bundled data: $error');
}
