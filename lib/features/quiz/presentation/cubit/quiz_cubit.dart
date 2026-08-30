import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/quiz.dart';
import '../../../game/data/game_repository.dart';

enum QuizStage { loading, ready, submitting, finished, error }

class QuizState extends Equatable {
  const QuizState({
    this.stage = QuizStage.loading,
    this.quiz,
    this.currentIndex = 0,
    this.selections = const {},
    this.result,
    this.failure,
    this.secondsLeft,
  });

  final QuizStage stage;
  final Quiz? quiz;
  final int currentIndex;

  /// `{ questionId: indeks pilihan }`.
  final Map<String, int> selections;

  final QuizResult? result;
  final Failure? failure;

  /// Sisa waktu bila quiz memiliki batas waktu.
  final int? secondsLeft;

  QuizQuestion? get currentQuestion {
    final questions = quiz?.questions;
    if (questions == null || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  int get totalQuestions => quiz?.questions.length ?? 0;
  bool get isLastQuestion => currentIndex >= totalQuestions - 1;
  int get answeredCount => selections.length;

  /// Pilihan saat ini untuk soal yang sedang tampil, bila sudah dijawab.
  int? get currentSelection {
    final question = currentQuestion;
    return question == null ? null : selections[question.id];
  }

  double get progress =>
      totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0;

  QuizState copyWith({
    QuizStage? stage,
    Quiz? quiz,
    int? currentIndex,
    Map<String, int>? selections,
    QuizResult? result,
    Failure? failure,
    int? secondsLeft,
    bool clearFailure = false,
  }) =>
      QuizState(
        stage: stage ?? this.stage,
        quiz: quiz ?? this.quiz,
        currentIndex: currentIndex ?? this.currentIndex,
        selections: selections ?? this.selections,
        result: result ?? this.result,
        failure: clearFailure ? null : (failure ?? this.failure),
        secondsLeft: secondsLeft ?? this.secondsLeft,
      );

  @override
  List<Object?> get props =>
      [stage, quiz, currentIndex, selections, result, failure, secondsLeft];
}

/// Mengendalikan pengerjaan quiz.
///
/// Cubit ini tidak pernah tahu jawaban mana yang benar — backend baru
/// mengungkapnya pada response hasil. Itulah yang membuat skor tidak bisa
/// dipalsukan dari sisi aplikasi.
class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._repository) : super(const QuizState());

  final GameRepository _repository;

  Timer? _timer;
  DateTime? _startedAt;

  Future<void> loadByQuizId(String quizId) =>
      _load(() => _repository.fetchQuiz(quizId));

  Future<void> loadByCollectible(String collectibleId) =>
      _load(() => _repository.fetchQuizByCollectible(collectibleId));

  Future<void> _load(Future<Quiz> Function() fetch) async {
    emit(const QuizState());

    try {
      final quiz = await fetch();

      if (quiz.questions.isEmpty) {
        emit(
          state.copyWith(
            stage: QuizStage.error,
            failure:
                const UnknownFailure(message: 'Quiz ini belum memiliki soal.'),
          ),
        );
        return;
      }

      _startedAt = DateTime.now();

      emit(
        QuizState(
          stage: QuizStage.ready,
          quiz: quiz,
          secondsLeft: quiz.timeLimitSec,
        ),
      );

      if (quiz.timeLimitSec != null) _startTimer();
    } on Object catch (error) {
      emit(state.copyWith(
          stage: QuizStage.error, failure: FailureMapper.map(error)));
    }
  }

  void selectOption(int optionIndex) {
    final question = state.currentQuestion;
    if (question == null || state.stage != QuizStage.ready) return;

    emit(
      state.copyWith(
        selections: {...state.selections, question.id: optionIndex},
      ),
    );
  }

  void nextQuestion() {
    if (state.isLastQuestion) return;
    emit(state.copyWith(currentIndex: state.currentIndex + 1));
  }

  void previousQuestion() {
    if (state.currentIndex == 0) return;
    emit(state.copyWith(currentIndex: state.currentIndex - 1));
  }

  /// Mengirim jawaban untuk dinilai.
  ///
  /// Soal yang belum dijawab tetap dikirim apa adanya — backend menghitungnya
  /// salah, bukan menolak keseluruhan pengiriman. Dengan begitu pemain yang
  /// kehabisan waktu tetap menerima hasil dan penjelasannya.
  Future<void> submit() async {
    final quiz = state.quiz;
    if (quiz == null || state.stage == QuizStage.submitting) return;

    _timer?.cancel();
    emit(state.copyWith(stage: QuizStage.submitting, clearFailure: true));

    try {
      final answers = state.selections.entries
          .map((entry) =>
              QuizAnswer(questionId: entry.key, selectedIndex: entry.value))
          .toList(growable: false);

      if (answers.isEmpty) {
        emit(
          state.copyWith(
            stage: QuizStage.ready,
            failure: const UnknownFailure(
              message: 'Jawab minimal satu soal sebelum mengirim.',
            ),
          ),
        );
        return;
      }

      final startedAt = _startedAt;
      final result = await _repository.submitQuiz(
        quizId: quiz.id,
        answers: answers,
        durationSec: startedAt == null
            ? null
            : DateTime.now().difference(startedAt).inSeconds,
      );

      emit(state.copyWith(
          stage: QuizStage.finished, result: result, clearFailure: true));
    } on Object catch (error) {
      emit(state.copyWith(
          stage: QuizStage.ready, failure: FailureMapper.map(error)));
    }
  }

  /// Mengulang quiz dari awal, mempertahankan soal yang sudah dimuat.
  void retry() {
    final quiz = state.quiz;
    if (quiz == null) return;

    _startedAt = DateTime.now();
    emit(QuizState(
        stage: QuizStage.ready, quiz: quiz, secondsLeft: quiz.timeLimitSec));
    if (quiz.timeLimitSec != null) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (state.secondsLeft ?? 0) - 1;

      if (remaining <= 0) {
        timer.cancel();
        emit(state.copyWith(secondsLeft: 0));
        // Waktu habis mengirim jawaban apa adanya, bukan membuang pekerjaan
        // pemain — soal yang belum terjawab dihitung salah oleh server.
        unawaited(submit());
        return;
      }

      emit(state.copyWith(secondsLeft: remaining));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
