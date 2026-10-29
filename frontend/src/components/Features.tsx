import Section from './Section'
import { areaPaths, icon } from './icons'

const features = [
  {
    title: 'Everyday junk',
    body: 'App caches, browser caches for Safari, Chrome, Firefox, Edge, Brave, Arc and Opera, logs and crash reports, opened Mail attachments, and the Trash. Bookmarks, passwords and history are left alone.',
    icon: icon(areaPaths.junk),
  },
  {
    title: 'Forgotten files',
    body: 'Old installers and disk images, files over 500 MB, downloads you haven’t opened in 90 days, and old iPhone and iPad backups. Shown for you to review, never removed on their own.',
    icon: icon(areaPaths.files),
  },
  {
    title: 'Leftovers from deleted apps',
    body: 'Settings and data folders of apps that are no longer anywhere on your Mac, and startup entries that point to programs that don’t exist any more.',
    icon: icon(areaPaths.apps),
  },
  {
    title: 'Programming tools',
    body: 'Xcode build data, archives and simulator caches, package caches from npm, Yarn, pnpm, pip, Homebrew, Cargo, Go, Gradle and more, and node_modules in projects untouched for two months.',
    icon: icon(areaPaths.developer),
  },
  {
    title: 'AI models',
    body: 'Models downloaded by Ollama and LM Studio, and Hugging Face, PyTorch, Whisper and Keras caches. A single model can take tens of gigabytes.',
    icon: icon(areaPaths.localAI),
  },
  {
    title: 'Only what you use',
    body: 'Sift asks what you use your Mac for (everyday use, software development, or AI and machine learning) and suggests an answer from what’s installed. Only the areas you switch on are scanned.',
    icon: icon(<><circle cx="12" cy="8" r="3.5" /><path d="M5 20c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5" /></>),
  },
]

// Icon tiles cycle through the palette: lavender first, chartreuse and tomato as accents.
const tiles = ['bg-lavender-100 text-lavender-700', 'bg-chartreuse-soft text-zinc-800', 'bg-tomato-soft text-tomato-ink']

export default function Features() {
  return (
    <Section
      id="features"
      eyebrow="What it cleans"
      title="It knows where the junk piles up."
      intro="Every Mac slowly fills with files you never asked for. Sift looks in the places they collect and adds up how much space each one takes."
      tinted
    >
      <ul className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {features.map((f, i) => (
          <li key={f.title} className="rounded-2xl border border-lavender-100 bg-white p-6">
            <div className={`mb-4 inline-flex h-11 w-11 items-center justify-center rounded-xl ${tiles[i % tiles.length]}`}>{f.icon}</div>
            <h3 className="text-lg font-semibold">{f.title}</h3>
            <p className="mt-2 text-zinc-600">{f.body}</p>
          </li>
        ))}
      </ul>
    </Section>
  )
}
