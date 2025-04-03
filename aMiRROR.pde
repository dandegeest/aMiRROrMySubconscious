import processing.video.*;
import java.io.*;
import java.util.*;
import java.text.SimpleDateFormat;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Base64;
import java.io.ByteArrayOutputStream;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;


// Camera and display settings
Capture cam;
int displayWidth = 1280;
int displayHeight = 720;
boolean camInitialized = false;

// Image handling
PImage currentCamImage = null;
PImage currentAIImage = null;
PImage displayImage = null;
float transitionAlpha = 0;
boolean isTransitioning = false;

// Timing variables
int captureInterval = 5000; // 5 seconds
int lastCaptureTime = 0;
boolean requestInProgress = false;
int requestStartTime = 0;
int requestTimeout = 60000; // 1 minute timeout

// File management
String outputDir = "replicate.com";
SimpleDateFormat dateFormat = new SimpleDateFormat("yyyyMMdd_HHmmss");

// Server settings
String serverUrl = "http://localhost:5000";
String configUrl = "http://localhost:5000/config/defaults";

// HTTP Client
HttpClient httpClient;

// Model cycling
String[] availableModels;
int currentModelIndex = 0;

// Replicate model parameters
String currentPrompt = "mirror mmiror on the wall";  // Match server default
String modelVersion = "mysubconscious";  // Default model version
boolean goFast = true;  // Match server default
float loraScale = 1.0;  // Match server default
String megapixels = "1";  // Match server default
int numOutputs = 1;  // Match server default
String aspectRatio = "custom";  // Match server default
String outputFormat = "png";  // Match server default
float guidanceScale = 3;  // Match server default
int outputQuality = 80;  // Match server default
float promptStrength = 0.7;  // Match server default
int numInferenceSteps = 4;  // Match server default
boolean showSettings = false;

// List of prompts to cycle through
String[] prompts = {
  "the mirror remembers dreams you've forgotten",
  "reflections shaped by inner fears and hopes",
  "seeing the self through fractured memories",
  "a reflection painted by emotion, not light",
  "your shadow self emerging from the glass",
  "subconscious thoughts made visible in color",
  "the dreamer becomes the dream in reflection",
  "what the mirror sees when you're not looking",
  "echoes of past lives beneath the skin",
  "your hidden feelings wearing your face",
  "internal chaos spilling into external calm",
  "the mind's eye disguised as your own",
  "watching yourself dissolve into thought",
  "emotion bleeding through a still face",
  "the version of you no one else sees",
  "a reflection stitched from memories and myth",
  "eyes holding galaxies of forgotten dreams",
  "when the mirror dreams of being you",
  "a portrait shaped by intuition and longing",
  "you, reflected through the mind's storm"
};
int currentPromptIndex = 0;

// List of one-word prompts for auto-capture
String[] autoCapturePrompts = {
  "Reverie",
  "Fracture",
  "Mirage",
  "Doppelgänger",
  "Submerge",
  "Lucidity",
  "Ego",
  "Ripple",
  "Haunting",
  "Awakening",
  "Distortion",
  "Echo",
  "Glimpse",
  "Specter",
  "Drift",
  "Introspection",
  "Paradox",
  "Flicker",
  "Whisper",
  "Phantom",
  "Veil",
  "Uncanny",
  "Subconscious",
  "Vessel",
  "Rebirth",
  "Threshold",
  "Pulse",
  "Obscura",
  "Shadow",
  "Inversion",
  "Sentience",
  "Descent",
  "Mindscape",
  "Otherness",
  "Resonance",
  "Refraction",
  "Presence",
  "Trace",
  "Reflection",
  "Transcendence"
};

// Add this variable with the other boolean state variables (around line 43-44)
boolean showStatusDisplay = true;

// Add these variables at the beginning near other image variables
PImage blendedBuffer = null;
PImage processedImageBuffer = null;

// Add this with other boolean state variables
boolean randomPrompt = false;

// Flipping the captured image before generating can give interesting results
boolean flipImage = false;

// Add this near the top with other state variables
enum CaptureMode {
  CaptureTimer,
  CaptureMotion
}

// Add this with other state variables
CaptureMode currentCaptureMode = CaptureMode.CaptureMotion;

