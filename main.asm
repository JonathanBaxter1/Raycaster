%include "header.asm"

ORG 0
BITS 16

program_start:
	; Setup IVT
	push ds
	mov ax, 0
	mov ds, ax
	mov word [ds:0x0000], divide_exception
	mov ax, cs
	mov word [ds:0x0002], ax
	pop ds

.loop:
	call wait_frame
	call clear_screen
	call draw_map
	call draw_player
	call render_3d


	call handle_keyboard
	jmp .loop

; Functions
render_3d:
	mov word [.pixel_x], 0

	; Calculate dx1 and dy1 (slope for ray aligned with player angle)
	; dx1 and dy1 values are 15 bit signed ints (-16384 to 16383)
	mov byte al, [player_dx]
	cbw
	shl ax, 7
	mov [.dx1], ax
	mov byte al, [player_dy]
	cbw
	shl ax, 7
	mov [.dy1], ax
.loop:
	; Code here
	; calculate angle/slope
	; reg bx = x
	mov ax, [.pixel_x]
	mov bx, 160
	sub ax, bx
	imul word [.dy1]
	idiv bx
	add ax, [.dx1]
	mov bx, ax

	; reg cx = y
	mov ax, [.pixel_x]
	mov cx, 160
	sub ax, cx
	imul word [.dx1]
	idiv cx
	neg ax
	add ax, [.dy1]
	mov cx, ax

	; Find nearest wall
	call cast_ray

	; Draw slice of wall
	mov di, [.pixel_x]
	call draw_slice

	; inc pixel x and repeat
	inc word [.pixel_x]
	cmp word [.pixel_x], 320
	jb .loop
	ret
.pixel_x:
	dw 0
.dx1:
	dw 0
.dy1:
	dw 0

cast_ray:
	; Inputs:
	; bx = delta x (signed int)
	; cx = delta y (signed int)
	; Outputs:
	; cx = distance to wall
	; bh = color

;	mov [.first_step], 1

	mov [.dx2], bx
	mov [.dy2], cx

	; if delta_x >= 0 && delta_y >= 0, cx = 2048
	cmp bx, 0
	jl .not_quadrant_1
	cmp cx, 0
	jl .not_quadrant_1

	; Quadrant 1

	; if dx2 >= dy2, goto quad1sec2
	mov ax, [.dx2]
	cmp ax, [.dy2]
	jge .quad1sec2

.quad1sec1:
	; calculate slope
	mov ax, [.dx2]
	mov cx, [.dy2]
	shr cx, 8
	inc cx ; maybe?
	div cl
	mov [.slope], al

	; x lines
	mov ax, [player_x]
	shr ax, 10
	inc ax
	mov bx, ax
	sub ax, [player_x]
;	mul word [.slope]
;	mov cx, 256
;	div cx
;	add ax, [player_y]
	mov cx, ax
	shr cx, 4

	; calculate distance from player
;	sub cx, [player_y]
;	mov cx, 2048
	jmp .end_cast_ray
.quad1sec2:
	mov cx, 4096
	jmp .end_cast_ray


.not_quadrant_1:
	mov cx, 65535
.end_cast_ray:
	mov bh, 0x20
	ret
;.first_step: db 0
.dx2: dw 0
.dy2: dw 0
.slope: dw 0

handle_keyboard:
	mov word [player_speed_x], 0
	mov word [player_speed_y], 0
	in al, 0x60
	cmp al, 0x11
	mov bl, al
	jne .skip_w
	mov al, [player_dy]
	cbw
	add [player_speed_x], ax
	mov al, [player_dx]
	cbw
	add [player_speed_y], ax
	mov al, bl
.skip_w:
	cmp al, 0x1E
	mov bl, al
	jne .skip_a
	mov al, [player_dy]
	cbw
	sub [player_speed_y], ax
	mov al, [player_dx]
	cbw
	add [player_speed_x], ax
	mov al, bl
.skip_a:
	mov bl, al
	cmp al, 0x1F
	jne .skip_s
	mov al, [player_dy]
	cbw
	sub [player_speed_x], ax
	mov al, [player_dx]
	cbw
	sub [player_speed_y], ax

.skip_s:
	cmp al, 0x20
	mov bl, al
	jne .skip_d
	mov al, [player_dy]
	cbw
	add [player_speed_y], ax
	mov al, [player_dx]
	cbw
	sub [player_speed_x], ax
	mov al, bl
.skip_d:
	cmp al, 0x4B
	jne .skip_left_arrow
	inc word [player_angle_int]
	and word [player_angle_int], 32-1
	mov si, cos_table
	add si, [player_angle_int]
	lodsb
	mov byte [player_dx], al
	mov si, sin_table
	add si, [player_angle_int]
	lodsb
	mov byte [player_dy], al
.skip_left_arrow:
	cmp al, 0x4D
	jne .skip_right_arrow
	dec word [player_angle_int]
	and word [player_angle_int], 32-1
	mov si, cos_table
	add si, [player_angle_int]
	lodsb
	mov byte [player_dx], al
	mov si, sin_table
	add si, [player_angle_int]
	lodsb
	mov byte [player_dy], al
