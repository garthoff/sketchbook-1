// TODO: replace EEPROM with FRAM so can store each count change

#include <EEPROM.h>
#include <Wire.h>

// ===eeprom stuff===
#define DEV_ADDR 0x50 //eeprom addr
const char HASH[] = "812500507"; // eeprom hash
const int tenthADDR = 10; // Address in EEPROM
const int odomADDR = 20;

// ===Serial2parallel===
int latchPin = 11; //ST_CP of 74HC595
int clockPin = 10; //SH_CP of 74HC595
int dataPin = 12; // DS of 74HC595

// ===Motorbike operations===
int ignition = 13;
int modePin = 7; // In parking mode or not
int parkPin = 6; // use parking light circuits
int normPin = 5; // use normal operation circuits

// ===2digit 7segment===
int val1pin = 3; // segment 1
int val2pin = 4; // segment 2
boolean seg1 = true;
boolean seg2 = false;
// values required per integer to be shown on 7seg
//const int array[] = {64,118,33,36,22,12,8,102,0,6}; // Common anode vals
const int array[] = {63,12,91,94,108,118,119,28,127,124,0}; // Common cathode vals. '0' is to blank 7seg


volatile int splitcnt=0,tenth,velo = 0; // speed 
volatile unsigned int count,dist; // odometer
volatile unsigned long splitvelo=0,split=0, oldtime = 0; // the millis time of last interrupt

int oldtenth;
unsigned int olddist;


void i2c_eeprom_write_byte(unsigned int eeaddress, byte data ) {
  int rdata = data;
  Wire.beginTransmission(0x50);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.send(rdata);
  Wire.endTransmission();
  delay(3);
}

byte i2c_eeprom_read_byte(unsigned int eeaddress ) {
  byte rdata = 0xFF;
  Wire.beginTransmission(DEV_ADDR);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.endTransmission();
  Wire.requestFrom(DEV_ADDR,1);
  if (Wire.available()) rdata = Wire.receive();
    return rdata;
  
}


// checks to see if the hash n the eeprom matches the constant
boolean check_hash(){  
  static int addr = 0;
  byte b = i2c_eeprom_read_byte(addr);
  while (b != 0){
    if (b != HASH[addr])
      return false;
    addr++;
    b = i2c_eeprom_read_byte(addr);
  }
  return true;
}

void segment(int val) { 
  digitalWrite(latchPin, LOW); 
  shiftOut(dataPin, clockPin, MSBFIRST, array[val]);  
  digitalWrite(latchPin, HIGH);
}

void serialsegments(int val) {  
  // 4 digit display
  Serial.print(val / 1000, BYTE);
  Serial.print((val / 100) % 10, BYTE);
  Serial.print((val / 10) % 10, BYTE);
  Serial.print(val % 10, BYTE);
  
}

void speeddisp(int val) {
  // will only update 1 segment (multiplexing)
  seg1 = !seg1;
  seg2 = !seg2;
  // this is needed to prevent bleeding over to next digit. It blanks
  // the shifter outputs
  segment(10); 
  if ( seg1 != true) {
    digitalWrite(val2pin, LOW);
    digitalWrite(val1pin, HIGH);
    segment(val / 10);
  }
  // the smallest number
  else {
    digitalWrite(val1pin, LOW);
    digitalWrite(val2pin, HIGH);
    segment(val % 10);
  }
}    

void calculations(void) {
  unsigned int calc = 0;
  unsigned long gap = 0;
  unsigned long now;

  now = millis();
  gap = now - oldtime; 
  // 2437 is a constant to get to mph 
  // because it's not float, can be =<1mph out (rounding error)
  calc = 2437/gap; 
  
  // do not want to update speed every interrupt (too fast)
  if ( (now - split) > 333 ){       
    // the display will only show up to 99
    if (  calc > 99 ){
      velo = 99;
    }
    else {
      velo = calc;
    }
    split = now;
  }
  oldtime = now;

  // Odometer calculations
  // 4641 triggers per mile based
  // on wheel circumference
  // Would be a total of 100k writes per 10,000miles (max of display)
  // 100k is max erase/write cycles of At168 (datasheet)
  if (count > 1477) {
    if (dist >= 9999){
      dist = 0;
    }
    else{
      dist += 1;
    }

    serialsegments(dist);
    tenth = 0;
    count = 0;
  }
  // update eeprom with a 1/10th mile val
  else {
    // I think it's more efficent to do
    // this rather than maths like modulu and rem
    // counts per mile = 1601/(pi*D)
    switch ( count ) {
      case 148:
        tenth = 1;
        break;
      case 295:
        tenth = 2;
        break;
      case 443:
        tenth = 3;
        break;
      case 591:
        tenth = 4;
        break;
      case 739:
        tenth = 5;
        break;
      case 886:
        tenth = 6;
        break;
      case 1034:
        tenth = 7;
        break;
      case 1182:
        tenth = 8;
        break;
      case 1329:
        tenth = 9;
        break;
    }
    count += 1;
  }
  
}


