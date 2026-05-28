import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/challenge/guess_normalizer.dart';

void main() {
  group('normalizeForGuess', () {
    test('lowercases input', () {
      expect(normalizeForGuess('PETRA'), 'petra');
    });

    test('strips diacritics', () {
      expect(normalizeForGuess('Angkor Vat'), 'angkor vat');
      expect(normalizeForGuess('Vézelay'), 'vezelay');
      expect(normalizeForGuess('Göreme'), 'goreme');
      expect(normalizeForGuess('Łódź'), 'lodz');
    });

    test('removes parenthetical suffixes', () {
      expect(normalizeForGuess('Timbuktu (extension)'), 'timbuktu');
      expect(normalizeForGuess('Danger Site (– Danger List)'), 'danger site');
    });

    test('removes non-alphanumeric characters', () {
      expect(normalizeForGuess("Rub' al Khali"), 'rub al khali');
      expect(normalizeForGuess('Rock-Hewn Churches'), 'rockhewn churches');
    });

    test('collapses multiple spaces', () {
      expect(normalizeForGuess('Abu   Simbel'), 'abu simbel');
    });

    test('trims leading and trailing whitespace', () {
      expect(normalizeForGuess('  Pompeii  '), 'pompeii');
    });

    test('handles empty string', () {
      expect(normalizeForGuess(''), '');
    });

    test('handles ß → ss', () {
      expect(normalizeForGuess('Straße'), 'strasse');
    });

    test('handles æ → ae and œ → oe', () {
      expect(normalizeForGuess('Ærø'), 'aero');
      expect(normalizeForGuess('Cœur'), 'coeur');
    });
  });

  group('guessMatches', () {
    test('exact match after normalization', () {
      expect(guessMatches('Petra', 'Petra'), isTrue);
      expect(guessMatches('petra', 'Petra'), isTrue);
      expect(guessMatches('PETRA', 'Petra'), isTrue);
    });

    test('diacritic-insensitive match', () {
      expect(guessMatches('Vezelay', 'Vézelay'), isTrue);
      expect(guessMatches('Goreme', 'Göreme'), isTrue);
    });

    test('partial match when input length >= 4', () {
      expect(guessMatches('Angkor', 'Angkor Wat'), isTrue);
      expect(guessMatches('Machu', 'Machu Picchu'), isTrue);
    });

    test('no partial match when input length < 4', () {
      expect(guessMatches('Taj', 'Taj Mahal'), isFalse);
      expect(guessMatches('Abu', 'Abu Simbel'), isFalse);
    });

    test('returns false for empty input', () {
      expect(guessMatches('', 'Petra'), isFalse);
    });

    test('returns false for wrong guess', () {
      expect(guessMatches('Colosseum', 'Petra'), isFalse);
    });

    test('parenthetical stripping helps matching', () {
      expect(guessMatches('Timbuktu', 'Timbuktu (extension)'), isTrue);
    });

    test('no false positive on short partial that is not contained', () {
      expect(guessMatches('Rome', 'Petra'), isFalse);
    });
  });
}
