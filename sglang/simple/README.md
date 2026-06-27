# Qwopus3.6-27B-Coder-MTP (SGLang Native)

Native SGLang server deployment for **Qwopus3.6-27B-Coder-Compat-MTP-GGUF** with built-in MTP (Multi-Token Prediction) speculative decoding via the NEXTN algorithm.

## Model

| Property           | Value                                                                                                               |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| Model              | [Jackrong/Qwopus3.6-27B-Coder-Compat-MTP-GGUF](https://huggingface.co/Jackrong/Qwopus3.6-27B-Coder-Compat-MTP-GGUF) |
| Quantization       | Q4_K_M (~16.8 GB)                                                                                                   |
| Architecture       | Dense Transformer, 27B params                                                                                       |
| Base               | Qwen3.6-27B                                                                                                         |
| MTP Heads          | 2 (built-in, no separate draft model)                                                                               |
| MTP Acceptance     | 76.81%                                                                                                              |
| Multimodal         | Yes (vision-capable)                                                                                                |
| Native Context     | 32K (64K via YaRN scaling)                                                                                          |
| SWE-bench Verified | 67.0% (thinking-off)                                                                                                |

## Quick Start

### 0. Prequisites

```bash
sudo apt install python3-full
pipx install uv
uv venv
source .venv/bin/activate
uv pip install sglang
./serve.sh start
```

### 1. Download the model

```bash
# From the project root (huggingface/ directory)
cd /path/to/llm-lab-setup
hf download heterodoxin/gemma-4-e4b-it-apostate \
    --local-dir heterodoxin/gemma-4-e4b-it-apostate \
    --include "*"
```

### 2. Start the server

```bash
./sglang/Qwopus3.6-27B-Coder-MTP/serve.sh start
```

### 3. Test

```bash
curl http://localhost:1005/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "Qwopus3.6-27B-Coder-Compat-MTP-Q4_K_M", "prompt": "What is 2+2?", "max_tokens": 32}'
```

### 4. Stop

```bash
./sglang/Qwopus3.6-27B-Coder-MTP/serve.sh stop
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

| Parameter              | Value      | Reason                                                                             |
| ---------------------- | ---------- | ---------------------------------------------------------------------------------- |
| `mem-fraction-static`  | `0.75`     | Conservative for 24GB + 64K KV cache. Model is 16.8GB, leaving ~5.4GB for KV cache |
| `max-running-requests` | `16`       | Lower concurrency to avoid OOM with 64K windows                                    |
| `cuda-graph-max-bs`    | `24`       | Reduced from 32 for memory headroom                                                |
| `kv-cache-dtype`       | `fp8_e5m2` | fp8 KV cache saves ~50% memory vs fp16                                             |

### MTP Speculative Decoding

| Parameter                      | Value   | Reason                                               |
| ------------------------------ | ------- | ---------------------------------------------------- |
| `speculative-algorithm`        | `NEXTN` | Built-in MTP heads in GGUF (no separate draft model) |
| `speculative-num-steps`        | `3`     | 3 speculative steps per decode                       |
| `speculative-eagle-topk`       | `1`     | Top-1 for NEXTN (matches Qwen3.6 best practice)      |
| `speculative-num-draft-tokens` | `4`     | 4 draft tokens per step (up to 12 total)             |

### Context Length

| Parameter              | Value   | Reason                                       |
| ---------------------- | ------- | -------------------------------------------- |
| `context-length`       | `65536` | 64K context via YaRN scaling (native is 32K) |
| `chunked-prefill-size` | `16384` | Chunked prefill for long contexts            |
| `max-prefill-tokens`   | `32768` | Prefill limit per request                    |

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
    "model": "Qwopus3.6-27B-Coder-Compat-MTP-Q4_K_M",
    "prompt": "Write a Python function to sort a list:",
    "max_tokens": 256,
    "temperature": 0.6
  }'
```

### Chat Completions

```bash
curl http://localhost:1005/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwopus3.6-27B-Coder-Compat-MTP-Q4_K_M",
    "messages": [
      {"role": "user", "content": "Explain speculative decoding in one sentence."}
    ],
    "max_tokens": 128
  }'
```

### Multimodal (Vision)

```bash
curl http://localhost:1005/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwopus3.6-27B-Coder-Compat-MTP-Q4_K_M",
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

1. **Reduce context**: Change `--context-length 65536` to `32768` (native)
2. **Increase mem-fraction**: Change `--mem-fraction-static 0.75` to `0.80` with 32K context
3. **Lower concurrency**: Reduce `--max-running-requests` to `8`

### MTP Not Active

Check logs for NEXTN references:

```bash
grep -i "nextn\|specul\|mtp" serve.log
```

If MTP is not active, verify the GGUF file contains MTP tensors:

```bash
gguf-dump "$MODEL_FILE" | grep -i "mtp\|draft\|nextn"
```

### Server Not Starting

Check logs:

```bash
tail -50 serve.log
```

Or follow in real-time:

```bash
./serve.sh logs
```

## VRAM Budget (Approximate)

```
Q4_K_M model weights:    ~16.8 GB
KV cache (64K, fp8):     ~3.5 GB
CUDA graphs:             ~0.5 GB
Overhead / activations:  ~2.2 GB
───────────────────────────────────
Total:                   ~23.0 GB  (of 24 GB)
```

The `0.75` mem-fraction leaves a safety margin for dynamic allocations.
