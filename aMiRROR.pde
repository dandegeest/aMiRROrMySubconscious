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

boolean showStatusDisplay = false;
PImage blendedBuffer = null;
PImage processedImageBuffer = null;

// Flipping the captured image before generating can give interesting results
boolean flipImage = false;

enum CaptureMode {
  CaptureTimer,
  CaptureMotion
}

// Add this with other state variables
enum CaptureType {
  Timed,
  Motion,
  Auto
}

// Add this with other state variables
CaptureType lastCaptureType = CaptureType.Timed;  // Track the type of the most recent capture

// Add this with other state variables
CaptureMode currentCaptureMode = CaptureMode.CaptureMotion;

float motionThreshold = 0.03;  // Adjusted for 4x4 pixel sampling (was 0.02)
PImage previousFrame = null;  // Store the previous frame for motion detection
boolean motionDetected = false;  // Flag to prevent multiple captures from same motion event

float currentMotion = 0;  // Store the current motion value
float lastFrameTime = 0;
float targetFrameTime = 1000.0f / 30.0f; // 30 FPS target
float cachedAspectRatio1 = 0;
float cachedAspectRatio2 = 0;

boolean galleryMode = true;  // Gallery mode is on by default
float[] guidanceScaleValues = {1.0, 1.5, 2.0, 2.5, 3.0, 3.5};
int autoCaptureTimeout = 30000;  // 30 seconds default

float pulsePhase = 0;
float pulseSpeed = 0.1;  // Speed of the pulse animation

//Scanline FX
int scanH = 5;
int scanY = scanH / 2;

//Glitch FX
int glitchCnt = 0;

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
  // Set up the display in landscape mode, the camera will be flipped to take portrait image
  size(1280, 720);
  //fullScreen(P2D, 2);
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
    if (processedImage != null) {  // Only update if we got a valid frame
      currentCamImage = processedImage;
    }
    
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
  //if (currentCamImage != null && !isTransitioning) {
  //  image(currentCamImage, 0, 0, width, height);
  //  tint(255, 225);
  //}
  //else noTint();
  
  if (displayImage != null) {
    image(displayImage, 0, 0, width, height);
  }
  
  //drawScanner();
  if (frameCount % 30 == 0) glitchCnt = (int)random(0, 15);
  glitch();
  displayStatus();  
  drawIndicator();
}

void glitch() {
  if (currentCamImage == null || currentAIImage == null || glitchCnt == 0)
    return;
  
  glitchCnt--;
  tint(250, 180);
  image(currentCamImage, 5, 5);
  noTint();
}

void drawScanner() {
  if (displayImage == null)
    return;
    
  blend(displayImage,
    0, 0, displayImage.width, scanH * 2,
    0, scanY - scanH, displayImage.width, scanH * 2, DODGE );
 
  if (frameCount % 15 == 0)
    scanY += scanH;
  if (scanY > displayImage.height) scanY = scanH;
}

void drawIndicator() {
  if (requestInProgress) {
    pushStyle();
    noStroke();
    
    // Draw multiple concentric circles with varying opacities
    float baseOpacity = 255 * (0.5 + 0.5 * sin(pulsePhase));
    float centerX = 50;
    float centerY = 50;
    
    // Outer circle (largest)
    fill(255, 0, 0, baseOpacity * 0.3);
    circle(centerX, centerY, 60);
    
    // Middle circle
    fill(255, 0, 0, baseOpacity * 0.6);
    circle(centerX, centerY, 40);
    
    // Inner circle (smallest)
    fill(255, 0, 0, baseOpacity);
    circle(centerX, centerY, 20);
    
    popStyle();
    
    // Update pulse phase
    pulsePhase += pulseSpeed;
  }
}

void generateRandomSettings(String[] settings) {
  settings[0] = availableModels[int(random(availableModels.length))];  // model
  settings[1] = prompts[int(random(prompts.length))];  // prompt
  settings[2] = str(constrain(promptStrength + random(-0.05, 0.05), 0, 1));  // strength
  settings[3] = str(random(1) > 0.5);  // flip
  settings[4] = str(guidanceScaleValues[int(random(guidanceScaleValues.length))]);  // guidance
}

