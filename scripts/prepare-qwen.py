"""Build-time model preparation; no Python dependency inside the distributed App."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPO='mlx-community/Qwen3-ASR-1.7B-6bit'
REVISION='edd077a475c4da058e25b6e6ec1199115ca1be2b'
p=argparse.ArgumentParser();p.add_argument('--model-dir',type=Path);args=p.parse_args()
model=args.model_dir or ROOT/'.tools/models/qwen3-asr-1.7b-6bit'
if not (model/'model.safetensors').is_file():
 from huggingface_hub import snapshot_download
 snapshot_download(REPO,revision=REVISION,local_dir=model,token=False)
config=json.loads((model/'config.json').read_text())
if config.get('model_type')!='qwen3_asr' or (config.get('quantization',{}).get('bits')!=6 or config.get('thinker_config',{}).get('text_config',{}).get('hidden_size')!=2048 or config.get('thinker_config',{}).get('text_config',{}).get('num_hidden_layers')!=28):
 raise SystemExit('Expected the fixed Qwen3-ASR-1.7B-6bit model, not another engine or precision')
# Generate before signing: the runtime must never write inside the installed app.
if not (model/'tokenizer.json').exists():
 vocab=json.loads((model/'vocab.json').read_text());tc=json.loads((model/'tokenizer_config.json').read_text())
 added=[dict(id=int(i),**{k:v.get(k,False if k!='content' else '') for k in ['content','single_word','lstrip','rstrip','normalized','special']}) for i,v in sorted(tc.get('added_tokens_decoder',{}).items(),key=lambda x:int(x[0]))]
 merges=[x for x in (model/'merges.txt').read_text().splitlines() if x and not x.startswith('#')]
 pattern=r"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"
 tokenizer=dict(version='1.0',truncation=None,padding=None,added_tokens=added,normalizer={'type':'NFC'},pre_tokenizer={'type':'Sequence','pretokenizers':[{'type':'Split','pattern':{'Regex':pattern},'behavior':'Isolated','invert':False},{'type':'ByteLevel','add_prefix_space':False,'trim_offsets':True,'use_regex':False}]},post_processor=None,decoder={'type':'ByteLevel','add_prefix_space':True,'trim_offsets':True,'use_regex':True},model={'type':'BPE','dropout':None,'unk_token':None,'continuing_subword_prefix':'','end_of_word_suffix':'','fuse_unk':False,'byte_fallback':False,'vocab':vocab,'merges':merges})
 (model/'tokenizer.json').write_text(json.dumps(tokenizer,ensure_ascii=False))
(model/'saysee-model.json').write_text(json.dumps({'repo':REPO,'revision':REVISION,'precision':'6-bit'},indent=2))
print(model)
