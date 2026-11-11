// ==============================================================================
// Smart Garage — ESP32-CAM (AI-Thinker) Live Video Streaming Firmware
//
// ক্যামেরা মডেল: AI-Thinker ESP32-CAM
// ফিক্সড আইপি: 192.168.0.250 (Flutter App এর সাথে সরাসরি কানেক্ট হবে)
// স্ট্রিম পাথ: http://192.168.0.250
// ==============================================================================

#include "esp_camera.h"
#include <WiFi.h>
#include "esp_timer.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "esp_http_server.h"

// ─── WiFi Credentials (আপনার রাউটারের সাথে মিল রাখা হয়েছে) ────
const char* ssid     = "TP-Link_5548";
const char* password = "70299519";

// ─── Static IP Configuration (192.168.0.250) ──────────────────
IPAddress local_IP(192, 168, 0, 250);
IPAddress gateway(192, 168, 0, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);
IPAddress secondaryDNS(8, 8, 4, 4);

// ─── AI-Thinker ESP32-CAM Pin Definitions ─────────────────────
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define FLASH_LED_PIN      4

#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

httpd_handle_t stream_httpd = NULL;

// ─── HTML Index Handler (Flutter WebView এর জন্য রেডি করা) ─────
static esp_err_t index_handler(httpd_req_t *req) {
  const char* html_page = 
    "<!DOCTYPE html>"
    "<html>"
    "<head>"
    "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no'>"
    "<title>Smart Garage Live</title>"
    "<style>"
    "body { background-color: #0A0A1A; color: #FFFFFF; font-family: sans-serif; text-align: center; margin: 0; padding: 12px; }"
    "h2 { color: #00E5CC; font-size: 16px; margin: 10px 0; }"
    "img { border-radius: 16px; max-width: 100%; height: auto; box-shadow: 0 8px 30px rgba(0,0,0,0.6); }"
    "</style>"
    "</head>"
    "<body>"
    "<h2>SMART GARAGE SURVEILLANCE</h2>"
    "<img src='/stream'>"
    "</body>"
    "</html>";

  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, html_page, HTTPD_RESP_USE_STRLEN);
}

// ─── MJPEG Video Stream Handler ───────────────────────────────
static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t * _jpg_buf = NULL;
  char * part_buf[64];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }
    if (res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    }
    if (res != ESP_OK) {
      break;
    }
  }
  return res;
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;
  config.ctrl_port = 32768;

  httpd_uri_t index_uri = {};
  index_uri.uri       = "/";
  index_uri.method    = HTTP_GET;
  index_uri.handler   = index_handler;
  index_uri.user_ctx  = NULL;

  httpd_uri_t stream_uri = {};
  stream_uri.uri       = "/stream";
  stream_uri.method    = HTTP_GET;
  stream_uri.handler   = stream_handler;
  stream_uri.user_ctx  = NULL;

  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &index_uri);
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    Serial.println("Camera HTTP Server Started!");
  }
}

void setup() {
  // Brownout Detector বন্ধ করা (ক্যামেরা বুট করার সময় পাওয়ার ড্রপ এড়াতে)
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println("\n--- ESP32-CAM STARTING ---");

  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW); // ফ্ল্যাশ অফ রাখা

  camera_config_t config = {}; // শূন্য দিয়ে ইনিশিয়ালাইজ (যাতে মেমরি গারবেজ না থাকে)
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 16500000; // 16.5MHz বেশি স্ট্যাবল এবং মেমরি বাফার ক্র্যাশ রোধ করে
  config.pixel_format = PIXFORMAT_JPEG;
  
  // PSRAM চেক এবং মেমরি অ্যালোকেশন
  if (psramFound()) {
    Serial.println("PSRAM found! High Quality Mode Enabled.");
    config.frame_size = FRAMESIZE_VGA; // 640x480
    config.jpeg_quality = 10;
    config.fb_count = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    config.grab_mode = CAMERA_GRAB_LATEST;
  } else {
    Serial.println("Warning: PSRAM not found! Using Safe Low-Memory Mode.");
    config.frame_size = FRAMESIZE_QVGA; // 320x240 (কখনো malloc fail করবে না)
    config.jpeg_quality = 12;
    config.fb_count = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  }

  // ক্যামেরা ইনিশিয়ালাইজেশন (অটো-ফলব্যাক সিস্টেম সহ)
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x. Retrying with ultra-safe mode...\n", err);
    // মেমরি ফেইল করলে স্বয়ংক্রিয়ভাবে সেফ মোডে চেষ্টা করবে
    esp_camera_deinit();
    config.frame_size = FRAMESIZE_QVGA;
    config.fb_count = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
    err = esp_camera_init(&config);
  }

  if (err != ESP_OK) {
    Serial.printf("Critical: Camera init still failed with error 0x%x\n", err);
    Serial.println("পরামর্শ: ক্যামেরার হলুদ ফিতা ক্যাবলটি চেক করুন অথবা Arduino IDE-তে Tools > PSRAM: Enabled করুন।");
    return;
  }

  sensor_t * s = esp_camera_sensor_get();
  // ক্যামেরার ছবি উল্টো আসলে নিচের মান ১ করে দেবেন
  s->set_vflip(s, 0); 
  s->set_hmirror(s, 0);

  // ─── পিওর DHCP মোড (হটস্পট নিজে আইপি দিবে) ───
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected successfully!");

  // সার্ভার চালু
  startCameraServer();

  Serial.println("\n==================================");
  Serial.print("Camera Stream Ready: http://");
  Serial.println(WiFi.localIP());
  Serial.println("==================================");
}

void loop() {
  delay(10000);
}

