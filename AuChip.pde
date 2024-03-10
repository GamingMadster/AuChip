import processing.sound.*;

AudioSample beeper;
boolean beepStart = false;

VM chip;

class VM {
  int PC = 0x200;
  int SP = 0;
  int I = 0;
  int DT = 0;
  int ST = 0;
  boolean DREW = false;
  int[] registers = new int[16];
  int[] flags = new int[16];
  int[] stack = new int[16];
  int[] memory = new int[4096];
  float soundRate = 10;
  int[] chipPlane1 = new int[2048];
  int[] chipPlane2 = new int[2048];
  
  
  color[] colors = {color(0,0,0),color(255,255,255),color(170,170,170),color(85,85,85)};
  
  
  int planeSelect = 1;
  PGraphics display = createGraphics(64,32);
}

// variants
boolean SuperChip = false;
boolean XoChip = false;

// quirks
boolean wOverride = false;
boolean Wrapping = true;

int Speed = 15;

// other
ArrayList<String> logs = new ArrayList<String>();

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

void keyPressed() {
  int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
  if(keyFound>=0)held[keyFound] = true;
  
  String[] temp = new String[logs.size()];
  logs.toArray(temp);
  
  if(key=='p')saveStrings("auchiplog.txt",temp);
}

void keyReleased() {
  int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
  if(keyFound>=0)held[keyFound] = false;
}

void setup() {
  size(384,192);
  
  noSmooth();
  
  surface.setTitle("AuChip8 - v0.0.1");
  surface.setResizable(true);
  surface.setLocation(100, 100);
  
  selectInput("Select a file to load into the interpreter", "FileInput");
  
  chip = new VM();
  chip.display.beginDraw();
  
  beeper = new AudioSample(this, 128, 4096);
  
  for(int i = 0; i<beeper.frames(); i++){
    beeper.write(i,sin(i/64) + sin(18*i/64)/18);
  }
  beeper.amp(0.1);
  
  if(!wOverride)Wrapping = false;
  
  if(SuperChip)Speed=30;
  if(XoChip){
    Speed = 100000;
    SuperChip = true;
    chip.memory = new int[65536];
    if(!wOverride)Wrapping = true;
  }
}

void draw() {
  for(int i = 0; i<Speed; i++){
    int op = FetchOp();
    Execute(op);
  }
  
  chip.DREW = false;
  
  key = ' ';
  
  if(chip.DT>0)chip.DT--;
  if(chip.ST>0){
    chip.ST--;
    beeper.rate(chip.soundRate);
    if(!beepStart){
      beeper.loop();
      beepStart = true;
    }
  }else{
    chip.soundRate = 10;
    beepStart = false;
    beeper.stop();
    beeper.cue(0);
  }
  
  drawDisplay();
}

int FetchOp() {
  int op = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
  chip.PC+=2;
  return op;
}

