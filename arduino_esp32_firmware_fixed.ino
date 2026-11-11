// ============================================================
// Smart Garage V3.0 — 2 Servo Motors (Entry: D13, Exit: D17)
// Prepaid Billing, OLED, 3-Color Traffic Light
// ============================================================
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/RTDBHelper.h"
#include <ESP32Servo.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "time.h"

// ─── WiFi ──────────────────────────────────────────────────
const char* ssid     = "TP-Link_5548";
const char* password = "70299519";

// ─── Firebase ──────────────────────────────────────────────
#define DATABASE_URL "live-tracking-2fb1c-default-rtdb.firebaseio.com"
#define DB_SECRET    "pFhLbvWkUMgkx0zZByHtBEi5HR1SEDzDfOHMYUqR"

// ─── NTP Server ────────────────────────────────────────────
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 21600; // Bangladesh Time (GMT +6)
const int   daylightOffset_sec = 0;

// ─── Pins (ESP32) ──────────────────────────────────────────
#define SS_PIN          5
#define RST_PIN         4
#define ENTRY_SERVO_PIN 13   // ভেতরে ঢুকলে এই সার্ভো ঘুরবে
#define EXIT_SERVO_PIN  17   // বাইরে বের হলে এই সার্ভো ঘুরবে (D17 / TX2)
#define GATE_IR_PIN     32  
#define SLOT1_IR        14
#define SLOT2_IR        27
#define SLOT3_IR        26
#define SLOT4_IR        25
#define OLED_SDA        21
#define OLED_SCL        22
#define RED_LED_PIN     33   // ট্রাফিক লাইট (লাল)
#define YELLOW_LED_PIN  15   // ট্রাফিক লাইট (হলুদ)
#define GREEN_LED_PIN   16   // ট্রাফিক লাইট (সবুজ)

// ─── Objects ───────────────────────────────────────────────
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

Servo entryServo;   // Entry Gate Servo
Servo exitServo;    // Exit Gate Servo
MFRC522 rfid(SS_PIN, RST_PIN);

FirebaseData fbdo;
FirebaseData fbdoCommand; // অ্যাপ থেকে কমান্ড পাওয়ার জন্য ডেডিকেটেড অবজেক্ট
FirebaseAuth auth;
FirebaseConfig config;

// ─── State Variables ───────────────────────────────────────
bool isEntryGateOpen = false;
unsigned long entryGateOpenTime = 0;

bool isExitGateOpen = false;
unsigned long exitGateOpenTime = 0;

bool slot1_state = HIGH, last_slot1 = HIGH;
bool slot2_state = HIGH, last_slot2 = HIGH;
bool slot3_state = HIGH, last_slot3 = HIGH;
bool slot4_state = HIGH, last_slot4 = HIGH;
int availableSlots = 4;

bool gate_ir_state = HIGH, last_gate_ir = HIGH;

String currentAlert = "SCAN CARD...";
unsigned long alertTimer = 0;

// ─── Functions ─────────────────────────────────────────────

String getCurrentTimeString() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "Time Error";
  char timeBuff[50];
  strftime(timeBuff, sizeof(timeBuff), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(timeBuff);
}

unsigned long getEpochTime() {
  time_t now;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return 0;
  time(&now);
  return now;
}

void updateDisplay(String alertMsg) {
  currentAlert = alertMsg;
  alertTimer = millis(); 
  display.clearDisplay();
  
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(5, 0);
  display.println("SMART PARKING SYSTEM");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);
  
  display.setTextSize(2);
  display.setCursor(0, 20);
  if (availableSlots == 0) {
    display.print("FULL! (0)");
  } else {
    display.print("SLOTS: ");
    display.print(availableSlots);
  }
  
  display.setTextSize(1);
  display.setCursor(0, 45);
  display.println(currentAlert);
  display.display();
}

void resetTrafficLight() {
  digitalWrite(RED_LED_PIN, HIGH);
  digitalWrite(YELLOW_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, LOW);
}

// গাড়ি ভেতরে ঢুকলে বা অ্যাপ কমান্ড আসলে: Entry Servo (Pin 13) খুলবে
void openEntryGate() {
  entryServo.write(90); 
  isEntryGateOpen = true;
  entryGateOpenTime = millis();
  
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(YELLOW_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, HIGH);
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/entryGateStatus", "open");
  Serial.println("Entry Gate Opened (Pin 13)");
}

