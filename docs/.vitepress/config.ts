import { defineConfig } from 'vitepress'
import { readFileSync, existsSync } from 'fs'
import { resolve } from 'path'

// 讀取 sync script 自動生成的統一 sidebar
function loadSidebar() {
  const sidebarPath = resolve(__dirname, 'sidebar-generated.json')
  if (existsSync(sidebarPath)) {
    try {
      const unified = JSON.parse(readFileSync(sidebarPath, 'utf-8'))
      return {
        '/starters/': unified,
        '/showcase/': unified,
        '/frontend/': unified,
      }
    } catch {
      console.warn('Failed to parse sidebar-generated.json, using fallback')
    }
  }
  return {
    '/starters/': [
      { text: 'Starters', items: [{ text: '總覽', link: '/starters/' }] },
      { text: 'Showcase', items: [
        { text: '後端範例', link: '/showcase/' },
        { text: '前端範例', link: '/frontend/' },
      ]},
    ],
  }
}

export default defineConfig({
  title: 'Company Starters',
  description: '企業級 Spring Boot Starter 共用元件庫 — 技術文件中心',
  lang: 'zh-TW',
  base: '/starter-portal/',
  ignoreDeadLinks: true,

  head: [
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
    ['meta', { name: 'og:type', content: 'website' }],
    ['meta', { name: 'og:title', content: 'Company Starters — 技術文件中心' }],
    ['meta', { name: 'og:description', content: '企業級 Spring Boot Starter 共用元件庫文件' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Company Starters',

    nav: [
      { text: '首頁', link: '/' },
      {
        text: '文件',
        items: [
          { text: 'Starters 總覽', link: '/starters/' },
          { text: 'Showcase 後端', link: '/showcase/' },
          { text: 'Showcase 前端', link: '/frontend/' },
        ],
      },
      { text: 'README 規範', link: '/template' },
      {
        text: '資源',
        items: [
          { text: 'GitHub', link: 'https://github.com/yanchen184/company-common-starters' },
          { text: 'Showcase Demo', link: 'https://github.com/yanchen184/starter-showcase' },
        ],
      },
    ],

    sidebar: loadSidebar(),

    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '搜尋文件', buttonAriaLabel: '搜尋' },
          modal: {
            noResultsText: '找不到相關結果',
            resetButtonTitle: '清除搜尋',
            footer: { selectText: '選擇', navigateText: '切換', closeText: '關閉' },
          },
        },
      },
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/yanchen184/company-common-starters' },
    ],

    footer: {
      message: 'Company Common Starters — 企業級共用元件庫',
      copyright: `文件自動同步自各 GitHub 倉庫`,
    },

    editLink: {
      pattern: 'https://github.com/yanchen184/starter-portal/edit/master/docs/:path',
      text: '在 GitHub 上編輯此頁',
    },

    lastUpdated: {
      text: '最後更新',
    },

    outline: {
      label: '本頁目錄',
      level: [2, 3],
    },

    docFooter: {
      prev: '上一頁',
      next: '下一頁',
    },

    returnToTopLabel: '回到頂部',
    sidebarMenuLabel: '選單',
    darkModeSwitchLabel: '深色模式',
  },
})
