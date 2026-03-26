/// Native-language immigration label pairs per country (ADR-097 Decision 11).
///
/// Index 0 = arrival / entry label.
/// Index 1 = departure / exit label.
///
/// Falls back to ['ARRIVAL', 'DEPARTURE'] for unlisted codes.
const Map<String, List<String>> kNativeStampLabels = {
  // English-speaking
  'AU': ['ARRIVAL', 'DEPARTURE'],
  'BB': ['ARRIVAL', 'DEPARTURE'],
  'BZ': ['ARRIVAL', 'DEPARTURE'],
  'CA': ['ARRIVAL', 'DEPARTURE'],
  'GB': ['ARRIVAL', 'DEPARTURE'],
  'GH': ['ARRIVAL', 'DEPARTURE'],
  'IE': ['ARRIVAL', 'DEPARTURE'],
  'JM': ['ARRIVAL', 'DEPARTURE'],
  'KE': ['ARRIVAL', 'DEPARTURE'],
  'LK': ['ARRIVAL', 'DEPARTURE'],
  'MV': ['ARRIVAL', 'DEPARTURE'],
  'NG': ['ARRIVAL', 'DEPARTURE'],
  'NZ': ['ARRIVAL', 'DEPARTURE'],
  'PH': ['ARRIVAL', 'DEPARTURE'],
  'SC': ['ARRIVÉE', 'DÉPART'], // Seychelles — French official
  'SG': ['ARRIVAL', 'DEPARTURE'],
  'TT': ['ARRIVAL', 'DEPARTURE'],
  'US': ['ADMITTED', 'DEPARTURE'],
  'ZW': ['ARRIVAL', 'DEPARTURE'],

  // French
  'BE': ['ARRIVÉE', 'DÉPART'],
  'BJ': ['ARRIVÉE', 'DÉPART'],
  'CD': ['ARRIVÉE', 'DÉPART'],
  'CI': ['ARRIVÉE', 'DÉPART'],
  'CM': ['ARRIVÉE', 'DÉPART'],
  'FR': ['ARRIVÉE', 'DÉPART'],
  'GA': ['ARRIVÉE', 'DÉPART'],
  'LU': ['ARRIVÉE', 'DÉPART'],
  'MA': ['ARRIVÉE', 'DÉPART'],
  'MG': ['ARRIVÉE', 'DÉPART'],
  'ML': ['ARRIVÉE', 'DÉPART'],
  'MU': ['ARRIVÉE', 'DÉPART'],
  'RE': ['ARRIVÉE', 'DÉPART'],
  'SN': ['ARRIVÉE', 'DÉPART'],
  'TN': ['ARRIVÉE', 'DÉPART'],

  // German
  'AT': ['EINREISE', 'AUSREISE'],
  'CH': ['EINREISE', 'AUSREISE'],
  'DE': ['EINREISE', 'AUSREISE'],
  'LI': ['EINREISE', 'AUSREISE'],

  // Spanish
  'AR': ['LLEGADA', 'SALIDA'],
  'BO': ['LLEGADA', 'SALIDA'],
  'CL': ['LLEGADA', 'SALIDA'],
  'CO': ['LLEGADA', 'SALIDA'],
  'CR': ['LLEGADA', 'SALIDA'],
  'CU': ['LLEGADA', 'SALIDA'],
  'DO': ['LLEGADA', 'SALIDA'],
  'EC': ['LLEGADA', 'SALIDA'],
  'ES': ['LLEGADA', 'SALIDA'],
  'GT': ['LLEGADA', 'SALIDA'],
  'HN': ['LLEGADA', 'SALIDA'],
  'MX': ['LLEGADA', 'SALIDA'],
  'NI': ['LLEGADA', 'SALIDA'],
  'PA': ['LLEGADA', 'SALIDA'],
  'PE': ['LLEGADA', 'SALIDA'],
  'PY': ['LLEGADA', 'SALIDA'],
  'SV': ['LLEGADA', 'SALIDA'],
  'UY': ['LLEGADA', 'SALIDA'],
  'VE': ['LLEGADA', 'SALIDA'],

  // Portuguese
  'AO': ['CHEGADA', 'PARTIDA'],
  'BR': ['CHEGADA', 'PARTIDA'],
  'CV': ['CHEGADA', 'PARTIDA'],
  'MZ': ['CHEGADA', 'PARTIDA'],
  'PT': ['CHEGADA', 'PARTIDA'],
  'ST': ['CHEGADA', 'PARTIDA'],

  // Dutch
  'NL': ['AANKOMST', 'VERTREK'],
  'SR': ['AANKOMST', 'VERTREK'],

  // Scandinavian
  'DK': ['ANKOMST', 'AFREJSE'],
  'FI': ['SAAPUMINEN', 'LÄHTÖ'],
  'IS': ['KOMA', 'BROTTFÖR'],
  'NO': ['ANKOMST', 'AVREISE'],
  'SE': ['ANKOMST', 'AVRESA'],

  // Slavic
  'BG': ['ПРИСТИГАНЕ', 'ЗАМИНАВАНЕ'],
  'CZ': ['PŘÍJEZD', 'ODJEZD'],
  'HR': ['DOLAZAK', 'ODLAZAK'],
  'HU': ['ÉRKEZÉS', 'INDULÁS'],
  'PL': ['WJAZD', 'WYJAZD'],
  'RO': ['SOSIRE', 'PLECARE'],
  'RS': ['DOLAZAK', 'ODLAZAK'],
  'RU': ['ВЪЕЗД', 'ВЫЕЗД'],
  'SI': ['PRIHOD', 'ODHOD'],
  'SK': ['PRÍCHOD', 'ODCHOD'],
  'UA': ['ПРИЇЗД', 'ВИЇЗД'],

  // Greek
  'CY': ['ΑΦΙΞΗ', 'ΑΝΑΧΩΡΗΣΗ'],
  'GR': ['ΑΦΙΞΗ', 'ΑΝΑΧΩΡΗΣΗ'],

  // Italian
  'IT': ['ARRIVO', 'PARTENZA'],
  'SM': ['ARRIVO', 'PARTENZA'],

  // East Asian (CJK)
  'CN': ['入境', '出境'],
  'HK': ['入境', '出境'],
  'JP': ['入国', '出国'],
  'KR': ['입국', '출국'],
  'MO': ['入境', '出境'],
  'TW': ['入境', '出境'],

  // Southeast Asian
  'ID': ['KEDATANGAN', 'KEBERANGKATAN'],
  'KH': ['ចូល', 'ចេញ'],
  'LA': ['ເຂົ້າ', 'ອອກ'],
  'MM': ['ဝင်ရောက်', 'ထွက်ခွာ'],
  'MY': ['KETIBAAN', 'PELEPASAN'],
  'TH': ['เข้าเมือง', 'ออกเมือง'],
  'VN': ['NHẬP CẢNH', 'XUẤT CẢNH'],

  // South Asian
  'BD': ['আগমন', 'প্রস্থান'],
  'IN': ['प्रवेश', 'प्रस्थान'],
  'NP': ['आगमन', 'प्रस्थान'],
  'PK': ['آمد', 'رفت'],

  // Middle Eastern / Arabic
  'AE': ['وصول', 'مغادرة'],
  'EG': ['وصول', 'مغادرة'],
  'IL': ['כניסה', 'יציאה'],
  'IR': ['ورود', 'خروج'],
  'JO': ['وصول', 'مغادرة'],
  'KW': ['وصول', 'مغادرة'],
  'LB': ['وصول', 'مغادرة'],
  'QA': ['وصول', 'مغادرة'],
  'SA': ['وصول', 'مغادرة'],

  // Central Asian
  'KZ': ['КІРУ', 'ШЫҒУ'],
  'UZ': ['KELISH', 'KETISH'],

  // Turkish
  'TR': ['GİRİŞ', 'ÇIKIŞ'],

  // African
  'ET': ['ዳርቻ', 'ወደ'],
  'TZ': ['KUWASILI', 'KUONDOKA'],
  'ZA': ['AANKOMS', 'VERTREK'],
};

/// Returns the arrival label for [countryCode] in the country's official language.
String nativeArrivalLabel(String countryCode) =>
    kNativeStampLabels[countryCode]?[0] ?? 'ARRIVAL';

/// Returns the departure label for [countryCode] in the country's official language.
String nativeDepartureLabel(String countryCode) =>
    kNativeStampLabels[countryCode]?[1] ?? 'DEPARTURE';
