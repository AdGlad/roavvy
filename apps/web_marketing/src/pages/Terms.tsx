const SUPPORT_EMAIL = 'admin@roavvy.com'
const LAST_UPDATED = '1 June 2026'

export default function Terms() {
  return (
    <LegalPage title="Terms and Conditions" lastUpdated={LAST_UPDATED}>
      <Disclaimer />

      <Section title="1. Acceptance of Terms">
        <p>By downloading, installing, or using the Roavvy application ("App") or accessing the Roavvy website at www.roavvy.com ("Website"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, do not use the App or Website.</p>
        <p>These Terms constitute a legally binding agreement between you and Roavvy ("we", "our", or "us"). We reserve the right to update these Terms at any time. Continued use of the App after changes are posted constitutes acceptance of the revised Terms.</p>
      </Section>

      <Section title="2. App Usage">
        <p>Roavvy grants you a limited, non-exclusive, non-transferable, revocable licence to use the App for personal, non-commercial purposes in accordance with these Terms.</p>
        <p>You agree not to:</p>
        <ul>
          <li>Copy, modify, or distribute the App or any portion of it</li>
          <li>Reverse engineer, decompile, or disassemble the App</li>
          <li>Use the App for any unlawful purpose</li>
          <li>Attempt to gain unauthorised access to any portion of the App or its systems</li>
          <li>Use automated tools to scrape, crawl, or extract data from the App</li>
        </ul>
      </Section>

      <Section title="3. User Accounts">
        <p>Some features of Roavvy may require you to create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.</p>
        <p>You agree to provide accurate, current, and complete information when creating an account. We reserve the right to terminate accounts that violate these Terms or that have been inactive for an extended period.</p>
      </Section>

      <Section title="4. Photo Metadata Scanning">
        <p>Roavvy requests access to your device's photo library in order to read GPS coordinates embedded in photo metadata. This process occurs entirely on your device. No photos or photo content are uploaded to our servers.</p>
        <p>Only derived metadata — such as GPS coordinates used to determine countries visited — may be processed or stored. By granting photo library access, you authorise Roavvy to perform this on-device scan.</p>
        <p>You may revoke photo library access at any time through your device's privacy settings.</p>
      </Section>

      <Section title="5. Privacy and Data Handling">
        <p>Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. Please review our Privacy Policy at www.roavvy.com/privacy.</p>
        <p>We are committed to handling your personal data in accordance with applicable data protection laws, including the General Data Protection Regulation (GDPR) where applicable.</p>
      </Section>

      <Section title="6. User-Generated Content">
        <p>The App may allow you to create, save, and share content such as travel maps, achievement cards, and challenge results ("User Content"). You retain ownership of any User Content you create.</p>
        <p>By sharing User Content through the App's features, you grant Roavvy a limited licence to display and distribute that content as part of the normal operation of the App's sharing features. We do not claim ownership of your User Content.</p>
      </Section>

      <Section title="7. Merchandise and Print-on-Demand Products">
        <p>Roavvy offers personalised merchandise through third-party print-on-demand providers. When you place an order, you are purchasing a physical product manufactured by our fulfilment partner.</p>
        <p>Merchandise orders are subject to additional terms from the relevant fulfilment provider. Roavvy acts as an intermediary and is not responsible for manufacturing defects beyond what is covered in our Refund Policy at www.roavvy.com/refund.</p>
        <p>Delivery times, shipping costs, and customs charges are determined by the fulfilment provider and may vary by location.</p>
      </Section>

      <Section title="8. Payments, Refunds, and Fulfilment">
        <p>In-app purchases and subscriptions are processed through the Apple App Store and are subject to Apple's payment terms. Refunds for App Store purchases must be requested directly through Apple.</p>
        <p>Refunds for merchandise orders are governed by our Refund Policy at www.roavvy.com/refund. Custom printed products cannot be returned unless damaged, defective, or incorrect.</p>
      </Section>

      <Section title="9. Intellectual Property">
        <p>All intellectual property in the App, including the design, graphics, source code, and brand identity, is owned by or licensed to Roavvy. Nothing in these Terms grants you any right to use our trademarks, logos, or brand elements without our prior written consent.</p>
        <p>The Roavvy name, logo, and visual identity are proprietary to Roavvy and may not be used without written permission.</p>
      </Section>

      <Section title="10. Prohibited Use">
        <p>You must not use the App or Website to:</p>
        <ul>
          <li>Violate any applicable law or regulation</li>
          <li>Infringe the intellectual property rights of any person</li>
          <li>Transmit unsolicited commercial communications</li>
          <li>Introduce malware, viruses, or harmful code</li>
          <li>Engage in data mining or scraping without our express consent</li>
          <li>Impersonate any person or misrepresent your affiliation with any entity</li>
        </ul>
      </Section>

      <Section title="11. Limitation of Liability">
        <p>To the maximum extent permitted by applicable law, Roavvy and its affiliates, officers, employees, and partners shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App or Website.</p>
        <p>Our total liability for any claim arising out of these Terms shall not exceed the amount you paid to us in the twelve months preceding the claim, or £50 (whichever is greater).</p>
        <p>Nothing in these Terms limits liability for death or personal injury caused by negligence, fraud, or any other liability that cannot be excluded by law.</p>
      </Section>

      <Section title="12. Changes to the Service">
        <p>We reserve the right to modify, suspend, or discontinue any part of the App or Website at any time, with or without notice. We are not liable to you or any third party for any modification, suspension, or discontinuation of the service.</p>
      </Section>

      <Section title="13. Governing Law">
        <p>These Terms are governed by and construed in accordance with the laws of England and Wales. Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of the courts of England and Wales.</p>
      </Section>

      <Section title="14. Contact">
        <p>If you have any questions about these Terms, please contact us at:</p>
        <ContactBlock />
      </Section>
    </LegalPage>
  )
}

// ── Shared legal components ───────────────────────────────────────────────────

export function LegalPage({ title, lastUpdated, children }: { title: string; lastUpdated: string; children: React.ReactNode }) {
  return (
    <>
      <section className="bg-navy-900 pt-16 pb-16 text-center">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <span className="section-label">Legal</span>
          <h1 className="section-heading text-4xl md:text-5xl">{title}</h1>
          <p className="text-slate-600 text-sm mt-4">Last updated: {lastUpdated}</p>
        </div>
      </section>

      <section className="bg-navy-950 py-16">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="prose prose-invert prose-slate max-w-none space-y-8">
            {children}
          </div>
        </div>
      </section>
    </>
  )
}

export function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="border-t border-slate-800/60 pt-8">
      <h2 className="text-xl font-bold text-white mb-4">{title}</h2>
      <div className="space-y-3 text-slate-400 text-sm leading-relaxed [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:space-y-1.5">
        {children}
      </div>
    </div>
  )
}

export function Disclaimer() {
  return (
    <div className="bg-amber-400/10 border border-amber-400/20 rounded-xl p-5 mb-8">
      <p className="text-amber-300 text-sm leading-relaxed">
        <strong className="text-amber-200">Legal disclaimer:</strong> This page is provided for general information purposes and should be reviewed by a qualified legal professional before publication. It does not constitute legal advice.
      </p>
    </div>
  )
}

export function ContactBlock() {
  return (
    <div className="bg-navy-800 rounded-xl border border-slate-800 p-5 mt-4">
      <p className="text-slate-300 text-sm">
        <strong className="text-white">Roavvy</strong><br />
        Email: <a href={`mailto:${SUPPORT_EMAIL}`} className="text-sky-400 hover:text-sky-300 transition-colors">{SUPPORT_EMAIL}</a><br />
        Website: <a href="https://www.roavvy.com" className="text-sky-400 hover:text-sky-300 transition-colors">www.roavvy.com</a>
      </p>
    </div>
  )
}
