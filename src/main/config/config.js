import path from 'path'
import os from 'os'
import { getOverride } from './server-config.js'

const isDev = process.env.NODE_ENV === 'development'
const isWin = process.platform === 'win32'

const DEFAULT_FACE2FACE_IP   = '127.0.0.1'
const DEFAULT_FACE2FACE_PORT = 8383
const DEFAULT_FACE2FACE_PATH = '/easy'
const DEFAULT_TTS_IP   = '127.0.0.1'
const DEFAULT_TTS_PORT = 18180

// 解析 env 里的完整 URL → {host, port, path}。允许任何 env 已设置的值整体覆盖默认。
function parseEnvUrl(envKey) {
  const raw = process.env[envKey]
  if (!raw || !raw.trim()) return null
  try {
    const u = new URL(raw.trim())
    return {
      host: u.hostname,
      port: u.port ? Number(u.port) : null,
      pathname: u.pathname || ''
    }
  } catch (_) {
    return null
  }
}

function resolveFace2FaceUrl() {
  const override = getOverride()
  const env      = parseEnvUrl('DUIX_FACE2FACE_URL')
  const ip   = override.ip            || (env && env.host) || DEFAULT_FACE2FACE_IP
  const port = override.face2facePort || (env && env.port) || DEFAULT_FACE2FACE_PORT
  // path 始终用默认 /easy（不让用户设置，避免误改）
  const pathname = DEFAULT_FACE2FACE_PATH
  return `http://${ip}:${port}${pathname}`
}

function resolveTtsUrl() {
  const override = getOverride()
  const env      = parseEnvUrl('DUIX_TTS_URL')
  const ip   = override.ip      || (env && env.host) || DEFAULT_TTS_IP
  const port = override.ttsPort || (env && env.port) || DEFAULT_TTS_PORT
  return `http://${ip}:${port}`
}

// 用 getter，每次 ${serviceUrl.face2face} 访问都重新求值。
// 用户在设置页保存后下一次 API 调用立刻生效，不用重启应用。
export const serviceUrl = {
  get face2face() { return resolveFace2FaceUrl() },
  get tts() { return resolveTtsUrl() }
}

// 暴露给设置页 IPC 用，避免重复实现优先级逻辑
export function getEffectiveConfig() {
  const override = getOverride()
  const envF2F   = parseEnvUrl('DUIX_FACE2FACE_URL')
  const envTts   = parseEnvUrl('DUIX_TTS_URL')

  const ip = override.ip || (envF2F && envF2F.host) || (envTts && envTts.host) || DEFAULT_FACE2FACE_IP
  const face2facePort = override.face2facePort || (envF2F && envF2F.port) || DEFAULT_FACE2FACE_PORT
  const ttsPort       = override.ttsPort      || (envTts && envTts.port) || DEFAULT_TTS_PORT

  // 标注每个字段的来源，前端用来显示"当前来自 .bat 启动器 / 设置页"
  function sourceOf(field, envHas) {
    if (override[field] !== undefined) return 'user'
    if (envHas) return 'env'
    return 'default'
  }
  return {
    ip,
    face2facePort,
    ttsPort,
    sources: {
      ip:            override.ip            !== undefined ? 'user' : ((envF2F && envF2F.host) || (envTts && envTts.host) ? 'env' : 'default'),
      face2facePort: sourceOf('face2facePort', envF2F && envF2F.port),
      ttsPort:       sourceOf('ttsPort',       envTts && envTts.port),
    },
    override: { ...override }
  }
}

export const dockerConfig = {
  containerName: (process.env.DUIX_CONTAINER_NAME && process.env.DUIX_CONTAINER_NAME.trim()) || 'duix-avatar-gen-video'
}

export const assetPath = {
  model: isWin
    ? path.join('D:', 'duix_avatar_data', 'face2face', 'temp')
    : path.join(os.homedir(), 'duix_avatar_data', 'face2face', 'temp'),
  ttsProduct: isWin
    ? path.join('D:', 'duix_avatar_data', 'face2face', 'temp')
    : path.join(os.homedir(), 'duix_avatar_data', 'face2face', 'temp'),
  ttsRoot: isWin
    ? path.join('D:', 'duix_avatar_data', 'voice', 'data')
    : path.join(os.homedir(), 'duix_avatar_data', 'voice', 'data'),
  ttsTrain: isWin
    ? path.join('D:', 'duix_avatar_data', 'voice', 'data', 'origin_audio')
    : path.join(os.homedir(), 'duix_avatar_data', 'voice', 'data', 'origin_audio')
}
