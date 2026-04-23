//////////////////////////////////////////////////
// Title:   assertions_hdlc
// Author:  Lorang Strand & Walter Brynhilsen
// Date:    23 April 2026
//////////////////////////////////////////////////

/* The assertions_hdlc module is a test module containing the concurrent
   assertions. It is used by binding the signals of assertions_hdlc to the
   corresponding signals in the test_hdlc testbench. This is already done in
   bind_hdlc.sv 

   For this exercise you will write concurrent assertions for the Rx module:
   - Verify that Rx_FlagDetect is asserted two cycles after a flag is received
   - Verify that Rx_AbortSignal is asserted after receiving an abort flag
*/

module assertions_hdlc (
  output int   ErrCntAssertions,
  input  logic Clk,
  input  logic Rst,
  input  logic Rx,
  input  logic Rx_FlagDetect,
  input  logic Rx_ValidFrame,
  input  logic Rx_AbortDetect,
  input  logic Rx_AbortSignal,
  input  logic Rx_Overflow,
  input  logic Rx_WrBuff,
  input  logic Rx_EoF,
  input  logic Rx_Ready,
  input  logic Rx_FrameError,
  input  logic Rx_Drop,
  input  logic [7:0] Rx_Frame_size,
  input  logic Rx_FCSerr,
  input  logic Tx,
  input  logic Tx_ValidFrame,
  input  logic Tx_AbortFrame,
  input  logic Tx_AbortedTrans,
  input  logic Tx_FCSDone,
  input  logic Tx_WriteFCS
);

  initial begin
    ErrCntAssertions  =  0;
  end


  // start and end of frame pattern: 8'h7E = 8'b01111110
  sequence start_end_pattern;
    (Rx == 'h7E);
  endsequence;

  // Check if flag sequence is detected
  property start_end_detected;
    @(posedge Clk) start_end_pattern |-> ##2 Rx_FlagDetect;
  endproperty

  start_end_detected_assert : assert property (start_end_detected) begin
    $display("PASS: Flag detect");
  end else begin 
    $error("Flag sequence did not generate FlagDetect"); 
    ErrCntAssertions++; 
  end


  // Abort pattern: 8'hFE = 8'b11111110
  sequence rx_abort_pattern;
    (Rx == 'hFE);
  endsequence;

  // Check if abort pattern is detected and abort signal is generated
  property rx_abort_detected;
    @(posedge Clk) rx_abort_pattern |-> Rx_AbortDetect;
  endproperty
  
  rx_abort_detected_assert : assert property (rx_abort_detected) begin
    $display("PASS: Abort signal");
  end else begin 
    $error("AbortSignal did not go high after AbortDetect during validframe"); 
    ErrCntAssertions++; 
  end

 

 // Idle pattern: 8'b11111111
  sequence rx_idle_pattern;
    (Rx == 'hFF);
  endsequence;

  property rx_idle_detected;
    rx_idle_pattern |-> !Rx_ValidFrame;
  endproperty;

  rx_idle_detected_assert:  assert property(@(posedge Clk) disable iff(Rx_AbortDetect || !Rst) rx_idle_detected) else begin
    $error("ERROR: Rx did not correctly generate idle pattern.");
    ErrCntAssertions++;
  end
  
  property tx_idle_pattern;
    $fell(Tx_ValidFrame) and !Tx_AbortedTrans |-> ##9 Tx;
  endproperty;

  tx_idle_assertion:  assert property(@(posedge Clk) disable iff(!Rst) tx_idle_pattern) else begin
    $error("ERROR: Tx did not generate idle pattern properly");
    ErrCntAssertions++;
  end

  // Verifiserer Tx abort pattern (spec 8) - only when mid-transmission
  property tx_abort_pattern;
    $rose(Tx_AbortedTrans) and $past(Tx_ValidFrame) |-> ##[1:2] (!Tx ##1 Tx[*7]);
  endproperty;

  tx_abort_assertion: assert property(@(posedge Clk) disable iff(!Rst) tx_abort_pattern) else begin
    $error("ERROR: Tx did not generate abort pattern after Tx_AbortedTrans");
    ErrCntAssertions++;
  end

endmodule
