// Mock all external dependencies before importing the module under test.
// The component cannot be rendered without @testing-library/react + jsdom;
// these tests verify the exported constants and Shopify GID format.
jest.mock("firebase/functions", () => ({ httpsCallable: jest.fn() }));
jest.mock("@/lib/firebase/init", () => ({ functions: {} }));
jest.mock("@/contexts/AuthContext", () => ({
  useAuth: () => ({ user: null, loading: true }),
}));
jest.mock("@/lib/firebase/useUserVisits", () => ({
  useUserVisits: () => ({ visitedCodes: [], loading: true }),
}));
jest.mock("next/navigation", () => ({
  useRouter: () => ({ replace: jest.fn() }),
}));
jest.mock("next/link", () => ({
  __esModule: true,
  default: ({ children }: { children: React.ReactNode }) => children,
}));
jest.mock("@/lib/countryNames", () => ({
  countryName: (code: string) => code,
}));

import React from "react";
import { POSTER_VARIANT_ID } from "../page";

describe("DesignPage — POSTER_VARIANT_ID", () => {
  it("is a valid Shopify ProductVariant GID", () => {
    expect(POSTER_VARIANT_ID).toMatch(
      /^gid:\/\/shopify\/ProductVariant\/\d+$/
    );
  });

  it("matches the Enhanced Matte 18×24in variant", () => {
    expect(POSTER_VARIANT_ID).toBe(
      "gid://shopify/ProductVariant/47577104351419"
    );
  });
});
