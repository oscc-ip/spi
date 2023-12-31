// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SPI_DEF_SV
`define INC_SPI_DEF_SV

/* register mapping
 * SPI_CTRL1:
 * BITS:   | 31:8 | 7:6 | 5    | 4   | 3   | 2   | 1    | 0    |
 * FIELDS: | RES  | DTB | SSTR | RDM | ASS | LSB | CPOL | CPHA |
 * PERMS:  | NONE | RW  | RW   | RW  | RW  | RW  | RW   | RW   |
 * --------------------------------------------------------------
* SPI_CTRL2:
 * BITS:   | 31:8 | 7:4 | 3  | 2  | 1    | 0    |
 * FIELDS: | RES  | NSS | ST | EN | RXIE | TXIE |
 * PERMS:  | NONE | RW  | RW | RW | RW   | RW   |
 * --------------------------------------------------------------
 * SPI_DIV:
 * BITS:   | 31:16 | 15:0 |
 * FIELDS: | RES   | DIV  |
 * PERMS:  | NONE  | RW   |
 * --------------------------------------------------------------
 * SPI_TXR:
 * BITS:   | 31:0   |
 * FIELDS: | TXDATA |
 * PERMS:  | W      |
 * --------------------------------------------------------------
 * SPI_RXR:
 * BITS:   | 31:0   |
 * FIELDS: | RXDATA |
 * PERMS:  | R      |
 * ---------------------------------------------------------------
 * SPI_STAT:
 * BITS:   | 31:3 | 2    | 1    | 0    |
 * FIELDS: | RES  | BUSY | RXIF | TXIF |
 * PERMS:  | NONE | R    | R    | R    |
 * ---------------------------------------------------------------
*/

// verilog_format: off
`define SPI_CTRL1 4'b0000 // BASEADDR + 0x00
`define SPI_CTRL2 4'b0001 // BASEADDR + 0x04
`define SPI_DIV   4'b0010 // BASEADDR + 0x08
`define SPI_TXR   4'b0011 // BASEADDR + 0x0C
`define SPI_RXR   4'b0100 // BASEADDR + 0x10
`define SPI_STAT  4'b0101 // BASEADDR + 0x14

`define SPI_CTRL1_ADDR {26'b0, `SPI_CTRL1, 2'b00}
`define SPI_CTRL2_ADDR {26'b0, `SPI_CTRL2, 2'b00}
`define SPI_DIV_ADDR   {26'b0, `SPI_DIV,   2'b00}
`define SPI_TXR_ADDR   {26'b0, `SPI_TXR,   2'b00}
`define SPI_RXR_ADDR   {26'b0, `SPI_RXR,   2'b00}
`define SPI_STAT_ADDR  {26'b0, `SPI_STAT,  2'b00}

`define SPI_CTRL1_WIDTH 8
`define SPI_CTRL2_WIDTH 8
`define SPI_DIV_WIDTH   16
`define SPI_TXR_WIDTH   32
`define SPI_RXR_WIDTH   32
`define SPI_STAT_WIDTH  3

`define SPI_NSS_NUM 1

// verilog_format: on

interface spi_if ();
  logic                    spi_sck_o;
  logic [`SPI_NSS_NUM-1:0] spi_nss_o;
  logic                    spi_miso_o;
  logic                    spi_mosi_i;
  logic                    irq_o;

  modport dut(
      output spi_sck_o,
      output spi_nss_o,
      output spi_miso_o,
      input spi_mosi_i,
      output irq_o
  );

  // verilog_format: off
  modport tb(
      input spi_sck_o,
      input spi_nss_o,
      input spi_miso_o,
      output spi_mosi_i,
      input irq_o
  );
  // verilog_format: on
endinterface
`endif
