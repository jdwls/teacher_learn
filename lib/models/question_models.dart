///选择题
class Question {
  String questionText;
  int score;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String? optionAImage;
  String? optionBImage;
  String? optionCImage;
  String? optionDImage;
  String? questionImage;
  String answer;

  Question({
    required this.questionText,
    required this.score,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.optionAImage,
    this.optionBImage,
    this.optionCImage,
    this.optionDImage,
    this.questionImage,
    required this.answer,
  });
}

/// 连线题
class MatchingQuestion {
  String questionText;
  int score;
  List<MatchingItem> items;
  String? questionImage;

  MatchingQuestion({
    required this.questionText,
    required this.score,
    required this.items,
    this.questionImage,
  });

  Map<String, dynamic> toMap() {
    return {
      '题型': '连线题',
      '题干': questionText,
      '题干图片': questionImage ?? '',
      'items': items.asMap().entries.map((entry) => entry.value.toMap(entry.key)).toList(),
    };
  }

  static MatchingQuestion fromMap(Map<String, dynamic> map) {
    final nestedItems = map['items'] as List<dynamic>?;
    List<MatchingItem> items;
    String questionText;
    int score;
    String? questionImage;
    if (nestedItems != null) {
      items = nestedItems.map((item) => MatchingItem.fromMap(item)).toList();
      questionText = map['题干'] ?? map['questionText'] ?? '';
      score = map['分值'] is int ? map['分值']
          : int.tryParse(map['score']?.toString() ?? map['分值']?.toString() ?? '5') ?? 5;
      questionImage = (map['题干图片'] ?? map['questionImage'])?.toString().isNotEmpty == true ? (map['题干图片'] ?? map['questionImage']) : null;
    } else {
      items = [];
      questionText = map['questionText'] ?? '';
      score = int.tryParse(map['score']?.toString() ?? '5') ?? 5;
      questionImage = map['questionImage']?.toString().isNotEmpty == true ? map['questionImage'] : null;
    }
    return MatchingQuestion(
      questionText: questionText, score: score, questionImage: questionImage, items: items,
    );
  }
}

/// 连线题匹配项
class MatchingItem {
  String leftText;
  String? leftImage;
  String rightText;
  String? rightImage;
  int score;

  MatchingItem({
    required this.leftText, this.leftImage,
    required this.rightText, this.rightImage,
    this.score = 5,
  });

  Map<String, dynamic> toMap(int index) {
    return {
      '序号': '${index + 1}',
      '左侧内容': leftText,
      '左侧图片': leftImage ?? '',
      '右侧内容': rightText,
      '右侧图片': rightImage ?? '',
      '分值': score,
    };
  }

  static MatchingItem fromMap(Map<String, dynamic> map) {
    return MatchingItem(
      leftText: map['左侧内容'] ?? map['leftText'] ?? '',
      leftImage: (map['左侧图片'] ?? map['leftImage'])?.toString().isNotEmpty == true
          ? (map['左侧图片'] ?? map['leftImage']) : null,
      rightText: map['右侧内容'] ?? map['rightText'] ?? '',
      rightImage: (map['右侧图片'] ?? map['rightImage'])?.toString().isNotEmpty == true
          ? (map['右侧图片'] ?? map['rightImage']) : null,
      score: int.tryParse(map['分值']?.toString() ?? map['score']?.toString() ?? '5') ?? 5,
    );
  }
}

/// 顺序题
class SequentialQuestion {
  String questionText;
  int score;
  List<SequentialItem> items;
  String? questionImage;

  SequentialQuestion({
    required this.questionText, required this.score, required this.items, this.questionImage,
  });

  Map<String, dynamic> toMap() {
    return {
      '题型': '顺序题',
      '题干': questionText,
      '分值': score,
      '题干图片': questionImage ?? '',
      'items': items.asMap().entries.map((entry) => entry.value.toMap(entry.key)).toList(),
    };
  }

  static SequentialQuestion fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>?;
    List<SequentialItem> items = [];
    if (rawItems != null) {
      items = rawItems.map((item) => SequentialItem.fromMap(item)).toList();
    }
    return SequentialQuestion(
      questionText: map['题干'] ?? map['questionText'] ?? '',
      score: map['分值'] is int ? map['分值']
          : int.tryParse(map['score']?.toString() ?? map['分值']?.toString() ?? '5') ?? 5,
      questionImage: (map['题干图片'] ?? map['questionImage'])?.toString().isNotEmpty == true
          ? (map['题干图片'] ?? map['questionImage']) : null,
      items: items,
    );
  }
}

/// 顺序题待排序项
class SequentialItem {
  String text;
  String? image;
  int score;

  SequentialItem({
    required this.text, this.image, this.score = 5,
  });

  Map<String, dynamic> toMap(int index) {
    return {
      '序号': '${index + 1}',
      '待排序项目': text,
      '项图片': image ?? '',
      '分值': score,
    };
  }

  static SequentialItem fromMap(Map<String, dynamic> map) {
    return SequentialItem(
      text: map['待排序项目'] ?? map['text'] ?? '',
      image: (map['项图片']?.toString().isNotEmpty == true) ? map['项图片'] : null,
      score: int.tryParse(map['分值']?.toString() ?? map['score']?.toString() ?? '5') ?? 5,
    );
  }
}

/// 打字题
class TypingQuestion {
  String typingType;
  String referenceText;
  int timeLimit;
  int score;

  TypingQuestion({
    required this.typingType, required this.referenceText, required this.timeLimit, required this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      '题型': '打字题',
      '打字类型': typingType,
      '参考文本': referenceText,
      '时间限制': timeLimit,
      '分值': score,
    };
  }

