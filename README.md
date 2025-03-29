# Replicate API Flask Server

A simple Flask server that serves as an API wrapper for the Replicate.com API, specifically for the `fofr/flux-my-subconscious` model.

## Setup

1. Clone this repository
2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```
3. Copy `.env.example` to `.env` and add your Replicate API token:
   ```
   cp .env.example .env
   ```
4. Edit `.env` and add your Replicate API token

## Running the Server

```
python app.py
```

The server will run on http://localhost:5000 by default.

## API Endpoints

### POST /generate

Generate an image using the fofr/flux-my-subconscious model.

**Request Body:**

```json
{
  "prompt": "Your prompt text",
  "width": 720,
  "height": 1280,
  "image": "optional_image_url_or_base64_or_filepath"
}
```

All parameters for the model are supported. The defaults are:

```json
{
  "model": "schnell",
  "width": 720,
  "height": 1280,
  "prompt": "MY_SUBCONSCIOUS",
  "go_fast": false,
  "lora_scale": 1,
  "megapixels": "1",
  "num_outputs": 1,
  "aspect_ratio": "custom",
  "output_format": "png",
  "guidance_scale": 3,
  "output_quality": 80,
  "prompt_strength": 0.8,
  "extra_lora_scale": 1,
  "num_inference_steps": 4
}
```

**Image Input Formats:**

The `image` parameter can be any of:
- URL starting with `http`
- Base64 encoded image starting with `data:image`
- Local file path

**Response:**

```json
{
  "success": true,
  "output_url": "https://replicate.delivery/..."
}
```

### GET /health

Health check endpoint.

**Response:**

```json
{
  "status": "healthy"
}
```

## Example Usage

Using curl:

```bash
curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful landscape",
    "image": "https://example.com/input.jpg"
  }'
```

Using Python requests:

```python
import requests

response = requests.post(
    "http://localhost:5000/generate",
    json={
        "prompt": "a beautiful landscape",
        "image": "https://example.com/input.jpg"
    }
)
print(response.json())
``` 