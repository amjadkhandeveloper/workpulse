import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(liveUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyView(message: '$e'),
      data: (rows) {
        final points = rows
            .where((r) => r['last_lat'] != null && r['last_lng'] != null)
            .toList();
        final center = points.isEmpty
            ? const LatLng(12.9716, 77.5946)
            : LatLng(
                (points.first['last_lat'] as num).toDouble(),
                (points.first['last_lng'] as num).toDouble(),
              );
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.workpulse.work_pulse',
                ),
                MarkerLayer(
                  markers: points
                      .map(
                        (row) => Marker(
                          point: LatLng(
                            (row['last_lat'] as num).toDouble(),
                            (row['last_lng'] as num).toDouble(),
                          ),
                          width: 120,
                          height: 64,
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: row['standby_status'] == 'in'
                                    ? AppColors.success
                                    : AppColors.primary,
                                size: 32,
                              ),
                              Text(
                                '${row['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                onPressed: () => ref.invalidate(liveUsersProvider),
                child: const Icon(Icons.refresh, color: AppColors.primary),
              ),
            ),
            if (points.isEmpty)
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No live locations yet. Users appear after Standby In or accepting a job.'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
