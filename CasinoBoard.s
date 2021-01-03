# ##################################################
# Casino Board
# By: Kelechi Igwe
#
# Constant Registers
# x4: Buttons Input
# x5: Switches Input
# x6: LEDs output
# x7: SSEG output
# x8: SSEG_MODE output
# x10: Button Press Value (sometimes)
# x12-16: Button On Values
# x28: Current Bet
# x29: Mode/Game Type (0: Slots, 1: Blackjack, 2: ATM)
# x30: Wallet Amount
# x31: Bank Amount
#
# Variable Registers
# x9, x11, x22-x27
# ##################################################

# Time Delays (Note: Taking into account that instructions are two cycles each)
.equ ONE_SEC, 0x17D7840 # Amount of clock cycles in about one second
.equ ONE_MSEC, 0x61A8 # Amount of clock cycles in about one millisecond

# Memory-Mapped I/Os
.equ BUTTONS, 0x11180000
.equ SWITCHES, 0x11000000
.equ LEDS, 0x11080000
.equ SSEG, 0x110C0000
.equ SSEG_MODE, 0x112C0000
.equ SLOT_NUM, 0x111C0000
.equ SLOT_BCD_IN, 0x111C0004
.equ SLOT_BCD_OUT, 0x111C0008
.equ SLOT_ON, 0x111C0008
.equ BLACKJACK, 0x11300000

# Miscellaneous
.equ MAX_VAL, 0x7FFFFFFF

.text
.global main
.type main, @function

main:
	LI x4, BUTTONS # Address for buttons
	LI x5, SWITCHES # Address for switches
	LI x6, LEDS # Address for LEDs
	LI x7, SSEG # Address for SSEG
	LI x8, SSEG_MODE # Address for SSEG Mode 1
	LI x30, 1000 # Wallet Amount
	LI x31, 10000 # Bank Amount
	LI x12, 16 # BTNU
	LI x13, 8 # BTNL
	LI x14, 4 # BTNC
	LI x15, 2 # BTNR
	LI x16, 1 # BTND

# ##################################################
# Main Menu
main_board:
	LI x9, 0x8000
	SW x9, 0(x6) # Reset LEDs to starting point
	SW x16, 0(x8) # Letter Mode
	LI x10, 0
	LI x11, 0
	LI x20, 0x1000
	LI x21, 0
	LI x22, 0
	LI x29, 0
	SW x16, 0(x8)
	LI x9, 0x92DD3 # SSEG Imm for "SLOTS"
	SW x9, 0(x7)
b_main_loop:
	BNE x11, x20, bml
	LW x10, 0(x4)
	BNE x10, x12, main_check_btnd
	call show_wallet
	J wallet_to_main
main_check_btnd:
	BNE x10, x16, b_main_loop
	call show_wallet
wallet_to_main:
	LI x9, 0x92DD3
	SW x9, 0(x7)
	LI x9, 0x8000
	SW x9, 0(x6)
	SW x16, 0(x8) # Back to Letter Mode
bml:
	LW x10, 0(x4)
	call sw_oneshot
	LW x11, 0(x5)
	BEQ x10, x12, move_up
	BEQ x10, x16, move_down
	BEQ x10, x14, select
	J b_main_loop
move_up: 		
	ADDI x21, x21, -1
	BGEZ x21, set_sseg
	LI x21, 2
	J set_sseg
move_down: 		
	ADDI x21, x21, 1
	BGEU x15, x21, set_sseg
	LI x21, 0
	J set_sseg
set_sseg: 		
	BEQZ x21, sseg_slots
	BEQ x21, x16, sseg_jack
	LI x22, 0x2000
	LI x9, 0x04D9A # SSEG Imm for ATM
	SW x9, 0(x7)
	SW x22, 0(x6)
	call switch_sseg_delay
	J b_main_loop
sseg_slots:		
	LI x22, 0x8000
	LI x9, 0x92DD3 # SSEG Imm for SLOTS
	SW x9, 0(x7)
	SW x22, 0(x6)
	call switch_sseg_delay
	J b_main_loop
sseg_jack:		
	LI x22, 0x4000
	LI x9, 0xFFF28 # SSEG Imm for 21
	SW x9, 0(x7)
	SW x22, 0(x6)
	call switch_sseg_delay
	J b_main_loop
select:
	SW x0, 0(x6)
	BEQZ x21, slots
	BEQ x21, x16, blackjack
	J atm
# ##################################################

