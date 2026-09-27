@C1 getcwd: [@C1 buf | U64 size ]
@C1 get_current_dir_name: []

@C1 realpath: [ @C1 path | @C1 resolved ]
I32 isatty: [ I32 fd ]

I64 read:    [ I32 fd | @ABYSS buf | U64 n ]
I64 write:   [ I32 fd | @ABYSS buf | U64 n ]
I32 close:   [ I32 fd ]
I32 pipe:    [ @I32 fds ]
I32 dup2:    [ I32 old | I32 new ]
I32 fork:    []
I32 execv:   [ @C1 path | @@C1 argv ]
I32 waitpid: [ I32 pid | @I32 status | I32 options ]
ABYSS _exit: [ I32 code ]

; <signal.h>; the handler is SIG_IGN (1) or SIG_DFL (0) here
@ABYSS signal: [ I32 sig | @ABYSS handler ]