// Add these with other state variables
float motionThreshold = 0.02;  // Default threshold for motion detection (0-1)
PImage previousFrame = null;  // Store the previous frame for motion detection
boolean motionDetected = false;  // Flag to prevent multiple captures from same motion event

// Add this with other state variables
float currentMotion = 0;  // Store the current motion value

// Add this function before setup()
PImage flipImageVertically(PImage source) {
  source.loadPixels();
  PImage flipped = createImage(source.width, source.height, RGB);
  flipped.loadPixels();
  
  for (int y = 0; y < source.height; y++) {
    for (int x = 0; x < source.width; x++) {
      int srcIndex = x + y * source.width;
      int dstIndex = x + (source.height - 1 - y) * source.width;
      flipped.pixels[dstIndex] = source.pixels[srcIndex];
    }
  }
  flipped.updatePixels();
  return flipped;
}

// Add these helper functions before the main code
void drawCameraPreview(int x, int y) {
  if (currentCamImage != null) {
    // Calculate preview dimensions (1/8 of actual size)
    int previewWidth = currentCamImage.width / 8;
    int previewHeight = currentCamImage.height / 8;
    
    // Draw the camera preview
    image(currentCamImage, x, y, previewWidth, previewHeight);

    // Draw border around preview
    stroke(255, 0, 0);
    noFill();
    strokeWeight(2);
    rect(x-1, y-1, previewWidth+2, previewHeight+2, 5);
  }
}

void adjustMotionThreshold(float delta) {
  motionThreshold = constrain(motionThreshold + delta, 0, 1);
  println("Motion threshold: " + nf(motionThreshold, 0, 3));
}

void switchCaptureMode() {
  currentCaptureMode = currentCaptureMode == CaptureMode.CaptureTimer ? 
                      CaptureMode.CaptureMotion : 
                      CaptureMode.CaptureTimer;
  println("Switched to capture mode:", currentCaptureMode);
}

void setup() {
  // Set up the display in landscape mode
  size(1280, 720);
  frameRate(30);
  
  // Initialize output directory only
  File outputPath = new File(dataPath(outputDir));
  outputPath.mkdir();
  
  // Initialize camera
  initializeCamera();
  
  // Initialize HTTP client
  httpClient = HttpClient.newBuilder()
               .version(HttpClient.Version.HTTP_1_1)
               .connectTimeout(Duration.ofSeconds(30))
               .build();
               
  // Fetch available models
  fetchAvailableModels();
  
  // Fetch and apply server defaults
  fetchAndApplyDefaults();
  
  // Create a blank display image
  displayImage = createImage(displayWidth, displayHeight, RGB);
  displayImage.loadPixels();
  for (int i = 0; i < displayImage.pixels.length; i++) {
    displayImage.pixels[i] = color(0);
  }
  displayImage.updatePixels();
}

void draw() {
  background(0);
  
  // If camera is available, read the frame
  if (camInitialized && cam.available()) {
    cam.read();
    
    // Process the camera image
    PImage processedImage = processImage(cam);
    currentCamImage = processedImage;
    
    // Display camera image or AI image with transition
    updateDisplay();
    
    // Handle different capture modes
    switch (currentCaptureMode) {
      case CaptureTimer:
        drawCaptureTimer();
        break;
      case CaptureMotion:
        drawCaptureMotion();
        break;
    }
  }
  
  // Display the current image
  if (currentCamImage != null) {
    image(currentCamImage, 0, 0, width, height);
    tint(255, 225);
  }
  else noTint();
  
  if (displayImage != null) {
    image(displayImage, 0, 0, width, height);
  }
  
  // Draw capture indicator if generation is in progress
  if (requestInProgress) {
    pushStyle();
    noStroke();
    fill(255, 0, 0);  // Red color
    circle(width - 30, 30, 20);  // Draw circle in upper right corner
    popStyle();
  }
  
  // Display status information
  displayStatus();
}

void drawCaptureTimer() {
  // Check if it's time for a new capture
  if (!requestInProgress && millis() - lastCaptureTime > captureInterval) {
    captureAndProcess();
  }
  
  // Check for timeout on requests
  if (requestInProgress && millis() - requestStartTime > requestTimeout) {
    println("Request timed out, resetting");
    requestInProgress = false;
  }
}