# ##################################################
# Button Handling
sw_oneshot: # Software One-Shot of Button
	MV x11, x10
	LW x10, 0(x4)
	BEQZ x10, sw_oneshot_done
	BEQ x29, x15, sw_oneshot_atm
	J sw_oneshot
sw_oneshot_done:
	MV x10, x11
	ret
sw_oneshot_atm:
	LW x25, 0(x5)
	LI x26, 0x1000
	BNE x25, x26, sw_oneshot
	LW x10, 0(x4)
	BEQ x10, x12, sw_oneshot_done
	BEQ x10, x16, sw_oneshot_done
	BEQZ x10, sw_oneshot_done
	J sw_oneshot
# ##################################################

# ##################################################
# Wallet Viewing
show_wallet:
	SW x0, 0(x8)
	LI x21, 0x1000
	LI x10, 3
	J wallet_loop
s_wallet:
	LI x10, 0x00FF
	SW x10, 0(x6)
	SW x30, 0(x7)
	MV x10, x16
	J wallet_loop
s_bank:
	LI x10, 0xFF00
	SW x10, 0(x6)
	SW x31, 0(x7)
	MV x10, x12
wallet_loop:	
	LW x9, 0(x5)
	BNE x9, x21, exit_wallet
	LW x9, 0(x4)
	BEQ x9, x10, wallet_loop
	BEQ x9, x12, s_bank
	BEQ x9, x16, s_wallet
exit_wallet:
	SW x0, 0(x6)
	ret
# ##################################################

# ##################################################
# ATM
atm:
	call switch_sseg_delay
	LI x9, 0
	LI x29, 2
	SW x0, 0(x6)
	SW x16, 0(x8)
	LI x10, 0
	LI x18, 0xFBA93 # SSEG Imm for OUT
	LI x21, 0x1000
	SW x18, 0(x7)
	MV x17, x18
atm_menu_loop:	
	LW x9, 0(x5)
	BNE x21, x9, aml_loop
	LW x9, 0(x4)
	BNE x9, x12, atm_check_btnd
	call show_wallet
	J wallet_to_atm
atm_check_btnd:
	BNE x9, x16, aml_loop
	call show_wallet
wallet_to_atm:
	SW x16, 0(x8)
	SW x17, 0(x7)
aml_loop:
	LW x10, 0(x4)
	call sw_oneshot
	BEQ x10, x12, atm_switch
	BEQ x10, x16, atm_switch
	BEQ x10, x14, atm_select
	BEQ x10, x13, main_board
	J atm_menu_loop
atm_switch:	
	BEQ x17, x18, switch_atm_in
	LI x17, 0xFBA93
	SW x17, 0(x7)
	J atm_menu_loop
switch_atm_in:
	LI x17, 0xFFD0D # SSEG Imm for IN
	SW x17, 0(x7)
	J atm_menu_loop
atm_select:	
	BNE x17, x18, deposit
	LI x23, 0 # 0: Withdrawing, 1: Depositing
	MV x24, x31
	J atm_action
deposit:
	LI x23, 1
	MV x24, x30
atm_action:
	call switch_sseg_delay
	SW x24, 0(x7)
	LI x19, 0xFFFF
	SW x0, 0(x8)
	AND x19, x24, x19
	SW x19, 0(x6)
	LI x17, ONE_SEC
atm_count1:	
	ADDI x17, x17, -1
	BNEZ x17, atm_count1
atm_action_setup:
	SW x0, 0(x6)
	SW x0, 0(x8)
atm_action_loop:		
	LW x9, 0(x5)
	BNE x9, x21, atm_action_cont
	LW x10, 0(x4)
	BNE x10, x12, aa_check_btnd
	call show_wallet
	J wallet_to_aa
aa_check_btnd:
	BNE x10, x16, atm_action_cont
	call show_wallet
wallet_to_aa:
	LW x9, 0(x5)
atm_action_cont:
	ADDI x29, x29, -1
	LW x10, 0(x4)
	call sw_oneshot
	ADDI x29, x29, 1
	SW x9, 0(x7)
	SW x9, 0(x6)
	BEQ x10, x13, atm
	BNE x10, x14, atm_action_loop
amount_sel:
	SW x16, 0(x8)
	BGTU x9, x24, amount_toobig
	LI x20, MAX_VAL
	BEQ x24, x30, wal_to_bank_lim
	SUB x20, x20, x30
	SUB x20, x20, x9
	BLTZ x20, atm_cpu_int_limit
	J amount_sel_cont
