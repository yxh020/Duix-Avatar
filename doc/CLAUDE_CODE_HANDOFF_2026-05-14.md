# Claude Code Handoff - 2026-05-14

## 1. 本次工作的出发点

- 目标不是研究底层模型，而是先把朋友的 `Duix-Avatar` fork 在本机跑起来，后面微调成内部批量数字人工具。
- 当前优先路线已经明确：`先走 Duix lite 路线，先跑起来`。
- 业务定位也已经明确：
  - 单个运营自己找素材、自己拍、自己找文案、自己配音、自己对口型、自己去剪映去重。
  - 工具重点负责：`形象素材 + 音频 -> 批量对口型生成视频`
  - 去重不在 Duix 里做，未来可考虑接到 `pyJianyingExport`。

## 2. 仓库与路径

- 仓库路径：`E:\AI-code\leo-Duix`
- 远程：`https://github.com/yxh020/Duix-Avatar.git`
- 当前本机 Duix 数据目录标准：
  - `E:\docker-data\duix-avatar-data\face2face`
  - 完整三服务后续预留：
    - `E:\docker-data\duix-avatar-data\voice\data`

## 3. 已完成的本地改动

### 仓库内新增文件

- `deploy/docker-compose.local.yml`
  - 完整三服务本机版
  - 路径已改到 `E:\docker-data\duix-avatar-data`
- `deploy/docker-compose-lite.local.yml`
  - lite 单服务本机版
  - 路径已改到 `E:\docker-data\duix-avatar-data\face2face`

### 仓库外环境改动

- Docker 配置文件：`C:\Users\Admin\.docker\daemon.json`
- 已加入镜像源，目前内容收敛为：
  - `https://docker.m.daocloud.io`

说明：
- 这是本机环境改动，不在 git 仓库内。
- 这么做是因为完整三服务里 `fish-speech-ziming` 镜像在线拉取反复失败。

## 4. 当前实际运行状态

### 已成功

- Docker Desktop 当前可正常工作。
- `docker info` 能正常返回。
- lite 容器已成功启动：
  - 容器名：`duix-avatar-gen-video`
  - 镜像：`guiji2025/duix.avatar`
  - 端口：`8383`
- 本机接口验证成功：
  - 访问：`http://127.0.0.1:8383/easy/query?code=test`
  - 返回：`200`
  - 内容：`任务不存在`
  - 这说明 API 通了。
- 容器内显卡可见：
  - `RTX 4060 Ti`
  - 容器内 `nvidia-smi` 正常

### 当前仍在运行的服务

- 仅保留 lite：
  - `duix-avatar-gen-video`

### 当前没有运行的东西

- 没有完整三服务的 compose 进程残留
- 没有 `fish-speech-ziming` 的后台拉取进程残留
- 没有 `tts/asr` 容器在运行

## 5. 镜像现状

### 已有镜像

- `guiji2025/duix.avatar`
- `guiji2025/fun-asr`
- 原有 TTS 相关：
  - `leo-tts/indextts15-route1:1.5-vllm-20260507`
  - `vllm/vllm-openai:v0.9.0`

### 缺失镜像

- `guiji2025/fish-speech-ziming`

## 6. 完整三服务卡点

完整三服务需要：

- `duix-avatar-gen-video`
- `duix-avatar-asr`
- `duix-avatar-tts`

目前卡点只剩 `duix-avatar-tts` 对应镜像：

- `guiji2025/fish-speech-ziming`

### 已尝试过的方案

1. 直接 `docker compose -f deploy/docker-compose.local.yml up -d`
2. 单独 `docker pull guiji2025/fish-speech-ziming`
3. 加多个 registry mirror
4. 只保留 `docker.m.daocloud.io`
5. 直接拉镜像站地址：
   - `docker pull docker.m.daocloud.io/guiji2025/fish-speech-ziming`

### 实际报错/现象

- 一种是 Docker Hub / 代理链路报 `EOF`
- 一种是镜像层 `failed size validation`
- 还有一种是长时间停在一串 `Already exists` 之后不再继续

结论：
- 不是 Docker 整体坏了
- 不是显卡问题
- 不是 compose 文件问题
- 是 `fish-speech-ziming` 这张镜像获取链路不稳定

