#ifndef __IR_EMITTER_H__
#define __IR_EMITTER_H__

#include <stdarg.h>

typedef struct IREmitter
{
    void (*emit_instr)(struct IREmitter*, const char *fmt, va_list ap);
    void (*emit_label)(struct IREmitter*, int id);
    void *userdata;
} IREmitter;

static inline
void ir_emit(IREmitter *e, const char *fmt, ...)
{
    va_list ap; va_start(ap, fmt);
    e->emit_instr(e, fmt, ap);
    va_end(ap);
}

static inline
void ir_emit_lbl(IREmitter *e, int id)
{ e->emit_label(e, id); }

#endif /* __IR_EMITTER_H__ */

