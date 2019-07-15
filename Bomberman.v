// Part 2 skeleton

module lab_6b
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,
		HEX0,
		HEX1   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [12:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B; 
	output [6:0] HEX0, HEX1;  				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	assign go = ~KEY[2];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(SW[10:8]), //BIG KIDS
			.x(x),//BIG KIDS
			.y(y),//BIG KIDS
			.plot(writeEn),//BIG KIDS
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
    
    // Instansiate datapath
    wire ld_x, ld_y, en_draw;
    wire [3:0] incrementer;

	control C0(
        .clk(CLOCK_50),
        
        .go(go),
        .ld_x(ld_x),
	.ld_y(ld_y),
	.en_draw(en_draw),
	.incrementer(incrementer),
    	);

	datapath D0(
        .clk(CLOCK_50),

        .ld_x(ld_x),
	.ld_y(ld_y),
	.en_draw(en_draw),
	.incrementer(incrementer),
        .x(x),//BIG KIDS
	.y(y),//BIG KIDS
	.writeEn(writeEn),//BIG KIDS

	.data_in(SW[7:0])

    	);

    hex_display h1(ld_x, HEX0);
    hex_display h2(ld_y, HEX1);

    // Instansiate FSM control
    
    
endmodule

module control(
    input clk,
    input go,

    output reg  ld_x, ld_y, en_draw,
    output reg  [3:0] incrementer
    );

    reg [5:0] current_state, next_state; 
    
    localparam  S_LOAD_X        = 5'd0,
                S_LOAD_X_WAIT   = 5'd1,
                S_LOAD_Y        = 5'd2,
                S_LOAD_Y_WAIT   = 5'd3,
                S_CYCLE_DRAW        = 5'd4;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
                S_LOAD_X: next_state = go ? S_LOAD_X_WAIT : S_LOAD_X; // Loop in current state until value is input
                S_LOAD_X_WAIT: next_state = go ? S_LOAD_X_WAIT : S_LOAD_Y; // Loop in current state until go signal goes low
                S_LOAD_Y: next_state = go ? S_LOAD_Y_WAIT : S_LOAD_Y; // Loop in current state until value is input
                S_LOAD_Y_WAIT: next_state = go ? S_LOAD_Y_WAIT : S_CYCLE_DRAW;
                S_CYCLE_DRAW: next_state = S_LOAD_X;
            default:     next_state = S_LOAD_X;
        endcase
    end // state_table
   

    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        ld_x = 1'b0;
	     ld_y = 1'b0;
	     en_draw = 1'b0;

        case (current_state)
            S_LOAD_X: begin
                ld_x = 1'b1;
                end
            S_LOAD_Y: begin
                ld_y = 1'b1;
                end
            S_CYCLE_DRAW: begin
                en_draw = 1'b1;
                end
        // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(current_state != S_CYCLE_DRAW) begin
			   incrementer <= 4'b0000;
            current_state <= next_state;
				end
	else
	    begin
	    if(incrementer == 4'b1111)
		current_state <= next_state;
	    else
		incrementer <= incrementer + 4'b0001;
	    end
    end // state_FFS
endmodule

module datapath(
    input clk,
    input [7:0] data_in,
    input ld_x, ld_y, en_draw,
    input [3:0] incrementer, 
    output reg writeEn,
    output reg [7:0] x,
    output reg [6:0] y
    );
    
    reg [7:0] p_x, p_y;
    
    // Registers x, y with respective input logic
    always@(posedge clk) 
	begin begin
            if(ld_x)
                p_x <= data_in;
            if(ld_y)
                p_y <= data_in[6:0];
        end
    end
 

    // If writer
    always @(*)
    begin
        case (en_draw)
            1'd0: begin
                writeEn = 1'b0;
					 x = 4'd0;
		          y = 4'd0;
					 end
            1'd1:begin
                writeEn = 1'b1;
		      x = p_x + incrementer[3:2];
		      y = p_y + incrementer[1:0];
		end
            default: begin 
				writeEn = 1'b0;
				x = 4'd0;
		      y = 4'd0;
				end
        endcase
    end
    
endmodule

module hex_display(IN, OUT);
    input [3:0] IN;
	 output reg [7:0] OUT;
	 
	 always @(*)
	 begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			4'b1010: OUT = 7'b0001000;
			4'b1011: OUT = 7'b0000011;
			4'b1100: OUT = 7'b1000110;
			4'b1101: OUT = 7'b0100001;
			4'b1110: OUT = 7'b0000110;
			4'b1111: OUT = 7'b0001110;
			
			default: OUT = 7'b0111111;
		endcase

	end
endmodule
