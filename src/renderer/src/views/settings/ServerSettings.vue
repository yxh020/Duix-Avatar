<template>
  <div class="server-settings">
    <div class="panel">
      <div class="panel-head">
        <div class="head-text">
          <div class="title">服务器设置</div>
          <div class="subtitle">
            把这里指向跑 Docker 容器的 A 机器局域网 IP。改完保存后，下一次提交任务立即生效，不用重启应用。
          </div>
        </div>
        <div class="head-extra">
          <t-button theme="default" variant="outline" @click="goBack">返回首页</t-button>
        </div>
      </div>

      <div class="form-card">
        <div class="form-row">
          <label class="row-label">
            服务端 IP
            <span class="hint" v-if="state.sources.ip === 'env'">当前来自启动器（.bat 注入）</span>
            <span class="hint" v-else-if="state.sources.ip === 'user'">当前来自此处保存</span>
            <span class="hint hint--muted" v-else>未配置 — 走默认 127.0.0.1</span>
          </label>
          <t-input v-model="state.form.ip" placeholder="例如 192.168.3.105" :disabled="state.busy" />
        </div>

        <div class="form-row form-row--cols">
          <div class="col">
            <label class="row-label">
              face2face 端口
              <span class="hint hint--muted">默认 8383</span>
            </label>
            <t-input-number
              v-model="state.form.face2facePort"
              :min="1" :max="65535" :decimal-places="0"
              :disabled="state.busy"
              style="width: 100%"
            />
          </div>
          <div class="col">
            <label class="row-label">
              TTS 端口
              <span class="hint hint--muted">默认 18180</span>
            </label>
            <t-input-number
              v-model="state.form.ttsPort"
              :min="1" :max="65535" :decimal-places="0"
              :disabled="state.busy"
              style="width: 100%"
            />
          </div>
        </div>

        <div class="actions">
          <t-button theme="default" :loading="state.testing" :disabled="!canTest" @click="onTest">
            测试连接
          </t-button>
          <t-button theme="primary" :loading="state.saving" :disabled="!canTest" @click="onSave">
            保存
          </t-button>
          <t-button theme="default" variant="text" :disabled="state.busy" @click="onReset">
            恢复默认
          </t-button>
        </div>

        <div v-if="state.testResult" class="test-result">
          <div class="test-row" :class="rowClass(state.testResult.face2face)">
            <span class="dot"></span>
            <span class="svc">face2face ({{ state.form.ip }}:{{ state.form.face2facePort }})</span>
            <span class="status">{{ statusText(state.testResult.face2face) }}</span>
            <span class="detail">{{ detailText(state.testResult.face2face) }}</span>
          </div>
          <div v-if="hasPortOnly" class="hint-line">
            提示：端口通但服务无响应，通常是 Docker 容器还在启动，等 30 秒再试一次。
          </div>
        </div>

        <div v-if="state.filePath" class="footer-note">
          配置文件位置：<code>{{ state.filePath }}</code>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { MessagePlugin } from 'tdesign-vue-next'
import { Client } from '@renderer/client'

const router = useRouter()

const state = reactive({
  form: { ip: '', face2facePort: 8383, ttsPort: 18180 },
  sources: { ip: 'default', face2facePort: 'default', ttsPort: 'default' },
  filePath: '',
  testing: false,
  saving: false,
  testResult: null,
  get busy() { return state.testing || state.saving }
})

const canTest = computed(() => {
  const ip = (state.form.ip || '').trim()
  if (!ip) return false
  return Number.isInteger(state.form.face2facePort)
      && Number.isInteger(state.form.ttsPort)
      && !state.busy
})

const hasPortOnly = computed(() => {
  const r = state.testResult
  return r && r.face2face?.status === 'port-only'
})

onMounted(async () => {
  await loadCurrent()
})

async function loadCurrent() {
  try {
    const cur = await Client.serverConfig.get()
    state.form.ip = cur.ip
    state.form.face2facePort = cur.face2facePort
    state.form.ttsPort = cur.ttsPort
    state.sources = cur.sources || state.sources
    state.filePath = cur.filePath || ''
  } catch (err) {
    MessagePlugin.error('读取当前服务器配置失败：' + (err && err.message))
  }
}

async function onTest() {
  state.testing = true
  state.testResult = null
  try {
    const res = await Client.serverConfig.test({
      ip: state.form.ip.trim(),
      face2facePort: state.form.face2facePort,
      ttsPort: state.form.ttsPort
    })
    if (!res.ok) {
      MessagePlugin.error(res.error || '测试失败')
      return
    }
    state.testResult = res
    if (res.face2face?.status === 'ok') MessagePlugin.success('face2face 服务正常')
    else MessagePlugin.warning('face2face 服务有问题，看下方详情')
  } catch (err) {
    MessagePlugin.error('测试出错：' + (err && err.message))
  } finally {
    state.testing = false
  }
}

