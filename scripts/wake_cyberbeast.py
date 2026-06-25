#!/usr/bin/env python3
import socket
import struct
import sys

def wake_on_lan(mac_address: str, ip_address: str = "255.255.255.255", port: int = 9):
    """Send a Wake-on-LAN Magic Packet to wake up a device."""
    # Clean the MAC address
    cleaned_mac = mac_address.replace(":", "").replace("-", "")
    if len(cleaned_mac) != 12:
        raise ValueError("Invalid MAC address length. Must be 12 hex characters.")
    
    # Pack the magic packet: 6 bytes of 0xFF followed by 16 repetitions of the MAC address
    hex_data = struct.pack("!B", 0xff) * 6
    mac_bytes = bytes.fromhex(cleaned_mac)
    for _ in range(16):
        hex_data += mac_bytes
        
    # Open socket and send broadcast packet
    print(f"Sending Magic Packet to {mac_address} ({ip_address}:{port})...")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        # Send broadcast
        sock.sendto(hex_data, (ip_address, port))
        # Send targeted subnet IP too as a backup
        sock.sendto(hex_data, ("192.168.1.255", port))
        print("Magic Packet transmitted successfully.")

if __name__ == "__main__":
    mac = "04:d9:f5:81:e2:6e"  # Cyberbeast Physical MAC address
    ip = "192.168.1.19"
    try:
        wake_on_lan(mac, ip_address="255.255.255.255")
    except Exception as e:
        print(f"Error sending Magic Packet: {e}", file=sys.stderr)
        sys.exit(1)
