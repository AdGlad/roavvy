const SUPPORT_EMAIL = 'support@roavvy.com'

const topics = [
  {
    icon: '⬇️',
    title: 'App download and installation',
    faqs: [
      {
        q: 'Where can I download Roavvy?',
        a: 'Roavvy is available free on the Apple App Store. Search for "Roavvy" or tap the Download button on our website at roavvy.com/download. iOS 16.0 or later is required.',
      },
      {
        q: 'What iOS version is required?',
        a: 'Roavvy requires iOS 16.0 or later. It is compatible with iPhone and iPad. We recommend keeping your device updated to the latest iOS version for the best experience.',
      },
      {
        q: 'Is Roavvy available on Android?',
        a: 'Roavvy is currently iOS-only. Android support is on our roadmap. Sign up via the app or follow us for updates when Android launches.',
      },
      {
        q: "The app won't install on my device",
        a: 'Make sure your device is running iOS 16.0 or later. Try restarting your device and attempting the download again. If the issue continues, check that you have sufficient storage space and a stable internet connection, then contact us if it still does not resolve.',
      },
    ],
  },
  {
    icon: '📸',
    title: 'Photo scanning',
    faqs: [
      {
        q: 'Why does Roavvy need photo library access?',
        a: 'Roavvy reads GPS coordinates embedded in your photo metadata to detect the countries you have visited. It does not access photo content, faces, or any visual data — only location coordinates. Your photos are never uploaded anywhere.',
      },
      {
        q: 'How long does scanning take?',
        a: 'Scanning 2,000 photos typically takes 10–30 seconds depending on your device. Larger libraries may take a little longer on the first scan. All subsequent scans are incremental and significantly faster.',
      },
      {
        q: 'Not all my countries are showing up',
        a: 'Countries are detected using GPS coordinates embedded in your photos. If a trip is missing, those photos may not have had location services enabled at the time. You can manually add or edit countries directly in the app. Make sure photo library access is set to "Full Access" in Settings > Privacy & Security > Photos > Roavvy.',
      },
      {
        q: "My recent photos haven't been detected",
        a: 'Tap "Rescan" in the app to pick up newly added photos. If photos are still missing, check that location services were enabled on your camera at the time of the trip, and that Roavvy has Full Access to your photo library in your device settings.',
      },
    ],
  },
  {
    icon: '🔒',
    title: 'Privacy and data',
    faqs: [
      {
        q: 'Are my photos uploaded to any server?',
        a: 'No. Roavvy reads GPS metadata entirely on your device. Your photos never leave your phone — not even as thumbnails, previews, or compressed copies. This is a core design principle, not an afterthought.',
      },
      {
        q: 'What data does Roavvy store?',
        a: 'Roavvy stores derived travel data (country codes and visit dates) locally on your device. If you create an account, this data may be synced securely to your account for backup. No photo content, images, or raw GPS tracks are ever stored or transmitted.',
      },
      {
        q: 'How do I delete my travel data?',
        a: 'You can delete all your travel history from Settings within the app. To permanently delete your account and all associated data, email us at support@roavvy.com and we will process the deletion within 30 days, in line with your rights under GDPR.',
      },
      {
        q: 'Does Roavvy share my location history?',
        a: 'No. Roavvy does not share, sell, or transmit your location history to any third party, including advertisers. Your travel data is private by design and is never used for targeted advertising.',
      },
    ],
  },
  {
    icon: '👕',
    title: 'Merchandise and orders',
    faqs: [
      {
        q: 'How do I order a personalised t-shirt?',
        a: 'Open the Merch section in the app, choose a design generated from your visited countries, select your size and product type, and complete checkout. Your order is sent directly to our print-on-demand fulfilment partner for production.',
      },
      {
        q: 'How long does delivery take?',
        a: 'Most orders are delivered within 7–14 business days. International orders may take slightly longer depending on your location and local customs. You will receive a tracking number by email once your order ships.',
      },
      {
        q: 'Can I change or cancel my order?',
        a: 'Orders can be changed or cancelled within 1 hour of placing them by contacting us immediately at support@roavvy.com. After production has started, we are unable to modify orders as each item is printed specifically for you.',
      },
      {
        q: 'My order arrived damaged or incorrect',
        a: "We're sorry to hear that. Please email support@roavvy.com within 14 days of receiving your order, including your order reference number and clear photos of the issue. We will arrange a replacement or full refund promptly.",
      },
    ],
  },
  {
    icon: '💳',
    title: 'Payments and billing',
    faqs: [
      {
        q: 'Is Roavvy free?',
        a: 'Yes — Roavvy is completely free to download and use. There are no subscription tiers, no premium features, and no paywalls. Every feature in the app is available to all users at no cost.',
      },
      {
        q: 'How do I pay for merchandise?',
        a: 'Merchandise orders are paid for at checkout within the app. We accept Visa, Mastercard, American Express, Apple Pay, and PayPal. All payments are processed securely — we do not store your card details.',
      },
      {
        q: 'I was charged for an order I didn\'t place',
        a: 'If you see an unexpected charge, please contact us immediately at support@roavvy.com with your order reference (if you have it) and we will investigate and resolve the issue as quickly as possible.',
      },
      {
        q: 'Are there any hidden fees?',
        a: 'No. The app is free. For merchandise, the price shown at checkout is the total you pay — including production and shipping. No hidden fees are added after you place your order.',
      },
    ],
  },
  {
    icon: '🐛',
    title: 'Bug reports',
    faqs: [
      {
        q: 'The app crashed or froze',
        a: 'Force-close the app by swiping it away in the app switcher, then reopen it. If the issue persists, restart your device. Please email us at support@roavvy.com with your device model, iOS version, and a description of what you were doing when it crashed.',
      },
      {
        q: 'A feature is not working as expected',
        a: 'First check that you are running the latest version of Roavvy from the App Store. If the issue continues, contact support with a clear description of the feature, what you expected to happen, and what actually happened.',
      },
      {
        q: 'I found an incorrect country detection',
        a: "Country detection relies on GPS data embedded in your photos at the time they were taken. If a country has been incorrectly assigned, you can edit it manually in the app. If you believe there is a systematic error, please report it to support@roavvy.com so we can investigate.",
      },
      {
        q: 'How do I report a bug?',
        a: 'Email support@roavvy.com with your device model, iOS version, a clear description of the bug, and the steps needed to reproduce it. Screenshots or a short screen recording are extremely helpful and speed up our investigation significantly.',
      },
    ],
  },
]

