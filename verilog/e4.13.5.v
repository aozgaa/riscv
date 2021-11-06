module RISCVCPU (clock);
parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, ALUop
          = 7'b001_0011;
input clock; // the clock is an external input
// The architecturally visible registers and scratch registers for
implementation
    reg [63:0] PC, Regs[0:31], ALUOut, MDR, A, B;
reg [31:0] Memory [0:1023], IR;
reg [2:0] state; // processor state
wire [6:0] opcode; // use to get opcode easily
wire [63:0] ImmGen; // used to generate immediate
assign opcode = IR[6:0]; // opcode is lower 7 bits
assign ImmGen = (opcode == LD) ? {{53{IR[31]}}, IR[30:20]} : /* (opcode == SD) */{{53{IR[31]}}, IR[30:25], IR[11:7]};
assign PCOffset = {{52{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
// set the PC to 0 and start the control in state 1
initial begin PC = 0; state = 1; end
// The state machine--triggered on a rising clock
always @(posedge clock)
begin
    Regs[0] <= 0; // shortcut way to make sure R0 is always 0
    case (state) //action depends on the state
        1: begin
            // first step: fetch the instruction, increment PC, go to next state
            IR <= Memory[PC >> 2];
            PC <= PC + 4;
            state <= 2; // next state
        end
        2: begin
            // second step: Instruction decode, register fetch, also
            compute branch address
            A <= Regs[IR[19:15]];
            B <= Regs[IR[24:20]];
            ALUOut <= PC + PCOffset; // compute PC-relative branch target
            state <= 3;
        end
        3: begin
            // third step: Load-store execution, ALU execution, Branch completion
            if ((opcode == LD) || (opcode == SD))
            begin
                ALUOut <= A + ImmGen; // compute effective address
                state <= 4;
            end
            else if (opcode == ALUop)
            begin
                case (IR[31:25]) // case for the various R-type instructions
                    0: ALUOut <= A + B; // add operation
                    default: ; // other R-type operations: subtract, SLT, etc.
                endcase
                state <= 4;
            end
            else if (opcode == BEQ)
            begin
                if (A == B) begin
                    PC <= ALUOut; // branch taken--update PC
                end
                state <= 1;
            end
            else ; // other opcodes or exception for undefined instruction would go here
        end
        4: begin
            if (opcode == ALUop)
            begin
                // ALU Operation
                Regs[IR[11:7]] <= ALUOut; // write the result
                state <= 1;
            end // R-type finishes
            else if (opcode == LD)
            begin
                // load instruction
                MDR <= Memory[ALUOut >> 2]; // read the memory
                state <= 5; // next state
            end
            else if (opcode == SD)
            begin
                // store instruction
                Memory[ALUOut >> 2] <= B; // write the memory
                state <= 1; // return to state 1
            end
            else // other instructions go here
            begin
            end
        end
        5: begin
            // LD is the only instruction still in execution
            Regs[IR[11:7]] <= MDR; // write the MDR to the register
            state <= 1;
        end // complete an LD instruction
    endcase
end
endmodule
