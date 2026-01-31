# Wiring notes (Raspberry Pi physical pin numbering)

You said: XBee Pro 900HP plugged into pins 2, 9, 8, 10. Typical mapping:

- Pin 2: 5V (VCC) - XBee VCC (use only if XBee accepts 5V)
- Pin 9: GND - common ground
- Pin 8: TXD (GPIO14 / UART0 TX) - connect to XBee DIN (XBee's RX)
- Pin 10: RXD (GPIO15 / UART0 RX) - connect to XBee DOUT (XBee's TX)

Important safety notes:
- Ensure your XBee module voltage requirement (3.3V vs 5V). Most XBee modules are 3.3V. If your XBee needs 3.3V, use a 3.3V regulator or the Pi's 3.3V pin (pin 1) instead of pin 2 (5V).
- Enable the serial port (disable serial console if necessary) via `sudo raspi-config` -> Interface Options -> Serial
- Use `/dev/serial0` or `/dev/ttyAMA0` depending on configuration (set by the OS)
