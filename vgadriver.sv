`default_nettype none
module vgadriver (
    input logic clk, rst, //25 MHz
    input logic [2:0] color_in, //R G B
    output logic [9:0] x_out, y_out,
    output logic hsync, vsync,
    output logic red, green, blue
);

//numbers are in clock cycles
//typical VGA display is 640 x 480 @ 60hz

    logic [9:0] H_ACTIVE = 10'd639; //visible screen region
    logic [9:0] H_FRONT = 10'd15; //frontporch
    logic [9:0] H_PULSE = 10'd95; // low for sync pulse
    logic [9:0] H_BACK = 10'd47; // back high to reset the cycle
    //these are all just limits
    logic [9:0] V_ACTIVE = 10'd479; //same stuff different dimension
    logic [9:0] V_FRONT = 10'd9;
    logic [9:0] V_PULSE = 10'd1;
    logic [9:0] V_BACK = 10'd32;

    //make this stuff look readable please use constants
    logic LOW = 1'b0;
    logic HIGH = 1'b1;

    typedef enum logic [1:0] {
        h_state_active = 2'b0,
        h_state_front = 2'b1,
        h_state_pulse = 2'b10,
        h_state_back = 2'b11
    } hstate_t;

    hstate_t current_hstate, next_hstate;

    typedef enum logic [1:0] {
        v_state_active = 2'b0,
        v_state_front = 2'b1,
        v_state_pulse = 2'b10,
        v_state_back = 2'b11
    } vstate_t;

    vstate_t current_vstate, next_vstate;

    logic hsync_r, vsync_r, line_done;



    logic [9:0] h_current_count, h_next_count;
    logic [9:0] v_current_count, v_next_count;


    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            h_current_count <= 0;
            current_hstate <= h_state_active;
            v_current_count <= 0;
            current_vstate <= v_state_active;
        end 
        else begin
            h_current_count <= h_next_count;
            v_current_count <= v_next_count;
            current_hstate <= next_hstate;
            current_vstate <= next_vstate;
        end
    end

    always_comb begin // H comb

    next_hstate = h_state_active;
    h_next_count = 'b0;

    case(current_hstate)

    h_state_active: begin
    hsync_r = HIGH;
    line_done = LOW;

    if (h_current_count == H_ACTIVE) begin
    h_next_count = 10'd0;
    next_hstate = h_state_front;
    end else begin
    h_next_count = h_current_count + 10'd1;
    next_hstate = current_hstate;
    end
    end

    h_state_front: begin
    hsync_r = HIGH;
    line_done = LOW;

    if (h_current_count == H_FRONT) begin
    h_next_count = 10'd0;
    next_hstate = h_state_pulse;
    end else begin
    h_next_count = h_current_count + 10'd1;
    next_hstate = current_hstate;
    end

    end

    h_state_pulse: begin
    hsync_r = LOW;
    line_done = LOW;
    if (h_current_count == H_PULSE) begin
    h_next_count = 10'd0;
    next_hstate = h_state_back;
    end else begin
    h_next_count = h_current_count + 10'd1;
    next_hstate = current_hstate;
    end
    end

    h_state_back: begin
    hsync_r = HIGH;

    if(h_current_count == H_BACK - 1) begin
    line_done = HIGH;
    end else begin
    line_done = LOW;
    end


    if (h_current_count == H_BACK) begin
    h_next_count = 10'd0;
    next_hstate = h_state_active;
    end else begin
    h_next_count = h_current_count + 10'd1;
    next_hstate = current_hstate;
    end


    end

    endcase
    end

    always_comb begin // V comb

        next_vstate = v_state_active;
        v_next_count = 'b0;

        case(current_vstate)
            v_state_active: begin
                vsync_r = HIGH;
                if (line_done==HIGH) begin
                    if (v_current_count == V_ACTIVE) begin
                        v_next_count = 10'd0;
                        next_vstate = v_state_front;
                    end 
                    else begin
                        v_next_count = v_current_count + 10'd1;
                        next_vstate = v_state_active;
                    end
                end 
                else begin
                    v_next_count = v_current_count;
                    next_vstate = current_vstate;
                end
            end

            v_state_front: begin
                vsync_r = HIGH;
                if (line_done == HIGH) begin
                    if (v_current_count == V_FRONT) begin
                        v_next_count = 10'd0;
                        next_vstate = v_state_pulse;
                    end 
                    else begin
                        v_next_count = v_current_count + 10'd1;
                        next_vstate = v_state_front;
                    end
                end 
                else begin
                    v_next_count = v_current_count;
                    next_vstate = current_vstate;
                end
            end

            v_state_pulse: begin
                vsync_r = LOW;
                if (line_done == HIGH) begin
                    if (v_current_count == V_PULSE) begin
                        v_next_count = 10'd0;
                        next_vstate = v_state_back;
                    end 
                    else begin
                        v_next_count = v_current_count + 10'd1;
                        next_vstate = v_state_pulse;
                    end
                end 
                else begin
                    v_next_count = v_current_count;
                    next_vstate = current_vstate;
                end
            end

            v_state_back: begin
                vsync_r = HIGH;
                if (line_done == HIGH) begin
                    if (v_current_count == V_BACK) begin
                        v_next_count = 10'd0;
                        next_vstate = v_state_active;
                    end 
                    else begin
                        v_next_count = v_current_count + 10'd1;
                        next_vstate = current_vstate;
                    end
                end else begin
                    v_next_count = v_current_count;
                    next_vstate = current_vstate;
                end
            end

        endcase
    end

    always_comb begin // COLORS YIPPEE
        if (current_hstate == h_state_active) begin
            if (current_vstate == v_state_active) begin
                red = color_in[2];
                green = color_in[1];
                blue = color_in[0];
            end 
            else begin
                red = 'd0;
                green = 'd0;
                blue = 'd0;
            end
        end 
        else begin
            red = 'd0;
            green = 'd0;
            blue = 'd0;
        end
    end


    //not even needed but the tutorial we followed had it
    assign vsync = vsync_r;
    assign hsync = hsync_r;

    always_comb begin
        if (current_hstate == h_state_active) begin
                x_out = h_current_count;
            end 
            else begin
                x_out = 10'd0;
            end

        if (current_vstate == v_state_active) begin
            y_out = v_current_count;
        end else begin
            y_out = 10'd0;
        end
    end

endmodule


//example instance: vgadriver ryangosling (.clk(hz100), .rst(1'b0), .color_in(3'b011), .red(red), .green(green), .blue(blue), .hsync(right[1]), .vsync(right[0]));

