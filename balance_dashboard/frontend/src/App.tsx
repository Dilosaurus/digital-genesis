import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Frame } from './components/shell/Frame'
import { Vision } from './pages/Vision'
import { Stub } from './pages/Stub'
import { CodexCards } from './pages/CodexCards'
import { CardDetail } from './pages/CardDetail'
import { CodexGems } from './pages/CodexGems'
import { CodexRelics } from './pages/CodexRelics'
import { CodexEquipment } from './pages/CodexEquipment'
import { CodexEnemies } from './pages/CodexEnemies'
import { Characters } from './pages/Characters'
import { CharacterDetail } from './pages/CharacterDetail'
import { Lore } from './pages/Lore'
import { Depths } from './pages/Depths'
import { Mechanics } from './pages/Mechanics'
import { Changelog } from './pages/Changelog'
import { Roadmap } from './pages/Roadmap'
import { Decisions } from './pages/Decisions'

// ─── deus.exe // codex — router ───────────────────────────────────────────

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Frame />}>
          <Route index element={<Vision />} />
          <Route path="lore" element={<Lore />} />
          <Route path="characters" element={<Characters />} />
          <Route path="characters/:id" element={<CharacterDetail />} />
          <Route path="depths" element={<Depths />} />
          <Route path="mechanics" element={<Mechanics />} />
          <Route path="codex/cards" element={<CodexCards />} />
          <Route path="codex/cards/:id" element={<CardDetail />} />
          <Route path="codex/gems" element={<CodexGems />} />
          <Route path="codex/relics" element={<CodexRelics />} />
          <Route path="codex/equipment" element={<CodexEquipment />} />
          <Route path="codex/enemies" element={<CodexEnemies />} />
          <Route path="roadmap" element={<Roadmap />} />
          <Route path="changelog" element={<Changelog />} />
          <Route path="decisions" element={<Decisions />} />
          <Route path="lab/tables" element={<Stub />} />
          <Route path="lab/simulator" element={<Stub />} />
          <Route path="lab/graph" element={<Stub />} />
          <Route path="drafts" element={<Stub />} />
          <Route path="*" element={<Stub />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
