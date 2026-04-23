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


  // start and end of frame pattern: 8'h7E = 8'b01111110 - Spec 12
  sequence start_end_pattern;
    !Rx ##1 Rx [*6] ##1 !Rx;
  endsequence;

  // Check if flag sequence is detected
  property start_end_detected;
    @(posedge Clk) start_end_pattern |-> ##2 Rx_FlagDetect;
  endproperty

  start_end_detected_assert : assert property (start_end_detected) else begin 
    $error("Flag sequence did not generate FlagDetect"); 
    ErrCntAssertions++; 
  end


  // Abort pattern: 8'hFE = 8'b11111110 - Spec 10
  sequence rx_abort_pattern;
    !Rx ##1 Rx [*7];
  endsequence;

  // Check if abort pattern is detected and abort signal is generated
  property rx_abort_detected;
    Rx_ValidFrame [*8] and rx_abort_pattern |-> ##2 Rx_AbortDetect |-> ##1 Rx_AbortSignal;
  endproperty
  
  rx_abort_detected_assert : assert property(@(posedge Clk) rx_abort_detected) else begin 
    $error("AbortSignal did not go high after AbortDetect during validframe"); 
    ErrCntAssertions++; 
  end


 // Idle pattern: 8'b11111111 - Spec 7
  sequence rx_idle_pattern;
    Rx [*8];
  endsequence;

  property rx_idle_detected;
    rx_idle_pattern |-> ##1 !Rx_ValidFrame;
  endproperty;

  rx_idle_detected_assert:  assert property(@(posedge Clk) disable iff(Rx_AbortDetect || !Rst) rx_idle_detected) else begin
    $error("ERROR: Rx did not correctly generate idle pattern.");
    ErrCntAssertions++;
  end

  sequence tx_idle_pattern;
    Tx [*8];
  endsequence;
  
  // wait 9 cycles after Tx_ValidFrame 
  property tx_idle_generation;
    $fell(Tx_ValidFrame) and !Tx_AbortedTrans |-> ##9 tx_idle_pattern;
  endproperty;

  tx_idle_assertion:  assert property(@(posedge Clk) disable iff(!Rst) tx_idle_generation) else begin
    $error("ERROR: Tx did not generate idle pattern properly");
    ErrCntAssertions++;
  end

  sequence tx_abort_pattern;
    !Tx ##1 Tx [*7];
  endsequence;

  // Verifiserer Tx abort pattern (spec 8) - only when mid-transmission
  property tx_abort_detected;
    @(posedge Clk) disable iff(!Rst)
    $rose(Tx_AbortFrame) ##1 $fell(Tx_AbortFrame) |-> ##[0:128] tx_abort_pattern;
    //$rose(Tx_AbortedTrans) |-> ##2 !Tx ##1 Tx [*7];
    //Rx_ValidFrame [*8] and rx_abort_pattern |-> ##2 Rx_AbortDetect |-> ##1 Rx_AbortSignal;
    //$rose(Tx_AbortedTrans |-> ##1 tx_abort_pattern;
    //Tx_AbortFrame |-> ##4 tx_abort_pattern;
  endproperty;

  tx_abort_assertion: assert property(tx_abort_detected) else begin
    $error("ERROR: Tx did not generate abort pattern after Tx_AbortedTrans");
    ErrCntAssertions++;
  end

  property tx_abort_trans_generation;
    @(posedge Clk) disable iff(!Rst) 
    $rose(Tx_AbortFrame) ##1 $fell(Tx_AbortFrame) |-> ##1 $rose(Tx_AbortedTrans);
  endproperty
  
  tx_abort_trans_assertion: assert property(tx_abort_trans_generation) else begin
    $error("ERROR: Tx_AbortTrans did not go high one clk cycle after Tx_AbortFrame.");
    ErrCntAssertions++;
  end
endmodule
