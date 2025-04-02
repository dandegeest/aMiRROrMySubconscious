from flask import Flask, request, jsonify, render_template
import replicate
import os
import requests
from dotenv import load_dotenv
import base64
import tempfile
import json
from functools import lru_cache
from concurrent.futures import ThreadPoolExecutor
import logging
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Get Replicate API token from environment
REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN")
if not REPLICATE_API_TOKEN:
    logger.warning("REPLICATE_API_TOKEN not set in environment")

# Create a session with connection pooling
session = requests.Session()
retry_strategy = Retry(
    total=3,
    backoff_factor=1,
    status_forcelist=[429, 500, 502, 503, 504],
)
adapter = HTTPAdapter(max_retries=retry_strategy, pool_connections=10, pool_maxsize=10)
session.mount("https://", adapter)
session.mount("http://", adapter)

# Create a thread pool for image processing
executor = ThreadPoolExecutor(max_workers=4)

# Global default parameters
DEFAULT_PARAMS = {
    "model": "schnell",
    "model_version": "mysubconscious",
    "width": 1280,
    "height": 720,
    "prompt": "a mirror or",
    "go_fast": True,
    "lora_scale": 1,
    "megapixels": "1",
    "num_outputs": 1,
    "aspect_ratio": "custom",
    "output_format": "png",
    "guidance_scale": 3,
    "output_quality": 80,
    "prompt_strength": 0.7,
    "extra_lora_scale": 1,
    "num_inference_steps": 4
}

# Cache model version information
MODEL_VERSIONS = {
    "mysubconscious": {
        "version_id": "de1b628b969c5c1c31c9cad1916eb74a4dfbaed6e1612f61a0e6af45718cecd9",
        "trigger": "MY_SUBCONSCIOUS"
    },
    "klingon": {
        "version_id": "4cff954216285e54af8831b40d19cadd696e849f3d6840de59a77add698775eb",
        "trigger": "KLINGON"
    },
    "neo-impressionism": {
        "version_id": "7cbedb5821207721873a5dcf248a5d8fe232214e32e5b6b94c4206c218be631e",
        "trigger": "neo-impressionism"
    },
    "condensation": {
        "version_id": "7d174a0ee7e9769758117762f7069646b3478e09cca605c2c2284b349af84f2d",
        "trigger": "CONDENSATION"
    },
    "weird": {
        "version_id": "a731522059fe08264e0403847198ed5fa29973e0a0a594b45d7e0244f943f3ee",
        "trigger": "WRD"
    },
    "spittingimage": {
        "version_id": "151060b63f5e1a3c7679b43e060253f6be0e9b1e4af9a3e5adf15061e7fd6cf0",
        "trigger": "spitting image"
    },
    "jameswebb": {
        "version_id": "7b2411574454fb1a1b4e3087f48dcb138cd5e0d3d4d901be2cbb903fa71abd19",
        "trigger": "JWST"
    },
    "cyberpunk": {
        "version_id": "5d0cefd0746b833042b384c3a310bc4d1f9d1304ec59ba93e75097d40b967180",
        "trigger": "cyber"
    }
}

# Valid model values for direct use
VALID_MODELS = {"schnell", "dev"}

@lru_cache(maxsize=128)
def get_model_version(model_name):
    """Cache model version lookups"""
    return MODEL_VERSIONS.get(model_name)

def process_image(image_data):
    """Process image data in a separate thread"""
    try:
        if image_data.startswith("http"):
            response = session.get(image_data)
            response.raise_for_status()
            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".png")
            temp_file.write(response.content)
            temp_file.close()
            with open(temp_file.name, "rb") as img_file:
                encoded_image = base64.b64encode(img_file.read()).decode('utf-8')
                return f"data:image/png;base64,{encoded_image}", temp_file.name
        elif image_data.startswith("data:image"):
            if "data:image/jpeg;base64," in image_data:
                return image_data.replace("data:image/jpeg;base64,", "data:image/png;base64,"), None
            return image_data, None
        else:
            with open(image_data, "rb") as img_file:
                encoded_image = base64.b64encode(img_file.read()).decode('utf-8')
                return f"data:image/png;base64,{encoded_image}", None
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        raise

