# Qwable 5 27B Coder - SGLang Setup

## Model Information
- **Model**: Qwable 5 27B Coder (Q4_K_M GGUF quantization)
- **Base**: Qwen3.6-27B (standard architecture, not MoE)
- **Size**: ~16GB
- **Context**: 131K tokens
- **Multimodal**: Text-only (GGUF format)
- **Server**: SGLang
- **Port**: 10006 → 8000 (container)

## Why This Model?

Qwable is based on Qwen3.6-27B (standard `qwen2` architecture), which SGLang supports in GGUF format. Unlike the Qwen3.6-35B-A3B which uses the unsupported `qwen35moe` architecture, this model works with SGLang GGUF loader.

> **Note**: This model was created as a demonstration of minimal fine-tuning (10 traces, 3 minutes training). See the [base model card](https://huggingface.co/DJLougen/Qwable-5-27B-Coder) for full context.

## Configuration Details

### Current Settings
- **KV Cache**: `fp8_e5m2` (efficient memory usage)
- **Memory Allocation**: 80% static (good balance)
- **Max Requests**: 24 concurrent
- **Prefill Batch**: 32K tokens max
- **CUDA Graphs**: Enabled (batch size up to 32)

### Why Text-Only?
SGLang's GGUF loader doesn't support separate `mmproj` files for vision. The mmproj file exists (`mmproj-Qwable-5-27B-Coder-f16.gguf`) but can't be loaded. For multimodal support, you'd need the full non-GGUF model.

## Quick Start

```bash
# Setup environment
cp .env.example .env
# Edit .env with your API keys

# Start server
docker compose up -d

# Check logs
docker logs -f qwable-27b-serve

# Test health
curl http://localhost:10006/health

# List models
curl http://localhost:10006/v1/models
```

## Usage Examples

### Text Completion
```bash
curl http://localhost:10006/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwable-5-27B-Coder-Q4_K_M",
    "messages": [
      {"role": "user", "content": "Write a Python function to parse JSON safely"}
    ],
    "temperature": 0.6,
    "max_tokens": 2000
  }'
```

### Streaming Response
```bash
curl http://localhost:10006/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwable-5-27B-Coder-Q4_K_M",
    "messages": [
      {"role": "system", "content": "You are a helpful coding assistant."},
      {"role": "user", "content": "Explain async/await in Python"}
    ],
    "stream": true,
    "temperature": 0.7
  }'
```

## Performance Tuning

Edit [docker-compose.yml](docker-compose.yml) command section:

### Lower Memory Usage
```yaml
--mem-fraction-static 0.70  # From 0.80
--context-length 65536      # From 131072
```

### Higher Throughput
```yaml
--max-running-requests 32   # From 24
--max-prefill-tokens 65536  # From 32768
```

### Better Quality (Higher VRAM)
```yaml
--kv-cache-dtype fp16       # From fp8_e5m2
--mem-fraction-static 0.85  # From 0.80
```

## Resource Requirements

### Minimum (128K context)
- **VRAM**: ~18GB
- **System RAM**: 8GB
- **GPU**: NVIDIA with CUDA support

### Recommended (131K context)
- **VRAM**: ~20GB
- **System RAM**: 16GB
- **GPU**: RTX 3090 / 4090 or better

## Comparison with Other Models

| Model            | Size | Context | VRAM  | Architecture | SGLang GGUF Support |
| ---------------- | ---- | ------- | ----- | ------------ | ------------------- |
| **Qwable 5 27B** | 16GB | 131K    | ~18GB | qwen2        | ✅ YES               |
| Qwen3.6-35B-A3B  | 18GB | 262K    | ~20GB | qwen35moe    | ❌ NO                |
| Gemma 4 26B      | 14GB | 128K    | ~16GB | gemma4       | ✅ YES               |

## Troubleshooting

### Model Won't Load
```bash
# Check if it's an architecture issue
docker logs qwable-27b-serve 2>&1 | grep -i "architecture\|error"

# If you see "qwen35moe not supported", wrong model
# Qwable uses standard qwen2, should work
```

### Out of Memory
```bash
# Lower context size
# Edit docker-compose.yml:
--context-length 65536  # Half of current 131K
```

### Slow Performance
```bash
# Check GPU utilization
docker exec qwable-27b-serve nvidia-smi

# Increase batch sizes if GPU underutilized
--max-prefill-tokens 65536
--cuda-graph-max-bs 64
```

## Monitoring

```bash
# Watch logs
docker logs -f qwable-27b-serve

# Check health endpoint
watch -n 2 'curl -s http://localhost:10006/health | jq'

# Resource usage
docker stats qwable-27b-serve

# Restart service
docker compose restart

# Stop service
docker compose down
```

## Notes

- This is a **text-only** setup (no vision support with GGUF)
- Model serves on **port 10006** externally
- Compatible with OpenAI API format
- Use `served-model-name` value in API calls: `Qwable-5-27B-Coder-Q4_K_M`
