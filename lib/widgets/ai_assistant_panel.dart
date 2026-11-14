import 'package:flutter/material.dart';

import '../services/ai_assistant_service.dart';
import '../theme/app_theme.dart';

/// AI 助手管理面板（教师端「学生端控制 → AI 助手」）
///
/// 两张卡片：
///   1. AI 配置：服务商 / API 地址 / API Key / 模型 / 系统提示词 / 采样参数
///   2. 对话记录：按班级、学生筛选，查看并清理学生与 AI 的历史对话
class AiAssistantPanel extends StatefulWidget {
  const AiAssistantPanel({super.key});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final AiAssistantService _aiService = AiAssistantService.instance;

  // ===== 配置表单 =====
  bool _enabled = false;
  String _provider = AiAssistantService.providerDeepSeek;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _contextMessagesController;
  late final TextEditingController _rateLimitController;

  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final config = _aiService.config;
    _enabled = config['enabled'] == true;
    _provider =
        config['provider']?.toString() ?? AiAssistantService.providerDeepSeek;
    _baseUrlController =
        TextEditingController(text: config['base_url']?.toString() ?? '');
    _apiKeyController =
        TextEditingController(text: config['api_key']?.toString() ?? '');
    _modelController =
        TextEditingController(text: config['model']?.toString() ?? '');
    _systemPromptController = TextEditingController(
        text: config['system_prompt']?.toString() ??
            AiAssistantService.defaultSystemPrompt);
    _temperatureController = TextEditingController(
        text: (config['temperature'] as num?)?.toDouble().toString() ?? '0.7');
    _maxTokensController =
        TextEditingController(text: '${config['max_tokens'] ?? 2000}');
    _contextMessagesController =
        TextEditingController(text: '${config['context_messages'] ?? 10}');
    _rateLimitController = TextEditingController(
        text: '${config['max_requests_per_day'] ?? AiAssistantService.defaultMaxRequestsPerDay}');
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _contextMessagesController.dispose();
    _rateLimitController.dispose();
    super.dispose();
  }

  // ==================== 配置操作 ====================

  /// 切换服务商时，自动填充对应的默认地址与模型
  void _onProviderChanged(String? provider) {
    if (provider == null) return;
    setState(() {
      _provider = provider;
      final defaultUrl = AiAssistantService.defaultBaseUrlFor(provider);
      final defaultModel = AiAssistantService.defaultModelFor(provider);
      // 仅在当前值是另一服务商的默认值时自动替换，避免覆盖教师手填内容
      final currentUrl = _baseUrlController.text.trim();
      if (currentUrl.isEmpty ||
          currentUrl == AiAssistantService.deepSeekBaseUrl ||
          currentUrl == AiAssistantService.openAiCompatibleBaseUrl) {
        _baseUrlController.text = defaultUrl;
      }
      final currentModel = _modelController.text.trim();
      if (currentModel.isEmpty ||
          currentModel == AiAssistantService.deepSeekModel ||
          currentModel == AiAssistantService.openAiCompatibleModel) {
        _modelController.text = defaultModel;
      }
    });
  }

  /// 收集表单当前值（保存与测试连接共用）
  Map<String, dynamic> _collectConfig() {
    return {
      'enabled': _enabled,
      'provider': _provider,
      'base_url': _baseUrlController.text.trim(),
      'api_key': _apiKeyController.text.trim(),
      'model': _modelController.text.trim(),
      'system_prompt': _systemPromptController.text.trim(),
      'temperature': double.tryParse(_temperatureController.text.trim()) ?? 0.7,
      'max_tokens': int.tryParse(_maxTokensController.text.trim()) ?? 2000,
      'context_messages':
          int.tryParse(_contextMessagesController.text.trim()) ?? 10,
      'max_requests_per_day':
          int.tryParse(_rateLimitController.text.trim()) ??
              AiAssistantService.defaultMaxRequestsPerDay,
    };
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;
    if (_enabled && _apiKeyController.text.trim().isEmpty) {
      _showSnack('开启 AI 助手前请先填写 API Key', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final saved = await _aiService.saveConfig(_collectConfig());
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showSnack(saved ? 'AI 配置已保存' : 'AI 配置保存失败', isError: !saved);
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnack('请先填写 API Key', isError: true);
      return;
    }

    setState(() => _isTesting = true);
    // 先保存当前表单，确保测试使用的是最新配置
    await _aiService.saveConfig(_collectConfig());
    final result = await _aiService.testConnection();
    if (!mounted) return;
    setState(() => _isTesting = false);
    _showSnack(result.message, isError: !result.success);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.dangerRed : AppTheme.successGreen,
      ),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigCard(),
      ],
    );
  }

  /// 输入框统一装饰
  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  /// 带标签的表单项
  Widget _buildFieldRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// 数字输入小卡片（[hint] 为字段说明，显示在标签下方）
  Widget _buildNumberField(
      String label, TextEditingController controller, String hint,
      {String? description}) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(description,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(hint: hint),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 卡片外壳（与打字配置区视觉一致）
  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
    List<Widget> actions = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ==================== 卡片 1：AI 配置 ====================

  Widget _buildConfigCard() {
    return _buildCard(
      icon: Icons.smart_toy_outlined,
      iconColor: const Color(0xFF8B5CF6),
      title: 'AI 助手配置',
      subtitle: 'API Key 仅保存在教师端，学生端无法获取',
      children: [
        Row(
          children: [
            Switch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              activeColor: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(
              _enabled ? '已开启（学生端可见）' : '已关闭（学生端隐藏）',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const Spacer(),
            Text(
              _aiService.hasApiKey ? '已配置 API Key' : '尚未配置 API Key',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _aiService.hasApiKey
                    ? AppTheme.successGreen
                    : AppTheme.dangerRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          label: '服务商',
          child: DropdownButtonFormField<String>(
            value: _provider,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: const [
              DropdownMenuItem(
                  value: AiAssistantService.providerDeepSeek,
                  child: Text('DeepSeek（默认）')),
              DropdownMenuItem(
                  value: AiAssistantService.providerOpenAiCompatible,
                  child: Text('OpenAI 兼容接口')),
            ],
            onChanged: _onProviderChanged,
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          label: 'API 地址',
          child: TextField(
            controller: _baseUrlController,
            decoration: _inputDecoration(
                hint: AiAssistantService.defaultBaseUrlFor(_provider)),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          label: 'API Key',
          child: TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: _inputDecoration(hint: 'sk-...').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          label: '模型',
          child: TextField(
            controller: _modelController,
            decoration: _inputDecoration(
                hint: AiAssistantService.defaultModelFor(_provider)),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          label: '系统提示词',
          child: TextField(
            controller: _systemPromptController,
            maxLines: 6,
            decoration: _inputDecoration(hint: '定义 AI 的角色与回答要求'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildNumberField('温度（0-2）', _temperatureController, '0.7',
                description: '0 最稳定 · 0.7 推荐 · 越高越发散'),
            _buildNumberField('最大输出 token', _maxTokensController, '2000',
                description: '单次回答的字数上限，越大越长'),
            _buildNumberField('携带上下文条数', _contextMessagesController, '10',
                description: '连同本句最多带上几条历史对话'),
            _buildNumberField('每人每天上限', _rateLimitController, '10',
                description: '每名学生每天最多提问次数'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? '保存中...' : '保存配置'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
