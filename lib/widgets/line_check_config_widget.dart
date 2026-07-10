import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 行检查配置项
class LineCheckItem {
  final String targetPath;
  final int lineNumber;
  final String expectedContent;
  final int score;

  LineCheckItem({
    required this.targetPath,
    required this.lineNumber,
    required this.expectedContent,
    required this.score,
  });
}

/// 行检查配置组件
/// 用于配置操作题的行内容检查项
class LineCheckConfigWidget extends StatefulWidget {
  final bool enabled;
  final List<String> availableFiles; // 可选择的文件列表
  final Function(LineCheckItem) onItemAdded;
  final Function(int index, LineCheckItem item) onItemUpdated;
  final Function(int index) onItemRemoved;
  final List<LineCheckItem> existingItems; // 已存在的检查项

  const LineCheckConfigWidget({
    super.key,
    this.enabled = true,
    this.availableFiles = const [],
    required this.onItemAdded,
    required this.onItemUpdated,
    required this.onItemRemoved,
    this.existingItems = const [],
  });

  @override
  State<LineCheckConfigWidget> createState() => _LineCheckConfigWidgetState();
}

class _LineCheckConfigWidgetState extends State<LineCheckConfigWidget> {
  final List<_LineCheckController> _controllers = [];
  List<LineCheckItem> _items = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.existingItems);
    for (final item in _items) {
      _controllers.add(_LineCheckController.fromItem(item));
    }
    if (_controllers.isEmpty) {
      _addNewItem();
    }
  }

  void _addNewItem() {
    setState(() {
      _controllers.add(_LineCheckController());
      _items.add(LineCheckItem(
        targetPath:
            widget.availableFiles.isNotEmpty ? widget.availableFiles.first : '',
        lineNumber: 1,
        expectedContent: '',
        score: 5,
      ));
    });
  }

  void _removeItem(int index) {
    if (_controllers.length > 1) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
        _items.removeAt(index);
      });
      widget.onItemRemoved(index);
    }
  }

  Future<void> _previewLine(int index) async {
    final ctrl = _controllers[index];
    final lineNumber = int.tryParse(ctrl.lineNumberController.text) ?? 1;
    final fileName = ctrl.selectedFileName;

    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择文件'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // 显示预览对话框
    showDialog(
      context: context,
      builder: (context) => _LinePreviewDialog(
        fileName: fileName,
        lineNumber: lineNumber,
        onContentConfirmed: (content) {
          ctrl.expectedContentController.text = content;
          _updateItem(index);
        },
      ),
    );
  }

  void _updateItem(int index) {
    final ctrl = _controllers[index];
    final item = LineCheckItem(
      targetPath: ctrl.selectedFileName,
      lineNumber: int.tryParse(ctrl.lineNumberController.text) ?? 1,
      expectedContent: ctrl.expectedContentController.text,
      score: int.tryParse(ctrl.scoreController.text) ?? 5,
    );

    setState(() {
      _items[index] = item;
    });

    widget.onItemUpdated(index, item);
  }

  @override
  void dispose() {
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '行检查配置',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled ? AppTheme.textPrimary : Colors.grey,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.enabled ? _addNewItem : null,
                icon: const Icon(Icons.add, size: 16),
                label: Text('添加检查项 (${_controllers.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _controllers.length > 3 ? 200 : null,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(_controllers.length, (index) {
                  return _buildLineCheckRow(index);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCheckRow(int index) {
    final ctrl = _controllers[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderMain),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 文件选择下拉框
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: ctrl.selectedFileName.isNotEmpty
                      ? ctrl.selectedFileName
                      : null,
                  hint: const Text('选择文件', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  items: widget.availableFiles.map((file) {
                    return DropdownMenuItem(
                      value: file,
                      child: Text(
                        file,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: widget.enabled
                      ? (value) {
                          setState(() {
                            ctrl.selectedFileName = value ?? '';
                          });
                          _updateItem(index);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // 行号输入
              SizedBox(
                width: 60,
                child: TextField(
                  controller: ctrl.lineNumberController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '行号',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateItem(index),
                ),
              ),
              const SizedBox(width: 8),
              // 分值输入
              SizedBox(
                width: 50,
                child: TextField(
                  controller: ctrl.scoreController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '分值',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateItem(index),
                ),
              ),
              const SizedBox(width: 4),
              // 预览按钮
              IconButton(
                onPressed: widget.enabled ? () => _previewLine(index) : null,
                icon: Icon(
                  Icons.visibility,
                  size: 16,
                  color: widget.enabled ? AppTheme.primaryBlue : Colors.grey,
                ),
                tooltip: '预览行内容',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              // 删除按钮
              IconButton(
                onPressed: widget.enabled && _controllers.length > 1
                    ? () => _removeItem(index)
                    : null,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: widget.enabled && _controllers.length > 1
                      ? Colors.red
                      : Colors.grey,
                ),
                tooltip: '删除此项',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 期望内容输入
          TextField(
            controller: ctrl.expectedContentController,
            enabled: widget.enabled,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '期望的行内容（完整匹配）',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            onChanged: (_) => _updateItem(index),
          ),
        ],
      ),
    );
  }
}

/// 行检查控制器
class _LineCheckController {
  final TextEditingController lineNumberController =
      TextEditingController(text: '1');
  final TextEditingController expectedContentController =
      TextEditingController();
  final TextEditingController scoreController =
      TextEditingController(text: '5');
  String selectedFileName = '';

  _LineCheckController();

  factory _LineCheckController.fromItem(LineCheckItem item) {
    final ctrl = _LineCheckController();
    ctrl.selectedFileName = item.targetPath;
    ctrl.lineNumberController.text = item.lineNumber.toString();
    ctrl.expectedContentController.text = item.expectedContent;
    ctrl.scoreController.text = item.score.toString();
    return ctrl;
  }

  void dispose() {
    lineNumberController.dispose();
    expectedContentController.dispose();
    scoreController.dispose();
  }
}

/// 行预览对话框
class _LinePreviewDialog extends StatefulWidget {
  final String fileName;
  final int lineNumber;
  final Function(String content) onContentConfirmed;

  const _LinePreviewDialog({
    required this.fileName,
    required this.lineNumber,
    required this.onContentConfirmed,
  });

  @override
  State<_LinePreviewDialog> createState() => _LinePreviewDialogState();
}

class _LinePreviewDialogState extends State<_LinePreviewDialog> {
  List<String> _contextLines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLineContext();
  }

  Future<void> _loadLineContext() async {
    // TODO: 从实际文件加载内容
    // 这里需要从已选择的文件中读取指定行的前后文
    // 暂时使用模拟数据
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _contextLines = [
        '// 前一行内容（第 ${widget.lineNumber - 1} 行）',
        '// 目标行内容（第 ${widget.lineNumber} 行）',
        '// 后一行内容（第 ${widget.lineNumber + 1} 行）',
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.visibility, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '预览: ${widget.fileName} 第 ${widget.lineNumber} 行',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderMain),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < _contextLines.length; i++)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: i == 1 ? Colors.green.withAlpha(26) : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    '${widget.lineNumber - 1 + i}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _contextLines[i],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: i == 1
                                          ? Colors.green[700]
                                          : Colors.grey[700],
                                      fontWeight: i == 1
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '点击"使用此内容"将目标行内容填充到期望内容中：',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_contextLines.length > 1) {
              widget.onContentConfirmed(_contextLines[1]);
            }
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('使用此内容'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
