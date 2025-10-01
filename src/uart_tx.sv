//`default_nettype none

module uart_tx #(
    parameter clk_divide = 234, // 27,000,000 (27Mhz) / 115200 Baud rate
    localparam clk_divide_len = $clog2(clk_divide)
) (
    input wire CLK,
    input wire START,
    input wire RST,
    input wire [7:0] TX_DATA_IN,
    input wire RX_CHECK,
    output wire TX,
    output wire TX_ACTIVE,
    output logic TX_FLAG            // flag to indicate that the transmission is complete
                                    // 0: transmission is not complete, 1: transmission is complete
);

    enum bit [2:0] {
        TX_IDLE = 3'b000,
        TX_START = 3'b001,
        TX_DATA = 3'b010,
        TX_STOP = 3'b011,
        TX_DONE = 3'b100
    } tx_state, tx_next_state;

    logic [clk_divide_len-1:0] clk_div_reg,clk_div_next; //クロックカウント
    logic [7:0] tx_data_reg, tx_data_next; //送信データ
    logic tx_out_reg,tx_out_next; //現在送信中のデータ
    logic [2:0] index_bit_reg,index_bit_next; //送信中の8bitデータ内で、現在のbit位置
    logic pre_start;
    logic tx_flag_reg, tx_flag_next; //送信完了フラグ

    assign TX_ACTIVE = (tx_state == TX_DATA); //データ送信中なのかを判断するフラグ
    assign TX = tx_out_reg;
    assign TX_FLAG = tx_flag_reg;

    always_ff @(posedge CLK) begin
        pre_start <= START;
        if (~RST) begin
            tx_state <= TX_IDLE;
            clk_div_reg <= 0;
            tx_data_reg <= 0;
            tx_out_reg <= 1;
            index_bit_reg <= 0;
            tx_flag_reg <= 0;
        end else begin
            tx_state <= tx_next_state;
            clk_div_reg <= clk_div_next;
            tx_data_reg <= tx_data_next;
            tx_out_reg <= tx_out_next;
            index_bit_reg <= index_bit_next;
            tx_flag_reg <= tx_flag_next;
        end
    end

    always @(*) begin
        tx_next_state = tx_state;
        clk_div_next = clk_div_reg;
        tx_data_next = tx_data_reg;
        tx_out_next = tx_out_reg;
        index_bit_next = index_bit_reg;
        tx_flag_next = tx_flag_reg;

        case (tx_state)
            TX_IDLE: begin
                tx_out_next = 1;            // set the tx line to high
                clk_div_next = 0;           // reset the clock divider
                index_bit_next = 0;         // counter for the bits to be transmitted
                tx_flag_next = 0;           // reset the transmission complete flag
                if (START == 1 && pre_start==0) begin
                    tx_data_next = TX_DATA_IN; // load the data to be transmitted
                    tx_next_state = TX_START;
                end
            end 

            TX_START: begin
                tx_out_next = 0;            // set the tx line to low to start uart transmission
                if (clk_div_reg < clk_divide-1) begin
                    clk_div_next = clk_div_reg + 1'b1;
                    tx_next_state = TX_START;
                end else begin
                    clk_div_next = 0;
                    tx_next_state = TX_DATA;
                end
            end

            TX_DATA: begin
                tx_out_next = tx_data_reg[index_bit_reg]; // set the tx line to the current bit of the data
                if (clk_div_reg < clk_divide-1) begin
                    clk_div_next = clk_div_reg + 1'b1;
                    tx_next_state = TX_DATA;
                end else begin
                    clk_div_next = 0;
                    if (index_bit_reg == 7) begin
                        index_bit_next = 0;
                        tx_next_state = TX_STOP;
                    end else begin
                        index_bit_next = index_bit_reg + 1'b1;
                        tx_next_state = TX_DATA;
                    end
                end
            end

            TX_STOP: begin
                tx_out_next = 1;            // set the tx line to high to stop uart transmission
                if (clk_div_reg < clk_divide-1) begin
                    clk_div_next = clk_div_reg + 1'b1;
                    tx_next_state = TX_STOP;
                end else begin
                    clk_div_next = 0;
                    tx_flag_next =1;
                    tx_next_state = TX_DONE;
                end
            end

            TX_DONE: begin
                tx_flag_next = 0;          // set the transmission complete flag
                tx_next_state = TX_IDLE;
            end
            default: tx_next_state = TX_IDLE;
        endcase
    end

endmodule