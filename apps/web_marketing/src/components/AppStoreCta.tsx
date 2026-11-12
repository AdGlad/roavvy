import type { ReactNode } from 'react'
import { APP_STORE_URL } from '../site'

// Renders a real App Store link once APP_STORE_URL is set; until then a
// non-clickable "coming soon" badge styled the same way.
export default function AppStoreCta({
  className,
  live,
  soon,
}: {
  className: string
  live: ReactNode
  soon: ReactNode
}) {
  if (APP_STORE_URL) {
    return (
      <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" className={className}>
        {live}
      </a>
    )
  }
  return (
    <span className={`${className} cursor-default pointer-events-none`} aria-disabled="true">
      {soon}
    </span>
  )
}
