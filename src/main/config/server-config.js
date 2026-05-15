// 服务端配置持久化
// 文件位置：app.getPath('userData')/server-config.json
//
// 优先级（高 → 低）：
//   1. 这里保存的用户配置（设置页"服务器设置"写入）
//   2. 环境变量 DUIX_FACE2FACE_URL / DUIX_TTS_URL（.bat 启动器注入）
//   3. 默认值 127.0.0.1
//
// 设计要点：
// - 同步 IO（启动期就要拿到 URL，main/api 模块 import 时立刻读）
// - 读取一次后缓存到内存；save 时同步刷盘 + 更新缓存
// - 字段任何一个缺省都允许，缺什么用上一级（env / 默认）补

import fs from 'fs'
import path from 'path'
import { app } from 'electron'

const CONFIG_FILE_NAME = 'server-config.json'

function getConfigPath() {
  return path.join(app.getPath('userData'), CONFIG_FILE_NAME)
}

let cached = null

function loadFromDisk() {
  const p = getConfigPath()
  try {
    if (!fs.existsSync(p)) return {}
    const raw = fs.readFileSync(p, 'utf8')
    if (!raw.trim()) return {}
    const obj = JSON.parse(raw)
    return sanitize(obj)
  } catch (err) {
    console.warn('[server-config] 读取失败，按空配置处理：', err && err.message)
    return {}
  }
}

function sanitize(obj) {
  if (!obj || typeof obj !== 'object') return {}
  const out = {}
  if (typeof obj.ip === 'string' && obj.ip.trim()) out.ip = obj.ip.trim()
  const f2f = Number(obj.face2facePort)
  if (Number.isInteger(f2f) && f2f > 0 && f2f < 65536) out.face2facePort = f2f
  const tts = Number(obj.ttsPort)
  if (Number.isInteger(tts) && tts > 0 && tts < 65536) out.ttsPort = tts
  return out
}

function ensureLoaded() {
  if (cached === null) cached = loadFromDisk()
  return cached
}

export function getOverride() {
  return { ...ensureLoaded() }
}

export function saveOverride(next) {
  const clean = sanitize(next)
  const p = getConfigPath()
  try {
    fs.mkdirSync(path.dirname(p), { recursive: true })
    fs.writeFileSync(p, JSON.stringify(clean, null, 2), 'utf8')
    cached = clean
    console.info('[server-config] 已保存：', JSON.stringify(clean))
    return { ok: true, value: { ...clean } }
  } catch (err) {
    console.error('[server-config] 保存失败：', err && err.message)
    return { ok: false, error: err && err.message }
  }
}

export function clearOverride() {
  const p = getConfigPath()
  try {
    if (fs.existsSync(p)) fs.unlinkSync(p)
  } catch (err) {
    console.warn('[server-config] 删除文件失败：', err && err.message)
  }
  cached = {}
  return { ok: true }
}

export function getConfigFilePath() {
  return getConfigPath()
}
