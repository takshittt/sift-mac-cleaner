import type { ReactNode } from 'react'
import Section from './Section'

const Path = ({ children }: { children: ReactNode }) => <strong className="font-semibold text-zinc-900">{children}</strong>

const steps: { title: string; body: ReactNode }[] = [
  {
    title: 'Move it to Applications',
    body: (
      <p>
        Double-click the downloaded <Path>.dmg</Path> file to open it. Then drag <Path>Sift</Path> onto the <Path>Applications</Path> folder next to it.
      </p>
    ),
  },
  {
    title: 'Open it the first time',
    body: (
      <>
        <p>Sift is free, so it isn’t registered with Apple (that costs money every year). Your Mac will block it the first time. You only need to do this once:</p>
        <ol className="mt-3 list-decimal space-y-1.5 pl-5 marker:text-lavender-500">
          <li>
            Open <Path>Sift</Path> from Applications. You’ll see a warning. Click <Path>Done</Path> or <Path>OK</Path>.
          </li>
          <li>
            Open <Path>System Settings → Privacy &amp; Security</Path>.
          </li>
          <li>
            Scroll down. Next to the message about Sift, click <Path>Open Anyway</Path>.
          </li>
          <li>
            Enter your password if asked, then click <Path>Open Anyway</Path> again.
          </li>
        </ol>
      </>
    ),
  },
  {
    title: 'Give it a full view (optional)',
    body: (
      <>
        <p>
          macOS hides some folders, like Safari data, Mail downloads and iPhone backups, unless an app has <Path>Full Disk Access</Path>. Sift works without it and tells you what it can’t see.
        </p>
        <ol className="mt-3 list-decimal space-y-1.5 pl-5 marker:text-lavender-500">
          <li>
            Click <Path>Open Settings</Path> on the banner in Sift. It opens <Path>System Settings → Privacy &amp; Security → Full Disk Access</Path>.
          </li>
          <li>
            Turn on the switch next to <Path>Sift</Path>. If it isn’t listed, click <Path>+</Path> and choose Sift from Applications.
          </li>
          <li>
            Back in Sift, click <Path>Scan Again</Path>.
          </li>
        </ol>
      </>
    ),
  },
]

export default function Install() {
  return (
    <Section id="install" eyebrow="Install" title="Up and running in three steps." intro="Takes about a minute. You only do this once." tinted>
      <ol className="mx-auto grid max-w-5xl gap-5 lg:grid-cols-3">
        {steps.map((s, i) => (
          <li key={s.title} className="rounded-2xl border border-lavender-100 bg-white p-6 text-zinc-600">
            <div className="mb-4 flex h-9 w-9 items-center justify-center rounded-full bg-lavender-600 font-semibold text-white">{i + 1}</div>
            <h3 className="mb-2 text-lg font-semibold text-zinc-900">{s.title}</h3>
            {s.body}
          </li>
        ))}
      </ol>
    </Section>
  )
}
