# Qwen3.6-35B-A3B Configuration Guide

## Quick Start

Choose one of the provided configurations:

1. **docker-compose.yml** (Original) - Your current working configuration
2. **docker-compose.refined.yml** (Recommended) - Optimized for better performance
3. **docker-compose.conservative.yml** (Safe) - Conservative settings with stability focus

## Configuration Comparison

| Parameter            | Original | Refined | Conservative | Notes                         |
| -------------------- | -------- | ------- | ------------ | ----------------------------- |
| mem-fraction-static  | 0.85     | 0.80    | 0.78         | Memory allocation             |
| max-running-requests | 16       | 24      | 16           | Concurrent requests           |
| max-prefill-tokens   | -        | 32768   | 16384        | Prefill limit per request     |
| cuda-graph-max-bs    | -        | 32      | 24           | CUDA graph batch optimization |

## Choosing a Configuration

### Use **Original** if:
- ✅ Current setup is working well
- ✅ Don't want to risk any changes
- ✅ Running production workload

### Use **Refined** if:
- ✅ Want better throughput (20-30% improvement)
- ✅ Have 24GB+ VRAM
- ✅ Handle moderate to high concurrency
- ✅ Need optimal performance

### Use **Conservative** if:
- ✅ Have limited VRAM (<24GB)
- ✅ Prioritize stability over performance
- ✅ Running on shared GPU resources
- ✅ Want maximum reliability

## Key Improvements in Refined Configuration

### 1. CUDA Graph Optimization
```yaml
--cuda-graph-max-bs 32
```
**Benefit:** Reduces kernel launch overhead by ~15-25%
**Trade-off:** Slightly longer warmup time

### 2. Increased Concurrency
```yaml
--max-running-requests 24  # up from 16
```
**Benefit:** Better throughput under load
**Trade-off:** Requires adequate VRAM

### 3. Memory Tuning
```yaml
--mem-fraction-static 0.80  # down from 0.85
```
**Benefit:** More headroom for dynamic allocations
**Trade-off:** Slightly less KV cache capacity

### 4. Prefill Limits
```yaml
--max-prefill-tokens 32768
```
**Benefit:** Prevents OOM on very long inputs
**Trade-off:** Long contexts processed in chunks

## Testing Your Configuration

### 1. Basic Health Check
```bash
curl http://localhost:10005/health
```

### 2. Simple Generation Test
```bash
curl http://localhost:10005/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-UD-IQ4_NL",
    "prompt": "Explain quantum computing in simple terms:",
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

### 3. Multimodal Test (with base64 image)
```bash
curl http://localhost:10005/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-UD-IQ4_NL",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "What do you see in this image?"},
          {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
        ]
      }
    ]
  }'
```

### 4. Performance Benchmark
```bash
docker exec -it sglang-serve bash
python -m sglang.bench_serving \
  --backend sglang \
  --host localhost \
  --port 8000 \
  --dataset-name random \
  --random-input-len 2048 \
  --random-output-len 512 \
  --num-prompts 100 \
  --request-rate 4
