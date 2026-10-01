import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// In-app PDF study view — keeps the reader inside Study Vault
/// so future PDF-related features can live on this screen.
class PdfStudyScreen extends StatelessWidget {
  const PdfStudyScreen({
    super.key,
    required this.title,
    required this.filePath,
  });

  final String title;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(
              child: Text('PDF file is missing from local storage.'),
            );
          }

          return PdfViewer.file(
            filePath,
            params: const PdfViewerParams(
              margin: 8,
            ),
          );
        },
      ),
    );
  }
}
