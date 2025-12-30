################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.macro push(%reg) # push to stack               
sw %reg, 0($sp) # push %reg value onto the stack
addi $sp, $sp, -4 # move the stack pointer to an empty location
.end_macro

.macro pop(%reg) #  pop from stack
    addi $sp, $sp, 4 # move the stack pointer to the previous location
    lw %reg, 0($sp) # pop value and store in %reg
.end_macro

.data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL: # The address of the bitmap display.
    .word 0x10008000
ADDR_KBRD: # The address of the keyboard.
    .word 0xffff0000
ADDR_NEW: 
    .word 0x10009770 # The address of the grid of next state

Y_OFFSET: # amount to add to a memory address to go down one line
    .word 128

SCREEN_HEIGHT: 32
SCREEN_WIDTH: 32

# Details related to the box to play the game in
BOX_X:
    .word 3
BOX_Y:
    .word 3
BOX_WIDTH: 
    .word 11
BOX_HEIGHT:
    .word 24

# Details related to position of preview 
NEW_X:
    .word 25
NEW_Y:
    .word 5

# Details related to position of saved piece 
SAVED_X: 
    .word 25
SAVED_Y:
    .word 15
    
STARTING_POS: # starting x pos of the gems (1-(box width - 2))
    .word 4

SLEEP_TIME: # amount of time to sleep per loop 
    .word 10

DECREASE_FALL_TIME_TIME: 10000 # amount of time to wait until decreasing the fall time of gravity(should be a multiple of SLEEP_TIME)
DECREASE_FALL_TIME_INTERVAL: 100 # amount to decrease fall time by
MIN_FALL_TIME_HARD: 50
MIN_FALL_TIME_MEDIUM: 300
MIN_FALL_TIME_EASY: 500
FALL_TIME_HARD: 350
FALL_TIME_MEDIUM: 500
FALL_TIME_EASY: 1000

# Colors
# pieces
RED_COL:
    .word 0xFF6B6B
BLUE_COL:
    .word 0x8CD7FF
PURPLE_COL:
    .word 0xC98CFF
PINK_COL:
    .word 0xFF8CEC
YELLOW_COL:
    .word 0xFFF48C
GREEN_COL:
    .word 0x68FCA4
GREY_COL: # border
    .word 0x858585
LIGHT_GREY_COL:
    .word 0xcccccc
WHITE_COL: # text
    .word 0xffffff
    
next_piece_addr: .word 0
saved_piece_addr: .word 0
min_fall_time: .word 500 # min fall time 
fall_time: .word 1000 # number of milliseconds until piece should fall (should be a multiple of SLEEP_TIME)
falling_counter: .word 0 # counter for when current piece should fall
dec_fall_time_counter: .word 0 # counter for when gravity speed should increase
paused: .byte 0
game_over: .byte 0
cur_level: .byte 0 # 0 is easy, 1 is medium, 2 is hard

##############################################################################
# Mutable Data
##############################################################################


##############################################################################
# Code
##############################################################################
.text
.globl main

# Run the game.
main:

menu:
    jal clear_screen
    ## Parameters for drawing letters/numbers ##
    # $s1: y-coor
    # $s2: vertical offset (7)
    # $s3: horizontal offset (2)
    # $s6: height
    # $s5: width
    # $s4: color
    # $s7: x-coor
    
    # Draw E = 1
    li $s7, 4
    li $s1, 2
    lw $s4, GREEN_COL
    li $s6, 5
    li $s5, 3
    li $s2, 7
    li $s3, 2
    jal draw_E
    
    addi $s7, $s7, 8 # sum of x-coor for = and 12
    jal draw_1
    
    subi $s7, $s7, 4 # remove x-coor for 1
    addi $s1, $s1, 1
    jal draw_equal

    
    # Draw M = 2
    li $s7, 4
    li $s1, 9
    lw $s4, YELLOW_COL
    jal draw_M
        
    addi $s7, $s7, 10
    jal draw_2
    
    subi $s7, $s7, 4
    addi $s1, $s1, 1
    jal draw_equal

    
    # Draw H = 3
    li $s7, 4
    li $s1, 16
    lw $s4, RED_COL
    jal draw_H
        
    addi $s7, $s7, 8
    jal draw_3
        
    subi $s7, $s7, 4
    addi $s1, $s1, 1
    jal draw_equal
    
    
    menu_loop:
         # read keyboard input
        lw $t1 ADDR_KBRD # keyboard memory address
        lw $t8, 0($t1) # Load first word from keyboard
        li $a0, 0 # Reset $a0
        beq $t8, 1, menu_keyboard_input
        bne $t8, 1, menu_post_keyboard_input # skip keyboard input
        menu_keyboard_input:
            lw $a0, 4($t1)  # Load the hex of the ascii of the key pressed
            beq $a0, 0x31, press_1  # easy
            beq $a0, 0x32, press_2  # medium
            beq $a0, 0x33, press_3 # hard
            j menu_post_keyboard_input # else 
            press_1: # easy
                li $t0, 0
                sb $t0 cur_level
                lw $t0, MIN_FALL_TIME_EASY
                sw $t0, min_fall_time
                j end_menu
            press_2: # medium
                li $t0, 1
                sb $t0 cur_level
                lw $t0, MIN_FALL_TIME_MEDIUM
                sw $t0, min_fall_time
                j end_menu
            press_3:
                li $t0, 2
                sb $t0 cur_level
                lw $t0, MIN_FALL_TIME_HARD
                sw $t0, min_fall_time
                j end_menu  
            
        menu_post_keyboard_input:
        # sleeping
        lw $t0, SLEEP_TIME
        li $v0, 32
        add $a0, $t0, $zero
        syscall
        j menu_loop
end_menu:

# Initialize the game
initialize_game:
    jal clear_screen
    lw $t0 ADDR_DSPL # top left coordinate
    ### Drawing the box the game will be playing in ###
    
    lw $s1, GREY_COL # store grey color
    lw $s2, BOX_WIDTH # store width 
    lw $s3, BOX_X # store initial x coor
    lw $s4, BOX_Y # store initial y coor
    lw $s5, BOX_HEIGHT # store height
    li $s6, 2 # offset of 2 for horizontal line
    li $s7, 7 # offset of 7 for vertical line
    
    # top horizontal line
    push($s3) # push x-coor
    push($s4) # push y-coor
    push($s2) # push width
    push($s1) # push color
    sw $s6, 0($sp) # push offset of 2
    addi $sp, $sp, -4
    jal draw_line # call function
    
    # left vertical line
    sw $s3, 0($sp) # push x-coor
    addi $sp, $sp, -4 
    sw $s4, 0($sp) # push y-coor
    addi $sp, $sp, -4 
    sw $s5, 0($sp) # push height
    addi $sp, $sp, -4 
    sw $s1, 0($sp) # push color
    addi $sp, $sp, -4
    sw $s7, 0($sp) # push offset of 7
    addi $sp, $sp, -4
    jal draw_line # call function
    
    # bottom horizontal line
    sw $s3, 0($sp) # push x-coor
    addi $sp, $sp, -4 
    add $t0, $s4, $s5
    subi $t0, $t0, 1 # new y coor is orig_y + height - 1
    sw $t0, 0($sp) # push y-coor
    addi $sp, $sp, -4 
    sw $s2, 0($sp) # push width
    addi $sp, $sp, -4 
    sw $s1, 0($sp) # push color
    addi $sp, $sp, -4
    sw $s6, 0($sp) # push offset of 2
    addi $sp, $sp, -4
    jal draw_line # call function
    
    # right vertical line
    add $t0, $s3, $s2
    subi $t0, $t0, 1 # new x coor is orig_x + width - 1
    sw $t0, 0($sp) # push x-coor
    addi $sp, $sp, -4 
    sw $s4, 0($sp) # push y-coor
    addi $sp, $sp, -4 
    sw $s5, 0($sp) # push height
    addi $sp, $sp, -4 
    sw $s1, 0($sp) # push color
    addi $sp, $sp, -4
    sw $s7, 0($sp) # push offset of 7
    addi $sp, $sp, -4
    jal draw_line # call function

    # Make grid black
    lw $a0, ADDR_DSPL
    jal get_grid_addr
    add $t3, $v0, $zero # top left coor in cur state grid
    lw $t6, BOX_HEIGHT
    subi $t6, $t6, 2 # get grid height
    reset_state_y_loop_start:
        add $t0, $t3, $zero # store current coor in $t0
        beq $t6, $zero reset_state_y_loop_end
        lw $t7, BOX_WIDTH
        subi $t7, $t7, 2 # get grid width
        reset_state_x_loop_start:
            beq $t7, $zero reset_state_x_loop_end
            sw $zero, 0($t3) # store black in state
            addi $t3, $t3, 4 # go right
            subi $t7, $t7, 1 # decrement inner loop variable
            j reset_state_x_loop_start
        reset_state_x_loop_end:
        subi $t6, $t6, 1 # decrement outer loop variable
        add $t3, $t0, 128 # set cur coor to be $t0 but one column down
        j reset_state_y_loop_start
    reset_state_y_loop_end:
    
    jal reset_new_state # make new state blank
    
    # Resetting variables
    sb $zero, paused # Reset paused
    sw $zero, falling_counter # Reset current piece falling
    sb $zero, game_over # Reset game over
    sw $zero, dec_fall_time_counter
    
    lb $t0, cur_level
    beq $t0, 0, set_easy_speed
    beq $t0, 1, set_med_speed
    beq $t0, 2, set_hard_speed
    set_easy_speed:
        lw $t0, FALL_TIME_EASY
        sw $t0, fall_time
        j post_set_speed 
    set_med_speed:
        lw $t0, FALL_TIME_MEDIUM
        sw $t0, fall_time
        j post_set_speed 
    set_hard_speed:
        lw $t0, FALL_TIME_HARD
        sw $t0, fall_time 
        j post_set_speed 
    post_set_speed:

    ### Drawing the first piece ###
    # get the top left address of the grid
    lw $a0, ADDR_DSPL
    jal get_initial_coor # initial coor
    addi $a1, $v1, 0
    jal draw_piece
    add $s0, $v1, $zero # store the address of the current piece
    
    # next piece generation
    next_piece_generation:
        lw $a0, ADDR_DSPL
        lw $t4 NEW_X # starting x pos of piece
        sll $t4, $t4, 2 # horizontal offset
        lw $t5, NEW_Y
        sll $t5, $t5, 7 # vertical offset
        add $t2, $a0, $t4 
        add $t6, $t2, $t5 # return address of where piece starts
        addi $a1, $t6, 0
        sw $a1, next_piece_addr
        jal draw_piece
            
        lw $s1, NEW_Y
        subi $s1, $s1, 1
        li $s2, 7
        li $s3, 2
        li $s6, 5
        li $s5, 3
        lw $s4, LIGHT_GREY_COL
        lw $s7, NEW_X
        subi $s7, $s7, 8
        jal draw_N
    
    # saved piece initialization
    saved_piece:
        lw $a0, ADDR_DSPL
        jal get_saved_coor
        sw $v1, saved_piece_addr
        lw $t7, LIGHT_GREY_COL
        sw $t7, 0($v1)
        sw $t7, 128($v1)
        sw $t7, 256($v1)

        lw $s1, SAVED_Y
        subi $s1, $s1, 1
        li $s2, 7
        li $s3, 2
        li $s6, 5
        li $s5, 3
        lw $s4, LIGHT_GREY_COL
        lw $s7, SAVED_X
        subi $s7, $s7, 7
        jal draw_E