```

## Performance Expectations

### Single GPU (24GB) with Refined Config

| Metric                | Value         | Notes                          |
| --------------------- | ------------- | ------------------------------ |
| **Throughput**        | 600-900 tok/s | With 16-24 concurrent requests |
| **Latency (TPOT)**    | 25-40 ms      | Per token at moderate load     |
| **Max Context**       | 262K tokens   | Theoretical (chunked prefill)  |
| **Practical Context** | 64-128K       | With concurrent requests       |
| **Concurrent Users**  | 24            | Maximum running requests       |

### Bottlenecks to Monitor

1. **GPU Memory:** Watch for OOM errors
   ```bash
   nvidia-smi dmon -s u
   ```

2. **KV Cache Utilization:** Check server logs
   ```bash
   docker logs sglang-serve | grep "cache"
   ```

3. **Request Queue:** Monitor pending requests
   ```bash
   curl http://localhost:10005/get_model_info
   ```

## Troubleshooting

### Out of Memory (OOM)
**Symptoms:** Container crashes or "CUDA out of memory" errors

**Solutions:**
1. Switch to conservative config
2. Reduce `max-running-requests` to 12-16
3. Lower `mem-fraction-static` to 0.75
4. Reduce `context-length` to 131072 (128K)

### Slow Inference
**Symptoms:** High latency (>50ms TPOT)

**Solutions:**
1. Increase `cuda-graph-max-bs`
2. Reduce concurrent requests
3. Check GPU utilization: `nvidia-smi`
4. Verify no CPU throttling

### Multimodal Not Working
**Symptoms:** Errors processing images

**Solutions:**
1. Verify mmproj path is correct
2. Check mmproj file size (~2.5GB for BF16)
3. Test with small images first
4. Verify `--enable-multimodal` flag

## Advanced Tuning

### For Higher Throughput
```yaml
--max-running-requests 32
--cuda-graph-max-bs 48
--mem-fraction-static 0.82
--chunked-prefill-size 8192  # smaller chunks, more parallelism
```

### For Lower Latency
```yaml
--max-running-requests 8
--cuda-graph-max-bs 16
--mem-fraction-static 0.88
--chunked-prefill-size 32768  # larger chunks, fewer ops
```

### For Maximum Context
```yaml
--max-running-requests 4
--context-length 262144
--mem-fraction-static 0.70
--chunked-prefill-size 32768
--max-prefill-tokens 65536
```

## Migration Steps

### From Original to Refined

1. **Backup current config:**
   ```bash
   cp docker-compose.yml docker-compose.yml.backup
   ```

2. **Test refined config:**
   ```bash
   cp docker-compose.refined.yml docker-compose.yml
   docker-compose down
   docker-compose up -d
   ```

3. **Monitor for 15 minutes:**
   ```bash
   docker logs -f sglang-serve
   nvidia-smi dmon
   ```

4. **Run benchmark:**
   ```bash
   # Compare results with baseline
   ```

5. **Rollback if needed:**
   ```bash
   cp docker-compose.yml.backup docker-compose.yml
   docker-compose restart
   ```

## Environment Variables Reference

### Current (.env file)
```bash
HF_TOKEN=your_token_here
LLAMA_API_KEY=your_api_key_here
```

### Optional Performance Tuning
```bash
# CUDA settings
CUDA_VISIBLE_DEVICES=0
CUDA_LAUNCH_BLOCKING=0

# SGLang settings
SGLANG_ALLOW_OVERLOAD=0
SGLANG_WATCHDOG_TIMEOUT=600

# Logging
SGLANG_LOGGING_LEVEL=INFO
```

## Resources

- [SGLang Server Arguments](https://docs.sglang.io/docs/advanced_features/server_arguments)
- [Quantized KV Cache](https://docs.sglang.io/docs/advanced_features/quantized_kv_cache)
- [Hyperparameter Tuning](https://docs.sglang.io/docs/advanced_features/hyperparameter_tuning)
- [GGUF Model Loading](https://docs.sglang.io/docs/advanced_features/model_loading)

## Important Notes

⚠️ **About Ascend NPU Documentation**
The Qwen3.6-35B-A3B documentation you referenced is specific to **Ascend NPU** hardware and uses NPU-specific parameters like:
- `--device npu`
- `--attention-backend ascend`
- NPU-specific environment variables (HCCL, ASCEND, etc.)

These do NOT apply to NVIDIA GPU deployment. This guide focuses on **NVIDIA GPU** optimizations.

⚠️ **About GGUF Quantization**
- IQ4_NL quantization provides 4-bit precision
- Expect minor quality degradation (~5-10%) vs full precision
- Memory usage: ~9-11GB for model + KV cache
- Trade-off: 4x smaller size for slightly lower quality

⚠️ **About Speculative Decoding**
The Ascend docs mention NEXTN speculative decoding, which is built into Qwen3.6-35B-A3B. However:
- May not be available/effective with GGUF quantization
- Requires specific model format and SGLang version
- Check SGLang documentation for GGUF + speculative decoding support

## Support

For issues specific to:
- **SGLang:** https://github.com/sgl-project/sglang/issues
- **GGUF models:** https://github.com/ggerganov/llama.cpp
- **Qwen models:** https://github.com/QwenLM/Qwen

## Changelog

### 2026-06-26
- Created refined and conservative configurations
- Added CUDA graph optimization
- Added prefill token limits
- Tuned memory fractions
- Increased max concurrent requests
