// Exercise guide: how to do each exercise from the plan, with easier and harder versions.

class ExInfo {
  final String title, muscles, tip, easier, harder;
  final List<String> steps;
  const ExInfo(this.title, this.muscles, this.steps, this.tip, this.easier, this.harder);
}

const _lib = <String, ExInfo>{
  'goblet': ExInfo('Goblet squat', 'Thighs, glutes, core', [
    'Hold one dumbbell upright against your chest with both hands.',
    'Stand with feet a little wider than your shoulders, toes slightly out.',
    'Sit down and back between your knees, keeping your chest tall.',
    'Push through your heels to stand up.',
  ], 'Keep your elbows inside your knees at the bottom and your heels flat.', 'Squat to a chair and stand up, with a lighter weight.', 'Pause for 2 seconds at the bottom, or lower for 3 seconds.'),
  'squat': ExInfo('Squat', 'Thighs, glutes, core', [
    'Stand with feet shoulder-width apart and toes slightly out.',
    'Push your hips back and bend your knees as if sitting on a chair.',
    'Go down until your thighs are about level with the floor, chest up and heels down.',
    'Push through your heels to stand.',
  ], 'Your knees should follow the line of your toes. Do not let them fall inward.', 'Sit down to a chair and stand up again, or do a shallower squat.', 'Hold a backpack of books at your chest and take 3 seconds to lower.'),
  'glute': ExInfo('Glute bridge', 'Glutes, back of thighs', [
    'Lie on your back with knees bent and feet flat, hip-width apart.',
    'Press through your heels and lift your hips until your body is a straight line from knees to shoulders.',
    'Squeeze your glutes at the top for 1 second.',
    'Lower slowly.',
  ], 'Do not arch your lower back. Tuck your ribs down and squeeze your glutes.', 'Lift your hips only halfway.', 'Lift one foot off the floor and do the set on one leg.'),
  'push-up': ExInfo('Push-up', 'Chest, shoulders, triceps, core', [
    'Put your hands a little wider than your shoulders, on the floor, a table or a wall.',
    'Keep your body in one straight line from head to knees (or heels).',
    'Bend your elbows and lower your chest toward your hands.',
    'Push the floor away until your arms are straight.',
  ], 'Keep your elbows at about 45 degrees from your body, not flared out.', 'Use a wall or a table instead of the floor.', 'Move to the floor on your toes, or put your feet on a chair.'),
  'plank': ExInfo('Plank', 'Core, shoulders', [
    'Rest on your forearms and toes with elbows under your shoulders.',
    'Keep your body in one straight line, glutes tight and tummy pulled in.',
    'Breathe slowly and hold.',
  ], 'Do not let your hips sag or rise. Stop when your form breaks.', 'Do the plank on your knees.', 'Lift one foot for a few seconds, or hold for 10 seconds longer.'),
  'leg press': ExInfo('Leg press', 'Thighs, glutes', [
    'Sit with your back flat on the pad and feet shoulder-width on the plate.',
    'Release the safety and lower the plate until your knees are at about 90 degrees.',
    'Press through your whole foot without locking your knees.',
  ], 'Do not let your lower back lift off the pad.', 'Use a lighter weight and a shorter range.', 'Add weight and lower for 3 seconds.'),
  'chest press': ExInfo('Chest press', 'Chest, shoulders, triceps', [
    'Sit or lie with your back flat and the handles at chest height.',
    'Press forward until your arms are almost straight.',
    'Return slowly until you feel a stretch across your chest.',
  ], 'Keep your shoulders back and down. Do not shrug.', 'Use a lighter weight, or do wall push-ups.', 'Add weight and take 3 seconds to return.'),
  'shoulder press': ExInfo('Shoulder press', 'Shoulders, triceps', [
    'Sit with your back supported, dumbbells at shoulder height.',
    'Press the dumbbells up until your arms are almost straight.',
    'Lower slowly to shoulder height.',
  ], 'Do not arch your back. Keep your ribs down.', 'Use lighter weights or press one arm at a time.', 'Use heavier weights, or press from standing.'),
  'step-up': ExInfo('Step-up', 'Thighs, glutes, balance', [
    'Stand in front of a sturdy stair or step.',
    'Place one whole foot on the step and push through that heel to stand up.',
    'Lower back down slowly, then repeat on the same leg before switching.',
  ], 'Drive with the leg on the step. Do not push off the floor leg.', 'Use a lower step and hold a wall.', 'Use a higher step or hold books.'),
  'split squat': ExInfo('Split squat or lunge', 'Thighs, glutes, balance', [
    'Take a big step forward, back heel lifted.',
    'Lower your back knee toward the floor, front knee over your ankle.',
    'Push through the front heel to rise.',
  ], 'Keep your chest tall. Your front heel stays on the floor.', 'Hold a wall or chair for balance, and go less deep.', 'Hold books or dumbbells, or pause for 2 seconds at the bottom.'),
  'row': ExInfo('Backpack row', 'Back, back of shoulders, biceps', [
    'Hold a backpack of books with both hands. Bend forward at the hips with a flat back.',
    'Pull the bag to your lower ribs, squeezing your shoulder blades together.',
    'Lower slowly until your arms are straight.',
  ], 'Do not round your back. Look at the floor a little in front of you.', 'Row with one hand resting on a table.', 'Add more books, or row for 3 seconds on the way down.'),
  'superman': ExInfo('Superman hold', 'Lower back, glutes', [
    'Lie face down with your arms stretched in front.',
    'Lift your arms, chest and legs a little off the floor.',
    'Hold for 2 seconds, then lower.',
  ], 'Look at the floor. Lift only as high as feels comfortable.', 'Lift only your arms or only your legs.', 'Hold for 5 seconds each rep.'),
  'dead bug': ExInfo('Dead bug', 'Deep core', [
    'Lie on your back with arms up and knees bent over your hips.',
    'Slowly lower your right arm and left leg toward the floor, keeping your lower back pressed down.',
    'Return and switch sides.',
  ], 'If your lower back lifts off the floor, move less.', 'Move only your legs.', 'Hold a light weight, and move slower.'),
  'lat pulldown': ExInfo('Lat pulldown', 'Back, biceps', [
    'Sit with thighs under the pad and hold the bar a little wider than your shoulders.',
    'Pull the bar to your upper chest, leading with your elbows.',
    'Let it rise slowly until your arms are straight.',
  ], 'Do not lean far back or swing. Keep your chest tall.', 'Use less weight and a shorter range.', 'Add weight and pause for 1 second at the chest.'),
  'cable row': ExInfo('Seated cable row', 'Back, back of shoulders', [
    'Sit tall with feet on the plate and knees slightly bent.',
    'Pull the handle to your belly, squeezing your shoulder blades.',
    'Return slowly without rounding forward.',
  ], 'Keep your torso still. Your back does the work, not your swing.', 'Use less weight.', 'Add weight and hold the squeeze for 2 seconds.'),
  'deadlift': ExInfo('Romanian deadlift', 'Back of thighs, glutes, lower back', [
    'Stand holding dumbbells in front of your thighs, knees slightly bent.',
    'Push your hips back and slide the weights down your legs with a flat back.',
    'Go down until you feel a stretch in the back of your thighs, then drive your hips forward to stand.',
  ], 'Keep the weights close to your legs and your back flat the whole time.', 'Use very light weights or no weight at all.', 'Use heavier weights and lower for 3 seconds.'),
  'jog': ExInfo('Walk with jog intervals', 'Heart, legs', [
    'Walk briskly for 3 minutes.',
    'Jog gently for 1 minute.',
    'Repeat until the time is up.',
  ], 'You should be able to talk in short sentences. Slow down if you cannot.', 'Walk only, a little faster than usual.', 'Jog for 90 seconds in each round.'),
  'brisk': ExInfo('Brisk walk', 'Heart, legs', [
    'Walk fast enough that you can talk but not sing.',
    'Swing your arms and keep your head up.',
    'Keep a steady pace for the whole time.',
  ], 'Wear comfortable shoes and drink water before you start.', 'Walk at a comfortable pace and add 5 minutes each week.', 'Add a gentle hill or walk 5 minutes longer.'),
};

