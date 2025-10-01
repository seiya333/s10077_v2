// module eoc_edge_detect (
//     input wire FPGA_CLK,
//     input wire FPGA_RST,
//     input wire EOC,
//     output reg EOC_EDGE_FF
// );

//     reg EOC_DLY;
//     wire EOC_DLY_INVERT;
//     wire EOC_EDGE;

//     always @(posedge FPGA_CLK) begin
//         if (FPGA_RST) begin
//             // Reset logic
//             EOC_DLY <= 0;
//         end else begin
//             // Main logic
//             EOC_DLY <= EOC;
//         end
//     end
//     assign EOC_DLY_INVERT = ~EOC_DLY;
//     assign EOC_EDGE = EOC & EOC_DLY_INVERT;
//     always @(posedge FPGA_CLK) begin
//         if (FPGA_RST) begin
//             // Reset logic
//             EOC_EDGE_FF <= 0;
//         end else begin
//             // Main logic
//             EOC_EDGE_FF <= EOC_EDGE;
//         end
//     end
// endmodule