// Copyright (c) 2023 Beijing Institute of Open Source Chip
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SPI_TEST_SV
`define INC_SPI_TEST_SV

`include "apb4_master.sv"
`include "spi_define.sv"

class SPITest extends APB4Master;
  string                                       name;
  int                                          wr_val;
  int                                          wr_num;
  bit                    [`SPI_DATA_WIDTH-1:0] wr_que [$];
  virtual apb4_if.master                       apb4;
  virtual spi_if.tb                            spi;

  extern function new(string name = "spi_test", virtual apb4_if.master apb4, virtual spi_if.tb spi);
  extern task automatic test_reset_reg();
  extern task automatic test_wr_rd_reg(input bit [31:0] run_times = 1000);
  extern task automatic w25q_std_spi_wr_rd_test();
  extern task automatic w25q_dual_spi_wr_rd_test();
  extern task automatic w25q_quad_spi_wr_rd_test();
  extern task automatic test_irq(input bit [31:0] run_times = 10);
endclass

function SPITest::new(string name, virtual apb4_if.master apb4, virtual spi_if.tb spi);
  super.new("apb4_master", apb4);
  this.name   = name;
  this.wr_val = 0;
  this.wr_num = 0;
  this.wr_que = {};
  this.apb4   = apb4;
  this.spi    = spi;
endfunction

