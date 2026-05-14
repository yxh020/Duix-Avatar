import { ipcMain, app } from 'electron'
import crypto from 'crypto'
import path from 'path'
import fs from 'fs'
import { isEmpty } from 'lodash'
import { assetPath, dockerConfig } from '../config/config.js'
import { selectPage,selectByStatus, updateStatus, remove as deleteVideo, findFirstByStatus } from '../dao/video.js'
import { selectByID as selectF2FModelByID } from '../dao/f2f-model.js'
import { removeModelById, isTempModelName } from './model.js'
import { selectByID as selectVoiceByID } from '../dao/voice.js'
import {
  insert as insertVideo,
  count,
  update,
  selectByID as selectVideoByID
} from '../dao/video.js'
import { makeAudio4Video, copyAudio4Video } from './voice.js'
import { makeVideo as makeVideoApi,getVideoStatus } from '../api/f2f.js'
import log from '../logger.js'
import { getVideoDuration } from '../util/ffmpeg.js'

const MODEL_NAME = 'video'

/**
 * 分页查询合成结果
 * @param {number} page
 * @param {number} pageSize
 * @returns
 */
function page({ page, pageSize, name = '' }) {
  // 查询的有waiting状态的视频
  const waitingVideos = selectByStatus('waiting').map((v) => v.id)
  const total = count(name)
  const list = selectPage({ page, pageSize, name }).map((video) => {
    video = {
      ...video,
      file_path: video.file_path ? path.join(assetPath.model, video.file_path) : video.file_path
    }

    if(video.status === 'waiting'){
      video.progress = `${waitingVideos.indexOf(video.id) + 1} / ${waitingVideos.length}`
    }
    return video
  })

  return {
    total,
    list
  }
}

function findVideo(videoId) {
  const video = selectVideoByID(videoId)
  return {
    ...video,
    file_path: video.file_path ? path.join(assetPath.model, video.file_path) : video.file_path
  }
}

function countVideo(name = '') {
  return count(name)
}

function saveVideo({ id, model_id, name, text_content, voice_id, audio_path }) {
  const video = selectVideoByID(id)
  if(audio_path){
    audio_path = copyAudio4Video(audio_path)
  }

  if (video) {
    return update({ id, model_id, name, text_content, voice_id, audio_path })
  }
  return insertVideo({ model_id, name, status: 'draft', text_content, voice_id, audio_path })
}

/**
 * 合成视频
 * 更新视频状态为waiting
 * @param {number} videoId
 * @returns
 */
function makeVideo(videoId) {
  update({ id: videoId, status: 'waiting' })
  return videoId
}

export async function synthesisVideo(videoId) {
  try{
    update({
      id: videoId,
      file_path: null,
      status: 'pending',
      message: '正在提交任务',
    })

    // 查询Video
    const video = selectVideoByID(videoId)
    log.debug('~ makeVideo ~ video:', video)

    // 根据modelId获取model信息
    const model = selectF2FModelByID(video.model_id)
    log.debug('~ makeVideo ~ model:', model)

    let audioPath
    if(video.audio_path){
      // 将audio_path复制到ttsProduct目录下
      audioPath = video.audio_path
    }else{
      // 根据model信息中的voiceId获取voice信息
      const voice = selectVoiceByID(video.voice_id || model.voice_id)
      log.debug('~ makeVideo ~ voice:', voice)

      // 调用tts接口生成音频
      audioPath = await makeAudio4Video({
        voiceId: voice.id,
        text: video.text_content
      })
      log.debug('~ makeVideo ~ audioPath:', audioPath)
    }

    // 调用视频生成接口生成视频
    let result, param
    ({ result, param } = await makeVideoByF2F(audioPath, model.video_path))

    log.debug('~ makeVideo ~ result, param:', result, param)

    // 插入视频表
    if(10000 === result.code){ // 成功
      update({
        id: videoId,
        file_path: null,
        status: 'pending',
        message: result,
        audio_path: audioPath,
        param,
        code: param.code
      })
    }else{ // 失败
      update({
        id: videoId,
        file_path: null,
        status: 'failed',
        message: result.msg,
        audio_path: audioPath,
        param,
        code: param.code
      })
    }
  } catch (error) {
    log.error('~ synthesisVideo ~ error:', error.message)
    updateStatus(videoId, 'failed', error.message)
  }

  // 6. 返回视频id
  return videoId
}

// face2face 服务端 /easy/query 的 progress 字段只跳 0/20/80/100 四档，
// 同一档可能停几分钟，运营看着像卡死。
// 真实进度从容器 stdout 抽：每渲染完一帧会打 "[N] avi write success, current_idx: M"。
// 启动一次 `docker logs -f` 流式读，按 task code 维护已写出的最大帧号，
// 配合提交前 ffprobe 拿到的总帧数（音频时长 × 30 fps），算真百分比。
//
// 这套是"硬件无关"的真实进度：4090 跑得快帧号涨得快、4060 慢就慢，
// 跟 GPU/音频时长/分辨率无关，所见即所得。
const frameIdxByCode = new Map()    // taskCode -> max current_idx 已写出
const totalFramesByCode = new Map() // taskCode -> 预算总帧数
const startAtByCode = new Map()     // taskCode -> 首次见到 status=1 的时间戳（用于 0→20% 软启动）
// 软启动时长：服务端 /easy/query 一进入 status=1 就直接报 20%（特征提取阶段无细分），
// 用前 30 秒按时间线性 ramp 0→20，避免运营看到一上来就 20% 觉得"虚标"。
const SOFT_START_MS = 30_000

