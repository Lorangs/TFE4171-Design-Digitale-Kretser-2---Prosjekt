//////////////////////////////////////////////////
// Title:   assertions_hdlc
// Author:  
// Date:    
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
  input  logic Rx_WrBuff
);

  initial begin
    ErrCntAssertions  =  0;
  end

  /*******************************************
   *  Verify correct Rx_FlagDetect behavior  *
   *******************************************/
  // start and end of frame pattern: 8'h7E = 8'b01111110
  sequence start_end_pattern;
    (Rx == 'h7E);
  endsequence;

  // Check if flag sequence is detected
  property start_end_detected;
    @(posedge Clk) start_end_pattern |-> ##2 Rx_FlagDetect;
  endproperty

  start_end_detected_Assert : assert property (start_end_detected) begin
    $display("PASS: Flag detect");
  end else begin 
    $error("Flag sequence did not generate FlagDetect"); 
    ErrCntAssertions++; 
  end

  /********************************************
   *  Verify correct Rx_AbortSignal behavior  *
   ********************************************/
  // Abbort pattern: 8'hFE = 8'b11111110
  sequence abbort_pattern;
    (Rx == 'hFE);
  endsequence;

  // Check if abort pattern is detected and abort signal is generated
  property abbort_detected;
    @(posedge Clk) abbort_pattern |-> Rx_AbortDetect;
  endproperty:
  
  abbort_detected_assert: assert property (abbort_detected) begin
    $display("PASS: Abort signal");
  end else begin 
    $error("AbortSignal did not go high after AbortDetect during validframe"); 
    ErrCntAssertions++; 
  end

  /*********************************************
   * Verify removal of inserted zeros when Rx_ValidFrame is high *
    *********************************************/

  

  /*********************************************
   * Verify correct calculation of CRC
  *********************************************/

endmodule
