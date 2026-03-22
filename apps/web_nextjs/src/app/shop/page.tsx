"use client";

import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";

const PRODUCTS = [
  {
    id: "tshirt",
    name: "Travel T-Shirt",
    description:
      "Your visited countries printed on a premium unisex tee. Every country you've been, worn on your chest.",
  },
  {
    id: "poster",
    name: "Travel Poster",
    description:
      "A framed world map with your visited countries highlighted in gold. Perfect for your wall.",
  },
] as const;

export default function ShopPage() {
  const { user, loading } = useAuth();

  return (
    <main className="flex flex-col min-h-screen">
      <header className="flex items-center justify-between px-6 py-4 border-b">
        <Link href="/" className="text-xl font-bold">
          Roavvy
        </Link>
        {!loading && user && (
          <Link href="/map" className="text-sm text-gray-600 hover:underline">
            My map
          </Link>
        )}
      </header>

      <section className="flex flex-col items-center gap-4 px-6 py-12 text-center bg-amber-50">
        <h1 className="text-3xl font-bold">Your travels, on your wall.</h1>
        <p className="text-gray-600 max-w-md">
          Turn your Roavvy travel map into a personalised poster or t-shirt —
          with every country you&apos;ve visited highlighted.
        </p>
        {!loading && (
          <>
            {user ? (
              <div className="flex flex-col items-center gap-2">
                <span className="px-6 py-3 bg-amber-400 text-white rounded-lg font-medium opacity-60 cursor-not-allowed select-none">
                  Create my design →
                </span>
                <p className="text-xs text-gray-400">Country selection coming soon</p>
              </div>
            ) : (
              <Link
                href="/sign-in?next=/shop"
                className="px-6 py-3 bg-amber-500 text-white rounded-lg hover:bg-amber-600 font-medium"
              >
                Sign in to personalise your design
              </Link>
            )}
          </>
        )}
      </section>

      <section className="grid grid-cols-1 sm:grid-cols-2 gap-6 px-6 py-12 max-w-3xl mx-auto w-full">
        {PRODUCTS.map((product) => (
          <div
            key={product.id}
            className="flex flex-col gap-4 border rounded-xl p-6 bg-white shadow-sm"
          >
            <div className="w-full h-40 bg-amber-100 rounded-lg flex items-center justify-center">
              <span className="text-4xl">{product.id === "poster" ? "🗺️" : "👕"}</span>
            </div>
            <div>
              <h2 className="text-lg font-semibold">{product.name}</h2>
              <p className="text-sm text-gray-500 mt-1">{product.description}</p>
            </div>
          </div>
        ))}
      </section>

      <footer className="mt-auto px-6 py-6 border-t text-center text-sm text-gray-400">
        <p>
          Designed with your real travel history.{" "}
          <Link href="/privacy" className="hover:underline">
            Privacy policy
          </Link>
        </p>
      </footer>
    </main>
  );
}
