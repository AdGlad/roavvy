"use client";

import { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { useAuth } from "@/contexts/AuthContext";
import { db } from "@/lib/firebase/init";
import { effectiveVisits } from "./effectiveVisits";

export const useUserVisits = () => {
  const { user, loading: authLoading } = useAuth();
  const [visitedCodes, setVisitedCodes] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (authLoading) return;

    if (!user) {
      setVisitedCodes([]);
      setLoading(false);
      return;
    }

    const fetchVisits = async () => {
      setLoading(true);
      setError(null);
      try {
        const uid = user.uid;
        const [inferredSnap, addedSnap, removedSnap] = await Promise.all([
          getDocs(collection(db, `users/${uid}/inferred_visits`)),
          getDocs(collection(db, `users/${uid}/user_added`)),
          getDocs(collection(db, `users/${uid}/user_removed`)),
        ]);

        const inferred = inferredSnap.docs.map((d) => d.id);
        const added = addedSnap.docs.map((d) => d.id);
        const removed = removedSnap.docs.map((d) => d.id);

        setVisitedCodes(effectiveVisits(inferred, added, removed));
      } catch (err) {
        setError("Failed to load travel data.");
      } finally {
        setLoading(false);
      }
    };

    fetchVisits();
  }, [user, authLoading]);

  return { visitedCodes, loading, error };
};
