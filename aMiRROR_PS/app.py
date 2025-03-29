from flask import Flask, request, jsonify
import replicate
import os
import requests
from dotenv import load_dotenv
import base64
import tempfile
import json

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Get Replicate API token from environment
REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN")
if not REPLICATE_API_TOKEN:
    print("Warning: REPLICATE_API_TOKEN not set in environment")

@app.route("/generate", methods=["POST"])
def generate():
    # Get request data
    data = request.get_json() or {}
    
    # Get model parameters with defaults
    model_params = {
        "model": data.get("model", "schnell"),
        "width": data.get("width", 720),
        "height": data.get("height", 1280),
        "prompt": data.get("prompt", "MY_SUBCONSCIOUS"),
        "go_fast": data.get("go_fast", False),
        "lora_scale": data.get("lora_scale", 1),
        "megapixels": data.get("megapixels", "1"),
        "num_outputs": data.get("num_outputs", 1),
        "aspect_ratio": data.get("aspect_ratio", "custom"),
        "output_format": data.get("output_format", "png"),
        "guidance_scale": data.get("guidance_scale", 3),
        "output_quality": data.get("output_quality", 80),
        "prompt_strength": data.get("prompt_strength", 0.8),
        "extra_lora_scale": data.get("extra_lora_scale", 1),
        "num_inference_steps": data.get("num_inference_steps", 4)
    }
    
    # Process image if provided
    image_data = data.get("image")
    temp_file = None
    
    try:
        # Handle different image input types
        if image_data:
            if image_data.startswith("http"):
                # Download image from URL
                response = requests.get(image_data)
                response.raise_for_status()
                temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".png")
                temp_file.write(response.content)
                temp_file.close()
                # Base64 encode the image for the API
                with open(temp_file.name, "rb") as img_file:
                    encoded_image = base64.b64encode(img_file.read()).decode('utf-8')
                    model_params["image"] = f"data:image/png;base64,{encoded_image}"
                
            elif image_data.startswith("data:image"):
                # Already base64 encoded
                model_params["image"] = image_data
                
            elif os.path.exists(image_data):
                # Local file path, encode to base64
                with open(image_data, "rb") as img_file:
                    encoded_image = base64.b64encode(img_file.read()).decode('utf-8')
                    model_params["image"] = f"data:image/png;base64,{encoded_image}"
                
        # Call Replicate API directly
        headers = {
            "Authorization": f"Bearer {REPLICATE_API_TOKEN}",
            "Content-Type": "application/json",
            "Prefer": "wait"
        }
        
        payload = {
            "version": "de1b628b969c5c1c31c9cad1916eb74a4dfbaed6e1612f61a0e6af45718cecd9",
            "input": model_params
        }
        
        response = requests.post(
            "https://api.replicate.com/v1/predictions",
            headers=headers,
            json=payload
        )
        
        response.raise_for_status()
        result = response.json()
        
        # Return the output URLs
        if result.get("output") and isinstance(result["output"], list):
            return jsonify({"success": True, "output_url": result["output"][0]})
        elif result.get("status") == "succeeded":
            return jsonify({"success": True, "output_url": result.get("output")})
        else:
            # For asynchronous responses, return the prediction ID
            return jsonify({
                "success": True, 
                "prediction_id": result.get("id"),
                "status": result.get("status")
            })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
        
    finally:
        # Clean up temp file if created
        if temp_file:
            try:
                os.unlink(temp_file.name)
            except:
                pass

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True) 