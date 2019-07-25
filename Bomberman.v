// Part 2 skeleton

module Bomberman(
	input	CLOCK_50,				//	50 MHz
	input 	PS2_KBCLK,
	input 	PS2_KBDAT,

	output[17:0]		LEDR,	
	output			VGA_CLK,   				//	VGA Clock
	output			VGA_HS,					//	VGA H_SYNC
	output			VGA_VS,					//	VGA V_SYNC
	output			VGA_BLANK_N,				//	VGA BLANK
	output			VGA_SYNC_N,				//	VGA SYNC
	output	[9:0]	VGA_R,   				//	VGA Red[9:0]
	output	[9:0]	VGA_G,	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B, 
	output [6:0] HEX0, HEX1  				//	VGA Blue[9:0]
	);
	
	wire [7:0] key_input;
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire sample_scan, upper_case;
	
	keyboard kb(CLOCK_50, 1'b0,PS2_KBDAT, PS2_KBCLK,key_input, sample_scan, upper_case);

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(1'b1),
			.clock(CLOCK_50),
			.colour(colour), //BIG KIDS
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
    wire en_draw;
    wire [5:0] incrementer;
	wire [7:0] p_x;
	wire [6:0] p_y;
	wire [2:0] colour;

	p1control C0(
        .clk(CLOCK_50),
		  .sample_key(sample_scan),
        .key_input(key_input),
        .p_x(p_x),
		  .LEDR(LEDR[0]),
		.p_y(p_y),
		.colour(colour),
		.en_draw(en_draw),
		.incrementer(incrementer),
    	);

	datapath D0(
      .clk(CLOCK_50),
		.en_draw(en_draw),
		.incrementer(incrementer),
		.p_x(p_x),//BIG KIDS
		.p_y(p_y),//BIG KIDS
        .x(x),//BIG KIDS
		.y(y),//BIG KIDS
		.writeEn(writeEn)//BIG KIDS
    	);
		
	hex_display h0(key_input[3:0],HEX0);
	hex_display h1(key_input[7:4],HEX1);
    // Instansiate FSM control
    
    
endmodule

module p1control(
    input clk,
    input go,
	input [7:0] key_input,
	input sample_key,
	
	output LEDR,
    output reg  en_draw,
    output reg  [5:0] incrementer,
	output reg [7:0] p_x,
	output reg [6:0] p_y,
	output reg [2:0] colour
    );
	reg key_sample;
    reg [5:0] current_state, next_state;
	reg [9:0] current_pos, next_pos; 
	reg [14:0] wait_counter;
	
	assign LEDR = key_sample;
    
	 always@(posedge sample_key)
    begin: FLIPPER
        key_sample <= key_sample ? 1'b0 : 1'b1;
    end // state_FFS
	 
    localparam  S_WAIT          = 5'd0,
                S_CLEAR_PAST    = 5'd1,
                S_DRAW_NEW      = 5'd2,
				K_UP 			= 8'h75,
				K_DOWN 			= 8'h72,
				K_LEFT 			= 8'h6b,
				K_RIGHT 		= 8'h74;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
                S_WAIT: next_state = S_CLEAR_PAST; // Loop in current state until value is input
                S_CLEAR_PAST: next_state = S_DRAW_NEW; // Loop in current state until go signal goes low
                S_DRAW_NEW: next_state = S_WAIT; // Loop in current state until value is input
            default:  next_state = S_WAIT;
        endcase
    end // state_table
   
    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
		en_draw = 1'b0;
		colour = 3'b001;
        if (current_state == S_WAIT && sample_key) begin
			case (key_input)
				K_UP: next_pos = current_pos - 10'd1;
				K_DOWN: next_pos = current_pos + 10'd1;
				K_LEFT: next_pos = current_pos - 10'b0000100000;
				K_RIGHT: next_pos = current_pos + 10'b0000100000;
				default: next_pos = current_pos;
			endcase
		end
		else
			en_draw = 1'b1;
		if(current_state == S_CLEAR_PAST)
			colour = 3'b000;
		p_x = current_pos[9:5] * 8'd8;
		p_y = current_pos[4:0] * 7'd8;
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(incrementer == 6'b111111)begin
				if(current_state == S_CLEAR_PAST)
					current_pos <= next_pos;
				if(current_state == S_WAIT) begin
					if (wait_counter == 15'b111111111111111) begin
						current_state <= next_pos != current_pos? next_state : current_state;
						wait_counter <= 15'd0;
					end
					else
						wait_counter <= wait_counter + 15'd1;
				end
				else
					current_state <= next_state;
				incrementer <= 6'b000000;
			end
	    else
			incrementer <= incrementer + 6'b000001;
    end // state_FFS
endmodule

module datapath(
    input clk,
    input  en_draw,
    input [5:0] incrementer, 
	input [7:0] p_x,
	input [6:0] p_y,
	
    output reg writeEn,
    output reg [7:0] x,
    output reg [6:0] y
    );
 

    // If writer
    always @(*)
    begin
		writeEn = 1'b0;
		x = 4'd0;
		y = 4'd0;		 
		if (en_draw == 1'b1)	begin 
			writeEn = 1'b1;
			x = p_x + incrementer[5:3];
			y = p_y + incrementer[2:0];
		end
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
