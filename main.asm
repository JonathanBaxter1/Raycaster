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

	; Correct Distance to wall
	push bx
	mov ax, [.pixel_x] ; abs(pixel_x - 160)
	sub ax, 160
	mov bx, ax
	sar bx, 15
	xor ax, bx
	sub ax, bx
	shl ax, 1
	mov si, perspective_correct_table160
	add si, ax
	lodsw
	mul cx
	mov bx, 32768
	div bx
	mov cx, ax
.test:
	pop bx

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
	mov bx, 256
	mul bx
	inc cx ; maybe?
	div cx
	mov [.slope], ax

	; x lines
	mov ax, [player_x]
	shr ax, 10
	inc ax
	shl ax, 10
	mov [.cur_x], ax
	sub ax, [player_x]
	mul word [.slope]
	mov cx, 256
	div cx
	add ax, [player_y]
	mov [.cur_y], ax
.quad1sec1loop_x:
	; check map
	mov ax, [.cur_x]
	shr ax, 10
	mov bx, [.cur_y]
	shr bx, 10
	shl bx, 3
	mov si, map
	add si, bx
	add si, ax
	lodsb
	cmp al, 0
	jne .quad1sec1wall_x

	add word [.cur_x], 1024
	mov ax, 1024
	mul word [.slope]
	mov cx, 256
	div cx
	add [.cur_y], ax
	jmp .quad1sec1loop_x

.quad1sec1wall_x:
	mov ax, [.cur_x]
	mov [.min_x], ax
	mov word [.cur_x], 65535
	cmp byte [.slope], 0
	je .quad1sec1wall_y

	; y lines
	mov ax, [player_y]
	shr ax, 10
	inc ax
	shl ax, 10
	mov [.cur_y], ax
	sub ax, [player_y]
	mov cx, 256
	mul cx
	div word [.slope]
	add ax, [player_x]
	mov [.cur_x], ax
.quad1sec1loop_y:
	; check map
	mov ax, [.cur_x]
	shr ax, 10
	mov bx, [.cur_y]
	shr bx, 10
	shl bx, 3
	mov si, map
	add si, bx
	add si, ax
	lodsb
	cmp al, 0
	jne .quad1sec1wall_y

	add word [.cur_y], 1024
	mov ax, 1024
	mov cx, 256
	mul cx
	div word [.slope]
	add [.cur_x], ax
	jmp .quad1sec1loop_y


.quad1sec1wall_y:
	; calculate distance from player
	mov cx, [.min_x]
	cmp cx, [.cur_x]
	mov byte [.color], 0x20
	jbe .quad1sec1min_x
	mov cx, [.cur_x]
	mov byte [.color], 0x28
.quad1sec1min_x:
	sub cx, [player_x]

	mov bx, [.slope]
	shl bx, 1
	mov si, perspective_correct_table256
	add si, bx
	lodsw
	mov bx, ax
	mov ax, 32768
	mul cx
	div bx
	mov cx, ax

	jmp .end_cast_ray
.quad1sec2:
;	mov byte [.color], 0x20
	mov cx, 32768
	jmp .end_cast_ray


.not_quadrant_1:
	mov cx, 65535
.end_cast_ray:
	mov bh, [.color]
;	mov bh, 0x20
	ret
;.first_step: db 0
.dx2: dw 0
.dy2: dw 0
.slope: dw 0
.cur_x: dw 0
.cur_y: dw 0
.min_x: dw 0
.color: db 0x20

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

