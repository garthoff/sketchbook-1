#include <Wire.h>

#define DEV_ADDR 0x50

const char* const HASH = "210d5292498ff0f2";



void i2c_eeprom_write_page( int deviceaddress, unsigned int eeaddresspage, byte* data, byte length ) {
  Wire.beginTransmission(deviceaddress);
  Wire.send((int)(eeaddresspage >> 8)); // MSB
  Wire.send((int)(eeaddresspage & 0xFF)); // LSB
  byte c;
  for ( c = 0; c < length; c++)
    Wire.send(data[c]);
  Wire.endTransmission();
}

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

void write_hash(){
  i2c_eeprom_write_page(DEV_ADDR, 0, (byte *)HASH, sizeof(HASH));
  delay(100);
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

void print_hash(){
  int addr = 0;
  byte b = i2c_eeprom_read_byte(DEV_ADDR, addr);
  while (b != 0){
    Serial.print((char)b);
    addr++;
    b = i2c_eeprom_read_byte(DEV_ADDR, addr);
  }
  Serial.println();
}

void setup() {  
  Serial.begin(115200);
  Wire.begin(); 
}

void loop() {
  if (check_hash() == false){
    Serial.println("CRAP");
  }
  else{ 
    Serial.println("ALL GOOD");
    print_hash();  
  }
  delay(2000);
}
  
  
