/// Country ISO code → scene emoji for the travel timeline nodes.
///
/// Falls back to ✈️ for any country not in the map.
const Map<String, String> kCountrySceneIcon = {
  // Island paradise
  'MV': '🏝️', 'FJ': '🏝️', 'PH': '🏝️', 'BS': '🏝️', 'BB': '🏝️',
  'LC': '🏝️', 'VC': '🏝️', 'AG': '🏝️', 'DM': '🏝️', 'KN': '🏝️',
  'TT': '🏝️', 'TC': '🏝️', 'KY': '🏝️',
  // Beach destination
  'TH': '🏖️', 'ID': '🏖️', 'LK': '🏖️', 'MT': '🏖️', 'HR': '🏖️',
  'CU': '🏖️', 'DO': '🏖️', 'MX': '🏖️', 'PT': '🏖️', 'CY': '🏖️',
  // Mountains / ski
  'AT': '⛷️', 'CH': '⛷️', 'NO': '⛷️', 'FI': '⛷️', 'NZ': '⛷️',
  // Mountain scenery
  'NP': '🏔️', 'BT': '🏔️', 'IS': '🌋', 'GL': '🧊', 'SE': '🌌',
  'CA': '🏔️',
  // Cultural landmarks
  'FR': '🗼', 'IT': '🏛️', 'GR': '🏛️', 'EG': '🏺', 'PE': '🦙',
  'CN': '🏯', 'IN': '🕌', 'JP': '🗻', 'KH': '🛕', 'MM': '🛕',
  'JO': '🏜️', 'MA': '🕌', 'TR': '🕌', 'KR': '🏯', 'VN': '🛕',
  'TW': '🏯', 'PL': '🏰', 'CZ': '🏰', 'HU': '🏰', 'RO': '🏰',
  'DE': '🏰', 'ES': '🏰', 'GB': '🎡', 'US': '🗽',
  // Safari / wildlife
  'KE': '🦁', 'TZ': '🦒', 'ZA': '🐘', 'BW': '🦁', 'NA': '🦒',
  'RW': '🦍', 'ZM': '🐘', 'UG': '🦍', 'ET': '🦒', 'MZ': '🐘',
  // Desert
  'AE': '🏜️', 'SA': '🏜️', 'QA': '🏜️', 'OM': '🏜️', 'KW': '🏜️',
  // Rainforest / tropics
  'BR': '🌴', 'CR': '🌴', 'GA': '🌴', 'CO': '🌴', 'EC': '🦜',
  'AU': '🦘',
  // Wine / food
  'AR': '🥩', 'CL': '🍷',
  // City / urban
  'SG': '🌃', 'HK': '🌃',
  // Arctic / polar
  'RU': '🧊',
};

String countrySceneIcon(String isoCode) =>
    kCountrySceneIcon[isoCode.toUpperCase()] ?? '✈️';

/// Unicode flag emoji for a 2-letter ISO 3166-1 alpha-2 code.
String flagEmoji(String isoCode) {
  final code = isoCode.toUpperCase();
  if (code.length != 2) return '🏳️';
  const base = 0x1F1E6 - 65;
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}
