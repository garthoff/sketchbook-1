#include <Wire.h>

#define DEV_ADDR 0x50

const char HASH[] = "812500507";

void i2c_eeprom_write_byte( int deviceaddress, unsigned int eeaddress, byte data ) {
  int rdata = data;
  Wire.beginTransmission(deviceaddress);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.send(rdata);
  Wire.endTransmission();
  delay(10);
}

// WARNING: address is a page address, 6-bit end will wrap around
// also, data can be maximum of about 30 bytes, because the Wire library has a buffer of 32 bytes
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

// maybe let's not read more than 30 or 32 bytes at a time!
void i2c_eeprom_read_buffer( int deviceaddress, unsigned int eeaddress, byte *buffer, int length ) {
  Wire.beginTransmission(deviceaddress);
  Wire.send((int)(eeaddress >> 8)); // MSB
  Wire.send((int)(eeaddress & 0xFF)); // LSB
  Wire.endTransmission();
  Wire.requestFrom(deviceaddress,length);
  int c = 0;
  for ( c = 0; c < length; c++ )
    if (Wire.available()) buffer[c] = Wire.receive();
}

void write_key(){
  int cnt = 0;
  // hash stuff
  for (cnt = 0;cnt< sizeof(HASH);cnt++) {
    Serial.print(cnt);
    Serial.print(':');
    Serial.println(HASH[cnt]);
    i2c_eeprom_write_byte(DEV_ADDR,cnt,HASH[cnt]);
  }
  
  // ensure certain addresses are zeroed
  i2c_eeprom_write_byte(DEV_ADDR,10,0); // tenth
  i2c_eeprom_write_byte(DEV_ADDR,20,0); // odometer
  i2c_eeprom_write_byte(DEV_ADDR,21,0); // odometer
}

boolean check_hash(){
  int addr = 0;
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

void setup(){
  Wire.begin();
  Serial.begin(9600);
}

void loop(){
  write_key();
  delay(500);
  if ( check_hash() == true){
    Serial.println("SPAM");
    print_hash();
  }
  else{
    Serial.print("EGGS");
    
  }
  byte val;
  val = i2c_eeprom_read_byte(DEV_ADDR,10);
  Serial.print(val,DEC);
  val = i2c_eeprom_read_byte(DEV_ADDR,20);
  Serial.print(val,DEC);
  val = i2c_eeprom_read_byte(DEV_ADDR,21);
  Serial.println(val,DEC);
  
  delay(500);
  
}
