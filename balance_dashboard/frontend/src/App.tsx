import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { AppLayout } from './components/Layout/AppLayout'
import Overview from './pages/Overview'
import Tables from './pages/Tables'
import Graph from './pages/Graph'
import Simulator from './pages/Simulator'
import CardGallery from './pages/CardGallery'
import ItemGallery from './pages/ItemGallery'

// ---------------------------------------------------------------------------
// Placeholder page — shown until real page components are built in Phase 2
// ---------------------------------------------------------------------------

interface PlaceholderPageProps {
  title: string
}

function PlaceholderPage({ title }: PlaceholderPageProps) {
  return (
    <div className="flex flex-col items-center justify-center flex-1 gap-4 p-12 text-center">
      <div className="w-16 h-16 rounded-full bg-gray-800 flex items-center justify-center">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.5}
          strokeLinecap="round"
          strokeLinejoin="round"
          className="w-8 h-8 text-purple-400"
          aria-hidden
        >
          <path d="M12 2L2 7l10 5 10-5-10-5z" />
          <path d="M2 17l10 5 10-5" />
          <path d="M2 12l10 5 10-5" />
        </svg>
      </div>
      <h1 className="text-2xl font-semibold text-gray-100">{title}</h1>
      <p className="text-gray-500 max-w-sm text-sm">
        This page will be implemented in Phase 2. The routing, layout, types,
        hooks, and simulator utilities are ready.
      </p>
    </div>
  )
}

// ---------------------------------------------------------------------------
// App root with React Router
// ---------------------------------------------------------------------------

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<Overview />} />
          <Route path="tables" element={<Tables />} />
          <Route path="gallery" element={<CardGallery />} />
          <Route path="items" element={<ItemGallery />} />
          <Route path="graph" element={<Graph />} />
          <Route path="simulator" element={<Simulator />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
