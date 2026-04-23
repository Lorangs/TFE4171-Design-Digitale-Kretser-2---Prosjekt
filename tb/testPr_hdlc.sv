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
`define FCS_SIZE            2    // Size of FCS in bytes
`define NUM_RANDOM_TESTS    10//00   // Number of random tests to perform for each test case in the test program

`define START_END_FLAG      8'b01111110
`define ABORT_FLAG          8'b11111110

`define WAIT_TIME_ns        1000ns // Wait time in nano seconds

program testPr_hdlc(
  in_hdlc uin_hdlc
);

  int TbErrorCnt;

  initial begin
    int randomseed;
    int Size;

    $display("------------------------------------");
    $display("Event %t: Starting Test Program", $time);
    $display("------------------------------------");

    Init();

    randomseed = 0; 
    if (!$value$plusargs("seed=%d", randomseed)) begin
      randomseed = 12345;  // Default fallback
    end
    $srandom(randomseed); // Use the captured or default seed as a basis for a new randomseed
    randomseed = $urandom; // Capture the random seed used for this run
    $display("Random seed for this run: %0d", randomseed);

    // Generate stimulus and verify response for different size frames
    for (int i = 0; i < `NUM_RANDOM_TESTS; i++) begin
      if (i == 0)
        Size = 4;                               // minimum size frame, adjusted from 1 to 4 as FCS got errors otherwise
      else if (i == `NUM_RANDOM_TESTS-1)
        Size = `BUFFER_SIZE-2;                    // maximum size frame
      else
        Size = $urandom_range(4, `BUFFER_SIZE-2); // random size frame. range: [4..126]

        // Test behaviour:
        Receive(Size, 0, 0, 0, 0, 0, 0); //Normal
        Receive(Size, 1, 0, 0, 0, 0, 0); //Abort
        Receive(Size, 0, 1, 0, 0, 0, 0); // FCSerr
        Receive(Size, 0, 0, 1, 0, 0, 0); // Non-byte aligned
        Receive(`BUFFER_SIZE, 0, 0, 0, 1, 0, 0); //Overflow
        Receive(Size, 0, 0, 0, 0, 1, 0); // Dropped
        Receive(Size, 0, 0, 0, 0, 0, 1); // Skip read
        Transmit(Size, 0); // Normal
        Transmit(Size, 1); // Abort
    end

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

  task MakeRxStimulus(logic [127:0][7:0] Data, int Size, logic NoneByteAligned);
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

    // Send extra bits (not a full byte) to make data non-byte aligned
    if (NoneByteAligned) begin
      @(posedge uin_hdlc.Clk);
      uin_hdlc.Rx = 1'b0;
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
    $display("Event %t: Receiving message %s (Size=%0d)", $time, msg, Size);
    $display("------------------------------------------");

    for (int i = 0; i < Size; i++) begin
      ReceiveData[i] = $urandom;
    end
    ReceiveData[Size]   = '0;
    ReceiveData[Size+1] = '0;

    //Calculate FCS bits;
    GenerateFCSBytes(ReceiveData, Size, FCSBytes);
    if (FCSerr)
      FCSBytes = FCSBytes ^ 16'h0001; // Flip the final bit in FSC to generate FCS error
    ReceiveData[Size]   = FCSBytes[7:0];
    ReceiveData[Size+1] = FCSBytes[15:8];

    //Enable FCS. 
    if(!Overflow && !NonByteAligned)
      WriteAddress(`Rx_SC_ADDR, 8'h20);   // write to Rx_sc status control bit at address 'h2
    else
      WriteAddress(`Rx_SC_ADDR, 8'h00);   // write to Rx_sc status control bit at address 'h2

    //Generate stimulus
    InsertFlagOrAbort(1);
    
    MakeRxStimulus(ReceiveData, Size + 2, NonByteAligned);
    
    if(Overflow) begin
      OverflowData[0] = 8'h44;
      OverflowData[1] = 8'hBB;
      OverflowData[2] = 8'hCC;
      MakeRxStimulus(OverflowData, 3, NonByteAligned);
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
    else if (Drop)
      VerifyDroppedReceive(ReceiveData, Size);
    else if(FCSerr)
      VerifyFCSerrReceive(ReceiveData, Size);
    else if(NonByteAligned)
      VerifyNonByteAlignedReceive(ReceiveData, Size);
    else if(!SkipRead)
      VerifyNormalReceive(ReceiveData, Size);

    #`WAIT_TIME_ns;
  endtask

  task Transmit(int Size, int Abort);
    logic [127:0][7:0] WrittenData;
    logic [127:0][7:0] TransmittedData;
    logic [15:0] FCSBytes;
    string msg;

    if (Abort)
      msg = "- Abort";
    else
      msg = "- Normal";
    $display("----------------------------------------------");
    $display("Event %t: Transmitting message %s (Size=%0d)", $time, msg, Size);
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

    repeat(2)
      @(posedge uin_hdlc.Clk);

    VerifyTxFull(Size);

    //Start transmission
    WriteAddress(`Tx_SC_ADDR, 8'h02);

    if (Abort) begin
      // Let transmission start, then issue abort
      wait(!uin_hdlc.Tx_Done);  // Wait for transmission to actually start
      repeat(5)
        @(posedge uin_hdlc.Clk);
      WriteAddress(`Tx_SC_ADDR, 8'h04);

      repeat(20)
        @(posedge uin_hdlc.Clk);

      VerifyAbortTransmit();
    end else begin
      fork
        ReadTransmittedData(Size+2, Abort, TransmittedData);
        WaitAndVerifyTxDone(Size, Abort);
      join

      repeat(8)
        @(posedge uin_hdlc.Clk);

      VerfiyNormalTransmit(WrittenData, TransmittedData, FCSBytes, Size);
    end

    #`WAIT_TIME_ns;
  endtask

  task automatic ReadTransmittedData(int Size, int Abort, ref logic [127:0][7:0] TransmittedData);
    logic [7:0] flag_shift;
    int ones_cnt;
    int bit_idx, byte_idx;
    logic bit_val;

    TransmittedData = '0;
    flag_shift = '1;

    // Wait for start flag (01111110) on Tx line (Spec 5)
    forever begin
      @(posedge uin_hdlc.Clk);
      flag_shift = {uin_hdlc.Tx, flag_shift[7:1]};
      if (flag_shift == `START_END_FLAG) break;
    end

    // Read data bytes with zero removal (Spec 6)
    ones_cnt = 0;
    bit_idx  = 0;
    byte_idx = 0;

    while (byte_idx < Size) begin
      @(posedge uin_hdlc.Clk);
      bit_val = uin_hdlc.Tx;

      if (bit_val) begin
        ones_cnt++;
        if (ones_cnt >= 7) begin
          // Abort pattern detected (Spec 8)
          break;
        end
        TransmittedData[byte_idx][bit_idx] = 1'b1;
        bit_idx++;
      end else begin
        if (ones_cnt == 5) begin
          // Stuffed zero - discard (Spec 6)
          ones_cnt = 0;
        end else if (ones_cnt == 6) begin
          // End flag detected (Spec 5)
          break;
        end else begin
          TransmittedData[byte_idx][bit_idx] = 1'b0;
          bit_idx++;
          ones_cnt = 0;
        end
      end

      if (bit_idx == 8) begin
        bit_idx  = 0;
        byte_idx++;
      end
    end

    // Continue reading after data to detect end flag
    if (byte_idx >= Size) begin
      while (1) begin
        @(posedge uin_hdlc.Clk);
        bit_val = uin_hdlc.Tx;
        if (bit_val) begin
          ones_cnt++;
          if (ones_cnt >= 7) break;
        end else begin
          if (ones_cnt == 5)
            ones_cnt = 0;
          else if (ones_cnt == 6)
            break;
          else
            ones_cnt = 0;
        end
      end
    end

    // Verify end flag was detected - Spec 5
    assert(ones_cnt == 6) else begin
      $error("ReadTransmittedData: End flag (01111110) not detected after TX data");
      TbErrorCnt++;
    end
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

  // Spec 13:
  task VerifyOverflowReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_Ready);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    assert(Size >= `BUFFER_SIZE-`FCS_SIZE) else begin 
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
    for (int i = 0; i < `BUFFER_SIZE -`FCS_SIZE; i++) begin 
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);         // read off data from Rx_buff at address 'h3
      assert (ReadData == data[i]) else begin 
        $error("Rx_Data %h is not equal to data %h", ReadData, data[i]);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 

    // assert out of bounds indexes is set to zero
    for (int i = `BUFFER_SIZE -`FCS_SIZE; i < Size; i++) begin 
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);         
      assert(ReadData == 'h00) else begin
        $error("Out of Bounds data should be set to zero. Rx_Data[%d] is %h, which is out of bounds of len Rx_Data == 126", i, ReadData);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 
  endtask

  task VerifyDroppedReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_Ready);

    // Write Drop command to Rx_SC to drop the received frame
    WriteAddress(`Rx_SC_ADDR, 8'h02);

    repeat(2)
      @(posedge uin_hdlc.Clk);

    // Verify Rx_Ready is deasserted after drop
    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    assert(RxStatusControl[`Rx_SC_READY] == 0) else begin
      $error("Rx_Ready should be 0 after drop command");
      TbErrorCnt++;
    end
    
  endtask

  task VerifyFCSerrReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_FrameError);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    // FCS error should result in frame error - Spec 16
    assert(RxStatusControl[`Rx_SC_FRAME_ERR] == 1) else begin
      $error("Rx_FrameError should be 1 when FCS error occurs");
      TbErrorCnt++;
    end

    // Check all other status bits - Spec 3
    assert(RxStatusControl[`Rx_SC_READY] == 0) else begin
      $error("Rx_Ready should be 0 when frame received with FCS error");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_ABORT_SIG] == 0) else begin
      $error("Rx_AbortSignal should be 0 when FCS error occurs");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_OVERFLOW] == 0) else begin
      $error("Rx_Overflow should be 0 when FCS error occurs");
      TbErrorCnt++;
    end

    // Buffer should contain zeros after frame error - Spec 2
    for (int i = 0; i < Size; i++) begin
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);
      assert(ReadData == 'h00) else begin
        $error("Rx_Data[%0d] should be zero after FCS error, got %h", i, ReadData);
        TbErrorCnt++;
      end
      @(posedge uin_hdlc.Clk);
    end
  endtask

  task VerifyNonByteAlignedReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;
    wait(uin_hdlc.Rx_FrameError);

    ReadAddress(`Rx_SC_ADDR, RxStatusControl);

    // Spec 16: Non-byte aligned data should result in frame error
    assert(RxStatusControl[`Rx_SC_FRAME_ERR] == 1) else begin
      $error("Rx_FrameError should be 1 when non-byte aligned data received");
      TbErrorCnt++;
    end

    // Spec 3: Check all other status bits
    assert(RxStatusControl[`Rx_SC_READY] == 0) else begin
      $error("Rx_Ready should be 0 when non-byte aligned frame received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_ABORT_SIG] == 0) else begin
      $error("Rx_AbortSignal should be 0 when non-byte aligned data received");
      TbErrorCnt++;
    end

    assert(RxStatusControl[`Rx_SC_OVERFLOW] == 0) else begin
      $error("Rx_Overflow should be 0 when non-byte aligned data received");
      TbErrorCnt++;
    end

    // Spec 2: Buffer should contain zeros after frame error
    for (int i = 0; i < Size; i++) begin
      ReadAddress(`Rx_BUFFER_ADDR, ReadData);
      assert(ReadData == 'h00) else begin
        $error("Rx_Data[%0d] should be zero after non-byte aligned receive, got %h", i, ReadData);
        TbErrorCnt++;
      end
      @(posedge uin_hdlc.Clk);
    end
  endtask

  task VerfiyNormalTransmit(logic [127:0][7:0] WrittenData, logic [127:0][7:0] TransmittedData, logic [15:0] FCSBytes, int Size);
    logic [7:0] TxStatusControl;

    // Spec 4: Verify transmitted data matches written TX buffer
    for (int i = 0; i < Size; i++) begin
      assert(TransmittedData[i] == WrittenData[i]) else begin
        $error("VerfiyNormalTransmit: Data mismatch at byte %0d: expected %h, got %h", i, WrittenData[i], TransmittedData[i]);
        TbErrorCnt++;
      end
    end

    VerifyCRCCheck(TransmittedData, FCSBytes, Size);

    ReadAddress(`Tx_SC_ADDR, TxStatusControl);
    // Spec 17: Verify Tx_Done is asserted after entire TX buffer read
    assert(TxStatusControl[`Tx_SC_DONE] == 1) else begin
      $error("VerfiyNormalTransmit: Tx_Done should be 1 after normal transmission");
      TbErrorCnt++;
    end

    // Spec 3: Verify no abort bits set after normal transmission
    assert(TxStatusControl[`Tx_SC_ABORT_TRANS] == 0) else begin
      $error("VerfiyNormalTransmit: Tx_AbortedTrans should be 0 after normal transmission");
      TbErrorCnt++;
    end

    // Tx_Overflow is mentioned in datasheet, but there is non Tx_Overflow bit in Tx_SC ?
    // Assuming that this is a mistake in the datasheet
    /*
    if (Size >= `BUFFER_SIZE - `FCS_SIZE) begin
      assert(TxStatusControl[`Tx_SC_OVERFLOW] == 1) else begin
        $error("VerifyNormalTransmit: Tx_Overflow should be set high when transmitting more than 126 bytes.");
        TbErrorCnt++;
    end
    */
  endtask

  task VerifyAbortTransmit();
    logic [7:0] TxStatusControl;

    // Spec 9: Verify Tx_AbortedTrans is asserted
    ReadAddress(`Tx_SC_ADDR, TxStatusControl);
    assert(TxStatusControl[`Tx_SC_ABORT_TRANS] == 1) else begin
      $error("VerifyAbortTransmit: Tx_AbortedTrans should be 1 after aborting transmission");
      TbErrorCnt++;
    end

    // Spec 17: Tx_Done should also be asserted after abort
    assert(TxStatusControl[`Tx_SC_DONE] == 1) else begin
      $error("VerifyAbortTransmit: Tx_Done should be 1 after abort");
      TbErrorCnt++;
    end
  endtask

  /* ------------------------- 
  Secondary intermittent verification tasks 
  ------------------------- */

  task WaitAndVerifyTxDone(int Size, int Abort);
    if(!Abort) begin
      wait(!uin_hdlc.Tx_Done);  // Wait for Tx_Done to be low (transmission started)
      wait(uin_hdlc.Tx_Done);   // Wait for Tx_Done to go high again (transmission complete)
      a_TxDoneAsserted: assert (uin_hdlc.Tx_Done == 1'b1) else begin
        $display("Event %t: ERROR: Tx_Done=%0b, not asserted correctly after TxBuffer read in.", $time, uin_hdlc.Tx_Done);
        TbErrorCnt++;
      end
    end
  endtask

  task VerifyTxFull(int Size);
    logic [7:0] TxStatusControl;
    ReadAddress(`Tx_SC_ADDR, TxStatusControl);

    if (Size >= `BUFFER_SIZE -`FCS_SIZE) begin
      assert(TxStatusControl[`Tx_SC_FULL] == 1) else begin
        $error("Event %t: Tx_Full should be 1 when %0d bytes written (>= 126)", $time, Size);
        TbErrorCnt++;
      end
    end else begin
      assert(TxStatusControl[`Tx_SC_FULL] == 0) else begin
        $error("Event %t: Tx_Full should be 0 when %0d bytes written (< 126)", $time, Size);
        TbErrorCnt++;
      end
    end
  endtask

    // Spec 11.b:
  task VerifyCRCCheck(logic [127:0][7:0] data, logic [15:0] FCSBytes, int Size);
    assert(data[Size] == FCSBytes[7:0]) else begin
      $error("VerfiyCRCCheck: FCS byte 0 mismatch: expected %h, got %h", FCSBytes[7:0], data[Size]);
      TbErrorCnt++;
    end
    assert(data[Size+1] == FCSBytes[15:8]) else begin
      $error("VerifyCRCCheck: FCS byte 1 mismatch: expected %h, got %h", FCSBytes[15:8], data[Size+1]);
      TbErrorCnt++;
    end
  endtask;

/*
  // Spec 5 and 12:
  task VerifyStartEndPatternGeneration(logic [127:0][7:0] data, int Size)

  
  endtask;

  // Spec 6:
  task VerifyTxZeroInsert(logic [127:0][7:0] data, int Size)
    int ones_cnt;
  endtask;

  // Spec 7:
  task VerifyIdlePatternGeneration(logic [127:0][7:0] data, int Size)

  endtask;

  // Spec 8:
  task VerifyAbortPatternGeneration(logic [127:0][7:0] data, int Size)

  endtask;

  // Spec 9:
  task VerifyAbortDuringTransmission(logic [127:0][7:0] data, int Size)

  endtask;

  // Spec 11.a:
  task VerifyCRCGeneration(logic [127:0][7:0] data, int Size)
    logic [127:0][7:0] 

    wait(uid_hdlc.)
  endtask;

  // Spec 14:
  task VerifyFrameLengthMatchRxLEN(logic [127:0][7:0] data, int Size)

  endtask;
*/



endprogram
