/// シートの履歴を保持するクラス
class SheetHistory {
  final String sheetId;
  String displayName;
  final DateTime retrievalDate;
  bool isFavorite;

  SheetHistory({
    required this.sheetId,
    String? displayName,
    required this.retrievalDate,
    this.isFavorite = false,
  }) : displayName = displayName ?? sheetId;

  Map<String, dynamic> toMap() {
    return {
      'sheetId': sheetId,
      'displayName': displayName,
      'retrievalDate': retrievalDate.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory SheetHistory.fromMap(Map<String, dynamic> map) {
    return SheetHistory(
      sheetId: map['sheetId'],
      displayName: map['displayName'] ?? map['sheetId'],
      retrievalDate: DateTime.parse(map['retrievalDate']),
      isFavorite: map['isFavorite'] ?? false,
    );
  }
}
