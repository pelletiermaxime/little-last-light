<script setup lang="ts">
import { api } from '../../convex/_generated/api'
const configured = Boolean(useRuntimeConfig().public.convex.url)
const { data, status, error, refresh } = await useConvexQuery(api.achievements.stats, {}, { enabled: configured })
const percent = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 })
</script>

<template>
  <section class="achievement-stats" aria-labelledby="achievements-title">
    <div class="toolbar">
      <div><p class="eyebrow">COMMUNITY ACHIEVEMENTS</p><h2 id="achievements-title">Small victories against the dark</h2></div>
      <button v-if="error" @click="refresh()">Retry achievements</button>
    </div>
    <p v-if="!configured" class="state">Community achievements are not connected yet.</p>
    <p v-else-if="error" class="state">We couldn’t load achievements. Please try again.</p>
    <p v-else-if="status === 'pending' || !data" class="state">Gathering the community’s victories…</p>
    <template v-else>
      <p class="achievement-population">{{ data.totalPlayers.toLocaleString() }} tracked {{ data.totalPlayers === 1 ? 'player' : 'players' }} · Updates live</p>
      <ul class="achievement-list">
        <li v-for="achievement in data.achievements" :key="achievement.id">
          <div><h3>{{ achievement.name }}</h3><p>{{ achievement.description }}</p></div>
          <div class="achievement-completion"><strong>{{ data.totalPlayers ? `${percent.format(achievement.percentage)}%` : '—' }}</strong><span>{{ achievement.unlockedPlayers.toLocaleString() }} unlocked</span></div>
        </li>
      </ul>
      <p class="footnote">Unassisted play across releases, counted once per device or browser profile. Includes tracked players with no unlocks. Tracking starts with the achievements update; earlier play is not reconstructed. Clearing local game data creates a new identity.</p>
    </template>
  </section>
</template>

<style scoped>
.achievement-stats{margin-top:28px}.achievement-population{padding:0 30px 20px;margin:0;color:#a3b5ba;font-size:13px}.achievement-list{list-style:none;padding:0;margin:0}.achievement-list li{display:flex;align-items:center;justify-content:space-between;gap:24px;padding:22px 30px;border-top:1px solid #35424980}.achievement-list h3{font-size:16px;font-weight:550;margin:0 0 7px}.achievement-list p{font-size:14px;color:#a3b5ba;margin:0;line-height:1.5}.achievement-completion{text-align:right;flex-shrink:0;display:grid;gap:7px;font-variant-numeric:tabular-nums}.achievement-completion strong{font-size:23px;color:#ffcf7a;font-weight:500}.achievement-completion span{font-size:12px;color:#a3b5ba}.footnote{line-height:1.7}@media(max-width:600px){.achievement-list li{padding:20px;gap:14px}.achievement-population{padding:0 20px 20px}.achievement-completion strong{font-size:20px}}
</style>
