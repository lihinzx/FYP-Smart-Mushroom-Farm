import time
import busio
import digitalio
import board
import adafruit_rfm9x
import pyrebase
import threading
import requests
import os
from gpiozero import Button, OutputDevice
from datetime import datetime

# ==========================================
#          TELEGRAM CONFIGURATION
# ==========================================
TELEGRAM_TOKEN = "xxxxxx"
TELEGRAM_CHAT_ID = "xxxxxx"

NOTIFICATION_TRACKER = {
    "Site_A": {"exhaust": False, "uv": False, "hum": False, "fan": False},
    "Site_B": {"exhaust": False, "uv": False, "hum": False, "fan": False},
    "Water": "NORMAL"
}

# --- HISTORY LOGGING GLOBALS ---
LAST_HISTORY_LOG_TIME = {"Site_A": 0, "Site_B": 0}
HISTORY_LOG_INTERVAL = 600  # 10 minutes

def send_telegram(message):
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        payload = {"chat_id": TELEGRAM_CHAT_ID, "text": message, "parse_mode": "HTML"}
        requests.post(url, data=payload, timeout=5)
    except Exception as e:
        print(f"[TELEGRAM ERROR] {e}")

# ==========================================
#          FIREBASE CONFIGURATION
# ==========================================
config = {
    "apiKey": "xxxxx",
    "authDomain": "smart-mushroom-iot.firebaseapp.com",
    "databaseURL": "https://smart-mushroom-iot-default-rtdb.asia-southeast1.firebasedatabase.app/",
    "storageBucket": "smart-mushroom-iot.appspot.com"
}

email = "xxxxxxxxxxx"
password = "xxxxxxxxxxxxx"

firebase = pyrebase.initialize_app(config)
auth = firebase.auth()
db = firebase.database()

user = None
token_expiry = 0

def authenticate_firebase():
    global user, token_expiry
    try:
        user = auth.sign_in_with_email_and_password(email, password)
        print("Firebase Authentication Successful")
        token_expiry = time.time() + 3000 
    except Exception as e:
        print(f"Firebase Auth Failed: {e}")
        user = None

authenticate_firebase()

def check_firebase_token():
    global user, token_expiry
    if user is None or time.time() > token_expiry:
        try:
            if user:
                user = auth.refresh(user['refreshToken'])
            else:
                user = auth.sign_in_with_email_and_password(email, password)
            token_expiry = time.time() + 3000 
        except Exception as e:
            print(f"Failed to refresh token: {e}")

def log_to_history(site_id, temp, hum, co2, lux):
    global LAST_HISTORY_LOG_TIME
    now = time.time()
    if now - LAST_HISTORY_LOG_TIME[site_id] >= HISTORY_LOG_INTERVAL:
        try:
            date_key = datetime.now().strftime("%Y-%m-%d")
            time_key = datetime.now().strftime("%H%M")
            history_path = f"{site_id}/history/{date_key}"
            updates = {
                f"temperature/{time_key}": temp,
                f"humidity/{time_key}": hum,
                f"co2/{time_key}": co2,
                f"lux/{time_key}": lux
            }
            db.child(history_path).update(updates, user['idToken'])
            LAST_HISTORY_LOG_TIME[site_id] = now
        except Exception as e:
            print(f" [GRAPH ERROR] {e}")

# ==========================================
#          WATER LEVEL CONTROL
# ==========================================
WATER_LOW_PIN = 20
WATER_HIGH_PIN = 21
WATER_PUMP_PIN = 26 

CURRENT_WATER_LEVEL = "NORMAL"
CURRENT_PUMP_STATUS = "OFF"

def water_level_monitor_loop():
    global CURRENT_WATER_LEVEL, CURRENT_PUMP_STATUS
    low_sensor = Button(WATER_LOW_PIN, bounce_time=0.1)
    high_sensor = Button(WATER_HIGH_PIN, bounce_time=0.1)
    pump = OutputDevice(WATER_PUMP_PIN, active_high=False, initial_value=False)
    is_refilling = False

    while True:
        try:
            low_triggered = low_sensor.is_pressed
            high_triggered = high_sensor.is_pressed
            if not is_refilling:
                if low_triggered:
                    pump.on()
                    is_refilling = True
                    CURRENT_WATER_LEVEL = "LOW"
                    CURRENT_PUMP_STATUS = "ON"
                    send_telegram("💧 <b>Water Alert:</b> Level is LOW. Pump started.")
                else:
                    CURRENT_WATER_LEVEL = "NORMAL"
                    CURRENT_PUMP_STATUS = "OFF"
            else:
                if high_triggered:
                    pump.off()
                    is_refilling = False
                    CURRENT_WATER_LEVEL = "FULL"
                    CURRENT_PUMP_STATUS = "OFF"
                    send_telegram("✅ <b>Water Alert:</b> Tank is FULL. Pump stopped.")
                else:
                    CURRENT_WATER_LEVEL = "FILLING..."
                    CURRENT_PUMP_STATUS = "ON"
            time.sleep(0.5)
        except Exception as e:
            time.sleep(1)

