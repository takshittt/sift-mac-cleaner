import { areaPaths, icon } from './icons'

// A drawing of Sift's Overview screen in HTML, standing in for a screenshot (spec §4.1).

interface Area {
  title: string
  size: string
  share: number
  gradient: string
  path: keyof typeof areaPaths
}

// Same gradients as Theme.gradient(for:) in the app.
const areas: Area[] = [
  { title: 'Local AI', size: '13.6 GB', share: 0.4, gradient: 'from-[#c6f04a] to-lavender-500', path: 'localAI' },
  { title: 'Developer', size: '9.4 GB', share: 0.28, gradient: 'from-lavender-300 to-tomato', path: 'developer' },
  { title: 'System Junk', size: '6.8 GB', share: 0.2, gradient: 'from-lavender-300 to-lavender-500', path: 'junk' },
  { title: 'Files', size: '3.1 GB', share: 0.09, gradient: 'from-[#ff9a85] to-tomato', path: 'files' },
  { title: 'Apps & Leftovers', size: '1.2 GB', share: 0.04, gradient: 'from-[#d4ff4a] to-[#86c400]', path: 'apps' },
]

const sidebar = ['Overview', 'System Junk', 'Files', 'Apps & Leftovers', 'Developer', 'Local AI']

// The disk ring: 72% used, with the reclaimable part of it in chartreuse.
const R = 40
const C = 2 * Math.PI * R
const USED = 0.72
const FREEABLE = 0.07

export default function MockOverview() {
  return (
    <div aria-hidden="true" className="relative mx-auto w-full max-w-5xl select-none">
      <div className="relative overflow-hidden rounded-2xl border border-lavender-200 bg-gradient-to-br from-lavender-50 via-white to-lavender-100 shadow-2xl shadow-lavender-300/50">
        {/* The app's backdrop glows */}
        <div className="pointer-events-none absolute -top-24 right-0 h-72 w-72 rounded-full bg-chartreuse/30 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-24 left-0 h-72 w-72 rounded-full bg-tomato/20 blur-3xl" />

        {/* Title bar */}
        <div className="relative flex h-8 items-center gap-1.5 px-3.5">
          <span className="h-3 w-3 rounded-full bg-[#ff5f57]" />
          <span className="h-3 w-3 rounded-full bg-[#febc2e]" />
          <span className="h-3 w-3 rounded-full bg-[#28c840]" />
        </div>

        <div className="relative flex">
          {/* Sidebar */}
          <div className="hidden w-44 shrink-0 space-y-0.5 px-3 pt-2 pb-6 text-xs text-zinc-700 md:block">
            {sidebar.map((item, i) => (
              <div key={item} className={`rounded-md px-2.5 py-1.5 ${i === 0 ? 'bg-lavender-100 font-semibold text-lavender-700' : ''}`}>
                {item}
              </div>
            ))}
          </div>

          {/* Content */}
          <div className="min-w-0 flex-1 space-y-3 px-3 pb-20 sm:space-y-4 sm:px-5 md:pl-1">
            <div className="relative flex items-center justify-between gap-4 overflow-hidden rounded-2xl bg-gradient-to-br from-lavender-700 via-lavender-500 to-lavender-300 p-5 text-white shadow-lg shadow-lavender-500/30 sm:p-6">
              <div className="pointer-events-none absolute -top-16 right-10 h-40 w-40 rounded-full bg-white/20 blur-2xl" />
              <div className="relative">
                <p className="text-[10px] font-bold tracking-[0.12em] opacity-85">READY TO CLEAN</p>
                <p className="mt-1 text-3xl font-bold tracking-tight sm:text-4xl">34.1 GB</p>
                <p className="mt-2 inline-block rounded-full bg-white/20 px-2.5 py-0.5 text-[11px] font-medium">138 GB free of 494 GB</p>
              </div>
              <svg viewBox="0 0 100 100" className="relative h-20 w-20 shrink-0 -rotate-90 sm:h-24 sm:w-24">
                <circle cx="50" cy="50" r={R} fill="none" stroke="rgb(255 255 255 / 0.18)" strokeWidth="9" />
                <circle cx="50" cy="50" r={R} fill="none" stroke="rgb(255 255 255 / 0.45)" strokeWidth="9" strokeLinecap="round" strokeDasharray={`${C * USED} ${C}`} />
                <circle
                  cx="50" cy="50" r={R} fill="none" stroke="var(--color-chartreuse)" strokeWidth="9" strokeLinecap="round"
                  strokeDasharray={`${C * FREEABLE} ${C}`} strokeDashoffset={-C * (USED - FREEABLE)}
                />
                <text x="50" y="50" transform="rotate(90 50 50)" textAnchor="middle" dominantBaseline="central" fill="white" fontSize="18" fontWeight="700">
                  72%
                </text>
              </svg>
            </div>

            <div className="flex flex-wrap items-center gap-1.5 text-[11px]">
              <span className="text-zinc-500">Scanning for</span>
              {['Everyday use', 'Software development', 'AI and machine learning'].map((p, i) => (
                <span key={p} className={`rounded-full bg-lavender-100 px-2.5 py-0.5 font-medium text-lavender-700 ${i === 2 ? 'hidden sm:inline' : ''}`}>
                  {p}
                </span>
              ))}
            </div>

            <div className="grid grid-cols-2 gap-2.5 sm:gap-3 lg:grid-cols-3">
              {areas.map((a, i) => (
                <div key={a.title} className={`rounded-xl border border-white bg-white/80 p-3 shadow-md shadow-lavender-500/10 sm:p-3.5 ${i > 3 ? 'hidden lg:block' : ''}`}>
                  <span className={`inline-flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br text-white ${a.gradient}`}>
                    {icon(areaPaths[a.path], 'h-4 w-4')}
                  </span>
                  <p className="mt-2.5 text-[11px] font-medium text-zinc-500">{a.title}</p>
                  <p className="text-lg font-bold tracking-tight">{a.size}</p>
                  <div className="mt-2 h-1.5 rounded-full bg-lavender-100">
                    <div className={`h-full rounded-full bg-gradient-to-r ${a.gradient}`} style={{ width: `${Math.max(a.share * 100, 4)}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Floating action bar */}
        <div className="absolute inset-x-3 bottom-3 flex items-center justify-between gap-3 rounded-full border border-white bg-white/85 py-1.5 pr-1.5 pl-4 shadow-lg shadow-lavender-500/15 backdrop-blur sm:left-auto sm:right-5 sm:bottom-4 sm:gap-6">
          <span className="text-xs text-zinc-600">
            <strong className="font-semibold text-zinc-900">12.6 GB</strong> selected
          </span>
          <span className="rounded-full bg-gradient-to-br from-lavender-400 to-lavender-700 px-4 py-1.5 text-xs font-semibold text-white">Clean</span>
        </div>
      </div>
    </div>
  )
}
