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
color green, red, grey; // git-annex logo colors

void setup() {
  size(128, 128, P2D);
  green = color(64, 191, 76);
  red = color(216, 56, 45);
  grey = color(102, 102, 102);

  //hint(DISABLE_OPTIMIZED_STROKE);
  //hint(ENABLE_DEPTH_SORT);
  //hint(ENABLE_DEPTH_MASK);
  //hint(ENABLE_DEPTH_TEST);
  //hint(ENABLE_STROKE_PERSPECTIVE);
  //hint(ENABLE_TEXTURE_MIPMAPS);
}

void draw() {
  // don't include the background in the export
  background(204);

  // https://processing.org/discourse/beta/num_1191532471.html
  //if (record) {
  //  beginRaw(PDF, "icon.pdf");
  //}

  //g.beginDraw();
  //g.rectMode(CENTER);
  //g.fill(255, 100);
  ////g.stroke(59, 87);
  //g.strokeWeight(16.0);
  //g.rect(width/2.0, height/2.0, 223, 163, 4, 4, 4, 4); 
  //g.dispose();
  //g.endDraw();


  // Do all your drawing here
  g = createGraphics(width, height, P3D);
  g.beginDraw();
  g.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g.translate(width/1.9, height/2.1, -200.0);
  g.rotateX(0.7);
  g.rotateZ(0.3);
  g.rotateY(-0.5);
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
}

// Hit 'r' to record a single frame
void keyPressed() {
  if (key == 'r') {
    g.save("icon.png");
  }
}