import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country_names.dart';
import 'signature_tee_widgets.dart';
import 'signature_tees.dart';

/// "My tees" (M200): signature tees for every country visited, the most
/// recently discovered first. Tapping one opens its product page.
///
/// Opened only through `CommerceEntry.openMyTees`.
class MyTeesScreen extends ConsumerWidget {
  const MyTeesScreen({super.key, required this.onOpenTee});

  final void Function(BuildContext context, String countryCode) onOpenTee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tees = ref.watch(myTeesProvider);
    final catalogLoading = ref.watch(signatureCatalogProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My tees')),
      body: tees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load your tees.")),
        data: (codes) {
          if (codes.isEmpty) {
            if (catalogLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Every country you visit gets its own tees. '
                  'Scan your photos to find yours.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: codes.length,
            itemBuilder: (context, i) {
              final cc = codes[i];
              return Material(
                key: Key('my-tee-$cc'),
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpenTee(context, cc),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Expanded(child: SignatureTeeArt(countryCode: cc)),
                        const SizedBox(height: 8),
                        Text(
                          kCountryNames[cc] ?? cc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
