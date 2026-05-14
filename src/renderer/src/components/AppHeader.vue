<template>
  <div class="header">
    <div class="header-left">
      <span class="brand">AI数字人</span>
      <span class="build-tag" :title="`build ${appBuildTime}`">v{{ appVersion }} · {{ appBuildTime }}</span>
    </div>
    <div class="header-right">
      <t-dropdown :maxColumnWidth="false" :min-column-width="88" panel-top-content="" placement="bottom-right"
        @click="action.clickHandler">
        <div class="header-right-item" style="width: 70px">
          <img src="@renderer/assets/images/icons/setting.svg" alt="setting" />
          <div class="header-right-item-text">{{ $t('common.setting.title') }}</div>
        </div>
        <t-dropdown-menu>
          <t-dropdown-item :value="item.value" v-for="(item, index) in state.menuList" :key="index + 'menuList'"
            class="dropdown-box">
            <div class="language-switch-box">
              <span>{{ item.content }}</span>
              <img v-if="item.value === 'languageSwitch'" src="@renderer/assets/images/icons/switch.svg" alt="switch"
                class="language-switch" />
            </div>

            <t-dropdown-menu v-if="item.children">
              <t-dropdown-item v-for="(itemChildren, indexChildren) in item.children"
                :key="indexChildren + 'itemChildren'" :value="itemChildren.value"
                :class="itemChildren.value === home.homeState.language ? 'language-active' : ''">{{ itemChildren.content
                }}</t-dropdown-item>
            </t-dropdown-menu>
          </t-dropdown-item>
        </t-dropdown-menu>
      </t-dropdown>
      <div class="header-right-item" @click="action.minimize">
        <t-tooltip :content="$t('common.header.minimizeText')">
          <img src="@renderer/assets/images/icons/minimize.png" />
        </t-tooltip>
      </div>
      <div class="header-right-item" @click="action.maximize">
        <t-tooltip :content="state.isMaximized ? $t('common.header.restoreText') : $t('common.header.minimizeText')
          ">
          <img src="@renderer/assets/images/icons/maximize.png" />
        </t-tooltip>
      </div>
      <div class="header-right-item" @click="action.close">
        <t-tooltip :content="$t('common.header.closeText')">
          <img src="@renderer/assets/images/icons/close.png" />
        </t-tooltip>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, watch } from 'vue'
import { Client } from '@renderer/client'
import { useHomeStore } from '@renderer/stores/home.js'
import { useI18n } from 'vue-i18n'
import { saveContext } from '@renderer/api/index.js'
import { lang_ } from '@renderer/utils/const.js'
const { locale, t } = useI18n()
const home = useHomeStore()

// vite 注入：版本号 + 编译时间，用于 header 右侧的小标签
// eslint-disable-next-line no-undef
const appVersion = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : '0.0.0'
// eslint-disable-next-line no-undef
const appBuildTime = typeof __BUILD_TIME__ !== 'undefined' ? __BUILD_TIME__ : 'dev'
const state = reactive({
  isMaximized: false,
  menuList: [
    {
      content: '用户协议',
      key: 'common.setting.tab.userAgreementText',
      value: 'agreement'
    },
    {
      content: '打开日志',
      key: 'common.setting.tab.openLogText',
      value: 'openLog'
    },
    {
      content: '语言切换',
      value: 'languageSwitch',
      key: 'common.setting.tab.languageSwitchText',
      children: [
        {
          content: '中文',
          key: 'common.setting.languageSwitch.languageZhText',
          value: 'zh'
        },
        {
          content: '英文',
          key: 'common.setting.languageSwitch.languageEnText',
          value: 'en'
        }
      ]
    }
  ]
})
watch(locale, () => {
  state.menuList.forEach((el) => {
    el.content = t(el.key)
    if (el.children) el.children.forEach((item) => (item.content = t(item.key)))
  })
})
const action = {
  init() {
    action.setIsMaximized()
  },
  async setIsMaximized() {
    state.isMaximized = await Client.app.isMaximized()
  },
  minimize() {
    Client.app.minimize()
  },
  maximize() {
    Client.app.maximize()
    action.setIsMaximized()
  },
  close() {
    Client.app.close()
  },
  clickHandler({ value }) {
    if (value === 'agreement') {
      home.setAgreementVisible(true)
    } else if (value === 'openLog') {
      Client.app.openLog()
    } else {
      if (value === 'languageSwitch') return
      window.localStorage.setItem('language', value)
      locale.value = value
      saveContextAjax(value)
      home.setLanguage(value)
    }
  }
}
const saveContextAjax = async (lang) => {
  try {
    const res = await saveContext(lang_, lang)
    console.log(res)
  } catch (error) {
    console.log(error)
  }
}
</script>
<style>
.dropdown-box .t-icon-chevron-right {
  display: none !important;
}

.language-active {
  color: #166aff !important;
}

.t-dropdown__item-text .language-switch {
  width: 16px;
  display: block;
  margin-left: 14px;
}
</style>

<style lang="less" scoped>
.language-switch-box {
  display: flex;
}

.header {
  width: 100%;
  height: 60px;
  padding: 12px 20px 12px 14px;
  display: flex;
  position: fixed;
  top: 0;
  left: 0;
  align-items: center;
  background-color: #fff;
  -webkit-app-region: drag;
  -webkit-user-select: none;
  z-index: 999;
  box-shadow: inset 0px -1px 0px 0px #f2f2f4;

  &-left {
    width: 100%;
    flex: 1;
    height: 100%;
    display: flex;
    align-items: center;
    gap: 12px;

    .logo {
      width: 110px;
      height: 36px;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      height: 36px;
      padding: 0 4px;
      font-family: 'HarmonyOS Sans SC', 'Alibaba Sans', system-ui, sans-serif;
      font-size: 20px;
      font-weight: 700;
      letter-spacing: 2px;
      background: linear-gradient(135deg, #ffb800 0%, #ff7a00 100%);
      -webkit-background-clip: text;
      background-clip: text;
      -webkit-text-fill-color: transparent;
      user-select: none;
    }

    .build-tag {
      font-family: 'Consolas', 'JetBrains Mono', monospace;
      font-size: 11px;
      font-weight: 400;
      color: #999;
      padding: 2px 6px;
      border-radius: 4px;
      background: #f6f6f6;
      user-select: none;
      letter-spacing: 0;
    }
  }

  &-right {
    display: flex;
    align-items: center;
    gap: 8px;

    &-item {
      -webkit-app-region: no-drag;
      width: 30px;
      height: 30px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 4px;

      &:hover {
        background-color: #f2f2f4;
      }

      &-text {
        font-family: PingFang SC, PingFang SC;
        font-weight: 400;
        font-size: 12px;
        color: #000000;
        line-height: 14px;
        text-align: left;
      }

      img {
        width: 20px;
        height: 20px;
      }
    }
  }
}
</style>