void Execute(int op) {
  int v1000 = (op&0xF000)/0x1000;
  int v0100 = (op&0x0F00)/0x100;
  int v0010 = (op&0x00F0)/0x10;
  int v0001 = op&0x000F;
  int v0011 = op&0x00FF;
  int v0111 = op&0x0FFF;
  
  int enabled1 = chip.planeSelect & 1;
  int enabled2 = chip.planeSelect >> 1;
  
  int bitmask = 0xFFF;
  if(XoChip)bitmask = 0xFFFF;
  
  //logs.add("OP: "+hex(op,4)+" - PC: "+hex(chip.PC-2,4));
  
  switch(v1000){
    case 0x0:
      if(v0011==0x00){
        chip.PC-=2;
      }
      if(v0011==0xE0){
        if(enabled1==1){
          for(int i = 0; i<chip.chipPlane1.length; i++){
            chip.chipPlane1[i] = 0;
          }
        }
        if(enabled2==1){
          for(int i = 0; i<chip.chipPlane2.length; i++){
            chip.chipPlane2[i] = 0;
          }
        }
      }
      if(v0011==0xEE){
        chip.SP--;
        chip.PC = chip.stack[chip.SP];
      }
      
      // super chip instructions
      if(SuperChip){
        if(v0010==0x0C){
          for(int i = 0; i<v0001; i++){
            for(int p = chip.display.height-1; p>=0; p--){
              int posY = p*chip.display.width;
              for(int o = 0; o<chip.display.width; o++){
                int posX = o%chip.display.width;
                if(enabled1==1){
                  if(p==0){
                    chip.chipPlane1[posX+posY] = 0;
                  }else{
                    chip.chipPlane1[posX+posY] = chip.chipPlane1[posX+(posY-chip.display.width)&chip.chipPlane1.length-1];
                  }
                }
                if(enabled2==1){
                  if(p==0){
                    chip.chipPlane2[posX+posY] = 0;
                  }else{
                    chip.chipPlane2[posX+posY] = chip.chipPlane2[posX+(posY-chip.display.width)&chip.chipPlane2.length-1];
                  }
                }
              }
            }
          }
        }
        if(v0011==0xFB){
          for(int i = 0; i<4; i++){
            for(int p = 0; p<chip.display.height; p++){
              int posY = (p%chip.display.height)*chip.display.width;
              for(int o = chip.display.width-1; o>=0; o--){
                int posX = o;
                if(posX<chip.display.width){
                  if(enabled1==1){
                    if(posX==0){
                      chip.chipPlane1[posX+posY] = 0;
                    }else{
                      chip.chipPlane1[posX+posY] = chip.chipPlane1[posY+(posX-1)%chip.display.width];
                    }
                  }
                  if(enabled2==1){
                    if(posX==0){
                      chip.chipPlane2[posX+posY] = 0;
                    }else{
                      chip.chipPlane2[posX+posY] = chip.chipPlane2[posY+(posX-1)%chip.display.width];
                    }
                  }
                }
              }
            }
          }
        }
        if(v0011==0xFC){
          for(int i = 0; i<4; i++){
            for(int p = 0; p<chip.display.height; p++){
              int posY = (p%chip.display.height)*chip.display.width;
              for(int o = 0; o<chip.display.width; o++){
                int posX = o%chip.display.width;
                if(enabled1==1){
                  if(posX==0){
                    chip.chipPlane1[posX+posY] = chip.chipPlane1[(posY)%chip.chipPlane1.length];
                  }else{
                    chip.chipPlane1[posX+posY] = chip.chipPlane1[posY+(posX+1)%chip.display.width];
                  }
                }
                if(enabled2==1){
                  if(enabled1==1){
                    if(posX==0){
                      chip.chipPlane2[posX+posY] = chip.chipPlane2[(posY)%chip.chipPlane2.length];
                    }else{
                      chip.chipPlane2[posX+posY] = chip.chipPlane2[posY+(posX+1)%chip.display.width];
                    }
                  }
                }
              }
            }
          }
        }
        if(v0011==0xFE){
          chip.display.endDraw();
          chip.display = createGraphics(64,32);
          chip.display.beginDraw();
          chip.chipPlane1 = new int[2048];
          chip.chipPlane2 = new int[2048];
        }
        if(v0011==0xFF){
          chip.display.endDraw();
          chip.display = createGraphics(128,64);
          chip.display.beginDraw();
          chip.chipPlane1 = new int[8192];
          chip.chipPlane2 = new int[8192];
        }
        if(XoChip){
          if(v0010==0x0D){
            for(int i = 0; i<v0001; i++){
              for(int p = 0; p<chip.display.height; p++){
                int posY = p*chip.display.width;
                for(int o = 0; o<chip.display.width; o++){
                  int posX = o%chip.display.width;
                  if(enabled1==1){
                    if(p==chip.display.height-1){
                      chip.chipPlane1[posX+posY] = 0;
                    }else{
                      chip.chipPlane1[posX+posY] = chip.chipPlane1[posX+(posY+chip.display.width)&chip.chipPlane1.length-1];
                    }
                  }
                  if(enabled2==1){
                    if(p==chip.display.height-1){
                      chip.chipPlane2[posX+posY] = 0;
                    }else{
                      chip.chipPlane2[posX+posY] = chip.chipPlane2[posX+(posY+chip.display.width)&chip.chipPlane2.length-1];
                    }
                  }
                }
              }
            }
          }
        }
      }
      break;
      
    case 0x1:
      chip.PC = v0111;
      break;
      
    case 0x2:
      chip.stack[chip.SP] = chip.PC;
      chip.SP=(chip.SP+1)&0xF;
      chip.PC = v0111;
      break;
      
    case 0x3:
      if(chip.registers[v0100]==v0011){
        int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
        chip.PC+=2;
        if(check==0xF000)chip.PC+=2;
      }
      break;
      
    case 0x4:
      if(chip.registers[v0100]!=v0011){
        int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
        chip.PC+=2;
        if(check==0xF000)chip.PC+=2;
      }
      break;
      
    case 0x5:
      if(v0001==0x0){
        if(chip.registers[v0100]==chip.registers[v0010]){
          int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
          chip.PC+=2;
          if(check==0xF000)chip.PC+=2;
        }
      }
      if(XoChip){
        if(v0001==0x02){
          for(int i = 0; i<=v0010-v0100; i++){
            chip.memory[(chip.I+i)&bitmask] = chip.registers[i+v0100];
          }
        }
        if(v0001==0x03){
          for(int i = 0; i<=v0010-v0100; i++){
             chip.registers[i+v0100] = chip.memory[(chip.I+i)&bitmask];
          }
        }
      }
      break;
      
    case 0x6:
      chip.registers[v0100] = v0011;
      break;
      
    case 0x7:
      chip.registers[v0100] = (chip.registers[v0100]+v0011)&0xFF;
      break;
      
    case 0x8:
      if(v0001==0x0)chip.registers[v0100] = chip.registers[v0010];
      if(v0001==0x1){
        chip.registers[v0100] = chip.registers[v0100] | chip.registers[v0010];
        if(!SuperChip) chip.registers[15] = 0;
      }
      if(v0001==0x2){
        chip.registers[v0100] = chip.registers[v0100] & chip.registers[v0010];
        if(!SuperChip) chip.registers[15] = 0;
      }
      if(v0001==0x3){
        chip.registers[v0100] = chip.registers[v0100] ^ chip.registers[v0010];
        if(!SuperChip) chip.registers[15] = 0;
      }
      
      if(v0001==0x4){
        int old = chip.registers[v0010]+chip.registers[v0100];
        chip.registers[v0100]=old&0xFF;
        if(old>255){
          chip.registers[15] = 1;
        }else{
          chip.registers[15] = 0;
        }
      }
      
      if(v0001==0x5){
        int old = chip.registers[v0100]-chip.registers[v0010];
        chip.registers[v0100]=old&0xFF;
        if(old<0){
          chip.registers[15] = 0;
        }else{
          chip.registers[15] = 1;
        }
      }
      
      if(v0001==0x7){
        int old = chip.registers[v0010]-chip.registers[v0100];
        chip.registers[v0100]=old&0xFF;
        if(old<0){
          chip.registers[15] = 0;
        }else{
          chip.registers[15] = 1;
        }
      }
      
      if(v0001==0x6){
        int old = chip.registers[v0010]&0x1;
        if(SuperChip&&!XoChip){
          chip.registers[v0100] = chip.registers[v0100]>>1;
        }else{
          chip.registers[v0100] = chip.registers[v0010]>>1;
        }
        chip.registers[15] = old;
      }
      
      if(v0001==0xE){
        int old = chip.registers[v0010]>>7;
        if(SuperChip&&!XoChip){
          chip.registers[v0100] = (chip.registers[v0100]<<1)&0xFF;
        }else{
          chip.registers[v0100] = (chip.registers[v0010]<<1)&0xFF;
        }
        chip.registers[15] = old;
      }
      break;
      
    case 0x9:
      if(chip.registers[v0100]!=chip.registers[v0010]){
        int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
        chip.PC+=2;
        if(check==0xF000)chip.PC+=2;
      }
      break;
      
    case 0xA:
      chip.I = v0111;
      break;
      
    case 0xB:
      if(SuperChip&&!XoChip){
        chip.PC = (v0111 + chip.registers[v0100])&0xFFF;
      }else{
        chip.PC = (v0111 + chip.registers[0])&0xFFF;
      }
      break;
      
    case 0xC:
      chip.registers[v0100] = round(random(255))&v0011;
      break;
      
    case 0xD:
      if(SuperChip){
        if(XoChip){
          chip.registers[15] = 0;
      
          int X = chip.registers[v0100]%chip.display.width;
          int Y = chip.registers[v0010]%chip.display.height;
          
          int W = 8;
          
          if(v0001==0){
            v0001 = 16;
            W = 16;
          }
          
          for(int i = 0; i<v0001*2; i++){
            int Pixels = chip.memory[(i+chip.I)&0xFFFF];
            
            if(W==16)Pixels = (chip.memory[((i%v0001)*2+chip.I)&0xFFFF]<<8)+chip.memory[((i%v0001)*2+1+chip.I)&0xFFFF];
            
            for(int o = 0; o<W; o++){
              int posX = X+o;
              int posY = Y+(i%v0001);
              
              if(Wrapping&&XoChip){
                posX = posX%chip.display.width;
                posY = posY%chip.display.height;
              }
              
              int pos = (posX%chip.display.width)+(posY%chip.display.height)*chip.display.width;
              int Pixel = (Pixels>>(W-1-o))&0x1;
              if(Pixel==1){
                if(posX<chip.display.width&&posY<chip.display.height){
                  if(Math.floor(i/v0001)==0){
                    if(enabled1==1){
                      if(chip.chipPlane1[pos]==1)chip.registers[15] = 1;
                      chip.chipPlane1[pos] ^= 1;
                    }
                  }else{
                    if(enabled2==1){
                      if(chip.chipPlane2[pos]==1)chip.registers[15] = 1;
                      chip.chipPlane2[pos] ^= 1;
                    }
                  }
                }
              }
            }
          }
        }else{
          chip.registers[15] = 0;
      
          int X = chip.registers[v0100]%chip.display.width;
          int Y = chip.registers[v0010]%chip.display.height;
          
          int W = 8;
          
          if(v0001==0){
            v0001 = 16;
            W = 16;
          }
          
          for(int i = 0; i<v0001; i++){
            int Pixels = chip.memory[(i+chip.I)%0xFFF];
            
            if(W==16)Pixels = (chip.memory[(i*2+chip.I)%0xFFF]<<8)+chip.memory[(i*2+1+chip.I)%0xFFF];
            
            for(int o = 0; o<W; o++){
              int posX = X+o;
              int posY = Y+i;
              
              if(Wrapping||XoChip){
                posX = posX%chip.display.width;
                posY = posY%chip.display.height;
              }
              
              int pos = (posX%chip.display.width)+(posY%chip.display.height)*chip.display.width;
              int Pixel = (Pixels>>(W-1-o))&0x1;
              if(Pixel==1){
                //if(chip.chipPlane1[pos])chip.registers[15] = 1;
                //chip.chipPlane1[pos] = !chip.chipPlane1[pos];
                if(posX<chip.display.width&&posY<chip.display.height){
                  if(chip.chipPlane1[pos]==1)chip.registers[15] = 1;
                  chip.chipPlane1[pos] ^= 1;
                }
              }
            }
          }
        }
      }else{
        if(chip.DREW){
          chip.PC-=2;
          break;
        }
        chip.registers[15] = 0;
      
        int X = chip.registers[v0100]%chip.display.width;
        int Y = chip.registers[v0010]%chip.display.height;
        
        for(int i = 0; i<v0001; i++){
          int Pixels = chip.memory[(i+chip.I)%0xFFF];
          
          for(int o = 0; o<8; o++){
            int posX = X+o;
            int posY = Y+i;
            int pos = posX+(posY)*chip.display.width;
            int Pixel = (Pixels>>(7-o))&0x1;
            if(Pixel==1){
              if(posX<chip.display.width&&posY<chip.display.height){
                if(chip.chipPlane1[pos]==1)chip.registers[15] = 1;
                chip.chipPlane1[pos] ^= 1;
              }
            }
          }
        }
        chip.DREW = true;
      }
      break;
      
    case 0xE:
      if(v0011==0x9E)if(held[chip.registers[v0100]&0xF]){
        int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
        chip.PC+=2;
        if(check==0xF000)chip.PC+=2;
      }
      if(v0011==0xA1)if(!held[chip.registers[v0100]&0xF]){
        int check = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
        chip.PC+=2;
        if(check==0xF000)chip.PC+=2;
      }
      break;
      
    case 0xF:
      if(v0011==0x07){
        chip.registers[v0100] = chip.DT;
      }
      if(v0011==0x0A){
        int keyFound = java.util.Arrays.asList(keys).indexOf(Character.toString(key));
        if(keyFound==-1){
          chip.PC-=2;
          break;
        }
        if(held[keyFound]){
          chip.PC-=2;
          break;
        }
        chip.registers[v0100] = keyFound;
      }
      if(v0011==0x15){
        chip.DT = chip.registers[v0100];
      }
      if(v0011==0x18){
        chip.ST = chip.registers[v0100];
      }
      if(v0011==0x1E)chip.I = (chip.I + chip.registers[v0100]) & bitmask;
      if(v0011==0x29){
        chip.I = ((chip.registers[v0100]) & 0xF) * 5;
      }
      if(v0011==0x33){
        int value = chip.registers[v0100];
        chip.memory[chip.I] = (value/100)%10;
        chip.memory[(chip.I+1)&bitmask] = (value/10)%10;
        chip.memory[(chip.I+2)&bitmask] = value%10;
      }
      if(v0011==0x55){
        for(int i = 0; i<=v0100; i++){
          chip.memory[(chip.I+i)&bitmask] = chip.registers[i];
        }
        if(!SuperChip||XoChip)chip.I = (chip.I + v0100 + 1)&bitmask;
      }
      if(v0011==0x65){
        for(int i = 0; i<=v0100; i++){
           chip.registers[i] = chip.memory[(chip.I+i)&bitmask];
        }
        if(!SuperChip||XoChip)chip.I = (chip.I + v0100 + 1)&bitmask;
      }
      if(SuperChip){
        if(v0011==0x30){
          chip.I = ((chip.registers[v0100]) & 0xF) * 10 + 80;
        }
        if(v0011==0x75){
          for(int i = 0; i<=v0100; i++){
             chip.flags[i] = chip.registers[i];
          }
        } 
        if(v0011==0x85){
          for(int i = 0; i<=v0100; i++){
             chip.registers[i] = chip.flags[i];
          }
        }
      }
      if(XoChip){
        if(v0111==0x000){
          chip.I = (chip.memory[chip.PC]<<8)+chip.memory[chip.PC+1];
          chip.PC+=2;
        }
        if(v0011==0x01){
          chip.planeSelect = v0100 % 4;
        }
        if(v0011==0x02){
          beeper.stop();
          beeper.cue(0);
          for(int i = 0; i<beeper.frames(); i++){
            int memory = (chip.memory[(chip.I+floor(i/8))&0xFFFF]>>(7-(i%8)))&0x1;
            beeper.write(i,memory*25);
          }
          beeper.loop();
        }
        if(v0011==0x3A){
          double rate = 4000*Math.pow(2,(double)(chip.registers[v0100]-64)/48);
          chip.soundRate = (float)rate/4096;
        }
      }
      break;
      
     default:
       println("UNKNOWN OP",v1000,hex(op,4));
       break;
  }
}

