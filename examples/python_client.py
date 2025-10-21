#!/usr/bin/env python3
"""
Polyglot Realtime Engine - Python HTTP Client Example
"""

import requests
import json
import time

class PolyglotClient:
    def __init__(self, base_url="http://localhost:4000", app_id="demo-app", api_key="valid_key_demo-app"):
        self.base_url = base_url
        self.app_id = app_id
        self.api_key = api_key
        self.headers = {
            "Content-Type": "application/json",
            "X-API-Key": api_key
        }

    def publish_event(self, channel, event_type, data):
        """Publish an event to a channel"""
        url = f"{self.base_url}/apps/{self.app_id}/channels/{channel}/publish"
        payload = {
            "type": event_type,
            "data": data
        }

        response = requests.post(url, json=payload, headers=self.headers)
        if response.status_code == 200:
            result = response.json()
            print(f"Published event: {result['id']}")
            return result['id']
        else:
            print(f"Failed to publish: {response.text}")
            return None

    def get_history(self, channel):
        """Get event history for a channel"""
        url = f"{self.base_url}/apps/{self.app_id}/channels/{channel}/history"
        response = requests.get(url, headers=self.headers)

        if response.status_code == 200:
            return response.json()['events']
        else:
            print(f"Failed to get history: {response.text}")
            return []

# Ya3nyy zayy kedaa maslan..
if __name__ == "__main__":
    client = PolyglotClient()

    # Publish shwayat messages yaboyaa
    client.publish_event("room:general", "message", {"text": "Hello from Python!"})
    client.publish_event("room:general", "message", {"text": "This is a test message"})

    time.sleep(1)  # Wait a bit

    # Get history
    history = client.get_history("room:general")
    print("Event history:")
    for event in history:
        print(f"- {event['type']}: {event['data']}")
