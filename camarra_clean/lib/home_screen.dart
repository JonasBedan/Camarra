import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String userName = 'Jonáš'; // zatím staticky

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camarra'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text(
              'Ready to level up today?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to mission screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mission not implemented yet!')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Start Mission'),
            ),

            const SizedBox(height: 32),

            // Optional placeholder for XP/stats
            const Text('⭐ XP: 1200  |  🧠 Level: 3'),
          ],
        ),
      ),
    );
  }
}
