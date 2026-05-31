import { LegalPage, Section, Disclaimer, ContactBlock } from './Terms'

const LAST_UPDATED = '1 June 2026'

export default function Refund() {
  return (
    <LegalPage title="Refund Policy" lastUpdated={LAST_UPDATED}>
      <Disclaimer />

      <Section title="1. Overview">
        <p>This Refund Policy covers two separate purchasing channels available through Roavvy: digital purchases through the Apple App Store, and physical merchandise ordered through our print-on-demand service. Different refund rules apply to each channel.</p>
      </Section>

      <Section title="2. Digital Purchases and Subscriptions (Apple App Store)">
        <p>All in-app purchases, subscriptions, and premium feature unlocks are processed directly by Apple through the App Store. Roavvy does not process or store payment card details.</p>
        <p><strong className="text-white">Refund requests for App Store purchases must be made directly to Apple:</strong></p>
        <ul>
          <li>Visit reportaproblem.apple.com</li>
          <li>Sign in with your Apple ID</li>
          <li>Find the purchase and select "Request a Refund"</li>
          <li>Follow Apple's refund process</li>
        </ul>
        <p>Apple's refund decisions are made in accordance with Apple's own refund policy. Roavvy cannot process or override App Store refunds.</p>
      </Section>

      <Section title="3. Subscription Cancellations">
        <p>You may cancel your Roavvy subscription at any time through the App Store subscription management settings on your device. Cancellation takes effect at the end of the current billing period. You will continue to have access to premium features until the end of the paid period.</p>
        <p>We do not offer pro-rata refunds for unused subscription time.</p>
      </Section>

      <Section title="4. Merchandise Orders">
        <p>Roavvy offers personalised physical merchandise (such as t-shirts, prints, and travel products) produced through third-party print-on-demand providers. Because each item is manufactured specifically for you, we have the following policy:</p>

        <p><strong className="text-white">Custom printed items cannot be returned or refunded simply because:</strong></p>
        <ul>
          <li>You changed your mind after ordering</li>
          <li>You selected the wrong size or colour</li>
          <li>You no longer want the item</li>
        </ul>

        <p>Please review your order carefully before confirming, including size guides, product descriptions, and preview images.</p>
      </Section>

      <Section title="5. Damaged, Defective, or Incorrect Items">
        <p>If your merchandise arrives damaged, defective, or materially different from what you ordered, you are entitled to a replacement or refund. To request a remedy:</p>
        <ul>
          <li>Contact us within 14 days of receiving your order</li>
          <li>Provide your order reference number</li>
          <li>Include clear photographs showing the issue</li>
          <li>Email us at admin@roavvy.com</li>
        </ul>
        <p>We will assess your claim and, where valid, arrange a replacement or refund. Roavvy reserves the right to request the return of the defective item before issuing a remedy, though in most cases this is not required.</p>
      </Section>

      <Section title="6. Delivery Issues">
        <p>If your order has not arrived within the estimated delivery window, please contact us at admin@roavvy.com with your order reference. We will investigate with the fulfilment provider and arrange a replacement or refund if the order is confirmed lost in transit.</p>
        <p>Roavvy is not liable for delivery delays caused by customs, weather, or other circumstances beyond our control. Delivery estimates are provided in good faith but are not guaranteed.</p>
      </Section>

      <Section title="7. How to Contact Us">
        <p>For all refund requests, order queries, or disputes, please contact us at:</p>
        <ContactBlock />
        <p className="mt-4">Please include your order reference number, a description of the issue, and (where applicable) photographs. We aim to respond to all queries within 5 business days.</p>
      </Section>
    </LegalPage>
  )
}
