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
`include "clk_int_div.sv"
`include "spi_define.sv"

module spi_core #(
    parameter int FIFO_DEPTH = 512
) (
    input  logic                    clk_i,
    input  logic                    rst_n_i,
    input  logic                    en_i,
    input  logic [             3:0] nss_i,
    input  logic [             3:0] csv_i,
    input  logic                    ass_i,
    input  logic                    lsb_i,
    input  logic                    st_i,
    input  logic                    rwm_i,
    input  logic [             1:0] cmode_i,
    input  logic [             1:0] amode_i,
    input  logic [             1:0] asize_i,
    input  logic [             1:0] almode_i,
    input  logic [             1:0] alsize_i,
    input  logic [             1:0] dmode_i,
    input  logic [             1:0] dsize_i,
    input  logic [             7:0] cmd_i,
    input  logic [            31:0] addr_i,
    input  logic [            31:0] altr_i,
    input  logic [            15:0] nop_i,
    input  logic [            15:0] trl_i,
    input  logic                    cpol_i,
    input  logic                    cpha_i,
    input  logic [             7:0] div_i,
    output logic                    busy_o,
    output logic                    last_o,
    input  logic                    tx_valid_i,
    output logic                    tx_ready_o,
    input  logic [             7:0] tx_data_i,
    output logic                    rx_valid_o,
    input  logic                    rx_ready_i,
    output logic [             7:0] rx_data_o,
    output logic                    spi_sck_o,
    output logic [`SPI_NSS_NUM-1:0] spi_nss_o,
    output logic [             3:0] spi_io_en_o,
    input  logic [             3:0] spi_io_in_i,
    output logic [             3:0] spi_io_out_o
);


  logic [3:0] s_nss_sel;
  // fsm
  logic [3:0] s_fsm_state_d, s_fsm_state_q;
  logic [9:0] s_fsm_cnt_d, s_fsm_cnt_q;
  logic s_ce_fsm_low_bound, s_ce_fsm_high_bound;
  logic s_xfer_done;
  // clk
  logic [7:0] s_div_val, s_clk_cnt;
  logic s_spi_clk;
  // tx data
  logic s_tx_shift_1_ld, s_tx_shift_2_ld, s_tx_shift_4_ld;
  logic       s_tx_trg;
  logic       s_tx_shift_1_dat;
  logic [1:0] s_tx_shift_2_dat;
  logic [3:0] s_tx_shift_4_dat;
  logic [7:0] s_tx_data;

  // assign
  assign s_ce_fsm_low_bound  = s_fsm_state_q > `SPI_FSM_TCSP;
  assign s_ce_fsm_high_bound = s_fsm_state_q < `SPI_FSM_TCHD;
  assign s_xfer_done         = '0;
  assign s_tx_trg            = '0;

  assign spi_sck_o           = s_ce_fsm_low_bound && s_ce_fsm_high_bound ? s_spi_clk : '0;
  assign busy_o              = ~(s_fsm_state_q == `SPI_FSM_IDLE || s_fsm_state_q == `SPI_FSM_RECY);
  assign last_o              = '0;
  assign tx_ready_o          = s_fsm_state_d == `SPI_FSM_IDLE;
  assign rx_valid_o          = s_fsm_state_d == `SPI_FSM_IDLE;
  assign rx_data_o           = '0;

  // software nss ctrl is more flexible
  assign s_nss_sel           = (nss_i & {4{busy_o & ass_i}}) | (nss_i & {4{~ass_i}});
  assign spi_nss_o           = ~(s_nss_sel[`SPI_NSS_NUM-1:0] ^ csv_i[`SPI_NSS_NUM-1:0]);


  always_comb begin
    s_div_val = 8'd1;
    unique case (div_i)
      `SPI_PSCR_DIV1:  s_div_val = 8'd0;
      `SPI_PSCR_DIV2:  s_div_val = 8'd1;
      `SPI_PSCR_DIV4:  s_div_val = 8'd3;
      `SPI_PSCR_DIV8:  s_div_val = 8'd7;
      `SPI_PSCR_DIV16: s_div_val = 8'd15;
      `SPI_PSCR_DIV32: s_div_val = 8'd31;
      default:         s_div_val = 8'd1;
    endcase
  end
  // when div_valid_i == 1, inter cnt reg will set to '0'
  clk_int_div_simple #(
      .DIV_VALUE_WIDTH (8),
      .DONE_DELAY_WIDTH(3)
  ) u_clk_int_div_simple (
      .clk_i      (clk_i),
      .rst_n_i    (rst_n_i),
      .div_i      (s_div_val),
      .div_valid_i(~busy_o),
      .clk_init_i (cpol_i),
      .div_ready_o(),
      .div_done_o (),
      .clk_cnt_o  (s_clk_cnt),
      .clk_trg_o  (),
      .clk_o      (s_spi_clk)
  );

  // 1. delay some cycles to meet tCSP at negedge of ce
  // 2. align the first posedge of spi_sck when ce == 0
  // 3. delay some cycles to meet tCHD at posedge of ce
  always_comb begin
    s_fsm_state_d = s_fsm_state_q;
    s_fsm_cnt_d   = s_fsm_cnt_q;
    unique case (s_fsm_state_q)
      `SPI_FSM_IDLE: begin
        if (st_i) begin
          s_fsm_state_d = `SPI_FSM_TCSP;
        end
      end
      `SPI_FSM_TCSP: begin
        if (s_xfer_done) begin
          if (cmode_i != '0) s_fsm_state_d = `SPI_FSM_CMD;
          else if (amode_i != '0) s_fsm_state_d = `SPI_FSM_ADDR;
          else if (almode_i != '0) s_fsm_state_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_fsm_state_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
          end else s_fsm_state_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_CMD: begin
        if (s_xfer_done) begin
          if (amode_i != '0) s_fsm_state_d = `SPI_FSM_ADDR;
          else if (almode_i != '0) s_fsm_state_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_fsm_state_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
          end else s_fsm_state_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_ADDR: begin
        if (s_xfer_done) begin
          if (almode_i != '0) s_fsm_state_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_fsm_state_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
          end else s_fsm_state_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_ALTR: begin
        if (s_xfer_done) begin
          if (nop_i != '0) s_fsm_state_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
          end else s_fsm_state_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_NOP: begin
        if (s_xfer_done) begin
          if (dmode_i != '0) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
          end else s_fsm_state_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_WDATA: begin
        if (s_xfer_done) s_fsm_state_d = `SPI_FSM_TCHD;
      end
      `SPI_FSM_RDATA: begin
        if (s_xfer_done) s_fsm_state_d = `SPI_FSM_TCHD;
      end
      `SPI_FSM_TCHD: begin
        if (s_xfer_done) s_fsm_state_d = `SPI_FSM_RECY;
      end
      `SPI_FSM_RECY: begin
        if (s_xfer_done) s_fsm_state_d = `SPI_FSM_IDLE;
      end
      default: s_fsm_state_d = `SPI_FSM_IDLE;
    endcase
  end
  dffr #(4) u_spi_fsm_dffr (
      clk_i,
      rst_n_i,
      s_fsm_state_d,
      s_fsm_state_q
  );

  always_comb begin
    spi_io_en_o  = '0;
    spi_io_out_o = '0;
    unique case (s_fsm_state_q)
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
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
            spi_io_out_o[0] = s_tx_shift_1_dat;
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

  shift_reg #(
      .DATA_WIDTH(8),
      .SHIFT_NUM (1)
  ) u_std_spi_tx_shift_reg (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .type_i    (`SHIFT_REG_TYPE_LOGIC),
      .dir_i     ({1'b0, lsb_i}),
      .ld_en_i   (s_tx_shift_1_ld),
      .sft_en_i  (s_tx_trg),
      .ser_dat_i ('0),
      .par_data_i(s_tx_data),
      .ser_dat_o (s_tx_shift_1_dat),
      .par_data_o()
  );

  shift_reg #(
      .DATA_WIDTH(8),
      .SHIFT_NUM (2)
  ) u_dual_spi_tx_shift_reg (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .type_i    (`SHIFT_REG_TYPE_LOGIC),
      .dir_i     ({1'b0, lsb_i}),
      .ld_en_i   (s_tx_shift_2_ld),
      .sft_en_i  (s_tx_trg),
      .ser_dat_i ('0),
      .par_data_i(s_tx_data),
      .ser_dat_o (s_tx_shift_2_dat),
      .par_data_o()
  );

  shift_reg #(
      .DATA_WIDTH(8),
      .SHIFT_NUM (4)
  ) u_quad_spi_tx_shift_reg (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .type_i    (`SHIFT_REG_TYPE_LOGIC),
      .dir_i     ({1'b0, lsb_i}),
      .ld_en_i   (s_tx_shift_4_ld),
      .sft_en_i  (s_tx_trg),
      .ser_dat_i ('0),
      .par_data_i(s_tx_data),
      .ser_dat_o (s_tx_shift_4_dat),
      .par_data_o()
  );

endmodule
