import '../models/document.dart';

enum FileSource { files, gallery, camera, scan }

class SelectedFile {
  const SelectedFile(this.name, this.kind, this.sizeBytes);
  final String name;
  final FileKind kind;
  final int sizeBytes;
}

abstract interface class DocumentRepository {
  Future<List<Document>>
  list(); // Includes Trash; UI derives active/deleted views.
  Future<SelectedFile?> selectFile(FileSource source);
  Future<void> save(Document document);
  Stream<double> upload(Document document, SelectedFile file);
  Future<void> replace(String id, SelectedFile file);
  Future<void> trash(Set<String> ids);
  Future<void> restore(Set<String> ids);
  Future<void> permanentlyDelete(String id);
  Future<void> exportBackup();
}
