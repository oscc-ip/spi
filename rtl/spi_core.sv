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

module spi_core #(
    parameter int FIFO_DEPTH = 64
) (
    input  logic                      clk_i,
    input  logic                      rst_n_i,
    input  logic                      en_i,
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

  logic s_pos_edge, s_neg_edge, s_clk_trg, s_tx_trg;
  logic s_trans_done, s_dely_done;

  logic [3:0] s_nss_sel;
  logic [7:0] s_tx_data;

  logic s_busy_d, s_busy_q;
  logic [2:0] s_spi_fsm_d, s_spi_fsm_q;
  logic [2:0] s_sg_cnt_d, s_sg_cnt_q;
  logic [2:0] s_sg_tran_cnt_d, s_sg_tran_cnt_q, s_sg_tran_val;
  logic [15:0] s_dat_cnt_d, s_dat_cnt_q;
  logic [15:0] s_dely_cnt_d, s_dely_cnt_q;

  logic s_tx_shift_1_ld, s_tx_shift_2_ld, s_tx_shift_4_ld;
  logic       s_tx_shift_1_dat;
  logic [1:0] s_tx_shift_2_dat;
  logic [3:0] s_tx_shift_4_dat;


  assign tx_ready_o = '0;
  assign rx_valid_o = '0;
  assign rx_data_o  = '0;

  // software nss ctrl is more flexible
  assign s_nss_sel  = (nss_i & {4{busy_o & ass_i}}) | (nss_i & {4{~ass_i}});
  assign spi_nss_o  = ~(s_nss_sel[`SPI_NSS_NUM-1:0] ^ csv_i[`SPI_NSS_NUM-1:0]);

  assign s_tx_trg   = (cpol_i ^ cpha_i ? s_pos_edge : s_neg_edge) && ~last_o;
  // s_rx_trg
  assign busy_o     = s_busy_q;
  always_comb begin
    last_o       = '0;
    s_trans_done = '1;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: s_trans_done = '1;
      `SPI_FSM_CMD:  s_trans_done = (s_sg_cnt_q == '0) && (s_sg_tran_cnt_q == s_sg_tran_val);
      `SPI_FSM_ADDR: s_trans_done = (s_sg_cnt_q == asize_i) && (s_sg_tran_cnt_q == s_sg_tran_val);
      `SPI_FSM_ALTR: s_trans_done = (s_sg_cnt_q == alsize_i) && (s_sg_tran_cnt_q == s_sg_tran_val);
      `SPI_FSM_NOP:  s_trans_done = '0;
      `SPI_FSM_WDATA: begin
        s_trans_done = (s_dat_cnt_q == trl_i) && (s_sg_cnt_q == dsize_i) && (s_sg_tran_cnt_q == s_sg_tran_val);
        last_o = s_trans_done;
      end
      default:       s_trans_done = '1;
    endcase
  end

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


  assign s_dely_done = s_dely_cnt_q == nop_i;
  always_comb begin
    s_dely_cnt_d = '0;
    if (s_spi_fsm_q == `SPI_FSM_NOP) begin
      if (s_dely_cnt_q == nop_i) s_dely_cnt_d = '0;
      else s_dely_cnt_d = s_dely_cnt_q + 1'b1;
    end
  end
  dffr #(16) u_dely_cnt_dffr (
      clk_i,
      rst_n_i,
      s_dely_cnt_d,
      s_dely_cnt_q
  );


  always_comb begin
    s_dat_cnt_d = '0;
    if (s_spi_fsm_q == `SPI_FSM_WDATA) begin
      if (s_dat_cnt_q == trl_i) s_dat_cnt_d = '0;
      else s_dat_cnt_d = s_dat_cnt_q + 1'b1;
    end
  end
  dffr #(16) u_dat_cnt_dffr (
      clk_i,
      rst_n_i,
      s_dat_cnt_d,
      s_dat_cnt_q
  );

  spi_clkgen u_spi_clkgen (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .busy_i    (busy_o),
      .st_i      (st_i),
      .cpol_i    (cpol_i),
      .div_i     (div_i),
      .last_i    (last_o),
      .clk_trg_o (s_clk_trg),
      .clk_o     (spi_sck_o),
      .pos_edge_o(s_pos_edge),
      .neg_edge_o(s_neg_edge)
  );


  always_comb begin
    s_spi_fsm_d = s_spi_fsm_q;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: begin
        if (st_i) begin
          if (cmode_i != '0) s_spi_fsm_d = `SPI_FSM_CMD;
          else if (amode_i != '0) s_spi_fsm_d = `SPI_FSM_ADDR;
          else if (almode_i != '0) s_spi_fsm_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_spi_fsm_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_spi_fsm_d = `SPI_FSM_RDATA;
            else s_spi_fsm_d = `SPI_FSM_WDATA;
          end else s_spi_fsm_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_CMD: begin
        if (s_trans_done) begin
          if (amode_i != '0) s_spi_fsm_d = `SPI_FSM_ADDR;
          else if (almode_i != '0) s_spi_fsm_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_spi_fsm_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_spi_fsm_d = `SPI_FSM_RDATA;
            else s_spi_fsm_d = `SPI_FSM_WDATA;
          end else s_spi_fsm_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_ADDR: begin
        if (s_trans_done) begin
          if (almode_i != '0) s_spi_fsm_d = `SPI_FSM_ALTR;
          else if (nop_i != '0) s_spi_fsm_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_spi_fsm_d = `SPI_FSM_RDATA;
            else s_spi_fsm_d = `SPI_FSM_WDATA;
          end else s_spi_fsm_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_ALTR: begin
        if (s_trans_done) begin
          if (nop_i != '0) s_spi_fsm_d = `SPI_FSM_NOP;
          else if (dmode_i != '0) begin
            if (rwm_i) s_spi_fsm_d = `SPI_FSM_RDATA;
            else s_spi_fsm_d = `SPI_FSM_WDATA;
          end else s_spi_fsm_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_NOP: begin
        if (s_dely_done) begin
          if (dmode_i != '0) begin
            if (rwm_i) s_spi_fsm_d = `SPI_FSM_RDATA;
            else s_spi_fsm_d = `SPI_FSM_WDATA;
          end else s_spi_fsm_d = `SPI_FSM_IDLE;
        end
      end
      `SPI_FSM_WDATA: begin
        if (s_trans_done) s_spi_fsm_d = `SPI_FSM_IDLE;
      end
      `SPI_FSM_RDATA: begin
        if (s_trans_done) s_spi_fsm_d = `SPI_FSM_IDLE;
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

  always_comb begin
    spi_io_en_o   = '0;
    spi_io_out_o  = '0;
    s_sg_tran_val = 3'd7;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: begin
        spi_io_en_o   = '0;
        spi_io_out_o  = '0;
        s_sg_tran_val = 3'd7;
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
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd3;
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
            s_sg_tran_val   = 3'd1;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd3;
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
            s_sg_tran_val   = 3'd1;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd3;
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
            s_sg_tran_val   = 3'd1;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd3;
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
            s_sg_tran_val   = 3'd1;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd7;
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
            s_sg_tran_val   = 3'd3;
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
            s_sg_tran_val   = 3'd1;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
            s_sg_tran_val   = 3'd7;
          end
        endcase
      end
      default: begin
        spi_io_en_o   = '0;
        spi_io_out_o  = '0;
        s_sg_tran_val = 3'd7;
      end
    endcase
  end

  // split the data into 8b type
  always_comb begin
    s_tx_data  = '0;
    s_sg_cnt_d = '0;
    unique case (s_spi_fsm_q)
      `SPI_FSM_IDLE: s_tx_data = '0;
      `SPI_FSM_CMD:  s_tx_data = cmd_i;
      `SPI_FSM_ADDR: begin
        // 8~32b split
        // asize_i:
        // 0->[7:0]
        // 1->[15:8] [7:0]
        // 2->[23:16] [15:8] [7:0]
        // 3->[31:24] [23:16] [15:8] [7:0]
        if (s_sg_cnt_q == asize_i) s_sg_cnt_d = '0;
        else s_sg_cnt_d = s_sg_cnt_q + 1'b1;
        s_tx_data = addr_i[(asize_i-s_sg_cnt_q)*8+:8];
      end
      `SPI_FSM_ALTR: begin
        if (s_sg_cnt_q == alsize_i) s_sg_cnt_d = '0;
        else s_sg_cnt_d = s_sg_cnt_q + 1'b1;
        s_tx_data = addr_i[(alsize_i-s_sg_cnt_q)*8+:8];
      end
      `SPI_FSM_NOP: begin
        s_tx_data  = '0;
        s_sg_cnt_d = '0;
      end
      `SPI_FSM_WDATA: begin
        if (s_sg_cnt_q == dsize_i) s_sg_cnt_d = '0;
        else s_sg_cnt_d = s_sg_cnt_q + 1'b1;
        s_tx_data = addr_i[(dsize_i-s_sg_cnt_q)*8+:8];
      end
      `SPI_FSM_RDATA: begin
        s_tx_data  = '0;
        s_sg_cnt_d = '0;
      end
      default: begin
        s_tx_data  = '0;
        s_sg_cnt_d = '0;
      end
    endcase
  end
  dffr #(3) u_sg_cnt_dffr (
      clk_i,
      rst_n_i,
      s_sg_cnt_d,
      s_sg_cnt_q
  );

  // s_sg_tran_val
  always_comb begin
    s_sg_tran_cnt_d = s_sg_tran_cnt_q;
    if (s_sg_tran_cnt_q == s_sg_tran_val) s_sg_tran_cnt_d = '0;
    else s_sg_tran_cnt_d = s_sg_tran_cnt_q + 1'b1;
  end
  dffr #(3) u_sg_tran_cnt_dffr (
      clk_i,
      rst_n_i,
      s_sg_tran_cnt_d,
      s_sg_tran_cnt_q
  );

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