## 7. 当前建议路线

### 现在主线

先继续用 lite，把这台机跑顺：

- 用你自己的 `IndexTTS` 生成音频
- 用 Duix lite 只做：
  - `素材视频 + 音频 -> 对口型视频`

### 完整三服务后续路线

完整三服务不要再在这台机上死磕在线拉取。

更稳的方式：

1. 在别的能成功拉到 `guiji2025/fish-speech-ziming` 的机器上执行：
   - `docker pull guiji2025/fish-speech-ziming`
2. 导出：
   - `docker save guiji2025/fish-speech-ziming -o fish-speech-ziming.tar`
3. 拷到本机
4. 本机导入：
   - `docker load -i fish-speech-ziming.tar`
5. 然后再起完整三服务

## 8. 用户已明确的产品边界

- 默认匹配逻辑：`1 个形象素材 + 1 个音频 = 1 个作品`
- 一个文案可能生成多个 MP3
- 但同一个素材一般不会和同一个音频重复使用
- 不做复杂素材分类，用户自己用文件夹和命名管理
- 输出文件名要尽量详细
- 停止策略：停止后续任务，不强杀已提交任务
- 失败策略：显示失败，最多自动重试 1 次
- 去重不放在 Duix 里做
- 素材来源不做记录

## 9. Claude Code 接手建议

### 如果继续走 lite 落地

优先做这些：

1. 跑朋友 fork 客户端，看当前批量页在 lite 下是否能直接用
2. 如果批量页仍依赖 `addModel -> TTS/ASR`，就改成 lite 友好流程：
   - 不走声音克隆
   - 不走临时模特训练
   - 直接使用现成素材视频 + 现成音频提交到 `8383`
3. 做一套更贴近业务的批量逻辑：
   - 默认一对一顺序匹配
   - 单素材多音频
   - 多素材单音频
4. 保留详细输出命名

### 如果继续补完整三服务

不要继续在线拉 `fish-speech-ziming`。
优先改走：`别的机器 docker save -> 本机 docker load`

## 10. 关键命令

### 查看 lite 状态

```powershell
docker ps
docker logs duix-avatar-gen-video --tail 80
```

### lite 本地配置

```powershell
docker compose -f deploy\docker-compose-lite.local.yml up -d
docker compose -f deploy\docker-compose-lite.local.yml down
```

### 完整三服务本地配置

```powershell
docker compose -f deploy\docker-compose.local.yml up -d
docker compose -f deploy\docker-compose.local.yml down
```