export default function Support() {
  return (
    <>
      <section className="bg-navy-900 pt-16 pb-24 text-center">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <span className="section-label">Support</span>
          <h1 className="section-heading text-4xl md:text-5xl">How can we help?</h1>
          <p className="section-subheading">
            Find answers to common questions below, or reach us directly by email — we aim to reply within one business day.
          </p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="btn-primary mt-8 text-base px-8 py-4 inline-flex"
          >
            <EmailIcon />
            {SUPPORT_EMAIL}
          </a>
        </div>
      </section>

      <section className="bg-navy-950 py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 space-y-16">
          {topics.map(({ icon, title, faqs }) => (
            <div key={title}>
              <div className="flex items-center gap-3 mb-8">
                <span className="text-3xl">{icon}</span>
                <h2 className="text-xl font-bold text-white">{title}</h2>
              </div>
              <div className="space-y-3">
                {faqs.map(({ q, a }) => (
                  <details
                    key={q}
                    className="group bg-navy-900 border border-slate-800 rounded-xl overflow-hidden"
                  >
                    <summary className="flex items-center justify-between gap-4 px-6 py-5 cursor-pointer list-none hover:bg-navy-800/60 transition-colors">
                      <span className="text-white font-medium text-sm">{q}</span>
                      <svg
                        className="w-4 h-4 text-slate-500 shrink-0 transition-transform group-open:rotate-180"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                      </svg>
                    </summary>
                    <div className="px-6 pb-5 pt-1 text-slate-400 text-sm leading-relaxed border-t border-slate-800/60">
                      {a}
                    </div>
                  </details>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="bg-navy-900 py-20 text-center">
        <div className="max-w-xl mx-auto px-4">
          <div className="text-5xl mb-6">✉️</div>
          <h2 className="text-2xl font-bold text-white mb-4">Still need help?</h2>
          <p className="text-slate-400 text-sm leading-relaxed mb-8">
            Send us an email and we'll get back to you within one business day. Please include your device model, iOS version, and a description of the issue.
          </p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="btn-primary text-base px-8 py-4 inline-flex"
          >
            <EmailIcon />
            Email {SUPPORT_EMAIL}
          </a>
        </div>
      </section>
    </>
  )
}

function EmailIcon() {
  return (
    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
    </svg>
  )
}
