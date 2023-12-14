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
 * SPI_CTRL:
 * BITS:   | 31:24  | 23:21 | 20   | 19 | 18 | 17  | 16  | 15:8 | 7:6 | 5    | 4   | 3   | 2   | 1    | 0    |
 * FIELDS: | RES    | NSS   | BUSY | ST | EN | RXE | TXE | DIV  | DTB | MSTR | RDM | ASS | LSB | CPOL | CPHA |
 * PERMS:  | NONE   | RW    | RW   | RW | RW | RW  | RW  | RW   | RW  | RES  | RW  | RW  | RW  | RW   | RW   |
 * -----------------------------------------------------------------------------------------------------------
 * SPI_TX:
 * BITS:   | 31:0   |
 * FIELDS: | TXDATA |
 * PERMS:  | RW     |
 * -----------------------------------------------------------------------------------------------------------
 * SPI_RX:
 * BITS:   | 31:0   |
 * FIELDS: | RXDATA |
 * PERMS:  | RW     |
 * -----------------------------------------------------------------------------------------------------------
*/

// verilog_format: off
`define SPI_CTRL 4'b0000 // BASEADDR + 0x00
`define SPI_TX   4'b0001 // BASEADDR + 0x04
`define SPI_RX   4'b0010 // BASEADDR + 0x08

// verilog_format: on

interface spi_if #(
    parameter int SPI_NSS_NUM = 1
) ();
  logic                   spi_sck_o;
  logic [SPI_NSS_NUM-1:0] spi_nss_o;
  logic                   spi_miso_o;
  logic                   spi_mosi_i;
  logic                   irq_o;

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