### 本机 API 快速自检

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8383/easy/query?code=test"
```

## 11. 当前 git 状态

当前仓库未提交改动应包括：

- `deploy/docker-compose.local.yml`
- `deploy/docker-compose-lite.local.yml`
- 本文件 `doc/CLAUDE_CODE_HANDOFF_2026-05-14.md`

说明：
- Docker 配置文件 `C:\Users\Admin\.docker\daemon.json` 不在仓库里，不会进 git。

## 12. lite curl 端到端实测验证（2026-05-14 23:24 ~ 23:34）

第一次接手后用 curl 直接打通了 lite 单服务的合成链路，跳过整个客户端。
踩出来的契约写在下面，**下次接手前先看这一节，能省一遍试错。**

### 测试用例

| 项 | 值 |
|---|---|
| 视频 | `E:\AI-code\inputfiles\已去水印素材.mp4`（12 MB，1080×1920，竖屏） |
| 音频 | `E:\AI-code\inputfiles\钩子马.mp3`（1.9 MB，约 82 秒） |
| 容器 | `duix-avatar-gen-video`（lite 单服务，已 up） |
| GPU | RTX 4060 Ti，运行时占用 ~79%、显存 5.9 / 8.0 GB |
| 耗时 | submit → status=2 约 **8 分 30 秒** |
| 出片 | 68 MB，82.5 秒，1080×1920 |

### 已确认的 5 条 API 契约

1. **路径语义 = basename**
   - `audio_url` / `video_url` 字段是相对 `/code/data/temp/` 的 **文件名**，不是绝对路径
   - 即 host 上要把素材放到 `E:\docker-data\duix-avatar-data\face2face\temp\`
   - 客户端代码 [src/main/service/video.js:256-263](src/main/service/video.js:256) 提交参数已经是 basename 形式，跟服务约定一致

2. **出片落点 = temp/，不是 result/**
   - API 返回 `result: "/test001-r.mp4"`，前面一道斜杠**只是分隔符**
   - 实际文件在 `/code/data/temp/{code}-r.mp4`，host 对应：
     `E:\docker-data\duix-avatar-data\face2face\temp\{code}-r.mp4`
   - `result/` 目录只放 `param.json`（中间元数据：`[code, video_path, has_audio, fps, w, h, avi_path, work_dir, audio_npy, ?]`）
   - 这跟原客户端 [src/main/service/video.js:186](src/main/service/video.js:186) 用 `assetPath.model` 拼路径的逻辑是吻合的（model 路径 = temp 路径）
   - **重点**：出片文件名是 `{code}-r.mp4`（带 `-r` 后缀），不是 `{code}.mp4`

3. **音频要先转 wav**
   - mp3 没裸提交过，**别冒险**
   - 转码命令（直接用容器内 ffmpeg，省一次本机依赖）：
     ```bash
     docker exec duix-avatar-gen-video ffmpeg -y -loglevel error \
       -i /code/data/temp/<src>.mp3 -ar 16000 -ac 1 /code/data/temp/<src>.wav
     ```

4. **progress 字段精度极差**
   - 整个生命周期只在 **20%（特征提取完成）→ 80%（视频处理完成）→ 100%（任务完成）** 跳三档
   - 中间真实进度只能靠 `docker logs duix-avatar-gen-video --tail N` 看 `[N] preprocess_/avi write` 帧号
   - 后面做 UI 的话：**别绑 API progress 做精细进度条**，按"提交中 → 处理中 → 完成"三态显示更靠谱

5. **status 值约定**
   - `status=1` 运行中
   - `status=2` 成功（带 `cost / width / height / video_duration`）
   - `status=3` 失败

### 路径不对齐问题（接手时必须改）

客户端 [src/main/config/config.js:20-33](src/main/config/config.js:20) 仍写死 `D:\duix_avatar_data\...`，
但容器只挂了 `E:\docker-data\duix-avatar-data\face2face`，两边对不上。

不改这个，直接跑 electron 客户端肯定败：UI 把素材写到 D:\，容器在 E:\ 上找不到。

### 批量页的 addModel 死路

[src/renderer/src/views/model-quick-create/index.vue:173](src/renderer/src/views/model-quick-create/index.vue:173)
调 `addModel`，`addModel` 一定会调 `trainVoice`（见 [src/main/service/model.js:35-48](src/main/service/model.js:35) → [src/main/service/voice.js:17-31](src/main/service/voice.js:17)），
而 trainVoice 走 TTS 服务（18180），lite 模式没起 TTS，必失败。

接手时**必改**：批量页 submitOne() 跳过 addModel/saveVideo，直接：

```
对每个 (video, audio):
  1. 拷视频/音频到 E:\docker-data\duix-avatar-data\face2face\temp\
  2. POST /easy/submit  { audio_url: 'xxx.wav', video_url: 'yyy.mp4', code: uuid, chaofen:0, watermark_switch:0, pn:1 }
  3. 轮询 /easy/query?code=uuid
  4. status=2 → 把 {code}-r.mp4 拷到用户指定输出目录（用详细命名）
```

### 留在 temp/ 的测试样品

```
E:\docker-data\duix-avatar-data\face2face\temp\
  test1.mp4          原视频
  test1.mp3          原音频
  test1.wav          ffmpeg 转出来的 wav
  test001-r.mp4      出片（68 MB，82s，1080x1920）
  test001/           中间帧目录
```

下次接手前可以保留，作为 "API 通不通" 的基准测试样本。
要清就 `rm -rf E:\docker-data\duix-avatar-data\face2face\temp\test*`。

### 复现命令（一键自测）

```powershell
# 1. 看容器和 GPU
docker ps
docker logs duix-avatar-gen-video --tail 40

