// apps/web_nextjs/src/app/share/[token]/page.tsx
"use client";

// TODO: Replace with the final App Store URL once the listing is live in App Store Connect.
const APP_STORE_URL = "https://apps.apple.com/app/id0000000000";

import { useParams } from "next/navigation";
import { useState, useEffect } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase/init";
import DynamicMap from "@/components/DynamicMap";
import Image from "next/image";

interface SharedTravelData {
  uid: string;
  visitedCodes: string[];
  countryCount: number;
  createdAt: string;
}

export default function SharePage() {
  const params = useParams();
  const token = typeof params.token === "string" ? params.token : null;

  const [sharedData, setSharedData] = useState<SharedTravelData | null>(null);
  const [geoJsonData, setGeoJsonData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setError("Invalid share link.");
      setLoading(false);
      return;
    }

    async function fetchData() {
      try {
        const [docSnap, geoResponse] = await Promise.all([
          getDoc(doc(db, "sharedTravelCards", token!)),
          fetch("/data/countries.geojson"),
        ]);

        if (!docSnap.exists()) {
          setError("This travel map doesn't exist or has been removed.");
          return;
        }

        if (!geoResponse.ok) {
          throw new Error("Failed to load map data.");
        }

        setSharedData(docSnap.data() as SharedTravelData);
        setGeoJsonData(await geoResponse.json());
      } catch (e: unknown) {
        const message = e instanceof Error ? e.message : "Something went wrong.";
        setError(message);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [token]);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-gray-500">Loading travel map…</p>
      </div>
    );
  }

  if (error || !sharedData || !geoJsonData) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-red-500">{error ?? "No data available."}</p>
      </div>
    );
  }

  const countryCount = sharedData.countryCount ?? sharedData.visitedCodes.length;

  return (
    <>
      <title>{`${countryCount} countries visited · Roavvy`}</title>
      <div className="flex flex-col min-h-screen">
        <header className="px-6 py-4 border-b">
          <h1 className="text-xl font-semibold">
            {countryCount} {countryCount === 1 ? "country" : "countries"} visited
          </h1>
          <p className="text-sm text-gray-500 mt-1">Shared via Roavvy</p>
        </header>
        <div className="flex-1" style={{ minHeight: "500px" }}>
          <DynamicMap
            geoJsonData={geoJsonData}
            userVisits={sharedData.visitedCodes}
          />
        </div>
        <div className="flex flex-col items-center gap-3 px-6 py-8 border-t bg-amber-50">
          <p className="text-base font-semibold text-gray-800">
            Turn your travels into a poster
          </p>
          <p className="text-sm text-gray-500 text-center max-w-xs">
            Get a personalised world map poster or t-shirt with every country
            you&apos;ve visited highlighted in gold.
          </p>
          <a
            href="/shop"
            className="px-5 py-2 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600"
          >
            See the shop →
          </a>
        </div>
        <div className="flex flex-col items-center gap-3 px-6 py-8 border-t bg-gray-50">
          <p className="text-base font-medium text-gray-800">
            Discover your own travels with Roavvy
          </p>
          <p className="text-sm text-gray-500 text-center max-w-xs">
            Roavvy scans your photos to build your personal world travel map —
            no uploads, no accounts required to get started.
          </p>
          <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
            <Image
              src="/app-store-badge.svg"
              alt="Download on the App Store"
              width={120}
              height={40}
            />
          </a>
        </div>
      </div>
    </>
  );
}
