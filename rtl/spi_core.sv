// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "shift_reg.sv"
`include "edge_det.sv"
`include "spi_define.sv"

module spi_core (
    input  logic                      clk_i,
    input  logic                      rst_n_i,
    input  logic [               3:0] nss_i,
    input  logic [               3:0] csv_i,
    input  logic                      ass_i,
    input  logic                      lsb_i,
    input  logic                      st_i,
    input  logic                      rwm_i,
    input  logic                      cpol_i,
    input  logic                      cpha_i,
    input  logic [`SPI_TRL_WIDTH-1:0] trl_i,
    output logic                      busy_o,
    output logic                      last_o,
    input  logic                      tx_valid_i,
    output logic                      tx_ready_o,
    input  logic [              31:0] tx_data_i,
    output logic                      rx_valid_o,
    input  logic                      rx_ready_i,
    output logic [              31:0] rx_data_o,
    output logic                      spi_sck_o,
    output logic [  `SPI_NSS_NUM-1:0] spi_nss_o,
    output logic [               3:0] spi_io_en_o,
    input  logic [               3:0] spi_io_in_i,
    output logic [               3:0] spi_io_out_o
);
  logic [3:0] s_nss_sel;
  // software nss ctrl is more flexible
  assign s_nss_sel    = (nss_i & {4{busy_o & ass_i}}) | (nss_i & {4{~ass_i}});
  assign spi_nss_o    = ~(s_nss_sel[`SPI_NSS_NUM-1:0] ^ csv_i[`SPI_NSS_NUM-1:0]);

  assign busy_o       = '0;
  assign last_o       = '0;
  assign tx_ready_o   = '0;
  assign rx_valid_o   = '0;
  assign rx_data_o    = '0;
  assign spi_sck_o    = '0;
  assign spi_io_en_o  = '0;
  assign spi_io_out_o = '0;

endmodule
