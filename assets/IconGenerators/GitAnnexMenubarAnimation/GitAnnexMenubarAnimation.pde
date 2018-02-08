// https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/Finder.html
// 
// Retina screens 12x12 through 320x320
// Nonretina screens 8x8 through 160x160
//
// “Create your badge images so that each can be drawn at up to 320x320 pixels. For each image, fill the entire 
// frame edge-to-edge with your artwork (in other words, use no padding).”
//

PGraphics g;
boolean record;
float rX = 0;
float rY = 0;
float rZ = 0;
int frame = 0;
color white;

PImage saveFrame;

void setup() {
  size(128, 128, P2D);
  saveFrame = createImage(44, 44, ARGB);
  frameRate(60);
  white = color(255);

  //hint(DISABLE_OPTIMIZED_STROKE);
  //hint(ENABLE_DEPTH_SORT);
  //hint(ENABLE_DEPTH_MASK);
  //hint(ENABLE_DEPTH_TEST);
  //hint(ENABLE_STROKE_PERSPECTIVE);
  //hint(ENABLE_TEXTURE_MIPMAPS);
}

void draw() {
  g = createGraphics(width, height, P3D);
  g.beginDraw();
  g.background(255);
  g.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g.translate(width/1.9, height/2.1, -200.0);  
  g.rotateX(0.7);
  g.rotateZ(0.3);
  g.rotateY(-0.5);

  g.rotateX(rX);
  g.rotateZ(rZ);
  g.rotateY(rY);  

  g.strokeWeight(2.2);
  //stroke(0, 100);
  //fill(0, 20);
  //stroke(grey);
  //fill(255, 1);
  g.stroke(255);
  g.fill(0);
  g.box(40);
  g.endDraw();

  image(g, 0, 0);

  rX += PI/83.2;
  rY += PI/190.2;
  rZ += PI/169.0;

  if (frameCount % 10 == 0) {
    saveFrame.copy(g, 50, 48, 44, 44, 0, 0, 44, 44);
    saveFrame.loadPixels();
    // now that we have a flat image
    // we can replace white pixels with transparent for export to 2d
    for (int i = 0; i < saveFrame.pixels.length; i++) {
      if (saveFrame.pixels[i] == white) {
        saveFrame.pixels[i] = color(255, 0);
      }
    }
    saveFrame.updatePixels();
    saveFrame.save("saved/menubaricon-" + nf(frame++, 3, 0) + ".png");
  }
}

// Hit 'r' to record a single frame
void keyPressed() {
  if (key == 'r') {
    g.save("icon.png");
  }
}