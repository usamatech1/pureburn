// Account and sync, weekly challenges with a leaderboard, and the AI coach chat.
import 'package:flutter/material.dart' hide Text;
import 'cloud.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'ui.dart';

void _msg(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget _gap([double h = 16]) => SizedBox(height: h);

// ---------------------------------------------------------------- account
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final mail = TextEditingController(), pass = TextEditingController();
  bool busy = false, showPass = false;

  @override
  void initState() {
    super.initState();
    cloud.addListener(_r);
  }

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    cloud.removeListener(_r);
    mail.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go(bool up) async {
    setState(() => busy = true);
    try {
      if (up) {
        await cloud.signUp(mail.text, pass.text);
      } else {
        await cloud.signIn(mail.text, pass.text);
      }
      pass.clear();
      if (mounted) _after();
    } on CloudError catch (e) {
      if (mounted) _msg(context, e.message);
    } catch (_) {
      if (mounted) _msg(context, 'Could not reach the server. Check your internet.');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _google() async {
    setState(() => busy = true);
    try {
      await cloud.signInGoogle();
      if (mounted) _after();
    } on CloudError catch (e) {
      if (mounted) _msg(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  // After signing in: if the account already holds data, ask which to keep.
  Future<void> _after() async {
    try {
      final r = await cloud.syncNow();
      if (!mounted) return;
      if (r == 'conflict') return _conflict();
      _msg(context, r);
    } catch (_) {}
  }

  Future<void> _conflict() async {
    final keep = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Which data do you want to keep?'),
        content: const Text('This phone and your account both have changes. Keeping one replaces the other.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'cloud'), child: const Text('Use account data')),
          TextButton(onPressed: () => Navigator.pop(c, 'phone'), child: const Text('Use this phone')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ],
      ),
    );
    if (keep == null) return;
    try {
      if (keep == 'phone') {
        await cloud.push();
        if (mounted) _msg(context, 'Your phone data was saved to the account.');
      } else {
        final e = await cloud.pull();
        if (mounted) _msg(context, e ?? 'Loaded your data from the account.');
      }
    } on CloudError catch (e) {
      if (mounted) _msg(context, e.message);
    }
  }

  Future<void> _sync() async {
    final r = await cloud.syncNow();
    if (!mounted) return;
    if (r == 'conflict') return _conflict();
    _msg(context, r);
  }

  String _ago(int ms) {
    if (ms == 0) return 'never';
    final s = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    if (s < 60) return 'just now';
    if (s < 3600) return '${s ~/ 60} min ago';
    if (s < 86400) return '${s ~/ 3600} h ago';
    return '${s ~/ 86400} days ago';
  }

  @override
  Widget build(BuildContext context) {
    if (!cloudConfigured) {
      return Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          H2('Cloud is not switched on'),
          Muted('Accounts, sync, challenges and the AI coach need a free Firebase project. Add its details to the build (see SETUP_PHASE3.md in the project) and these features switch on. Everything else keeps working without it.'),
        ]),
      );
    }
    if (!cloud.signedIn) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Sign in'),
            const Muted('Use one account on all your phones. Your data stays on your phone unless you sign in and sync.'),
            _gap(14),
            TextField(controller: mail, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email')),
            _gap(10),
            TextField(
              controller: pass,
              obscureText: !showPass,
              decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showPass = !showPass))),
            ),
            _gap(14),
            if (googleReady) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _google,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                ),
              ),
              _gap(10),
              const Center(child: Muted('or use your email', size: 12)),
              _gap(10),
            ],
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(onPressed: busy ? null : () => _go(false), child: Text(busy ? 'Please wait' : 'Sign in')),
              OutlinedButton(onPressed: busy ? null : () => _go(true), child: const Text('Create account')),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          await cloud.resetPassword(mail.text);
                          if (mounted) _msg(context, 'If this email has an account, a reset link was sent.');
                        } on CloudError catch (e) {
                          if (mounted) _msg(context, e.message);
                        }
                      },
                child: const Text('Forgot password'),
              ),
            ]),
          ]),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Signed in'),
          const SizedBox(height: 4),
          Text(cloud.email, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          _gap(8),
          Muted('Last synced: ${_ago(cloud.lastSync)}'),
          if (cloud.status.isNotEmpty) Muted(cloud.status, size: 12),
          _gap(14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(onPressed: cloud.busy ? null : _sync, icon: const Icon(Icons.sync), label: Text(cloud.busy ? 'Syncing' : 'Sync now')),
            OutlinedButton(
              onPressed: () {
                cloud.signOut();
              },
              child: const Text('Sign out'),
            ),
          ]),
        ]),
      ),
      _gap(12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Sync automatically', style: TextStyle(fontWeight: FontWeight.w600))),
            Switch(value: cloud.autoSync, onChanged: cloud.setAuto),
          ]),
          const Muted('Saves your data to your account a few seconds after you make a change. If two phones changed at the same time, you are asked which to keep.', size: 12),
        ]),
      ),
      _gap(12),
      const Muted('Your plan, logs, food diary, weights and settings are stored in your private account space. Only you can read them.', size: 12),
    ]);
  }
}

