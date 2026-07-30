import { useEffect, useRef, useState } from 'react'
import './App.css'

const FEATURES = [
  {
    id: 'automate',
    title: 'Automate',
    copy: 'Chain miners, belts, inserters, and assemblers into living production lines.',
    image: '/assets/assembler.png',
    imageAlt: 'Assembling machine',
    icons: [
      { src: '/assets/electric_mining_drill.png', alt: 'Mining drill' },
      { src: '/assets/transport_belt.png', alt: 'Transport belt' },
      { src: '/assets/inserter.png', alt: 'Inserter' },
      { src: '/assets/furnace.png', alt: 'Furnace' },
    ],
  },
  {
    id: 'expand',
    title: 'Expand',
    copy: 'Power the grid, unlock research, and push the factory past every horizon.',
    image: '/assets/rocket_silo.png',
    imageAlt: 'Rocket silo',
    icons: [
      { src: '/assets/solar_panel.png', alt: 'Solar panel' },
      { src: '/assets/steam_engine.png', alt: 'Steam engine' },
      { src: '/assets/lab.png', alt: 'Research lab' },
      { src: '/assets/oil_refinery.png', alt: 'Oil refinery' },
    ],
  },
  {
    id: 'defend',
    title: 'Defend',
    copy: 'Hold the perimeter. Turrets and walls keep the swarm from your machines.',
    image: '/assets/gun_turret.png',
    imageAlt: 'Gun turret',
    icons: [
      { src: '/assets/laser_turret.png', alt: 'Laser turret' },
      { src: '/assets/biter.png', alt: 'Hostile creature' },
      { src: '/assets/military_science_pack.png', alt: 'Military science' },
      { src: '/assets/player.png', alt: 'Engineer' },
    ],
  },
]

const CONVEYOR = [
  '/assets/iron_plate.png',
  '/assets/copper_plate.png',
  '/assets/iron_gear_wheel.png',
  '/assets/electronic_circuit.png',
  '/assets/advanced_circuit.png',
  '/assets/processing_unit.png',
  '/assets/automation_science_pack.png',
  '/assets/logistic_science_pack.png',
  '/assets/chemical_plant.png',
  '/assets/production_science_pack.png',
  '/assets/utility_science_pack.png',
  '/assets/space_science_pack.png',
  '/assets/gear.png',
  '/assets/assembling_machine_3.png',
  '/assets/electric_furnace.png',
  '/assets/fast_transport_belt.png',
]

function useReveal() {
  const ref = useRef(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const node = ref.current
    if (!node) return undefined

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true)
          observer.disconnect()
        }
      },
      { threshold: 0.18, rootMargin: '0px 0px -8% 0px' },
    )

    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  return { ref, visible }
}

function Reveal({ className = '', children, as: Tag = 'div', delay = 0 }) {
  const { ref, visible } = useReveal()
  return (
    <Tag
      ref={ref}
      className={`reveal ${visible ? 'is-visible' : ''} ${className}`}
      style={{ '--reveal-delay': `${delay}ms` }}
    >
      {children}
    </Tag>
  )
}

function FeatureBlock({ feature, index }) {
  const reversed = index % 2 === 1
  const items = [
    { src: feature.image, alt: feature.imageAlt },
    ...feature.icons,
  ]
  const [selected, setSelected] = useState(items[0])
  const [swapKey, setSwapKey] = useState(0)

  function selectItem(item) {
    if (item.src === selected.src) return
    setSelected(item)
    setSwapKey((key) => key + 1)
  }

  return (
    <Reveal
      as="article"
      className={`feature ${reversed ? 'feature--reverse' : ''}`}
      delay={index * 80}
    >
      <div className="feature__visual">
        <img
          key={swapKey}
          src={selected.src}
          alt={selected.alt}
          className="feature__hero-asset"
        />
        <p className="feature__asset-label">{selected.alt}</p>
        <div
          className="feature__icon-row"
          role="listbox"
          aria-label={`${feature.title} assets`}
        >
          {items.map((item) => {
            const isActive = item.src === selected.src
            return (
              <button
                key={item.src}
                type="button"
                role="option"
                aria-selected={isActive}
                aria-label={`View ${item.alt}`}
                className={`feature__icon-btn ${isActive ? 'is-active' : ''}`}
                onClick={() => selectItem(item)}
              >
                <img src={item.src} alt="" className="feature__icon" />
              </button>
            )
          })}
        </div>
      </div>
      <div className="feature__copy">
        <p className="feature__index">0{index + 1}</p>
        <h2>{feature.title}</h2>
        <p>{feature.copy}</p>
      </div>
    </Reveal>
  )
}