void drawCaptureMotion() {
  if (currentCamImage == null) {
    previousFrame = null;
    currentMotion = 0;
    return;
  }
  
  // Initialize previous frame if needed
  if (previousFrame == null) {
    previousFrame = createImage(currentCamImage.width, currentCamImage.height, RGB);
    previousFrame.copy(currentCamImage, 0, 0, currentCamImage.width, currentCamImage.height, 0, 0, currentCamImage.width, currentCamImage.height);
    currentMotion = 0;
    return;
  }
  
  // Calculate motion between frames
  currentMotion = calculateMotion(previousFrame, currentCamImage);
  
  // Check if motion exceeds threshold and we're not already processing
  if (currentMotion > motionThreshold && !requestInProgress && !motionDetected) {
    println("Motion detected: " + nf(currentMotion, 0, 3));
    captureAndProcess(modelVersion, currentPrompt, promptStrength);
    motionDetected = true;
  } else if (currentMotion <= motionThreshold && !requestInProgress) {
    motionDetected = false;
  }
  
  // Check for timeout (30 seconds) and auto-capture if needed
  if (!requestInProgress && millis() - lastCaptureTime > 30000) {
    println("No motion detected for 30 seconds, auto-capturing...");
    // Select a random two-word prompt
    String randomPrompt = autoCapturePrompts[int(random(autoCapturePrompts.length))];
    println("Using auto-capture prompt: " + randomPrompt);
    captureAndProcess("condensation", randomPrompt, 0.9);
  }
  
  // Update previous frame
  previousFrame.copy(currentCamImage, 0, 0, currentCamImage.width, currentCamImage.height, 0, 0, currentCamImage.width, currentCamImage.height);
}

float calculateMotion(PImage prev, PImage curr) {
  float totalDiff = 0;
  int pixelCount = 0;
  
  prev.loadPixels();
  curr.loadPixels();
  
  // Compare each pixel between frames
  for (int i = 0; i < prev.pixels.length; i++) {
    color prevColor = prev.pixels[i];
    color currColor = curr.pixels[i];
    
    // Calculate difference in brightness
    float prevBrightness = brightness(prevColor);
    float currBrightness = brightness(currColor);
    
    totalDiff += abs(prevBrightness - currBrightness);
    pixelCount++;
  }
  
  // Return average difference normalized to 0-1 range
  return totalDiff / (pixelCount * 255);
}

void initializeCamera() {
  String[] cameras = Capture.list();
  
  if (cameras == null || cameras.length == 0) {
    println("No cameras available");
    return;
  }
  
  // Print available cameras
  println("Available cameras:");
  for (int i = 0; i < cameras.length; i++) {
    println(i + ": " + cameras[i]);
  }
  
  // First try to find the NexiGo N960E camera specifically
  for (int i = 0; i < cameras.length; i++) {
    if (cameras[i].contains("NexiGo N960E")) {
      println("Selected NexiGo camera: " + cameras[i]);
      cam = new Capture(this, cameras[i]);
      camInitialized = true;
      cam.start();
      return;
    }
  }
  
  // If NexiGo not found, try to use any camera with 720p if available
  for (int i = 0; i < cameras.length; i++) {
    if (cameras[i].contains("720")) {
      println("Selected 720p camera: " + cameras[i]);
      cam = new Capture(this, cameras[i]);
      camInitialized = true;
      cam.start();
      return;
    }
  }
  
  // If no 720p camera, use the first available camera
  if (!camInitialized && cameras.length > 0) {
    println("Selected default camera: " + cameras[0]);
    cam = new Capture(this, cameras[0]);
    camInitialized = true;
    cam.start();
  }
}

