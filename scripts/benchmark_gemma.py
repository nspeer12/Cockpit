#!/usr/bin/env python3
import json
import urllib.request
import time
import sys

def benchmark_model(model_name: str, host: str = "100.103.251.82", port: int = 1234):
    url = f"http://{host}:{port}/v1/chat/completions"
    prompt = "Write a highly detailed, 500-word creative history of artificial intelligence from the year 1950 to 2050. Be descriptive and verbose."
    
    headers = {
        "Content-Type": "application/json"
    }
    
    data = {
        "model": model_name,
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.5,
        "max_tokens": 1024,
        "stream": True
    }
    
    req = urllib.request.Request(
        url, 
        data=json.dumps(data).encode('utf-8'), 
        headers=headers, 
        method="POST"
    )
    
    print(f"\n🚀 Initiating Tokens/Sec Speedtest for: {model_name}")
    print(f"📡 Target endpoint: {url}")
    print("⏳ Connecting and generating...")
    
    token_count = 0
    start_time = None
    first_token_time = None
    
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            start_time = time.time()
            
            for line in response:
                if not line:
                    continue
                line_str = line.decode('utf-8').strip()
                if not line_str.startswith("data:"):
                    continue
                if line_str == "data: [DONE]":
                    break
                
                try:
                    payload = json.loads(line_str[5:].strip())
                    delta = payload.get("choices", [{}])[0].get("delta", {})
                    content = delta.get("content", "")
                    
                    if content:
                        if token_count == 0:
                            first_token_time = time.time()
                            print("⚡ First token received. Benchmarking stream speed...\n")
                        
                        token_count += 1
                        sys.stdout.write(content)
                        sys.stdout.flush()
                except Exception:
                    pass
                    
            end_time = time.time()
            
            # Calculations
            total_duration = end_time - start_time
            generation_duration = end_time - (first_token_time if first_token_time else start_time)
            ttft = (first_token_time - start_time) if first_token_time else 0
            tps = token_count / generation_duration if generation_duration > 0 else 0
            
            print("\n\n" + "="*50)
            print(f"📊 SPEEDTEST COMPLETE: {model_name}")
            print("="*50)
            print(f"• Total Generated Tokens  : {token_count}")
            print(f"• Time-to-First-Token (TTFT): {ttft:.3f} seconds")
            print(f"• Pure Generation Duration : {generation_duration:.3f} seconds")
            print(f"• Total Process Duration   : {total_duration:.3f} seconds")
            print(f"• Token Generation Speed   : {tps:.2f} tokens/sec")
            print("="*50)
            return tps
            
    except Exception as e:
        print(f"\n❌ Error during benchmark: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    model = "google/gemma-4-31b"
    if len(sys.argv) > 1:
        model = sys.argv[1]
    benchmark_model(model)
