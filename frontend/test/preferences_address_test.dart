import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamazon/data/api.dart';
import 'package:lamazon/data/addresses.dart';
import 'package:lamazon/data/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'address selection and settings are server-backed; failures preserve state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final rows = <Map<String, dynamic>>[];
      final preferences = {
        'push': true,
        'emailOffers': false,
        'orderUpdates': true,
      };
      var refuse = false;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/me') return http.Response('{}', 200);
        if (refuse && request.method != 'GET') {
          return http.Response('{"error":"try again"}', 503);
        }
        if (path == '/api/addresses') {
          if (request.method == 'POST') {
            final row = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            )..['id'] = 'saved-1';
            rows.add(row);
            return http.Response(jsonEncode(row), 201);
          }
          return http.Response(jsonEncode(rows), 200);
        }
        if (path.endsWith('/default')) return http.Response('', 204);
        if (path.startsWith('/api/addresses/') && request.method == 'DELETE') {
          rows.clear();
          return http.Response('', 204);
        }
        if (path == '/api/preferences') {
          if (request.method == 'PATCH') {
            preferences.addAll(
              Map<String, bool>.from(jsonDecode(request.body) as Map),
            );
          }
          return http.Response(jsonEncode(preferences), 200);
        }
        return http.Response('[]', 200);
      });
      await http.runWithClient(() async {
        await Session.instance.signIn(
          const AuthTokens(
            email: 'test@example.com',
            token: 'test',
            refreshToken: 'refresh',
            expiresIn: 3600,
          ),
        );
        await AddressBook.instance.add(
          const Address(
            id: '',
            label: AddressLabel.home,
            line: 'Room',
            city: 'LPU',
            pincode: '',
          ),
        );
        expect(AddressBook.instance.selected?.id, 'saved-1');
        expect(rows.single['isDefault'], isTrue);
        await Api.instance.preferences({'push': false});
        expect((await Api.instance.preferences())['push'], isFalse);
        refuse = true;
        await expectLater(
          AddressBook.instance.remove('saved-1'),
          throwsException,
        );
        expect(AddressBook.instance.selected?.id, 'saved-1');
        await expectLater(
          Api.instance.preferences({'push': true}),
          throwsException,
        );
        expect((await Api.instance.preferences())['push'], isFalse);
        refuse = false;
        await AddressBook.instance.remove('saved-1');
        expect(AddressBook.instance.addresses, isEmpty);
        await Session.instance.signOut();
      }, () => client);
    },
  );
}
