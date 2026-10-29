import type { ReactNode } from 'react'
import { ISSUES_URL, REPO_URL } from '../release'
import Section from './Section'

const link = 'font-medium text-lavender-700 underline-offset-2 hover:underline'

const items: { q: string; a: ReactNode }[] = [
  {
    q: 'Is Sift free?',
    a: (
      <>
        Yes, completely. It’s open source under the MIT license, and the code is on{' '}
        <a className={link} href={REPO_URL}>GitHub</a>.
      </>
    ),
  },
  {
    q: 'Could it delete something I need?',
    a: 'Your Documents, Photos, iCloud Drive, Keychain, Mail, Messages, Contacts, Calendars and Safari data are never touched, whatever you select. Only items labelled Safe are ticked for you, and anything that might be yours goes to the Trash rather than being deleted.',
  },
  {
    q: 'How do I get something back?',
    a: 'Open the Trash in the Dock, select the item and choose File → Put Back. Caches and logs that rebuild themselves are deleted right away instead, because moving them to the Trash would free no space. You can change this in Settings → General → Deletion mode.',
  },
  {
    q: 'Why does my Mac warn me when I open it?',
    a: 'Apple charges developers every year to register their apps. Sift is free, so it isn’t registered, and macOS shows a warning the first time. Follow step 2 of the install guide above to open it anyway. You only need to do this once.',
  },
  {
    q: 'Does it need Full Disk Access?',
    a: 'No. Without it, Sift still scans everything macOS lets it see and tells you what it’s missing. With it, Sift can also find Safari data, Mail downloads, iPhone and iPad backups and some app containers.',
  },
  {
    q: 'Does it run in the background or send my data anywhere?',
    a: 'No. Sift only does something while it’s open. It works offline, needs no account, and nothing about your files ever leaves your Mac.',
  },
  {
    q: 'Will it speed up my Mac?',
    a: 'Sift is about storage space, not speed. It doesn’t scan for viruses or tweak the system. It frees up space, which helps most when your disk is nearly full.',
  },
  {
    q: 'Which Macs does it work on?',
    a: 'Macs with Apple silicon (M1 or newer) running macOS 14 (Sonoma) or newer. Intel Macs aren’t supported.',
  },
  {
    q: 'How do I update or uninstall it?',
    a: 'To update, download the new version and replace the old Sift in your Applications folder. Your settings are kept. To uninstall, quit Sift and drag it from Applications to the Trash.',
  },
  {
    q: 'I found a bug.',
    a: (
      <>
        Please <a className={link} href={ISSUES_URL}>open an issue on GitHub</a> and describe what happened.
      </>
    ),
  },
]

export default function Faq() {
  return (
    <Section id="faq" eyebrow="FAQ" title="Questions and answers.">
      <div className="mx-auto max-w-3xl divide-y divide-zinc-200 border-y border-zinc-200">
        {items.map((item) => (
          <details key={item.q} className="group">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-lg font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lavender-600 [&::-webkit-details-marker]:hidden">
              {item.q}
              <svg viewBox="0 0 20 20" fill="currentColor" className="h-5 w-5 shrink-0 text-tomato transition-transform group-open:rotate-45" aria-hidden="true">
                <path d="M10 4a1 1 0 0 1 1 1v4h4a1 1 0 1 1 0 2h-4v4a1 1 0 1 1-2 0v-4H5a1 1 0 1 1 0-2h4V5a1 1 0 0 1 1-1z" />
              </svg>
            </summary>
            <p className="pb-5 text-zinc-600">{item.a}</p>
          </details>
        ))}
      </div>
    </Section>
  )
}
