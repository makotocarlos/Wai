import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubtitleText extends StatelessWidget {
  final String text;
  final TextAlign align;

  const SubtitleText(this.text, {super.key, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.playfairDisplay(
        color: Colors.white70,
        fontSize: 27,   // 🔥 un poquito más grande
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
