import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/board.dart';
import '../theme.dart';

class Marble {
  final BoardItem item;
  Color color;
  double baseRadius;
  double radius;
  double x, y;
  double vx, vy;
  bool flipped; // for flashcards
  bool expanded = false; // for thoughts
  double scale = 1.0; // for shrinking into net
  double expandScale = 1.0; // animated expand factor

  Marble({
    required this.item,
    required this.color,
    required this.baseRadius,
    required this.radius,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.flipped = false,
    this.scale = 1.0,
  });

  double get drawRadius => radius * scale * expandScale;
}

class MarbleBoard extends StatefulWidget {
  final List<BoardItem> items;
  final BoardType boardType;
  final VoidCallback onChanged;
  final void Function(BoardItem) onRemove;
  final void Function(BoardItem) onTap;
  final void Function(BoardItem)? onLongPress;
  final VoidCallback? onLongPressEmpty;

  const MarbleBoard({
    super.key,
    required this.items,
    required this.boardType,
    required this.onChanged,
    required this.onRemove,
    required this.onTap,
    this.onLongPress,
    this.onLongPressEmpty,
  });

  @override
  State<MarbleBoard> createState() => MarbleBoardState();
}

class MarbleBoardState extends State<MarbleBoard>
    with SingleTickerProviderStateMixin {
  final List<Marble> _marbles = [];
  List<Marble> get marbles => _marbles;
  late Ticker _ticker;
  final _random = Random();

  void flipAll(bool flipped) {
    setState(() {
      for (final m in _marbles) {
        m.flipped = flipped;
      }
    });
  }

  void shake() {
    setState(() {
      for (final m in _marbles) {
        m.vx += (_random.nextDouble() - 0.5) * 600;
        m.vy += (_random.nextDouble() - 0.5) * 600;
      }
    });
  }

  void resetSizes() {
    setState(() {
      for (final m in _marbles) {
        m.baseRadius = minRadius + _random.nextDouble() * (maxRadius - minRadius);
        m.radius = m.baseRadius * m.item.sizeMultiplier;
      }
    });
  }
  Size _size = Size.zero;

  // Physics constants
  static const double damping = 0.95;
  static const double friction = 0.999;
  double get minRadius => _size.shortestSide * 0.1;
  double get maxRadius => _size.shortestSide * 0.14;
  static const double caughtScale = 0.45;

  // Dragging
  int? _dragIndex;

  // Net position (bottom-right)
  double get _netSize => _size.shortestSide * 0.28;
  double get _netX => _netSize * 0.8;
  double get _netY => _size.height - _netSize * 0.8;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MarbleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMarbles();
  }

  void _syncMarbles() {
    final existingIds = _marbles.map((m) => m.item.id).toSet();
    for (final item in widget.items) {
      if (!existingIds.contains(item.id)) {
        final color =
            PensineColors.bubbles[item.colorIndex % PensineColors.bubbles.length];
        final baseRadius = minRadius + _random.nextDouble() * (maxRadius - minRadius);
        final maxR = _size.width * 0.4;
        final radius = (baseRadius * item.sizeMultiplier).clamp(0.0, maxR);
        _marbles.add(Marble(
          item: item,
          color: color,
          baseRadius: baseRadius,
          radius: radius,
          x: _size.width > 0
              ? radius + _random.nextDouble() * (_size.width - radius * 2)
              : 100 + _random.nextDouble() * 200,
          y: -radius * 2,
          vx: (_random.nextDouble() - 0.5) * 80,
          vy: (_random.nextDouble() - 0.5) * 80,
          scale: item.done ? caughtScale : 1.0,
        ));
      }
    }
    // Update existing marbles (color/size may have changed)
    for (final marble in _marbles) {
      marble.color =
          PensineColors.bubbles[marble.item.colorIndex % PensineColors.bubbles.length];
      marble.radius = (marble.baseRadius * marble.item.sizeMultiplier).clamp(0.0, _size.width * 0.4);
    }
    final currentIds = widget.items.map((i) => i.id).toSet();
    _marbles.removeWhere((m) => !currentIds.contains(m.item.id));
  }

  void _tick(Duration elapsed) {
    if (_size == Size.zero) return;

    const dt = 1.0 / 60.0;
    final w = _size.width;
    final h = _size.height;

    for (var i = 0; i < _marbles.length; i++) {
      final m = _marbles[i];
      if (i == _dragIndex) continue;

      final isCaught = (widget.boardType == BoardType.todo || widget.boardType == BoardType.flashcards) && m.item.done;

      // Animate scale
      final targetScale = isCaught ? caughtScale : 1.0;
      m.scale += (targetScale - m.scale) * 0.08;

      // Animate expand
      final targetExpand = m.expanded ? 4.0 : 1.0;
      m.expandScale += (targetExpand - m.expandScale) * 0.1;

      if (isCaught) {
        // Attract toward net
        final dx = _netX - m.x;
        final dy = _netY - m.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 5) {
          m.vx += dx / dist * 400 * dt;
          m.vy += dy / dist * 400 * dt;
        }
        // Extra damping when caught
        m.vx *= 0.96;
        m.vy *= 0.96;
      }

      m.vx *= friction;
      m.vy *= friction;
      m.x += m.vx * dt;
      m.y += m.vy * dt;

      final r = m.drawRadius;
      if (m.x - r < 0) {
        m.x = r;
        m.vx = m.vx.abs() * damping;
      }
      if (m.x + r > w) {
        m.x = w - r;
        m.vx = -m.vx.abs() * damping;
      }
      if (m.y + r > h) {
        m.y = h - r;
        m.vy = -m.vy.abs() * damping;
      }
      if (m.y - r < 0) {
        m.y = r;
        m.vy = m.vy.abs() * damping;
      }

      // Gentle random drift for free marbles
      if (!isCaught) {
        final speed = sqrt(m.vx * m.vx + m.vy * m.vy);
        if (speed < 30) {
          m.vx += (_random.nextDouble() - 0.5) * 40;
          m.vy += (_random.nextDouble() - 0.5) * 40;
        }
      }
    }

    // Marble-to-marble collisions
    for (var i = 0; i < _marbles.length; i++) {
      for (var j = i + 1; j < _marbles.length; j++) {
        final a = _marbles[i];
        final b = _marbles[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = a.drawRadius + b.drawRadius;

        if (dist < minDist && dist > 0) {
          final nx = dx / dist;
          final ny = dy / dist;
          final overlap = minDist - dist;

          if (i == _dragIndex) {
            b.x += nx * overlap;
            b.y += ny * overlap;
          } else if (j == _dragIndex) {
            a.x -= nx * overlap;
            a.y -= ny * overlap;
          } else {
            a.x -= nx * overlap * 0.5;
            a.y -= ny * overlap * 0.5;
            b.x += nx * overlap * 0.5;
            b.y += ny * overlap * 0.5;
          }

          if (i != _dragIndex && j != _dragIndex) {
            final dvx = a.vx - b.vx;
            final dvy = a.vy - b.vy;
            final dot = dvx * nx + dvy * ny;

            if (dot > 0) {
              a.vx -= dot * nx * damping;
              a.vy -= dot * ny * damping;
              b.vx += dot * nx * damping;
              b.vy += dot * ny * damping;
            }
          }
        }
      }
    }

    setState(() {});
  }

  int? _hitTest(Offset pos) {
    for (var i = _marbles.length - 1; i >= 0; i--) {
      final m = _marbles[i];
      final dx = pos.dx - m.x;
      final dy = pos.dy - m.y;
      if (dx * dx + dy * dy <= m.drawRadius * m.drawRadius) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_size == Size.zero && newSize != Size.zero) {
          _size = newSize;
          _syncMarbles();
        }
        _size = newSize;

        return GestureDetector(
          onPanStart: (details) {
            _dragIndex = _hitTest(details.localPosition);
          },
          onPanUpdate: (details) {
            if (_dragIndex != null && _dragIndex! < _marbles.length) {
              final m = _marbles[_dragIndex!];
              m.x = details.localPosition.dx;
              m.y = details.localPosition.dy;
              m.vx = 0;
              m.vy = 0;
            }
          },
          onPanEnd: (details) {
            if (_dragIndex != null && _dragIndex! < _marbles.length) {
              final m = _marbles[_dragIndex!];
              m.vx = details.velocity.pixelsPerSecond.dx * 0.3;
              m.vy = details.velocity.pixelsPerSecond.dy * 0.3;
            }
            _dragIndex = null;
          },
          onTapUp: (details) {
            final idx = _hitTest(details.localPosition);
            if (idx != null) {
              final marble = _marbles[idx];
              if (widget.boardType == BoardType.thoughts) {
                setState(() {
                  // Collapse any other expanded marble
                  for (final m in _marbles) {
                    if (m != marble) m.expanded = false;
                  }
                  marble.expanded = !marble.expanded;
                });
              } else if (widget.boardType == BoardType.flashcards) {
                if (marble.flipped) {
                  // Tap flipped card = wrong, flip back and grow slightly
                  setState(() {
                    marble.flipped = false;
                    final maxInflated = _size.width * 0.4 / marble.item.sizeMultiplier;
                    marble.baseRadius = (marble.baseRadius * 1.15).clamp(minRadius, maxInflated);
                    marble.radius = (marble.baseRadius * marble.item.sizeMultiplier).clamp(0.0, _size.width * 0.4);
                  });
                } else {
                  // Tap unflipped card = reveal
                  setState(() => marble.flipped = true);
                }
              } else {
                widget.onTap(marble.item);
              }
            } else if (widget.boardType == BoardType.thoughts) {
              // Tap empty space collapses any expanded marble
              setState(() {
                for (final m in _marbles) {
                  m.expanded = false;
                }
              });
            }
          },
          onDoubleTapDown: (details) {
            if (widget.boardType == BoardType.flashcards) {
              final idx = _hitTest(details.localPosition);
              if (idx != null) {
                final marble = _marbles[idx];
                if (!marble.item.done) {
                  // Double-tap = correct (works on either side)
                  setState(() {
                    marble.item.done = true;
                    marble.flipped = false;
                  });
                  widget.onChanged();
                }
              }
            }
          },
          onLongPressStart: (details) {
            final idx = _hitTest(details.localPosition);
            if (idx != null && widget.onLongPress != null) {
              widget.onLongPress!(_marbles[idx].item);
            } else if (idx == null && widget.onLongPressEmpty != null) {
              widget.onLongPressEmpty!();
            }
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _MarblePainter(
              marbles: _marbles,
              boardType: widget.boardType,
              netX: _netX,
              netY: _netY,
              netSize: _netSize,
              brightness: Theme.of(context).brightness,
            ),
          ),
        );
      },
    );
  }
}

