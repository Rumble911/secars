import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The browser talks to Vite (localhost:5173) only. Vite forwards /api to Spring Boot,
// so the session cookie is same-origin and SameSite=Strict works as designed.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
    },
  },
});