wal_to_bank_lim:
	SUB x20, x20, x31
	SUB x20, x20, x9
	BLTZ x20, atm_cpu_int_limit
amount_sel_cont:
	LI x20, 0xFE092 # SSEG Imm for YES
	MV x22, x20
	SW x22, 0(x7)
amount_sel_loop:
	LW x10, 0(x4)
	call sw_oneshot
	BEQ x10, x14, check_atm_action
	BEQ x10, x12, switch_aa_conf
	BEQ x10, x16, switch_aa_conf
	J amount_sel_loop
atm_cpu_int_limit:
	LI x11, 0x24628 # SSEG Imm for Err0
	J atm_err
switch_aa_conf:
	BEQ x22, x20, switch_aa_no
	LI x20, 0xFE092
	SW x20, 0(x7)
	J amount_sel_loop
switch_aa_no:
	LI x20, 0xFFDAE # SSEG Imm for NO
	SW x20, 0(x7)
	J amount_sel_loop
amount_toobig:
	LI x11, 0x2462E # SSEG Imm for Err0
atm_err:
	SW x11, 0(x7)
	LI x25, ONE_SEC
	LI x26, 2
atm_count2:		
	ADDI x25, x25, -1
	BNEZ x25, atm_count2	
	ADDI x26, x26, -1
	BEQZ x26, atm_action_setup
	LI x25, ONE_SEC
	J atm_count2
check_atm_action:	
	BNE x22, x20, atm_action_setup
	BEQZ x23, perform_wdraw
	SUB x30, x30, x9
	LI x10, MAX_VAL
	SUB x10, x10, x9
	BGTU x31, x10, set_bank_max
	ADD x31, x31, x9
	J atm
perform_wdraw:
	SUB x31, x31, x9
	LI x10, MAX_VAL
	SUB x10, x10, x9
	BGTU x30, x10, set_wallet_max
	ADD x30, x30, x9
	J atm
set_bank_max:
	LI x31, MAX_VAL
	J atm
set_wallet_max:
	LI x30, MAX_VAL
	J atm
# ##################################################

# ##################################################
# Slot Delays
show_slot: # Delay for showing resulting 4-digits
	LI x26, ONE_SEC # Delay Count for about 1 sec
	LI x27, 3 # Repeat three times for 3 sec total
	SW x0, 0(x6)
slot_count:
	ADDI x26, x26, -1
	BNEZ x26, slot_count
	ADDI x27, x27, -1
	LI x26, ONE_SEC
	BNEZ x27, slot_count
	ret

show_result: # Delay for showing win or loss
	LI x18, ONE_SEC # Delay Count for about 1 sec
	LI x19, 2 # 2 sec total
result_count:
	ADDI x18, x18, -1
	BNEZ x18, result_count
	ADDI x19, x19, -1
	LI x18, ONE_SEC
	BNEZ x19, result_count
	ret

led_delay: # Delay for cycling between LEDs
	LI x26, 0x4E200
l_d_count:
	ADDI x26, x26, -1
	BNEZ x26, l_d_count
	ret
# ##################################################

# ##################################################
# Slots
slots:
	call switch_sseg_delay
	call bet
	BEQ x25, x16, main_board # User wants to go back to main
	LI x9, 0
	LI x25, 0
	LI x29, 0
	LI x21, SLOT_NUM
	LI x23, SLOT_ON
	SW x16, 0(x8) # Letter Mode
	LI x26, 0x7D247 # SSEG Imm for PUSH
	SW x26, 0(x7)
push_wait:	
	LW x10, 0(x4)
	call sw_oneshot
	BNE x10, x14, push_wait
cycling_setup:
	SW x0, 0(x8) # Number Mode
	LI x11, 40
	LI x20, 1
	LI x22, 0x8000
	LW x17, 0(x21)
	SW x17, 0(x7)
	SW x16, 0(x23)
cycling:
	LW x17, 0(x21)
	SW x20, 0(x6)
	SLLI x20, x20, 1
	call led_delay
	SW x20, 0(x6)
	SLLI x20, x20, 1
	call led_delay
	SW x20, 0(x6)
	SLLI x20, x20, 1
	call led_delay
	SW x20, 0(x6)
	SLLI x20, x20, 1
	call led_delay
	SW x17, 0(x7)
	ADDI x9, x9, 1
	BEQ x9, x11, start_checks
	BLTU x20, x22, cycling
	LI x20, 1
	J cycling
