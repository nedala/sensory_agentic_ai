import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';


class FileHelper {
  final String _myContactIDFileName = 'my_contact_id.txt';

  // Save binary data (e.g., images, audio, ink drawings)
  Future<String> saveBinaryData(String fileName, List<int> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(data, flush: true);
    return path;
  }

  Future<String> saveBinaryDataFromUint8List(
      String fileName, Uint8List data) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(data, flush: true);
    return path;
  }

  Future<Uint8List> loadImageData(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  // Save JSON data to a file (for text notes, contacts)
  Future<String> saveJsonData(String fileName, String jsonData) async {
    final directory = await getApplicationDocumentsDirectory();
    print('${directory.path}, $fileName, $jsonData');
    final path = '${directory.path}/$fileName.json';
    final file = File(path);
    await file.writeAsString(jsonData, flush: true);
    return path;
  }

  // Load data from a specified file path
  Future<String> loadFromFile(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  // Delete a file by its path
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Save the ID of the contact identified as "Self"
  Future<void> saveSelfContactID(String contactID) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_myContactIDFileName';
    final file = File(path)..writeAsStringSync(contactID);
  }

  // Load the ID of the contact identified as "Self"
  Future<String> loadSelfContactID() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_myContactIDFileName';
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
    return '';
  }

  Future<String> copyFileToAppDirectory(
      String originalPath, String newFileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/$newFileName';
    await File(originalPath).copy(newPath);
    return newPath;
  }

  Future<String> getFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }
}