async function onSave() {
  state.saving = true
  try {
    const res = await Client.serverConfig.save({
      ip: state.form.ip.trim(),
      face2facePort: state.form.face2facePort,
      ttsPort: state.form.ttsPort
    })
    if (!res.ok) {
      MessagePlugin.error('保存失败：' + (res.error || '未知错误'))
      return
    }
    if (res.effective) {
      state.sources = res.effective.sources || state.sources
    }
    MessagePlugin.success('已保存，下一次任务即用新地址')
  } catch (err) {
    MessagePlugin.error('保存出错：' + (err && err.message))
  } finally {
    state.saving = false
  }
}

async function onReset() {
  state.saving = true
  try {
    const res = await Client.serverConfig.reset()
    if (res.ok && res.effective) {
      state.form.ip = res.effective.ip
      state.form.face2facePort = res.effective.face2facePort
      state.form.ttsPort = res.effective.ttsPort
      state.sources = res.effective.sources
    }
    state.testResult = null
    MessagePlugin.success('已恢复默认（回到启动器/环境变量值）')
  } finally {
    state.saving = false
  }
}

function rowClass(r) {
  if (!r) return 'row--fail'
  if (r.status === 'ok') return 'row--ok'
  if (r.status === 'port-only') return 'row--warn'
  return 'row--fail'
}

function statusText(r) {
  if (!r) return '—'
  if (r.status === 'ok') return '通 ✓'
  if (r.status === 'port-only') return '端口通 / 服务无响应'
  return '不通 ✗'
}

function detailText(r) {
  if (!r) return ''
  const parts = []
  if (r.tcp) parts.push(`TCP ${r.tcp.ok ? r.tcp.latencyMs + 'ms' : r.tcp.reason}`)
  if (r.http) parts.push(`HTTP ${r.http.ok ? r.http.latencyMs + 'ms' : r.http.reason}`)
  return parts.join(' · ')
}

function goBack() {
  router.push('/home')
}
</script>

<style lang="less" scoped>
.server-settings {
  height: calc(100vh - 60px);
  padding: 20px;
  background-color: #f4f4f6;
  overflow: auto;
}

.panel {
  background: #fff;
  border-radius: 8px;
  padding: 24px;
  max-width: 760px;
}

.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 24px;
  margin-bottom: 24px;

  .title {
    font-family: HarmonyOS Sans SC, PingFang SC, sans-serif;
    font-weight: 600;
    font-size: 20px;
    color: #1f2329;
    line-height: 28px;
  }
  .subtitle {
    margin-top: 6px;
    font-size: 13px;
    color: #696f7a;
    line-height: 20px;
    max-width: 560px;
  }
}

.form-card {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.form-row {
  display: flex;
  flex-direction: column;
  gap: 6px;

  &--cols {
    flex-direction: row;
    gap: 18px;
    .col {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
  }
}

.row-label {
  font-size: 13px;
  color: #1f2329;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;

  .hint {
    font-weight: 400;
    font-size: 12px;
    color: #3c73ff;
  }
  .hint--muted { color: #9097a5; }
}

.actions {
  display: flex;
  gap: 10px;
  margin-top: 8px;
}

.test-result {
  margin-top: 8px;
  border: 1px solid #ebeef2;
  border-radius: 6px;
  padding: 12px 14px;
  background: #fafbfc;

  .test-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 0;
    font-size: 13px;

    .dot {
      width: 8px; height: 8px; border-radius: 50%;
      background: #ccc;
      flex-shrink: 0;
    }
    .svc { color: #1f2329; min-width: 220px; }
    .status { font-weight: 600; min-width: 160px; }
    .detail { color: #696f7a; font-size: 12px; }
  }

  .row--ok   .dot    { background: #1bbf6c; }
  .row--ok   .status { color: #1bbf6c; }
  .row--warn .dot    { background: #ffae00; }
  .row--warn .status { color: #b56b00; }
  .row--fail .dot    { background: #e34d59; }
  .row--fail .status { color: #e34d59; }

  .hint-line {
    margin-top: 6px;
    font-size: 12px;
    color: #b56b00;
  }
}

.footer-note {
  margin-top: 16px;
  font-size: 12px;
  color: #9097a5;
  code {
    background: #f4f4f6;
    padding: 2px 6px;
    border-radius: 3px;
    color: #696f7a;
  }
}
</style>
