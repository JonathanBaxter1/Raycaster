%include "header.asm"

ORG 0
BITS 16

%define ENDL 0x0D, 0x0A

boot_start:
_start:
	jmp short start
	nop

times 33 db 0

start:
	jmp 0x7c0:start2

start2:
	cli
	mov ax, 0x7c0
	mov ds, ax
	mov sp, 0x7c00
	sti

; Main
start3:
	; set video mode
	mov ax, 0x0013
	int 0x10

	; Check USB label
	cmp dl, 0x80
	jae usb_good

	; USB is labeled as floppy (error)
	mov ax, 0xA000
	mov es, ax
	mov di, 0x2000
	mov al, 0x28
	stosb
	jmp $

usb_good:

	; move bootloader to 0x0600
	mov ax, 0x0000
	mov es, ax
	mov si, 0x0000
	mov di, 0x0600
	mov cx, 256
	rep movsb

	jmp 0x0060:boot_location2

boot_location2:

	; copy program to RAM
	cli
	mov ax, 0x0060
	mov ds, ax
	sti
	mov si, disk_addr_packet
	mov ah, 0x42
	int 0x13

	; Setup segment registers
	cli
	mov ax, 0x7c0
	mov ds, ax
	mov ax, 0xA000
	mov es, ax
	mov sp, 0x7c00
	sti
	jmp 0x07c0:0x0000

; Data

disk_addr_packet:
	db 0x10
	db 0x00
block_count: dw NUM_SECTORS
db_address: dw 0x7c00
	dw 0x00
	dd 1
	dd 0

boot_end:
times 510-($ - $$) db 0
dw 0xAA55
