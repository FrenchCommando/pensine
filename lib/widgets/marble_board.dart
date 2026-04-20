import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/board.dart';
import '../theme.dart';

/// When true, the marble physics ticker early-returns. Screenshot tests
/// toggle this so the captured frame is stable and `binding.takeScreenshot`
/// isn't blocked waiting for idle (the ticker calls setState every frame).
bool debugPauseMarblePhysics = false;

class Marble {
  final BoardItem item;
  Color color;
  double baseRadius;
  double radius;
  double x, y;
  double vx, vy;
  bool flipped;
  bool expanded = false;
  double scale = 1.0;
  double expandScale = 1.0;
  bool dying = false;

  // Cached font-fit result so the paint loop doesn't re-lay 10 TextPainters
  // per marble per frame. Invalidated when radius or display text change.
  double? _fitRadius;
  String? _fitText;
  double? _fitFontSize;

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

  double fitFontSize(String text, double forRadius, double Function() recompute) {
    if (_fitFontSize == null ||
        _fitText != text ||
        _fitRadius != forRadius) {
      _fitFontSize = recompute();
      _fitRadius = forRadius;
      _fitText = text;
    }
    return _fitFontSize!;
  }
}

class MarbleBoard extends StatefulWidget {
  final List<BoardItem> items;
  final BoardType boardType;
  final VoidCallback onChanged;
  final void Function(BoardItem) onRemove;
  final void Function(BoardItem) onTap;
  final void Function(BoardItem)? onLongPress;
  final VoidCallback? onLongPressEmpty;
  final Color? accentColor;

