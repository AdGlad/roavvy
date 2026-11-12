// Single source of truth for company facts shown across the site.
// Keep these accurate: they are what reviewers (e.g. Google for Startups)
// check against the business email domain and registration records.

export const CONTACT_EMAIL = 'admin@roavvy.com'

// Empty until the app is live: every download button shows "coming soon".
// Set to the App Store listing URL at launch to turn them into links.
export const APP_STORE_URL = ''

export const COMPANY = {
  tradingName: 'Roavvy',
  legalName: 'Christopher Adam Gladstone trading as Roavvy',
  abn: '76 540 390 025',
  location: 'North Curl Curl, NSW, Australia',
  website: 'https://www.roavvy.com',
}

export const FOUNDER = {
  name: 'Adam Gladstone',
  role: 'Founder',
  founded: '2025',
  photo: '/images/founder.jpg',
  bio: [
    'Adam is a technology and startup entrepreneur and a lifelong technologist. As the founder of Roavvy he builds the product end to end — the iOS app, the on-device country detection, and the Google Cloud platform behind it.',
    "He also travels extensively around the world. Roavvy grew out of that: the thousands of photos on his own phone already held a complete record of everywhere he'd been, and no app was using it. Roavvy turns that record into a living travel map — privately, on your own device.",
  ],
  linkedin: 'https://www.linkedin.com/in/adamgladstone/',
}
