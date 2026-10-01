import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study_pins/data/pin_categories_providers.dart';
import '../data/review_session_providers.dart';
import '../domain/review_models.dart';
import 'review_session_screen.dart';

/// Lightweight filters before starting a review queue.
class ReviewSetupScreen extends ConsumerStatefulWidget {
  const ReviewSetupScreen({
    super.key,
    required this.scope,
    this.initialFilters = const ReviewSessionFilters(),
  });

  final ReviewScope scope;
  final ReviewSessionFilters initialFilters;

  static Future<void> open(
    BuildContext context, {
    required ReviewScope scope,
    ReviewSessionFilters initialFilters = const ReviewSessionFilters(),
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReviewSetupScreen(scope: scope, initialFilters: initialFilters),
      ),
    );
  }

  @override
  ConsumerState<ReviewSetupScreen> createState() => _ReviewSetupScreenState();
}

class _ReviewSetupScreenState extends ConsumerState<ReviewSetupScreen> {
  late ReviewSessionFilters _filters;
  Set<String?> _selectedCategories = {};
  bool _categoriesInitialized = false;
  int? _availableCount;
  bool _counting = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  ReviewSessionFilters get _effectiveFilters => _filters.copyWith(
    categoryIds: _selectedCategories.isEmpty ? null : _selectedCategories,
  );

  Future<void> _refreshCount() async {
    setState(() => _counting = true);
    final count = await ref
        .read(studyReviewServiceProvider)
        .countReviewable(
          scope: widget.scope,
          filters: _effectiveFilters.copyWith(shuffle: false),
        );
    if (!mounted) return;
    setState(() {
      _availableCount = count;
      _counting = false;
    });
  }

  Future<void> _start() async {
    final session = await ref
        .read(activeReviewSessionProvider.notifier)
        .start(scope: widget.scope, filters: _effectiveFilters);
    if (!mounted) return;
    if (session.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No annotations match these filters.')),
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ReviewSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(studyPinCategoriesProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    ref.listen(studyPinCategoriesProvider, (prev, next) {
      next.whenData((cats) {
        if (_categoriesInitialized) return;
        _categoriesInitialized = true;
        _selectedCategories = {null, ...cats.map((c) => c.id)};
        _refreshCount();
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text('Review: ${widget.scope.title}')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 640 : double.infinity),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              if (_counting)
                const LinearProgressIndicator()
              else
                Text(
                  '${_availableCount ?? '…'} annotations available',
                  style: theme.textTheme.titleMedium,
                ),
              const SizedBox(height: 24),
              Text('Categories', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load categories'),
                data: (cats) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('General'),
                      selected: _selectedCategories.contains(null),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories = {
                              ..._selectedCategories,
                              null,
                            };
                          } else {
                            _selectedCategories = {..._selectedCategories}
                              ..remove(null);
                          }
                        });
                        _refreshCount();
                      },
                    ),
                    for (final cat in cats)
                      FilterChip(
                        label: Text(cat.name),
                        selected: _selectedCategories.contains(cat.id),
                        avatar: CircleAvatar(
                          backgroundColor: Color(cat.colorValue),
                          radius: 6,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories = {
                                ..._selectedCategories,
                                cat.id,
                              };
                            } else {
                              _selectedCategories = {..._selectedCategories}
                                ..remove(cat.id);
                            }
                          });
                          _refreshCount();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Include', style: theme.textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Point annotations'),
                value: _filters.includePoint,
                onChanged: (v) {
                  setState(() => _filters = _filters.copyWith(includePoint: v));
                  _refreshCount();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Text annotations'),
                value: _filters.includeText,
                onChanged: (v) {
                  setState(() => _filters = _filters.copyWith(includeText: v));
                  _refreshCount();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favorites only'),
                value: _filters.favoritesOnly,
                onChanged: (v) {
                  setState(
                    () => _filters = _filters.copyWith(favoritesOnly: v),
                  );
                  _refreshCount();
                },
              ),
              const SizedBox(height: 16),
              Text('Order', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Original'),
                    icon: Icon(Icons.sort),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Shuffle'),
                    icon: Icon(Icons.shuffle),
                  ),
                ],
                selected: {_filters.shuffle},
                onSelectionChanged: (values) {
                  setState(
                    () => _filters = _filters.copyWith(shuffle: values.first),
                  );
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Start Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openReviewSetup(
  BuildContext context, {
  required ReviewScope scope,
  ReviewSessionFilters filters = const ReviewSessionFilters(),
}) {
  return ReviewSetupScreen.open(context, scope: scope, initialFilters: filters);
}