start_checks:
	call show_slot
	SW x0, 0(x23)
	LI x18, SLOT_BCD_IN
	SW x17, 0(x18)
	LI x9, 9
	LI x10, -9
	LI x18, -1
	LI x21, SLOT_BCD_OUT
	LW x17, 0(x21)
	LI x19, 1	
	LI x20, 0
	LI x21, 0
	SRLI x23, x17, 4 # x23: Third Digit
	SRLI x24, x17, 8 # x24: Second Digit
	SRLI x25, x17, 12 # x25: First Digit
	ANDI x22, x17, 0x000F # x22: Fourth/Last Digit
	ANDI x23, x23, 0x000F
	ANDI x24, x24, 0x000F
	ANDI x25, x25, 0x000F
check_fours:
	LI x26, 0x2BA91 # SSEG Imm for FOUR
	BNE x22, x23, check_straight
	BNE x22, x24, check_straight
	BEQ x22, x25, win_setup
check_straight:
	LI x26, 0x94E20 # SSEG Imm for STRA
	SUB x17, x23, x22
	BLTZ x17, s_set_back
	LI x21, 1
	J str_check
s_set_back:	
	LI x20, 1
str_check:	
	BEQ x17, x16, str_pos # Difference is 1	
	BEQ x17, x18, str_neg # Difference is -1
	BEQ x17, x10, straight_for # Difference is -9
	BEQ x17, x9, straight_back # Difference is 9
	J check_threes
str_pos:	
	BLT x21, x16, check_threes
	J straight_three
str_neg:	
	BLT x20, x16, check_threes
	J straight_three
straight_for:	
	BGTU x21, x16, check_threes
	BGEU x20, x16, check_threes
	ADDI x21, x21, 1
	J straight_three
straight_back:	
	BGTU x20, x16, check_threes
	BGEU x21, x16, check_threes
	ADDI x20, x20, 1
straight_three: 
	BEQ x19, x15, straight_two
	BGTU x19, x15, win_setup
	SUB x17, x24, x23
	ADDI x19, x19, 1
	J str_check
straight_two:	
	SUB x17, x25, x24
	ADDI x19, x19, 1
	J str_check
check_threes:	
	LI x26, 0x99E24 # SSEG Imm for THRE
	BEQ x22, x23, check_th_two
	BEQ x23, x24, check_th_t_two
check_th_two:	
	BEQ x22, x24, check_th_th
	J check_o_e
check_th_t_two: 
	BEQ x23, x24, check_th_t_th
	J check_o_e
check_th_th:	
	BEQ x22, x25, win_setup
	J check_o_e
check_th_t_th:	
	BEQ x23, x25, win_setup
check_o_e:	
	LI x26, 0x2548D # SSEG Imm for EVEN
	LI x20, 0
	MV x21, x22
	AND x21, x21, x16
	BEQZ x21, check_o_e_cont # Number is even, check for other evens
check_oe_one:	
	LI x20, 1
	LI x26, 0x70C72 # SSEG Imm for ODDS
check_o_e_cont:
	MV x21, x23
	AND x21, x21, x16
	BNE x21, x20, check_twos
	MV x21, x24
	AND x21, x21, x16
	BNE x21, x20, check_twos
	MV x21, x25
	AND x21, x21, x16
	BEQ x21, x20, win_setup
check_twos:	
	LI x26, 0x78111 # SSEG Imm for PAIR
	BEQ x22, x23, win_setup
	BEQ x22, x24, win_setup
	BEQ x22, x25, win_setup
	BEQ x23, x24, win_setup
	BEQ x23, x25, win_setup
	BEQ x24, x25, win_setup
loss_setup:	
	LI x19, 0x5BA52 # SSEG Imm for LOSS
	SW x0, 0(x6) 
	LI x20, 0
	J result
win_setup:
	LI x19, 0xFFFF
	SW x19, 0(x6)
	LI x19, 0xB6D0D # SSEG Imm for WIN
	LI x20, 1
result:
	SW x16, 0(x8) # Letter Mode
	SW x19, 0(x7)
	call show_result
	SW x0, 0(x6)
	BEQ x29, x16, bj_result # If gamemode is 21, go back to 21
	BEQZ x20, slots # If player loss, go back to slots
s_show_win:
	SW x26, 0(x7)
	call show_result
slot_payout:
	LI x9, 0x2BA91 # Four of a Kind
	BEQ x9, x26, four_payout
	LI x9, 0x94E20 # Straight(Four in a Row)
	BEQ x9, x26, straight_payout
	LI x9, 0x99E24 # Three of a Kind
	BEQ x9, x26, three_payout
	LI x9, 0x70C72 # All Odd Numbers
	BEQ x9, x26, odds_payout
	LI x9, 0x2548D # All Even Numbers
	BEQ x9, x26, evens_payout
	LI x9, 0x78111 # Two of a Kind (Pair)
	BEQ x9, x26, pair_payout
	J slots
