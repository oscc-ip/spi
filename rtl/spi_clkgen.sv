// Copyright 2015 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

module spi_clkgen (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       clk_en_i,
    input  logic [7:0] clk_div_i,
    input  logic       clk_div_valid_i,
    input  logic       cpol_i,
    output logic       spi_clk_o,
    output logic       spi_rise_o,
    output logic       spi_fall_o
);

  logic [7:0] s_cnt_div_d, s_cnt_div_q;
  logic [7:0] s_cnt_d, s_cnt_q;
  logic s_spi_clk_d, s_spi_clk_q;
  logic s_running_d, s_running_q;

  assign spi_clk_o   = s_spi_clk_q;
  assign spi_rise_o  = (s_cnt_q == s_cnt_div_q && s_spi_clk_q == 1'b0) ? s_running_q : 1'b0;
  assign spi_fall_o  = (s_cnt_q == s_cnt_div_q && s_spi_clk_q == 1'b1) ? s_running_q : 1'b0;

  assign s_cnt_div_d = clk_div_valid_i ? clk_div_i : s_cnt_div_q;
  dffr #(8) u_cnt_div_dffr (
      clk_i,
      rst_n_i,
      s_cnt_div_d,
      s_cnt_div_q
  );

  assign s_cnt_d = (~clk_en_i || s_cnt_q == s_cnt_div_q) ? '0 : s_cnt_q + 1'b1;
  dffr #(8) u_cnt_dffr (
      clk_i,
      rst_n_i,
      s_cnt_d,
      s_cnt_q
  );

  always_comb begin
    s_spi_clk_d = s_spi_clk_q;
    if (clk_en_i == 1'b0) begin
      s_spi_clk_d = cpol_i;
    end else if (clk_en_i && s_cnt_q == s_cnt_div_q) begin
      s_spi_clk_d = ~s_spi_clk_q;
    end
  end
  dffr #(1) u_spi_clk_dffr (
      clk_i,
      rst_n_i,
      s_spi_clk_d,
      s_spi_clk_q
  );

  assign s_running_d = clk_en_i;
  dffr #(1) u_running_dffr (
      clk_i,
      rst_n_i,
      s_running_d,
      s_running_q
  );

endmodule
