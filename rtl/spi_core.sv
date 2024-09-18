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
    input  logic                       rwm_i,
    input  logic                       pos_edge_i,
    input  logic                       neg_edge_i,
    input  logic                       cpol_i,
    input  logic                       cpha_i,
    input  logic [                1:0] tdtb_i,
    input  logic [                1:0] rdtb_i,
    input  logic [                1:0] spm_i,
    input  logic [                3:0] snm_i,
    input  logic [ `SPI_CAL_WIDTH-1:0] cal_i,
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
    output logic [                3:0] spi_io_en_o,
    input  logic [                3:0] spi_io_in_i,
    output logic [                3:0] spi_io_out_o
);

  logic [`SPI_DATA_BIT_WIDTH+1:0] s_tran_cnt_d, s_tran_cnt_q;
  logic [`SPI_TRL_WIDTH-1:0] s_trl_d, s_trl_q;
  logic s_trl_en;
  logic [`SPI_DATA_WIDTH-1:0] s_tx_data_d, s_tx_data_q;
  logic s_tx_data_en;
  logic [`SPI_DATA_WIDTH-1:0] s_rx_data_d, s_rx_data_q;
  logic s_busy_d, s_busy_q;
  logic [3:0] s_ser_cnt_d, s_ser_cnt_q;
  logic s_rx_data_en, s_par_trg;
  logic s_tran_done, s_tran_done_fe_trg, s_st_re_trg, s_st_fe_trg, s_tx_trg, s_rx_trg;
  logic [ 3:0] s_std_mosi;
  logic [ 1:0] s_dual_io     [0:3];
  logic [ 1:0] s_dual_wr_data[0:3];
  logic [ 3:0] s_quad_io     [0:3];
  logic [ 3:0] s_quad_wr_data[0:3];
  logic [31:0] s_std_rd_data [0:3];
  logic [31:0] s_dual_rd_data[0:3];
  logic [31:0] s_quad_rd_data[0:3];

  // rx trg need to delay one cycle
  assign s_tran_done = ~(|s_tran_cnt_q);
  assign s_tx_trg    = (cpol_i ^ cpha_i ? pos_edge_i : neg_edge_i) && ~last_o;
  assign s_rx_trg    = (cpol_i ^ cpha_i ? pos_edge_i : neg_edge_i);
  assign busy_o      = s_busy_q;
  assign last_o      = s_tran_done && ~(|s_trl_q);

  // spi mode ctrl
  always_comb begin
    spi_io_en_o = '1;
    unique case (spm_i)
      `SPI_STD_SPI: begin
        spi_io_en_o[0] = 1'b0;
        spi_io_en_o[1] = 1'b1;
      end
      `SPI_DUAL_SPI: begin
        if (~rwm_i) begin
          spi_io_en_o[1:0] = '0;  // wr only oper
        end else begin  // when par addr mode, set io high-z state
          spi_io_en_o[0] = s_trl_q <= cal_i ? 1'b1 : 1'b0;
          spi_io_en_o[1] = snm_i > 4'b1 ? 1'b1 : (s_trl_q <= cal_i ? 1'b1 : 1'b0);
        end
      end
      `SPI_QUAD_SPI: begin
        if (~rwm_i) begin
          spi_io_en_o[3:0] = '0;  // wr only oper
        end else begin
          spi_io_en_o[0]   = s_trl_q <= cal_i ? 1'b1 : 1'b0;
          spi_io_en_o[3:1] = snm_i > 4'b1 ? '1 : (s_trl_q <= cal_i ? '1 : '0);
        end
      end
      default: spi_io_en_o = '1;
    endcase
  end

  // spi in/out ctrl
  always_comb begin
    spi_io_out_o[3:0] = '0;
    unique case (spm_i)
      `SPI_STD_SPI: spi_io_out_o[0] = s_std_mosi[tdtb_i];
      `SPI_DUAL_SPI: begin
        spi_io_out_o[0] = s_par_trg ? s_dual_io[tdtb_i][0] : s_std_mosi[0];  // 8b cmd trans
        spi_io_out_o[1] = s_par_trg ? s_dual_io[tdtb_i][1] : '0;
      end
      `SPI_QUAD_SPI: begin
        spi_io_out_o[0] = s_par_trg ? s_quad_io[tdtb_i][0] : s_std_mosi[0];  // 8b cmd trans
        spi_io_out_o[1] = s_par_trg ? s_quad_io[tdtb_i][1] : '0;
        spi_io_out_o[2] = s_par_trg ? s_quad_io[tdtb_i][2] : '0;
        spi_io_out_o[3] = s_par_trg ? s_quad_io[tdtb_i][3] : '0;
      end
      default:      spi_io_out_o[3:0] = '0;
    endcase
  end

  assign s_par_trg = s_ser_cnt_q == snm_i;
  always_comb begin
    s_ser_cnt_d = s_ser_cnt_q;
    if (s_st_fe_trg) begin
      s_ser_cnt_d = 1'b0;
    end else if (s_tran_done && ~s_par_trg) begin
      s_ser_cnt_d = s_ser_cnt_q + 1'b1;
    end
  end
  dffr #(4) u_ser_cnt_dffr (
      clk_i,
      rst_n_i,
      s_ser_cnt_d,
      s_ser_cnt_q
  );

  always_comb begin
    s_tran_cnt_d = s_tran_cnt_q;
    if (~s_tran_done && st_i) begin
      if ((~cpol_i & pos_edge_i) || (cpol_i & neg_edge_i)) begin
        s_tran_cnt_d = s_tran_cnt_q - 1'b1;
      end
    end else begin
      // s_tran_done can only mantain one cycle,
      // (s_ser_cnt_d == snm_i) mean s_par_trg need to set valid advance by one cycle
      if (spm_i != `SPI_STD_SPI && ~(s_ser_cnt_d == snm_i)) begin
        s_tran_cnt_d = 7'd8;
      end else begin
        unique case (tdtb_i)
          `SPI_TRANS_8_BITS: begin
            unique case (spm_i)
              `SPI_STD_SPI:  s_tran_cnt_d = 7'd8;
              `SPI_DUAL_SPI: s_tran_cnt_d = 7'd4;
              `SPI_QUAD_SPI: s_tran_cnt_d = 7'd2;
              default:       s_tran_cnt_d = 7'd8;
            endcase
          end
          `SPI_TRANS_16_BITS: begin
            unique case (spm_i)
              `SPI_STD_SPI:  s_tran_cnt_d = 7'd16;
              `SPI_DUAL_SPI: s_tran_cnt_d = 7'd8;
              `SPI_QUAD_SPI: s_tran_cnt_d = 7'd4;
              default:       s_tran_cnt_d = 7'd16;
            endcase
          end
          `SPI_TRANS_24_BITS: begin
            unique case (spm_i)
              `SPI_STD_SPI:  s_tran_cnt_d = 7'd24;
              `SPI_DUAL_SPI: s_tran_cnt_d = 7'd12;
              `SPI_QUAD_SPI: s_tran_cnt_d = 7'd6;
              default:       s_tran_cnt_d = 7'd24;
            endcase
          end
          `SPI_TRANS_32_BITS: begin
            unique case (spm_i)
              `SPI_STD_SPI:  s_tran_cnt_d = 7'd32;
              `SPI_DUAL_SPI: s_tran_cnt_d = 7'd16;
              `SPI_QUAD_SPI: s_tran_cnt_d = 7'd8;
              default:       s_tran_cnt_d = 7'd32;
            endcase
          end
          default: s_tran_cnt_d = 7'd8;
        endcase
      end
    end
  end
  dffrh #(`SPI_DATA_BIT_WIDTH + 2) u_tran_cnt_dffrh (
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
      s_st_re_trg
  );

  edge_det_sync_fe #(
      .DATA_WIDTH(1)
  ) u_st_fe (
      clk_i,
      rst_n_i,
      st_i,
      s_st_fe_trg
  );

  edge_det_sync_fe #(
      .DATA_WIDTH(1)
  ) u_trand_done_fe (
      clk_i,
      rst_n_i,
      s_tran_done,
      s_tran_done_fe_trg
  );

  // std spi tx
  assign tx_ready_o = s_st_re_trg || s_tran_done;
  for (genvar i = 1; i <= 4; i++) begin : SPI_TX_SHIFT_ONE_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (1)
    ) u_std_spi_tx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_LOGIC),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (tx_valid_i && tx_ready_o),
        .sft_en_i  (s_tx_trg),
        .ser_dat_i (1'b0),
        .par_data_i(tx_data_i[8*i-1:0]),
        .ser_dat_o (s_std_mosi[i-1]),
        .par_data_o()
    );
  end

  // dual spi tx
  for (genvar i = 1; i <= 4; i++) begin : SPI_TX_SHIFT_TWO_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (2)
    ) u_dual_spi_tx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_LOGIC),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (tx_valid_i && tx_ready_o),
        .sft_en_i  (s_tx_trg),
        .ser_dat_i ('0),
        .par_data_i(tx_data_i[8*i-1:0]),
        .ser_dat_o (s_dual_wr_data[i-1]),
        .par_data_o()
    );

    assign s_dual_io[i-1] = ~lsb_i ? s_dual_wr_data[i-1] : {s_dual_wr_data[i-1][0], s_dual_wr_data[i-1][1]};
  end

  // quad spi tx
  for (genvar i = 1; i <= 4; i++) begin : SPI_TX_SHIFT_FOUR_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (4)
    ) u_quad_spi_tx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_LOGIC),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (tx_valid_i && tx_ready_o),
        .sft_en_i  (s_tx_trg),
        .ser_dat_i ('0),
        .par_data_i(tx_data_i[8*i-1:0]),
        .ser_dat_o (s_quad_wr_data[i-1]),
        .par_data_o()
    );

    assign s_quad_io[i-1] = ~lsb_i ? s_quad_wr_data[i-1] :
    {s_quad_wr_data[i-1][0], s_quad_wr_data[i-1][1], s_quad_wr_data[i-1][2], s_quad_wr_data[i-1][3]};
  end

  // put data to rx fifo, delay tran done with one cycle
  assign rx_valid_o = rwm_i && (s_st_fe_trg || (s_trl_q < cal_i && s_tran_done_fe_trg));
  always_comb begin
    rx_data_o = '0;
    if (rx_valid_o && rx_ready_i) begin
      unique case (spm_i)
        `SPI_STD_SPI:  rx_data_o = s_std_rd_data[rdtb_i];
        `SPI_DUAL_SPI: rx_data_o = s_dual_rd_data[rdtb_i];
        `SPI_QUAD_SPI: rx_data_o = s_quad_rd_data[rdtb_i];
        default:       rx_data_o = '0;
      endcase
    end
  end

  // std spi rx
  for (genvar i = 1; i <= 4; i++) begin : SPI_RX_SHIFT_ONE_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (1)
    ) u_std_spi_rx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_SERI),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (1'b0),
        .sft_en_i  (s_rx_trg),
        .ser_dat_i (s_trl_q <= cal_i ? spi_io_in_i[1] : 1'b0),
        .par_data_i('0),
        .ser_dat_o (),
        .par_data_o(s_std_rd_data[i-1][8*i-1:0])
    );

    // fill unused bits
    if (i <= 3) begin
      assign s_std_rd_data[i-1][31:8*i] = '0;
    end
  end

  // dual spi rx
  for (genvar i = 1; i <= 4; i++) begin : SPI_RX_SHIFT_TWO_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (2)
    ) u_dual_spi_rx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_SERI),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (1'b0),
        .sft_en_i  (s_rx_trg),
        .ser_dat_i (s_trl_q <= cal_i ? spi_io_in_i[1:0] : '0),
        .par_data_i('0),
        .ser_dat_o (),
        .par_data_o(s_dual_rd_data[i-1][8*i-1:0])
    );

    // fill unused bits
    if (i <= 3) begin
      assign s_dual_rd_data[i-1][31:8*i] = '0;
    end
  end

  // quad spi rx
  for (genvar i = 1; i <= 4; i++) begin : SPI_RX_SHIFT_FOUR_BLOCK
    shift_reg #(
        .DATA_WIDTH(8 * i),
        .SHIFT_NUM (4)
    ) u_quad_spi_rx_shift_reg (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .type_i    (`SHIFT_REG_TYPE_SERI),
        .dir_i     ({1'b0, lsb_i}),
        .ld_en_i   (1'b0),
        .sft_en_i  (s_rx_trg),
        .ser_dat_i (s_trl_q <= cal_i ? spi_io_in_i[3:0] : '0),
        .par_data_i('0),
        .ser_dat_o (),
        .par_data_o(s_quad_rd_data[i-1][8*i-1:0])
    );

    // fill unused bits
    if (i <= 3) begin
      assign s_quad_rd_data[i-1][31:8*i] = '0;
    end
  end
endmodule