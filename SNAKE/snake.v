module snake(KEY, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
 CLOCK_50, VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK, VGA_R, VGA_G, VGA_B,
 PS2_DAT, PS2_CLK);
	
	input CLOCK_50;
	input [3:0] KEY;
	input PS2_CLK, PS2_DAT;
	
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK;				//	VGA BLANK
	output reg	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output reg	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output reg 	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	
	wire [9:0] xPosition, yPosition, randomX, randomY;
	wire InDisplayArea;
	wire [7:0] score;
	wire R, G, B;
	wire [3:0] direction;
	wire slow_VGA_CLK; // 25MHz clk
	wire food, border, game_over;  
	wire [6:0] size;  
	wire [7:0] keyValue;
	wire snakeHead, snakeBody, update;
	wire resetn;
	
	assign VGA_CLK = slow_VGA_CLK;
	assign resetn = ~KEY[0];

	hex_decoder h1(.hex_digit(score[3:0]), .segments(HEX0));
	hex_decoder h2(.hex_digit(score[7:4]), .segments(HEX1));
	hex_decoder h3(.hex_digit(4'h0), .segments(HEX2));
	hex_decoder h4(.hex_digit(4'h0), .segments(HEX3));
	hex_decoder h5(.hex_digit(size[3:0]), .segments(HEX4));
	hex_decoder h6(.hex_digit(size[6:4]), .segments(HEX5));
	
	VGA_control display1 (slow_VGA_CLK, xPosition, yPosition, InDisplayArea, VGA_HS, VGA_VS, VGA_BLANK);

	keyboardController keyboard1(CLOCK_50,	PS2_DAT, PS2_CLK, keyValue);
	
	random random1(slow_VGA_CLK, randomX, randomY);
	
	update_and_slow_clk update1(CLOCK_50, slow_VGA_CLK, update);
	
	control control1(resetn, slow_VGA_CLK, direction, keyValue);
	
	datapath data1(direction, resetn, randomX, randomY, update, slow_VGA_CLK, 
					xPosition, yPosition, score, food, border, game_over, snakeHead, snakeBody, size);
		
	//Set pixel colour
	assign R = (InDisplayArea && (food || snakeHead || snakeBody || game_over));
	assign G = (InDisplayArea && ((food || border) && ~game_over));
	assign B = (InDisplayArea && (border && ~game_over));	
	
	always@(posedge slow_VGA_CLK)
	begin
		VGA_R = {8{R}};
		VGA_G = {8{G}};
		VGA_B = {8{B}};
	end 
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module datapath(direction, resetn, randomX, randomY, update, slow_VGA_CLK, 
					xPosition, yPosition, score, food, border, game_over, snakeHead, snakeBody, size);
					
	input [3:0] direction;
	input resetn;
	input [9:0] randomX, randomY;
	input update; 
	input slow_VGA_CLK;
	
	input [9:0] xPosition, yPosition;
	
	output reg [7:0] score;
	
	parameter 	SIZE_VAL = 1, 
					SCORE_VAL = 1,
					INIT_SNAKE_X = 50,
					INIT_SNAKE_Y = 50,
					INIT_FOOD_X = 300,
					INIT_FOOD_Y = 250;
	
	output reg food, border, game_over, snakeHead, snakeBody;
	
	reg [9:0] foodxPos;
	reg [9:0] foodyPos;
	reg [9:0] snakeX[0:64]; 
	reg [8:0] snakeY[0:64];  
	
	reg found;
	integer randomFood, moveCount, bodyCount, porchCount;
	
	output reg [5:0] size; 

	//Border
	always@(slow_VGA_CLK) 
	begin
		border <= (((xPosition >= 0) && (xPosition <= 10) || (xPosition >= 630) && (xPosition <= 640)) || // Left & Right of screen
					 ((yPosition >= 0) && (yPosition <= 10) ||(yPosition >= 470) && (yPosition <= 480))); // Top & Bottom of screen
	end
	
	always@(posedge slow_VGA_CLK)
	begin
		//Check for food position
		food = ((xPosition >= foodxPos && xPosition < foodxPos + 10) && (yPosition >= foodyPos && yPosition < foodyPos + 10)) ;
		
		//Check for snake head position
		snakeHead = (xPosition >= snakeX[0] && xPosition < (snakeX[0]+10)) && (yPosition >= snakeY[0] && yPosition < (snakeY[0]+10));
		
		//Check for snake body position
		found = 0;
		for(bodyCount = 1; bodyCount < size; bodyCount = bodyCount + 1)
		begin
			if(~found)
			begin				
				snakeBody = ((xPosition >= snakeX[bodyCount] && xPosition < snakeX[bodyCount] + 10) && (yPosition >= snakeY[bodyCount] && yPosition < snakeY[bodyCount] + 10));
				found = snakeBody;
			end
		end
		
		//Check for game over contact
		if ((border || snakeBody) && snakeHead)
			game_over <= 1; //Change to 1 later in game_over
		
		//Snake eats current food in play
		if(food && snakeHead)
			begin
				size = size + 1;
				score = score + 1;
			end
		//Reset size and score to initial values
		else if (resetn)
			begin
				size = SIZE_VAL;
				score = 1'b0;
				game_over <= 0;
			end
			
		//Set initial food position
		if(randomFood == 0)
			begin
				foodxPos <= INIT_FOOD_X;
				foodyPos <= INIT_FOOD_Y;
				randomFood = 1'b1;
			end
		else
			begin
				//Assign new food position after snake eats the current food play
				if(food && snakeHead)
					begin
						randomFood = 1'b1;
						//Random food is outside of display range
						if((randomX[9:0] < 15) || (randomX[9:0] > 625) || (randomY[8:0] < 15) || (randomY[8:0] > 465))
							begin
								foodxPos <= INIT_FOOD_X - 20;
								foodyPos <= INIT_FOOD_Y + 40;
							end
						else
							begin
								foodxPos <= randomX;
								foodyPos <= randomY;
							end
					end
			else if (resetn)
					randomFood = 1'b0;

			end
	end
		
	//Moving the snake
	always@(posedge update)
	begin
		if(~resetn)
			begin
			// Moves the snake body.
				for(moveCount = 64; moveCount > 0; moveCount = moveCount - 1)
					begin
						if(moveCount <= size - 1)
						begin
							snakeX[moveCount] = snakeX[moveCount - 1];
							snakeY[moveCount] = snakeY[moveCount - 1];
						end
					end
				case(direction)
					4'b0001: snakeY[0] <= (snakeY[0] - 10); // Up
					4'b0010: snakeX[0] <= (snakeX[0] - 10); // Left
					4'b0100: snakeY[0] <= (snakeY[0] + 10); // Down
					4'b1000: snakeX[0] <= (snakeX[0] + 10); // Right
				endcase	
			end
		//Set initial snake position
		else if(resetn)
			begin
			snakeX[0] = INIT_SNAKE_X;
			snakeY[0] = INIT_SNAKE_Y;
				// Set all snake parts to porch of screen
				for(porchCount = 1; porchCount < 63; porchCount = porchCount + 1)
					begin
					snakeX[porchCount] = 700;
					snakeY[porchCount] = 500;
					end
			end
	end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module control(resetn, slow_VGA_CLK, direction, keyValue);
	input resetn;
	input slow_VGA_CLK;
	input [7:0] keyValue;
	output reg [3:0] direction;
	
	always@(posedge resetn, posedge slow_VGA_CLK)
	begin
		if (resetn)
			direction = 4'b1000;
		else begin
			if (keyValue == 117 & direction != 4'b0100) // Up if not going Down
				direction = 4'b0001;
			else if (keyValue == 107 && direction != 4'b1000) // Left if not going Right
				direction = 4'b0010;
			else if (keyValue == 114 && direction != 4'b0001) // Down if not going Up
				direction = 4'b0100;
			else if (keyValue == 116 && direction != 4'b0010) // Right if not going Left
				direction = 4'b1000;
		end
	end

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module update_and_slow_clk(CLOCK_50, slow_VGA_CLK, update);

	input CLOCK_50; //50MHz clock
	output reg slow_VGA_CLK; //25MHz clock
	reg q;
	output reg update;
	reg [21:0]count;	

	always@(posedge CLOCK_50)
	begin
		q <= ~q; 
		slow_VGA_CLK <= q;
		
		count <= count + 1;
		if(count == 1000000)
		begin
			update <= ~update;
			count <= 0;
		end
	end
	
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module VGA_control (slow_VGA_CLK, xPosition, yPosition, InDisplayArea, VGA_HS, VGA_VS, VGA_BLANK);

	////////////////////////////////////////////
	/// http://www.fpga4fun.com/PongGame.html///
	////////////////////////////////////////////

	input slow_VGA_CLK;
	
	output reg [9:0] xPosition, yPosition;
	output reg InDisplayArea;
	output VGA_HS, VGA_VS, VGA_BLANK;
	
	reg p_HS, p_VS;

	parameter porchHF = 640;
	parameter syncH = 655;
	parameter porchHB = 745;
	parameter maxH = 800;

	parameter porchVF = 480;
	parameter syncV = 490;
	parameter porchVB = 495;
	parameter maxV = 525;
	
	// Counters
	always@(posedge slow_VGA_CLK)
		begin	
			if(xPosition == maxH)
				xPosition <= 0;
			else
				xPosition <= xPosition + 1;
		end
		
	always@(posedge slow_VGA_CLK)
		begin
			if (xPosition == maxH)
			begin
				if(yPosition == maxV)
					yPosition <= 0;
				else
					yPosition <= yPosition + 1;
			end
		end
	
	always@(posedge slow_VGA_CLK)
	begin
		InDisplayArea <= ((xPosition < porchHF) && (yPosition < porchVF)); 
	end
	
	always@(posedge slow_VGA_CLK)
	begin
		p_HS <= ((xPosition >= syncH) && (xPosition < porchHB)); 
		p_VS <= ((yPosition >= syncV) && (yPosition < porchVB)); 
	end

	assign VGA_VS = ~p_VS; 
	assign VGA_HS = ~p_HS;
	assign VGA_BLANK = InDisplayArea;
	
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module random(slow_VGA_CLK, randomX, randomY);
	input slow_VGA_CLK;
	output reg [9:0] randomX;
	output reg [8:0] randomY;

	reg [7:0] x = 10; //.5 -> 0 - 255 -> 62
	reg [6:0] y = 10; //.5 -> 0 - 127 -> 46
	
	always@(posedge slow_VGA_CLK)
		x <= x + 4;
		
	always@(posedge slow_VGA_CLK)
		y <= y + 2;
	
	always@(posedge slow_VGA_CLK)
	begin
		if(x > 62)
			randomX <= ((x % 62) + 1) * 10 ;
		else if (x < 5)
			randomX <= ((x + 1) * 4) * 10;
		else
			randomX <= (x * 10);
	end
	
	always@(posedge slow_VGA_CLK)
	begin
		if (y > 46)
			randomY <= ((y % 46) + 1) * 10;
		else if (y < 5)
			randomY <= ((y + 1) * 3) * 10;
		else 
			randomY <= (y * 10);
	end
	
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

///////////////////////////////////////////////////////////////////
/// 								///												 ///
///		ALL MODULES BEYOND THIS POINT ARE FROM:         ///
///   https://www.dropbox.com/s/b2gkbqohw0zeflw/fff.zip?dl=0    ///
///								///												 ///
///////////////////////////////////////////////////////////////////

module keyboardController(CLOCK_50,	PS2_DAT, PS2_CLK, keyValue);

input CLOCK_50, PS2_CLK, PS2_DAT;
output [7:0] keyValue;

wire reset = 1'b0;
wire [7:0] scan_code;
assign keyValue = scan_code;
reg [7:0] history[1:4];
wire read, scan_ready;

oneshot pulser(
   .pulse_out(read),
   .trigger_in(scan_ready),
   .clk(CLOCK_50)
);

keyboard kbd(
  .keyboard_clk(PS2_CLK),
  .keyboard_data(PS2_DAT),
  .clock50(CLOCK_50),
  .reset(reset),
  .read(read),
  .scan_ready(scan_ready),
  .scan_code(scan_code)
);
always @(posedge scan_ready)
begin
	history[4] <= history[3];
	history[3] <= history[2];
	history[2] <= history[1];
	history[1] <= scan_code;
end
	

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module keyboard(keyboard_clk, keyboard_data, clock50, reset, read, scan_ready, scan_code);
input keyboard_clk;
input keyboard_data;
input clock50; // 50 Mhz system clock
input reset;
input read;
output scan_ready;
output [7:0] scan_code;
reg ready_set;
reg [7:0] scan_code;
reg scan_ready;
reg read_char;
reg clock; // 25 Mhz internal clock

reg [3:0] incnt;
reg [8:0] shiftin;

reg [7:0] filter;
reg keyboard_clk_filtered;

// scan_ready is set to 1 when scan_code is available.
// user should set read to 1 and then to 0 to clear scan_ready

always @ (posedge ready_set or posedge read)
if (read == 1) scan_ready <= 0;
else scan_ready <= 1;

// divide-by-two 50MHz to 25MHz
always @(posedge clock50)
	clock <= ~clock;



// This process filters the raw clock signal coming from the keyboard 
// using an eight-bit shift register and two AND gates

always @(posedge clock)
begin
   filter <= {keyboard_clk, filter[7:1]};
   if (filter==8'b1111_1111) keyboard_clk_filtered <= 1;
   else if (filter==8'b0000_0000) keyboard_clk_filtered <= 0;
end


// This process reads in serial data coming from the terminal

always @(posedge keyboard_clk_filtered)
begin
   if (reset==1)
   begin
      incnt <= 4'b0000;
      read_char <= 0;
   end
   else if (keyboard_data==0 && read_char==0)
   begin
	read_char <= 1;
	ready_set <= 0;
   end
   else
   begin
	   // shift in next 8 data bits to assemble a scan code	
	   if (read_char == 1)
   		begin
      		if (incnt < 9) 
      		begin
				incnt <= incnt + 1'b1;
				shiftin = { keyboard_data, shiftin[8:1]};
				ready_set <= 0;
			end
		else
			begin
				incnt <= 0;
				scan_code <= shiftin[7:0];
				read_char <= 0;
				ready_set <= 1;
			end
		end
	end
end

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module oneshot(output reg pulse_out, input trigger_in, input clk);
reg delay;

always @ (posedge clk)
begin
	if (trigger_in && !delay) pulse_out <= 1'b1;
	else pulse_out <= 1'b0;
	delay <= trigger_in;
end 
endmodule

