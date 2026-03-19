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
      { text: 'Showcase 後端', link: '/showcase/' },
      { text: 'Showcase 前端', link: '/frontend/' },
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
            { text: 'Notification', link: '/starters/common-notification' },
          ],
        },
      ],
      '/showcase/': [
        {
          text: 'Showcase 後端',
          items: [
            { text: 'Starter Showcase', link: '/showcase/' },
          ],
        },
      ],
      '/frontend/': [
        {
          text: 'Showcase 前端',
          items: [
            { text: 'React Frontend', link: '/frontend/' },
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
