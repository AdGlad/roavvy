/// Normalizes a site name or user input for fuzzy matching.
///
/// Steps applied in order:
/// 1. Strip parenthetical suffixes like "(– Danger List)" or "(extension)".
/// 2. Lowercase.
/// 3. Strip diacritics via URI round-trip (handles most Latin diacritics).
/// 4. Remove all non-alphanumeric characters except spaces.
/// 5. Collapse multiple spaces and trim.
String normalizeForGuess(String s) {
  // Step 1: remove anything in parentheses.
  var result = s.replaceAll(RegExp(r'\([^)]*\)'), '');

  // Step 2: lowercase.
  result = result.toLowerCase();

  // Step 3: strip diacritics via URI encode/decode round-trip.
  // e.g. "é" → "%C3%A9" → stripped of combining bytes → "e"
  result = _stripDiacritics(result);

  // Step 4: remove non-alphanumeric (except spaces).
  result = result.replaceAll(RegExp(r'[^a-z0-9 ]'), '');

  // Step 5: collapse whitespace.
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

  return result;
}

/// Returns true if [input] is a matching guess for [siteName].
///
/// Rules:
/// - Normalized [input] must equal normalized [siteName], OR
/// - Normalized [siteName] must contain normalized [input] where input length >= 4.
bool guessMatches(String input, String siteName) {
  final n = normalizeForGuess(input);
  final m = normalizeForGuess(siteName);
  if (n.isEmpty) return false;
  return n == m || (n.length >= 4 && m.contains(n));
}

// ── Diacritic stripping ───────────────────────────────────────────────────────

/// Strips Latin diacritics by encoding to bytes then keeping only ASCII.
///
/// Works for the vast majority of UNESCO site names (French, Spanish,
/// Portuguese, German, etc.). Does not handle non-Latin scripts —
/// those pass through unchanged (the matching still works if the user
/// types the same script).
String _stripDiacritics(String s) {
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    if (rune < 128) {
      // Pure ASCII — keep as-is.
      buffer.writeCharCode(rune);
    } else {
      // e.g. "é" → encoded as "%C3%A9" — we want the base "e".
      // Strategy: decode back and if it normalises to ASCII via the
      // known Latin diacritic table, use that; otherwise skip.
      final mapped = _latinDiacriticMap[rune];
      if (mapped != null) {
        buffer.write(mapped);
      }
      // Unknown non-ASCII runes are dropped (treated as punctuation).
    }
  }
  return buffer.toString();
}

/// Maps common Latin diacritic code points to their ASCII base letters.
const Map<int, String> _latinDiacriticMap = {
  // à á â ã ä å
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
  // è é ê ë
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
  // ì í î ï
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
  // ò ó ô õ ö ø
  0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o',
  // ù ú û ü
  0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u',
  // ý ÿ
  0xFD: 'y', 0xFF: 'y',
  // ñ
  0xF1: 'n',
  // ç
  0xE7: 'c',
  // ß → ss
  0xDF: 'ss',
  // Uppercase variants
  0xC0: 'a', 0xC1: 'a', 0xC2: 'a', 0xC3: 'a', 0xC4: 'a', 0xC5: 'a',
  0xC8: 'e', 0xC9: 'e', 0xCA: 'e', 0xCB: 'e',
  0xCC: 'i', 0xCD: 'i', 0xCE: 'i', 0xCF: 'i',
  0xD2: 'o', 0xD3: 'o', 0xD4: 'o', 0xD5: 'o', 0xD6: 'o', 0xD8: 'o',
  0xD9: 'u', 0xDA: 'u', 0xDB: 'u', 0xDC: 'u',
  0xDD: 'y',
  0xD1: 'n',
  0xC7: 'c',
  // Extended Latin (common in UNESCO names)
  0x0105: 'a', 0x0104: 'a', // ą Ą
  0x010D: 'c', 0x010C: 'c', // č Č
  0x0107: 'c', 0x0106: 'c', // ć Ć
  0x010F: 'd', 0x010E: 'd', // ď Ď
  0x011B: 'e', 0x011A: 'e', // ě Ě
  0x0119: 'e', 0x0118: 'e', // ę Ę
  0x011F: 'g', 0x011E: 'g', // ğ Ğ
  0x013A: 'l', 0x0139: 'l', // ĺ Ĺ
  0x013E: 'l', 0x013D: 'l', // ľ Ľ
  0x0142: 'l', 0x0141: 'l', // ł Ł
  0x0144: 'n', 0x0143: 'n', // ń Ń
  0x0148: 'n', 0x0147: 'n', // ň Ň
  0x0151: 'o', 0x0150: 'o', // ő Ő
  0x0159: 'r', 0x0158: 'r', // ř Ř
  0x015B: 's', 0x015A: 's', // ś Ś
  0x0161: 's', 0x0160: 's', // š Š
  0x015F: 's', 0x015E: 's', // ş Ş
  0x0165: 't', 0x0164: 't', // ť Ť
  0x016F: 'u', 0x016E: 'u', // ů Ů
  0x0171: 'u', 0x0170: 'u', // ű Ű
  0x017A: 'z', 0x0179: 'z', // ź Ź
  0x017E: 'z', 0x017D: 'z', // ž Ž
  0x017C: 'z', 0x017B: 'z', // ż Ż
  0x00E6: 'ae', 0x00C6: 'ae', // æ Æ
  0x0153: 'oe', 0x0152: 'oe', // œ Œ
};
