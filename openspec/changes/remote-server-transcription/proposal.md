## Why

手机端转录质量不足；现有目标设备上 Whisper small 对 45 秒音频推理耗时 70.824 秒，仍有识别错误。把手机定位为可靠采集端，把高质量识别迁往本次一并实现的服务器，使模型能力不再受手机算力和安装包限制。

## What Changes

- **BREAKING**：从禁止运行时联网转录改为支持用户选择的远端转录；同步更新权限、隐私说明和发布检查。
- 手机保留本地原始录音、恢复和播放能力；新增持久化上传、断点续传、任务状态同步和转录结果导入。
- 新建可部署服务端：鉴权 API、音频存储、持久化任务、独立模型 worker、配置和容器部署说明。
- 首版以录音结束后的完整转录为目标；模型接口可替换，优先评测 Qwen3-ASR-1.7B，对照 faster-whisper large-v3。
- 部署目标固定为现有 RTX 3080 Ti 12GB、8 核 CPU、32GB 内存：单 GPU 任务并发、单批分块推理、识别与对齐顺序执行，不要求新增硬件。
- 远端新任务不依赖手机本地模型。保留已有录音、转录和人工编辑，避免把旧本地任务自动上传。

## Capabilities

### New Capabilities

- `remote-transcription`: 手机与自建服务端之间可恢复的音频上传、异步转录、结果回写和运行来源追踪。

### Modified Capabilities

无已发布规范：`openspec/specs/` 当前为空。本变更与待完成的 bootstrap/offline-streaming 变更并存；在远端模式的联网和推理位置上替代其离线要求，不把原有未完成任务标为完成。

## Impact

涉及 Android 联网与后台上传、Flutter 转录协调和录音配置、Drift 任务与来源元数据、bootstrap、录音/转录界面、隐私发布检查，以及新增服务端目录和部署产物。

初步 GitNexus upstream 分析：TranscriptionCoordinator 为 MEDIUM（8 个直接依赖、35 个总影响项），NewRecordingController 为 MEDIUM（5 个直接依赖、11 个总影响项）；结果未关联执行流，不代表没有业务影响。实际修改每个已有符号前仍须逐项执行 impact。
