# aMiRROrMySubconscious? - Interactive AI Mirror

![aMiRROR](images/blended.png)

aMiRROR is an interactive Processing sketch that uses AI to transform your self-portrait into artistic and/or weird AI interpretations. It captures your image through a webcam and processes it using various AI image to image fine tuned LORA models to create unique, artistic representations.

This project will be used for an art installation titled [aMiRRoRMySubconscious](DDisArteDD.md), featuring a simulated mirror using an LCD panel mounted in a gilded frame. The installation will capture and process the portraits of onlookers in real-time, transforming their reflections into AI-generated artistic interpretations. The piece explores the intersection of technology, art, and human perception, creating a dynamic and interactive experience that challenges our understanding of self-reflection in the digital age.

Special thanks to [@fofr_ai](https://www.threads.net/@fofr_ai) for the detailed explanation of fine tuning LORA models on [Replicate.com](https://replicate.com/fofr) and for the models used in this project.

This project was built with the help of [Cursor](https://cursor.sh), an AI-powered IDE that made development and debugging a breeze. 🚀 *high five* ✋

## Requirements

### Processing Libraries
- **Video Library**
  - Open Processing
  - Go to Sketch > Import Library > Add Library
  - Search for "Video"
  - Install "Video | GStreamer-based video library for Processing" by The Processing Foundation

### Java Version
The sketch requires **Java 11 or newer** as it uses Java's built-in HTTP client.

To check your Java version in Processing:
1. Open Processing
2. Go to Help > About Processing
3. It should show which Java version is being used

If you need to update Java, download the latest JDK from [Oracle](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://adoptium.net/).

After installing the Video library and ensuring you have Java 11+, restart Processing and open the aMiRROR.pde sketch.

## Test Outputs

<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 20px;">
  <img src="images/fofr_mysubconscious_20250403_202325.png" alt="AI Generated Image 1" style="width: 100%;"/>
  <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px;">
    <img src="images/aimirror1.png" alt="AI Generated Image 2" style="width: 100%;"/>
    <img src="images/aimirror2.png" alt="AI Generated Image 3" style="width: 100%;"/>
  </div>
</div>

<div style="display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; margin-top: 20px;">
  <img src="examples/fofr_20250329_160804.png" alt="Example 1" style="width: 100%;">
  <img src="examples/fofr_20250329_160759.png" alt="Example 2" style="width: 100%;">
  <img src="examples/fofr_20250329_160755.png" alt="Example 3" style="width: 100%;">
  <img src="examples/fofr_20250329_160749.png" alt="Example 4" style="width: 100%;">
  <img src="examples/fofr_20250329_160744.png" alt="Example 5" style="width: 100%;">
  <img src="examples/fofr_20250329_160719.png" alt="Example 6" style="width: 100%;">
  <img src="examples/fofr_20250329_160715.png" alt="Example 7" style="width: 100%;">
  <img src="examples/fofr_20250329_160709.png" alt="Example 8" style="width: 100%;">
  <img src="examples/fofr_20250329_160704.png" alt="Example 9" style="width: 100%;">
  <img src="examples/fofr_20250329_160702.png" alt="Example 10" style="width: 100%;">
  <img src="examples/fofr_20250329_160650.png" alt="Example 11" style="width: 100%;">
  <img src="examples/fofr_20250329_160644.png" alt="Example 12" style="width: 100%;">
  <img src="examples/fofr_20250329_160640.png" alt="Example 13" style="width: 100%;">
  <img src="examples/fofr_20250329_160634.png" alt="Example 14" style="width: 100%;">
  <img src="examples/fofr_20250329_160629.png" alt="Example 15" style="width: 100%;">
  <img src="examples/fofr_20250329_160447.png" alt="Example 16" style="width: 100%;">
  <img src="examples/fofr_20250329_160441.png" alt="Example 17" style="width: 100%;">
  <img src="examples/fofr_20250329_160435.png" alt="Example 18" style="width: 100%;">
  <img src="examples/fofr_20250329_160431.png" alt="Example 19" style="width: 100%;">
  <img src="examples/fofr_20250329_160425.png" alt="Example 20" style="width: 100%;">
  <img src="examples/fofr_20250329_160421.png" alt="Example 21" style="width: 100%;">
  <img src="examples/fofr_20250329_160415.png" alt="Example 22" style="width: 100%;">
  <img src="examples/fofr_20250329_160411.png" alt="Example 23" style="width: 100%;">
  <img src="examples/fofr_20250329_160207.png" alt="Example 24" style="width: 100%;">
  <img src="examples/fofr_20250329_160202.png" alt="Example 25" style="width: 100%;">
  <img src="examples/fofr_20250329_160157.png" alt="Example 26" style="width: 100%;">
  <img src="examples/fofr_20250329_160153.png" alt="Example 27" style="width: 100%;">
  <img src="examples/fofr_20250329_160147.png" alt="Example 28" style="width: 100%;">
  <img src="examples/fofr_20250329_160142.png" alt="Example 29" style="width: 100%;">
  <img src="examples/fofr_20250329_160137.png" alt="Example 30" style="width: 100%;">
  <img src="examples/fofr_20250329_160119.png" alt="Example 31" style="width: 100%;">
  <img src="examples/fofr_20250329_160006.png" alt="Example 32" style="width: 100%;">
  <img src="examples/fofr_20250329_155915.png" alt="Example 33" style="width: 100%;">
  <img src="examples/fofr_20250329_155910.png" alt="Example 34" style="width: 100%;">
  <img src="examples/fofr_20250329_155905.png" alt="Example 35" style="width: 100%;">
  <img src="examples/fofr_20250329_155850.png" alt="Example 36" style="width: 100%;">
  <img src="examples/fofr_20250329_155840.png" alt="Example 37" style="width: 100%;">
  <img src="examples/fofr_20250329_155835.png" alt="Example 38" style="width: 100%;">
  <img src="examples/fofr_20250329_155830.png" alt="Example 39" style="width: 100%;">
  <img src="examples/fofr_20250329_155826.png" alt="Example 40" style="width: 100%;">
</div>

## Features

- Real-time webcam capture
- Motion detection for automatic capture
- Multiple AI model support
  - [My Subconscious](https://replicate.com/fofr/flux-my-subconscious)
  
    <img src="images/mysubconscious.png" alt="My Subconscious Model Example" width="256"/>
  - [Nobel](https://replicate.com/fofr/flux-nobel-prize-2024-sketch)
  
    <img src="images/nobel24.png" alt="Nobel Model Example" width="256"/>
  - [Neo-Impressionism](https://replicate.com/fofr/flux-neo-impressionism)
  
    <img src="images/neo.png" alt="Neo-Impressionism Model Example" width="256"/>
  - [Condensation](https://replicate.com/fofr/flux-condensation)
  
    <img src="images/condensation.png" alt="Condensation Model Example" width="256"/>
  - [Weird](https://replicate.com/fofr/flux-weird)
  
    <img src="images/weird.png" alt="Weird Model Example" width="256"/>
  - [Spitting Image](https://replicate.com/fofr/flux-spitting-image)
  
    <img src="images/spitting.png" alt="Spitting Image Model Example" width="256"/>
  - [James Webb](https://replicate.com/fofr/flux-jwst)
  
    <img src="images/jwst.png" alt="James Webb Model Example" width="256"/>
  - [Cyberpunk](https://replicate.com/fofr/flux-80s-cyberpunk)
  
    <img src="images/cyberpunk.png" alt="Cyberpunk Model Example" width="256"/>
- Customizable prompts and parameters
- Fullscreen mode support
- Automatic image saving
- Interactive controls

## Setup

### Processing Sketch Setup

1. Clone this repository
2. Open `aMiRROR.pde` in Processing
3. Install required Processing libraries:
   - Video (for webcam support)

### Flask Server Setup

The sketch requires a Flask server to communicate with the Replicate API.

1. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```
2. Copy `.env.example` to `.env` and add your Replicate API token:
   ```
   cp .env.example .env
   ```
3. Edit `.env` and add your Replicate API token

## Running the Application

1. Start the Flask server:
   ```
   python app.py
   ```
   The server will run on http://localhost:5000 by default.

2. Run the Processing sketch in Processing IDE

## Controls

![HUD Interface](images/HUD.png)

- `SPACE`: Toggle between camera and AI view
- `S`: Force a new capture
- `P`: Cycle to next prompt
- `F`: Toggle image flipping
- `M`: Cycle through available models
- `R`: Toggle random prompt mode
- `C`: Switch capture mode (Timer/Motion)
- `D`: Toggle status display visibility
- `G`: Toggle fast mode
- `TAB`: Toggle settings panel
- `[`/`]`: Adjust motion threshold
- `1-9`: Set prompt strength (0.1-0.9)
- `+`/`-`: Fine-tune prompt strength
- `UP`/`DOWN`: Adjust inference steps
- `LEFT`/`RIGHT`: Adjust guidance scale
- `L`/`K`: Adjust lora scale

## Technical Details