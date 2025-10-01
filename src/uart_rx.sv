//`default_nettype none

module uart_rx #(
    parameter clk_divide = 234,
    parameter clk_divide_len = $clog2(clk_divide),
    parameter half_clk_divide = int'(clk_divide/2)
) (
    input wire CLK,
    input wire RST,
    input wire RX,
    output wire [7:0] RX_DATA_OUT,
    output wire RX_CHECK
);

    enum bit [2:0] {
        RX_IDLE = 3'b000,
        RX_START = 3'b001,
        RX_DATA = 3'b010,
        RX_STOP = 3'b011,
        RX_DONE = 3'b100
    } rx_state, rx_next_state;

    logic [clk_divide_len-1:0] clk_div_reg,clk_div_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic [2:0] index_bit_reg,index_bit_next;
    logic transmission_flag, transmission_flag_next;

    always_ff @(posedge CLK) begin
        if (~RST) begin
            rx_state <= RX_IDLE;
            clk_div_reg <= 0;
            rx_data_reg <= 0;
            transmission_flag <= 0;
        end else begin
            rx_state <= rx_next_state;
            clk_div_reg <= clk_div_next;
            rx_data_reg <= rx_data_next;
            index_bit_reg <= index_bit_next;
            transmission_flag <= transmission_flag_next;
        end
    end

    always @(*) begin
        rx_next_state = rx_state;
        clk_div_next = clk_div_reg;
        rx_data_next = rx_data_reg;
        index_bit_next = index_bit_reg;
        transmission_flag_next = transmission_flag;

        case (rx_state)
            // if 
            RX_IDLE: begin
                clk_div_next = 0;
                index_bit_next = 0;
                if (~RX) begin
                    rx_next_state = RX_START;
                end
            end 

            RX_START: begin
                if (clk_div_reg == half_clk_divide) begin
                    if (~RX) begin
                        clk_div_next = 0;
                        rx_next_state = RX_DATA;
                    end else begin
                        rx_next_state = RX_IDLE;
                    end
                end else begin
                    clk_div_next = clk_div_reg + 1'b1;
                    rx_next_state = RX_START;
                end
            end

            RX_DATA: begin
                if (clk_div_reg < clk_divide-1) begin
                    clk_div_next = clk_div_reg + 1'b1;
                    rx_next_state = RX_DATA;
                end else begin
                    clk_div_next = 0;
                    rx_data_next[index_bit_reg] = RX;
                    if (index_bit_reg < 7) begin
                        index_bit_next = index_bit_reg + 1'b1;
                        rx_next_state = RX_DATA;
                    end else begin
                        index_bit_next = 0;
                        rx_next_state = RX_STOP;
                    end
                end
            end

            RX_STOP: begin
                if (clk_div_reg < clk_divide-1) begin
                    clk_div_next = clk_div_reg + 1'b1;
                    rx_next_state = RX_STOP;
                end else begin
                    clk_div_next = 0;
                    transmission_flag_next = 1;
                    rx_next_state = RX_DONE;
                end
            end

            RX_DONE: begin
                transmission_flag_next = 0;
                rx_next_state = RX_IDLE;
            end
            
            default: rx_next_state = RX_IDLE;
        endcase

    end

    assign RX_DATA_OUT = rx_data_reg;
    assign RX_CHECK = transmission_flag;

endmodule
