<template>
  <div class="works-content-box">
    <!-- form -->
    <div class="form-box">
      <div class="toolbar-actions">
        <span class="selected-count">已选 {{ selectedIds.length }} 项</span>
        <t-checkbox
          :checked="isAllSelected"
          :indeterminate="isIndeterminate"
          @change="toggleSelectAll"
        >
          全选
        </t-checkbox>
        <t-button
          theme="primary"
          variant="outline"
          :disabled="selectedIds.length === 0"
          @click="showBatchDeleteDialog"
        >
          批量删除
        </t-button>
        <t-button
          theme="primary"
          :disabled="selectedIds.length === 0"
          @click="downloadSelectedVideos"
        >
          批量下载
        </t-button>
      </div>
      <t-input
        v-model="state.formData.name"
        class="form-input"
        :placeholder="$t('common.input.enterKeywordPlaceholder')"
        @change="onKeypressFun"
      >
        <template #prefix-icon>
          <img src="../../../assets/images/home/select.svg" />
        </template>
      </t-input>
      <t-button class="refresh-button" theme="default" variant="outline" @click="refreshList">
        <img src="../../../assets/images/home/go.svg" />
        <span>刷新</span>
      </t-button>
    </div>
    <div class="works-content-table">
      <div v-if="home.homeState.videoNum === 0" class="empty">
        <div class="empty-box">
          <img src="../../../assets/images/home/worksList.svg" />
          <div class="empty-text">{{ $t('common.videoList.emptyText') }}</div>
          <div class="empty-text">
            <span @click="linkRoute">{{ $t('common.videoList.emptyLinkRouteText') }}</span>
            {{ $t('common.videoList.emptyRightText') }}
          </div>
        </div>
      </div>
      <div v-else class="table-list">
        <div v-for="(item, index) in state.worksList" :key="item.id || index" class="li">
          <div class="select-box" @click.stop="toggleSelect(item.id)">
            <div class="select-icon" :class="{ checked: selectedIds.includes(item.id) }">
              <CheckIcon v-if="selectedIds.includes(item.id)" />
            </div>
          </div>
          <!-- 视频上部分内容 -->
          <div class="img-video comme">
            <div class="img-video-content">
              <div v-if="item.status === 'success'" class="duration">
                {{ item.duration + '' ? millisecondsToTime(item.duration * 1000) : '00:00' }}
              </div>
              <div v-if="item.status === 'success'" class="works-video">
                <img
                  :src="getVideoThumbnail(item) || occupationMap"
                  :class="{ 'works-img--brand': !getVideoThumbnail(item) }"
                  alt="video thumbnail"
                />
              </div>
              <img
                v-if="item.status === 'failed' || item.status === 'pending' || item.status === 'draft'"
                class="works-img works-img--brand"
                src="../../../assets/images/home/hero.jpg"
              />
              <div v-if="item.status === 'failed' || item.status === 'draft'" class="fail">
                <div class="fail-line"></div>
                <span>{{
                  item.status === 'failed'
                    ? $t('common.videoList.makeFailedText')
                    : $t('common.videoList.draftsText')
                }}</span>
              </div>
            </div>
          </div>
          <!-- 下载和预览 -->
          <div
            class="download-preview comme"
            :style="
              item.status === 'failed' || item.status === 'success'
                ? 'background: rgba(0, 0, 0, 0.74);'
                : ''
            "
          >
            <div class="download-preview-content">
              <div
                v-if="item.status === 'success'"
                class="preview-button"
                @click="previewVideo(item.file_path)"
              >
                <img src="../../../assets/images/home/video.svg" />
                <span>{{ $t('common.videoList.previewTitle') }}</span>
              </div>
              <div
                v-if="item.status === 'success'"
                class="download-button"
                @click="downloadVideo(item)"
              >
                <img src="../../../assets/images/home/icon-down.svg" />
                <span>{{ $t('common.videoList.downloadTitle') }}</span>
              </div>
              <div v-if="item.status === 'failed'" class="detection-failed-text">
                {{ $t('common.videoList.makeFailedText') }}
                <img src="../../../assets/images/home/icon-delete.svg" />
              </div>
              <div v-if="item.status === 'draft'" class="detection-failed-text">
                {{ $t('common.videoList.draftsText') }}
                <img src="../../../assets/images/home/icon-delete.svg" />
              </div>
              <div v-if="item.status === 'failed'" class="detection-failed-title">
                {{ item.message }}
              </div>
              <div
                v-if="
                  item.status === 'success' || item.status === 'failed' || item.status === 'draft'
                "
                class="delete-video"
                @click="delVideo(item.id)"
              >
                <DeleteIcon style="color: #fff; font-size: 12px" />
              </div>
            </div>
          </div>
          <!-- 制作中 -->
          <div v-if="item.status === 'pending'" class="production comme">
            <div class="production-content">
              <img src="../../../assets/images/home/loading.svg" />
              <div class="progress-text">{{ item.progress }}%</div>
              <div class="production-text">{{ $t('common.videoList.underProduction') }}</div>
            </div>
            <div class="delete-video" @click="delVideo(item.id)">
              <DeleteIcon style="color: #fff; font-size: 12px" />
            </div>
          </div>
          <!-- 排队中 -->
          <div v-if="item.status === 'waiting'" class="production comme">
            <div class="production-content">
              <img src="../../../assets/images/home/loading.svg" />
              <div class="progress-text">{{ item.progress }}</div>
              <div class="production-text">{{ $t('common.videoList.queuing') }}</div>
            </div>
            <div class="delete-video" @click="delVideo(item.id)">
              <DeleteIcon style="color: #fff; font-size: 12px" />
            </div>
          </div>
          <!-- 视频下部分内容 -->
          <div class="bottom-text">
            <div class="h1">{{ item.name }}</div>
            <div class="text">
              {{ item.created_at ? formatDate(item.created_at) : '' }}
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="home.homeState.videoNum > 0" class="pagination-box">
      <div class="pagination-content">
        <t-config-provider :global-config="locale === 'zh' ? globalZh : globalEn">
          <t-pagination
            v-model="state.current"
            v-model:pageSize="state.pageSize"
            :total="state.total"
            show-jumper
            class="pagination"
            @page-size-change="onPageSizeChange"
            @current-change="onCurrentChange"
          />
        </t-config-provider>
      </div>
    </div>
    <VideoDialog
      :showVideoDialog="state.showVideoDialog"
      :videoUrl="state.videoUrl"
      @cancel="cancelFun"
    />
    <DeleteDialog ref="deleteDialogRef" @ok="okDelete" />
    <DeleteDialog ref="batchDeleteDialogRef" @ok="okBatchDelete" />
  </div>