PImage processImage(Capture camImage) {
  // If camera image is already the correct size, return it directly
  if (camImage.width == displayWidth && camImage.height == displayHeight) {
    return camImage;
  }
  
  // Create an image with the target display dimensions only once
  if (processedImageBuffer == null) {
    processedImageBuffer = createImage(displayWidth, displayHeight, RGB);
  }
  
  // Calculate scaling to maintain aspect ratio and center crop
  float aspectRatio1 = (float)displayWidth / (float)displayHeight;
  float aspectRatio2 = (float)cam.width / (float)cam.height;
  
  float scaleFactor;
  int sourceX, sourceY, sourceWidth, sourceHeight;
  
  if (aspectRatio1 > aspectRatio2) {
    // Target is wider than source - scale to match width and crop height
    scaleFactor = (float)displayWidth / (float)cam.width;
    sourceX = 0;
    sourceWidth = cam.width;
    sourceHeight = (int)(displayHeight / scaleFactor);
    sourceY = (cam.height - sourceHeight) / 2; // Center vertically
  } else {
    // Target is taller than source - scale to match height and crop width
    scaleFactor = (float)displayHeight / (float)cam.height;
    sourceY = 0;
    sourceHeight = cam.height;
    sourceWidth = (int)(displayWidth / scaleFactor);
    sourceX = (cam.width - sourceWidth) / 2; // Center horizontally
  }
  
  // Resize and crop the camera image to fit the display
  processedImageBuffer.copy(camImage, sourceX, sourceY, sourceWidth, sourceHeight, 
               0, 0, displayWidth, displayHeight);
  
  return processedImageBuffer;
}

void updateDisplay() {
  // Handle transition between camera and AI images
  if (currentAIImage != null) {
    try {
      // Create a local reference to avoid race conditions
      PImage aiImageRef = currentAIImage;
      
      // We have an AI image, blend with camera
      // Create blendedBuffer only once and reuse it
      if (blendedBuffer == null) {
        blendedBuffer = createImage(displayWidth, displayHeight, RGB);
      }
      
      // If transitioning, update alpha
      if (isTransitioning) {
        transitionAlpha += 0.067; // Speed of transition (1/15 for 0.5s at 30fps)
        if (transitionAlpha >= 1) {
          transitionAlpha = 1;
          isTransitioning = false;
        }
      }
      
      // Additional null check for currentCamImage
      if (currentCamImage == null) return;
      
      // Make sure both images have pixels loaded
      currentCamImage.loadPixels();
      aiImageRef.loadPixels();
      blendedBuffer.loadPixels();
      
      // Blend the images with safer access
      for (int i = 0; i < blendedBuffer.pixels.length; i++) {
        // Add bounds check to avoid index issues
        if (i < currentCamImage.pixels.length && i < aiImageRef.pixels.length) {
          color camColor = currentCamImage.pixels[i];
          color aiColor = aiImageRef.pixels[i];
          blendedBuffer.pixels[i] = lerpColor(camColor, aiColor, transitionAlpha);
        }
      }
      blendedBuffer.updatePixels();
      
      // Simply point to our buffer instead of creating a new image
      displayImage = blendedBuffer;
    } catch (Exception e) {
      // Log the error and gracefully handle it
      println("Error in updateDisplay: " + e.getMessage());
      // Fall back to showing just the camera image
      displayImage = currentCamImage;
    }
  } else {
    // If no AI image yet, just show camera
    displayImage = currentCamImage;
  }
}

void captureAndProcess() {
  // Call the new version with current settings
  captureAndProcess(modelVersion, currentPrompt, promptStrength);
}

void captureAndProcess(String modelVersion, String prompt, float promptStrength) {
  if (currentCamImage == null) return;
  
  // Request garbage collection before starting a new capture cycle
  System.gc();
  
  lastCaptureTime = millis();
  requestInProgress = true;
  requestStartTime = millis();
  
  // Generate timestamp for output file only
  String timestamp = getCurrentTimestamp();
  String outputFilename = outputDir + "/fofr_" + modelVersion + "_" + timestamp + ".png";
  
  // Flip the image vertically if enabled
  PImage imageToProcess = flipImage ? flipImageVertically(currentCamImage) : currentCamImage;
  
  // Create the JSON payload for the request
  JSONObject json = new JSONObject();
  json.setString("model_version", modelVersion);
  
  // Set the prompt based on random toggle
  String promptToUse = randomPrompt ? prompts[int(random(prompts.length))] : prompt;
  json.setString("prompt", promptToUse);
  
  // Send prompt strength as a float
  json.setFloat("prompt_strength", promptStrength);
  
  // Continue with the rest of the parameters
  json.setString("lora", "fofr_loras");
  json.setInt("width", displayWidth);
  json.setInt("height", displayHeight);
  json.setString("image", encodeImageToBase64(imageToProcess));
  json.setBoolean("go_fast", goFast);
  json.setFloat("lora_scale", loraScale);
  json.setFloat("extra_lora_scale", 1.0);  // Always set to 1
  json.setString("megapixels", megapixels);
  json.setInt("num_outputs", numOutputs);
  json.setString("aspect_ratio", aspectRatio);
  json.setString("output_format", outputFormat);
  json.setFloat("guidance_scale", guidanceScale);
  json.setInt("output_quality", outputQuality);
  json.setInt("num_inference_steps", numInferenceSteps);
  
  // Send to the Flask server in a separate thread to avoid blocking
  Thread t = new Thread(new Runnable() {
    public void run() {
      sendToFlaskServer(json.toString(), outputFilename);
    }
  });
  t.setDaemon(true); // Make thread a daemon so it won't prevent app from exiting
  t.start();
}

