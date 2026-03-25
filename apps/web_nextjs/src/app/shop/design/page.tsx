"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { httpsCallable } from "firebase/functions";
import { useAuth } from "@/contexts/AuthContext";
import { useUserVisits } from "@/lib/firebase/useUserVisits";
import { functions } from "@/lib/firebase/init";
import { countryName } from "@/lib/countryNames";

export const POSTER_VARIANT_ID = "gid://shopify/ProductVariant/47577104351419";

/** Converts an ISO 3166-1 alpha-2 code to its flag emoji. */
function countryFlag(code: string): string {
  const base = 0x1f1e6 - 65; // offset from 'A' to regional indicator A
  const codePoints = [...code.toUpperCase()].map((ch) => base + ch.charCodeAt(0));
  return String.fromCodePoint(...codePoints);
}

interface CreateMerchCartResult {
  checkoutUrl: string;
  cartId: string;
  merchConfigId: string;
  previewUrl?: string;
}

export default function DesignPage() {
  const router = useRouter();
  const { user, loading: authLoading } = useAuth();
  const { visitedCodes, loading: visitsLoading } = useUserVisits();

  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [initialised, setInitialised] = useState(false);
  const [calling, setCalling] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Auth guard — redirect unauthenticated users
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/sign-in?next=/shop/design");
    }
  }, [authLoading, user, router]);

  // Pre-select all countries on first load
  useEffect(() => {
    if (!visitsLoading && !initialised) {
      setSelected(new Set(visitedCodes));
      setInitialised(true);
    }
  }, [visitsLoading, visitedCodes, initialised]);

  const toggle = (code: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(code)) {
        next.delete(code);
      } else {
        next.add(code);
      }
      return next;
    });
  };

  const selectAll = () => setSelected(new Set(visitedCodes));
  const deselectAll = () => setSelected(new Set());

  const handleCreate = async () => {
    setError(null);
    setCalling(true);
    try {
      const fn = httpsCallable<unknown, CreateMerchCartResult>(
        functions,
        "createMerchCart"
      );
      const result = await fn({
        variantId: POSTER_VARIANT_ID,
        selectedCountryCodes: Array.from(selected),
        quantity: 1,
      });
      window.location.href = result.data.checkoutUrl;
    } catch {
      setError("Something went wrong. Please try again.");
      setCalling(false);
    }
  };

  // Show nothing while auth is resolving or redirect is in flight
  if (authLoading || (!user && !authLoading)) {
    return null;
  }

  if (visitsLoading) {
    return (
      <main className="flex items-center justify-center min-h-screen">
        <p className="text-gray-500">Loading your countries…</p>
      </main>
    );
  }

  return (
    <main className="flex flex-col min-h-screen">
      <header className="flex items-center justify-between px-6 py-4 border-b">
        <Link href="/" className="text-xl font-bold">
          Roavvy
        </Link>
        <Link href="/shop" className="text-sm text-gray-600 hover:underline">
          ← Back to shop
        </Link>
      </header>

      <div className="flex flex-col gap-6 px-6 py-10 max-w-2xl mx-auto w-full">
        <div>
          <h1 className="text-2xl font-bold">Choose your countries</h1>
          <p className="text-gray-500 mt-1 text-sm">
            Select the countries to include in your poster.
          </p>
        </div>

        {visitedCodes.length === 0 ? (
          <p className="text-gray-500 text-sm">
            No countries found — scan the app first.
          </p>
        ) : (
          <>
            <div className="flex gap-3 text-sm">
              <button
                onClick={selectAll}
                disabled={calling}
                className="text-amber-600 hover:underline disabled:opacity-40"
              >
                Select all
              </button>
              <span className="text-gray-300">|</span>
              <button
                onClick={deselectAll}
                disabled={calling}
                className="text-amber-600 hover:underline disabled:opacity-40"
              >
                Deselect all
              </button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {[...visitedCodes].sort().map((code) => (
                <label
                  key={code}
                  className="flex items-center gap-2 p-2 rounded-lg border cursor-pointer hover:bg-amber-50 text-sm"
                >
                  <input
                    type="checkbox"
                    checked={selected.has(code)}
                    onChange={() => toggle(code)}
                    disabled={calling}
                    className="accent-amber-500"
                  />
                  <span aria-hidden>{countryFlag(code)}</span>
                  <span className="truncate">{countryName(code)}</span>
                </label>
              ))}
            </div>
          </>
        )}

        {error && <p className="text-red-600 text-sm">{error}</p>}

        <button
          onClick={handleCreate}
          disabled={selected.size === 0 || calling}
          className="w-full py-3 bg-amber-500 text-white rounded-lg font-medium hover:bg-amber-600 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {calling ? (
            <>
              <span className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent" />
              Creating your poster…
            </>
          ) : (
            "Create my poster"
          )}
        </button>
      </div>
    </main>
  );
}
