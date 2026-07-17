#include <lib/mem.h>
#include <stddef.h>
#include <lib/kprintf.h>
#include <drivers/console.h>
#include <drivers/keyb_handler.h>
#include <core/info.h>
#include <core/shell.h>
#include <lib/str.h>

#define MAX_ARGS 8

static char *argv[MAX_ARGS];
static int   argc;

struct command {
    const char *name;
    void (*fn)(int argc, char **argv);
};

/*=====================================================================
 * COMMANDS
 *====================================================================*/

/* cmd_echo: Echo's out a command */
static void cmd_echo(int argc, char **argv){
    for(int k = 1; k < argc; k++)
        kprintf("%s ", argv[k]);
    kprintf("\n");
}

/* cmd_clear: Clear's the screen */
static void cmd_clear(int argc, char **argv){
    (void)argc; (void)argv;
    console_clear();
}

/* cmd_version: sends the current kernel version */
static void cmd_version(int argc, char**argv){
    (void)argc; (void)argv;
    kprintf("version %s - %s\n", KERNEL_VERSION_SNAME, KERNEL_VERSION);
}

/* cmd_ping: pongs */
static void cmd_ping(int argc, char**argv){
    (void)argc; (void)argv;
    kprintf("pong");
    kprintf("\n");
}

/* cmd_add: adds two int */
static void cmd_add(int argc, char**argv){
    if(argc > 1){
        kprintf("%u\n", (parse_uint(argv[2])) + parse_uint(argv[1]));
    } else {kprintf("insufficient args\n");}
}



/* cmd_help: FORWARD DECLARATION */
static void cmd_help(int argc, char **argv);

/* cmd_miniman: FORWARD DECLARATION */
static void cmd_miniman(int argc, char **argv);


/*=========================================================================



/* command table */
static const struct command commands[] ={
    {"echo", cmd_echo},
    {"clear", cmd_clear},
    {"version", cmd_version},
    {"help", cmd_help},
    {"ping", cmd_ping},
    {"add", cmd_add},

};



/* Command parser*/
static void handle_command(char *cmd){
    argc = 0;
    int i = 0;
    while (cmd[i] != '\0'){
        while(cmd[i] == ' ')i++;
        if (cmd[i] == '\0') break;
        if (argc < MAX_ARGS) argv[argc++] = &cmd[i];
        while (cmd[i] != ' ' && cmd[i] != '\0') i++;
        if (cmd[i] == ' ') {cmd[i] = '\0'; i++;}
    }

    if (argc==0) return;
    size_t n = sizeof(commands)/sizeof(commands[-1]);
    for (size_t j = 0; j < n; j++){
        if(strcmp(argv[0], commands[j].name) == 0) {
                commands[j].fn(argc,argv);
                return;
        }
    }
    kprintf("unknown: %s\n",argv[0]);
}

/* cmd_help: prints the available commands by table lookup */
static void cmd_help(int argc, char **argv){
    (void)argc; (void)argv;
    for (size_t j = 0; j < sizeof(commands)/sizeof(commands[0]); j++)
            kprintf("%s\n", commands[j].name);
}



/* shell run loop */
void shell_run(void){
    kprintf("(version %s - %s)\n", KERNEL_VERSION_SNAME, KERNEL_VERSION);
    console_write("[bsh=> ");
    for (;;){
        if (keyb_line_ready()) {
            char *cmd = keyb_take_line();
            handle_command(cmd);
            console_write("[bsh=> ");
        }
    }
}
