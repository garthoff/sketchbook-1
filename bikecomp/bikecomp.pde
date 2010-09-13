#include <EEPROM.h>
#include <Wire.h>
#define DEV_ADDR 0x50 //eeprom addr
const char HASH[] = "812500507"; // eeprom hash
// values required per integer to be shown on 7seg
const int array[] = {64,118,33,36,22,12,8,102,0,6}; 

int latchPin = 11; //ST_CP of 74HC595
int clockPin = 10; //SH_CP of 74HC595
int dataPin = 12; // DS of 74HC595
int ignition = 9;


int val1pin = 3; // segment 1
int val2pin = 4; // segment 2

boolean seg1 = true;
boolean seg2 = false;

volatile int velo = 0; // speed 
volatile unsigned int count,dist; // odometer
volatile unsigned long oldtime = 0; // the millis time of last interrupt

void i2c_eeprom_write_byte(unsigned int eeaddress, byte data ) {
  int rdata = data;
  Wire.beginTransmission(0x50);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.send(rdata);
  Wire.endTransmission();
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
  Serial.print(val / 1000, BYTE);
  Serial.print((val / 100) % 10, BYTE);
  Serial.print((val / 10) % 10, BYTE);
  Serial.print(val % 10, BYTE);
  
}

void speeddisp(int val) {
  // will only update 1 segment (multiplexing)
  seg1 = !seg1;
  seg2 = !seg2;
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
  // delay is needed otherwise the 7segs do not
  // turn off quick enough (aliasing?) 
  delay(5);
}    

void calculations(void) {
  unsigned long gap = 0;
  unsigned long now;
  unsigned int calc = 0;
  int tenth = 0;

  now = millis();
  gap = now - oldtime; 
  // 2437 is a constant to get to mph 
  calc = 2437/gap;
  
  // the display will only show up to 99
  if (  calc > 99 ){
    velo = 99;
  }
  else {
    velo = calc;
  }
  
  oldtime = now;

  // Odometer calculations
  // 4641 triggers per mile based
  // on wheel circumference
  // Would be a total of 100k writes per 10,000miles (max of display)
  // 100k is max erase/write cycles of At168 (datasheet)
  if (count > 4641) {
    dist += 1;
    serialsegments(dist);
    
    EEPROM.write(0,0); // tenth of a mile val
    EEPROM.write(1,dist);
    count = 0;
  }
  // update eeprom with a 1/10th mile val
  else {
    // I think it's more efficent to do
    // this rather than maths like modulu and rem
    switch ( count ) {
      case 464:
        tenth = 1;
        break;
      case 928:
        tenth = 2;
        break;
      case 1392:
        tenth = 3;
        break;
      case 1856:
        tenth = 4;
        break;
      case 2320:
        tenth = 5;
        break;
      case 2784:
        tenth = 6;
        break;
      case 3248:
        tenth = 7;
        break;
      case 3712:
        tenth = 8;
        break;
      case 4176:
        tenth = 9;
        break;
    }
    // only write when travelled a 1/10th
    if ( tenth != 0 ){
      // cannot use wire from interrupt
      EEPROM.write(0,tenth);
    }
    count += 1;
  }
  
}

void setup() {
  //set pins to output so you can control the shift register
  Wire.begin();
  
  pinMode(ignition, OUTPUT);
  
  // If the hash in the keyfob(eeprom) does not 
  // read correctly, wait forever
  while ( check_hash()  == false) {
    digitalWrite(ignition, LOW); // ensure ignition is disabled
    delay(1000);
  }
  
  pinMode(latchPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  pinMode(dataPin, OUTPUT);
  pinMode(val1pin, OUTPUT);
  pinMode(val2pin, OUTPUT);
  
  // enable ignition
  digitalWrite(ignition, HIGH);
  
  // the odometer values
  count = EEPROM.read(0) * 464; // 1/10ths of a mile
  dist = EEPROM.read(1); // miles

  
  Serial.begin(57600); // Highest ser-disp will allow
  Serial.print('v');
  serialsegments(dist);

  
  // Tested this interrupt with a dremel and a coloured mopwheel
  // similar to real-world setup. Worked at half-speed which calculates
  // to 720MPH or ~56000rpm of the dremel. At any higher speed the time to
  // increment a mile takes longer.
  attachInterrupt(0, calculations, CHANGE); // pin 3
}

void loop() {
  // The only thing that needs to run all
  // the time as the 7segs are being multiplexed
  speeddisp(velo); 
  // This is the place to write to the i2ceeprom
  // wire.h does not like isr  
}
