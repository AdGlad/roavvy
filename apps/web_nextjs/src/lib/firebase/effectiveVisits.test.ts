import { effectiveVisits } from "./effectiveVisits";

describe("effectiveVisits", () => {
  it("returns [] for all empty inputs", () => {
    expect(effectiveVisits([], [], [])).toEqual([]);
  });

  it("returns inferred codes when no added or removed", () => {
    const result = effectiveVisits(["GB", "FR"], [], []);
    expect(result.sort()).toEqual(["FR", "GB"]);
  });

  it("adds codes not in inferred", () => {
    const result = effectiveVisits(["GB"], ["JP"], []);
    expect(result.sort()).toEqual(["GB", "JP"]);
  });

  it("added code already in inferred is not duplicated", () => {
    const result = effectiveVisits(["GB"], ["GB"], []);
    expect(result).toHaveLength(1);
    expect(result).toContain("GB");
  });

  it("removed suppresses an inferred code", () => {
    const result = effectiveVisits(["GB", "FR"], [], ["GB"]);
    expect(result).toEqual(["FR"]);
  });

  it("removed suppresses an added code", () => {
    const result = effectiveVisits([], ["GB"], ["GB"]);
    expect(result).toEqual([]);
  });

  it("all three inputs: (inferred ∪ added) − removed", () => {
    const result = effectiveVisits(["GB", "FR", "DE"], ["JP", "FR"], ["DE", "JP"]);
    // combined: GB, FR, DE, JP — minus DE, JP → GB, FR
    expect(result.sort()).toEqual(["FR", "GB"]);
  });

  it("handles duplicates within inferred input", () => {
    const result = effectiveVisits(["GB", "GB"], [], []);
    expect(result).toHaveLength(1);
    expect(result).toContain("GB");
  });

  it("removed code not in inferred or added has no effect", () => {
    const result = effectiveVisits(["GB"], [], ["US"]);
    expect(result).toEqual(["GB"]);
  });
});
