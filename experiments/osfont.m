#include <AppKit/AppKit.h>
#include <CoreText/CoreText.h>
#include <CoreFoundation/CoreFoundation.h>

void getBounds(char* utf8Text, char* utf8FontName, int fontSize, float* width, float* height) {
  NSString *text = [NSString stringWithUTF8String:utf8Text];
  NSString *fontName = [NSString stringWithUTF8String:utf8FontName];
  NSFont *font = [NSFont fontWithName:fontName size:fontSize/2]; //[NSFont systemFontOfSize:17]

  NSSize sampleSize = [text sizeWithAttributes: @{
      NSFontAttributeName: font
  }];
  width[0] = sampleSize.width*2;
  height[0] = sampleSize.height*2;


  /*
  // https://stackoverflow.com/questions/58827123/get-font-glyph-metrics-with-swift

  NSAttributedString* textAttr = [[NSAttributedString alloc] initWithString:text attributes:@{
      NSFontAttributeName: font
  }];

  CTLineRef* line = CTLineCreateWithAttributedString(textAttr);
  CFArrayRef* glyphRuns = CTLineGetGlyphRuns(line); // as! [CTRun]

  CFIndex count = CFArrayGetCount(glyphRuns);
  for( int i = 0; i < count ; ++i  )
  {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, i);

    // get font;
    CFDictionaryRef attributes = CTRunGetAttributes(run); // as! [CFString: Any]
    CTFontRef font = attributes[kCTFontAttributeName]; // else { return nil }

  // for run in glyphRuns {
  //     let font = run.font!
  //     let glyphs = run.glyphs()
  //     let boundingRects = run.boundingRects(for: glyphs, in: font)
  //     for pair in zip(glyphs, boundingRects) { print(pair) }
  }
  */

}

void drawText(char* utf8Text, char* utf8FontName, int fontSize, int width, int height, char* rawData) {
  NSString *text = [NSString stringWithUTF8String:utf8Text];
  NSString *fontName = [NSString stringWithUTF8String:utf8FontName];
  NSFont *font = [NSFont fontWithName:fontName size:fontSize/2]; //[NSFont systemFontOfSize:17]

  NSImage *image = [NSImage imageWithSize:CGSizeMake(width, height) flipped:YES drawingHandler:^BOOL(NSRect dstRect) {

      // Attributes can be customized to change font, text color, etc.
      NSDictionary *attributes = @{
        NSFontAttributeName: font
      };
      [text drawAtPoint:NSMakePoint(0, 0) withAttributes:attributes];

      return YES;
  }];
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect:NULL context:nil hints:nil]];

  // Test by writing image out.
  // NSData *data = [rep representationUsingType:NSPNGFileType properties:nil];
  // [data writeToFile:@"out.png" atomically:YES];

  // Todo: make this faster by copying bytes directly
  for (int y = 0; y < height; y ++){
    for (int x = 0; x < width; x ++){
      NSColor* pixelColor = [rep colorAtX:x y:y];
      float a = pixelColor.alphaComponent;
      rawData[(y * width + x) * 4 + 0] = pixelColor.redComponent * a * 255;
      rawData[(y * width + x) * 4 + 1] = pixelColor.greenComponent * a * 255;
      rawData[(y * width + x) * 4 + 2] = pixelColor.blueComponent * a * 255;
      rawData[(y * width + x) * 4 + 3] = pixelColor.alphaComponent * 255;
    }
  }
}
