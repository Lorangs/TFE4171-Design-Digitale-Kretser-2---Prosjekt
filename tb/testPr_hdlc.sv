//////////////////////////////////////////////////
// Title:   testPr_hdlc
// Author:  Lorang Strand and Walter Brynhilsen
// Date:    21 April 2026
//////////////////////////////////////////////////

// Tx Status Control Register
`define Tx_SC_ADDR          3'h0
/*  Tx_SC [7:0] index:
    0 (LSB) -> Tx_Done
    1       -> Tx_Enable
    2       -> Tx_AbortFrame
    3       -> Tx_AbortTrans
    4       -> Tx_Full
    5-7     -> N/A    
*/
`define Tx_SC_DONE          0
`define Tx_SC_EN            1
`define Tx_SC_ABORT_FRAME   2
`define Tx_SC_ABORT_TRANS   3
`define Tx_SC_FULL          4

`define Tx_BUFFER_ADDR      3'h1
/*  Tx_Buff [7:0] index:
    0-7     -> Tx Data Byte
    Reset:  8'h00
    R/W:    Write Only
*/

// Rx Status Control Register
`define Rx_SC_ADDR          3'h2
/* Rx_SC [7:0] index:
    0 (LSB) -> Rx_Ready
    1       -> Rx_Drop
    2       -> Rx_FrameError
    3       -> Rx_AbortSignal
    4       -> Rx_Overflow
    5       -> RxFCSen
    6-7     -> N/A    
*/
`define Rx_SC_READY         0
`define Rx_SC_DROP          1
`define Rx_SC_FRAME_ERR     2
`define Rx_SC_ABORT_SIG     3
`define Rx_SC_OVERFLOW      4
`define Rx_SC_FCS_EN        5


`define Rx_BUFFER_ADDR      3'h3
/* Rx_Buff [7:0] index:
    0-7     -> Rx Data Byte
    Reset:  8'h00
    R/W:    Read Only
*/

`define Rx_LEN_ADDR         3'h4
/* Rx_Len [7:0] index:
    0-7     -> Rx Frame Length
    Reset:  8'h00
    R/W:    Read Only
*/

`define BUFFER_SIZE         128  // Size of Rx_Buff and Tx_Buff in bytes
`define NUM_RANDOM_TESTS    10   // Number of random tests to perform for each test case in the test program

`define START_END_FLAG      8'b01111110
`define ABORT_FLAG          8'b11111110

