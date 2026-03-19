import { defineConfig } from 'vitepress'

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
      { text: '開發日誌', link: '/guide/01-架構設計與PoC驗證' },
      { text: 'Showcase', link: '/showcase/' },
    ],

    sidebar: {
      '/starters/': [
        {
          text: 'Starters',
          items: [
            { text: '總覽', link: '/starters/' },
            { text: 'Security', link: '/starters/care-security' },
            { text: 'Log', link: '/starters/common-log-spring-boot-starter' },
            { text: 'Response', link: '/starters/common-response-spring-boot-starter' },
            { text: 'JPA', link: '/starters/common-jpa-spring-boot-starter' },
            { text: 'Attachment', link: '/starters/common-attachment-spring-boot-starter' },
            { text: 'Report', link: '/starters/common-report' },
          ],
        },
      ],
      '/guide/': [
        {
          text: '開發日誌',
          items: [
            { text: '01 - 架構設計與 PoC 驗證', link: '/guide/01-架構設計與PoC驗證' },
            { text: '02 - 安全強化與 LDAP 整合', link: '/guide/02-安全強化與LDAP整合' },
            { text: '03 - 驗證碼與 Starter 整合', link: '/guide/03-驗證碼與Common-Starter整合' },
            { text: '04 - 自然人憑證與前端整合', link: '/guide/04-自然人憑證與前端整合' },
            { text: '05 - TDD 可行性評估', link: '/guide/05-TDD可行性評估' },
            { text: '06 - CodeReview 規範', link: '/guide/06-CodeReview規範' },
            { text: '07 - 品質工程與模組重構', link: '/guide/07-品質工程與模組重構' },
            { text: '08 - 附件管理與報表模組', link: '/guide/08-附件管理與報表模組' },
            { text: '09 - 報表模組增強', link: '/guide/09-報表模組增強' },
          ],
        },
      ],
      '/showcase/': [
        {
          text: 'Showcase',
          items: [
            { text: '後端 (Spring Boot)', link: '/showcase/' },
            { text: '前端 (React)', link: '/showcase/frontend' },
          ],
        },
      ],
    },

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
