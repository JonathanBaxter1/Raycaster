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
handle_keyboard:
	mov word [player_speed_x], 0
	mov word [player_speed_y], 0
	in al, 0x60
	cmp al, 0x11
	mov bl, al
	jne .skip_w
	mov si, sin_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	add [player_speed_x], ax
	mov si, cos_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	add [player_speed_y], ax
	mov al, bl
.skip_w:
	cmp al, 0x1E
	mov bl, al
	jne .skip_a
	mov si, sin_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	sub [player_speed_y], ax
	mov si, cos_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	add [player_speed_x], ax
	mov al, bl
.skip_a:
	mov bl, al
	cmp al, 0x1F
	jne .skip_s
	mov si, sin_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	sub [player_speed_x], ax
	mov si, cos_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	sub [player_speed_y], ax

.skip_s:
	cmp al, 0x20
	mov bl, al
	jne .skip_d
	mov si, sin_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	add [player_speed_y], ax
	mov si, cos_table
	add si, [player_angle_int]
	mov al, [si]
	cbw
	sub [player_speed_x], ax
	mov al, bl
.skip_d:
	cmp al, 0x4B
	jne .skip_left_arrow
	inc word [player_angle_int]
	and word [player_angle_int], 32-1
.skip_left_arrow:
	cmp al, 0x4D
	jne .skip_right_arrow
	dec word [player_angle_int]
	and word [player_angle_int], 32-1
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

render_3d:
	mov word [.pixel_x], 0
.loop_x:
	; Vertical Scan
	mov word [.min_dis_v], 65535
	mov byte [.first_loop_var], 1
	mov bx, [player_x] ; cur x pos
	mov cx, [player_y] ; cur y pos
	shr bx, 10 ; map x pos
.loop_step_v:
	; dec map_x
	dec bx

	cmp byte [.first_loop_var], 0
	mov byte [.first_loop_var], 0
	je .not_first_loop_v

	push bx
	shl bx, 10
	sub bx, [player_x]
	neg bx
	mov ax, 160
	mul cx ; changes dx
	mov cx, [.pixel_x]
	cmp cx, 0
	jne .cx_not_0 ; to prevent divide by 0
	pop bx
	jmp .end_loop_step_v
.cx_not_0:
	div cx ; changes dx
	add cx, ax
	pop bx
	jmp .first_loop_v
.not_first_loop_v:
	push bx
	mov dx, 2
	mov ax, 32768
	mov cx, [.pixel_x]
	div cx ; changes dx
	add cx, ax
	pop bx
.first_loop_v:
	; block = map[x, y]
	mov si, map
	mov ax, cx
	shr ax, 7
	mov dx, bx
	add ax, dx
	add si, ax
	lodsb

	; if block == 0 && map_x != 0, continue
	cmp bx, 0
	je .world_border
	cmp al, 0
	je .loop_step_v
.world_border:

	; dis = map_y*(2^10) - player_y
	sub cx, [player_y]
	mov [.min_dis_v], cx

.end_loop_step_v:
	; Horizontal Scan
	mov byte [.first_loop_var], 1
	mov bx, [player_x] ; cur x pos
	mov cx, [player_y] ; cur y pos
	shr cx, 10 ; map y pos
.loop_step_h:
	; inc map_y
	inc cx

	cmp byte [.first_loop_var], 0
	mov byte [.first_loop_var], 0
	je .not_first_loop_h

	push cx
	shl cx, 10
	sub cx, [player_y]
	mov ax, [.pixel_x]
	mul cx ; changes dx
	mov cx, 160
	div cx ; changes dx
	sub bx, ax
	pop cx
	jmp .first_loop_h
.not_first_loop_h:
	push cx
	mov ax, [.pixel_x]
	shl ax, 6
	mov cx, 10
	mov dx, 0
	div cx ; changes dx
	sub bx, ax
	pop cx
.first_loop_h:
	; block = map[x, y]
	mov si, map
	mov ax, cx
	shl ax, 3
	mov dx, bx
	shr dx, 10
	add ax, dx
	add si, ax
	lodsb

	; if block == 0, continue
	cmp al, 0
	je .loop_step_h

	; dis = map_y*(2^10) - player_y
	shl cx, 10
	sub cx, [player_y]

	; Find shortest path
	cmp [.min_dis_v], cx
	jnb .h_shortest_dis
	mov bh, 0x28
	mov cx, [.min_dis_v]
	jmp .render
.h_shortest_dis:
	mov bh, 0x20

.render:
	; Render
	mov di, [.pixel_x]
	add di, 160
	call draw_line

	inc word [.pixel_x]
	cmp word [.pixel_x], 160

	jne .loop_x
	ret
.first_loop_var:
	db 1
.min_dis_v:
	dw 65535
.pixel_x:
	dw 0


draw_line:
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
