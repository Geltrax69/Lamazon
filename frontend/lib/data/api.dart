import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';

/// Where the Go backend lives. Override per build:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// Thin client over the Go API. ponytail: plain http + dartjson, no codegen
/// and no repository layer — there is one caller per endpoint.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _timeout = Duration(seconds: 5);

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
