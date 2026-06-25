# Multimodal GGUF Support in SGLang

## Issue Fixed

The original configuration included unsupported arguments:
- ❌ `--model-name` → Use `--served-model-name` instead
- ❌ `--mmproj /path/to/mmproj-BF16.gguf` → Not supported for GGUF models

## Current Status

### ✅ Text-Only Model Working
The current configuration will work for **text-only inference** with the Qwen3.6-35B-A3B model:

```yaml
--model-path /models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf
--served-model-name Qwen3.6-35B-A3B-UD-IQ4_NL
--load-format gguf
--enable-multimodal
```

### ⚠️ Multimodal (Vision) Support

SGLang's GGUF loader **does not support separate mmproj files** like llama.cpp does.

For multimodal/vision capabilities with Qwen3.6-35B-A3B, you have two options:

#### Option 1: Use Non-GGUF Format (Recommended)
Load the full-precision or quantized safetensors model:

```yaml
--model-path /models/unsloth/Qwen3.6-35B-A3B-MTP
--served-model-name Qwen3.6-35B-A3B-MTP
--load-format auto  # or safetensors
--quantization fp8  # optional: fp8 weight quantization
--kv-cache-dtype fp8_e5m2
--enable-multimodal
```

**Pros:**
- ✅ Full multimodal support (text + images)
- ✅ Native SGLang multimodal handling
- ✅ Vision projector loaded automatically

**Cons:**
- ❌ Higher VRAM usage (~25-30GB vs ~11GB with GGUF IQ4)
- ❌ Slower loading time

#### Option 2: Keep GGUF for Text-Only
If you primarily need text generation and vision is secondary:

```yaml
--model-path /models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf
--served-model-name Qwen3.6-35B-A3B-UD-IQ4_NL
--load-format gguf
# Remove --enable-multimodal for text-only
```

**Pros:**
- ✅ Very low VRAM usage (~11GB)
- ✅ Fast loading
- ✅ Good text generation quality

**Cons:**
- ❌ No vision/image support

## Recommendation

Based on your setup:

### If You Need Vision Support
Switch to the full model:

```bash
cd /mnt/data/sglang/sglang/Qwen3.6-35B-A3B-MTP
cp docker-compose.yml docker-compose.gguf.backup
```

Then update docker-compose.yml:

```yaml
command: >
  python3 -m sglang.launch_server
  --model-path /models/unsloth/Qwen3.6-35B-A3B-MTP
  --served-model-name Qwen3.6-35B-A3B-MTP
  --load-format auto
  --quantization fp8
  --enable-multimodal
  --kv-cache-dtype fp8_e5m2
  --context-length 262144
  --port 8000
  --host 0.0.0.0
  --mem-fraction-static 0.80
  --chunked-prefill-size 16384
  --max-prefill-tokens 32768
  --watchdog-timeout 600
  --tp 1
  --max-running-requests 24
  --cuda-graph-max-bs 32
```

### If You Don't Need Vision
Keep GGUF, but optionally remove `--enable-multimodal` since it won't work anyway.

## Testing

After making changes, test the configuration:

```bash
docker-compose down
docker-compose up -d
docker logs -f sglang-serve
```

**Text-only test:**
```bash
curl http://localhost:10005/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-UD-IQ4_NL",
    "prompt": "Explain quantum computing:",
    "max_tokens": 100
  }'
```

**Vision test (only works with non-GGUF):**
```bash
curl http://localhost:10005/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-MTP",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What is in this image?"},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
      ]
    }]
  }'
```

## References

- [SGLang Server Arguments](https://docs.sglang.io/docs/advanced_features/server_arguments)
- [SGLang Multimodal Support](https://docs.sglang.io/docs/supported-models/multimodal_language_models)
- [SGLang Quantization](https://docs.sglang.io/docs/advanced_features/quantization)

## Summary

- ✅ **Fixed:** Removed unsupported `--model-name` and `--mmproj` arguments
- ✅ **Current:** Text-only inference works with GGUF
- ⚠️ **Limitation:** Vision requires non-GGUF format
- 📝 **Decision:** Choose based on whether you need multimodal capabilities