.skip_right_arrow:

	; Move player
	mov ax, [player_x]
	add ax, [player_speed_x]
	shr ax, 10
	mov bx, [player_y]
	shr bx, 10
	shl bx, 3
	add ax, bx
	mov si, map
	add si, ax
	lodsb
	cmp ax, 0
	jne .skip_player_move_x
	mov ax, [player_speed_x]
	add word [player_x], ax
.skip_player_move_x:
	mov ax, [player_y]
	add ax, [player_speed_y]
	shr ax, 10
	shl ax, 3
	mov bx, [player_x]
	shr bx, 10
	add ax, bx
	mov si, map
	add si, ax
	lodsb
	cmp ax, 0
	jne .skip_player_move_y
	mov ax, [player_speed_y]
	add word [player_y], ax
.skip_player_move_y:
	ret

clear_screen:
	mov al, 0
	mov di, 0
	mov cx, 320*200
	rep stosb
	ret

wait_frame:
	; 18.2 FPS
.loop:
	mov ah,0x00
	int 0x1a
	cmp dx, [.last_time]
	je .loop
	mov [.last_time], dx
	ret
.last_time: dw 0

draw_player:
	mov bx, [player_x]
	mov ax, [player_y]
	shr ax, 7
	shr bx, 7
	mov cx, 320
	mul word cx
	add ax, bx
	mov di, ax
	mov ax, 0x20
	stosb
	ret

draw_map:
	mov cx, 8*8
	mov word [.i], 0
	mov si, map
.loop:
	push cx
	lodsb
	mov ah, 0
	cmp ax, 0
	je .skip_block
	dec ax
	mov bx, 8*8
	mul word bx
	push si
	mov si, sprites
	add si, ax
	mov bx, [.i]
	and bx, 8-1
	shl bx, 3
	mov ax, [.i]
	shr ax, 3
	shl ax, 3
	call draw_sprite8
	pop si
.skip_block:
	pop cx
	inc word [.i]
	loop .loop
	ret
.i: dw 0

draw_slice:
	; cx = distance from wall
	; di = x coordinate
	; bh = color

	; if dis < 820, len = 200
	cmp cx, 820
	jb .max_len

	; len = 163840/dis
	mov ax, 32768
	mov dx, 2
	div cx
	mov cx, ax

	jmp .not_max_len
.max_len:
	mov cx, 200
.not_max_len:

	shr cl, 1
	mov al, 100
	sub al, cl
	mov bl, 5
	mul bl
	shl ax, 6
	add di, ax
	shl cl, 1
	mov al, bh ; color
.loop:
	stosb
	add di, 320-1
	loop .loop
	ret


draw_sprite8:
	; si = sprite pointer
	; bx = x coordinate
	; ax = y coordinate
	mov cx, 320
	mul word cx
	add ax, bx
	mov di, ax
	mov cx, 8
.loop:
	push cx
	mov cx, 8
	rep movsb
	pop cx
	add di, 320-8
	loop .loop
	ret

; Data
player_x: dw 12*128
player_y: dw 12*128
player_angle_int: dw 0
player_dx: db 127
player_dy: db 0

player_speed_x: dw 0
player_speed_y: dw 0


sprites:
sprite1:
	db 28h, 28h, 28h, 28h, 28h, 28h, 28h, 28h
	db 28h, 2fh, 2ah, 2ah, 2ah, 2ah, 2fh, 28h
	db 28h, 2ah, 2fh, 2ah, 2ah, 2fh, 2ah, 28h
	db 28h, 2ah, 2ah, 2fh, 2fh, 2ah, 2ah, 28h
	db 28h, 2ah, 2ah, 2fh, 2fh, 2ah, 2ah, 28h
	db 28h, 2ah, 2fh, 2ah, 2ah, 2fh, 2ah, 28h
	db 28h, 2fh, 2ah, 2ah, 2ah, 2ah, 2fh, 28h
	db 28h, 28h, 28h, 28h, 28h, 28h, 28h, 28h

map:
	db 1,1,1,1,1,1,1,1
	db 1,0,0,0,0,0,0,1
	db 1,0,0,0,0,0,0,1
	db 1,0,0,0,1,0,0,1
	db 1,0,0,0,1,0,0,1
	db 1,0,0,0,1,0,0,1
	db 1,0,0,0,1,0,0,1
	db 1,1,1,1,1,1,1,1

sin_table:
	db 0,24,48,70,90,106,117,125
	db 127,125,117,106,90,70,48,24
	db 0,-25,-49,-71,-91,-107,-118,-126
	db -128,-126,-118,-107,-91,-71,-49,-25

cos_table:
	db 127,125,117,106,90,70,48,24
	db 0,-25,-49,-71,-91,-107,-118,-126
	db -128,-126,-118,-107,-91,-71,-49,-25
	db -1,24,48,70,90,106,117,125

; Exception Handlers
divide_exception:
	mov dx, 0
	mov ax, 65535
	mov cx, 1
	iret


times NUM_SECTORS*512-($-$$) db 0
