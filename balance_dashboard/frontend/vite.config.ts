import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// ─────────────────────────────────────────────────────────────────────────────
// deus.exe // codex — vite config
// Backend: FastAPI on :8000
// Frontend dev: :3000 with proxy for /api and /assets
// ─────────────────────────────────────────────────────────────────────────────

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 3001,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
      // Card-game asset mount — deliberately NOT under /assets/ so it
      // doesn't collide with Vite's built JS/CSS (which live at
      // /assets/index-<hash>.js in production).
      '/media': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
