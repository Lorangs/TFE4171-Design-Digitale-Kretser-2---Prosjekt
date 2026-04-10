//////////////////////////////////////////////////
// Title:   testPr_hdlc
// Author: 
// Date:  
//////////////////////////////////////////////////

/* testPr_hdlc contains the simulation and immediate assertion code of the
   testbench. 

   For this exercise you will write immediate assertions for the Rx module which
   should verify correct values in some of the Rx registers for:
   - Normal behavior
   - Buffer overflow 
   - Aborts

   HINT:
   - A ReadAddress() task is provided, and addresses are documentet in the 
     HDLC Module Design Description
*/

program testPr_hdlc(
  in_hdlc uin_hdlc
);
  
  int TbErrorCnt;

  /****************************************************************************
   *                                                                          *
   *                               Student code                               *
   *                                                                          *
   ****************************************************************************/

  // VerifyAbortReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer is zero after abort.
  task VerifyAbortReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadData;
    logic [7:0] RxStatusControl;


    /* Rx_sc [7:0] index:
        0 (LSB) -> Rx_Ready
        1       -> Rx_Drop
        2       -> Rx_FrameError
        3       -> Rx_AbortSignal
        4       -> Rx_Overflow
        5       -> RxFCSen
        6-7     -> N/A    
    */
    ReadAddress('h2, RxStatusControl);    // read off Rx_SC status control register at address 'h2

    // assert Rx_Ready status bit
    assert(RxStatusControl[0] == 0) else begin 
      $error("Rx_Ready should be 0 when an abort is received");
      TbErrorCnt++;
    end 

    // asset Rx_FrameError status bit
    assert(RxStatusControl[2] == 0) else begin 
      $error("Rx_FrameError should be 0 when an abort is received");
      TbErrorCnt++;
    end

    // assert Rx_AbortSignal status bit
    assert(RxStatusControl[3]== 1) else begin 
      $error("Rx_AbortSignal should be 1 when an abort is received");
      TbErrorCnt++;
    end

    // assert Rx_Overflow status bit
    assert(RxStatusControl[4] == 0) else begin 
      $error("Rx_Overflow should be 0 when an abort is received");
      TbErrorCnt++;
    end

    // assert that all bytes in Rx_Buff ('h3) is set to zero ('h00) when Rx_AbortSignal is set
    for (int i = 0; i < Size; i++) begin 
      ReadAddress('h3, ReadData);
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

    ReadAddress('h2, RxStatusControl);  // Read off Rx_SC status control register at address 'h2

    // assert size is smaller than buffer size when receiving normal package
    assert(Size <= 127) else begin 
      $error("Recieved size is too large (%h). Overflow bit should be high.", Size);
      TbErrorCnt++;
    end 

    // assert Rx_Ready status bit
    assert(RxStatusControl[0] == 1) else begin 
      $error("Rx_Ready should be 1 when a frame is received");
      TbErrorCnt++;
    end 

    // assert Rx_FrameError status bit
    assert(RxStatusControl[2] == 0) else begin 
      $error("Rx_FrameError should be 0 when a normal frame is received");
      TbErrorCnt++;
    end

    // assert Rx_AbortSignal status bit
    assert(RxStatusControl[3] == 0) else begin 
      $error("Rx_AbortSignal should be 0 when a normal frame is received");
      TbErrorCnt++;
    end

    // assert Rx_Overflow status bit
    assert(RxStatusControl[4] == 0) else begin 
      $error("Rx_Overflow should be 0 when a normal frame is received");
      TbErrorCnt++;
    end


    // assert read data match that of Rx_buff (address 'h3)
    for (int i = 0; i < Size; i++) begin
      ReadAddress('h3, ReadData);       // read of data from Rx_Buff from address 'h3
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

    ReadAddress('h2, RxStatusControl);

    // assert Size is larger than buffer size when Rx_Overflow status bit is high
    assert(Size >= 126) else begin 
      $error("Overflow bit is high, but Size (%d) is smaller than buffer size.", Size);
      TbErrorCnt++;
    end

    // assert Rx_Ready status bit
    assert(RxStatusControl[0] == 1) else begin 
      $error("Rx_Ready should be high when an overflow is recieved.");
      TbErrorCnt++;
    end 
 
    // assert Rx_FrameError status bit
    assert(RxStatusControl[2] == 0) else begin 
      $error("Rx_FrameError should be zero when an overflow is received.");
      TbErrorCnt++;
    end 
 

    // assert Rx_AbortSignal status bit
    assert(RxStatusControl[3] == 0) else begin 
      $error("Rx_AbortSignal should be zero when an overflow is received.");
      TbErrorCnt++; 
    end 

    // assert Rx_Overflow status bit
    assert(RxStatusControl[4] == 1) else begin 
      $error("Rx_Overflow should be 1 when an overflow is reveived.");
      TbErrorCnt++;
    end 

    // assert first 125 bytes match in Rx_buff
    for (int i = 0; i < 126; i++) begin 
      ReadAddress('h3, ReadData);         // read off data from Rx_buff at address 'h3
      assert (ReadData == data[i]) else begin 
        $error("Rx_Data %h is not equal to data %h", ReadData, data[i]);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 

    // assert out of bounds indexes is set to zero
    for (int i = 126; i < Size; i++) begin 
      ReadAddress('h3, ReadData);             // read off data from Rx_Buff at address 'h3
      assert(ReadData == 'h00) else begin 
        $error("Out of Bounds data should be set to zero. Rx_Data[%d] is %h, which is out of bounds of len Rx_Data == 126", i, ReadData);
        TbErrorCnt++;
      end 
      @(posedge uin_hdlc.Clk);
    end 

  endtask

  /****************************************************************************
   *                                                                          *
   *                             Simulation code                              *
   *                                                                          *
   ****************************************************************************/

  initial begin
    $display("*************************************************************");
    $display("%t - Starting Test Program", $time);
    $display("*************************************************************");

    Init();

    //Receive: Size, Abort, FCSerr, NonByteAligned, Overflow, Drop, SkipRead
    Receive( 10, 0, 0, 0, 0, 0, 0); //Normal
    Receive( 40, 1, 0, 0, 0, 0, 0); //Abort
    Receive(126, 0, 0, 0, 1, 0, 0); //Overflow
    Receive( 45, 0, 0, 0, 0, 0, 0); //Normal
    Receive(126, 0, 0, 0, 0, 0, 0); //Normal
    Receive(122, 1, 0, 0, 0, 0, 0); //Abort
    Receive(126, 0, 0, 0, 1, 0, 0); //Overflow
    Receive( 25, 0, 0, 0, 0, 0, 0); //Normal
    Receive( 47, 0, 0, 0, 0, 0, 0); //Normal

    $display("*************************************************************");
    $display("%t - Finishing Test Program", $time);
    $display("*************************************************************");
    $stop;
  end

  final begin

    $display("*********************************");
    $display("*                               *");
    $display("* \tAssertion Errors: %0d\t  *", TbErrorCnt + uin_hdlc.ErrCntAssertions);
    $display("*                               *");
    $display("*********************************");

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
    $display("*************************************************************");
    $display("%t - Starting task Receive %s", $time, msg);
    $display("*************************************************************");

    for (int i = 0; i < Size; i++) begin
      ReceiveData[i] = $urandom;
    end
    ReceiveData[Size]   = '0;
    ReceiveData[Size+1] = '0;

    //Calculate FCS bits;
    GenerateFCSBytes(ReceiveData, Size, FCSBytes);
    ReceiveData[Size]   = FCSBytes[7:0];
    ReceiveData[Size+1] = FCSBytes[15:8];

    //Enable FCS. 
    if(!Overflow && !NonByteAligned)
      WriteAddress('h2, 8'h20);   // write to Rx_sc status control bit at address 'h2
    else
      WriteAddress('h2, 8'h00);   // write to Rx_sc status control bit at address 'h2

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

    #5000ns;
  endtask

  task GenerateFCSBytes(logic [127:0][7:0] data, int size, output logic[15:0] FCSBytes);
    logic [23:0] CheckReg;
    CheckReg[15:8]  = data[1];
    CheckReg[7:0]   = data[0];
    for(int i = 2; i < size+2; i++) begin
      CheckReg[23:16] = data[i];
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

endprogram
