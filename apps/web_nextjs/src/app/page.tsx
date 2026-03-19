"use client";

import { useAuth } from "@/contexts/AuthContext";

export default function Home() {
  const { user, loading, signOut } = useAuth();

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <h1 className="text-4xl font-bold mb-8">Hello, Roavvy!</h1>

      {loading ? (
        <p>Loading...</p>
      ) : user ? (
        <div className="flex flex-col items-center gap-4">
          <p>Welcome, user!</p>
          <p className="text-sm text-gray-500">UID: {user.uid}</p>
          <button
            onClick={signOut}
            className="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
          >
            Sign Out
          </button>
        </div>
      ) : (
        <p className="text-gray-500">Not signed in.</p>
      )}
    </main>
  );
}