let logTailer = null
function ensureDockerLogTailer() {
  if (logTailer) return
  try {
    const { spawn } = require('child_process')
    logTailer = spawn('docker', ['logs', '-f', '--tail', '0', dockerConfig.containerName])
    let buffer = ''
    const onData = (chunk) => {
      buffer += chunk.toString('utf8')
      let nl
      while ((nl = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, nl)
        buffer = buffer.slice(nl + 1)
        // 形如：... INFO: <code> -> [N] avi write success, current_idx: M.
        const m = line.match(/INFO:\s+([a-f0-9-]{36})\s+->\s+\[\d+\]\s+avi write success,\s+current_idx:\s+(\d+)/)
        if (m) {
          const code = m[1]
          const idx = parseInt(m[2], 10)
          if (idx > (frameIdxByCode.get(code) || 0)) {
            frameIdxByCode.set(code, idx)
          }
        }
      }
    }
    logTailer.stdout.on('data', onData)
    logTailer.stderr.on('data', onData) // docker logs 内容混在 stderr 里也常见
    logTailer.on('exit', (code) => {
      log.warn(`docker logs tailer exited (code=${code}), real progress will fall back to API`)
      logTailer = null
    })
    logTailer.on('error', (err) => {
      log.warn('docker logs tailer error:', err.message)
      logTailer = null
    })
  } catch (e) {
    log.warn('failed to spawn docker logs tailer:', e.message)
    logTailer = null
  }
}

// 容器渲染的真实 fps 写在每个任务开始时被覆盖的 result/param.json 第 4 个字段。
// 当前镜像 = 30 fps，但若官方升级，从文件读才不会出错。
// 同步 fs.readFileSync 即可，文件很小，提交前 < 1ms。
function getCurrentFps() {
  try {
    const paramJsonPath = path.join(path.dirname(assetPath.model), 'result', 'param.json')
    const data = JSON.parse(fs.readFileSync(paramJsonPath, 'utf8'))
    if (Array.isArray(data) && typeof data[3] === 'number' && data[3] > 0) {
      return data[3]
    }
  } catch (e) {
    // 文件还没写出（首次运行）或者格式异常 —— 回落到 30
  }
  return 30
}

export async function loopPending() {
  const video = findFirstByStatus('pending')
  if (!video) {
    synthesisNext()

    setTimeout(() => {
      loopPending()
    }, 2000)
    return
  }

  const statusRes = await getVideoStatus(video.code)

  // lite 模式：任务结束（成功 / 失败 / 系统异常）都尝试回收临时模特 __TMP__。
  // model_id 拿不到、模特不是临时的、删除报错都吞掉，不影响主链路。
  const cleanupTempModel = () => {
    try {
      if (!video.model_id) return
      const model = selectF2FModelByID(video.model_id)
      if (model && isTempModelName(model.name)) {
        removeModelById(model.id)
      }
    } catch (e) {
      log.warn('cleanupTempModel error:', e.message)
    }
  }

  if ([9999, 10002, 10003].includes(statusRes.code)) {
    updateStatus(video.id, 'failed', statusRes.msg)
    frameIdxByCode.delete(video.code)
    totalFramesByCode.delete(video.code)
    startAtByCode.delete(video.code)
    cleanupTempModel()
  } else if (statusRes.code === 10000) {
    if (statusRes.data.status === 1) {
      ensureDockerLogTailer()
      // 首次见到 status=1 → 记下时间戳，后面用于 0→20% 软启动 ramp
      if (!startAtByCode.has(video.code)) {
        startAtByCode.set(video.code, Date.now())
      }
      // 优先用 docker logs 抽到的真实帧号算百分比；拿不到就回退 API progress
      let displayProgress = statusRes.data.progress
      const total = totalFramesByCode.get(video.code)
      const current = frameIdxByCode.get(video.code)
      if (total > 0 && current > 0) {
        const realPct = Math.floor((current / total) * 100)
        displayProgress = Math.max(statusRes.data.progress, Math.min(99, realPct))
      }
      // 进度永不倒退：electron 重启或 docker logs 重新连接时，
      // 内存里的帧号 Map 是空的，displayProgress 会被算成 API 报的低档值（比如 20）。
      // 用 DB 已经写过的进度作下限兜住，运营不会看到进度条往回缩。
      // 封顶 99，留给 status=2 的 100 跳变。
      const dbProgress = typeof video.progress === 'number' ? video.progress : 0
      displayProgress = Math.min(99, Math.max(dbProgress, displayProgress))
      // 软启动 cap：前 30 秒按时间线性 ramp 0→20，盖住服务端瞬跳到 20% 的问题。
      // 只在还在 0→20 阶段（dbProgress < 20）应用，避免重启 session 时把已经爬到的进度拉回来。
      if (dbProgress < 20) {
        const elapsed = Date.now() - startAtByCode.get(video.code)
        const softCap = Math.floor(Math.min(1, elapsed / SOFT_START_MS) * 20)
        displayProgress = Math.min(displayProgress, softCap)
      }
      updateStatus(
        video.id,
        'pending',
        statusRes.data.msg,
        displayProgress,
      )
    }else if (statusRes.data.status === 2) { // 合成成功
      // ffmpeg 获取视频时长
      let duration
      if(process.env.NODE_ENV === 'development'){
        duration = 88
      }else{
        const resultPath = path.join(assetPath.model, statusRes.data.result)
        duration = await getVideoDuration(resultPath)
      }

      update({
        id: video.id,
        status: 'success',
        message: statusRes.data.msg,
        progress: statusRes.data.progress,
        file_path: statusRes.data.result,
        duration
      })
      frameIdxByCode.delete(video.code)
      totalFramesByCode.delete(video.code)
      startAtByCode.delete(video.code)
      cleanupTempModel()

    } else if (statusRes.data.status === 3) {
      updateStatus(video.id, 'failed', statusRes.data.msg)
      frameIdxByCode.delete(video.code)
      totalFramesByCode.delete(video.code)
      startAtByCode.delete(video.code)
      cleanupTempModel()
    }
  }

  setTimeout(() => {
    loopPending()
  }, 2000)
  return video
}