game_loop:
    # $s0: address of the current piece
    
    jal reset_new_state

    # read keyboard input
    # Note: Will be updated when calling update_state
    lw $t1 ADDR_KBRD # keyboard memory address
    lw $t8, 0($t1) # Load first word from keyboard
    li $a0, 0 # Reset $a0
    beq $t8, 1, keyboard_input
    bne $t8, 1, post_keyboard_input # skip keyboard input
    keyboard_input:
        lw $a0, 4($t1)  # Load the hex of the ascii of the key pressed
        beq $a0, 0x71, end_program  # End game if the key q was pressed
        beq $a0, 0x6D, press_M # menu
        beq $a0, 0x72, press_R  
        # Game over management: ignore key presses when game over
        lb $t0, game_over
        beq $t0, 1, post_keyboard_input
        
        beq $a0, 0x70, press_P
        # Pause management: ignore key presses when paused
        lb $t0, paused
        beq $t0, 1, post_keyboard_input

        beq $a0, 0x61, press_A  
        beq $a0, 0x77, press_W  
        beq $a0, 0x73, press_S  
        beq $a0, 0x64, press_D 
        beq $a0, 0x65, press_E 
        
        j post_keyboard_input # else 
        press_A: # move left
            lw $t0, 252($s0)
            bne $t0, $zero, post_keyboard_input # invalid if color isn't black
            addi $a0, $zero, -4
            jal move_piece
            j post_keyboard_input
        press_S: # move down
            lw $t0, 384($s0)
            bne $t0, $zero, post_keyboard_input # invalid if color isn't black
            addi $a0, $zero, 128
            jal move_piece
            j post_keyboard_input
        press_D: # move right
            lw $t0, 260($s0)
            bne $t0, 0x0, post_keyboard_input # invalid if color isn't black
            addi $a0, $zero, 4
            jal move_piece
            j post_keyboard_input
        press_W: # rotate
            j rotate_piece
        press_E: # switch with saved piece
            # new state saved = cur state cur
            replace_new:
                lw $a0, ADDR_NEW
                jal get_saved_coor
                addi $a0, $v1, 0
                addi $a1, $s0, 0
                jal overwrite_piece
            
            # new state cur = cur state saved
            replace_cur:
                jal get_new_coor
                addi $a0, $v0, 0
                lw $a1, saved_piece_addr
                jal overwrite_piece
            
            lw $t0, LIGHT_GREY_COL
            lw $t1, saved_piece_addr
            lw $t2, 0($t1)
            bne $t2, $t0, post_keyboard_input # if cur piece was not replaced with grey, keep going
            
            replace_grey_with_preview:
                jal update_state
                addi $a0, $s0, 0
                jal replace_with_preview_piece
                
            j post_keyboard_input
        press_P: # pause/unpause game
            # Pause management: pause/unpause game upon pressing p
            lb $t1, paused
            beq $t1, 0, pause
            beq $t1, 1, unpause
            pause:
                addi $t1, $zero, 1
                sb $t1, paused
                jal update_state
                lw $a0, WHITE_COL
                jal draw_paused
                jal reset_new_state
                j post_keyboard_input
            unpause:
                sb $zero, paused
                jal update_state
                li $a0, 0
                jal draw_paused
                jal reset_new_state
                j post_keyboard_input
        press_R:
            li $a0, 0
            jal draw_game_over
            sb $zero, game_over
            j initialize_game # Go to start of game to restart
        press_M:
            j menu # Go to menu
    
    rotate_piece:
        jal get_new_coor
        add $t3, $s0, $zero # cur piece coor in cur state
        add $t4, $v0, $zero
        # load current colors
        lw $t1, 0($t3) 
        lw $t2, 128($t3)
        lw $t0, 256($t3) 
        # paint colors in new location
        sw $t0, 0($t4) 
        sw $t1, 128($t4)
        sw $t2, 256($t4)
        j post_keyboard_input
    post_keyboard_input:
    
    jal update_state
    

    # Pause management: skip checking collision if paused
    lb $t1, paused
    beq $t1, 1, post_check_collision
    # Game over management: skip checking collision if game over
    lb $t1, game_over
    beq $t1, 1, post_check_collision
    check_collision:
        jal check_collision_bottom # check collision due to keyboard press
    post_check_collision:
    # skip draw outline/falling...
    # Pause management: ...if paused
    lb $t1, paused
    beq $t1, 1, sleep 
    # Game over management: ...if game over
    lb $t1, game_over
    beq $t1, 1, sleep 
            
    # Decrease fall managment: check if current piece should fall if counter has reached DECREASE_FALL_TIME_TIME
    lw $t0, DECREASE_FALL_TIME_TIME
    lw $t1, dec_fall_time_counter
    bne $t1, $t0, post_dec_fall_time # skip decreasing fall time if counter hasn't reached time yet
    
    dec_fall_time:
        lw $t0, DECREASE_FALL_TIME_INTERVAL
        lw $t1, fall_time
        lw $t2, min_fall_time
        sub $t3, $t1, $t2 # fall_time - min_fall_time
        ble $t3, $zero, post_dec_fall_time # skip decreasing fall time if fall time is less than or equal to min (fall_time - min_fall_time <= 0)
        sub $t1, $t1, $t0 # fall time - fall time interval
        sw $t1, fall_time # change fall time
        sw $zero, dec_fall_time_counter # reset counter
    post_dec_fall_time:
    
    
    # Redraw current board
    jal update_state
    
    # Fall management: check if current piece should fall if counter has reached fall_time
    lw $t0, fall_time
    lw $t1, falling_counter
    blt $t1, $t0, post_piece_fall # skip piece_fall if counter hasn't reached time yet

    piece_fall:
        # jal reset_new_state
        li $a0, 128
        jal move_piece # Note: Will be updated when calling update_state
        jal update_state
        jal check_collision_bottom # check collision due to gravity
        # Fall management: reset falling counter
        sw $zero, falling_counter  # reset counter
    post_piece_fall:

    # Fall management: add to falling counter
    lw $t0, SLEEP_TIME
    lw $t1, falling_counter
    add $t1, $t1, $t0
    sw $t1, falling_counter
    
    # Decrease fall managment: add to counter
    lw $t0, SLEEP_TIME
    lw $t1, dec_fall_time_counter
    add $t1, $t1, $t0
    sw $t1, dec_fall_time_counter

    jal draw_outline # draw outline right before sleeping

    sleep:
        # sleeping
        lw $t0, SLEEP_TIME
        li $v0, 32
        add $a0, $t0, $zero
        syscall
        jal update_state # removes outline if it was drawn (so it flickers)
    j game_loop