@app.route("/generate", methods=["POST"])
def generate():
    try:
        data = request.get_json() or {}
        model_params = DEFAULT_PARAMS.copy()
        
        # Update parameters efficiently
        for key, value in data.items():
            if key in model_params or key in ("image", "model_version", "lora"):
                model_params[key] = value
        
        # Handle model selection
        model_version_name = model_params.pop("model_version", None)
        model_name = model_params.get("model", "schnell")
        
        if model_version_name:
            model_info = get_model_version(model_version_name)
            if not model_info:
                return jsonify({"success": False, "error": f"Unknown model version: {model_version_name}"}), 400
            model_version = model_info["version_id"]
            model_params["model"] = "schnell"
            
            # Add trigger word if needed
            trigger = model_info.get("trigger")
            if trigger:
                prompt = model_params.get("prompt", "")
                if not prompt.startswith(trigger):
                    model_params["prompt"] = f"{trigger} {prompt}".strip()
        else:
            if model_name not in VALID_MODELS:
                return jsonify({"success": False, "error": f"Invalid model: {model_name}"}), 400
            model_version = "de1b628b969c5c1c31c9cad1916eb74a4dfbaed6e1612f61a0e6af45718cecd9"
        
        # Process image asynchronously if provided
        image_data = model_params.get("image")
        temp_file = None
        if image_data:
            future = executor.submit(process_image, image_data)
            try:
                processed_image, temp_file = future.result(timeout=10)
                model_params["image"] = processed_image
            except Exception as e:
                return jsonify({"success": False, "error": f"Image processing error: {str(e)}"}), 400
        
        # Create sanitized parameters for logging
        log_params = {k: v for k, v in model_params.items() if k != "image"}
        logger.info(f"Sending parameters to Replicate: {log_params}")
        logger.info(f"Using model version: {model_version}")
        
        # Call Replicate API
        headers = {
            "Authorization": f"Bearer {REPLICATE_API_TOKEN}",
            "Content-Type": "application/json",
            "Prefer": "wait"
        }
        
        response = session.post(
            "https://api.replicate.com/v1/predictions",
            headers=headers,
            json={"version": model_version, "input": model_params}
        )
        
        if response.status_code == 422:
            error_detail = response.json().get("detail", "Unknown error")
            logger.error(f"Replicate API validation error: {error_detail}")
            return jsonify({"success": False, "error": f"API validation error: {error_detail}"}), 422
        
        response.raise_for_status()
        result = response.json()
        
        # Return appropriate response
        if result.get("output") and isinstance(result["output"], list):
            return jsonify({"success": True, "output_url": result["output"][0]})
        elif result.get("status") == "succeeded":
            return jsonify({"success": True, "output_url": result.get("output")})
        else:
            return jsonify({
                "success": True,
                "prediction_id": result.get("id"),
                "status": result.get("status")
            })
            
    except Exception as e:
        logger.error(f"Error in generate: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500
        
    finally:
        # Clean up temp file if created
        if temp_file:
            try:
                os.unlink(temp_file)
            except:
                pass

@app.route("/config", methods=["GET", "POST"])
def config():
    global DEFAULT_PARAMS
    
    if request.method == "POST":
        try:
            new_params = request.get_json()
            # Update only existing parameters
            DEFAULT_PARAMS.update({k: v for k, v in new_params.items() if k in DEFAULT_PARAMS})
            return jsonify({"success": True, "params": DEFAULT_PARAMS})
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 400
    
    return render_template('config.html', params=DEFAULT_PARAMS)

@app.route("/config/defaults", methods=["GET"])
def get_defaults():
    return jsonify(DEFAULT_PARAMS)

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({"status": "healthy"})

@app.route("/models", methods=["GET"])
def get_models():
    return jsonify(list(MODEL_VERSIONS.keys()))

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True) 