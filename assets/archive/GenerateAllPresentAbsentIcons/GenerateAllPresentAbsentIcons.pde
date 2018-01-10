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
int MAX_CIRCLES = 5;

void setup() {
  size(320, 320, P3D);
  green = color(64, 191, 76);
  red = color(216, 56, 45);
  grey = color(102, 102, 102);

  for (int NUMBER_OF_COPIES=0; NUMBER_OF_COPIES<=MAX_CIRCLES; NUMBER_OF_COPIES++) {
    for (int NUMCOPIES=0; NUMCOPIES<=MAX_CIRCLES; NUMCOPIES++) {
      g = createGraphics(width, height, P3D);

      float b = 2.3;

      // Do all your drawing here
      g.beginDraw();

      g.beginCamera();
      g.pushMatrix();

      g.camera(width/1.9, height/1.9, (height/4.7) / tan(PI*30.0 / 180.0), // eye
        width/2.0, height/2.0, 0, // center
        0, 1, 0); // up

      g.translate(width/1.9, height/2.1, -200.0);

      g.translate(-4.3, -12.8, 1.0);
      g.rotateX(0.7);
      g.rotateZ(0.3);
      g.rotateY(-0.5);
      g.strokeWeight(10.0);
      g.stroke(64.0*b, 191.0*b, 76.0*b);
      g.fill(255, 0);
      g.box(188.1);

      g.popMatrix();
      g.endCamera();

      g.hint(DISABLE_DEPTH_TEST);
      g.translate(32.7, 304.6);
      g.scale(0.7);
      g.rectMode(CENTER);

      color fillColor = grey;
      color strokeColor = grey;
      // we have the desired number of copies
      // make everything green, for goodness
      if (NUMBER_OF_COPIES >= NUMCOPIES) {
        fillColor = green;
        strokeColor = color(64.0*b, 191.0*b, 76.0*b);
      }

      for (int i=1; i<=MAX_CIRCLES; i++) {
        g.strokeWeight(3.0);
        g.pushMatrix();
        if (i <= NUMBER_OF_COPIES) {
          g.fill(fillColor);
        } else { 
          g.noFill();
        }
        g.stroke(strokeColor);

        g.translate(width * ((float)i / (float)MAX_CIRCLES), 0, 0);
        g.rect(0, 0, 25, 25, 5);

        // this is the git-annex numcopies value
        // draw an extra outline around the square
        if (i == NUMCOPIES) {
          g.noFill();
          g.strokeWeight(4.3);
          g.rect(0, 0, 38, 38, 5);
        }

        g.popMatrix();
      }

      g.hint(ENABLE_DEPTH_TEST);
      g.endDraw();
      g.save("Absent"+NUMBER_OF_COPIES+"Copies"+NUMCOPIES+"NumCopies.png");
    }
  }
  exit();
}