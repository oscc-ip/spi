#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#define GPIO_BASE_ADDR  0x10004000
#define GPIO_REG_PADDIR *((volatile uint32_t *)(GPIO_BASE_ADDR + 0))
#define GPIO_REG_PADOUT *((volatile uint32_t *)(GPIO_BASE_ADDR + 8))

#define TIMER_BASE_ADDR 0x10005000
#define TIMER_REG_CTRL  *((volatile uint32_t *)(TIMER_BASE_ADDR + 0))
#define TIMER_REG_PSCR  *((volatile uint32_t *)(TIMER_BASE_ADDR + 4))
#define TIMER_REG_CNT   *((volatile uint32_t *)(TIMER_BASE_ADDR + 8))
#define TIMER_REG_CMP   *((volatile uint32_t *)(TIMER_BASE_ADDR + 12))
#define TIMER_REG_STAT  *((volatile uint32_t *)(TIMER_BASE_ADDR + 16))

#define SPI_BASE_ADDR   0x10006000
#define SPI_REG_CTRL1   *((volatile uint32_t *)(SPI_BASE_ADDR + 0))
#define SPI_REG_CTRL2   *((volatile uint32_t *)(SPI_BASE_ADDR + 4))
#define SPI_REG_DIV     *((volatile uint32_t *)(SPI_BASE_ADDR + 8))
#define SPI_REG_CAL     *((volatile uint32_t *)(SPI_BASE_ADDR + 12))
#define SPI_REG_TRL     *((volatile uint32_t *)(SPI_BASE_ADDR + 16))
#define SPI_REG_TXR     *((volatile uint32_t *)(SPI_BASE_ADDR + 20))
#define SPI_REG_RXR     *((volatile uint32_t *)(SPI_BASE_ADDR + 24))
#define SPI_REG_STAT    *((volatile uint32_t *)(SPI_BASE_ADDR + 28))

#define lcd_dc_clr      (GPIO_REG_PADOUT = (uint32_t)0)
#define lcd_dc_set      (GPIO_REG_PADOUT = (uint32_t)1)

#define USE_HORIZONTAL 2

#if USE_HORIZONTAL == 0 || USE_HORIZONTAL == 1
#define LCD_W 135
#define LCD_H 240
#else
#define LCD_W 240
#define LCD_H 135
#endif

void gpio_init() {
    GPIO_REG_PADDIR = (uint32_t)0;
}

void timer_init() {
    TIMER_REG_CTRL = (uint32_t)0x0;
    while(TIMER_REG_STAT == 1);           // clear irq
    TIMER_REG_CMP  = (uint32_t)(50000-1); // 50MHz for 1ms
}

void delay_ms(uint32_t val) {
    TIMER_REG_CTRL = (uint32_t)0xD;
    for(int i = 1; i <= val; ++i) {
        while(TIMER_REG_STAT == 0);
    }
    TIMER_REG_CTRL = (uint32_t)0x0;
}

void spi_init() {
    SPI_REG_DIV   = (uint32_t)0;
    SPI_REG_CTRL1 = (uint32_t)0x8;  // ass mode
    SPI_REG_CTRL2 = (uint32_t)0x20; // nss = 0
    SPI_REG_CTRL2 = (uint32_t)0x24; // nss = 0, st = 1
    printf("SPI_DIV: %x SPI_CTRL1: %x SPI_CTRL2: %x\n", SPI_REG_DIV, SPI_REG_CTRL1, SPI_REG_CTRL2);
}

void spi_wr_dat(uint8_t dat) {
    SPI_REG_TXR   = (uint32_t)dat;
    SPI_REG_TRL   = (uint32_t)0;
    SPI_REG_CTRL2 = (uint32_t)0x2C; // 0010_1100
    while(((SPI_REG_STAT & 0x04)>>2) == 1);
}

void lcd_wr_cmd(uint8_t cmd) {
    lcd_dc_clr;
    spi_wr_dat(cmd);
    lcd_dc_set;
}

void lcd_wr_data8(uint8_t dat) {
    spi_wr_dat(dat);
}

void lcd_wr_data16(uint16_t dat) {
    spi_wr_dat(dat >> 8);
    spi_wr_dat(dat);
}

