<script setup lang="ts">
import { useData } from 'vitepress'
import { computed } from 'vue'

interface ChangeEntry {
  date: string
  summary: string
  linesAdded: number
  linesRemoved: number
  changeType: 'new' | 'content' | 'deleted'
}

const { frontmatter } = useData()

const changes = computed<ChangeEntry[]>(() => frontmatter.value.changelog ?? [])

const typeLabel: Record<string, string> = {
  new: '新增',
  content: '更新',
  deleted: '移除',
}

const typeClass: Record<string, string> = {
  new: 'badge-new',
  content: 'badge-update',
  deleted: 'badge-delete',
}
</script>

<template>
  <div v-if="changes.length" class="changelog-section">
    <details>
      <summary class="changelog-title">
        最近變更 ({{ changes.length }})
      </summary>
      <div class="changelog-list">
        <div v-for="(item, i) in changes" :key="i" class="changelog-item">
          <span class="changelog-date">{{ item.date }}</span>
          <span :class="['changelog-badge', typeClass[item.changeType]]">
            {{ typeLabel[item.changeType] }}
          </span>
          <span class="changelog-summary">{{ item.summary }}</span>
          <span class="changelog-stats" v-if="item.changeType === 'content'">
            <span class="stat-add">+{{ item.linesAdded }}</span>
            <span class="stat-remove">-{{ item.linesRemoved }}</span>
          </span>
        </div>
      </div>
    </details>
  </div>
</template>

<style scoped>
.changelog-section {
  margin-top: 48px;
  padding-top: 24px;
  border-top: 1px solid var(--vp-c-divider);
}

.changelog-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--vp-c-text-1);
  cursor: pointer;
  user-select: none;
}

.changelog-list {
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.changelog-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  line-height: 1.5;
  flex-wrap: wrap;
}

.changelog-date {
  color: var(--vp-c-text-3);
  font-family: var(--vp-font-family-mono);
  font-size: 12px;
  flex-shrink: 0;
}

.changelog-badge {
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
  flex-shrink: 0;
}

.badge-new {
  background: rgba(16, 185, 129, 0.15);
  color: #059669;
}

.dark .badge-new {
  background: rgba(52, 211, 153, 0.15);
  color: #34d399;
}

.badge-update {
  background: rgba(59, 130, 246, 0.15);
  color: #2563eb;
}

.dark .badge-update {
  background: rgba(96, 165, 250, 0.15);
  color: #60a5fa;
}

.badge-delete {
  background: rgba(239, 68, 68, 0.15);
  color: #dc2626;
}

.dark .badge-delete {
  background: rgba(248, 113, 113, 0.15);
  color: #f87171;
}

.changelog-summary {
  color: var(--vp-c-text-2);
}

.changelog-stats {
  font-family: var(--vp-font-family-mono);
  font-size: 12px;
  flex-shrink: 0;
}

.stat-add {
  color: #059669;
}

.dark .stat-add {
  color: #34d399;
}

.stat-remove {
  color: #dc2626;
  margin-left: 4px;
}

.dark .stat-remove {
  color: #f87171;
}
</style>