four_payout:
	LI x9, 496
	J returnbet
straight_payout:
	LI x9, 248
	J returnbet
three_payout:
	LI x9, 13
	J returnbet
odds_payout:
	LI x9, 9
	J returnbet	
evens_payout:
	LI x9, 8
	J returnbet
pair_payout:
	LI x9, 1
returnbet:
	ADD x30, x30, x28
	ADDI x9, x9, -1
	BNEZ x9, returnbet
	J slots
# ##################################################

# ##################################################
# Switch SSEG Delay (to help with stopping multiple presses)
switch_sseg_delay:
	LI x10, ONE_MSEC
	LI x11, 75
ssd_loop:
	ADDI x10, x10, -1
	BNEZ x10, ssd_loop
	ADDI x11, x11, -1
	LI x10, ONE_MSEC
	BNEZ x11, ssd_loop
	ret
# ##################################################

# ##################################################
# Bet
bet:
	SW x16, 0(x8) # Letter Mode
	LI x19, 0xF8493 # SSEG Imm for BET
	LI x22, 0x1000
	LI x23, 0xFFFF
	SW x19, 0(x7)
	LI x26, ONE_SEC # Delay Count for about 1 sec
bet_count1:
	ADDI x26, x26, -1
	BNEZ x26, bet_count1
bet_loop_setup:
	SW x0, 0(x8) # Number Mode
bet_loop:
	LW x9, 0(x5)
	LW x10, 0(x4)
	AND x9, x9, x23
	BNE x9, x22, bet_loop_cont
	BEQ x10, x12, bet_s_bank
	BEQ x10, x16, bet_s_wallet
bet_loop_cont:
	SW x9, 0(x6)
	SW x9, 0(x7)
bet_oneshot:
	MV x11, x10
	LW x10, 0(x4)
	BEQ x10, x12, bet_os_fin
	BEQ x10, x16, bet_os_fin
	BNEZ x10, bet_oneshot
bet_os_fin:
	MV x10, x11
	BEQ x10, x14, select_bet
	BEQ x10, x13, bet_go_back
	J bet_loop
bet_s_wallet:
	LI x10, 0x00FF
	SW x10, 0(x6)
	SW x30, 0(x7)
	MV x10, x16
	J bet_wallet_loop
bet_s_bank:
	LI x10, 0xFF00
	SW x10, 0(x6)
	SW x31, 0(x7)
	MV x10, x12
bet_wallet_loop:	
	LW x9, 0(x5)
	BNE x9, x22, bet_loop
	LW x9, 0(x4)
	BEQ x9, x10, bet_wallet_loop
	BEQ x9, x12, bet_s_bank
	BEQ x9, x16, bet_s_wallet
	J bet_loop
bet_go_back:	
	LI x25, 1
	ret 
select_bet:	
	SW x16, 0(x8) # Letter Mode
	BLTU x30, x9, bet_too_big
	LI x20, 496
	MV x21, x30
	SUB x21, x21, x9
	LI x25, MAX_VAL
	SUB x25, x25, x21
	LI x26, 0
highest_payout:
	ADD x26, x26, x9
	ADDI x20, x20, -1
	BNEZ x20, highest_payout
	SUB x25, x25, x26
	BLTZ x25, cpu_int_limit
continue_bet:
	LI x20, 0xFE092 # SSEG Imm for YES
	LI x21, 1
	SW x20, 0(x7)
s_bet_loop:	
	LW x10, 0(x4)
s_bet_oneshot:
	MV x11, x10
	LW x10, 0(x4)
	BNEZ x10, s_bet_oneshot
	MV x10, x11
	BEQ x10, x14, check_answer_b
	BEQ x10, x12, switch_bet
	BEQ x10, x16, switch_bet
	J s_bet_loop
switch_bet:	
	BEQ x21, x16, s_bet_no
	LI x20, 0xFE092
	SW x20, 0(x7)
	ADDI x21, x21, 1
	J s_bet_loop
s_bet_no:
	LI x20, 0xFFDAE # SSEG Imm for NO
	SW x20, 0(x7)
	ADDI x21, x21, -1
	J s_bet_loop
cpu_int_limit:
	LI x11, 0x24628 # SSEG Imm for Err1
	J show_bet_error