# 2. 提交（前提：temp/ 下已有 test1.wav + test1.mp4）
curl.exe -s -X POST -H "Content-Type: application/json" `
  -d '{\"audio_url\":\"test1.wav\",\"video_url\":\"test1.mp4\",\"code\":\"selfcheck001\",\"chaofen\":0,\"watermark_switch\":0,\"pn\":1}' `
  http://127.0.0.1:8383/easy/submit

# 3. 轮询
curl.exe -s "http://127.0.0.1:8383/easy/query?code=selfcheck001"
```

## 13. 数据目录标准修正（2026-05-15）：E:\\ → D:\\

§2 § 12 里写的 `E:\docker-data\duix-avatar-data\face2face` 是 codex 当时拍的标准，
**实际验证发现这个标准是错的**：

- 官方客户端 `Duix.Avatar-1.0.6-lite-setup.exe` 默认把视频/音频写到 `D:\duix_avatar_data\face2face\temp\`
- 官方 `deploy/docker-compose-lite.yml` 默认挂载也是 `d:/duix_avatar_data/face2face`
- E:\\docker-data\\ 这条标准跟官方默认完全不对齐，**实测一上就死**：
  容器在 /code/data/temp/ 找不到客户端写到 D:\\ 的文件 → `三次获取音频时长失败`

修正：

- 当前 `deploy/docker-compose-lite.local.yml` 已改回 `d:/duix_avatar_data/face2face`（跟官方完全一致，本质冗余，本次清理已删除该文件）
- 之后 lite 路线**统一走官方默认 `D:\duix_avatar_data\face2face`**
- 完整三服务（`docker-compose.local.yml`）仍然挂 E:\\docker-data\\ —— 后续如果真要起完整三服务，需要二次修正

E:\\docker-data\\duix-avatar-data\\face2face\\temp\\ 里残留的 §12 测试样品（test1.*、test001-r.mp4）从这台机的容器视角已不可见，但物理文件仍在盘上。要清直接 `rm -rf`。

## 14. 运营单任务分发：两脚本两文件方案

### 运营需要的东西

| 文件 | 来源 | 用途 |
|---|---|---|
| `duix-avatar.tar` | 官方 GitHub Release | `docker load -i` 进本机；脚本会自动调 |
| `Duix.Avatar-1.0.6-lite-setup.exe` | 官方 GitHub Release | 客户端，双击装 |
| `start-duix-lite.bat` | 本仓库 `deploy/` | 双击入口（纯 ASCII） |
| `start-duix-lite.ps1` | 本仓库 `deploy/` | 启动主体（UTF-8 with BOM） |

打成 zip 发给运营，解压后跟 `duix-avatar.tar` 放同目录，双击 `.bat` 即可。

### 前置环境（运营机器必须）

1. NVIDIA 显卡（≥ 8 GB 显存，4060 Ti 实测）
2. NVIDIA 驱动 + Windows WSL2 (`wsl --install`)
3. Docker Desktop for Windows（启用 WSL2 后端）
4. 磁盘 D:\\ 存在，至少留 30 GB 空闲

### `start-duix-lite.ps1` 内部流程

1. 找 docker.exe
2. 检查 Docker Desktop 在跑
3. 用一次性 `docker run nvidia-smi` 探针验证 GPU 接通（镜像没 load 时跳过此步）
4. 检查镜像 → 没有就 `docker load -i duix-avatar.tar`（30 分钟超时）
5. 建 `D:\duix_avatar_data\face2face\{temp,result,log}`
6. 干掉同名旧容器
7. `docker run` 起新容器（带 `--gpus all --restart always --privileged --shm-size=8g -p 8383:8383 -v d:/duix_avatar_data/face2face:/code/data` + `python /code/app_local.py`）
8. 轮询 `http://127.0.0.1:8383/easy/query?code=ping` 自检（最多 60 秒）

### 编码规则（重要）

`.bat` 必须纯 ASCII，`.ps1` 必须 UTF-8 with BOM，详见全局 `~/.claude/CLAUDE.md` 「Windows 分发脚本」章节。
完整版规则与范本路径见 `life/40_wiki/windows-distribution-scripts.md`。

### 实测确认

- 本机（leo 工作机，RTX 4060 Ti）：lite 容器 + 客户端 + curl 双链路均通
- 运营机（春超机器，2026-05-15）：`start-duix-lite.bat` 双击 → 出片，通


