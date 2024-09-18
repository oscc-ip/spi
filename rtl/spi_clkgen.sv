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

module spi_clkgen (
    input  logic                      clk_i,
    input  logic                      rst_n_i,
    input  logic                      busy_i,
    input  logic                      st_i,
    input  logic                      cpol_i,
    input  logic [`SPI_DIV_WIDTH-1:0] clk_div_i,
    input  logic                      last_i,
    output logic                      clk_o,
    output logic                      pos_edge_o,
    output logic                      neg_edge_o
);

  logic [`SPI_DIV_WIDTH-1:0] s_cnt_d, s_cnt_q;
  logic s_spi_clk_d, s_spi_clk_q;
  logic s_spi_pos_edge_d, s_spi_pos_edge_q;
  logic s_spi_neg_edge_d, s_spi_neg_edge_q;
  logic s_is_zero, s_is_one;

  assign s_is_zero  = s_cnt_q == '0;
  assign s_is_one   = s_cnt_q == {{(`SPI_DIV_WIDTH - 1) {1'b0}}, 1'b1};
  assign clk_o      = s_spi_clk_q;
  assign pos_edge_o = s_spi_pos_edge_q;
  assign neg_edge_o = s_spi_neg_edge_q;

  assign s_cnt_d    = (~busy_i || s_is_zero) ? clk_div_i : s_cnt_q - 1'b1;
  dffrh #(`SPI_DIV_WIDTH) u_cnt_dffrh (
      clk_i,
      rst_n_i,
      s_cnt_d,
      s_cnt_q
  );

  always_comb begin
    s_spi_clk_d = s_spi_clk_q;
    if (~busy_i) begin
      s_spi_clk_d = cpol_i;
    end else if (busy_i && s_is_zero && (~last_i || (s_spi_clk_q ^ cpol_i))) begin
      s_spi_clk_d = ~s_spi_clk_q;
    end
  end
  dffr #(1) u_spi_clk_dffr (
      clk_i,
      rst_n_i,
      s_spi_clk_d,
      s_spi_clk_q
  );


  // clk_div_i == 0 : 2-div need to do special judge
  always_comb begin
    s_spi_pos_edge_d = '0;
    if (busy_i && ~s_spi_clk_q && s_is_one) begin
    end else if (clk_div_i == '0) begin
      if (~cpol_i) begin
        s_spi_pos_edge_d = (s_spi_clk_q || (~busy_i && st_i)) && ~last_i;
      end else begin
        s_spi_pos_edge_d = s_spi_clk_q && busy_i && ~last_i;
      end
    end
  end
  dffr #(1) u_spi_pos_edge_dffr (
      clk_i,
      rst_n_i,
      s_spi_pos_edge_d,
      s_spi_pos_edge_q
  );

  always_comb begin
    s_spi_neg_edge_d = '0;
    if (busy_i && s_spi_clk_q && s_is_one) begin
      s_spi_neg_edge_d = 1'b1;
    end else if (clk_div_i == '0) begin
      if (cpol_i) begin
        s_spi_neg_edge_d = (~s_spi_clk_q || (~busy_i && st_i)) && ~last_i;
      end else begin
        s_spi_neg_edge_d = ~s_spi_clk_q && busy_i && ~last_i;
      end
    end
  end
  dffr #(1) u_spi_neg_edge_dffr (
      clk_i,
      rst_n_i,
      s_spi_neg_edge_d,
      s_spi_neg_edge_q
  );
endmodule