# Draw a line (vertical or horizontal)
# $a0 = x coordinate to start at
# $a1 = y coordinate to start at 
# $a2 = set length of line
# $t1 = color
# $a3 = offset (2 if we are drawing a horizontal line, 7 if we are drawing a vertical line)
draw_line:
    # $t0: address of top left point of screen
    # $t1: color to use
    # $t2: current coordinate
    # $t3: stop condition
    # $t4: temp register to get offsets
    pop($a3) # pop $a3 (offset)
    
    # get the exponent 2^$a3 (stored in $v0)
    push($ra)
    # $a0 = base
    # $a1 = exponent
    addi $a0, $zero, 2
    add $a1, $zero, $a3
    jal calculate_exponent
    pop($ra)
    
    pop($t1) # pop $t1 (color)
    pop($a2) # pop $a2 (set length of line)
    pop($a1) # pop $a1 (y coordinate to start at)
    pop($a0) # pop $a0 (x coordinate to start at)

    lw $t0, ADDR_DSPL
    
    sll $t4, $a0, 2 # Multiply the x-coor by 4 to get the horizontal offset to add to the initial address
    add $t2, $t0, $t4 # add horizontal offset to $t0 and store in $t2
    
    sll $t4, $a1, 7  # Multiply the y-coor by 128 = 2^7
    add $t2, $t2, $t4 # add vertical offset
    
    # Make a loop to draw a line.
    # calculate the difference between the starting value and the end value
    sllv $t4, $a2, $a3 # Multiply the length by $a3 to get the horizontal/vertical offset to add to the current address
    add $t3, $t2, $t4 # set stopping location
    draw_line_loop_start:
        beq $t3, $t2, draw_line_loop_end # check if $t2 has reached the final location of the line
        sw $t1, 0( $t2 ) # paint the current pixel
        add $t2, $t2, $v0 # move $t2 to the next pixel in the row/col by 2^$a3
        j draw_line_loop_start
    draw_line_loop_end:

    jr $ra # end draw_line function



# Calculate base^exponent
# $a0 = base
# $a1 = exponent
# $v0 = base^exponent
calculate_exponent:
    # $t1 = counter for computing exponent
    # $t2 = stop condition for exponent loop
    # $t3 = current value
    li $t1, 0 # initialize counter
    add $t2, $zero, $a1 # set stop condition 
    li $t3, 1 # initialize current value
    calculate_exponent_loop_start:
        beq $t1, $t2 calculate_exponent_loop_end # end when counter = stop condition
        mult $t3, $a0 # multiply current value by base
        mflo $t3 # store new value
        addi $t1, $t1, 1 # increment loop variable
        j calculate_exponent_loop_start
    calculate_exponent_loop_end:
    add $v0, $zero, $t3 # store return value
    jr $ra # end calculate_exponent function
    
    
# Clear screen by coloring everything black
clear_screen:
    # draw new state board to be the same as current state board
    push($ra)
    lw $s2, SCREEN_HEIGHT
    li $s1, 0
    clear_screen_loop_start:
        beq $s2, $s1, clear_screen_loop_end
        li $t0, 0
        lw $t1, SCREEN_WIDTH
        li $t2, 2
        push($t0) # x-coor
        push($s1) # y-coor
        push($t1) # length
        push($t0) # color (black)
        push($t2) # offset
        jal draw_line
        addi $s1, $s1, 1 # increment loop variable
        j clear_screen_loop_start
    clear_screen_loop_end:
    pop($ra)

    jr $ra # end clear_screen function
    

# Store values for drawing a line for the box
initialize_box_details:
    # $t1: Grey color
    # $t2: box width
    # $t3: box x coor
    # $t4: box y coor
    # $t5: box height
    lw $t1, GREY_COL # store grey color
    lw $t2, BOX_WIDTH # store width 
    lw $t3, BOX_X # store initial x coor
    lw $t4, BOX_Y # store initial y coor
    lw $t5, BOX_HEIGHT # store height
    jr $ra # end initialize_box_details function
    
# Get top left coordinate of this state's grid
# $a0: top left address of current state screen
get_grid_addr:
    # $v0: the address of the top left coordinate
    add $t0, $a0, $zero
    lw $t1 BOX_X # top left of box x
    lw $t2 BOX_Y # top left of box y 
    add $t1, $t1, 1 # starting x pos of piece
    addi $t2, $t2, 1 # top left of grid y
    sll $t1, $t1, 2 # horizontal offset
    sll $t2, $t2, 7 # vertical offset
    add $v0, $t0, $t1
    add $v0, $v0, $t2 # address
    jr $ra # end get_grid_addr function

# get address to draw initial piece
# $a0: top left address of start the screen for the state
get_initial_coor:
    # $v1: address of the top of the piece 
    # get the top left address of the grid
    sw $ra, 0($sp)
    addi $sp, $sp, -4
    jal get_grid_addr
    addi $sp, $sp, 4
    lw $ra, 0($sp) # pop $ra
    add $t0, $v0, $zero # store the top left address in $t0

    lw $t4 STARTING_POS # starting x pos of piece
    sll $t4, $t4, 2 # horizontal offset
    add $t2, $t0, $t4 # address of where piece starts
    add $v1, $t2, $zero # return result
    jr $ra

