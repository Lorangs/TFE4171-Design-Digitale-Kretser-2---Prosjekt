//////////////////////////////////////////////////
// Title:   bind_hdlc
// Author:  Karianne Krokan Kragseth
// Date:    20.10.2017
//////////////////////////////////////////////////

module bind_hdlc ();

  bind test_hdlc assertions_hdlc u_assertion_bind(
    .ErrCntAssertions (uin_hdlc.ErrCntAssertions),
    .Clk              (uin_hdlc.Clk),
    .Rst              (uin_hdlc.Rst),
    .Rx               (uin_hdlc.Rx),
    .Rx_FlagDetect    (uin_hdlc.Rx_FlagDetect),
    .Rx_ValidFrame    (uin_hdlc.Rx_ValidFrame),
    .Rx_AbortDetect   (uin_hdlc.Rx_AbortDetect),
    .Rx_AbortSignal   (uin_hdlc.Rx_AbortSignal),
    .Rx_Overflow      (uin_hdlc.Rx_Overflow),
    .Rx_WrBuff        (uin_hdlc.Rx_WrBuff),
    
    .Rx_EoF           (uin_hdlc.Rx_EoF),
    .Rx_Ready         (uin_hdlc.Rx_Ready),
    .Rx_FrameError    (uin_hdlc.Rx_Frame_Error),
    .Rx_Drop          (uin_hdlc.Rx_Drop),
    .Rx_Frame_size    (uin_hdlc.Rx_FrameSize),
    .Rx_FCSerr        (uin_hdlc.Rx_FCSerr),

    .Tx               (uin_hdlc.Tx),
    .Tx_ValidFrame    (uin_hdlc.Tx_ValidFrame),
    .Tx_AbortFrame    (uin_hdlc.Tx_AbortFrame),
    .Tx_AbortedTrans  (uin_hdlc.Tx_AbortedTrans),
    .Tx_FCSDone       (uin_hdlc.Tx_FCSDone),
    .Tx_WriteFCS      (uin_hdlc.Tx_WriteFCS)
  );

endmodule
