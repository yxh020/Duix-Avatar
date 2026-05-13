<template>
  <t-layout class="quick-create-layout">
    <t-content class="quick-create-content">
      <div class="panel">
        <div class="title">上传多个原始视频并轮流使用多个音频</div>
        <div class="subtitle">
          页面会为每个视频先创建一个带特殊名称的模特，然后按顺序轮流使用已选音频依次提交合成任务。
        </div>

        <t-button theme="primary" variant="outline" class="back-btn" @click="goHome">返回首页</t-button>

        <div class="form-item">
          <span class="label">批量任务名称前缀</span>
          <div class="value readonly">{{ tempPrefix }}</div>
        </div>

        <div class="form-item">
          <span class="label">原始视频（已选 {{ state.videos.length }} 个）</span>
          <div class="list-actions">
            <t-button theme="default" variant="outline" :disabled="loading" @click="pickVideos">
              选择视频
            </t-button>
            <t-button theme="default" variant="outline" :disabled="loading || !state.videos.length" @click="clearVideos">
              清空
            </t-button>
          </div>
          <div class="option-row">
            <t-switch v-model="state.autoDelete" :disabled="state.loading" />
            <span class="option-label">任务完成后自动删除原视频</span>
          </div>
          <div class="file-list" v-if="state.videos.length">
            <div v-for="(item, index) in state.videos" :key="item.path" class="file-item">
              <div class="file-item__main">
                <div class="index">{{ index + 1 }}</div>
                <div class="file-info">
                  <div class="name">{{ item.name }}</div>
                </div>
              </div>
              <div class="file-item__status">
                <div class="status" :class="item.statusClass">{{ item.statusText }}</div>
              </div>
              <t-button v-if="!state.loading" class="delete-btn" theme="default" variant="text" size="small" @click="removeVideo(index)">
                删除
              </t-button>
            </div>
          </div>
          <div v-else class="empty block-empty">点击选择多个视频文件</div>
        </div>

        <div class="form-item">
          <span class="label">音频文件（可多选）</span>
          <div class="list-actions">
            <t-button theme="default" variant="outline" :disabled="loading" @click="pickAudios">
              选择音频
            </t-button>
            <t-button theme="default" variant="outline" :disabled="loading || !state.audios.length" @click="clearAudios">
              清空
            </t-button>
          </div>
          <div class="file-list" v-if="state.audios.length">
            <div v-for="(item, index) in state.audios" :key="item.path" class="file-item">
              <div class="file-item__main">
                <div class="index">{{ index + 1 }}</div>
                <div class="name">{{ item.name }}</div>
              </div>
              <t-button v-if="!state.loading" class="delete-btn" theme="default" variant="text" size="small" @click="removeAudio(index)">
                删除
              </t-button>
            </div>
          </div>
          <div v-else class="empty block-empty">点击选择多个音频文件</div>
        </div>

        <div class="actions">
          <t-button theme="default" variant="outline" :disabled="!state.loading" @click="interrupt">
            中断批量
          </t-button>
          <t-button theme="primary" :loading="loading" :disabled="!canSubmit" @click="submit">
            开始批量合成
          </t-button>
        </div>
      </div>
    </t-content>
  </t-layout>
</template>

