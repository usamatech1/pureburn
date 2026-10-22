// Cloud account, sync, challenges and AI coach calls. Uses Firebase over plain HTTPS (REST),
// so there are no native plugins. It switches on only when FB_API_KEY and FB_PROJECT are set at build time.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_stub.dart' if (dart.library.html) 'cloud_web.dart';

const fbApiKey = String.fromEnvironment('FB_API_KEY');
const fbProject = String.fromEnvironment('FB_PROJECT');
const _fbRegionRaw = String.fromEnvironment('FB_REGION');
String get fbRegion => _fbRegionRaw.isEmpty ? 'us-central1' : _fbRegionRaw;
// The Web client ID is a public identifier (it is visible in every Google sign-in page), so it is safe to keep here.
const _gEnv = String.fromEnvironment('GOOGLE_CLIENT_ID');
const googleClientId = _gEnv == '' ? '561795698433-up6bmkc03s6bbh4su8ph73rb1v7bnlnm.apps.googleusercontent.com' : _gEnv;
bool get googleReady => cloudConfigured && googleClientId.isNotEmpty;
bool get cloudConfigured => fbApiKey.isNotEmpty && fbProject.isNotEmpty;

class CloudError implements Exception {
  final String message;
  CloudError(this.message);
  @override
  String toString() => message;
}

String _friendly(String code) {
  final c = code.toUpperCase();
  if (c.contains('EMAIL_EXISTS')) return 'This email already has an account. Try signing in.';
  if (c.contains('INVALID_LOGIN') || c.contains('INVALID_PASSWORD') || c.contains('EMAIL_NOT_FOUND')) return 'Wrong email or password.';
  if (c.contains('WEAK_PASSWORD')) return 'Use a password with at least 6 characters.';
  if (c.contains('INVALID_EMAIL')) return 'That email does not look right.';
  if (c.contains('TOO_MANY')) return 'Too many tries. Please wait a few minutes.';
  if (c.contains('PERMISSION_DENIED')) return 'The server refused this. Check the Firestore rules in the setup guide.';
  return 'Something went wrong ($code).';
}

class ChallengeEntry {
  final String uid, name;
  final int score;
  ChallengeEntry(this.uid, this.name, this.score);
}

class CloudService extends ChangeNotifier {
  SharedPreferences? _sp;
  String uid = '', email = '', _idToken = '', _refresh = '';
  int _exp = 0;
  bool busy = false;
  String status = '';
  bool autoSync = true;
  int lastSync = 0; // ms of the last successful push or pull
  int localChange = 0; // ms of the last local edit
  bool applying = false;
  Timer? _debounce;
  Future<String?> Function(String json)? onRemote; // restores a remote backup into the app
  String Function()? exporter;

  bool get signedIn => uid.isNotEmpty;