# Assuming $s0 has the address of the piece in the current grid, get the coordinate in the new state grid
get_new_coor:
# $v0: new address
    lw $t0, ADDR_DSPL
    lw $t1, ADDR_NEW
    sub $t2, $s0, $t0 # get dif in addresses of top left and current piece loc
    add $v0, $t1, $t2 # cur piece coor in new state
    jr $ra # end get_new_coor function

# get address to draw saved piece
# $a0: top left address of start the screen for the state
get_saved_coor:
    # $v1: address of the top of the piece 
    # get the top left address of the grid
    lw $t4 SAVED_X # starting x pos of piece
    sll $t4, $t4, 2 # horizontal offset
    lw $t5, SAVED_Y
    sll $t5, $t5, 7 # vertical offset
    add $t2, $a0, $t4 
    add $v1, $t2, $t5 # return address of where piece starts
    jr $ra

# function to draw a piece at the top of the grid
# $a0: top left address of start the screen for the state
# $a1: coordinate address to draw
draw_piece:
    addi $t2, $a1, 0

    addi $t4, $t2, 384 # stop loop after three iterations
    draw_piece_loop_start:
        beq $t2, $t4 draw_piece_loop_end
        lw $t6, 0($t2)
        bne $t6, $zero, draw_piece_move_down # Don't draw a new color when the place is already filled
        
        # get a random color out of 6 options and store in $t5
        get_color:
            li $a0, 0
            addi $a1, $zero, 5
            li $v0, 42
            li $a0, 0
            li $a1, 5
            syscall
            beq $a0, 0 get_color_choose_0
            beq $a0, 1 get_color_choose_1
            beq $a0, 2 get_color_choose_2
            beq $a0, 3 get_color_choose_3
            beq $a0, 4 get_color_choose_4
            beq $a0, 5 get_color_choose_5
            get_color_choose_0:
                lw $t5 RED_COL
                j get_color_end
            get_color_choose_1:
                lw $t5 BLUE_COL
                j get_color_end
            get_color_choose_2:
                lw $t5 PURPLE_COL
                j get_color_end
            get_color_choose_3:
                lw $t5 YELLOW_COL
                j get_color_end
            get_color_choose_4:
                lw $t5 PINK_COL
                j get_color_end
            get_color_choose_5:
                lw $t5 GREEN_COL
                j get_color_end
            get_color_end:   
        
        sw $t5, 0($t2)
        draw_piece_move_down:
        addi $t2, $t2, 128 # move down
        j draw_piece_loop_start
    draw_piece_loop_end:
    jr $ra # end draw_piece function
   
# function to overwrite a state board with another state board
# $a0: top left address of the current state board
# $a1: top left address of the new state board (that will be overwritten)
overwrite_state_board:
    # draw new state board to be the same as current state board
    add $t3, $a0, $zero # top left address in cur state grid
    add $t4, $a1, $zero # top left address in new state grid

    lw $t6, SCREEN_HEIGHT
    subi $t6, $t6, 2 # get grid height
    overwrite_state_y_loop_start:
        add $t0, $t3, $zero # store current coor in $t0
        add $t1, $t4, $zero # store the current coor in new state in $t1
        beq $t6, $zero overwrite_state_y_loop_end
        lw $t7, SCREEN_WIDTH
        subi $t7, $t7, 2 # get grid width
        overwrite_state_x_loop_start:
            beq $t7, $zero overwrite_state_x_loop_end
            lw $t5, 0($t3) # load current color
            sw $t5, 0($t4) # store current color in new state
            addi $t3, $t3, 4 # go right
            addi $t4, $t4, 4 # go right
            subi $t7, $t7, 1 # decrement inner loop variable
            j overwrite_state_x_loop_start
        overwrite_state_x_loop_end:
        subi $t6, $t6, 1 # decrement outer loop variable
        add $t3, $t0, 128 # set cur coor to be $t0 but one column down
        add $t4, $t1, 128 # set cur coor in new state to be $t1 but one column down
        j overwrite_state_y_loop_start
    overwrite_state_y_loop_end:
    jr $ra # end overwrite_state_board function

# function to loop through entire current grid,
#   check if there are 3+ of the same color in a specific xy direction,
#   and erase the boxes if there are in the new grid
# $a0: x direction to move
# $a1: y direction to move
check_same_color:
    # $v0: 1 if something was changed, otherwise 0
    push($ra)
    push($a0)
    push($a1)
    lw $a0, ADDR_DSPL
    jal get_grid_addr
    lw $t2, ADDR_NEW
    add $t0, $v0, $zero # top left addr in cur state grid
    sub $t1, $t0, $a0 # get dif in addresses
    add $t1, $t1, $t2 # top left addr in new state grid
    pop($a0)
    pop($a1)
    pop($ra)

    sll $t2, $a0, 2 # horizontal offset
    sll $t3, $a1, 7 # vertical offset
    add $t8, $t2, $t3 # get difference to add each check by adding the shifts (product)
    
    # $t0: top left addr in cur state grid
    # $t1: top left addr in new state grid
    # $t8: difference to add to the address to check the next box
    li $v0, 0
    check_same_color_y_loop_start:
        add $t2, $t0, $zero # store current addr in $t2
        add $t3, $t1, $zero # store the current addr in new state in $t3

        lw $t4, GREY_COL
        lw $t5, 0($t2)
        beq $t5, $t4 check_same_color_y_loop_end # end loop when current value is grey (on border)
        
        check_same_color_x_loop_start:
            lw $t4, GREY_COL
            lw $t5, 0($t2) # store the current color
            beq $t5, $t4 check_same_color_x_loop_end # end loop when current value is grey (on border)
            beq $t5, $zero same_color_erase_loop_end # don't check when current value is black
            
            add $t6, $t2, $zero # store current address we are checking (current grid state)
            li $t7, 0 # store number of same colors
            same_color_loop_start:
                lw $t4, 0($t6) # store color of current box we are checking
                bne $t4, $t5 same_color_loop_end # break loop when color does not match original
                add $t6, $t8, $t6 # move in direction
                addi $t7, $t7, 1
                j same_color_loop_start
            same_color_loop_end:
            blt $t7, 3, same_color_erase_loop_end # skip erasing boxes when count is strictly less than 3
            add $t6, $t3, $zero # store current address we are checking (new grid state)
            li $v0, 1 # set return value as true
            same_color_erase_loop_start:
                beq $t7, 0, same_color_erase_loop_end # end when count is 0
                sw $zero, 0($t6) # erase block in new state
                add $t6, $t6, $t8 # move in direction
                subi $t7, $t7, 1
                j same_color_erase_loop_start
            same_color_erase_loop_end:
            
            addi $t2, $t2, 4 # go right
            addi $t3, $t3, 4 # go right

            j check_same_color_x_loop_start
        check_same_color_x_loop_end:
        addi $t0, $t0, 128 # move cur coor one column down
        addi $t1, $t1, 128 # move cur coor in new state one column down
        j check_same_color_y_loop_start
    check_same_color_y_loop_end:
    jr $ra # end overwrite_state_board function
 
