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
    input       clk_i,
    input       rst_n_i,
    input       lsb_i,
    input       st_i,
    input       pos_edge_i,
    input       neg_edge_i,
    input       cpol_i,
    input       cpha_i,
    input [1:0] dtb_i,

    output busy_o,
    output last_o,

    input spi_clk_i,
    input spi_mosi_o,
    input spi_miso_i

);

  logic [`SPI_DATA_BIT_WIDTH:0] s_tran_cnt_d, s_tran_cnt_q, s_tx_idx, s_rx_idx;
  logic s_busy_d, s_busy_q;
  logic s_mosi_d, s_mosi_q;
  logic [`SPI_DATA_NUM-1:0] tx_data, rx_data;
  logic s_tx_clk, s_rx_clk;


  assign busy_o   = s_busy_q;
  assign last_o   = ~(|s_tran_cnt_q);
  assign s_tx_idx = lsb_i ? 1'b0 : s_tran_cnt_q - 1'b1;
  // assign s_rx_idx = lsb_i ? 1'b0 : 


  always_comb begin
    s_tran_cnt_d = s_tran_cnt_q;
    if (busy_o) begin
      s_tran_cnt_d = pos_edge_i ? (s_tran_cnt_q - 1'b1) : s_tran_cnt_q;
    end else begin
      unique case (dtb_i)
        2'b00: s_tran_cnt_d = {1'b0, 5'd7};
        2'b01: s_tran_cnt_d = {1'b0, 5'd15};
        2'b10: s_tran_cnt_d = {1'b0, 5'd23};
        2'b11: s_tran_cnt_d = {1'b0, 5'd31};
      endcase
    end
  end
  dffr #(`SPI_DATA_BIT_WIDTH + 1) u_tran_cnt_dffr (
      apb4.pclk,
      apb4.presetn,
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
      apb4.pclk,
      apb4.presetn,
      s_busy_d,
      s_busy_q
  );


  assign s_mosi_d = (s_tx_clk || ~busy_o) ? tx_data[s_tx_idx[`SPI_DATA_BIT_WIDTH-1:0]] : s_mosi_q;
  dffr #(1) u_mosi_dffr (
      apb4.pclk,
      apb4.presetn,
      s_mosi_d,
      s_mosi_q
  );

endmodule
