# SGLang Router Docker Configuration

## Helper commands

### Docker

```bash
docker compose down && docker compose up -d && docker logs -f llama-cpp
```

```bash
docker compose down
docker compose up -d
docker logs -f llama-cpp
```

```bash
docker run --rm ghcr.io/ggml-org/llama.cpp:server-cuda --help
```

### Power limit

```bash
sudo nvidia-smi -i 0 -pl 300
```

### Monitoring

```bash
watch nvidia-smi -i 0
```

```bash
nvtop
```

### Hugging Face

```bash
hf download  DAXZEIT/Qwen3.6-27B-Claude-Opus-Reasoning-Distilled-UD-Q4_K_XL-gguf --local-dir DAXZEIT/Qwen3.6-27B-Claude-Opus-Reasoning-Distilled-UD-Q4_K_XL-gguf  --include "**"
```

## Refs

- <https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055>