  Future<void> load(SharedPreferences sp) async {
    _sp = sp;
    try {
      final raw = sp.getString('pureburn-cloud');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        uid = '${j['uid'] ?? ''}';
        email = '${j['email'] ?? ''}';
        _idToken = '${j['id'] ?? ''}';
        _refresh = '${j['rt'] ?? ''}';
        _exp = (j['exp'] ?? 0) as int;
        autoSync = j['auto'] != false;
        lastSync = (j['last'] ?? 0) as int;
        localChange = (j['lc'] ?? 0) as int;
      }
    } catch (_) {}
    await _finishWebGoogle();
    notifyListeners();
  }

  bool justSignedIn = false;

  /// After Google sends the browser back, the page address holds #id_token=...
  Future<void> _finishWebGoogle() async {
    if (!kIsWeb) return;
    final frag = Uri.base.fragment;
    if (!frag.contains('id_token=')) return;
    try {
      final q = Uri.splitQueryString(frag.startsWith('/') ? frag.substring(1) : frag);
      final idt = q['id_token'];
      webCleanUrl();
      if (idt == null || idt.isEmpty) return;
      final parts = idt.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
        final want = _sp?.getString('pureburn-gnonce');
        if (want == null || payload['nonce'] != want) {
          status = 'Google sign-in could not be verified. Please try again.';
          return;
        }
      }
      await _sp?.remove('pureburn-gnonce');
      await _auth('signInWithIdp', {'postBody': 'id_token=${Uri.encodeComponent(idt)}&providerId=google.com', 'requestUri': 'http://localhost', 'returnSecureToken': true, 'returnIdpCredential': true});
      justSignedIn = true;
      status = 'Signed in with Google. Tap Sync now to save or load your data.';
    } on CloudError catch (e) {
      status = e.message;
    } catch (_) {
      status = 'Google sign-in failed. Please try again.';
    }
  }

  void _save() {
    _sp?.setString('pureburn-cloud', jsonEncode({'uid': uid, 'email': email, 'id': _idToken, 'rt': _refresh, 'exp': _exp, 'auto': autoSync, 'last': lastSync, 'lc': localChange}));
  }

  void setAuto(bool v) {
    autoSync = v;
    _save();
    notifyListeners();
  }

  // ---- auth ----
  Future<void> _auth(String path, Map<String, dynamic> body) async {
    if (!cloudConfigured) throw CloudError('The cloud is not set up in this build yet.');
    final r = await http.post(Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:$path?key=$fbApiKey'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw CloudError(_friendly('${(j['error'] ?? {})['message'] ?? r.statusCode}'));
    uid = '${j['localId']}';
    email = '${j['email'] ?? ''}';
    _idToken = '${j['idToken']}';
    _refresh = '${j['refreshToken']}';
    _exp = DateTime.now().millisecondsSinceEpoch + (int.tryParse('${j['expiresIn']}') ?? 3600) * 1000 - 60000;
    _save();
    notifyListeners();
  }

  Future<void> signInGoogle() async {
    if (!googleReady) throw CloudError('Google sign-in is not set up in this build yet.');
    if (kIsWeb) {
      // The old popup flow no longer works on the web, so go to Google and come back with an ID token.
      final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36) + uid.hashCode.toRadixString(36);
      await _sp?.setString('pureburn-gnonce', nonce);
      final back = '${Uri.base.origin}${Uri.base.path.endsWith('/') ? Uri.base.path : '${Uri.base.path}/'}';
      webGo(Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': googleClientId,
        'redirect_uri': back,
        'response_type': 'id_token',
        'scope': 'openid email profile',
        'nonce': nonce,
        'prompt': 'select_account',
      }).toString());
      return;
    }
    try {
      final g = GoogleSignIn(scopes: const ['email'], clientId: kIsWeb ? googleClientId : null, serverClientId: kIsWeb ? null : googleClientId);
      final a = await g.signIn();
      if (a == null) throw CloudError('Google sign-in was cancelled.');
      final t = await a.authentication;
      final idt = t.idToken, act = t.accessToken;
      if ((idt == null || idt.isEmpty) && (act == null || act.isEmpty)) throw CloudError('Google did not return a sign-in token.');
      final tok = (idt != null && idt.isNotEmpty) ? 'id_token=${Uri.encodeComponent(idt)}' : 'access_token=${Uri.encodeComponent(act!)}';
      await _auth('signInWithIdp', {'postBody': '$tok&providerId=google.com', 'requestUri': 'http://localhost', 'returnSecureToken': true, 'returnIdpCredential': true});
    } on CloudError {
      rethrow;
    } catch (e) {
      throw CloudError('Google sign-in failed. Check the setup steps. ($e)');
    }
  }

  Future<void> signUp(String mail, String pass) => _auth('signUp', {'email': mail.trim(), 'password': pass, 'returnSecureToken': true});
  Future<void> signIn(String mail, String pass) => _auth('signInWithPassword', {'email': mail.trim(), 'password': pass, 'returnSecureToken': true});

  Future<void> resetPassword(String mail) async {
    if (!cloudConfigured) throw CloudError('The cloud is not set up in this build yet.');
    final r = await http.post(Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$fbApiKey'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': mail.trim()}));
    if (r.statusCode != 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      throw CloudError(_friendly('${(j['error'] ?? {})['message'] ?? r.statusCode}'));
    }
  }

  void signOut() {
    try {
      GoogleSignIn().signOut();
    } catch (_) {}
    uid = email = _idToken = _refresh = '';
    _exp = 0;
    lastSync = 0;
    _save();
    notifyListeners();
  }

  Future<String> token() async {
    if (!signedIn) throw CloudError('Please sign in first.');
    if (DateTime.now().millisecondsSinceEpoch < _exp) return _idToken;
    final r = await http.post(Uri.parse('https://securetoken.googleapis.com/v1/token?key=$fbApiKey'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'grant_type=refresh_token&refresh_token=$_refresh');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      signOut();
      throw CloudError('Your session ended. Please sign in again.');
    }
    _idToken = '${j['id_token']}';
    _refresh = '${j['refresh_token']}';
    _exp = DateTime.now().millisecondsSinceEpoch + (int.tryParse('${j['expires_in']}') ?? 3600) * 1000 - 60000;
    _save();
    return _idToken;
  }

  // ---- Firestore REST helpers ----
  String get _docs => 'https://firestore.googleapis.com/v1/projects/$fbProject/databases/(default)/documents';

  Future<Map<String, dynamic>> _call(String method, String url, [Object? body]) async {
    final t = await token();
    final h = {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'};
    final u = Uri.parse(url);
    final r = method == 'GET' ? await http.get(u, headers: h) : method == 'PATCH' ? await http.patch(u, headers: h, body: jsonEncode(body)) : await http.post(u, headers: h, body: jsonEncode(body));
    if (r.statusCode == 404) return {'_missing': true};
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) {
      final m = j is Map ? '${(j['error'] ?? {})['status'] ?? (j['error'] ?? {})['message'] ?? r.statusCode}' : '${r.statusCode}';
      throw CloudError(_friendly(m));
    }
    return j is Map<String, dynamic> ? j : {'list': j};
  }

  // ---- sync ----
  /// Called by AppState whenever local data is saved.
  void markDirty() {
    if (applying) return;
    localChange = DateTime.now().millisecondsSinceEpoch;
    _save();
    if (!signedIn || !autoSync || !cloudConfigured) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 25), () async {
      try {
        final r = await _remoteAt();
        if (r > lastSync) {
          status = 'Another phone changed your data. Open Account to choose which to keep.';
          notifyListeners();
          return;
        }
        await push();
      } catch (_) {}
    });
  }

  Future<int> _remoteAt() async {
    final j = await _call('GET', '$_docs/users/$uid/sync/state');
    if (j['_missing'] == true) return 0;
    return int.tryParse('${(j['fields']?['at'] ?? {})['integerValue'] ?? 0}') ?? 0;
  }

  Future<void> push() async {
    final data = exporter?.call() ?? '{}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _call('PATCH', '$_docs/users/$uid/sync/state?updateMask.fieldPaths=data&updateMask.fieldPaths=at', {
      'fields': {'data': {'stringValue': data}, 'at': {'integerValue': '$now'}},
    });
    lastSync = now;
    localChange = now;
    status = 'Saved to your account.';
    _save();
    notifyListeners();
  }

  /// Returns null when restored, 'none' when the cloud is empty, otherwise an error text.
  Future<String?> pull() async {
    final j = await _call('GET', '$_docs/users/$uid/sync/state');
    if (j['_missing'] == true) return 'none';
    final data = '${(j['fields']?['data'] ?? {})['stringValue'] ?? ''}';
    final at = int.tryParse('${(j['fields']?['at'] ?? {})['integerValue'] ?? 0}') ?? 0;
    if (data.isEmpty) return 'none';
    applying = true;
    final err = await onRemote?.call(data);
    applying = false;
    if (err != null) return err;
    lastSync = at;
    localChange = at;
    status = 'Loaded your data from the account.';
    _save();
    notifyListeners();
    return null;
  }

  /// True when both this phone and the account changed since the last sync.
  Future<bool> conflict() async {
    final r = await _remoteAt();
    return r > lastSync && localChange > lastSync;
  }

  /// Smart sync: pushes when only this phone changed, pulls when only the account changed.
  Future<String> syncNow() async {
    busy = true;
    notifyListeners();
    try {
      final r = await _remoteAt();
      if (r == 0) {
        await push();
        return 'Your data is now saved in your account.';
      }
      final localNew = localChange > lastSync;
      if (r > lastSync && localNew) return 'conflict';
      if (r > lastSync) {
        final e = await pull();
        return e ?? 'Loaded the newer data from your account.';
      }
      await push();
      return 'Synced.';
    } on CloudError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your internet.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ---- challenges ----
  Future<void> submitScore(String challengeId, String name, int score) async {
    await _call('PATCH', '$_docs/challenges/$challengeId/entries/$uid?updateMask.fieldPaths=name&updateMask.fieldPaths=score&updateMask.fieldPaths=at', {
      'fields': {'name': {'stringValue': name}, 'score': {'integerValue': '$score'}, 'at': {'integerValue': '${DateTime.now().millisecondsSinceEpoch}'}},
    });
  }

  Future<List<ChallengeEntry>> leaderboard(String challengeId) async {
    final j = await _call('POST', '$_docs/challenges/$challengeId:runQuery', {
      'structuredQuery': {
        'from': [{'collectionId': 'entries'}],
        'orderBy': [{'field': {'fieldPath': 'score'}, 'direction': 'DESCENDING'}],
        'limit': 20,
      }
    });
    final out = <ChallengeEntry>[];
    for (final e in (j['list'] ?? const []) as List) {
      final d = (e as Map)['document'];
      if (d == null) continue;
      final f = d['fields'] as Map<String, dynamic>;
      final id = '${d['name']}'.split('/').last;
      out.add(ChallengeEntry(id, '${(f['name'] ?? {})['stringValue'] ?? 'Player'}', int.tryParse('${(f['score'] ?? {})['integerValue'] ?? 0}') ?? 0));
    }
    return out;
  }

  Future<void> leave(String challengeId) async {
    final t = await token();
    await http.delete(Uri.parse('$_docs/challenges/$challengeId/entries/$uid'), headers: {'Authorization': 'Bearer $t'});
  }

  // ---- AI coach ----
  Future<String> coach(String message, Map<String, dynamic> context) async {
    final t = await token();
    final r = await http
        .post(Uri.parse('https://$fbRegion-$fbProject.cloudfunctions.net/coach'),
            headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'}, body: jsonEncode({'message': message, 'context': context}))
        .timeout(const Duration(seconds: 45));
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode == 429) throw CloudError('${j['error'] ?? 'You reached today\'s coach limit. Come back tomorrow.'}');
    if (r.statusCode != 200) throw CloudError('The coach is not available right now.');
    return '${j['reply'] ?? ''}';
  }
}

final cloud = CloudService();
