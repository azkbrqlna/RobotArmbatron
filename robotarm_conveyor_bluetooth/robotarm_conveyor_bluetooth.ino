#include <BluetoothSerial.h>
#include <ESP32Servo.h>
#include <Preferences.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
// ==========================================
// BLUETOOTH SERIAL SETUP
// ==========================================
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif

BluetoothSerial SerialBT;
const char* BT_DEVICE_NAME = "Ambatron";

// ==========================================
// PIN & HARDWARE SETUP (FULL SERVO)
// ==========================================
const int PIN_SERVO[4] = {13, 14, 27, 26}; // 0: Base, 1: Shoulder, 2: Elbow, 3: Gripper
Servo servos[4];

// Servo 360 untuk Conveyor (Pin 25)
const int PIN_CONV = 25;
Servo convServo;

Preferences preferences;

// Batas sudut fisik
const int LIMITS[4][2] = {
  {0, 180},  // Base
  {0, 45},   // Shoulder
  {30, 180}, // Elbow
  {0, 180}   // Gripper
};

// ==========================================
// VARIABEL SMOOTH SERVO & CONVEYOR
// ==========================================
const int POS_HOME[4] = {90, 0, 150, 180};
int targetAngles[4] = {90, 0, 150, 180};
float currentPhysical[4] = {90.0, 0.0, 150.0, 180.0};

int targetConv = 0; // 0=Stop, 1=Maju, 2=Mundur

unsigned long lastServoUpdate = 0;
const int SERVO_INTERVAL = 15; // ms
const float SERVO_SPEED = 0.5; // derajat per step

const int MAX_FRAMES = 50;
struct Frame {
  int angles[4];
  int conv;
  int convDurationMs; // Durasi jalan konveyor dalam milidetik (0 jika tidak ada timer)
};

Frame seqA[MAX_FRAMES]; int countA = 0;
Frame seqB[MAX_FRAMES]; int countB = 0;

bool isPlaying = false;
char playSeq = 'A';
int playIndex = 0;
bool isWaitingNextFrame = false;
unsigned long playPauseTimer = 0;
const int PAUSE_BETWEEN_FRAMES = 800; // ms jeda antar frame

// Variabel kontrol waktu konveyor saat playback otomatis
bool convRunning = false;
unsigned long convStartTime = 0;
int currentFrameConv = 0;
int currentFrameConvDur = 0;

unsigned long lastStatusBroadcast = 0;
int lastReportedIndex = -1;

// ==========================================
// FUNGSI SERVO 360 (CONVEYOR)
// ==========================================
const int CONV_STOP = 95;
const int CONV_MAJU_PELAN = CONV_STOP - 12;   // 83
const int CONV_MUNDUR_PELAN = CONV_STOP + 12; // 107

void updateConveyor(int state) {
  targetConv = state;
  if (state == 1) {
    convServo.write(CONV_MAJU_PELAN);
  } else if (state == 2) {
    convServo.write(CONV_MUNDUR_PELAN);
  } else {
    convServo.write(CONV_STOP);
  }
}

void applyFrame(Frame f) {
  for (int i = 0; i < 4; i++) {
    targetAngles[i] = f.angles[i];
  }
  currentFrameConv = f.conv;
  currentFrameConvDur = f.convDurationMs;
  convStartTime = millis();
  convRunning = (currentFrameConv != 0);
  updateConveyor(currentFrameConv);
}

// ==========================================
// MEMORI NVS (PREFERENCES)
// ==========================================
void loadSequences() {
  preferences.begin("robot_arm_v4", false);
  countA = preferences.getInt("countA", -1);
  if (countA >= 0 && countA <= MAX_FRAMES) {
    if (countA > 0) preferences.getBytes("seqA", seqA, sizeof(Frame) * countA);
    countB = preferences.getInt("countB", 0);
    if (countB > 0 && countB <= MAX_FRAMES) {
      preferences.getBytes("seqB", seqB, sizeof(Frame) * countB);
    } else {
      countB = 0;
    }
  } else {
    // Migrasi otomatis dari namespace lama robot_arm_v3 jika tersedia
    preferences.end();
    preferences.begin("robot_arm_v3", true);
    int oldA = preferences.getInt("countA", 0);
    int oldB = preferences.getInt("countB", 0);
    struct OldFrame { int angles[4]; int conv; };
    if (oldA > 0 && oldA <= MAX_FRAMES) {
      OldFrame oldSeqA[MAX_FRAMES];
      preferences.getBytes("seqA", oldSeqA, sizeof(OldFrame) * oldA);
      countA = oldA;
      for (int i = 0; i < oldA; i++) {
        for (int j = 0; j < 4; j++) seqA[i].angles[j] = oldSeqA[i].angles[j];
        seqA[i].conv = oldSeqA[i].conv;
        seqA[i].convDurationMs = 0;
      }
    } else {
      countA = 0;
    }
    if (oldB > 0 && oldB <= MAX_FRAMES) {
      OldFrame oldSeqB[MAX_FRAMES];
      preferences.getBytes("seqB", oldSeqB, sizeof(OldFrame) * oldB);
      countB = oldB;
      for (int i = 0; i < oldB; i++) {
        for (int j = 0; j < 4; j++) seqB[i].angles[j] = oldSeqB[i].angles[j];
        seqB[i].conv = oldSeqB[i].conv;
        seqB[i].convDurationMs = 0;
      }
    } else {
      countB = 0;
    }
    preferences.end();
    saveSequenceData('A');
    saveSequenceData('B');
    return;
  }
  preferences.end();
}

