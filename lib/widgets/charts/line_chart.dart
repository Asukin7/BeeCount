import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';

/// 折线图坐标计算结果，供 State 和 CrosshairPainter 共享
class _ChartLayout {
  final double dx;
  final List<Offset> allPoints;
  final List<Offset>? secondaryAllPoints;
  final double Function(double v) yFor;
  final double maxV;
  final double minV;

  const _ChartLayout({
    required this.dx,
    required this.allPoints,
    this.secondaryAllPoints,
    required this.yFor,
    required this.maxV,
    required this.minV,
  });

  /// 从图表参数计算布局
  static _ChartLayout? compute({
    required Size size,
    required List<double> values,
    required List<double>? secondaryValues,
    required double maxV,
    required double minV,
  }) {
    if (values.isEmpty) return null;

    const bottomPadding = 24.0;
    const topPadding = 16.0;
    const leftPadding = 24.0;
    final span = (maxV - minV).abs();

    double yFor(double v) {
      if (span == 0) return size.height / 2;
      final t = (v - minV) / span;
      return topPadding + (1 - t) * (size.height - topPadding - bottomPadding);
    }

    final dx = (size.width - leftPadding - 12) / (values.length - 1).clamp(1, 999);

    final allPoints = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      allPoints.add(Offset(leftPadding + i * dx, yFor(values[i])));
    }

    List<Offset>? secondaryAllPoints;
    if (secondaryValues != null && secondaryValues.isNotEmpty) {
      secondaryAllPoints = <Offset>[];
      for (int i = 0; i < secondaryValues.length; i++) {
        secondaryAllPoints.add(Offset(leftPadding + i * dx, yFor(secondaryValues[i])));
      }
    }

    return _ChartLayout(
      dx: dx,
      allPoints: allPoints,
      secondaryAllPoints: secondaryAllPoints,
      yFor: yFor,
      maxV: maxV,
      minV: minV,
    );
  }

  /// 根据触摸 X 坐标吸附到最近数据点索引
  int? snapToIndex(double touchX) {
    if (allPoints.isEmpty) return null;
    final rawIndex = ((touchX - leftPadding) / dx).round();
    return rawIndex.clamp(0, allPoints.length - 1);
  }

  static const topPadding = 12.0;
  static const bottomPadding = 16.0;
  static const leftPadding = 24.0;
}

class LineChart extends StatefulWidget {
  final List<double> values;
  final List<double>? secondaryValues; // 第二条线的数据（可选）
  final Color? secondaryColor; // 第二条线的颜色（可选）
  final List<String> xLabels;
  final int? highlightIndex;
  final VoidCallback onSwipeLeft; // 下一周期
  final VoidCallback onSwipeRight; // 上一周期
  final bool showHint;
  final String? hintText;
  final VoidCallback? onCloseHint;
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final bool hideAmounts; // 是否隐藏金额
  final Color themeColor;
  // 令牌化参数
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;
  final bool isDark; // 是否暗黑模式
  final bool isCurved; // 是否使用圆滑曲线

