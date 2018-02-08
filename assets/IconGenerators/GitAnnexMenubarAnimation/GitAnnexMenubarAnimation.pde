// https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/Finder.html
// 
// Retina screens 12x12 through 320x320
// Nonretina screens 8x8 through 160x160
//
// “Create your badge images so that each can be drawn at up to 320x320 pixels. For each image, fill the entire 
// frame edge-to-edge with your artwork (in other words, use no padding).”
//

PGraphics g44, g22;
boolean record;
float rX = 0;
float rY = 0;
float rZ = 0;
int frame = 0;
color white, black;

PImage saveFrame44, saveFrame22;

void setup() {
  size(128, 128, P2D);
  saveFrame44 = createImage(44, 44, ARGB);
  saveFrame22 = createImage(22, 22, ARGB);
  frameRate(60);
  white = color(255);
  black = color(0);

  //hint(DISABLE_OPTIMIZED_STROKE);
  //hint(ENABLE_DEPTH_SORT);
  //hint(ENABLE_DEPTH_MASK);
  //hint(ENABLE_DEPTH_TEST);
  //hint(ENABLE_STROKE_PERSPECTIVE);
  //hint(ENABLE_TEXTURE_MIPMAPS);
}

void draw() {
  g44 = createGraphics(width, height, P3D);
  g44.smooth(4);
  g44.beginDraw();
  g44.background(255);
  g44.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g44.translate(width/1.9, height/2.1, -200.0);  
  g44.rotateX(0.7);
  g44.rotateZ(0.3);
  g44.rotateY(-0.5);

  g44.rotateX(rX);
  g44.rotateZ(rZ);
  g44.rotateY(rY);  

  g44.strokeWeight(3.5);
  g44.stroke(255);
  g44.fill(0);
  g44.box(50);
  g44.endDraw();

  g22 = createGraphics(width, height, P3D);
  g22.smooth(4);
  g22.beginDraw();
  g22.background(255);
  g22.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g22.translate(width/1.9, height/2.1, -200.0);  
  g22.rotateX(0.7);
  g22.rotateZ(0.3);
  g22.rotateY(-0.5);

  g22.rotateX(rX);
  g22.rotateZ(rZ);
  g22.rotateY(rY);  

  g22.strokeWeight(2);
  g22.stroke(255);
  g22.fill(0);
  g22.box(25);
  g22.endDraw();

  image(g44, 0, 0);

  rX += PI/83.2;
  rY += PI/190.2;
  rZ += PI/169.0;

  if (frameCount % 10 == 0) {
    // 44px image, 2x
    saveFrame44.copy(g44, 50, 48, 44, 44, 0, 0, 44, 44);
    replaceColorsWithTransparent(saveFrame44);
    saveFrame44.save("saved-44px/menubaricon-" + nf(frame, 3, 0) + ".png");

    // 22px image, 1x
    saveFrame22.copy(g22, 61, 58, 22, 22, 0, 0, 22, 22);
    replaceColorsWithTransparent(saveFrame22);
    saveFrame22.save("saved-22px/menubaricon-" + nf(frame, 3, 0) + ".png");    

    frame++;
  }

  if (frame > 16) {
    exit();
  }
}

// Hit 'r' to record a single frame
void keyPressed() {
  if (key == 'r') {
    g.save("icon.png");
  }
}

void replaceColorsWithTransparent(PImage img) {
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    // now that we have a flat image
    // we can replace white pixels with transparent for export to 2d
    if (img.pixels[i] == white) {
      img.pixels[i] = color(255, 0);
    } else if (img.pixels[i] != black) {
      // replace grayscale, aliasing pixels with transparency
      // for menubar icon
      img.pixels[i] = color(0, 255-green(img.pixels[i]));
    }
  }
  img.updatePixels();
}