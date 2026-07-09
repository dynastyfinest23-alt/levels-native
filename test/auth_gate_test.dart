import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/router.dart';

void main() {
  group('authRedirect without a session', () {
    test('home redirects to /login', () {
      expect(authRedirect(signedIn: false, location: '/'), '/login');
    });

    test('unknown and future routes redirect to /login (default-deny)', () {
      expect(
        authRedirect(signedIn: false, location: '/assessment'),
        '/login',
      );
      expect(authRedirect(signedIn: false, location: '/dashboard'), '/login');
      expect(authRedirect(signedIn: false, location: '/nonsense'), '/login');
    });

    test('the PRD M1.4 placeholder routes redirect to /login', () {
      expect(authRedirect(signedIn: false, location: '/drill'), '/login');
      expect(authRedirect(signedIn: false, location: '/track'), '/login');
      expect(authRedirect(signedIn: false, location: '/reassessment'), '/login');
    });

    test('login and signup are reachable', () {
      expect(authRedirect(signedIn: false, location: '/login'), isNull);
      expect(authRedirect(signedIn: false, location: '/signup'), isNull);
    });
  });

  group('authRedirect with a session', () {
    test('auth screens bounce to home', () {
      expect(authRedirect(signedIn: true, location: '/login'), '/');
      expect(authRedirect(signedIn: true, location: '/signup'), '/');
    });

    test('home is allowed', () {
      expect(authRedirect(signedIn: true, location: '/'), isNull);
    });
  });
}
