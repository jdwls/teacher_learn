import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/question_bank_service.dart';
import '../models/question_models.dart';
import 'question_page/controllers.dart';
import 'question_page/mixins/choice_mixin.dart';
import 'question_page/mixins/matching_mixin.dart';
import 'question_page/mixins/sequential_mixin.dart';
import 'question_page/mixins/typing_mixin.dart';
import 'question_page/mixins/operation_mixin.dart';

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  State createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State
    with ChoiceQuestionMixin,
         MatchingQuestionMixin,
         SequentialQuestionMixin,
         TypingQuestionMixin,
         OperationQuestionMixin {
  String selectedQuestionType = '选择题';
  final List<Question> questions = [];
  final List<MatchingQuestion> matchingQuestions = [];
  final List<SequentialQuestion> sequentialQuestions = [];
  final List<TypingQuestion> typingQuestions = [];

  final TextEditingController questionController = TextEditingController();
  final TextEditingController scoreController =
      TextEditingController(text: '5');
  final TextEditingController optionAController = TextEditingController();
  final TextEditingController optionBController = TextEditingController();
  final TextEditingController optionCController = TextEditingController();
  final TextEditingController optionDController = TextEditingController();

  String selectedAnswer = '';
  int? editingIndex;

  String? tempQuestionImage;
  String? tempOptionAImage;
  String? tempOptionBImage;
  String? tempOptionCImage;
  String? tempOptionDImage;

  String? savedQuestionImage;
  String? savedOptionAImage;
  String? savedOptionBImage;
  String? savedOptionCImage;
  String? savedOptionDImage;

  // 连线题相关
  final TextEditingController matchingQuestionController =
      TextEditingController();
  final TextEditingController matchingScoreController =
      TextEditingController(text: '5');
  String? savedMatchingQuestionImage;
  String? tempMatchingQuestionImage;
  int? editingMatchingIndex;
  final List<MatchingItemControllers> matchingItemControllers = [];
  int matchingItemCount = 2;

  // 顺序题相关
  final TextEditingController sequentialQuestionController =
      TextEditingController();
  final TextEditingController sequentialScoreController =
      TextEditingController(text: '5');
  String? savedSequentialQuestionImage;
  String? tempSequentialQuestionImage;
  int? editingSequentialIndex;
  final List<SequentialItemControllers> sequentialItemControllers = [];
  int sequentialItemCount = 3;

  // 打字题相关
  final TextEditingController typingReferenceTextController =
      TextEditingController();
  final TextEditingController typingScoreController =
      TextEditingController(text: '10');
  final TextEditingController typingTimeLimitController =
      TextEditingController(text: '5');
  String typingType = 'chinese';
  int? editingTypingIndex;

  // 操作题相关
  final List<OperationQuestion> operationQuestions = [];
  final TextEditingController operationQuestionController =
      TextEditingController();
  final TextEditingController operationScoreController =
      TextEditingController(text: '10');
  int? editingOperationIndex;
  final List<OperationFileController> operationFileControllers = [];
  final List<OperationAnswerController> operationAnswerControllers = [];
  int operationFileCount = 1;
  int operationAnswerCount = 1;
  String? selectedOperationFileName;

  // 题库与考试时间配置
  String? selectedBank;
  int examTimeLimit = 30;
  final TextEditingController examTimeLimitController =
      TextEditingController(text: '30');
  int earlySubmitMinutes = 25;
  final TextEditingController earlySubmitMinutesController =
      TextEditingController(text: '25');

  // ========== 初始化 ==========

  @override
  void initState() {
    super.initState();
    initializeMatchingItemControllers();
    for (var i = 0; i < operationFileCount; i++) {
      operationFileControllers.add(OperationFileController());
    }
    for (var i = 0; i < operationAnswerCount; i++) {
      final controller = OperationAnswerController();
      controller.lineCheckControllers.add(OperationLineCheckController());
      operationAnswerControllers.add(controller);
    }
  }

  // ========== 生命周期 ==========

  @override
  void dispose() {
    // 选择题控制器
    questionController.dispose();
    scoreController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    optionDController.dispose();

    // 连线题控制器
    matchingQuestionController.dispose();
    matchingScoreController.dispose();
    for (final ctrl in matchingItemControllers) {
      ctrl.dispose();
    }

    // 顺序题控制器
    sequentialQuestionController.dispose();
    sequentialScoreController.dispose();
    for (final ctrl in sequentialItemControllers) {
      ctrl.dispose();
    }

    // 打字题控制器
    typingReferenceTextController.dispose();
    typingScoreController.dispose();
    typingTimeLimitController.dispose();

    // 操作题控制器
    operationQuestionController.dispose();
    operationScoreController.dispose();
    for (final ctrl in operationFileControllers) {
      ctrl.dispose();
    }
    for (final ctrl in operationAnswerControllers) {
      ctrl.dispose();
    }

    // 考试时间配置控制器
    examTimeLimitController.dispose();
    earlySubmitMinutesController.dispose();

    super.dispose();
  }

  // ========== 选择题 clearForm（被 choice_mixin 的 stub 调用） ==========

  /// 清除选择题表单。choice_mixin 通过 self.clearForm() 调用此方法。
  @override
  void clearForm() {
    questionController.clear();
    scoreController.text = '5';
    optionAController.clear();
    optionBController.clear();
    optionCController.clear();
    optionDController.clear();
    setState(() {
      selectedAnswer = '';
      editingIndex = null;
      tempQuestionImage = null;
      tempOptionAImage = null;
      tempOptionBImage = null;
      tempOptionCImage = null;
      tempOptionDImage = null;
      savedQuestionImage = null;
      savedOptionAImage = null;
      savedOptionBImage = null;
      savedOptionCImage = null;
      savedOptionDImage = null;
    });
  }

  // ========== 题库保存（被所有 mixin 通过 self.saveQuestionsToFile() 调用） ==========

  @override
  Future<bool> saveQuestionsToFile() async {
    if (selectedBank == null) return false;

    final questionsData = questions.map((q) {
      return {
        'type': '选择题',
        'questionText': q.questionText,
        'optionA': q.optionA,
        'optionB': q.optionB,
        'optionC': q.optionC,
        'optionD': q.optionD,
        'answer': q.answer,
        'score': q.score.toString(),
        'questionImage': q.questionImage ?? '',
        'imageA': q.optionAImage ?? '',
        'imageB': q.optionBImage ?? '',
        'imageC': q.optionCImage ?? '',
        'imageD': q.optionDImage ?? '',
      };
    }).toList();

    final matchingQuestionsData =
        matchingQuestions.map((q) => q.toMap()).toList();

    final sequentialQuestionsData =
        sequentialQuestions.map((q) => q.toMap()).toList();

    final typingQuestionsData = typingQuestions.map((q) => q.toMap()).toList();

    final operationQuestionsData =
        operationQuestions.map((q) => q.toMap()).toList();

    final success = await QuestionBankService.saveQuestionToBank(
      selectedBank!,
      questionsData,
      matchingQuestions: matchingQuestionsData,
      sequentialQuestions: sequentialQuestionsData,
      typingQuestions: typingQuestionsData,
      operationQuestions: operationQuestionsData,
      earlySubmitMinutes: earlySubmitMinutes,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    } else if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已保存到题库: $selectedBank'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    return success;
  }

  // ========== 考试时间配置 ==========

  Future<void> _saveEarlySubmitMinutes() async {
    if (selectedBank == null) return;
    final success = await QuestionBankService.saveEarlySubmitMinutes(
      selectedBank!,
      earlySubmitMinutes,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('提前交卷时间已更新为 $earlySubmitMinutes 分钟'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveExamTimeLimit() async {
    if (selectedBank == null) return;

    final success = await QuestionBankService.saveExamTimeLimit(
      selectedBank!,
      examTimeLimit,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('考试时间已更新为 $examTimeLimit 分钟'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ========== 导入功能（已禁用） ==========

  void _handleImportQuestionBank() {
    // 导入功能暂时禁用
  }

  // ========== 统计 Getter ==========

  int get _totalQuestionCount =>
      questions.length +
      matchingQuestions.length +
      sequentialQuestions.length +
      typingQuestions.length +
      operationQuestions.length;

  int get _totalScore {
    int total = 0;
    total += questions.fold(0, (sum, q) => sum + q.score);
    for (var q in matchingQuestions) {
      for (var item in q.items) {
        total += item.score;
      }
    }
    for (var q in sequentialQuestions) {
      for (var item in q.items) {
        total += item.score;
      }
    }
    total += typingQuestions.fold(0, (sum, q) => sum + q.score);
    total += operationQuestions.fold(0, (sum, q) {
      int itemTotal = 0;
      for (final item in q.initialFiles) {
        itemTotal += item.score;
      }
      return sum + itemTotal;
    });
    return total;
  }

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                if (selectedQuestionType == '选择题')
                  buildQuestionForm()
                else if (selectedQuestionType == '连线题')
                  buildMatchingQuestionForm()
                else if (selectedQuestionType == '顺序题')
                  buildSequentialQuestionForm()
                else if (selectedQuestionType == '打字题')
                  buildTypingQuestionForm()
                else
                  buildOperationQuestionForm(),
                if (selectedQuestionType == '选择题')
                  buildQuestionTable()
                else if (selectedQuestionType == '连线题')
                  buildMatchingQuestionTable()
                else if (selectedQuestionType == '顺序题')
                  buildSequentialQuestionTable()
                else if (selectedQuestionType == '打字题')
                  buildTypingQuestionTable()
                else
                  buildOperationQuestionTable(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========== 顶部栏 UI ==========

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < 900 ? _buildNarrowTopBar() : _buildWideTopBar(),
        ),
    );
  }

  Widget _buildWideTopBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildTypeButton('选择题'),
        _buildTypeButton('连线题'),
        _buildTypeButton('顺序题'),
        _buildTypeButton('打字题'),
        _buildTypeButton('操作题'),
        _buildStatsChip(),
        if (selectedBank != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  child: TextField(
                    controller: examTimeLimitController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: '30',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          height: 4),
                    ),
                    onChanged: (value) {
                      final newLimit = int.tryParse(value) ?? 30;
                      setState(() {
                        examTimeLimit = newLimit;
                      });
                      _saveExamTimeLimit();
                    },
                  ),
                ),
                Text(' 分钟',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                      height: 3,
                    )),
              ],
            ),
          ),
        if (selectedBank != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  child: TextField(
                    controller: earlySubmitMinutesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: '25',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          height: 4),
                    ),
                    onChanged: (value) {
                      final newMinutes = int.tryParse(value) ?? 25;
                      setState(() {
                        earlySubmitMinutes = newMinutes;
                      });
                      _saveEarlySubmitMinutes();
                    },
                  ),
                ),
                Text(' 分钟可交',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      height: 3,
                    )),
              ],
            ),
          ),
        _buildQuestionBankButton(),
        if (selectedBank != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedBank!.length > 7
                      ? '${selectedBank!.substring(0, 7)}...'
                      : selectedBank!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                      fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNarrowTopBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildTypeButton('选择题'),
        _buildTypeButton('连线题'),
        _buildTypeButton('顺序题'),
        _buildTypeButton('打字题'),
        _buildTypeButton('操作题'),
        _buildStatsChip(),
        _buildQuestionBankButton(),
        ElevatedButton.icon(
          onPressed: _handleImportQuestionBank,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('导入题库'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[400],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label) {
    final isSelected = selectedQuestionType == label;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedQuestionType = label;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 $label 模式'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? AppTheme.primaryBlue : const Color(0xFFE5E7EB),
        foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildQuestionBankButton() {
    return ElevatedButton(
      onPressed: () async {
        final banks = await QuestionBankService.getQuestionBanks();
        if (!mounted) return;
        String? tempSelected =
            banks.contains(selectedBank) ? selectedBank : null;
        showDialog(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('选择题库'),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (banks.isEmpty)
                      const Text('暂无可用题库，请通过其他方式添加题库')
                    else
                      DropdownButtonFormField<String>(
                        value: tempSelected,
                        hint: const Text(
                          '请选择题库',
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        isExpanded: true,
                        isDense: true,
                        menuMaxHeight: 48.0 * 5,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 24,
                          ),
                        ),
                        items: banks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: Text(
                              bank,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            tempSelected = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: banks.isEmpty
                      ? null
                      : () async {
                          if (tempSelected != null) {
                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('正在加载题库数据...'),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            final questionData =
                                await QuestionBankService.loadQuestionsFromBank(
                                    tempSelected!);

                            final loadedQuestions = questionData.map((q) {
                              return Question(
                                questionText: q['questionText'] ?? '',
                                score: int.tryParse(
                                        q['score']?.toString() ?? '5') ??
                                    5,
                                optionA: q['optionA'] ?? '',
                                optionB: q['optionB'] ?? '',
                                optionC: q['optionC'] ?? '',
                                optionD: q['optionD'] ?? '',
                                answer: q['answer'] ?? '',
                                questionImage:
                                    q['questionImage']?.toString().isNotEmpty ==
                                            true
                                        ? q['questionImage']
                                        : null,
                                optionAImage:
                                    q['imageA']?.toString().isNotEmpty == true
                                        ? q['imageA']
                                        : null,
                                optionBImage:
                                    q['imageB']?.toString().isNotEmpty == true
                                        ? q['imageB']
                                        : null,
                                optionCImage:
                                    q['imageC']?.toString().isNotEmpty == true
                                        ? q['imageC']
                                        : null,
                                optionDImage:
                                    q['imageD']?.toString().isNotEmpty == true
                                        ? q['imageD']
                                        : null,
                              );
                            }).toList();

                            final matchingData = await QuestionBankService
                                .loadMatchingQuestionsFromBank(tempSelected!);

                            final loadedMatchingQuestions = matchingData
                                .map((q) => MatchingQuestion.fromMap(q))
                                .toList();

                            final sequentialData = await QuestionBankService
                                .loadSequentialQuestionsFromBank(tempSelected!);

                            final loadedSequentialQuestions = sequentialData
                                .map((q) => SequentialQuestion.fromMap(q))
                                .toList();

                            final typingData = await QuestionBankService
                                .loadTypingQuestionsFromBank(tempSelected!);

                            final loadedTypingQuestions = typingData
                                .map((q) => TypingQuestion.fromMap(q))
                                .toList();

                            final operationData = await QuestionBankService
                                .loadOperationQuestionsFromBank(tempSelected!);

                            final loadedOperationQuestions = operationData
                                .map((q) => OperationQuestion.fromMap(q))
                                .toList();

                            final examTimeLimitValue =
                                await QuestionBankService.loadExamTimeLimit(
                                    tempSelected!);
                            final earlySubmitMinutesValue = await QuestionBankService
                                .loadEarlySubmitMinutes(tempSelected!);

                            setState(() {
                              selectedBank = tempSelected;
                              questions.clear();
                              questions.addAll(loadedQuestions);
                              matchingQuestions.clear();
                              matchingQuestions
                                  .addAll(loadedMatchingQuestions);
                              sequentialQuestions.clear();
                              sequentialQuestions
                                  .addAll(loadedSequentialQuestions);
                              typingQuestions.clear();
                              typingQuestions.addAll(loadedTypingQuestions);
                              operationQuestions.clear();
                              operationQuestions
                                  .addAll(loadedOperationQuestions);

                              examTimeLimit = examTimeLimitValue;
                              examTimeLimitController.text =
                                  examTimeLimitValue.toString();

                              earlySubmitMinutes = earlySubmitMinutesValue;
                              earlySubmitMinutesController.text =
                                  earlySubmitMinutesValue.toString();

                              if (loadedTypingQuestions.isNotEmpty) {
                                selectedQuestionType = '打字题';
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '已加载题库: $tempSelected，共 ${questions.length} 选择题，${matchingQuestions.length} 连线题，${sequentialQuestions.length} 顺序题，${typingQuestions.length} 打字题'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        );
      },
      child: const Text('选择题库'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStatsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '共 $_totalQuestionCount 题',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '总 $_totalScore 分',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