class _MarblePainter extends CustomPainter {
  final List<Marble> marbles;
  final BoardType boardType;
  final double netX;
  final double netY;
  final double netSize;
  final Brightness brightness;

  _MarblePainter({
    required this.marbles,
    required this.boardType,
    required this.netX,
    required this.netY,
    required this.netSize,
    required this.brightness,
  });

  Color get _overlayColor => brightness == Brightness.dark ? Colors.white : Colors.black;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw net for to-do and flashcard boards
    if (boardType == BoardType.todo || boardType == BoardType.flashcards) {
      _drawNet(canvas, size);
    }

    for (final m in marbles) {
      final isDone = m.item.done;
      final isFlipped = boardType == BoardType.flashcards && m.flipped;
      final r = m.drawRadius;

      // Flipped flashcards shift the hue and brighten
      final drawColor = isFlipped
          ? m.color
          : m.color;

      final alpha = (boardType == BoardType.todo && isDone) ? 0.7 : 1.0;

      // Outer glow
      final glowPaint = Paint()
        ..color = drawColor.withValues(alpha: 0.15 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isFlipped ? 18 : 12);
      canvas.drawCircle(Offset(m.x, m.y), r + 4, glowPaint);

      // Main marble with gradient
      final gradient = isFlipped
          ? RadialGradient(
              center: const Alignment(0.3, 0.3),
              colors: [
                drawColor.withValues(alpha: 0.95),
                drawColor.withValues(alpha: 0.65),
                drawColor.withValues(alpha: 0.45),
              ],
              stops: const [0.0, 0.6, 1.0],
            )
          : RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                drawColor.withValues(alpha: 0.9 * alpha),
                drawColor.withValues(alpha: 0.5 * alpha),
                drawColor.withValues(alpha: 0.3 * alpha),
              ],
              stops: const [0.0, 0.7, 1.0],
            );
      final rect = Rect.fromCircle(center: Offset(m.x, m.y), radius: r);
      final marblePaint = Paint()..shader = gradient.createShader(rect);
      canvas.drawCircle(Offset(m.x, m.y), r, marblePaint);

      // Shine highlight
      final shinePaint = Paint()
        ..color = Colors.white.withValues(alpha: isFlipped ? 0.6 : 0.4 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(m.x - r * 0.25, m.y - r * 0.25),
        r * 0.2,
        shinePaint,
      );

      // Choose display text
      String displayText;
      if (boardType == BoardType.flashcards && m.flipped && m.item.backContent != null) {
        displayText = m.item.backContent!;
      } else {
        displayText = m.item.content;
      }

      final isExpanded = m.expanded && m.expandScale > 1.5;

      if (isExpanded && m.item.description != null) {
        // Expanded: show title + description
        final maxWidth = r * 1.4;
        final titleStyle = TextStyle(
          color: Colors.white,
          fontSize: r * 0.15,
          fontWeight: FontWeight.w800,
        );
        final descStyle = TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: r * 0.1,
          fontWeight: FontWeight.w500,
        );

        final titlePainter = TextPainter(
          text: TextSpan(text: displayText, style: titleStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '..',
        );
        titlePainter.layout(maxWidth: maxWidth);

        final descPainter = TextPainter(
          text: TextSpan(text: m.item.description!, style: descStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 6,
          ellipsis: '..',
        );
        descPainter.layout(maxWidth: maxWidth);

        final totalHeight = titlePainter.height + 8 + descPainter.height;
        final startY = m.y - totalHeight / 2;

        titlePainter.paint(
          canvas,
          Offset(m.x - titlePainter.width / 2, startY),
        );
        descPainter.paint(
          canvas,
          Offset(m.x - descPainter.width / 2, startY + titlePainter.height + 8),
        );
      } else {
        // Normal: show title only, shrink font to fit
        final maxWidth = r * 1.4;
        final maxHeight = r * 1.4;
        var fontSize = r * 0.28;

        late TextPainter textPainter;
        // Shrink font until text fits inside the marble
        for (var i = 0; i < 10; i++) {
          final style = TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          );
          textPainter = TextPainter(
            text: TextSpan(text: displayText, style: style),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 3,
          );
          textPainter.layout(maxWidth: maxWidth);
          if (textPainter.height <= maxHeight && !textPainter.didExceedMaxLines) break;
          fontSize *= 0.85;
        }
        textPainter.paint(
          canvas,
          Offset(m.x - textPainter.width / 2, m.y - textPainter.height / 2),
        );
      }

      // Arrow indicator for flashcards
      if (boardType == BoardType.flashcards && m.item.backContent != null) {
        final arrow = m.flipped ? '\u27F6' : '\u27F5'; // ⟶ or ⟵
        final arrowPainter = TextPainter(
          text: TextSpan(
            text: arrow,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: r * 0.4,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        arrowPainter.layout();
        arrowPainter.paint(
          canvas,
          Offset(m.x - arrowPainter.width / 2, m.y + r * 0.55),
        );
      }

    }
  }

  void _drawNet(Canvas canvas, Size size) {
    final netPaint = Paint()
      ..color = _overlayColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Net basket shape — curved lines forming a scoop
    final cx = netX;
    final cy = netY;

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), netSize * 0.6, netPaint);

    // Cross-hatch inside the circle
    for (var angle = 0.0; angle < pi; angle += pi / 6) {
      final dx = cos(angle) * netSize * 0.6;
      final dy = sin(angle) * netSize * 0.6;
      canvas.drawLine(
        Offset(cx - dx, cy - dy),
        Offset(cx + dx, cy + dy),
        netPaint,
      );
    }

    // Handle
    final handlePaint = Paint()
      ..color = _overlayColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - netSize * 0.35, cy - netSize * 0.35),
      Offset(cx - netSize * 0.75, cy - netSize * 0.75),
      handlePaint,
    );

    // Count caught items
    final caught = marbles.where((m) => m.item.done).length;
    if (caught > 0) {
      final countPainter = TextPainter(
        text: TextSpan(
          text: '$caught',
          style: TextStyle(
            color: _overlayColor.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      countPainter.layout();
      countPainter.paint(
        canvas,
        Offset(cx - countPainter.width / 2, cy + netSize * 0.6 + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarblePainter oldDelegate) => true;
}