  const MarbleBoard({
    super.key,
    required this.items,
    required this.boardType,
    required this.onChanged,
    required this.onRemove,
    required this.onTap,
    this.onLongPress,
    this.onLongPressEmpty,
    this.accentColor,
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
    _ensureTickerRunning();
  }

  void resetSizes() {
    setState(() {
      for (final m in _marbles) {
        m.baseRadius = minRadius + _random.nextDouble() * (maxRadius - minRadius);
        m.radius = m.baseRadius * m.item.sizeMultiplier;
      }
    });
    _ensureTickerRunning();
  }

  void _ensureTickerRunning() {
    if (!_ticker.isActive) _ticker.start();
  }

  /// True when no marble is moving, scaling, expanding, or dying, and no drag
  /// is in progress. Lets `_tick` stop the Ticker so `hasScheduledFrame` goes
  /// false — unblocks `pumpAndSettle` once caught marbles converge to the net.
  bool _isIdle() {
    if (_dragIndex != null) return false;
    if (_marbles.isEmpty) return true;

    final hasNet = widget.boardType.hasNet;
    final isSequential = widget.boardType.isSequential;
    String? activeSeqId;
    var hasActiveSeq = false;
    if (isSequential) {
      for (final i in widget.items) {
        if (!i.done) {
          activeSeqId = i.id;
          hasActiveSeq = true;
          break;
        }
      }
    }

    for (final m in _marbles) {
      if (m.dying) return false;
      if (m.vx != 0 || m.vy != 0) return false;

      final scaleTarget = (hasNet && m.item.done) ? caughtScale : 1.0;
      if ((m.scale - scaleTarget).abs() > 0.005) return false;

      final isActiveChecklist =
          hasActiveSeq && !m.item.done && m.item.id == activeSeqId;
      final isFlashcardFlipped = widget.boardType == BoardType.flashcards &&
          m.flipped &&
          m.item.description != null;
      final shouldExpand = m.expanded || isActiveChecklist || isFlashcardFlipped;
      final maxExpand = (_size.shortestSide * 0.45) / (m.radius * m.scale);
      final expandTarget = shouldExpand ? maxExpand.clamp(1.0, 4.0) : 1.0;
      if ((m.expandScale - expandTarget).abs() > 0.005) return false;
    }
    return true;
  }
  Size _size = Size.zero;
  int _tickCount = 0;

  static const double damping = 0.95;
  static const double friction = 0.999;
  static const double caughtScale = 0.45;
  double get minRadius => _size.shortestSide * 0.1;
  double get maxRadius => _size.shortestSide * 0.14;

  int? _dragIndex;

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
        final maxR = _size.shortestSide * 0.4;
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
      marble.radius = (marble.baseRadius * marble.item.sizeMultiplier).clamp(0.0, _size.shortestSide * 0.4);
    }
    final currentIds = widget.items.map((i) => i.id).toSet();
    for (final m in _marbles) {
      if (!currentIds.contains(m.item.id)) {
        m.dying = true;
      }
    }
    // Parent rebuilds land here — items added/removed or `done` toggled
    // (which moves the scale target). Wake the Ticker to resolve those.
    _ensureTickerRunning();
  }

  void _tick(Duration elapsed) {
    if (debugPauseMarblePhysics) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (_size == Size.zero) return;

    const dt = 1.0 / 60.0;
    final w = _size.width;
    final h = _size.height;
    final isSequential = widget.boardType.isSequential;
    final hasNet = widget.boardType.hasNet;
    final activeSequentialId = isSequential
        ? widget.items.firstWhere((i) => !i.done, orElse: () => widget.items.first).id
        : null;
    final hasActiveSequential = isSequential && widget.items.any((i) => !i.done);

    for (var i = 0; i < _marbles.length; i++) {
      final m = _marbles[i];
      if (i == _dragIndex) continue;

      if (m.dying) {
        m.scale *= 0.94;
        if (m.scale < 0.01) continue;
      }

      final isCaught = hasNet && m.item.done;

      if (!m.dying) {
        final targetScale = isCaught ? caughtScale : 1.0;
        m.scale += (targetScale - m.scale) * 0.08;
      }

      final isActiveChecklist = hasActiveSequential &&
          !m.item.done &&
          m.item.id == activeSequentialId;
      final isFlashcardFlipped = widget.boardType == BoardType.flashcards &&
          m.flipped &&
          m.item.description != null;

      final maxExpand = (_size.shortestSide * 0.45) / (m.radius * m.scale);
      final shouldExpand = m.expanded || isActiveChecklist || isFlashcardFlipped;
      final targetExpand = shouldExpand ? maxExpand.clamp(1.0, 4.0) : 1.0;
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

      // Deadband — once friction + damping bring a marble below a pixel/s,
      // snap to zero so `_isIdle` can detect rest. Without this, exponential
      // friction asymptotes and `pumpAndSettle` never unblocks.
      if (m.vx.abs() < 1 && m.vy.abs() < 1) {
        m.vx = 0;
        m.vy = 0;
      }
    }

    if (_marbles.any((m) => m.dying)) {
      _marbles.removeWhere((m) => m.dying && m.scale < 0.01);
    }

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

    _tickCount++;
    if (_isIdle()) _ticker.stop();
    setState(() {});
  }

  int? _hitTest(Offset pos) {
    for (var i = _marbles.length - 1; i >= 0; i--) {
      final m = _marbles[i];
      if (m.dying) continue;
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
            if (_dragIndex != null) _ensureTickerRunning();
          },
          onPanUpdate: (details) {
            if (_dragIndex != null && _dragIndex! < _marbles.length) {
              final m = _marbles[_dragIndex!];
              m.x = details.localPosition.dx;
              m.y = details.localPosition.dy;
              m.vx = 0;
              m.vy = 0;
              _ensureTickerRunning();
            }
          },
          onPanEnd: (details) {
            if (_dragIndex != null && _dragIndex! < _marbles.length) {
              final m = _marbles[_dragIndex!];
              m.vx = details.velocity.pixelsPerSecond.dx * 0.3;
              m.vy = details.velocity.pixelsPerSecond.dy * 0.3;
            }
            _dragIndex = null;
            _ensureTickerRunning();
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
                _ensureTickerRunning();
              } else if (widget.boardType == BoardType.flashcards) {
                if (marble.flipped) {
                  // Tap flipped card = wrong, flip back and grow slightly
                  setState(() {
                    marble.flipped = false;
                    final maxInflated = _size.shortestSide * 0.4 / marble.item.sizeMultiplier;
                    marble.baseRadius = (marble.baseRadius * 1.15).clamp(minRadius, maxInflated);
                    marble.radius = (marble.baseRadius * marble.item.sizeMultiplier).clamp(0.0, _size.shortestSide * 0.4);
                  });
                  _ensureTickerRunning();
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
              _ensureTickerRunning();
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
                  _ensureTickerRunning();
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
          child: Semantics(
            label: '${widget.boardType.name} board with ${widget.items.length} items',
            child: CustomPaint(
              size: Size.infinite,
              painter: _MarblePainter(
                marbles: _marbles,
                boardType: widget.boardType,
                netX: _netX,
                netY: _netY,
                netSize: _netSize,
                brightness: Theme.of(context).brightness,
                itemOrder: widget.items.map((i) => i.id).toList(),
                accentColor: widget.accentColor,
                tick: _tickCount,
              ),
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
  final List<String> itemOrder;
  final Color? accentColor;
  final int tick;

  _MarblePainter({
    required this.marbles,
    required this.boardType,
    required this.netX,
    required this.netY,
    required this.netSize,
    required this.brightness,
    required this.itemOrder,
    required this.tick,
    this.accentColor,
  });

  Color get _overlayColor => accentColor ?? (brightness == Brightness.dark ? Colors.white : Colors.black);

  @override
  void paint(Canvas canvas, Size size) {
    final isSequential = boardType.isSequential;
    String? activeSequentialId;
    if (isSequential) {
      for (final m in marbles) {
        if (!m.item.done) {
          activeSequentialId = m.item.id;
          break;
        }
      }
    }
    final alphaWhenDone =
        (boardType == BoardType.todo || isSequential) ? 0.7 : 1.0;

    if (boardType.hasNet) {
      _drawNet(canvas, size);
    }

    for (final m in marbles) {
      final isDone = m.item.done;
      final isFlipped = boardType == BoardType.flashcards && m.flipped;
      final r = m.drawRadius;

      final drawColor = m.color;
      final alpha = isDone ? alphaWhenDone : 1.0;

      final isActiveChecklist =
          activeSequentialId != null && !isDone && m.item.id == activeSequentialId;

      final glowPaint = Paint()
        ..color = drawColor.withValues(alpha: isActiveChecklist ? 0.4 : 0.15 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isActiveChecklist ? 24 : (isFlipped ? 18 : 12));
      canvas.drawCircle(Offset(m.x, m.y), r + (isActiveChecklist ? 8 : 4), glowPaint);

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

      final isFlashcardFlipped = boardType == BoardType.flashcards &&
          m.flipped &&
          m.item.description != null;
      final isExpanded = (m.expanded || isActiveChecklist || isFlashcardFlipped) &&
          m.expandScale > 1.5;

      if (isExpanded && m.item.description != null) {
        // Expanded: show title + description
        final maxWidth = r * 1.5;
        final titleStyle = TextStyle(
          color: Colors.white,
          fontSize: r * 0.2,
          fontWeight: FontWeight.w800,
        );
        final descStyle = TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: r * 0.13,
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
        final maxWidth = r * 1.4;
        final isSingleWord = !displayText.contains(' ');
        // Fit at the static radius (baseRadius * sizeMultiplier) so scale and
        // expand animations don't invalidate the cache every frame. The fit
        // problem is homogeneous in r, so we rescale the result to drawRadius.
        final baseR = m.radius;
        final baseFontSize = m.fitFontSize(displayText, baseR, () {
          final baseMaxW = baseR * 1.4;
          final baseMaxH = baseR * 1.4;
          var size = baseR * 0.28;
          for (var i = 0; i < 10; i++) {
            final painter = TextPainter(
              text: TextSpan(
                text: displayText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                ),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLines: isSingleWord ? 1 : 3,
            );
            painter.layout(maxWidth: baseMaxW);
            if (painter.height <= baseMaxH && !painter.didExceedMaxLines) return size;
            size *= 0.85;
          }
          return size;
        });
        final fontSize = baseR > 0 ? baseFontSize * (r / baseR) : baseFontSize;
        final textPainter = TextPainter(
          text: TextSpan(
            text: displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: isSingleWord ? 1 : 3,
        );
        textPainter.layout(maxWidth: maxWidth);
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

      if (isSequential) {
        final stepIndex = itemOrder.indexOf(m.item.id);
        if (stepIndex >= 0) {
          final stepPainter = TextPainter(
            text: TextSpan(
              text: '${stepIndex + 1}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: isDone ? 0.4 : 0.7),
                fontSize: r * 0.25,
                fontWeight: FontWeight.w900,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          stepPainter.layout();
          stepPainter.paint(
            canvas,
            Offset(m.x - stepPainter.width / 2, m.y + r * 0.5),
          );
        }
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
  bool shouldRepaint(covariant _MarblePainter oldDelegate) => oldDelegate.tick != tick;
}
