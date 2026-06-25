# SGLang Qwen3.6-35B-A3B Configuration Refinements

## Overview
This document outlines recommended refinements for the Qwen3.6-35B-A3B-MTP deployment on NVIDIA GPU based on SGLang best practices.

**Note:** The Ascend NPU documentation provided focuses on NPU-specific optimizations. This refinement focuses on NVIDIA GPU deployment with GGUF quantized models.

## Current Configuration

```yaml
Command:
  --model-path /models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf
  --model-name Qwen3.6-35B-A3B-UD-IQ4_NL
  --load-format gguf
  --mmproj /models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/mmproj-BF16.gguf
  --enable-multimodal
  --kv-cache-dtype fp8_e5m2
  --context-length 262144
  --port 8000
  --host 0.0.0.0
  --mem-fraction-static 0.85
  --chunked-prefill-size 16384
  --watchdog-timeout 600
  --tp 1
  --max-running-requests 16
```

## Recommended Refinements

### 1. **CUDA Graph Optimization** (NEW)
Enable CUDA graph compilation for better GPU kernel efficiency:
- Add `--disable-cuda-graph` removal (it's enabled by default, but we can optimize batch sizes)
- Add `--cuda-graph-max-bs 32` for dynamic batch size capture up to 32

**Rationale:** CUDA graphs significantly reduce kernel launch overhead for decode operations. For single GPU deployment with moderate concurrency (16 requests), max batch size of 32 is optimal.

### 2. **Chunked Prefill Tuning**
Keep current value: `--chunked-prefill-size 16384`

**Rationale:** 16KB chunks are good for balancing prefill latency with memory efficiency on single GPU. This aligns with Ascend NPU recommendations for similar workload patterns.

### 3. **Memory Fraction Adjustment** (MODIFY)
Current: `--mem-fraction-static 0.85`
Recommended: `--mem-fraction-static 0.80`

**Rationale:** With GGUF quantization (IQ4_NL), leave slightly more headroom for dynamic allocations and KV cache. The FP8 KV cache is already memory-efficient.

### 4. **Max Running Requests** (REVIEW)
Current: `--max-running-requests 16`
Recommended: Keep 16 or increase to 24-32 depending on GPU VRAM

**Rationale:** For single 24GB GPU, 16 is conservative. With IQ4 quantization + fp8_e5m2 KV cache, you might handle 24-32 concurrent requests with shorter contexts.

### 5. **Prefix Caching** (NEW - OPTIONAL)
Add: `--enable-radix-cache` (enabled by default, but explicitly noted)

**Rationale:** Radix cache is beneficial for repeated prefixes (e.g., system prompts). The Ascend docs show significant gains with prefix caching (90% hit rate scenarios).

### 6. **Speculative Decoding** (ADVANCED - OPTIONAL)
The Qwen3.6-35B-A3B model supports built-in multi-token prediction (NEXTN). For GGUF format, this may not be applicable, but if using full precision models later:

```bash
--speculative-algorithm NEXTN \
--speculative-num-steps 3 \
--speculative-eagle-topk 1 \
--speculative-num-draft-tokens 4
```

**Note:** This requires the full model, not GGUF quantized version.

### 7. **Data Type Specification** (CLARIFY)
For GGUF models, the quantization is embedded. However, for KV cache:
- Keep: `--kv-cache-dtype fp8_e5m2` ✅

**Rationale:** FP8 E5M2 provides excellent memory savings with minimal quality loss.

### 8. **Health Check Optimization**
Current: 120s start period is good
Consider: Adjust interval based on actual startup time

### 9. **Max Prefill Tokens** (NEW - OPTIONAL)
Add: `--max-prefill-tokens 32768`

**Rationale:** Limits single prefill operation size, preventing OOM on very long inputs while allowing 262K context via chunked prefill.

### 10. **Request Rate Limiting** (PRODUCTION)
Add environment variables:
```yaml
- MAX_TOTAL_TOKENS=524288  # 2x context length
- MAX_LORAS=0              # Not using LoRA
```

## Recommended Configuration Changes

### Priority 1 (High Impact)
1. Add CUDA graph max batch size
2. Adjust mem-fraction-static to 0.80
3. Add max-prefill-tokens limit

### Priority 2 (Medium Impact)
4. Consider increasing max-running-requests to 24
5. Explicitly enable features (radix-cache, etc.)

### Priority 3 (Low Priority/Advanced)
6. Monitor and tune based on actual workload
7. Consider speculative decoding if switching to full model

## Testing Recommendations

1. **Baseline Benchmark:**
   ```bash
   python -m sglang.bench_serving \
     --backend sglang \
     --host localhost \
     --port 10005 \
     --dataset-name random \
     --random-input-len 2048 \
     --random-output-len 512 \
     --num-prompts 100 \
     --request-rate 4
   ```

2. **Long Context Test:**
   ```bash
   # Test with longer contexts (64K input)
   --random-input-len 65536 \
   --random-output-len 1024 \
   --num-prompts 10
   ```

3. **Multimodal Test:**
   Test with image inputs to verify mmproj is working correctly

## Performance Expectations

With these refinements on a single 24GB GPU:
- **Throughput:** ~500-800 tokens/sec (decode) with 16 concurrent requests
- **Latency:** 20-40ms per token (TPOT) at moderate load
- **Context:** Up to 262K tokens (chunked), effectively ~64K practical limit on single GPU

## Notes

- GGUF quantization (IQ4_NL) trades ~5-10% quality for 4x memory reduction
- FP8 E5M2 KV cache adds another ~2x memory savings
- Single GPU limits practical context to ~64-128K with multiple concurrent requests
- For longer contexts or higher throughput, consider multi-GPU setup (TP=2 or more)

## References

- Ascend NPU docs: Hardware-specific optimizations (NOT directly applicable)
- SGLang Server Arguments: https://docs.sglang.io/docs/advanced_features/server_arguments
- Quantized KV Cache: https://docs.sglang.io/docs/advanced_features/quantized_kv_cache
- CUDA Graphs: https://docs.sglang.io/docs/advanced_features/breakable_cuda_graph
