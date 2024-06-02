import processing.sound.*;

chip au;

String[] keys = {
  "x",
  "1",
  "2",
  "3",
  "q",
  "w",
  "e",
  "a",
  "s",
  "d",
  "z",
  "c",
  "4",
  "r",
  "f",
  "v",
};

boolean[] held = new boolean[16];

class chip {
  // general int arrays
  int[] memory = new int[4096];
  int[] stack = new int[16];
  int[] reg = new int[16];
  
  int[] fb = new int[2048];
  
  // schip exclusive
  int[] flags = new int[16];
   
  // xochip exclusive
  int[] colors = {0x1a,0x1c,0x2c,0xf4,0xf4,0xf4,0x94,0xb0,0xc2,0x33,0x3c,0x57,0xb1,0x3e,0x53,0xa7,0xf0,0x70,0x3b,0x5d,0xc9,0xff,0xcd,0x75,0x5d,0x27,0x5d,0x38,0xb7,0x64,0x29,0x36,0x6f,0x56,0x6c,0x86,0xef,0x7d,0x57,0x73,0xef,0xf7,0x41,0xa6,0xf6,0x25,0x71,0x79}; // colors of the display dependent on what bits are enabled.
  
  // pointers
  int pc = 0x200;
  int sp = 0x0;
  int i = 0x0000;
  
  // counters
  int dt = 0;
  int st = 0;
  
  // beeper speaker
  AudioSample sound;
  
  // very very cool display
  PGraphics display = createGraphics(64,32);
  
  // quirks
  boolean vfreset = false;
  boolean shifting = false;
  boolean dispwait = false;
  boolean clipping = false;
  boolean incr = true;
  
  // xochip exclusive
  int pselect = 1;
  
  // cycle rate
  int cycles = 200000;
}

void setup() {
  size(384,192);
  
  noSmooth();
  
  background(0);
  
  surface.setTitle("AuChip8 - v0.0.2");
  surface.setResizable(true);
  surface.setLocation(100, 100);
  
  selectInput("Select a file to load into the interpreter", "FileInput");
  
  au = new chip();
  au.display.beginDraw();
  au.display.background(color(au.colors[0],au.colors[1],au.colors[2]));
  
  au.sound = new AudioSample(this, 128, 44100);
  
  // default sound
  for(int i = 0; i<au.sound.frames(); i++){
    au.sound.write(i, sin(i/64) + sin(18*i/64)/18);
  }
}

void draw() {
  for(int i = 0; i < au.cycles; i++)next();
  
  if(au.dt>0)au.dt--;
  if(au.st>0){
    au.st--;
    if(!au.sound.isPlaying())au.sound.loop();
  }else{
    au.sound.stop();
  }
  
  au.display.loadPixels();
  
  for(int i = 0; i < au.display.pixels.length; i++){
    int r = au.colors[au.fb[i] * 3];
    int g = au.colors[au.fb[i] * 3 + 1];
    int b = au.colors[au.fb[i] * 3 + 2];
    
    au.display.pixels[i] = color(r,g,b);
  }
  
  au.display.updatePixels();
  
  key = ' ';
  
  image(au.display,0,0,width,height);
}

