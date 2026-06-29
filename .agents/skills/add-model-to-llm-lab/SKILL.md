---
name: add-model-to-llm-lab
description: Add a new model to the LLM Home Lab (llama-cpp Docker + chatLanguageModels.json). Handles research, download, router.ini config, and Copilot JSON sync.
version: 1.0
tags: [llm, llama-cpp, docker, model-configuration, copilot]
---

# Add Model to LLM Home Lab

Automates the full pipeline of adding a new model to the LLM Home Lab setup: research best parameters, download, configure `router.ini`, and sync `chatLanguageModels.json` for VS Code Copilot.

## When to Use

- User wants to add a new model to their local LLM server
- User provides a model name/repo and asks to configure it
- User wants to research optimal parameters for a new model

## Prerequisites

- NVIDIA RTX 3090 24GB (single GPU)
- Docker with llama-cpp server running on `172.16.1.110:10005`
- `nvidia-persistenced` active
- GPU power limit at 300W

## Workflow

### Step 1: Research Best Parameters

Search the internet for community recommendations on the target model:

1. Check **Hugging Face Discussions** for the model repo (look for parameter tuning threads)
2. Search for the model name + "llama.cpp router.ini" or "sampling params"
3. Check **Reddit** (r/LocalLLaMA) and **Discord** for community configs
4. Look for known issues: context loops, VRAM overflow, tool-call hangs

Key research targets:

- Optimal `temp`, `top-k`, `min-p`, `repeat-penalty`
- KV cache quantization (q4_0 vs q8_0 vs f16)
- MTP spec-decoding configs (draft model, n-max)
- Vision projector (`mmproj`) availability
- Context length limits (training vs inference)
- YaRN RoPE scaling needs

### Step 2: Download the Model

```bash
cd huggingface
hf download <org>/<repo> --local-dir <org>/<repo> --include "*.gguf"
```

Verify the download:

- Check that the `.gguf` file exists
- Note the quantization level from the filename (Q4_K_M, Q8_0, etc.)
- If a vision model, check for `mmproj-*.gguf` in the same repo

### Step 3: Add Entry to `router.ini`

**Path convention:**

- Local: `huggingface/<org>/<repo>/filename.gguf`
- router.ini: `/models/<org>/<repo>/filename.gguf`

**Template for non-MTP model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
temp = <temp>
top-k = <top-k>
; <used>Gi/<total>Gi
```

**Template for MTP (speculative decoding) model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
model-draft = /models/<org>/<repo>/<draft-gguf>
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
cache-type-k-draft = <draft-cache-k>
cache-type-v-draft = <draft-cache-v>
spec-type = draft-mtp
spec-draft-n-max = <n-max>
temp = <temp>
top-k = <top-k>
; <used>Gi/<total>Gi
```

**Template for vision model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
mmproj = /models/<org>/<repo>/<mmproj-file>.gguf
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
temp = <temp>
top-k = <top-k>
image-min-tokens = -1
; <used>Gi/<total>Gi
```

**Apply model-specific overrides:**

| Model Family                        | Overrides                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------- |
| **Gemma** (any Gemma variant)       | `cache-type-k = f16`, `cache-type-v = f16` (q8_0 causes context loops)     |
| **Ornith-1.0-35B**                  | `min-p = 0.0`, `presence-penalty = 0.0`                                    |
| **Qwopus-27B-Coder**                | `temp = 0.6`, `top-k = 20`                                                 |
| **256K+ ctx, model trained on 32K** | Add YaRN: `rope-scaling = yarn`, `rope-scale = 8`, `yarn-orig-ctx = 32768` |
| **512K/1M ctx**                     | `rope-scaling = yarn`, `rope-scale = 2` or `4`, `yarn-orig-ctx = 262144`   |

**Context size rules:**

- Must be a power of 2 (or close): 131072, 163840, 262144, 524288, 1048576
- 256K with 32K training → YaRN scale 8
- 512K with 32K training → YaRN scale 2
- 1M with 32K training → YaRN scale 4

**Memory estimation:**

- Q4_K_M: ~4.5GB per 1B params + ~1GB KV cache
- Q8_0: ~9GB per 1B params + ~2GB KV cache
- f16 KV: ~2GB per 1B params for cache
- Comment format: `; <used>Gi/<total>Gi`

### Step 4: Add Entry to `chatLanguageModels.json`

**URL:** `http://172.16.1.110:10005/v1/chat/completions`

