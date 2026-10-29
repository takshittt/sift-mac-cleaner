import type { ReactNode } from 'react'

// Small inline stroke icons, so the site needs no icon library.
export const icon = (path: ReactNode, className = 'h-6 w-6') => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden="true">
    {path}
  </svg>
)

// One per area in the app's sidebar (SectionKind in SiftCore).
export const areaPaths = {
  junk: <><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13" /><path d="M10 11v5M14 11v5" /></>,
  files: <><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" /><path d="M14 3v5h5M9 13h6M9 17h4" /></>,
  apps: <><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" /><path d="M10.5 11.5a1.5 1.5 0 1 1 2 1.4c-.4.2-.5.5-.5.9M12 16.5h.01" /></>,
  developer: <><path d="m8 8-4 4 4 4M16 8l4 4-4 4M13.5 5l-3 14" /></>,
  localAI: <><rect x="6" y="6" width="12" height="12" rx="2" /><path d="M10 10h4v4h-4zM9 3v3M15 3v3M9 18v3M15 18v3M3 9h3M3 15h3M18 9h3M18 15h3" /></>,
}
