import 'package:flutter/material.dart';

class ResponsiveScaffoldBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveScaffoldBody({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= 800;

        return Row(
          children: [
            if (isLarge) const SizedBox(width: 250), // drawer placeholder
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
