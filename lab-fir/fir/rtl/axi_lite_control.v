module axi_lite_control
#(
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32
)
(
    input clk,
    input rst_n,

    input                     awvalid,
    input [(pADDR_WIDTH-1):0] awaddr,
    input                     wvalid,
    input [(pDATA_WIDTH-1):0] wdata,
    input                     arvalid,
    input [(pADDR_WIDTH-1):0] araddr,
    input                     rready,
    
    output                     awready,
    output                     wready,
    output                     arready,
    output                     rvalid,
    output reg [(pDATA_WIDTH-1):0] rdata,


    output [(pDATA_WIDTH-1):0] XferLength,

    output [3:0]               tap_WE,
    output                     tap_EN,
    output [(pDATA_WIDTH-1):0] tap_Di,
    output [(pADDR_WIDTH-1):0] tap_A,
    input  [(pDATA_WIDTH-1):0] tap_Do,
    

    output                     ap_start,
    input                      reset_ap_start,
    input                      ap_done,
    input                      ap_idle

);


localparam
    ADDR_AP_CTRL            = 'h00,
    ADDR_REGXFERLENG_DATA_0 = 'h10,
    ADDR_AN32COEF_BASE      = 'h20,
    ADDR_AN32COEF_HIGH      = 'h4f,

    WRIDLE                  = 2'd0,
    WRDATA                  = 2'd1,
    WRRESET                 = 2'd2,

    RDIDLE                  = 2'd0,
    RDDATA                  = 2'd1,
    RDRESET                 = 2'd2;

reg [1:0]                wstate_r, wstate_w;
reg [pADDR_WIDTH -1 :0 ] waddr_r;
wire                     aw_hs, w_hs;


reg [1:0]                rstate_r, rstate_w;
wire                     ar_hs, r_hs;
reg                      an32Coef_read_r, an32Coef_read_r_d1;
reg                      an32Coef_write_r;

reg                     ap_start_r;
reg [pDATA_WIDTH-1 : 0] XferLeng_r;

reg ap_done_r;
reg ap_idle_r;



assign awready = (wstate_r == WRIDLE);
assign wready  = (wstate_r == WRDATA) & (~ar_hs);
//assign wready  = (wstate_r == WRDATA);
assign aw_hs   = awvalid & awready;
assign w_hs    = wvalid  & wready;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        wstate_r <= WRRESET;
    end
    else begin 
        wstate_r <= wstate_w;
    end
end

always @(*) begin
    case (wstate_r)
        WRIDLE:begin
            wstate_w = (awvalid)? WRDATA : WRIDLE;
        end
        WRDATA:begin
            wstate_w = (w_hs) ? WRIDLE : WRDATA; 
        end
        default:begin
            wstate_w = WRIDLE;
        end
    endcase
end

always @(posedge clk) begin
    if (aw_hs)begin
        waddr_r <= awaddr;
    end
end


assign arready = (rstate_r == RDIDLE);
assign rvalid  = (rstate_r == RDDATA) & (~an32Coef_read_r) & (~an32Coef_read_r_d1);

assign ar_hs   = arvalid & arready;
assign r_hs    = rvalid  & rready;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n)begin
        rstate_r <= RDRESET;
    end
    else begin 
        rstate_r <= rstate_w;
    end
end

always@(*)begin
    case(rstate_r)
        RDIDLE:begin
            rstate_w = (arvalid) ? RDDATA : RDIDLE;
        end
        RDDATA:begin
            rstate_w = (r_hs) ? RDIDLE : RDDATA;
        end
        default:begin
            rstate_w = RDIDLE;
        end
    endcase 
end


always @(posedge clk) begin
    if (ar_hs) begin
        rdata <= 'b0;
        case (araddr)
            ADDR_AP_CTRL: begin
                rdata[0] <= ap_start;
                rdata[1] <= ap_done_r;
                rdata[2] <= ap_idle_r;
            end
            ADDR_REGXFERLENG_DATA_0: begin
                rdata <= XferLength;
            end
        endcase
    end
    else if (an32Coef_read_r_d1) begin
        rdata <= tap_Do;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ap_done_r <= 1'b0;
    end
    else begin
        if (ap_done)begin
            ap_done_r <= 1'd1;
        end
        else if(ar_hs & (araddr == ADDR_AP_CTRL))begin
            ap_done_r <= 1'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ap_idle_r <= 1'b0;
    end
    else begin
        if (ap_idle)begin
            ap_idle_r <= 1'd1;
        end
        else if(ar_hs & (araddr == ADDR_AP_CTRL))begin
            ap_idle_r <= 1'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ap_start_r <= 1'b0;
    end
    else begin
        if (w_hs && waddr_r == ADDR_AP_CTRL && wdata[0])begin
            ap_start_r <= 1'b1;
        end
        else if (reset_ap_start)begin
            ap_start_r <= 1'b0;
        end
    end
end

assign ap_start = ap_start_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        XferLeng_r <= 0;
    end
    else begin
        if (w_hs && waddr_r == ADDR_REGXFERLENG_DATA_0) begin
            XferLeng_r <= wdata;
        end
    end
end

assign XferLength = XferLeng_r;

assign tap_A       = (w_hs)? waddr_r - ADDR_AN32COEF_BASE : araddr - ADDR_AN32COEF_BASE; 
//assign tap_EN      = ar_hs | (an32Coef_write_r & wvalid);
assign tap_EN      = 1'b1;
assign tap_WE      = {4{an32Coef_write_r & w_hs}};
assign tap_Di      = wdata;


always @(posedge clk or negedge rst_n) begin
    if (~rst_n)begin
        an32Coef_read_r <= 1'b0;
    end
    else begin 
        an32Coef_read_r <= (ar_hs && araddr >= ADDR_AN32COEF_BASE && araddr <= ADDR_AN32COEF_HIGH) ? 1'b1 : 1'b0;
    end
end

always@(posedge clk)begin
    an32Coef_read_r_d1 <= an32Coef_read_r; 
end

always@(posedge clk or negedge rst_n) begin
    if (~rst_n)begin
        an32Coef_write_r <= 1'b0;
    end
    else begin
        if (aw_hs && awaddr >= ADDR_AN32COEF_BASE && awaddr <= ADDR_AN32COEF_HIGH)begin
            an32Coef_write_r <= 1'b1;
        end
        else if (w_hs) begin
            an32Coef_write_r <= 1'b0;
        end
    end
end



endmodule
