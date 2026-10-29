import type { Release } from '../release'
import DownloadButton from './DownloadButton'
import MockOverview from './MockOverview'

export default function Hero({ release }: { release: Release | null }) {
  return (
    <section id="top" className="bg-gradient-to-b from-lavender-50 via-white to-white px-4 pt-16 pb-20 sm:px-6 sm:pt-24">
      <div className="mx-auto max-w-3xl text-center">
        <img src="icon.png" alt="" className="mx-auto mb-6 h-20 w-20 sm:h-24 sm:w-24" />
        <h1 className="relative isolate text-4xl font-bold tracking-tight text-balance sm:text-6xl">
          Free up space on your Mac,{' '}
          <span className="relative whitespace-nowrap">
            <span aria-hidden="true" className="absolute inset-x-0 bottom-1 -z-10 h-3 -rotate-1 rounded-sm bg-chartreuse sm:bottom-2 sm:h-5" />
            safely.
          </span>
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-lg text-pretty text-zinc-600 sm:text-xl">
          Sift finds the caches, leftovers and forgotten files filling up your Mac, explains each one in plain words, and{' '}
          <strong className="font-semibold text-zinc-900">never touches your personal files</strong>.
        </p>
        <div className="mt-9">
          <DownloadButton release={release} />
        </div>
      </div>
      <div className="mt-16">
        <MockOverview />
      </div>
    </section>
  )
}
