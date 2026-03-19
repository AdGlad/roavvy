// apps/web_nextjs/src/app/privacy/page.tsx
// Public page — no auth guard. URL referenced in App Store Connect metadata.

export const metadata = {
  title: "Privacy Policy · Roavvy",
  description: "How Roavvy handles your data.",
};

export default function PrivacyPage() {
  return (
    <main className="max-w-2xl mx-auto px-6 py-12 text-sm leading-relaxed text-gray-800">
      <h1 className="text-2xl font-semibold mb-2">Privacy Policy</h1>
      <p className="text-gray-500 mb-8">Last updated: March 2026</p>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">What Roavvy does</h2>
        <p>
          Roavvy reads the GPS coordinates and timestamps embedded in photos
          already on your device to detect which countries you have visited. It
          builds a personal travel map from this metadata.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">
          What data Roavvy collects
        </h2>
        <ul className="list-disc list-inside space-y-1">
          <li>
            <strong>Country codes</strong> — which countries you have visited,
            derived from photo GPS data (e.g. "GB", "JP").
          </li>
          <li>
            <strong>Visit timestamps</strong> — the earliest and most recent
            date a photo was taken in each country.
          </li>
          <li>
            <strong>Achievement state</strong> — which travel milestones you
            have unlocked.
          </li>
          <li>
            <strong>Anonymous user ID</strong> — a random identifier created on
            first launch, used to associate your data in our cloud database. It
            contains no personal information.
          </li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">
          What Roavvy never collects
        </h2>
        <ul className="list-disc list-inside space-y-1">
          <li>Your photos or any image data.</li>
          <li>
            Precise GPS coordinates — coordinates are used only to resolve the
            country and are discarded immediately after.
          </li>
          <li>Your name, email address, or any contact information.</li>
          <li>Your location in real time.</li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">
          Where your data is stored
        </h2>
        <p className="mb-2">
          Your travel data is stored in two places:
        </p>
        <ul className="list-disc list-inside space-y-1">
          <li>
            <strong>On your device</strong> — in a local SQLite database. This
            is the primary copy and is always available offline.
          </li>
          <li>
            <strong>In Google Firebase (Firestore)</strong> — a cloud database
            used to back up your data and power the optional sharing feature.
            Only the derived metadata listed above is stored here, never photos.
          </li>
        </ul>
        <p className="mt-2">
          Firebase data is stored in data centres operated by Google LLC, which
          may be located outside your country of residence.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">
          Optional Sign in with Apple
        </h2>
        <p>
          You may optionally sign in with Apple to link your travel data to a
          persistent identity. If you do, Apple provides Roavvy with a stable
          anonymous user identifier. Roavvy does not receive your name or Apple
          ID email address unless you explicitly choose to share them.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">Sharing</h2>
        <p>
          If you choose to share your travel map, Roavvy creates a public link
          containing only your visited country list and a count. No name, photo,
          or identifier is included. You can remove this link at any time from
          the Privacy &amp; Account screen.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">Your rights</h2>
        <ul className="list-disc list-inside space-y-1">
          <li>
            <strong>Delete your data</strong> — use "Delete Account" in the
            Privacy &amp; Account screen. This permanently removes all your data
            from both the device and Firebase.
          </li>
          <li>
            <strong>Remove your sharing link</strong> — use "Remove link" in the
            Privacy &amp; Account screen.
          </li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="font-semibold text-base mb-2">Contact</h2>
        <p>
          Questions about this policy? Contact us at{" "}
          <a
            href="mailto:privacy@roavvy.app"
            className="text-blue-600 underline"
          >
            privacy@roavvy.app
          </a>
          .
        </p>
      </section>

      <p className="mt-12 text-gray-400">
        <a href="/" className="hover:underline">
          ← Back to Roavvy
        </a>
      </p>
    </main>
  );
}