bet_too_big:
	LI x11, 0x2462E # SSEG Imm for Err0
show_bet_error:
	SW x11, 0(x7)
	LI x25, ONE_SEC
	LI x26, 2
bet_count2:	
	ADDI x25, x25, -1
	BNEZ x25, bet_count2
	LI x25, ONE_SEC
	ADDI x26, x26, -1
	BNEZ x26, bet_count2
	J bet_loop_setup
check_answer_b: 
	BEQZ x21, bet_loop_setup
	BEQZ x9, bet_loop_setup
	LI x25, 0
	SW x0, 0(x6)
	MV x28, x9
	SUB x30, x30, x28
	ret
# ##################################################

# ##################################################
# Functions for Blackjack (21)
show_card_total:
	LI x18, ONE_SEC
sct_loop:
	ADDI x18, x18, -1
	BNEZ x18, sct_loop
	ret
# ##################################################

# ##################################################
# Blackjack (21)
blackjack:
	call switch_sseg_delay
	call bet
	BEQ x25, x16, main_board # User wants to go back to main
	LI x9, 0
	LI x11, 0
	LI x20, 0x1000
	LI x21, BLACKJACK # Address for Random Card Number
	LI x22, 0
	LI x23, 0
	LI x24, 0
	LI x25, 21
	LI x29, 1
bj_first:	
	LW x23, 0(x21)
	LW x9, 0(x21)
	ADD x23, x23, x9
	SW x0, 0(x8) # Number Mode
	SW x23, 0(x7)
	call show_card_total
	call show_card_total
	J bj_hit_check
bj_loop_setup:
	SW x16, 0(x8) # Letter Mode
	LI x26, 0xF9D13 # SSEG Imm for HIT
	MV x27, x26
	SW x26, 0(x7)
bj_loop:
	LW x9, 0(x5)
	BEQ x9, x20, bj_plyr_show
	LW x10, 0(x4)
	call sw_oneshot
	BEQ x10, x16, bj_switch
	BEQ x10, x12, bj_switch
	BEQ x10, x14, bj_sel
	J bj_loop
bj_plyr_show:
	SW x0, 0(x8)
	SW x23, 0(x7)
	SW x23, 0(x6)
bps_loop:
	LW x9, 0(x5)
	BEQ x9, x20, bps_loop
	SW x0, 0(x6)
	SW x26, 0(x7)
	SW x16, 0(x8)
	J bj_loop
bj_switch:	
	BEQ x27, x26, bj_s_stay
	LI x27, 0xF9D13
	SW x27, 0(x7)
	J bj_loop
bj_s_stay:	
	LI x27, 0x94C18 # SSEG Imm for STAY
	SW x27, 0(x7)
	J bj_loop
bj_sel:
	BNE x27, x26, bj_stay
bj_hit:	
	LW x11, 0(x21)
	ADD x23, x23, x11
	SW x0, 0(x8)
	SW x23, 0(x7)
	call show_card_total
bj_hit_check:
	BGTU x23, x25, loss_setup
	BEQ x23, x25, bj_dealer
	J bj_loop_setup
bj_stay:
	SW x0, 0(x8)
	SW x23, 0(x7)
	call show_card_total
	call show_card_total
bj_dealer:
	LI x26, 0
	SW x16, 0(x8)
	LI x9, 0xF8D71 # SSEG Imm for DLR
	SW x9, 0(x7)
	LI x20, ONE_SEC
bj_dlr_count1:
	ADDI x20, x20, -1
	BNEZ x20, bj_dlr_count1
	LW x24, 0(x21)
	LW x9, 0(x21)
	ADD x24, x24, x9
	SW x0, 0(x8) # Number Mode
bj_dlr_show:
	SW x24, 0(x7)
	call show_card_total
	BGTU x24, x25, win_setup
	BGTU x24, x23, loss_setup
	BEQ x24, x23, bj_tie_check
	BGTU x26, x15, win_setup
bj_dlr_hit:
	LW x9, 0(x21)
	ADD x24, x24, x9
	ADDI x26, x26, 1
	J bj_dlr_show
bj_tie_check:
	BNE x24, x25, bj_dlr_hit
	LI x9, 0xFCD04 # SSEG Imm for TIE
	SW x16, 0(x8)
	call show_result
	ADD x30, x30, x28
	J blackjack
bj_result:
	BEQZ x20, blackjack
	ADD x30, x30, x28
	ADD x30, x30, x28
	J blackjack
# ##################################################
