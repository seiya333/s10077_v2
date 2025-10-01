// `default_nettype none

// module top (
//     input  wire FPGA_CLK,   // FPGAの基準クロック (例: 50 MHz)
//     input  wire FPGA_RST,   // 外部リセットスイッチ
//     output wire SENSOR_CLK, // 分周クロック
//     output wire ST          // 出力信号
// );

//     // クロック分周モジュール
//     clk_div #(
//         .DIV(8)
//     ) clk_div_inst (
//         .FPGA_CLK(FPGA_CLK),
//         .FPGA_RST(FPGA_RST),
//         .SENSOR_CLK(SENSOR_CLK)
//     );

//     // ST生成モジュール
//     st_gene #(
//         .MAX(100),
//         .MIN(0),
//         .HIGH(10)
//     ) st_gene_inst (
//         .SENSOR_CLK(SENSOR_CLK),
//         .FPGA_RST(FPGA_RST),
//         .ST(ST)
//     );

// endmodule

module top(
    input  wire FPGA_CLK,   // FPGA の基準クロック
    input  wire FPGA_RST,   // リセット (Active Low なら調整が必要)
    input  wire EOC,        // センサからの EOC 入力

    output wire SENSOR_CLK, // センサ駆動用クロック
    output wire ST,         // センサ駆動用 ST 信号
    output wire EOC_EDGE,    // EOC 立ち上がり検出出力
    // output wire [10:0] EOC_COUNT, // EOC 立ち上がり検出回数
    output wire [5:0] LED
);
    wire [10:0] eoc_count;
    // クロック分周器
    clk_div #(
        .DIV(8)
    ) u_clk_div (
        .FPGA_CLK(FPGA_CLK),
        .FPGA_RST(FPGA_RST),
        .SENSOR_CLK(SENSOR_CLK)
    );

    // ST 信号生成器
    st_gene #(
        .MAX (40000),
        .MIN (0),
        .HIGH(6000)
    ) u_st_gene (
        .SENSOR_CLK(SENSOR_CLK),
        .FPGA_RST(FPGA_RST),
        .ST(ST)
    );

    // EOC 立ち上がり検出器
    eoc_edge_detect u_eoc_edge_detect (
        .FPGA_CLK(FPGA_CLK),
        .FPGA_RST(FPGA_RST),
        .EOC(EOC),
        .EOC_EDGE_FF(EOC_EDGE)
    );

    // EOC カウンタ
    eoc_counter u_eoc_counter (
        .FPGA_CLK(FPGA_CLK),
        .FPGA_RST(FPGA_RST),
        .EOC_EDGE_FF(EOC_EDGE),
        .EOC_COUNT(eoc_count)
    );

    assign LED = eoc_count[5:0]; // 下位 6 ビットを LED に接続
endmodule


module clk_div #(parameter DIV = 8)
    (
        input wire FPGA_CLK,
        input wire FPGA_RST,
        output reg SENSOR_CLK 
    );

    reg [31:0] counter;

    // クロックが立ち上がるたびにカウンターを増やす
    always @(posedge FPGA_CLK or negedge FPGA_RST) begin
        if (!FPGA_RST) begin
            counter <= 0;
            SENSOR_CLK <= 0;
        end
        else if (counter == DIV-1) begin
            counter <= 0;
            SENSOR_CLK <= ~SENSOR_CLK;
        end
        else begin
            counter <= counter + 32'b1;
        end
    end

endmodule

// module st_gene #(
//     parameter MAX = 120000,
//     parameter MIN = 0,
//     parameter HIGH = 6000
// )(
//     input wire SENSOR_CLK,
//     input wire FPGA_RST,
//     output reg ST
// );
//     reg [20:0] st_counter;
//     localparam LOW = MAX - HIGH;

//     always @(posedge SENSOR_CLK or negedge FPGA_RST) begin
//         if (!FPGA_RST) begin
//             st_counter <= 0;
//             ST <= 0;
//         end
//         else begin
//             st_counter <= st_counter + 1;
//             if (st_counter == LOW-1) begin
//                 ST <= 1; // ST信号をHIGHに
//             end
//             else if (st_counter == MAX-1) begin
//                 st_counter <= 0;
//                 ST <= 0; // ST信号をLOWに戻してカウンターをリセット
//             end
//         end
//     end
// endmodule

module st_gene #(
    parameter MAX = 40000,
    parameter MIN = 0,
    parameter HIGH = 6000
)(
    input wire SENSOR_CLK,
    input wire FPGA_RST,
    output wire ST
);
    reg [20:0] st_counter;
    localparam LOW = MAX - HIGH;

    // カウンタの制御 (SENSOR_CLK の立ち上がりエッジでのみ更新)
    always @(posedge SENSOR_CLK or negedge FPGA_RST) begin
        if (!FPGA_RST) begin
            st_counter <= 0;
        end
        else if (st_counter >= MAX-1) begin
            st_counter <= 0;
        end
        else begin
            st_counter <= st_counter + 21'b1;
        end
    end

    // ST信号の制御 (st_counter に基づく組み合わせ回路)
    assign ST = (st_counter >= LOW && st_counter < MAX);

    
endmodule

module eoc_edge_detect (
    input wire FPGA_CLK,
    input wire FPGA_RST,
    input wire EOC,
    output reg EOC_EDGE_FF
);

    reg EOC_DLY;
    wire EOC_DLY_INVERT;
    wire EOC_EDGE;
    
    always @(posedge FPGA_CLK) begin
        if (!FPGA_RST) begin
            // Reset logic
            EOC_DLY <= 0;
        end else begin
            // Main logic
            EOC_DLY <= EOC;
        end
    end
    assign EOC_DLY_INVERT = ~EOC_DLY;
    assign EOC_EDGE = EOC & EOC_DLY_INVERT;
    always @(posedge FPGA_CLK) begin
        if (!FPGA_RST) begin
            // Reset logic
            EOC_EDGE_FF <= 0;
        end else begin
            // Main logic
            EOC_EDGE_FF <= EOC_EDGE;
        end
    end
endmodule

module eoc_counter (
    input wire FPGA_CLK,
    input wire FPGA_RST,
    input wire EOC_EDGE_FF,
    output reg [10:0] EOC_COUNT
);
    reg [10:0] count_reg;

    always @(posedge FPGA_CLK or negedge FPGA_RST) begin
        if (!FPGA_RST) begin
            count_reg <= 0;
        end else if (EOC_EDGE_FF) begin
            count_reg <= ~(count_reg + 11'b1);
        end
    end
    assign EOC_COUNT = count_reg;
endmodule

// module st_gene #(
//     parameter MAX = 120000,
//     parameter MIN = 0,
//     parameter HIGH = 6000
// )(
//     input wire SENSOR_CLK,
//     input wire FPGA_RST,
//     output reg ST
// );
//     reg [16:0] st_counter;
//     localparam LOW = MAX - HIGH;

//     always @(posedge SENSOR_CLK or posedge !FPGA_RST) begin
//         if (!FPGA_RST) begin
//             st_counter <= 0;
//             ST <= 0;
//         end
//         else if (st_counter <= LOW-1) begin
//             st_counter <= st_counter + 17'b1;
//             ST <= 0;
//         end
//         else if (st_counter == MAX-1) begin
//             st_counter <= 0;
//             ST <= 0;
//         end
//         else begin
//             st_counter <= st_counter + 17'b1;
//             ST <= 1;
//         end
//     end
// endmodule