export default function App() {
  return (
    <div className="page">
      <header className="topbar">
        <a className="brand-mark" href="#top" aria-label="FactoryForge home">
          <img src="/assets/AppIcon.png" alt="" width={36} height={36} />
          <span>FactoryForge</span>
        </a>
        <nav className="topbar__nav" aria-label="Primary">
          <a href="#pillars">Pillars</a>
          <a href="#line">Production</a>
          <a href="#cta">Play</a>
        </nav>
      </header>

      <main id="top">
        <section className="hero" aria-label="FactoryForge splash">
          <div className="hero__media" aria-hidden="true">
            <img src="/assets/splash.png" alt="" className="hero__splash" />
            <div className="hero__veil" />
            <div className="hero__grid" />
          </div>

          <div className="hero__content">
            <p className="hero__brand">FactoryForge</p>
            <h1>Build the machine that builds everything.</h1>
            <p className="hero__lede">
              An industrial factory sandbox — automate production, expand the
              frontier, and defend what you forge.
            </p>
            <div className="hero__actions">
              <a className="btn btn--primary" href="#cta">
                Get Started
              </a>
              <a className="btn btn--ghost" href="#pillars">
                See the Factory
              </a>
            </div>
          </div>
        </section>

        <section id="pillars" className="pillars">
          <Reveal className="section-head">
            <p className="eyebrow">Core loop</p>
            <h2>Automate. Expand. Defend.</h2>
          </Reveal>

          <div className="feature-list">
            {FEATURES.map((feature, index) => (
              <FeatureBlock key={feature.id} feature={feature} index={index} />
            ))}
          </div>
        </section>

        <section id="line" className="conveyor-section" aria-label="Production line">
          <Reveal className="section-head section-head--center">
            <p className="eyebrow">On the belt</p>
            <h2>From ore to orbit</h2>
            <p>
              Every plate, circuit, and science pack keeps the line moving —
              until the rocket clears the silo.
            </p>
          </Reveal>

          <div className="conveyor" aria-hidden="true">
            <div className="conveyor__track">
              {[...CONVEYOR, ...CONVEYOR].map((src, i) => (
                <img key={`${src}-${i}`} src={src} alt="" className="conveyor__item" />
              ))}
            </div>
          </div>
        </section>

        <section id="cta" className="finale">
          <div className="finale__glow" aria-hidden="true" />
          <Reveal className="finale__inner">
            <img
              src="/assets/AppIcon.png"
              alt=""
              className="finale__icon"
              width={88}
              height={88}
            />
            <h2>Forge your factory.</h2>
            <p>
              FactoryForge is an iOS factory automation game. Fire up the line,
              research the tech tree, and launch something worthy of the sky.
            </p>
            <div className="hero__actions finale__actions">
              <a className="btn btn--primary" href="https://github.com/auxon/factoryforge">
                View on GitHub
              </a>
              <a className="btn btn--ghost" href="#top">
                Back to Splash
              </a>
            </div>
          </Reveal>
        </section>
      </main>

      <footer className="footer">
        <span>FactoryForge</span>
        <span className="footer__sep" aria-hidden="true" />
        <span>Automate · Expand · Defend</span>
      </footer>
    </div>
  )
}
