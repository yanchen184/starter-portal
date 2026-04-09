import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import ChangeLog from './ChangeLog.vue'
import { h } from 'vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'doc-after': () => h(ChangeLog),
    })
  },
} satisfies Theme
