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
    input  logic [               1:0] cmode_i,
    input  logic [               1:0] amode_i,
    input  logic [               1:0] asize_i,
    input  logic [               1:0] almode_i,
    input  logic [               1:0] alsize_i,
    input  logic [               1:0] dmode_i,
    input  logic [               1:0] dsize_i,
    input  logic [               7:0] cmd_i,
    input  logic [              31:0] addr_i,
    input  logic [              31:0] altr_i,
    input  logic [              15:0] nop_i,
    input  logic [`SPI_TRL_WIDTH-1:0] trl_i,
    input  logic                      cpol_i,
    input  logic                      cpha_i,
    input  logic [               7:0] div_i,
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
  logic s_pos_edge, s_neg_edge;
  logic [2:0] s_spi_fsm_d, s_spi_fsm_q;
  logic [3:0] s_nss_sel;
  logic       s_tx_shift_1;
  logic [1:0] s_tx_shift_2;
  logic [3:0] s_tx_shift_4;
  // software nss ctrl is more flexible
  assign s_nss_sel    = (nss_i & {4{busy_o & ass_i}}) | (nss_i & {4{~ass_i}});
  assign spi_nss_o    = ~(s_nss_sel[`SPI_NSS_NUM-1:0] ^ csv_i[`SPI_NSS_NUM-1:0]);

  assign busy_o       = '0;
  assign last_o       = '0;
  assign tx_ready_o   = '0;
  assign rx_valid_o   = '0;
  assign rx_data_o    = '0;

  spi_clkgen u_spi_clkgen (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .busy_i    (1'b1),
      .st_i      (1'b1),
      .cpol_i    (1'b0),
      .div_i     (8'd1),
      .last_i    (1'b0),
      .clk_o     (spi_sck_o),
      .pos_edge_o(s_pos_edge),
      .neg_edge_o(s_neg_edge)
  );


  always_comb begin
    s_spi_fsm_d = s_spi_fsm_q;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: begin
      end
      `SPI_FSM_CMD: begin
      end
      `SPI_FSM_ADDR: begin
      end
      `SPI_FSM_ALTR: begin
      end
      `SPI_FSM_NOP: begin
      end
      `SPI_FSM_WDATA: begin
      end
      `SPI_FSM_RDATA: begin
      end
      default: s_spi_fsm_d = `SPI_FSM_IDLE;
    endcase
  end
  dffr #(3) u_spi_fsm_dffr (
      clk_i,
      rst_n_i,
      s_spi_fsm_d,
      s_spi_fsm_q
  );


  // cmd: 8, shift-1, -2, -4
  // addr: 8~32b, shift-1, -2, -4
  // altr: 8~32b, shift-1, -2, -4
  // data: mulit 8~32b, shift-1, -2, -4
  // spi_io_en_o, spi_io_out_o

  always_comb begin
    spi_io_en_o  = '0;  // high-z
    spi_io_out_o = '0;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: begin
        spi_io_en_o  = '0;
        spi_io_out_o = '0;
      end
      `SPI_FSM_CMD: begin
        unique case (cmode_i)
          `SPI_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2[0];
            spi_io_out_o[1] = s_tx_shift_2[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4[0];
            spi_io_out_o[1] = s_tx_shift_4[1];
            spi_io_out_o[2] = s_tx_shift_4[2];
            spi_io_out_o[3] = s_tx_shift_4[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_ADDR: begin
        unique case (amode_i)
          `SPI_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2[0];
            spi_io_out_o[1] = s_tx_shift_2[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4[0];
            spi_io_out_o[1] = s_tx_shift_4[1];
            spi_io_out_o[2] = s_tx_shift_4[2];
            spi_io_out_o[3] = s_tx_shift_4[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_ALTR: begin
        unique case (almode_i)
          `SPI_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2[0];
            spi_io_out_o[1] = s_tx_shift_2[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4[0];
            spi_io_out_o[1] = s_tx_shift_4[1];
            spi_io_out_o[2] = s_tx_shift_4[2];
            spi_io_out_o[3] = s_tx_shift_4[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_NOP: begin
        spi_io_en_o  = '1;
        spi_io_out_o = '0;
      end
      `SPI_FSM_WDATA: begin
        unique case (dmode_i)
          `SPI_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2[0];
            spi_io_out_o[1] = s_tx_shift_2[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4[0];
            spi_io_out_o[1] = s_tx_shift_4[1];
            spi_io_out_o[2] = s_tx_shift_4[2];
            spi_io_out_o[3] = s_tx_shift_4[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_RDATA: begin
        unique case (dmode_i)
          `SPI_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b0;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = 1'b0;
            spi_io_out_o[1] = 1'b0;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b0;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b0;
            spi_io_en_o[3]  = 1'b0;
            spi_io_out_o[0] = 1'b0;
            spi_io_out_o[1] = 1'b0;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b0;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      default: begin
        spi_io_en_o  = '0;
        spi_io_out_o = '0;
      end
    endcase
  end

  // dw: 8, 16, 24, 32 // 12
  // shift 1 2 4

  // for()
  // assign s_tx_shift_1 = 
  // shift_reg #(
  //     .DATA_WIDTH(8 * i),
  //     .SHIFT_NUM (1)
  // ) u_std_spi_tx_shift_reg (
  //     .clk_i     (clk_i),
  //     .rst_n_i   (rst_n_i),
  //     .type_i    (`SHIFT_REG_TYPE_LOGIC),
  //     .dir_i     ({1'b0, lsb_i}),
  //     .ld_en_i   (tx_valid_i && tx_ready_o),
  //     .sft_en_i  (s_tx_trg),
  //     .ser_dat_i (1'b0),
  //     .par_data_i(),
  //     .ser_dat_o (),
  //     .par_data_o()
  // );
endmodule