String encodeImageToBase64(PImage img) {
  img.loadPixels(); // ensure pixels are updated

  // Convert to BufferedImage
  BufferedImage bimg = new BufferedImage(img.width, img.height, BufferedImage.TYPE_INT_RGB);
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      bimg.setRGB(x, y, img.pixels[y * img.width + x]);
    }
  }

  // Encode to PNG bytes
  try {
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ImageIO.write(bimg, "png", baos);
    byte[] imageBytes = baos.toByteArray();

    // Convert to Base64 string with data URI prefix
    return "data:image/png;base64," + Base64.getEncoder().encodeToString(imageBytes);
  } catch (Exception e) {
    println("Error encoding image: " + e.getMessage());
    return null;
  }
}

void sendToFlaskServer(String jsonPayload, String outputFilename) {
  try {
    // Parse the JSON to get just the prompt and prompt strength for logging
    JSONObject json = parseJSONObject(jsonPayload);
    String prompt = json.getString("prompt");
    float pStrength = json.getFloat("prompt_strength");
    String model = json.getString("model_version");
    
    // Create a copy of the JSON for logging without the image data
    JSONObject logJson = new JSONObject();
    logJson.setString("model_version", model);
    logJson.setString("prompt", prompt);
    logJson.setFloat("prompt_strength", pStrength);
    logJson.setBoolean("go_fast", json.getBoolean("go_fast"));
    logJson.setFloat("lora_scale", json.getFloat("lora_scale"));
    logJson.setInt("num_inference_steps", json.getInt("num_inference_steps"));
    
    // Print just the relevant parameters
    println("Sending request: " + logJson.toString());
    
    // Build the request
    HttpRequest request = HttpRequest.newBuilder()
      .uri(URI.create(serverUrl + "/generate"))
      .header("Content-Type", "application/json")
      .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
      .build();
    
    // Send request
    HttpResponse<String> response = httpClient.send(
      request, HttpResponse.BodyHandlers.ofString());
    
    // Process the response
    int statusCode = response.statusCode();
    if (statusCode == 200) {
      JSONObject jsonResponse = parseJSONObject(response.body());
      if (jsonResponse != null && jsonResponse.getBoolean("success")) {
        String outputUrl = jsonResponse.getString("output_url");
        
        // Download the image using the passed filename
        downloadImage(outputUrl, outputFilename);
        lastCaptureTime = millis(); // Make sure the image displays for 5 seconds if request took longer
      } else {
        println("Error in response: " + response.body());
      }
    } else {
      println("HTTP error: " + statusCode);
    }
  } 
  catch (Exception e) {
    println("Error sending to server: " + e.getMessage());
    e.printStackTrace();
  }
  
  // Request is complete
  requestInProgress = false;
}