// Add this function before the drawCaptureTimer function
void handleGalleryCapture() {
  String[] randomSettings = new String[5];
  generateRandomSettings(randomSettings);
  captureAndProcess(randomSettings[0], randomSettings[1], float(randomSettings[2]), boolean(randomSettings[3]), float(randomSettings[4]));
}

void drawCaptureTimer() {
  // Check if it's time for a new capture
  if (!requestInProgress && millis() - lastCaptureTime > captureInterval) {
    if (galleryMode) {
      lastCaptureType = CaptureType.Timed;
      handleGalleryCapture();
    } else {
      lastCaptureType = CaptureType.Timed;
      captureAndProcess(modelVersion, currentPrompt, promptStrength, flipImage, guidanceScale);
    }
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
    
    currentAIImage = null;  
    
    // If the last capture was an auto-capture, clear the display image
    if (lastCaptureType == CaptureType.Auto) {
      displayImage = null;
      isTransitioning = false;
      transitionAlpha = 0;
    }
    
    if (galleryMode) {
      lastCaptureType = CaptureType.Motion;
      handleGalleryCapture();
    } else {
      lastCaptureType = CaptureType.Motion;
      captureAndProcess(modelVersion, currentPrompt, promptStrength, flipImage, guidanceScale);
    }
    motionDetected = true;
  } else if (currentMotion <= motionThreshold && !requestInProgress) {
    motionDetected = false;
  }
  
  // Check for timeout and auto-capture if needed
  if (!requestInProgress && millis() - lastCaptureTime > autoCaptureTimeout) {
    println("No motion detected for " + (autoCaptureTimeout/1000) + " seconds, auto-capturing...");
    // Always use auto-capture settings regardless of gallery mode
    String randomPrompt = autoCapturePrompts[int(random(autoCapturePrompts.length))];
    String formattedPrompt = "The word \"" + randomPrompt + "\" on a steamed over mirror";
    float randomStrength = random(0.8, 0.95);
    println("Using auto-capture prompt: " + formattedPrompt + " with strength: " + nf(randomStrength, 0, 2));
    lastCaptureType = CaptureType.Auto;
    captureAndProcess("condensation", formattedPrompt, randomStrength, flipImage, guidanceScale);
  }
  
  // Update previous frame
  previousFrame.copy(currentCamImage, 0, 0, currentCamImage.width, currentCamImage.height, 0, 0, currentCamImage.width, currentCamImage.height);
}

float calculateMotion(PImage prev, PImage curr) {
  if (prev == null || curr == null) return 0;
  
  // Sample every 4th pixel for faster motion detection
  int sampleSize = 4;
  float totalDiff = 0;
  int pixelCount = 0;
  
  prev.loadPixels();
  curr.loadPixels();
  
  for (int y = 0; y < prev.height; y += sampleSize) {
    for (int x = 0; x < prev.width; x += sampleSize) {
      int i = y * prev.width + x;
      if (i < prev.pixels.length && i < curr.pixels.length) {
        color prevColor = prev.pixels[i];
        color currColor = curr.pixels[i];
        
        // Use a faster brightness calculation
        float prevBrightness = (red(prevColor) + green(prevColor) + blue(prevColor)) / 3.0f;
        float currBrightness = (red(currColor) + green(currColor) + blue(currColor)) / 3.0f;
        
        totalDiff += abs(prevBrightness - currBrightness);
        pixelCount++;
      }
    }
  }
  
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
      cam = new Capture(this, 1280, 720, cameras[i]);
      camInitialized = true;
      cam.start();
      return;
    }
  }
  
  // If NexiGo not found, try to use any camera with 720p if available
  for (int i = 0; i < cameras.length; i++) {
    if (cameras[i].contains("720")) {
      println("Selected 720p camera: " + cameras[i]);
      cam = new Capture(this, 1280, 720, cameras[i]);
      camInitialized = true;
      cam.start();
      return;
    }
  }
  
  // If no 720p camera, use the first available camera
  if (!camInitialized && cameras.length > 0) {
    println("Selected default camera: " + cameras[0]);
    cam = new Capture(this, 1280, 720, cameras[0]);
    camInitialized = true;
    cam.start();
  }
}

