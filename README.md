# SGLang Router Docker Configuration

## Helper commands

### Docker

```bash
docker compose down && docker compose up -d && docker logs -f sglang-router
```


```bash
docker compose down
docker compose up -d
docker logs -f sglang-router
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
