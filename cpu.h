/* define opcodes for proto16 cpu */
/* (C) k theis 2/2019 */

const char opcodes[256][8] = {
	"nop","x","x","x","x","x","x","x",
	"set","x","x","x","x","x","x","x",
	"clr","x","x","x","x","x","x","x",
	"trap","x","x","x","x","x","x","x",
	"halt","x","x","x","x","x","x","x",
	"reset","x","x","x","x","x","x","x",
	"x","x","x","x","x","x","x","x",
	"load","x","x","x","x","x","x","x",
	"and","x","x","x","x","x","x","x",
	"or","x","x","x","x","x","x","x",
	"xor","x","x","x","x","x","x","x",
	"sll","x","x","x","x","x","x","x",
	"srl","x","x","x","x","x","x","x",
	"comp","x","x","x","x","x","x","x",
	"add","x","x","x","x","x","x","x",
	"sub","x","x","x","x","x","x","x",
	"mul","x","x","x","x","x","x","x",
	"div","x","x","x","x","x","x","x",
	"cmp","x","x","x","x","x","x","x",
	"test","x","x","x","x","x","x","x",
	"swap","x","x","x","x","x","x","x",
	"x","x","x","x","x","x","x","x",
	"inc","x","x","x","x","x","x","x",
	"dec","x","x","x","x","x","x","x",
	"push","x","x","x","x","x","x","x",
	"pop","x","x","x","x","x","x","x",
	"jmp","jz","jnz","jc","jnc","jm","jp","jov",
	"x","x","x","x","x","x","x","x",
	"call","cz","cnz","cc","cnc","cm","cp","cov",
	"x","x","x","x","x","x","x","x",
	"ret","rz","rnz","rc","rnc","rm","rp","rov",
	"x","x","x","x","x","x","x","x"
	};

/* number of seperate operands per instruction */
const int opcodesize[] = {
	1,0,0,0,0,0,0,0,	// nop
	2,0,0,0,0,0,0,0,	// set
	2,0,0,0,0,0,0,0,	// clr
	1,0,0,0,0,0,0,0,	// trap
	1,0,0,0,0,0,0,0,	// halt
	1,0,0,0,0,0,0,0,	// reset
	0,0,0,0,0,0,0,0,	// 
	3,0,0,0,0,0,0,0,	// load
	3,0,0,0,0,0,0,0,	// and
	3,0,0,0,0,0,0,0,	// or
	3,0,0,0,0,0,0,0,	// xor
	2,0,0,0,0,0,0,0,	// sll
	2,0,0,0,0,0,0,0,	// srl
	2,0,0,0,0,0,0,0,	// comp
	3,0,0,0,0,0,0,0,	// add
	3,0,0,0,0,0,0,0,	// sub
	3,0,0,0,0,0,0,0,	// mul
	3,0,0,0,0,0,0,0,	// div
	3,0,0,0,0,0,0,0,	// cmp
	2,0,0,0,0,0,0,0,	// test
	2,0,0,0,0,0,0,0,	// swap
	0,0,0,0,0,0,0,0,	//
	2,0,0,0,0,0,0,0,	// inc
	2,0,0,0,0,0,0,0,	// dec
	2,0,0,0,0,0,0,0,	// push
	2,0,0,0,0,0,0,0,	// pop
	4,4,4,4,4,4,4,4,	// jump
	0,0,0,0,0,0,0,0,	//
	4,4,4,4,4,4,4,4,	// call
	0,0,0,0,0,0,0,0,	//
	1,1,1,1,1,1,1,1,	// ret
	0,0,0,0,0,0,0,0
	};

const char reg[16][6] = {
	"#",	// immediate
	"[",	// memory
	"R0","R1","R2","R3","R4","R5","R6","R7",
	"(IX)","(IY)","IX","IY","SP","PC"
	};

const char flags[8][8] = {
	"Z",
	"CY",
	"S",
	"OV",
	"INTE",
	"INTF",
	"K",
	"X"
	};
