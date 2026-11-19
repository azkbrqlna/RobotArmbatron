#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>
#include <Preferences.h> 

// ==========================================
// PIN & HARDWARE SETUP (FULL SERVO)
// ==========================================
const int PIN_SERVO[4] = {13, 14, 27, 26}; // Base, Shoulder, Elbow, Gripper
Servo servos[4];

// Setup Servo 360 untuk Conveyor (Kita pakai Pin 25)
const int PIN_CONV = 25;
Servo convServo;

WebServer server(80);
Preferences preferences;

// ==========================================
// VARIABEL SMOOTH SERVO & CONVEYOR
// ==========================================
const int POS_HOME[4] = {90, 0, 150, 180}; 
int targetAngles[4] = {90, 0, 150, 180};       
float currentPhysical[4] = {90.0, 0.0, 150.0, 180.0}; 

int targetConv = 0; // 0=Stop, 1=Maju, 2=Mundur

unsigned long lastServoUpdate = 0;
const int SERVO_INTERVAL = 15;        
const float SERVO_SPEED = 0.5;        

const int MAX_FRAMES = 50;
struct Frame { 
  int angles[4]; 
  int conv; 
};

Frame seqA[MAX_FRAMES]; int countA = 0;
Frame seqB[MAX_FRAMES]; int countB = 0;

bool isPlaying = false;
char playSeq = 'A';
int playIndex = 0;
bool isWaitingNextFrame = false;
unsigned long playPauseTimer = 0;
const int PAUSE_BETWEEN_FRAMES = 1000; 

