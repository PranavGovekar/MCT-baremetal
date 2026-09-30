#include "xparameters.h"
#include "xil_printf.h"
#include "xiicps.h"
#include "sleep.h"
#include "xil_io.h"

/* ============================================================
 * Demo printing control
 * ============================================================
 *
 * PRINT_EVERY_N = 1 prints every event.
 *
 * WARNING:
 * This format prints many lines per event over UART.
 * It is very human-readable, but it is slow.
 *
 * If your event rate is high and the terminal cannot keep up,
 * change PRINT_EVERY_N to 10 or 100.
 */
#define PRINT_EVERY_N       1

/* ============================================================
 * I2C / DAC constants for ZCU102 + FMC-DIO-5CH-TTL-A
 * ============================================================ */
#define IIC_DEVICE_ID       XPAR_XIICPS_1_DEVICE_ID
#define IIC_SCLK_RATE       100000

#define I2C_MUX_ADDR        0x74
#define MUX_CH_FMC_HPC0     0x80

#define DAC5578_ADDR        0x48
#define DAC_VREF_MV         3300u
#define DAC_TARGET_MV       1000u

/* ============================================================
 * AXI GPIO addresses from the Vivado TCL script
 * ============================================================ */
#define AXI_GPIO_CTRL_BASE      0xA0010000
#define AXI_GPIO_CONFIG_BASE    0xA0020000
#define AXI_GPIO_STATUS_BASE    0xA0030000

#define GPIO_DATA_OFFSET        0x00
#define GPIO_TRI_OFFSET         0x04
#define GPIO2_DATA_OFFSET       0x08
#define GPIO2_TRI_OFFSET        0x0C

/* Control GPIO bits:
 *   bit 0 = enable
 *   bit 1 = FIFO pop pulse
 */
#define CTRL_ENABLE             0x01u
#define CTRL_ENABLE_POP         0x03u

#define POP_PULSE_US            10u

static XIicPs Iic;

/* ------------------------------------------------------------
 * Simple polled I2C write
 * ------------------------------------------------------------ */
static int i2c_send(u8 addr, u8 *buf, int len)
{
    int ret = XIicPs_MasterSendPolled(&Iic, buf, len, addr);
    while (XIicPs_BusIsBusy(&Iic));
    return ret;
}

/* ------------------------------------------------------------
 * Initialize I2C mux and DAC5578
 * ------------------------------------------------------------ */
