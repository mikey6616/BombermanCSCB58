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
			.colour(sprite_colour), //BIG KIDS
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
	wire [2:0] colour, sprite_colour;

	p1control C0(
        .clk(CLOCK_50),
		  .sample_key(sample_scan),
        .key_input(key_input),
        .p_x(p_x),
		  .LEDR(LEDR[0]),
		.p_y(p_y),
		.colour(colour),
		.en_draw(en_draw),
		.incrementer(incrementer)
    	);

	datapath D0(
      .clk(CLOCK_50),
		.en_draw(en_draw),
		.colour(colour),
		.sprite_colour(sprite_colour),
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
	input [7:0] key_input,
	input sample_key,
	
	output LEDR,
    output reg  en_draw,
    output reg  [5:0] incrementer,
	output reg [7:0] p_x,
	output reg [6:0] p_y,
	output reg [2:0] colour
    );
	reg key_sample, draw_bomb1, draw_bomb2, explosion1, explosion2, clear_explosion, check_clock;
	reg [1:0] t_size1, r_size1, b_size1, l_size1, t_size2, r_size2, b_size2, l_size2, clear_inc;
	reg [4:0] bomb_count1, bomb_count2;
	reg [8:0] wall_index; 
    reg [5:0] current_state, next_state;
	reg [9:0] next_pos1, next_pos2, current_pos1, current_pos2, bomb_pos1, bomb_pos2, exp_draw_pos, next_exp_pos;
	initial bomb_pos1 = 10'd0;
	initial bomb_pos2 = 10'd0;
	initial next_pos1 = 10'b0000100001;
	initial next_pos2 = 10'b1001001101;
	reg [14:0] wait_counter;
	reg [299:0] CRATES;
	initial CRATES = 300'b000000000000000000000000011001000110000000000000001000000000000000000100000000000110000000100000011001111111111111111110000000000000000000000111111100001111111000000000000000000000011111111111111111100110000000100000011000000000010000000000000000000010000000000000011001000110000000000000000000000000;
	reg [299:0] EXPLOSIONS;
	initial	EXPLOSIONS = 300'd0;
	assign LEDR = key_sample;
   
	 always@(posedge sample_key)
    begin: FLIPPER
        key_sample <= key_sample ? 1'b0 : 1'b1;
    end // state_FFS
	 
    localparam  	 S_WALLER 		 = 5'd0,
					 S_WAIT          = 5'd1,
					 S_CLEAR_PAST_P1 = 5'd2,
					 S_DRAW_NEW_P1   = 5'd3,
					 S_CLEAR_PAST_P2 = 5'd4,
					 S_DRAW_NEW_P2   = 5'd5,
					 B1_UP		     = 5'd6,
					 B1_RIGHT	     = 5'd7,
					 B1_DOWN		 = 5'd8,
					 B1_LEFT         = 5'd9,
					 B2_UP		     = 5'd10,
					 B2_RIGHT	     = 5'd11,
					 B2_DOWN		 = 5'd12,
					 B2_LEFT         = 5'd13,
					 DRAW_LAST        = 5'd14,
					 SPAWN_P1        = 5'd15,
					 SPAWN_P2        = 5'd16,
					 P1_WIN          = 5'd17,
					 P2_WIN          = 5'd18,
					 P12_WIN         = 5'd19,
				K_UP 			= 8'h75,
				K_DOWN 			= 8'h72,
				K_LEFT 			= 8'h6b,
				K_RIGHT 		= 8'h74,
				W_UP			= 8'h1d,
				A_LEFT		= 8'h1c,
				S_DOWN		= 8'h1b,
				D_RIGHT		= 8'h23,
				PLACE_BOMB1 = 8'h70,
				PLACE_BOMB2 = 8'h2b,
				WALL_MAP = 300'b111111111111111111111000000000000000000110011000000000011001100110000000000110011000000000000000000110000000000000000001100000001111000000011000000011110000000110000000111100000001100000000000000000011000000000000000000110011000000000011001100110000000000110011000000000000000000111111111111111111111;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
					S_WALLER: next_state =  S_WAIT;
					S_WAIT: next_state = S_CLEAR_PAST_P1; // Loop in current state until value is input
					S_CLEAR_PAST_P1: next_state = S_DRAW_NEW_P1; // Loop in current state until go signal goes low
					S_DRAW_NEW_P1: next_state = S_CLEAR_PAST_P2; // Loop in current state until value is input
					S_CLEAR_PAST_P2: next_state = S_DRAW_NEW_P2; // Loop in current state until go signal goes low
					S_DRAW_NEW_P2: next_state = S_WAIT;
					B1_UP: next_state = B1_RIGHT;
					B1_RIGHT: next_state = B1_DOWN;
					B1_DOWN: next_state = B1_LEFT;
					B1_LEFT: next_state = S_WAIT;
					B2_UP: next_state = B2_RIGHT;
					B2_RIGHT: next_state = B2_DOWN;
					B2_DOWN: next_state = B2_LEFT;
					B2_LEFT: next_state = S_WAIT;
					SPAWN_P1: next_state = SPAWN_P2;
					SPAWN_P2: next_state = S_WAIT;
            default:  next_state = S_WAIT;
        endcase
    end // state_table
   
    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
		en_draw = 1'b0;
		colour = 3'b001;
        if (current_state == S_WAIT) begin
			if (sample_key) begin
				case (key_input)
					K_UP: next_pos1 <= current_pos1 - 10'd1;
					K_DOWN: next_pos1 <= current_pos1 + 10'd1;
					K_LEFT: next_pos1 <= current_pos1 - 10'b0000100000;
					K_RIGHT: next_pos1 <= current_pos1 + 10'b0000100000;
					W_UP: next_pos2 <= current_pos2 - 10'd1;
					S_DOWN: next_pos2 <= current_pos2 + 10'd1;
					A_LEFT: next_pos2 <= current_pos2 - 10'b0000100000;
					D_RIGHT: next_pos2 <= current_pos2 + 10'b0000100000;
					PLACE_BOMB1: begin 
						if (bomb_pos1 == 10'd0)
							draw_bomb1 = 1'b1;
					end
					PLACE_BOMB2: begin 
						if (bomb_pos2 == 10'd0)
							draw_bomb2 = 1'b1;
					end
				endcase
			end
			else begin
				draw_bomb1 = 1'b0;
				draw_bomb2 = 1'b0;
			end	
		end
		else
			en_draw = 1'b1;
		
		if(current_state == S_CLEAR_PAST_P1) begin
			if (current_pos1 == bomb_pos1) begin
				colour = 3'b100;
				//draw_bomb1 = 1'b0;
			end
			else
				colour = 3'b000;
		end
		else if (current_state == S_CLEAR_PAST_P2) begin
			if (current_pos2 == bomb_pos2) begin
				colour = 3'b100;
				//draw_bomb2 = 1'b0;
			end
			else
				colour = 3'b000;
		end
		else if (current_state == S_DRAW_NEW_P2 || current_state == SPAWN_P2 || current_state == P2_WIN)
			colour = 3'b010;
		else if (current_state == S_WALLER) begin
			if (WALL_MAP[wall_index])
				colour = 3'b111;
			else if (CRATES[wall_index])
				colour = 3'b110;
			else 
				colour = 3'b000;
		end
		else if (current_state > 5'd5 && current_state < 5'd15) begin
			if (clear_explosion)
				colour = 3'b000;
			else
				colour = 3'b011;
		end else if (current_state == P12_WIN) begin
			colour = 3'b111;
		end
		
		if (current_state == S_DRAW_NEW_P1 || current_state == S_CLEAR_PAST_P1 || current_state == SPAWN_P1) begin
			p_x = current_pos1[9:5] * 8'd8;
			p_y = current_pos1[4:0] * 7'd8;
		end
		else if (current_state == S_DRAW_NEW_P2 || current_state == S_CLEAR_PAST_P2 || current_state == SPAWN_P2) begin
			p_x = current_pos2[9:5] * 8'd8;
			p_y = current_pos2[4:0] * 7'd8;
		end
		else begin
			p_x = exp_draw_pos[9:5] * 8'd8;
			p_y = exp_draw_pos[4:0] * 7'd8;
		end
		
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
		  if (draw_bomb1) begin
			bomb_count1 <= 5'b11111;
			bomb_pos1 <= current_pos1;
		  end
		  if(draw_bomb2) begin
			bomb_count2 <= 5'b11111;
			bomb_pos2 <= current_pos2;
		  end
		  if (current_state == S_WALLER) begin
				if(incrementer == 6'b111111) begin
					if (wall_index < 9'd299) begin
						wall_index <= wall_index + 1'b1;
						if (exp_draw_pos[9:5] < 5'd19)
							exp_draw_pos <= exp_draw_pos + 10'b0000100000;
						else begin
							exp_draw_pos <= exp_draw_pos[4:0] + 10'd1;
						end
					end
					else begin
						current_pos2 <= 10'b1001001101;
						current_pos1 <= 10'b0000100001;
						current_state <= SPAWN_P1;
					end
					incrementer <= 6'd0;
				end
				else
					incrementer <= incrementer + 6'b000001;
		  end
		  else begin
			  if(incrementer == 6'b111111) begin
					case (current_state)
						S_CLEAR_PAST_P1: begin
								current_pos1 <= next_pos1;
								current_state <= next_state;
						end
						S_CLEAR_PAST_P2: begin
								current_pos2 <= next_pos2;
								current_state <= next_state;
						end
						S_DRAW_NEW_P1:
							current_state <= next_pos2 != current_pos2 && WALL_MAP[next_pos2[4:0] * 9'd20 + next_pos2[9:5]] == 1'b0 && next_pos2 != bomb_pos1 && CRATES[next_pos2[4:0] * 9'd20 + next_pos2[9:5]] == 1'b0 ? next_state : S_WAIT;
						S_WAIT: begin
							check_clock <= check_clock ? 1'b0 : 1'b1;
							if (wait_counter == 15'b111111111111111) begin
								if (next_pos1 != current_pos1 && WALL_MAP[next_pos1[4:0] * 9'd20 + next_pos1[9:5]] == 1'b0 && next_pos1 != bomb_pos2 && CRATES[next_pos1[4:0] * 9'd20 + next_pos1[9:5]] == 1'b0)
									current_state <= next_state;
								else if (next_pos2 != current_pos2 && WALL_MAP[next_pos2[4:0] * 9'd20 + next_pos2[9:5]] == 1'b0 && next_pos2 != bomb_pos1 && CRATES[next_pos2[4:0] * 9'd20 + next_pos2[9:5]] == 1'b0)
									current_state <= S_CLEAR_PAST_P2;
								
								if (bomb_count1 > 5'd0)
									bomb_count1 <= bomb_count1 - 1'b1;
								else if (bomb_pos1 != 10'd0 && check_clock == 1'b1) begin
									if (explosion1 == 1'b0) begin
										clear_explosion <= 1'b0;
										explosion1 <= 1'b1;
										bomb_count1 <= 5'b11111;
										current_state <= B1_UP;
										exp_draw_pos <= bomb_pos1;
										next_exp_pos <= bomb_pos1 - 1;
									end else begin
										clear_explosion <= 1'b1;
										clear_inc <= 2'd0;
										explosion1 <= 1'b0;
										current_state <= B1_UP;
										exp_draw_pos <= bomb_pos1;
									end
								end
								if (bomb_count2 > 5'd0)
									bomb_count2 <= bomb_count2 - 1'b1;
								else if (bomb_pos2 != 10'd0 && check_clock == 1'b0) begin
									if (explosion2 == 1'b0) begin
										clear_explosion <= 1'b0;
										explosion2 <= 1'b1;
										bomb_count2 <= 5'b11111;
										current_state <= B2_UP;
										exp_draw_pos <= bomb_pos2;
										next_exp_pos <= bomb_pos2 - 1;
									end else begin
										clear_explosion <= 1'b1;
										clear_inc <= 2'd0;
										explosion2 <= 1'b0;
										current_state <= B2_UP;
										exp_draw_pos <= bomb_pos2;
									end
								end
								//PAste
								wait_counter <= 15'd0;
							end
							else
								wait_counter <= wait_counter + 15'd1;
						end
						B1_UP: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == t_size1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos1;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos - 1;
								end
							end
							else begin
								if (t_size1 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 + 10'b0000100000;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 + 10'b0000100000;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									t_size1 <= t_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos1 + 10'b0000100000;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									t_size1 <= t_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos - 1;
								end
							end
						end
						B1_RIGHT: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == r_size1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos1;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos + 10'b0000100000;
								end
							end
							else begin
								if (r_size1 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 + 1;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 + 1;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									r_size1 <= r_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos1 + 1;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									r_size1 <= r_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos + 10'b0000100000;
								end
							end
						end
						B1_DOWN: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == b_size1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos1;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos + 1;
								end
							end
							else begin
								if (b_size1 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 - 10'b0000100000;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1 - 10'b0000100000;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									b_size1 <= b_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos1 - 10'b0000100000;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									b_size1 <= b_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos + 1;
								end
							end
						end
						B1_LEFT: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == l_size1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos1;
									t_size1 <= 2'd0;
									r_size1 <= 2'd0;
									b_size1 <= 2'd0;
									l_size1 <= 2'd0;
									bomb_pos1 <= 10'd0;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos - 10'b0000100000;
								end
							end
							else begin
								if (l_size1 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos1;
									next_exp_pos <= bomb_pos1;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									l_size1 <= l_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos1;
									current_state <= DRAW_LAST;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									l_size1 <= l_size1 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos - 10'b0000100000;
								end
							end
						end
						B2_UP: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == t_size2) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos2;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos - 1;
								end
							end
							else begin
								if (t_size2 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 + 10'b0000100000;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 + 10'b0000100000;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									t_size2 <= t_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos2 + 10'b0000100000;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									t_size2 <= t_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos - 1;
								end
							end
						end
						B2_RIGHT: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == r_size2) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos2;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos + 10'b0000100000;
								end
							end
							else begin
								if (r_size2 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 + 1;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 + 1;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									r_size2 <= r_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos2 + 1;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									r_size2 <= r_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos + 10'b0000100000;
								end
							end
						end
						B2_DOWN: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == b_size2) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos2;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos + 1;
								end
							end
							else begin
								if (b_size2 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 - 10'b0000100000;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2 - 10'b0000100000;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									b_size2 <= b_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos2 - 10'b0000100000;
									current_state <= next_state;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									b_size2 <= b_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos + 1;
								end
							end
						end
						B2_LEFT: begin
							//NONESENSE
							if (clear_explosion) begin
								if (clear_inc == l_size2) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= 2'd0;
									exp_draw_pos <= bomb_pos2;
									t_size2 <= 2'd0;
									r_size2 <= 2'd0;
									b_size2 <= 2'd0;
									l_size2 <= 2'd0;
									bomb_pos2 <= 10'd0;
									current_state <= next_state;
								end else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b0;
									clear_inc <= clear_inc + 1;
									exp_draw_pos <= exp_draw_pos - 10'b0000100000;
								end
							end
							else begin
								if (l_size2 == 2'd3) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2;
									current_state <= next_state;
								end
								else if (WALL_MAP[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									exp_draw_pos <= bomb_pos2;
									next_exp_pos <= bomb_pos2;
									current_state <= next_state;
								end
								else if (CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] == 1'b1) begin
									CRATES[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b0;
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									EXPLOSIONS[next_exp_pos[4:0] * 9'd20 + next_exp_pos[9:5]] <= 1'b1;
									l_size2 <= l_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= bomb_pos2;
									current_state <= DRAW_LAST;
								end
								else begin
									EXPLOSIONS[exp_draw_pos[4:0] * 9'd20 + exp_draw_pos[9:5]] <= 1'b1;
									l_size2 <= l_size2 + 1;
									exp_draw_pos <= next_exp_pos;
									next_exp_pos <= next_exp_pos - 10'b0000100000;
								end
							end
						end
						default: begin 
							if (current_state > 5'd16) begin
								if (exp_draw_pos[9:5] < 5'd19)
									exp_draw_pos <= exp_draw_pos + 10'b0000100000;
								else begin
									exp_draw_pos <= exp_draw_pos[4:0] + 10'd1;
								end
							end
							else
								current_state <= next_state;
						end
					endcase
					incrementer <= 6'd0;
				end
			 else
				incrementer <= incrementer + 6'd1;
			if (explosion1 || explosion2) begin
				if (EXPLOSIONS[current_pos1[4:0] * 9'd20 + current_pos1[9:5]] == 1'b1 && EXPLOSIONS[current_pos2[4:0] * 9'd20 + current_pos2[9:5]] == 1'b1) begin
					current_state <= P12_WIN;
					exp_draw_pos <= 10'd0;
					explosion1 <= 1'b0;
					explosion2 <= 1'b0;
				end
				else if (EXPLOSIONS[current_pos1[4:0] * 9'd20 + current_pos1[9:5]] == 1'b1) begin
					current_state <= P2_WIN;
					exp_draw_pos <= 10'd0;
					explosion1 <= 1'b0;
					explosion2 <= 1'b0;
				end
				else if (EXPLOSIONS[current_pos2[4:0] * 9'd20 + current_pos2[9:5]] == 1'b1) begin
					current_state <= P1_WIN;
					exp_draw_pos <= 10'd0;
					explosion1 <= 1'b0;
					explosion2 <= 1'b0;
				end
			end
		end
    end // state_FFS
endmodule

module datapath(
    input clk,
    input  en_draw,
    input [5:0] incrementer, 
	input [2:0] colour,
	input [7:0] p_x,
	input [6:0] p_y,
	
    output reg writeEn,
	output reg [2:0] sprite_colour,
    output reg [7:0] x,
    output reg [6:0] y
    );
	localparam  	 PLAYER 		 = 64'b1100001110000001001001000000000000000000100000010001100000011000,
					 WALL  	 		 = 64'b1000000100000000000000000000000000000000000000000000000010000001,
					 CRATE 		     = 64'b0000000001111110010110100101101001011010010110100111111000000000,
					 BOMB 		     = 64'b1100001110000101000000100000000000000000000000101000010111000011,
					 EXPLOSION 		 = 64'b0111110110101010110101011010101111010101101010110101010110111110;

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
		case (colour)
		3'b111: sprite_colour = WALL[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		3'b010: sprite_colour = PLAYER[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		3'b001: sprite_colour = PLAYER[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		3'b100: sprite_colour = BOMB[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		3'b011: sprite_colour = EXPLOSION[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		3'b110: sprite_colour = CRATE[incrementer[2:0] * 6'd8 + incrementer[5:3]] == 1'b1 ? 3'b000 : colour;
		default: sprite_colour = colour;
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