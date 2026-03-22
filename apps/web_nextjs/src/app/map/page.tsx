"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { signOut } from "firebase/auth";
import { useAuth } from "@/contexts/AuthContext";
import { useUserVisits } from "@/lib/firebase/useUserVisits";
import { auth } from "@/lib/firebase/init";
import DynamicMap from "@/components/DynamicMap";

export default function MapPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();
  const { visitedCodes, loading: visitsLoading, error } = useUserVisits();
  const [geoJsonData, setGeoJsonData] = useState<object | null>(null);
  const [geoError, setGeoError] = useState(false);

  useEffect(() => {
    if (!authLoading && !user) {
      router.push("/sign-in");
    }
  }, [user, authLoading, router]);

  useEffect(() => {
    fetch("/data/countries.geojson")
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load GeoJSON");
        return res.json();
      })
      .then((data) => setGeoJsonData(data))
      .catch(() => setGeoError(true));
  }, []);

  const handleSignOut = async () => {
    await signOut(auth);
    router.push("/sign-in");
  };

  if (authLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p>Loading...</p>
      </main>
    );
  }

  if (!user) return null;

  if (visitsLoading || !geoJsonData) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p>Loading your map...</p>
      </main>
    );
  }

  if (error || geoError) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p>Something went wrong loading your travel data. Please try again.</p>
      </main>
    );
  }

  return (
    <main className="flex flex-col h-screen">
      <header className="flex items-center justify-between px-4 py-3 border-b">
        <div>
          {visitedCodes.length === 0 ? (
            <p className="text-sm text-gray-500">
              No travel data yet. Open the Roavvy app and scan your photos.
            </p>
          ) : (
            <p className="font-medium">{visitedCodes.length} countries visited</p>
          )}
        </div>
        <div className="flex items-center gap-4">
          <Link href="/shop" className="text-sm text-amber-600 font-medium hover:underline">
            Shop
          </Link>
          <button
            onClick={handleSignOut}
            className="text-sm text-gray-600 hover:underline"
          >
            Sign out
          </button>
        </div>
      </header>
      <div className="flex-1">
        <DynamicMap geoJsonData={geoJsonData} userVisits={visitedCodes} />
      </div>
    </main>
  );
}