# ==========================================
#          LORA & RELAY CONFIG
# ==========================================
RFM9X_FREQ = 433.0
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)
CS = digitalio.DigitalInOut(board.CE0)
RESET = digitalio.DigitalInOut(board.D25)

relay_shared_hum = digitalio.DigitalInOut(board.D17)
relay_shared_hum.direction = digitalio.Direction.OUTPUT
relay_shared_fan = digitalio.DigitalInOut(board.D27) 
relay_shared_fan.direction = digitalio.Direction.OUTPUT

relay_a_uv = digitalio.DigitalInOut(board.D22)
relay_a_uv.direction = digitalio.Direction.OUTPUT
relay_a_exhaust = digitalio.DigitalInOut(board.D23)
relay_a_exhaust.direction = digitalio.Direction.OUTPUT

relay_b_uv = digitalio.DigitalInOut(board.D13)
relay_b_uv.direction = digitalio.Direction.OUTPUT
relay_b_exhaust = digitalio.DigitalInOut(board.D19)
relay_b_exhaust.direction = digitalio.Direction.OUTPUT

try:
    rfm9x = adafruit_rfm9x.RFM9x(spi, CS, RESET, RFM9X_FREQ)
    rfm9x.tx_power = 23
    print("LoRa receiver initialized.")
except RuntimeError as error:
    print(f"LoRa Init Error: {error}")
    exit()

LAST_SHARED_HUMIDIFIER = False
LAST_SHARED_BLOW_FAN = False

def sync_shared_devices(val_a, val_b, last_known_state, device_name):
    new_state = last_known_state
    if val_a != last_known_state:
        new_state = val_a
        try:
            db.child("Site_B").child("manual_controls").update({device_name: val_a}, user['idToken'])
        except: pass
    elif val_b != last_known_state:
        new_state = val_b
        try:
            db.child("Site_A").child("manual_controls").update({device_name: val_b}, user['idToken'])
        except: pass
    return new_state

