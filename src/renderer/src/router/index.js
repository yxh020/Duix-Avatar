import { createRouter, createWebHashHistory } from 'vue-router'
import home from '@renderer/views/home/index.vue'
import account from '@renderer/views/account/index.vue'
import VideoEditView from '@renderer/views/video-edit/VideoEditView.vue'
import ModelQuickCreateView from '@renderer/views/model-quick-create/index.vue'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      name: 'root',
      redirect: '/home'
    },
    {
      path: '/home',
      name: 'home',
      component: home
    },
    {
      path: '/video/edit',
      name: 'videoEdit',
      component: VideoEditView
    },
    {
      path: '/model/quick-create',
      name: 'modelQuickCreate',
      component: ModelQuickCreateView
    },
    {
      path: '/account',
      name: 'account',
      component: account
    }
  ]
})

export default router