void saveSequenceData(char seq) {
  preferences.begin("robot_arm_v4", false);
  if (seq == 'A') {
    preferences.putInt("countA", countA);
    if (countA > 0) {
      preferences.putBytes("seqA", seqA, sizeof(Frame) * countA);
    } else {
      preferences.remove("seqA");
    }
  } else {
    preferences.putInt("countB", countB);
    if (countB > 0) {
      preferences.putBytes("seqB", seqB, sizeof(Frame) * countB);
    } else {
      preferences.remove("seqB");
    }
  }
  preferences.end();
}

// ==========================================
// HELPER PROTOKOL BLUETOOTH
// ==========================================
void sendFramesResponse(char seq) {
  int count = (seq == 'A') ? countA : countB;
  String out = "FRAMES:" + String(seq) + ":" + String(count) + ":";
  out.reserve(out.length() + count * 30); // Pre-allocate to prevent heap churn
  for (int i = 0; i < count; i++) {
    Frame f = (seq == 'A') ? seqA[i] : seqB[i];
    out += String(f.angles[0]) + "," +
           String(f.angles[1]) + "," +
           String(f.angles[2]) + "," +
           String(f.angles[3]) + "," +
           String(f.conv) + "," +
           String(f.convDurationMs);
    if (i < count - 1) out += ";";
  }
  out += "\n";
  SerialBT.print(out);
  Serial.print("BT TX: " + out);
}

void sendStatus() {
  String status = "STATUS:" + String(isPlaying ? 1 : 0) + ":" + String(playIndex) + "\n";
  SerialBT.print(status);
  Serial.print("BT TX: " + status);
}

// ==========================================
// PARSER PERINTAH BLUETOOTH
// Protokol:
// S:<id>:<angle>\n       -> Set Servo angle
// C:<state>\n            -> Set Conveyor (0=stop, 1=fwd, 2=rev)
// GET:<seq>\n            -> Minta daftar frame (A atau B)
// SAVE:<seq>[:<c>:<dur>] -> Simpan frame baru dari posisi saat ini
// UPD:<seq>:<idx>[:<c>:<dur>] -> Update frame ke-idx dengan posisi saat ini
// DEL:<seq>:<idx>\n      -> Hapus frame ke-idx yang dipilih
// UNDO:<seq>\n           -> Hapus frame terakhir
// PLAY:<seq>\n           -> Jalankan urutan looping
// STOP\n                 -> Berhenti darurat
// POS?\n                 -> Minta status sudut saat ini
// ==========================================
String rxBuffer = "";

int splitColon(String s, String tokens[], int maxTokens) {
  int tokenCount = 0;
  int start = 0;
  while (start < s.length() && tokenCount < maxTokens) {
    int nextColon = s.indexOf(':', start);
    if (nextColon == -1) {
      tokens[tokenCount++] = s.substring(start);
      break;
    } else {
      tokens[tokenCount++] = s.substring(start, nextColon);
      start = nextColon + 1;
    }
  }
  return tokenCount;
}