void downloadImage(String url, String outputFilename) {
  try {
    // Create HTTP request for the image
    HttpRequest request = HttpRequest.newBuilder()
      .uri(URI.create(url))
      .GET()
      .build();
    
    // Make sure the output directory exists
    File outputDir = new File(dataPath(this.outputDir));
    if (!outputDir.exists()) {
      outputDir.mkdirs();
    }
    
    // Get full path and ensure it's valid
    Path outputPath = Paths.get(dataPath(outputFilename));
    
    try {
      // Get the image as bytes using the HTTP client
      HttpResponse<byte[]> response = httpClient.send(
        request, HttpResponse.BodyHandlers.ofByteArray());
      
      // Check response
      if (response.statusCode() == 200) {
        // Save the bytes directly to a file using Files API
        Files.write(outputPath, response.body());
        
        // Load the new AI image first, before clearing the old one
        PImage newAIImage = loadImage(outputPath.toString());
        
        if (newAIImage != null) {
          // Flip the image back to original orientation if enabled
          PImage finalImage = flipImage ? flipImageVertically(newAIImage) : newAIImage;
          
          // Only after successfully loading the new image, update references
          synchronized(this) {
            // Clear old reference first
            currentAIImage = null;
            System.gc(); // Request garbage collection
            
            // Now set the new image
            currentAIImage = finalImage;
            isTransitioning = true;
            transitionAlpha = 0;
          }
        } else {
          println("Error: Failed to load saved image as PImage");
        }
      } else {
        println("HTTP error: " + response.statusCode());
      }
    } catch (IOException e) {
      println("I/O error saving image file: " + e.getMessage());
      e.printStackTrace();
    } catch (InterruptedException e) {
      println("Request interrupted: " + e.getMessage());
      e.printStackTrace();
    }
  } catch (Exception e) {
    println("Error downloading image: " + e.getClass().getName() + " - " + e.getMessage());
    e.printStackTrace();
  }
}

void displayStatus() {
  // Only display status if showStatusDisplay is true
  if (!showStatusDisplay) return;
  
  // Display status information as an overlay
  fill(0, 150);
  noStroke();
  
  if (showSettings) {
    // Show expanded settings panel in the upper left
    rect(10, 10, 300, 550);
    
    fill(255);
    textSize(16);
    text("aMiRROR - AI Subconscious Mirror", 20, 40);
    textSize(14);
    
    // Main settings
    text("Prompt: " + (randomPrompt ? "RANDOM" : currentPrompt), 20, 70);
    text("Model: " + modelVersion + " (M to cycle)", 20, 90);
    text("Random Prompt: " + (randomPrompt ? "ON" : "OFF") + " (R to toggle)", 20, 110);
    text("Capture Mode: " + currentCaptureMode + " (C to cycle)", 20, 130);
    text("Flip Image: " + (flipImage ? "ON" : "OFF") + " (F to toggle)", 20, 150);
    
    // Camera settings
    text("Camera: " + cam.width + "x" + cam.height + " → " + displayWidth + "x" + displayHeight, 20, 170);
    
    // Generation settings
    text("Steps: " + numInferenceSteps + " (↑/↓ to change)", 20, 190);
    text("Guidance Scale: " + nf(guidanceScale, 0, 2) + " (←/→ to change)", 20, 210);
    text("Prompt Strength: " + nf(promptStrength, 0, 2) + " (+/- to change)", 20, 230);
    text("Fast Mode: " + (goFast ? "ON" : "OFF") + " (G to toggle)", 20, 250);
    text("Lora Scale: " + nf(loraScale, 0, 1) + " (L/K to change)", 20, 270);
    
    // Advanced settings
    text("Megapixels: " + megapixels, 20, 290);
    text("Quality: " + outputQuality, 20, 310);
    
    // Status and motion settings
    if (currentCaptureMode == CaptureMode.CaptureMotion) {
      text("Motion Threshold: " + nf(motionThreshold, 0, 3) + " ([/] to change)", 20, 330);
      text("Current Motion: " + nf(currentMotion, 0, 3), 20, 350);
      text("Framerate: " + nf(frameRate, 0, 1) + " fps", 20, 370);
      if (requestInProgress) {
        text("Generating... " + ((millis() - requestStartTime) / 1000) + "s", 20, 390);
      } else {
        text("MOTION", 20, 390);
      }
      text("Press TAB to hide settings", 20, 410);
    } else {
      text("Framerate: " + nf(frameRate, 0, 1) + " fps", 20, 330);
      if (requestInProgress) {
        text("Generating... " + ((millis() - requestStartTime) / 1000) + "s", 20, 350);
      } else {
        text("Next capture in " + ((captureInterval - (millis() - lastCaptureTime)) / 1000) + "s", 20, 350);
      }
      text("Press TAB to hide settings", 20, 370);
    }
    
    // Show camera preview at 1/8 scale
     if (currentCamImage != null ) {
      int previewX = (300 - currentCamImage.width/8) / 2 + 10;
      int previewY = 430;
      drawCameraPreview(previewX, previewY);
    }
 } else {
    // Show minimal info in the upper left
    rect(10, 10, 300, 300);
    
    fill(255);
    textSize(14);
    text("aMiRROR - AI Subconscious Mirror", 20, 30);
    
    // Show prompt and prompt strength
    text("Prompt: " + (randomPrompt ? "RANDOM" : currentPrompt), 20, 50);
    text("Strength: " + nf(promptStrength, 0, 2), 20, 70);
    text("Model: " + modelVersion, 20, 90);
    text("Mode: " + currentCaptureMode, 20, 110);
    text("Random: " + (randomPrompt ? "ON" : "OFF"), 20, 130);
    text("Flip: " + (flipImage ? "ON" : "OFF"), 20, 150);
    
    // Add motion threshold to minimal display when in motion mode
    if (currentCaptureMode == CaptureMode.CaptureMotion) {
      text("Motion: " + nf(motionThreshold, 0, 2), 20, 170);
    }
    
    if (requestInProgress) {
      text("Generating... " + ((millis() - requestStartTime) / 1000) + "s", 20, 190);
    } else {
      text(currentCaptureMode == CaptureMode.CaptureMotion ? "MOTION" : "Next capture in " + ((captureInterval - (millis() - lastCaptureTime)) / 1000) + "s", 20, 190);
    }
    
    // Show camera preview at 1/8 scale in minimal mode
    if (currentCamImage != null ) {
      int previewX = (300 - currentCamImage.width/8) / 2 + 10;
      int previewY = 200;
      drawCameraPreview(previewX, previewY);
    }
  }
}

