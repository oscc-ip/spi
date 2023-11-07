`timescale 1ns / 1ps

module spi_clkgen_tb ();
  logic rst_n_i, clk_i;
  logic spi_clk_o, spi_rise_o, spi_fall_o;
  logic clk_en_i;
  
  always #5.000 clk_i <= ~clk_i;

  initial begin
    clk_i   = 1'b0;
    rst_n_i = 1'b0;
    clk_en_i = 1'b0;
    // wait for a while to release reset signal
    // repeat (4096) @(posedge clk_i);
    repeat (40) @(posedge clk_i);
    #100 rst_n_i = 1;
    #200 clk_en_i = 1'b1;
  end

  initial begin
    if ($test$plusargs("dump_fst_wave")) begin
      $dumpfile("sim.wave");
      $dumpvars(0, spi_clkgen_tb);
    end else if ($test$plusargs("default_args")) begin
      $display("=========sim default args===========");
    end
    $display("sim 11000ns");
    #11000 $finish;
  end

  spi_clkgen u_spi_clkgen (
      clk_i,
      rst_n_i,
      clk_en_i,
      8'd3,
      1'b1,
      1'b1,
      spi_clk_o,
      spi_rise_o,
      spi_fall_o
  );

endmodule
