#ifndef __LOCATION_H__
#define __LOCATION_H__

typedef struct
{
    int         line;
    int         col;
} Position;

typedef struct
{
    //const char *filename;
    Position from;
    Position to;
} Location;

#endif /* __LOCATION_H__ */
