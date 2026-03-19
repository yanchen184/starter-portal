import { defineConfig } from 'vitepress'
import { readFileSync, existsSync } from 'fs'
import { resolve } from 'path'

// 讀取 sync script 自動生成的 sidebar
function loadSidebar() {
  const sidebarPath = resolve(__dirname, 'sidebar-generated.json')
  if (existsSync(sidebarPath)) {
    try {
      return JSON.parse(readFileSync(sidebarPath, 'utf-8'))
    } catch {
      console.warn('Failed to parse sidebar-generated.json, using fallback')
    }
  }
  // Fallback: 手動 sidebar
  return {
    '/starters/': [{ text: 'Starters', items: [{ text: '總覽', link: '/starters/' }] }],
    '/showcase/': [{ text: 'Showcase 後端', items: [{ text: 'README', link: '/showcase/' }] }],
    '/frontend/': [{ text: 'Showcase 前端', items: [{ text: 'README', link: '/frontend/' }] }],
  }
}

export default defineConfig({
  title: 'Company Starters',
  description: '公司共用 Spring Boot Starter 文件入口',
  lang: 'zh-TW',
  base: '/starter-portal/',
  ignoreDeadLinks: true,

  themeConfig: {
    nav: [
      { text: '首頁', link: '/' },
      { text: 'Starters', link: '/starters/' },
      { text: 'Showcase 後端', link: '/showcase/' },
      { text: 'Showcase 前端', link: '/frontend/' },
    ],

    sidebar: loadSidebar(),

    search: {
      provider: 'local',
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/yanchen184' },
    ],

    footer: {
      message: 'Company Common Starters Documentation',
    },
  },
})