// ==========================================
// KODE HTML, CSS & JAVASCRIPT (Sama Persis, Tidak Ada Ubahan)
// ==========================================
const char PAGE_HTML[] PROGMEM = R"=====(
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, orientation=landscape">
  <title>Arm & Conveyor Controller</title>
  <style>
    :root {
      --light-teal: #a8edea; --light-pink: #fed6e3; --accent-pink: #ff6b81;
      --accent-teal: #20b2aa; --glass-bg: rgba(255, 255, 255, 0.7);
      --glass-border: rgba(255, 255, 255, 0.9); --text-dark: #2d3436;
      --danger: #ff4757; --success: #2ed573; --edit-blue: #0984e3;
    }
    body { background: linear-gradient(135deg, var(--light-teal), var(--light-pink)); background-attachment: fixed; color: var(--text-dark); font-family: 'Segoe UI', sans-serif; text-align: center; margin: 0; padding: 15px; touch-action: manipulation; }
    .panel { background: var(--glass-bg); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); border: 2px solid var(--glass-border); border-radius: 20px; box-shadow: 0 8px 32px rgba(31, 38, 135, 0.15); padding: 20px; max-width: 700px; margin: 0 auto; }
    h1 { color: var(--accent-pink); font-size: 24px; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 5px 0; text-shadow: 2px 2px 0px #FFF; font-weight: 900; }
    h2 { font-size: 14px; color: #636e72; margin-top: 0; margin-bottom: 20px; font-weight: bold; }
    .tabs { display: flex; gap: 10px; margin-bottom: 15px; }
    .tab-btn { flex: 1; background: rgba(255,255,255,0.5); color: var(--text-dark); border: 2px solid #FFF; border-radius: 10px; padding: 10px; cursor: pointer; font-weight: bold; transition: all 0.3s; }
    .tab-btn.active { background: var(--accent-pink); color: #FFF; border-color: var(--accent-pink); box-shadow: 0 4px 15px rgba(255, 107, 129, 0.3); }
    .slider-box { background: rgba(255,255,255,0.5); border: 1px solid #FFF; border-radius: 10px; margin: 10px 0; padding: 15px; text-align: left; }
    label { font-weight: bold; color: var(--accent-teal); font-size: 14px; }
    .val-display { float: right; font-weight: bold; color: var(--text-dark); background: #FFF; padding: 2px 8px; border-radius: 5px;}
    input[type=range] { width: 100%; accent-color: var(--accent-pink); margin-top: 10px; }
    .conv-box { background: rgba(32, 178, 170, 0.15); border: 2px solid var(--accent-teal); border-radius: 10px; padding: 15px; margin-top: 15px; }
    .conv-controls { display: flex; gap: 10px; justify-content: center; margin-top: 10px; }
    .conv-btn { flex: 1; padding: 10px; border-radius: 8px; border: 2px solid var(--accent-teal); background: #FFF; color: var(--accent-teal); font-weight: bold; cursor: pointer; }
    .conv-btn.active { background: var(--accent-teal); color: #FFF; }
    .conv-stop.active { background: var(--danger); color: #FFF; border-color: var(--danger); }
    
    .auto-panel { display: none; margin-top: 15px; }
    .seq-selector { display: flex; background: #FFF; border-radius: 10px; padding: 5px; margin-bottom: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
    .seq-btn { flex: 1; background: transparent; color: #a4b0be; border: none; padding: 8px; font-weight: bold; cursor: pointer; border-radius: 8px; font-size: 14px; }
    .seq-btn.active { background: var(--accent-teal); color: #FFF; }
    .timeline-box { background: rgba(255,255,255,0.7); border: 2px solid #FFF; border-radius: 15px; padding: 15px; margin-bottom: 15px; }
    .timeline-header { font-weight: bold; color: var(--accent-teal); font-size: 14px; text-align: left; margin-bottom: 10px; }
    .frames-container { display: flex; overflow-x: auto; gap: 10px; padding: 10px 5px; scroll-behavior: smooth; }
    .frame-item { min-width: 45px; height: 45px; background: #FFF; border: 2px solid var(--accent-teal); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-weight: bold; color: var(--accent-teal); cursor: pointer; transition: all 0.2s; box-shadow: 0 4px 6px rgba(0,0,0,0.05); flex-shrink: 0; }
    .frame-item:hover { transform: translateY(-3px); }
    .frame-item.editing { background: var(--edit-blue); color: #FFF; border-color: var(--edit-blue); box-shadow: 0 0 10px rgba(9, 132, 227, 0.5); transform: scale(1.1); }
    .frame-item.playing { background: var(--accent-pink); color: #FFF; border-color: var(--accent-pink); box-shadow: 0 0 15px var(--accent-pink); transform: scale(1.1); font-size: 18px; }

    .edit-controls { display: flex; gap: 10px; margin-top: 15px; }
    .btn-record { background: var(--accent-pink); color: #FFF; border: none; width: 100%; padding: 12px; border-radius: 8px; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 10px rgba(255,107,129,0.3); margin-top: 10px;}
    .btn-record:active { transform: scale(0.98); }
    .btn-save-edit { background: var(--edit-blue); color: #FFF; border: none; width: 100%; padding: 12px; border-radius: 8px; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 10px rgba(9, 132, 227, 0.3);}
    .btn-cancel-edit { background: transparent; color: var(--text-dark); border: 2px solid #ccc; width: 100%; padding: 12px; border-radius: 8px; font-weight: bold; font-size: 14px; cursor: pointer; }
    .btn-hapus { background: transparent; color: var(--danger); border: 2px solid var(--danger); width: 100%; padding: 10px; border-radius: 8px; font-weight: bold; font-size: 12px; cursor: pointer; margin-top: 15px; }
    
    .exec-box { display: flex; gap: 10px; }
    .btn-play { background: var(--success); color: #FFF; border: none; padding: 15px; border-radius: 10px; flex: 2; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 10px rgba(46, 213, 115, 0.3);}
    .btn-stop { background: var(--danger); color: #FFF; border: none; padding: 15px; border-radius: 10px; flex: 1; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 10px rgba(255, 71, 87, 0.3);}
    .sys-msg { background: rgba(255,255,255,0.9); color: var(--text-dark); padding: 8px; border-radius: 5px; font-size: 12px; margin-top: 20px; font-weight: bold; }
  </style>
</head>
<body>
  <div class="panel">
    <h1>Arm Robot & Conveyor</h1><h2>Oleh Kelompok 4</h2>
    
    <div class="tabs">
      <button class="tab-btn active" id="tab-manual" onclick="switchMode('manual')">🖐️ MANUAL</button>
      <button class="tab-btn" id="tab-auto" onclick="switchMode('auto')">🤖 OTOMATIS</button>
    </div>

    <div id="view-slider">
      <div class="slider-box"><label>BASE</label><div class="val-display" id="v0">90&deg;</div><input type="range" min="0" max="180" value="90" id="s0" oninput="setAngle(0, this.value, 's')"></div>
      <div class="slider-box"><label>SHOULDER</label><div class="val-display" id="v1">0&deg;</div><input type="range" min="0" max="45" value="0" id="s1" oninput="setAngle(1, this.value, 's')"></div>
      <div class="slider-box"><label>ELBOW</label><div class="val-display" id="v2">150&deg;</div><input type="range" min="30" max="180" value="150" id="s2" oninput="setAngle(2, this.value, 's')"></div>
      <div class="slider-box"><label>GRIPPER</label><div class="val-display" id="v3">180&deg;</div><input type="range" min="0" max="180" value="180" id="s3" oninput="setAngle(3, this.value, 's')"></div>
    </div>


    <div class="conv-box">
      <label>⚙️ AKSI CONVEYOR DI TITIK INI</label>
      <div class="conv-controls">
        <button class="conv-btn" id="cb-2" onclick="setConv(2)">◀ MUNDUR</button>
        <button class="conv-btn conv-stop active" id="cb-0" onclick="setConv(0)">STOP</button>
        <button class="conv-btn" id="cb-1" onclick="setConv(1)">MAJU ▶</button>
      </div>
    </div>

    <div class="auto-panel" id="panel-auto">
      <div class="seq-selector">
        <button class="seq-btn active" id="seq-A" onclick="setSeq('A')">SEQUENCE A</button>
        <button class="seq-btn" id="seq-B" onclick="setSeq('B')">SEQUENCE B</button>
      </div>

      <div class="timeline-box">
        <div class="timeline-header">📍 TIMELINE TITIK GERAK</div>
        <div class="frames-container" id="frames-container">
          <div style="color:#a4b0be; font-size:12px; width:100%; text-align:center; padding:10px;">Belum ada titik tersimpan</div>
        </div>
        
        <div id="add-controls">
          <button class="btn-record" onclick="saveNewFrame()">➕ REKAM TITIK & CONVEYOR DI SINI</button>
          <button class="btn-hapus" onclick="undoLast()">🗑️ Hapus 1 Titik Terakhir</button>
        </div>
        
        <div class="edit-controls" id="edit-controls" style="display:none; gap:6px;">
          <button class="btn-cancel-edit" onclick="cancelEdit()">BATAL</button>
          <button class="btn-hapus" onclick="deleteEditingFrame()" style="margin:0; width:100%; border-color:#ff4757; color:#ff4757;">🗑️ HAPUS TITIK INI</button>
          <button class="btn-save-edit" onclick="updateFrame()">💾 SIMPAN</button>
        </div>
      </div>

      <div class="exec-box">
        <button class="btn-play" onclick="startPlay()">▶️ JALANKAN SECARA LOOP</button>
        <button class="btn-stop" onclick="stopPlay()">⏹ STOP DARURAT</button>
      </div>
    </div>
    <div class="sys-msg" id="status-msg">STATUS: MODE MANUAL AKTIF</div>
  </div>

  <script>
    let angles = [90, 0, 150, 180]; 
    const limits = [[0,180], [0,45], [30,180], [0,180]];
    let convState = 0; 
    let moveInterval = null; let lastTime = 0; let fetchTimeout = null;
    let activeSeq = 'A';
    let framesData = []; 
    let editingIndex = -1;
    let playPollInterval = null;

    function switchMode(mode) {
      if(mode === 'manual') {
        document.getElementById('tab-manual').classList.add('active'); document.getElementById('tab-auto').classList.remove('active');
        document.getElementById('panel-auto').style.display = 'none'; document.getElementById('status-msg').innerText = 'STATUS: MODE MANUAL AKTIF';
        stopPlay(); 
      } else {
        document.getElementById('tab-auto').classList.add('active'); document.getElementById('tab-manual').classList.remove('active');
        document.getElementById('panel-auto').style.display = 'block'; document.getElementById('status-msg').innerText = 'STATUS: SIAP MEREKAM (SEQ ' + activeSeq + ')';
        fetchFrames(); 
      }
    }
    function setSeq(seq) {
      activeSeq = seq;
      document.getElementById('seq-A').classList.remove('active'); document.getElementById('seq-B').classList.remove('active');
      document.getElementById('seq-' + seq).classList.add('active'); document.getElementById('status-msg').innerText = 'STATUS: SIAP MEREKAM (SEQ ' + activeSeq + ')';
      cancelEdit(); fetchFrames();
    }
    function setConv(state) {
      convState = state;
      document.getElementById('cb-0').classList.remove('active'); document.getElementById('cb-1').classList.remove('active'); document.getElementById('cb-2').classList.remove('active');
      document.getElementById('cb-' + state).classList.add('active');
      fetch('/conveyor?state=' + state).catch(e => console.log(e));
    }
    function fetchFrames() {
      fetch('/api/get_frames?seq=' + activeSeq).then(res => res.text()).then(data => {
          framesData = [];
          if(data.length > 0) {
            let lines = data.split(';');
            lines.forEach(line => {
              if(line.includes(',')) {
                let parts = line.split(',');
                framesData.push([parseInt(parts[0]), parseInt(parts[1]), parseInt(parts[2]), parseInt(parts[3]), parseInt(parts[4])]);
              }
            });
          }
          renderTimeline();
        }).catch(err => console.log(err));
    }
    function renderTimeline() {
      let container = document.getElementById('frames-container'); container.innerHTML = '';
      if(framesData.length === 0) { container.innerHTML = '<div style="color:#a4b0be; font-size:12px; width:100%; text-align:center; padding:10px;">Belum ada titik tersimpan</div>'; return; }
      framesData.forEach((frame, idx) => {
        let box = document.createElement('div');
        box.className = 'frame-item'; box.id = 'frame-box-' + idx; 
        let icon = ""; if(frame[4] == 1) icon = "▶️"; else if(frame[4] == 2) icon = "◀️";
        box.innerHTML = (idx + 1) + "<br><span style='font-size:10px'>" + icon + "</span>";
        if (idx === editingIndex) box.classList.add('editing');
        box.onclick = () => { selectFrameForEdit(idx); }; container.appendChild(box);
      });
      container.scrollLeft = container.scrollWidth;
    }
    function selectFrameForEdit(idx) {
      editingIndex = idx; let targetAngles = framesData[idx];
      setAngle(0, targetAngles[0]); setAngle(1, targetAngles[1]); setAngle(2, targetAngles[2]); setAngle(3, targetAngles[3]); setConv(targetAngles[4]);
      renderTimeline(); document.getElementById('add-controls').style.display = 'none'; document.getElementById('edit-controls').style.display = 'flex';
      document.getElementById('status-msg').innerText = 'STATUS: MENGEDIT TITIK KE-' + (idx + 1);
    }
    function cancelEdit() {
      editingIndex = -1; renderTimeline(); document.getElementById('add-controls').style.display = 'block'; document.getElementById('edit-controls').style.display = 'none'; document.getElementById('status-msg').innerText = 'STATUS: SIAP MEREKAM (SEQ ' + activeSeq + ')';
    }
    function saveNewFrame() { fetch('/api/save?seq=' + activeSeq).then(res => res.text()).then(data => { fetchFrames(); }).catch(err => console.log(err)); }
    function updateFrame() { if(editingIndex === -1) return; fetch(`/api/update?seq=${activeSeq}&idx=${editingIndex}`).then(res => res.text()).then(data => { cancelEdit(); fetchFrames(); }).catch(err => console.log(err)); }
    function undoLast() { fetch('/api/undo?seq=' + activeSeq).then(res => res.text()).then(data => { fetchFrames(); }).catch(err => console.log(err)); }
    function deleteEditingFrame() {
      if(editingIndex === -1) return;
      fetch(`/api/delete?seq=${activeSeq}&idx=${editingIndex}`).then(res => res.text()).then(data => {
        cancelEdit();
        fetchFrames();
      }).catch(err => console.log(err));
    }
    function startPlay() {
      cancelEdit(); fetch('/api/play?seq=' + activeSeq).then(() => {
        document.getElementById('status-msg').innerText = 'STATUS: ROBOT & CONVEYOR BERJALAN...';
        if(playPollInterval) clearInterval(playPollInterval); playPollInterval = setInterval(pollPlayStatus, 300);
      });
    }
    function stopPlay() {
      fetch('/api/stop').then(() => {
        if(playPollInterval) { clearInterval(playPollInterval); playPollInterval = null; }
        document.getElementById('status-msg').innerText = 'STATUS: BERHENTI.';
        let boxes = document.getElementsByClassName('frame-item'); for(let i=0; i<boxes.length; i++) { boxes[i].classList.remove('playing'); }
        setConv(0); 
      });
    }
    function pollPlayStatus() {
      fetch('/api/play_status').then(res => res.text()).then(data => {
          let parts = data.split(','); let isPlay = parseInt(parts[0]); let currentIdx = parseInt(parts[1]);
          if(isPlay === 1) {
            let boxes = document.getElementsByClassName('frame-item'); for(let i=0; i<boxes.length; i++) { boxes[i].classList.remove('playing'); }
            let activeBox = document.getElementById('frame-box-' + currentIdx); if(activeBox) activeBox.classList.add('playing');
          } else { stopPlay(); }
        }).catch(err => console.log(err));
    }
    function sendData(id, val) {
      let now = Date.now();
      if (now - lastTime > 50) { fetch(`/servo?id=${id}&angle=${val}`).catch(e => console.log(e)); lastTime = now; } 
      else { clearTimeout(fetchTimeout); fetchTimeout = setTimeout(() => { fetch(`/servo?id=${id}&angle=${val}`).catch(e => console.log(e)); lastTime = Date.now(); }, 50); }
    }
    function setAngle(id, val, source = 'system') {
      val = parseInt(val); val = Math.max(limits[id][0], Math.min(limits[id][1], val)); 
      if (angles[id] !== val) {
        angles[id] = val;
        if (source !== 's') { document.getElementById('s'+id).value = val; }
        document.getElementById('v'+id).innerHTML = val + '&deg;';
        sendData(id, val);
      }
    }
    window.oncontextmenu = function(event) { event.preventDefault(); event.stopPropagation(); return false; };
  </script>
</body>
</html>
)=====";

// ==========================================
// FUNGSI SERVO 360 (CONVEYOR)
// ==========================================

const int CONV_STOP = 95; 

// Kecepatan dihitung otomatis berdasarkan titik henti di atas
const int CONV_MAJU_PELAN = CONV_STOP - 12;   
const int CONV_MUNDUR_PELAN = CONV_STOP + 12; 

void updateConveyor(int state) {
  if (state == 1) { // MAJU
    convServo.write(CONV_MAJU_PELAN);
  } else if (state == 2) { // MUNDUR
    convServo.write(CONV_MUNDUR_PELAN);
  } else { // STOP
    convServo.write(CONV_STOP);
  }
}

// ==========================================
// FUNGSI MEMORI NVS (BACKEND ESP32)
// ==========================================
void loadSequences() {
  preferences.begin("robot_arm_v3", true); 
  countA = preferences.getInt("countA", 0);
  if(countA > 0) preferences.getBytes("seqA", seqA, sizeof(Frame) * countA);
  
  countB = preferences.getInt("countB", 0);
  if(countB > 0) preferences.getBytes("seqB", seqB, sizeof(Frame) * countB);
  preferences.end();
}

void saveSequenceData(char seq) {
  preferences.begin("robot_arm_v3", false); 
  if(seq == 'A') {
    preferences.putInt("countA", countA);
    preferences.putBytes("seqA", seqA, sizeof(Frame) * countA);
  } else {
    preferences.putInt("countB", countB);
    preferences.putBytes("seqB", seqB, sizeof(Frame) * countB);
  }
  preferences.end();
}

void setup() {
  Serial.begin(115200);

  // Inisialisasi Servo Lengan secara bertahap (mencegah inrush current brownout)
  for (int i = 0; i < 4; i++) {
    targetAngles[i] = POS_HOME[i];
    currentPhysical[i] = (float)POS_HOME[i];
    servos[i].write(POS_HOME[i]);
    delay(15);
    servos[i].attach(PIN_SERVO[i]);
  }

  // Inisialisasi Servo Conveyor
  convServo.write(CONV_STOP); // Default stop sesuai kalibrasi
  delay(15);
  convServo.attach(PIN_CONV);
  loadSequences();
  WiFi.softAP("RobotArm", "12345678"); 

  // ==========================================
  // ROUTING API
  // ==========================================
  server.on("/", []() { server.send(200, "text/html", PAGE_HTML); });
  
  server.on("/servo", []() {
    if (server.hasArg("id") && server.hasArg("angle")) {
      int id = server.arg("id").toInt();
      int angle = server.arg("angle").toInt();
      if (id == 0) angle = constrain(angle, 0, 180);
      else if (id == 1) angle = constrain(angle, 0, 45);
      else if (id == 2) angle = constrain(angle, 30, 180);
      else if (id == 3) angle = constrain(angle, 0, 180);

      targetAngles[id] = angle; 
      isPlaying = false; 
      server.send(200, "text/plain", "OK");
    }
  });

  server.on("/conveyor", []() {
    if (server.hasArg("state")) {
      targetConv = server.arg("state").toInt();
      updateConveyor(targetConv);
      isPlaying = false; 
      server.send(200, "text/plain", "OK");
    }
  });

  server.on("/api/get_frames", []() {
    char seq = server.arg("seq").charAt(0);
    int count = (seq == 'A') ? countA : countB;
    String out = "";
    out.reserve(count * 20);
    for(int i=0; i<count; i++) {
      Frame f = (seq == 'A') ? seqA[i] : seqB[i];
      out += String(f.angles[0]) + "," + String(f.angles[1]) + "," + String(f.angles[2]) + "," + String(f.angles[3]) + "," + String(f.conv);
      if(i < count-1) out += ";";
    }
    server.send(200, "text/plain", out);
  });

  server.on("/api/save", []() {
    char seq = server.arg("seq").charAt(0);
    int count = (seq == 'A') ? countA : countB;
    if(count < MAX_FRAMES) {
      Frame newFrame;
      for(int i=0; i<4; i++) newFrame.angles[i] = targetAngles[i];
      newFrame.conv = targetConv; 
      
      if(seq == 'A') { seqA[countA] = newFrame; countA++; }
      else { seqB[countB] = newFrame; countB++; }
      saveSequenceData(seq);
      server.send(200, "text/plain", "OK");
    } else {
      server.send(400, "text/plain", "FULL");
    }
  });

  server.on("/api/update", []() {
    char seq = server.arg("seq").charAt(0);
    int idx = server.arg("idx").toInt();
    Frame newFrame;
    for(int i=0; i<4; i++) newFrame.angles[i] = targetAngles[i];
    newFrame.conv = targetConv; 
    if(seq == 'A') seqA[idx] = newFrame; else seqB[idx] = newFrame;
    saveSequenceData(seq);
    server.send(200, "text/plain", "OK");
  });

  server.on("/api/undo", []() {
    char seq = server.arg("seq").charAt(0);
    if(seq == 'A' && countA > 0) { countA--; saveSequenceData('A'); }
    else if(seq == 'B' && countB > 0) { countB--; saveSequenceData('B'); }
    server.send(200, "text/plain", "OK");
  });
  server.on("/api/delete", []() {
    char seq = server.arg("seq").charAt(0);
    int idx = server.arg("idx").toInt();
    int count = (seq == 'A') ? countA : countB;
    if (idx >= 0 && idx < count) {
      if (seq == 'A') {
        for (int i = idx; i < countA - 1; i++) seqA[i] = seqA[i + 1];
        countA--;
        saveSequenceData('A');
      } else {
        for (int i = idx; i < countB - 1; i++) seqB[i] = seqB[i + 1];
        countB--;
        saveSequenceData('B');
      }
      server.send(200, "text/plain", "OK");
    } else {
      server.send(400, "text/plain", "ERR");
    }
  });

  server.on("/api/play", []() {
    char seq = server.arg("seq").charAt(0);
    int count = (seq == 'A') ? countA : countB;
    if(count > 0) {
      playSeq = seq; 
      playIndex = 0; 
      isPlaying = true; 
      isWaitingNextFrame = false;
      
      Frame startFrame = (playSeq == 'A') ? seqA[0] : seqB[0];
      for(int i=0; i<4; i++) targetAngles[i] = startFrame.angles[i];
      targetConv = startFrame.conv;
      updateConveyor(targetConv);
      
      server.send(200, "text/plain", "PLAYING");
    } else {
      server.send(400, "text/plain", "KOSONG");
    }
  });

  server.on("/api/stop", []() {
    isPlaying = false; 
    targetConv = 0;
    updateConveyor(0); 
    server.send(200, "text/plain", "STOPPED");
  });

  server.on("/api/play_status", []() {
    String out = String(isPlaying ? 1 : 0) + "," + String(playIndex);
    server.send(200, "text/plain", out);
  });

  server.begin();
}

// ==========================================
// FUNGSI NON-BLOCKING SMOOTH SERVO 
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
// LOOP UTAMA AUTO-PLAY 
// ==========================================
void loop() {
  server.handleClient(); 
  updateServosSmoothly();

  if (isPlaying) {
    int maxCount = (playSeq == 'A') ? countA : countB;
    if (maxCount > 0) {
      bool allReached = true;
      for(int i = 0; i < 4; i++) {
        if (abs(currentPhysical[i] - (float)targetAngles[i]) > 0.6) {
          allReached = false; break;
        }
      }

      if (allReached) {
        if (!isWaitingNextFrame) {
          isWaitingNextFrame = true;
          playPauseTimer = millis();
        } else {
          if (millis() - playPauseTimer > PAUSE_BETWEEN_FRAMES) {
            playIndex++;
            if (playIndex >= maxCount) playIndex = 0; 
            
            Frame nextFrame = (playSeq == 'A') ? seqA[playIndex] : seqB[playIndex];
            for(int i = 0; i < 4; i++) targetAngles[i] = nextFrame.angles[i];
            
            targetConv = nextFrame.conv;
            updateConveyor(targetConv);
            
            isWaitingNextFrame = false;
          }
        }
      }
    }
  }
}