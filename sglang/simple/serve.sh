#!/bin/bash

MODEL_FILE="../../huggingface/heterodoxin/gemma-4-e4b-it-apostate"
SERVED_NAME="gemma-4-e4b-it-apostate"

# Launch in background
python3 -m sglang.launch_server \
		--model-path "$MODEL_FILE" \
		--served-model-name "$SERVED_NAME" \
		--port "$PORT" \
		--host 0.0.0.0 \
		--context-length 32768 \
		--mem-fraction-static 0.90 \
		--chunked-prefill-size 16384 \
		--max-prefill-tokens 32768 \
		--kv-cache-dtype fp8_e5m2 \
		--max-running-requests 16 \
		--cuda-graph-max-bs 24 \
		--enable-multimodal \
		--trust-remote-code \
		--watchdog-timeout 600