  const LineChart({
    super.key,
    required this.values,
    this.secondaryValues,
    this.secondaryColor,
    required this.xLabels,
    required this.highlightIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.showHint,
    this.hintText,
    this.onCloseHint,
    this.whiteBg = true,
    this.showGrid = true,
    this.showDots = true,
    this.annotate = true,
    this.hideAmounts = false,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
    this.isDark = false,
    this.isCurved = true,
  });

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = _computeLayout(size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: layout == null
              ? null
              : (details) {
                  setState(() {
                    _selectedIndex =
                        layout.snapToIndex(details.localPosition.dx);
                  });
                },
          onLongPressMoveUpdate: layout == null
              ? null
              : (details) {
                  final newIndex = layout.snapToIndex(details.localPosition.dx);
                  if (newIndex != _selectedIndex) {
                    setState(() {
                      _selectedIndex = newIndex;
                    });
                  }
                },
          onLongPressEnd: layout == null
              ? null
              : (details) {
                  // 检测快速水平滑动 → 切换周期
                  final v = details.velocity.pixelsPerSecond.dx;
                  if (v < -300) {
                    widget.onSwipeLeft();
                  } else if (v > 300) {
                    widget.onSwipeRight();
                  }
                  setState(() {
                    _selectedIndex = null;
                  });
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _LinePainter(
                  values: widget.values,
                  secondaryValues: widget.secondaryValues,
                  secondaryColor: widget.secondaryColor,
                  xLabels: widget.xLabels,
                  highlightIndex: widget.highlightIndex,
                  whiteBg: widget.whiteBg,
                  showGrid: widget.showGrid,
                  showDots: widget.showDots,
                  annotate: widget.annotate,
                  hideAmounts: widget.hideAmounts,
                  themeColor: widget.themeColor,
                  lineWidth: widget.lineWidth,
                  dotRadius: widget.dotRadius,
                  cornerRadius: widget.cornerRadius,
                  xLabelFontSize: widget.xLabelFontSize,
                  yLabelFontSize: widget.yLabelFontSize,
                  isDark: widget.isDark,
                  isCurved: widget.isCurved,
                  layout: layout, // 传入共享坐标布局
                ),
              ),
              // 十字线层
              if (_selectedIndex != null && layout != null)
                CustomPaint(
                  painter: _CrosshairPainter(
                    point: layout.allPoints[_selectedIndex!],
                    themeColor: widget.themeColor,
                    dotRadius: widget.dotRadius,
                    crosshairColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.4),
                    chartSize: size,
                  ),
                ),
              // 气泡层
              if (_selectedIndex != null && layout != null)
                _buildTooltip(layout, context),
              // 滑动提示
              if (widget.showHint)
                Positioned(
                  right: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BeeTokens.dividerStatic,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.swipe,
                              size: 14,
                              color: BeeTokens.textSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            widget.hintText ??
                                AppLocalizations.of(context).analyticsSwipeHint,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: BeeTokens.textSecondary(context)),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: widget.onCloseHint,
                            child: Icon(Icons.close,
                                size: 14,
                                color: BeeTokens.textTertiary(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  _ChartLayout? _computeLayout(Size size) {
    if (widget.values.isEmpty) return null;

    final allValues = <double>[...widget.values];
    if (widget.secondaryValues != null && widget.secondaryValues!.isNotEmpty) {
      allValues.addAll(widget.secondaryValues!);
    }
    final maxV = allValues.isEmpty ? 0.0 : allValues.reduce(math.max);
    final minV = allValues.isEmpty ? 0.0 : allValues.reduce(math.min);

    return _ChartLayout.compute(
      size: size,
      values: widget.values,
      secondaryValues: widget.secondaryValues,
      maxV: maxV,
      minV: minV,
    );
  }

  Widget _buildTooltip(_ChartLayout layout, BuildContext context) {
    final idx = _selectedIndex!;
    final point = layout.allPoints[idx];

    // X 轴标签（保护越界）
    final labelIdx = idx.clamp(0, widget.xLabels.length - 1);
    final xLabel = widget.xLabels.isNotEmpty ? widget.xLabels[labelIdx] : '';

    // 主线数值
    final primaryValue = widget.values[idx];
    final primaryText = widget.hideAmounts ? '**' : _fmt(primaryValue);

    // 副线数值（可选）
    final hasSecondary = widget.secondaryValues != null &&
        widget.secondaryValues!.isNotEmpty &&
        idx < widget.secondaryValues!.length;
    final secondaryText = hasSecondary && !widget.hideAmounts
        ? _fmt(widget.secondaryValues![idx])
        : (hasSecondary && widget.hideAmounts ? '**' : null);

    // 气泡背景色
    final bgColor = widget.isDark
        ? Colors.grey.withValues(alpha: 0.85)
        : Colors.white;
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
    final subTextColor =
        widget.isDark ? Colors.white70 : BeeTokens.secondaryTextStatic;

    final tooltipWidget = Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            xLabel,
            style: TextStyle(fontSize: 10, color: subTextColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            primaryText,
            style: TextStyle(
                fontSize: 10,
                color: widget.themeColor,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 2),
            Text(
              secondaryText,
              style: TextStyle(
                  fontSize: 10, color: widget.secondaryColor ?? Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    // 使用 CustomSingleChildLayout 定位气泡（自动填满 Stack 空间）
    return CustomSingleChildLayout(
      delegate: _TooltipPositionDelegate(
        anchorPoint: point,
      ),
      child: tooltipWidget,
    );
  }
}

/// 数值格式化（文件级共享）
String _fmt(double v) {
  if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? secondaryValues;
  final Color? secondaryColor;
  final List<String> xLabels;
  final int? highlightIndex;
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final bool hideAmounts;
  final Color themeColor;
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;
  final bool isDark;
  final bool isCurved;
  final _ChartLayout? layout;

  _LinePainter({
    required this.values,
    this.secondaryValues,
    this.secondaryColor,
    required this.xLabels,
    required this.highlightIndex,
    required this.whiteBg,
    required this.showGrid,
    required this.showDots,
    required this.annotate,
    required this.hideAmounts,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
    this.isDark = false,
    this.isCurved = true,
    this.layout,
  });

  // 获取主文字颜色（暗黑模式感知）
  Color get primaryTextColor =>
      isDark ? Colors.white : BeeTokens.primaryTextStatic;

  // 获取次要文字颜色（暗黑模式感知）
  Color get secondaryTextColor =>
      isDark ? Colors.white70 : BeeTokens.secondaryTextStatic;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..color = whiteBg ? Colors.white : BeeTokens.dividerStatic;
    // 步骤 1: 背景
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)), bgPaint);

    // 步骤 2: 网格（可选）
    if (showGrid) {
      final gridPaint = Paint()
        ..color = BeeTokens.dividerStatic
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      const rows = 4;
      for (int i = 1; i <= rows; i++) {
        final y = size.height * i / (rows + 1);
        canvas.drawLine(
            Offset(_ChartLayout.leftPadding, y),
            Offset(size.width - 8, y),
            gridPaint);
      }
    }

    if (values.isEmpty || layout == null) return;

    final yFor = layout!.yFor;
    final allPoints = layout!.allPoints;
    final secondaryAllPoints = layout!.secondaryAllPoints;

    // 计算主线非零值的平均值，用于平均线绘制
    final nonZeroVals = values.where((v) => v != 0).toList();
    final avgV = nonZeroVals.isEmpty
        ? 0.0
        : nonZeroVals.reduce((a, b) => a + b) / nonZeroVals.length;

    // 计算副线非零值的平均值
    final secondaryNonZeroVals = secondaryValues == null
        ? <double>[]
        : secondaryValues!.where((v) => v != 0).toList();
    final avgSecondaryV = secondaryNonZeroVals.isEmpty
        ? 0.0
        : secondaryNonZeroVals.reduce((a, b) => a + b) /
            secondaryNonZeroVals.length;

    // 收集非零点的索引
    final nzIndices = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] != 0) nzIndices.add(i);
    }

    final line = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true;

    // 步骤 3: 副线渐变面积（在主线之前绘制，副线在下层）
    Path? secondaryLinePath;
    List<int>? secondaryNzIndices;
    if (secondaryValues != null &&
        secondaryValues!.isNotEmpty &&
        secondaryColor != null &&
        secondaryAllPoints != null) {
      secondaryNzIndices = <int>[];
      for (int i = 0; i < secondaryValues!.length; i++) {
        if (secondaryValues![i] != 0) secondaryNzIndices.add(i);
      }
      if (secondaryAllPoints.length >= 2) {
        secondaryLinePath = _buildLinePath(secondaryAllPoints);
        _fillGradientArea(canvas, secondaryLinePath, secondaryAllPoints,
            size.height - _ChartLayout.bottomPadding, secondaryColor!);
      }
    }

    // 步骤 4: 主线渐变面积
    Path? primaryLinePath;
    if (allPoints.length >= 2) {
      primaryLinePath = _buildLinePath(allPoints);
      _fillGradientArea(canvas, primaryLinePath, allPoints,
          size.height - _ChartLayout.bottomPadding, themeColor);
    }

    // 步骤 6: 副线平均线
    if (secondaryValues != null &&
        secondaryValues!.isNotEmpty &&
        secondaryColor != null) {
      final avgSecY = yFor(avgSecondaryV);
      final avgSecLinePaint = Paint()
        ..color = secondaryColor!.withValues(alpha: 0.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
          canvas,
          Offset(_ChartLayout.leftPadding, avgSecY),
          Offset(size.width - 8, avgSecY),
          avgSecLinePaint,
          dashWidth: 6,
          gapWidth: 4);
    }

    // 步骤 7: 主线平均线
    final avgY = yFor(avgV);
    final avgLinePaint = Paint()
      ..color = BeeTokens.secondaryTextStatic.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas,
        Offset(_ChartLayout.leftPadding, avgY),
        Offset(size.width - 8, avgY),
        avgLinePaint,
        dashWidth: 6, gapWidth: 4);

    // 步骤 8: 副线线条
    if (secondaryLinePath != null) {
      final secondaryLinePaint = Paint()
        ..color = secondaryColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..isAntiAlias = true;
      canvas.drawPath(secondaryLinePath, secondaryLinePaint);
    }

    // 步骤 9: 主线线条
    if (primaryLinePath != null) {
      canvas.drawPath(primaryLinePath, line);
    }



    // 步骤 12: Y 轴刻度值
    if (annotate) {
      final yLabelStyle =
          TextStyle(fontSize: yLabelFontSize - 1, color: secondaryTextColor);
      final tickMaxV = layout!.maxV;
      final tickMinV = layout!.minV;
      final yTickCount = 5;
      for (int i = 0; i <= yTickCount; i++) {
        final v = tickMinV + (tickMaxV - tickMinV) * i / yTickCount;
        if (v == 0) continue;
        final displayText = hideAmounts ? '**' : _fmt(v);
        final tp = TextPainter(
          text: TextSpan(text: displayText, style: yLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 40);
        final yPos = yFor(v);
        tp.paint(canvas, Offset(0, yPos - tp.height / 2));
      }
    }

    // 步骤 13: X 轴标签
    if (xLabels.isNotEmpty) {
      final baseStyle =
          TextStyle(fontSize: xLabelFontSize, color: secondaryTextColor);
      final hiStyle = TextStyle(
          fontSize: xLabelFontSize,
          color: primaryTextColor,
          fontWeight: FontWeight.w600);
      final n = xLabels.length;
      int step = (n / 8).ceil();
      if (step < 1) step = 1;
      for (int i = 0; i < n; i += step) {
        final lbl = xLabels[i];
        final tp = TextPainter(
          text: TextSpan(
              text: lbl,
              style: (highlightIndex != null && i == highlightIndex)
                  ? hiStyle
                  : baseStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final dxi = _ChartLayout.leftPadding + i * layout!.dx;
        tp.paint(
            canvas, Offset(dxi - tp.width / 2, size.height - tp.height - 2));
      }
    }
  }

  /// 使用 Catmull-Rom 样条插值生成圆滑曲线路径
  /// Monotone Cubic 插值：严格保证曲线不过冲，同时尽量平滑
  Path _buildCurvedPath(List<Offset> points) {
    if (points.length < 2) return Path();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final n = points.length;

    if (n == 2) {
      final dx = points[1].dx - points[0].dx;
      final dy = points[1].dy - points[0].dy;
      path.cubicTo(
        points[0].dx + dx / 3, points[0].dy + dy / 3,
        points[1].dx - dx / 3, points[1].dy - dy / 3,
        points[1].dx, points[1].dy,
      );
      return path;
    }

    // 计算每个点的切线斜率
    final slopes = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        slopes[i] = (points[1].dy - points[0].dy) /
            (points[1].dx - points[0].dx);
      } else if (i == n - 1) {
        slopes[i] = (points[n - 1].dy - points[n - 2].dy) /
            (points[n - 1].dx - points[n - 2].dx);
      } else {
        slopes[i] = (points[i + 1].dy - points[i - 1].dy) /
            (points[i + 1].dx - points[i - 1].dx);
      }
    }

    // Fritsch-Carlson 修正：保证单调性
    for (int i = 0; i < n - 1; i++) {
      final dx = points[i + 1].dx - points[i].dx;
      final dy = points[i + 1].dy - points[i].dy;
      if (dy == 0) {
        slopes[i] = 0;
        slopes[i + 1] = 0;
      } else {
        final alpha = slopes[i] / (dy / dx);
        final beta = slopes[i + 1] / (dy / dx);
        if (alpha < 0) slopes[i] = 0;
        if (beta < 0) slopes[i + 1] = 0;
        final sum = alpha.abs() + beta.abs();
        if (sum > 3) {
          final scale = 3.0 / sum;
          slopes[i] *= scale;
          slopes[i + 1] *= scale;
        }
      }
    }

    for (int i = 0; i < n - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dx = p2.dx - p1.dx;
      final cp1 = Offset(p1.dx + dx / 3, p1.dy + slopes[i] * dx / 3);
      final cp2 = Offset(p2.dx - dx / 3, p2.dy - slopes[i + 1] * dx / 3);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  /// 构建线条路径（根据 isCurved 选择折线或圆滑曲线）
  Path _buildLinePath(List<Offset> points) {
    if (points.length < 2) {
      return Path();
    }
    if (!isCurved) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      return path;
    }
    return _buildCurvedPath(points);
  }

  /// 绘制曲线下方的渐变面积
  void _fillGradientArea(
    Canvas canvas,
    Path path,
    List<Offset> points,
    double bottomY,
    Color color,
  ) {
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, bottomY)
      ..lineTo(points.first.dx, bottomY)
      ..close();

    final bounds = path.getBounds();
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bottomY - bounds.top,
    );

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.4),
        color.withValues(alpha: 0.0),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.secondaryValues != secondaryValues ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.whiteBg != whiteBg ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.annotate != annotate ||
        oldDelegate.hideAmounts != hideAmounts ||
        oldDelegate.themeColor != themeColor ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isCurved != isCurved;
  }
}

