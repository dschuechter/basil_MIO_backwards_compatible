
`timescale 1ps / 1ps
`default_nettype none

module sram_test (
    
    input wire FCLK_IN, 
    
    //full speed 
    inout wire [7:0] BUS_DATA,
    input wire [15:0] ADD,
    input wire RD_B,
    input wire WR_B,
    
    //high speed
    inout wire [7:0] FD,
    input wire FREAD,
    input wire FSTROBE,
    input wire FMODE,
    
    //SRAM
    output wire [19:0] SRAM_A,
    inout wire [15:0] SRAM_IO,
    output wire SRAM_BHE_B,
    output wire SRAM_BLE_B,
    output wire SRAM_CE1_B,
    output wire SRAM_OE_B,
    output wire SRAM_WE_B,
    
    output wire [4:0] LED,
    
    inout wire SDA,
    inout wire SCL

    );   
    
    assign SDA = 1'bz;
    assign SCL = 1'bz;
    
    assign LED = 0; 
    
    //BASIL bus mapping
    wire [15:0] BUS_ADD;
    assign BUS_ADD = ADD - 16'h4000;
    wire BUS_RST, BUS_CLK, BUS_RD, BUS_WR;
    assign BUS_RD = ~RD_B;
    assign BUS_WR = ~WR_B;
    assign BUS_CLK = FCLK_IN;
    
    reset_gen i_reset_gen(.CLK(BUS_CLK), .RST(BUS_RST));
 
    //MODULE ADREESSES
    localparam GPIO_CONTROL_BASEADDR = 16'h0000;
    localparam GPIO_CONTROL_HIGHADDR = 16'h000f;
    
    localparam GPIO_PATTERN_BASEADDR = 16'h0010;
    localparam GPIO_PATTERN_HIGHADDR = 16'h001f;

    localparam FIFO_BASEADDR = 16'h0020;  
    localparam FIFO_HIGHADDR = 16'h002f;  
    
    // USER MODULES //
    wire [5:0] CONTROL_NOT_USED;
    wire PATTERN_EN;
    wire COUNTER_EN;
    gpio
    #(
        .BASEADDR(GPIO_CONTROL_BASEADDR), 
        .HIGHADDR(GPIO_CONTROL_HIGHADDR),
        
        .IO_WIDTH(8),
        .IO_DIRECTION(8'hff)
    ) i_gpio_control
    (
        .BUS_CLK(BUS_CLK),
        .BUS_RST(BUS_RST),
        .BUS_ADD(BUS_ADD),
        .BUS_DATA(BUS_DATA),
        .BUS_RD(BUS_RD),
        .BUS_WR(BUS_WR),
        .IO({CONTROL_NOT_USED, PATTERN_EN, COUNTER_EN})
    );
        
    wire [31:0] PATTERN;
    gpio
    #( 
        .BASEADDR(GPIO_PATTERN_BASEADDR), 
        .HIGHADDR(GPIO_PATTERN_HIGHADDR),
        
        .IO_WIDTH(32),
        .IO_DIRECTION(32'hffffffff) 
    ) i_gpio_pattern
    (
        .BUS_CLK(BUS_CLK),
        .BUS_RST(BUS_RST),
        .BUS_ADD(BUS_ADD),
        .BUS_DATA(BUS_DATA),
        .BUS_RD(BUS_RD),
        .BUS_WR(BUS_WR),
        .IO(PATTERN)
    );
     
    wire PATTERN_FIFO_READ;
    wire PATTERN_FIFO_EMPTY;
    
    wire [31:0] COUNTER_FIFO_DATA;
    wire COUNTER_FIFO_EMPTY;
    wire COUNTER_FIFO_READ;
  
    wire ARB_READY_OUT, ARB_WRITE_OUT;
    wire [31:0] ARB_DATA_OUT;
    
    rrp_arbiter 
    #( 
        .WIDTH(2)
    ) i_rrp_arbiter
    (
        .RST(BUS_RST),
        .CLK(BUS_CLK),
    
        .WRITE_REQ({COUNTER_EN, PATTERN_EN}),
        .HOLD_REQ({2'b0}),
        .DATA_IN({COUNTER_FIFO_DATA, PATTERN}),
        .READ_GRANT({COUNTER_FIFO_READ, PATTERN_FIFO_READ}),

        .READY_OUT(ARB_READY_OUT),
        .WRITE_OUT(ARB_WRITE_OUT),
        .DATA_OUT(ARB_DATA_OUT)
    );

    sram_fifo 
    #(
        .BASEADDR(FIFO_BASEADDR), 
        .HIGHADDR(FIFO_HIGHADDR)
    ) i_out_fifo (
        .BUS_CLK(BUS_CLK),
        .BUS_RST(BUS_RST),
        .BUS_ADD(BUS_ADD),
        .BUS_DATA(BUS_DATA),
        .BUS_RD(BUS_RD),
        .BUS_WR(BUS_WR), 

        .SRAM_A(SRAM_A),
        .SRAM_IO(SRAM_IO),
        .SRAM_BHE_B(SRAM_BHE_B),
        .SRAM_BLE_B(SRAM_BLE_B),
        .SRAM_CE1_B(SRAM_CE1_B),
        .SRAM_OE_B(SRAM_OE_B),
        .SRAM_WE_B(SRAM_WE_B),
    
        .USB_READ(FREAD && FSTROBE),
        .USB_DATA(FD),
    
        .FIFO_READ_NEXT_OUT(ARB_READY_OUT),
        .FIFO_EMPTY_IN(!ARB_WRITE_OUT),
        .FIFO_DATA(ARB_DATA_OUT),
    
        .FIFO_NOT_EMPTY(),
        .FIFO_READ_ERROR(),
        .FIFO_FULL(),
        .FIFO_NEAR_FULL()
    ); 

    reg [7:0] count;
    always@(posedge BUS_CLK)
        if(BUS_RST)
            count <= 0;
        else if (COUNTER_FIFO_READ)
            count <= count + 4;
    
    wire [7:0] count_send [3:0];
    assign count_send[0] = count;
    assign count_send[1] = count + 1;
    assign count_send[2] = count + 2;
    assign count_send[3] = count + 3;
    
    assign COUNTER_FIFO_DATA = {count_send[3], count_send[2], count_send[1], count_send[0]};

endmodule
