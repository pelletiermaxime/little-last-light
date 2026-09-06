<script setup lang="ts">
import { api } from '../../convex/_generated/api'
const config = useRuntimeConfig()
const route = useRoute()
const router = useRouter()
const configured = Boolean(config.public.convex.url)
const version = computed(() => typeof route.query.version === 'string' ? route.query.version : '')
const { data: versions, status: versionsStatus, error: versionsError, refresh: refreshVersions } = await useConvexQuery(api.scores.versions, {}, {
  enabled: configured,
})
watch(versions, available => {
  if (!version.value && available?.[0]) router.replace({ query: { version: available[0] } })
}, { immediate: true })
const { data: scores, status, error, refresh } = await useConvexQuery(api.scores.list, () => version.value ? { version: version.value } : undefined, {
  enabled: configured,
})
const options = computed(() => [...new Set([version.value, ...(versions.value ?? [])].filter(Boolean))])
const energyFormat = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 })
function energy(value: number | undefined) {
  return value === undefined ? 'Not recorded' : energyFormat.format(Math.floor(value))
}
function selectVersion(event: Event) {
  router.replace({ query: { version: (event.target as HTMLSelectElement).value } })
}
function time(ms: number) {
  return `${Math.floor(ms / 60000).toString().padStart(2, '0')}:${Math.floor(ms / 1000 % 60).toString().padStart(2, '0')}.${(ms % 1000).toString().padStart(3, '0')}`
}
</script>

<template>
  <main>
    <nav><a href="https://pelletiermaxime.github.io/little-last-light-demo/">← Play Little Last Light</a><span>THE RECORDS</span></nav>
    <header>
      <div class="spark" aria-hidden="true">✦</div>
      <p class="eyebrow">LITTLE LAST LIGHT</p>
      <h1>Some lights<br>last a little longer.</h1>
      <p class="intro">A refuge built. A darkness held back.<br>The longest survival runs, one version at a time.</p>
    </header>
    <section aria-labelledby="board-title">
      <div class="toolbar">
        <div><p class="eyebrow">SURVIVAL LEADERBOARD</p><h2 id="board-title">The last lights</h2></div>
        <div class="actions">
          <label for="version">Game version<select id="version" :value="version" :disabled="!options.length" @change="selectVersion"><option v-if="!options.length" value="">No versions yet</option><option v-for="item in options" :key="item" :value="item">v{{ item }}</option></select></label>
          <span v-if="configured && !error && !versionsError" class="eyebrow">Updates live</span>
          <button v-if="error || versionsError" @click="refreshVersions(); version && refresh()">Retry</button>
        </div>
      </div>
      <div aria-live="polite">
        <p v-if="!configured" class="state">The online leaderboard is not connected yet. You can still play and keep your records locally.</p>
        <p v-else-if="status === 'pending' || versionsStatus === 'pending'" class="state">Gathering the last lights…</p>
        <p v-else-if="error || versionsError" class="state">We couldn’t reach the leaderboard. Please try again in a moment.</p>
        <p v-else-if="!scores?.length" class="state">No lights recorded{{ version ? ` for v${version}` : '' }} yet. Beat your personal best in the game to publish the first.</p>
        <div v-else class="table-wrap"><table>
          <caption class="sr-only">Top 100 survival records for version {{ version }}</caption>
          <thead><tr><th scope="col">Rank</th><th scope="col">Keeper of the light</th><th scope="col" class="duration">Survived</th><th scope="col" class="energy">Energy<span class="column-note">Invested / Earned</span></th></tr></thead>
          <tbody v-for="score in scores" :key="`${version}:${score.rank}:${score.username}:${score.achievedAt}`" :class="{ first: score.rank === 1 }">
            <tr>
              <td class="rank">{{ String(score.rank).padStart(2, '0') }}</td>
              <td class="keeper">{{ score.username }}</td>
              <td class="duration">{{ time(score.durationMs) }}</td>
              <td class="energy">
                <span :aria-label="`Defense investment: ${energy(score.energyInvested)}`">{{ energy(score.energyInvested) }}</span>
                <span class="energy-total" :aria-label="`Energy earned: ${energy(score.energyEarned)}`">/ {{ energy(score.energyEarned) }}</span>
              </td>
            </tr>
            <tr class="layout-row"><td colspan="4">
              <details v-if="score.turretLayout">
                <summary :aria-label="`View ${score.username}'s turret layout`">Turret layout <span class="layout-count">{{ score.turretLayout.turrets.length }} {{ score.turretLayout.turrets.length === 1 ? 'turret' : 'turrets' }}</span></summary>
                <TurretLayout :layout="score.turretLayout" :username="score.username" />
              </details>
              <span v-else class="missing-layout">Turret layout not recorded</span>
            </td></tr>
          </tbody>
        </table></div>
      </div>
      <p class="footnote">Top 100 · Best published run per device and version · Longer is better</p>
      <p class="data-note">Invested: energy spent on the turrets and persistent damage, fire rate, and health upgrades used for this run. The starting turret is free; unspent energy is excluded. Earned: energy generated during the run. Compare survival time alongside investment to see how much progression supported each defense. Older runs may not have this data.</p>
    </section>
    <footer>Beat your personal best, choose a username, and publish from the game.<br>No account needed. These are community-submitted, unverified runs.</footer>
  </main>
