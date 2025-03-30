from flask import Flask, request, jsonify, render_template
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

# Global default parameters
DEFAULT_PARAMS = {
    "model": "schnell",
    "width": 720,
    "height": 1280,
    "prompt": "MY_SUBCONSCIOUS",
    "go_fast": False,
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

@app.route("/generate", methods=["POST"])
def generate():
    # Get request data
    data = request.get_json() or {}
    
    # Create a clean copy of defaults
    model_params = DEFAULT_PARAMS.copy()
    
    # Map Processing parameter names to server parameter names
    param_mapping = {
        "model_version": "model",
        "input_image": "image"
    }
    
    # Update parameters from request data, handling mapped names
    for key, value in data.items():
        target_key = param_mapping.get(key, key)
        if target_key in model_params or target_key == "image":
            model_params[target_key] = value
    
    # Add any additional parameters that aren't in defaults but are needed
    if "lora" in data:
        model_params["lora"] = data["lora"]
    
    # Process image if provided
    image_data = model_params.get("image")
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
                # Already base64 encoded - ensure it's marked as PNG
                if "data:image/jpeg;base64," in image_data:
                    model_params["image"] = image_data.replace("data:image/jpeg;base64,", "data:image/png;base64,")
                
            else:
                # Treat as local file path, encode to base64
                try:
                    with open(image_data, "rb") as img_file:
                        encoded_image = base64.b64encode(img_file.read()).decode('utf-8')
                        model_params["image"] = f"data:image/png;base64,{encoded_image}"
                except Exception as e:
                    print(f"Error reading image file {image_data}: {str(e)}")
                    return jsonify({"success": False, "error": f"Could not read image file: {str(e)}"}), 400
        
        # Print the parameters being sent (for debugging)
        print("Sending parameters to Replicate:", model_params)
        
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
        
        if response.status_code == 422:
            error_detail = response.json().get("detail", "Unknown error")
            print("Replicate API validation error:", error_detail)
            return jsonify({"success": False, "error": f"API validation error: {error_detail}"}), 422
        
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
        print("Error in generate:", str(e))  # Add error logging
        return jsonify({"success": False, "error": str(e)}), 500
        
    finally:
        # Clean up temp file if created
        if temp_file:
            try:
                os.unlink(temp_file.name)
            except:
                pass

@app.route("/config", methods=["GET", "POST"])
def config():
    global DEFAULT_PARAMS
    
    if request.method == "POST":
        try:
            new_params = request.get_json()
            # Update only existing parameters
            for key in DEFAULT_PARAMS:
                if key in new_params:
                    DEFAULT_PARAMS[key] = new_params[key]
            return jsonify({"success": True, "params": DEFAULT_PARAMS})
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 400
    
    # GET request - render the configuration page
    return render_template(
        'config.html', 
        params=DEFAULT_PARAMS
    )

@app.route("/config/defaults", methods=["GET"])
def get_defaults():
    """Get the current default parameters in JSON format"""
    return jsonify(DEFAULT_PARAMS)

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True) 