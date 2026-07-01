import 'package:flutter/material.dart';

class AgroFlowLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const AgroFlowLogo({
    Key? key,
    this.size = 80,
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00FF87), // Neon green/mint
              Color(0xFF60EFFF), // Neon cyan
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: (showShadow)
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FF87).withOpacity(0.35),
                    blurRadius: size * 0.25,
                    offset: Offset(0, size * 0.1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative thin inner white ring
            Container(
              width: size * 0.82,
              height: size * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
            ),
            // Outer glowing ring
            Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.0,
                ),
              ),
            ),
            // Middle plant icon representing growth
            Icon(
              Icons.eco_rounded,
              size: size * 0.45,
              color: Colors.white,
            ),
            // Small overlay representing smart system / data node
            Positioned(
              right: size * 0.28,
              top: size * 0.28,
              child: Container(
                width: size * 0.08,
                height: size * 0.08,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
