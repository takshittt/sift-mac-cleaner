import Section from './Section'
import { icon } from './icons'

// The three labels from SafetyLevel in SiftCore.
const levels = [
  {
    title: 'Safe',
    dot: 'bg-emerald-500',
    body: 'Rebuilt automatically by macOS or the app. Nothing of yours is lost.',
    selection: 'Ticked for you',
  },
  {
    title: 'Caution',
    dot: 'bg-amber-400',
    body: 'Safe, but you may need to re-download, rebuild or sign in again.',
    selection: 'Your call',
  },
  {
    title: 'Review',
    dot: 'bg-tomato',
    body: 'May contain your own data. Look through it yourself before removing.',
    selection: 'Never ticked for you',
  },
]

const protectedPlaces = ['Documents', 'Photos', 'iCloud Drive', 'Keychain', 'Mail', 'Messages', 'Contacts', 'Calendars', 'Safari data']

const guardrails = [
  'Anything that might be yours goes to the Trash, so you can put it back. Only caches and logs that rebuild themselves are deleted right away.',
  'Files of apps that are open are left alone, because the app is probably using them.',
  'Folders for Dropbox, OneDrive, Google Drive, Docker, games and AI models are clearly marked and never pre-selected.',
  'Nothing outside your home folder is removed, and Sift won’t follow shortcuts that point somewhere else.',
  'If you pick anything marked Review, Sift asks before going ahead.',
]

const check = icon(<path d="m5 12.5 4.5 4.5L19 7.5" />, 'mt-0.5 h-5 w-5 shrink-0 text-lavender-600')

export default function Safety() {
  return (
    <Section
      id="safety"
      eyebrow="Safety"
      title="Freeing space is only useful if nothing important is lost."
      intro="Every item gets a label that says how safe it is to remove. Only the green ones are ticked for you."
    >
      <ul className="mx-auto grid max-w-5xl gap-5 md:grid-cols-3">
        {levels.map((l) => (
          <li key={l.title} className="rounded-2xl border border-zinc-200 p-6">
            <div className="flex items-center gap-2.5">
              <span className={`h-3 w-3 rounded-full ${l.dot}`} aria-hidden="true" />
              <h3 className="text-lg font-semibold">{l.title}</h3>
            </div>
            <p className="mt-2 text-zinc-600">{l.body}</p>
            <p className="mt-4 inline-block rounded-full bg-lavender-50 px-3 py-1 text-sm font-medium text-lavender-700">{l.selection}</p>
          </li>
        ))}
      </ul>

      <div className="mx-auto mt-5 grid max-w-5xl gap-5 lg:grid-cols-2">
        <div className="rounded-2xl bg-gradient-to-br from-lavender-600 to-lavender-700 p-6 text-white sm:p-8">
          <h3 className="text-lg font-semibold">Never touched, whatever you select</h3>
          <p className="mt-2 text-lavender-100">These are blocked in the app’s own logic, so a mistake in a list can’t reach them.</p>
          <ul className="mt-5 flex flex-wrap gap-2">
            {protectedPlaces.map((p) => (
              <li key={p} className="rounded-full bg-white/15 px-3 py-1 text-sm font-medium">
                {p}
              </li>
            ))}
          </ul>
        </div>
        <div className="rounded-2xl border border-zinc-200 p-6 sm:p-8">
          <h3 className="text-lg font-semibold">And a few more guardrails</h3>
          <ul className="mt-4 space-y-3 text-zinc-600">
            {guardrails.map((g) => (
              <li key={g} className="flex gap-3">
                {check}
                {g}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </Section>
  )
}
