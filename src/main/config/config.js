import path from 'path'
import os from 'os'

const isDev = process.env.NODE_ENV === 'development'
const isWin = process.platform === 'win32'

function resolveServiceUrl(envKey, defaultUrl) {
  const envUrl = process.env[envKey]
  return envUrl && envUrl.trim() ? envUrl.trim() : defaultUrl
}

const defaultFace2FaceUrl = isDev ? 'http://127.0.0.1:8383/easy' : 'http://127.0.0.1:8383/easy'
const defaultTtsUrl = isDev ? 'http://127.0.0.1:18180' : 'http://127.0.0.1:18180'

export const serviceUrl = {
  face2face: resolveServiceUrl('DUIX_FACE2FACE_URL', defaultFace2FaceUrl),
  tts: resolveServiceUrl('DUIX_TTS_URL', defaultTtsUrl)
}

export const assetPath = {
  model: isWin
    ? path.join('D:', 'duix_avatar_data', 'face2face', 'temp')
    : path.join(os.homedir(), 'duix_avatar_data', 'face2face', 'temp'), // 模特视频
  ttsProduct: isWin
    ? path.join('D:', 'duix_avatar_data', 'face2face', 'temp')
    : path.join(os.homedir(), 'duix_avatar_data', 'face2face', 'temp'), // TTS 产物
  ttsRoot: isWin
    ? path.join('D:', 'duix_avatar_data', 'voice', 'data')
    : path.join(os.homedir(), 'duix_avatar_data', 'voice', 'data'), // TTS服务根目录
  ttsTrain: isWin
    ? path.join('D:', 'duix_avatar_data', 'voice', 'data', 'origin_audio')
    : path.join(os.homedir(), 'duix_avatar_data', 'voice', 'data', 'origin_audio') // TTS 训练产物
}
