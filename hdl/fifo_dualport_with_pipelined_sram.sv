module fifo_dualport_with_pipelined_sram #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic             wr_en_i,
    input  logic             rd_en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o,
    output logic             empty_o,
    output logic             full_o
);

    // ======== SRAM В ВИДЕ FIFO С ДОП СИГНАЛАМИ ========

    localparam SRAM_PTR_WIDTH       = $clog2(DEPTH);
    localparam SRAM_MAX_PTR         = DEPTH - 1;
    localparam SRAM_LATENCY         = 5;
    localparam SRAM_POP_COUNT_WIDTH = $clog2(SRAM_LATENCY);
    
    localparam BUF_DEPTH = SRAM_LATENCY + 1;

    // сигналы для логики sram
    // текущая логика превращает sram в fifo с задержкой в 5 тактов
    logic [SRAM_PTR_WIDTH - 1 : 0]       sram_wr_ptr, sram_rd_ptr;
    logic                                sram_wr_ptr_odd_circle, sram_rd_ptr_odd_circle;
    logic                                sram_full, sram_empty;
    logic                                sram_push, sram_pop;
    logic [WIDTH - 1 : 0]                sram_data_o;
    logic                                sram_data_out_vld;
    logic                                sram_wait_out;        // обозначает, что sram сейчас выдает данные (5 тактов на выдачу)
    logic [SRAM_POP_COUNT_WIDTH - 1 : 0] sram_pop_count;       // счетчик количества отправленных запросов на выдачу данных, которые до сих пор не выданы

    sram_dualport_latency_5 #(
        .WIDTH ( WIDTH ),
        .DEPTH ( DEPTH )
    ) i_mem (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .wen_i   (sram_push),
        .ren_i   (sram_pop),
        .waddr_i (sram_wr_ptr),
        .raddr_i (sram_rd_ptr),
        .data_i  (data_i),
        .data_o  (sram_data_o),
        .vld_o   (sram_data_out_vld)
    );

    // логика ptr для записи данных в sram
    always_ff @(posedge clk_i)
    begin
        if (rst_i)
        begin
           sram_wr_ptr <= '0;
           sram_wr_ptr_odd_circle <= 1'b0;
        end
        else if (sram_push)
        begin
            if (sram_wr_ptr == SRAM_MAX_PTR)
            begin
                sram_wr_ptr            <= '0;
                sram_wr_ptr_odd_circle <= ~sram_wr_ptr_odd_circle;
            end
            else
                sram_wr_ptr <= sram_wr_ptr + 1;
        end
    end

    // логика ptr для чтения данных из sram
    always_ff @(posedge clk_i)
    begin
        if (rst_i)
        begin
           sram_rd_ptr <= '0;
           sram_rd_ptr_odd_circle <= 1'b0;
        end
        else if (sram_pop)
        begin
            if (sram_rd_ptr == SRAM_MAX_PTR)
            begin
                sram_rd_ptr            <= '0;
                sram_rd_ptr_odd_circle <= ~sram_rd_ptr_odd_circle;
            end
            else
                sram_rd_ptr <= sram_rd_ptr + 1;
        end
    end

    // логика empty и full у sram
    wire sram_same_circles = (sram_rd_ptr_odd_circle == sram_wr_ptr_odd_circle);
    wire sram_equal_ptrs  = (sram_rd_ptr == sram_wr_ptr);

    assign sram_full  = sram_equal_ptrs & ~sram_same_circles;
    assign sram_empty = sram_equal_ptrs & sram_same_circles;

    // логика счетчика сделанных pop из sram (значение не может быть выше 5, так как latency=5)
    always_ff @(posedge clk_i) 
    begin
        if (rst_i)
            sram_pop_count <= '0;
        else
        begin
            case ({sram_pop, sram_data_out_vld})
                2'b10   : sram_pop_count <= sram_pop_count + 1;
                2'b01   : sram_pop_count <= sram_pop_count - 1;
                default : sram_pop_count <= sram_pop_count;
            endcase
        end
    end

    assign sram_wait_out = (sram_pop_count != SRAM_POP_COUNT_WIDTH'(0));

    // ======== БУФЕР НА ВЫХОДЕ ========

    // сигналы для работы с буфером
    logic                 buf_full, buf_empty;
    logic                 buf_push, buf_pop;
    logic [WIDTH - 1 : 0] buf_data_i;

    logic bypass; // сигнал для обхода sram данными прямо в fifo на выходе

    bram_fifo #(
        .WIDTH( WIDTH ),
        .DEPTH( BUF_DEPTH )
    ) i_fifo (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .push_i  (buf_push),
        .pop_i   (buf_pop),
        .data_i  (buf_data_i),
        .data_o  (data_o),
        .full_o  (buf_full),
        .empty_o (buf_empty)
    );



    // ======== СОЕДИНЕНИЕ ОБОИХ БЛОКОВ В SHOW-AHEAD FIFO ========
    assign bypass     = ~buf_full & sram_empty & ~sram_wait_out;
    assign buf_data_i = bypass ? data_i : sram_data_o; // проброс данных

    assign sram_push  = ~bypass & wr_en_i & ~sram_full;
    assign sram_pop   = ~buf_full & ~sram_empty;

    assign buf_push   = bypass ? wr_en_i : sram_data_out_vld;
    assign buf_pop    = rd_en_i & ~buf_empty;

    assign full_o     = sram_full;
    assign empty_o    = buf_empty;
endmodule