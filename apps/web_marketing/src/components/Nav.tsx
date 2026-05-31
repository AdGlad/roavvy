import { useState } from 'react'
import { Link, NavLink } from 'react-router-dom'

const APP_STORE_URL = 'https://apps.apple.com/'

const links = [
  { to: '/', label: 'Home', exact: true },
  { to: '/features', label: 'Features' },
  { to: '/download', label: 'Download' },
  { to: '/investors', label: 'Investors' },
  { to: '/support', label: 'Support' },
]

export default function Nav() {
  const [open, setOpen] = useState(false)

  return (
    <header className="fixed top-0 inset-x-0 z-50 bg-navy-900/90 backdrop-blur-md border-b border-slate-800/60">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2.5 group">
            <GlobeLogo />
            <span className="text-xl font-bold text-white tracking-tight group-hover:text-sky-400 transition-colors">
              Roavvy
            </span>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden md:flex items-center gap-1">
            {links.map(({ to, label, exact }) => (
              <NavLink
                key={to}
                to={to}
                end={exact}
                className={({ isActive }) =>
                  `px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                    isActive
                      ? 'text-sky-400 bg-sky-400/10'
                      : 'text-slate-400 hover:text-white hover:bg-white/5'
                  }`
                }
              >
                {label}
              </NavLink>
            ))}
          </nav>

          {/* Desktop CTA */}
          <div className="hidden md:flex items-center gap-3">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary text-sm py-2 px-4"
            >
              <AppleIcon />
              Download
            </a>
          </div>

          {/* Mobile hamburger */}
          <button
            onClick={() => setOpen(!open)}
            className="md:hidden p-2 rounded-lg text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
            aria-label="Toggle menu"
          >
            {open ? <XIcon /> : <MenuIcon />}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {open && (
        <div className="md:hidden border-t border-slate-800/60 bg-navy-900/95 backdrop-blur-md">
          <nav className="px-4 py-4 flex flex-col gap-1">
            {links.map(({ to, label, exact }) => (
              <NavLink
                key={to}
                to={to}
                end={exact}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  `px-4 py-3 rounded-xl text-sm font-medium transition-colors ${
                    isActive
                      ? 'text-sky-400 bg-sky-400/10'
                      : 'text-slate-300 hover:text-white hover:bg-white/5'
                  }`
                }
              >
                {label}
              </NavLink>
            ))}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary text-sm mt-3 justify-center"
            >
              <AppleIcon />
              Download on App Store
            </a>
          </nav>
        </div>
      )}
    </header>
  )
}

function GlobeLogo() {
  return (
    <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
      <circle cx="16" cy="16" r="14" fill="#0F1729" />
      <circle cx="16" cy="16" r="12" stroke="#38BDF8" strokeWidth="1.5" fill="none" />
      <ellipse cx="16" cy="16" rx="6" ry="12" stroke="#38BDF8" strokeWidth="1" fill="none" />
      <line x1="4" y1="16" x2="28" y2="16" stroke="#38BDF8" strokeWidth="1" />
      <line x1="6" y1="10" x2="26" y2="10" stroke="#38BDF8" strokeWidth="0.8" strokeDasharray="2 2" />
      <line x1="6" y1="22" x2="26" y2="22" stroke="#38BDF8" strokeWidth="0.8" strokeDasharray="2 2" />
      <circle cx="20" cy="11" r="2.5" fill="#FBBF24" />
    </svg>
  )
}

function AppleIcon() {
  return (
    <svg className="w-4 h-4" viewBox="0 0 814 1000" fill="currentColor">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.5 8.2 319.2 8.2 237.2c0-137.7 90-210.4 176-210.4 46.5 0 85.4 30.7 114.9 30.7 28.2 0 71.4-32.5 124.8-32.5 20.3 0 93.7 1.9 156.8 66.8zM586.8 37.9c-6.4 36.5-20.9 72.3-44.2 100.6-23.4 28.5-52.8 49.8-83.3 56.6 0-.6-.1-1.3-.1-1.9 0-35.6 16.1-74.1 38.3-99.7C520.6 65.6 566.4 43 586.8 37.9z"/>
    </svg>
  )
}

function MenuIcon() {
  return (
    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  )
}

function XIcon() {
  return (
    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
    </svg>
  )
}
