import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InteractiveJointVisualizer extends StatelessWidget {
  final double angle;
  final double maxAngle;
  final String jointName;
  final String motionName;
  final String side; // 'Right' or 'Left'
  final Function(double) onAngleChanged;
  final bool isHighContrast;

  const InteractiveJointVisualizer({
    super.key,
    required this.angle,
    required this.maxAngle,
    required this.jointName,
    required this.motionName,
    required this.side,
    required this.onAngleChanged,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد اتجاه الحركة البصري
    // اليمين هو الأساس، واليسار سيتم عكسه تلقائياً
    bool isClockwise = true; 
    
    // تخصيص الاتجاه بناءً على نوع الحركة (لليد اليمنى)
    final lowerMotion = motionName.toLowerCase();
    if (lowerMotion.contains('extension') || lowerMotion.contains('ulnar')) {
      isClockwise = false; 
    }

    // الألوان (High Contrast for Dark Mode)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isHighContrast 
        ? const Color(0xFF00FFFF) // Cyan فاقع
        : (isDark ? const Color(0xFF69F0AE) : Colors.blue); 
    
    final baseColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final glowColor = primaryColor.withOpacity(0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // مساحة الرسم التفاعلية
        GestureDetector(
          onPanUpdate: (details) {
            _handleDrag(context, details);
          },
          child: Transform(
            alignment: Alignment.center,
            // 🔄 عكس أفقي لليد اليسرى
            transform: Matrix4.identity()..scale(side == 'Left' ? -1.0 : 1.0, 1.0),
            child: CustomPaint(
              size: Size(240.w, 180.h),
              painter: _AdvancedLimbPainter(
                angle: angle,
                maxAngle: maxAngle,
                color: primaryColor,
                baseColor: baseColor,
                glowColor: glowColor,
                isClockwise: isClockwise,
                jointType: _getJointType(jointName),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 10.h),
        
        // عرض القيمة الرقمية الكبيرة
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.black54 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
            boxShadow: isDark ? [BoxShadow(color: glowColor, blurRadius: 10)] : [],
          ),
          child: Text(
            '${angle.toInt()}°',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: primaryColor,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  void _handleDrag(BuildContext context, DragUpdateDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final center = Offset(box.size.width / 2, box.size.height * 0.75);
    final touch = box.globalToLocal(details.globalPosition);
    
    double dx = touch.dx - center.dx;
    if (side == 'Left') dx = -dx; 
    
    double dy = touch.dy - center.dy;

    double theta = atan2(dy, dx);
    
    double degrees = -theta * 180 / pi;
    if (degrees < 0) degrees += 360;
    
    if (degrees > 180) degrees = 0; 
    
    double newAngle = degrees.clamp(0.0, maxAngle);
    onAngleChanged(newAngle);
  }

  String _getJointType(String joint) {
    if (joint.contains('Shoulder')) return 'ball';
    if (joint.contains('Wrist')) return 'wrist';
    return 'hinge'; 
  }
}

class _AdvancedLimbPainter extends CustomPainter {
  final double angle;
  final double maxAngle;
  final Color color;
  final Color baseColor;
  final Color glowColor;
  final bool isClockwise;
  final String jointType;

  _AdvancedLimbPainter({
    required this.angle,
    required this.maxAngle,
    required this.color,
    required this.baseColor,
    required this.glowColor,
    required this.isClockwise,
    required this.jointType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.75);
    final limbLength = size.height * 0.55;
    final strokeWidth = 6.w;

    final Paint basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint activePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final Paint glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4;

    // 1. رسم الطرف الثابت
    canvas.drawLine(
      center,
      Offset(center.dx + limbLength, center.dy),
      basePaint,
    );

    // 2. حساب زاوية الحركة
    final dir = isClockwise ? -1 : 1; 
    
    double radians = angle * (pi / 180) * dir;
    
    final endX = center.dx + limbLength * cos(radians);
    final endY = center.dy + limbLength * sin(radians);
    final endPoint = Offset(endX, endY);

    // 3. رسم Glow
    canvas.drawLine(center, endPoint, glowPaint);

    // 4. رسم القوس
    final Rect rect = Rect.fromCircle(center: center, radius: limbLength * 0.5);
    canvas.drawArc(rect, 0, radians, true, fillPaint);
    canvas.drawArc(rect, 0, radians, false, activePaint..strokeWidth = 2);

    // 5. رسم الطرف المتحرك
    canvas.drawLine(center, endPoint, activePaint..strokeWidth = strokeWidth);

    // 6. رسم السهم
    _drawArrowHead(canvas, center, endPoint, color);

    // 7. رسم نقطة الارتكاز
    canvas.drawCircle(center, 8.w, Paint()..color = baseColor..style = PaintingStyle.fill);
    canvas.drawCircle(center, 4.w, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Color color) {
    final double arrowSize = 12.w;
    final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
    
    final path = Path();
    path.moveTo(end.dx + arrowSize * cos(angle), end.dy + arrowSize * sin(angle)); 
    path.lineTo(end.dx - arrowSize * cos(angle - pi / 6), end.dy - arrowSize * sin(angle - pi / 6));
    path.lineTo(end.dx - arrowSize * cos(angle + pi / 6), end.dy - arrowSize * sin(angle + pi / 6));
    path.close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _AdvancedLimbPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color;
  }
}