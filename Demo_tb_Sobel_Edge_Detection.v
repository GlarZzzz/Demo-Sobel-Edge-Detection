`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 04:47:34 PM
// Design Name: 
// Module Name: Demo_tb_Sobel_Edge_Detection
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


module Demo_tb_Sobel_Edge_Detection();

    localparam integer IMAGE_WIDTH       = 640;
    localparam integer IMAGE_HEIGHT      = 480;
    localparam integer AXIS_TDATA_WIDTH  = 24;
    localparam integer SOBEL_THRESHOLD   = 100; 
    localparam integer CLK_PERIOD        = 10;
    
    parameter INPUT_FILENAME = "input_image_Sobel.hex";
    parameter OUTPUT_FILENAME = "output_image_Sobel.hex";
    
    reg aclk;
    reg aresetn;
    
    reg                         s_axis_tvalid;
    reg [AXIS_TDATA_WIDTH-1:0]  s_axis_tdata;
    reg                         s_axis_tlast;
    reg                         s_axis_tuser;
    wire                        s_axis_tready;

    wire                        m_axis_tvalid;
    wire [AXIS_TDATA_WIDTH-1:0] m_axis_tdata;
    wire                        m_axis_tlast;
    wire                        m_axis_tuser;
    reg                         m_axis_tready;
        

    integer output_file_handle;
    reg [7:0] image_mem [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    integer line_count_out = 0; 
    
        
    // --- Stage 1: Sobel Edge Detector ---
    Demo_Sobel_Edge_Detection_Design_Source #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .AXIS_TDATA_WIDTH(AXIS_TDATA_WIDTH),
        .SOBEL_THRESHOLD(SOBEL_THRESHOLD)
    ) uut_sobel_detector (
        .aclk(aclk),
        .aresetn(aresetn),
        // Input from Second Box Blur
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tready(s_axis_tready),
        // Final Output to Testbench
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tready(m_axis_tready)
    );

    always #(CLK_PERIOD/2) aclk = ~aclk;


    initial begin
        aclk = 0; aresetn = 0;
        s_axis_tvalid = 0; s_axis_tdata = 0;
        s_axis_tlast = 0;  s_axis_tuser = 0;
        m_axis_tready = 0;

        $readmemh(INPUT_FILENAME, image_mem);
        $display("INFO: Input image %s", INPUT_FILENAME ," loaded.");
        output_file_handle = $fopen(OUTPUT_FILENAME, "w");

        #100; aresetn = 1; #100;
        
        fork
            send_image_stream();
            receive_image_stream();
        join

        $fclose(output_file_handle);
        $display("INFO: Output image saved to %s", OUTPUT_FILENAME , ".");
        $display("INFO: Simulation finished successfully after receiving %d lines.", line_count_out);
        $finish;
    end
    

    task send_image_stream;
        integer y, x;
        reg [7:0] pixel_val;
        begin
            @(posedge aclk);
            for (y = 0; y < IMAGE_HEIGHT; y = y + 1) begin
                for (x = 0; x < IMAGE_WIDTH; x = x + 1) begin
                    wait (s_axis_tready == 1'b1);
                    
                    pixel_val = image_mem[y * IMAGE_WIDTH + x];
                    
                    s_axis_tvalid <= 1'b1;
                    s_axis_tdata  <= {pixel_val, pixel_val, pixel_val}; 
                    s_axis_tuser  <= (y == 0 && x == 0); 
                    s_axis_tlast  <= (x == IMAGE_WIDTH - 1);
                    
                    @(posedge aclk);
                end
            end
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
            s_axis_tuser  <= 1'b0;
        end
    endtask
    
    task receive_image_stream;
        begin
            m_axis_tready <= 1'b1;
            
            while (line_count_out < IMAGE_HEIGHT) begin
                @(posedge aclk);
                if (m_axis_tvalid && m_axis_tready) begin
                    $fwrite(output_file_handle, "%h\n", m_axis_tdata[7:0]);
                    
                    if (m_axis_tlast) begin
                        line_count_out = line_count_out + 1;
                        $display("INFO: Received End-of-Line %d of %d.", line_count_out, IMAGE_HEIGHT);
                    end
                end
            end
        end
    endtask

endmodule
