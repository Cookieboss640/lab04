// `default_nettype none
// Empty top module
module top (
  // I/O ports
  input  logic hz25M, reset,
  input  logic [20:0] pb,
  output logic [7:0] left, right,
         ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  output logic red, green, blue,

  // UART ports
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
 

);
// Internal signals
logic [9:0] x, y;
logic onehuzz;
logic [7:0] current_score;
logic finish, gameover;
 logic [19:0][19:0] display_array;
 logic [2:0] final_color, grid;
// Color priority logic: starboy and score display take priority over grid
always_comb begin
  final_color = 0;
  if (grid != '0) begin
    final_color = grid;
  end
end

  snakeGame game (
      .clk(hz25M),
      .reset(reset),
      .btn({pb[6], pb[2], pb[3], pb[1]}),  // Direct button connection
      .display_array(display_array),
      .gameover(gameover)
  );


  // Your code goes here...
vgadriver ryangosling (
.clk(hz25M), 
.rst(1'b0),
.color_in(grid),
.red(left[5]),
.green(left[4]),
.blue(left[3]),
.hsync(left[7]),
.vsync(left[0]),
.x_out(x),
.y_out(y)
);

    // input logic [9:0] x, y,
    // input logic [19:0][19:0] display_array,  // 20x20 game state (1 bit per cell)
    // input logic gameover,
    // output logic [2:0] shape_color

snakeGrid agartha (
  .x(x),
  .y(y),
  .display_array(display_array),
  .gameover('0),
  .shape_color(grid)
);
endmodule