const _order = [
  'goblet', 'split squat', 'step-up', 'squat', 'glute', 'push-up', 'plank', 'leg press', 'chest press', 'shoulder press', 'backpack rows',
  'superman', 'dead bug', 'lat pulldown', 'cable row', 'deadlift', 'jog', 'brisk',
];

ExInfo? exInfoFor(String name) {
  final n = name.toLowerCase();
  for (final k in _order) {
    if (n.contains(k)) return _lib[k == 'backpack rows' ? 'row' : k];
  }
  return null;
}

// Plan lines such as "Squats: 3 sets of 10 to 12 (hold a backpack ...)".
class ExItem {
  final String id, name, raw, per;
  final int sMin, sMax, rMin, rMax;
  final bool hold;
  final String? note;
  ExItem(this.id, this.name, this.raw, this.sMin, this.sMax, this.rMin, this.rMax, this.hold, this.per, this.note);
}

final _re = RegExp(r'^(.+?): (\d+)(?: to (\d+))? (sets|holds) of (\d+)(?: to (\d+))?(?: seconds)?( per leg| per side)?(?: \((.*)\))?$');

ExItem? parseEx(String id, String raw) {
  final m = _re.firstMatch(raw);
  if (m == null) return null;
  final s1 = int.parse(m[2]!), s2 = m[3] == null ? s1 : int.parse(m[3]!);
  final r1 = int.parse(m[5]!), r2 = m[6] == null ? r1 : int.parse(m[6]!);
  return ExItem(id, m[1]!, raw, s1, s2, r1, r2, m[4] == 'holds' || raw.contains('seconds'), (m[7] ?? '').trim(), m[8]);
}

int setsFor(ExItem e, String level) => level == 'beg' ? (e.sMin - 1).clamp(2, 9) : level == 'adv' ? e.sMax + 1 : e.sMin;

int repsFor(ExItem e, String level) => level == 'beg' ? e.rMin : level == 'adv' ? e.rMax + (e.hold ? 10 : 0) : e.rMax;

String targetText(ExItem e, String level) {
  final s = setsFor(e, level);
  final unit = e.hold ? 'seconds' : 'reps';
  final per = e.per.isEmpty ? '' : ' ${e.per}';
  if (level == 'beg') return '$s sets of ${e.rMin} $unit$per. Go slowly and focus on form.';
  if (level == 'adv') return '$s sets of ${e.rMax}${e.hold ? '+' : ''} $unit$per. Add weight or slow the lowering.';
  return '$s sets of ${e.rMin == e.rMax ? '${e.rMin}' : '${e.rMin} to ${e.rMax}'} $unit$per.';
}
