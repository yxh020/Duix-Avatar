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

