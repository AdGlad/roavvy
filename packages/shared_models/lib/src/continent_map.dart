/// Maps ISO 3166-1 alpha-2 country codes to one of the six inhabited
/// continental regions (ADR-035).
///
/// Territories are mapped to the continent of their administering country.
/// Countries absent from this map are silently ignored by [AchievementEngine]
/// — no exception is thrown.
///
/// The six region names used here must match what [AchievementEngine] expects:
/// 'Africa', 'Asia', 'Europe', 'North America', 'South America', 'Oceania'.
const Map<String, String> kCountryContinent = {
  // ── Africa ────────────────────────────────────────────────────────────────
  'DZ': 'Africa', // Algeria
  'AO': 'Africa', // Angola
  'BJ': 'Africa', // Benin
  'BW': 'Africa', // Botswana
  'BF': 'Africa', // Burkina Faso
  'BI': 'Africa', // Burundi
  'CV': 'Africa', // Cabo Verde
  'CM': 'Africa', // Cameroon
  'CF': 'Africa', // Central African Republic
  'TD': 'Africa', // Chad
  'KM': 'Africa', // Comoros
  'CG': 'Africa', // Congo
  'CD': 'Africa', // Congo (DR)
  'CI': 'Africa', // Côte d'Ivoire
  'DJ': 'Africa', // Djibouti
  'EG': 'Africa', // Egypt
  'GQ': 'Africa', // Equatorial Guinea
  'ER': 'Africa', // Eritrea
  'SZ': 'Africa', // Eswatini
  'ET': 'Africa', // Ethiopia
  'GA': 'Africa', // Gabon
  'GM': 'Africa', // Gambia
  'GH': 'Africa', // Ghana
  'GN': 'Africa', // Guinea
  'GW': 'Africa', // Guinea-Bissau
  'KE': 'Africa', // Kenya
  'LS': 'Africa', // Lesotho
  'LR': 'Africa', // Liberia
  'LY': 'Africa', // Libya
  'MG': 'Africa', // Madagascar
  'MW': 'Africa', // Malawi
  'ML': 'Africa', // Mali
  'MR': 'Africa', // Mauritania
  'MU': 'Africa', // Mauritius
  'MA': 'Africa', // Morocco
  'MZ': 'Africa', // Mozambique
  'NA': 'Africa', // Namibia
  'NE': 'Africa', // Niger
  'NG': 'Africa', // Nigeria
  'RW': 'Africa', // Rwanda
  'ST': 'Africa', // São Tomé and Príncipe
  'SN': 'Africa', // Senegal
  'SC': 'Africa', // Seychelles
  'SL': 'Africa', // Sierra Leone
  'SO': 'Africa', // Somalia
  'ZA': 'Africa', // South Africa
  'SS': 'Africa', // South Sudan
  'SD': 'Africa', // Sudan
  'TZ': 'Africa', // Tanzania
  'TG': 'Africa', // Togo
  'TN': 'Africa', // Tunisia
  'UG': 'Africa', // Uganda
  'ZM': 'Africa', // Zambia
  'ZW': 'Africa', // Zimbabwe
  // African territories
  'EH': 'Africa', // Western Sahara
  'RE': 'Africa', // Réunion (France)
  'YT': 'Africa', // Mayotte (France)
  'SH': 'Africa', // Saint Helena (UK)
  'TF': 'Africa', // French Southern Territories

  // ── Asia ──────────────────────────────────────────────────────────────────
  'AF': 'Asia', // Afghanistan
  'AM': 'Asia', // Armenia
  'AZ': 'Asia', // Azerbaijan
  'BH': 'Asia', // Bahrain
  'BD': 'Asia', // Bangladesh
  'BT': 'Asia', // Bhutan
  'BN': 'Asia', // Brunei
  'KH': 'Asia', // Cambodia
  'CN': 'Asia', // China
  'GE': 'Asia', // Georgia
  'IN': 'Asia', // India
  'ID': 'Asia', // Indonesia
  'IR': 'Asia', // Iran
  'IQ': 'Asia', // Iraq
  'IL': 'Asia', // Israel
  'JP': 'Asia', // Japan
  'JO': 'Asia', // Jordan
  'KZ': 'Asia', // Kazakhstan
  'KW': 'Asia', // Kuwait
  'KG': 'Asia', // Kyrgyzstan
  'LA': 'Asia', // Laos
  'LB': 'Asia', // Lebanon
  'MY': 'Asia', // Malaysia
  'MV': 'Asia', // Maldives
  'MN': 'Asia', // Mongolia
  'MM': 'Asia', // Myanmar
  'NP': 'Asia', // Nepal
  'KP': 'Asia', // North Korea
  'OM': 'Asia', // Oman
  'PK': 'Asia', // Pakistan
  'PS': 'Asia', // Palestinian Territory
  'PH': 'Asia', // Philippines
  'QA': 'Asia', // Qatar
  'SA': 'Asia', // Saudi Arabia
  'SG': 'Asia', // Singapore
  'KR': 'Asia', // South Korea
  'LK': 'Asia', // Sri Lanka
  'SY': 'Asia', // Syria
  'TW': 'Asia', // Taiwan
  'TJ': 'Asia', // Tajikistan
  'TH': 'Asia', // Thailand
  'TL': 'Asia', // Timor-Leste
  'TR': 'Asia', // Turkey
  'TM': 'Asia', // Turkmenistan
  'AE': 'Asia', // United Arab Emirates
  'UZ': 'Asia', // Uzbekistan
  'VN': 'Asia', // Vietnam
  'YE': 'Asia', // Yemen
  // Asian territories
  'HK': 'Asia', // Hong Kong (China)
  'MO': 'Asia', // Macao (China)
  'IO': 'Asia', // British Indian Ocean Territory

  // ── Europe ────────────────────────────────────────────────────────────────
  'AL': 'Europe', // Albania
  'AD': 'Europe', // Andorra
  'AT': 'Europe', // Austria
  'BY': 'Europe', // Belarus
  'BE': 'Europe', // Belgium
  'BA': 'Europe', // Bosnia and Herzegovina
  'BG': 'Europe', // Bulgaria
  'HR': 'Europe', // Croatia
  'CY': 'Europe', // Cyprus
  'CZ': 'Europe', // Czechia
  'DK': 'Europe', // Denmark
  'EE': 'Europe', // Estonia
  'FI': 'Europe', // Finland
  'FR': 'Europe', // France
  'DE': 'Europe', // Germany
  'GR': 'Europe', // Greece
  'HU': 'Europe', // Hungary
  'IS': 'Europe', // Iceland
  'IE': 'Europe', // Ireland
  'IT': 'Europe', // Italy
  'XK': 'Europe', // Kosovo
  'LV': 'Europe', // Latvia
  'LI': 'Europe', // Liechtenstein
  'LT': 'Europe', // Lithuania
  'LU': 'Europe', // Luxembourg
  'MT': 'Europe', // Malta
  'MD': 'Europe', // Moldova
  'MC': 'Europe', // Monaco
  'ME': 'Europe', // Montenegro
  'NL': 'Europe', // Netherlands
  'MK': 'Europe', // North Macedonia
  'NO': 'Europe', // Norway
  'PL': 'Europe', // Poland
  'PT': 'Europe', // Portugal
  'RO': 'Europe', // Romania
  'RU': 'Europe', // Russia
  'SM': 'Europe', // San Marino
  'RS': 'Europe', // Serbia
  'SK': 'Europe', // Slovakia
  'SI': 'Europe', // Slovenia
  'ES': 'Europe', // Spain
  'SE': 'Europe', // Sweden
  'CH': 'Europe', // Switzerland
  'UA': 'Europe', // Ukraine
  'GB': 'Europe', // United Kingdom
  'VA': 'Europe', // Vatican City
  // European territories
  'GI': 'Europe', // Gibraltar (UK)
  'GG': 'Europe', // Guernsey (UK)
  'JE': 'Europe', // Jersey (UK)
  'IM': 'Europe', // Isle of Man (UK)
  'AX': 'Europe', // Åland Islands (Finland)
  'SJ': 'Europe', // Svalbard (Norway)
  'FO': 'Europe', // Faroe Islands (Denmark)

  // ── North America ─────────────────────────────────────────────────────────
  // Includes Central America and the Caribbean
  'AG': 'North America', // Antigua and Barbuda
  'BS': 'North America', // Bahamas
  'BB': 'North America', // Barbados
  'BZ': 'North America', // Belize
  'CA': 'North America', // Canada
  'CR': 'North America', // Costa Rica
  'CU': 'North America', // Cuba
  'DM': 'North America', // Dominica
  'DO': 'North America', // Dominican Republic
  'SV': 'North America', // El Salvador
  'GD': 'North America', // Grenada
  'GT': 'North America', // Guatemala
  'HT': 'North America', // Haiti
  'HN': 'North America', // Honduras
  'JM': 'North America', // Jamaica
  'MX': 'North America', // Mexico
  'NI': 'North America', // Nicaragua
  'PA': 'North America', // Panama
  'KN': 'North America', // Saint Kitts and Nevis
  'LC': 'North America', // Saint Lucia
  'VC': 'North America', // Saint Vincent and the Grenadines
  'TT': 'North America', // Trinidad and Tobago
  'US': 'North America', // United States
  // North American territories
  'AI': 'North America', // Anguilla (UK)
  'AW': 'North America', // Aruba (Netherlands)
  'BM': 'North America', // Bermuda (UK)
  'VG': 'North America', // British Virgin Islands
  'KY': 'North America', // Cayman Islands (UK)
  'CW': 'North America', // Curaçao (Netherlands)
  'GL': 'North America', // Greenland (Denmark)
  'GP': 'North America', // Guadeloupe (France)
  'MQ': 'North America', // Martinique (France)
  'MS': 'North America', // Montserrat (UK)
  'PR': 'North America', // Puerto Rico (US)
  'BQ': 'North America', // Caribbean Netherlands
  'MF': 'North America', // Saint Martin (France)
  'PM': 'North America', // Saint Pierre and Miquelon (France)
  'SX': 'North America', // Sint Maarten (Netherlands)
  'TC': 'North America', // Turks and Caicos Islands (UK)
  'VI': 'North America', // US Virgin Islands

  // ── South America ─────────────────────────────────────────────────────────
  'AR': 'South America', // Argentina
  'BO': 'South America', // Bolivia
  'BR': 'South America', // Brazil
  'CL': 'South America', // Chile
  'CO': 'South America', // Colombia
  'EC': 'South America', // Ecuador
  'GY': 'South America', // Guyana
  'PY': 'South America', // Paraguay
  'PE': 'South America', // Peru
  'SR': 'South America', // Suriname
  'UY': 'South America', // Uruguay
  'VE': 'South America', // Venezuela
  // South American territories
  'FK': 'South America', // Falkland Islands (UK)
  'GF': 'South America', // French Guiana (France)
  'GS': 'South America', // South Georgia and South Sandwich Islands (UK)

  // ── Oceania ───────────────────────────────────────────────────────────────
  'AU': 'Oceania', // Australia
  'FJ': 'Oceania', // Fiji
  'KI': 'Oceania', // Kiribati
  'MH': 'Oceania', // Marshall Islands
  'FM': 'Oceania', // Micronesia
  'NR': 'Oceania', // Nauru
  'NZ': 'Oceania', // New Zealand
  'PW': 'Oceania', // Palau
  'PG': 'Oceania', // Papua New Guinea
  'WS': 'Oceania', // Samoa
  'SB': 'Oceania', // Solomon Islands
  'TO': 'Oceania', // Tonga
  'TV': 'Oceania', // Tuvalu
  'VU': 'Oceania', // Vanuatu
  // Oceanian territories
  'AS': 'Oceania', // American Samoa (US)
  'CK': 'Oceania', // Cook Islands (NZ)
  'GU': 'Oceania', // Guam (US)
  'NC': 'Oceania', // New Caledonia (France)
  'NF': 'Oceania', // Norfolk Island (Australia)
  'MP': 'Oceania', // Northern Mariana Islands (US)
  'PF': 'Oceania', // French Polynesia (France)
  'TK': 'Oceania', // Tokelau (NZ)
  'WF': 'Oceania', // Wallis and Futuna (France)
  'PN': 'Oceania', // Pitcairn Islands (UK)
  'CC': 'Oceania', // Cocos (Keeling) Islands (Australia)
  'CX': 'Oceania', // Christmas Island (Australia)
};
