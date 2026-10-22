// Desi food database, meal templates for swaps, Ramadan and diet filters, and shopping rates.
// Values are typical home-cooked amounts and are estimates. Prices are rough Pakistan averages.

class Food {
  final String id, name, serving;
  final int kcal;
  final double p, c, f, price;
  final List<String> tags; // meat, fish, egg, dairy, nuts
  final String? ing; // shopping ingredient key
  final double ingQty; // amount of that ingredient in one serving
  final double step; // smallest portion change
  final bool mine;
  const Food(this.id, this.name, this.serving, this.kcal, this.p, this.c, this.f, this.price,
      {this.tags = const [], this.ing, this.ingQty = 0, this.step = 0.5, this.mine = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'serving': serving, 'kcal': kcal, 'p': p, 'c': c, 'f': f};
  static Food fromJson(Map<String, dynamic> j) => Food(j['id'] as String, j['name'] as String, (j['serving'] ?? '1 serving') as String, (j['kcal'] as num).round(),
      ((j['p'] ?? 0) as num).toDouble(), ((j['c'] ?? 0) as num).toDouble(), ((j['f'] ?? 0) as num).toDouble(), 0, mine: true);
}

const foodDb = <Food>[
  // breads and rice
  Food('roti', 'Roti', '1 medium, 40 g', 105, 3.5, 21, 0.8, 8, ing: 'atta', ingQty: 40, step: 1),
  Food('paratha', 'Paratha', '1 plain', 260, 5, 32, 12, 35, ing: 'atta', ingQty: 60, step: 1),
  Food('naan', 'Naan', '1 piece', 260, 8, 48, 4, 40, ing: 'atta', ingQty: 80, step: 1),
  Food('rice', 'Boiled rice', '1 cup', 205, 4, 45, 0.4, 35, ing: 'rice', ingQty: 70),
  Food('khichdi', 'Khichdi (daal chawal)', '1 plate', 330, 12, 58, 5, 70, ing: 'rice', ingQty: 60),
  Food('pulao', 'Chicken pulao', '1 plate', 450, 20, 55, 16, 250, tags: ['meat'], ing: 'rice', ingQty: 90),
  Food('biryani', 'Chicken biryani', '1 plate', 550, 24, 65, 20, 350, tags: ['meat'], ing: 'rice', ingQty: 100),
  Food('oats', 'Oats porridge with milk', '1 bowl', 220, 9, 34, 5, 70, tags: ['dairy'], ing: 'oats', ingQty: 40),
  Food('oats_w', 'Oats porridge with water', '1 bowl', 150, 5, 27, 3, 45, ing: 'oats', ingQty: 40),
  // daal, pulses and sabzi
  Food('masoor', 'Masoor daal', '1 cup', 200, 12, 28, 4, 30, ing: 'daal', ingQty: 65),
  Food('moong', 'Moong daal', '1 cup', 180, 12, 28, 3, 40, ing: 'daal', ingQty: 65),
  Food('mash', 'Mash daal', '1 cup', 200, 13, 28, 4, 50, ing: 'daal', ingQty: 65),
  Food('chana_daal', 'Chana daal', '1 cup', 220, 12, 34, 4, 40, ing: 'daal', ingQty: 65),
  Food('chana_curry', 'Chana salan (cholay)', '1 cup', 270, 12, 38, 8, 45, ing: 'chana', ingQty: 70),
  Food('lobia', 'Lobia curry', '1 cup', 190, 11, 30, 3, 40, ing: 'daal', ingQty: 65),
  Food('rajma', 'Rajma', '1 cup', 225, 13, 38, 3, 60, ing: 'daal', ingQty: 65),
  Food('bhindi', 'Bhindi sabzi', '1 cup', 120, 3, 12, 7, 30, ing: 'veg', ingQty: 150),
  Food('aloo', 'Aloo curry', '1 cup', 180, 3, 26, 7, 25, ing: 'veg', ingQty: 150),
  Food('palak', 'Palak sabzi', '1 cup', 90, 4, 8, 5, 30, ing: 'veg', ingQty: 150),
  Food('lauki', 'Lauki or tori sabzi', '1 cup', 80, 2, 10, 4, 20, ing: 'veg', ingQty: 150),
  Food('gobi', 'Gobi sabzi', '1 cup', 110, 4, 12, 5, 30, ing: 'veg', ingQty: 150),
  Food('salad', 'Kheera, tamatar and pyaz salad', '1 bowl', 40, 2, 8, 0.3, 20, ing: 'veg', ingQty: 200, step: 1),
  Food('raita', 'Raita', '1/2 cup', 70, 3, 6, 3.5, 30, tags: ['dairy'], ing: 'dahi', ingQty: 100, step: 1),
  // protein
  Food('egg_boiled', 'Boiled egg', '1 egg', 75, 6.3, 0.6, 5, 44, tags: ['egg'], ing: 'eggs', ingQty: 1, step: 1),
  Food('omelette', 'Vegetable omelette (little oil)', '2 eggs', 190, 13, 2, 14, 100, tags: ['egg'], ing: 'eggs', ingQty: 2, step: 1),
  Food('chicken_tikka', 'Chicken tikka', '100 g', 165, 25, 2, 6, 70, tags: ['meat'], ing: 'chicken', ingQty: 130),
  Food('chicken_salan', 'Light chicken salan', '100 g chicken', 190, 20, 4, 10, 90, tags: ['meat'], ing: 'chicken', ingQty: 100),
  Food('chicken_grill', 'Grilled chicken breast', '100 g', 165, 31, 0, 3.6, 65, tags: ['meat'], ing: 'chicken', ingQty: 100),
  Food('fish_grill', 'Grilled or baked fish (rohu)', '100 g', 140, 24, 0, 4, 110, tags: ['fish'], ing: 'fish', ingQty: 120),
  Food('seekh', 'Seekh kabab', '1 piece', 120, 8, 3, 8, 50, tags: ['meat'], ing: 'chicken', ingQty: 60, step: 1),
  Food('shami', 'Shami kabab', '1 piece', 110, 7, 8, 6, 35, tags: ['meat'], ing: 'chicken', ingQty: 50, step: 1),
  Food('beef_salan', 'Beef salan', '1 cup', 320, 24, 8, 22, 200, tags: ['meat']),
  Food('mutton_karahi', 'Mutton karahi', '1 cup', 380, 26, 6, 28, 320, tags: ['meat']),
  Food('nihari', 'Nihari', '1 cup', 450, 28, 6, 35, 300, tags: ['meat']),
  Food('haleem', 'Haleem', '1 bowl', 330, 22, 28, 13, 150, tags: ['meat']),
  // dairy and drinks
  Food('milk', 'Doodh (milk)', '1 glass, 250 ml', 150, 8, 12, 8, 48, tags: ['dairy'], ing: 'milk', ingQty: 250),
  Food('chai', 'Chai with milk and 1 tsp sugar', '1 cup', 70, 2, 10, 2.5, 15, tags: ['dairy'], ing: 'milk', ingQty: 60, step: 1),
  Food('chai_ns', 'Chai with milk, no sugar', '1 cup', 45, 2, 3, 2.5, 12, tags: ['dairy'], ing: 'milk', ingQty: 60, step: 1),
  Food('green_tea', 'Green tea, no sugar', '1 cup', 2, 0, 0, 0, 12, step: 1),
  Food('dahi', 'Dahi (plain yogurt)', '1 cup, 200 g', 120, 7, 9, 6, 58, tags: ['dairy'], ing: 'dahi', ingQty: 200),
  Food('lassi_sweet', 'Sweet lassi', '1 glass', 220, 7, 36, 5, 70, tags: ['dairy'], ing: 'dahi', ingQty: 150),
  Food('lassi_salt', 'Namkeen lassi', '1 glass', 100, 6, 9, 4, 50, tags: ['dairy'], ing: 'dahi', ingQty: 150),
  Food('rooh_afza', 'Sharbat (Rooh Afza)', '1 glass', 120, 0, 30, 0, 25),
  Food('cold_drink', 'Cold drink', '1 can', 140, 0, 35, 0, 60),
  // fruit and nuts
  Food('apple', 'Apple', '1 medium', 95, 0.5, 25, 0.3, 45, ing: 'fruit', ingQty: 1, step: 1),
  Food('banana', 'Banana', '1 medium', 105, 1.3, 27, 0.4, 20, ing: 'fruit', ingQty: 1, step: 1),
  Food('guava', 'Guava (amrood)', '1 medium', 70, 3, 15, 1, 30, ing: 'fruit', ingQty: 1, step: 1),
  Food('kinnow', 'Kinnow', '1 piece', 50, 1, 12, 0.2, 20, ing: 'fruit', ingQty: 1, step: 1),
  Food('anaar', 'Anaar (pomegranate)', '1 cup seeds', 140, 3, 32, 2, 70, ing: 'fruit', ingQty: 1),
  Food('papaya', 'Papaya', '1 cup', 60, 1, 15, 0.4, 40, ing: 'fruit', ingQty: 1),
  Food('mango', 'Mango', '1 cup', 100, 1, 25, 0.6, 60, ing: 'fruit', ingQty: 1),
  Food('khajoor', 'Khajoor (dates)', '3 dates', 70, 0.6, 18, 0.1, 30, ing: 'khajoor', ingQty: 3),
  Food('almonds', 'Almonds', '10 nuts, 15 g', 90, 3.2, 3.3, 7.9, 45, tags: ['nuts'], ing: 'nuts', ingQty: 15),
  Food('walnuts', 'Walnuts', '15 g', 100, 2.3, 2.1, 10, 40, tags: ['nuts'], ing: 'nuts', ingQty: 15),
  Food('peanuts', 'Peanuts (mungfali)', '20 g', 115, 5, 3.2, 10, 12, tags: ['nuts'], ing: 'nuts', ingQty: 20),
  Food('bhuna_chana', 'Bhuna chana', '30 g', 110, 6, 18, 2, 12, ing: 'chana', ingQty: 30),
  // snacks and treats
  Food('chana_chaat', 'Chana chaat', '1 bowl', 180, 8, 28, 4, 50, ing: 'chana', ingQty: 50),
  Food('fruit_chaat', 'Fruit chaat', '1 bowl', 150, 2, 35, 1, 80, ing: 'fruit', ingQty: 2),
  Food('samosa', 'Samosa', '1 piece', 260, 4, 24, 17, 40, step: 1),
  Food('pakora', 'Pakora', '4 pieces', 200, 5, 18, 12, 40),
  Food('halwa_puri', 'Halwa puri', '1 plate', 650, 12, 75, 32, 200),
  Food('kheer', 'Kheer', '1 bowl', 280, 7, 45, 8, 80, tags: ['dairy']),
  Food('gulab_jamun', 'Gulab jamun', '1 piece', 150, 2, 22, 6, 40, tags: ['dairy'], step: 1),
  Food('biscuit', 'Biscuits', '2 pieces', 100, 1, 15, 4, 10),
  Food('ghee', 'Desi ghee', '1 tsp', 45, 0, 0, 5, 10, tags: ['dairy'], step: 1),
  Food('oil', 'Cooking oil', '1 tsp', 40, 0, 0, 4.5, 6, step: 1),
];

// -------------------------------------------------------------------------- shopping
class Ing {
  final String label, unit, group;
  final double rate; // Rs per unit (per g, ml or piece)
  const Ing(this.label, this.unit, this.group, this.rate);
}

const ingredients = <String, Ing>{
  'atta': Ing('Atta (flour)', 'g', 'Grains and flour', 0.15),
  'rice': Ing('Rice', 'g', 'Grains and flour', 0.28),
  'oats': Ing('Oats', 'g', 'Grains and flour', 0.45),
  'daal': Ing('Daal, lobia, rajma (dry)', 'g', 'Daal and chana', 0.33),
  'chana': Ing('Chana (dry or roasted)', 'g', 'Daal and chana', 0.28),
  'eggs': Ing('Eggs', 'pcs', 'Protein', 44),
  'chicken': Ing('Chicken', 'g', 'Protein', 0.55),
  'fish': Ing('Fish', 'g', 'Protein', 0.8),
  'milk': Ing('Milk (doodh)', 'ml', 'Dairy', 0.19),
  'dahi': Ing('Dahi (yogurt)', 'g', 'Dairy', 0.22),
  'veg': Ing('Sabzi, tomato, onion, cucumber', 'g', 'Vegetables and fruit', 0.08),
  'fruit': Ing('Fruit', 'pcs', 'Vegetables and fruit', 40),
  'khajoor': Ing('Khajoor (dates)', 'pcs', 'Other', 10),
  'nuts': Ing('Nuts (almonds, peanuts)', 'g', 'Other', 0.8),
};

// -------------------------------------------------------------------------- meal templates
class TP {
  final String food;
  final double servings;
  final bool fixed;
  const TP(this.food, this.servings, {this.fixed = false});
}

class Tmpl {
  final String id, name, group;
  final List<TP> parts;
  const Tmpl(this.id, this.name, this.group, this.parts);
}

const templates = <Tmpl>[
  // breakfast
  Tmpl('b_eggs', 'Boiled eggs, roti and chai', 'breakfast', [TP('egg_boiled', 2), TP('roti', 1), TP('chai_ns', 1, fixed: true)]),
  Tmpl('b_omelette', 'Vegetable omelette, roti and green tea', 'breakfast', [TP('omelette', 1), TP('roti', 1), TP('green_tea', 1, fixed: true)]),
  Tmpl('b_daal', 'Moong daal, roti and green tea', 'breakfast', [TP('moong', 1), TP('roti', 1), TP('green_tea', 1, fixed: true)]),
  Tmpl('b_chana', 'Chana chaat and roti', 'breakfast', [TP('chana_chaat', 1), TP('roti', 1), TP('green_tea', 1, fixed: true)]),
  Tmpl('b_cholay', 'Chana salan and roti', 'breakfast', [TP('chana_curry', 1), TP('roti', 1)]),
  Tmpl('b_oats', 'Oats with milk and banana', 'breakfast', [TP('oats', 1), TP('banana', 1)]),
  Tmpl('b_oatsw', 'Oats with water and banana', 'breakfast', [TP('oats_w', 1), TP('banana', 1)]),
  Tmpl('b_dahi', 'Dahi, roti and fruit', 'breakfast', [TP('dahi', 1), TP('roti', 2), TP('apple', 1)]),
  // snacks
  Tmpl('s_apple', 'Apple', 'snack', [TP('apple', 1)]),
  Tmpl('s_banana', 'Banana', 'snack', [TP('banana', 1)]),
  Tmpl('s_guava', 'Guava (amrood)', 'snack', [TP('guava', 1)]),
  Tmpl('s_kinnow', 'Kinnow', 'snack', [TP('kinnow', 2)]),
  Tmpl('s_anaar', 'Anaar (pomegranate)', 'snack', [TP('anaar', 1)]),
  Tmpl('s_papaya', 'Papaya', 'snack', [TP('papaya', 1)]),
  Tmpl('s_chana', 'Bhuna chana', 'snack', [TP('bhuna_chana', 1)]),
  Tmpl('s_chaat', 'Chana chaat', 'snack', [TP('chana_chaat', 1)]),
  Tmpl('s_fruitchaat', 'Fruit chaat', 'snack', [TP('fruit_chaat', 1)]),
  Tmpl('s_peanut', 'Peanuts (mungfali)', 'snack', [TP('peanuts', 1)]),
  Tmpl('s_almond', 'Almonds and khajoor', 'snack', [TP('almonds', 1), TP('khajoor', 1)]),
  Tmpl('s_dahi', 'Dahi', 'snack', [TP('dahi', 1)]),
  Tmpl('s_milkbanana', 'Doodh with banana', 'snack', [TP('milk', 1), TP('banana', 1)]),
  // lunch and dinner
  Tmpl('m_daal', 'Daal, roti, salad and raita', 'main', [TP('masoor', 1), TP('roti', 2), TP('salad', 1, fixed: true), TP('raita', 1, fixed: true)]),
  Tmpl('m_daalv', 'Daal, roti and salad', 'main', [TP('masoor', 1), TP('roti', 2), TP('salad', 1, fixed: true)]),
  Tmpl('m_tikka', 'Chicken tikka, sabzi and roti', 'main', [TP('chicken_tikka', 1.5), TP('bhindi', 1, fixed: true), TP('roti', 1)]),
  Tmpl('m_grill', 'Grilled chicken, sabzi and roti', 'main', [TP('chicken_grill', 1.5), TP('lauki', 1, fixed: true), TP('roti', 1)]),
  Tmpl('m_chana', 'Chana salan, roti and salad', 'main', [TP('chana_curry', 1), TP('roti', 2), TP('salad', 1, fixed: true)]),
  Tmpl('m_lobia', 'Lobia, roti and sabzi', 'main', [TP('lobia', 1), TP('roti', 2), TP('gobi', 1, fixed: true)]),
  Tmpl('m_fish', 'Grilled fish, sabzi and roti', 'main', [TP('fish_grill', 1.5), TP('palak', 1, fixed: true), TP('roti', 1)]),
  Tmpl('m_rajma', 'Rajma chawal and salad', 'main', [TP('rajma', 1), TP('rice', 1), TP('salad', 1, fixed: true)]),
  Tmpl('m_khichdi', 'Khichdi and raita', 'main', [TP('khichdi', 1), TP('raita', 1, fixed: true), TP('salad', 1, fixed: true)]),
  Tmpl('m_palak', 'Palak, daal and roti', 'main', [TP('palak', 1, fixed: true), TP('moong', 1), TP('roti', 2)]),
  Tmpl('m_egg', 'Omelette, sabzi and roti', 'main', [TP('omelette', 1), TP('gobi', 1, fixed: true), TP('roti', 1)]),
  Tmpl('m_pulao', 'Chicken pulao, salad and raita', 'main', [TP('pulao', 1), TP('salad', 1, fixed: true), TP('raita', 1, fixed: true)]),
  // sehri
  Tmpl('sh_egg', 'Omelette, roti, dahi and doodh', 'sehri', [TP('omelette', 1), TP('roti', 1), TP('dahi', 1, fixed: true), TP('milk', 1, fixed: true)]),
  Tmpl('sh_daal', 'Daal, roti and dahi', 'sehri', [TP('masoor', 1), TP('roti', 2), TP('dahi', 1, fixed: true)]),
  Tmpl('sh_oats', 'Oats with milk, banana and khajoor', 'sehri', [TP('oats', 1), TP('banana', 1), TP('khajoor', 1, fixed: true)]),
  Tmpl('sh_chana', 'Chana salan, roti and doodh', 'sehri', [TP('chana_curry', 1), TP('roti', 2), TP('milk', 1, fixed: true)]),
  Tmpl('sh_vegan', 'Oats with water, banana and khajoor, with chana chaat', 'sehri', [TP('oats_w', 1), TP('banana', 1), TP('khajoor', 1, fixed: true), TP('chana_chaat', 1)]),
  Tmpl('sh_daalv', 'Daal, roti and salad', 'sehri', [TP('moong', 1), TP('roti', 2), TP('salad', 1, fixed: true)]),
  // iftar
  Tmpl('i_std', 'Khajoor, fruit chaat and chana chaat', 'iftar', [TP('khajoor', 1, fixed: true), TP('fruit_chaat', 1), TP('chana_chaat', 1)]),
  Tmpl('i_lassi', 'Khajoor, namkeen lassi and chana chaat', 'iftar', [TP('khajoor', 1, fixed: true), TP('lassi_salt', 1, fixed: true), TP('chana_chaat', 1)]),
  Tmpl('i_veg', 'Khajoor, banana and bhuna chana', 'iftar', [TP('khajoor', 1, fixed: true), TP('banana', 1), TP('bhuna_chana', 2)]),
];

String groupOf(String mealId) {
  switch (mealId) {
    case 'bf':
      return 'breakfast';
    case 'mm':
    case 'sn':
    case 'pw':
      return 'snack';
    case 'seh':
      return 'sehri';
    case 'ifr':
      return 'iftar';
    default:
      return 'main';
  }
}

// -------------------------------------------------------------------------- helpers
const _aliases = <String, List<String>>{
  'egg': ['egg', 'omelette'],
  'meat': ['chicken', 'kabab', 'mutton', 'beef', 'tikka', 'boti'],
  'fish': ['fish', 'rohu'],
  'dairy': ['milk', 'dahi', 'doodh', 'yogurt', 'raita', 'lassi', 'ghee'],
  'nuts': ['almond', 'walnut', 'peanut', 'mungfali', 'nuts'],
};

/// The words that mean a food is not allowed for this diet.
Set<String> blockedTags(String dietType, List<String> allergies) {
  final s = <String>{...allergies};
  if (dietType == 'veg' || dietType == 'vegan') s.addAll(['meat', 'fish']);
  if (dietType == 'vegan') s.addAll(['egg', 'dairy']);
  return s;
}

bool textBlocked(String text, Set<String> blocked) {
  final t = text.toLowerCase();
  for (final b in blocked) {
    for (final w in _aliases[b] ?? const <String>[]) {
      if (t.contains(w)) return true;
    }
  }
  return false;
}
