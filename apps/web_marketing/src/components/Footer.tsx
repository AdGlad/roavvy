import { Link } from 'react-router-dom'

const SUPPORT_EMAIL = 'support@roavvy.com'
const APP_STORE_URL = 'https://apps.apple.com/'

export default function Footer() {
  return (
    <footer className="bg-navy-950 border-t border-slate-800/60 mt-auto">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10">
          {/* Brand */}
          <div className="md:col-span-1">
            <div className="flex items-center gap-2 mb-4">
              <GlobeMini />
              <span className="text-lg font-bold text-white">Roavvy</span>
            </div>
            <p className="text-slate-500 text-sm leading-relaxed mb-5">
              Free AI-powered travel app that turns your photo library into a living world map. Your journey, finally visible.
            </p>
            {/* Payment methods */}
            <p className="text-slate-600 text-xs mb-2">Merchandise payments accepted:</p>
            <div className="flex flex-wrap gap-2 items-center">
              <span className="bg-slate-800 border border-slate-700 rounded px-2 py-0.5 text-slate-400 text-xs font-medium">Visa</span>
              <span className="bg-slate-800 border border-slate-700 rounded px-2 py-0.5 text-slate-400 text-xs font-medium">Mastercard</span>
              <span className="bg-slate-800 border border-slate-700 rounded px-2 py-0.5 text-slate-400 text-xs font-medium">Apple Pay</span>
              <span className="bg-slate-800 border border-slate-700 rounded px-2 py-0.5 text-slate-400 text-xs font-medium">PayPal</span>
            </div>
          </div>

          {/* App */}
          <div>
            <h4 className="text-white font-semibold text-sm mb-4 tracking-wide">App</h4>
            <ul className="space-y-3">
              {[
                { to: '/features', label: 'Features' },
                { to: '/download', label: 'Download' },
                { to: '/support', label: 'Support' },
              ].map(({ to, label }) => (
                <li key={to}>
                  <Link to={to} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                    {label}
                  </Link>
                </li>
              ))}
              <li>
                <span className="text-slate-600 text-xs">Android — coming soon</span>
              </li>
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="text-white font-semibold text-sm mb-4 tracking-wide">Company</h4>
            <ul className="space-y-3">
              {[
                { to: '/about', label: 'About' },
                { to: '/investors', label: 'Investors' },
              ].map(({ to, label }) => (
                <li key={to}>
                  <Link to={to} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                    {label}
                  </Link>
                </li>
              ))}
              <li>
                <a href={`mailto:${SUPPORT_EMAIL}`} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                  Contact
                </a>
              </li>
            </ul>
          </div>

          {/* Legal */}
          <div>
            <h4 className="text-white font-semibold text-sm mb-4 tracking-wide">Legal</h4>
            <ul className="space-y-3">
              {[
                { to: '/privacy', label: 'Privacy Policy' },
                { to: '/terms', label: 'Terms & Conditions' },
                { to: '/refund', label: 'Refund Policy' },
              ].map(({ to, label }) => (
                <li key={to}>
                  <Link to={to} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                    {label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="border-t border-slate-800/60 mt-10 pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-slate-600 text-sm">
            &copy; 2026 Roavvy. All rights reserved. &middot; Free to download and use.
          </p>
          <div className="flex items-center gap-4">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-600 hover:text-sky-400 text-sm transition-colors flex items-center gap-1.5"
            >
              <svg className="w-4 h-4" viewBox="0 0 814 1000" fill="currentColor">
                <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.5 8.2 319.2 8.2 237.2c0-137.7 90-210.4 176-210.4 46.5 0 85.4 30.7 114.9 30.7 28.2 0 71.4-32.5 124.8-32.5 20.3 0 93.7 1.9 156.8 66.8zM586.8 37.9c-6.4 36.5-20.9 72.3-44.2 100.6-23.4 28.5-52.8 49.8-83.3 56.6 0-.6-.1-1.3-.1-1.9 0-35.6 16.1-74.1 38.3-99.7C520.6 65.6 566.4 43 586.8 37.9z" />
              </svg>
              App Store
            </a>
            <a href={`mailto:${SUPPORT_EMAIL}`} className="text-slate-600 hover:text-sky-400 text-sm transition-colors">
              {SUPPORT_EMAIL}
            </a>
          </div>
        </div>
      </div>
    </footer>
  )
}

function GlobeMini() {
  return (
    <svg width="24" height="24" viewBox="0 0 32 32" fill="none">
      <circle cx="16" cy="16" r="12" stroke="#38BDF8" strokeWidth="1.5" fill="none" />
      <ellipse cx="16" cy="16" rx="6" ry="12" stroke="#38BDF8" strokeWidth="1" fill="none" />
      <line x1="4" y1="16" x2="28" y2="16" stroke="#38BDF8" strokeWidth="1" />
      <circle cx="20" cy="11" r="2.5" fill="#FBBF24" />
    </svg>
  )
}