void setup() {
  unsigned int lsb,msb;
  //set pins to output so you can control the shift register
  Wire.begin();
  
  // outputs that are crucial in preventing
  // unsecure use (e.g. no key)
  pinMode(ignition, OUTPUT);
  pinMode(parkPin, OUTPUT);
  pinMode(normPin, OUTPUT);
  
  // If the hash in the keyfob(eeprom) does not 
  // read correctly, wait forever  
  while ( check_hash() == false ){
    digitalWrite(ignition, HIGH); // ensure ignition is disabled
    digitalWrite(parkPin, LOW); // ensure lights are off
    digitalWrite(normPin, LOW); // ensure lights are off
    digitalWrite(val1pin, HIGH);
    digitalWrite(val2pin, HIGH);
    delay(1000);
  }
  // enable ignition
  digitalWrite(ignition, LOW);
  
  pinMode(latchPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  pinMode(dataPin, OUTPUT);
  pinMode(val1pin, OUTPUT);
  pinMode(val2pin, OUTPUT);
  
  // the odometer values
  tenth = i2c_eeprom_read_byte(10);
  oldtenth = tenth;
  count = tenth * 464; // counts since last mile
  lsb = i2c_eeprom_read_byte(21);
  msb = i2c_eeprom_read_byte(20) ;
  dist = (msb << 8) | lsb;
  olddist = dist;
  
  Serial.begin(57600); // Highest ser-disp will allow
  Serial.print('v'); // reset to '0000'
  serialsegments(dist);

  attachInterrupt(0, calculations, CHANGE); // pin 3
}

void loop() {
  boolean halt = false;
  // The only thing that needs to run all
  // the time as the 7segs are being multiplexed
  speeddisp(velo);
  
  // mode
  if ( digitalRead(modePin) == LOW ) {
    digitalWrite(normPin, HIGH);
    digitalWrite(parkPin, LOW);
  }
  else{
    digitalWrite(normPin, LOW);
    digitalWrite(parkPin, HIGH);   
  }
  
  // If the check_hash() interrupts the display
  // i'm not seeing it
  while (check_hash() == false){
    halt = true;
    detachInterrupt(0); // make sure odometer does nowt
    
    digitalWrite(ignition, HIGH); // disable ignition
    digitalWrite(parkPin, LOW);
    digitalWrite(normPin, LOW); 
    digitalWrite(val1pin, LOW);
    digitalWrite(val2pin, LOW);
    // maybe blank instead if in park mode
    for(int z=0;z<4;z++){
      Serial.print('-',BYTE);
    }
    
  }
  // to prevent unnecesary calls
  if ( halt == true ){
    halt = false;
    attachInterrupt(0, calculations, CHANGE); //re-enable the odometer functionality
    digitalWrite(ignition, LOW); // turn ignition back on
    serialsegments(dist);    
  }

  // This is the place to write to the i2ceeprom
  // wire.h does not like isr
  if (dist != olddist){    
    // eeprom stuff
    olddist = dist;
    int lsb,msb;
    msb = dist >> 8;
    lsb = dist & 0xFF;
    i2c_eeprom_write_byte(odomADDR,msb);
    i2c_eeprom_write_byte((odomADDR + 1),lsb);
    i2c_eeprom_write_byte(tenthADDR,0); // must mean tenth has zeroed as well
  }
  else if (tenth != oldtenth){    
    // eeprom stuff
    oldtenth = tenth;
    i2c_eeprom_write_byte(tenthADDR,tenth);
  }
}
