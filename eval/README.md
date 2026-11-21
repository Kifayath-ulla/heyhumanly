# Rewrite-quality eval

Sends `cases.json` through the extension's exact prompt (`extension/core.js`) on local Ollama models, then scores each rewrite with simple automatic checks:
- facts kept
- questions and doubt kept
- tone, lowercase and slang kept
- filler removed
- length
- no invented words

```bash
ollama pull qwen2.5:3b
node eval/run.mjs --models qwen2.5:3b,qwen2.5:7b --out eval/results
node eval/run.mjs --models qwen2.5:3b --case rambling-meeting    # one case
```

Each run writes a Markdown summary and a JSON file with every rewrite. `results/baseline-0.1.5-cpu.*` is the first baseline (CPU only, temperature 0.2, seed 7).