// ---------------------------------------------------------------- challenges
class _Ch {
  final String key, title, unit, blurb;
  const _Ch(this.key, this.title, this.unit, this.blurb);
}

const _chs = <_Ch>[
  _Ch('steps', 'Most steps this week', 'steps', 'Walk more than everyone else from Monday to Sunday.'),
  _Ch('workouts', 'Workout streak', 'workouts', 'Finish every task of your planned workouts.'),
  _Ch('water', 'Hydration hero', 'days', 'Reach your water goal on as many days as you can.'),
  _Ch('sleep', 'Sleep champion', 'nights', 'Sleep close to your goal on as many nights as you can.'),
];

int challengeScore(String key) {
  final wk = app.weekDates();
  final today = isoDate(DateTime.now());
  var n = 0;
  for (final dt in wk) {
    if (dt.compareTo(today) > 0) continue;
    final i = app.dayInfo(dt);
    switch (key) {
      case 'steps':
        n += i.steps;
        break;
      case 'workouts':
        if (i.exT > 0 && i.exD >= i.exT) n++;
        break;
      case 'water':
        if (i.wg > 0 && i.water >= i.wg) n++;
        break;
      case 'sleep':
        final g = ((app.set['sleepGoal'] ?? 8) as num).toDouble();
        if ((app.logs[dt]?.sleep ?? 0) >= g - 0.5) n++;
        break;
    }
  }
  return n;
}

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final nick = TextEditingController();
  final boards = <String, List<ChallengeEntry>>{};
  final loading = <String>{};

  String get _week => app.weekDates().first;
  String _id(_Ch c) => '${_week}_${c.key}';
  List<String> get _joined => [for (final e in (app.set['joined'] ?? const []) as List) '$e'];
  String get _name {
    final n = '${app.set['nick'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final e = cloud.email;
    return e.contains('@') ? e.split('@').first : 'Player';
  }

  @override
  void initState() {
    super.initState();
    nick.text = '${app.set['nick'] ?? ''}';
    if (cloud.signedIn) _refreshJoined();
  }

  @override
  void dispose() {
    nick.dispose();
    super.dispose();
  }

  Future<void> _refreshJoined() async {
    for (final c in _chs) {
      if (_joined.contains(_id(c))) {
        try {
          await cloud.submitScore(_id(c), _name, challengeScore(c.key));
        } catch (_) {}
        await _load(c);
      }
    }
  }

  Future<void> _load(_Ch c) async {
    setState(() => loading.add(_id(c)));
    try {
      boards[_id(c)] = await cloud.leaderboard(_id(c));
    } on CloudError catch (e) {
      if (mounted) _msg(context, e.message);
    } catch (_) {
      if (mounted) _msg(context, 'Could not reach the server.');
    }
    if (mounted) setState(() => loading.remove(_id(c)));
  }

  Future<void> _join(_Ch c) async {
    try {
      app.set['nick'] = nick.text.trim();
      app.saveSettings();
      await cloud.submitScore(_id(c), _name, challengeScore(c.key));
      final j = _joined..add(_id(c));
      app.set['joined'] = j.toSet().toList();
      app.saveSettings();
      await _load(c);
    } on CloudError catch (e) {
      if (mounted) _msg(context, e.message);
    } catch (_) {
      if (mounted) _msg(context, 'Could not reach the server.');
    }
  }

  Future<void> _leave(_Ch c) async {
    try {
      await cloud.leave(_id(c));
    } catch (_) {}
    app.set['joined'] = _joined..remove(_id(c));
    app.saveSettings();
    boards.remove(_id(c));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!cloudConfigured || !cloud.signedIn) {
      return Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Weekly challenges'),
          Muted(cloudConfigured ? 'Sign in to join challenges and see the leaderboard.' : 'Challenges need the cloud to be switched on. See the Account page.'),
          _gap(12),
          FilledButton(onPressed: () => app.go('account'), child: const Text('Go to Account')),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Your name on the leaderboard'),
          TextField(controller: nick, maxLength: 20, decoration: const InputDecoration(labelText: 'Nickname', hintText: 'A nickname, not your real name')),
          const Muted('Other players only see this nickname and your score. Never your email, weight or food.', size: 12),
        ]),
      ),
      _gap(12),
      for (final c in _chs) ...[
        _card(c),
        _gap(12),
      ],
      const Muted('Challenges restart every Monday. Scores come from what you log in the app.', size: 12),
    ]);
  }

  Widget _card(_Ch c) {
    final id = _id(c);
    final joined = _joined.contains(id);
    final score = challengeScore(c.key);
    final board = boards[id] ?? const <ChallengeEntry>[];
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          Pill('$score ${c.unit}'),
        ]),
        const SizedBox(height: 4),
        Muted(c.blurb, size: 12.5),
        _gap(10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          if (!joined) FilledButton(onPressed: () => _join(c), child: const Text('Join')),
          if (joined) FilledButton(onPressed: () => _join(c), child: const Text('Update my score')),
          if (joined) OutlinedButton(onPressed: () => _leave(c), child: const Text('Leave')),
          if (joined) TextButton(onPressed: loading.contains(id) ? null : () => _load(c), child: Text(loading.contains(id) ? 'Loading' : 'Refresh')),
        ]),
        if (joined && board.isNotEmpty) ...[
          _gap(10),
          for (var i = 0; i < board.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600))),
                Expanded(child: Text(board[i].name, style: TextStyle(fontWeight: board[i].uid == cloud.uid ? FontWeight.w700 : FontWeight.w400))),
                Text('${board[i].score}'),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- coach
