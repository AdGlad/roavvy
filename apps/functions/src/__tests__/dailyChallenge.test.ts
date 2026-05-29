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
  describe('clue 1 — geography (category + region)', () => {
    it('uses "Cultural" for cultural sites', () => {
      const clue = buildClues(culturalNorth)[0];
      expect(clue.type).toBe('geography');
      expect(clue.text).toBe('A Cultural site in Africa and the Arab States.');
    });

    it('uses "Natural" for natural sites', () => {
      const clue = buildClues(naturalSouth)[0];
      expect(clue.type).toBe('geography');
      expect(clue.text).toBe('A Natural site in Latin America and the Caribbean.');
    });

    it('uses "Mixed Cultural and Natural" for mixed sites', () => {
      const clue = buildClues(mixedRecent)[0];
      expect(clue.type).toBe('geography');
      expect(clue.text).toBe(
        'A Mixed Cultural and Natural site in Latin America and the Caribbean.',
      );
    });
  });

  describe('clue 2 — historical (inscription year + hemisphere)', () => {
    it('Northern Hemisphere for positive latitude', () => {
      const clue = buildClues(culturalNorth)[1];
      expect(clue.type).toBe('historical');
      expect(clue.text).toBe('Inscribed in 1979. Located in the Northern Hemisphere.');
    });

    it('Southern Hemisphere for negative latitude', () => {
      const clue = buildClues(naturalSouth)[1];
      expect(clue.type).toBe('historical');
      expect(clue.text).toContain('Southern Hemisphere');
    });
  });

  describe('clue 3 — location (flag + country name)', () => {
    it('includes the Egyptian flag and country name', () => {
      const clue = buildClues(culturalNorth)[2];
      expect(clue.type).toBe('location');
      expect(clue.text).toBe('🇪🇬 Found in Egypt.');
    });

    it('includes the Argentine flag and country name', () => {
      const clue = buildClues(naturalSouth)[2];
      expect(clue.type).toBe('location');
      expect(clue.text).toBe('🇦🇷 Found in Argentina.');
    });
  });

  describe('clue 4 — contextual hint', () => {
    it('marks very early sites (<=1980) as historical', () => {
      const clue = buildClues(culturalNorth)[3];
      expect(clue.type).toBe('historical');
      expect(clue.text).toContain('very first');
      expect(clue.text).toContain('1979');
    });

    it('marks early sites (1981–1990) as historical', () => {
      const clue = buildClues(naturalSouth)[3];
      expect(clue.type).toBe('historical');
      expect(clue.text).toContain('early years');
    });

    it('uses natural type for recent mixed sites', () => {
      const clue = buildClues(mixedRecent)[3];
      expect(clue.type).toBe('natural');
      expect(clue.text).toContain('both its cultural heritage and its natural landscape');
    });
  });

  describe('clue 5 — direct (first word of name)', () => {
    it('returns the first word of the site name', () => {
      const clue = buildClues(culturalNorth)[4];
      expect(clue.type).toBe('direct');
      expect(clue.text).toBe('The site name begins with "Memphis".');
    });

    it('returns the first word for single-word names', () => {
      const singleWord = { ...culturalNorth, name: 'Karnak' };
      const clue = buildClues(singleWord)[4];
      expect(clue.type).toBe('direct');
      expect(clue.text).toBe('The site name begins with "Karnak".');
    });
  });

  it('always returns an array of exactly 5 clues', () => {
    expect(buildClues(culturalNorth)).toHaveLength(5);
    expect(buildClues(naturalSouth)).toHaveLength(5);
    expect(buildClues(mixedRecent)).toHaveLength(5);
  });
});