// Entry Servo বন্ধ করা
void closeEntryGate() {
  entryServo.write(0); 
  isEntryGateOpen = false;
  resetTrafficLight();
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/entryGateStatus", "closed");
  Serial.println("Entry Gate Closed (Pin 13)");
}

// গাড়ি বাইরে বের হলে বা অ্যাপ কমান্ড আসলে: Exit Servo (Pin 17) খুলবে
void openExitGate() {
  exitServo.write(90); 
  isExitGateOpen = true;
  exitGateOpenTime = millis();
  
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(YELLOW_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, HIGH);
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/exitGateStatus", "open");
  Serial.println("Exit Gate Opened (Pin 17)");
}

// Exit Servo বন্ধ করা
void closeExitGate() {
  exitServo.write(0); 
  isExitGateOpen = false;
  resetTrafficLight();
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/exitGateStatus", "closed");
  Serial.println("Exit Gate Closed (Pin 17)");
}

void setup() {
  Serial.begin(115200);

  Wire.begin(OLED_SDA, OLED_SCL);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  
  // ২টি সার্ভো ইনিশিয়ালাইজেশন
  entryServo.attach(ENTRY_SERVO_PIN);
  entryServo.write(0); 

  exitServo.attach(EXIT_SERVO_PIN);
  exitServo.write(0); 
  
  pinMode(GATE_IR_PIN, INPUT_PULLUP);
  pinMode(SLOT1_IR, INPUT_PULLUP);
  pinMode(SLOT2_IR, INPUT_PULLUP);
  pinMode(SLOT3_IR, INPUT_PULLUP);
  pinMode(SLOT4_IR, INPUT_PULLUP);

  // ট্রাফিক লাইট সেটআপ
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  resetTrafficLight(); // শুরুতে লাল বাতি চালু

  SPI.begin();
  rfid.PCD_Init();

  updateDisplay("Connecting WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); }
  updateDisplay("WiFi Connected!");
  delay(1000);
  
  updateDisplay("Syncing Time...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  time_t now = time(nullptr);
  while (now < 1600000000) { 
    delay(500);
    now = time(nullptr);
  }
  
  updateDisplay("Connecting DB...");
  config.database_url = DATABASE_URL;
  config.signer.tokens.legacy_token = DB_SECRET;
  fbdo.setBSSLBufferSize(4096, 1024); 
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  // শুরুর সাথে সাথে স্লট স্ট্যাটাস ফায়ারবেজে সিঙ্ক করা
  slot1_state = digitalRead(SLOT1_IR);
  slot2_state = digitalRead(SLOT2_IR);
  slot3_state = digitalRead(SLOT3_IR);
  slot4_state = digitalRead(SLOT4_IR);
  last_slot1 = slot1_state;
  last_slot2 = slot2_state;
  last_slot3 = slot3_state;
  last_slot4 = slot4_state;
  
  FirebaseJson initSlots;
  initSlots.set("slot1", (slot1_state == LOW) ? "Full" : "Empty");
  initSlots.set("slot2", (slot2_state == LOW) ? "Full" : "Empty");
  initSlots.set("slot3", (slot3_state == LOW) ? "Full" : "Empty");
  initSlots.set("slot4", (slot4_state == LOW) ? "Full" : "Empty");
  Firebase.RTDB.setJSON(&fbdo, "/garage/slots", &initSlots);

  // গেইট ও কমান্ড স্ট্যাটাস ইনিশিয়ালাইজেশন
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/entryGateStatus", "closed");
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/exitGateStatus", "closed");
  Firebase.RTDB.setStringAsync(&fbdo, "/garage/command", "none");

  // ফায়ারবেজ কমান্ড স্ট্রিম চালু করা
  fbdoCommand.setBSSLBufferSize(2048, 512);
  Firebase.RTDB.beginStream(&fbdoCommand, "/garage/command");

  updateDisplay("System Ready!");
  Serial.println("System Ready!");
  delay(1000);
}

void loop() {
  
  // ০. Reset Alert 
  if (millis() - alertTimer > 5000 && currentAlert != "SCAN CARD..." && currentAlert != "GARAGE IS FULL!") {
    if (availableSlots == 0) updateDisplay("GARAGE IS FULL!");
    else updateDisplay("SCAN CARD...");
  }

  // ১. Entry Gate অটো বন্ধ (গাড়ি ঢুকলে ৩ সেকেন্ড পর বন্ধ হবে)
  gate_ir_state = digitalRead(GATE_IR_PIN);
  if (isEntryGateOpen && gate_ir_state == HIGH && (millis() - entryGateOpenTime > 3000)) {
    closeEntryGate();
    Serial.println("Entry Gate Auto Closed!");
  }
  last_gate_ir = gate_ir_state;

  // ১.১ Exit Gate অটো বন্ধ (বের হওয়ার ৩ সেকেন্ড পর বন্ধ হবে — কোনো delay ছাড়া)
  if (isExitGateOpen && (millis() - exitGateOpenTime > 3000)) {
    closeExitGate();
    Serial.println("Exit Gate Auto Closed!");
  }

  // ২. Slot Tracking 
  slot1_state = digitalRead(SLOT1_IR);
  if (slot1_state != last_slot1) {
    Firebase.RTDB.setStringAsync(&fbdo, "/garage/slots/slot1", (slot1_state == LOW) ? "Full" : "Empty");
    last_slot1 = slot1_state;
  }
  
  slot2_state = digitalRead(SLOT2_IR);
  if (slot2_state != last_slot2) {
    Firebase.RTDB.setStringAsync(&fbdo, "/garage/slots/slot2", (slot2_state == LOW) ? "Full" : "Empty");
    last_slot2 = slot2_state;
  }

  slot3_state = digitalRead(SLOT3_IR);
  if (slot3_state != last_slot3) {
    Firebase.RTDB.setStringAsync(&fbdo, "/garage/slots/slot3", (slot3_state == LOW) ? "Full" : "Empty");
    last_slot3 = slot3_state;
  }

  slot4_state = digitalRead(SLOT4_IR);
  if (slot4_state != last_slot4) {
    Firebase.RTDB.setStringAsync(&fbdo, "/garage/slots/slot4", (slot4_state == LOW) ? "Full" : "Empty");
    last_slot4 = slot4_state;
  }

  int currentAvailable = (slot1_state) + (slot2_state) + (slot3_state) + (slot4_state); 
  if (currentAvailable != availableSlots) {
    availableSlots = currentAvailable;
    if (availableSlots == 0) updateDisplay("GARAGE IS FULL!");
    else updateDisplay("SCAN CARD...");
  }

  // ৩. RFID Prepaid Payment Logic
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    
    // কার্ড স্ক্যান করার সাথে সাথে হলুদ বাতি জ্বলবে (Processing)
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(YELLOW_LED_PIN, HIGH);
    digitalWrite(GREEN_LED_PIN, LOW);
    
    updateDisplay("Processing...");
    String uid = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
      uid += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
      uid += String(rfid.uid.uidByte[i], HEX);
    }
    uid.toUpperCase();
    rfid.PICC_HaltA(); 
    
    Serial.println("\n--- NEW CARD SCANNED ---");
    Serial.println("Card UID: " + uid);
    
    String pathStatus = "/garage/users/" + uid + "/status";
    String pathBalance = "/garage/users/" + uid + "/balance";
    
    bool isUserIn = false;
    unsigned long entryEpoch = 0;
    int currentBalance = 0;

    if (Firebase.RTDB.getString(&fbdo, pathStatus)) {
      if (fbdo.stringData() == "IN") {
        isUserIn = true;
        if (Firebase.RTDB.getInt(&fbdo, "/garage/users/" + uid + "/entryEpoch")) {
           entryEpoch = fbdo.intData();
        }
      }
    }

    if (Firebase.RTDB.getInt(&fbdo, pathBalance)) {
      currentBalance = fbdo.intData();
    } else {
      currentBalance = 200; 
      Firebase.RTDB.setInt(&fbdo, pathBalance, currentBalance);
      Serial.println("New User Registered! Bonus 200 TK Added.");
    }

    unsigned long currentEpoch = getEpochTime();
    String timeNow = getCurrentTimeString();

    if (isUserIn) {
      // ════════════════════════════════════════════════════════════════
      // ─── EXIT (গাড়ি বের হচ্ছে) ───
      // ════════════════════════════════════════════════════════════════
      int parkedMinutes = (currentEpoch - entryEpoch) / 60; 
      if (parkedMinutes < 1) parkedMinutes = 1; 
      int fare = parkedMinutes * 2; 

      if (currentBalance >= fare) {
        int newBalance = currentBalance - fare;
        
        // Single FirebaseJson node update avoids SSL engine collision
        FirebaseJson exitData;
        exitData.set("status", "OUT");
        exitData.set("lastFare", fare);
        exitData.set("exitTime", timeNow);
        exitData.set("balance", newBalance);
        Firebase.RTDB.updateNode(&fbdo, "/garage/users/" + uid, &exitData);
        
        openExitGate(); // ✅ শুধু EXIT গেট (D17) খুলবে!
        updateDisplay("PAID: " + String(fare) + " BAL: " + String(newBalance));
        Serial.println("Action: EXIT (Payment Successful)");
      } else {
        updateDisplay("LOW BALANCE! BAL: " + String(currentBalance));
        resetTrafficLight();
        Serial.println("Action: EXIT DENIED (Insufficient Funds)");
      }
      
    } else {
      // ════════════════════════════════════════════════════════════════
      // ─── ENTRY (গাড়ি ভেতরে ঢুকছে) ───
      // ════════════════════════════════════════════════════════════════
      if (availableSlots == 0) {
        updateDisplay("ENTRY DENIED! FULL!");
        resetTrafficLight();
        Serial.println("Action: DENIED (Garage Full)");
      } else if (currentBalance < 10) {
        updateDisplay("LOW BAL  TO ENTER!");
        resetTrafficLight();
        Serial.println("Action: DENIED (Balance less than 10 TK)");
      } else {
        // Single FirebaseJson node update avoids SSL engine collision
        FirebaseJson entryData;
        entryData.set("status", "IN");
        entryData.set("entryEpoch", (int)currentEpoch);
        entryData.set("entryTime", timeNow);
        Firebase.RTDB.updateNode(&fbdo, "/garage/users/" + uid, &entryData);
        
        openEntryGate(); // ✅ শুধু ENTRY গেট (D13) খুলবে!
        updateDisplay("WELCOME! BAL: " + String(currentBalance));
        Serial.println("Action: ENTRY");
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ৪. Firebase App Command Listener (Manual Open / Close from Flutter)
  // ════════════════════════════════════════════════════════════════
  if (Firebase.ready()) {
    if (!Firebase.RTDB.readStream(&fbdoCommand)) {
      if (!fbdoCommand.httpConnected()) {
        Firebase.RTDB.beginStream(&fbdoCommand, "/garage/command");
      }
    }
    if (fbdoCommand.streamAvailable()) {
      if (fbdoCommand.dataType() == "string") {
        String cmd = fbdoCommand.stringData();
        if (cmd == "open_entry_gate" || cmd == "open") {
          Serial.println("App Command: OPEN ENTRY GATE");
          updateDisplay("APP: OPEN ENTRY");
          openEntryGate();
          Firebase.RTDB.setStringAsync(&fbdo, "/garage/command", "none");
        } else if (cmd == "close_entry_gate" || cmd == "close") {
          Serial.println("App Command: CLOSE ENTRY GATE");
          updateDisplay("APP: CLOSE ENTRY");
          closeEntryGate();
          Firebase.RTDB.setStringAsync(&fbdo, "/garage/command", "none");
        } else if (cmd == "open_exit_gate") {
          Serial.println("App Command: OPEN EXIT GATE");
          updateDisplay("APP: OPEN EXIT");
          openExitGate();
          Firebase.RTDB.setStringAsync(&fbdo, "/garage/command", "none");
        } else if (cmd == "close_exit_gate") {
          Serial.println("App Command: CLOSE EXIT GATE");
          updateDisplay("APP: CLOSE EXIT");
          closeExitGate();
          Firebase.RTDB.setStringAsync(&fbdo, "/garage/command", "none");
        }
      }
    }
  }
}
