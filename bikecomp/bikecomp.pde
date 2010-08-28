#include <Wire.h>
#define DEV_ADDR 0x50 //eeprom addr
const char* const HASH = "210d5292498ff0f2"; // eeprom hash

int latchPin = 11; //ST_CP of 74HC595
int clockPin = 10; //SH_CP of 74HC595
int dataPin = 12; // DS of 74HC595
int array[] = {64,118,33,36,22,12,8,102,0,6};

int val1pin = 3; // segment 1
int val2pin = 4; // segment 2

boolean seg1 = true;
boolean seg2 = false;

volatile int velo = 0; // speed 
volatile unsigned int count = 0; 
volatile unsigned int dist = 0; // odometer
volatile unsigned long oldtime = 0; // the millis time of last interrupt

byte i2c_eeprom_read_byte( int deviceaddress, unsigned int eeaddress ) {
  byte rdata = 0xFF;
  Wire.beginTransmission(deviceaddress);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.endTransmission();
  Wire.requestFrom(deviceaddress,1);
  if (Wire.available()) rdata = Wire.receive();
  return rdata;
}

boolean check_hash(){
  // checks to see if the hash n the eeprom matches the constant
  static int addr = 0;
  byte b = i2c_eeprom_read_byte(DEV_ADDR, addr);
  while (b != 0){
    if (b != HASH[addr])
      return false;
    addr++;
    b = i2c_eeprom_read_byte(DEV_ADDR, addr);
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
      delay(7);
}    

void calculations(void) {
  unsigned int gap = 0;
  unsigned long now;

  now = millis();
  gap = now - oldtime; 
  // 2437 is a constant to get to mph 
  velo = 2437/gap;
  
  oldtime = now;

  // Odometer calculations
  // 4641 triggers per mile based
  // on wheel circumference
  // TODO: make these variables pertinent i.e eeprom
  if (count > 4641) {
    dist += 1;
    serialsegments(dist);
    count = 0;
  }
  else {
    count += 1;
  }
  
}

void checkup() {
  // If the hash does not read correctly wait forever
  while ( check_hash()  == false) {
    delay(1000);
  }
}

void setup() {
  //set pins to output so you can control the shift register
  Wire.begin(); 
  checkup();
  pinMode(latchPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  pinMode(dataPin, OUTPUT);
  pinMode(val1pin, OUTPUT);
  pinMode(val2pin, OUTPUT);
  Serial.begin(9600);
  //Serial.print(0x76, HEX); //reset display. NOT WORKING
  Serial.print('v');
  attachInterrupt(0, calculations, CHANGE); // pin 3
}

void loop() {
    speeddisp(velo);      
}
