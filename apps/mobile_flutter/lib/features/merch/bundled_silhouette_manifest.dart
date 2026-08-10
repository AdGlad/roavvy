// GENERATED FILE — do not edit by hand.
//
// Regenerate with:
//   dart run tool/generate_bundled_silhouette_manifest.dart
//
// Maps each ISO-2 country code (UPPERCASE) to the slug of its ONE bundled
// national-silhouette asset at `assets/silhouettes/{cc}_{slug}.svg` (with a
// matching `.png`). The subject varies (animal, landmark, or plant) but every
// entry here is guaranteed to exist as a bundled asset, so it can be clipped
// 100% locally with no network — this is the offline-safe complement to
// [AnimalSilhouetteService]'s Firebase-Storage-backed silhouette set.
//
// The procedural design engine consults this map (synchronously, deterministically)
// to decide whether a single-country design may emit a national-silhouette clip.

/// ISO-2 (UPPERCASE) → bundled silhouette slug. Derived from the actual files in
/// `assets/silhouettes/`, NOT from `assets/symbols/animal_slugs.json` (whose
/// slugs do not reliably match the bundled filenames).
const Map<String, String> kBundledSilhouetteSlugs = {
  'AD': 'pyrenean_chamois',
  'AE': 'arabian_oryx',
  'AF': 'snow_leopard',
  'AL': 'golden_eagle',
  'AM': 'brown_bear',
  'AO': 'palanca_negra',
  'AR': 'jaguar',
  'AT': 'alpine_ibex',
  'AU': 'kangaroo',
  'AZ': 'caucasian_leopard',
  'BA': 'brown_bear',
  'BB': 'green_monkey',
  'BD': 'bengal_tiger',
  'BE': 'lion',
  'BF': 'white_stallion',
  'BG': 'brown_bear',
  'BH': 'arabian_oryx',
  'BI': 'mountain_gorilla',
  'BJ': 'african_leopard',
  'BN': 'proboscis_monkey',
  'BO': 'llama',
  'BR': 'jaguar',
  'BT': 'takin',
  'BW': 'zebra',
  'BY': 'european_bison',
  'BZ': 'baird_tapir',
  'CA': 'beaver',
  'CD': 'okapi',
  'CF': 'forest_elephant',
  'CG': 'forest_elephant',
  'CH': 'alpine_ibex',
  'CL': 'huemul_deer',
  'CM': 'gorilla',
  'CN': 'giant_panda',
  'CO': 'spectacled_bear',
  'CR': 'sloth',
  'CY': 'mouflon',
  'CZ': 'european_lynx',
  'DE': 'brown_bear',
  'DJ': 'dik_dik',
  'DK': 'red_squirrel',
  'DZ': 'fennec_fox',
  'EE': 'lynx',
  'ER': 'african_wild_ass',
  'ES': 'iberian_lynx',
  'ET': 'ethiopian_wolf',
  'FI': 'brown_bear',
  'FR': 'eiffel_tower',
  'GA': 'forest_elephant',
  'GB': 'lion',
  'GE': 'snow_leopard',
  'GH': 'african_elephant',
  'GM': 'red_colobus_monkey',
  'GN': 'hippopotamus',
  'GQ': 'forest_elephant',
  'GT': 'guatemalan_moose',
  'GW': 'saltwater_hippo',
  'GY': 'jaguar',
  'HN': 'white_tailed_deer',
  'HR': 'dalmatian',
  'HU': 'racka_sheep',
  'ID': 'orangutan',
  'IE': 'red_deer',
  'IL': 'mountain_gazelle',
  'IN': 'bengal_tiger',
  'IQ': 'mesopotamian_fallow_deer',
  'IR': 'persian_leopard',
  'IS': 'arctic_fox',
  'IT': 'italian_wolf',
  'JO': 'arabian_oryx',
  'JP': 'mount_fuji',
  'KE': 'african_lion',
  'KG': 'snow_leopard',
  'KH': 'asian_elephant',
  'KM': 'flying_fox',
  'KN': 'vervet_monkey',
  'KP': 'amur_tiger',
  'KR': 'amur_tiger',
  'KW': 'arabian_oryx',
  'KZ': 'snow_leopard',
  'LA': 'asian_elephant',
  'LB': 'brown_bear',
  'LI': 'alpine_ibex',
  'LK': 'sri_lankan_elephant',
  'LR': 'pygmy_hippo',
  'LS': 'basotho_pony',
  'LT': 'european_bison',
  'LV': 'red_deer',
  'LY': 'fennec_fox',
  'MA': 'barbary_macaque',
  'MD': 'aurochs',
  'ME': 'brown_bear',
  'MG': 'ring_tailed_lemur',
  'MK': 'eurasian_lynx',
  'ML': 'african_elephant',
  'MM': 'indochinese_tiger',
  'MN': 'snow_leopard',
  'MR': 'dromedary_camel',
  'MU': 'flying_fox',
  'MW': 'elephant',
  'MX': 'axolotl',
  'MY': 'malayan_tiger',
  'MZ': 'african_elephant',
  'NA': 'oryx',
  'NE': 'addax_antelope',
  'NG': 'nigerian_elephant',
  'NI': 'white_tailed_deer',
  'NL': 'friesian_cow',
  'NO': 'elk',
  'NP': 'snow_leopard',
  'NZ': 'kiwi',
  'OM': 'arabian_oryx',
  'PA': 'sloth',
  'PE': 'llama',
  'PG': 'cuscus',
  'PH': 'tarsier',
  'PK': 'markhor',
  'PL': 'european_bison',
  'PS': 'mountain_gazelle',
  'PT': 'iberian_lynx',
  'PW': 'fruit_bat',
  'PY': 'giant_anteater',
  'QA': 'arabian_oryx',
  'RO': 'carpathian_brown_bear',
  'RS': 'european_brown_bear',
  'RU': 'brown_bear',
  'RW': 'mountain_gorilla',
  'SA': 'arabian_camel',
  'SC': 'coco_de_mer',
  'SD': 'dromedary_camel',
  'SE': 'moose',
  'SG': 'asian_lion',
  'SI': 'brown_bear',
  'SK': 'tatra_chamois',
  'SL': 'chimpanzee',
  'SM': 'european_hare',
  'SN': 'african_lion',
  'SO': 'dromedary_camel',
  'SR': 'jaguar',
  'SS': 'nile_lechwe',
  'SY': 'syrian_brown_bear',
  'SZ': 'lion',
  'TD': 'african_elephant',
  'TG': 'african_lion',
  'TH': 'thai_elephant',
  'TJ': 'snow_leopard',
  'TL': 'timor_deer',
  'TM': 'akhal_teke_horse',
  'TN': 'barbary_sheep',
  'TO': 'flying_fox',
  'TR': 'anatolian_wolf',
  'TT': 'blue_emperor',
  'TW': 'formosan_black_bear',
  'TZ': 'african_elephant',
  'UA': 'eurasian_lynx',
  'UG': 'mountain_gorilla',
  'US': 'bald_eagle',
  'UY': 'pampas_deer',
  'UZ': 'snow_leopard',
  'WS': 'pacific_flying_fox',
  'ZA': 'springbok',
};

