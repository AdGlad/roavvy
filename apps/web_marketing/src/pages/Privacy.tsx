import { LegalPage, Section, ContactBlock } from './Terms'

const LAST_UPDATED = '1 June 2026'

export default function Privacy() {
  return (
    <LegalPage title="Privacy Policy" lastUpdated={LAST_UPDATED}>
      <Section title="1. Introduction">
        <p>Roavvy ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and protect your information when you use the Roavvy app ("App") and website at www.roavvy.com.</p>
        <p>We are committed to handling your personal data in accordance with applicable data protection laws, including the Australian Privacy Act 1988 (Cth).</p>
      </Section>

      <Section title="2. On-Device Photo Scanning">
        <p>Roavvy's core feature is the on-device scanning of GPS coordinates from your photo library. This means:</p>
        <ul>
          <li>Your photos are <strong>never uploaded</strong> to our servers or any third-party server</li>
          <li>Only GPS coordinate metadata is read — not photo content, faces, or personal details</li>
          <li>Country detection is performed entirely on your device</li>
          <li>You remain in control of photo library access and can revoke it at any time</li>
        </ul>
        <p>The App requests iOS photo library permission. You may grant full or limited access. Revoking access in your device's Settings will prevent future scans.</p>
      </Section>

      <Section title="3. Information We Collect">
        <p><strong className="text-white">On-device data (not transmitted):</strong></p>
        <ul>
          <li>GPS coordinates extracted from photo metadata</li>
          <li>Detected countries and regions</li>
          <li>Travel scan history and timestamps</li>
        </ul>
        <p><strong className="text-white">Data that may be stored or transmitted:</strong></p>
        <ul>
          <li>Derived travel data (country codes, visit dates) — used to power the map and achievements</li>
          <li>Anonymous usage analytics — used to improve the App (if applicable)</li>
          <li>Account information if you create an account (email, display name)</li>
          <li>Merchandise order details if you place an order (name, delivery address)</li>
        </ul>
      </Section>

      <Section title="4. How We Use Your Information">
        <p>We use the information we collect to:</p>
        <ul>
          <li>Provide and improve the App and its features</li>
          <li>Display your personal travel map and achievements</li>
          <li>Process merchandise orders and fulfilment</li>
          <li>Respond to support requests</li>
          <li>Comply with legal obligations</li>
        </ul>
        <p>We do not sell your personal data to third parties. We do not use your location history for advertising.</p>
      </Section>

      <Section title="5. Firebase Services">
        <p>Roavvy uses Firebase, a platform provided by Google LLC, for authentication, database, and cloud storage services. Firebase may process personal data on our behalf in accordance with Google's Privacy Policy. We use Firebase in a manner designed to minimise data exposure.</p>
        <p>For more information, see Google's Privacy Policy at policies.google.com/privacy.</p>
      </Section>

      <Section title="6. Apple App Store">
        <p>Roavvy is distributed through the Apple App Store. Apple may collect data about your device and app usage in accordance with Apple's Privacy Policy. In-app purchases are processed by Apple. We do not receive payment card details.</p>
        <p>For more information, see Apple's Privacy Policy at apple.com/legal/privacy.</p>
      </Section>

      <Section title="7. Merchandise and Print-on-Demand">
        <p>If you order merchandise through Roavvy, your order details (name, delivery address, email) are shared with our print-on-demand fulfilment provider solely for the purpose of manufacturing and delivering your order. We select fulfilment partners who maintain appropriate data protection standards.</p>
        <p>Fulfilment partners are not permitted to use your data for marketing or any purpose other than order fulfilment.</p>
      </Section>

      <Section title="8. Your Rights">
        <p>You have the following rights regarding your personal data:</p>
        <ul>
          <li><strong className="text-white">Access:</strong> Request a copy of the personal data we hold about you</li>
          <li><strong className="text-white">Correction:</strong> Request correction of inaccurate personal data</li>
          <li><strong className="text-white">Deletion:</strong> Request deletion of your personal data ("right to be forgotten")</li>
          <li><strong className="text-white">Portability:</strong> Request your data in a machine-readable format</li>
          <li><strong className="text-white">Objection:</strong> Object to certain uses of your personal data</li>
        </ul>
        <p>To exercise any of these rights, contact us at the address below. We will respond within 30 days.</p>
      </Section>

      <Section title="9. Data Retention">
        <p>We retain your personal data only for as long as necessary to provide the App's services or as required by law. You may request deletion of your account and associated data at any time by contacting us.</p>
      </Section>

      <Section title="10. Security">
        <p>We implement appropriate technical and organisational measures to protect your personal data from unauthorised access, disclosure, or loss. However, no method of data transmission or storage is 100% secure.</p>
      </Section>

      <Section title="11. Children's Privacy">
        <p>Roavvy is not directed at children under the age of 13. We do not knowingly collect personal data from children under 13. If you believe a child has provided us with personal data, please contact us and we will delete it promptly.</p>
      </Section>

      <Section title="12. Changes to This Policy">
        <p>We may update this Privacy Policy from time to time. When we do, we will post the updated policy on this page with a new "Last updated" date. Continued use of the App after changes are posted constitutes acceptance of the revised policy.</p>
      </Section>

      <Section title="13. Contact">
        <p>If you have questions, concerns, or requests regarding this Privacy Policy, please contact us at:</p>
        <ContactBlock />
      </Section>
    </LegalPage>
  )
}