/// 十字定位线绘制器
class _CrosshairPainter extends CustomPainter {
  final Offset point; // 吸附点坐标
  final Color themeColor;
  final double dotRadius;
  final Color crosshairColor;
  final Size chartSize;

  _CrosshairPainter({
    required this.point,
    required this.themeColor,
    required this.dotRadius,
    required this.crosshairColor,
    required this.chartSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final crosshairPaint = Paint()
      ..color = crosshairColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 垂直线（延伸到图表底部）
    canvas.drawLine(
      Offset(point.dx, _ChartLayout.topPadding),
      Offset(point.dx, chartSize.height),
      crosshairPaint,
    );

    // 水平线
    canvas.drawLine(
      Offset(_ChartLayout.leftPadding, point.dy),
      Offset(chartSize.width - 8, point.dy),
      crosshairPaint,
    );

    // 高亮圆点
    final dotPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) {
    return oldDelegate.point != point ||
        oldDelegate.themeColor != themeColor ||
        oldDelegate.crosshairColor != crosshairColor ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.chartSize != chartSize;
  }
}

/// 气泡定位委托：将气泡定位到吸附点上方
class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  final Offset anchorPoint;

  _TooltipPositionDelegate({
    required this.anchorPoint,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return const BoxConstraints(maxWidth: 120);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 默认居中在吸附点上方，偏移 12px
    double x = anchorPoint.dx - childSize.width / 2;
    double y = anchorPoint.dy - childSize.height - 12;

    // 左边界保护
    if (x < 4) x = 4;
    // 右边界保护
    if (x + childSize.width > size.width - 4) {
      x = size.width - childSize.width - 4;
    }
    // 上边界保护：气泡改到下方
    if (y < 4) {
      y = anchorPoint.dy + 12;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _TooltipPositionDelegate oldDelegate) {
    return oldDelegate.anchorPoint != anchorPoint;
  }
}

void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint,
    {double dashWidth = 5, double gapWidth = 3}) {
  final total = (p2 - p1).distance;
  final dir = (p2 - p1) / total;
  double drawn = 0;
  while (drawn < total) {
    final start = p1 + dir * drawn;
    final end = p1 + dir * (drawn + dashWidth).clamp(0, total);
    canvas.drawLine(start, end, paint);
    drawn += dashWidth + gapWidth;
  }
}
