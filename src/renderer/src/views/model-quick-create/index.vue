<template>
  <t-layout class="quick-create-layout">
    <t-content class="quick-create-content">
      <div class="panel">
        <div class="panel-head">
          <div class="head-text">
            <div class="title">批量对口型合成</div>
            <div class="subtitle-row">
              <div class="subtitle">
                为每段素材配上音频，逐个提交合成任务。素材数 ≥ 音频数时音频会循环复用。
              </div>
              <div class="future-chip" title="更多配对方式（N:1 / 顺序 / 随机 / 自定义）开发中">
                <span class="future-dot"></span>
                更多配对方式 · 敬请期待
              </div>
            </div>
            <div v-if="state.videos.length || state.audios.length" class="pair-badge">
              <span class="pair-num">{{ state.videos.length }}</span>
              <span class="pair-icon">×</span>
              <span class="pair-num">{{ state.audios.length }}</span>
              <span class="pair-arrow">→</span>
              <span class="pair-num pair-num--strong">{{ state.videos.length }}</span>
              <span class="pair-label">个作品</span>
            </div>
          </div>
          <div class="head-extra">
            <t-button class="back-btn" theme="default" variant="outline" @click="goHome">返回首页</t-button>
          </div>
        </div>

        <div class="form-card">
        <div class="form-item">
          <div class="form-item__head">
            <span class="label">
              素材视频<span class="label-count">已选 {{ state.videos.length }} 个</span>
              <span class="label-hint">· 支持一次多选，再次选择会替换</span>
            </span>
            <div class="list-actions">
              <t-tooltip :content="state.videos.length ? '将替换当前列表，请一次性多选完成' : '在弹窗里按 Ctrl / Shift 一次性多选'" placement="top">
                <t-button theme="primary" variant="outline" :disabled="loading" @click="pickVideos">
                  <template #icon><AddIcon /></template>
                  {{ state.videos.length ? '重新选择' : '选择视频' }}
                </t-button>
              </t-tooltip>
              <t-button theme="default" variant="text" size="small" :disabled="loading || !state.videos.length" @click="clearVideos">
                清空
              </t-button>
            </div>
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
          <div v-else class="drop-zone" @click="!loading && pickVideos()">
            <AddIcon class="drop-icon" />
            <span>点击选择多段素材视频</span>
          </div>
        </div>

        <div class="form-item">
          <div class="form-item__head">
            <span class="label">
              音频文件<span class="label-count">已选 {{ state.audios.length }} 个</span>
              <span class="label-hint">· 支持一次多选，再次选择会替换</span>
            </span>
            <div class="list-actions">
              <t-tooltip :content="state.audios.length ? '将替换当前列表，请一次性多选完成' : '在弹窗里按 Ctrl / Shift 一次性多选'" placement="top">
                <t-button theme="primary" variant="outline" :disabled="loading" @click="pickAudios">
                  <template #icon><AddIcon /></template>
                  {{ state.audios.length ? '重新选择' : '选择音频' }}
                </t-button>
              </t-tooltip>
              <t-button theme="default" variant="text" size="small" :disabled="loading || !state.audios.length" @click="clearAudios">
                清空
              </t-button>
            </div>
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
          <div v-else class="drop-zone" @click="!loading && pickAudios()">
            <AddIcon class="drop-icon" />
            <span>点击选择音频文件（mp3 / wav，每个音频对应一个作品）</span>
          </div>
        </div>

        <div class="actions">
          <div class="actions-left">
            <t-switch v-model="state.autoDelete" :disabled="state.loading" size="small" />
            <span class="option-label">完成后自动删除原素材（失败时素材始终保留）</span>
          </div>
          <div class="actions-right">
            <t-button theme="default" variant="outline" :disabled="!state.loading" @click="interrupt">
              中断后续
            </t-button>
            <t-button theme="primary" :loading="loading" :disabled="!canSubmit" @click="submit">
              开始批量合成
            </t-button>
          </div>
        </div>
        </div>
      </div>
    </t-content>
  </t-layout>
</template>

