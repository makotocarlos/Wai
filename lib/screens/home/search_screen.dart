import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
	const SearchScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						'Explorar',
						style: Theme.of(context).textTheme.headlineSmall?.copyWith(
							fontWeight: FontWeight.w700,
						),
					),
					const SizedBox(height: 16),
					TextField(
						decoration: InputDecoration(
							hintText: 'Busca por titulo, autor o categoria',
							prefixIcon: const Icon(Icons.search_rounded),
							border: OutlineInputBorder(
								borderRadius: BorderRadius.circular(20),
							),
						),
					),
					const SizedBox(height: 24),
					Expanded(
						child: Center(
							child: Text(
								'La busqueda inteligente llegara pronto.',
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.bodyLarge,
							),
						),
					),
				],
			),
		);
	}
}
