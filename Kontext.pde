import processing.video.*;
import java.util.Base64;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URI;
import java.time.Duration;
import java.io.ByteArrayOutputStream;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.time.Instant;
import controlP5.*;
import drop.*;

Capture cam;
PImage currentImage;
PImage resultImage;
boolean isProcessing = false;
String serverUrl = "http://localhost:5000";
String kontextEndpoint = serverUrl + "/kontext";
long currentTimestamp;
int currentVersion = 0;  // Track version number for current capture
HttpClient httpClient;

// ControlP5
ControlP5 cp5;
Textfield promptField;

// Thumbnail settings
int thumbnailWidth = 160;  // 1/8 of window width
int thumbnailHeight = 90;  // 1/8 of window height
int thumbnailX = 10;
int thumbnailY = 10;

// Processing indicator settings
float pulsePhase = 0;
float pulseSpeed = 0.1;  // Speed of the pulse animation

// Text field settings
int textFieldHeight = 40;
int textFieldPadding = 10;

// Drop handler
SDrop drop;

// Session management
String currentSessionPrefix = "";  // Will store the timestamp prefix for current session

// Camera preview control
boolean showCameraPreview = true;

void setup() {
  size(1280, 720);
  
  // Initialize drop handler
  drop = new SDrop(this);
  
  // Initialize ControlP5
  cp5 = new ControlP5(this);
  
  // Create text input field without label
  promptField = cp5.addTextfield("prompt")
    .setPosition(10, height - textFieldHeight - textFieldPadding)
    .setSize(width - 20, textFieldHeight)
    .setFont(createFont("Arial", 20))
    .setColor(color(255))
    .setColorActive(color(255))
    .setColorBackground(color(0, 100))
    .setColorForeground(color(255))
    .setColorCursor(color(255))
    .setText("A surreal mirror reflection")
    .setAutoClear(false)
    .setFocus(true)
    .setLabel("");  // Remove the label
  
  // Initialize webcam at full window resolution
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("No cameras available");
    exit();
  }
  
  cam = new Capture(this, width, height, cameras[0]);
  cam.start();
  
  // Create data directory if it doesn't exist
  File dataDir = new File(sketchPath("data/Kontext"));
  if (!dataDir.exists()) {
    dataDir.mkdirs();
  }
  
  // Initialize HTTP client
  httpClient = HttpClient.newBuilder()
               .version(HttpClient.Version.HTTP_1_1)
               .connectTimeout(Duration.ofSeconds(30))
               .build();
}

void draw() {
  background(0);
  
  if (cam.available()) {
    cam.read();
  }
  
  // Display current image (either captured or result) at full window size
  if (currentImage != null) {
    image(currentImage, 0, 0, width, height);
  }
  
  // Draw webcam thumbnail with border and hover effect if preview is active
  if (showCameraPreview) {
    pushStyle();
    // Draw border
    stroke(255);
    strokeWeight(2);
    noFill();
    rect(thumbnailX - 2, thumbnailY - 2, thumbnailWidth + 4, thumbnailHeight + 4);
    // Draw webcam feed
    image(cam, thumbnailX, thumbnailY, thumbnailWidth, thumbnailHeight);
    
    // Add hover effect
    if (mouseX >= thumbnailX && mouseX <= thumbnailX + thumbnailWidth &&
        mouseY >= thumbnailY && mouseY <= thumbnailY + thumbnailHeight) {
      fill(255, 50);
      noStroke();
      rect(thumbnailX, thumbnailY, thumbnailWidth, thumbnailHeight);
    }
    popStyle();
  }
  
  // Draw processing indicator
  if (isProcessing) {
    drawIndicator();
  }
}

