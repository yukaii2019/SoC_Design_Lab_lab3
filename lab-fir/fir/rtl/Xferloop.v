module Xferloop
#(
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    input clk,
    input rst_n,

    input                      ss_tvalid, 
    input  [(pDATA_WIDTH-1):0] ss_tdata, 
    input                      ss_tlast, 
    output                     ss_tready, 

    input                      sm_tready, 
    output                     sm_tvalid, 
    output reg [(pDATA_WIDTH-1):0] sm_tdata, 
    output                     sm_tlast,


    input [(pDATA_WIDTH-1):0] XferLength,


    output [3:0]               data_WE,
    output                     data_EN,
    output [(pDATA_WIDTH-1):0] data_Di,
    output [(pADDR_WIDTH-1):0] data_A,
    input  [(pDATA_WIDTH-1):0] data_Do,


    output  [3:0]               tap_WE,
    output                      tap_EN,
    output  [(pADDR_WIDTH-1):0] tap_A,
    input   [(pDATA_WIDTH-1):0] tap_Do,



    input    ap_start,
    output   reg reset_ap_start,
    output   ap_done,
    output   reg ap_idle

);

    reg [3:0]    cnt_r;
    reg [3:0]    shift_r;
    reg [9:0]    sm_hs_cnt_r;



    wire ss_hs;
    reg ss_hs_d1, ss_hs_d2, ss_hs_d3;
    wire ss_data;
    reg ss_data_d1, ss_data_d2, ss_data_d3;
    wire data_11;
    reg  data_11_d1, data_11_d2, data_11_d3;

    wire sm_hs;

    reg[1:0] ss_state_r, ss_state_w;
    reg[1:0] sm_state_r, sm_state_w;


    reg [pDATA_WIDTH-1:0] ss_tdata_d1, ss_tdata_d2;
    reg signed [pDATA_WIDTH-1:0] data, tap;
    reg signed [pDATA_WIDTH-1:0] acc, acc_w;
    wire signed [pDATA_WIDTH*2-1:0] mul;


    reg last_data;

    localparam
        SSIDLE                  = 2'd0,
        SSDATA                  = 2'd1,
        SSRESET_BRAM            = 2'd2,
        SSRESET                 = 2'd3,

        SMIDLE                  = 2'd0,
        SMDATA                  = 2'd1,
        SMRESET                 = 2'd2;


    // ================ read state =====================//

    assign data_11 = (cnt_r == 10);
    assign ss_tready = (ss_state_r == SSIDLE);
    assign ss_data = (ss_state_r == SSDATA) & ~( (sm_state_r == SMDATA) & ~sm_hs ); // freeze when output not handshake
    assign ss_hs = ss_tready & ss_tvalid;
    
    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            ss_state_r <= SSRESET;
        end
        else begin
            ss_state_r <= ss_state_w;
        end
    end

    always@(*)begin
        case(ss_state_r)
            SSRESET_BRAM:begin
                ss_state_w = (data_11) ? SSIDLE : SSRESET_BRAM;
            end
            SSIDLE:begin
                ss_state_w = (ss_tvalid) ? SSDATA: SSIDLE;
            end
            SSDATA:begin
                ss_state_w = (data_11) ? SSIDLE : SSDATA;
            end
            default:begin
                ss_state_w = (ap_start) ? SSRESET_BRAM : SSRESET;
            end
        endcase
    end

    // ================ write state =====================//

    assign sm_tvalid = (sm_state_r == SMDATA);
    assign sm_hs = sm_tready & sm_tvalid;

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            sm_state_r <= SMRESET;
        end
        else begin
            sm_state_r <= sm_state_w;
        end
    end

    always@(*)begin
        case(sm_state_r)
            SMIDLE:begin
                sm_state_w = (data_11_d3 & ss_data_d3) ? SMDATA : SMIDLE;
            end
            SMDATA:begin
                sm_state_w = (sm_hs) ? SMIDLE : SMDATA;
            end
            default:begin
                sm_state_w = (ap_start) ? SMIDLE : SMRESET;
            end
        endcase
    end


    // ================ bram control logic =====================//

    assign data_A = {(cnt_r + shift_r < 11)? cnt_r + shift_r : cnt_r + shift_r - 11, 2'd0};
    assign data_EN = 1;
    assign data_WE = {4{ss_hs | (ss_state_r == SSRESET_BRAM)}};
    assign data_Di = (ss_hs) ? ss_tdata : 0; 

    assign tap_A = { (11-cnt_r < 11) ? 11-cnt_r : cnt_r , 2'd0};
    assign tap_EN = 1;
    assign tap_WE = 4'd0;


    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            cnt_r <= 0;
        end
        else begin
            if ((ss_state_r == SSRESET_BRAM) | ss_hs | ss_data)begin
                cnt_r <= (cnt_r == 10) ? 0 : cnt_r + 1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            shift_r <= 0;
        end
        else begin
            if (ss_hs | ss_data)begin
                shift_r <= (cnt_r == 10) ? (shift_r == 10)? 0 : shift_r + 1 : shift_r;
            end
        end
    end

    // ==================== control logic =========================//

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            sm_hs_cnt_r <= 0;
        end
        else begin
            if(sm_hs)begin
                sm_hs_cnt_r <= sm_hs_cnt_r + 1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            reset_ap_start <= 0;
        end
        else begin
            reset_ap_start <= (ss_hs)? 1 : reset_ap_start;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            last_data <= 1'd0;
        end
        else begin
            last_data <= (sm_hs_cnt_r == XferLength-1) ? 1'd1: last_data;
            //last_data <= (ss_tlast & sm_hs) ? 1'd1: last_data;
        end
    end

    assign ap_done = last_data & sm_hs;
    assign sm_tlast = last_data & sm_tvalid;

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            ap_idle <= 1'd0;
        end
        else begin
            ap_idle <= (ap_done) ? 1'd1: ap_idle;
        end
    end

    // ==================== pass control signal =========================//

    always@(posedge clk)begin
        ss_hs_d1 <= ss_hs;
        ss_data_d1 <= ss_data;
        data_11_d1 <= data_11;
    end

    always@(posedge clk)begin
        ss_hs_d2 <= ss_hs_d1;
        ss_data_d2 <= ss_data_d1;
        data_11_d2 <= data_11_d1;
    end

    always@(posedge clk)begin
        ss_hs_d3   <= ss_hs_d2;
        ss_data_d3 <= ss_data_d2;
        data_11_d3 <= data_11_d2;
    end

    
    always@(posedge clk)begin
        if(ss_hs)begin
            ss_tdata_d1 <= ss_tdata;
        end
    end

    always@(posedge clk)begin
        if (ss_hs_d1)begin
            ss_tdata_d2 <= ss_tdata_d1;
        end
    end

    always@(posedge clk)begin
        if (ss_hs_d2 | ss_data_d2)begin
            data <= (ss_hs_d2) ? ss_tdata_d2 : data_Do;
        end
    end

    always@(posedge clk)begin
        if(ss_hs_d2 | ss_data_d2)begin
            tap <= tap_Do;
        end
    end
    
    assign mul = tap * data;    

    always@(*)begin
        if(ss_hs_d3)begin
            acc_w = mul;
        end
        else begin
            acc_w = acc + mul;
        end
    end

    always@(posedge clk)begin
        if(ss_hs_d3 | ss_data_d3)begin
            acc <= acc_w;
        end
    end

    always@(posedge clk)begin
        if(data_11_d3)begin
            sm_tdata <= acc_w;
        end
    end

   

endmodule 
