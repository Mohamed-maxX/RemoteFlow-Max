import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

class HttpFileService {
  Future<Map<String, dynamic>> browse(String hostIp, int httpPort, [String path = '']) async {
    try {
      final uri = Uri.parse('http://$hostIp:$httpPort/api/files/browse').replace(
        queryParameters: path.isNotEmpty ? {'path': path} : null,
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final itemsRaw = data['items'] as List<dynamic>? ?? [];
        final items = itemsRaw.map((e) => FileItem.fromMap(e as Map<String, dynamic>)).toList();
        return {
          'current_path': data['current_path'] as String? ?? '',
          'parent_path': data['parent_path'] as String? ?? '',
          'downloads_path': data['downloads_path'] as String? ?? '',
          'items': items,
        };
      }
    } catch (_) {}
    return {'current_path': '', 'parent_path': '', 'items': <FileItem>[]};
  }

  Future<bool> openFile(String hostIp, int httpPort, String path) async {
    try {
      final uri = Uri.parse('http://$hostIp:$httpPort/api/files/open');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'path': path}),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFile(String hostIp, int httpPort, String path) async {
    try {
      final uri = Uri.parse('http://$hostIp:$httpPort/api/files/delete');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'path': path}),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadBytes(
    String hostIp,
    int httpPort,
    String filename,
    List<int> bytes, [
    String? dest,
  ]) async {
    try {
      var uri = Uri.parse('http://$hostIp:$httpPort/api/files/upload');
      if (dest != null && dest.isNotEmpty) {
        uri = uri.replace(queryParameters: {'dest': dest});
      }

      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      return streamedResponse.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// High-speed multipart file upload from device storage to PC host with real-time streaming
  Future<bool> uploadLocalFile(
    String hostIp,
    int httpPort,
    String localPath, {
    String? dest,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return false;

      final totalSize = await file.length();
      final filename = file.uri.pathSegments.last;

      var uri = Uri.parse('http://$hostIp:$httpPort/api/files/upload');
      if (dest != null && dest.isNotEmpty) {
        uri = uri.replace(queryParameters: {'dest': dest});
      }

      final request = http.MultipartRequest('POST', uri);
      final multipartFile = await http.MultipartFile.fromPath('file', localPath, filename: filename);
      request.files.add(multipartFile);

      final response = await request.send().timeout(const Duration(minutes: 5));
      if (response.statusCode == 200) {
        onProgress?.call(totalSize, totalSize);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// High-speed chunked streaming file download from PC host to mobile device Downloads folder
  Future<File?> downloadFile(
    String downloadUrl,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request).timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      final file = File(destinationPath);
      final sink = file.openWrite();

      int receivedBytes = 0;
      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }).asFuture();

      await sink.flush();
      await sink.close();
      client.close();

      return file;
    } catch (e) {
      return null;
    }
  }

  /// Resolves the optimal directory for saving downloaded files on Android
  static Future<Directory> getDeviceDownloadDir() async {
    try {
      // 1. Check official public Android Download directory
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }

      // 2. path_provider getDownloadsDirectory
      final dir = await getDownloadsDirectory();
      if (dir != null && await dir.exists()) {
        return dir;
      }

      // 3. getExternalStorageDirectory
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final subDownload = Directory('${extDir.path}/Download');
        if (!await subDownload.exists()) {
          await subDownload.create(recursive: true);
        }
        return subDownload;
      }

      // 4. Fallback to application documents
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<bool> openUrl(String hostIp, int httpPort, String url) async {
    try {
      final uri = Uri.parse('http://$hostIp:$httpPort/api/files/open_url');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url': url}),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
