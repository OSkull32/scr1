//------------------------------------------------------------------------------
// Monitors the instruction-fetch interface of the SCR1 AHB testbench and,
// when the fetched word is the ADDI instruction, prints its PC.
//------------------------------------------------------------------------------

module scr1_tb_log_cmd();

localparam int unsigned FIFO_DEPTH = 8;

logic [31:0]        addr_fifo [0:FIFO_DEPTH-1];
int unsigned        wr_ptr;
int unsigned        rd_ptr;

wire                clk   = scr1_top_tb_ahb.i_top.i_imem_ahb.clk;
wire                req   = scr1_top_tb_ahb.i_top.i_imem_ahb.imem_req;
wire                ack   = scr1_top_tb_ahb.i_top.i_imem_ahb.imem_req_ack;
wire [31:0]         addr  = scr1_top_tb_ahb.i_top.i_imem_ahb.imem_addr;
wire [1:0]          resp  = scr1_top_tb_ahb.i_top.i_imem_ahb.imem_resp;
wire [31:0]         rdata = scr1_top_tb_ahb.i_top.i_imem_ahb.imem_rdata;

// ADDI: opcode 0010011, funct3 000, 32-bit instruction (low bits 11)
wire is_addi = (rdata[1:0]   == 2'b11)    &&
               (rdata[6:0]   == 7'b0010011) &&
               (rdata[14:12] == 3'b000);

initial begin
    wr_ptr = 0;
    rd_ptr = 0;
end

always_ff @(posedge clk) begin
    // remember the address of every accepted fetch request
    if (req && ack) begin
        addr_fifo[wr_ptr] <= addr;
        wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
    end
    // response with valid data: print PC of the returned instruction
    if (resp == 2'b01) begin
        if (is_addi) begin
            $display("Detected ADDI, PC = 0x%08x (instr = 0x%08x)", addr_fifo[rd_ptr], rdata);
        end
        rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
    end
end

endmodule
