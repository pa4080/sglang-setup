# Gemma-4-E4B-IT-Apostate (SGLang Native)

Native SGLang server deployment for **heterodoxin/gemma-4-e4b-it-apostate** — a 9B multimodal model (text + vision + audio) built on Gemma4 architecture.

## Model

| Property       | Value                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------- |
| Model          | [heterodoxin/gemma-4-e4b-it-apostate](https://huggingface.co/heterodoxin/gemma-4-e4b-it-apostate) |
| Format         | Safetensors BF16 (~17 GB, single `model.safetensors`)                                             |
| Architecture   | Gemma4ForConditionalGeneration (9B params)                                                        |
| Base           | google/gemma-4-e4b-it                                                                             |
| Multimodal     | Text + Vision + Audio (all embedded in safetensors)                                               |
| Native Context | 131K (using 32K for VRAM safety)                                                                  |
| Edit Type      | Apostate (weight projection, refusal reduction: 95.8% → 29.5%)                                    |

## Quick Start

### 0. Prerequisites

```bash
sudo apt install python3-full
pipx install uv
uv venv
source .venv/bin/activate
uv pip install sglang
```

### 1. Download the model

```bash
# From the project root (huggingface/ directory)
cd /path/to/llm-lab-setup
huggingface-cli download heterodoxin/gemma-4-e4b-it-apostate \
    --local-dir huggingface/heterodoxin/gemma-4-e4b-it-apostate \
    --include "*"
```

### 2. Start the server

```bash
./sglang/simple/serve.sh start
```

### 3. Test

```bash
curl http://localhost:1005/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "gemma-4-e4b-it-apostate", "prompt": "What is 2+2?", "max_tokens": 32}'
```

### 4. Stop

```bash
./sglang/simple/serve.sh stop
```

## Script Commands

```bash
./serve.sh start      # Start the server
./serve.sh stop       # Stop the server
./serve.sh restart    # Restart
./serve.sh status     # Check if running
./serve.sh logs       # Tail server logs
```

## Configuration Rationale

### Memory (RTX 3090, 24GB VRAM)

| Parameter              | Value  | Reason                                                                                         |
| ---------------------- | ------ | ---------------------------------------------------------------------------------------------- |
| `mem-fraction-static`  | `0.90` | 9B BF16 = ~18GB model; 0.90 leaves ~2.2GB for KV cache + overhead                              |
| `max-running-requests` | `16`   | Moderate concurrency for 9B model                                                              |
| `cuda-graph-max-bs`    | `24`   | CUDA graph batch optimization                                                                  |
| `kv-cache-dtype`       | `fp16` | **Gemma4 requires fp16 KV cache** — fp8 causes quality loss (repetitive tokens, context drift) |

### Why `--kv-cache-dtype fp16`?

Gemma4 architecture uses **hybrid sliding-window attention** and **logit soft-capping** which produces massive activation outliers. Quantized KV caches (fp8, q8_0) cause catastrophic precision loss. This is documented across the workspace:

- `sglang/Gemma-4-26B-A4B/README.md` — "KV Cache Must Be FP16"
- `sglang/Gemma-4-26B-A4B/README.md` — "Always use `--kv-cache-dtype fp16` for Gemma models"

### Multimodal

The model's `config.json` contains `vision_config`, `audio_config`, and `video_token_id`. SGLang loads these automatically when `--enable-multimodal` is set — no separate mmproj file needed (unlike GGUF loaders).

### Context Length

| Parameter              | Value   | Reason                                      |
| ---------------------- | ------- | ------------------------------------------- |
| `context-length`       | `32768` | 32K — safe for 24GB VRAM with fp16 KV cache |
| `chunked-prefill-size` | `16384` | Chunked prefill for long contexts           |
| `max-prefill-tokens`   | `32768` | Prefill limit per request                   |

> **Note**: The model supports up to 131K context natively. To extend beyond 32K, reduce `mem-fraction-static` and `max-running-requests` accordingly.

## Testing

### Health Check

```bash
curl http://localhost:1005/health
```

### Model Info

```bash
curl http://localhost:1005/get_model_info | jq
```

### Text Generation

```bash
curl http://localhost:1005/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-e4b-it-apostate",
    "prompt": "Write a Python function to sort a list:",
    "max_tokens": 256,
    "temperature": 0.7
  }'
```

### Chat Completions

```bash
curl http://localhost:1005/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-e4b-it-apostate",
    "messages": [
      {"role": "user", "content": "Explain the Gemma4 architecture in one sentence."}
    ],
    "max_tokens": 128
  }'
```

### Multimodal (Vision)

```bash
curl http://localhost:1005/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-e4b-it-apostate",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "What do you see in this image?"},
          {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
        ]
      }
    ],
    "max_tokens": 256
  }'
```

## Troubleshooting

### OOM on RTX 3090

If the server fails to start with OOM errors:

1. **Reduce context**: Change `--context-length 32768` to `16384`
2. **Lower mem-fraction**: Change `--mem-fraction-static 0.90` to `0.85`
3. **Lower concurrency**: Reduce `--max-running-requests` to `8`

### Server Not Starting

Check logs:

```bash
tail -50 serve.log
```

Or follow in real-time:

```bash
./serve.sh logs
```

### Port Conflict

If port 1005 is in use:

```bash
ss -tlnp | grep 1005
```

Kill the process or change `PORT=1005` in `serve.sh` to another value.

## VRAM Budget (Approximate)

```
BF16 model weights:    ~18.0 GB
KV cache (32K, fp16):  ~3.0 GB
CUDA graphs:           ~0.5 GB
Overhead / activations: ~1.0 GB
───────────────────────────────────
Total:                 ~22.5 GB  (of 24 GB)
```

The `0.90` mem-fraction leaves a small safety margin for dynamic allocations.
