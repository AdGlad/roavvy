import { buildClues } from '../dailyChallenge';

const culturalNorth = {
  siteId: '86',
  name: 'Memphis and its Necropolis',
  countryCode: 'EG',
  latitude: 29.8575,
  longitude: 31.2225,
  category: 'cultural' as const,
  region: 'Africa and the Arab States',
  inscriptionYear: 1979,
};

const naturalSouth = {
  siteId: '999',
  name: 'Iguazu National Park',
  countryCode: 'AR',
  latitude: -25.686,
  longitude: -54.444,
  category: 'natural' as const,
  region: 'Latin America and the Caribbean',
  inscriptionYear: 1984,
};

const mixedRecent = {
  siteId: '500',
  name: 'Machu Picchu',
  countryCode: 'PE',
  latitude: -13.163,
  longitude: -72.545,
  category: 'mixed' as const,
  region: 'Latin America and the Caribbean',
  inscriptionYear: 2000, // post-1990 so category flavour applies
};

describe('buildClues', () => {
  describe('clue 1 — category + region', () => {
    it('uses "Cultural" for cultural sites', () => {
      expect(buildClues(culturalNorth)[0]).toBe(
        'A Cultural site in Africa and the Arab States.',
      );
    });

    it('uses "Natural" for natural sites', () => {
      expect(buildClues(naturalSouth)[0]).toBe(
        'A Natural site in Latin America and the Caribbean.',
      );
    });

    it('uses "Mixed Cultural and Natural" for mixed sites', () => {
      expect(buildClues(mixedRecent)[0]).toBe(
        'A Mixed Cultural and Natural site in Latin America and the Caribbean.',
      );
    });
  });

  describe('clue 2 — inscription year + hemisphere', () => {
    it('Northern Hemisphere for positive latitude', () => {
      expect(buildClues(culturalNorth)[1]).toBe(
        'Inscribed in 1979. Located in the Northern Hemisphere.',
      );
    });

    it('Southern Hemisphere for negative latitude', () => {
      expect(buildClues(naturalSouth)[1]).toContain('Southern Hemisphere');
    });
  });

  describe('clue 3 — flag + country name', () => {
    it('includes the Egyptian flag and country name', () => {
      expect(buildClues(culturalNorth)[2]).toBe('🇪🇬 Found in Egypt.');
    });

    it('includes the Argentine flag and country name', () => {
      expect(buildClues(naturalSouth)[2]).toBe('🇦🇷 Found in Argentina.');
    });
  });

  describe('clue 4 — contextual hint', () => {
    it('marks very early sites (<=1980)', () => {
      expect(buildClues(culturalNorth)[3]).toContain('very first');
      expect(buildClues(culturalNorth)[3]).toContain('1979');
    });

    it('marks early sites (1981–1990)', () => {
      expect(buildClues(naturalSouth)[3]).toContain('early years');
    });

    it('uses mixed flavour for recent mixed sites', () => {
      expect(buildClues(mixedRecent)[3]).toContain(
        'both its cultural heritage and its natural landscape',
      );
    });
  });

  describe('clue 5 — first word of name', () => {
    it('returns the first word of the site name', () => {
      expect(buildClues(culturalNorth)[4]).toBe(
        'The site name begins with "Memphis".',
      );
    });

    it('returns the first word for single-word names', () => {
      const singleWord = { ...culturalNorth, name: 'Karnak' };
      expect(buildClues(singleWord)[4]).toBe(
        'The site name begins with "Karnak".',
      );
    });
  });

  it('always returns an array of exactly 5 clues', () => {
    expect(buildClues(culturalNorth)).toHaveLength(5);
    expect(buildClues(naturalSouth)).toHaveLength(5);
    expect(buildClues(mixedRecent)).toHaveLength(5);
  });
});