</template>
<script setup>
import { reactive, onMounted, onBeforeUnmount, ref, computed } from 'vue'
import { DeleteIcon, CheckIcon } from 'tdesign-icons-vue-next'
import { videoPage, exportVideo, removeVideo } from '@renderer/api/index.js'
import { formatDate, millisecondsToTime } from '@renderer/utils/index.js'
import VideoDialog from '@renderer/views/home/components/videoDialog.vue'
import { Client } from '@renderer/client'
import { useHomeStore } from '@renderer/stores/home.js'
import { useRouter } from 'vue-router'
import DeleteDialog from '@renderer/components/deleteDialog.vue'
import { MessagePlugin } from 'tdesign-vue-next'
import enConfig from 'tdesign-vue-next/es/locale/en_US'
import zhConfig from 'tdesign-vue-next/es/locale/zh_CN'
import { useI18n } from 'vue-i18n'
const { locale, t } = useI18n()
import { localUrl } from '@renderer/utils'
// 占位图统一用品牌 hero.jpg（金身火爆熊），覆盖 success 任务缩略图加载失败的 fallback
import occupationMap from '../../../assets/images/home/hero.jpg'

import merge from 'lodash/merge'
const globalEn = merge(enConfig, {
  pagination: {}
})
const globalZh = merge(zhConfig, {
  pagination: {}
})
const router = useRouter()
const home = useHomeStore()
const deleteDialogRef = ref(null)
const batchDeleteDialogRef = ref(null)
const selectedIds = ref([])
const thumbnailCache = reactive({})
const state = reactive({
  interval: null,
  current: 1,
  videoUrl: '',
  showVideoDialog: false,
  pageSize: 50,
  total: 0,
  delVideoId: '',
  worksList: [],
  url: `file:///B:/dd.mov`,
  formData: {
    name: ''
  }
})
onMounted(() => {
  videoPageAJax()
  state.interval = setInterval(() => {
    videoPageAJax()
  }, 10000)
})
onBeforeUnmount(() => {
  clearInterval(state.interval)
})
const cancelFun = () => {
  state.showVideoDialog = false
}
const linkRoute = () => {
  router.push('/video/edit')
}
const isAllSelected = computed(() => {
  const selectableIds = state.worksList.map((item) => item.id).filter(Boolean)
  return selectableIds.length > 0 && selectableIds.every((id) => selectedIds.value.includes(id))
})
const isIndeterminate = computed(() => {
  const selectableIds = state.worksList.map((item) => item.id).filter(Boolean)
  const selectedCount = selectableIds.filter((id) => selectedIds.value.includes(id)).length
  return selectedCount > 0 && selectedCount < selectableIds.length
})
const refreshList = () => {
  videoPageAJax()
}
const toggleSelect = (id) => {
  if (!id) return
  if (selectedIds.value.includes(id)) {
    selectedIds.value = selectedIds.value.filter((itemId) => itemId !== id)
    return
  }
  selectedIds.value.push(id)
}
const toggleSelectAll = (checked) => {
  const checkedValue = checked?.target ? checked.target.checked : checked
  const selectableIds = state.worksList.map((item) => item.id).filter(Boolean)
  selectedIds.value = checkedValue ? [...selectableIds] : []
}
const showBatchDeleteDialog = () => {
  if (selectedIds.value.length === 0) return
  batchDeleteDialogRef.value?.showDialogFun()
}
const previewVideo = (url) => {
  state.showVideoDialog = true
  state.videoUrl = url
}
const generateVideoThumbnail = (videoUrl, itemId) => {
  console.log('[worksList] start generate thumbnail', { itemId, videoUrl })
  return new Promise((resolve, reject) => {
    const video = document.createElement('video')
    video.crossOrigin = 'anonymous'
    video.preload = 'auto'
    video.muted = true
    video.playsInline = true
    video.src = videoUrl

    const cleanup = () => {
      video.removeAttribute('src')
      video.load()
    }

    const captureFrame = () => {
      const canvas = document.createElement('canvas')
      const sourceWidth = video.videoWidth || 320
      const sourceHeight = video.videoHeight || 180
      canvas.width = sourceWidth
      canvas.height = sourceHeight
      const context = canvas.getContext('2d')
      if (!context) {
        console.warn('[worksList] canvas context unavailable', { itemId })
        cleanup()
        reject(new Error('canvas context unavailable'))
        return
      }
      context.drawImage(video, 0, 0, sourceWidth, sourceHeight)
      const dataUrl = canvas.toDataURL('image/jpeg', 0.9)
      console.log('[worksList] thumbnail generated', {
        itemId,
        dataUrlPrefix: dataUrl.slice(0, 32),
        currentTime: video.currentTime,
        width: sourceWidth,
        height: sourceHeight
      })
      cleanup()
      resolve(dataUrl)
    }

    video.addEventListener(
      'loadedmetadata',
      () => {
        console.log('[worksList] video metadata loaded', {
          itemId,
          duration: video.duration,
          width: video.videoWidth,
          height: video.videoHeight
        })
      },
      { once: true }
    )

    video.addEventListener(
      'seeked',
      () => {
        console.log('[worksList] video seeked', {
          itemId,
          currentTime: video.currentTime,
          duration: video.duration
        })
        captureFrame()
      },
      { once: true }
    )

    video.addEventListener(
      'loadeddata',
      () => {
        const duration = Number.isFinite(video.duration) ? video.duration : 0
        const targetTime = Math.min(Math.max(duration * 0.15, 0.5), 3)
        console.log('[worksList] video loadeddata, seeking frame', {
          itemId,
          duration,
          targetTime
        })
        if (!duration || duration <= targetTime) {
          captureFrame()
          return
        }
        try {
          video.currentTime = targetTime
        } catch (error) {
          console.warn('[worksList] seek failed, fallback to current frame', { itemId, error })
          captureFrame()
        }
      },
      { once: true }
    )

    video.addEventListener(
      'error',
      (event) => {
        console.error('[worksList] video load error', { itemId, videoUrl, event })
        cleanup()
        reject(event)
      },
      { once: true }
    )
  })
}
const getVideoThumbnail = (item) => {
  return item.cover_path ? localUrl.addFileProtocol(item.cover_path) : thumbnailCache[item.id] || ''
}
const cacheVideoThumbnail = async (item) => {
  if (!item?.id || thumbnailCache[item.id] || !item.file_path) {
    console.log('[worksList] skip cache thumbnail', {
      itemId: item?.id,
      hasCache: Boolean(item?.id && thumbnailCache[item.id]),
      hasFilePath: Boolean(item?.file_path)
    })
    return
  }
  try {
    const url = localUrl.addFileProtocol(item.file_path)
    console.log('[worksList] cache thumbnail begin', { itemId: item.id, url })
    thumbnailCache[item.id] = await generateVideoThumbnail(url, item.id)
    console.log('[worksList] cache thumbnail success', { itemId: item.id, cached: Boolean(thumbnailCache[item.id]) })
  } catch (error) {
    console.error('[worksList] generate thumbnail failed', { itemId: item?.id, error })
  }
}
const batchGenerateThumbnails = async (list) => {
  const targets = list.filter((item) => item.status === 'success')
  console.log('[worksList] batchGenerateThumbnails', {
    total: list.length,
    targets: targets.map((item) => ({ id: item.id, file_path: item.file_path, cover_path: item.cover_path }))
  })
  await Promise.allSettled(targets.map((item) => cacheVideoThumbnail(item)))
}
const videoPageAJax = async () => {
  try {
    const res = await videoPage({
      page: state.current,
      pageSize: state.pageSize,
      name: state.formData.name
    })
    if (res) {
      const { total, list } = res
      if (list) {
        state.total = total
        state.worksList = list.map((item) => ({
          ...item,
          thumbnailUrl: item.cover_path ? localUrl.addFileProtocol(item.cover_path) : ''
        }))
        console.log('[worksList] videoPageAJax response', {
          total,
          current: state.current,
          pageSize: state.pageSize,
          list: state.worksList.map((item) => ({
            id: item.id,
            status: item.status,
            file_path: item.file_path,
            cover_path: item.cover_path,
            thumbnailUrl: item.thumbnailUrl
          }))
        })
        selectedIds.value = selectedIds.value.filter((id) => list.some((item) => item.id === id))
        batchGenerateThumbnails(list)
      }
    }
  } catch (error) {
    console.log(error)
  }
}
const onKeypressFun = () => {
  if (!state.isTime) {
    state.isTime = true
    const timeout = setTimeout(() => {
      videoPageAJax()
      state.isTime = false
      clearTimeout(timeout)
    }, 800)
  }
}
const onPageSizeChange = (size) => {
  state.pageSize = size
  selectedIds.value = []
  videoPageAJax()
}

