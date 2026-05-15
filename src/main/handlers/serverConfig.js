// 服务器设置 IPC：读取 / 保存 / 测试连通
//
// 测试连通采用两步：
//   1) TCP connect 看端口能否握手（最稳，不依赖 HTTP 协议）
//   2) 端口通了再 HTTP 打一个实接口，看服务有没有起来（容器启动中端口通但 HTTP 没响应）
// 任一步失败都带毫秒级延迟回去，前端显示三档：ok / port-only / fail。

import net from 'net'
import axios from 'axios'
import { getEffectiveConfig } from '../config/config.js'
import { saveOverride, clearOverride, getConfigFilePath } from '../config/server-config.js'

function tcpProbe(host, port, timeoutMs = 3000) {
  return new Promise((resolve) => {
    const sock = new net.Socket()
    const started = Date.now()
    let done = false
    const finish = (result) => {
      if (done) return
      done = true
      try { sock.destroy() } catch (_) {}
      resolve(result)
    }
    sock.setTimeout(timeoutMs)
    sock.once('connect', () => finish({ ok: true, latencyMs: Date.now() - started }))
    sock.once('timeout', () => finish({ ok: false, reason: 'timeout', latencyMs: Date.now() - started }))
    sock.once('error', (err) => finish({ ok: false, reason: (err && err.code) || 'error', latencyMs: Date.now() - started }))
    try { sock.connect(port, host) } catch (err) {
      finish({ ok: false, reason: 'throw:' + (err && err.message), latencyMs: 0 })
    }
  })
}

async function httpProbe(url, timeoutMs = 3000) {
  const started = Date.now()
  try {
    // validateStatus: true → 任何状态码都视为"服务有响应"（4xx/5xx 都说明 HTTP 起来了）
    await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    return { ok: true, latencyMs: Date.now() - started }
  } catch (err) {
    const reason = (err && err.code) || (err && err.message) || 'error'
    return { ok: false, reason, latencyMs: Date.now() - started }
  }
}

async function probeService(host, port, httpUrl) {
  const tcp = await tcpProbe(host, port)
  if (!tcp.ok) {
    return { status: 'fail', tcp, http: null }
  }
  const http = await httpProbe(httpUrl)
  if (http.ok) {
    return { status: 'ok', tcp, http }
  }
  return { status: 'port-only', tcp, http }
}

export default {
  name: 'serverConfig',

  async get() {
    const eff = getEffectiveConfig()
    return {
      ...eff,
      filePath: getConfigFilePath()
    }
  },

  async save(_app, payload) {
    console.info('[serverConfig.save] payload:', JSON.stringify(payload))
    const r = saveOverride(payload || {})
    if (!r.ok) return { ok: false, error: r.error }
    return { ok: true, effective: getEffectiveConfig() }
  },

  async reset() {
    clearOverride()
    return { ok: true, effective: getEffectiveConfig() }
  },

  async test(_app, payload) {
    const ip = (payload && payload.ip) || ''
    const f2fPort = Number(payload && payload.face2facePort)
    const ttsPort = Number(payload && payload.ttsPort)
    if (!ip || !Number.isInteger(f2fPort) || !Number.isInteger(ttsPort)) {
      return { ok: false, error: '参数不完整：需要 ip / face2facePort / ttsPort' }
    }
    console.info(`[serverConfig.test] ip=${ip} f2f=${f2fPort} tts=${ttsPort}`)

    const [face2face, tts] = await Promise.all([
      probeService(ip, f2fPort, `http://${ip}:${f2fPort}/easy/query?code=health-check`),
      probeService(ip, ttsPort, `http://${ip}:${ttsPort}/`)
    ])

    return {
      ok: true,
      face2face,
      tts
    }
  }
}
