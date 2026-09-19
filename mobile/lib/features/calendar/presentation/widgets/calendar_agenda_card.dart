import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/loading_card.dart';
import '../calendar_controller.dart';

/// Dashboard card displaying today's Google Calendar agenda events.
class CalendarAgendaCard extends ConsumerWidget {
  const CalendarAgendaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarEventsAsync = ref.watch(calendarEventsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ChronologTheme.cyan950,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: ChronologTheme.cyan400,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Today's Agenda",
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  color: ChronologTheme.zinc400,
                  tooltip: 'Refresh calendar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.invalidate(calendarEventsProvider),
                ),
              ],
            ),
            const SizedBox(height: 14),

            calendarEventsAsync.when(
              loading: () => const LoadingCard(
                message: 'Loading calendar events...',
                height: 70,
              ),
              error: (err, _) => ErrorRetry(
                title: 'Could not load calendar events',
                message: err.toString(),
                onRetry: () => ref.invalidate(calendarEventsProvider),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: ChronologTheme.zinc950,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ChronologTheme.zinc800),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          color: ChronologTheme.zinc500,
                          size: 30,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No events today',
                          style: TextStyle(
                            color: ChronologTheme.zinc200,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your calendar is completely clear for the day.',
                          style: TextStyle(
                            color: ChronologTheme.zinc500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = events[index];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ChronologTheme.zinc950,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ChronologTheme.zinc800),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ChronologTheme.cyan950,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: ChronologTheme.cyan400.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  event.formattedTimeSpan,
                                  style: const TextStyle(
                                    color: ChronologTheme.cyan400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.title,
                            style: const TextStyle(
                              color: ChronologTheme.zinc200,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (event.location != null &&
                              event.location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: ChronologTheme.zinc500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ChronologTheme.zinc500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
