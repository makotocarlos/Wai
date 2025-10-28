import 'package:flutter/material.dart';

import '../../features/books/presentation/pages/create_book_page.dart';

class WriteScreen extends StatelessWidget {
  const WriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu zona de escritura',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Organiza ideas, crea nuevos capítulos y comparte tus historias con la comunidad.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _CreateBookCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateBookPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Consejos rápidos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const _WriteTip(
                icon: Icons.bolt,
                title: 'Piensa en la sinopsis',
                message:
                    'Resume tu historia en pocas líneas antes de empezar. Esto te ayudará a estructurar los capítulos.',
              ),
              const _WriteTip(
                icon: Icons.group,
                title: 'Habla con tus lectores',
                message:
                    'Publica un adelanto, escucha sus comentarios y mejora cada capítulo antes de lanzarlo.',
              ),
              const _WriteTip(
                icon: Icons.layers,
                title: 'Construye capítulo a capítulo',
                message:
                    'Puedes regresar y editar cualquier capítulo cuando quieras. Guarda borradores para no perder ideas.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateBookCard extends StatelessWidget {
  const _CreateBookCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF262B40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note, color: Colors.greenAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Escribir nuevo libro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Define la categoría, sube tu portada y crea capítulos paso a paso.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }
}

class _WriteTip extends StatelessWidget {
  const _WriteTip({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.greenAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
