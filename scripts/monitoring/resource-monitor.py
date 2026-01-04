#!/usr/bin/env python3

"""
Resource Monitor Script
Author: Iskandar Kurbonov
Description: Monitor CPU, RAM, disk and send alerts
Usage: python3 resource-monitor.py [--interval 60] [--threshold 80]
"""

import psutil
import time
import argparse
import json
import requests
from datetime import datetime

class ResourceMonitor:
    def __init__(self, interval=60, cpu_threshold=80, memory_threshold=85, disk_threshold=90):
        self.interval = interval
        self.cpu_threshold = cpu_threshold
        self.memory_threshold = memory_threshold
        self.disk_threshold = disk_threshold
        self.slack_webhook = None
        self.telegram_token = None
        self.telegram_chat_id = None

    def get_cpu_usage(self):
        """Get CPU usage percentage"""
        return psutil.cpu_percent(interval=1, percpu=False)

    def get_memory_usage(self):
        """Get memory usage information"""
        mem = psutil.virtual_memory()
        return {
            'total': mem.total // (1024**3),  # GB
            'used': mem.used // (1024**3),
            'percent': mem.percent
        }

    def get_disk_usage(self):
        """Get disk usage for all partitions"""
        disks = []
        for partition in psutil.disk_partitions():
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                disks.append({
                    'device': partition.device,
                    'mountpoint': partition.mountpoint,
                    'total': usage.total // (1024**3),
                    'used': usage.used // (1024**3),
                    'percent': usage.percent
                })
            except PermissionError:
                continue
        return disks

    def get_network_stats(self):
        """Get network statistics"""
        net_io = psutil.net_io_counters()
        return {
            'bytes_sent': net_io.bytes_sent // (1024**2),  # MB
            'bytes_recv': net_io.bytes_recv // (1024**2)
        }

    def check_thresholds(self):
        """Check if any metrics exceed thresholds"""
        alerts = []

        # Check CPU
        cpu = self.get_cpu_usage()
        if cpu > self.cpu_threshold:
            alerts.append(f"⚠️ CPU usage is {cpu}% (threshold: {self.cpu_threshold}%)")

        # Check Memory
        memory = self.get_memory_usage()
        if memory['percent'] > self.memory_threshold:
            alerts.append(f"⚠️ Memory usage is {memory['percent']}% (threshold: {self.memory_threshold}%)")

        # Check Disk
        for disk in self.get_disk_usage():
            if disk['percent'] > self.disk_threshold:
                alerts.append(f"⚠️ Disk {disk['mountpoint']} usage is {disk['percent']}% (threshold: {self.disk_threshold}%)")

        return alerts

    def send_slack_alert(self, message):
        """Send alert to Slack"""
        if not self.slack_webhook:
            return

        payload = {
            'text': f"🚨 Resource Monitor Alert",
            'attachments': [{
                'color': 'danger',
                'text': '\n'.join(message)
            }]
        }

        try:
            requests.post(self.slack_webhook, json=payload)
            print(f"✓ Slack alert sent")
        except Exception as e:
            print(f"✗ Failed to send Slack alert: {e}")

    def send_telegram_alert(self, message):
        """Send alert to Telegram"""
        if not self.telegram_token or not self.telegram_chat_id:
            return

        url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"
        payload = {
            'chat_id': self.telegram_chat_id,
            'text': f"🚨 Resource Monitor Alert\n\n{chr(10).join(message)}",
            'parse_mode': 'HTML'
        }

        try:
            requests.post(url, json=payload)
            print(f"✓ Telegram alert sent")
        except Exception as e:
            print(f"✗ Failed to send Telegram alert: {e}")

    def print_stats(self):
        """Print current statistics"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"\n{'='*60}")
        print(f"Resource Monitor - {timestamp}")
        print(f"{'='*60}")

        # CPU
        cpu = self.get_cpu_usage()
        print(f"\n📊 CPU Usage: {cpu}%")

        # Memory
        memory = self.get_memory_usage()
        print(f"\n💾 Memory:")
        print(f"  Total: {memory['total']} GB")
        print(f"  Used: {memory['used']} GB")
        print(f"  Usage: {memory['percent']}%")

        # Disk
        print(f"\n💿 Disk:")
        for disk in self.get_disk_usage():
            print(f"  {disk['mountpoint']}: {disk['used']}/{disk['total']} GB ({disk['percent']}%)")

        # Network
        network = self.get_network_stats()
        print(f"\n🌐 Network:")
        print(f"  Sent: {network['bytes_sent']} MB")
        print(f"  Received: {network['bytes_recv']} MB")

        print(f"{'='*60}")

    def run(self):
        """Main monitoring loop"""
        print(f"Starting resource monitor (interval: {self.interval}s)")
        print(f"Thresholds - CPU: {self.cpu_threshold}%, Memory: {self.memory_threshold}%, Disk: {self.disk_threshold}%")

        try:
            while True:
                self.print_stats()

                # Check thresholds and send alerts
                alerts = self.check_thresholds()
                if alerts:
                    print(f"\n⚠️ ALERTS:")
                    for alert in alerts:
                        print(f"  {alert}")

                    self.send_slack_alert(alerts)
                    self.send_telegram_alert(alerts)

                time.sleep(self.interval)

        except KeyboardInterrupt:
            print("\n\nMonitoring stopped by user")

def main():
    parser = argparse.ArgumentParser(description='Resource Monitor')
    parser.add_argument('--interval', type=int, default=60, help='Check interval in seconds (default: 60)')
    parser.add_argument('--cpu-threshold', type=int, default=80, help='CPU threshold percentage (default: 80)')
    parser.add_argument('--memory-threshold', type=int, default=85, help='Memory threshold percentage (default: 85)')
    parser.add_argument('--disk-threshold', type=int, default=90, help='Disk threshold percentage (default: 90)')
    parser.add_argument('--slack-webhook', help='Slack webhook URL for alerts')
    parser.add_argument('--telegram-token', help='Telegram bot token')
    parser.add_argument('--telegram-chat-id', help='Telegram chat ID')

    args = parser.parse_args()

    monitor = ResourceMonitor(
        interval=args.interval,
        cpu_threshold=args.cpu_threshold,
        memory_threshold=args.memory_threshold,
        disk_threshold=args.disk_threshold
    )

    if args.slack_webhook:
        monitor.slack_webhook = args.slack_webhook

    if args.telegram_token and args.telegram_chat_id:
        monitor.telegram_token = args.telegram_token
        monitor.telegram_chat_id = args.telegram_chat_id

    monitor.run()

if __name__ == '__main__':
    main()
