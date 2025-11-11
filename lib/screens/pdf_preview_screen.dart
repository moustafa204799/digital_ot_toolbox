// 📦 lib/screens/pdf_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfData;
  final String patientName;

  const PdfPreviewScreen({
    super.key,
    required this.pdfData,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة تقرير: $patientName'),
      ),
      // هذا الويدجت السحري من حزمة printing
      // يعرض الـ PDF ويتيح المشاركة والطباعة مباشرة من داخله
      body: PdfPreview(
        build: (format) => pdfData,
      ),
    );
  }
}