**Token limits mapping:**

| router.ini ctx-size | maxInputTokens | maxOutputTokens |
| ------------------- | -------------- | --------------- |
| 108K–128K           | 82944–98304    | 27648–32768     |
| 122K–160K           | 92160–122880   | 30720–40960     |
| 256K                | 196608         | 65536           |
| 512K                | 393216         | 131072          |
| 1M                  | 393216         | 131072          |

**Required fields for every model:**

```json
{
  "id": "<ModelID>",
  "name": "<ModelID>",
  "url": "http://172.16.1.110:10005/v1/chat/completions",
  "toolCalling": true,
  "streaming": true,
  "thinking": true,
  "reasoningEffortFormat": "chat-completions",
  "supportsReasoningEffort": ["low", "medium", "high"],
  "maxInputTokens": <ctx-size>,
  "maxOutputTokens": <output-tokens>
}
```

**Vision models:** Add `"vision": true`

**MTP models:** Add `"reasoningEffort": "high"` to the settings block

**Edit tools (all models):**

```json
"editTools": ["apply-patch", "code-rewrite", "find-replace", "multi-find-replace"]
```

**Settings block:**
Add to `"settings"` object:

```json
"<ModelID>": {
  "reasoningEffort": "high"
}
```

### Step 5: Verify & Restart

```bash
docker compose down && docker compose up -d
docker logs -f llama-cpp
```

Check that the model loads without errors. Verify with a test prompt.

## Conventions

### Naming

- Match the router.ini entry name exactly in chatLanguageModels.json
- Use descriptive IDs: `<Family>-<Size>-<Quant>-<Variant>`
- Examples: `Ornith-1.0-9B-256K-Q80-Q4-MTP`, `Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision`

### File Organization

- Models directory: `/models/<org>/<repo>/`
- HuggingFace cache: `huggingface/<org>/<repo>/`
- Vision projectors co-located with their models

### Docker Compose

- llama-cpp already serves all models via `--models-preset /app/router.ini`
- No changes needed to `docker-compose.yml` for new models
- `--cache-ram 10240` (10GB RAM for KV cache) is the fixed allocation

### Common Pitfalls

- **Gemma + q8_0 KV cache** = guaranteed context loop. Always use f16.
- **Ornith-1.0-35B without min-p = 0.0** = premature response termination at ~3 turns.
- **Ornith-1.0-35B with mmap** = tool-call hangs at high GPU utilization.
- **Jinja template `enable_thinking | default(false)`** = forces thought channel close, causing token repetition. Remove forced bypass for Copilot.
- **Context > training context without YaRN** = possible training context overflow.
- **MTP draft model missing** = speculative decoding fails silently.

## Example: Adding a New Model

Given: `unsloth/gemma-4-26B-A4B-it-qat-GGUF` (26B params, vision, MTP4)

1. **Research**: Check HF discussions for Gemma 4 parameter tuning
2. **Download**: `hf download unsloth/gemma-4-26B-A4B-it-qat-GGUF --local-dir unsloth/gemma-4-26B-A4B-it-qat-GGUF --include "**"`
3. **router.ini**:
   ```ini
   [Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision]
   model = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf
   model-draft = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mtp-gemma-4-26B-A4B-it.gguf
   mmproj = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mmproj-BF16.gguf
   ctx-size = 262144
   cache-type-k = q8_0
   cache-type-v = q8_0
   cache-type-k-draft = q8_0
   cache-type-v-draft = q8_0
   spec-type = draft-mtp
   spec-draft-n-max = 4
   temp = 0.6
   top-k = 64
   image-min-tokens = -1
   ; 17.680Gi/24Gi
   ```
4. **chatLanguageModels.json**: Add matching entry with `maxInputTokens: 196608`, `maxOutputTokens: 65536`, `"vision": true`
5. **Restart**: `docker compose up -d`
