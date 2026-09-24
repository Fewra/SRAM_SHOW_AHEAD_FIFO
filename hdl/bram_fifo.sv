module bram_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input  logic                 clk_i,
    input  logic                 rst_i,
    input  logic                 push_i,
    input  logic                 pop_i,
    input  logic [WIDTH - 1 : 0] data_i,
    
    output logic [WIDTH - 1 : 0] data_o,
    output logic                 full_o,
    output logic                 empty_o
);

    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam MAX_PTR   = DEPTH - 1;

    logic [PTR_WIDTH - 1 : 0] wr_ptr;
    logic [PTR_WIDTH - 1 : 0] rd_ptr;

    logic                     wr_ptr_odd_circle;
    logic                     rd_ptr_odd_circle;

    logic [WIDTH - 1 : 0] data [DEPTH];

    // логика ptr для записи данных
    always_ff @(posedge clk_i)
    begin
        if (rst_i)
        begin
            wr_ptr            <= '0;
            wr_ptr_odd_circle <= 1'b0;
        end
        else if (push_i)
        begin
            if (wr_ptr == MAX_PTR)
            begin
                wr_ptr            <= '0;
                wr_ptr_odd_circle <= ~wr_ptr_odd_circle;
            end
            else
                wr_ptr <= wr_ptr + PTR_WIDTH'(1);
        end
    end

    // логика ptr для чтения данных
    always_ff @(posedge clk_i)
    begin
        if (rst_i)
        begin
            rd_ptr            <= '0;
            rd_ptr_odd_circle <= 1'b0;
        end
        else if (pop_i)
        begin
            if (rd_ptr == MAX_PTR)
            begin
                rd_ptr            <= '0;
                rd_ptr_odd_circle <= ~rd_ptr_odd_circle;
            end
            else
                rd_ptr <= rd_ptr + PTR_WIDTH'(1);
        end
    end

    // логика поступления данных
    always_ff @(posedge clk_i)
    begin
        if (push_i)
            data[wr_ptr] <= data_i;
    end

    // логика вывода данных
    assign data_o = data[rd_ptr];

    // флаги full и empty
    wire equal_ptrs   = (wr_ptr == rd_ptr);
    wire same_circles = (wr_ptr_odd_circle == rd_ptr_odd_circle);

    assign full  = equal_ptrs & ~same_circles;
    assign empty = equal_ptrs & same_circles;

endmodule