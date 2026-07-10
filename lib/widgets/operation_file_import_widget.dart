import 'package:flutter/material.dart';
import '../services/file_picker_service.dart';
import '../theme/app_theme.dart';

/// 文件导入组件
/// 用于操作题的初始文件和答案文件导入
class OperationFileImportWidget extends StatefulWidget {
  final String label; // 标签（如"初始文件"或"答案文件"）
  final bool enabled; // 是否启用
  final Function(FilePickResult) onFilePicked; // 文件选择回调
  final VoidCallback? onFileRemoved; // 文件删除回调
  final FilePickResult? existingFile; // 已存在的文件（用于编辑模式）
  final String? filePreview; // 文件内容预览（简略）

  const OperationFileImportWidget({
    super.key,
    required this.label,
    this.enabled = true,
    required this.onFilePicked,
    this.onFileRemoved,
    this.existingFile,
    this.filePreview,
  });

  @override
  State<OperationFileImportWidget> createState() =>
      _OperationFileImportWidgetState();
}

class _OperationFileImportWidgetState extends State<OperationFileImportWidget> {
  FilePickResult? _selectedFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.existingFile;
  }

  Future<void> _pickFile() async {
    if (!widget.enabled) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePickerService.pickSingleFile();
      if (result != null) {
        setState(() {
          _selectedFile = result;
        });
        widget.onFilePicked(result);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
    });
    widget.onFileRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasFile ? AppTheme.primaryBlue : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFile ? Icons.insert_drive_file : Icons.upload_file,
                size: 16,
                color: hasFile ? AppTheme.primaryBlue : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled ? AppTheme.textPrimary : Colors.grey,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!hasFile)
                TextButton.icon(
                  onPressed: widget.enabled ? _pickFile : null,
                  icon: const Icon(Icons.folder_open, size: 14),
                  label: const Text('选择文件'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('重新选择'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _removeFile,
                      icon: const Icon(Icons.close, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(24, 24),
                      ),
                      tooltip: '删除文件',
                    ),
                  ],
                ),
            ],
          ),
          if (hasFile) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderMain),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description,
                          size: 14, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _selectedFile!.fileName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${_selectedFile!.lineCount} 行',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_selectedFile!.fileSize / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (widget.filePreview != null && !hasFile) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.filePreview!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
