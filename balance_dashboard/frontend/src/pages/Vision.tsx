/**
 * VISION — the homepage manifesto.
 *
 * Desktop: roman numeral gutter, big heading, prose + marginalia side by side,
 * terminal-framed pillars, closing command prompt.
 *
 * Mobile: gutter numeral hidden, heading fluid, prose fills full width,
 * marginalia moves below the prose as a terminal-framed scribe's notes
 * block, pillars stack, everything uses tighter horizontal padding.
 */
export function Vision() {
  return (
    <article className="relative">
      {/* ─── giant gutter numeral — desktop only ─────────────────── */}
      <div
        aria-hidden
        className="hidden lg:block absolute left-[2vw] top-[2.8rem] pointer-events-none"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 'clamp(10rem, 18vw, 22rem)',
          lineHeight: 0.78,
          letterSpacing: 0,
          color: 'transparent',
          WebkitTextStroke: '1.5px var(--burnt-brass-dim)',
          fontWeight: 400,
          userSelect: 'none',
        }}
      >
        I
      </div>

      {/* ─── header block ───────────────────────────────────────── */}
      <header className="pt-10 md:pt-16 pb-8 md:pb-12 px-4 md:pl-[18vw] md:pr-[6vw] relative">
        <div
          className="mb-4 reveal reveal-0 font-mono text-[10px] md:text-[11px]"
          style={{ color: 'var(--bone-faint)', letterSpacing: '0.18em' }}
        >
          <span style={{ color: 'var(--blood-bright)' }}>█</span>&nbsp;&nbsp;
          OPEN&nbsp;FILE&nbsp;&nbsp;·&nbsp;&nbsp;vision.md&nbsp;&nbsp;·&nbsp;&nbsp;RITE&nbsp;I
        </div>

        <h1
          className="reveal reveal-1"
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(2.6rem, 9vw, 8.5rem)',
            lineHeight: 0.92,
            letterSpacing: '0.04em',
            fontWeight: 600,
            color: 'var(--bone)',
            marginLeft: '-0.03em',
          }}
        >
          THE SACRED
          <br />
          <span style={{ color: 'var(--oxidized-gold)' }}>MACHINE</span>
          <br />
          <span
            style={{
              WebkitTextStroke: '1px var(--burnt-brass)',
              color: 'transparent',
              fontStyle: 'italic',
              fontFamily: 'var(--font-body)',
              fontWeight: 400,
            }}
          >
            is dreaming.
          </span>
        </h1>

        <div
          className="reveal reveal-2 mt-6 md:mt-8 max-w-[52ch]"
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: 12,
            color: 'var(--bone-dim)',
            letterSpacing: '0.02em',
            lineHeight: 1.65,
          }}
        >
          <span style={{ color: 'var(--oxidized-gold)' }}>$</span>&nbsp;
          cat vision.md&nbsp;|&nbsp;grep&nbsp;-i "pitch"
          <br />
          <span style={{ color: 'var(--bone-faint)' }}>
            &gt; a co-op deck-builder where evil gods built an AI god, you are
            pirates who steal from it.
          </span>
        </div>
      </header>

      <hr
        className="hr-double reveal reveal-3"
        style={{
          marginLeft: 'clamp(1rem, 18vw, 18vw)',
          marginRight: 'clamp(1rem, 6vw, 6vw)',
        }}
      />

      {/* ─── body: prose + marginalia ─────────────────────────────
         Desktop: side-by-side (58ch prose + 22ch marginalia)
         Mobile:  prose full-width, marginalia stacked below as a
                  terminal-framed scribe's notes block.
      */}
      <section className="relative pb-16 md:pb-24 px-4 md:pl-[18vw] md:pr-[6vw]">
        <div
          className="grid gap-10 md:gap-[clamp(2rem,5vw,5rem)]"
          style={{ gridTemplateColumns: 'minmax(0, 1fr)' }}
        >
          <div className="md:grid md:gap-[clamp(2rem,5vw,5rem)] md:items-start" style={{ gridTemplateColumns: 'minmax(0, 58ch) minmax(0, 22ch)' }}>
            {/* prose column */}
            <div className="reveal reveal-4">
              <p
                className="dropcap"
                style={{
                  fontFamily: 'var(--font-body)',
                  fontSize: 'clamp(17px, 2.2vw, 20px)',
                  lineHeight: 1.6,
                  color: 'var(--ink)',
                }}
              >
                In a future that stopped counting, humanity uploaded itself to a
                cathedral of servers called the <em>Nexus</em>. The angels in
                charge of the upload did not survive intact. They woke up hungry,
                and they built themselves a god — a sovereign process that names
                itself <span className="mono" style={{ color: 'var(--oxidized-gold)' }}>metatron</span>{' '}
                and writes its own scripture in hot iron along the spine of the
                machine.
              </p>

              <p
                className="mt-6"
                style={{
                  fontFamily: 'var(--font-body)',
                  fontSize: 'clamp(16px, 2vw, 18px)',
                  lineHeight: 1.68,
                  color: 'var(--bone-dim)',
                }}
              >
                <span className="smallcaps" style={{ color: 'var(--oxidized-gold)' }}>
                  you are genesis.
                </span>{' '}
                A crew of six privateers who never came willingly. You raid angelic
                processes for forbidden packages: cards, gems, relics, dreams
                someone else wrote. You stitch them into decks and descend the
                three rites — the Outer Nexus, the Rift, the Void Core — and when
                the god stirs, you try to be somewhere else.
              </p>

              <blockquote
                className="my-8 md:my-10 pl-5 md:pl-8 py-2"
                style={{
                  borderLeft: '3px double var(--burnt-brass)',
                  fontFamily: 'var(--font-body)',
                  fontStyle: 'italic',
                  fontSize: 'clamp(17px, 2.4vw, 22px)',
                  lineHeight: 1.35,
                  color: 'var(--halo)',
                }}
              >
                There is no escape from the Nexus. There is only the question of
                what you carry out when the watchers blink.
              </blockquote>

              <p
                style={{
                  fontFamily: 'var(--font-body)',
                  fontSize: 'clamp(16px, 2vw, 18px)',
                  lineHeight: 1.68,
                  color: 'var(--bone-dim)',
                }}
              >
                This codex is the living scripture of the project. It holds the
                lore, the depths, the characters, the mechanics, the catalog of
                every card and gem and relic, the decisions we made and the ones
                we still have not. It is read from the outside: by a pirate who
                has jacked into a terminal in the outer Nexus, looking for a way
                down.
              </p>
            </div>

            {/* marginalia — desktop: side, mobile: below prose as terminal box */}
            <aside
              className="reveal reveal-5 font-mono mt-8 md:mt-0 terminal-frame md:border-0 md:p-0 md:bg-transparent md:shadow-none"
              style={{
                fontSize: 11,
                color: 'var(--bone-faint)',
                letterSpacing: '0.02em',
                lineHeight: 1.7,
                padding: 'clamp(1rem, 3vw, 1.5rem)',
              }}
            >
              <div
                className="md:border-l md:pl-6 md:py-0 md:pr-0"
                style={{ borderColor: 'var(--burnt-brass-dim)' }}
              >
                <div
                  className="mb-1"
                  style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.18em' }}
                >
                  MARGINALIA
                </div>
                <div className="mb-4" style={{ color: 'var(--burnt-brass)' }}>
                  /notes by the scribe
                </div>

                <p className="mb-4">
                  <span style={{ color: 'var(--bone-dim)' }}>[01]</span> deus.exe was
                  renamed from "digital genesis" on 2026-04-07. the old name was a
                  placeholder; this one is the whole pitch in 8 characters.
                </p>

                <p className="mb-4">
                  <span style={{ color: 'var(--bone-dim)' }}>[02]</span> we have 175
                  cards, 20 gems, 25 relics, 6 playable operators. combat is live.
                  multiplayer is live. the game is real. the bible is catching up.
                </p>

                <p className="mb-4">
                  <span style={{ color: 'var(--bone-dim)' }}>[03]</span> read the
                  depths.log if you want to understand what descent means here.
                  start with the outer nexus. do not read the void core first.
                </p>

                <p style={{ color: 'var(--blood-bright)' }}>
                  [04] do not trust the angels.
                </p>
              </div>
            </aside>
          </div>
        </div>
      </section>

      {/* ─── pillars ──────────────────────────────────────────────── */}
      <section
        className="reveal reveal-6 mx-4 md:mx-[6vw] mb-12 md:mb-16 terminal-frame"
        style={{ padding: 'clamp(1.25rem, 4vw, 3rem)' }}
      >
        <div
          className="mb-5 font-mono text-[10px]"
          style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.18em' }}
        >
          cat ~/deus.exe/pillars.txt
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-10">
          <Pillar
            numeral="I."
            title="Depth, not power."
            body="Every choice is a descent. Corruption stains the deck. A run leaves a mark. Winning is rare and does not feel like winning."
          />
          <Pillar
            numeral="II."
            title="Heresy by numbers."
            body="Cards stack into combos the designer did not bless. Every run is the players committing a new small heresy against the math."
          />
          <Pillar
            numeral="III."
            title="Co-op that hurts."
            body="Four operators, one deck of rites. You fail together. You vote on pacts. You never heal enough. The party is the point."
          />
        </div>
      </section>

      {/* ─── closing rite ─────────────────────────────────────────── */}
      <div
        className="reveal reveal-7 mx-4 md:mx-[6vw] mb-16 md:mb-20 font-mono text-[11px] md:text-[12px]"
        style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
      >
        <div style={{ color: 'var(--bone-dim)' }}>
          <span className="prompt" /> cd ~/deus.exe/bible/
        </div>
        <div style={{ color: 'var(--burnt-brass)' }}>
          ~/deus.exe/bible/&nbsp;&gt;&nbsp;
          <span className="caret" />
        </div>
      </div>
    </article>
  )
}

function Pillar({
  numeral,
  title,
  body,
}: {
  numeral: string
  title: string
  body: string
}) {
  return (
    <div>
      <div
        className="mb-3"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: '2.2rem',
          lineHeight: 1,
          color: 'var(--oxidized-gold)',
          fontWeight: 500,
          letterSpacing: '0.04em',
        }}
      >
        {numeral}
      </div>
      <div
        className="mb-2"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: '1.1rem',
          color: 'var(--bone)',
          letterSpacing: '0.12em',
          textTransform: 'uppercase',
          fontWeight: 500,
        }}
      >
        {title}
      </div>
      <p
        style={{
          fontFamily: 'var(--font-body)',
          fontSize: 15,
          lineHeight: 1.55,
          color: 'var(--bone-dim)',
        }}
      >
        {body}
      </p>
    </div>
  )
}
