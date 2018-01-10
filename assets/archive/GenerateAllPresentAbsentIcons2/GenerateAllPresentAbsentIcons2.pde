// Run and press the 'r' key to regenerate all icons
//
// https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/Finder.html
// 
// Retina screens 12x12 through 320x320
// Nonretina screens 8x8 through 160x160
//
// “Create your badge images so that each can be drawn at up to 320x320 pixels. For each image, fill the entire 
// frame edge-to-edge with your artwork (in other words, use no padding).”
//

boolean record;
color green, red, grey; // git-annex logo colors
color absentStroke;
int MAX_COPY_COUNT_TO_SHOW = 5;
boolean doSaveAllIcons = false;

void setup() {
  size(320, 320, P3D);
  green = color(64, 191, 76);
  red = color(216, 56, 45);
  grey = color(102, 102, 102);
  absentStroke = color(150);
}

void draw() {
  if (doSaveAllIcons) {
    saveAllIcons();
    exit();
  }

  background(255);

  PGraphics g = createGraphics(width, height, P3D);

  int actualCopies = 3;
  int desiredCopies = 3;
  // workaround, boolean not supported by tweak mode
  int i = 0;
  boolean present = i == 0 ? true : false;
  drawAnIconTo(g, 3, 3, present);

  image(g, 0, 0);
}

void drawAnIconTo(PGraphics g, int actualCopies, int desiredCopies, boolean present) {
  float b = 2.3;

  // Do all your drawing here
  g.hint(ENABLE_DEPTH_TEST);
  g.beginDraw();

  g.beginCamera();
  g.pushMatrix();

  g.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
    width/2.0, height/2.0, 0, // center
    0, 1, 0); // up

  g.translate(width/1.9, height/2.1, -200.0);

  g.translate(-33.3, -12.8, 1.0);
  g.rotateX(0.7);
  g.rotateZ(0.2);
  g.rotateY(1.3);
  g.strokeWeight(20.0);
  if (present) {
    g.stroke(64.0*b, 191.0*b, 76.0*b);
    g.fill(green);
  } else {
    g.stroke(absentStroke);
    g.fill(255, 0);
  }
  g.box(166.1);

  g.popMatrix();
  g.endCamera();

  g.hint(DISABLE_DEPTH_TEST);
  g.translate(287.6, -15.3);
  g.scale(0.9);
  g.rectMode(CENTER);

  color fillColor = grey;
  color strokeColor = grey;
  // we have the desired number of copies
  // make everything green, for goodness
  if (actualCopies >= desiredCopies) {
    fillColor = green;
    strokeColor = color(64.0*b, 191.0*b, 76.0*b);
  }

  for (int i=1; i<=MAX_COPY_COUNT_TO_SHOW; i++) {
    g.strokeWeight(4.0);
    g.pushMatrix();
    if (i <= actualCopies) {
      g.fill(fillColor);
    } else { 
      g.noFill();
    }
    g.stroke(strokeColor);

    g.translate(0.0, height * ((float)i / (float)MAX_COPY_COUNT_TO_SHOW), 0.0);
    g.rect(0, 0, 25, 25, 5);

    // this is the git-annex numcopies value
    // draw an extra outline around the square
    if (i == desiredCopies) {
      g.noFill();
      g.strokeWeight(7.9);
      g.rect(0, 0, 45, 45, 7);
    }

    g.popMatrix();
  }

  g.hint(ENABLE_DEPTH_TEST);
  g.endDraw();
}

void saveAllIcons() {
  PGraphics g;
  for (int i=0; i<=1; i++) {
    boolean present = true;
    String presentString = "Present";
    if (i == 1) {
      present = false;
      presentString = "Absent";
    }
    for (int actualCopies=0; actualCopies<=MAX_COPY_COUNT_TO_SHOW; actualCopies++) {
      for (int desiredCopies=0; desiredCopies<=MAX_COPY_COUNT_TO_SHOW; desiredCopies++) {
        g = createGraphics(width, height, P3D);
        drawAnIconTo(g, actualCopies, desiredCopies, present);
        g.save("saved/"+presentString+actualCopies+"ActualCopies"+desiredCopies+"DesiredCopies.png");
      }
    }
  }
}

// Hit 'r' to record all frames
void keyPressed() {
  // save all icons and quit
  if (key == 'r') {
    doSaveAllIcons = true;
  }
}