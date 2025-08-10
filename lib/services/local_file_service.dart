import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalFileService {
  /// Chemin vers le répertoire Documents de l’app
  Future<Directory> get _documentsDir async {
    return await getApplicationDocumentsDirectory();
  }

  /// Retourne un File dans Documents
  Future<File> fileInDocuments(String filename) async {
    final dir = await _documentsDir;
    return File('${dir.path}/$filename');
  }

  /// Écrit du texte dans un fichier (Documents)
  Future<void> writeString(String filename, String content) async {
    final file = await fileInDocuments(filename);
    await file.writeAsString(content, flush: true);
  }

  /// Lit du texte depuis un fichier (Documents)
  Future<String> readString(String filename) async {
    try {
      final file = await fileInDocuments(filename);
      return await file.readAsString();
    } catch (e) {
      return '';
    }
  }

  /// Exemple : supprime un fichier (Documents)
  Future<void> deleteFile(String filename) async {
    final file = await fileInDocuments(filename);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Retourne la liste des fichiers dans Documents
  Future<List<FileSystemEntity>> listDocuments() async {
    final dir = await _documentsDir;
    return dir.list().toList();
  }
}