class _Msg {
  final bool me;
  final String text;
  final bool offline;
  _Msg(this.me, this.text, {this.offline = false});
}

final List<_Msg> _chat = [];

Map<String, dynamic> coachContext() {
  final d = app.d;
  final i = app.dayInfo(app.selDate);
  final c = <String, dynamic>{};
  if (d.ok) {
    c['goal'] = d.goal;
    c['sex'] = d.sex;
    c['age'] = d.age;
    c['heightCm'] = d.h.round();
    c['weightKg'] = d.w;
    c['targetKg'] = d.tKg;
    c['bmi'] = double.parse(d.bmi.toStringAsFixed(1));
    if (d.plan != null) {
      c['kcalTarget'] = d.plan!.kcal;
      c['proteinG'] = d.plan!.pG;
    }
    if (d.diet != null) {
      c['todayPlan'] = [for (final m in d.diet!.meals) '${m.name} (${m.kcal} kcal): ${m.items.join(', ')}'];
    }
  }
  c['eatenKcalToday'] = i.kcal;
  c['proteinToday'] = i.p.round();
  c['waterGlasses'] = i.water;
  c['steps'] = i.steps;
  c['streakDays'] = app.streak();
  c['dietType'] = '${app.set['dietType'] ?? 'any'}';
  c['allergies'] = app.set['allergies'] ?? [];
  c['ramadan'] = app.set['ramadan'] == true;
  c['level'] = '${app.set['level'] ?? 'inter'}';
  return c;
}

