#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#define TIMER_BASE_ADDR          0x10005000
#define TIMER_REG_CTRL           *((volatile uint32_t *)(TIMER_BASE_ADDR + 0))
#define TIMER_REG_PSCR           *((volatile uint32_t *)(TIMER_BASE_ADDR + 4))
#define TIMER_REG_CNT            *((volatile uint32_t *)(TIMER_BASE_ADDR + 8))
#define TIMER_REG_CMP            *((volatile uint32_t *)(TIMER_BASE_ADDR + 12))
#define TIMER_REG_STAT           *((volatile uint32_t *)(TIMER_BASE_ADDR + 16))

#define SPI_BASE_ADDR            0x10006000
#define SPI_REG_CTRL1            *((volatile uint32_t *)(SPI_BASE_ADDR + 0))
#define SPI_REG_CTRL2            *((volatile uint32_t *)(SPI_BASE_ADDR + 4))
#define SPI_REG_DIV              *((volatile uint32_t *)(SPI_BASE_ADDR + 8))
#define SPI_REG_CAL              *((volatile uint32_t *)(SPI_BASE_ADDR + 12))
#define SPI_REG_TRL              *((volatile uint32_t *)(SPI_BASE_ADDR + 16))
#define SPI_REG_TXR              *((volatile uint32_t *)(SPI_BASE_ADDR + 20))
#define SPI_REG_RXR              *((volatile uint32_t *)(SPI_BASE_ADDR + 24))
#define SPI_REG_STAT             *((volatile uint32_t *)(SPI_BASE_ADDR + 28))

#define W25X_WRITE_ENABLE        0x06
#define W25X_WRITE_DISABLE       0x04
#define W25X_READ_STAT_REG       0x05
#define W25X_WRITE_STAT_REG      0x01
#define W25X_READ_DATA           0x03
#define W25X_FAST_READ_DATA      0x0B
#define W25X_FAST_READ_DUAL      0x3B
#define W25X_PAGE_PROGRAM        0x02
#define W25X_BLOCK_ERASE         0xD8
#define W25X_SECTOR_ERASE        0x20
#define W25X_CHIP_ERASE          0xC7
#define W25X_POWER_DOWN          0xB9
#define W25X_RELEASE_POWER_DOWN  0xAB
#define W25X_DEVICE_ID           0xAB
#define W25X_MANU_FACT_DEVICE_ID 0x90
#define W25X_JEDEC_DEVICE_ID     0x9F

#define SPI_FLASH_PAGE_SIZE      256

#define TEST_NUM                 20 // need to < 64
#define TEST_32B_NUM             6  // need to < 64

#define spi_cs_clr    (SPI_REG_CTRL2 = SPI_REG_CTRL2 | 0x20)
#define spi_cs_set    (SPI_REG_CTRL2 = SPI_REG_CTRL2 & 0x1FFDF)

// 256   block(64KB)
// 4096  sector[1 block  -> 16 sector(4KB)]
// 65536 page  [1 sector -> 16 page(256B)]

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

void spi_manu_init() {
    SPI_REG_DIV   = (uint32_t)0;
    SPI_REG_CTRL1 = (uint32_t)0x0;  // manual mode
    SPI_REG_CTRL2 = (uint32_t)0x20; // nss = 0
    SPI_REG_CTRL2 = (uint32_t)0x24; // nss = 0, en = 1
    printf("SPI_DIV: %x SPI_CTRL1: %x SPI_CTRL2: %x\n", SPI_REG_DIV, SPI_REG_CTRL1, SPI_REG_CTRL2);
}

void spi_auto_init() {
    SPI_REG_DIV   = (uint32_t)0;
    SPI_REG_CTRL1 = (uint32_t)0x8;  // auto mode
    SPI_REG_CTRL2 = (uint32_t)0x20; // nss = 0
    SPI_REG_CTRL2 = (uint32_t)0x24; // nss = 0, en = 1
    printf("SPI_DIV: %x SPI_CTRL1: %x SPI_CTRL2: %x\n", SPI_REG_DIV, SPI_REG_CTRL1, SPI_REG_CTRL2);
}