<script setup>
import { computed, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { MessagePlugin } from 'tdesign-vue-next'
import { AddIcon } from 'tdesign-icons-vue-next'
import { addModel, makeVideo, modelPage, saveVideo } from '@renderer/api'
import { Client } from '@renderer/client'

const router = useRouter()
const tempPrefix = `__TMP__${new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14)}`
const state = reactive({
  loading: false,
  interrupted: false,
  autoDelete: false,
  videos: [],
  audios: []
})

const canSubmit = computed(() => Boolean(state.videos.length && state.audios.length && !state.loading))
const loading = computed(() => state.loading)

const getFileName = (path) => path.split(/[\\/]/).pop() || ''
const getBaseName = (path) => {
  const name = getFileName(path)
  return name.replace(/\.[^.]+$/, '') || name
}
const formatTimeStamp = () => {
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
}
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
  // 详细命名：YYYYMMDD-HHmmss-素材名_钩子名（例：20260515-021723-已去水印素材_钩子马）
  // 时间在前可按文件名排序，秒级唯一防止批量内撞名，素材_钩子顺序跟 UI 选择顺序对齐
  const videoName = `${formatTimeStamp()}-${getBaseName(videoPath)}_${getBaseName(audioPath)}`

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
        // 仅在提交成功后才删除原视频，失败时保留素材便于排查或重试
        if (state.autoDelete) {
          await deleteOriginalVideo(currentVideo.path, i)
        }
      } catch (error) {
        console.error(error)
        updateVideoStatus(i, '失败', 'status--error')
        failCount += 1
        MessagePlugin.error(error?.message || `第 ${i + 1} 个任务失败`)
      }
    }

    if (!state.interrupted) {
      MessagePlugin.success(`批量合成任务已完成，成功 ${successCount} 个，失败 ${failCount} 个`)
      // 提交完成后回到首页，方便运营到"我的作品"里看进度
      setTimeout(goHome, 1500)
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
    height: calc(100vh - 60px);
    min-height: 0;
    padding: 20px;
    background: #f4f4f6;
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
    background: transparent;
    display: flex;
    flex-direction: column;
  }

  .form-card {
    display: flex;
    flex-direction: column;
    background: #ffffff;
    border-radius: 12px;
    padding: 24px;
  }

  .panel-head {
    position: relative;
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 24px;
    padding: 28px 32px;
    min-height: 160px;
    background: linear-gradient(135deg, #4a90ff 0%, #2f80ed 100%);
    border-radius: 12px;
    box-shadow: 0 6px 18px rgba(47, 128, 237, 0.18);
    overflow: hidden;
  }
  .panel-head::before {
    content: '';
    position: absolute;
    top: -40%;
    right: -10%;
    width: 320px;
    height: 320px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0) 70%);
    pointer-events: none;
  }
  .panel-head::after {
    content: '';
    position: absolute;
    bottom: -50%;
    left: 30%;
    width: 260px;
    height: 260px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 70%);
    pointer-events: none;
  }
  .head-text { min-width: 0; flex: 1; position: relative; z-index: 1; }
  .head-extra { display: flex; align-items: center; gap: 12px; flex: none; position: relative; z-index: 1; }
  .subtitle-row { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-top: 8px; }

  .future-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    background: rgba(255, 255, 255, 0.18);
    border: 1px solid rgba(255, 255, 255, 0.35);
    border-radius: 999px;
    font-size: 12px;
    color: #ffffff;
    backdrop-filter: blur(4px);
    user-select: none;
    cursor: help;
    transition: background 0.2s, border-color 0.2s;
  }
  .future-chip:hover {
    background: rgba(255, 255, 255, 0.26);
    border-color: rgba(255, 255, 255, 0.55);
  }
  .future-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #ffd166;
    box-shadow: 0 0 0 0 rgba(255, 209, 102, 0.7);
    animation: future-pulse 1.8s ease-out infinite;
  }
  @keyframes future-pulse {
    0%   { box-shadow: 0 0 0 0 rgba(255, 209, 102, 0.7); }
    70%  { box-shadow: 0 0 0 8px rgba(255, 209, 102, 0); }
    100% { box-shadow: 0 0 0 0 rgba(255, 209, 102, 0); }
  }

  .pair-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 12px;
    padding: 6px 14px;
    background: rgba(255, 255, 255, 0.16);
    border: 1px solid rgba(255, 255, 255, 0.32);
    border-radius: 999px;
    font-size: 13px;
    color: #ffffff;
    backdrop-filter: blur(4px);
    user-select: none;
  }
  .pair-num { font-weight: 600; min-width: 14px; text-align: center; color: #ffffff; }
  .pair-num--strong { color: #fff6d6; font-size: 16px; font-weight: 700; }
  .pair-icon { color: rgba(255, 255, 255, 0.7); font-size: 12px; }
  .pair-arrow { color: rgba(255, 255, 255, 0.7); margin: 0 2px; }
  .pair-label { color: rgba(255, 255, 255, 0.85); font-size: 12px; }

  .title {
    font-family: 'Alimama FangYuanTi VF-Bold', 'PingFang SC', sans-serif;
    font-size: 28px;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: 2px;
    line-height: 1.3;
    margin: 0;
  }
  .subtitle {
    color: rgba(255, 255, 255, 0.85);
    font-size: 13px;
    line-height: 1.6;
    margin: 0;
    letter-spacing: 0.5px;
  }

  .back-btn {
    background: rgba(255, 255, 255, 0.95) !important;
    border-color: rgba(255, 255, 255, 0.95) !important;
    color: #2f80ed !important;
    font-weight: 600;
  }
  .back-btn:hover {
    background: #ffffff !important;
    color: #1f6fda !important;
  }
  .form-item { margin-bottom: 20px; }
  .form-item__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 10px;
  }
  .label { font-size: 13px; color: #374151; display: inline-flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
  .label-count { font-size: 12px; color: #9ca3af; font-weight: normal; }
  .label-hint { font-size: 12px; color: #b5b9c1; font-weight: normal; }
  .readonly, .file-list {
    background: #fafafa;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }
  .readonly { min-height: 44px; display: flex; align-items: center; padding: 0 14px; color: #111827; font-size: 14px; }

  .drop-zone {
    color: #9ca3af;
    width: 100%;
    min-height: 64px;
    padding: 12px 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: #fafbfc;
    border: 1px dashed #d1d5db;
    border-radius: 8px;
    font-size: 13px;
    cursor: pointer;
    transition: border-color 0.15s, background 0.15s, color 0.15s;
  }
  .drop-zone:hover {
    border-color: #6366f1;
    background: #f5f6ff;
    color: #4f46e5;
  }
  .drop-icon { font-size: 16px; }

  .list-actions { display: flex; gap: 8px; align-items: center; }
  .option-label { user-select: none; font-size: 12px; color: #6b7280; }
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

  .actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    margin-top: 4px;
    padding-top: 20px;
    border-top: 1px solid #f0f1f3;
    flex: none;
  }
  .actions-left { display: flex; align-items: center; gap: 10px; min-width: 0; }
  .actions-right { display: flex; align-items: center; gap: 12px; flex: none; }
}
</style>
