import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/quiz.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/quiz_cubit.dart';

/// Halaman pengerjaan quiz.
///
/// Dapat dibuka lewat dua jalan: dengan [quizId] (setelah scan, karena hasil
/// scan sudah membawa id quiz-nya) atau dengan [collectibleId] (dari halaman
/// detail koleksi, yang hanya mengenal tokohnya). Tepat salah satu wajib diisi.
class QuizPage extends StatelessWidget {
  const QuizPage({this.quizId, this.collectibleId, super.key})
      : assert(
          quizId != null || collectibleId != null,
          'Isi salah satu: quizId atau collectibleId',
        );

  final String? quizId;
  final String? collectibleId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuizCubit>(
      create: (_) {
        final cubit = QuizCubit(sl<GameRepository>());
        final id = quizId;
        if (id != null) {
          cubit.loadByQuizId(id);
        } else {
          cubit.loadByCollectible(collectibleId!);
        }
        return cubit;
      },
      child: const _QuizView(),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<QuizCubit, QuizState>(
          listenWhen: (previous, current) =>
              previous.stage != current.stage &&
              current.stage == QuizStage.finished,
          listener: (context, state) {
            // XP quiz baru saja masuk; segarkan kartu profil.
            context.read<AuthCubit>().refreshUser();
          },
          builder: (context, state) => switch (state.stage) {
            QuizStage.loading => const LoadingView(message: 'Memuat soal…'),
            QuizStage.error => FailureView(
                failure: state.failure!,
                onRetry: () => context.pop(),
                retryLabel: 'Kembali',
              ),
            QuizStage.finished => _ResultView(result: state.result!),
            _ => _QuestionView(state: state),
          },
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.state});

  final QuizState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = state.currentQuestion;
    if (question == null) return const LoadingView();

    final selection = state.currentSelection;
    final isSubmitting = state.stage == QuizStage.submitting;

    return Column(
      children: [
        _QuizHeader(state: state),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Soal ${state.currentIndex + 1} dari ${state.totalQuestions}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  question.question,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                for (var index = 0;
                    index < question.options.length;
                    index++) ...[
                  _OptionTile(
                    label: question.options[index],
                    letter: String.fromCharCode(65 + index),
                    isSelected: selection == index,
                    onTap: isSubmitting
                        ? null
                        : () => context.read<QuizCubit>().selectOption(index),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        _QuizFooter(state: state),
      ],
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.state});

  final QuizState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondsLeft = state.secondsLeft;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _confirmExit(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Keluar dari quiz',
              ),
              Expanded(
                child: Text(
                  state.quiz?.title ?? 'Quiz',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (secondsLeft != null)
                _TimerChip(secondsLeft: secondsLeft)
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari quiz?'),
        content: const Text(
          'Jawaban yang sudah dipilih tidak akan tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut Mengerjakan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) context.pop();
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    // Di bawah 15 detik warnanya berubah — sinyal yang cukup jelas tanpa perlu
    // animasi yang mengganggu konsentrasi.
    final isUrgent = secondsLeft <= 15;
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isUrgent ? AppColors.danger : AppColors.primary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$minutes:$seconds',
        style: TextStyle(
          color: isUrgent ? AppColors.danger : AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.letter,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final String letter;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizFooter extends StatelessWidget {
  const _QuizFooter({required this.state});

  final QuizState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuizCubit>();
    final isSubmitting = state.stage == QuizStage.submitting;
    final hasAnswered = state.currentSelection != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        children: [
          if (state.currentIndex > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isSubmitting ? null : cubit.previousQuestion,
                child: const Text('Sebelumnya'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isSubmitting || !hasAnswered
                  ? null
                  : state.isLastQuestion
                      ? cubit.submit
                      : cubit.nextQuestion,
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      state.isLastQuestion ? 'Kirim Jawaban' : 'Selanjutnya'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hasil penilaian beserta koreksi tiap soal.
///
/// Penjelasan jawaban selalu ditampilkan, termasuk untuk soal yang sudah benar —
/// tujuan quiz ini belajar, bukan sekadar menilai.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = result.passed;
    final accent = passed ? AppColors.success : AppColors.warning;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${result.score}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'SKOR',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: accent, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            passed ? 'Alhamdulillah, Anda lulus!' : 'Belum lulus, coba lagi ya',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.correctCount} dari ${result.totalQuestions} jawaban benar',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (result.xpEarned > 0) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+${result.xpEarned} XP',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ] else if (passed) ...[
            const SizedBox(height: 14),
            Text(
              'XP untuk quiz ini sudah pernah Anda peroleh.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pembahasan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          for (final correction in result.corrections) ...[
            _CorrectionCard(correction: correction),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          if (!passed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<QuizCubit>().retry(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Coba Lagi'),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('Lanjut Menjelajah'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});

  final QuizCorrection correction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = correction.isCorrect;
    final accent = isCorrect ? AppColors.success : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect
                      ? 'Jawaban Anda benar'
                      : correction.selectedIndex == null
                          ? 'Tidak dijawab'
                          : 'Jawaban Anda kurang tepat',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (correction.explanation != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    correction.explanation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
