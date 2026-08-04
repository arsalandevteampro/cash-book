import 'dart:math';
import 'package:flutter/material.dart';

class PatternLockCanvas extends StatefulWidget {
  final int dimension; // Default 3 (for 3x3 grid = 9 dots)
  final ValueChanged<List<int>> onComplete;
  final bool isError;
  final bool isSuccess;

  const PatternLockCanvas({
    super.key,
    this.dimension = 3,
    required this.onComplete,
    this.isError = false,
    this.isSuccess = false,
  });

  @override
  State<PatternLockCanvas> createState() => _PatternLockCanvasState();
}

class _PatternLockCanvasState extends State<PatternLockCanvas> {
  final List<int> _selectedIndices = [];
  Offset? _currentDragPosition;

  Offset _getDotCenter(int index, Size size) {
    final row = index ~/ widget.dimension;
    final col = index % widget.dimension;
    final cellWidth = size.width / widget.dimension;
    final cellHeight = size.height / widget.dimension;

    return Offset(
      col * cellWidth + cellWidth / 2,
      row * cellHeight + cellHeight / 2,
    );
  }

  int? _getHitDotIndex(Offset localPosition, Size size) {
    final cellWidth = size.width / widget.dimension;
    final cellHeight = size.height / widget.dimension;
    final hitRadius = min(cellWidth, cellHeight) * 0.4;

    for (int i = 0; i < widget.dimension * widget.dimension; i++) {
      final center = _getDotCenter(i, size);
      if ((localPosition - center).distance <= hitRadius) {
        return i;
      }
    }
    return null;
  }

  void _handlePanStart(DragStartDetails details, RenderBox box) {
    final localPos = box.globalToLocal(details.globalPosition);
    final index = _getHitDotIndex(localPos, box.size);

    setState(() {
      _selectedIndices.clear();
      _currentDragPosition = localPos;
      if (index != null) {
        _selectedIndices.add(index);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, RenderBox box) {
    final localPos = box.globalToLocal(details.globalPosition);
    final index = _getHitDotIndex(localPos, box.size);

    setState(() {
      _currentDragPosition = localPos;
      if (index != null && !_selectedIndices.contains(index)) {
        _selectedIndices.add(index);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _currentDragPosition = null;
    });

    if (_selectedIndices.isNotEmpty) {
      widget.onComplete(List.from(_selectedIndices));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.isError
        ? Colors.red
        : widget.isSuccess
            ? Colors.green
            : theme.colorScheme.primary;

    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (details) {
              final box = context.findRenderObject() as RenderBox;
              _handlePanStart(details, box);
            },
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              _handlePanUpdate(details, box);
            },
            onPanEnd: _handlePanEnd,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PatternPainter(
                dimension: widget.dimension,
                selectedIndices: _selectedIndices,
                currentDragPos: _currentDragPosition,
                activeColor: primaryColor,
                dotColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final int dimension;
  final List<int> selectedIndices;
  final Offset? currentDragPos;
  final Color activeColor;
  final Color dotColor;

  _PatternPainter({
    required this.dimension,
    required this.selectedIndices,
    required this.currentDragPos,
    required this.activeColor,
    required this.dotColor,
  });

  Offset _getDotCenter(int index, Size size) {
    final row = index ~/ dimension;
    final col = index % dimension;
    final cellWidth = size.width / dimension;
    final cellHeight = size.height / dimension;

    return Offset(
      col * cellWidth + cellWidth / 2,
      row * cellHeight + cellHeight / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dotRadius = min(size.width, size.height) / (dimension * 7);
    final activeDotRadius = dotRadius * 1.8;

    // Draw Lines
    if (selectedIndices.isNotEmpty) {
      final linePaint = Paint()
        ..color = activeColor.withValues(alpha: 0.8)
        ..strokeWidth = dotRadius * 0.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final startCenter = _getDotCenter(selectedIndices.first, size);
      path.moveTo(startCenter.dx, startCenter.dy);

      for (int i = 1; i < selectedIndices.length; i++) {
        final center = _getDotCenter(selectedIndices[i], size);
        path.lineTo(center.dx, center.dy);
      }

      if (currentDragPos != null) {
        path.lineTo(currentDragPos!.dx, currentDragPos!.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw Dots
    for (int i = 0; i < dimension * dimension; i++) {
      final center = _getDotCenter(i, size);
      final isSelected = selectedIndices.contains(i);

      if (isSelected) {
        // Outer glow circle
        final outerPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, activeDotRadius * 1.5, outerPaint);

        // Active dot
        final activePaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, activeDotRadius, activePaint);
      } else {
        // Inactive dot
        final inactivePaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, dotRadius, inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedIndices != selectedIndices ||
        oldDelegate.currentDragPos != currentDragPos ||
        oldDelegate.activeColor != activeColor;
  }
}
