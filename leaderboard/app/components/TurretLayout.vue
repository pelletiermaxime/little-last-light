<script setup lang="ts">
import type { TurretLayout } from '../../convex/runDetails'

const props = defineProps<{ layout: TurretLayout; username: string }>()
// Scale dots with the arena so even unusually large arenas remain readable.
const radius = computed(() => Math.max(7, Math.min(props.layout.width, props.layout.height) / 65))
const legend = computed(() => [
  { type: 'damage', label: 'Damage', color: '#9bddff' },
  { type: 'pulse', label: 'Slow', color: '#d3a4ff' },
  { type: 'sniper', label: 'Watchlight', color: '#fff0cc' },
  { type: undefined, label: 'Type not recorded', color: '#a3b5ba' },
].map(item => ({ ...item, count: props.layout.turrets.filter(turret => turret.type === item.type).length })).filter(item => item.count > 0))
</script>

<template>
  <figure class="turret-layout">
    <svg :viewBox="`0 0 ${layout.width} ${layout.height}`" role="img" :aria-label="`${username}'s run layout: ${layout.turrets.length} turrets`">
      <title>{{ username }}'s turret layout at run end</title>
      <desc>Top-down arena. Blue circles mark damage turrets, purple diamonds mark slow turrets, ivory squares mark Watchlight snipers, and gray circles mark turrets whose type was not recorded. The cross marks the arena center.</desc>
      <rect width="100%" height="100%" fill="#101820" />
      <path :d="`M ${layout.width / 2} 0 V ${layout.height} M 0 ${layout.height / 2} H ${layout.width}`" stroke="#354249" stroke-dasharray="5 10" vector-effect="non-scaling-stroke" />
      <g v-for="(turret, index) in layout.turrets" :key="index" :transform="`translate(${turret.x * layout.width} ${turret.y * layout.height})`">
        <title>{{ turret.type === 'sniper' ? 'Watchlight sniper' : turret.type === 'pulse' ? 'Slow turret' : turret.type === 'damage' ? 'Damage turret' : 'Turret · Type not recorded' }}</title>
        <template v-if="turret.type === 'pulse'">
          <circle :r="radius * 1.85" fill="#503767" />
          <path :d="`M 0 ${-radius * 1.3} L ${radius * 1.3} 0 L 0 ${radius * 1.3} L ${-radius * 1.3} 0 Z`" fill="#d3a4ff" />
        </template>
        <template v-else-if="turret.type === 'sniper'">
          <rect :x="-radius * 1.65" :y="-radius * 1.65" :width="radius * 3.3" :height="radius * 3.3" :rx="radius * 0.25" fill="#36566f" />
          <rect :x="-radius" :y="-radius" :width="radius * 2" :height="radius * 2" fill="#fff0cc" />
        </template>
        <template v-else>
          <circle :r="radius * 1.85" :fill="turret.type === 'damage' ? '#36566f' : '#354249'" />
          <circle :r="radius" :fill="turret.type === 'damage' ? '#9bddff' : '#a3b5ba'" />
        </template>
      </g>
    </svg>
    <figcaption>
      <span>{{ layout.turrets.length }} {{ layout.turrets.length === 1 ? 'turret' : 'turrets' }} · Positions at run end · Arena center marked</span>
      <div class="legend"><span v-for="item in legend" :key="item.label"><span class="turret-dot" :class="{ diamond: item.type === 'pulse', square: item.type === 'sniper' }" :style="{ background: item.color }" aria-hidden="true" /> {{ item.count }} {{ item.label }}</span></div>
      <template v-if="layout.upgrades"><br><span>Upgrades · Damage level {{ layout.upgrades.damage }} · Fire rate level {{ layout.upgrades.fireRate }} · Health level {{ layout.upgrades.health }}</span></template>
    </figcaption>
  </figure>
</template>

<style scoped>
.legend{display:flex;flex-wrap:wrap;gap:4px 16px}.diamond{border-radius:0!important;transform:rotate(45deg)}
.square{border-radius:0!important}
.turret-layout{margin:0;max-width:560px}.turret-layout svg{display:block;width:100%;max-height:360px;border:1px solid #354249;border-radius:8px;background:#101820}.turret-layout figcaption{margin-top:12px;color:#a3b5ba;font-size:12px;line-height:1.6}.turret-dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#9bddff;margin-right:4px}
</style>
