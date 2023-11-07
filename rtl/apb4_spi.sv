// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// verilog_format: off
`define SPI_CTRL 4'b0000 //BASEADDR+0x00
`define TIM_PSCR 4'b0001 //BASEADDR+0x04
`define TIM_CNT  4'b0010 //BASEADDR+0x08
`define TIM_CMP  4'b0011 //BASEADDR+0x0C
// verilog_format: on

/* register mapping
 * SPI_CTRL:
 * BITS:   | 31:24  | 23:20 | 19 | 18 | 17  | 16  | 15:8 | 7:6 | 5    | 4   | 3   | 2   | 1    | 0    |
 * FIELDS: | RES    | NSS   | ST | EN | RXE | TXE | DIV  | DTB | MSTR | RDM | ASS | LSB | CPOL | CPHA |
 * PERMS:  | NONE   | RW    | RW | RW | RW  | RW  | RW   | RW  | RES  | RW  | RW  | RW  | RW   | RW   |
 * ----------------------------------------------------------------------------------------------------
 * SPI_TX:
 * BITS:   | 31:0   |
 * FIELDS: | TXDATA |
 * PERMS:  | RW     |
 * ----------------------------------------------------------------------------------------------------
 * SPI_RX:
 * BITS:   | 31:0   |
 * FIELDS: | RXDATA |
 * PERMS:  | RW     |
 * ----------------------------------------------------------------------------------------------------
*/
module apb4_spi #(
    parameter int SPI_NSS_NUM = 4
) (
    // verilog_format: off
    apb4_if.slave apb4,
    // verilog_format: on
    output spi_sck_o,
    output logic [SPI_NSS_NUM-1:0] spi_nss_o,
    output logic spi_miso_o,
    input logic spi_mosi_i,
    output logic irq_o
);
endmodule