void drawIndicator() {
  if (isProcessing) {
    pushStyle();
    noStroke();
    
    // Draw multiple concentric circles with varying opacities
    float baseOpacity = 255 * (0.5 + 0.5 * sin(pulsePhase));
    float centerX = width / 2;
    float centerY = height / 2;
    
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

void keyPressed() {
  if (key == ENTER || key == RETURN) {
    if (currentImage != null && !isProcessing) {
      // Send to server
      sendToServer();
    }
  } else if (key == CODED && !promptField.isFocus()) {
    if (keyCode == LEFT) {
      // Go to previous version
      if (currentVersion > 0) {
        currentVersion--;
        loadCurrentVersion();
      }
    } else if (keyCode == RIGHT) {
      // Go to next version
      currentVersion++;
      loadCurrentVersion();
    }
  }
}

void loadCurrentVersion() {
  String filename;
  if (currentVersion == 0) {
    filename = String.format("data/Kontext/capture_%s.png", currentSessionPrefix);
  } else {
    filename = String.format("data/Kontext/kontext_%s-%d.png", currentSessionPrefix, currentVersion);
  }
  
  File file = new File(sketchPath(filename));
  if (file.exists()) {
    currentImage = loadImage(filename);
    println("Loaded version " + currentVersion + " from: " + filename);
  } else {
    // If file doesn't exist, go back to last valid version
    currentVersion--;
    println("Version " + currentVersion + " not found, staying at version " + currentVersion);
  }
}

void mousePressed() {
  if (mouseButton == RIGHT) {
    // Toggle camera preview on right click
    showCameraPreview = !showCameraPreview;
  } else if (mouseButton == LEFT && showCameraPreview) {
    // Only capture if preview is active
    if (mouseX >= thumbnailX && mouseX <= thumbnailX + thumbnailWidth &&
        mouseY >= thumbnailY && mouseY <= thumbnailY + thumbnailHeight) {
      // Capture current frame
      currentImage = cam.copy();
      // Get current timestamp
      currentTimestamp = Instant.now().toEpochMilli();
      currentSessionPrefix = String.valueOf(currentTimestamp);
      // Reset version counter
      currentVersion = 0;
      // Save to data folder
      String filename = String.format("data/Kontext/capture_%s.png", currentSessionPrefix);
      currentImage.save(filename);
      println("Saved capture to: " + filename);
    }
  }
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

void sendToServer() {
  isProcessing = true;
  
  // Create the JSON payload
  JSONObject json = new JSONObject();
  json.setString("prompt", promptField.getText());
  json.setString("image", encodeImageToBase64(currentImage));
  
  // Send to server in a separate thread
  Thread t = new Thread(new Runnable() {
    public void run() {
      try {
        // Create HTTP request
        HttpRequest request = HttpRequest.newBuilder()
          .uri(URI.create(kontextEndpoint))
          .header("Content-Type", "application/json")
          .POST(HttpRequest.BodyPublishers.ofString(json.toString()))
          .build();
        
        // Send request and get response
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() == 200) {
          println("Server response body: " + response.body());
          JSONObject jsonResponse = parseJSONObject(response.body());
          
          if (jsonResponse.hasKey("output_url")) {
            String imageUrl = jsonResponse.getString("output_url");
            if (imageUrl != null && !imageUrl.isEmpty()) {
              // Download the image
              HttpRequest imageRequest = HttpRequest.newBuilder()
                .uri(URI.create(imageUrl))
                .GET()
                .build();
              
              HttpResponse<byte[]> imageResponse = httpClient.send(imageRequest, HttpResponse.BodyHandlers.ofByteArray());
              
              if (imageResponse.statusCode() == 200) {
                // Increment version counter
                currentVersion++;
                // Save the image bytes to a file with version number
                String resultFile = String.format("data/Kontext/kontext_%s-%d.png", currentSessionPrefix, currentVersion);
                Files.write(Paths.get(sketchPath(resultFile)), imageResponse.body());
                println("Saved result to: " + resultFile);
                
                // Load the image
                resultImage = loadImage(resultFile);
                println("Image loaded successfully from: " + resultFile);
                
                // Set the result as the current image for next processing
                currentImage = resultImage.copy();
              } else {
                println("Error downloading image: " + imageResponse.statusCode());
              }
            } else {
              println("Error: Empty image URL received from server");
            }
          } else if (jsonResponse.hasKey("prediction_id")) {
            String predictionId = jsonResponse.getString("prediction_id");
            println("Prediction started with ID: " + predictionId);
            
            // Poll for result
            boolean predictionComplete = false;
            int attempts = 0;
            int maxAttempts = 30; // 30 seconds timeout
            
            while (!predictionComplete && attempts < maxAttempts) {
              // Wait 1 second between attempts
              Thread.sleep(1000);
              attempts++;
              
              // Create polling request
              HttpRequest pollRequest = HttpRequest.newBuilder()
                .uri(URI.create(kontextEndpoint + "?id=" + predictionId))
                .GET()
                .build();
              
              HttpResponse<String> pollResponse = httpClient.send(pollRequest, HttpResponse.BodyHandlers.ofString());
              println("Poll attempt " + attempts + ": " + pollResponse.body());
              
              // Only try to parse JSON if we got a valid response
              if (pollResponse.statusCode() == 200) {
                try {
                  JSONObject pollJson = parseJSONObject(pollResponse.body());
                  
                  // Check for direct output_url first
                  if (pollJson.hasKey("output_url")) {
                    String imageUrl = pollJson.getString("output_url");
                    if (imageUrl != null && !imageUrl.isEmpty()) {
                      // Download the image
                      HttpRequest imageRequest = HttpRequest.newBuilder()
                        .uri(URI.create(imageUrl))
                        .GET()
                        .build();
                      
                      HttpResponse<byte[]> imageResponse = httpClient.send(imageRequest, HttpResponse.BodyHandlers.ofByteArray());
                      
                      if (imageResponse.statusCode() == 200) {
                        // Increment version counter
                        currentVersion++;
                        // Save the image bytes to a file with version number
                        String resultFile = String.format("data/Kontext/kontext_%s-%d.png", currentSessionPrefix, currentVersion);
                        Files.write(Paths.get(sketchPath(resultFile)), imageResponse.body());
                        println("Saved result to: " + resultFile);
                        
                        // Load the image
                        resultImage = loadImage(resultFile);
                        println("Image loaded successfully from: " + resultFile);
                        
                        // Set the result as the current image for next processing
                        currentImage = resultImage.copy();
                        predictionComplete = true;
                      } else {
                        println("Error downloading image: " + imageResponse.statusCode());
                      }
                    } else {
                      println("Error: Empty image URL received from server");
                    }
                  }
                  // Then check for status updates
                  else if (pollJson.hasKey("status")) {
                    String status = pollJson.getString("status");
                    if (status.equals("succeeded")) {
                      if (pollJson.hasKey("output_url")) {
                        String imageUrl = pollJson.getString("output_url");
                        if (imageUrl != null && !imageUrl.isEmpty()) {
                          // Download the image
                          HttpRequest imageRequest = HttpRequest.newBuilder()
                            .uri(URI.create(imageUrl))
                            .GET()
                            .build();
                          
                          HttpResponse<byte[]> imageResponse = httpClient.send(imageRequest, HttpResponse.BodyHandlers.ofByteArray());
                          
                          if (imageResponse.statusCode() == 200) {
                            // Increment version counter
                            currentVersion++;
                            // Save the image bytes to a file with version number
                            String resultFile = String.format("data/Kontext/kontext_%s-%d.png", currentSessionPrefix, currentVersion);
                            Files.write(Paths.get(sketchPath(resultFile)), imageResponse.body());
                            println("Saved result to: " + resultFile);
                            
                            // Load the image
                            resultImage = loadImage(resultFile);
                            println("Image loaded successfully from: " + resultFile);
                            
                            // Set the result as the current image for next processing
                            currentImage = resultImage.copy();
                            predictionComplete = true;
                          } else {
                            println("Error downloading image: " + imageResponse.statusCode());
                          }
                        } else {
                          println("Error: Empty image URL received from server");
                        }
                      } else {
                        println("Error: No output_url in completed prediction");
                      }
                    } else if (status.equals("failed")) {
                      println("Error: Prediction failed");
                      predictionComplete = true;
                    }
                  } else {
                    println("Error: No status or output_url field in response");
                  }
                } catch (Exception e) {
                  println("Error parsing response: " + e.getMessage());
                }
              } else {
                println("Error: Server returned status code " + pollResponse.statusCode());
              }
            }
            
            if (!predictionComplete) {
              println("Error: Prediction timed out after " + maxAttempts + " seconds");
            }
          } else {
            println("Error: No prediction_id or output_url in server response");
            println("Available fields: " + jsonResponse.keys());
            println("Full response: " + response.body());
          }
        } else {
          println("Error: Server returned status code " + response.statusCode());
          println("Response: " + response.body());
        }
      } catch (Exception e) {
        println("Error sending to server: " + e.getMessage());
        e.printStackTrace();
      } finally {
        isProcessing = false;
      }
    }
  });
  t.setDaemon(true);
  t.start();
}

// Handle dropped files
void dropEvent(DropEvent event) {
  if (event.isFile()) {
    String[] fileExtensions = {".jpg", ".jpeg", ".png", ".gif"};
    String filePath = event.file().getAbsolutePath();
    
    // Check if the file is an image
    boolean isImage = false;
    for (String ext : fileExtensions) {
      if (filePath.toLowerCase().endsWith(ext)) {
        isImage = true;
        break;
      }
    }
    
    if (isImage) {
      // Hide camera preview when image is dropped
      showCameraPreview = false;
      
      // Load and set the dropped image
      currentImage = loadImage(filePath);
      if (currentImage != null) {
        // Get current timestamp and start new session
        currentTimestamp = Instant.now().toEpochMilli();
        currentSessionPrefix = String.valueOf(currentTimestamp);
        // Reset version counter
        currentVersion = 0;
        // Save to data folder
        String filename = String.format("data/Kontext/capture_%s.png", currentSessionPrefix);
        currentImage.save(filename);
        println("Saved dropped image to: " + filename);
      }
    }
  }
}