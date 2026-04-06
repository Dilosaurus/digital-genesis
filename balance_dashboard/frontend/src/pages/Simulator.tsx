import { useSimulatorStore } from '../stores/simulatorStore'
import { LoadoutPicker } from '../components/Simulator/LoadoutPicker'
import { ModifierStackPreview } from '../components/Simulator/ModifierStackPreview'
import { CardCalculator } from '../components/Simulator/CardCalculator'
import { ComparisonMode } from '../components/Simulator/ComparisonMode'

// ---------------------------------------------------------------------------
// Section icons (inline SVG)
// ---------------------------------------------------------------------------

const SECTION_ICONS: Record<string, React.ReactNode> = {
  loadout: (
    <svg className="w-4 h-4 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
    </svg>
  ),
  modifiers: (
    <svg className="w-4 h-4 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    </svg>
  ),
  calculator: (
    <svg className="w-4 h-4 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
    </svg>
  ),
  comparison: (
    <svg className="w-4 h-4 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
    </svg>
  ),
}

// ---------------------------------------------------------------------------
// Section wrapper
// ---------------------------------------------------------------------------

interface SectionProps {
  title: string
  description?: string
  accent: 'purple' | 'blue' | 'green' | 'red'
  icon: keyof typeof SECTION_ICONS
  children: React.ReactNode
}

function Section({ title, description, accent, icon, children }: SectionProps) {
  const accentClass = `panel-accent-${accent}`
  return (
    <section className={`panel ${accentClass} p-6`}>
      <div className="mb-4">
        <h2 className="text-lg font-semibold text-gray-100 flex items-center gap-2">
          {SECTION_ICONS[icon]}
          {title}
        </h2>
        {description && (
          <p className="text-sm text-gray-500 mt-0.5 ml-6">{description}</p>
        )}
      </div>
      {children}
    </section>
  )
}

// ---------------------------------------------------------------------------
// Simulator page
// ---------------------------------------------------------------------------

export default function Simulator() {
  const { loadoutA, setLoadoutA, resetLoadout } = useSimulatorStore()

  return (
    <div className="flex flex-col gap-6 p-6">
      {/* Page header */}
      <div className="gradient-header rounded-2xl p-6 -m-1">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-100">Scenario Simulator</h1>
            <p className="text-sm text-gray-500 mt-1">
              Configure a loadout and see instant card stat previews — all calculated client-side.
            </p>
          </div>
          <button
            onClick={() => resetLoadout('A')}
            className="px-4 py-2 text-sm rounded-lg font-medium gradient-purple text-white glow-purple hover:glow-purple-md transition-shadow"
          >
            Reset Loadout
          </button>
        </div>
      </div>

      {/* Two-column layout: Loadout Picker + Modifier Stack */}
      <div className="grid grid-cols-[360px_1fr] gap-6 items-start">
        {/* ---- Loadout Picker ---- */}
        <Section
          title="Loadout"
          description="Select relics, equipment, gems, skills, and context."
          accent="purple"
          icon="loadout"
        >
          <LoadoutPicker
            loadout={loadoutA}
            onUpdate={setLoadoutA}
          />
        </Section>

        {/* ---- Modifier Stack Preview ---- */}
        <Section
          title="Active Modifier Stack"
          description="All modifiers contributed by the current loadout, in resolution order."
          accent="blue"
          icon="modifiers"
        >
          <ModifierStackPreview loadout={loadoutA} />
        </Section>
      </div>

      {/* ---- Card Calculator ---- */}
      <Section
        title="Card Calculator"
        description="Effective stats for every card with the current loadout. Click a row to expand the pipeline breakdown."
        accent="green"
        icon="calculator"
      >
        <CardCalculator loadout={loadoutA} />
      </Section>

      {/* ---- Comparison Mode ---- */}
      <Section
        title="Comparison Mode"
        description="Compare two loadouts side by side and see per-card deltas."
        accent="red"
        icon="comparison"
      >
        <ComparisonMode />
      </Section>
    </div>
  )
}
