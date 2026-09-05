export default defineNuxtConfig({
  compatibilityDate: '2026-09-05',
  ssr: false,
  modules: ['better-convex-nuxt'],
  convex: {
    auth: { enabled: false },
    defaults: { server: false, subscribe: true, auth: 'none' },
  },
  app: { head: { title: 'Little Last Light · Leaderboard', meta: [
    { name: 'description', content: 'The longest surviving lights. Explore Little Last Light records for each game version.' },
  ] } },
})