# move current piece in the given direction (changing new state board)
# $a0: direction to move according to key press
move_piece:
    # change new state board based on key press
    push($ra) # push $ra
    jal get_new_coor
    pop($ra)

    add $t3, $s0, $zero # cur piece coor in cur state
    add $t4, $v0, $zero
    add $s0, $s0, $a0 # move current piece location
    
    # load current colors
    lw $t0, 0($t3) 
    lw $t1, 128($t3)
    lw $t2, 256($t3) 
    # erase current colors
    sw $zero, 0($t4)
    sw $zero, 128($t4)
    sw $zero, 256($t4)
    # paint colors in new location
    add $t4, $t4, $a0 # move in direction of $a0
    sw $t0, 0($t4) 
    sw $t1, 128($t4)
    sw $t2, 256($t4)
    jr $ra # end move_piece function

# replace current piece with preview piece, and add a new piece to preview
# $a0: coordinate of the current piece
replace_with_preview_piece:
    push($ra)
    lw $a1, next_piece_addr 
    jal overwrite_piece # put new coordinate in
    lw $a0, ADDR_DSPL
    # color preview piece black (draw_piece doesn't overwrite non-black locations)
    sw $zero, 0($a1)
    sw $zero, 128($a1)
    sw $zero, 256($a1)
    jal draw_piece # draw at $a1 (next piece)
    jal reset_new_state
    pop($ra)
    jr $ra

# implement gravity on pieces on the board (change next state grid based on current state grid)
gravity:
    # $v0: 1 if any block fell, otherwise 0
    sw $ra, 0($sp) # push $ra
    addi $sp, $sp, -4
    lw $a0, ADDR_DSPL
    jal get_grid_addr
    lw $t2, ADDR_NEW
    add $t0, $v0, $zero # top left addr in cur state grid
    sub $t1, $t0, $a0 # get dif in addresses
    add $t1, $t1, $t2 # top left addr in new state grid
    addi $sp, $sp, 4
    lw $ra, 0($sp) # pop $ra
    
    # $t0: top left addr in cur state grid
    # $t1: top left addr in new state grid
    li $v0, 0
    gravity_y_loop_start:
        add $t2, $t0, $zero # store current addr in $t2
        add $t3, $t1, $zero # store the current addr in new state in $t3

        lw $t4, GREY_COL
        lw $t5, 0($t2)
        beq $t5, $t4 gravity_y_loop_end # end loop when current value is grey (on border)
        
        gravity_x_loop_start:
            lw $t4, GREY_COL
            lw $t5, 0($t2) # store the current color
            beq $t5, $t4 gravity_x_loop_end # end loop when current value is grey (on border)
            beq $t5, $zero post_fall # don't check when current value is black
            
            addi $t6, $t2, 128 # move down in current grid state
            lw $t7, 0($t6) # get color of the block below in current grid state
            bne $t7, $zero, post_fall # if block below is not black, block will not fall down
            fall:
                add $t6, $t3, 128 # move down in new grid state
                sw $zero, 0($t3) # erase block in new state
                sw $t5, 0($t6) # color next block in new state
                li $v0, 1
            post_fall:
            
            addi $t2, $t2, 4 # go right
            addi $t3, $t3, 4 # go right

            j gravity_x_loop_start
        gravity_x_loop_end:
        addi $t0, $t0, 128 # move cur coor one column down
        addi $t1, $t1, 128 # move cur coor in new state one column down
        j gravity_y_loop_start
    gravity_y_loop_end:
    jr $ra # end gravity function

# reset new state of game to current state of grid
reset_new_state:
    lw $a0, ADDR_DSPL
    lw $a1, ADDR_NEW
    sw $ra, 0($sp) # push $ra
    addi $sp, $sp, -4
    jal overwrite_state_board
    addi $sp, $sp, 4
    lw $ra, 0($sp) # pop $ra
    jr $ra # end update_state function
    

# update state of game to new state gride
update_state:
    lw $a0, ADDR_NEW
    lw $a1, ADDR_DSPL
    sw $ra, 0($sp) # push $ra
    addi $sp, $sp, -4
    jal overwrite_state_board
    addi $sp, $sp, 4
    lw $ra, 0($sp) # pop $ra
    jr $ra # end update_state function

# Overwrite the vertical piece at current address with colors at new address
# $a0: current address
# $a1: new address
overwrite_piece:
    lw $t0, 0($a1)
    lw $t1, 128($a1)
    lw $t2, 256($a1)
    sw $t0, 0($a0)
    sw $t1, 128($a0)
    sw $t2, 256($a0)
    jr $ra

