import { create } from 'zustand'
import type { Loadout } from '../types'

// ---------------------------------------------------------------------------
// Default empty loadout
// ---------------------------------------------------------------------------

const DEFAULT_LOADOUT: Loadout = {
  relics: [],
  equipment: {},
  gems: {},
  skills: [],
  corruption_tier: 0,
  strength: 0,
  dexterity: 0,
  context: {
    vulnerable: false,
    weak: false,
    hp_pct: 1.0,
  },
}

// ---------------------------------------------------------------------------
// Store interface
// ---------------------------------------------------------------------------

interface SimulatorStore {
  loadoutA: Loadout
  loadoutB: Loadout
  activeLoadout: 'A' | 'B'
  comparisonMode: boolean

  /** Merge partial changes into loadout A */
  setLoadoutA: (loadout: Partial<Loadout>) => void
  /** Merge partial changes into loadout B */
  setLoadoutB: (loadout: Partial<Loadout>) => void
  /** Switch which loadout is the active one */
  setActiveLoadout: (which: 'A' | 'B') => void
  /** Toggle side-by-side comparison mode on/off */
  toggleComparison: () => void
  /** Reset a loadout back to defaults */
  resetLoadout: (which: 'A' | 'B') => void
}

// ---------------------------------------------------------------------------
// Zustand store
// ---------------------------------------------------------------------------

export const useSimulatorStore = create<SimulatorStore>(set => ({
  loadoutA: { ...DEFAULT_LOADOUT, context: { ...DEFAULT_LOADOUT.context } },
  loadoutB: { ...DEFAULT_LOADOUT, context: { ...DEFAULT_LOADOUT.context } },
  activeLoadout: 'A',
  comparisonMode: false,

  setLoadoutA: (partial) =>
    set(state => ({
      loadoutA: mergeLoadout(state.loadoutA, partial),
    })),

  setLoadoutB: (partial) =>
    set(state => ({
      loadoutB: mergeLoadout(state.loadoutB, partial),
    })),

  setActiveLoadout: (which) => set({ activeLoadout: which }),

  toggleComparison: () =>
    set(state => ({ comparisonMode: !state.comparisonMode })),

  resetLoadout: (which) =>
    set(() => ({
      [which === 'A' ? 'loadoutA' : 'loadoutB']: {
        ...DEFAULT_LOADOUT,
        context: { ...DEFAULT_LOADOUT.context },
      },
    })),
}))

// ---------------------------------------------------------------------------
// Helper: shallow-merge a partial loadout, preserving nested context object
// ---------------------------------------------------------------------------

function mergeLoadout(current: Loadout, partial: Partial<Loadout>): Loadout {
  const { context, ...rest } = partial
  return {
    ...current,
    ...rest,
    context: context
      ? { ...current.context, ...context }
      : current.context,
  }
}

// ---------------------------------------------------------------------------
// Convenience selector — returns the currently active loadout
// ---------------------------------------------------------------------------

export function selectActiveLoadout(state: SimulatorStore): Loadout {
  return state.activeLoadout === 'A' ? state.loadoutA : state.loadoutB
}
