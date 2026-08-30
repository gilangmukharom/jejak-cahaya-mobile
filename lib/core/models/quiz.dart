import 'package:equatable/equatable.dart';

import 'achievement.dart';
import 'json_utils.dart';
import 'scan_result.dart';

class Quiz extends Equatable {
  const Quiz({
    required this.id,
    required this.title,
    required this.passingScore,
    required this.xpReward,
    required this.attemptsUsed,
    required this.questions,
    required this.collectibleName,
    this.description,
    this.timeLimitSec,
    this.maxAttempts,
    this.bestScore,
    this.collectibleImageUrl,
  });

  final String id;
  final String title;

  /// Persentase jawaban benar minimum agar dianggap lulus (0–100).
  final int passingScore;
  final int xpReward;
  final int attemptsUsed;
  final List<QuizQuestion> questions;
  final String collectibleName;

  final String? description;
  final int? timeLimitSec;

  /// Null berarti percobaan tidak dibatasi.
  final int? maxAttempts;
  final int? bestScore;
  final String? collectibleImageUrl;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final collectible = Json.map(json['collectible']);

    return Quiz(
      id: Json.str(json['id']),
      title: Json.str(json['title']),
      passingScore: Json.integer(json['passingScore'], 60),
      xpReward: Json.integer(json['xpReward']),
      attemptsUsed: Json.integer(json['attemptsUsed']),
      questions: Json.list(json['questions'], QuizQuestion.fromJson),
      collectibleName: Json.str(collectible['name']),
      description: Json.strOrNull(json['description']),
      timeLimitSec: Json.intOrNull(json['timeLimitSec']),
      maxAttempts: Json.intOrNull(json['maxAttempts']),
      bestScore: Json.intOrNull(json['bestScore']),
      collectibleImageUrl: Json.strOrNull(collectible['imageUrl']),
    );
  }

  bool get hasAttemptsLeft =>
      maxAttempts == null || attemptsUsed < maxAttempts!;

  @override
  List<Object?> get props => [id, title, questions, attemptsUsed];
}

/// Satu soal. Jawaban benar tidak pernah dikirim bersama soal — backend baru
/// mengungkapnya pada response hasil, setelah jawaban masuk.
class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.points,
    required this.orderIndex,
  });

  final String id;
  final String question;
  final List<String> options;
  final int points;
  final int orderIndex;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: Json.str(json['id']),
        question: Json.str(json['question']),
        options: Json.stringList(json['options']),
        points: Json.integer(json['points'], 10),
        orderIndex: Json.integer(json['orderIndex']),
      );

  @override
  List<Object?> get props => [id, question, options];
}

class QuizAnswer extends Equatable {
  const QuizAnswer({required this.questionId, required this.selectedIndex});

  final String questionId;
  final int selectedIndex;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'selectedIndex': selectedIndex,
      };

  @override
  List<Object?> get props => [questionId, selectedIndex];
}

class QuizResult extends Equatable {
  const QuizResult({
    required this.attemptId,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.passed,
    required this.xpEarned,
    required this.attemptNo,
    required this.corrections,
    required this.totalXp,
    required this.unlockedAchievements,
    this.levelUp,
  });

  final String attemptId;

  /// Persentase 0–100.
  final int score;
  final int correctCount;
  final int totalQuestions;
  final bool passed;
  final int xpEarned;
  final int attemptNo;
  final List<QuizCorrection> corrections;
  final int totalXp;
  final List<Achievement> unlockedAchievements;
  final LevelUp? levelUp;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        attemptId: Json.str(json['attemptId']),
        score: Json.integer(json['score']),
        correctCount: Json.integer(json['correctCount']),
        totalQuestions: Json.integer(json['totalQuestions']),
        passed: Json.boolean(json['passed']),
        xpEarned: Json.integer(json['xpEarned']),
        attemptNo: Json.integer(json['attemptNo'], 1),
        corrections: Json.list(json['corrections'], QuizCorrection.fromJson),
        totalXp: Json.integer(json['totalXp']),
        unlockedAchievements:
            Json.list(json['unlockedAchievements'], Achievement.fromJson),
        levelUp: json['levelUp'] is Map<String, dynamic>
            ? LevelUp.fromJson(json['levelUp'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [attemptId, score, passed, xpEarned];
}

/// Koreksi satu soal, dikirim setelah jawaban dinilai.
///
/// Selalu memuat [explanation] — pemain yang menjawab salah tetap belajar,
/// yang justru merupakan tujuan utama quiz ini.
class QuizCorrection extends Equatable {
  const QuizCorrection({
    required this.questionId,
    required this.correctIndex,
    required this.isCorrect,
    this.selectedIndex,
    this.explanation,
  });

  final String questionId;
  final int correctIndex;
  final bool isCorrect;

  /// Null bila soal ini tidak dijawab (mis. waktu habis).
  final int? selectedIndex;
  final String? explanation;

  factory QuizCorrection.fromJson(Map<String, dynamic> json) => QuizCorrection(
        questionId: Json.str(json['questionId']),
        correctIndex: Json.integer(json['correctIndex']),
        isCorrect: Json.boolean(json['isCorrect']),
        selectedIndex: Json.intOrNull(json['selectedIndex']),
        explanation: Json.strOrNull(json['explanation']),
      );

  @override
  List<Object?> get props =>
      [questionId, correctIndex, isCorrect, selectedIndex];
}
