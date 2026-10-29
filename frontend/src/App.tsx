import Faq from './components/Faq'
import Features from './components/Features'
import Footer from './components/Footer'
import Header from './components/Header'
import Hero from './components/Hero'
import Install from './components/Install'
import Safety from './components/Safety'
import { useLatestRelease } from './release'

export default function App() {
  // Looked up once here and passed down, so the page makes a single API request.
  const release = useLatestRelease()
  return (
    <>
      <Header release={release} />
      <main>
        <Hero release={release} />
        <Features />
        <Safety />
        <Install />
        <Faq />
      </main>
      <Footer release={release} />
    </>
  )
}