void next() {
  int op = (au.memory[au.pc] << 8) + au.memory[au.pc + 1];
  int v1000 = (op & 0xF000) >> 12;
  int v0100 = (op & 0xF00) >> 8;
  int v0010 = (op & 0xF0) >> 4;
  int v0001 = op & 0xF;
  int v0011 = op & 0xFF;
  int v0111 = op & 0xFFF;
  
  au.pc = (au.pc + 2) % au.memory.length;
  
  int nxt = (au.memory[au.pc] << 8) + au.memory[au.pc + 1];
  
  int tmp = 0;
  
  //print(op+",");
  
  switch(v1000){
    case 0x0:
      switch(v0011){
        case 0xe0:
          for(int i = 0; i < au.fb.length; i++){
            au.fb[i] = au.fb[i] & (au.pselect ^ 0b1111);
          }
        break;
        
        case 0xee:
          au.sp = (au.sp - 1) & 0xF;
          au.pc = au.stack[au.sp];
        break;
        
        case 0xfb:
          for(int i = 0; i < 4; i++){
            for(int p = 0; p < au.display.height; p++){
              int posY = (p % au.display.height) * au.display.width;
              for(int o = au.display.width - 1; o >= 0; o--){
                int posX = o;
                if(posX < au.display.width){
                  if(posX==0){
                    au.fb[posX+posY] &= au.pselect ^ 0b1111;
                  }else{
                    au.fb[posX+posY] = au.fb[posY+(posX-1)%au.display.width];
                  }
                }
              }
            }
          }
        break;
        
        case 0xfc:
          for(int i = 0; i < 4; i++){
            for(int p = 0; p < au.display.height; p++){
              int posY = (p % au.display.height) * au.display.width;
              for(int o = 0; o < au.display.width; o++){
                int posX = o % au.display.width;
                if(posX == 0){
                  au.fb[posX+posY] &= au.pselect ^ 0b1111;
                }else{
                  au.fb[posX+posY] = au.fb[posY + (posX + 1) % au.display.width]; //& au.pselect;
                }
              }
            }
          }
        break;
        
        case 0xfe:
          au.display.endDraw();
          au.display = createGraphics(64,32);
          au.display.beginDraw();
          au.display.loadPixels();
          au.fb = new int[2048];
        break;
        
        case 0xff:
          au.display.endDraw();
          au.display = createGraphics(128,64);
          au.display.beginDraw();
          au.display.loadPixels();
          au.fb = new int[8192];
        break;
        
        default:
          //au.pc = (au.pc - 2) % au.memory.length;
          //if(op!=0x0000)println("UNIMPL, 0: "+hex(op,4));
        break;
      }
    break;
    
    case 0x1:
      au.pc = v0111;
    break;
    
    case 0x2:
      au.stack[au.sp] = au.pc;
      au.sp = (au.sp + 1) & 0xF;
      au.pc = v0111;
    break;
    
    case 0x3:
      if(au.reg[v0100] == v0011){
        au.pc += 2;
        if(nxt == 0xF000) au.pc += 2;
        au.pc %= au.memory.length;
      }
    break;
    
    case 0x4:
      if(au.reg[v0100] != v0011){
        au.pc += 2;
        if(nxt == 0xF000) au.pc += 2;
        au.pc %= au.memory.length;
      }
    break;
    
    case 0x5:
      int range = Math.abs(v0010-v0100);
      switch(v0001){
        case 0x0:
          if(au.reg[v0100] == au.reg[v0010]){
            au.pc += 2;
            if(nxt == 0xF000) au.pc += 2;
            au.pc %= au.memory.length;
          }
        break;
        
        case 0x2:
          if(v0100 < v0010){
            for(int i = 0; i <= range; i++){
              au.memory[(au.i + i) % au.memory.length] = au.reg[i+v0100];
            }
          } else {
            for(int i = 0; i <= range; i++){
              au.memory[(au.i + i) % au.memory.length] = au.reg[v0100-i];
            }
          }
        break;
        
        case 0x3:
          if(v0100 < v0010){
            for(int i = 0; i <= range; i++){
              au.reg[i+v0100] = au.memory[(au.i + i) % au.memory.length];
            }
          } else {
            for(int i = 0; i <= range; i++){
              au.reg[v0100-i] = au.memory[(au.i + i) % au.memory.length];
            }
          }
        break;
        
        default:
          au.pc = (au.pc - 2) % au.memory.length;
          println("UNIMPL, 8: "+hex(op,4));
        break;
      }
    break;
    
    case 0x6:
      au.reg[v0100] = v0011;
    break;
    
    case 0x7:
      au.reg[v0100] = (au.reg[v0100] + v0011) & 0xFF;
    break;
    
    case 0x8:
      switch(v0001){
        case 0x0:
          au.reg[v0100] = au.reg[v0010];
        break;
        
        case 0x1:
          au.reg[v0100] |= au.reg[v0010];
          if(au.vfreset) au.reg[15] = 0;
        break;
        
        case 0x2:
          au.reg[v0100] &= au.reg[v0010];
          if(au.vfreset) au.reg[15] = 0;
        break;
        
        case 0x3:
          au.reg[v0100] ^= au.reg[v0010];
          if(au.vfreset) au.reg[15] = 0;
        break;
        
        case 0x4:
          tmp = au.reg[v0100] + au.reg[v0010];
          au.reg[v0100] = tmp & 0xFF;
          if(tmp > 0xFF){
            au.reg[15] = 1;
          } else {
            au.reg[15] = 0;
          }
        break;
        
        case 0x5:
          tmp = au.reg[v0100] - au.reg[v0010];
          au.reg[v0100] = tmp & 0xFF;
          if(tmp < 0x00){
            au.reg[15] = 0;
          } else {
            au.reg[15] = 1;
          }
        break;
        
        case 0x6:
          if(au.shifting){
            tmp = au.reg[v0100];
          } else {
            tmp = au.reg[v0010];
          }
          au.reg[v0100] = tmp >> 1;
          au.reg[15] = tmp & 0x1;
        break;
        
        case 0x7:
          tmp = au.reg[v0010] - au.reg[v0100];
          au.reg[v0100] = tmp & 0xFF;
          if(tmp < 0x00){
            au.reg[15] = 0;
          } else {
            au.reg[15] = 1;
          }
        break;
        
        case 0xe:
          if(au.shifting){
            tmp = au.reg[v0100];
          } else {
            tmp = au.reg[v0010];
          }
          au.reg[v0100] = (tmp << 1) & 0xFF;
          au.reg[15] = tmp >> 7;
        break;
        
        default:
          au.pc = (au.pc - 2) % au.memory.length;
          println("UNIMPL, 8: "+hex(op,4));
        break;
      }
    break;
    
    case 0x9:
      if(au.reg[v0100] != au.reg[v0010]){
        au.pc += 2;
        if(nxt == 0xF000) au.pc += 2;
        au.pc %= au.memory.length;
      }
    break;
    
    case 0xa:
      au.i = v0111;
    break;
    
    case 0xb:
      au.pc = (v0111 + au.reg[0]) % au.memory.length;
    break;
    
    case 0xc:
      au.reg[v0100] = (int)Math.round((Math.random() * 255)) & v0011;
    break;
    
    case 0xd:
      // TODO: display wait
      
      //drawSprite(au.reg[v0100],au.reg[v0010],v0001,au.i);
      //if(true)break;
      
      int ir = au.i;
      
      int x = au.reg[v0100];
      int y = au.reg[v0010];
      int w = 8;
      int h = v0001;
      
      if(h == 0){
        h = 16;
        w = 16;
      }
      
      au.reg[15] = 0;
      
      for(int p = 0; p < 4; p++){
        for(int i = 0; i < h; i++){
          int py = y + i;
          if(!au.clipping) py %= au.display.height;
          
          int row = au.memory[(ir + i) % au.memory.length];
          if(w == 16)row = (au.memory[(ir + i * 2) % au.memory.length] << 8) + au.memory[(ir + i * 2 + 1) % au.memory.length];
          
          for(int o = 0; o < w; o++) {
            int px = x + o;
            if(!au.clipping) px %= au.display.width;
            
            int pl = (row >> (w - 1 - o)) & 0x1;
            
            if(pl == 1){
              if(au.clipping){
                if(px >= au.display.width && py >= au.display.height) {
                  break;
                }
              }
              
              if(((au.pselect >> p) & 0x1) == 1){
                if((au.fb[px + py * au.display.width] & au.pselect) > 0)au.reg[15] = 1;
                au.fb[px + py * au.display.width] ^= 1<<p;
              }
            }
          }
        }
        if(w == 16){
          if(((au.pselect >> p) & 0x1) == 1){
            ir = (ir + h * 2) % au.memory.length;
          }
        }else{
          if(((au.pselect >> p) & 0x1) == 1){
            ir = (ir + h) % au.memory.length;
          }
        }
      }
    break;
    
    case 0xe:
      switch(v0011){
        case 0x9e:
          if(held[au.reg[v0100]&0xF]){
            au.pc += 2;
            if(nxt == 0xF000) au.pc += 2;
            au.pc %= au.memory.length;
          }
        break;
        
        case 0xa1:
          if(!held[au.reg[v0100]&0xF]){
            au.pc += 2;
            if(nxt == 0xF000) au.pc += 2;
            au.pc %= au.memory.length;
          }
        break;
        
        default:
          au.pc = (au.pc - 2) % au.memory.length;
          println("UNIMPL, E: "+hex(op,4));
        break;
      }
    break;
    
    case 0xf:
      switch(v0011){
        case 0x00:
          au.i = (au.memory[au.pc] << 8) + au.memory[au.pc + 1];
          au.pc = (au.pc + 2) % au.memory.length;
        break;
        
        case 0x01:
          au.pselect = v0100;
        break;
        
        case 0x02:
        
          for(int i = 0; i<au.sound.frames(); i++){
            int memory = (au.memory[(au.i+floor(i/8))&0xFFFF]>>(7-(i%8)))&0x1;
            au.sound.write(i,memory);
          }
          if(au.st==0){
            au.sound.cue(0);
          }
        break;
        
        case 0x07:
          au.reg[v0100] = au.dt;
        break;
        
        case 0x0a:
          int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
          if(keyFound==-1){
            au.pc = (au.pc - 2) % au.memory.length;
            break;
          }
          if(held[keyFound]){
            au.pc = (au.pc - 2) % au.memory.length;
            break;
          }
          au.reg[v0100] = keyFound;
          key = ' ';
        break;
        
        case 0x15:
          au.dt = au.reg[v0100];
        break;
        
        case 0x18:
          au.st = au.reg[v0100];
        break;
        
        case 0x1e:
          au.i = (au.i + au.reg[v0100]) % au.memory.length;
        break;
        
        case 0x29:
          au.i = (au.reg[v0100] & 0xF) * 5;
        break;
        
        case 0x30:
          au.i = (au.reg[v0100] & 0xF) * 10 + 80;
        break;
        
        case 0x33:
          au.memory[au.i] = (au.reg[v0100] / 100) % 10;
          au.memory[(au.i + 1) % au.memory.length] = (au.reg[v0100] / 10) % 10;
          au.memory[(au.i + 2) % au.memory.length] = au.reg[v0100] % 10;
        break;
        
        case 0x3a:
          double rate = 4000 * Math.pow(2, (double)(au.reg[v0100] - 64) / 48);
          au.sound.rate((float)rate / 44100);
        break;
        
        case 0x55:
          for(int i = 0; i <= v0100; i++){
            au.memory[(au.i + i) % au.memory.length] = au.reg[i];
          }
          if(au.incr) au.i = (au.i + v0100 + 1) % au.memory.length;
        break;
        
        case 0x65:
          for(int i = 0; i <= v0100; i++){
            au.reg[i] = au.memory[(au.i + i) % au.memory.length];
          }
          if(au.incr) au.i = (au.i + v0100 + 1) % au.memory.length;
        break;
        
        case 0x75:
          for(int i = 0; i <= v0100; i++){
            au.flags[i] = au.reg[i];
          }
        break;
        
        case 0x85:
          for(int i = 0; i <= v0100; i++){
            au.reg[i] = au.flags[i];
          }
        break;
        
        default:
          au.pc = (au.pc - 2) % au.memory.length;
          println("UNIMPL, F: "+hex(op,4));
        break;
      }
    break;
    
    default:
      println("UNIMPL: "+hex(op,4));
    break;
  }
}

