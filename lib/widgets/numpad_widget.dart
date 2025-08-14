import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NumpadWidget extends StatelessWidget {
  final Function(String)? onNumberPressed;

  const NumpadWidget({
    super.key,
    this.onNumberPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: 1, 2, 3, +10
          Row(
            children: [
              _buildNumButton('1'),
              _buildNumButton('2'),
              _buildNumButton('3'),
              _buildActionButton('+10', AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 4),
          
          // Row 2: 4, 5, 6, +20
          Row(
            children: [
              _buildNumButton('4'),
              _buildNumButton('5'),
              _buildNumButton('6'),
              _buildActionButton('+20', AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 4),
          
          // Row 3: 7, 8, 9, +50
          Row(
            children: [
              _buildNumButton('7'),
              _buildNumButton('8'),
              _buildNumButton('9'),
              _buildActionButton('+50', AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 4),
          
          // Row 4: +/-, 0, ., -20
          Row(
            children: [
              _buildActionButton('+/-', AppTheme.secondaryColor),
              _buildNumButton('0'),
              _buildNumButton('.'),
              _buildActionButton('-20', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumButton(String text) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 50,
        child: ElevatedButton(
          onPressed: () => onNumberPressed?.call(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.blackColor,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 50,
        child: ElevatedButton(
          onPressed: () => onNumberPressed?.call(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
