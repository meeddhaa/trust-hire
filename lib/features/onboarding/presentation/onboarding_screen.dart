import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/skill_keywords.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_motion.dart';
import '../providers/onboarding_providers.dart';

/// Profile build: name, skills (the input side of the match-gap diff),
/// experience, and education — typed, not a resume upload, per the
/// "Decision: no Firebase Storage" note in docs/ARCHITECTURE.md. The
/// router redirects here for any signed-in user whose profile isn't
/// `onboardingComplete` yet, and away from here once it is.
///
/// Name is collected here, required, rather than pulled off the signed-in
/// Firebase user — a phone+OTP sign-in (see `SignInScreen`) has no
/// display name of its own, and this is the one screen every user passes
/// through regardless of how they signed in. Without it,
/// `UserProfile.friendlyUsername` has nothing to fall back to but the
/// phone number, or "there".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _skillController = TextEditingController();
  // Autocomplete's own assertion requires focusNode and textEditingController
  // to be given together or not at all — caught live: passing only the
  // controller (needed so `_addSkill` can clear it after each add) without
  // this crashed onboarding outright with "(focusNode == null) ==
  // (textEditingController == null)' is not true".
  final _skillFocusNode = FocusNode();
  final _headlineController = TextEditingController();
  final _yearsController = TextEditingController();
  final _educationController = TextEditingController();
  final List<String> _skills = [];

  @override
  void dispose() {
    _nameController.dispose();
    _skillController.dispose();
    _skillFocusNode.dispose();
    _headlineController.dispose();
    _yearsController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    if (_skills.any((s) => s.toLowerCase() == skill.toLowerCase())) {
      _skillController.clear();
      return;
    }
    setState(() {
      _skills.add(skill);
      _skillController.clear();
    });
  }

  void _removeSkill(String skill) => setState(() => _skills.remove(skill));

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter your name to continue.')));
      return;
    }
    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add at least one skill to continue.')));
      return;
    }
    ref.read(onboardingControllerProvider.notifier).submit(
          displayName: name,
          skills: _skills,
          yearsOfExperience: int.tryParse(_yearsController.text.trim()),
          educationLevel:
              _educationController.text.trim().isEmpty ? null : _educationController.text.trim(),
          headline: _headlineController.text.trim().isEmpty ? null : _headlineController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(onboardingControllerProvider);
    final isLoading = state.isLoading;

    ref.listen(onboardingControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null) {
        final message = error is Failure ? error.message : 'Something went wrong — please try again.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Build your profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'What should we call you?',
                  style: text.headlineSmall,
                ).animate().fadeIn(duration: AppMotion.standard),
                const SizedBox(height: 4),
                Text(
                  'Shown on your profile — the only place this app ever asks for a name.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Naafisa Medha'),
                ),
                const SizedBox(height: 28),

                Text(
                  "What you're good at",
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'This is what every match score gets diffed against — the more '
                  'specific, the sharper the gap breakdown.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  textEditingController: _skillController,
                  focusNode: _skillFocusNode,
                  optionsBuilder: (value) =>
                      SkillKeywords.suggestionsFor(value.text, exclude: _skills),
                  onSelected: _addSkill,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Add a skill',
                        hintText: 'e.g. Python, SQL, Figma',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        _addSkill(value);
                        onFieldSubmitted();
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final scheme = Theme.of(context).colorScheme;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: scheme.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220, minWidth: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: scheme.outline),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_skills.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in _skills)
                        InputChip(
                          key: ValueKey(skill),
                          label: Text(skill),
                          onDeleted: () => _removeSkill(skill),
                        ).animate().fadeIn(duration: AppMotion.fast).scaleXY(
                              begin: 0.85,
                              end: 1.0,
                              duration: AppMotion.fast,
                              curve: AppMotion.settle,
                            ),
                    ],
                  ),
                const SizedBox(height: 28),

                Text('A bit more context', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text('Optional, but sharpens the match reasoning.', style: text.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _headlineController,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    hintText: 'e.g. Backend developer, 3 yrs, fintech',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Years of experience'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _educationController,
                  decoration: const InputDecoration(
                    labelText: 'Education',
                    hintText: 'e.g. BSc in CSE',
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('See my matches'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
