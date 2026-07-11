// Shim + in-memory ROM loader over SMS Plus GX. Bypasses the core's file/zip loader
// so we can hand it ROM bytes directly and read back an RGBA framebuffer.
#include "smscore.h"
#include "shared.h"

// The core expects the frontend ("port") to provide this global.
t_config option;

// Symbols normally provided by loadrom.c (which we skip in favor of an in-memory
// loader) — supplied here so the core links.
uint8_t gaiden_hack = 0;
void free_rom(void) {
    if (cart.rom) { free(cart.rom); cart.rom = NULL; cart.loaded = 0; }
}
void system_manage_sram(uint8_t *sram, uint8_t slot_number, uint8_t mode) {
    (void)sram; (void)slot_number; (void)mode;   // no SRAM persistence in the debugger
}

static uint16_t g_fb16[256 * 192];      // core renders here (RGB 5:6:5)
static uint32_t g_rgba[256 * 192];      // converted for display (bytes R,G,B,A)
static int      g_loaded = 0;
static int      g_inited = 0;           // system_init runs exactly once per process

int sms_core_load(const uint8_t *data, int size) {
    if (!data || size <= 0) return 0;

    if (cart.rom) { free(cart.rom); cart.rom = NULL; }
    cart.rom = (uint8_t *)malloc((size_t)size);
    if (!cart.rom) return 0;
    memcpy(cart.rom, data, (size_t)size);
    cart.size   = (uint32_t)size;
    cart.pages  = (uint16_t)(size / 0x4000);
    cart.mapper = MAPPER_SEGA;
    cart.loaded = 1;

    // Astro Warrior: Export-region SMS, Sega mapper, NTSC.
    sms.console   = CONSOLE_SMS2;
    sms.display   = DISPLAY_NTSC;
    sms.territory = TERRITORY_EXPORT;
    sms.device[0] = DEVICE_PAD2B;      // standard 2-button pad — else input.pad is ignored
    sms.device[1] = DEVICE_PAD2B;

    memset(&option, 0, sizeof(option));
    option.sndrate = 44100;
    option.fm      = 0;
    option.nosound = 1;
    option.spritelimit = 1;

    memset(&bitmap, 0, sizeof(bitmap));
    bitmap.width  = 256;
    bitmap.height = 192;
    bitmap.depth  = 16;
    bitmap.pitch  = 256 * 2;
    bitmap.data   = (uint8_t *)g_fb16;

    if (!g_inited) { system_init(); g_inited = 1; }   // init-once (singleton core)
    system_poweron();
    g_loaded = 1;
    return 1;
}

void sms_core_reset(void) { if (g_loaded) system_reset(); }

void sms_core_shutdown(void) {
    // Keep the emulator subsystems initialized so the same process can load again
    // without tearing down (and later using) freed global state. Just drop the ROM.
    g_loaded = 0;
    if (cart.rom) { free(cart.rom); cart.rom = NULL; cart.loaded = 0; }
}

void sms_core_set_buttons(uint32_t b, int pause) {
    uint8_t pad = 0;
    if (b & SMSB_UP)    pad |= INPUT_UP;
    if (b & SMSB_DOWN)  pad |= INPUT_DOWN;
    if (b & SMSB_LEFT)  pad |= INPUT_LEFT;
    if (b & SMSB_RIGHT) pad |= INPUT_RIGHT;
    if (b & SMSB_B1)    pad |= INPUT_BUTTON1;
    if (b & SMSB_B2)    pad |= INPUT_BUTTON2;
    input.pad[0] = pad;
    input.pad[1] = 0;
    input.system = pause ? INPUT_PAUSE : 0;
}

void sms_core_run_frame(void) {
    if (!g_loaded) return;
    system_frame(0);
    for (int i = 0; i < 256 * 192; i++) {
        uint16_t p = g_fb16[i];
        uint32_t r = (p >> 11) & 0x1F; r = (r << 3) | (r >> 2);
        uint32_t g = (p >> 5)  & 0x3F; g = (g << 2) | (g >> 4);
        uint32_t bl = p        & 0x1F; bl = (bl << 3) | (bl >> 2);
        // bytes in memory: R, G, B, A (little-endian uint32)
        g_rgba[i] = (0xFFu << 24) | (bl << 16) | (g << 8) | r;
    }
}

const uint32_t *sms_core_framebuffer(int *width, int *height) {
    if (width)  *width  = 256;
    if (height) *height = 192;
    return g_rgba;
}

// Peek Z80 work RAM (0xC000–0xDFFF, 8 KB mirrored). Lets the debugger read the ROM's
// entity table (§ Appendix C) — e.g. the player ship's fixed-point position.
int sms_core_ram(int addr) {
    if (!g_loaded) return 0;
    return sms.wram[(unsigned)addr & 0x1FFF];
}

// Raw controller port read (0xDC/0xDD) as the CPU would see it — diagnostics.
int sms_core_port(int port) {
    return g_loaded ? pio_port_r(port) : 0xFF;
}