void lcd_init() {
    delay_ms(500);
    lcd_wr_cmd(0x11);
    delay_ms(120);
    lcd_wr_cmd(0x36);
    if(USE_HORIZONTAL == 0)lcd_wr_data8(0x00);
    else if(USE_HORIZONTAL == 1)lcd_wr_data8(0xC0);
    else if(USE_HORIZONTAL == 2)lcd_wr_data8(0x70);
    else lcd_wr_data8(0xA0);

    lcd_wr_cmd(0x3A);
    lcd_wr_data8(0x05);

    lcd_wr_cmd(0xB2);
    lcd_wr_data8(0x0C);
    lcd_wr_data8(0x0C);
    lcd_wr_data8(0x00);
    lcd_wr_data8(0x33);
    lcd_wr_data8(0x33);

    lcd_wr_cmd(0xB7);
    lcd_wr_data8(0x35);

    lcd_wr_cmd(0xBB);
    lcd_wr_data8(0x19);

    lcd_wr_cmd(0xC0);
    lcd_wr_data8(0x2C);

    lcd_wr_cmd(0xC2);
    lcd_wr_data8(0x01);

    lcd_wr_cmd(0xC3);
    lcd_wr_data8(0x12);

    lcd_wr_cmd(0xC4);
    lcd_wr_data8(0x20);

    lcd_wr_cmd(0xC6);
    lcd_wr_data8(0x0F);

    lcd_wr_cmd(0xD0);
    lcd_wr_data8(0xA4);
    lcd_wr_data8(0xA1);

    lcd_wr_cmd(0xE0);
    lcd_wr_data8(0xD0);
    lcd_wr_data8(0x04);
    lcd_wr_data8(0x0D);
    lcd_wr_data8(0x11);
    lcd_wr_data8(0x13);
    lcd_wr_data8(0x2B);
    lcd_wr_data8(0x3F);
    lcd_wr_data8(0x54);
    lcd_wr_data8(0x4C);
    lcd_wr_data8(0x18);
    lcd_wr_data8(0x0D);
    lcd_wr_data8(0x0B);
    lcd_wr_data8(0x1F);
    lcd_wr_data8(0x23);

    lcd_wr_cmd(0xE1);
    lcd_wr_data8(0xD0);
    lcd_wr_data8(0x04);
    lcd_wr_data8(0x0C);
    lcd_wr_data8(0x11);
    lcd_wr_data8(0x13);
    lcd_wr_data8(0x2C);
    lcd_wr_data8(0x3F);
    lcd_wr_data8(0x44);
    lcd_wr_data8(0x51);
    lcd_wr_data8(0x2F);
    lcd_wr_data8(0x1F);
    lcd_wr_data8(0x1F);
    lcd_wr_data8(0x20);
    lcd_wr_data8(0x23);

    lcd_wr_cmd(0x21);
    lcd_wr_cmd(0x29);
}


void lcd_addr_set(uint16_t x1, uint16_t y1, uint16_t x2, uint16_t y2) {
    if(USE_HORIZONTAL == 0) {
        lcd_wr_cmd(0x2A);      // set col addr
        lcd_wr_data16(x1 + 52);
        lcd_wr_data16(x2 + 52);
        lcd_wr_cmd(0x2B);      // set row addr
        lcd_wr_data16(y1 + 40);
        lcd_wr_data16(y2 + 40);
        lcd_wr_cmd(0x2C);      // write memory
    } else if(USE_HORIZONTAL == 1) {
        lcd_wr_cmd(0x2A);
        lcd_wr_data16(x1 + 53);
        lcd_wr_data16(x2 + 53);
        lcd_wr_cmd(0x2B);
        lcd_wr_data16(y1 + 40);
        lcd_wr_data16(y2 + 40);
        lcd_wr_cmd(0x2C);
    } else if(USE_HORIZONTAL == 2) {
        lcd_wr_cmd(0x2A);
        lcd_wr_data16(x1 + 40);
        lcd_wr_data16(x2 + 40);
        lcd_wr_cmd(0x2B);
        lcd_wr_data16(y1 + 53);
        lcd_wr_data16(y2 + 53);
        lcd_wr_cmd(0x2C);
    } else {
        lcd_wr_cmd(0x2A);
        lcd_wr_data16(x1 + 40);
        lcd_wr_data16(x2 + 40);
        lcd_wr_cmd(0x2B);
        lcd_wr_data16(y1 + 52);
        lcd_wr_data16(y2 + 52);
        lcd_wr_cmd(0x2C);
    }
}

void lcd_fill(uint16_t xsta, uint16_t ysta, uint16_t xend, uint16_t yend, uint16_t color) {
    lcd_addr_set(xsta, ysta, xend - 1, yend - 1);
    for(uint16_t i = ysta; i < yend; ++i) {
        for(uint16_t j = xsta; j < xend; ++j) {
            lcd_wr_data16(color);
        }
    }
}

int main(){
    putstr("spi tft lcd test\n");

    gpio_init();
    timer_init();
    spi_init();
    lcd_init();
    putstr("lcd init done\n");
    // lcd_wr_cmd(0x01); // software reset
    while(1) {
        lcd_fill(0, 0, LCD_W, LCD_H, 0xF800); // red
        lcd_fill(0, 0, LCD_W, LCD_H, 0x07E0); // green
        lcd_fill(0, 0, LCD_W, LCD_H, 0x001F); // blue
    }

    return 0;
}
