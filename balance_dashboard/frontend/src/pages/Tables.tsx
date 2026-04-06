import { useState } from 'react'
import { CardsTable } from '../components/Tables/CardsTable'
import { RelicsTable } from '../components/Tables/RelicsTable'
import { EquipmentTable } from '../components/Tables/EquipmentTable'
import { GemsTable } from '../components/Tables/GemsTable'
import { SkillsTable } from '../components/Tables/SkillsTable'
import { EnemiesTable } from '../components/Tables/EnemiesTable'

// ---------------------------------------------------------------------------
// Tab definitions
// ---------------------------------------------------------------------------

type TabId = 'cards' | 'relics' | 'equipment' | 'gems' | 'skills' | 'enemies'

interface Tab {
  id: TabId
  label: string
}

const TABS: Tab[] = [
  { id: 'cards', label: 'Cards' },
  { id: 'relics', label: 'Relics' },
  { id: 'equipment', label: 'Equipment' },
  { id: 'gems', label: 'Gems' },
  { id: 'skills', label: 'Skills' },
  { id: 'enemies', label: 'Enemies' },
]

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function Tables() {
  const [activeTab, setActiveTab] = useState<TabId>('cards')

  return (
    <div className="flex flex-col flex-1 min-h-0">
      {/* Page header */}
      <div className="px-6 pt-6 pb-5 gradient-header">
        <h1 className="text-2xl font-bold text-gray-100 mb-1">Balance Tables</h1>
        <p className="text-sm text-gray-400 mb-5">
          Browse, sort, and edit game data. Changes write back to .tres files.
        </p>
        {/* Pill tab bar */}
        <div className="flex gap-2" role="tablist">
          {TABS.map(tab => (
            <button
              key={tab.id}
              role="tab"
              aria-selected={activeTab === tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={[
                'px-4 py-1.5 text-sm font-medium rounded-full transition-all duration-200',
                activeTab === tab.id
                  ? 'gradient-purple text-white glow-purple'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-[var(--bg-elevated)]',
              ].join(' ')}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table content */}
      <div className="flex-1 overflow-auto p-6">
        {activeTab === 'cards' && <CardsTable />}
        {activeTab === 'relics' && <RelicsTable />}
        {activeTab === 'equipment' && <EquipmentTable />}
        {activeTab === 'gems' && <GemsTable />}
        {activeTab === 'skills' && <SkillsTable />}
        {activeTab === 'enemies' && <EnemiesTable />}
      </div>
    </div>
  )
}
