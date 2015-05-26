#ifndef  MN_MEM_H
#define  MN_MEM_H

#include <stdlib.h>

/*! \file 
 
    Memory management macros to make it easier to debug
    memory usage.
 
 */

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

    /**
     * Tries to allocate a given number of bytes, associating the allocation
     * with an arbitrary user tag.
     */
    #define  MN_MALLOC(size, tag) (mnMalloc(size, tag))
    
    /**
     * Frees a given pointer.
     */
    #define  MN_FREE(ptr) (mnFree(ptr))
    
    void* mnMalloc(size_t size, const char* tag);
    
    void mnFree(void* ptr);
    
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /*  MN_MEM_H */