void spi_wr_dat_8b(uint8_t cmd) {
    if(((SPI_REG_STAT & 0x08) >> 3) == 1) {
        putstr("tx fifo is full\n");
        return;
    }
    SPI_REG_TXR   = (uint32_t)cmd;
    SPI_REG_CAL   = 0;
    SPI_REG_TRL   = (uint32_t)0;
    SPI_REG_CTRL2 = (uint32_t)0x2C;           // start trans
    while(((SPI_REG_STAT & 0x04) >> 2) == 1); // wait tx trans done
}

// num: trans data num(>=1)
void spi_wr_dat(uint8_t cmd, uint32_t wr_addr, bool have_addr, uint32_t num, uint8_t *data) {
    if(((SPI_REG_STAT & 0x08) >> 3) == 1) {
        putstr("tx fifo is full\n");
        return;
    }

    uint8_t cur_addr[3] = {0};
    if(have_addr) {
        cur_addr[0] = (wr_addr & 0xFF0000) >> 16;
        cur_addr[1] = (wr_addr & 0x00FF00) >> 8;
        cur_addr[2] = (wr_addr & 0x0000FF);
        num += 3;
    }

    SPI_REG_TXR = (uint32_t)cmd;
    SPI_REG_CAL = 0;
    SPI_REG_TRL = num;
    for(int i = 0; i < num; ++i) {
        if(((SPI_REG_STAT & 0x08) >> 3) == 1) {
            putstr("tx fifo is full\n");
            return;
        }
        if(have_addr) {
            if(i <= 2) SPI_REG_TXR = cur_addr[i];
            else SPI_REG_TXR = data[i-3];
        } else SPI_REG_TXR = data[i];
    }

    SPI_REG_CTRL2 = (uint32_t)0x2C;           // start trans
    while(((SPI_REG_STAT & 0x04) >> 2) == 1); // wait tx trans done
}

// num: trans data num(>=1)
void spi_rd_dat(uint8_t cmd, uint32_t rd_addr, bool have_addr, uint32_t num, uint8_t *data) {
    if(((SPI_REG_STAT & 0x08) >> 3) == 1) {
         putstr("tx fifo is full\n");
         return;
    }
    SPI_REG_TXR   = (uint32_t)cmd;

    uint8_t trans_num = num, cur_addr[3] = {0};
    if(have_addr) {
        cur_addr[0] = (rd_addr & 0xFF0000) >> 16;
        cur_addr[1] = (rd_addr & 0x00FF00) >> 8;
        cur_addr[2] = (rd_addr & 0x0000FF);
        trans_num += 3;
        for(int i = 0; i < 3; ++i) {
            if(((SPI_REG_STAT & 0x08) >> 3) == 1) {
                 putstr("tx fifo is full\n");
                 return;
            }
            SPI_REG_TXR = cur_addr[i];
        }
    }

    if(have_addr) SPI_REG_CAL = trans_num - 4;
    else SPI_REG_CAL = trans_num - 1;
    SPI_REG_TRL = trans_num;
    SPI_REG_CTRL2 = (uint32_t)0x3C;               // start trans

    for(int i = 0; i < num; ++i) {
        while(((SPI_REG_STAT & 0x10) >> 4) == 1); // wait rx fifo is no empty
        data[i] = SPI_REG_RXR;
    }
}

void spi_flash_write_done() {
    uint8_t recv[1] = {0};
    do {
        spi_rd_dat(W25X_READ_STAT_REG, 0, false, 1, recv);
    } while(recv[0] & 0x01);
}

void spi_flash_id_read() {
    uint8_t recv[3];
    spi_rd_dat(W25X_JEDEC_DEVICE_ID, 0, false, 3, recv);
    printf("MANU_ID: %x FLASH ID: %x\n", recv[0], (recv[1] << 8) | recv[2]);
}

void spi_flash_sector_erase(uint32_t sect_addr) {
    spi_wr_dat_8b(W25X_WRITE_ENABLE);
    spi_flash_write_done();
    spi_wr_dat(W25X_SECTOR_ERASE, sect_addr, true, 0, NULL);
    spi_flash_write_done();
}

void spi_flash_page_write(uint32_t page_addr, uint32_t num, uint8_t *data) {
    spi_wr_dat_8b(W25X_WRITE_ENABLE);
    if(num > SPI_FLASH_PAGE_SIZE) {
        printf("write num %d is larger than page size\n", num);
        return;
    }
    spi_wr_dat(W25X_PAGE_PROGRAM, page_addr, true, num, data);
    spi_flash_write_done();
}

