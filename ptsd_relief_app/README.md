# ptsd_relief_app

A new Flutter project.

## Checklist
- [x] Ollama chat system functional
- [ ] Find an appropriate vision capable model
- [ ] Implement image upload and processing
- [ ] Figma design improvments
- [ ] Proper logging of chat snippets
- [ ] Hardware: order a Raspberry Pi 5 and sensors

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Command to start using Ollama
```bash
ollama serve
```
```bash
curl http://localhost:11434
```

## Pull and Manage Models
```bash
ollama pull <model_name>
```
```bash
ollama list
```
```bash
ollama show <model_name>
```
```bash
ollama rm <model_name>
```

## Run the model
```bash
ollama run <model_name> --prompt "What is the capital of France?"
```


## Models that work
- gemma3:1b
- deepseek-r1:1.5b
- qwen3:1.7b

Selected Model: **qwen3:1.7b**


# Running Ollama as a server for the flutter app
```bash
OLLAMA_HOST="0.0.0.0" ollama serve
```

## Request example (single-response)
```bash
POST /api/generate HTTP/1.1
Host: <HOST>:11434
Content-Type: application/json

{
  "model": "qwen3:1.7b",
  "prompt": "Hello, how are you?",
  "stream": true
}
```

## Request Example (chat-style)
```bash
POST /api/chat HTTP/1.1
Host: <HOST>:11434
Content-Type: application/json

{
  "model": "qwen3:1.7b",
  "messages": [
    {"role":"system","content":"You are a helpful assistant."},
    {"role":"user","content":"What’s the weather today?"}
  ],
  "stream": true
}
```