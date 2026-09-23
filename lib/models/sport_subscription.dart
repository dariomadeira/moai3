import 'package:flutter/material.dart';

/// Representa una suscripción a un deporte o competición en Moai TV.
class SportSubscription {
  final String id;
  final String name;
  final String sport;
  final String? description;
  final IconData icon;
  final bool isSubscribed;

  const SportSubscription({
    required this.id,
    required this.name,
    required this.sport,
    this.description,
    required this.icon,
    this.isSubscribed = false,
  });

  SportSubscription copyWith({
    String? id,
    String? name,
    String? sport,
    String? description,
    IconData? icon,
    bool? isSubscribed,
  }) {
    return SportSubscription(
      id: id ?? this.id,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SportSubscription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
