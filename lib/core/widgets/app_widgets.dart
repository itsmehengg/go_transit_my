import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE4E8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1220),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.color = AppColors.primary, super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class TransportIcon extends StatelessWidget {
  const TransportIcon({
    required this.icon,
    this.color = AppColors.primary,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(icon, color: Colors.white, size: size * .52),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class MockMap extends StatelessWidget {
  const MockMap({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      child: CustomPaint(
        painter: _MapPainter(),
        child: SizedBox(height: 190, width: double.infinity),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFEFF6FF), BlendMode.srcOver);
    final road = Paint()
      ..color = const Color(0xFFD3DCE8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      canvas.drawLine(
        Offset(0, 20 + i * 28),
        Offset(size.width, 6 + i * 32),
        road,
      );
    }
    final blue = Paint()
      ..color = AppColors.primary2
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final green = Paint()
      ..color = AppColors.success
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(25, size.height - 34),
      Offset(size.width - 24, 36),
      blue,
    );
    canvas.drawLine(
      const Offset(60, 35),
      Offset(size.width - 70, size.height - 32),
      green,
    );
    final marker = Paint()..color = AppColors.primary2;
    for (final p in [
      const Offset(46, 70),
      Offset(size.width * .45, 50),
      Offset(size.width * .7, 112),
      Offset(size.width * .25, 145),
    ]) {
      canvas.drawCircle(p, 7, marker);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