void processCommand(String cmd) {
  cmd.trim();
  if (cmd.length() == 0) return;

  Serial.println("BT RX: " + cmd);

  String tokens[6];
  int nTokens = splitColon(cmd, tokens, 6);
  if (nTokens == 0) return;

  String op = tokens[0];

  if (op == "S") {
    // Format: S:<id>:<angle>
    if (nTokens >= 3) {
      int id = tokens[1].toInt();
      int angle = tokens[2].toInt();
      if (id >= 0 && id < 4) {
        angle = constrain(angle, LIMITS[id][0], LIMITS[id][1]);
        targetAngles[id] = angle;
        isPlaying = false; // Interupsi manual membatalkan mode auto
        convRunning = false;
        updateConveyor(0);
      }
    }
  } else if (op == "C") {
    // Format: C:<state>
    if (nTokens >= 2) {
      int state = tokens[1].toInt();
      updateConveyor(state);
      isPlaying = false;
      convRunning = false;
    }
  } else if (op == "GET") {
    // Format: GET:<seq>
    if (nTokens >= 2) {
      char seq = tokens[1].charAt(0);
      sendFramesResponse(seq);
    }
  } else if (op == "SAVE") {
    // Format: SAVE:<seq> atau SAVE:<seq>:<conv>:<durMs>
    if (nTokens >= 2) {
      char seq = tokens[1].charAt(0);
      int convVal = targetConv;
      int durVal = 0;

      if (nTokens >= 4) {
        convVal = tokens[2].toInt();
        durVal = tokens[3].toInt();
      }

      int count = (seq == 'A') ? countA : countB;
      if (count < MAX_FRAMES) {
        Frame newFrame;
        for (int i = 0; i < 4; i++) newFrame.angles[i] = targetAngles[i];
        newFrame.conv = convVal;
        newFrame.convDurationMs = durVal;

        if (seq == 'A') { seqA[countA] = newFrame; countA++; }
        else { seqB[countB] = newFrame; countB++; }
        saveSequenceData(seq);
        sendFramesResponse(seq);
      } else {
        SerialBT.println("ERR:FULL");
      }
    }
  } else if (op == "UPD") {
    // Format: UPD:<seq>:<idx> atau UPD:<seq>:<idx>:<conv>:<durMs>
    if (nTokens >= 3) {
      char seq = tokens[1].charAt(0);
      int idx = tokens[2].toInt();
      int convVal = targetConv;
      int durVal = 0;

      if (nTokens >= 5) {
        convVal = tokens[3].toInt();
        durVal = tokens[4].toInt();
      }

      int count = (seq == 'A') ? countA : countB;
      if (idx >= 0 && idx < count) {
        Frame newFrame;
        for (int i = 0; i < 4; i++) newFrame.angles[i] = targetAngles[i];
        newFrame.conv = convVal;
        newFrame.convDurationMs = durVal;
        if (seq == 'A') seqA[idx] = newFrame; else seqB[idx] = newFrame;
        saveSequenceData(seq);
        sendFramesResponse(seq);
      }
    }
  } else if (op == "DEL") {
    // Format: DEL:<seq>:<idx>
    if (nTokens >= 3) {
      char seq = tokens[1].charAt(0);
      int idx = tokens[2].toInt();
      int count = (seq == 'A') ? countA : countB;
      if (idx >= 0 && idx < count) {
        if (seq == 'A') {
          for (int i = idx; i < countA - 1; i++) seqA[i] = seqA[i + 1];
          countA--;
        } else {
          for (int i = idx; i < countB - 1; i++) seqB[i] = seqB[i + 1];
          countB--;
        }
        saveSequenceData(seq);
        sendFramesResponse(seq);
      }
    }
  } else if (op == "UNDO") {
    // Format: UNDO:<seq>
    if (nTokens >= 2) {
      char seq = tokens[1].charAt(0);
      if (seq == 'A' && countA > 0) { countA--; saveSequenceData('A'); }
      else if (seq == 'B' && countB > 0) { countB--; saveSequenceData('B'); }
      sendFramesResponse(seq);
    }
  } else if (op == "CLEAR") {
    // Format: CLEAR:<seq>
    if (nTokens >= 2) {
      char seq = tokens[1].charAt(0);
      if (seq == 'A') countA = 0;
      else if (seq == 'B') countB = 0;
      saveSequenceData(seq);
      sendFramesResponse(seq);
    }
  } else if (op == "PLAY") {
    // Format: PLAY:<seq>
    if (nTokens >= 2) {
      char seq = tokens[1].charAt(0);
      int count = (seq == 'A') ? countA : countB;
      if (count > 0) {
        playSeq = seq;
        playIndex = 0;
        isPlaying = true;
        isWaitingNextFrame = false;

        Frame startFrame = (playSeq == 'A') ? seqA[0] : seqB[0];
        applyFrame(startFrame);

        sendStatus();
      } else {
        SerialBT.println("ERR:EMPTY");
      }
    }
  } else if (cmd == "STOP") {
    isPlaying = false;
    convRunning = false;
    updateConveyor(0);
    sendStatus();
  } else if (cmd == "POS?") {
    String cur = "POS:" + String((int)currentPhysical[0]) + "," +
                          String((int)currentPhysical[1]) + "," +
                          String((int)currentPhysical[2]) + "," +
                          String((int)currentPhysical[3]) + "," +
                          String(targetConv) + "\n";
    SerialBT.print(cur);
  }
}