perspective_correct_table160:
	dw 32768, 32767, 32765, 32762, 32757, 32752, 32744, 32736
	dw 32727, 32716, 32704, 32690, 32676, 32660, 32643, 32624
	dw 32605, 32584, 32562, 32539, 32514, 32489, 32462, 32434
	dw 32405, 32375, 32343, 32311, 32277, 32242, 32206, 32169
	dw 32131, 32092, 32052, 32011, 31968, 31925, 31881, 31835
	dw 31789, 31742, 31694, 31645, 31595, 31544, 31492, 31439
	dw 31386, 31331, 31276, 31220, 31163, 31105, 31047, 30988
	dw 30928, 30867, 30806, 30744, 30681, 30618, 30554, 30489
	dw 30424, 30358, 30292, 30224, 30157, 30089, 30020, 29951
	dw 29881, 29811, 29741, 29670, 29598, 29526, 29454, 29381
	dw 29308, 29235, 29161, 29087, 29012, 28937, 28862, 28787
	dw 28711, 28635, 28559, 28483, 28406, 28329, 28252, 28175
	dw 28098, 28020, 27943, 27865, 27787, 27709, 27630, 27552
	dw 27474, 27395, 27317, 27238, 27159, 27080, 27002, 26923
	dw 26844, 26765, 26686, 26608, 26529, 26450, 26371, 26293
	dw 26214, 26135, 26057, 25978, 25900, 25821, 25743, 25665
	dw 25587, 25509, 25431, 25353, 25276, 25198, 25121, 25044
	dw 24967, 24890, 24813, 24736, 24660, 24584, 24508, 24432
	dw 24356, 24280, 24205, 24130, 24054, 23980, 23905, 23831
	dw 23756, 23682, 23608, 23535, 23461, 23388, 23315, 23242
	dw 23170

perspective_correct_table256:
	dw 32768, 32767, 32767, 32765, 32764, 32761, 32759, 32755
	dw 32752, 32747, 32743, 32737, 32732, 32725, 32719, 32711
	dw 32704, 32695, 32687, 32678, 32668, 32658, 32647, 32636
	dw 32624, 32612, 32600, 32587, 32573, 32559, 32545, 32530
	dw 32514, 32499, 32482, 32465, 32448, 32431, 32412, 32394
	dw 32375, 32355, 32335, 32315, 32294, 32273, 32251, 32229
	dw 32206, 32183, 32160, 32136, 32112, 32087, 32062, 32036
	dw 32011, 31984, 31958, 31930, 31903, 31875, 31847, 31818
	dw 31789, 31760, 31730, 31700, 31669, 31638, 31607, 31576
	dw 31544, 31511, 31479, 31446, 31412, 31379, 31345, 31311
	dw 31276, 31241, 31206, 31170, 31134, 31098, 31062, 31025
	dw 30988, 30950, 30913, 30875, 30837, 30798, 30759, 30720
	dw 30681, 30642, 30602, 30562, 30521, 30481, 30440, 30399
	dw 30358, 30316, 30275, 30233, 30191, 30148, 30106, 30063
	dw 30020, 29977, 29934, 29890, 29846, 29802, 29758, 29714
	dw 29670, 29625, 29580, 29535, 29490, 29445, 29399, 29354
	dw 29308, 29262, 29216, 29170, 29124, 29077, 29031, 28984
	dw 28937, 28891, 28844, 28796, 28749, 28702, 28654, 28607
	dw 28559, 28512, 28464, 28416, 28368, 28320, 28272, 28224
	dw 28175, 28127, 28078, 28030, 27981, 27933, 27884, 27835
	dw 27787, 27738, 27689, 27640, 27591, 27542, 27493, 27444
	dw 27395, 27346, 27297, 27248, 27199, 27149, 27100, 27051
	dw 27002, 26952, 26903, 26854, 26805, 26755, 26706, 26657
	dw 26608, 26558, 26509, 26460, 26411, 26361, 26312, 26263
	dw 26214, 26165, 26116, 26067, 26017, 25968, 25919, 25870
	dw 25821, 25773, 25724, 25675, 25626, 25577, 25529, 25480
	dw 25431, 25383, 25334, 25286, 25237, 25189, 25140, 25092
	dw 25044, 24996, 24947, 24899, 24851, 24803, 24756, 24708
	dw 24660, 24612, 24565, 24517, 24470, 24422, 24375, 24327
	dw 24280, 24233, 24186, 24139, 24092, 24045, 23998, 23952
	dw 23905, 23858, 23812, 23766, 23719, 23673, 23627, 23581
	dw 23535, 23489, 23443, 23397, 23352, 23306, 23261, 23215


; Exception Handlers
divide_exception:
	mov dx, 0
	mov ax, 65535
	mov cx, 1
	iret


times NUM_SECTORS*512-($-$$) db 0
