import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'

export function AppLayout() {
  return (
    <div className="flex min-h-screen text-gray-100" style={{ background: 'var(--bg-deep)' }}>
      <Sidebar />
      <main className="flex-1 flex flex-col overflow-auto bg-grid-pattern">
        <Outlet />
      </main>
    </div>
  )
}