// ==========================================
// SMOOTH SERVO ENGINE
// ==========================================
void updateServosSmoothly() {
  if (millis() - lastServoUpdate >= SERVO_INTERVAL) {
    lastServoUpdate = millis();
    for (int i = 0; i < 4; i++) {
      if (abs((float)targetAngles[i] - currentPhysical[i]) > 0.1) {
        if (targetAngles[i] > currentPhysical[i]) {
          currentPhysical[i] += SERVO_SPEED;
          if (currentPhysical[i] > targetAngles[i]) currentPhysical[i] = targetAngles[i];
        } else {
          currentPhysical[i] -= SERVO_SPEED;
          if (currentPhysical[i] < targetAngles[i]) currentPhysical[i] = targetAngles[i];
        }
        servos[i].write((int)currentPhysical[i]);
      }
    }
  }
}

// ==========================================
// SETUP
// ==========================================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); // Nonaktifkan brownout reset saat tegangan sesaat drop karena servo
  Serial.begin(115200);
  Serial.println("Robot Arm & Conveyor ESP32 Bluetooth Starting...");

  // Inisialisasi Servo Lengan secara bertahap (mencegah inrush current brownout)
  for (int i = 0; i < 4; i++) {
    targetAngles[i] = POS_HOME[i];
    currentPhysical[i] = (float)POS_HOME[i];
    servos[i].write(POS_HOME[i]);
    delay(15);
    servos[i].attach(PIN_SERVO[i]);
  }

  // Inisialisasi Conveyor 360
  convServo.write(CONV_STOP);
  delay(15);
  convServo.attach(PIN_CONV);
  loadSequences();

  // Inisialisasi Bluetooth Serial Classic
  SerialBT.begin(BT_DEVICE_NAME);
  Serial.printf("Bluetooth Aktif! Cari dan hubungkan ke '%s'\n", BT_DEVICE_NAME);
}

// ==========================================
// MAIN LOOP
// ==========================================
void loop() {
  // 1. Terima data dari Bluetooth Serial secara non-blocking
  while (SerialBT.available()) {
    char c = (char)SerialBT.read();
    if (c == '\n' || c == '\r') {
      if (rxBuffer.length() > 0) {
        processCommand(rxBuffer);
        rxBuffer = "";
      }
    } else {
      rxBuffer += c;
      if (rxBuffer.length() > 64) rxBuffer = ""; // Mencegah buffer overflow
    }
  }

  // 2. Gerakkan servo dengan kecepatan halus (interpolasi linear)
  updateServosSmoothly();

  // 3. Logika Auto-Play Sequence
  if (isPlaying) {
    int maxCount = (playSeq == 'A') ? countA : countB;
    if (maxCount > 0) {
      // 3a. Kontrol waktu durasi konveyor
      if (convRunning && currentFrameConvDur > 0) {
        if (millis() - convStartTime >= (unsigned long)currentFrameConvDur) {
          convRunning = false;
          updateConveyor(0); // Konveyor otomatis berhenti sesuai durasi terekam!
        }
      }

      // 3b. Cek pergerakan servo lengan
      bool armReached = true;
      for (int i = 0; i < 4; i++) {
        if (abs(currentPhysical[i] - (float)targetAngles[i]) > 0.6) {
          armReached = false;
          break;
        }
      }

      // Frame dianggap tuntas jika servo sudah sampai target dan durasi konveyor sudah selesai
      bool frameDone = armReached && (!convRunning || currentFrameConvDur == 0);

      if (frameDone) {
        if (!isWaitingNextFrame) {
          isWaitingNextFrame = true;
          playPauseTimer = millis();
        } else {
          if (millis() - playPauseTimer > PAUSE_BETWEEN_FRAMES) {
            playIndex++;
            if (playIndex >= maxCount) playIndex = 0;

            Frame nextFrame = (playSeq == 'A') ? seqA[playIndex] : seqB[playIndex];
            applyFrame(nextFrame);

            isWaitingNextFrame = false;
            lastReportedIndex = playIndex;
            sendStatus(); // Update status frame index ke Flutter
          }
        }
      }
    }
  }

  // Kirim status berkala jika frame index berubah
  if (isPlaying && playIndex != lastReportedIndex) {
    lastReportedIndex = playIndex;
    sendStatus();
  }
}
