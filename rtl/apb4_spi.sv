// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "register.sv"
`include "fifo.sv"
`include "spi_define.sv"

module apb4_spi #(
    parameter int FIFO_DEPTH     = 16,
    parameter int LOG_FIFO_DEPTH = $clog2(FIFO_DEPTH)
) (
    apb4_if.slave apb4,
    spi_if.dut    spi
);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`SPI_CTRL1_WIDTH-1:0] s_spi_ctrl1_d, s_spi_ctrl1_q;
  logic s_spi_ctrl1_en;
  logic [`SPI_CTRL2_WIDTH-1:0] s_spi_ctrl2_d, s_spi_ctrl2_q;
  logic s_spi_ctrl2_en;
  logic [`SPI_DIV_WIDTH-1:0] s_spi_div_d, s_spi_div_q;
  logic s_spi_div_en;
  logic [`SPI_STAT_WIDTH-1:0] s_spi_stat_d, s_spi_stat_q;
  logic s_spi_stat_en;

  logic s_bit_cpha, s_bit_cpol, s_bit_lsb, s_bit_ass, s_bit_rdm, s_bit_sstr;
  logic [1:0] s_bit_dtb;
  logic s_bit_txie, s_bit_rxie, s_bit_en, s_bit_st;
  logic [3:0] s_bit_nss;
  logic s_bit_txif, s_bit_rxif, s_bit_busy;
  // fifo
  logic s_tx_push_valid, s_tx_push_ready, s_tx_empty, s_tx_full, s_tx_pop_valid, s_tx_pop_ready;
  logic s_rx_push_valid, s_rx_push_ready, s_rx_empty, s_rx_full, s_rx_pop_valid, s_rx_pop_ready;
  logic [31:0] s_tx_push_data, s_tx_pop_data, s_rx_push_data, s_rx_pop_data;
  logic [LOG_FIFO_DEPTH:0] s_tx_elem, s_rx_elem;
  // spi
  logic s_pos_edge, s_neg_edge;

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_cpha      = s_spi_ctrl1_q[0];
  assign s_bit_cpol      = s_spi_ctrl1_q[1];
  assign s_bit_lsb       = s_spi_ctrl1_q[2];
  assign s_bit_ass       = s_spi_ctrl1_q[3];
  assign s_bit_rdm       = s_spi_ctrl1_q[4];
  assign s_bit_sstr      = s_spi_ctrl1_q[5];
  assign s_bit_dtb       = s_spi_ctrl1_q[7:6];
  assign s_bit_txie      = s_spi_ctrl2_q[0];
  assign s_bit_rxie      = s_spi_ctrl2_q[1];
  assign s_bit_en        = s_spi_ctrl2_q[2];
  assign s_bit_st        = s_spi_ctrl2_q[3];
  assign s_bit_nss       = s_spi_ctrl2_q[7:4];

  assign s_spi_stat_q[0] = s_bit_txif;
  assign s_spi_stat_q[1] = s_bit_rxif;
  assign s_spi_stat_q[2] = s_bit_busy;
  assign irq_o           = s_bit_txif | s_bit_rxif;

  assign s_spi_ctrl1_en  = s_apb4_wr_hdshk && s_apb4_addr == `SPI_CTRL1 && ~s_bit_busy;
  assign s_spi_ctrl1_d   = s_spi_ctrl1_en ? apb4.pwdata[`SPI_CTRL1_WIDTH-1:0] : s_spi_ctrl1_q;
  dffer #(`SPI_CTRL1_WIDTH) u_spi_ctrl1_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_ctrl1_en,
      s_spi_ctrl1_d,
      s_spi_ctrl1_q
  );

  assign s_spi_ctrl2_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_CTRL2 && ~s_bit_busy;
  assign s_spi_ctrl2_d  = s_spi_ctrl2_en ? apb4.pwdata[`SPI_CTRL2_WIDTH-1:0] : s_spi_ctrl2_q;
  dffer #(`SPI_CTRL2_WIDTH) u_spi_ctrl2_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_ctrl2_en,
      s_spi_ctrl2_d,
      s_spi_ctrl2_q
  );

  assign s_spi_div_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_DIV && ~s_bit_busy;
  assign s_spi_div_d  = s_spi_div_en ? apb4.pwdata[`SPI_DIV_WIDTH-1:0] : s_spi_div_q;
  dffer #(`SPI_DIV_WIDTH) u_spi_div_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_div_en,
      s_spi_div_d,
      s_spi_div_q
  );

  always_comb begin
    s_tx_push_valid = 1'0;
    s_tx_push_data  = '0;
    if (s_apb4_wr_hdshk && s_apb4_addr == `SPI_TXR) begin
      s_tx_push_valid = 1'b1;
      unique case (s_bit_dtb)
        2'b00: s_tx_push_data = apb4.pwdata[7:0];
        2'b01: s_tx_push_data = apb4.pwdata[15:0];
        2'b10: s_tx_push_data = apb4.pwdata[23:0];
        2'b11: s_tx_push_data = apb4.pwdata[31:0];
      endcase
    end
  end

  assign s_spi_stat_en = ((s_bit_txif || s_bit_rxif) && s_apb4_rd_hdshk && s_apb4_addr == `SPI_STAT)
                      || (~s_bit_txif && s_bit_en && s_bit_txie && s_tx_irq_trg)
                      || (~s_bit_rxif && s_bit_en && s_bit_rxie && s_rx_irq_trg);
  always_comb begin
    s_spi_stat_d = s_spi_stat_q;
    if ((s_bit_txif || s_bit_rxif) && s_apb4_rd_hdshk && s_apb4_addr == `SPI_STAT) begin
      s_spi_stat_d = {s_bit_busy, 2'b0};
    end else if (~s_bit_txif && s_bit_en && s_bit_txie && s_tx_irq_trg) begin
      s_spi_stat_d = {s_bit_busy, s_bit_rxif, 1'b1};
    end else if (~s_bit_rxif && s_bit_en && s_bit_rxie && s_rx_irq_trg) begin
      s_spi_stat_d = {s_bit_busy, 1'b1, s_bit_txif};
    end else if (1'b0) begin  // TODO: busy flag
      s_spi_stat_d = {1'b0, s_bit_rxif, s_bit_txif};
    end
  end
  dffer #(`SPI_STAT_WIDTH) u_spi_stat_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_stat_en,
      s_spi_stat_d,
      s_spi_stat_q
  );


  assign s_spi_rv_rx = {
    s_rx_pop_data[7:0], s_rx_pop_data[15:8], s_rx_pop_data[23:16], s_rx_pop_data[31:24]
  };
  always_comb begin
    apb4.prdata    = '0;
    s_rx_pop_ready = 1'0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `SPI_CTRL1: apb4.prdata[`SPI_CTRL1_WIDTH-1:0] = s_spi_ctrl1_q;
        `SPI_CTRL2: apb4.prdata[`SPI_CTRL2_WIDTH-1:0] = s_spi_ctrl2_q;
        `SPI_DIV:   apb4.prdata[`SPI_DIV_WIDTH-1:0] = s_spi_div_q;
        `SPI_RXR: begin
          s_rx_pop_ready                  = 1'b1;
          apb4.prdata[`SPI_RXR_WIDTH-1:0] = s_bit_rdm ? s_spi_rv_rx : s_rx_pop_data;
        end
        `SPI_STAT:  apb4.prdata[`SPI_STAT_WIDTH-1:0] = s_spi_stat_q;
        default:    apb4.prdata = '0;
      endcase
    end
  end

  spi_clkgen u_spi_clkgen (
      .clk_i     (apb4.pclk),
      .rst_n_i   (apb4.presetn),
      .en_i      (s_bit_en),
      .st_i      (s_bit_st),
      .cpol_i    (s_bit_cpol),
      .cpha_i    (s_bit_cpha),
      .clk_div_i (s_spi_div_q),
      .last_i    (s_last),
      .clk_o     (spi.spi_sck_o),
      .pos_edge_o(s_pos_edge),
      .neg_edge_o(s_neg_edge)
  );

  assign s_tx_push_ready = ~s_tx_full;
  assign s_tx_pop_valid  = ~s_tx_empty;
  fifo #(
      .DATA_WIDTH  (32),
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_tx_fifo (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .flush_i(~s_bit_en),
      .cnt_o  (s_tx_elem),
      .push_i (s_tx_push_valid),
      .full_o (s_tx_full),
      .dat_i  (s_tx_push_data),
      .pop_i  (s_tx_pop_ready),
      .empty_o(s_tx_empty),
      .dat_o  (s_tx_pop_data)
  );

  assign s_rx_push_ready = ~s_rx_full;
  assign s_rx_pop_valid  = ~s_rx_empty;
  fifo #(
      .DATA_WIDTH  (32),
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_rx_fifo (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .flush_i(~s_bit_en),
      .cnt_o  (s_rx_elem),
      .push_i (s_rx_push_valid),
      .full_o (s_rx_full),
      .dat_i  (s_rx_push_data),
      .pop_i  (s_rx_pop_ready),
      .empty_o(s_rx_empty),
      .dat_o  (s_rx_pop_data)
  );


  spi_core u_spi_core (
      .clk_i     (apb4.pclk),
      .rst_n_i   (apb4.presetn),
      .lsb_i     (s_bit_lsb),
      .st_i      (s_bit_st),
      .pos_edge_i(s_pos_edge),
      .neg_edge_i(s_neg_edge),
      .cpol_i    (s_bit_cpol),
      .cpha_i    (s_bit_cpha),
      .dtb_i     (s_bit_dtb),
      .busy_o    (s_bit_busy),
      .last_o    (s_last),
      .spi_clk_i (spi.spi_sck_o),
      .spi_mosi_i(spi.spi_mosi_o),
      .spi_miso_o(spi.spi_miso_i)
  );

endmodule