PImage processImage(Capture camImage) {
  // Skip frame if we're falling behind
  float currentTime = millis();
  if (currentTime - lastFrameTime < targetFrameTime) {
    return null;  // Skip this frame
  }
  lastFrameTime = currentTime;
  
  // If camera image is already the correct size, return it directly
  if (camImage.width == displayWidth && camImage.height == displayHeight) {
    return camImage;
  }
  
  // Create an image with the target display dimensions only once
  if (processedImageBuffer == null) {
    processedImageBuffer = createImage(displayWidth, displayHeight, RGB);
  }
  
  // Cache aspect ratio calculations
  if (cachedAspectRatio1 == 0) {
    cachedAspectRatio1 = (float)displayWidth / (float)displayHeight;
  }
  if (cachedAspectRatio2 == 0) {
    cachedAspectRatio2 = (float)cam.width / (float)cam.height;
  }
  
  float scaleFactor;
  int sourceX, sourceY, sourceWidth, sourceHeight;
  
  if (cachedAspectRatio1 > cachedAspectRatio2) {
    scaleFactor = (float)displayWidth / (float)cam.width;
    sourceX = 0;
    sourceWidth = cam.width;
    sourceHeight = (int)(displayHeight / scaleFactor);
    sourceY = (cam.height - sourceHeight) / 2;
  } else {
    scaleFactor = (float)displayHeight / (float)cam.height;
    sourceY = 0;
    sourceHeight = cam.height;
    sourceWidth = (int)(displayWidth / scaleFactor);
    sourceX = (cam.width - sourceWidth) / 2;
  }
  
  // Use direct pixel array access for better performance
  camImage.loadPixels();
  processedImageBuffer.loadPixels();
  
  for (int y = 0; y < displayHeight; y++) {
    for (int x = 0; x < displayWidth; x++) {
      int srcX = sourceX + (int)(x / scaleFactor);
      int srcY = sourceY + (int)(y / scaleFactor);
      if (srcX >= 0 && srcX < cam.width && srcY >= 0 && srcY < cam.height) {
        processedImageBuffer.pixels[y * displayWidth + x] = camImage.pixels[srcY * cam.width + srcX];
      }
    }
  }
  
  processedImageBuffer.updatePixels();
  return processedImageBuffer;
}

void updateDisplay() {
  if (currentAIImage == null) {
    displayImage = currentCamImage;
    return;
  }
  
  try {
    PImage aiImageRef = currentAIImage;
    
    if (blendedBuffer == null) {
      blendedBuffer = createImage(displayWidth, displayHeight, RGB);
    }
    
    if (isTransitioning) {
      transitionAlpha += 0.067;
      if (transitionAlpha >= 1) {
        transitionAlpha = 1;
        isTransitioning = false;
      }
    }
    
    if (currentCamImage == null) return;
    
    // Use direct pixel array access for better performance
    currentCamImage.loadPixels();
    aiImageRef.loadPixels();
    blendedBuffer.loadPixels();
    
    for (int i = 0; i < blendedBuffer.pixels.length; i++) {
      if (i < currentCamImage.pixels.length && i < aiImageRef.pixels.length) {
        color camColor = currentCamImage.pixels[i];
        color aiColor = aiImageRef.pixels[i];
        
        // Fast color blending without lerpColor
        float r1 = red(camColor);
        float g1 = green(camColor);
        float b1 = blue(camColor);
        float r2 = red(aiColor);
        float g2 = green(aiColor);
        float b2 = blue(aiColor);
        
        blendedBuffer.pixels[i] = color(
          r1 + (r2 - r1) * transitionAlpha,
          g1 + (g2 - g1) * transitionAlpha,
          b1 + (b2 - b1) * transitionAlpha
        );
      }
    }
    
    blendedBuffer.updatePixels();
    displayImage = blendedBuffer;
  } catch (Exception e) {
    println("Error in updateDisplay: " + e.getMessage());
    displayImage = currentCamImage;
  }
}

void captureAndProcess() {
  // Call the new version with current settings
  captureAndProcess(modelVersion, currentPrompt, promptStrength, flipImage, guidanceScale);
}

