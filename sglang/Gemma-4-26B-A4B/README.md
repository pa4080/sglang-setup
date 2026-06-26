# Gemma 4 26B A4B - SGLang Setup

## Model Information
- **Model**: Gemma 4 26B A4B (QAT quantization to Q4_K_XL GGUF)
- **Architecture**: gemma4 (MoE with 4B active)
- **Size**: ~14GB
- **Context**: 131K tokens
- **Server**: SGLang
- **Port**: 10007 → 8000 (container)

## Important: Gemma-Specific Configuration

### KV Cache Must Be FP16
Gemma 4 architecture uses **hybrid sliding-window attention** and **logit soft-capping** which produces massive activation outliers. Quantized KV caches (q8_0, fp8) cause catastrophic precision loss leading to:
- Repetitive token generation
- Context loss
- Server hangs

**Always use `--kv-cache-dtype fp16` for Gemma models.**

## Quick Start

```bash
# Setup environment
cp .env.example .env

# Start server
docker compose up -d

# Check logs
docker logs -f gemma-4-26b-serve

# Test health
curl http://localhost:10007/health
```

## Testing Architecture Support

If this fails with:
```
ValueError: GGUF model with architecture gemma4 is not supported yet.
```

Then SGLang's GGUF loader doesn't support Gemma 4 either, and you'll need to use **llama.cpp instead**.

## Resource Requirements

- **VRAM**: ~18-20GB (FP16 cache uses more memory)
- **System RAM**: 16GB
- **GPU**: NVIDIA with CUDA support

## Troubleshooting

### Architecture Not Supported
If SGLang rejects `gemma4` architecture:
```bash
# Switch to llama.cpp
cd ../../llama-cpp
# Use the existing router.ini configuration
```

### Out of Memory
Lower context or switch to Q8 cache (risk: quality loss):
```yaml
--context-length 65536      # Half context
--mem-fraction-static 0.70  # Less memory
```

## Notes
- **No vision support** with GGUF (mmproj files not loadable)
- FP16 KV cache is **mandatory** for Gemma stability
- Check logs for architecture support errors
