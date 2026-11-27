import { LegalPage, Section, ContactBlock } from './Terms'

const LAST_UPDATED = '26 November 2026'

export default function Privacy() {
  return (
    <LegalPage title="Privacy Policy" lastUpdated={LAST_UPDATED}>
      <Section title="1. Introduction">
        <p>Roavvy ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and protect your information when you use the Roavvy app ("App") and website at www.roavvy.com.</p>
        <p>We are committed to handling your personal data in accordance with applicable data protection laws, including the Australian Privacy Act 1988 (Cth).</p>
      </Section>

      <Section title="2. On-Device Photo Scanning">
        <p>Roavvy's core feature is an on-device scan of your photo library. This means:</p>
        <ul>
          <li>Your photos are <strong>never uploaded</strong> to our servers or any third-party server</li>
          <li>Only the location (GPS coordinates) and date stored in each photo's metadata are read, not the photo content, faces, or other personal details</li>
          <li>Working out which countries you visited happens entirely on your device</li>
          <li>You remain in control of photo library access and can revoke it at any time</li>
        </ul>
        <p>The App requests iOS photo library permission. You may grant full or limited access. Revoking access in your device's Settings will prevent future scans.</p>
      </Section>

      <Section title="3. Information We Collect">
        <p><strong className="text-white">Kept on your device only (never sent to us):</strong></p>
        <ul>
          <li>Your photos</li>
          <li>GPS coordinates read from photo metadata</li>
          <li>Your device's current location, if you allow location access (see section 4)</li>
        </ul>
        <p><strong className="text-white">Stored with your account and synced to our servers:</strong></p>
        <ul>
          <li><strong className="text-white">Travel data:</strong> the countries you have visited, the dates of your first and last visit, your trips (country, start and end dates), and the number of photos found for each. This is country-level information only, never GPS coordinates.</li>
          <li><strong className="text-white">Achievements and travel cards:</strong> the achievements you unlock and the travel cards you create</li>
          <li><strong className="text-white">World Leap game results:</strong> for each game you play, the date, your score, and the countries in that game</li>
          <li><strong className="text-white">Account identifiers:</strong> a unique user ID, created even if you continue without signing in</li>
          <li><strong className="text-white">Email address:</strong> if you sign in with email, Apple, Google, or Facebook</li>
        </ul>
        <p><strong className="text-white">Diagnostics:</strong> if the App crashes, a crash report (device model, operating system version, and technical details of the error) is sent to help us fix the problem. Crash reports are not linked to your account.</p>
        <p>We do not collect your name, phone number, contacts, photos, browsing history, or payment information, and the App contains no advertising or analytics tracking.</p>
      </Section>

      <Section title="4. Location Access">
        <p>The optional UNESCO Nearby feature asks for access to your device's location so it can show World Heritage Sites near you and how far away they are. Your location is used on your device only. It is not sent to us or stored.</p>
      </Section>

      <Section title="5. How We Use Your Information">
        <p>We use the information we collect to:</p>
        <ul>
          <li>Show your personal travel map, trips, and achievements</li>
          <li>Save your World Leap game results</li>
          <li>Keep your travel data safe if you change or reinstall your phone</li>
          <li>Sign you in to your account</li>
          <li>Fix crashes and improve the App</li>
          <li>Respond to support requests</li>
          <li>Comply with legal obligations</li>
        </ul>
        <p>We do not sell your personal data. We do not use your data for advertising, and we do not track you across other companies' apps or websites.</p>
      </Section>

      <Section title="6. Sharing Your Map">
        <p>Map sharing links are not currently available in the App. If you created a sharing link in an earlier version, anyone with that link can see the list of countries you have visited and the number of countries. You can remove it at any time from Privacy &amp; account in the App, and it is removed automatically if you delete your account.</p>
      </Section>

      <Section title="7. Service Providers">
        <p>We use the following providers to run the App. They process data on our behalf and only for the purposes described here:</p>
        <ul>
          <li><strong className="text-white">Google Firebase</strong> (Google LLC): sign-in (Firebase Authentication), storing and syncing your travel data (Cloud Firestore and Cloud Functions), app security (App Check), app settings (Remote Config), and crash reports (Crashlytics). See policies.google.com/privacy.</li>
          <li><strong className="text-white">Sign in with Apple, Google Sign-In, and Facebook Login</strong>, if you choose one of them to sign in. The provider shares your email address with us and handles your sign-in under its own privacy policy.</li>
        </ul>
        <p>Suggested titles for travel cards are created by Apple's on-device intelligence. This happens on your device and nothing is sent to us or to any AI service.</p>
        <p>Images of World Heritage Sites are loaded from UNESCO's website (whc.unesco.org). When an image loads, UNESCO receives your device's IP address, as with any website.</p>
      </Section>

      <Section title="8. Where Your Data Is Stored">
        <p>Our service providers, including Google Firebase, may store and process your data outside Australia, including in the United States. We use providers that apply appropriate security and privacy protections to that data.</p>
      </Section>

      <Section title="9. Apple App Store">
        <p>Roavvy is distributed through the Apple App Store. Apple may collect data about your device and app usage in accordance with Apple's Privacy Policy. The App does not currently offer in-app purchases, and we do not receive payment card details.</p>
        <p>For more information, see Apple's Privacy Policy at apple.com/legal/privacy.</p>
      </Section>

      <Section title="10. Merchandise">
        <p>Roavvy does not currently sell merchandise and does not collect names, delivery addresses, or order details. If we offer merchandise in future, we will update this policy before collecting any order information, including which fulfilment partners receive it and why.</p>
      </Section>

      <Section title="11. Deleting Your Account">
        <p>You can delete your account in the App at any time: on the Map tab, open the menu (⋮), choose <strong className="text-white">Privacy &amp; account</strong>, then <strong className="text-white">Delete account</strong>. This deletes your account, the travel data stored with it, and any sharing link, and clears the travel data saved on your device.</p>
        <p>You can also ask us to delete your data by contacting us at the address below.</p>
      </Section>

      <Section title="12. Your Rights">
        <p>You have the following rights regarding your personal data:</p>
        <ul>
          <li><strong className="text-white">Access:</strong> Request a copy of the personal data we hold about you</li>
          <li><strong className="text-white">Correction:</strong> Request correction of inaccurate personal data</li>
          <li><strong className="text-white">Deletion:</strong> Delete your account in the App, or ask us to delete your personal data</li>
          <li><strong className="text-white">Portability:</strong> Request your data in a machine-readable format</li>
          <li><strong className="text-white">Objection:</strong> Object to certain uses of your personal data</li>
        </ul>
        <p>To exercise any of these rights, contact us at the address below. We will respond within 30 days.</p>
      </Section>

      <Section title="13. Data Retention">
        <p>We keep your personal data only while your account exists, or for as long as required by law. When you delete your account, your data is deleted. Crash reports are kept for a limited period by Firebase Crashlytics and then deleted automatically.</p>
      </Section>

      <Section title="14. Security">
        <p>We implement appropriate technical and organisational measures to protect your personal data from unauthorised access, disclosure, or loss. However, no method of data transmission or storage is 100% secure.</p>
      </Section>

      <Section title="15. Children's Privacy">
        <p>Roavvy is not directed at children under the age of 13. We do not knowingly collect personal data from children under 13. If you believe a child has provided us with personal data, please contact us and we will delete it promptly.</p>
      </Section>

      <Section title="16. Changes to This Policy">
        <p>We may update this Privacy Policy from time to time. When we do, we will post the updated policy on this page with a new "Last updated" date. Continued use of the App after changes are posted constitutes acceptance of the revised policy.</p>
      </Section>

      <Section title="17. Contact">
        <p>If you have questions, concerns, or requests regarding this Privacy Policy, please contact us at:</p>
        <ContactBlock />
      </Section>
    </LegalPage>
  )
}
