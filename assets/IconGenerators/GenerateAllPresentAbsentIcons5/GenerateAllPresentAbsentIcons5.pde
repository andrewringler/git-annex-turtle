import processing.pdf.*;

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
// save illustrator files for use with Processing
// save as SVG 1.0, Only Glyphs Used,
// Css properties: presentation attributes 
//
//

boolean record;
color green, red, grey; // git-annex logo colors
color absentStroke;
int MAX_COPY_COUNT_TO_SHOW = 3;
boolean doSaveAllIcons = false;
PShape overpassMonoOutline0;
PShape presentIcon;

void setup() {
  size(320, 320, P2D);
  green = color(64, 191, 76);
  red = color(216, 56, 45);
  grey = color(102, 102, 102);
  absentStroke = color(150);
  frameRate(5);

  overpassMonoOutline0 = loadShape("0-Overpass-Mono-Bold-Outline.ai.svg");
  presentIcon = loadShape("GitAnnexPresentCube.ai.svg");
}

void draw() {
  if (doSaveAllIcons) {
    saveAllIcons();
    exit();
  }

  background(255);

  PGraphics g = createGraphics(width, height, P2D);
  g.beginDraw();

  int actualCopies = 3;
  int desiredCopies = 3;
  // workaround, boolean not supported by tweak mode
  int i = 0;
  boolean present = i == 0 ? true : false;
  drawAnIconTo(g, actualCopies, desiredCopies, present);
  g.endDraw();

  image(g, 0, 0);
}

void drawAnIconTo(PGraphics g, int actualCopies, int desiredCopies, boolean present) {
  float b = 2.3;

  // Draw Num Copies
  g.pushMatrix();
  g.translate(4.3, -9.3);
  g.scale(1.6);
  g.shape(overpassMonoOutline0, 0, 0, 82.7, 117.9);
  g.popMatrix();

  // Draw Present Icon
  if (present) {
    g.pushMatrix();
    g.translate(235.7, 236.8);
    g.shape(presentIcon, 0, 0, 75.3, 75.3);
    g.popMatrix();
  }
}

void saveAllIcons() {
  for (int i=0; i<=1; i++) {
    boolean present = true;
    String presentString = "Present";
    if (i == 1) {
      present = false;
      presentString = "Absent";
    }
    for (int actualCopies=0; actualCopies<=MAX_COPY_COUNT_TO_SHOW; actualCopies++) {
      for (int desiredCopies=0; desiredCopies<=MAX_COPY_COUNT_TO_SHOW; desiredCopies++) {
        String filename = "saved/"+presentString+actualCopies+"ActualCopies"+desiredCopies+"DesiredCopies.pdf"; 
        PGraphicsPDF g = (PGraphicsPDF) createGraphics(width, height, PDF, filename);
        g.beginDraw();
        drawAnIconTo(g, actualCopies, desiredCopies, present);
        g.dispose();
        g.endDraw();
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