<script setup>
import { computed, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { MessagePlugin } from 'tdesign-vue-next'
import { addModel, makeVideo, modelPage, saveVideo } from '@renderer/api'
import { Client } from '@renderer/client'

const router = useRouter()
const tempPrefix = `__TMP__${new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14)}`
const state = reactive({
  loading: false,
  interrupted: false,
  autoDelete: true,
  videos: [],
  audios: []
})

const canSubmit = computed(() => Boolean(state.videos.length && state.audios.length && !state.loading))
const loading = computed(() => state.loading)

const getFileName = (path) => path.split(/[\\/]/).pop() || ''
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const goHome = () => {
  router.push('/home')
}

const pickVideos = async () => {
  const filePaths = await Client.file.selectVideo(true)
  if (!filePaths) return
  const paths = Array.isArray(filePaths) ? filePaths : [filePaths]
  state.videos = paths.map((path, index) => ({
    path,
    name: getFileName(path) || `video_${index + 1}`,
    statusText: '待处理',
    statusClass: 'status--pending'
  }))
}

const pickAudios = async () => {
  const filePaths = await Client.file.selectAudio(true)
  if (!filePaths) return
  const paths = Array.isArray(filePaths) ? filePaths : [filePaths]
  state.audios = paths.map((path, index) => ({
    path,
    name: getFileName(path) || `audio_${index + 1}`
  }))
}

const clearVideos = () => {
  state.videos = []
}

const clearAudios = () => {
  state.audios = []
}

const removeVideo = (index) => {
  state.videos.splice(index, 1)
}

const removeAudio = (index) => {
  state.audios.splice(index, 1)
}

const updateVideoStatus = (index, statusText, statusClass = '') => {
  const target = state.videos[index]
  if (!target) return
  target.statusText = statusText
  target.statusClass = statusClass
}

const findCreatedModel = async (name) => {
  for (let i = 0; i < 6; i += 1) {
    const result = await modelPage({ page: 1, pageSize: 100, name })
    const created = result?.list?.find((item) => item.name === name)
    if (created?.id) return created
    await wait(800)
  }
  return null
}

const submitOne = async (videoPath, audioPath, index) => {
  const modelName = `${tempPrefix}_${index + 1}`
  const videoName = `批量视频_${index + 1}_${Date.now()}`

  const created = await addModel({ name: modelName, videoPath })
  if (!created) throw new Error(`第 ${index + 1} 个视频创建模特失败`)

  const model = await findCreatedModel(modelName)
  if (!model?.id) throw new Error(`第 ${index + 1} 个视频未找到模特记录`)

  const saveId = await saveVideo({
    model_id: model.id,
    name: videoName,
    audio_path: audioPath,
    text_content: ''
  })
  const videoId = saveId || model.id
  const makeId = await makeVideo(videoId)
  if (makeId != videoId) throw new Error(`第 ${index + 1} 个视频合成失败`)

  return { name: getFileName(videoPath), status: '已提交' }
}

const deleteOriginalVideo = async (videoPath, index) => {
  try {
    await Client.file.deleteFile(videoPath)
    updateVideoStatus(index, `${state.videos[index]?.statusText || '已提交'} · 原视频已删除`, 'status--success')
  } catch (error) {
    console.error(error)
    updateVideoStatus(index, `${state.videos[index]?.statusText || '已提交'} · 原视频删除失败`, 'status--warning')
  }
}

const interrupt = () => {
  state.interrupted = true
  state.loading = false
  MessagePlugin.warning('已中断后续批量任务，当前执行中的步骤无法强制取消')
}

const submit = async () => {
  if (!canSubmit.value) return
  state.loading = true
  state.interrupted = false
  state.videos.forEach((video) => {
    if (video.statusClass !== 'status--success') {
      video.statusText = '待处理'
      video.statusClass = 'status--pending'
    }
  })
  let successCount = 0
  let failCount = 0

  try {
    for (let i = 0; i < state.videos.length; i += 1) {
      if (state.interrupted) {
        MessagePlugin.warning('批量任务已中断')
        break
      }

      const currentVideo = state.videos[i]
      const currentAudio = state.audios[i % state.audios.length]
      updateVideoStatus(i, `处理中：${currentAudio.name}`, 'status--processing')

      try {
        const result = await submitOne(currentVideo.path, currentAudio.path, i)
        updateVideoStatus(i, result.status, 'status--success')
        successCount += 1
        MessagePlugin.success(`第 ${i + 1} 个任务已提交`)
      } catch (error) {
        console.error(error)
        updateVideoStatus(i, '失败', 'status--error')
        failCount += 1
        MessagePlugin.error(error?.message || `第 ${i + 1} 个任务失败`)
      } finally {
        if (state.autoDelete) {
          await deleteOriginalVideo(currentVideo.path, i)
        }
      }
    }

    if (!state.interrupted) {
      MessagePlugin.success(`批量合成任务已完成，成功 ${successCount} 个，失败 ${failCount} 个`)
    }
  } finally {
    state.loading = false
  }
}
</script>

<style lang="less" scoped>
.quick-create-layout {
  width: 100%;
  min-height: 100vh;
  background: #ffffff;
  color: #1d1e20;

  .quick-create-header {
    height: 24px;
    padding: 0 24px;
    border-bottom: none;
    background: #ffffff;
    display: flex;
    align-items: center;
    justify-content: flex-end;
  }

  .quick-create-content {
    display: flex;
    justify-content: flex-start;
    align-items: flex-start;
    height: calc(100vh - 24px);
    min-height: 0;
    padding: 0 24px 24px;
    background: #ffffff;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: rgba(99, 102, 241, 0.45) transparent;
  }

  .quick-create-content::-webkit-scrollbar {
    width: 10px;
    height: 10px;
  }

  .quick-create-content::-webkit-scrollbar-track {
    background: transparent;
  }

  .quick-create-content::-webkit-scrollbar-thumb {
    background: linear-gradient(180deg, rgba(99, 102, 241, 0.55), rgba(79, 70, 229, 0.75));
    border-radius: 999px;
    border: 2px solid rgba(255, 255, 255, 0.85);
  }

  .quick-create-content::-webkit-scrollbar-thumb:hover {
    background: linear-gradient(180deg, rgba(99, 102, 241, 0.75), rgba(79, 70, 229, 0.95));
  }

  .quick-create-content::-webkit-scrollbar-corner {
    background: transparent;
  }

  .panel {
    width: 100%;
    max-width: 1280px;
    min-height: calc(100vh - 48px);
    background: #ffffff;
    border: 1px solid #e8e8e8;
    border-radius: 12px;
    padding: 24px;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.04);
    display: flex;
    flex-direction: column;
    position: relative;
    .back-btn{
      position: absolute;
      right: 24px;
      top: 24px;
    }
  }

  .title { font-size: 22px; font-weight: 700; margin-bottom: 8px; color: #1d1e20; }
  .subtitle { color: #6b7280; font-size: 13px; margin-bottom: 24px; line-height: 1.6; }
  .form-item { margin-bottom: 20px; }
  .label { display: block; margin-bottom: 10px; font-size: 13px; color: #374151; }
  .readonly, .empty, .file-list {
    background: #fafafa;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }
  .readonly { min-height: 44px; display: flex; align-items: center; padding: 0 14px; color: #111827; font-size: 14px; }
  .empty { color: #9ca3af; padding: 18px; width: 100%; min-height: 90px; display: flex; align-items: center; justify-content: center; border: none; }

  .list-actions { display: flex; gap: 12px; margin-bottom: 12px; }
  .option-row { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; color: #374151; font-size: 13px; }
  .option-label { user-select: none; font-size: 12px; color: #666;}
  .file-list { padding: 12px; display: grid; gap: 8px; max-height: 220px; overflow: auto; scrollbar-width: thin; scrollbar-color: rgba(99, 102, 241, 0.35) transparent; }
  .file-list::-webkit-scrollbar { width: 8px; height: 8px; }
  .file-list::-webkit-scrollbar-track { background: transparent; }
  .file-list::-webkit-scrollbar-thumb {
    background: linear-gradient(180deg, rgba(99, 102, 241, 0.35), rgba(79, 70, 229, 0.6));
    border-radius: 999px;
    border: 2px solid rgba(255, 255, 255, 0.85);
  }
  .file-list::-webkit-scrollbar-thumb:hover {
    background: linear-gradient(180deg, rgba(99, 102, 241, 0.55), rgba(79, 70, 229, 0.8));
  }
  .file-item { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 12px; border-radius: 6px; background: #ffffff; border: 1px solid #edf0f2; }
  .file-item__main { display: flex; align-items: center; gap: 12px; min-width: 0; flex: 1; }
  .file-item__status { flex: none; min-width: 180px; display: flex; justify-content: flex-end; }
  .file-item .index { width: 24px; height: 24px; border-radius: 50%; background: #434af9; color: #fff; display:flex; align-items:center; justify-content:center; font-size: 12px; flex:none; }
  .file-info { min-width: 0; flex: 1; }
  .file-item .name { overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
  .status {
    display: inline-flex;
    align-items: center;
    padding: 2px 8px;
    border-radius: 999px;
    font-size: 12px;
    line-height: 1.5;
    border: 1px solid transparent;
    flex: none;
  }
  .status--pending { color: #6b7280; background: #f3f4f6; border-color: #e5e7eb; }
  .status--processing { color: #b45309; background: #fffbeb; border-color: #fde68a; }
  .status--success { color: #15803d; background: #f0fdf4; border-color: #bbf7d0; }
  .status--error { color: #b91c1c; background: #fef2f2; border-color: #fecaca; }
  .status--warning { color: #b45309; background: #fffbeb; border-color: #fde68a; }
  .delete-btn { flex: none; color: #ef4444; }

  .actions { display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; flex: none; }
}
</style>
