import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../constants/app_theme.dart';
import '../models/file_item.dart';
import '../providers/connection_provider.dart';
import '../providers/file_explorer_provider.dart';
import '../providers/theme_provider.dart';

class FileExplorerScreen extends ConsumerStatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  ConsumerState<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends ConsumerState<FileExplorerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(fileExplorerProvider.notifier).loadDirectory();
    });

    // Listen for push offers sent from PC host
    Future.microtask(() {
      ref.read(connectionProvider.notifier).incomingPackets.listen((pkt) {
        if (!mounted) return;
        if (pkt.type.toLowerCase() == "file" && pkt.action.toLowerCase() == "push_offer") {
          _handleHostPushOffer(pkt.payload);
        }
      });
    });
  }

  void _handleHostPushOffer(Map<String, dynamic> payload) {
    final filename = payload['filename'] as String? ?? 'ملف وارد';
    final size = payload['size'] as int? ?? 0;
    final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cyanNeon.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_download_rounded, color: AppTheme.cyanNeon, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "ملف وارد من الكمبيوتر",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "أرسل لك الكمبيوتر ملفاً جاهزاً للتحميل المباشر:",
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, color: AppTheme.orangeNeon, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filename,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$sizeMb ميجابايت",
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("تجاهل", style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text("تحميل وحفظ الآن", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanNeon,
                foregroundColor: AppTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadFileWithProgress(FileItem(
                  name: filename,
                  path: payload['path'] as String? ?? filename,
                  isDir: false,
                  size: size,
                  modified: DateTime.now().millisecondsSinceEpoch,
                  ext: filename.split('.').last,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(FileItem item) {
    if (item.isDir) {
      if (item.ext == 'drive') return Icons.storage_rounded;
      return Icons.folder_rounded;
    }
    final ext = item.ext.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif': return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov': return Icons.movie_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg': return Icons.music_note_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar': return Icons.folder_zip_rounded;
      case 'py':
      case 'dart':
      case 'js':
      case 'json':
      case 'html': return Icons.code_rounded;
      case 'apk': return Icons.android_rounded;
      case 'exe':
      case 'msi': return Icons.settings_applications_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(FileItem item) {
    if (item.isDir) {
      return item.ext == 'drive' ? AppTheme.orangeNeon : AppTheme.cyanGlow;
    }
    final ext = item.ext.toLowerCase();
    if (['pdf', 'exe', 'msi'].contains(ext)) return AppTheme.redAlert;
    if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) return AppTheme.purpleNeon;
    if (['py', 'dart', 'js', 'json', 'html'].contains(ext)) return AppTheme.cyanGlow;
    if (['zip', 'rar', '7z', 'apk'].contains(ext)) return AppTheme.orangeNeon;
    if (['mp3', 'wav', 'flac'].contains(ext)) return AppTheme.emeraldNeon;
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) return const Color(0xFFE11D48);
    return AppTheme.textSecondary;
  }

  void _onItemTap(FileItem item) {
    if (item.isDir) {
      ref.read(fileExplorerProvider.notifier).loadDirectory(item.path);
      HapticFeedback.selectionClick();
    } else {
      _showFileActionSheet(item);
    }
  }

  // -------------------------------------------------------------
  // Real-Time File Download with Progress & Direct Open
  // -------------------------------------------------------------
  void _downloadFileWithProgress(FileItem item) {
    HapticFeedback.lightImpact();
    double progressPercent = 0.0;
    int receivedBytes = 0;
    int totalBytes = item.size;
    bool isDone = false;
    String? downloadedFilePath;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Trigger actual download once dialog mounts
            if (progressPercent == 0.0 && !isDone && errorMessage == null) {
              ref.read(fileExplorerProvider.notifier).downloadFile(
                item,
                onProgress: (received, total) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      receivedBytes = received;
                      totalBytes = total > 0 ? total : item.size;
                      progressPercent = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.5;
                    });
                  }
                },
              ).then((path) {
                if (dialogCtx.mounted) {
                  setDialogState(() {
                    if (path != null) {
                      isDone = true;
                      downloadedFilePath = path;
                    } else {
                      errorMessage = "فشل تحميل الملف من الكمبيوتر. تأكد من اتصال الشبكة.";
                    }
                  });
                }
              }).catchError((err) {
                if (dialogCtx.mounted) {
                  setDialogState(() {
                    errorMessage = "خطأ أثناء التحميل: $err";
                  });
                }
              });
            }

            final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppTheme.bgSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDone ? AppTheme.emeraldNeon.withOpacity(0.15) : AppTheme.cyanNeon.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDone ? Icons.check_circle_rounded : Icons.downloading_rounded,
                        color: isDone ? AppTheme.emeraldNeon : AppTheme.cyanNeon,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isDone ? "اكتمل التحميل بنجاح!" : "جاري حفظ الملف في الموبايل...",
                        style: GoogleFonts.cairo(
                          color: isDone ? AppTheme.emeraldNeon : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(_getFileIcon(item), color: _getFileColor(item), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDone
                                      ? "تم الحفظ في: مجلد التنزيلات (Download)"
                                      : "$receivedMb MB من أصل $totalMb MB (${(progressPercent * 100).toInt()}%)",
                                  style: GoogleFonts.cairo(
                                    color: isDone ? AppTheme.emeraldNeon : AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: AppTheme.redAlert, fontSize: 12),
                      )
                    else if (!isDone) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyanNeon),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "يتم النقل بأقصى سرعة عبر شبكة الواي فاي المحلية...",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!isDone)
                    TextButton(
                      child: const Text("إلغاء", style: TextStyle(color: AppTheme.textMuted)),
                      onPressed: () => Navigator.pop(dialogCtx),
                    )
                  else ...[
                    TextButton(
                      child: const Text("إغلاق", style: TextStyle(color: Colors.white70)),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text("فتح الملف الآن", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyanNeon,
                        foregroundColor: AppTheme.bgDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        if (downloadedFilePath != null) {
                          try {
                            await OpenFilex.open(downloadedFilePath!);
                          } catch (_) {}
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFileActionSheet(FileItem item) {
    final theme = ref.read(themeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getFileColor(item).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getFileIcon(item), color: _getFileColor(item), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${item.readableSize} • في الكمبيوتر",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Action 1: Download to Phone (Primary Action)
              ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  "⬇️ حفظ وتحميل إلى الموبايل (Downloads)",
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyanNeon,
                  foregroundColor: AppTheme.bgDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadFileWithProgress(item);
                },
              ),
              const SizedBox(height: 10),

              // Action 2: Open on PC Screen
              OutlinedButton.icon(
                icon: const Icon(Icons.desktop_windows_rounded, color: Colors.white, size: 20),
                label: Text(
                  "💻 فتح الملف على شاشة الكمبيوتر",
                  style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  backgroundColor: Colors.white.withOpacity(0.04),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  ref.read(fileExplorerProvider.notifier).openFile(item.path);
                  Navigator.pop(ctx);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.emeraldNeon,
                      content: Text("تم إرسال أمر فتح ${item.name} على شاشة الكمبيوتر!", style: const TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Action 3: Delete File
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.redAlert, size: 20),
                label: Text(
                  "حذف الملف من الكمبيوتر",
                  style: GoogleFonts.cairo(color: AppTheme.redAlert, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.redAlert, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  ref.read(fileExplorerProvider.notifier).deleteFile(item.path);
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Redesigned Quick Transfer Dialog (3 Main Sections)
  // -------------------------------------------------------------
  void _showQuickTransferSheet() {
    final theme = ref.read(themeProvider);
    final state = ref.read(fileExplorerProvider);
    final notifier = ref.read(fileExplorerProvider.notifier);
    final textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeNeon.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.swap_horizontal_circle_rounded, color: AppTheme.orangeNeon, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "مركز نقل ومشاركة الملفات",
                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "نقل حقيقي فائق السرعة عبر الواي فاي بين الهاتف والكمبيوتر",
                          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Option 1: Pick & Upload from Phone to PC (Primary Big Button)
                _buildTransferOptionCard(
                  icon: Icons.upload_file_rounded,
                  iconColor: AppTheme.orangeNeon,
                  badgeText: "من الموبايل ⬅️ للكمبيوتر",
                  badgeColor: AppTheme.orangeNeon,
                  title: "💻⬅️📱 اختيار ملف من الموبايل وإرساله للكمبيوتر",
                  description: "إرسال صور، مقاطع فيديو، مستندات، أو ملفات APK مباشرة إلى مجلد التنزيلات في الكمبيوتر",
                  buttonLabel: "اختيار ملفات ورفعها الآن",
                  buttonColor: AppTheme.orangeNeon,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                      if (result != null && result.files.isNotEmpty) {
                        int count = 0;
                        for (final f in result.files) {
                          if (f.path != null) {
                            final ok = await notifier.uploadLocalFile(
                              f.path!,
                              dest: state.currentPath.isNotEmpty ? state.currentPath : null,
                            );
                            if (ok) count++;
                          }
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.emeraldNeon,
                              content: Text(
                                "✓ تم إرسال $count ملفات بنجاح إلى مجلد التنزيلات في الكمبيوتر!",
                                style: const TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: AppTheme.redAlert, content: Text("حدث خطأ أثناء رفع الملف: $e")),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Option 2: Pull / Download File from PC to Phone (Big Button)
                _buildTransferOptionCard(
                  icon: Icons.download_for_offline_rounded,
                  iconColor: AppTheme.cyanNeon,
                  badgeText: "من الكمبيوتر ⬅️ للموبايل",
                  badgeColor: AppTheme.cyanNeon,
                  title: "📱⬅️💻 سحب/استلام ملف من الكمبيوتر للموبايل",
                  description: "تصفح مجلد تنزيلات الكمبيوتر أو الأقراص وتحميل أي ملف وحفظه في مجلد Download بهاتفك",
                  buttonLabel: "تصفح تنزيلات الكمبيوتر وسحب ملف",
                  buttonColor: AppTheme.cyanNeon,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (state.downloadsPath.isNotEmpty) {
                      notifier.loadDirectory(state.downloadsPath);
                    } else {
                      notifier.loadDirectory("");
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Option 3: Quick Text & Link Dropper
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_snippet_rounded, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "📝 إرسال نص أو كود أو روابط سريعة للكمبيوتر",
                            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: textCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "الصق هنا أي نص أو رابط أو كود لحفظه فوراً على الكمبيوتر...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text("إرسال النص للكمبيوتر", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final text = textCtrl.text.trim();
                          if (text.isNotEmpty) {
                            final bytes = utf8.encode(text);
                            notifier.uploadBytes("quick_note_${DateTime.now().millisecondsSinceEpoch}.txt", bytes);
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.emeraldNeon,
                                content: Text("تم إرسال الملاحظة وحفظها على الكمبيوتر بنجاح!", style: TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.bold)),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferOptionCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String description,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: buttonColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: Icon(icon, size: 18),
            label: Text(buttonLabel, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppTheme.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileExplorerProvider);
    final notifier = ref.read(fileExplorerProvider.notifier);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Navigation & Quick Jump
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.bgSurface.withOpacity(0.9),
                border: Border(bottom: BorderSide(color: theme.cardBorderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (state.currentPath.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.arrow_forward_rounded, color: theme.primaryColor),
                          tooltip: "للأعلى مجلد واحد",
                          onPressed: () => notifier.loadDirectory(state.parentPath),
                        ),
                      Expanded(
                        child: Text(
                          state.currentPath.isEmpty ? "هذا الكمبيوتر (الأقراص المحلية)" : state.currentPath,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
                        tooltip: "تحديث",
                        onPressed: () => notifier.loadDirectory(state.currentPath),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.storage_rounded, color: theme.secondaryAccent, size: 14),
                        label: const Text("الأقراص", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: theme.cardFillColor,
                        side: BorderSide(color: theme.cardBorderColor),
                        onPressed: () => notifier.loadDirectory(""),
                      ),
                      const SizedBox(width: 8),
                      if (state.downloadsPath.isNotEmpty)
                        ActionChip(
                          avatar: Icon(Icons.download_rounded, color: theme.primaryColor, size: 14),
                          label: const Text("تنزيلات الكمبيوتر", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: theme.cardFillColor,
                          side: BorderSide(color: theme.cardBorderColor),
                          onPressed: () => notifier.loadDirectory(state.downloadsPath),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: state.isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    )
                  : state.items.isEmpty
                      ? const Center(
                          child: Text("المجلد فارغ", style: TextStyle(color: AppTheme.textMuted)),
                        )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: state.items.length,
                      separatorBuilder: (_, __) => Divider(color: theme.cardBorderColor.withOpacity(0.5), height: 1),
                      itemBuilder: (context, idx) {
                        final item = state.items[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _getFileColor(item).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_getFileIcon(item), color: _getFileColor(item), size: 24),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.isDir ? "مجلد" : item.readableSize,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                          // Next to every file: Distinct ⬇️ Download to mobile button!
                          trailing: item.isDir
                              ? const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted, size: 20)
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _downloadFileWithProgress(item),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_rounded, color: theme.primaryColor, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            "تحميل",
                                            style: GoogleFonts.cairo(
                                              color: theme.primaryColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          onTap: () => _onItemTap(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: _showQuickTransferSheet,
          backgroundColor: AppTheme.orangeNeon,
          icon: const Icon(Icons.swap_vert_rounded, color: Colors.white),
          label: Text(
            "إرسال واستلام سريع",
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
