`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 03:42:15 PM
// Design Name: 
// Module Name: Demo_Sobel_Edge_Detection _Design_Source
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Demo_Sobel_Edge_Detection_Design_Source #(

    parameter integer IMAGE_WIDTH         = 640,
    parameter integer IMAGE_HEIGHT        = 480,
    parameter integer AXIS_TDATA_WIDTH    = 24,
    parameter integer SOBEL_THRESHOLD     = 100
)
(

    input wire aclk,
    input wire aresetn,

    input wire                          s_axis_tvalid,
    input wire [AXIS_TDATA_WIDTH-1:0]   s_axis_tdata,
    input wire                          s_axis_tlast,
    input wire                          s_axis_tuser,
    output reg                          s_axis_tready,

    output reg                          m_axis_tvalid,
    output reg [AXIS_TDATA_WIDTH-1:0]   m_axis_tdata,
    output reg                          m_axis_tlast,
    output reg                          m_axis_tuser,
    input wire                          m_axis_tready

    );
    
    localparam integer DATA_WIDTH_8BIT = 8;
    localparam integer TOTAL_PIPELINE_DELAY = 5;

    reg [$clog2(IMAGE_WIDTH)-1:0]  x_cnt;
    reg [$clog2(IMAGE_HEIGHT)-1:0] y_cnt;
    reg [DATA_WIDTH_8BIT-1:0] line_buffer1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH_8BIT-1:0] line_buffer2 [0:IMAGE_WIDTH-1];
    wire [DATA_WIDTH_8BIT-1:0] lb1_data;
    wire [DATA_WIDTH_8BIT-1:0] lb2_data;
    reg [DATA_WIDTH_8BIT-1:0] window [0:2][0:2];
    wire [DATA_WIDTH_8BIT-1:0] s_axis_tdata_8bit = s_axis_tdata[DATA_WIDTH_8BIT-1:0];
    wire s_axis_fire = s_axis_tvalid && s_axis_tready;
    
    reg [DATA_WIDTH_8BIT-1:0] window_stage0 [0:2][0:2];
    reg signed [11:0] gx_stage1, gy_stage1;
    reg [12:0] grad_mag_stage2;
    reg [DATA_WIDTH_8BIT-1:0] out_pixel_stage3;
    
    reg border_pixel_pipe_0, roi_pipe_0;
    reg border_pixel_pipe_1, roi_pipe_1;
    reg border_pixel_pipe_2, roi_pipe_2;
    
    reg [TOTAL_PIPELINE_DELAY-1:0] valid_pipe, eol_pipe, user_pipe;

    wire signed [11:0] gx_temp;
    wire signed [11:0] gy_temp;
    wire in_roi_temp;
    wire is_border_temp;
    wire [11:0] abs_gx_stage2;
    wire [11:0] abs_gy_stage2;

    always @(*) s_axis_tready = m_axis_tready || !m_axis_tvalid;
    
    always @(posedge aclk) begin 
    if(!aresetn) begin 
        x_cnt <= 0; y_cnt <= 0;     
    end 
    else if (s_axis_fire) begin 
            if (s_axis_tlast) begin 
                 x_cnt <= 0; y_cnt <= (y_cnt == IMAGE_HEIGHT - 1) ? 0 : y_cnt + 1; 
             end 
             else begin 
             x_cnt <= x_cnt + 1; 
             end 
        end 
    end
    assign lb1_data = line_buffer1[x_cnt];
    assign lb2_data = line_buffer2[x_cnt];
    always @(posedge aclk) begin 
        if (s_axis_fire) 
        begin 
            line_buffer1[x_cnt] <= s_axis_tdata_8bit; 
            line_buffer2[x_cnt] <= lb1_data; 
           end 
       end
    always @(posedge aclk) begin 
    if (s_axis_fire) begin 
            window[0][0] <= window[0][1]; 
            window[0][1] <= window[0][2]; 
            window[1][0] <= window[1][1]; 
            window[1][1] <= window[1][2]; 
            window[2][0] <= window[2][1]; 
            window[2][1] <= window[2][2]; 
            window[0][2] <= lb2_data; 
            window[1][2] <= lb1_data; 
            window[2][2] <= s_axis_tdata_8bit; 
        end 
    end


    assign in_roi_temp    = (x_cnt > 0) && (x_cnt < 640);
    assign is_border_temp = (y_cnt < 1) || (y_cnt > (IMAGE_HEIGHT - 2)) || (x_cnt < 1) || (x_cnt > (IMAGE_WIDTH - 2));      
    
    assign gx_temp = ($signed(window_stage0[0][2]) - $signed(window_stage0[0][0])) 
                   + (($signed(window_stage0[1][2]) - $signed(window_stage0[1][0])) << 1) 
                   + ($signed(window_stage0[2][2]) - $signed(window_stage0[2][0]));

    assign gy_temp = ($signed(window_stage0[2][0]) + ($signed(window_stage0[2][1]) << 1) + $signed(window_stage0[2][2])) 
                   - ($signed(window_stage0[0][0]) + ($signed(window_stage0[0][1]) << 1) + $signed(window_stage0[0][2]));

    assign abs_gx_stage2 = (gx_stage1 < 0) ? -gx_stage1 : gx_stage1;
    assign abs_gy_stage2 = (gy_stage1 < 0) ? -gy_stage1 : gy_stage1;
    
    always @(posedge aclk) begin
        if (s_axis_fire) begin
            window_stage0[0][0] <= window[0][0]; window_stage0[0][1] <= window[0][1]; window_stage0[0][2] <= window[0][2];
            window_stage0[1][0] <= window[1][0]; window_stage0[1][1] <= window[1][1]; window_stage0[1][2] <= window[1][2];
            window_stage0[2][0] <= window[2][0]; window_stage0[2][1] <= window[2][1]; window_stage0[2][2] <= window[2][2];
            border_pixel_pipe_0 <= is_border_temp; roi_pipe_0 <= in_roi_temp;
            
            gx_stage1 <= gx_temp; 
            gy_stage1 <= gy_temp;
            border_pixel_pipe_1 <= border_pixel_pipe_0; roi_pipe_1 <= roi_pipe_0;

            grad_mag_stage2 <= abs_gx_stage2 + abs_gy_stage2;
            border_pixel_pipe_2 <= border_pixel_pipe_1; roi_pipe_2 <= roi_pipe_1;

            out_pixel_stage3 <= (roi_pipe_2 && !border_pixel_pipe_2 && grad_mag_stage2 > SOBEL_THRESHOLD) ? 8'd255 : 8'd0;
        end
    end

    always @(posedge aclk) begin 
    if (!aresetn) begin 
        valid_pipe <= 0; 
        eol_pipe <= 0; 
        user_pipe <= 0; 
    end 
    else begin 
        valid_pipe <= {valid_pipe[TOTAL_PIPELINE_DELAY-2:0],s_axis_fire}; 
        eol_pipe   <= {eol_pipe[TOTAL_PIPELINE_DELAY-2:0],s_axis_tlast}; 
        user_pipe  <= {user_pipe[TOTAL_PIPELINE_DELAY-2:0],s_axis_tuser}; 
        end 
    end
    always @(posedge aclk) begin 
    if (!aresetn) begin 
        m_axis_tvalid <= 1'b0; 
        m_axis_tdata <= 0; 
        m_axis_tlast <= 1'b0;
        m_axis_tuser <= 1'b0; 
    end 
    else begin 
        if (m_axis_tready || !m_axis_tvalid) begin 
            m_axis_tvalid <= valid_pipe[TOTAL_PIPELINE_DELAY-1]; 
            m_axis_tlast  <= eol_pipe[TOTAL_PIPELINE_DELAY-1]; 
            m_axis_tuser  <= user_pipe[TOTAL_PIPELINE_DELAY-1]; 
            m_axis_tdata  <= {out_pixel_stage3,out_pixel_stage3,out_pixel_stage3}; 
              end 
         end 
    end

endmodule
