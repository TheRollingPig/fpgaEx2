module uart_rx_op
//baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	(
	  input [3:0]       data_bit_num_i,    // 5 6 7 8
	  input [1:0]       parity_type_i,     // none even odd
	  input [1:0]       stop_bit_num_i,    // 1 1.5 2
	  input [7:0]       oversample_rate_i,
	  
	  input		  		clk_i,
	  input		  		reset_n_i,
	  input	      		clk_sample_i,         //oversampling rate * BAUD_RATE
	  input 	  		uart_rx_i,
	  // to interface
	  output reg [7:0]  data_rx_o,
	  output reg  		datarx_vld_o,
	  output reg 		int_parity_error_o,
	  output reg        busy_rx_o
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
	localparam IDEL = 13'd1;				//inmemidiate state between stop and start, reset some value
	localparam RECEIVE_START  = 13'd2;
	localparam RECEIVE_DATA0  = 13'd4;
	localparam RECEIVE_DATA1  = 13'd8;
	localparam RECEIVE_DATA2  = 13'd16;
	localparam RECEIVE_DATA3  = 13'd32;
	localparam RECEIVE_DATA4  = 13'd64;
	localparam RECEIVE_DATA5  = 13'd128;
	localparam RECEIVE_DATA6  = 13'd256;
	localparam RECEIVE_DATA7  = 13'd512;
	localparam RECEIVE_PARITY = 13'd1024;
	localparam RECEIVE_STOP0  = 13'd2048;
	localparam RECEIVE_STOP1  = 13'd4096;
	
	// where to reset??
	reg [12:0] state;
	reg [12:0] state_next;
	reg [7:0]  rx_buffer;
	reg [3:0]  rx_low_cnt;
	reg		   flag_start_det;
	reg [7:0]  cnt_sample;
	reg 	   flag_sample;
	reg 	   flag_parity_error;
	reg		   parity_buffer;
	reg        flag_data_valid;
	
	//reset and dff for FSM
	always @ (posedge clk_i)
	begin
		if( !reset_n_i )
		begin
			state <= RECEIVE_START;
			rx_buffer <= 8'b0;
		end
		else
			state <= state_next;
	end
	
	//start bit detection and filter spikes
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			rx_low_cnt <= 4'b0;
			flag_start_det <= 1'b0;
		end
		else
		begin
			if( state == RECEIVE_START && !uart_rx_i && clk_sample_i )
			begin
				rx_low_cnt <= rx_low_cnt + 4'b1;
			end
			
			if( state == IDEL )
			begin
				rx_low_cnt <= 4'b0;
			end
			
			if( rx_low_cnt == ( oversample_rate_i / 2 - 1 ) )
			begin
				flag_start_det <= 1'b1;		
			end
			else
			begin
				flag_start_det <= 1'b0;
			end
		end
	end
	
	//generate sample pluse
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			cnt_sample <= 8'b0;
			flag_sample <= 1'b0;
		end
		else
		begin
			if( flag_start_det && clk_sample_i )
			begin
				cnt_sample <= cnt_sample + 8'b1;
			end
			
			if( state == IDEL )
			begin
				cnt_sample <= 8'b0;
			end
				
			if( cnt_sample == oversample_rate_i )
			begin
				flag_sample <= 1'b1;
				cnt_sample <= 8'b0;
			end
			else
			begin
				flag_sample <= 1'b0;
			end
		end
	end
	
	// how to reset some flag registers and handle some internal registers
	// for state change
	always @ ( * )
	begin
		state_next = state;
		case( state )
		  //IDEL used to clear some flag bits and output
		  IDEL:
		    if( !flag_start_det )
			begin
				state_next = RECEIVE_START;
			end
		  RECEIVE_START:
			if( flag_start_det )
			begin
				state_next = RECEIVE_DATA0;
			end
		  
		  RECEIVE_DATA0:
		    if( flag_sample )
			begin
				rx_buffer[0] = uart_rx_i;
				state_next = RECEIVE_DATA1;
			end
		  
		  RECEIVE_DATA1:
		    if( flag_sample )
			begin
				rx_buffer[1] = uart_rx_i;
				state_next = RECEIVE_DATA2;
			end
		  
		  RECEIVE_DATA2:
		    if( flag_sample )
			begin
				rx_buffer[2] = uart_rx_i;
				state_next = RECEIVE_DATA3;
			end
		  
		  RECEIVE_DATA3:
		    if( flag_sample )
			begin
				rx_buffer[3] = uart_rx_i;
				state_next = RECEIVE_DATA4;
			end
		  
		  RECEIVE_DATA4:
		    if( flag_sample )
			begin
				rx_buffer[4] = uart_rx_i;
				if( data_bit_num_i == DATA_NUM_5 )
				begin
					if( parity_type_i != PARITY_NONE )
						state_next = RECEIVE_PARITY;
					else
						state_next = RECEIVE_STOP0;
				end
				else
					state_next = RECEIVE_DATA5;
			end
		  
		  RECEIVE_DATA5:
		    if( flag_sample )
			begin
				rx_buffer[5] = uart_rx_i;
				if( data_bit_num_i == DATA_NUM_6 )
				begin
					if( parity_type_i != PARITY_NONE )
						state_next = RECEIVE_PARITY;
					else
						state_next = RECEIVE_STOP0;
				end
				else
					state_next = RECEIVE_DATA6;
			end
		  
		  RECEIVE_DATA6:
		    if( flag_sample )
			begin
				rx_buffer[6] = uart_rx_i;
				if( data_bit_num_i == DATA_NUM_7 )
				begin
					if( parity_type_i != PARITY_NONE )
						state_next = RECEIVE_PARITY;
					else
						state_next = RECEIVE_STOP0;
				end
				else
					state_next = RECEIVE_DATA7;
			end
		  
		  RECEIVE_DATA7:
		    if( flag_sample )
			begin
				rx_buffer[7] <= uart_rx_i;
				if( parity_type_i != PARITY_NONE )
					state_next = RECEIVE_PARITY;
				else
					state_next = RECEIVE_STOP0;
			end
		  
		  RECEIVE_PARITY:
		    if( flag_sample )
			begin
				parity_buffer = uart_rx_i;
				case (parity_type_i)
				  PARITY_EVEN:
				    if( parity_buffer != ^rx_buffer )
					begin
						flag_parity_error = 1'b1;
					end
				  PARITY_ODD:
					if( parity_buffer != ~(^rx_buffer) )
					begin
						flag_parity_error = 1'b1;
					end
				  default:
				    flag_parity_error = 1'b0;
				endcase
				state_next = RECEIVE_STOP0;
			end
		  
		  RECEIVE_STOP0:
		    if( flag_sample )
			begin
				if( stop_bit_num_i == STOP_NUM_1 )
					state_next = IDEL;
				else
					state_next = RECEIVE_STOP1;
			end
		  
		  RECEIVE_STOP1:
		    if( flag_sample )
				state_next = IDEL;
		  
		  default:
		    begin
				state_next = RECEIVE_START;
			end
		endcase
	end
	
	// for int_parity_error_o
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			int_parity_error_o <= 1'b0;
			parity_buffer <= 1'b0;
			flag_parity_error <= 1'b0;
		end
		else
		begin
			if( state == IDEL && flag_parity_error )
			begin
				int_parity_error_o <= 1'b1;
				flag_parity_error <= 1'b0;
			end
			else
			begin
				int_parity_error_o <= 1'b0;
			end
		end
	end
	
	// for busy_rx_o
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			busy_rx_o <= 1'b0;
		end
		else
		begin
			if( state == RECEIVE_DATA0 )
				busy_rx_o <= 1'b1;
			if( state == IDEL )
				busy_rx_o <= 1'b0;
		end
	end
	
	//for datarx_vld_o
	always @ ( posedge clk_i )
	begin
		if( !reset_n_i )
		begin
			data_rx_o <= 8'b0;
			datarx_vld_o <= 1'b0;
			flag_data_valid <= 1'b0;
		end
		else
		begin
			if( state == IDEL && !flag_data_valid )
			begin
				data_rx_o <= rx_buffer;
				datarx_vld_o <= 1'b1;
				flag_data_valid <= 1'b1;
			end
			else if( state == RECEIVE_START )
				flag_data_valid <= 1'b0;
			else
				datarx_vld_o <= 1'b0;
		end
	end

endmodule