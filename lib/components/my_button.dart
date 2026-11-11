// lib/components/my_button.dart (Updated to accept a child widget)

import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onTap;

  const MyButton({
    super.key,
    this.text,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: child ?? // যদি child দেওয়া হয়, তবে child দেখাবে
              Text(
                text ?? "", // নাহলে text দেখাবে
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        ),
      ),
    );
  }
}