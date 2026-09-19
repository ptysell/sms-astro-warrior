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

int sms_core_vdp_reg(int reg) {
    if (!g_loaded || reg < 0 || reg > 15) return 0;
    return vdp.reg[reg];
}

// Peek a byte of VDP VRAM (0x0000–0x3FFF, 16 KB). Holds the name table, pattern
// generator, and the Sprite Attribute Table (base = sms_core_sat_base()). `vdp` is
// the core's VDP global (extern in vdp.h, pulled in via shared.h).
int sms_core_vram(int addr) {
    if (!g_loaded) return 0;
    return vdp.vram[(unsigned)addr & 0x3FFF];
}

// Peek a byte of VDP CRAM (0x00–0x3F). SMS uses indices 0x00–0x1F: two 16-colour
// palettes (background, then sprites), each byte packed --BBGGRR (6-bit colour).
int sms_core_cram(int addr) {
    if (!g_loaded) return 0;
    return vdp.cram[(unsigned)addr & 0x3F];
}

// Sprite Attribute Table base address in VRAM, derived by the core from VDP reg 5.
int sms_core_sat_base(void) {
    if (!g_loaded) return 0;
    return vdp.satb;
}

// Peek a byte of the Sprite Attribute Table (index relative to the SAT base). The SAT
// layout is: y[0..63] at +0x00, then (x,pattern) pairs at +0x80. 0xD0 in a y-slot ends
// the visible list.
int sms_core_sat(int index) {
    if (!g_loaded) return 0;
    return vdp.vram[(unsigned)(vdp.satb + index) & 0x3FFF];
}

// Poke a byte of Z80 work RAM (0xC000–0xDFFF, 8 KB mirrored) — mirror of sms_core_ram.
// Dev/harness only: lets a stage-warp harness set the variant/stage selector (e.g.
// 0xC240), wave-index (0xC211), or stage counter (0xC25B) to jump into a later zone.
void sms_core_write_ram(int addr, int val) {
    if (!g_loaded) return;
    sms.wram[(unsigned)addr & 0x1FFF] = (uint8_t)(val & 0xFF);
}

// ---- PSG (SN76489) write capture — dev/debug only, opt-in, read-only ----
// A ring of raw bytes written to the PSG data port (0x7F), appended by a hook in the
// SN76489 write path (sn76489.c). It is a STRICT no-op unless capture is enabled and it
// never reads or mutates any emulation state, so it cannot affect timing or determinism.
#define SMS_PSG_LOG_CAP 8192
static uint8_t g_psg_log[SMS_PSG_LOG_CAP];
static int     g_psg_head    = 0;   // next ring slot to write
static int     g_psg_total   = 0;   // total writes since reset (may exceed cap)
static int     g_psg_enabled = 0;   // capture off by default

// Hook called from SN76489_Write on every PSG data write. No-op unless enabled.
void sms_psg_capture_note(int data) {
    if (!g_psg_enabled) return;
    g_psg_log[g_psg_head] = (uint8_t)(data & 0xFF);
    g_psg_head = (g_psg_head + 1) % SMS_PSG_LOG_CAP;
    g_psg_total++;
}

// Enable capture and clear the log.
void sms_core_psg_capture_reset(void) {
    g_psg_enabled = 1;
    g_psg_head = 0;
    g_psg_total = 0;
}

// Total PSG writes captured since the last reset (uncapped; may exceed the ring size).
int sms_core_psg_count(void) { return g_psg_total; }

// Copy up to `max` captured bytes (oldest-first) into `out`, then clear the log; returns
// the number copied. If more than SMS_PSG_LOG_CAP writes occurred, only the most recent
// SMS_PSG_LOG_CAP survive in the ring.
int sms_core_psg_drain(uint8_t *out, int max) {
    if (!out || max <= 0) { g_psg_head = 0; g_psg_total = 0; return 0; }
    int avail = g_psg_total < SMS_PSG_LOG_CAP ? g_psg_total : SMS_PSG_LOG_CAP;
    int n = avail < max ? avail : max;
    int start = (g_psg_total <= SMS_PSG_LOG_CAP) ? 0 : g_psg_head;   // oldest survivor
    for (int i = 0; i < n; i++) out[i] = g_psg_log[(unsigned)(start + i) % SMS_PSG_LOG_CAP];
    g_psg_head = 0; g_psg_total = 0;
    return n;
}
