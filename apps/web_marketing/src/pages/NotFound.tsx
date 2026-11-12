import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <section className="bg-navy-900 py-32 text-center">
      <div className="max-w-xl mx-auto px-4">
        <span className="section-label">404</span>
        <h1 className="section-heading text-4xl">Page not found</h1>
        <p className="section-subheading">The page you were looking for doesn't exist.</p>
        <Link to="/" className="btn-primary mt-8 inline-flex">Back to home</Link>
      </div>
    </section>
  )
}