void spi_flash_buf_write(uint32_t wr_addr, uint32_t num, uint8_t *data) {
    uint8_t page_num = 0, rem_byte_num = 0, rem_addr = 0, rem_byte_num_in_one_page = 0, tmp = 0;

    rem_addr = wr_addr % SPI_FLASH_PAGE_SIZE;
    rem_byte_num_in_one_page = SPI_FLASH_PAGE_SIZE - rem_addr;
    page_num = num / SPI_FLASH_PAGE_SIZE;
    rem_byte_num = num % SPI_FLASH_PAGE_SIZE;

    if(rem_addr == 0) {
        if(page_num == 0) {
            spi_flash_page_write(wr_addr, num, data);
        } else {
            while (page_num--) {
                spi_flash_page_write(wr_addr, SPI_FLASH_PAGE_SIZE, data);
                wr_addr +=  SPI_FLASH_PAGE_SIZE;
                data += SPI_FLASH_PAGE_SIZE;
            }
            spi_flash_page_write(wr_addr, rem_byte_num, data);
        }
    } else {
        if (page_num == 0) {
            if (rem_byte_num > rem_byte_num_in_one_page) {
                tmp = rem_byte_num - rem_byte_num_in_one_page;
                spi_flash_page_write(wr_addr, rem_byte_num_in_one_page, data);
                wr_addr += rem_byte_num_in_one_page;
                data += rem_byte_num_in_one_page;
                spi_flash_page_write(wr_addr, tmp, data);
            } else {
                spi_flash_page_write(wr_addr, num, data);
            }
        } else {
            num -= rem_byte_num_in_one_page;
            page_num = num / SPI_FLASH_PAGE_SIZE;
            rem_byte_num = num % SPI_FLASH_PAGE_SIZE;

            spi_flash_page_write(wr_addr, rem_byte_num_in_one_page, data);

            wr_addr += rem_byte_num_in_one_page;
            data += rem_byte_num_in_one_page;
            while (page_num--) {
                spi_flash_page_write(wr_addr, SPI_FLASH_PAGE_SIZE, data);
                wr_addr += SPI_FLASH_PAGE_SIZE;
                data += SPI_FLASH_PAGE_SIZE;
            }
            if (rem_byte_num != 0) {
                spi_flash_page_write(wr_addr, rem_byte_num, data);
            }
        }
    }
}

void spi_flash_buf_read(uint32_t rd_addr, uint32_t num, uint8_t *data) {
    spi_rd_dat(W25X_READ_DATA, rd_addr, true, num, data);
}

uint32_t tot_cnt = 0, err_cnt = 0;
void check_result(uint8_t *ref_data, uint8_t *recv_data, uint32_t test_num) {
    for(int i = 0; i < test_num; ++i) {
        if(ref_data[i] != recv_data[i]) {
            printf("[mismatch]ref: %d recv: %d\n", ref_data[i], recv_data[i]);
            ++err_cnt;
        }
    }
}

int main(){
    uint8_t ref_data[TEST_NUM], recv_data[TEST_NUM];
    for(int i = 0; i < TEST_NUM; ++i) ref_data[i] = i;

    putstr("spi nor flash test\n");
    timer_init();
    spi_auto_init();
    spi_flash_id_read();
    putstr("ass mode page wr/rd test\n");

    for(int i = 0, cur_addr = 0; i < 70; ++i) {
        spi_flash_sector_erase(cur_addr);
        cur_addr += 4096;
    }
    putstr("sector erase done\n");

    tot_cnt = 1;
    for(int i = 0, cur_addr = 0; i < 1024; ++i) {
        spi_flash_page_write(cur_addr, TEST_NUM, ref_data);
        spi_flash_buf_read(cur_addr, TEST_NUM, recv_data);
        check_result(ref_data, recv_data, TEST_NUM);
        printf(" [addr: %x] %d iter check done\n", cur_addr, i);
        cur_addr += 256;
        ++tot_cnt;
    }
    printf("tot: %d, err: %d\n", tot_cnt * TEST_NUM, err_cnt);
    putstr("ass mode page wr/rd test done\n");


    putstr("ass mode wr/rd test done\n");
    putstr("test done\n");

    return 0;
}
