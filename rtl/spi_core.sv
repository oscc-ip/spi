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
    input  logic                       clk_i,
    input  logic                       rst_n_i,
    input  logic                       lsb_i,
    input  logic                       st_i,
    input  logic                       rwm_i,
    input  logic                       pos_edge_i,
    input  logic                       neg_edge_i,
    input  logic                       cpol_i,
    input  logic                       cpha_i,
    input  logic                       tdtb_i,
    input  logic                       rdtb_i,
    input  logic [                1:0] spm_i,
    input  logic [                3:0] snm_i,
    input  logic [ `SPI_CAL_WIDTH-1:0] cal_i,
    input  logic                       trl_valid_i,
    input  logic [ `SPI_TRL_WIDTH-1:0] trl_i,
    output logic                       busy_o,
    output logic                       last_o,
    input  logic                       tx_valid_i,
    output logic                       tx_ready_o,
    input  logic [`SPI_DATA_WIDTH-1:0] tx_data_i,
    output logic                       rx_valid_o,
    input  logic                       rx_ready_i,
    output logic [`SPI_DATA_WIDTH-1:0] rx_data_o,
    output logic [                3:0] spi_io_en_o,
    input  logic [                3:0] spi_io_in_i,
    output logic [                3:0] spi_io_out_o
);

endmodule
