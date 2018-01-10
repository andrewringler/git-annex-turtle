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
PFont overpassMono;
PShape overpassMono0;

void setup() {
  size(320, 320, P3D);
  green = color(64, 191, 76);
  red = color(216, 56, 45);
  grey = color(102, 102, 102);

  g = createGraphics(width, height, P3D);
  //g.hint(DISABLE_OPTIMIZED_STROKE);
  g.hint(ENABLE_DEPTH_SORT);
  //g.hint(DISABLE_DEPTH_TEST);
  //hint(ENABLE_DEPTH_MASK);
  //hint(ENABLE_DEPTH_TEST);
  //hint(ENABLE_STROKE_PERSPECTIVE);
  //hint(ENABLE_TEXTURE_MIPMAPS);

  overpassMono = createFont("OverpassMono-Bold.ttf", 114);
  overpassMono0 = loadShape("0-Overpass-Mono-Bold-Outline2.ai.svg");
  //overpassMono0.setFill(color(0, 0, 0, 0));
  //overpassMono0.setStroke(color(102));
  //overpassMono0.setStrokeWeight(1.0);  
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
  g.beginDraw();
  g.background(204); //draw background when doing tweak mode
  g.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g.translate(width/1.9, height/2.1, -200.0);

  g.pushMatrix();
  g.translate(-100.3, -96.1, 188);
  g.scale(1.0);
  //g.noStroke();
  //g.fill(102, 102, 102);
  //g.noFill();
  //g.strokeWeight(14);
  //g.stroke(216);
  //g.box(150.4, 150.4, 150.3);
  //g.textAlign(CENTER, CENTER);
  //g.textSize(114);
  //g.textFont(overpassMono);
  //g.text("1", 0, 0);
  //g.noFill();
  //g.noStroke();
  g.shape(overpassMono0, 0, 0);
  g.popMatrix();

  g.rotateX(0.7);
  g.rotateZ(0.3);
  g.rotateY(-0.5);
  g.strokeWeight(10.0);
  //stroke(0, 100);
  //fill(0, 20);
  //stroke(grey);
  //fill(255, 1);
  float b = 2.3;
  g.stroke(64.0*b, 191.0*b, 76.0*b);
  g.fill(255, 0);
  g.box(200.0);

  g.endDraw();

  image(g, 0, 0);
}

// Hit 'r' to record a single frame
void keyPressed() {
  if (key == 'r') {
    g.save("icon.png");
  }
}