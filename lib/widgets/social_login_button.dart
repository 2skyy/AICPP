import 'package:flutter/material.dart';
import '../theme/toss_colors.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.backgroundColor,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final Color backgroundColor;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: TossColors.fieldFill),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
