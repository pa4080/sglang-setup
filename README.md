# LLM Home Lab with Nvidia RTX 3090

## SGLang vs llama.cpp Architectural Differences

### 🔴 **What Won't Work the Same**

| llama.cpp                                                    | SGLang                                              | Impact                                                                                              |
| ------------------------------------------------------------ | --------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Multi-model router** (`router.ini` + `--models-preset`)    | Single model per instance                           | You get one dedicated server, not a model gateway                                                   |
| **Draft MTP speculative decoding** (`spec-type = draft-mtp`) | ✅ Supports EAGLE/NEXTN/NGRAM only                   | **MTP is not supported** — you lose draft-token acceleration                                        |
| **KV cache q4_0** (`cache-type-k = q4_0`)                    | KV cache quantization: `fp8_e5m2` / `fp8_e4m3` only | Can't use Q4 KV cache — SGLang's paged KV cache is already quite memory-efficient                   |
| **`--cache-ram` (prompt cache)**                             | SGLang uses paged KV cache natively                 | Different memory model — no prompt cache needed, but use `--max-running-requests` to limit sessions |
| **`--ctx-checkpoints`**                                      | SGLang has no checkpoint system                     | N/A (SGLang uses radix tree prefix caching instead)                                                 |

### ✅ **What Maps Well**

| llama.cpp → SGLang                                    |
| ----------------------------------------------------- |
| `ctx-size = 262144` → `--context-length 262144`       |
| `temp = 1.0` → `--temp 1.0`                           |
| `top-k = 20` → `--top-k 20`                           |
| `top-p = 0.95` → `--top-p 0.95`                       |
| `min-p = 0.0` → `--min-p 0.0`                         |
| `presence-penalty = 0.0` → `--presence-penalty 0.0`   |
| Multimodal (`mmproj`) → `--enable-multimodal`         |
| Model path → `--model-path` with `--load-format gguf` |

