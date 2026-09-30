# HeavenlyPad

HeavenlyPad is a purpose-built, ultra-low latency native macOS Nintendo DS emulator designed specifically for playing *Rhythm Heaven DS* (Rhythm Tengoku Gold). 

By leveraging native Apple frameworks (SwiftUI, Metal, Core Audio) and absolute Trackpad coordinate mapping, HeavenlyPad faithfully recreates the original stylus experience on your Mac trackpad with zero input lag.

## Features
- **Absolute Trackpad Mapping:** Flick and tap your trackpad exactly like a Nintendo DS touchscreen. No clicking-and-dragging required.
- **Ultra-Low Latency:** Custom lock-free Core Audio engine and Metal rendering pipeline strictly designed for rhythm games.
- **AirPods A/V Calibration:** Built-in video delay slider to perfectly sync visuals with the inherent Bluetooth audio delay of wireless headphones.
- **Cloud Saves:** Automatically saves your `.sav` files to your Documents folder, syncing effortlessly with iCloud Drive.
- **Native macOS Experience:** Written entirely in Swift, dynamically adapting to your macOS environment.

---

## Attributions & Acknowledgements

This project stands on the shoulders of giants. HeavenlyPad is a custom macOS frontend, but the heavy lifting of the emulation is powered by incredible open-source projects:

* **[melonDS](https://melonds.kuribo64.net/)**: Massive thanks to Arisotura and the melonDS contributors. The core CPU/GPU emulation inside HeavenlyPad is entirely powered by a compiled `melonds_libretro` core.
* **[Libretro](https://www.libretro.com/)**: For their lightweight and incredibly robust C API that makes bridging Swift and C++ emulators seamless.
* **Rhythm Heaven Community**: For keeping the love for this incredible franchise alive.

---

## Legal Mentions & Disclaimer

**HeavenlyPad is an open-source, non-commercial fan project.**
* "Nintendo", "Nintendo DS", and "Rhythm Heaven" are registered trademarks of **Nintendo Co., Ltd.**
* HeavenlyPad is **in no way affiliated with, authorized, maintained, sponsored, or endorsed by Nintendo** or any of its affiliates or subsidiaries.
* **NO ROMS OR COPYRIGHTED MATERIAL ARE INCLUDED.** This application does not contain any game files, BIOS files, or copyrighted assets. It is a blank emulator. Users are entirely responsible for legally dumping their own purchased copies of the game from their own hardware. The promotion or discussion of piracy is strictly prohibited.

## License

The Swift frontend code of HeavenlyPad is licensed under the **MIT License**. 
However, please note that the bundled `melonds_libretro.dylib` core is licensed under the **GNU GPLv3**. Therefore, if you distribute compiled binaries of HeavenlyPad that include the core, the combined work must comply with the terms of the GPLv3. See the `LICENSE` file for details.
