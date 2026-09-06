<script setup lang="ts">
import type { TurretLayout } from '../../convex/runDetails'

const props = defineProps<{ layout: TurretLayout; username: string }>()
// Scale dots with the arena so even unusually large arenas remain readable.
const radius = computed(() => Math.max(7, Math.min(props.layout.width, props.layout.height) / 65))
</script>

<template>
  <figure class="turret-layout">
    <svg :viewBox="`0 0 ${layout.width} ${layout.height}`" role="img" :aria-label="`${username}'s run layout: ${layout.turrets.length} turrets`">
      <title>{{ username }}'s turret layout at run end</title>
      <desc>Top-down arena. Blue circles mark the saved turret positions. The cross marks the arena center.</desc>
      <rect width="100%" height="100%" fill="#101820" />
      <path :d="`M ${layout.width / 2} 0 V ${layout.height} M 0 ${layout.height / 2} H ${layout.width}`" stroke="#354249" stroke-dasharray="5 10" vector-effect="non-scaling-stroke" />
      <g v-for="(turret, index) in layout.turrets" :key="index" :transform="`translate(${turret.x * layout.width} ${turret.y * layout.height})`">
        <circle :r="radius * 1.85" fill="#36566f" />
        <circle :r="radius" fill="#9bddff" />
      </g>
    </svg>
    <figcaption>
      <span><span class="turret-dot" aria-hidden="true" /> {{ layout.turrets.length }} {{ layout.turrets.length === 1 ? 'turret' : 'turrets' }} · Positions at run end · Arena center marked</span>
      <template v-if="layout.upgrades"><br><span>Upgrades · Damage level {{ layout.upgrades.damage }} · Fire rate level {{ layout.upgrades.fireRate }} · Health level {{ layout.upgrades.health }}</span></template>
    </figcaption>
  </figure>
</template>

<style scoped>
.turret-layout{margin:0;max-width:560px}.turret-layout svg{display:block;width:100%;max-height:360px;border:1px solid #354249;border-radius:8px;background:#101820}.turret-layout figcaption{margin-top:12px;color:#a3b5ba;font-size:12px;line-height:1.6}.turret-dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#9bddff;margin-right:4px}
</style>