</template>

<style>
:root{font-family:Inter,ui-sans-serif,system-ui,sans-serif;color:#edf2ed;background:#101820;color-scheme:dark;font-synthesis:none}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 50% 8%,#37403155,transparent 46%);min-height:100vh}main{max-width:1020px;margin:auto;padding:32px 40px 56px}a{color:#c7d8d6;text-decoration:none}a:hover{text-decoration:underline}nav{display:flex;justify-content:space-between;font-size:13px;gap:20px}nav span,.eyebrow{font-size:11px;letter-spacing:.2em;color:#ffcf7a;font-weight:650}header{padding:64px 0 54px;text-align:center}.spark{font-size:40px;color:#ffcf7a;text-shadow:0 0 40px #ffcf7a80;margin-bottom:26px}h1{font-family:Georgia,serif;font-weight:400;font-size:clamp(40px,6vw,66px);line-height:1.08;letter-spacing:-.035em;margin:20px 0}.intro,footer{color:#a3b5ba;line-height:1.8;font-size:15px}section{border:1px solid #354249;border-radius:14px;overflow:hidden;background:#18232bd9;box-shadow:0 22px 60px #0002}.toolbar{display:flex;justify-content:space-between;align-items:center;padding:28px 30px;gap:24px}.eyebrow{margin:0 0 10px}h2{font-family:Georgia,serif;font-size:28px;font-weight:400;margin:0}.actions{display:flex;align-items:end;gap:12px}label{font-size:12px;color:#a3b5ba;display:grid;gap:7px}select,button{font:inherit;color:#edf2ed;border:1px solid #536368;background:#223139;padding:10px 14px;border-radius:7px;min-height:42px}button{cursor:pointer;font-size:13px}button:hover{border-color:#ffcf7a}button:disabled{opacity:.5;cursor:default}a:focus-visible,button:focus-visible,select:focus-visible{outline:2px solid #ffcf7a;outline-offset:4px}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;text-align:left}th{font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:#a3b5ba;font-weight:500;padding:15px 30px;background:#111c2380}td{padding:20px 30px;border-top:1px solid #35424980;font-size:15px}.rank{color:#a3b5ba;width:90px;font-variant-numeric:tabular-nums}.duration{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}.first{background:#ffcf7a09}.first .rank,.first .duration{color:#ffcf7a}.footnote{font-size:12px;color:#a3b5ba;border-top:1px solid #354249;margin:0;padding:20px 30px}.state{padding:45px 30px;text-align:center;color:#b8c9cb;line-height:1.7}footer{text-align:center;font-size:12px;padding:30px 0 0}.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)}@media(max-width:600px){main{padding:24px 18px}nav span{display:none}header{padding:48px 0 36px}.toolbar{align-items:start;flex-direction:column;padding:24px 20px}.actions{width:100%;justify-content:space-between}td,th{padding:16px 14px}.footnote{padding:18px 20px;line-height:1.7}h1{font-size:42px}}
</style>

<style>
.column-note{display:block;text-transform:none;letter-spacing:0;margin-top:6px;font-size:10px}.energy{text-align:right;font-variant-numeric:tabular-nums}.energy-total{display:block;color:#a3b5ba;font-size:12px;margin-top:5px}.keeper{overflow-wrap:anywhere}.layout-row td{border-top:0;padding:0 30px 18px}.layout-row summary{cursor:pointer;color:#9bddff;font-size:12px;width:fit-content;padding:8px 0}.layout-row summary:focus-visible{outline:2px solid #ffcf7a;outline-offset:4px}.layout-count{color:#a3b5ba;margin-left:10px}.layout-row details[open] summary{margin-bottom:12px}.missing-layout{color:#a3b5ba;font-size:12px}.data-note{margin:0;padding:0 30px 20px;color:#a3b5ba;font-size:12px;line-height:1.7}@media(max-width:600px){td,th{padding:14px 8px;font-size:12px}th{font-size:9px;letter-spacing:.03em}.rank{width:auto}.layout-row td{padding:0 14px 16px}.data-note{padding:0 20px 18px}.energy-total{font-size:11px}}
</style>
