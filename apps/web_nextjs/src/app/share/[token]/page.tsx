// apps/web_nextjs/src/app/share/[token]/page.tsx
"use client";

import { useParams } from "next/navigation";
import { useState, useEffect } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase/init";
import DynamicMap from "@/components/DynamicMap";

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
      </div>
    </>
  );
}
