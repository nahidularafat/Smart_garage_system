import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.light(
    surface: Colors.grey.shade300,       // Replaces background
    primary: const Color.fromARGB(255, 255, 254, 254),
    secondary: const Color.fromARGB(255, 250, 240, 240),
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade700,
  ),
);