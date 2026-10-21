class FileItem {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final int modified;
  final String ext;

  const FileItem({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.modified,
    required this.ext,
  });

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      isDir: map['is_dir'] as bool? ?? false,
      size: (map['size'] as num?)?.toInt() ?? 0,
      modified: (map['modified'] as num?)?.toInt() ?? 0,
      ext: map['ext'] as String? ?? '',
    );
  }

  String get readableSize {
    if (isDir) return 'Folder';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
