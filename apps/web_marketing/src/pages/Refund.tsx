import { LegalPage, Section, ContactBlock } from './Terms'
import { CONTACT_EMAIL } from '../site'

const LAST_UPDATED = '20 November 2026'

export default function Refund() {
  return (
    <LegalPage title="Refund Policy" lastUpdated={LAST_UPDATED}>
      <Section title="1. Overview">
        <p>Roavvy is currently free. The App has no purchases, subscriptions, or in-app payments, so there is nothing to refund today. If you have been charged by anyone claiming to be Roavvy, please contact us at {CONTACT_EMAIL}.</p>
        <p>The sections below describe how refunds will work if we offer personalised merchandise in future, and apply to any order placed through a pre-release test version of the App.</p>
      </Section>

      <Section title="2. Merchandise Orders">
        <p>Personalised physical merchandise (such as t-shirts, prints, and travel products) is produced through third-party print-on-demand providers. Because each item is manufactured specifically for you, we have the following policy:</p>

        <p><strong className="text-white">Custom printed items cannot be returned or refunded simply because:</strong></p>
        <ul>
          <li>You changed your mind after ordering</li>
          <li>You selected the wrong size or colour</li>
          <li>You no longer want the item</li>
        </ul>

        <p>Please review your order carefully before confirming, including size guides, product descriptions, and preview images.</p>
      </Section>

      <Section title="3. Damaged, Defective, or Incorrect Items">
        <p>If your merchandise arrives damaged, defective, or materially different from what you ordered, you are entitled to a replacement or refund. To request a remedy:</p>
        <ul>
          <li>Contact us within 14 days of receiving your order</li>
          <li>Provide your order reference number</li>
          <li>Include clear photographs showing the issue</li>
          <li>Email us at {CONTACT_EMAIL}</li>
        </ul>
        <p>We will assess your claim and, where valid, arrange a replacement or refund. Roavvy reserves the right to request the return of the defective item before issuing a remedy, though in most cases this is not required.</p>
      </Section>

      <Section title="4. Delivery Issues">
        <p>If your order has not arrived within the estimated delivery window, please contact us at {CONTACT_EMAIL} with your order reference. We will investigate with the fulfilment provider and arrange a replacement or refund if the order is confirmed lost in transit.</p>
        <p>Roavvy is not liable for delivery delays caused by customs, weather, or other circumstances beyond our control. Delivery estimates are provided in good faith but are not guaranteed.</p>
      </Section>

      <Section title="5. How to Contact Us">
        <p>For all refund requests, order queries, or disputes, please contact us at:</p>
        <ContactBlock />
        <p className="mt-4">Please include your order reference number, a description of the issue, and (where applicable) photographs. We aim to respond to all queries within 5 business days.</p>
      </Section>
    </LegalPage>
  )
}
