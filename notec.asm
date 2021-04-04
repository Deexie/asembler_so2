default rel

ESCAPE_NUM_SIGN equ '='
ADD_SIGN        equ '+'
MUL_SIGN        equ '*'
NEG_SIGN        equ '-'
AND_SIGN        equ '&'
OR_SIGN         equ '|'
XOR_SIGN        equ '^'
NOT_SIGN        equ '~'
POP_SIGN        equ 'Z'
DUP_SIGN        equ 'Y'
SWAP_SIGN       equ 'X'
N_SIGN          equ 'N'
NOTEC_SIGN      equ 'n'
DEBUG_SIGN      equ 'g'
RV_SIGN         equ 'W'

global notec
extern debug

section .bss

; Keeps elements offered by n-th notec.
align 8
exchange:       resq N

; Keeps the number of notec with which the n-th notec wants to exchange its element.
; Notecs' numbers are scaled, so that they expand from 1 to N.
; Zero means that n-th notec does not want to exchange its element.
align 4
waiting:        resd N

section .text

; Performs given operations on stack.
; Gets number of this notec in rdi and a string of operations to perform in rsi.
; Returns a number from the top of the stack after all the operations.
; Modifies rax, rdx, rdi, rsi, r8-r11 registers.
notec:
        mov     rax, rsp
        push    rbp
        push    rbx
        push    r12
        mov     rbp, rax                    ; Pushes content of preserved registers that will be modified on stack.

        mov     r12, rdi                    ; r12 keeps the number of this notec.
        mov     rbx, rsi                    ; rbx keeps the string of operations.

        xor     rdi, rdi
        jmp     get_sign

next_sign:
        inc     rbx

get_sign:
        mov     dil, [rbx]
        test    dil, dil                    ; Null sign encountered.
        jz      return

        cmp     dil, ESCAPE_NUM_SIGN
        je      escape
        cmp     dil, ADD_SIGN
        je      sum
        cmp     dil, MUL_SIGN
        je      multiply
        cmp     dil, NEG_SIGN
        je      arythmetic_negation
        cmp     dil, AND_SIGN
        je      logical_and
        cmp     dil, OR_SIGN
        je      logical_or
        cmp     dil, XOR_SIGN
        je      logical_xor
        cmp     dil, NOT_SIGN
        je      bitwise_negation
        cmp     dil, POP_SIGN
        je      stack_pop
        cmp     dil, DUP_SIGN
        je      duplicate
        cmp     dil, SWAP_SIGN
        je      swap
        cmp     dil, N_SIGN
        je      n_count
        cmp     dil, NOTEC_SIGN
        je      nth_number
        cmp     dil, DEBUG_SIGN
        je      debug_call
        cmp     dil, RV_SIGN
        je      rendez_vous

        xor     rax, rax
        jmp     num_mode

next_num:
        inc     rbx
        mov     dil, [rbx]
        test    dil, dil
        jnz     num_mode
        push    rax                         ; Number that was just created needs to be pushed on stack.
        jmp     return

num_mode:
        cmp     dil, '0'
        jb      lowercase_letter
        cmp     dil, '9'
        ja      lowercase_letter

        sub     dil, '0'                    ; Gets the proper value.
        jmp     update_number

lowercase_letter:
        cmp     dil, 'a'
        jb      uppercase_letter
        cmp     dil, 'f'
        ja      uppercase_letter

        sub     dil, 'a' - 10               ; Gets the proper value.
        jmp     update_number

uppercase_letter:
        cmp     dil, 'A'
        jb      escape_num_mode
        cmp     dil, 'F'
        ja      escape_num_mode             ; If current sign is not a digit, num mode is escaped.

        sub     dil, 'A' - 10               ; Gets the proper value.

update_number:
        mov     rsi, 16
        mul     rsi
        add     rax, rdi                    ; Calculates hexadecimal number.

        xor     rdi, rdi
        jmp     next_num

escape_num_mode:
        push    rax
        jmp     get_sign                    ; Current sign was not parsed yet.

escape:
        jmp     next_sign

sum:
        pop     rax
        add     rax, [rsp]
        mov     [rsp], rax
        jmp     next_sign

multiply:
        pop     rax
        mov     rdx, [rsp]
        mul     rdx
        mov     [rsp], rax
        jmp     next_sign

arythmetic_negation:
        mov     rax, [rsp]
        neg     rax
        mov     [rsp], rax
        jmp     next_sign

logical_and:
        pop     rax
        and     rax, [rsp]
        mov     [rsp], rax
        jmp     next_sign

logical_or:
        pop     rax
        or      rax, [rsp]
        mov     [rsp], rax
        jmp     next_sign

logical_xor:
        pop     rax
        xor     rax, [rsp]
        mov     [rsp], rax
        jmp     next_sign

bitwise_negation:
        mov     rax, [rsp]
        not     rax
        mov     [rsp], rax
        jmp     next_sign

stack_pop:
        pop     rax
        jmp     next_sign

duplicate:
        mov     rax, [rsp]
        push    rax
        jmp     next_sign

swap:
        mov     rax, [rsp]
        mov     rdx, [rsp + 8]
        mov     [rsp], rdx
        mov     [rsp + 8], rax
        jmp     next_sign

n_count:
        push    N
        jmp     next_sign

nth_number:
        push    r12
        jmp     next_sign

debug_call:
        mov     rdi, r12
        mov     rsi, rsp

        xor     rdx, rdx
        mov     rax, rsp
        mov     r11, 16
        div     r11
        test    rdx, rdx                    ; Checks if stack needs to be aligned.
        jnz     align_needed

        call    debug
        mov     rdx, 8
        mul     rdx
        add     rsp, rax                    ; Moves stack pointer given number of bytes.
        xor     rdi, rdi
        jmp     next_sign

align_needed:
        sub     rsp, 8
        call    debug
        mov     rdx, 8
        mul     rdx
        add     rsp, rax                    ; Moves stack pointer given number of bytes.
        add     rsp, 8
        xor     rdi, rdi
        jmp     next_sign

rendez_vous:
        pop     rdi                         ; Partner's number.
        inc     rdi                         ; Normalized to [1; N].
        mov     rsi, [rsp]                  ; Offered item.

        lea     r8, [waiting]
        lea     r9, [exchange]
last_value_grabbed_check:
        mov     eax, [r8 + r12 * 4]
        test    eax, eax
        jnz     last_value_grabbed_check    ; Waits for the recent partner to grab its item.

        mov     [r9 + r12 * 8], rsi
        mov     [r8 + r12 * 4], edi         ; Declares offer of this notec.

        mov     r10d, r12d
        inc     r10d                        ; Normalized number of this notec is needed.
        dec     rdi                         ; Real number of the partner is needed.

waiting_for_partner:
        mov     eax, [r8 + rdi * 4]
        cmp     eax, r10d                   ; Checks if the partner wants to exchange.
        jne     waiting_for_partner

        mov     rax, [r9 + rdi * 8]         ; Gets exchanged element.
        mov     [r8 + rdi * 4], DWORD 0     ; Informs partner that its item was grabbed.
        mov     [rsp], rax

        xor     rdi, rdi
        jmp     next_sign

return:
        pop     rax
        mov     rsp, rbp
        mov     rbp, [rsp - 8]
        mov     rbx, [rsp - 16]
        mov     r12, [rsp - 24]             ; Resets value of preserved registers.
        ret