void keyPressed() {
  // Convert key to uppercase for simpler checks
  char ciKeyPressed = Character.toUpperCase(key);
  
  // Handle special keys first
  if (key == CODED) {
    switch (keyCode) {
      case UP:
        numInferenceSteps = constrain(numInferenceSteps + 1, 1, 50);
        break;
      case DOWN:
        numInferenceSteps = constrain(numInferenceSteps - 1, 1, 50);
        break;
      case LEFT:
        guidanceScale = constrain(guidanceScale - 0.01, 0, 10);
        break;
      case RIGHT:
        guidanceScale = constrain(guidanceScale + 0.01, 0, 10);
        break;
    }
    return;
  }
  
  // Handle regular keys with switch statement
  switch (ciKeyPressed) {
    case 'S':
      // Force a new capture
      captureAndProcess(modelVersion, currentPrompt, promptStrength);
      break;
      
    case 'P':
      // Cycle to next prompt
      currentPromptIndex = (currentPromptIndex + 1) % prompts.length;
      currentPrompt = prompts[currentPromptIndex];
      break;
      
    case ' ':
      // Toggle between camera and AI view
      transitionAlpha = (transitionAlpha > 0.5) ? 0 : 1;
      break;
      
    case 'D':
      // Toggle status display visibility
      showStatusDisplay = !showStatusDisplay;
      break;
      
    case 'F':
      // Toggle image flipping
      flipImage = !flipImage;
      println("Image flipping: " + (flipImage ? "ON" : "OFF"));
      break;
      
    case 'G':
      // Toggle fast mode
      goFast = !goFast;
      break;
      
    case 'M':
      // Cycle through available models
      if (availableModels != null && availableModels.length > 0) {
        currentModelIndex = (currentModelIndex + 1) % availableModels.length;
        modelVersion = availableModels[currentModelIndex];
        println("Switched to model:", modelVersion);
      }
      break;
      
    case 'R':
      // Toggle random prompt mode
      randomPrompt = !randomPrompt;
      break;
      
    case 'C':
      switchCaptureMode();
      break;
      
    case 'L':
      // Increase lora scale
      loraScale = constrain(loraScale + 0.1, -1, 3);
      println("Lora scale: " + nf(loraScale, 0, 1));
      break;
      
    case 'K':
      // Decrease lora scale
      loraScale = constrain(loraScale - 0.1, -1, 3);
      println("Lora scale: " + nf(loraScale, 0, 1));
      break;
      
    case '+':
    case '=':
      promptStrength = constrain(promptStrength + 0.01, 0, 1);
      break;
      
    case '-':
    case '_':
      promptStrength = constrain(promptStrength - 0.01, 0, 1);
      break;
      
    case '[':
    case '{':
      adjustMotionThreshold(-0.01);
      break;
      
    case ']':
    case '}':
      adjustMotionThreshold(0.01);
      break;
      
    case '\t':  // TAB key
      showSettings = !showSettings;
      break;
      
    default:
      // Handle number keys 1-9 for prompt strength
      if (ciKeyPressed >= '1' && ciKeyPressed <= '9') {
        promptStrength = (ciKeyPressed - '0') / 10.0;
        println("Set prompt strength to:", nf(promptStrength, 0, 1));
      }
      break;
  }
}

