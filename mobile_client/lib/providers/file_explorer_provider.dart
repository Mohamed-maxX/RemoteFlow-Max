import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../services/http_file_service.dart';
import 'connection_provider.dart';

class FileExplorerState {
  final String currentPath;
  final String parentPath;
  final String downloadsPath;
  final List<FileItem> items;
  final bool isLoading;
  final String? error;

  const FileExplorerState({
    this.currentPath = '',
    this.parentPath = '',
    this.downloadsPath = '',
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  FileExplorerState copyWith({
    String? currentPath,
    String? parentPath,
    String? downloadsPath,
    List<FileItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return FileExplorerState(
      currentPath: currentPath ?? this.currentPath,
      parentPath: parentPath ?? this.parentPath,
      downloadsPath: downloadsPath ?? this.downloadsPath,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FileExplorerNotifier extends StateNotifier<FileExplorerState> {
  final Ref _ref;
  final HttpFileService _service = HttpFileService();

  FileExplorerNotifier(this._ref) : super(const FileExplorerState());

  int get _httpPort => 5058;
  String? get _hostIp => _ref.read(connectionProvider).hostIp;

  Future<void> loadDirectory([String path = '']) async {
    final ip = _hostIp;
    if (ip == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final data = await _service.browse(ip, _httpPort, path);

    state = state.copyWith(
      currentPath: data['current_path'] as String? ?? '',
      parentPath: data['parent_path'] as String? ?? '',
      downloadsPath: data['downloads_path'] as String? ?? '',
      items: data['items'] as List<FileItem>? ?? [],
      isLoading: false,
    );
  }

  Future<bool> openFile(String path) async {
    final ip = _hostIp;
    if (ip == null) return false;
    return await _service.openFile(ip, _httpPort, path);
  }

  Future<bool> deleteFile(String path) async {
    final ip = _hostIp;
    if (ip == null) return false;
    final ok = await _service.deleteFile(ip, _httpPort, path);
    if (ok) {
      await loadDirectory(state.currentPath);
    }
    return ok;
  }

  Future<bool> uploadBytes(String filename, List<int> bytes, [String? dest]) async {
    final ip = _hostIp;
    if (ip == null) return false;
    final ok = await _service.uploadBytes(ip, _httpPort, filename, bytes, dest);
    if (ok && state.currentPath.isNotEmpty) {
      await loadDirectory(state.currentPath);
    }
    return ok;
  }

  Future<bool> uploadLocalFile(
    String localPath, {
    String? dest,
    void Function(int sent, int total)? onProgress,
  }) async {
    final ip = _hostIp;
    if (ip == null) return false;
    final ok = await _service.uploadLocalFile(ip, _httpPort, localPath, dest: dest, onProgress: onProgress);
    if (ok) {
      await loadDirectory(state.currentPath);
    }
    return ok;
  }

  Future<String?> downloadFile(
    FileItem item, {
    void Function(int received, int total)? onProgress,
  }) async {
    final ip = _hostIp;
    if (ip == null) return null;

    final encoded = Uri.encodeComponent(item.path);
    final downloadUrl = 'http://$ip:$_httpPort/api/files/download?path=$encoded';
    final targetDir = await HttpFileService.getDeviceDownloadDir();
    final destPath = '${targetDir.path}/${item.name}';

    final file = await _service.downloadFile(downloadUrl, destPath, onProgress: onProgress);
    return file?.path;
  }

  Future<bool> openUrl(String url) async {
    final ip = _hostIp;
    if (ip == null) return false;
    return await _service.openUrl(ip, _httpPort, url);
  }
}

final fileExplorerProvider =
    StateNotifierProvider<FileExplorerNotifier, FileExplorerState>((ref) {
  return FileExplorerNotifier(ref);
});
