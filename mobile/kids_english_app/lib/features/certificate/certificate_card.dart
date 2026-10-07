import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-10-07" -> "7 Oct 2026" (the certificate is English, like the whole child area).
String prettyDate(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) return isoDate;
  return '$day ${_months[month - 1]} ${parts[0]}';
}

/// The certificate: Dandoona, the child's name, the unit name and the date. Drawn with ordinary widgets so the app can
/// turn it into a picture on the device (no external service). Designed at 360 x 500 and scaled to fit.
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.childName, required this.unitTitle, required this.date, required this.mascot, this.unitColor = Palette.orange});

  static const double designWidth = 360;
  static const double designHeight = 500;

  final String childName;
  final String unitTitle;

  /// Already formatted (see [prettyDate]).
  final String date;
  final String? mascot;
  final Color unitColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: designWidth,
      height: designHeight,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Palette.plum, borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: Palette.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.sunflower, width: 5),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) Icon(Icons.star_rounded, size: i == 1 ? 40 : 30, color: Palette.sunflower),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              Strings.en('certificate').toUpperCase(),
              key: const Key('certificate-title'),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 3, color: Palette.nightInk),
            ),
            const SizedBox(height: 6),
            Text(Strings.en('certAwardedTo'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Palette.brown)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                childName,
                key: const Key('certificate-name'),
                maxLines: 1,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Palette.plum),
              ),
            ),
            Container(height: 4, width: 190, margin: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: Palette.sunflower, borderRadius: BorderRadius.circular(4))),
            Text(Strings.en('certFinished'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Palette.brown)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(color: unitColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: Palette.nightInk, width: 3)),
              child: Text(unitTitle, key: const Key('certificate-unit'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Palette.white)),
            ),
            Expanded(
              child: mascot == null
                  ? const SizedBox.shrink()
                  : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: AssetPicture(mascot!, semanticLabel: 'Dandoona')),
            ),
            Text(date, key: const Key('certificate-date'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.nightInk)),
          ],
        ),
      ),
    );
  }
}
