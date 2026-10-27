import '../domain/models/game_question.dart';

/// Catalogue local des questions utilisées par les manches du jeu.
///
/// Les règles de progression restent dans `BubbleGame`; ce fichier ne contient
/// que le contenu éditorial.
abstract final class GameQuestions {
  /// All questions available for game sessions.
  static const List<GameQuestion> all = [
    // --- Salutations ---
    GameQuestion(
      prompt: "What does 'hello' mean in French?",
      answer: 'Bonjour',
      choices: ['Au revoir', 'À très bientôt', 'Bonjour', 'Merci', 'Beaucoup'],
      knowledge: ['french', 'greetings', 'beginner', 'en-to-fr'],
      nameAudiofr: 'bonjour.mp3',
      nameAudioEn: 'hello_en_us.mp3'
    ),
    GameQuestion(
      prompt: "What does 'goodbye' mean in French?",
      answer: 'Au revoir',
      choices: ['Bonjour', 'Merci', 'Bonsoir', 'Au revoir', 'Beaucoup'],
      knowledge: ['french', 'greetings', 'beginner', 'farewell'],
      nameAudiofr: 'aurevoir.mp3',
      nameAudioEn: 'goodbye_en_us.mp3'
    ),
    GameQuestion(
      prompt: "What does 'thank you' mean in French?",
      answer: 'Merci',
      choices: ['Pardon', 'Bonjour', 'Salut', 'Beaucoup', 'Merci'],
      knowledge: ['french', 'politeness', 'beginner', 'gratitude'],
      nameAudiofr: 'thank_you_fr.mp3',
      nameAudioEn: 'thanks_en_us.mp3'
    ),
    GameQuestion(
      prompt: "How do you say 'good evening' in French?",
      answer: 'Bonsoir',
      choices: ['Bonsoir', 'Bonne nuit', 'Bonjour', 'Salut', 'À demain'],
      knowledge: ['french', 'greetings', 'time-of-day', 'en-to-fr'],
      nameAudiofr: 'bonsoir.mp3',
      nameAudioEn: 'goodbye_en_us.mp3'
    ),
    GameQuestion(
      prompt: "How do you say 'good night' in French?",
      answer: 'Bonne nuit',
      choices: ['Bonsoir', 'À bientôt', 'Bonne nuit', 'Bonne journée', 'Merci'],
      knowledge: ['french', 'greetings', 'time-of-day', 'bedtime'],
      nameAudiofr: 'bonne_nuit.mp3',
    ),
    GameQuestion(
      prompt: "What does 'please' mean in French?",
      answer: "S'il vous plaît",
      choices: ['Pardon', "S'il vous plaît", 'De rien', 'Merci', 'Excusez-moi'],
      knowledge: ['french', 'politeness', 'formal', 'requests'],
      nameAudiofr: 'sil_vous_plait.mp3',
      nameAudioEn: 'please_en_us.mp3'
    ),
    GameQuestion(
      prompt: "What does 'you're welcome' mean in French?",
      answer: 'De rien',
      choices: ['De rien', 'Merci', 'Pardon', 'Bonjour', 'Au revoir'],
      knowledge: ['french', 'politeness', 'replies', 'everyday'],
      nameAudiofr: 'de_rien.mp3',
    ),
    GameQuestion(
      prompt: "What does 'sorry / excuse me' mean in French?",
      answer: 'Pardon',
      choices: ['Merci', 'Salut', 'Bonsoir', 'Pardon', 'Beaucoup'],
      knowledge: ['french', 'politeness', 'apology', 'everyday'],
      nameAudiofr: 'pardon.mp3',
      nameAudioEn: 'sorry_en_us.mp3'
    ),

    // --- Oui / non / mots courants ---
    GameQuestion(
      prompt: "What does 'yes' mean in French?",
      answer: 'Oui',
      choices: ['Non', 'Oui', 'Peut-être', 'Jamais', 'Toujours'],
      knowledge: ['french', 'basics', 'beginner', 'answers'],
      nameAudiofr: 'oui.mp3',
      nameAudioEn: 'yes_en_us.mp3'
    ),
    GameQuestion(
      prompt: "What does 'no' mean in French?",
      answer: 'Non',
      choices: ['Oui', 'Peut-être', 'Non', 'Jamais', 'Beaucoup'],
      knowledge: ['french', 'basics', 'beginner', 'negation'],
      nameAudiofr: 'non.mp3',
      nameAudioEn: 'no_en_us.mp3'
    ),
    GameQuestion(
      prompt: "What does 'a lot / very much' mean in French?",
      answer: 'Beaucoup',
      choices: ['Peu', 'Beaucoup', 'Trop', 'Rien', 'Jamais'],
      knowledge: ['french', 'adverbs', 'quantity', 'intermediate'],
      nameAudiofr: 'beaucoup.mp3',
      nameAudioEn: 'alot_en_us.mp3'
    ),

    // --- Questions inversées (français -> anglais) ---
    GameQuestion(
      prompt: "What does 'Comment ça va ?' mean in English?",
      answer: 'How are you?',
      choices: [
        'Where are you?',
        'What is your name?',
        'How are you?',
        'How old are you?',
        'Who are you?',
      ],
      knowledge: ['french', 'conversation', 'questions', 'fr-to-en'],
      nameAudiofr: 'comment_ca_va.mp3',
    ),
    GameQuestion(
      prompt: "What does 'Je m'appelle' mean in English?",
      answer: 'My name is',
      choices: [
        'I am hungry',
        'I live in',
        'My name is',
        'I am tired',
        'I like',
      ],
      knowledge: ['french', 'introductions', 'phrases', 'fr-to-en'],
      nameAudiofr: 'je_mappelle.mp3',
    ),
    GameQuestion(
      prompt: "What does 'À demain' mean in English?",
      answer: 'See you tomorrow',
      choices: [
        'See you tomorrow',
        'Good morning',
        'Thank you',
        'Good luck',
        'Welcome',
      ],
      knowledge: ['french', 'farewell', 'time-expressions', 'fr-to-en'],
      nameAudiofr: 'a_demain.mp3',
    ),

    // --- Nombres ---
    GameQuestion(
      prompt: "What is 'three' in French?",
      answer: 'Trois',
      choices: ['Deux', 'Quatre', 'Cinq', 'Trois', 'Un'],
      knowledge: ['french', 'numbers', 'counting', 'beginner'],
      nameAudiofr: 'trois.mp3',
    ),
    GameQuestion(
      prompt: "What is 'ten' in French?",
      answer: 'Dix',
      choices: ['Six', 'Dix', 'Sept', 'Huit', 'Neuf'],
      knowledge: ['french', 'numbers', 'counting', 'pronunciation'],
      nameAudiofr: 'dix.mp3',
    ),

    // --- Couleurs ---
    GameQuestion(
      prompt: "What is 'red' in French?",
      answer: 'Rouge',
      choices: ['Bleu', 'Vert', 'Rouge', 'Jaune', 'Noir'],
      knowledge: ['french', 'colors', 'adjectives', 'beginner'],
      nameAudiofr: 'rouge.mp3',
    ),
    GameQuestion(
      prompt: "What is 'green' in French?",
      answer: 'Vert',
      choices: ['Vert', 'Blanc', 'Rose', 'Violet', 'Gris'],
      knowledge: ['french', 'colors', 'adjectives', 'nature'],
      nameAudiofr: 'vert.mp3',
    ),

    // --- Nourriture & boissons ---
    GameQuestion(
      prompt: "What is 'water' in French?",
      answer: 'Eau',
      choices: ['Lait', 'Jus', 'Eau', 'Café', 'Thé'],
      knowledge: ['french', 'food-and-drink', 'nouns', 'beginner'],
      nameAudiofr: 'eau.mp3',
    ),
    GameQuestion(
      prompt: "What is 'bread' in French?",
      answer: 'Pain',
      choices: ['Pomme', 'Pain', 'Fromage', 'Riz', 'Poisson'],
      knowledge: ['french', 'food-and-drink', 'nouns', 'bakery'],
      nameAudiofr: 'pain.mp3',
    ),

    // --- Famille ---
    GameQuestion(
      prompt: "What is 'mother' in French?",
      answer: 'Mère',
      choices: ['Père', 'Sœur', 'Frère', 'Mère', 'Tante'],
      knowledge: ['french', 'family', 'nouns', 'accents'],
      nameAudiofr: 'mere.mp3',
    ),

    // --- Jours ---
    GameQuestion(
      prompt: "What is 'Monday' in French?",
      answer: 'Lundi',
      choices: ['Mardi', 'Lundi', 'Jeudi', 'Samedi', 'Dimanche'],
      knowledge: ['french', 'days-of-week', 'calendar', 'intermediate'],
      nameAudiofr: 'lundi.mp3',
    ),
  ];
}
