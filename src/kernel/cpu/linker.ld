ENTRY(start)

SECTIONS 
{
    . = 0x7E00;                 /* location counter = load address */

    .text   : {                 /* code */
        *entry.o(.text)         /* asm stub FIRST -> sits at 0x7E00 (matches any path) */
        *(.text)                /* all other code */
    }       

    .rodata : {*(.rodata)}      /* string literals, const data */
    .data   : {*(.data)}        /* initialized gobals */

    .bss    : {
        __bss_start = .;        /* boundary symbols for zeroing .bss */
        *(.bss)
        *(COMMON)
        __bss_end   = .;
     }         
}
