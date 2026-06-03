// T5 — Integration test scan fixture
//
// Raw photo records matching test/fixtures/visits/multi_continent_30_countries.json.
// These are the coordinates sent by the Swift bridge (no country code).
// Country resolution happens in Dart via CountryLookup with the real geodata.

const kFixturePhotos = [
  {
    'assetId': 'v_gb_01',
    'lat': 51.5,
    'lng': -0.1,
    'capturedAt': '2018-06-10T08:00:00.000Z',
  },
  {
    'assetId': 'v_fr_01',
    'lat': 48.8,
    'lng': 2.3,
    'capturedAt': '2018-08-22T12:00:00.000Z',
  },
  {
    'assetId': 'v_de_01',
    'lat': 52.5,
    'lng': 13.4,
    'capturedAt': '2019-03-05T10:00:00.000Z',
  },
  {
    'assetId': 'v_es_01',
    'lat': 40.4,
    'lng': -3.7,
    'capturedAt': '2019-07-14T15:00:00.000Z',
  },
  {
    'assetId': 'v_it_01',
    'lat': 41.9,
    'lng': 12.5,
    'capturedAt': '2019-09-01T11:00:00.000Z',
  },
  {
    'assetId': 'v_pt_01',
    'lat': 38.7,
    'lng': -9.1,
    'capturedAt': '2020-02-14T09:00:00.000Z',
  },
  {
    'assetId': 'v_nl_01',
    'lat': 52.4,
    'lng': 4.9,
    'capturedAt': '2020-04-20T13:00:00.000Z',
  },
  {
    'assetId': 'v_be_01',
    'lat': 50.8,
    'lng': 4.4,
    'capturedAt': '2020-06-08T10:00:00.000Z',
  },
  {
    'assetId': 'v_ch_01',
    'lat': 47.4,
    'lng': 8.5,
    'capturedAt': '2020-12-27T14:00:00.000Z',
  },
  {
    'assetId': 'v_no_01',
    'lat': 59.9,
    'lng': 10.7,
    'capturedAt': '2021-01-15T16:00:00.000Z',
  },
  {
    'assetId': 'v_jp_01',
    'lat': 35.7,
    'lng': 139.7,
    'capturedAt': '2021-04-03T08:00:00.000Z',
  },
  {
    'assetId': 'v_th_01',
    'lat': 13.8,
    'lng': 100.5,
    'capturedAt': '2021-06-20T11:00:00.000Z',
  },
  {
    'assetId': 'v_vn_01',
    'lat': 21.0,
    'lng': 105.8,
    'capturedAt': '2021-07-05T09:00:00.000Z',
  },
  {
    'assetId': 'v_sg_01',
    'lat': 1.3,
    'lng': 103.8,
    'capturedAt': '2021-08-11T14:00:00.000Z',
  },
  {
    'assetId': 'v_id_01',
    'lat': -8.4,
    'lng': 115.2,
    'capturedAt': '2021-09-02T07:00:00.000Z',
  },
  {
    'assetId': 'v_in_01',
    'lat': 28.6,
    'lng': 77.2,
    'capturedAt': '2022-01-18T10:00:00.000Z',
  },
  {
    'assetId': 'v_us_01',
    'lat': 40.7,
    'lng': -74.0,
    'capturedAt': '2022-03-22T13:00:00.000Z',
  },
  {
    'assetId': 'v_ca_01',
    'lat': 43.7,
    'lng': -79.4,
    'capturedAt': '2022-05-30T11:00:00.000Z',
  },
  {
    'assetId': 'v_mx_01',
    'lat': 19.4,
    'lng': -99.1,
    'capturedAt': '2022-07-14T09:00:00.000Z',
  },
  {
    'assetId': 'v_br_01',
    'lat': -22.9,
    'lng': -43.2,
    'capturedAt': '2022-10-05T15:00:00.000Z',
  },
  {
    'assetId': 'v_ar_01',
    'lat': -34.6,
    'lng': -58.4,
    'capturedAt': '2022-11-20T12:00:00.000Z',
  },
  {
    'assetId': 'v_cl_01',
    'lat': -33.5,
    'lng': -70.7,
    'capturedAt': '2023-01-08T10:00:00.000Z',
  },
  {
    'assetId': 'v_au_01',
    'lat': -33.9,
    'lng': 151.2,
    'capturedAt': '2023-03-17T08:00:00.000Z',
  },
  {
    'assetId': 'v_nz_01',
    'lat': -36.9,
    'lng': 174.8,
    'capturedAt': '2023-04-02T09:00:00.000Z',
  },
  {
    'assetId': 'v_za_01',
    'lat': -33.9,
    'lng': 18.4,
    'capturedAt': '2023-06-14T11:00:00.000Z',
  },
  {
    'assetId': 'v_ke_01',
    'lat': -1.3,
    'lng': 36.8,
    'capturedAt': '2023-07-28T07:00:00.000Z',
  },
  {
    'assetId': 'v_ma_01',
    'lat': 33.6,
    'lng': -7.6,
    'capturedAt': '2023-09-10T14:00:00.000Z',
  },
  {
    'assetId': 'v_eg_01',
    'lat': 30.1,
    'lng': 31.2,
    'capturedAt': '2023-10-22T10:00:00.000Z',
  },
  {
    'assetId': 'v_ae_01',
    'lat': 25.2,
    'lng': 55.3,
    'capturedAt': '2024-01-06T13:00:00.000Z',
  },
  {
    'assetId': 'v_tr_01',
    'lat': 41.0,
    'lng': 28.9,
    'capturedAt': '2024-02-19T11:00:00.000Z',
  },
];

const kFixturePhotoCount = 30;

/// Expected country codes resolved from the fixture coordinates via CountryLookup.
const kFixtureExpectedCountries = [
  'GB',
  'FR',
  'DE',
  'ES',
  'IT',
  'PT',
  'NL',
  'BE',
  'CH',
  'NO',
  'JP',
  'TH',
  'VN',
  'SG',
  'ID',
  'IN',
  'US',
  'CA',
  'MX',
  'BR',
  'AR',
  'CL',
  'AU',
  'NZ',
  'ZA',
  'KE',
  'MA',
  'EG',
  'AE',
  'TR',
];
