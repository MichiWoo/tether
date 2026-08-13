import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/files/domain/file_item.dart';
import 'package:tether_app/features/files/presentation/file_preview.dart';
import 'package:tether_app/features/files/providers/files_provider.dart';

import '../../helpers/fake_files.dart';

void main() {
  FileItem file({String? mimeType}) => FileItem(
        id: 'f1',
        name: 'archivo',
        size: 1024,
        mimeType: mimeType,
        status: FileStatus.uploaded,
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

  group('previewKindOf', () {
    test('clasifica imágenes, texto y no soportados', () {
      expect(previewKindOf(file(mimeType: 'image/png')), FilePreviewKind.image);
      expect(previewKindOf(file(mimeType: 'text/plain')), FilePreviewKind.text);
      expect(previewKindOf(file(mimeType: 'application/json')), FilePreviewKind.text);
      expect(previewKindOf(file(mimeType: 'application/pdf')), FilePreviewKind.unsupported);
      expect(previewKindOf(file()), FilePreviewKind.unsupported);
    });
  });

  Widget buildDialog(FileItem item, FakeUploadService uploadService) {
    return ProviderScope(
      overrides: [
        uploadServiceProvider.overrideWithValue(uploadService),
      ],
      child: MaterialApp(
        home: FilePreviewDialog(file: item, previewUrl: 'https://example.com/x'),
      ),
    );
  }

  testWidgets('muestra el contenido de texto', (tester) async {
    final uploadService = FakeUploadService()..textContent = 'hola mundo';

    await tester.pumpWidget(
      buildDialog(file(mimeType: 'text/plain'), uploadService),
    );
    await tester.pumpAndSettle();

    expect(find.text('hola mundo'), findsOneWidget);
  });

  testWidgets('muestra metadata si el tipo no es soportado', (tester) async {
    final uploadService = FakeUploadService();

    await tester.pumpWidget(
      buildDialog(file(mimeType: 'application/pdf'), uploadService),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Vista previa no disponible'), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);
  });

  testWidgets('muestra el error si falla la carga de texto', (tester) async {
    final uploadService = FakeUploadService()..failFetchText = true;

    await tester.pumpWidget(
      buildDialog(file(mimeType: 'text/plain'), uploadService),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el contenido.'), findsOneWidget);
  });
}
