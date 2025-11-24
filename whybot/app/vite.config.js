import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 3003,
    proxy: {
      '/api': 'http://localhost:6823',
      '/ws': {
        target: 'ws://localhost:6823',
        ws: true,
      },
    },
  },
});