task automatic SPITest::test_reset_reg();
  super.test_reset_reg();
  // verilog_format: off
  this.rd_check(`SPI_CTRL1_ADDR, "CTRL1 REG", 32'b0 & {`SPI_CTRL1_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`SPI_CTRL2_ADDR, "CTRL2 REG", 32'b0 & {`SPI_CTRL2_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`SPI_DIV_ADDR, "DIV REG", 32'b0 & {`SPI_DIV_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`SPI_CAL_ADDR, "CAL REG", 32'b0 & {`SPI_CAL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic SPITest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  super.test_wr_rd_reg();
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
      this.wr_rd_check(`SPI_CTRL1_ADDR, "CTRL1 REG", $random & {`SPI_CTRL1_WIDTH{1'b1}}, Helper::EQUL);
      this.wr_rd_check(`SPI_DIV_ADDR, "DIV REG", $random & {`SPI_DIV_WIDTH{1'b1}}, Helper::EQUL);
      this.wr_rd_check(`SPI_CAL_ADDR, "CAL REG", $random & {`SPI_CAL_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic SPITest::w25q_std_spi_wr_rd_test();
  $display("=== [test std spi wr rd] ===");
  this.wr_que = {};
  this.wr_num = 32;

  for (int i = 0; i < 256 / 4; i++) begin
    this.wr_que.push_back($random);
    if (i < 3) begin
      $display("wr_que[%d]:%h", i, this.wr_que[i]);
    end
  end

  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_DIV_ADDR, 32'd0 & {`SPI_DIV_WIDTH{1'b1}});
  this.write(`SPI_CTRL1_ADDR, 32'b00_0000_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (100) @(posedge this.apb4.pclk);

  // write enable
  this.write(`SPI_TXR_ADDR, 32'h06);
  this.write(`SPI_CTRL2_ADDR, 32'b0010_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (50) @(posedge this.apb4.pclk);
  this.write(`SPI_CTRL1_ADDR, 32'b11_1100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 32'h0200_0000);  // write page program
  // wr data
  foreach (this.wr_que[i]) begin
    if (i < this.wr_num) begin
      this.write(`SPI_TXR_ADDR, this.wr_que[i]);
    end else begin
      break;
    end
  end

  this.write(`SPI_CAL_ADDR, 32'd0);
  this.write(`SPI_TRL_ADDR, this.wr_num + 1);
  this.write(`SPI_CTRL2_ADDR, 32'b0010_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (4000) @(posedge this.apb4.pclk);  // for delay tpp time

  // rd data
  this.write(`SPI_TXR_ADDR, 32'h0300_0000);  // read data
  // this.write(`SPI_TXR_ADDR, 32'd0);
  this.write(`SPI_CAL_ADDR, this.wr_num);
  this.write(`SPI_TRL_ADDR, this.wr_num + 1);
  this.write(`SPI_CTRL2_ADDR, 32'b0011_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (400 * this.wr_num) @(posedge this.apb4.pclk);

  for (int i = 0; i < this.wr_num; i++) begin
    this.read(`SPI_RXR_ADDR);
    if (super.rd_data != this.wr_que[i]) begin
      $display("%t unmatch rd data: %h expr data: %h", $time, super.rd_data, this.wr_que[i]);
    end
  end
endtask

task automatic SPITest::w25q_dual_spi_wr_rd_test();
  $display("=== [test dual spi wr rd] ===");
  $display("=== [cmd: ser addr: ser data: par] ===");
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_DIV_ADDR, 32'd0 & {`SPI_DIV_WIDTH{1'b1}});
  this.write(`SPI_CTRL1_ADDR, 32'b01_00000000_0011_1100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0101_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 32'h3B);  // cmd
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr0
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr1
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr2
  this.write(`SPI_TXR_ADDR, 32'h0);  // dummy
  this.write(`SPI_CAL_ADDR, 2);
  this.write(`SPI_TRL_ADDR, 5 + 2);
  this.write(`SPI_CTRL2_ADDR, 32'b0101_0000_0001_1_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200 * 4) @(posedge this.apb4.pclk);
  for (int i = 0; i < 3; i++) begin
    this.read(`SPI_RXR_ADDR);
    $display("%t rd data: %h", $time, super.rd_data);
  end

  $display("=== [cmd: ser addr: par data: par] ===");
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_DIV_ADDR, 32'd0 & {`SPI_DIV_WIDTH{1'b1}});
  this.write(`SPI_CTRL1_ADDR, 32'b01_00000000_0011_1100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 32'hBB);  // cmd
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr+dummy
  this.write(`SPI_CAL_ADDR, 2);
  this.write(`SPI_TRL_ADDR, 2 + 2);
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_1_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200 * 4) @(posedge this.apb4.pclk);
  for (int i = 0; i < 3; i++) begin
    this.read(`SPI_RXR_ADDR);
    $display("%t rd data: %h", $time, super.rd_data);
  end
endtask

task automatic SPITest::w25q_quad_spi_wr_rd_test();
  $display("=== [test quad spi wr rd] ===");
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_DIV_ADDR, 32'd0 & {`SPI_DIV_WIDTH{1'b1}});
  this.write(`SPI_CTRL1_ADDR, 32'b00_0000_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200) @(posedge this.apb4.pclk);
  this.write(`SPI_TXR_ADDR, 32'h06);
  this.write(`SPI_CAL_ADDR, 0);
  this.write(`SPI_TRL_ADDR, 0);
  this.write(`SPI_CTRL2_ADDR, 32'b0010_1100 & {`SPI_CTRL2_WIDTH{1'b1}});  //write enable
  repeat (200) @(posedge this.apb4.pclk);

  this.write(`SPI_CTRL1_ADDR, 32'b0001_0100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200) @(posedge this.apb4.pclk);
  this.write(`SPI_TXR_ADDR, 32'h3102);
  this.write(`SPI_CAL_ADDR, 0);
  this.write(`SPI_TRL_ADDR, 0);
  this.write(`SPI_CTRL2_ADDR, 32'b0010_1100 & {`SPI_CTRL2_WIDTH{1'b1}});  //write qe = 1
  repeat (200) @(posedge this.apb4.pclk);

  this.write(`SPI_CTRL1_ADDR, 32'b00_0000_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200) @(posedge this.apb4.pclk);
  this.write(`SPI_TXR_ADDR, 32'h06);
  this.write(`SPI_CAL_ADDR, 0);
  this.write(`SPI_TRL_ADDR, 0);
  this.write(`SPI_CTRL2_ADDR, 32'b0010_1100 & {`SPI_CTRL2_WIDTH{1'b1}});  //write enable
  repeat (200) @(posedge this.apb4.pclk);

  $display("=== [test quad wr] ===");
  this.wr_que = {};
  this.wr_num = 32;

  for (int i = 0; i < 256 / 4; i++) begin
    this.wr_que.push_back($random);
    if (i < 3) begin
      $display("wr_que[%d]:%h", i, this.wr_que[i]);
    end
  end

  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_CTRL1_ADDR, 32'b10_00000000_0011_1100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0100_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 32'h32);  // cmd
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr[23:16]
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr[15:8]
  this.write(`SPI_TXR_ADDR, 32'h90);  // addr[7:0]
  // wr data
  foreach (this.wr_que[i]) begin
    if (i < this.wr_num) begin
      this.write(`SPI_TXR_ADDR, this.wr_que[i]);
    end else begin
      break;
    end
  end

  this.write(`SPI_CAL_ADDR, '0);  // no use in wr oper
  this.write(`SPI_TRL_ADDR, this.wr_num + 4);
  this.write(`SPI_CTRL2_ADDR, 32'b0100_0000_0001_0_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  $display("%t", $time);
  repeat (4000) @(posedge this.apb4.pclk);  // for delay tpp time

  $display("=== [cmd: ser addr: par data: par] ===");
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_CTRL1_ADDR, 32'b10_00000000_0011_1100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0101_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 32'h6B);  // cmd
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr[23:16]
  this.write(`SPI_TXR_ADDR, 32'h0);  // addr[15:8]
  this.write(`SPI_TXR_ADDR, 32'h90);  // addr[7:0]
  this.write(`SPI_TXR_ADDR, 32'h0);  // dummy
  this.write(`SPI_CAL_ADDR, 2);
  this.write(`SPI_TRL_ADDR, 5 + 2);
  this.write(`SPI_CTRL2_ADDR, 32'b0101_0000_0001_1_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200 * 4) @(posedge this.apb4.pclk);
  for (int i = 0; i < 3; i++) begin
    this.read(`SPI_RXR_ADDR);
    $display("%t rd data: %h", $time, super.rd_data);
  end

  $display("=== [cmd: ser addr: par data: par] ===");
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_CTRL1_ADDR, 32'b10_00000000_0001_0100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 16'hEB);  // cmd
  this.write(`SPI_TXR_ADDR, 16'h0);  // addr[23:8]
  this.write(`SPI_TXR_ADDR, 16'h0);  // addr[7:0] + M[7:0]
  this.write(`SPI_TXR_ADDR, 16'h0);  // dummy
  this.write(`SPI_CAL_ADDR, 2);
  this.write(`SPI_TRL_ADDR, 4 + 2);
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_1_1100 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200 * 4) @(posedge this.apb4.pclk);
  for (int i = 0; i < 3; i++) begin
    this.read(`SPI_RXR_ADDR);
    $display("%t rd data: %h", $time, super.rd_data);
  end
endtask

task automatic SPITest::test_irq(input bit [31:0] run_times = 10);
  super.test_irq();
  repeat (200 * 3) @(posedge this.apb4.pclk);
  this.write(`SPI_CTRL1_ADDR, 32'b10_00000_00011_01_0100_1000 & {`SPI_CTRL1_WIDTH{1'b1}});
  this.write(`SPI_CTRL2_ADDR, 32'b0010_0000 & {`SPI_CTRL2_WIDTH{1'b1}});  // clear que
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_0_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  this.write(`SPI_TXR_ADDR, 16'hEB);  // cmd
  this.write(`SPI_TXR_ADDR, 16'h0);  // addr[23:8]
  this.write(`SPI_TXR_ADDR, 16'h0);  // addr[7:0] + M[7:0]
  this.write(`SPI_TXR_ADDR, 16'h0);  // dummy
  this.write(`SPI_CAL_ADDR, 2);
  this.write(`SPI_TRL_ADDR, 4 + 2);
  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_1_1111 & {`SPI_CTRL2_WIDTH{1'b1}});
  repeat (200 * 4) @(posedge this.apb4.pclk);
  // for (int i = 0; i < 3; i++) begin
  //   this.read(`SPI_RXR_ADDR);
  //   $display("%t rd data: %h", $time, super.rd_data);
  // end

  this.write(`SPI_CTRL2_ADDR, 32'b0001_0000_0001_1_0100 & {`SPI_CTRL2_WIDTH{1'b1}});
  for (int i = 0; i < 2; i++) begin
    this.read(`SPI_STAT_ADDR);
    $display("%t stat reg: %h", $time, super.rd_data);
  end
endtask
`endif
