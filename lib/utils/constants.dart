class AppConstants {
  // Phrase Categories
  static const Map<String, List<String>> phraseCategories = {
    'Common': [
      'Hello, how are you?',
      'Good morning',
      'Thank you very much',
      'Nice to meet you',
      'How is your day?',
      'I am doing well',
      'See you later',
      'Have a good day',
    ],
    'Food & Drink': [
      'I would like water',
      'Can I have coffee?',
      'The food is delicious',
      'I am hungry',
      'Pass the salt please',
      'More juice please',
      'I want breakfast',
      'Time for dinner',
    ],
    'Feelings': [
      'I am happy today',
      'I feel tired',
      'I am excited',
      'I feel much better',
      'I am grateful',
      'That makes me smile',
      'I feel strong',
      'I am proud of myself',
    ],
    'Medical': [
      'I need my medicine',
      'I have an appointment',
      'Please call the doctor',
      'I feel dizzy',
      'My throat hurts',
      'I need to rest',
      'Time for therapy',
      'I feel improvement',
    ],
    'Sentence Builder': [
      'The cat sat on the mat',
      'I went to the store yesterday',
      'She is reading a big book',
      'We played in the park today',
      'He likes to eat red apples',
      'The dog ran across the yard',
      'My friend gave me a gift',
      'They are going to the beach',
    ],
    'Sentence Chain': [
      'Apple Doctor Running Blue',
      'Cat River Sunny Pencil',
      'Garden Chair Music Star Light',
      'Water Lamp House Green',
      'Table Monkey Cloud Orange Rain',
      'Bread Tiger Window Silver',
      'Flower Clock Bridge Mountain',
      'Candle Rabbit Forest Purple Stone',
    ],
    'Tongue Twisters': [
      'She sells seashells by the seashore',
      'Peter Piper picked a peck of pickled peppers',
      'How much wood would a woodchuck chuck',
      'Red lorry yellow lorry',
      'Unique New York',
      'Toy boat toy boat toy boat',
      'Fresh French fried fish',
      'Six slippery snails slid slowly',
    ],
  };

  // Exercise Types
  static const String phraseExercise = 'phrase_practice';
  static const String wordRepeat = 'word_repeat';
  static const String pictureNaming = 'picture_naming';

  // Word Repeat Sounds
  static const List<String> wordRepeatItems = [
    'Apple',
    'Banana',
    'Cat',
    'Dog',
    'Elephant',
    'Fish',
    'Guitar',
    'House',
    'Ice cream',
    'Jungle',
    'Kite',
    'Lemon',
  ];

  // Picture Naming Items
  static const List<Map<String, String>> pictureNamingItems = [
    {'word': 'Apple', 'emoji': '🍎'},
    {'word': 'Car', 'emoji': '🚗'},
    {'word': 'Dog', 'emoji': '🐕'},
    {'word': 'Sun', 'emoji': '☀️'},
    {'word': 'Book', 'emoji': '📖'},
    {'word': 'Fish', 'emoji': '🐟'},
    {'word': 'Tree', 'emoji': '🌳'},
    {'word': 'House', 'emoji': '🏠'},
    {'word': 'Star', 'emoji': '⭐'},
    {'word': 'Cup', 'emoji': '☕'},
    {'word': 'Bird', 'emoji': '🐦'},
    {'word': 'Cat', 'emoji': '🐱'},
  ];

  // Difficulty Levels
  static const int difficultyEasy = 1;
  static const int difficultyMedium = 2;
  static const int difficultyHard = 3;

  static const int mediumTimerSeconds = 5;

  // Sentence Chain items for Hard difficulty - Picture Naming
  // Each entry has a 'chain' (3-5 words to repeat in order) and 'emojis'
  static const List<Map<String, String>> pictureNamingHardItems = [
    {'chain': 'Apple Car Dog', 'emojis': '🍎 🚗 🐕'},
    {'chain': 'Sun Book Fish Tree', 'emojis': '☀️ 📖 🐟 🌳'},
    {'chain': 'House Star Cup', 'emojis': '🏠 ⭐ ☕'},
    {'chain': 'Bird Cat Apple Sun', 'emojis': '🐦 🐱 🍎 ☀️'},
    {'chain': 'Fish Tree House Star Cup', 'emojis': '🐟 🌳 🏠 ⭐ ☕'},
    {'chain': 'Dog Book Bird', 'emojis': '🐕 📖 🐦'},
    {'chain': 'Car Sun Tree Cat', 'emojis': '🚗 ☀️ 🌳 🐱'},
    {'chain': 'Star Fish Apple Dog House', 'emojis': '⭐ 🐟 🍎 🐕 🏠'},
    {'chain': 'Cup Bird Car', 'emojis': '☕ 🐦 🚗'},
    {'chain': 'Tree House Cat Book', 'emojis': '🌳 🏠 🐱 📖'},
    {'chain': 'Apple Star Dog Fish', 'emojis': '🍎 ⭐ 🐕 🐟'},
    {'chain': 'Sun Cup Bird Tree House', 'emojis': '☀️ ☕ 🐦 🌳 🏠'},
  ];

  // Sentence Chain items for Hard difficulty - Word Repeat
  // Each entry has a 'chain' (3-5 words to repeat in correct order)
  static const List<Map<String, String>> wordRepeatHardItems = [
    {'chain': 'Apple Doctor Running'},
    {'chain': 'Cat River Sunny Pencil'},
    {'chain': 'Garden Chair Music'},
    {'chain': 'Water Lamp House Green'},
    {'chain': 'Table Monkey Cloud Orange Rain'},
    {'chain': 'Bread Tiger Window'},
    {'chain': 'Flower Clock Bridge Mountain'},
    {'chain': 'Candle Rabbit Forest Purple'},
    {'chain': 'Silver Basket Ocean'},
    {'chain': 'Hammer Sunset Island River'},
    {'chain': 'Circle Diamond Feather Pilot Stone'},
    {'chain': 'Velvet Dragon Morning'},
  ];

  // Achievement Definitions
  static const List<Map<String, dynamic>> achievements = [
    {'id': 'first_word', 'title': 'First Word', 'subtitle': 'Completed first exercise', 'icon': '🎯', 'requirement': 1},
    {'id': 'streak_3', 'title': '3 Day Streak', 'subtitle': 'Practiced 3 days in a row', 'icon': '🔥', 'requirement': 3},
    {'id': 'streak_7', 'title': '7 Day Streak', 'subtitle': 'Practiced 7 days in a row', 'icon': '⚡', 'requirement': 7},
    {'id': 'words_50', 'title': '50 Words', 'subtitle': 'Spoke 50 words total', 'icon': '💬', 'requirement': 50},
    {'id': 'words_100', 'title': '100 Words', 'subtitle': 'Spoke 100 words total', 'icon': '🏆', 'requirement': 100},
    {'id': 'accuracy_80', 'title': 'Sharp Speaker', 'subtitle': 'Got 80%+ accuracy', 'icon': '🎖️', 'requirement': 80},
    {'id': 'all_categories', 'title': 'Explorer', 'subtitle': 'Tried all categories', 'icon': '🌟', 'requirement': 4},
  ];

  // Feedback Messages Based on Clarity Score
  static String getFeedback(double score) {
    if (score >= 90) return 'Excellent! Your pronunciation is very clear.';
    if (score >= 75) return 'Great job! Very good pronunciation.';
    if (score >= 60) return 'Good effort! Keep practicing for more clarity.';
    if (score >= 40) return 'Nice try! Focus on speaking slowly and clearly.';
    return 'Keep going! Practice makes perfect. Try again.';
  }
}
