import 'package:flutter/material.dart';

import '../models/user_model.dart';

class LeaderboardCard extends StatelessWidget {
  final int rank;
  final VolunteerUser user;
  final bool highlight;

  const LeaderboardCard({super.key, required this.rank, required this.user, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? Colors.green.shade100 : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text(rank.toString())),
        title: Text(user.name),
        subtitle: Text('${user.points} points • ${user.city}'),
        trailing: Wrap(
          spacing: 4,
          children: user.badges.take(3).map((badge) => Chip(label: Text(badge), visualDensity: VisualDensity.compact)).toList(),
        ),
      ),
    );
  }
}
