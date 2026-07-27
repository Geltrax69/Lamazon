import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Reusable loading state for any screen.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF1A1A1A)),
    );
  }
}

/// Reusable error state with retry for any screen.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView(
      {super.key, this.message = 'Something went wrong', required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.wifiOff, size: 44, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B6B6B))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