void drawSprite(int VX, int VY, int N, int I) {
    if (au.pselect==0) {
        au.reg[0xF] = 0;
        return;
    }
    
    VX &= au.display.width  - 1;
    VY &= au.display.height - 1;
    au.reg[0xF] = 0;

    boolean wide = (N == 0);
    N = VY + (wide ? 16 : N);

    for (int mask = 1; mask <= 0x8; mask <<= 1) {
        if ((mask & au.pselect)==0) continue;

        for (int H = VY; H < N; ++H) {
            if (au.clipping && H >= au.display.height) break;

            int Y = (H & au.display.height - 1) * au.display.width;

            drawByte(VX + 0, Y, au.memory[I++], mask);
            if (!wide) continue;
            drawByte(VX + 8, Y, au.memory[I++], mask);
        }
    }
}

void drawByte(int dX, int dY, int data, int mask) {
    for (int W = 0; W < 8; ++W) {
        int X = dX + W;
        if (au.clipping && X >= au.display.width) break;
        X &= au.display.width - 1;

        if ((data >> (7 - W) & 0x1)==0) continue;

        int pxPos = dY + X;
        if ((au.fb[pxPos] & mask)>0) au.reg[0xF] = 1;
        au.fb[pxPos] ^= mask;
    }
}

void keyPressed() {
  int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
  if(keyFound>=0)held[keyFound] = true;
}