/// Runtime accessor over [kBundledSilhouetteSlugs]. Pure, synchronous, and
/// deterministic so the procedural generator can consult it inside a
/// seed-driven sampling loop without any async/network work.
class BundledSilhouetteManifest {
  const BundledSilhouetteManifest._();

  /// Asset directory holding the bundled silhouette SVG/PNG pairs.
  static const String assetDir = 'assets/silhouettes';

  /// Whether [countryCode] (any case) has a bundled national silhouette.
  static bool hasFor(String countryCode) =>
      kBundledSilhouetteSlugs.containsKey(countryCode.toUpperCase());

  /// The bundled silhouette slug for [countryCode], or null if none is bundled.
  static String? slugFor(String countryCode) =>
      kBundledSilhouetteSlugs[countryCode.toUpperCase()];

  /// Whether the composite (country, slug) names a bundled silhouette — i.e.
  /// the slug matches the one bundled asset for that country. Used by the local
  /// clip loader to decide bundled-vs-network without touching the filesystem.
  static bool isBundled(String countryCode, String slug) =>
      kBundledSilhouetteSlugs[countryCode.toUpperCase()] == slug;

  /// The bundled SVG asset path for [countryCode] + [slug], or null if that
  /// pair is not bundled. Filenames are lowercase `{cc}_{slug}.svg`.
  static String? assetPathFor(String countryCode, String slug) {
    if (!isBundled(countryCode, slug)) return null;
    return '$assetDir/${countryCode.toLowerCase()}_$slug.svg';
  }

  /// How many countries have a bundled silhouette.
  static int get count => kBundledSilhouetteSlugs.length;
}
