#include <Wire.h>
#include <SPI.h>
#include <LoRa.h>
#include <SparkFun_SCD4x_Arduino_Library.h>

#define SS 5
#define RST 14
#define DIO0 2

// --- NEW: Lux Sensor Pin ---
// GPIO 34 is a safe Analog Input (ADC1_CH6) on most ESP32 boards
#define LUX_PIN 34 
// ---------------------------

// --- !!! ---
// Set your Site ID here ("A" or "B")
String siteID = "A"; 
// --- !!! ---

SCD4x mySensor;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);
  randomSeed(micros());

  // Initialize Lux Pin
  pinMode(LUX_PIN, INPUT);

  // Initialize sensor
  if (!mySensor.begin()) {
    Serial.println("SCD41 not detected!");
    while (1);
  }
  mySensor.startPeriodicMeasurement();

  // Initialize LoRa
  LoRa.setPins(SS, RST, DIO0);
  if (!LoRa.begin(433E6)) {
    Serial.println("Starting LoRa failed!");
    while (1);
  }
  //LoRa.setPreambleLength(16); // Increase preamble to 16

  Serial.println("LoRa transmitter started! Site: " + siteID);
  Serial.println("This is Site: " + siteID);
}

void loop() {
  if (mySensor.readMeasurement()) {
    float co2 = mySensor.getCO2();
    float temperature = mySensor.getTemperature();
    float humidity = mySensor.getHumidity();

    // --- READ TEMT6000 LUX SENSOR ---
    int analogValue = analogRead(LUX_PIN);
    
    // Convert Analog (0-4095) to Voltage (0 - 3.3V)
    float voltage = analogValue * (3.3 / 4095.0);
    
    // TEMT6000 logic: The breakout board usually has a 10k ohm resistor.
    // Current (Amps) = Voltage / Resistance
    // The sensor outputs approx 20 microAmps at 100 Lux.
    // Therefore: Lux ≈ (Current in microAmps) * 2
    
    float amps = voltage / 10000.0;  // Assuming 10k resistor on module
    float microAmps = amps * 1000000;
    float lux = microAmps * 2.0; 
    // --------------------------------

    // --- NEW, BETTER MESSAGE FORMAT ---
    // Format: "site:A,co2:462.0,temp:28.8,hum:79.6,lux:150.5"
    String message = "    <site:" + siteID +
                     ",co2:" + String(co2, 2) +       
                     ",temp:" + String(temperature, 1) +
                     ",hum:" + String(humidity, 1) +
                     ",lux:" + String(lux, 1) + ">"; // Added Lux here

    Serial.println("Sending: " + message);

    LoRa.beginPacket();
    LoRa.print(message);
    LoRa.endPacket();

    // Add random delay
    long randomDelay = random(0, 1000); 
    delay(10000 + randomDelay);
  }
}