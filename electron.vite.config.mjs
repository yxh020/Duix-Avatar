import { resolve } from 'path'
import { readFileSync } from 'fs'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import vue from '@vitejs/plugin-vue'

// 注入版本号 + 编译时间到渲染层，AppHeader 显示用
const pkg = JSON.parse(readFileSync(resolve('package.json'), 'utf8'))
const buildTime = new Date()
const pad = (n) => String(n).padStart(2, '0')
const buildTimeStr =
  `${buildTime.getFullYear()}-${pad(buildTime.getMonth() + 1)}-${pad(buildTime.getDate())}` +
  ` ${pad(buildTime.getHours())}:${pad(buildTime.getMinutes())}`

const defines = {
  __APP_VERSION__: JSON.stringify(pkg.version),
  __BUILD_TIME__: JSON.stringify(buildTimeStr)
}

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    define: defines
  },
  preload: {
    plugins: [externalizeDepsPlugin()]
  },
  renderer: {
    resolve: {
      alias: {
        '@renderer': resolve('src/renderer/src')
      }
    },
    plugins: [vue()],
    define: defines
  }
})