# Assuming $s0 holds the current piece, potentially check for collisions with bottom
check_collision_bottom:
    push($ra)
    # draw new state board to be the same as current state board
    jal reset_new_state
    
    # Check collision with bottom
    lw $t0, 384($s0)
    beq $t0, $zero, post_bottom_hit # if color is black, we skip adding a new piece (haven't hit bottom yet)
    
    hit_bottom: # managing hitting the bottom of the grid
        # check if any pieces can cancel out 
        remove_same_pieces:
            li $a0, 1 # check for horizontal 
            li $a1, 0 
            jal check_same_color
            add $v1, $v0, $zero
    
            li $a0, 0 # check for vertical
            li $a1, 1
            jal check_same_color
            or $v1, $v1, $v0
            
            li $a0, 1 # check for diagonal bottom right
            li $a1, 1
            jal check_same_color
            or $v1, $v1, $v0
            
            li $a0, -1 # check for diagonal bottom left
            li $a1, 1
            jal check_same_color
            or $v1, $v1, $v0
            
            beq $v1, 0, post_remove_same_pieces # $v1 is 0 means nothing has been erased, so exit
            
            # if something has been erased, apply gravity
            gravity_loop:
                li $v0, 32 # sleeping
                li $a0, 200
                syscall
                
                jal reset_keyboard_input
                    
                jal update_state
                jal reset_new_state
                jal gravity
                beq $v0, 1 gravity_loop # $v0 is 1 means something fell down
                # keep running loop as long as gravity occurred
            post_gravity_loop:
        
            # $v1 is 1 means there have been changes made, so restart the loop
            beq $v1, 1, remove_same_pieces
        post_remove_same_pieces:
        li $v1, 0 # resetting $v1
        
        end_game_check: # 
            # hit the bottom, check if we've reached the top for any column
            lw $a0, ADDR_DSPL
            jal get_grid_addr
            addi $t1, $v0, 0 # store address of top left
            lw $t2, BOX_X # width of grid
            end_game_check_loop_start:
                beq $t2, 0, end_game_check_loop_end 
                lw $t0, 0($t1) # checking the color of the top box
                bne $t0, $zero, end_game # if color is not black, game is lost
                subi $t2, $t2, 1
                addi $t1, $t1, 4 # move right
                j end_game_check_loop_start
            end_game_check_loop_end:
            j post_end_game_check # dont end game in this case
            # fill in final squares and end game
            end_game:
                lw $a0, WHITE_COL
                jal draw_game_over
                jal reset_new_state
                addi $t1, $zero, 1
                sb $t1, game_over
                j sleep
        post_end_game_check:
  
        end_game_check_add_new:
            # hit the bottom, check if adding a new piece will make us reach the top
            lw $a0, ADDR_DSPL
            jal get_initial_coor
            lw $t0, 256($v1) # checking the third box in the piece
            beq $t0, $zero, post_end_game_check_add_new # If the third square is not filled yet, ignore end game code
            # fill in final squares and end game
            draw_and_end_game:
                lw $a0, ADDR_DSPL 
                jal get_initial_coor # get initial coordinate of piece
                addi $a0, $v1, 0
                add $s0, $v1, $zero # store the address of the current piece
                jal replace_with_preview_piece
                lw $a0, WHITE_COL
                jal draw_game_over
                jal reset_new_state
                addi $t1, $zero, 1
                sb $t1, game_over
                jal reset_keyboard_input
                j sleep
        post_end_game_check_add_new:
        add_new_piece:
            lw $a0, ADDR_DSPL 
            jal get_initial_coor # get initial coordinate of piece
            addi $a0, $v1, 0
            add $s0, $v1, $zero # store the address of the current piece
            jal replace_with_preview_piece
            # Fall management: reset falling counter for new piece
            sw $zero, falling_counter  # reset counter
            jal reset_keyboard_input
            j post_keyboard_input
        post_add_new_piece:
    post_bottom_hit:
    
    jal update_state
    pop($ra)
    jr $ra

# Create outline of where current piece will end up
# Assumes $s0 has the current address
draw_outline: # draw on our current grid (not the next grid)
    addi $t0, $s0, 0 # store current address in $t0
    addi $t0, $t0, 384 # go three down
    find_bottom_of_col_loop_start:
        lw $t1, 0($t0) # get color at current point
        bne $t1, $zero, find_bottom_of_col_loop_end # end loop if color is not black
        addi $t0, $t0, 128
        j find_bottom_of_col_loop_start
    find_bottom_of_col_loop_end:
    # At this point: current value of $t0 corresponds to a location that isn't black, and three above could be black
    subi $t0, $t0, 128 # go back to the lowest coor that should have outline (if its black)
    lw $t5, -256($t0)
    bne $t5, $zero, draw_outline_loop_end # don't draw outline if the piece is already partially on where the entire outline should be
    li $t2, 3
    addi, $t4, $s0, 0 # load current address into $t4
    addi $t4, $t4, 256 # make $t4 the last box of our current piece
    lw $t3, 0($t4) # store last color of current piece into $t3
    draw_outline_loop_start:
        beq $t2, $zero, draw_outline_loop_end # already went back three times
        lw $t1, 0($t0) # get color at current point
        bne $t1, $zero, draw_outline_loop_end # stop if this color isn't black (above wouldn't be black either since we are at the bottom)
        sw $t3, 0($t0) # color the value of $t3
        subi $t0, $t0, 128 # go back for current address
        subi $t2, $t2, 1
        # change next color to use to be color above current box of current piece
        subi $t4, $t4, 128
        lw $t3, 0($t4)
        j draw_outline_loop_start
    draw_outline_loop_end:
    jr $ra
    
# remove keyboard input if exists
reset_keyboard_input:
    # read keyboard input (to make sure they don't stack and all apply after gravity
    lw $t1 ADDR_KBRD # keyboard memory address
    lw $t8, 0($t1) # Load first word from keyboard
    li $a0, 0 # Reset $a0
    bne $t8, 1, post_remove_keyboard_input # skip keyboard input
    lw $a0, 4($t1)  # Load the hex of the ascii of the key pressed
    post_remove_keyboard_input:
    jr $ra

