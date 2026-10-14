import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Outcome of a sign-in attempt. UI matches on these to render a
/// distinct message per failure mode rather than a generic "sign-in
/// failed" toast.
sealed class AuthResult {
  const AuthResult();
}

class AuthSigned extends AuthResult {
  const AuthSigned(this.account);
  final GoogleSignInAccount account;
}

class AuthCancelled extends AuthResult {
  const AuthCancelled();
}

class AuthNetworkError extends AuthResult {
  const AuthNetworkError([this.message]);
  final String? message;
}

class AuthDenied extends AuthResult {
  const AuthDenied();
}

class AuthFailed extends AuthResult {
  const AuthFailed(this.message);
  final String message;
}

/// Wraps `google_sign_in` for the Drive `appDataFolder` scope and
/// exposes a `googleapis` `DriveApi` once signed in. Token refresh is
/// handled by `google_sign_in` — we just re-read `authHeaders` each
/// time we build a client, so a stale token gets refreshed under us.
class DriveAuth {
  DriveAuth._();
  static final DriveAuth instance = DriveAuth._();

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  Stream<GoogleSignInAccount?> get onUserChanged => _signIn.onCurrentUserChanged;

  Future<AuthResult> signIn() => _attempt(() => _signIn.signIn());

  Future<AuthResult> signInSilently() =>
      _attempt(() => _signIn.signInSilently());

  Future<void> signOut() async {
    await _signIn.signOut();
  }

  /// Builds an authenticated `DriveApi` for the current account.
  /// Returns null when the user is signed out — callers should treat
  /// that as "show the sign-in CTA" rather than an error.
  Future<drive.DriveApi?> client() async {
    final account = currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    final headers = await account.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<AuthResult> _attempt(
    Future<GoogleSignInAccount?> Function() op,
  ) async {
    try {
      final account = await op();
      if (account == null) return const AuthCancelled();
      return AuthSigned(account);
    } on PlatformException catch (e) {
      return _classify(e);
    } catch (e) {
      return AuthFailed(e.toString());
    }
  }

  AuthResult _classify(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code.contains('cancel')) return const AuthCancelled();
    if (msg.contains('network') || code.contains('network')) {
      return AuthNetworkError(e.message);
    }
    if (msg.contains('denied') || code.contains('denied')) {
      return const AuthDenied();
    }
    return AuthFailed('${e.code}: ${e.message ?? ''}');
  }
}

/// `google_sign_in` only hands out a bearer-header map; `googleapis`
/// expects an `http.Client`. Wrap a vanilla client and inject the
/// headers on every send.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
