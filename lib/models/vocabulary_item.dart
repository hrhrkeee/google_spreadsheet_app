/// 単語データを保持するモデルクラス
class VocabularyItem {
  final String word;
  final String meaning;
  final String notes;
  final String category;
  final bool green;
  final bool yellow;
  final bool red;

  const VocabularyItem({
    required this.word,
    required this.meaning,
    required this.notes,
    required this.category,
    required this.green,
    required this.yellow,
    required this.red,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'meaning': meaning,
      'notes': notes,
      'category': category,
      'green': green,
      'yellow': yellow,
      'red': red,
    };
  }

  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    return VocabularyItem(
      word: map['word'],
      meaning: map['meaning'],
      notes: map['notes'],
      category: map['category'],
      green: map['green'],
      yellow: map['yellow'],
      red: map['red'],
    );
  }
  
  // CSVの行からVocabularyItemを作成するファクトリメソッド
  factory VocabularyItem.fromCsvRow(List<dynamic> row, Map<String, int> headerIndices) {
    return VocabularyItem(
      word: row[headerIndices['単語']!].toString(),
      meaning: row[headerIndices['意味']!].toString(),
      notes: row[headerIndices['備考']!].toString(),
      category: row[headerIndices['カテゴリー']!].toString(),
      green: row[headerIndices['緑']!].toString().toLowerCase() == 'true',
      yellow: row[headerIndices['黄']!].toString().toLowerCase() == 'true',
      red: row[headerIndices['赤']!].toString().toLowerCase() == 'true',
    );
  }
  
  // 色フィルターに一致するかどうかをチェック
  bool matchesColorFilter({bool filterGreen = false, bool filterYellow = false, bool filterRed = false}) {
    if (!filterGreen && !filterYellow && !filterRed) {
      return true; // フィルターが選択されていない場合は全て一致
    }
    
    return (filterGreen && green) || (filterYellow && yellow) || (filterRed && red);
  }
}
