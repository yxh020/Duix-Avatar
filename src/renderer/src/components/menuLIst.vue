<template>
  <div class="menu-list">
    <div class="menu-top">
      <li v-for="(item, index) in state.menuList" :key="index" @click="handleClick(item)">
        <div class="content-body">
          <img class="icon" :src="item.active ? item.onIcon : item.offIcon" />
          <div class="text" :style="item.active ? 'color: #434AF9' : ''">
            {{ item.name }}
          </div>
          <img class="active-icon" v-if="item.active" :src="activeIcon" />
        </div>
      </li>
    </div>
    <div class="menu-bottom">
      <li @click="handleClick(serverSetting)">
        <div class="content-body">
          <div class="icon icon--svg" :style="serverSetting.active ? 'color: #434AF9' : 'color: #9097a5'">
            <ServerIcon size="28" />
          </div>
          <div class="text" :style="serverSetting.active ? 'color: #434AF9' : ''">
            {{ serverSetting.name }}
          </div>
          <img class="active-icon" v-if="serverSetting.active" :src="activeIcon" />
        </div>
      </li>
    </div>
  </div>
</template>
<script setup>
import { useRouter, useRoute } from 'vue-router'
import { reactive, watch, ref } from 'vue'
import { ServerIcon } from 'tdesign-icons-vue-next'
import onIcon from '../assets/images/home/menu/onHome.svg'
import activeIcon from '../assets/images/home/menu/active.svg'
import offIcon from '../assets/images/home/menu/offHome.svg'
import onBatchIcon from '../assets/images/home/menu/onBatch.svg'
import offBatchIcon from '../assets/images/home/menu/offBatch.svg'
import { useI18n } from 'vue-i18n'
const { t, locale } = useI18n()
const unRoute = useRoute()
const router = useRouter()
const obj = [
  {
    key: 'common.menu.text',
    name: t('common.menu.text'),
    onIcon,
    offIcon,
    active: true,
    path: '/home'
  },
  {
    key: 'common.menu.batchText',
    name: t('common.menu.batchText'),
    onIcon: onBatchIcon,
    offIcon: offBatchIcon,
    active: false,
    path: '/model/quick-create'
  }
]
const state = reactive({
  menuList: obj
})

// 服务器设置走独立块，固定在底部
const serverSetting = ref({
  key: 'common.menu.serverSetting',
  name: '服务器',
  active: false,
  path: '/settings/server'
})

watch(locale, () => {
  state.menuList.forEach((el) => {
    el.name = t(el.key)
  })
})
watch(
  () => unRoute.path,
  (newPath) => {
    state.menuList.forEach((el) => {
      el.active = newPath.includes(el.path)
    })
    serverSetting.value.active = newPath.startsWith(serverSetting.value.path)
  },
  { immediate: true }
)
const handleClick = (item) => {
  router.push(item.path)
}
</script>
<style lang="less" scoped>
.menu-list {
  width: 76px;
  background: #fff;
  position: fixed;
  left: 0;
  top: 0;
  padding-top: 60px;
  padding-bottom: 12px;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: space-between;

  .menu-top, .menu-bottom {
    display: flex;
    flex-direction: column;
  }

  li {
    list-style: none;
    display: flex;
    height: 50px;
    cursor: pointer;
    align-items: center;
    justify-content: center;
    margin-top: 20px;
    .content-body {
      position: relative;
      .icon {
        width: 44px;
        height: 44px;
        display: block;
      }
      .icon--svg {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .active-icon {
        position: absolute;
        display: block;
        top: 8px;
        left: -16px;
      }
      .text {
        text-align: center;
        font-family: PingFang SC, PingFang SC;
        font-weight: 400;
        font-size: 12px;
        color: #9097a5;
        line-height: 14px;
        margin-top: 3px;
      }
    }
  }

  .menu-bottom li {
    margin-top: 0;
    margin-bottom: 8px;
  }
}
</style>