void fetchAndApplyDefaults() {
  try {
    // Create HTTP request for defaults
    HttpRequest request = HttpRequest.newBuilder()
      .uri(URI.create(configUrl))
      .GET()
      .build();
    
    // Send request and get response
    HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    
    if (response.statusCode() == 200) {
      // Parse JSON response
      JSONObject json = parseJSONObject(response.body());
      
      // Update all model parameters from defaults
      modelVersion = json.getString("model_version", modelVersion);  // Get model version from server
      goFast = json.getBoolean("go_fast", goFast);
      loraScale = json.getFloat("lora_scale", loraScale);
      megapixels = json.getString("megapixels", megapixels);
      numOutputs = json.getInt("num_outputs", numOutputs);
      aspectRatio = json.getString("aspect_ratio", aspectRatio);
      outputFormat = json.getString("output_format", outputFormat);
      guidanceScale = json.getFloat("guidance_scale", guidanceScale);
      outputQuality = json.getInt("output_quality", outputQuality);
      promptStrength = json.getFloat("prompt_strength", promptStrength);
      numInferenceSteps = json.getInt("num_inference_steps", numInferenceSteps);
      
      println("Successfully synced parameters with server defaults");
    } else {
      println("Error fetching defaults: " + response.statusCode());
    }
  } catch (Exception e) {
    println("Error fetching defaults: " + e.getMessage());
  }
}

// Add this method to explicitly clean up resources when the app is closed
void exit() {
  try {
    // Close the camera if it's running and initialized
    if (cam != null && camInitialized) {
      cam.stop();
    }
    
    // Release image resources with null checks
    if (currentCamImage != null) {
      currentCamImage = null;
    }
    if (currentAIImage != null) {
      currentAIImage = null;
    }
    if (displayImage != null) {
      displayImage = null;
    }
    if (blendedBuffer != null) {
      blendedBuffer = null;
    }
    if (processedImageBuffer != null) {
      processedImageBuffer = null;
    }
    if (previousFrame != null) {
      previousFrame = null;
    }
    
    // Request garbage collection
    System.gc();
  } catch (Exception e) {
    println("Error during cleanup: " + e.getMessage());
    e.printStackTrace();
  }
  
  // Call the super method to finish exiting
  super.exit();
}

// Helper method to get a formatted timestamp string
String getCurrentTimestamp() {
  return dateFormat.format(new Date());
}

void fetchAvailableModels() {
  try {
    // Create HTTP request for models
    HttpRequest request = HttpRequest.newBuilder()
      .uri(URI.create(serverUrl + "/models"))
      .GET()
      .build();
    
    // Send request and get response
    HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    
    if (response.statusCode() == 200) {
      // Parse JSON response
      JSONArray models = parseJSONArray(response.body());
      availableModels = new String[models.size()];
      for (int i = 0; i < models.size(); i++) {
        availableModels[i] = models.getString(i);
      }
      println("Available models:", join(availableModels, ", "));
    } else {
      println("Error fetching models:", response.statusCode());
      // Fallback to default model if server request fails
      availableModels = new String[]{"mysubconscious"};
    }
  } catch (Exception e) {
    println("Error fetching models:", e.getMessage());
    // Fallback to default model if server request fails
    availableModels = new String[]{"mysubconscious"};
  }
}