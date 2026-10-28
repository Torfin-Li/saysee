# Third-party components

Saysee's own source is MIT-licensed. Dependencies and bundled model resources retain their own licenses; this document does not relicense them.

## Model

- [Qwen3 ASR](https://github.com/QwenLM/Qwen3-ASR): Apache-2.0.
- [MLX-community Qwen3-ASR-1.7B-6bit conversion](https://huggingface.co/mlx-community/Qwen3-ASR-1.7B-6bit), pinned revision `edd077a475c4da058e25b6e6ec1199115ca1be2b`.
- The Apache license text is retained in `Resources/Licenses/Qwen3-ASR-LICENSE.txt`. App builds also include the pinned model's README/model card. Model weights are downloaded during build preparation and are not stored in this Git repository.

## Native runtime

- [MLX Audio Swift](https://github.com/Blaizzy/mlx-audio-swift): MIT, source revision fixed in `Package.swift`.
- [MLX Swift](https://github.com/ml-explore/mlx-swift): MIT. Its MLX/MLX-C, metal-cpp, fmt and JSON components have their own accompanying notices.
- Swift Transformers/Tokenizers, Swift Hugging Face, Swift Crypto, Swift ASN.1, Swift Collections, Swift Numerics, EventSource, yyjson and zstd are resolved transitively. `Package.resolved` records the exact dependency graph.

`scripts/collect-licenses.py` copies license, notice and copying files from the exact resolved dependency checkouts, including nested components, into `Contents/Resources/Licenses`. It also records `Package.resolved` in the bundle. Consult those texts for each component's terms.

The current app does not link or bundle Python, sherpa-onnx or ONNX Runtime. Historical experiments and their notices are retained only in ignored local research directories.