# function to draw a paused symbol at the top of the grid
# $a0: color to use
draw_paused:
    # $a0 = x coordinate to start at
    # $a1 = y coordinate to start at 
    # $a2 = set length of line
    # $a3 = offset (2 if we are drawing a horizontal line, 7 if we are drawing a vertical line)
    push($ra)

    li $s1, 3 # length
    li $s2, 7 # offset
    li $s3, 28 # y-coor
    addi $s4, $a0, 0 # color

    # push
    li $t0, 1 # x-coor
    push($t0) 
    push($s3) # y-coor
    push($s1) # height
    push($s4) # color
    push($s2) # offset of 7
    jal draw_line
    
    li $t0, 3 # x-coor
    push($t0) 
    push($s3) # y-coor
    push($s1) # height
    push($s4) # color
    push($s2) # offset of 7
    jal draw_line
    
    addi $sp, $sp, 4
    lw $ra, 0($sp) # pop $ra
    jr $ra # end draw_paused function

# function to draw a paused symbol at the top of the grid
# $a0: color to use
draw_game_over:
    # $a0 = x coordinate to start at
    # $a1 = y coordinate to start at 
    # $a2 = set length of line
    # $a3 = offset (2 if we are drawing a horizontal line, 7 if we are drawing a vertical line)
    push($ra)

    li $s1, 2 # y-coor
    li $s2, 7 # offset (vertical)
    li $s3, 2 # offset (horizontal)
    li $s6, 5 # height
    li $s5, 3 # width 1
    addi $s4, $a0, 0 # color

    # Draw G 
    li $s7, 6 # G x-coor
    jal draw_G
    
    # Draw A 
    addi $s7, $s7, 4 # A x-coor
    jal draw_A
    
    # Draw M 
    addi $s7, $s7, 4 # M x-coor
    jal draw_M
    
    # Draw E
    addi $s7, $s7, 6
    jal draw_E
    
    # Draw O
    addi $s1, $s1, 6
    li $s7, 8 # O x-coor
    jal draw_O
    
    # Draw V
    addi $s7, $s7, 4 # V x-coor
    li $s6, 2
    jal draw_V
    
    # Draw E
    li $s6, 5
    addi $s7, $s7, 6
    jal draw_E
    
    # Draw $
    addi $s7, $s7, 4
    li $s5, 4
    jal draw_R


    pop($ra)
    jr $ra # end draw_paused function

## Parameters for drawing letters/numbers ##
# $s1: y-coor
# $s2: vertical offset (7)
# $s3: horizontal offset (2)
# $s6: height
# $s5: width
# $s4: color
# $s7: x-coor

draw_G:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    add $t0, $s1, $s6
    subi $t0, $t0, 1
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s1, 2
    addi $t1, $s7, 2
    push($t1) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s2) # offset of 7
    jal draw_line
    pop($ra)
    jr $ra # end draw_G function
    

draw_A:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s7, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    pop($ra)
    jr $ra 

draw_M:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 1
    addi $t1, $s1, 1
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 2
    addi $t1, $s1, 2
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 4
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 3
    addi $t1, $s1, 1
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    pop($ra)
    jr $ra 


draw_E:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s1, 4
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    pop($ra)
    jr $ra 

draw_O:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    addi $t0, $s1, 4
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s7, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    pop($ra)
    jr $ra 
 
draw_V:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 1
    addi $t1, $s1, 2
    push($t0) # x-coor
    push($t1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 2
    addi $t1, $s1, 4
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 3
    addi $t1, $s1, 2
    push($t0) # x-coor
    push($t1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 4
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    pop($ra)
    jr $ra 

draw_R:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s7, 3
    subi $t1, $s6, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($t1) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 2
    addi $t1, $s1, 3
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 3
    addi $t1, $s1, 4
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    pop($ra)
    jr $ra 

draw_H:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset of 7
    jal draw_line
    
    addi $t0, $s7, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset of 7
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    pop($ra)
    jr $ra 

draw_N:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 1
    addi $t1, $s1, 1
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 2
    addi $t1, $s1, 2
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 3
    addi $t1, $s1, 3
    li $t2, 1
    push($t0) # x-coor
    push($t1) # y-coor
    push($t2) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    addi $t0, $s7, 4
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line
    
    pop($ra)
    jr $ra 


draw_1:
    push($ra)
    push($s7) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    pop($ra)
    jr $ra 
    
    
draw_2:
    push($ra)
    addi $t0, $s7, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($s5) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s1, 4
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s1, 2
    push($s7) # x-coor
    push($t0) # y-coor
    push($s5) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    pop($ra)
    jr $ra 

draw_3:
    push($ra)
    addi $t0, $s7, 2
    push($t0) # x-coor
    push($s1) # y-coor
    push($s6) # height
    push($s4) # color
    push($s2) # offset
    jal draw_line

    push($s7) 
    push($s1) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line
    
    addi $t0, $s1, 4
    push($s7) 
    push($t0) # y-coor
    push($s5) # length
    push($s4) # color
    push($s3) # offset of 2
    jal draw_line

    pop($ra)
    jr $ra 
    
# function to draw an equal symbol 
draw_equal:
    push($ra)
    
    push($s7) 
    push($s1) # y-coor
    push($s5) # height
    push($s4) # color
    push($s3) # offset
    jal draw_line
    
    addi $t0, $s1, 2
    push($s7) 
    push($t0) # y-coor
    push($s5) # height
    push($s4) # color
    push($s3) # offset
    jal draw_line
    
    pop($ra)
    jr $ra # end draw_paused function


# end program function
end_program:
    li $v0, 10 # terminate program gracefully
    syscall