void drawDisplay() {
  chip.display.loadPixels();
  for(int i = 0; i<chip.display.pixels.length; i++){
    int enabled1 = chip.chipPlane1[i];
    int enabled2 = chip.chipPlane2[i];
    color given = chip.colors[(enabled2<<1)+enabled1];
    chip.display.pixels[i] = given;
  }
  chip.display.updatePixels();
  image(chip.display,0,0,width,height);
}

void FileInput(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel, reopen prompt.");
    surface.setTitle("Please select a file.");
    selectInput("Select a file to load into the interpreter", "FileInput");
  }else{
    logs = new ArrayList<String>();
    
    String[] path = split(selection.toString(),'\\');
    String type = split(selection.toString(),'.')[1].toLowerCase();
    
    byte file[] = loadBytes(selection);
    
    if(type.equals("ch8")){
      Speed = 15;
      SuperChip = false;
      XoChip = false;
      chip.memory = new int[4096];
    }
    if(type.equals("sc8")){
      Speed = 30;
      SuperChip = true;
      XoChip = false;
      chip.memory = new int[4096];
    }
    if(type.equals("xo8")){
      Speed = 200000;
      SuperChip = true;
      XoChip = true;
      chip.memory = new int[65536];
    }
    
    println(SuperChip,XoChip);
    
    if(file.length>chip.memory.length){
      println("File too big, reopen prompt.");
      surface.setTitle("File is too big.");
      selectInput("Select a file to load into the intedrpreter", "FileInput");
      return;
    }
    
    surface.setTitle("AuChip8 - v0.0.1 - "+path[path.length-1]);
    
    int[] font = {0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70, 0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0, 0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0, 0xF0, 0x80, 0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40, 0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0, 0xF0, 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80};
    int[] sFont = {0x3C,0x7E,0xE7,0xC3,0xC3,0xC3,0xC3,0xE7,0x7E,0x3C,0x18,0x78,0x78,0x18,0x18,0x18,0x18,0x18,0xFF,0xFF,0x7E,0xFF,0xC3,0x03,0x07,0x1E,0x78,0xE0,0xFF,0xFF,0x7E,0xFF,0xC3,0x03,0x0E,0x0E,0x03,0xC3,0xFF,0x7E,0xC3,0xC3,0xC3,0xC3,0xFF,0x7F,0x03,0x03,0x03,0x03,0xFF,0xFF,0xC0,0xC0,0xFE,0x7F,0x03,0x03,0xFF,0xFE,0x7F,0xFF,0xC0,0xC0,0xFE,0xFF,0xC3,0xC3,0xFF,0x7E,0xFF,0xFF,0x03,0x03,0x07,0x0E,0x1C,0x18,0x18,0x18,0x7E,0xFF,0xC3,0xC3,0x7E,0x7E,0xC3,0xC3,0xFF,0x7E,0x7E,0xFF,0xC3,0xC3,0xFF,0x7F,0x03,0x07,0x7E,0x7C,0x18,0x3C,0x7E,0xE7,0xC3,0xC3,0xFF,0xFF,0xC3,0xC3,0xFE,0xFF,0xC3,0xC3,0xFE,0xFE,0xC3,0xC3,0xFF,0xFE,0x3F,0x7F,0xE0,0xC0,0xC0,0xC0,0xC0,0xE0,0x7F,0x3F,0xFC,0xFE,0xC7,0xC3,0xC3,0xC3,0xC3,0xC7,0xFE,0xFC,0x7F,0xFF,0xC0,0xC0,0xFF,0xFF,0xC0,0xC0,0xFF,0x7F,0x7F,0xFF,0xC0,0xC0,0xFF,0xFF,0xC0,0xC0,0xC0,0xC0,
};

    // just in case
    for(int i = 0; i<chip.memory.length; i++){
      chip.memory[i] = 0;
    }
    
    for(int i = 0; i<file.length; i++){
      chip.memory[i+0x200] = file[i] & 0xFF;
    }
    
    for(int i = 0; i<font.length; i++){
      chip.memory[i] = font[i];
    }
    for(int i = 0; i<sFont.length; i++){
      chip.memory[i+80] = sFont[i];
    }
    
    chip.SP = 0;
    chip.I = 0;
    chip.PC = 0x200;
  }
}
