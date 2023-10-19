`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  reg  [3:0]               tap_WE,
    output  reg                      tap_EN,
    output  reg  [(pDATA_WIDTH-1):0] tap_Di,
    output  reg  [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg  [3:0]               data_WE,
    output  reg                      data_EN,
    output  reg  [(pDATA_WIDTH-1):0] data_Di,
    output  reg  [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin


    wire ap_start;
    wire [pDATA_WIDTH-1 : 0] XferLength;

    wire ap_done;
    wire ap_idle;

    wire reset_ap_start;

    wire [pADDR_WIDTH-1 :0] data_A_Xferloop;
    wire                    data_EN_Xferloop;
    wire [3:0]              data_WE_Xferloop;
    wire [(pDATA_WIDTH-1):0]data_Di_Xferloop;

    wire [pADDR_WIDTH-1 :0] tap_A_axi_lite;
    wire                    tap_EN_axi_lite;
    wire [3:0]              tap_WE_axi_lite;
    wire [(pDATA_WIDTH-1):0]tap_Di_axi_lite;

    wire [pADDR_WIDTH-1 :0] tap_A_Xferloop;
    wire                    tap_EN_Xferloop;
    wire [3:0]              tap_WE_Xferloop;




    reg ss_running;
    always@(posedge axis_clk or negedge axis_rst_n)begin
        if(~axis_rst_n)begin
            ss_running <= 1'd0;
        end 
        else begin
            ss_running <= (ap_start) ? 1'd1 : ss_running;
        end
    end


    always@(posedge axis_clk)begin
        data_A  <= data_A_Xferloop; 
        data_EN <= data_EN_Xferloop;
        data_WE <= data_WE_Xferloop;
        data_Di <= data_Di_Xferloop;
    end

    always@(posedge axis_clk)begin
        tap_A  <= (ss_running)? tap_A_Xferloop  : tap_A_axi_lite; 
        tap_EN <= (ss_running)? tap_EN_Xferloop : tap_EN_axi_lite;
        tap_WE <= (ss_running)? tap_WE_Xferloop : tap_WE_axi_lite;
        tap_Di <= tap_Di_axi_lite;

    end


    axi_lite_control axi_lite_control_U0(
        .clk(axis_clk),
        .rst_n(axis_rst_n),

        .awvalid(awvalid),
        .awaddr (awaddr),
        .wvalid (wvalid),
        .wdata  (wdata),
        .arvalid(arvalid),
        .araddr (araddr),
        .rready (rready),
    
        .awready(awready),
        .wready (wready),
        .arready(arready),
        .rvalid (rvalid),
        .rdata  (rdata),


        
        .XferLength(XferLength),
    
        .tap_WE(tap_WE_axi_lite),
        .tap_EN(tap_EN_axi_lite),
        .tap_Di(tap_Di_axi_lite),
        .tap_A (tap_A_axi_lite),
        .tap_Do(tap_Do),

        .ap_start(ap_start),
        .reset_ap_start(reset_ap_start),
        .ap_done (ap_done),
        .ap_idle (ap_idle)
    );

    Xferloop Xferloop_U0
    (
        .clk(axis_clk),
        .rst_n(axis_rst_n),

        .ss_tvalid(ss_tvalid), 
        .ss_tdata (ss_tdata), 
        .ss_tlast (ss_tlast), 
        .ss_tready(ss_tready), 

        .sm_tready(sm_tready), 
        .sm_tvalid(sm_tvalid), 
        .sm_tdata (sm_tdata), 
        .sm_tlast (sm_tlast),

        .XferLength(XferLength),


        .data_WE(data_WE_Xferloop),
        .data_EN(data_EN_Xferloop),
        .data_Di(data_Di_Xferloop),
        .data_A (data_A_Xferloop),
        .data_Do(data_Do),

        .tap_WE(tap_WE_Xferloop),
        .tap_EN(tap_EN_Xferloop),
        .tap_A (tap_A_Xferloop),
        .tap_Do(tap_Do),


        .ap_start(ap_start),
        .reset_ap_start(reset_ap_start),
        .ap_done (ap_done),
        .ap_idle (ap_idle)

    );


end
endmodule