const onCurrentChange = (index) => {
  state.current = index
  selectedIds.value = []
  videoPageAJax()
}

const delVideo = (id) => {
  console.log("🚀 ~ delVideo ~ id:", id)
  if (deleteDialogRef.value && deleteDialogRef.value.showDialogFun) {
    // 正在制作中（status=pending）的任务：face2face 容器没有 /cancel API，
    // 删除只是清记录，GPU 还会继续跑完。给运营一个明确的提示，避免误以为真的停了。
    const target = state.worksList.find((item) => item.id === id)
    const note = target && target.status === 'pending'
      ? '此任务正在 GPU 渲染中，删除仅会清除记录，容器仍会渲染到完成（结果文件保留在模型目录但不再显示）。建议等任务结束再删。'
      : ''
    deleteDialogRef.value.showDialogFun(note)
    state.delVideoId = id
  }
}
const okDelete = () => {
  removeVideo(state.delVideoId)
    .then(() => {
      videoPageAJax()
      MessagePlugin.success(t('common.message.deleteSuccessText'))
      home.setVideoNum(home.homeState.videoNum > 0 ? home.homeState.videoNum - 1 : 0)
    })
    .catch((error) => {
      MessagePlugin.error(t('common.message.deleteErrorText'))
      console.error('Error:', error)
    })
}
const okBatchDelete = async () => {
  const deleteCount = selectedIds.value.length
  try {
    await Promise.all(selectedIds.value.map((id) => removeVideo(id)))
    selectedIds.value = []
    await videoPageAJax()
    MessagePlugin.success(t('common.message.deleteSuccessText'))
    home.setVideoNum(Math.max(home.homeState.videoNum - deleteCount, 0))
  } catch (error) {
    MessagePlugin.error(t('common.message.deleteErrorText'))
    console.error('Error:', error)
  }
}
const downloadVideo = async (video) => {
  const fileExtension = video.file_path?.split('.')?.pop()
  const saveName = `${video.name}.${fileExtension}`
  try {
    const savePath = await Client.file.saveFile(saveName)
    await exportVideo(video.id, savePath)
  } catch (error) {
    console.log(error)
  }
}
const downloadSelectedVideos = async () => {
  if (!selectedIds.value.length) return
  const selectedVideos = state.worksList.filter((item) => selectedIds.value.includes(item.id))
  if (!selectedVideos.length) return

  try {
    const folderPath = await Client.file.selectFolder()
    if (!folderPath) return

    for (const video of selectedVideos) {
      const fileExtension = video.file_path?.split('.')?.pop() || 'mp4'
      const saveName = `${video.name}.${fileExtension}`
      const savePath = `${folderPath.replace(/[\\/]$/, '')}\\${saveName}`
      await exportVideo(video.id, savePath)
    }

    MessagePlugin.success('批量下载完成')
  } catch (error) {
    console.error('Batch download failed:', error)
    MessagePlugin.error('批量下载失败')
  }
}
</script>
<style lang="less" scoped>
.works-content-box {
  .form-box {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 24px;
    position: absolute;
    top: -50px;
    right: 0;

    .toolbar-actions {
      display: flex;
      align-items: center;
      gap: 12px;

      .selected-count {
        font-size: 12px;
        color: #666;
      }
    }

    .form-input {
      width: 216px;
      margin-left: auto;
    }
  }
  .works-content-table {
    min-height: calc(100vh - 384px);
    .empty {
      display: flex;
      justify-content: center;
      align-items: center;
      height: calc(100vh - 414px);
      .empty-box {
        img {
          width: 160px;
          display: block;
          margin: 0 auto;
        }
        .empty-text {
          font-family: PingFang SC, PingFang SC;
          font-weight: 400;
          font-size: 12px;
          text-align: center;
          color: #999999;
          line-height: 16px;
          span {
            color: #434af9;
            border-bottom: 1xp solid #434af9;
            cursor: pointer;
          }
        }
      }
    }
    .table-list {
      display: grid;
      padding: 0 8px 40px;
      box-sizing: border-box;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      justify-content: start;
      gap: 12px;
      color: #ccc;

      .li:hover {
        transform: scale(1.01);
        box-shadow: 0px 0px 12px rgba(0, 0, 0, 0.12);

        .download-preview {
          z-index: 2;
          display: flex;
          justify-content: center;
          align-items: center;
          position: relative;

          .download-preview-content {
            .download-button {
              width: 90px;
              height: 30px;
              cursor: pointer;
              background: #434af9;
              border-radius: 4px;
              display: flex;
              align-items: center;
              justify-content: center;
              border: 1px solid #434af9;
              font-family: PingFang SC, PingFang SC;
              font-weight: 500;
              font-size: 12px;
              color: #ffffff;

              line-height: 18px;

              img {
                margin-right: 4px;
              }
            }

            .detection-failed-text {
              font-family: PingFang SC, PingFang SC;
              font-weight: 500;
              font-size: 12px;
              padding: 0 6px;
              display: flex;
              justify-content: center;
              color: #ffffff;
              line-height: 18px;
              margin-bottom: 12px;
            }

            .detection-failed-title {
              font-family: PingFang SC, PingFang SC;
              font-weight: 400;
              width: 80px;
              text-align: center;
              font-size: 12px;
              display: flex;
              justify-content: center;
              color: #ffffff;
              line-height: 18px;
            }

            .preview-button {
              width: 90px;
              height: 30px;
              cursor: pointer;
              display: flex;
              align-items: center;
              justify-content: center;
              margin-bottom: 8px;
              border-radius: 4px;
              font-family: PingFang SC, PingFang SC;
              font-weight: 500;
              font-size: 12px;
              color: #ffffff;
              line-height: 18px;
              border: 1px solid rgba(255, 255, 255, 0.6);

              img {
                margin-right: 4px;
              }
            }
          }
        }
      }

      .select-box {
        position: absolute;
        top: 8px;
        right: 8px;
        z-index: 10;
        width: 20px;
        height: 20px;
        cursor: pointer;

        .select-icon {
          width: 20px;
          height: 20px;
          border-radius: 4px;
          box-sizing: border-box;
          background: rgba(255, 255, 255, 0.95);
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;

          &.checked {
            background: #434af9;
            border-color: #434af9;
          }
        }
      }

      .delete-video {
          width: 20px;
          height: 20px;
          background: rgba(255, 255, 255, 0.2);
          border-radius: 6px;
          position: absolute;
          left: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          top: 10px;
        }

      .li {
        transition: all 0.3s ease;
        width: 100%;
        height: 320px;
        border-radius: 8px;
        position: relative;
        overflow: hidden;
        .download-preview {
          display: none;
        }

        .comme {
          position: absolute;
          top: 0;
          width: 100%;
          left: 0;
          border-radius: 8px 8px 0 0;
          height: calc(100% - 54px);
        }

        .img-video {
          z-index: 1;
          height: calc(100% - 64px);

          .img-video-content {
            position: relative;
            height: 100%;
            background-color: #ebeef5;
            border-radius: 10px 10px 0 0;
            overflow: hidden;

            .works-img {
              width: 100%;
              height: 100%;
              object-fit: cover;
              border-radius: 8px 8px 0 0;
              background-color: #fff;
            }

            /* 待制作 / 失败 / 渲染中显示的品牌占位图 —— hero.jpg + 透明度，弱化但保留品牌感 */
            .works-img--brand {
              opacity: 0.35;
              filter: saturate(0.85);
              background: linear-gradient(135deg, #f8fafc 0%, #eef2ff 100%);
            }

            .works-video {
              width: 100%;
              height: 100%;
              overflow: hidden;
              position: absolute;
              border-radius: 8px 8px 0 0;
              left: 0;
              display: flex;
              align-items: center;
              top: 0;
              img {
                width: 100%;
                height: 100%;
                object-fit: cover;
              }
            }

            .fail {
              padding: 0 6px;
              height: 22px;
              background: rgba(255, 255, 255, 0.9);
              border-radius: 0px 8px 0px 8px;
              position: absolute;
              display: flex;
              justify-content: center;
              align-items: center;
              top: 0;
              right: 0;

              .fail-line {
                width: 4px;
                height: 4px;
                background: #ff2f2f;
                border-radius: 8px;
                margin-right: 5px;
              }

              span {
                font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
                font-weight: 400;
                font-size: 12px;
                color: #253858;
                line-height: 14px;
              }
            }

            .duration {
              padding: 0 5px;
              position: absolute;
              bottom: 8px;
              right: 8px;
              height: 18px;
              background: rgba(0, 0, 0, 0.63);
              border-radius: 4px;
              font-family: PingFang SC, PingFang SC;
              font-weight: 400;
              display: flex;
              justify-content: center;
              align-items: center;
              font-size: 10px;
              color: #ffffff;
              line-height: 12px;
              font-style: normal;
            }
          }
        }

        .bottom-text {
          height: 54px;
          position: absolute;
          bottom: 0;
          padding: 4px 8px 8px 8px;
          box-sizing: border-box;
          left: 0;
          width: 100%;
          background: #ffffff;
          border-bottom: 1px solid #f2f2f4;
          border-left: 1px solid #f2f2f4;
          border-right: 1px solid #f2f2f4;
          border-radius: 0 0 8px 8px;
          .h1 {
            font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
            font-weight: 600;
            font-size: 14px;
            color: #252525;
            line-height: 28px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
          .text {
            font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
            font-weight: 400;
            margin-top: 5px;
            font-size: 10px;
            color: rgba(37, 37, 37, 0.5);
            line-height: 12px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
        }

        .production {
          z-index: 2;
          background: rgba(0, 0, 0, 0.74);
          display: flex;
          justify-content: center;
          align-items: center;

          .production-content {
            img {
              display: block;
              width: 20px;
              height: 20px;
              margin: 0 auto;
              animation: spin 1s linear infinite;
            }
            @keyframes spin {
              0% {
                transform: rotate(0deg);
              }
              100% {
                transform: rotate(360deg);
              }
            }
            .production-text {
              font-family: PingFang SC, PingFang SC;
              font-weight: 400;
              font-size: 12px;
              margin-top: 10px;
              color: #ffffff;
              line-height: 14px;
              text-align: center;
            }
            .progress-text {
              font-family: PingFang SC, PingFang SC;
              font-weight: 400;
              font-size: 12px;
              margin-top: 10px;
              color: #ffffff;
              line-height: 14px;
              text-align: center;
            }
          }
        }
      }
    }
  }

  .pagination-box {
    position: sticky;
    z-index: 99;
    height: 46px;
    width: 100%;
    bottom: -20px;
    left: 0;
    background-color: #fff;
    .pagination-content {
      justify-content: center;
      display: flex;
      height: 46px;
    }
  }
}
</style>
