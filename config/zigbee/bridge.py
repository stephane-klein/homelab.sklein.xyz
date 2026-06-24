import json
import time
import requests
import paho.mqtt.client as mqtt

VM_URL = "http://victoria-metrics-victoria-metrics-single-server.victoria-metrics.svc.cluster.local:8428/api/v1/import/prometheus"
MQTT_BROKER = "mosquitto.zigbee.svc.cluster.local"
MQTT_PORT = 1883
MQTT_TOPIC = "zigbee2mqtt/#"


def on_connect(client, userdata, flags, reason_code):
    client.subscribe(MQTT_TOPIC)
    print(f"Connected/reconnected to {MQTT_BROKER}:{MQTT_PORT}, subscribed to {MQTT_TOPIC}")


def on_message(client, userdata, msg):
    topic = msg.topic
    sensor = topic.split("/")[-1]
    try:
        data = json.loads(msg.payload)
    except json.JSONDecodeError:
        return
    ts = int(time.time() * 1000)
    lines = []
    if "temperature" in data:
        lines.append(f'zigbee_temperature{{sensor="{sensor}"}} {data["temperature"]} {ts}')
    if "humidity" in data:
        lines.append(f'zigbee_humidity{{sensor="{sensor}"}} {data["humidity"]} {ts}')
    if "battery" in data:
        lines.append(f'zigbee_battery{{sensor="{sensor}"}} {data["battery"]} {ts}')
    if lines:
        try:
            requests.post(VM_URL, data="\n".join(lines), timeout=5)
        except requests.RequestException as e:
            print(f"Failed to push to VictoriaMetrics: {e}")


def main():
    while True:
        try:
            client = mqtt.Client()
            client.on_connect = on_connect
            client.on_message = on_message
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            break
        except Exception as e:
            print(f"MQTT connection failed: {e}, retrying in 5s...")
            time.sleep(5)
    client.loop_forever()


if __name__ == "__main__":
    main()
