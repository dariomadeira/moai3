import 'package:flutter/material.dart';

/// Semillas M3 para el color primario / de acento.
abstract final class MoaiAccentColors {
  static const List<Color> seeds = [
    Color(0xFF4A90D9), // Azul (default)
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Verde
    Color(0xFF10B981), // Esmeralda
    Color(0xFF00ACC1), // Cian
    Color(0xFFFB8C00), // Naranja
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFDD835), // Ámbar
    Color(0xFFE53935), // Rojo
    Color(0xFFE91E63), // Rosa
    Color(0xFF5C6BC0), // Índigo
    Color(0xFF8E24AA), // Violeta
  ];

  static const List<String> labelKeys = [
    'settings_accent_blue',
    'settings_accent_teal',
    'settings_accent_green',
    'settings_accent_emerald',
    'settings_accent_cyan',
    'settings_accent_orange',
    'settings_accent_coral',
    'settings_accent_amber',
    'settings_accent_red',
    'settings_accent_pink',
    'settings_accent_indigo',
    'settings_accent_violet',
  ];

  static int clampIndex(int index) => index.clamp(0, seeds.length - 1);

  static Color seedAt(int index) => seeds[clampIndex(index)];
}

