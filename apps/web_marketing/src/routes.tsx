import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Features from './pages/Features'
import Download from './pages/Download'
import Support from './pages/Support'
import About from './pages/About'
import Terms from './pages/Terms'
import Privacy from './pages/Privacy'
import Refund from './pages/Refund'
import Investors from './pages/Investors'
import NotFound from './pages/NotFound'

// Every route here is pre-rendered to static HTML at build time
// (scripts/prerender.mjs). `title` becomes that page's <title>.
export const PAGES = [
  { path: '/', title: 'Roavvy — Your Travel Story, Finally Visible' },
  { path: '/features', title: 'Features — Roavvy' },
  { path: '/download', title: 'Download — Roavvy' },
  { path: '/support', title: 'Support — Roavvy' },
  { path: '/about', title: 'About Roavvy — Team & Company' },
  { path: '/investors', title: 'Investors — Roavvy' },
  { path: '/terms', title: 'Terms & Conditions — Roavvy' },
  { path: '/privacy', title: 'Privacy Policy — Roavvy' },
  { path: '/refund', title: 'Refund Policy — Roavvy' },
]

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/features" element={<Features />} />
        <Route path="/download" element={<Download />} />
        <Route path="/support" element={<Support />} />
        <Route path="/about" element={<About />} />
        <Route path="/terms" element={<Terms />} />
        <Route path="/privacy" element={<Privacy />} />
        <Route path="/refund" element={<Refund />} />
        <Route path="/investors" element={<Investors />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
