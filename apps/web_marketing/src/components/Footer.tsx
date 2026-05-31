import { Link } from 'react-router-dom'

const SUPPORT_EMAIL = 'admin@roavvy.com'

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
            <p className="text-slate-500 text-sm leading-relaxed">
              Turn your travel photos into a living world map. Discover where you've been, unlock achievements, and wear your journey.
            </p>
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
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="text-white font-semibold text-sm mb-4 tracking-wide">Company</h4>
            <ul className="space-y-3">
              {[
                { to: '/investors', label: 'Investors' },
                { href: `mailto:${SUPPORT_EMAIL}`, label: 'Contact' },
              ].map(({ to, href, label }) =>
                to ? (
                  <li key={to}>
                    <Link to={to} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                      {label}
                    </Link>
                  </li>
                ) : (
                  <li key={label}>
                    <a href={href} className="text-slate-500 hover:text-sky-400 text-sm transition-colors">
                      {label}
                    </a>
                  </li>
                )
              )}
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
            &copy; 2026 Roavvy. All rights reserved.
          </p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="text-slate-600 hover:text-sky-400 text-sm transition-colors"
          >
            {SUPPORT_EMAIL}
          </a>
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
