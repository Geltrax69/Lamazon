import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'addresses.dart';
import 'orders.dart';
import 'seller.dart';
import 'session.dart';
import 'staff.dart';

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

  /// Sign-in waits on the mail provider, not just on us, and the first send
  /// after a cold start pays for DNS and TLS to it as well. Five seconds is
  /// the budget for a database read; this one is somebody else's network.
  static const _authTimeout = Duration(seconds: 20);

  Uri _url(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  Future<List<dynamic>> _getList(String path, [Map<String, String>? q]) async {
    final res = await http.get(_url(path, q)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('${res.statusCode} on $path');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// The shop's navigation: departments, each with its categories nested.
  Future<List<dynamic>> categories() => _getList('/api/categories');

  Future<void> addCategory({
    required String name,
    String parent = '',
    String icon = '',
    String colour = '',
  }) => _staffCall(StaffSession.admin, 'POST', '/api/admin/categories', {
    'name': name,
    'parent': parent,
    'icon': icon,
    'colour': colour,
  });

  Future<void> deleteCategory(String name) => _staffCall(
    StaffSession.admin,
    'DELETE',
    '/api/admin/categories/${Uri.encodeComponent(name)}',
  );

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
        .map(
          (r) => Shop(
            name: r['name'] as String,
            tagline: r['tagline'] as String? ?? '',
            imageUrl: r['imageUrl'] as String? ?? '',
            tab: r['tab'] as String? ?? 'All',
          ),
        )
        .toList();
  }

  /// Everything one shop sells, priced at that shop.
  Future<List<Product>> shopProducts(String shop) async {
    final rows = await _getList(
      '/api/shops/${Uri.encodeComponent(shop)}/products',
    );
    return rows.map((r) => _product(r as Map<String, dynamic>)).toList();
  }

  Future<bool> isServiceable(String city) async {
    final res = await http
        .get(_url('/api/locations/check', {'city': city}))
        .timeout(_timeout);
    if (res.statusCode != 200) return false;
    return (jsonDecode(res.body) as Map<String, dynamic>)['serviceable'] ==
        true;
  }

  // ---- Sign in ----------------------------------------------------------

  /// Asks the backend to email a six-digit code. Throws with the server's
  /// reason (bad address, or a resend too soon after the last one).
  Future<void> requestLoginCode(String email) async {
    final res = await http
        .post(
          _url('/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(_authTimeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
  }

  /// Trades the code for a token pair.
  Future<AuthTokens> verifyLoginCode(String email, String code) async {
    final res = await http
        .post(
          _url('/api/login/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(_authTimeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Trades a refresh token for a fresh pair. The backend rotates the refresh
  /// token too, so whatever comes back replaces both.
  Future<AuthTokens> refreshSession(String refreshToken) async {
    final res = await http
        .post(
          _url('/api/login/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
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

  // ---- Account ----------------------------------------------------------

  /// Who is signed in, with their public id and roles. The backend derives
  /// "seller" from owning a store, so it is right the moment one is opened.
  Future<Map<String, dynamic>> me() async {
    final res = await http
        .get(_url('/api/me'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateMe({String? name, String? phone}) async {
    final res = await http
        .patch(
          _url('/api/me'),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          // Null means "leave it alone"; the backend COALESCEs on its side.
          body: jsonEncode({'name': ?name, 'phone': ?phone}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
  }

  Future<List<Address>> addresses() async {
    final res = await http
        .get(_url('/api/addresses'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return (jsonDecode(res.body) as List<dynamic>)
        .map((r) => Address.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Returns the saved address, whose id comes from the server.
  Future<Address> addAddress(Address a) async {
    final res = await http
        .post(
          _url('/api/addresses'),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'label': a.label.title,
            'line': a.line,
            'city': a.city,
            'pincode': a.pincode,
            'name': a.name,
            'phone': a.phone,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 201) throw http.ClientException(_reason(res));
    return Address.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    final res = await http
        .delete(_url('/api/addresses/$id'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 204) throw http.ClientException(_reason(res));
  }

  // ---- Notifications ----------------------------------------------------

  /// Firebase Web Push certificate public key. Empty when the backend has no
  /// key, which is how push stays optional.
  Future<String> pushPublicKey() async {
    final res = await http.get(_url('/api/push/key')).timeout(_timeout);
    if (res.statusCode != 200) return '';
    return (jsonDecode(res.body) as Map<String, dynamic>)['publicKey']
        as String;
  }

  /// Files this browser under the signed-in address, so orders can reach it.
  Future<void> subscribeToPush(Map<String, dynamic> subscription) async {
    final res = await http
        .post(
          _url('/api/push/subscribe'),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          body: jsonEncode(subscription),
        )
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

  /// Reads the store back. Throws [NoStoreYet] when this account has none,
  /// which is a normal state rather than an error.
  Future<SellerStore> sellerStore() async {
    final res = await http
        .get(_url('/api/seller/store'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode == 404) throw const NoStoreYet();
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final r = jsonDecode(res.body) as Map<String, dynamic>;
    return SellerStore(
      name: r['name'] as String? ?? '',
      photo: null, // the server holds a URL; the picked bytes are local only
      location: r['location'] as String? ?? '',
      city: r['city'] as String? ?? '',
      categories: (r['categories'] as List<dynamic>? ?? const [])
          .cast<String>(),
      status: r['status'] as String? ?? 'approved',
      rejectReason: r['rejectReason'] as String? ?? '',
    )..photoUrl = r['photoUrl'] as String? ?? '';
  }

  /// Saves an edit to a listing that already exists. Photos are not part of
  /// this — they have their own endpoint, and their own way of failing.
  Future<InventoryItem> updateItem(
    String itemId, {
    required String title,
    required String description,
    required String category,
    required double price,
    required double mrp,
    required int stock,
  }) async {
    final res = await http
        .patch(
          _url('/api/seller/items/$itemId'),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'description': description,
            'category': category,
            'price': price,
            'mrp': mrp,
            'stock': stock,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    return _inventoryItem(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<InventoryItem>> sellerItems() async {
    final res = await http
        .get(_url('/api/seller/items'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const [])
        .map((r) => _inventoryItem(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<SellerOrder>> sellerOrders() async {
    final res = await http
        .get(_url('/api/seller/orders'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['orders'] as List<dynamic>? ?? const []).map((raw) {
      final r = raw as Map<String, dynamic>;
      return _sellerOrder(r);
    }).toList();
  }

  SellerOrder _sellerOrder(Map<String, dynamic> r) => SellerOrder(
    id: r['id'] as String,
    itemId: r['itemId'] as String? ?? '',
    itemTitle: r['itemTitle'] as String? ?? '',
    units: (r['units'] as num?)?.toInt() ?? 1,
    amount: (r['amount'] as num?)?.toDouble() ?? 0,
    stage: stageFrom(r['stage'] as String?),
    receiverName: r['receiverName'] as String? ?? '',
    receiverPhone: r['receiverPhone'] as String? ?? '',
    receiverAddress: r['receiverAddress'] as String? ?? '',
    rejectReason: r['rejectReason'] as String? ?? '',
  );

  /// The shop taking the order on. The backend generates the buyer's delivery
  /// code here, so the answer is authoritative — the app never invents one.
  Future<SellerOrder> acceptOrder(String id) async =>
      _sellerOrder(await _post('/api/seller/orders/$id/accept'));

  Future<SellerOrder> rejectOrder(String id, String reason) async =>
      _sellerOrder(
        await _post('/api/seller/orders/$id/reject', body: {'reason': reason}),
      );

  // ---- Buying ------------------------------------------------------------

  /// Places one order against one stock line. [addressId] empty means the
  /// default address; the backend copies it onto the order.
  Future<MyOrder> placeOrder({
    required String itemId,
    int units = 1,
    String addressId = '',
  }) async {
    final body = await _post(
      '/api/orders',
      body: {
        'itemId': itemId,
        'units': units,
        if (addressId.isNotEmpty) 'addressId': addressId,
      },
      expect: 201,
    );
    return MyOrder.fromJson(body);
  }

  /// The buyer's own orders, including the delivery code while one is live.
  Future<List<MyOrder>> myOrders() async {
    final res = await http
        .get(_url('/api/orders'), headers: await _authHeader())
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['orders'] as List<dynamic>? ?? const [])
        .map((r) => MyOrder.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// One shape for the small JSON POSTs that carry a session.
  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, Object?> body = const {},
    int expect = 200,
  }) async {
    final res = await http
        .post(
          _url(path),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode != expect) throw http.ClientException(_reason(res));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---- Admin and delivery ------------------------------------------------
  //
  // Staff calls carry their own token, never the shopper's: the backend keeps
  // the two kinds apart on purpose, and so does this.

  Map<String, String> _staffHeader(StaffSession staff) {
    final token = staff.token;
    if (token == null) throw http.ClientException('sign in first');
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _staffCall(
    StaffSession staff,
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final url = _url(path);
    final headers = {
      ..._staffHeader(staff),
      'Content-Type': 'application/json',
    };
    final payload = body == null ? null : jsonEncode(body);
    final res = await switch (method) {
      'POST' => http.post(url, headers: headers, body: payload),
      'DELETE' => http.delete(url, headers: headers),
      _ => http.get(url, headers: headers),
    }.timeout(_timeout);
    if (res.statusCode == 401) {
      // The token died; sign the panel out rather than looping on errors.
      await staff.signOut();
    }
    if (res.statusCode >= 300) throw http.ClientException(_reason(res));
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {'items': decoded};
  }

  Future<void> adminLogin(String username, String password) async {
    final res = await http
        .post(
          _url('/api/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final r = jsonDecode(res.body) as Map<String, dynamic>;
    await StaffSession.admin.signIn(
      r['token'] as String,
      r['username'] as String,
    );
  }

  Future<Map<String, dynamic>> adminOverview() =>
      _staffCall(StaffSession.admin, 'GET', '/api/admin/overview');

  /// Leaderboards, computed server-side: ranking a thousand orders is the
  /// database's job, not the phone's.
  Future<Map<String, dynamic>> adminInsights() =>
      _staffCall(StaffSession.admin, 'GET', '/api/admin/insights');

  Future<List<dynamic>> adminStores({String status = ''}) async {
    final body = await _staffCall(
      StaffSession.admin,
      'GET',
      '/api/admin/stores${status.isEmpty ? '' : '?status=$status'}',
    );
    return body['items'] as List<dynamic>? ?? const [];
  }

  Future<void> approveStore(String owner) => _staffCall(
    StaffSession.admin,
    'POST',
    '/api/admin/stores/${Uri.encodeComponent(owner)}/approve',
  );

  Future<void> rejectStore(String owner, String reason) => _staffCall(
    StaffSession.admin,
    'POST',
    '/api/admin/stores/${Uri.encodeComponent(owner)}/reject',
    {'reason': reason},
  );

  Future<List<dynamic>> adminOrders({String stage = ''}) async {
    final body = await _staffCall(
      StaffSession.admin,
      'GET',
      '/api/admin/orders${stage.isEmpty ? '' : '?stage=$stage'}',
    );
    return body['items'] as List<dynamic>? ?? const [];
  }

  /// Puts a rider's name on an order, or clears it with an empty number.
  Future<void> assignOrder(String id, String phone) => _staffCall(
    StaffSession.admin,
    'POST',
    '/api/admin/orders/$id/assign',
    {'phone': phone},
  );

  Future<List<dynamic>> riders() async {
    final body = await _staffCall(
      StaffSession.admin,
      'GET',
      '/api/admin/riders',
    );
    return body['items'] as List<dynamic>? ?? const [];
  }

  /// Returns the PIN, which is shown once and never readable again.
  Future<String> addRider(String phone, String name) async {
    final body = await _staffCall(
      StaffSession.admin,
      'POST',
      '/api/admin/riders',
      {'phone': phone, 'name': name},
    );
    return body['pin'] as String? ?? '';
  }

  /// A fresh PIN for a rider who lost theirs. Returns the four digits, which
  /// are shown once and never readable again.
  Future<String> resetRiderPin(String phone) async {
    final body = await _staffCall(
      StaffSession.admin,
      'POST',
      '/api/admin/riders/$phone/pin',
    );
    return body['pin'] as String? ?? '';
  }

  /// Moves a rider to a new number, taking their run and their history with
  /// them. Returns the new PIN.
  Future<String> changeRiderNumber(String phone, String next) async {
    final body = await _staffCall(
      StaffSession.admin,
      'POST',
      '/api/admin/riders/$phone/number',
      {'phone': next},
    );
    return body['pin'] as String? ?? '';
  }

  /// Off, not gone: they stop being handed orders and are signed out, and
  /// their deliveries stay on their name.
  Future<void> removeRider(String phone) =>
      _staffCall(StaffSession.admin, 'DELETE', '/api/admin/riders/$phone');

  Future<void> restoreRider(String phone) =>
      _staffCall(StaffSession.admin, 'POST', '/api/admin/riders/$phone/on');

  /// Gone for good. Refused while they are carrying something.
  Future<void> deleteRider(String phone) => _staffCall(
    StaffSession.admin,
    'DELETE',
    '/api/admin/riders/$phone?forever=true',
  );

  Future<void> riderLogin(String phone, String pin) async {
    final res = await http
        .post(
          _url('/api/delivery/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'pin': pin}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException(_reason(res));
    final r = jsonDecode(res.body) as Map<String, dynamic>;
    await StaffSession.rider.signIn(
      r['token'] as String,
      r['phone'] as String,
      r['name'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> riderOrders() =>
      _staffCall(StaffSession.rider, 'GET', '/api/delivery/orders');

  Future<Map<String, dynamic>> riderHistory() =>
      _staffCall(StaffSession.rider, 'GET', '/api/delivery/history');

  Future<void> riderPick(String id) =>
      _staffCall(StaffSession.rider, 'POST', '/api/delivery/orders/$id/pick');

  Future<void> riderDeliver(String id, String code) => _staffCall(
    StaffSession.rider,
    'POST',
    '/api/delivery/orders/$id/deliver',
    {'code': code},
  );

  InventoryItem _inventoryItem(Map<String, dynamic> r) =>
      InventoryItem(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          description: r['description'] as String? ?? '',
          category: r['category'] as String? ?? '',
          price: (r['price'] as num?)?.toDouble() ?? 0,
          mrp: (r['mrp'] as num?)?.toDouble() ?? 0,
          stock: (r['stock'] as num?)?.toInt() ?? 0,
        )
        ..serverId = r['id'] as String
        ..imageUrls = (r['imageUrls'] as List<dynamic>? ?? const [])
            .cast<String>();

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
    double mrp = 0,
    List<Uint8List> photos = const [],
  }) async {
    final body = await _send('/api/seller/items', {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'mrp': mrp,
      'stock': stock,
    }, photos);
    return (
      id: body['id'] as String,
      imageUrls: (body['imageUrls'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  /// Extra photos for an item that already exists — the edit screen's path.
  Future<List<String>> addItemPhotos(
    String itemId,
    List<Uint8List> photos,
  ) async {
    final body = await _send(
      '/api/seller/items/$itemId/photos',
      const {},
      photos,
    );
    return (body['imageUrls'] as List<dynamic>).cast<String>();
  }

  /// One shape for every seller write: JSON when there is nothing to upload,
  /// multipart when there is. The backend accepts both, so the app never has
  /// to sequence two calls and reconcile a half-done result.
  Future<Map<String, dynamic>> _send(
    String path,
    Map<String, Object?> fields,
    List<Uint8List> photos,
  ) async {
    final auth = await _authHeader();
    final http.Response res;
    if (photos.isEmpty) {
      res = await http
          .post(
            _url(path),
            headers: {...auth, 'Content-Type': 'application/json'},
            body: jsonEncode(fields),
          )
          .timeout(_timeout);
    } else {
      final req = http.MultipartRequest('POST', _url(path))
        ..headers.addAll(auth);
      // MultipartRequest.fields is a Map, so a repeated key is impossible —
      // list values go as one comma-separated field and the backend splits it.
      fields.forEach((k, v) => req.fields[k] = v is List ? v.join(',') : '$v');
      for (var i = 0; i < photos.length; i++) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'file',
            photos[i],
            filename: 'photo_${i + 1}.jpg',
          ),
        );
      }
      res = await http.Response.fromStream(
        await req.send().timeout(_uploadTimeout),
      );
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
    mrp: (r['mrp'] as num?)?.toDouble() ?? 0,
    imageUrl: r['imageUrl'] as String? ?? '',
    store: r['store'] as String? ?? '',
    description: r['description'] as String? ?? '',
    // Photos past the cover. The gallery shows every one; before this they
    // were parsed away, so a two-photo listing looked like a one-photo one.
    extraImages:
        ((r['imageUrls'] as List<dynamic>? ?? const []).cast<String>().toList()
              ..remove(r['imageUrl'] as String? ?? ''))
            .where((u) => u.isNotEmpty)
            .toList(),
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

/// This account has no store yet — a normal state, not a failure.
class NoStoreYet implements Exception {
  const NoStoreYet();
  @override
  String toString() => 'no store yet';
}
