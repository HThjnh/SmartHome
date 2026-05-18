import paho.mqtt.client as mqtt
import firebase_admin
from firebase_admin import credentials, db
import json
import time
import os 
import logging
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("BRIDGE")

load_dotenv()

initialized_listeners = {
    'pump': False,
    'mode': False,
    'led_living': False,
    'led_bed': False,
    'led_kitchen': False
}
last_temp = None
last_water = None
last_pump = None  
start_pump_time = None
current_log_id = None

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'databaseURL': os.getenv("FIREBASE_DB_URL")
    })
    logger.info("Firebase initialized successfully.")
except Exception as e:
    logger.info(f"Failed to initialize Firebase: {e}")

#Send command to ESP32 with topic control
def listener_pump(event):
    if not initialized_listeners['pump']:
        initialized_listeners['pump'] = True
        print("Initialize pump listener.")
        return
    
    if event.data is not None:
        cmd = "ON" if event.data == 1 else "OFF"
        client.publish("home/roof/pump_control", cmd)
        print(f"Command from App: {cmd}")

def listener_mode(event):
    if not initialized_listeners['mode']:
        initialized_listeners['mode'] = True
        print("Initialize mode listener.")
        return
        
    if event.data is not None:
        client.publish("home/roof/mode_control", event.data)
        print(f"Command from App: {event.data}")
    
def listener_led_living(event):
    if not initialized_listeners['led_living']:
        initialized_listeners['led_living'] = True
        return
    if event.data is not None:
        cmd = "LIVING_ON" if event.data == 1 else "LIVING_OFF"
        client.publish("home/led/control", cmd)

def listener_led_bed(event):
    if not initialized_listeners['led_bed']:
        initialized_listeners['led_bed'] = True
        return
    if event.data is not None:
        cmd = "BED_ON" if event.data == 1 else "BED_OFF"
        client.publish("home/led/control", cmd)

def listener_led_kitchen(event):
    if not initialized_listeners['led_kitchen']:
        initialized_listeners['led_kitchen'] = True
        return
    if event.data is not None:
        cmd = "KITCHEN_ON" if event.data == 1 else "KITCHEN_OFF"
        client.publish("home/led/control", cmd)

TOPICS = [
    "home/roof/temp/dashboard",
    "home/roof/temp/graph",
    "home/roof/water_level",
    "home/roof/pump_status", 
    "home/led/status",
    "home/roof/system_mode",
    
    "home/roof/pump_control", 
    "home/roof/mode_control",
    "home/led/control"
]

#Listen from ESP32 command
def on_connect(client, userdata, flags, rc):
    print("Connected to HiveMQ, listening 8 topic...")
    for topic in TOPICS:
        client.subscribe(topic)

def on_message(client, userdata, msg):
    global last_temp, last_pump, start_pump_time, current_log_id
    try:
        topic = msg.topic
        raw_payload = msg.payload.decode()
        
        # 1. Decode JSON code (Ues if ESP send JSON code, or use string)
        try:
            payload = json.loads(raw_payload)
        except json.JSONDecodeError:
            payload = raw_payload 

        # 2. LED HANDLE (Topic: home/led/status) - Data synchronization from ESP to Firebase
        if topic == "home/led/status":
            if "_" in payload:
                room, state = payload.split("_")
                status_val = 1 if state == "ON" else 0
                room_map = {
                    "LIVING":  "led_living_status",
                    "KITCHEN": "led_kitchen_status",
                    "BED":     "led_bed_status"
                }
                if room in room_map:
                    db.reference(room_map[room]).set(status_val)
                    print(f"LED Synchronization: {room} is {state}")

        # 3. TEMPARATURE HANDLE (Topic: home/roof/temp/*)
        # 3a. Update temperature to graph
        elif topic == "home/roof/temp/dashboard":
            current_temp = float(payload) 
            db.reference("roof_temp").set(current_temp) 
        # 3b. Update on Dashboard
        elif topic == "home/roof/temp/graph":
            current_temp = float(payload)  
            today_str = time.strftime("%Y_%m_%d")
            db.reference(f"temp_history/{today_str}").push({
                "value": current_temp, 
                "time": time.strftime("%H:%M")
            })
            print(f"Saved temperature history {today_str}: {current_temp}")

        # 4. PUMP HANDLE (Topic: home/roof/pump_status)
        elif topic == "home/roof/pump_status":
            if payload != last_pump:
                if payload == "ON":
                    start_pump_time = time.time()
                    new_log_ref = db.reference("pump_history").push({
                        "status": "ON",
                        "time": time.strftime("%d/%m %H:%M:%S"),
                        "duration": "Đang chạy"
                    })
                    current_log_id = new_log_ref.key
                    db.reference("roof_pump_status").set(1)
                    print(f"Turned Pump")
                elif payload == "OFF" and current_log_id:
                    if start_pump_time:
                        total_second = int(time.time() - start_pump_time)
                        minutes = total_second // 60
                        seconds = total_second % 60

                        if minutes > 0:
                            duration_text = f"{minutes} phút {seconds} giây"
                        else:
                            duration_text = f"{seconds} giây"
                    else:
                        duration_text = "N/A"
                    db.reference(f"pump_history/{current_log_id}").update({
                        "status": "OFF",
                        "duration": duration_text
                    })
                    db.reference("roof_pump_status").set(0)
                    db.reference("pump_control").set(0)
                    current_log_id = None 
                    print(f"Turned off Pump. Time: {duration_text}")
                last_pump = payload

        # 5. WATER LEVEL HANDLE (Topic: home/roof/water_level)
        elif topic == "home/roof/water_level":
            current_water = float(payload)
            db.reference("water_level").set(current_water)
            print(f"Water level: {current_water}%")

        # 6. MODE HANDLE (Topic: home/roof/system_mode)
        elif topic == "home/roof/system_mode":
            db.reference("roof_system_mode").set(payload)
            print(f"System mode: {payload}")

    except Exception as e:
        print(f"Occurred error by {msg.topic}: {e}")

MQTT_BROKER = os.getenv("MQTT_BROKER")
MQTT_PORT = int(os.getenv("MQTT_PORT", 8883))
MQTT_USER = os.getenv("MQTT_USER")
MQTT_PASS = os.getenv("MQTT_PASS")

client = mqtt.Client()
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.tls_set()
client.on_connect = on_connect
client.on_message = on_message
try:
    logger.info("Connecting to MQTT Broker...")
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
except Exception as e:
    logger.error(f"Failed to connect to MQTT Broker: {e}")
    exit(1)

client.loop_start()
print("Bridge currently operating . Press Ctrl+C to stop...")

db.reference('pump_control').listen(listener_pump)
db.reference('mode_control').listen(listener_mode)
db.reference('led_living_control').listen(listener_led_living)
db.reference('led_bed_control').listen(listener_led_bed)
db.reference('led_kitchen_control').listen(listener_led_kitchen)

try:
    while True:
        time.sleep(1) 
except KeyboardInterrupt:
    print("\nStopping Bridge...")
    client.disconnect()
    client.loop_stop()