/**
 * 合成下一个视频
 */
function synthesisNext() {
  // 查询所有未完成的视频任务
  const video = findFirstByStatus('waiting')
  if (video) {
    synthesisVideo(video.id)
  }
}

function removeVideo(videoId) {
  // 查询视频
  const video = selectVideoByID(videoId)
  log.debug('~ removeVideo ~ videoId:', videoId)

  // 删除视频
  const videoPath = path.join(assetPath.model, video.file_path ||'')
  if (!isEmpty(video.file_path) && fs.existsSync(videoPath)) {
    fs.unlinkSync(videoPath)
  }

  // 删除音频
  const audioPath = path.join(assetPath.model, video.audio_path ||'')
  if (!isEmpty(video.audio_path) && fs.existsSync(audioPath)) {
    fs.unlinkSync(audioPath)
  }

  // 删除视频表
  return deleteVideo(videoId)
}

function exportVideo(videoId, outputPath) {
  const video = selectVideoByID(videoId)
  const filePath = path.join(assetPath.model, video.file_path)
  fs.copyFileSync(filePath, outputPath)
}

/**
 * 调用face2face生成视频
 * @param {string} audioPath
 * @param {string} videoPath
 * @returns
 */
async function makeVideoByF2F(audioPath, videoPath) {
  const uuid = crypto.randomUUID()
  const param = {
    audio_url: audioPath,
    video_url: videoPath,
    code: uuid,
    chaofen: 0,
    watermark_switch: 0,
    pn: 1
  }

  // 提交前预算总帧数：音频时长 × fps（fps 优先从上次任务的 param.json 读，回落 30）。
  // 这个数会被 loopPending 用来算真实进度。失败了也不影响主流程，只是进度条会回退到 API 4 档。
  try {
    const fullAudioPath = path.join(assetPath.ttsProduct, audioPath)
    const audioDuration = await getVideoDuration(fullAudioPath)
    if (audioDuration > 0) {
      totalFramesByCode.set(uuid, Math.ceil(audioDuration * getCurrentFps()))
    }
  } catch (e) {
    log.warn('~ makeVideoByF2F ~ failed to compute total frames for progress:', e.message)
  }

  const result = await makeVideoApi(param)
  return { param, result }
}

function modify(video) {
  return update(video)
}

export function init() {
  // electron 退出前杀掉 docker logs 流的子进程，避免变成孤儿
  app.on('before-quit', () => {
    if (logTailer) {
      try { logTailer.kill() } catch (e) { /* 子进程已死也 OK */ }
      logTailer = null
    }
  })

  ipcMain.handle(MODEL_NAME + '/page', (event, ...args) => {
    return page(...args)
  })
  ipcMain.handle(MODEL_NAME + '/make', (event, ...args) => {
    return makeVideo(...args)
  })
  ipcMain.handle(MODEL_NAME + '/modify', (event, ...args) => {
    return modify(...args)
  })
  ipcMain.handle(MODEL_NAME + '/save', (event, ...args) => {
    return saveVideo(...args)
  })
  ipcMain.handle(MODEL_NAME + '/find', (event, ...args) => {
    return findVideo(...args)
  })
  ipcMain.handle(MODEL_NAME + '/count', (event, ...args) => {
    return countVideo(...args)
  })
  ipcMain.handle(MODEL_NAME + '/export', (event, ...args) => {
    return exportVideo(...args)
  })
  ipcMain.handle(MODEL_NAME + '/remove', (event, ...args) => {
    return removeVideo(...args)
  })
}
