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
`include "spi_define.sv"

module apb4_spi (
    apb4_if.slave apb4,
    spi_if.dut    spi
);

  logic [3:0] s_apb4_addr;
  logic [31:0] s_spi_ctrl_d, s_spi_ctrl_q;
  logic [31:0] s_spi_tx_d, s_spi_tx_q;
  logic [31:0] s_spi_rx_q;
  logic [ 7:0] s_spi_div;
  logic [ 3:0] s_spi_nss;
  logic [ 1:0] s_spi_dtb;
  logic [31:0] s_spi_rv_rx;
  logic s_spi_busy, s_spi_st, s_spi_en, s_spi_rxe, s_spi_txe;
  logic s_spi_mstr, s_spi_rdm, s_spi_ass, s_spi_lsb, s_spi_cpol, s_spi_cpha;

  assign s_apb4_addr = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready = 1'b1;
  assign apb4.pslverr = 1'b0;
  assign irq_o = s_spi_en && (s_spi_txe || s_spi_rxe);
  assign s_spi_rv_rx = {s_spi_rx_q[7:0], s_spi_rx_q[15:8], s_spi_rx_q[23:16], s_spi_rx_q[31:24]};
  assign s_spi_nss = s_spi_ctrl_q[24:21];
  assign s_spi_busy = s_spi_ctrl_q[20];
  assign s_spi_st = s_spi_ctrl_q[19];
  assign s_spi_en = s_spi_ctrl_q[18];
  assign s_spi_rxe = s_spi_ctrl_q[17];
  assign s_spi_txe = s_spi_ctrl_q[16];
  assign s_spi_div = s_spi_ctrl_q[15:8];
  assign s_spi_dtb = s_spi_ctrl_q[7:6];
  assign s_spi_mstr = s_spi_ctrl_q[5];
  assign s_spi_rdm = s_spi_ctrl_q[4];
  assign s_spi_ass = s_spi_ctrl_q[3];
  assign s_spi_lsb = s_spi_ctrl_q[2];
  assign s_spi_cpol = s_spi_ctrl_q[1];
  assign s_spi_cpha = s_spi_ctrl_q[0];


  assign s_spi_ctrl_d    = (s_apb4_wr_hdshk && s_apb4_addr == `SPI_CTRL && ~s_spi_busy) ? apb4.pwdata : s_spi_clk_q;
  dffr #(32) u_spi_ctrl_dffr (
      apb4.pclk,
      apb4.presetn,
      s_spi_ctrl_d,
      s_spi_ctrl_q
  );

  always_comb begin
    s_spi_tx_d = s_spi_tx_q;
    if (s_apb4_wr_hdshk && s_apb4_addr == `SPI_TX && ~s_spi_busy) begin
      unique case (s_spi_dtb)
        2'b00: s_spi_tx_d = apb4.pwdata[7:0];
        2'b01: s_spi_tx_d = apb4.pwdata[15:0];
        2'b10: s_spi_tx_d = apb4.pwdata[23:0];
        2'b11: s_spi_tx_d = apb4.pwdata[31:0];
      endcase
    end
  end
  dffr #(32) u_spi_tx_dffr (
      apb4.pclk,
      apb4.presetn,
      s_spi_tx_d,
      s_spi_tx_q
  );

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `SPI_CTRL: apb4.prdata = s_spi_ctrl_q;
        `SPI_TX:   apb4.prdata = s_spi_tx_q;
        `SPI_RX:   apb4.pready = s_spi_rdm == 1'b1 ? s_spi_rv_rx : s_spi_rx_q;
      endcase
    end
  end

  spi_clkgen u_spi_clkgen (
      .clk_i          (abp4.pclk),
      .rst_n_i        (apb4.presetn),
      .clk_en_i       (1'b1),
      .clk_div_i      (s_spi_div),
      .clk_div_valid_i(),
      .cpol_i         (s_spi_cpol),
      .spi_clk_o      (),
      .spi_rise_o     (),
      .spi_fall_o     ()
  );

endmodule
