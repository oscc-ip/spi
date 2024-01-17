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
    input  logic                       pos_edge_i,
    input  logic                       neg_edge_i,
    input  logic                       cpol_i,
    input  logic                       cpha_i,
    input  logic [                1:0] dtb_i,
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
    input  logic                       spi_clk_i,
    output logic                       spi_mosi_o,
    input  logic                       spi_miso_i
);

  logic [`SPI_DATA_BIT_WIDTH+1:0] s_tran_cnt_d, s_tran_cnt_q;
  logic [`SPI_TRL_WIDTH-1:0] s_trl_d, s_trl_q;
  logic s_trl_en;
  logic [`SPI_DATA_WIDTH-1:0] s_tx_data_d, s_tx_data_q;
  logic s_tx_data_en;
  logic [`SPI_DATA_WIDTH-1:0] s_rx_data_d, s_rx_data_q;
  logic s_busy_d, s_busy_q;
  logic s_mosi_d, s_mosi_q;
  logic s_rx_data_en;
  logic s_tran_done, s_st_trg, s_data_trg;
  logic [3:0] s_std_mosi;
  logic [7:0] s_std_rd_data;


  assign busy_o      = s_busy_q;
  assign s_tran_done = ~(|s_tran_cnt_q);
  assign last_o      = s_tran_done && ~(|s_trl_q);
  assign s_data_trg  = (cpol_i ^ cpha_i ? pos_edge_i : neg_edge_i) && ~last_o;

  always_comb begin
    s_tran_cnt_d = s_tran_cnt_q;
    if (~s_tran_done && st_i) begin
      if ((~cpol_i & pos_edge_i) || (cpol_i & neg_edge_i)) begin
        s_tran_cnt_d = s_tran_cnt_q - 1'b1;
      end
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

  assign s_trl_en = trl_valid_i || s_tran_done;
  always_comb begin
    s_trl_d = s_trl_q;
    if (trl_valid_i) begin
      s_trl_d = trl_i;
    end else if (s_tran_done) begin
      s_trl_d = s_trl_q - 1'b1;
    end
  end
  dffer #(`SPI_TRL_WIDTH) u_trl_dffer (
      clk_i,
      rst_n_i,
      s_trl_en,
      s_trl_d,
      s_trl_q
  );

  always_comb begin
    s_busy_d = s_busy_q;
    if (~s_busy_q && st_i) begin
      s_busy_d = 1'b1;
    end else if (s_busy_q && last_o) begin
      s_busy_d = 1'b0;
    end
  end
  dffr #(1) u_busy_dffr (
      clk_i,
      rst_n_i,
      s_busy_d,
      s_busy_q
  );

  edge_det_sync_re #(
      .DATA_WIDTH(1)
  ) u_st_re (
      clk_i,
      rst_n_i,
      st_i,
      s_st_trg
  );

  // tx fifo
  assign spi_mosi_o = s_std_mosi[dtb_i];
  assign tx_ready_o = s_st_trg || s_tran_done;
  for (genvar i = 1; i <= 4; i++) begin
    shift_reg #(8 * i) u_tx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_LOGIC),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (tx_valid_i && tx_ready_o),
        .sft_en_i  (s_data_trg),
        .ser_dat_i (1'b0),
        .par_data_i(tx_data_i[8*i-1:0]),
        .ser_dat_o (s_std_mosi[i-1]),
        .par_data_o()
    );
  end

  // put data to rx fifo
  assign rx_valid_o = 1'b0;  // TODO:
  assign rx_data_o  = (rx_valid_o && rx_ready_i) ? s_std_rd_data : '0;
  shift_reg #(8) u_rx_shift_reg (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .type_i    (`SHIFT_REG_TYPE_LOGIC),
      .dir_i     ({1'b0, lsb_i}),
      .ld_en_i   (1'b0),
      .sft_en_i  (s_data_trg),
      .ser_dat_i (spi_miso_i),
      .par_data_i('0),
      .ser_dat_o (),
      .par_data_o(s_std_rd_data)
  );
endmodule
