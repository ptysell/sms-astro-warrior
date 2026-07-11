// Minimal C shim over SMS Plus GX — a clean, Swift-friendly SMS core surface.
// GPL-2 core (see smsplus/): this module is DEV/DEBUG ONLY and must not ship in the app.
#ifndef SMSCORE_H
#define SMSCORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Load an SMS ROM from memory (Sega mapper). Returns 1 on success.
int  sms_core_load(const uint8_t *data, int size);
void sms_core_reset(void);
void sms_core_shutdown(void);

// Controller-1 button bitfield + Master System pause line.
void sms_core_set_buttons(uint32_t buttons, int pause);

// Advance exactly one video frame (~60 Hz NTSC).
void sms_core_run_frame(void);

// RGBA8888 framebuffer, 256×192 (bytes R,G,B,A). Fills width/height.
const uint32_t *sms_core_framebuffer(int *width, int *height);

// Peek a byte of Z80 work RAM (address in 0xC000–0xDFFF).
int sms_core_ram(int addr);

// Raw controller port read (0xDC / 0xDD) — diagnostics.
int sms_core_port(int port);

#define SMSB_UP    0x01u
#define SMSB_DOWN  0x02u
#define SMSB_LEFT  0x04u
#define SMSB_RIGHT 0x08u
#define SMSB_B1    0x10u
#define SMSB_B2    0x20u

#ifdef __cplusplus
}
#endif

#endif /* SMSCORE_H */
