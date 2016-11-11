`define HIGH 1'b1
`define LOW  1'b0

module uart_tx_op
//baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	(
	  input [3:0]  data_bit_num_i,    // 5 6 7 8
	  input [1:0]  parity_type_i,     // none even odd
	  input [1:0]  stop_bit_num_i,    // 1 1.5 2
	  
	  input		   clk_i,
	  input		   reset_n_i,
	  input	       clk_en_i,
	  // from interface
	  input [7:0]  data_tx_i,
	  input		   shoot_i,
	  
	  output reg   uart_tx_o,
	  output reg   busy_tx_o
	);
	
	//localparam one hot??
	localparam PARITY_NONE  = 2'b00;
	localparam PARITY_EVEN  = 2'b01;
	localparam PARITY_ODD   = 2'b10;

	localparam DATA_NUM_5   = 4'd5;
	localparam DATA_NUM_6  	= 4'd6;
	localparam DATA_NUM_7  	= 4'd7;
	localparam DATA_NUM_8  	= 4'd8;

	localparam STOP_NUM_1  	= 2'b00;
	localparam STOP_NUM_15 	= 2'b01;
	localparam STOP_NUM_2  	= 2'b10;
	
	
	//state localparam for FSM
	localparam SM_IDEL        = 13'd1;
	localparam SM_SEND_START  = 13'd2;
	localparam SM_SEND_DATA0  = 13'd4;
	localparam SM_SEND_DATA1  = 13'd8;
	localparam SM_SEND_DATA2  = 13'd16;
	localparam SM_SEND_DATA3  = 13'd32;
	localparam SM_SEND_DATA4  = 13'd64;
	localparam SM_SEND_DATA5  = 13'd128;
	localparam SM_SEND_DATA6  = 13'd256;
	localparam SM_SEND_DATA7  = 13'd512;
	localparam SM_SEND_PARITY = 13'd1024;
	localparam SM_SEND_STOP0  = 13'd2048;
	localparam SM_SEND_STOP1  = 13'd4096;
	
	// for FSM
	reg [12:0] state;
	reg [12:0] state_next;
	reg [7:0]  data_in_lch;
	reg start_cnt;
	
	always @ (posedge clk_i)
	begin
		if(!reset_n_i)
		begin
			state <= SM_IDEL;	// complete here
		end
		else
			state <= state_next;
	end
	
	//for data_in_lch
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			data_in_lch <= 0;
			start_cnt <= 0;
		end
		else
		begin
			if( state == SM_IDEL && shoot_i )
			begin
				data_in_lch <= data_tx_i;
				start_cnt <= `HIGH;
			end
			
			if( state == SM_SEND_DATA0 )
			begin
				start_cnt <= `LOW;
			end
		end
	end
	
	always @ (*)
	begin
		state_next = state;
		case (state)
		  SM_IDEL:
			begin
				if( clk_en_i && start_cnt )
				begin
					state_next = SM_SEND_START;
				end
			end
		  SM_SEND_START:
			if(clk_en_i)
				state_next = SM_SEND_DATA0;			
		  SM_SEND_DATA0:
		    if(clk_en_i)
				state_next = SM_SEND_DATA1;
		  SM_SEND_DATA1:
		    if(clk_en_i)
				state_next = SM_SEND_DATA2;
		  SM_SEND_DATA2:
		    if(clk_en_i)
				state_next = SM_SEND_DATA3;
		  SM_SEND_DATA3:
		    if(clk_en_i)
				state_next = SM_SEND_DATA4;
		  SM_SEND_DATA4:
		    if(clk_en_i)
			begin
				if(data_bit_num_i == DATA_NUM_5)
				begin
					if(parity_type_i != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA5;
			end
		  SM_SEND_DATA5:
		    if(clk_en_i)
			begin
				if(data_bit_num_i == DATA_NUM_6)
				begin
					if(parity_type_i != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA6;
			end
		  SM_SEND_DATA6:
		    if(clk_en_i)
			begin
				if(data_bit_num_i == DATA_NUM_7)
				begin
					if(parity_type_i != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA7;
			end
		
 		  SM_SEND_DATA7:
			if(clk_en_i)
			begin
				if(parity_type_i != PARITY_NONE)
					state_next = SM_SEND_PARITY;
				else
					state_next = SM_SEND_STOP0;
			end
		  SM_SEND_PARITY:
		    if(clk_en_i)
				state_next = SM_SEND_STOP0;
		  SM_SEND_STOP0:
			// not consider the 1.5 stop bit
			if(clk_en_i)
			begin
				if(stop_bit_num_i == STOP_NUM_1)
					state_next = SM_IDEL;
				else
					state_next = SM_SEND_STOP1;
			end
		  SM_SEND_STOP1:
		    if(clk_en_i)
				state_next = SM_IDEL;
		  default:
			begin
				state_next = SM_IDEL;
			end
		endcase
	end
	
	always @ (*)
	begin
		case (state)
		  SM_IDEL:
			begin
				uart_tx_o = `HIGH;
			end
		  SM_SEND_START:
			begin
				uart_tx_o = `LOW;
			end
		  SM_SEND_DATA0,
		  SM_SEND_DATA1,
		  SM_SEND_DATA2,
		  SM_SEND_DATA3,
		  SM_SEND_DATA4,
		  SM_SEND_DATA5,
		  SM_SEND_DATA6,
		  SM_SEND_DATA7:
			begin
				uart_tx_o = ( (state >> 2) & data_in_lch ) != 0;
			end
		  //parity operation
		  SM_SEND_PARITY:
		    begin
				case (parity_type_i)
				  PARITY_EVEN:
					uart_tx_o = ^data_in_lch;
				  PARITY_ODD:
					uart_tx_o = ~(^data_in_lch);
				  default:
				    uart_tx_o = `HIGH;
				endcase
			end
		  SM_SEND_STOP0:
		    begin
				uart_tx_o = `HIGH;
			end
		  SM_SEND_STOP1:
		    begin
				uart_tx_o = `HIGH;
			end
		  default:
			begin
				uart_tx_o = `HIGH;
			end
		endcase
	end
	
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			busy_tx_o <= 1'b0;
		end
		else
		begin
			if( state == SM_IDEL && shoot_i )
			begin
				busy_tx_o <= 1'b1;
			end
			
			if( state == SM_SEND_STOP0 )
			begin
				busy_tx_o <= 1'b0;
			end
		end
	end
	
endmodule
	