  static TypingQuestion fromMap(Map<String, dynamic> map) {
    return TypingQuestion(
      typingType: map['打字类型'] ?? map['typingType'] ?? 'chinese',
      referenceText: map['参考文本'] ?? map['referenceText'] ?? '',
      timeLimit: (map['时间限制'] ?? map['timeLimit']) is int
          ? (map['时间限制'] ?? map['timeLimit'])
          : int.tryParse((map['时间限制'] ?? map['timeLimit'])?.toString() ?? '5') ?? 5,
      score: (map['分值'] ?? map['score']) is int ? (map['分值'] ?? map['score'])
          : int.tryParse((map['分值'] ?? map['score'])?.toString() ?? '10') ?? 10,
    );
  }
}

/// 操作题初始文件（每个条目包含文件信息和检查行列表）
class OperationFile {
  String fileName;
  String? filePath;
  String? localCachePath;
  String? content;
  List<Map<String, dynamic>>? checkLines;
  int lineNumber;
  String expectedContent;
  int score;

  OperationFile({
    required this.fileName, this.filePath, this.localCachePath, this.content, this.checkLines,
    this.lineNumber = 1, this.expectedContent = '', this.score = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      '文件名': fileName,
      '文件路径': filePath ?? '',
      '检查行': checkLines ?? [],
    };
  }

  static OperationFile fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? checkLines;
    final checkLinesData = map['检查行'];
    if (checkLinesData is List) {
      checkLines = checkLinesData.cast<Map<String, dynamic>>();
    }
    return OperationFile(
      fileName: map['文件名'] ?? map['fileName'] ?? '',
      filePath: (map['文件路径'] ?? map['filePath'])?.toString().isNotEmpty == true ? (map['文件路径'] ?? map['filePath']).toString() : null,
      checkLines: checkLines,
      content: map['内容'] ?? map['content'],
      lineNumber: map['行号'] is int ? map['行号']
          : int.tryParse(map['行号']?.toString() ?? '1') ?? 1,
      expectedContent: map['期望内容'] ?? map['expectedContent'] ?? '',
      score: map['分值'] is int ? map['分值']
          : int.tryParse(map['分值']?.toString() ?? map['score']?.toString() ?? '5') ?? 5,
    );
  }
}

/// 操作题行检查项
class OperationCheckLine {
  String targetPath;
  int lineNumber;
  String expectedContent;
  int score;

  OperationCheckLine({
    required this.targetPath, required this.lineNumber, required this.expectedContent, required this.score,
  });

  Map<String, dynamic> toMap() {
    return {'目标路径': targetPath, '行号': lineNumber, '期望内容': expectedContent, '分值': score};
  }

  static OperationCheckLine fromMap(Map<String, dynamic> map) {
    return OperationCheckLine(
      targetPath: map['目标路径'] ?? map['targetPath'] ?? '',
      lineNumber: map['行号'] ?? map['lineNumber'] ?? 1,
      expectedContent: map['期望内容'] ?? map['expectedContent'] ?? '',
      score: map['分值'] is int ? map['分值']
          : int.tryParse(map['分值']?.toString() ?? map['score']?.toString() ?? '5') ?? 5,
    );
  }
}

/// 操作题正确答案检查项
class OperationAnswer {
  String targetPath;
  List<String> keywords;
  List<OperationCheckLine> checkLines;
  int score;

  OperationAnswer({
    required this.targetPath, required this.keywords, this.checkLines = const [], required this.score,
  });

  Map<String, dynamic> toMap() {
    return {'目标路径': targetPath, '关键字': keywords, '检查项': checkLines.map((c) => c.toMap()).toList(), '分值': score};
  }

  static OperationAnswer fromMap(Map<String, dynamic> map) {
    List<String> keywords = [];
    final keywordsData = map['关键字'] ?? map['keywords'];
    if (keywordsData is List) {
      keywords = keywordsData.map((e) => e.toString()).toList();
    }
    List<OperationCheckLine> checkLines = [];
    final checkLinesData = map['检查项'] ?? map['checkLines'];
    if (checkLinesData is List) {
      checkLines = checkLinesData.map((c) => OperationCheckLine.fromMap(c as Map<String, dynamic>)).toList();
    }
    return OperationAnswer(
      targetPath: map['目标路径'] ?? map['targetPath'] ?? '',
      keywords: keywords,
      checkLines: checkLines,
      score: map['分值'] is int ? map['分值']
          : int.tryParse(map['分值']?.toString() ?? map['score']?.toString() ?? '5') ?? 5,
    );
  }
}

/// 操作题
class OperationQuestion {
  String questionText;
  int score;
  List<OperationFile> initialFiles;

  OperationQuestion({
    required this.questionText, required this.score, required this.initialFiles,
  });

  Map<String, dynamic> toMap() {
    return {
      '题型': '操作题',
      '题号': '1',
      '题干': questionText,
      '分值': score,
      '初始文件': initialFiles.map((f) => f.toMap()).toList(),
    };
  }

  static OperationQuestion fromMap(Map<String, dynamic> map) {
    List<OperationFile> initialFiles = [];
    final initialFilesData = map['初始文件'] ?? map['initialFiles'];
    if (initialFilesData is List) {
      initialFiles = initialFilesData.map((f) => OperationFile.fromMap(f as Map<String, dynamic>)).toList();
    }
    return OperationQuestion(
      questionText: map['题干'] ?? map['questionText'] ?? '',
      score: map['分值'] is int ? map['分值']
          : int.tryParse(map['分值']?.toString() ?? '10') ?? 10,
      initialFiles: initialFiles,
    );
  }
}