# ==========================================
#          MAIN EXECUTION
# ==========================================
if __name__ == "__main__":
    send_telegram("🚀 <b>System Online:</b> Raspberry Pi is monitoring the Mushroom Farm.")
    
    water_thread = threading.Thread(target=water_level_monitor_loop, daemon=True)
    water_thread.start()

    LIGHT_ON_HOUR = 8   
    LIGHT_OFF_HOUR = 20  

    while True:
        try:
            packet = rfm9x.receive(timeout=1.0)
            check_firebase_token()
            
            # 1. GET MANUAL CONTROLS
            manual_a, manual_b = {}, {}
            try:
                manual_a = db.child("Site_A").child("manual_controls").get(user['idToken']).val() or {}
                manual_b = db.child("Site_B").child("manual_controls").get(user['idToken']).val() or {}
                
                hum_a, hum_b = manual_a.get("humidifier", False), manual_b.get("humidifier", False)
                fan_a, fan_b = manual_a.get("blow_fan", False), manual_b.get("blow_fan", False)

                LAST_SHARED_HUMIDIFIER = sync_shared_devices(hum_a, hum_b, LAST_SHARED_HUMIDIFIER, "humidifier")
                LAST_SHARED_BLOW_FAN = sync_shared_devices(fan_a, fan_b, LAST_SHARED_BLOW_FAN, "blow_fan")
            except: pass

            if packet is not None:
                packet_text = str(packet, 'utf-8')
                start_index, end_index = packet_text.find('<'), packet_text.find('>')

                if start_index != -1 and end_index > start_index:
                    clean_data = packet_text[start_index + 1 : end_index]
                    data = {} 
                    for item in clean_data.split(','):
                        kv = item.split(':', 1)
                        if len(kv) == 2: data[kv[0].strip()] = kv[1].strip()
                    
                    raw_site = data.get('site', 'A') 
                    base_path = raw_site if "Site_" in raw_site else f"Site_{raw_site}" 
                    site_id = "Site_A" if "A" in base_path else "Site_B"

                    try:
                        co2_val = float(data.get('co2', 0))
                        temp_val = float(data.get('temp', 0))
                        hum_val = float(data.get('hum', 0))
                        lux_val = float(data.get('lux', 0))
                    except: continue

                    # --- CONTROL LOGIC ---
                    settings_snapshot = db.child(base_path).child("settings").get(user['idToken']).val() or {}
                    control_mode = settings_snapshot.get("control_mode", "auto")
                    growth_mode = settings_snapshot.get("growth_mode", "unknown")

                    site_exhaust_active = False
                    site_uv_active = False

                    if control_mode == "manual":
                        if "Site_A" in base_path:
                            site_exhaust_active = manual_a.get("exhaust_fan", False)
                            site_uv_active = manual_a.get("uv_light", False)
                        else:
                            site_exhaust_active = manual_b.get("exhaust_fan", False)
                            site_uv_active = manual_b.get("uv_light", False)
                        final_hum_status, final_fan_status = LAST_SHARED_HUMIDIFIER, LAST_SHARED_BLOW_FAN
                    else: 
                        # Auto Logic
                        target_hum_min, target_temp_max, target_co2_limit = 0, 35, 20000
                        target_lux_min, mode_needs_light = 0, False

                        if growth_mode == "spawn_run":
                            target_hum_min, target_temp_max, target_co2_limit = 90.0, 25.0, 20000.0
                        elif growth_mode == "pin_head":
                            target_hum_min, target_temp_max, target_co2_limit, target_lux_min, mode_needs_light = 95.0, 19.0, 600.0, 2000.0, True
                        elif growth_mode == "cropping":
                            target_hum_min, target_temp_max, target_co2_limit, target_lux_min, mode_needs_light = 85.0, 25.0, 600.0, 500.0, True

                        current_hour = datetime.now().hour
                        is_daytime = LIGHT_ON_HOUR <= current_hour < LIGHT_OFF_HOUR
                        if mode_needs_light and is_daytime:
                            site_uv_active = (lux_val < target_lux_min)

                        needs_mist = (hum_val < target_hum_min) or (temp_val > target_temp_max)
                        final_hum_status = final_fan_status = needs_mist
                        site_exhaust_active = (co2_val > target_co2_limit)

                    # --- HARDWARE EXECUTION ---
                    relay_shared_hum.value = final_hum_status
                    relay_shared_fan.value = final_fan_status

                    if "A" in base_path:
                        relay_a_uv.value, relay_a_exhaust.value = site_uv_active, site_exhaust_active
                    elif "B" in base_path:
                        relay_b_uv.value, relay_b_exhaust.value = site_uv_active, site_exhaust_active

                    # --- TELEGRAM NOTIFICATIONS ---
                    nt = NOTIFICATION_TRACKER[site_id]
                    if site_exhaust_active != nt["exhaust"]:
                        send_telegram(f"🌬 <b>{site_id} Exhaust Fan:</b> {'ON' if site_exhaust_active else 'OFF'}")
                        nt["exhaust"] = site_exhaust_active
                    if site_uv_active != nt["uv"]:
                        send_telegram(f"💡 <b>{site_id} UV Light:</b> {'ON' if site_uv_active else 'OFF'}")
                        nt["uv"] = site_uv_active

                    # --- TERMINAL DASHBOARD ---
                    os.system('clear') # Keep terminal clean
                    print("="*45)
                    print(f" 🍄 MUSHROOM FARM MONITOR: {base_path} ")
                    print(f" 🕒 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                    print("-" * 45)
                    print(f" 🌡️  Temperature: {temp_val:>6.2f} °C")
                    print(f" 💧  Humidity:    {hum_val:>6.2f} %")
                    print(f" ☁️  CO2 Level:   {co2_val:>6.0f} ppm")
                    print(f" ☀️  Light (Lux): {lux_val:>6.0f} lx")
                    print("-" * 45)
                    print(f" 🌫️  Mistmaker:    {'✅ ON' if final_hum_status else '❌ OFF'}")
                    print(f" 💡  UV Light:     {'✅ ON' if site_uv_active else '❌ OFF'}")
                    print(f" 🌬️  Exhaust Fan:  {'✅ ON' if site_exhaust_active else '❌ OFF'}")
                    print(f" 🚰  Water Pump:   {CURRENT_PUMP_STATUS}")
                    print(f" 📊  Tank Level:   {CURRENT_WATER_LEVEL}")
                    print("-" * 45)
                    print(f" 🛠️  Control Mode: {control_mode.upper()}")
                    print(f" 🌱  Growth Stage: {growth_mode.upper()}")
                    print("="*45)

                    # --- UPLOAD REALTIME STATUS ---
                    firebase_data = {
                        "co2": co2_val, "temperature": temp_val, "humidity": hum_val, "lux": lux_val,
                        "timestamp": {".sv": "timestamp"},
                        "humidifier_status": "ON" if final_hum_status else "OFF",
                        "blow_fan_status": "ON" if final_fan_status else "OFF",
                        "uv_light_status": "ON" if site_uv_active else "OFF",
                        "exhaust_fan_status": "ON" if site_exhaust_active else "OFF",
                        "water_level_status": CURRENT_WATER_LEVEL,
                        "water_pump_status": CURRENT_PUMP_STATUS,
                        "active_mode": control_mode.upper() 
                    }
                    db.child(base_path).child("sensor").set(firebase_data, user['idToken'])
                    
                    # LOG HISTORY FOR GRAPH
                    log_to_history(site_id, temp_val, hum_val, co2_val, lux_val)

        except Exception as e:
            print(f"Loop Error: {e}")
            time.sleep(1)