static int dac_init(void)
{
    XIicPs_Config *cfg;
    u8 mux_sel = MUX_CH_FMC_HPC0;
    u8 code = (u8)((DAC_TARGET_MV * 255UL) / DAC_VREF_MV);
    u8 buf[3];
    int ch;

    cfg = XIicPs_LookupConfig(IIC_DEVICE_ID);
    if (!cfg) {
        return XST_FAILURE;
    }

    if (XIicPs_CfgInitialize(&Iic, cfg, cfg->BaseAddress) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    XIicPs_SetSClk(&Iic, IIC_SCLK_RATE);

    /* Select TCA9548A mux channel for FMC HPC0 */
    if (i2c_send(I2C_MUX_ADDR, &mux_sel, 1) != XST_SUCCESS) {
        xil_printf("ERROR: I2C mux select failed\r\n");
        return XST_FAILURE;
    }

    usleep(5000);

    /* Write threshold to all 8 DAC channels */
    for (ch = 0; ch < 8; ch++) {
        buf[0] = (u8)(0x30u | (u8)ch);
        buf[1] = code;
        buf[2] = 0x00u;

        if (i2c_send(DAC5578_ADDR, buf, 3) != XST_SUCCESS) {
            xil_printf("ERROR: DAC channel %d write failed\r\n", ch);
            return XST_FAILURE;
        }

        usleep(2000);
    }

    xil_printf("DAC threshold set to %u mV\r\n", (unsigned int)DAC_TARGET_MV);
    return XST_SUCCESS;
}

/* ------------------------------------------------------------
 * Print one coincidence bit as:
 *
 * NAME    0
 *
 * or:
 *
 * NAME    1
 * ------------------------------------------------------------ */
static void print_bit_line(const char *name, u32 coinc_word, int bit)
{
    u32 value = (coinc_word >> bit) & 0x1u;
    xil_printf("%s\t%u\r\n", name, (unsigned int)value);
}

/* ------------------------------------------------------------
 * Print one full event
 *
 * Coincidence word bit mapping used by the VHDL:
 *
 *   bit 0  = A
 *   bit 1  = B
 *   bit 2  = C
 *   bit 3  = D
 *   bit 4  = AB
 *   bit 5  = AC
 *   bit 6  = AD
 *   bit 7  = BC
 *   bit 8  = BD
 *   bit 9  = CD
 *   bit 10 = ABC
 *   bit 11 = ABD
 *   bit 12 = ACD
 *   bit 13 = BCD
 *   bit 14 = ABCD
 *   bit 15 = ABCD padding duplicate, intentionally omitted
 * ------------------------------------------------------------ */
static void print_event(u32 ts, u32 coinc_word)
{
    xil_printf("TS\t%u\r\n", (unsigned int)ts);

    /* Single channels */
    print_bit_line("A",    coinc_word, 0);
    print_bit_line("B",    coinc_word, 1);
    print_bit_line("C",    coinc_word, 2);
    print_bit_line("D",    coinc_word, 3);

    /* Two-channel combinations */
    print_bit_line("AB",   coinc_word, 4);
    print_bit_line("AC",   coinc_word, 5);
    print_bit_line("AD",   coinc_word, 6);
    print_bit_line("BC",   coinc_word, 7);
    print_bit_line("BD",   coinc_word, 8);
    print_bit_line("CD",   coinc_word, 9);

    /* Three-channel combinations */
    print_bit_line("ABC",  coinc_word, 10);
    print_bit_line("ABD",  coinc_word, 11);
    print_bit_line("ACD",  coinc_word, 12);
    print_bit_line("BCD",  coinc_word, 13);

    /* Four-channel combination */
    print_bit_line("ABCD", coinc_word, 14);

    /*
     * Bit 15 is also ABCD in the VHDL, but it is only a padding copy.
     * If you really want to see it, uncomment this line:
     *
     * print_bit_line("ABCD15", coinc_word, 15);
     */

    xil_printf("\r\n");
}

/* ------------------------------------------------------------
 * Main
 * ------------------------------------------------------------ */
int main(void)
{
    u32 event_count = 0;

    init_platform();

    xil_printf("\r\n");
    xil_printf("=========================================\r\n");
    xil_printf(" FMC-DIO coincidence demo\r\n");
    xil_printf(" Output format:\r\n");
    xil_printf("   TS, then all coincidence bits\r\n");
    xil_printf("=========================================\r\n");
    xil_printf("\r\n");

    /* Initialize DAC thresholds */
    if (dac_init() != XST_SUCCESS) {
        xil_printf("FATAL: DAC initialization failed\r\n");
        xil_printf("Check that the FMC-DIO card is seated in HPC0.\r\n");
        while (1) {
            /* Stop here */
        }
    }

    /* Set GPIO directions safely */
    Xil_Out32(AXI_GPIO_CTRL_BASE   + GPIO_TRI_OFFSET,  0x00000000u);
    Xil_Out32(AXI_GPIO_CONFIG_BASE + GPIO_TRI_OFFSET,  0x00000000u);
    Xil_Out32(AXI_GPIO_STATUS_BASE + GPIO_TRI_OFFSET,  0xFFFFFFFFu);
    Xil_Out32(AXI_GPIO_STATUS_BASE + GPIO2_TRI_OFFSET, 0xFFFFFFFFu);

    /* Reset CT core */
    Xil_Out32(AXI_GPIO_CTRL_BASE + GPIO_DATA_OFFSET, 0x00u);
    usleep(1000);

    /* Release reset and enable CT core */
    Xil_Out32(AXI_GPIO_CTRL_BASE + GPIO_DATA_OFFSET, CTRL_ENABLE);
    usleep(1000);

    /* Set pulse-stretch window width.
     * 20 clocks at 200 MHz = 100 ns.
     */
    Xil_Out32(AXI_GPIO_CONFIG_BASE + GPIO_DATA_OFFSET, 20u);

    xil_printf("Waiting for events...\r\n\r\n");

    while (1) {
        u32 status = Xil_In32(AXI_GPIO_STATUS_BASE + GPIO2_DATA_OFFSET);
        u32 fifo_empty = (status >> 16) & 0x1u;

        if (!fifo_empty) {
            u32 ts    = Xil_In32(AXI_GPIO_STATUS_BASE + GPIO_DATA_OFFSET);
            u32 coinc = status & 0x0000FFFFu;

            event_count++;

            if ((event_count % PRINT_EVERY_N) == 0u) {
                print_event(ts, coinc);
            }

            /* Pop FIFO:
             * Keep enable = 1, pulse pop = 1.
             */
            Xil_Out32(AXI_GPIO_CTRL_BASE + GPIO_DATA_OFFSET, CTRL_ENABLE_POP);
            usleep(POP_PULSE_US);
            Xil_Out32(AXI_GPIO_CTRL_BASE + GPIO_DATA_OFFSET, CTRL_ENABLE);
        }
    }

    cleanup_platform();
    return 0;
}