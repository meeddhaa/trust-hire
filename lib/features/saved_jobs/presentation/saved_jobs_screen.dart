import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/main_shell.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/saved_job.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../listing_detail/providers/listing_detail_providers.dart';
import '../providers/saved_jobs_providers.dart';

class SavedJobsScreen extends ConsumerWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedJobsStreamProvider);

    return Scaffold(
      appBar: AppBar(leading: buildDrawerButton(context), title: const Text('Saved')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load saved jobs",
          message: error.toString(),
        ),
        data: (saved) {
          if (saved.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No saved jobs yet',
              message: 'Tap the bookmark on a listing to save it here for later.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _SavedJobTile(savedJob: saved[index]),
          );
        },
      ),
    );
  }
}

class _SavedJobTile extends ConsumerWidget {
  const _SavedJobTile({required this.savedJob});

  final SavedJob savedJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingByIdProvider(savedJob.listingId));
    final uid = ref.read(currentUidProvider);

    return Card(
      child: ListTile(
        title: listingAsync.when(
          data: (listing) => Text(listing?.title ?? 'Listing no longer available'),
          loading: () => const Text('Loading…'),
          error: (_, _) => const Text('Listing no longer available'),
        ),
        subtitle: listingAsync.value?.company != null ? Text(listingAsync.value!.company) : null,
        trailing: IconButton(
          icon: const Icon(Icons.bookmark),
          color: Theme.of(context).colorScheme.primary,
          tooltip: 'Remove from saved',
          onPressed: uid == null
              ? null
              : () => ref.read(savedJobRepositoryProvider).unsave(uid: uid, listingId: savedJob.listingId),
        ),
        onTap: () => context.push('/listings/${savedJob.listingId}'),
      ),
    );
  }
}
