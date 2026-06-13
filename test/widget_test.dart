import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_project/pages/form_validation.dart';

void main() {
  testWidgets('shows vehicle inspection form', (tester) async {
    await tester.pumpWidget(const VehicleInspectionApp());

    expect(find.text('Form Inspeksi Kendaraan'), findsOneWidget);
    expect(find.text('Nomor Polisi'), findsOneWidget);
    expect(find.text('Dokumentasi Foto'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Submit Inspeksi'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Submit Inspeksi'), findsOneWidget);
  });
}