void keyReleased() {
  int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
  if(keyFound>=0)held[keyFound] = false;
}

void FileInput(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel, reopen prompt.");
    surface.setTitle("Please select a file.");
    selectInput("Select a file to load into the interpreter", "FileInput");
  }else{
    
    String[] path = split(selection.toString(),'\\');
    String type = split(selection.toString(),'.')[1].toLowerCase();
    
    byte file[] = loadBytes(selection);
    
    if(type.equals("xo8")){
      au.memory = new int[0x10000];
    }
    
    if(file.length>au.memory.length){
      println("File too big, reopen prompt.");
      surface.setTitle("AuChip8 - v0.0.2 - File is too big.");
      selectInput("Select a file to load into the intedrpreter", "FileInput");
      return;
    }
    
    surface.setTitle("AuChip8 - v0.0.2 - "+path[path.length-1]);
    
    int[] font = {0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70, 0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0, 0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0, 0xF0, 0x80, 0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40, 0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0, 0xF0, 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80};
    int[] sFont = {0x3C,0x7E,0xE7,0xC3,0xC3,0xC3,0xC3,0xE7,0x7E,0x3C,0x18,0x78,0x78,0x18,0x18,0x18,0x18,0x18,0xFF,0xFF,0x7E,0xFF,0xC3,0x03,0x07,0x1E,0x78,0xE0,0xFF,0xFF,0x7E,0xFF,0xC3,0x03,0x0E,0x0E,0x03,0xC3,0xFF,0x7E,0xC3,0xC3,0xC3,0xC3,0xFF,0x7F,0x03,0x03,0x03,0x03,0xFF,0xFF,0xC0,0xC0,0xFE,0x7F,0x03,0x03,0xFF,0xFE,0x7F,0xFF,0xC0,0xC0,0xFE,0xFF,0xC3,0xC3,0xFF,0x7E,0xFF,0xFF,0x03,0x03,0x07,0x0E,0x1C,0x18,0x18,0x18,0x7E,0xFF,0xC3,0xC3,0x7E,0x7E,0xC3,0xC3,0xFF,0x7E,0x7E,0xFF,0xC3,0xC3,0xFF,0x7F,0x03,0x07,0x7E,0x7C,0x18,0x3C,0x7E,0xE7,0xC3,0xC3,0xFF,0xFF,0xC3,0xC3,0xFE,0xFF,0xC3,0xC3,0xFE,0xFE,0xC3,0xC3,0xFF,0xFE,0x3F,0x7F,0xE0,0xC0,0xC0,0xC0,0xC0,0xE0,0x7F,0x3F,0xFC,0xFE,0xC7,0xC3,0xC3,0xC3,0xC3,0xC7,0xFE,0xFC,0x7F,0xFF,0xC0,0xC0,0xFF,0xFF,0xC0,0xC0,0xFF,0x7F,0x7F,0xFF,0xC0,0xC0,0xFF,0xFF,0xC0,0xC0,0xC0,0xC0,};
    
    // just in case
    for(int i = 0; i < au.memory.length; i++){
      au.memory[i] = 0;
    }
    
    // fill memory with font and program
    for(int i = 0; i < file.length; i++){
      au.memory[i+0x200] = file[i] & 0xFF;
    }
    for(int i = 0; i < font.length; i++){
      au.memory[i] = font[i];
    }
    for(int i = 0; i < sFont.length; i++){
      au.memory[i+80] = sFont[i];
    }
    
    au.sp = 0;
    au.i = 0;
    au.pc = 0x200;
  }
}
