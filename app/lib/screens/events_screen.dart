import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Basit etkinlikler listesi (tab: Etkinlikler).
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [...MockData.events, ...MockData.events];
    return ListView(
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7, -1.1),
              radius: 1.2,
              colors: [AppColors.primary2, AppColors.primary],
              stops: [0.0, 0.55],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Etkinlikler',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Yakınındaki etkinlikleri keşfet',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...events.map((e) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: _eventRow(context, e),
            )),
      ],
    );
  }

  Widget _eventRow(BuildContext context, EventItem e) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(width: 110, height: 110, child: NetImage(e.image)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(e.tag,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(height: 6),
                  Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('${e.day} ${e.month} · ${e.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
