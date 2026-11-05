/// Kana, kanji and the marks that sit inside a word (々, ー, ヶ). A run
/// of these is segmented on its own; punctuation and Latin end it.
final japaneseRun = RegExp(r'[ぁ-ゖゝゞァ-ヺー-ヾ々〆一-鿿㐀-䶿豈-﫿]+');

/// One kanji, or a mark that stands in for one (々, 〆).
final kanjiChar = RegExp(r'[々〆一-鿿㐀-䶿豈-﫿]');
