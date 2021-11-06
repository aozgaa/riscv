module Datapath (ALUOp, MemtoReg, MemRead, MemWrite, IorD, RegWrite,
                 IRWrite,
                 PCWrite, PCWriteCond, ALUSrcA, ALUSrcB, PCSource,
                 opcode, clock); // the control inputs + clock
parameter LD = 7'b000_0011, SD = 7'b010_0011;
input [1:0] ALUOp, ALUSrcB; // 2-bit control signals
input MemtoReg, MemRead, MemWrite, IorD, RegWrite, IRWrite, PCWrite,
      PCWriteCond, ALUSrcA, PCSource, clock; // 1-bit control signals
output [6:0] opcode; // opcode is needed as an output by control
reg [63:0] PC, MDR, ALUOut; // CPU state + some temporaries
reg [31:0] Memory[0:1023], IR; // CPU state + some temporaries
wire [63:0] A, B, SignExtendOffset, PCOffset, ALUResultOut, PCValue,
     JumpAddr, Writedata, ALUAin,
     ALUBin, MemOut; // these are signals derived from registers
wire [3:0] ALUCtl; // the ALU control lines
wire Zero; // the Zero out signal from the ALU
initial PC = 0; //start the PC at 0
// Combinational signals used in the datapath
// Read using word address with either ALUOut or PC as the address source
assign MemOut = MemRead ? Memory[(IorD ? ALUOut : PC) >> 2] : 0;
assign opcode = IR[6:0]; // opcode shortcut
// Get the write register data either from the ALUOut or from the MDR
assign Writedata = MemtoReg ? MDR : ALUOut;
// Generate immediate
assign ImmGen = (opcode == LD) ? {{53{IR[31]}}, IR[30:20]} :
       /* (opcode == SD) */{{53{IR[31]}}, IR[30:25], IR[11:7]};
// Generate pc offset for branches
assign PCOffset = {{52{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
// The A input to the ALU is either the rs register or the PC
assign ALUAin = ALUSrcA ? A : PC; // ALU input is PC or A
// Creates an instance of the ALU control unit (see the module defined in Figure B.5.16)
// Input ALUOp is control-unit set and used to describe the instruction class as in Chapter 4
// Input IR[31:25] is the function code field for an ALU instruction
// Output ALUCtl are the actual ALU control bits as in Chapter 4
ALUControl alucontroller (ALUOp, IR[31:25], ALUCtl); // ALU control unit
// Creates a 2-to-1 multiplexor used to select the source of the next PC
// Inputs are ALUResultOut (the incremented PC), ALUOut (the branch address)
// PCSource is the selector input and PCValue is the multiplexor output
Mult2to1 PCdatasrc (ALUResultOut, ALUOut, PCSource, PCValue);
// Creates a 4-to-1 multiplexor used to select the B input of the ALU
// Inputs are register B, constant 4, generated immediate, PC offset
// ALUSrcB is the select or input
// ALUBin is the multiplexor output
Mult4to1 ALUBinput (B, 64'd4, ImmGen, PCOffset, ALUSrcB, ALUBin);
// Creates a RISC-V ALU
// Inputs are ALUCtl (the ALU control), ALU value inputs (ALUAin, ALUBin)
// Outputs are ALUResultOut (the 64-bit output) and Zero (zero detection output)
RISCVALU ALU (ALUCtl, ALUAin, ALUBin, ALUResultOut, Zero); // the ALU
// Creates a RISC-V register file
// Inputs are the rs1 and rs2 fields of the IR used to specify which registers to read,
// Writereg (the write register number), Writedata (the data to be written),
// RegWrite (indicates a write), the clock
// Outputs are A and B, the registers read
registerfile regs (IR[19:15], IR[24:20], IR[11:7], Writedata,
                   RegWrite, A, B, clock); // Register file
// The clock-triggered actions of the datapath
always @(posedge clock)
begin
    if (MemWrite) Memory[ALUOut >> 2] <= B; // Write memory -- must be a store
    ALUOut <= ALUResultOut; // Save the ALU result for use on a later clock cycle
    if (IRWrite) IR <= MemOut; // Write the IR if an instruction fetch
    MDR <= MemOut; // Always save the memory read value
    // The PC is written both conditionally (controlled by PCWrite) and unconditionally
end
endmodule