void captureAndProcess(String modelVersion, String prompt, float promptStrength, boolean shouldFlip, float guidance) {
  if (currentCamImage == null) return;
  
  // Request garbage collection before starting a new capture cycle
  System.gc();
  
  lastCaptureTime = millis();
  requestInProgress = true;  // Set flag at the start
  requestStartTime = millis();
  
  // Generate timestamp for output file only
  String timestamp = getCurrentTimestamp();
  String outputFilename = outputDir + "/" + modelVersion + "_" + timestamp + "_" + nf(promptStrength, 0, 2) + "_" + nf(guidance, 0, 2) + ".png";
  
  // Flip the image vertically if enabled
  PImage imageToProcess = shouldFlip ? flipImageVertically(currentCamImage) : currentCamImage;
  
  // Create the JSON payload for the request
  JSONObject json = new JSONObject();
  json.setString("model_version", modelVersion);
  
  // Set the prompt - no need to format it here as it's already formatted when needed
  json.setString("prompt", prompt);
  
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
  json.setFloat("guidance_scale", guidance);
  json.setInt("output_quality", outputQuality);
  json.setInt("num_inference_steps", numInferenceSteps);
  
  // Send to the Flask server in a separate thread to avoid blocking
  Thread t = new Thread(new Runnable() {
    public void run() {
      try {
        sendToFlaskServer(json.toString(), outputFilename, shouldFlip);
      } catch (Exception e) {
        println("Error in request thread: " + e.getMessage());
        requestInProgress = false;  // Ensure flag is cleared on error
      }
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

void sendToFlaskServer(String jsonPayload, String outputFilename, boolean shouldFlip) {
  try {
    // Parse the JSON to get just the prompt and prompt strength for logging
    JSONObject json = parseJSONObject(jsonPayload);
    String prompt = json.getString("prompt");
    float pStrength = json.getFloat("prompt_strength");
    String model = json.getString("model_version");
     
    // Create a copy of the JSON for logging without the image data
    JSONObject logJson = new JSONObject();
    logJson.setString("prompt", prompt);
    logJson.setString("model_version", model);
    logJson.setFloat("prompt_strength", pStrength);
    logJson.setBoolean("flip", shouldFlip);
    logJson.setFloat("lora_scale", json.getFloat("lora_scale"));
    
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
        
        // Download the image using the passed filename and flip parameter
        downloadImage(outputUrl, outputFilename, shouldFlip);
        lastCaptureTime = millis(); // Make sure the image displays for 5 seconds if request took longer
      } else {
        println("Error in response: " + response.body());
        requestInProgress = false;
      }
    } else {
      println("HTTP error: " + statusCode);
      requestInProgress = false;
    }
  } 
  catch (Exception e) {
    println("Error sending to server: " + e.getMessage());
    e.printStackTrace();
    requestInProgress = false;
  }
}

void downloadImage(String url, String outputFilename, boolean shouldFlip) {
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
          PImage finalImage = shouldFlip ? flipImageVertically(newAIImage) : newAIImage;
          
          // If flip mode is on, save the flipped image back to disk
          if (shouldFlip) {
            // Convert PImage to BufferedImage
            BufferedImage bimg = new BufferedImage(finalImage.width, finalImage.height, BufferedImage.TYPE_INT_RGB);
            finalImage.loadPixels();
            for (int y = 0; y < finalImage.height; y++) {
              for (int x = 0; x < finalImage.width; x++) {
                bimg.setRGB(x, y, finalImage.pixels[y * finalImage.width + x]);
              }
            }
            
            // Save the flipped image back to disk
            ImageIO.write(bimg, "png", outputPath.toFile());
            println("Saved flipped image to: " + outputPath);
          }
          
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
  } finally {
    // Only set requestInProgress to false here, after everything is complete
    requestInProgress = false;
    println("Request completed, red dot should disappear");
  }
}

void displayStatus() {
  // Only display status if showStatusDisplay is true
  if (!showStatusDisplay) return;
  
  // Display status information as an overlay
  fill(0, 150);
  noStroke();
  
  // Show settings panel in the upper left
  rect(10, 10, 300, height - 20);  // Use height - 20 to leave some margin at bottom
  
  fill(255);
  textSize(16);
  text("aMiRROR - AI Subconscious Mirror", 20, 40);
  textSize(14);
  
  // Main settings
  text("Prompt: " + currentPrompt, 20, 70);
  text("Model: " + modelVersion + " (M to cycle)", 20, 90);
  text("Gallery Mode: " + (galleryMode ? "ON" : "OFF") + " (G to toggle)", 20, 110);
  text("Capture Mode: " + currentCaptureMode + " (C to cycle)", 20, 130);
  text("Flip Image: " + (flipImage ? "ON" : "OFF") + " (F to toggle)", 20, 150);
  
  // Camera settings
  text("Camera: " + cam.width + "x" + cam.height + " → " + displayWidth + "x" + displayHeight, 20, 170);
  
  // Generation settings
  text("Steps: " + numInferenceSteps + " (↑/↓ to change)", 20, 190);
  text("Guidance Scale: " + nf(guidanceScale, 0, 2) + " (←/→ to change)", 20, 210);
  fill(255, 0, 0);
  text("Prompt Strength: " + nf(promptStrength, 0, 2) + " (+/- to change)", 20, 230);
  fill(255);
  text("Fast Mode: " + (goFast ? "ON" : "OFF") + " (G to toggle)", 20, 250);
  text("Lora Scale: " + nf(loraScale, 0, 1) + " (L/K to change)", 20, 270);
  
  // Status and motion settings
  if (currentCaptureMode == CaptureMode.CaptureMotion) {
    text("Motion Threshold: " + nf(motionThreshold, 0, 3) + " ([/] to change)", 20, 290);
    text("Current Motion: " + nf(currentMotion, 0, 3), 20, 310);
    text("Auto-capture: " + (autoCaptureTimeout/1000) + "s (</> to change)", 20, 330);
    fill(0, 255, 0);
    text("Framerate: " + nf(frameRate, 0, 1) + " fps", 20, 350);
    fill(255);
    if (requestInProgress) {
      text("Generating... " + ((millis() - requestStartTime) / 1000) + "s", 20, 370);
    } else {
      text("MOTION", 20, 370);
    }
    text("Press D to hide settings", 20, 390);
  } else {
    text("Framerate: " + nf(frameRate, 0, 1) + " fps", 20, 290);
    if (requestInProgress) {
      text("Generating... " + ((millis() - requestStartTime) / 1000) + "s", 20, 310);
    } else {
      text("Next capture in " + ((captureInterval - (millis() - lastCaptureTime)) / 1000) + "s", 20, 310);
    }
    text("Press D to hide settings", 20, 330);
  }
  
  // Show camera preview at 1/8 scale
  if (currentCamImage != null) {
    int previewX = (300 - currentCamImage.width/8) / 2 + 10;
    int previewY = 450;  // Moved down to prevent overlap
    drawCameraPreview(previewX, previewY);
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
      captureAndProcess(modelVersion, currentPrompt, promptStrength, flipImage, guidanceScale);
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
      // Toggle gallery mode
      galleryMode = !galleryMode;
      println("Gallery mode: " + (galleryMode ? "ON" : "OFF"));
      break;
      
    case 'M':
      // Cycle through available models
      if (availableModels != null && availableModels.length > 0) {
        currentModelIndex = (currentModelIndex + 1) % availableModels.length;
        modelVersion = availableModels[currentModelIndex];
        println("Switched to model:", modelVersion);
      }
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
      adjustMotionThreshold(-0.001);
      break;
      
    case ']':
    case '}':
      adjustMotionThreshold(0.001);
      break;
      
    case '<':
    case ',':
      // Decrease auto-capture timeout
      autoCaptureTimeout = constrain(autoCaptureTimeout - 5000, 5000, 60000);
      println("Auto-capture timeout: " + (autoCaptureTimeout/1000) + "s");
      break;
      
    case '>':
    case '.':
      // Increase auto-capture timeout
      autoCaptureTimeout = constrain(autoCaptureTimeout + 5000, 5000, 60000);
      println("Auto-capture timeout: " + (autoCaptureTimeout/1000) + "s");
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

// Add this method to clean up resources
void cleanupResources() {
  if (blendedBuffer != null) {
    blendedBuffer = null;
  }
  if (processedImageBuffer != null) {
    processedImageBuffer = null;
  }
  if (previousFrame != null) {
    previousFrame = null;
  }
  System.gc();
}