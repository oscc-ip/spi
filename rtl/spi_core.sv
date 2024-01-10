// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "spi_define.sv"

module spi_core (
    input  logic                       clk_i,
    input  logic                       rst_n_i,
    input  logic                       lsb_i,
    input  logic                       st_i,
    input  logic                       pos_edge_i,
    input  logic                       neg_edge_i,
    input  logic                       cpol_i,
    input  logic                       cpha_i,
    input  logic [                1:0] dtb_i,
    output logic                       busy_o,
    output logic                       last_o,
    input  logic                       tx_valid_i,
    output logic                       tx_ready_o,
    input  logic [`SPI_DATA_WIDTH-1:0] tx_data_i,
    output logic                       rx_valid_o,
    input  logic                       rx_ready_i,
    output logic [`SPI_DATA_WIDTH-1:0] rx_data_o,
    input  logic                       spi_clk_i,
    output logic                       spi_mosi_o,
    input  logic                       spi_miso_i
);

  logic [`SPI_DATA_BIT_WIDTH+1:0] s_tran_cnt_d, s_tran_cnt_q, s_tx_idx, s_rx_idx;
  logic [`SPI_DATA_WIDTH-1:0] s_tx_data_d, s_tx_data_q;
  logic s_tx_data_en;
  logic [`SPI_DATA_WIDTH-1:0] s_rx_data_d, s_rx_data_q;
  logic s_busy_d, s_busy_q;
  logic s_mosi_d, s_mosi_q;
  logic s_rx_data_en;
  logic s_tx_clk, s_rx_clk;

  assign busy_o = s_busy_q;
  assign last_o = ~(|s_tran_cnt_q);
  assign spi_mosi_o = s_mosi_q;
  assign s_tx_idx = lsb_i ? 1'b0 : s_tran_cnt_q - 1'b1;
  assign s_rx_idx = lsb_i ? 1'b0 : s_tran_cnt_q - 1'b1;  // NOTE: some err

  // cpol == 0: pos edge is eariler than neg edge
  always_comb begin
    s_tran_cnt_d = s_tran_cnt_q;
    if (busy_o) begin
      s_tran_cnt_d = (~cpol_i & pos_edge_i) || (cpol_i & neg_edge_i) ? (s_tran_cnt_q - 1'b1) : s_tran_cnt_q;
    end else begin
      unique case (dtb_i)
        2'b00: s_tran_cnt_d = {1'b0, 6'd8};
        2'b01: s_tran_cnt_d = {1'b0, 6'd16};
        2'b10: s_tran_cnt_d = {1'b0, 6'd24};
        2'b11: s_tran_cnt_d = {1'b0, 6'd32};
      endcase
    end
  end
  dffr #(`SPI_DATA_BIT_WIDTH + 2) u_tran_cnt_dffr (
      clk_i,
      rst_n_i,
      s_tran_cnt_d,
      s_tran_cnt_q
  );

  always_comb begin
    s_busy_d = s_busy_q;
    if (~s_busy_q && st_i) begin
      s_busy_d = 1'b1;
    end else if (s_busy_q && last_o && pos_edge_i) begin
      s_busy_d = 1'b0;  // NOTE: some error? pos_edge
    end
  end
  dffr #(1) u_busy_dffr (
      clk_i,
      rst_n_i,
      s_busy_d,
      s_busy_q
  );

  // tx
  assign s_mosi_d = (s_tx_clk || ~busy_o) ? s_tx_data_q[s_tx_idx[`SPI_DATA_BIT_WIDTH-1:0]] : s_mosi_q;
  dffr #(1) u_mosi_dffr (
      clk_i,
      rst_n_i,
      s_mosi_d,
      s_mosi_q
  );

  // tx fifo
  assign tx_ready_o   = ~busy_o;
  assign s_tx_data_en = tx_valid_i && tx_ready_o;
  assign s_tx_data_d  = s_tx_data_en ? tx_data_i : s_tx_data_q;
  dffer #(`SPI_DATA_WIDTH) u_tx_data_dffer (
      clk_i,
      rst_n_i,
      s_tx_data_en,
      s_tx_data_d,
      s_tx_data_q
  );

  assign s_rx_data_en = s_rx_clk || ~busy_o;
  assign s_rx_data_d  = s_rx_data_en ? {s_rx_data_q[`SPI_DATA_WIDTH-2:0], spi_miso_i} : s_rx_data_q;
  dffer #(`SPI_DATA_WIDTH) u_rx_dat_dffer (
      clk_i,
      rst_n_i,
      s_rx_data_en,
      s_rx_data_d,
      s_rx_data_q
  );

  // rx fifo
  assign rx_valid_o = 1'b1;
  assign rx_data_o  = (rx_valid_o && rx_ready_i) ? s_rx_data_q : '0;
endmodule
