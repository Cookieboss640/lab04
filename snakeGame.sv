`default_nettype none

/////////////////////////////////////////////////////////////////
// Snake Game Main Controller Module
// Handles game logic, snake movement, collision detection, and scoring
/////////////////////////////////////////////////////////////////
module snakeGame (
    input logic clk,              // 25 MHz clock
    input logic reset,            // Reset signal
    input logic [3:0] btn,        // Buttons: [3]=up, [2]=down, [1]=left, [0]=right
    output logic [19:0][19:0] display_array,  // 20x20 grid state
    output logic gameover         // Game over flag
);

    // Game parameters
    localparam GRID_SIZE = 20;
    localparam MAX_SNAKE_LENGTH = 400;  // 20x20 grid
    
    // Clock divider for snake speed (adjust for game speed)
    localparam SPEED_DIV = 25_000_000 / 2;  // 2 updates per second
    logic [31:0] clk_counter;
    logic tick;
    
    // Snake body storage - stores x,y coordinates
    logic [4:0] snake_x [MAX_SNAKE_LENGTH-1:0];  // X coordinates (0-19)
    logic [4:0] snake_y [MAX_SNAKE_LENGTH-1:0];  // Y coordinates (0-19)
    logic [9:0] snake_length;  // Current length of snake
    
    // Snake head position and direction
    logic [4:0] head_x, head_y;
    typedef enum logic [1:0] {
        DIR_RIGHT = 2'b00,
        DIR_LEFT  = 2'b01,
        DIR_DOWN  = 2'b10,
        DIR_UP    = 2'b11
    } direction_t;
    direction_t current_dir, next_dir;
    
    // Apple/Food position
    logic [4:0] apple_x, apple_y;
    logic apple_eaten;
    
    // LFSR for pseudo-random apple position
    logic [7:0] lfsr;
    
    // Game state machine
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        PLAYING = 2'b01,
        GAME_OVER = 2'b10
    } state_t;
    state_t game_state;
    
    // Clock divider for game tick
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
            tick <= 0;
        end else begin
            if (clk_counter >= SPEED_DIV - 1) begin
                clk_counter <= 0;
                tick <= 1;
            end else begin
                clk_counter <= clk_counter + 1;
                tick <= 0;
            end
        end
    end
    
    // LFSR for random number generation
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'b10101010;
        else
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end
    
    // Direction control - prevent 180 degree turns
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_dir <= DIR_RIGHT;
            next_dir <= DIR_RIGHT;
        end else begin
            // Update direction on button press
            if (btn[3] && current_dir != DIR_DOWN)      // Up
                next_dir <= DIR_UP;
            else if (btn[2] && current_dir != DIR_UP)   // Down
                next_dir <= DIR_DOWN;
            else if (btn[1] && current_dir != DIR_RIGHT) // Left
                next_dir <= DIR_LEFT;
            else if (btn[0] && current_dir != DIR_LEFT)  // Right
                next_dir <= DIR_RIGHT;
            
            // Apply direction change on game tick
            if (tick && game_state == PLAYING)
                current_dir <= next_dir;
        end
    end
    
    // Main game logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize game
            game_state <= IDLE;
            gameover <= 0;
            snake_length <= 3;
            
            // Initialize snake in the middle
            snake_x[0] <= 10;  // Head
            snake_y[0] <= 10;
            snake_x[1] <= 9;
            snake_y[1] <= 10;
            snake_x[2] <= 8;
            snake_y[2] <= 10;
            
            // Initialize remaining body parts off-screen
            for (int i = 3; i < MAX_SNAKE_LENGTH; i++) begin
                snake_x[i] <= 0;
                snake_y[i] <= 0;
            end
            
            // Place first apple
            apple_x <= 15;
            apple_y <= 10;
            
            head_x <= 10;
            head_y <= 10;
            
        end else begin
            case (game_state)
                IDLE: begin
                    // Wait for any button press to start
                    if (btn != 4'b0000) begin
                        game_state <= PLAYING;
                    end
                end
                
                PLAYING: begin
                    if (tick) begin
                        // Calculate new head position
                        case (current_dir)
                            DIR_RIGHT: head_x <= head_x + 1;
                            DIR_LEFT:  head_x <= head_x - 1;
                            DIR_DOWN:  head_y <= head_y + 1;
                            DIR_UP:    head_y <= head_y - 1;
                        endcase
                        
                        // Check wall collision
                        if (head_x >= GRID_SIZE || head_y >= GRID_SIZE) begin
                            game_state <= GAME_OVER;
                            gameover <= 1;
                        end
                        
                        // Check self-collision
                        for (int i = 0; i < snake_length; i++) begin
                            if (head_x == snake_x[i] && head_y == snake_y[i]) begin
                                game_state <= GAME_OVER;
                                gameover <= 1;
                            end
                        end
                        
                        // Check apple collision
                        apple_eaten <= 0;
                        if (head_x == apple_x && head_y == apple_y) begin
                            apple_eaten <= 1;
                            snake_length <= snake_length + 1;
                            
                            // Generate new apple position
                            apple_x <= lfsr[4:0] % GRID_SIZE;
                            apple_y <= lfsr[7:3] % GRID_SIZE;
                        end
                        
                        // Move snake body
                        if (!gameover) begin
                            // Shift body segments
                            for (int i = MAX_SNAKE_LENGTH-1; i > 0; i--) begin
                                snake_x[i] <= snake_x[i-1];
                                snake_y[i] <= snake_y[i-1];
                            end
                            
                            // Update head position
                            snake_x[0] <= head_x;
                            snake_y[0] <= head_y;
                        end
                    end
                end
                
                GAME_OVER: begin
                    // Stay in game over state until reset
                    gameover <= 1;
                end
            endcase
        end
    end
    
    // Generate display array
    always_comb begin
        // Clear display
        for (int row = 0; row < GRID_SIZE; row++) begin
            for (int col = 0; col < GRID_SIZE; col++) begin
                display_array[row][col] = 1'b0;
            end
        end
        
        // Draw snake body
        for (int i = 0; i < snake_length; i++) begin
            if (snake_x[i] < GRID_SIZE && snake_y[i] < GRID_SIZE) begin
                display_array[snake_y[i]][snake_x[i]] = 1'b1;
            end
        end
        
        // Draw apple (if not on snake)
        if (apple_x < GRID_SIZE && apple_y < GRID_SIZE) begin
            display_array[apple_y][apple_x] = 1'b1;
        end
    end

endmodule