/// A simple answer from the plan when the AI coach cannot be reached.
String offlineCoach(String q) {
  final t = q.toLowerCase();
  final d = app.d;
  if (!d.ok || d.diet == null) return 'Fill in your profile and plan first, then I can answer from your plan.';
  String meal(List<String> ids) {
    for (final m in d.diet!.meals) {
      if (ids.contains(m.id)) return '${m.name} (about ${m.kcal} kcal): ${m.items.join(', ')}.';
    }
    return '';
  }

  if (RegExp(r'raat|dinner|night|ratt').hasMatch(t)) {
    final m = meal(['dn', 'rdn']);
    if (m.isNotEmpty) return 'For dinner your plan says $m Keep it light and eat 2 to 3 hours before sleeping.';
  }
  if (RegExp(r'lunch|dopahar|dopehar').hasMatch(t)) {
    final m = meal(['ln']);
    if (m.isNotEmpty) return 'For lunch your plan says $m';
  }
  if (RegExp(r'breakfast|nashta|nasta|sehri|sehr').hasMatch(t)) {
    final m = meal(['bf', 'seh']);
    if (m.isNotEmpty) return 'Your plan says $m';
  }
  if (RegExp(r'iftar').hasMatch(t)) {
    final m = meal(['ifr']);
    if (m.isNotEmpty) return 'For iftar your plan says $m';
  }
  if (t.contains('protein')) {
    return 'Aim for about ${d.plan?.pG ?? 80} g of protein a day. Eggs, daal, chana, dahi and chicken are the cheapest sources. Add one of them to every meal.';
  }
  if (RegExp(r'weight|wazan|motap|fat|kam').hasMatch(t)) {
    return 'Stay near ${d.plan?.kcal ?? 1800} kcal a day, walk daily and keep your workouts. Weigh yourself once a week at the same time. Slow and steady works best.';
  }
  return 'I can answer from your plan when offline. Try asking about dinner, lunch, breakfast, protein or weight. Sign in to chat with the full AI coach.';
}

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});
  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || sending) return;
    input.clear();
    setState(() {
      _chat.add(_Msg(true, q));
      sending = true;
    });
    _down();
    String reply;
    var off = false;
    try {
      if (cloudConfigured && cloud.signedIn) {
        reply = await cloud.coach(q, coachContext());
        if (reply.trim().isEmpty) throw CloudError('empty');
      } else {
        off = true;
        reply = offlineCoach(q);
      }
    } on CloudError catch (e) {
      if (e.message.contains('limit')) {
        reply = e.message;
      } else {
        off = true;
        reply = offlineCoach(q);
      }
    } catch (_) {
      off = true;
      reply = offlineCoach(q);
    }
    if (!mounted) return;
    setState(() {
      _chat.add(_Msg(false, reply, offline: off));
      sending = false;
    });
    _down();
  }

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final on = cloudConfigured && cloud.signedIn;
    final chips = const ['Aaj raat kya khaun?', 'Review my week and suggest changes', 'How can I get more protein cheaply?', 'I missed my workout. What now?'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        dark: true,
        child: Row(children: [
          const Icon(Icons.psychology_alt_outlined, size: 34, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PureBurn coach', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 3),
              Text(on ? 'Ask in English or Roman Urdu. The coach knows your plan and today\'s log.' : 'Offline mode: answers come from your plan. Sign in for the full AI coach.', style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6), height: 1.4)),
            ]),
          ),
        ]),
      ),
      _gap(12),
      if (_chat.isEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: [for (final c in chips) ActionChip(label: Text(c), onPressed: () => _send(c))])
      else
        for (final m in _chat)
          Align(
            alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: m.me ? Theme.of(context).colorScheme.primary : card(context),
                borderRadius: BorderRadius.circular(18),
                border: m.me ? null : Border.all(color: line(context)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(m.text, style: TextStyle(height: 1.45, color: m.me ? Theme.of(context).colorScheme.onPrimary : fg(context))),
                if (m.offline) Padding(padding: const EdgeInsets.only(top: 6), child: Muted('From your plan (offline)', size: 11)),
              ]),
            ),
          ),
      if (sending) Padding(padding: const EdgeInsets.only(bottom: 10), child: Muted('Thinking...')),
      _gap(4),
      Row(children: [
        Expanded(
          child: TextField(
            controller: input,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ask your coach'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: sending ? null : () => _send(input.text), icon: const Icon(Icons.send)),
      ]),
      _gap(10),
      if (_chat.isNotEmpty) TextButton(onPressed: () => setState(_chat.clear), child: const Text('Clear chat')),
      const Muted('General wellness guidance only, not medical advice. If you have a health condition, ask your doctor.', size: 12),
    ]);
  }
}
