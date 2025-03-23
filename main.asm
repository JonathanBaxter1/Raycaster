ORG 0
BITS 16

program_start:

.loop:
	call wait_frame
	call clear_screen
	call draw_map
	call draw_player

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

draw_line:
	; cx = height
	; di = x coordinate
	mov al, 0x20
	stosb
	add di, 320
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
	db 1,0,1,0,0,0,0,1
	db 1,0,1,0,0,1,1,1
	db 1,0,0,0,0,0,0,1
	db 1,0,0,1,0,0,0,1
	db 1,0,1,0,0,0,0,1
	db 1,1,1,0,0,0,0,1
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


times 1024-($-$$) db 0