`define WAIT_TIME_ns        1000ns // Wait time in nano seconds


program testPr_hdlc(
  in_hdlc uin_hdlc
);

  int TbErrorCnt;

  initial begin
    $display("------------------------------------");
    $display("Event %t: Starting Test Program", $time);
    $display("------------------------------------");

    Init();

    int randomseed = 0; 
    if (!$value$plusargs("seed=%d", randomseed)) begin
      randomseed = 12345;  // Default fallback
    end
    $srandom(randomseed); // Use the captured or default seed as a basis for a new randomseed
    randomseed = $urandom; // Capture the random seed used for this run
    $display("Random seed for this run: %0d", randomseed);

    // Generate stimulus and verify response for different size frames
    int Size;
    for (int i = 0; i < `NUM_RANDOM_TESTS; i++) begin
      if (i == 0)
        Size = 1;                               // minimum size frame
      else if (i == `NUM_RANDOM_TESTS - 1)
        Size = `BUFFER_SIZE;                    // maximum size frame
      else
        Size = $urandom_range(1, `BUFFER_SIZE); // random size frame

        // Test behaviour:
        VerifyNormalReceive();
        #`WAIT_TIME_ns;
        VerifyAbortReceive();
        #`WAIT_TIME_ns;
        VerifyOverflowReceive();
        #`WAIT_TIME_ns;
        VerifyDroppedReceive();
        #`WAIT_TIME_ns;
        VerifyRxLENReceive();
        #`WAIT_TIME_ns;
        VerifyFCSerrReceive();
        #`WAIT_TIME_ns;
        VerifyNonByteAlignedReceive();
        #`WAIT_TIME_ns;
        VerfiyNormalTransmit();
        #`WAIT_TIME_ns;
        VerifyAbortTransmit();
        #`WAIT_TIME_ns;
    

    $display("------------------------------------");
    $display("Event %t: Finishing Test Program", $time);
    $display("------------------------------------");
    $stop;
  end

  final begin
    $display("------------------------------------");
    $display("* \tAssertion Errors: %0d\t  *", TbErrorCnt + uin_hdlc.ErrCntAssertions);
    $display("------------------------------------");
  end

  task Init();
    uin_hdlc.Clk         =   1'b0;
    uin_hdlc.Rst         =   1'b0;
    uin_hdlc.Address     = 3'b000;
    uin_hdlc.WriteEnable =   1'b0;
    uin_hdlc.ReadEnable  =   1'b0;
    uin_hdlc.DataIn      =     '0;
    uin_hdlc.TxEN        =   1'b1;
    uin_hdlc.Rx          =   1'b1;
    uin_hdlc.RxEN        =   1'b1;

    TbErrorCnt = 0;

    #1000ns;
    uin_hdlc.Rst         =   1'b1;
  endtask

  task WriteAddress(input logic [2:0] Address ,input logic [7:0] Data);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Address     = Address;
    uin_hdlc.WriteEnable = 1'b1;
    uin_hdlc.DataIn      = Data;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.WriteEnable = 1'b0;
  endtask

  task ReadAddress(input logic [2:0] Address ,output logic [7:0] Data);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Address    = Address;
    uin_hdlc.ReadEnable = 1'b1;
    #100ns;
    Data                = uin_hdlc.DataOut;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.ReadEnable = 1'b0;
  endtask


  /* ------------------
   Stimuli tasks 
   ----------------- */
  task InsertFlagOrAbort(int flag);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b0;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    if(flag)
      uin_hdlc.Rx = 1'b0;
    else
      uin_hdlc.Rx = 1'b1;
  endtask

  task MakeRxStimulus(logic [127:0][7:0] Data, int Size);
    logic [4:0] PrevData;
    PrevData = '0;
    for (int i = 0; i < Size; i++) begin
      for (int j = 0; j < 8; j++) begin
        if(&PrevData) begin
          @(posedge uin_hdlc.Clk);
          uin_hdlc.Rx = 1'b0;
          PrevData = PrevData >> 1;
          PrevData[4] = 1'b0;
        end

        @(posedge uin_hdlc.Clk);
        uin_hdlc.Rx = Data[i][j];

        PrevData = PrevData >> 1;
        PrevData[4] = Data[i][j];
      end
    end
  endtask

  task Receive(int Size, int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop, int SkipRead);
    logic [127:0][7:0] ReceiveData;
    logic       [15:0] FCSBytes;
    logic   [2:0][7:0] OverflowData;
    string msg;
    if(Abort)
      msg = "- Abort";
    else if(FCSerr)
      msg = "- FCS error";
    else if(NonByteAligned)
      msg = "- Non-byte aligned";
    else if(Overflow)
      msg = "- Overflow";
    else if(Drop)
      msg = "- Drop";
    else if(SkipRead)
      msg = "- Skip read";
    else
      msg = "- Normal";
    $display("------------------------------------------");
    $display("Event %t: Receiving message %s", $time, msg);
    $display("------------------------------------------");

    for (int i = 0; i < Size; i++) begin
      ReceiveData[i] = $urandom;
    end

    //Calculate FCS bits;
    GenerateFCSBytes(ReceiveData, Size, FCSBytes);
    ReceiveData[Size]   = FCSBytes[7:0];
    ReceiveData[Size+1] = FCSBytes[15:8];

    //Enable FCS. 
    if(!Overflow && !NonByteAligned)
      WriteAddress(`Rx_SC_ADDR, 8'h20);   // write to Rx_sc status control bit at address 'h2
    else
      WriteAddress(`Rx_SC_ADDR, 8'h00);   // write to Rx_sc status control bit at address 'h2

    //Generate stimulus
    InsertFlagOrAbort(1);
    
    MakeRxStimulus(ReceiveData, Size + 2);
    
    if(Overflow) begin
      OverflowData[0] = 8'h44;
      OverflowData[1] = 8'hBB;
      OverflowData[2] = 8'hCC;
      MakeRxStimulus(OverflowData, 3);
    end

    if(Abort) begin
      InsertFlagOrAbort(0);
    end else begin
      InsertFlagOrAbort(1);
    end

    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;

    repeat(8)
      @(posedge uin_hdlc.Clk);

    if(Abort)
      VerifyAbortReceive(ReceiveData, Size);
    else if(Overflow)
      VerifyOverflowReceive(ReceiveData, Size);
    else if(!SkipRead)
      VerifyNormalReceive(ReceiveData, Size);

    #`WAIT_TIME_ns;
  endtask

  task Transmit(int Size, int Abort, output logic [127:0][7:0] WrittenData, output logic [127:0][7:0] TransmittedData, output logic [15:0] FCSBytes);
    $display("----------------------------------------------");
    $display("Event %t: Transmitting message (Size=%0d, Abort=%0d)", $time, Size, Abort);
    $display("----------------------------------------------");

    for (int i = 0; i < Size; i++)
      WrittenData[i] = $urandom;
    WrittenData[Size]     = '0;
    WrittenData[Size + 1] = '0;

    GenerateFCSBytes(WrittenData, Size, FCSBytes);

    for (int i = 0; i < Size; i++) begin
      @(posedge uin_hdlc.Clk);
      WriteAddress(`Tx_BUFFER_ADDR, WrittenData[i]);
    end

    VerifyTxFull(Size);

    //Start transmission and read Tx output
    WriteAddress(`Tx_SC_ADDR, 8'h02);

    fork
      ReadTransmittedData(Size+2, Abort, TransmittedData);
      WaitAndVerifyTxDone(Size, Abort);
    join

    repeat(8)
      @(posedge uin_hdlc.Clk);
  endtask

  task GenerateFCSBytes(logic [127:0][7:0] Data, int Size, output logic[15:0] FCSBytes);
    logic [23:0] CheckReg;
    CheckReg[15:8]  = Data[1];
    CheckReg[7:0]   = Data[0];
    for(int i = 2; i < Size+2; i++) begin
      CheckReg[23:16] = Data[i];
      for(int j = 0; j < 8; j++) begin
        if(CheckReg[0]) begin
          CheckReg[0]    = CheckReg[0] ^ 1;
          CheckReg[1]    = CheckReg[1] ^ 1;
          CheckReg[13:2] = CheckReg[13:2];
          CheckReg[14]   = CheckReg[14] ^ 1;
          CheckReg[15]   = CheckReg[15];
          CheckReg[16]   = CheckReg[16] ^1;
        end
        CheckReg = CheckReg >> 1;
      end
    end
    FCSBytes = CheckReg;
  endtask

  /* ------------------------- 
  Main verification tasks 
  ------------------------- */
  task VerifyAbortReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;

    ReadAddress(`Rx_SC_ADDR, RxStatusControl); 

    assert(RxStatusControl[`Rx_SC_READY] == 0) else begin 
      $error("Rx_Ready should be 0 when an abort is received");
      TbErrorCnt++;
    end 

    assert(RxStatusControl[`Rx_SC_FRAME_ERR] == 0) else begin 
      $error("Rx_FrameError should be 0 when an abort is received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_ABORT_SIG]== 1) else begin 
      $error("Rx_AbortSignal should be 1 when an abort is received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_OVERFLOW] == 0) else begin 
      $error("Rx_Overflow should be 0 when an abort is received");
      TbErrorCnt++;
    end

    // assert that all bytes in Rx_Buff is set to zero when Rx_AbortSignal is set
    for (int i = 0; i < Size; i++) begin 
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);
      assert(ReadData == 'h00) else begin 
        $error("Rx_Data should be set to zero when an abort is received. Rx_Data[%h] is set to %h", i, ReadData);
      end 
      @(posedge uin_hdlc.Clk);
    end 
  endtask

  // VerifyNormalReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyNormalReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_Ready);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);  

    // assert size is smaller than buffer size when receiving normal package
    assert(Size <= `BUFFER_SIZE-1) else begin 
      $error("Recieved size is too large (%h). Overflow bit should be high.", Size);
      TbErrorCnt++;
    end 

    assert(RxStatusControl[`Rx_SC_READY] == 1) else begin 
      $error("Rx_Ready should be 1 when a frame is received");
      TbErrorCnt++;
    end 

    assert(RxStatusControl[`Rx_SC_FRAME_ERR] == 0) else begin 
      $error("Rx_FrameError should be 0 when a normal frame is received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_ABORT_SIG] == 0) else begin 
      $error("Rx_AbortSignal should be 0 when a normal frame is received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_OVERFLOW] == 0) else begin 
      $error("Rx_Overflow should be 0 when a normal frame is received");
      TbErrorCnt++;
    end

    // assert read data match that of Rx_buff
    for (int i = 0; i < Size; i++) begin
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);       
      assert(ReadData == data[i]) else begin 
        $error("  be %h, but is %h", data[i], ReadData);
        TbErrorCnt++;
      end
      @(posedge uin_hdlc.Clk);
    end

  endtask

  // VerifyNormalReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyOverflowReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_Ready);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    assert(Size >= `BUFFER_SIZE-2) else begin 
      $error("Overflow bit is high, but Size (%d) is smaller than buffer size.", Size);
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_READY] == 1) else begin 
      $error("Rx_Ready should be high when an overflow is recieved.");
      TbErrorCnt++;
    end 

    assert(RxStatusControl[`Rx_SC_FRAME_ERR] == 0) else begin 
      $error("Rx_FrameError should be zero when an overflow is received.");
      TbErrorCnt++;
    end 
 
    assert(RxStatusControl[`Rx_SC_ABORT_SIG] == 0) else begin 
      $error("Rx_AbortSignal should be zero when an overflow is received.");
      TbErrorCnt++; 
    end 

    assert(RxStatusControl[`Rx_SC_OVERFLOW] == 1) else begin 
      $error("Rx_Overflow should be 1 when an overflow is reveived.");
      TbErrorCnt++;
    end 

    // assert first 125 bytes match in Rx_buff
    for (int i = 0; i < `BUFFER_SIZE-2; i++) begin 
      ReadAddress(`Rx_BUFF_ADDR, ReadData);         // read off data from Rx_buff at address 'h3
      assert (ReadData == data[i]) else begin 
        $error("Rx_Data %h is not equal to data %h", ReadData, data[i]);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 

    // assert out of bounds indexes is set to zero
    for (int i = `BUFFER_SIZE-2; i < Size; i++) begin 
      ReadAddress(`Rx_BUFF_ADDR, ReadData);         
        $error("Out of Bounds data should be set to zero. Rx_Data[%d] is %h, which is out of bounds of len Rx_Data == 126", i, ReadData);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 
  endtask

  task VerifyDroppedReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uid.hdlc.Rx_Ready);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    assert(RxStatusControl[`Rx_SC_DROP] == 1) else begin
      $error("Rx_Drop should be high when drop signal is received.")
    end
    
  endtask

  task VerifyFCSerrReceive(logic [127:0][7:0] data, int Size);

  endtask

  task VerifyNonByteAlignedReceive(logic [127:0][7:0] data, int Size);

  endtask

  task VerfiyNormalTransmit();

  endtask

  task VerifyAbortTransmit();

  endtask

  /* ------------------------- 
  Secondary intermittent verification tasks 
  ------------------------- */

  task WaitAndVerifyTxDone(int Size, int Abort);
    if(!Abort) begin
      for(int i = 0; i < Size-1; i++) begin
        wait(uin_hdlc.Tx_RdBuff);
        @(posedge uin_hdlc.Clk);
      end
      a_TxDoneAsserted: assert (uin_hdlc.Tx_Done == 1'b1)
        $display("Event %t: Tx_Done correctly asserted after TxBuffer read in.", $time);
      else begin
        $display("Event %t: ERROR: Tx_Done=%0b, not asserted correctly after TxBuffer read in.", $time, uin_hdlc.Tx_Done);
        TbErrorCnt++;
      end
    end
  endtask

  task VerifyTxFull(int Size);
    logic [7:0] TxStatusControl;
    ReadAddress(`Tx_SC_ADDR, TxStatusControl);

    if (Size >= `BUFFER_SIZE-2) begin
      assert(TxStatusControl[`Tx_SC_FULL] == 1) $display("Event %t: Tx_Full Correctly asserted (Size=%0d)", $time, Size);
      else begin
        $error("Event %t: Tx_Full should be 1 when %0d bytes written (>= 126)", $time, Size);
        TbErrorCnt++;
      end
    end else begin
      assert(TxStatusControl[`Tx_SC_FULL] == 0) $display("Event %t: Tx_Full correctly not asserted (Size=%0d)", $time, Size);
      else begin
        $error("Event %t: Tx_Full should be 0 when %0d bytes written (< 126)", $time, Size);
        TbErrorCnt++;
      end
    end
  endtask

endprogram
